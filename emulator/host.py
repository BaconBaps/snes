"""Run a libretro core and stream frames to the Godot room."""

import ctypes as c
import faulthandler
import logging
import os
from pathlib import Path
import select
import socket
import struct
import sys
import time

VOID = c.c_void_p
UINT = c.c_uint
SIZE = c.c_size_t
ENV = c.CFUNCTYPE(c.c_bool, UINT, VOID)
VIDEO = c.CFUNCTYPE(None, VOID, UINT, UINT, SIZE)
AUDIO = c.CFUNCTYPE(None, c.c_int16, c.c_int16)
BATCH = c.CFUNCTYPE(SIZE, VOID, SIZE)
POLL = c.CFUNCTYPE(None)
INPUT = c.CFUNCTYPE(c.c_int16, UINT, UINT, UINT, UINT)
LOG = logging.getLogger("emulator")
# RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 1) in Genesis Plus GX.
MEGA_DRIVE_GAMEPAD = 0x201


class CoreVariable(c.Structure):
    _fields_ = [("key", c.c_char_p), ("value", c.c_char_p)]


# Mercury's built-in DSP implementation supports cartridges such as Super Mario Kart.
# The core gates its DSP option behind the advanced-settings flag.
# Keep the returned C strings alive for the lifetime of the host.
BSNES_OPTIONS = {
    b"bsnes_violate_accuracy": b"enabled",
    b"bsnes_chip_hle": b"HLE",
}


class Game(c.Structure):
    _fields_ = [("path", c.c_char_p), ("data", VOID), ("size", SIZE), ("meta", c.c_char_p)]


class AVInfo(c.Structure):
    _fields_ = [("dimensions", UINT * 4), ("aspect", c.c_float),
                ("fps", c.c_double), ("sample_rate", c.c_double)]


