# Bedroom Gaming Emulator

A Godot 4 Super Nintendo and Mega Drive emulator frontend set in a 1990s bedroom. Insert a cartridge to boot the game. The CRT renders the game, **Reset** restarts it in place, and **Eject** turns it off and releases the cartridge.

## Run it on Windows

1. Download the project using **Code → Download ZIP** and extract it.
2. Install [64-bit Python 3 for Windows](https://www.python.org/downloads/windows/). If the installer offers **Add Python to PATH**, enable it. Confirm that `python --version` works in a new terminal. Restart Godot if it was open while you installed Python.
3. Download either 64-bit Windows core and extract its DLL into the project's `emulator` folder, next to `host.py`. You can install both to compare them.
   - [Snes9x](https://buildbot.libretro.com/nightly/windows/x86_64/latest/snes9x_libretro.dll.zip)
   - [bsnes-mercury Balanced](https://buildbot.libretro.com/nightly/windows/x86_64/latest/bsnes_mercury_balanced_libretro.dll.zip)
4. In the Godot Project Manager, choose **Import**, select `project.godot`, and press **F5**.
5. Follow the setup wizard to choose folders for your SNES and Mega Drive libraries and see the gamepad controls. Choose the core in **Settings → Emulation**, then drag a cartridge to the slot. To compare cores, eject the cartridge, choose the other core, and reinsert it.

The sample cartridges show a graphical preview without Python or a core. The core binaries and ROMs are separate from the repository. See the [Snes9x license](https://github.com/libretro/snes9x/blob/master/LICENSE) and [bsnes-mercury source and license](https://github.com/libretro/bsnes-mercury).

The ROM folder and preferences are saved in Godot’s per-user data folder. They carry over when you extract an updated project and run it under the same user account.

## First-time setup

The wizard opens automatically on a fresh profile. It covers controls and lets you choose separate ROM, cartridge art and PDF manual folders for each console. You can skip any folder or skip setup entirely. Open **Settings → Setup wizard** to return later. Existing profiles can open the wizard from Settings.

Keep the same filename stem for matching files, including any region tags. For example, `Sonic (USA).md`, `Sonic (USA).png` and `Sonic (USA).pdf` match.

## Build a portable Windows ZIP

Install the export templates matching your Godot 4 editor (**Editor → Manage Export Templates**). From the project folder, run this build command with a Python installation that has pip:

```powershell
python tools/package_windows.py --godot "C:\path\to\Godot.exe"
```

The output is `dist/Bedroom-Gaming-Emulator-Windows.zip`. The builder packages an x64 executable, an embedded Python runtime, the PDF renderer, and any supported Windows core DLLs that you have placed in `emulator`. You can point it to a different DLL folder with `--core-dir`. Check the core's redistribution terms before sharing its binary. ROMs and manuals stay in the recipient's own library.

Recipients extract the ZIP and open **Bedroom Gaming Emulator.exe**. Keep the adjacent folders with the executable. They do not need Godot, Python, pip, or a separate PDF viewer.

## Cart List and shoeboxes

Click the **Cart List** pad tucked behind the cartridges to search by name or filter for favourites, recently played games, and the active shoebox. Choose a result and click **Find in shoebox** to jump to and highlight its cartridge.

To make a custom shoebox, enter a name and click **Create box**. Select a game in the notebook and choose **Add to box**. Use **Move earlier** or **Move later**, or drag a cartridge onto another cartridge in the shoebox to change its place. The notebook remembers favourites, recent games, custom boxes, and their order across launches. Select **All cartridges** to return to the complete ROM library.

## Game Notes

Insert a cartridge and click the **Game Notes** booklet beside the Cart List. The editor opens on the right and saves your text automatically beside the ROM. For example, `Sonic (USA).md` uses `Sonic (USA).txt`.

## Mega Drive

Extract the [Windows x64 Genesis Plus GX core](https://buildbot.libretro.com/nightly/windows/x86_64/latest/genesis_plus_gx_libretro.dll.zip) into `emulator` beside `host.py`. On Linux x86-64, use the [Linux core](https://buildbot.libretro.com/nightly/linux/x86_64/latest/genesis_plus_gx_libretro.so.zip).

Press **MEGA DRIVE** on the TV or choose it in Settings, then choose a ROM folder containing `.md`, `.gen`, `.bin`, or `.smd` cartridges. The Mega Drive remembers its own ROM and artwork folders. Use the **SNES** and **MEGA DRIVE** buttons on the TV to switch inputs. Switching pauses the outgoing game and resumes the incoming game when its console finishes sliding in. Both cartridges stay where you left them until you close the app. Drag a cartridge into the slot to boot it, click the white **Reset** button to restart, and pull the cartridge free to power off. The sample cartridges still work as a graphical preview without a ROM folder.

The core uses six-button controllers. On a gamepad, the west, south, and east face buttons map to A, B, and C. L1, north, and R1 map to X, Y, and Z. On the keyboard, **A**, **Z**, **X** map to A, B, C, and **Q**, **S**, **W** map to X, Y, Z. Enter is Start and Shift is Mode. Connect the second plug to enable Player 2.

## Instruction manuals

The portable Windows ZIP includes PDF support. If you run the Godot source project directly, install the optional PDF renderer with `python -m pip install pypdfium2 Pillow` (use `python3` on Linux). Name the PDF like the ROM, for example `Super Mario Kart (Europe).pdf` for `Super Mario Kart (Europe).sfc`. Put it beside the ROM or in a `manuals` subfolder inside the ROM folder.

When you insert a matching cartridge, its first PDF page fades onto the booklet behind the right-hand stack. Click the booklet to read over the shoebox. The cover opens on the right, followed by facing pages and a final page alone on the left. The controls are centred below the spread. Click the right or left side of the spread to turn forward or back. The **Previous** and **Next** buttons work too. Use **2×** zoom to read small text. The emulator keeps running while the manual is open.

## Cartridge artwork

Put a cropped label image next to its ROM or choose a separate directory under **Settings → Choose cartridge art folder**. Use the same filename before the extension, including any region tags. For example, pair `Super Mario Kart (Europe).sfc` with `Super Mario Kart (Europe).png`. PNG, JPG, and JPEG are supported. The separate artwork folder takes priority when both locations have a match. Games without matching artwork keep their generated labels.

Artwork stretches to fill the rounded label area. Crop it to roughly 3.7:1 beforehand if you want to preserve its original proportions.

## ScreenScraper downloads

Open **Settings → Download art and manuals**, enter your [ScreenScraper](https://www.screenscraper.fr/) account credentials and your developer API credentials, then choose **Download missing media**. ScreenScraper requires a developer ID and password for API access. See the [ScreenScraper API documentation](https://www.screenscraper.fr/webapi2.php) for details. The app keeps credentials only for the current session.

The app matches the games in the selected ROM folder using filenames and checksums. It downloads available cartridge artwork and PDF manuals into the app's data folder. Local artwork and manuals take priority. Downloads already saved are reused on future launches. If ScreenScraper pauses the run because of your account quota, you can run it again once the quota resets.

## Room and emulation settings

Click any wall poster to choose a PNG, JPG, JPEG, or WebP image. It stretches to fill that poster and is saved for future launches. Choose **Restore original** in the same dialog to bring back its original artwork.

Click the hanging light to dim the bedroom. The CRT image and its glow keep their brightness. The room uses the Graphite cabinet with the Soft CRT effect.

**Settings → Emulation** contains the SNES core selector, **Save state**, and **Load state**. Save states capture the running game and use one slot per ROM and core. These files are separate from battery saves.

bsnes Balanced uses its built-in DSP emulation for cartridges such as Super Mario Kart.

If a game stops unexpectedly, open **Settings → Emulation → Open last emulator log** before starting another game. The log lists the cartridge, selected core, and last startup step reached. Each launch replaces the previous log.

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

## SNES Mouse

Mario Paint filenames select the SNES Mouse automatically. For other titles, insert the cartridge and choose **SNES Mouse** under **Settings → Emulation → Controller port 1**. The choice is saved for that ROM. **Auto** uses the filename to choose between the mouse and gamepad.

Click the CRT to capture the mouse. Move it and use the left and right buttons in the game. Press **Esc** to return to the room. The mouse also releases when the window loses focus or playback stops.
