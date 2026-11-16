#!/usr/bin/env python3
"""Builds out/qa/crawl.md from the crawler's per-screen logs.
Uses $QA_DIR/crawl-NN-*.md when the test runner could write them, else the crawl-* attachments in the result bundle.
Usage: tools/qa_crawl_report.py <qa-dir> [<crawl.xcresult>]"""
import glob, json, os, re, subprocess, sys, tempfile

qa = sys.argv[1]
bundle = sys.argv[2] if len(sys.argv) > 2 else None
os.makedirs(qa, exist_ok=True)
parts = {}
for path in sorted(glob.glob(os.path.join(qa, "crawl-[0-9][0-9]-*.md"))):
    parts[os.path.basename(path)[:-3]] = open(path, encoding="utf-8").read()
if not parts and bundle and os.path.isdir(bundle):
    out = tempfile.mkdtemp()
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", out],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    manifest = os.path.join(out, "manifest.json")
    if os.path.exists(manifest):
        for test in json.load(open(manifest)):
            for a in test.get("attachments", []):
                m = re.match(r"(crawl-\d\d-[a-z0-9-]+)", a.get("suggestedHumanReadableName", ""))
                if m:
                    parts[m.group(1)] = open(os.path.join(out, a["exportedFileName"]), encoding="utf-8").read()
                    open(os.path.join(qa, m.group(1) + ".md"), "w", encoding="utf-8").write(parts[m.group(1)])
names = sorted(parts)
problems = sum(int(re.search(r"problems (\d+)", parts[n]).group(1)) for n in names if re.search(r"problems (\d+)", parts[n]))
tapped = sum(int(re.search(r"Tapped (\d+)", parts[n]).group(1)) for n in names if re.search(r"Tapped (\d+)", parts[n]))
head = ["# Pray to Scroll: QA crawl", "",
        f"{len(names)} screens · {tapped} controls tapped · {problems} problems", "",
        "Every enabled, hittable button, cell, switch and menu item on every tab and demo route, tapped once on the",
        "iPhone 17 Pro Max simulator (demo data, dark mode), then back to the screen. A problem = a crash, getting stuck,",
        "or an error alert. Destructive actions (erase, leave circle, report/block) are in DestructiveTests.", ""]
open(os.path.join(qa, "crawl.md"), "w", encoding="utf-8").write("\n".join(head) + "\n" + "\n".join(parts[n] for n in names))
print(f"crawl.md: {len(names)} screens, {tapped} taps, {problems} problems")
