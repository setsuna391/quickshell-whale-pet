#!/usr/bin/env python3
"""Atomically persist a menu setting without replacing managed symlinks."""
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in {"model", "scale", "sound", "reminders", "humming"}:
        return
    path = Path.home() / ".config/dsh-pet/config.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path.parent / ".config.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if path.is_symlink():
            return
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            data = {}
        if not isinstance(data, dict):
            return
        data[sys.argv[1]] = json.loads(sys.argv[2])
        mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
        fd, name = tempfile.mkstemp(prefix=".config-", dir=path.parent)
        try:
            os.fchmod(fd, mode)
            with os.fdopen(fd, "w", encoding="utf-8") as out:
                json.dump(data, out, ensure_ascii=False)
            os.replace(name, path)
        finally:
            if os.path.exists(name):
                os.unlink(name)


if __name__ == "__main__":
    main()