class Emulator:
    def __init__(self, core_path, save_path, mouse_enabled=False):
        self.core = c.CDLL(str(core_path))
        self.gamepad_device = MEGA_DRIVE_GAMEPAD if core_path.stem == "genesis_plus_gx_libretro" else 1
        self.save_path = save_path
        self.state_path = save_path.with_suffix(f".{core_path.stem}.state")
        self.system_dir = os.fsencode(save_path.parent)
        self.pixel_format = 0
        self.buttons = [0, 0]
        self.mouse_enabled = mouse_enabled
        self.clear_mouse()
        self.player_two_connected = False
        self.audio = bytearray()
        self.video = b""
        self.width = self.height = 0

        # ctypes must retain these references for as long as the core is alive.
        self.callbacks = [
            ("environment", ENV(self.environment)),
            ("video_refresh", VIDEO(self.frame)),
            ("audio_sample", AUDIO(self.sample)),
            ("audio_sample_batch", BATCH(self.samples)),
            ("input_poll", POLL(lambda: None)),
            ("input_state", INPUT(self.input_state)),
        ]
        for name, callback in self.callbacks:
            setter = getattr(self.core, "retro_set_" + name)
            setter.argtypes = [type(callback)]
            setter.restype = None
            setter(callback)
        for name in ("init", "deinit", "reset", "run", "unload_game"):
            getattr(self.core, "retro_" + name).restype = None
        self.core.retro_load_game.argtypes = [c.POINTER(Game)]
        self.core.retro_load_game.restype = c.c_bool
        self.core.retro_get_system_av_info.argtypes = [c.POINTER(AVInfo)]
        self.core.retro_get_system_av_info.restype = None
        self.core.retro_get_memory_data.argtypes = [UINT]
        self.core.retro_get_memory_data.restype = VOID
        self.core.retro_get_memory_size.argtypes = [UINT]
        self.core.retro_get_memory_size.restype = SIZE
        self.core.retro_set_controller_port_device.argtypes = [UINT, UINT]
        self.core.retro_set_controller_port_device.restype = None
        self.core.retro_serialize_size.argtypes = []
        self.core.retro_serialize_size.restype = SIZE
        for name in ("retro_serialize", "retro_unserialize"):
            function = getattr(self.core, name)
            function.argtypes = [VOID, SIZE]
            function.restype = c.c_bool

    def environment(self, command, data):
        if command == 10:  # SET_PIXEL_FORMAT
            pixel_format = c.cast(data, c.POINTER(c.c_int))[0]
            if pixel_format in (0, 2):  # 0RGB1555 or RGB565
                self.pixel_format = pixel_format
                return True
        elif command in (9, 31):  # GET_SYSTEM_DIRECTORY, GET_SAVE_DIRECTORY
            c.cast(data, c.POINTER(c.c_char_p))[0] = self.system_dir
            return True
        elif command == 15:  # GET_VARIABLE
            variable = c.cast(data, c.POINTER(CoreVariable)).contents
            if variable.key in BSNES_OPTIONS:
                variable.value = BSNES_OPTIONS[variable.key]
                return True
        elif command == 17:  # GET_VARIABLE_UPDATE
            c.cast(data, c.POINTER(c.c_bool))[0] = False
            return True
        elif command == 3:  # GET_CAN_DUPE
            c.cast(data, c.POINTER(c.c_bool))[0] = True
            return True
        return False

    def frame(self, data, width, height, pitch):
        if not data:
            self.video = b""
            self.width = self.height = 0
            return
        raw = c.string_at(data, pitch * height)
        row_size = width * 2
        if pitch == row_size:
            self.video = raw
        else:
            self.video = b"".join(raw[row:row + row_size] for row in range(0, len(raw), pitch))
        self.width, self.height = width, height

    def sample(self, left, right):
        self.audio.extend(struct.pack("<hh", left, right))

    def samples(self, data, count):
        self.audio.extend(c.string_at(data, count * 4))
        return count

    def input_state(self, port, device, index, button):
        if self.mouse_enabled and port == 0:
            if device == 2 and index == 0 and button < 4:
                return self.mouse_frame[button]
            return 0
        if port < 2 and device == 1 and index == 0 and button < 12:
            return (self.buttons[port] >> button) & 1
        return 0

    def clear_mouse(self):
        self.mouse_motion = [0, 0]
        self.mouse_buttons = 0
        self.mouse_pressed = 0
        self.mouse_frame = (0, 0, 0, 0)

    def prepare_mouse_frame(self):
        # A SNES Mouse reports up to 127 counts per axis at a time.
        dx, dy = (max(-127, min(127, value)) for value in self.mouse_motion)
        self.mouse_motion[0] -= dx
        self.mouse_motion[1] -= dy
        buttons = self.mouse_buttons | self.mouse_pressed
        self.mouse_pressed = 0
        self.mouse_frame = (dx, dy, buttons & 1, (buttons >> 1) & 1)

    def set_port_one(self, mouse_enabled):
        self.mouse_enabled = mouse_enabled
        self.buttons[0] = 0
        self.clear_mouse()
        self.core.retro_set_controller_port_device(0, 2 if mouse_enabled else self.gamepad_device)
        LOG.info("Controller port 1: %s", "SNES Mouse" if mouse_enabled else "Gamepad")

    def set_player_two(self, connected):
        self.player_two_connected = connected
        self.buttons[1] = 0
        self.core.retro_set_controller_port_device(1, self.gamepad_device if connected else 0)

    def load_save(self):
        size = self.core.retro_get_memory_size(0)
        address = self.core.retro_get_memory_data(0)
        if size and address and self.save_path.is_file():
            saved = self.save_path.read_bytes()[:size]
            c.memmove(address, saved, len(saved))

    def save(self):
        size = self.core.retro_get_memory_size(0)
        address = self.core.retro_get_memory_data(0)
        if size and address:
            temporary = self.save_path.with_suffix(".tmp")
            temporary.write_bytes(c.string_at(address, size))
            temporary.replace(self.save_path)

    def state_command(self, save):
        try:
            size = self.core.retro_serialize_size()
            if size <= 0:
                return "This core does not support save states for this game."
            if save:
                data = c.create_string_buffer(size)
                if not self.core.retro_serialize(data, size):
                    return "The core could not capture this save state."
                temporary = self.state_path.with_suffix(".tmp")
                temporary.write_bytes(data.raw)
                temporary.replace(self.state_path)
                return "State saved."
            if not self.state_path.is_file():
                return "No save state for this game and core."
            if self.state_path.stat().st_size != size:
                return "This state is incompatible with the current core."
            data = c.create_string_buffer(self.state_path.read_bytes())
            if not self.core.retro_unserialize(data, size):
                return "The core could not load this state."
            return "State loaded."
        except OSError:
            return "Could not access the save-state file."

    def run(self, connection, rom_path):
        LOG.info("Reading ROM")
        rom = rom_path.read_bytes()
        buffer = c.create_string_buffer(rom)
        game = Game(os.fsencode(rom_path), c.cast(buffer, VOID), len(rom), None)
        LOG.info("Initializing core")
        self.core.retro_init()
        try:
            LOG.info("Loading cartridge (%d bytes)", len(rom))
            if not self.core.retro_load_game(c.byref(game)):
                raise RuntimeError("The emulator core could not load this ROM.")
            try:
                LOG.info("Configuring controllers")
                self.set_port_one(self.mouse_enabled)
                self.set_player_two(False)
                LOG.info("Loading battery save (present: %s)", self.save_path.is_file())
                self.load_save()
                LOG.info("Querying audio and video settings")
                av = AVInfo()
                self.core.retro_get_system_av_info(c.byref(av))
                LOG.info("Starting emulation (%.3f fps, %.0f Hz)", av.fps, av.sample_rate)
                self.stream(connection, av)
                LOG.info("Playback ended")
            finally:
                try:
                    self.save()
                finally:
                    self.core.retro_unload_game()
        finally:
            self.core.retro_deinit()

    def stream(self, connection, av):
        interval = 1.0 / av.fps
        deadline = time.monotonic()
        commands = bytearray()
        sample_start = deadline
        frame_count = 0
        sent_first_picture = False
        paused = False
        core_seconds = 0.0
        send_seconds = 0.0
        while True:
            timeout = None if paused else max(0, deadline - time.monotonic())
            ready, _, _ = select.select([connection], [], [], timeout)
            if ready:
                incoming = connection.recv(1024)
                if not incoming:
                    return
                commands.extend(incoming)
                while len(commands) >= 3:
                    command, mask = struct.unpack_from("<BH", commands)
                    del commands[:3]
                    if command == ord("Q"):
                        return
                    if command == ord("U"):
                        paused = bool(mask)
                        self.buttons[:] = [0, 0]
                        self.clear_mouse()
                        if not paused:
                            deadline = sample_start = time.monotonic()
                            frame_count = 0
                            core_seconds = send_seconds = 0.0
                    elif command == ord("R"):
                        self.core.retro_reset()
                    elif command in (ord("S"), ord("L")):
                        message = self.state_command(command == ord("S")).encode("utf-8")
                        connection.sendall(struct.pack("<IIIII", 5, 0, 0, 0, len(message)) + message)
                    elif command == ord("P"):
                        self.set_player_two(bool(mask))
                    elif command == ord("D") and bool(mask) != self.mouse_enabled:
                        self.set_port_one(bool(mask))
                    elif command == ord("C"):
                        self.clear_mouse()
                    elif self.mouse_enabled and command in (ord("X"), ord("Y")):
                        axis = command - ord("X")
                        value = mask if mask < 32768 else mask - 65536
                        self.mouse_motion[axis] = max(-4096, min(4096, self.mouse_motion[axis] + value))
                    elif self.mouse_enabled and command == ord("M"):
                        buttons = mask & 3
                        self.mouse_pressed |= buttons & ~self.mouse_buttons
                        self.mouse_buttons = buttons
                    elif command == ord("I"):
                        self.buttons[0] = mask
                    elif command == ord("J") and self.player_two_connected:
                        self.buttons[1] = mask
                if paused or time.monotonic() < deadline:
                    continue
            self.audio.clear()
            self.video = b""
            self.width = self.height = 0
            frame_start = time.monotonic()
            if self.mouse_enabled:
                self.prepare_mouse_frame()
            self.core.retro_run()
            core_end = time.monotonic()
            kind = 2 if self.pixel_format == 2 else 3
            header = struct.pack("<IIIII", kind, self.width, self.height, round(av.sample_rate), len(self.audio))
            connection.sendall(header + self.video + self.audio)
            if not sent_first_picture and self.video:
                LOG.info("Sent first picture (%d × %d)", self.width, self.height)
                sent_first_picture = True
            now = time.monotonic()
            frame_count += 1
            core_seconds += core_end - frame_start
            send_seconds += now - core_end
            elapsed = now - sample_start
            if elapsed >= 1.0:
                stats = struct.pack("<IIIII", 4, round(av.fps * 1000),
                                    round(frame_count / elapsed * 1000),
                                    round(core_seconds * 1e6 / frame_count),
                                    round(send_seconds * 1e6 / frame_count))
                connection.sendall(stats)
                sample_start = now
                frame_count = 0
                core_seconds = send_seconds = 0.0
            deadline += interval
            if deadline < time.monotonic() - 3 * interval:
                deadline = time.monotonic()


