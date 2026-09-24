import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import time

ORIGIN = "https://music.youtube.com"

WANTED = (
    "SID",
    "HSID",
    "SSID",
    "APISID",
    "SAPISID",
    "LOGIN_INFO",
    "PREF",
    "SIDCC",
    "__Secure-1PSID",
    "__Secure-3PSID",
    "__Secure-1PAPISID",
    "__Secure-3PAPISID",
    "__Secure-1PSIDCC",
    "__Secure-3PSIDCC",
    "__Secure-1PSIDTS",
    "__Secure-3PSIDTS",
)

AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/140.0.0.0 Safari/537.36"
)


def profile():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.environ.get("VJMUSIC_PROFILE") or os.path.join(base, "YouTube Music")


def cookies():
    source = os.path.join(profile(), "Cookies")
    if not os.path.exists(source):
        raise SystemExit("not_signed_in")

    with tempfile.TemporaryDirectory() as work:
        copy = os.path.join(work, "Cookies")
        shutil.copy2(source, copy)
        db = sqlite3.connect(copy)
        try:
            rows = db.execute(
                "select name, value from cookies "
                "where host_key like '%youtube.com' and value != ''"
            ).fetchall()
        finally:
            db.close()

    found = {name: value for name, value in rows if name in WANTED}
    secret = found.get("SAPISID") or found.get("__Secure-3PAPISID")
    if not secret:
        raise SystemExit("not_signed_in")

    header = "; ".join(f"{name}={value}" for name, value in found.items())
    return header, secret


def authorization(secret):
    stamp = int(time.time())
    digest = hashlib.sha1(f"{stamp} {secret} {ORIGIN}".encode()).hexdigest()
    return f"SAPISIDHASH {stamp}_{digest}"


def track(item):
    artists = item.get("artists") or []
    album = item.get("album") or {}
    thumbs = item.get("thumbnails") or []
    return {
        "videoId": item.get("videoId") or "",
        "title": item.get("title") or "",
        "artist": ", ".join(a.get("name", "") for a in artists if a.get("name")),
        "album": album.get("name") or "",
        "duration": item.get("duration") or "",
        "art": thumbs[-1].get("url") if thumbs else "",
    }


def main():
    if sys.argv[1:2] != ["liked"]:
        raise SystemExit("usage: vjmusic liked")

    limit = int(os.environ.get("VJMUSIC_LIMIT", "500"))

    from ytmusicapi import YTMusic

    jar, secret = cookies()

    api = YTMusic(
        auth=json.dumps(
            {
                "Cookie": jar,
                "Authorization": authorization(secret),
                "User-Agent": AGENT,
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "X-Goog-AuthUser": "0",
                "Origin": ORIGIN,
            }
        )
    )

    playlist = api.get_liked_songs(limit=limit)
    rows = [track(item) for item in playlist.get("tracks", [])]
    json.dump([row for row in rows if row["videoId"]], sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
