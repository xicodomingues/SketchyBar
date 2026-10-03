#!/usr/bin/env python3
"""Time showing hidden items: the first show after a start vs. repeat shows.

usage: bench/first-show.py <probe-item> <item> [<item> ...] [-- key=value ...]

Sets drawing=on on the items in one call (plus any extra properties after `--`),
then polls `--query <probe-item>` until it reports an on-screen rect. Prints the
first show and two repeat shows in ms. Run it right after a restart, on items
that are hidden (drawing=off) at that point. ~10-15ms of each figure is the cost
of spawning the sketchybar CLI twice.
"""
import json, subprocess, sys, time

SB = "sketchybar"

def run(*args):
    return subprocess.run([SB, *args], capture_output=True, text=True).stdout

def show(items, probe, extra):
    args = []
    for name in items:
        args += ["--set", name, "drawing=on", *extra]
    start = time.perf_counter()
    run(*args)
    while time.perf_counter() - start < 5:
        rects = json.loads(run("--query", probe)).get("bounding_rects", {})
        if any(r["origin"][0] > -9000 and r["size"][0] > 0 for r in rects.values()):
            return (time.perf_counter() - start) * 1000
    return float("nan")

def hide(items):
    args = []
    for name in items:
        args += ["--set", name, "drawing=off"]
    run(*args)
    time.sleep(0.4)

argv = sys.argv[1:]
extra = []
if "--" in argv:
    split = argv.index("--")
    argv, extra = argv[:split], argv[split + 1:]
probe, items = argv[0], argv[1:]
times = []
for _ in range(3):
    times.append(show(items, probe, extra))
    hide(items)
print(f"{len(items)} item(s): first {times[0]:.0f}ms, repeat {times[1]:.0f}ms / {times[2]:.0f}ms")
