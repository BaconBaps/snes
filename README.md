# Bedroom Arcade

A Godot 4 Super Nintendo emulator frontend set in a 1990s bedroom. Insert a cartridge to boot the game. The CRT renders the game, **Reset** restarts it in place, and **Eject** turns it off and releases the cartridge.

## Run it on Windows

1. Download the project using **Code → Download ZIP** and extract it.
2. Install [64-bit Python 3 for Windows](https://www.python.org/downloads/windows/). If the installer offers **Add Python to PATH**, enable it. Confirm that `python --version` works in a new terminal. Restart Godot if it was open while you installed Python.
3. Download either 64-bit Windows core and extract its DLL into the project's `emulator` folder, next to `host.py`. You can install both to compare them.
   - [Snes9x](https://buildbot.libretro.com/nightly/windows/x86_64/latest/snes9x_libretro.dll.zip)
   - [bsnes-mercury Balanced](https://buildbot.libretro.com/nightly/windows/x86_64/latest/bsnes_mercury_balanced_libretro.dll.zip)
4. In the Godot Project Manager, choose **Import**, select `project.godot`, and press **F5**.
5. Click the **Settings** gear, then **Choose ROM folder** and select a folder containing your `.sfc` or `.smc` files. Choose the core in **Settings → Emulation**, then drag a cartridge to the slot. To compare cores, eject the cartridge, choose the other core, and reinsert it.

The sample cartridges show a graphical preview without Python or a core. The core binaries and ROMs are separate from the repository. See the [Snes9x license](https://github.com/libretro/snes9x/blob/master/LICENSE) and [bsnes-mercury source and license](https://github.com/libretro/bsnes-mercury).

The ROM folder and preferences are saved in Godot’s per-user data folder. They carry over when you extract an updated project and run it under the same user account.

## Cartridge notebook and shoeboxes

Click the **Game notes** pad tucked behind the cartridges to search by name or filter for favourites, recently played games, and the active shoebox. Choose a result and click **Find in shoebox** to jump to and highlight its cartridge.

To make a custom shoebox, enter a name and click **Create box**. Select a game in the notebook and choose **Add to box**. Use **Move earlier** or **Move later**, or drag a cartridge onto another cartridge in the shoebox to change its place. The notebook remembers favourites, recent games, custom boxes, and their order across launches. Select **All cartridges** to return to the complete ROM library.

## Cartridge artwork

Put a cropped label image next to its ROM or choose a separate directory under **Settings → Choose cartridge art folder**. Use the same filename before the extension, including any region tags. For example, pair `Super Mario Kart (Europe).sfc` with `Super Mario Kart (Europe).png`. PNG, JPG, and JPEG are supported. The separate artwork folder takes priority when both locations have a match. Games without matching artwork keep their generated labels.

Artwork stretches to fill the rounded label area. Crop it to roughly 3.7:1 beforehand if you want to preserve its original proportions.

## Room and emulation settings

Click any wall poster to choose a PNG, JPG, JPEG, or WebP image. It stretches to fill that poster and is saved for future launches. Choose **Restore original** in the same dialog to bring back its original artwork.

Click the hanging light to dim the bedroom. The CRT image and its glow keep their brightness. Use **Settings → CRT television** to choose the Original, Graphite, or Silver cabinet.

**Settings → Emulation** contains the core selector, **Save state**, **Load state**, **Scanlines**, and the **Shader preset** picker. Save states capture the running game and use one slot per ROM and core. These files are separate from battery saves. The display controls take effect immediately.

## Controls

| Action | Input |
| --- | --- |
| SNES D-pad | Arrow keys or gamepad D-pad |
| SNES B / A | Z / X, or gamepad south / east face buttons |
| SNES Y / X | A / S, or gamepad west / north face buttons |
| SNES L / R | Q / W, or gamepad shoulder buttons |
| Start / Select | Enter / Shift, or gamepad Start / Back |
| Fullscreen | F11 |

For local multiplayer, drag the loose gray plug from the floor into the console’s front-right port. The second gamepad Godot detects then controls Player 2. Pull the plug out and drop it away from the port to disconnect it. Player 1 keeps keyboard and first-gamepad input. You can plug in before or during a game.

After ejecting, drag the cartridge back to the shoebox before inserting another. **Stack** is the default. Use **Settings → Cartridge view** to switch to **Grid**. In Stack view, hover over an exposed cartridge to lift it and reveal its full label, then drag it as usual. Use the mouse wheel or the arrows on the front of the shoebox to turn pages. **A–Z** jumps to the page containing the first matching title. Saves are written to Godot's `user://saves` folder on eject or normal exit. Keep ROMs at the same paths so the prototype can match them to their saves.

On Linux x86-64, put the [Linux Snes9x core](https://buildbot.libretro.com/nightly/linux/x86_64/latest/snes9x_libretro.so.zip) or the [Linux bsnes-mercury Balanced core](https://buildbot.libretro.com/nightly/linux/x86_64/latest/bsnes_mercury_balanced_libretro.so.zip) in the same folder and use `python3`. Set `BEDROOM_ARCADE_PYTHON` to a Python executable path to override the default.

## Gamepad room controls

Move either analogue stick on the first gamepad to reveal and steer the virtual pointer. Tap **L2** to pick up a cartridge or loose plug and tap **L2** again to drop it. Use **R2** to click room controls, page arrows, the A–Z menu, and Settings. While holding an item, **R2** cancels and puts it back. Moving the mouse switches back to the regular pointer.

The D-pad, face buttons, L1/R1, Start and Back/Select remain mapped to SNES gameplay. You can move the virtual pointer without moving your character.

## Playback diagnostics

Press **F10** while playing to show timing for the current session. Play for a few seconds before reading it. **Core** shows the measured emulation rate and the game's nominal rate. **Received** counts completed frame packets per second, and **CRT** counts video uploads per second. **Godot** shows the window's render rate. **Audio underruns** counts times the generator ran out of samples during the last interval. If playback stutters, capture both lines while it is happening.
