"""Save and restore Bedroom Gaming Emulator data without touching ROM folders."""

import json
from pathlib import Path
import re
import shutil
import sys
from tempfile import TemporaryDirectory, mkdtemp
from zipfile import ZIP_DEFLATED, ZipFile

STATE = ("settings.cfg", "notebook.cfg", "saves", "posters", "screenscraper", "restored-media")
MEDIA = re.compile(r"restored-media/[0-9a-f]{64}/(?:label\.(?:png|jpe?g|webp)|manual\.pdf|notes\.txt)")
SAVE = re.compile(r"saves/[0-9a-f]{64}\.(?:srm|[\w-]+\.state)")
POSTER = re.compile(r"posters/poster-[1-4]\.png")
SCRAPED = re.compile(r"screenscraper/[0-9a-f]{64}/(?:label\.(?:png|jpe?g|webp)|manual\.pdf)")


def allowed(name):
    return name in STATE[:2] or any(pattern.fullmatch(name) for pattern in (MEDIA, SAVE, POSTER, SCRAPED))


def check_archive_location(root, archive):
    path = archive.resolve()
    if any(path.is_relative_to((root / name).resolve()) for name in STATE):
        raise ValueError("Choose a ZIP outside the app’s data folders.")


def backup(root, destination, manifest_path):
    check_archive_location(root, destination)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = {}
    for component in STATE:
        path = root / component
        for file in path.rglob("*") if path.is_dir() else [path]:
            name = file.relative_to(root).as_posix()
            if file.is_file() and allowed(name):
                files[name] = file
    for name, source in manifest["media"].items():
        if MEDIA.fullmatch(name):
            if "/label." in name:
                prefix = name.rsplit(".", 1)[0]
                for extension in ("png", "jpg", "jpeg", "webp"):
                    files.pop(f"{prefix}.{extension}", None)
            files[name] = Path(source)
    if "settings.cfg" not in files:
        raise ValueError("The app settings could not be saved.")
    if any(destination.resolve() == file.resolve() for file in files.values()):
        raise ValueError("Choose a different location for the backup ZIP.")
    with TemporaryDirectory(dir=destination.parent) as temporary:
        output = Path(temporary) / "backup.zip"
        with ZipFile(output, "w", ZIP_DEFLATED) as archive:
            archive.writestr("backup.json", json.dumps({"version": 1, "roms": manifest["roms"]}))
            for name, file in files.items():
                archive.write(file, name)
        output.replace(destination)


def restore(root, source):
    check_archive_location(root, source)
    with TemporaryDirectory(prefix="restore-", dir=root) as temporary:
        work = Path(temporary)
        staged = work / "staged"
        staged.mkdir()
        with ZipFile(source) as archive:
            entries = archive.infolist()
            names = {entry.filename.lower() for entry in entries}
            if len(names) != len(entries) or not {"backup.json", "settings.cfg"} <= names:
                raise ValueError("This is not a Bedroom Gaming Emulator backup.")
            with archive.open("backup.json") as index:
                manifest = json.loads(index.read(16 * 1024 * 1024))
            if manifest.get("version") != 1:
                raise ValueError("This backup format is unsupported.")
            for entry in entries:
                if entry.filename == "backup.json":
                    continue
                if not allowed(entry.filename):
                    raise ValueError("The backup contains an unexpected file.")
                output = staged / entry.filename
                output.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(entry) as member, output.open("xb") as file:
                    shutil.copyfileobj(member, file)
        # Stage and validate the archive before replacing any current files.
        previous = Path(mkdtemp(prefix="before-restore-", dir=root))
        moved = []
        installed = []
        try:
            for name in STATE:
                current = root / name
                if current.exists():
                    current.replace(previous / name)
                    moved.append(name)
                replacement = staged / name
                if replacement.exists():
                    replacement.replace(current)
                    installed.append(name)
        except OSError:
            try:
                for name in reversed(installed):
                    (root / name).replace(staged / name)
                for name in reversed(moved):
                    (previous / name).replace(root / name)
            except OSError as error:
                raise OSError(f"Restore could not be rolled back. Previous files are in {previous}") from error
            previous.rmdir()
            raise
        shutil.rmtree(previous, ignore_errors=True)


def main():
    operation, root, archive, *args = sys.argv[1:]
    if operation == "backup":
        backup(Path(root), Path(archive), Path(args[0]))
    elif operation == "restore":
        restore(Path(root), Path(archive))
    else:
        raise ValueError("Unknown backup operation.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
