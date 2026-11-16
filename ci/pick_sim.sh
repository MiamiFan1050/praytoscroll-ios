#!/bin/bash
# Prints the UDID of the best available 6.9" iPhone simulator (App Store screenshots need 1320x2868).
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys, re
d = json.load(sys.stdin)["devices"]
best = None
for rt, devs in d.items():
    if "iOS" not in rt:
        continue
    ver = tuple(int(x) for x in re.findall(r"\d+", rt.split("iOS")[-1])[:2])
    for dev in devs:
        name = dev["name"]
        if "Pro Max" in name and "iPhone" in name:
            m = re.search(r"iPhone (\d+)", name)
            gen = int(m.group(1)) if m else 0
            key = (gen >= 16, ver, gen)
            if best is None or key > best[0]:
                best = (key, dev["udid"], name, rt)
if not best:
    sys.exit("no Pro Max simulator")
print(best[1])
print(f"{best[2]} {best[3]}", file=sys.stderr)
'
