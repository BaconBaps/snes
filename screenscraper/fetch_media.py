"""Download missing SNES media using ScreenScraper API v2."""
import hashlib
import json
import os
import re
import sys
import time
import zlib
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, build_opener

API = "https://api.screenscraper.fr/api2/"
SYSTEM = "4"
LABEL_TYPES = ("support-texture", "support-2d")


class DownloadStopped(Exception):
    pass


class MediaMissing(Exception):
    pass


class SameServiceRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not service_url(newurl):
            raise DownloadStopped("ScreenScraper redirected outside its API.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def service_url(url):
    parts = urlsplit(url)
    return parts.scheme == "https" and parts.netloc.lower() in {
        "api.screenscraper.fr", "www.screenscraper.fr", "screenscraper.fr",
    } and parts.path.startswith("/api2/")


def counter(info, *names):
    for name in names:
        try:
            return int(info.get(name))
        except (TypeError, ValueError):
            continue
    return 0


class ScreenScraper:
    def __init__(self, credentials):
        self.credentials = {**credentials, "softname": "Bedroom Arcade"}
        self.opener = build_opener(SameServiceRedirect())
        self.next_request = 0.0
        self.interval = 1.0
        self.daily_remaining = None
        self.misses_remaining = None

    def get(self, url, limit):
        if not service_url(url):
            raise DownloadStopped("ScreenScraper returned an unexpected media URL.")
        if self.daily_remaining is not None and self.daily_remaining <= 0:
            raise DownloadStopped("The daily ScreenScraper request limit has been reached.")
        time.sleep(max(0.0, self.next_request - time.monotonic()))
        self.next_request = time.monotonic() + self.interval
        if self.daily_remaining is not None:
            self.daily_remaining -= 1
        parts = urlsplit(url)
        params = dict(parse_qsl(parts.query))
        params.update(self.credentials)
        authenticated_url = urlunsplit(parts._replace(query=urlencode(params), fragment=""))
        try:
            with self.opener.open(authenticated_url, timeout=20) as response:
                data = response.read(limit + 1)
        except HTTPError as error:
            code = error.code
            if code == 404:
                raise MediaMissing from None
            messages = {
                401: "ScreenScraper is currently limiting access. Check your account or try again later.",
                403: "ScreenScraper denied access. Check your account and developer credentials.",
                429: "ScreenScraper is rate limiting requests. Try again later.",
                430: "Your daily ScreenScraper request limit has been reached.",
                431: "Your daily limit for unrecognised ROMs has been reached.",
            }
            raise DownloadStopped(messages.get(code, f"ScreenScraper returned HTTP {code}.")) from None
        except (OSError, URLError):
            raise DownloadStopped("Could not connect to ScreenScraper. Try again later.") from None
        if len(data) > limit or data.strip() == b"NOMEDIA":
            raise MediaMissing
        return data

    def json(self, endpoint, **params):
        url = API + endpoint + "?" + urlencode({**params, "output": "json"})
        try:
            data = json.loads(self.get(url, 4 * 1024 * 1024))
            return data["response"]
        except (ValueError, TypeError, KeyError):
            raise DownloadStopped("ScreenScraper returned an unreadable API response.") from None

    def read_quota(self):
        try:
            user = self.json("ssuserInfos.php").get("ssuser", {})
        except MediaMissing:
            raise DownloadStopped("ScreenScraper could not find your account.") from None
        per_minute = counter(user, "maxrequestspermin", "maxrequestsperdmin")
        if per_minute > 0:
            self.interval = max(1.0, 60.0 / per_minute)
            self.next_request = max(self.next_request, time.monotonic() + self.interval)
        daily_limit = counter(user, "maxrequestsperday")
        if daily_limit > 0:
            self.daily_remaining = daily_limit - counter(user, "requeststoday")
        miss_limit = counter(user, "maxrequestskoperday")
        if miss_limit > 0:
            self.misses_remaining = miss_limit - counter(user, "requestskotoday")

    def game_info(self, rom):
        if self.misses_remaining is not None and self.misses_remaining <= 0:
            raise DownloadStopped("Your daily limit for unrecognised ROMs has been reached.")
        with rom.open("rb") as file:
            size = rom.stat().st_size
            if size % 1024 == 512:
                file.seek(512)
                size -= 512
            crc = 0
            md5 = hashlib.md5(usedforsecurity=False)
            sha1 = hashlib.sha1(usedforsecurity=False)
            for chunk in iter(lambda: file.read(1024 * 1024), b""):
                crc = zlib.crc32(chunk, crc)
                md5.update(chunk)
                sha1.update(chunk)
        try:
            return self.json("jeuInfos.php", systemeid=SYSTEM, romtype="rom",
                             romnom=rom.name, romtaille=size, crc=f"{crc:08x}",
                             md5=md5.hexdigest(), sha1=sha1.hexdigest())
        except MediaMissing:
            if self.misses_remaining is not None:
                self.misses_remaining -= 1
            raise


def preferred_regions(name, info):
    aliases = {"usa": "us", "europe": "eu", "japan": "jp", "world": "wor",
               "france": "fr", "germany": "de", "spain": "es", "italy": "it"}
    filename_regions = [aliases[tag] for tag in re.findall(r"[a-z]+", " ".join(
        re.findall(r"\(([^)]+)\)", name.lower()))) if tag in aliases]
    rom = info.get("rom") or {}
    matched = (rom.get("romregions") or {}).get("romregion", [])
    region_codes = [item.get("shortname", "") for item in matched if isinstance(item, dict)]
    return list(dict.fromkeys(filename_regions + region_codes + ["wor", "us", "eu", "uk", "jp"]))


def media_urls(game, kinds, regions):
    media = game.get("medias", [])
    if isinstance(media, list):
        def preference(item):
            region = item.get("region")
            rank = regions.index(region) if region in regions else len(regions)
            return rank, kinds.index(item["type"].lower())

        eligible = [item for item in media if isinstance(item, dict)
                    and str(item.get("type", "")).lower() in kinds and item.get("url")]
        yield from (item["url"] for item in sorted(eligible, key=preference))
    elif isinstance(media, dict):
        # Older response format groups each media type by region.
        for region in regions:
            for kind in kinds:
                if kind == "manuel":
                    url = (media.get("media_manuel") or {}).get("media_manuel_" + region)
                else:
                    suffix = kind.split("-")[1]
                    group = (media.get("media_supports") or {}).get("media_supports_" + suffix, {})
                    url = group.get("media_support_" + suffix + "_" + region)
                if url:
                    yield url


def label_extension(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if data.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "webp"
    return None


def write_atomic(path, data):
    temporary = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        temporary.write_bytes(data)
        for retry in range(4):
            try:
                temporary.replace(path)
                return
            except PermissionError:
                if retry == 3:
                    raise
                time.sleep(0.05)
    finally:
        temporary.unlink(missing_ok=True)


def download(api, game, directory, regions, label):
    kinds = LABEL_TYPES if label else ("manuel",)
    limit = (16 if label else 80) * 1024 * 1024
    for url in dict.fromkeys(media_urls(game, kinds, regions)):
        try:
            data = api.get(url, limit)
        except MediaMissing:
            continue
        extension = label_extension(data) if label else ("pdf" if data.startswith(b"%PDF-") else None)
        if extension:
            directory.mkdir(parents=True, exist_ok=True)
            filename = f"label.{extension}" if label else "manual.pdf"
            write_atomic(directory / filename, data)
            return True
    return False


def run(config, report):
    jobs = config["jobs"]
    api = ScreenScraper(config["credentials"])
    labels = manuals = missing = unreadable = 0
    try:
        api.read_quota()
        for index, job in enumerate(jobs, start=1):
            rom = Path(job["rom"])
            report(f"Game {index} of {len(jobs)} · {rom.stem}")
            try:
                info = api.game_info(rom)
            except MediaMissing:
                missing += 1
                continue
            except OSError:
                unreadable += 1
                continue
            game = info.get("jeu") or {}
            regions = preferred_regions(rom.name, info)
            directory = Path(job["directory"])
            has_label = job["label"] and download(api, game, directory, regions, True)
            labels += has_label
            has_manual = job["manual"] and download(api, game, directory, regions, False)
            manuals += has_manual
            if (job["label"] and not has_label) or (job["manual"] and not has_manual):
                missing += 1
        result = "Download complete."
    except DownloadStopped as error:
        result = str(error)
    except OSError:
        result = "Could not write the ScreenScraper cache."
    summary = f"{result} Saved {labels} cartridge images and {manuals} manuals."
    if missing:
        summary += f" Media unavailable for {missing} games."
    if unreadable:
        summary += f" Could not read {unreadable} ROM files."
    report(summary, done=True)


def main():
    path = Path(sys.argv[1])

    def report(message, done=False):
        write_atomic(path, json.dumps({"message": message, "done": done}).encode("utf-8"))

    try:
        credentials = json.loads(sys.stdin.buffer.readline())
        manifest = Path(str(path) + ".jobs")
        jobs = json.loads(manifest.read_text(encoding="utf-8"))
        manifest.unlink()
        run({"credentials": credentials, "jobs": jobs}, report)
    except Exception:
        # Avoid printing request URLs, which include credentials.
        report("The downloader could not complete this request.", done=True)


if __name__ == "__main__":
    main()
