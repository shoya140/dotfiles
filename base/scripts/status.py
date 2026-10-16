#!/usr/bin/env python3
"""Read the JSON of a mise bootstrap status command on stdin and print what check needs.

usage: mise bootstrap packages status --json | status.py declared <manager>
           declared package names of brew, brew-cask or mas
       mise bootstrap macos defaults status --json | status.py domains
           host<TAB>domain of every declared macOS default
"""
import json
import sys


def declared(status, manager):
    for package in (status.get(manager) or {}).get("packages", []):
        print(package["package"].rsplit("/", 1)[-1])


def domains(status):
    seen = set()
    for entry in (status.get("macos_defaults") or {}).get("entries", []):
        key = (entry.get("host") or "any", entry["domain"])
        if key not in seen:
            seen.add(key)
            print(f"{key[0]}\t{key[1]}")


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "declared":
        declared(json.load(sys.stdin), args[1])
    elif args == ["domains"]:
        domains(json.load(sys.stdin))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
