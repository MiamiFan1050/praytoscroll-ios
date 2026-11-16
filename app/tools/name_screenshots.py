#!/usr/bin/env python3
"""Copies xcresulttool-exported attachments to NN-name.png using manifest.json.
Usage: tools/name_screenshots.py <exported-dir> <out-dir>"""
import json, os, re, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
manifest = json.load(open(os.path.join(src, "manifest.json")))
count = 0
for test in manifest:
    for a in test.get("attachments", []):
        human = a.get("suggestedHumanReadableName", "")
        m = re.match(r"(\d\d-[a-z0-9-]+)", human)
        if not m:
            continue
        shutil.copy(os.path.join(src, a["exportedFileName"]), os.path.join(dst, m.group(1) + ".png"))
        count += 1
print(f"{count} screenshots -> {dst}")
