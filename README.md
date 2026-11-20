# Bedroom Arcade

A Godot 4 Super Nintendo emulator frontend set in a 1990s bedroom. Insert a cartridge to boot the game. The CRT renders the game, **Reset** restarts it in place, and **Eject** turns it off and releases the cartridge.

## Run it on Windows

1. Download the project using **Code → Download ZIP** and extract it.
2. Install [64-bit Python 3 for Windows](https://www.python.org/downloads/windows/). If the installer offers **Add Python to PATH**, enable it. Confirm that `python --version` works in a new terminal. Restart Godot if it was open while you installed Python.
3. Download either 64-bit Windows core and extract its DLL into the project's `emulator` folder, next to `host.py`. You can install both to compare them.
   - [Snes9x](https://buildbot.libretro.com/nightly/windows/x86_64/latest/snes9x_libretro.dll.zip)
   - [bsnes-mercury Balanced](https://buildbot.libretro.com/nightly/windows/x86_64/latest/bsnes_mercury_balanced_libretro.dll.zip)
4. In the Godot Project Manager, choose **Import**, select `project.godot`, and press **F5**.
5. Click **Choose ROM folder** and select a folder containing your `.sfc` or `.smc` files. Choose the core next to the folder button, then drag a cartridge to the slot. To compare cores, eject the cartridge, choose the other core, and reinsert it.

The sample cartridges show a graphical preview without Python or a core. The core binaries and ROMs are separate from the repository. See the [Snes9x license](https://github.com/libretro/snes9x/blob/master/LICENSE) and [bsnes-mercury source and license](https://github.com/libretro/bsnes-mercury).

## Controls

| Action | Input |
| --- | --- |
| SNES D-pad | Arrow keys or gamepad D-pad |
| SNES B / A | Z / X, or gamepad south / east face buttons |
| SNES Y / X | A / S, or gamepad west / north face buttons |
| SNES L / R | Q / W, or gamepad shoulder buttons |
| Start / Select | Enter / Shift, or gamepad Start / Back |
| Fullscreen | F11 |

After ejecting, drag the cartridge back to the desk before inserting another. Use the **Grid / Stack** selector underneath the desk to change layouts. In Stack view, hover over an exposed cartridge to lift it and reveal its full label, then drag it as usual. Scroll over the desk to view more cartridges. Saves are written to Godot's `user://saves` folder on eject or normal exit. Keep ROMs at the same paths so the prototype can match them to their saves.

On Linux x86-64, put the [Linux Snes9x core](https://buildbot.libretro.com/nightly/linux/x86_64/latest/snes9x_libretro.so.zip) or the [Linux bsnes-mercury Balanced core](https://buildbot.libretro.com/nightly/linux/x86_64/latest/bsnes_mercury_balanced_libretro.so.zip) in the same folder and use `python3`. Set `BEDROOM_ARCADE_PYTHON` to a Python executable path to override the default.

## Playback diagnostics

Press **F10** while playing to show timing for the current session. Play for a few seconds before reading it. **Core** shows the measured emulation rate and the game's nominal rate. **Received** counts completed frame packets per second, and **CRT** counts video uploads per second. **Godot** shows the window's render rate. **Audio underruns** counts times the generator ran out of samples during the last interval. If playback stutters, capture both lines while it is happening.