def run_host(port, nonce, core, rom, save, mouse_enabled=False):
    # Windows socket waits can otherwise round up to the system timer tick.
    timer = c.WinDLL("winmm") if sys.platform == "win32" else None
    timer_active = timer is not None and timer.timeBeginPeriod(1) == 0
    try:
        with socket.create_connection(("127.0.0.1", int(port)), timeout=3) as connection:
            connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            # A high-resolution SNES frame can exceed the default send buffer.
            connection.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1024 * 1024)
            connection.sendall(nonce.encode("ascii"))
            try:
                LOG.info("Opening core library")
                Emulator(Path(core), Path(save), mouse_enabled).run(connection, Path(rom))
            except (BrokenPipeError, ConnectionResetError):
                pass
            except Exception as error:
                LOG.exception("Emulator error")
                message = str(error).encode("utf-8")[:4096]
                try:
                    connection.sendall(struct.pack("<IIIII", 1, 0, 0, 0, len(message)) + message)
                    # Let Godot consume the error before closing the connection.
                    while connection.recv(1024):
                        pass
                except OSError:
                    pass
    finally:
        if timer_active:
            timer.timeEndPeriod(1)


def main():
    arguments = sys.argv[1:]
    if len(arguments) == 5:
        run_host(*arguments)
        return
    port, nonce, core, rom, save, log_path, *options = arguments
    mouse_enabled = options == ["mouse"]
    try:
        log_file = open(log_path, "w", encoding="utf-8", buffering=1)
    except OSError:
        run_host(port, nonce, core, rom, save, mouse_enabled)
        return
    with log_file:
        logging.basicConfig(stream=log_file, level=logging.INFO, format="%(levelname)s %(message)s")
        faulthandler.enable(file=log_file, all_threads=False)
        try:
            LOG.info("Cartridge: %s | Core: %s", Path(rom).name, Path(core).name)
            run_host(port, nonce, core, rom, save, mouse_enabled)
        except Exception:
            LOG.exception("Emulator host stopped")
            raise
        finally:
            faulthandler.disable()


if __name__ == "__main__":
    main()
