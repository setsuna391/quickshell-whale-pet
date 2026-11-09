#!/usr/bin/env python3
"""Select a lyric line for the currently playing MPRIS track."""
import hashlib
import json
import os
from pathlib import Path
import random
import re
import sys
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def select_line(data, position):
    synced = []
    for line in (data.get("syncedLyrics") or "").splitlines():
        match = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*?)\s*$", line)
        if match and match.group(3):
            synced.append((int(match.group(1)) * 60 + float(match.group(2)), match.group(3)))
    if synced:
        previous = [item for item in synced if item[0] <= position]
        return max(previous, default=(0, ""), key=lambda item: item[0])[1]
    lines = [line.strip() for line in (data.get("plainLyrics") or "").splitlines() if line.strip()]
    return random.choice(lines) if lines else ""


def netease_song_matches(song, artist, title):
    normalize = lambda value: str(value).strip().casefold()
    requested = {normalize(name) for name in re.split(r"[,，、/]", artist) if name.strip()}
    found = {normalize(item.get("name", "")) for item in song.get("artists", []) if isinstance(item, dict)}
    return normalize(song.get("name", "")) == normalize(title) and bool(requested) and requested <= found


def netease_lyrics(artist, title):
    headers = {"User-Agent": "Mozilla/5.0", "Referer": "https://music.163.com/"}
    query = urlencode({"s": title + " " + artist, "type": 1, "limit": 20})
    with urlopen(Request("https://music.163.com/api/search/get/web?" + query, headers=headers), timeout=6) as response:
        result = json.loads(response.read(1024 * 1024).decode("utf-8"))
    songs = result.get("result", {}).get("songs", [])
    song = next((item for item in songs if isinstance(item, dict) and netease_song_matches(item, artist, title)), None)
    if not song or not isinstance(song.get("id"), int):
        return {}
    query = urlencode({"id": song["id"], "lv": 1, "tv": -1})
    with urlopen(Request("https://music.163.com/api/song/lyric?" + query, headers=headers), timeout=6) as response:
        result = json.loads(response.read(1024 * 1024).decode("utf-8"))
    return {"syncedLyrics": (result.get("lrc") or {}).get("lyric")}


def lyrics_for(artist, title):
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "dsh-pet"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = hashlib.sha256((artist + "\0" + title).encode()).hexdigest()
    path = cache / (key + ".json")
    try:
        age = time.time() - path.stat().st_mtime
        if age < 86400:
            cached = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(cached, dict) and (cached.get("syncedLyrics") or cached.get("plainLyrics") or age < 300):
                return cached
    except (OSError, ValueError):
        pass
    query = urlencode({"artist_name": artist, "track_name": title})
    headers = {"User-Agent": "DSH-Pet/1.1 (https://github.com/setsuna391/quickshell-whale-pet)"}
    try:
        with urlopen(Request("https://lrclib.net/api/get?" + query, headers=headers), timeout=6) as response:
            data = json.loads(response.read(1024 * 1024).decode("utf-8"))
    except (OSError, ValueError):
        data = {}
    if not isinstance(data, dict):
        data = {}
    if not data.get("syncedLyrics") and not data.get("plainLyrics"):
        try:
            data = netease_lyrics(artist, title)
        except (OSError, ValueError, TypeError, KeyError, AttributeError):
            data = {}
    try:
        path.write_text(json.dumps({"syncedLyrics": data.get("syncedLyrics"),
                                    "plainLyrics": data.get("plainLyrics")}), encoding="utf-8")
        path.chmod(0o600)
    except OSError:
        pass
    return data


def main():
    try:
        data = lyrics_for(sys.argv[1], sys.argv[2]) if len(sys.argv) == 3 else {}
        print(json.dumps({"syncedLyrics": data.get("syncedLyrics"),
                          "plainLyrics": data.get("plainLyrics")}, ensure_ascii=False))
    except (OSError, ValueError, TypeError):
        print("{}")


if __name__ == "__main__":
    main()
