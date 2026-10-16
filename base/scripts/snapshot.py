#!/usr/bin/env python3
"""Turn a plist from "defaults export" into stable JSON text without the ignored keys.

usage: defaults export <domain> - | snapshot.py <domain> <ignore.conf>
"""
import datetime
import hashlib
import json
import plistlib
import re
import sys


def load_ignore(path, domain):
    patterns = []
    try:
        with open(path, encoding="utf-8") as f:
            for raw in f:
                line = re.sub(r"(^|\s+)#.*$", "", raw).strip()
                if not line:
                    continue
                parts = line.split(None, 1)
                if len(parts) != 2:
                    continue
                dom, pattern = parts
                if dom in ("*", domain):
                    patterns.append(re.compile(pattern))
    except FileNotFoundError:
        pass
    return patterns


def normalize(obj):
    if isinstance(obj, dict):
        return {str(k): normalize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [normalize(v) for v in obj]
    if isinstance(obj, bytes):
        return "<data %d bytes sha1=%s>" % (len(obj), hashlib.sha1(obj).hexdigest()[:12])
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    if isinstance(obj, plistlib.UID):
        return "<uid %d>" % obj.data
    return obj


def main():
    domain, ignore_path = sys.argv[1], sys.argv[2]
    patterns = load_ignore(ignore_path, domain)
    raw = sys.stdin.buffer.read()
    data = plistlib.loads(raw) if raw.strip() else {}
    if not isinstance(data, dict):
        data = {"<root>": data}
    kept = {k: v for k, v in data.items() if not any(p.fullmatch(k) for p in patterns)}
    json.dump(normalize(kept), sys.stdout, indent=2, sort_keys=True, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
