"""Build an x64 Windows ZIP with the embedded Python runtime and PDF support."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.request import urlretrieve
from zipfile import ZipFile

PROJECT = Path(__file__).resolve().parents[1]
PYTHON_VERSION = "3.13.12"
PYTHON_URL = f"https://www.python.org/ftp/python/{PYTHON_VERSION}/python-{PYTHON_VERSION}-embed-amd64.zip"
CORE_NAMES = ("snes9x_libretro.dll", "bsnes_mercury_balanced_libretro.dll")


def build(godot, core_dir, output):
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bedroom-arcade-") as temporary:
        work = Path(temporary)
        portable = work / "Bedroom Arcade"
        portable.mkdir()
        runtime = portable / "runtime"
        runtime.mkdir()

        archive = work / "python.zip"
        urlretrieve(PYTHON_URL, archive)
        with ZipFile(archive) as python:
            python.extractall(runtime)
        paths = runtime / "python313._pth"
        paths.write_text(paths.read_text(encoding="utf-8").rstrip() + "\npackages\n", encoding="utf-8")
        subprocess.run([
            sys.executable, "-m", "pip", "install", "--disable-pip-version-check",
            "--only-binary=:all:", "--platform", "win_amd64", "--python-version", "3.13",
            "--implementation", "cp", "--abi", "cp313", "--target", str(runtime / "packages"),
            "pypdfium2==5.13.0", "Pillow==13.0.0",
        ], check=True)

        for script in ("emulator/host.py", "manuals/render_page.py", "screenscraper/fetch_media.py"):
            destination = portable / script
            destination.parent.mkdir(exist_ok=True)
            shutil.copy2(PROJECT / script, destination)
        included = []
        for name in CORE_NAMES:
            source = core_dir / name
            if source.is_file():
                shutil.copy2(source, portable / "emulator" / name)
                included.append(name)

        notice = [
            "Bedroom Arcade portable build", "",
            "Open Bedroom Arcade.exe from this extracted folder. Keep the runtime,",
            "emulator, and manuals folders beside it. Python and PDF support are included.",
            "Choose your own ROM folder. Place a matching PDF beside the ROM or in its manuals subfolder.",
            "", "Bundled third-party components",
            "Python: runtime/LICENSE.txt",
            "PDFium/pypdfium2 and Pillow: runtime/packages, in the package license and dist-info folders.",
            "Godot: Godot-LICENSE.txt and Godot-COPYRIGHT.txt.",
        ]
        if included:
            notice.extend(["", "Included emulator cores: " + ", ".join(included)])
        else:
            notice.extend(["", "Add a Windows x64 SNES libretro core DLL to the emulator folder for ROM playback."])
            print("No emulator core DLLs found. The package will need a core for ROM playback.", flush=True)
        licenses = {
            "Godot-LICENSE.txt": "https://raw.githubusercontent.com/godotengine/godot/master/LICENSE.txt",
            "Godot-COPYRIGHT.txt": "https://raw.githubusercontent.com/godotengine/godot/master/COPYRIGHT.txt",
        }
        if CORE_NAMES[0] in included:
            licenses["Snes9x-LICENSE.txt"] = "https://raw.githubusercontent.com/libretro/snes9x/master/LICENSE"
            notice.append("Snes9x license and source: Snes9x-LICENSE.txt and https://github.com/libretro/snes9x")
        if CORE_NAMES[1] in included:
            licenses["bsnes-mercury-LICENSE.txt"] = "https://raw.githubusercontent.com/libretro/bsnes-mercury/master/LICENSE"
            notice.append("bsnes-mercury license and source: bsnes-mercury-LICENSE.txt and https://github.com/libretro/bsnes-mercury")
        for filename, url in licenses.items():
            urlretrieve(url, portable / filename)
        (portable / "Read me.txt").write_text("\n".join(notice) + "\n", encoding="utf-8")

        subprocess.run([godot, "--headless", "--path", str(PROJECT), "--editor", "--import"], check=True)
        subprocess.run([
            godot, "--headless", "--path", str(PROJECT), "--export-release",
            "Windows Portable", str(portable / "Bedroom Arcade.exe"),
        ], check=True)
        if not (portable / "Bedroom Arcade.exe").is_file():
            raise RuntimeError("Godot did not create the Windows executable. Check the export templates.")

        result = shutil.make_archive(str(work / "Bedroom-Arcade-Windows"), "zip", work, portable.name)
        shutil.copy2(result, output)
    print(f"Portable Windows package: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Path to a Godot 4 executable")
    parser.add_argument("--core-dir", type=Path, default=PROJECT / "emulator", help="Optional x64 Windows core DLL directory")
    parser.add_argument("--output", type=Path, default=PROJECT / "dist" / "Bedroom-Arcade-Windows.zip")
    args = parser.parse_args()
    build(args.godot, args.core_dir, args.output)


if __name__ == "__main__":
    main()
