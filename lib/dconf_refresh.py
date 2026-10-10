#!/usr/bin/env python3
"""Refresh the values in a dconf keyfile from the running system.

Only keys already in the file are touched. Comments, order and sections
stay as they are. A key that is now at its default (dconf read prints
nothing) keeps its old value and is reported.
"""
import subprocess
import sys

path = sys.argv[1]
out = []
section = None
with open(path) as f:
    for line in f:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1]
        elif section and s and not s.startswith("#") and "=" in s:
            key = s.split("=", 1)[0]
            value = subprocess.run(
                ["dconf", "read", f"/{section}/{key}"],
                capture_output=True, text=True, check=True,
            ).stdout.strip()
            if value:
                line = f"{key}={value}\n"
            else:
                print(f"  at default, kept old value: /{section}/{key}", file=sys.stderr)
        out.append(line)

with open(path, "w") as f:
    f.writelines(out)
