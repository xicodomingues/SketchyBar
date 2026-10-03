# Lazy item windows — benchmarks

Supporting data for the `lazy-item-windows` branch (one commit on top of v2.24.0).

## The problem

`bar_draw` calls `bar_item_get_window` before `bar_draws_item`, and that getter
creates the window when it is missing. Every item therefore owns a window on
every display, including items with `drawing=off` and items associated with a
different display; the unused ones are parked at (-9999, -9999).

Setting those windows up is expensive. While it happens the main thread sits in
SkyLight's `CGSWindowReloadCABackingStoreLayer` / `CGSWindowUpdateBackingStoreData`
blocks, each a synchronous `CA::Transaction::commit` waiting on the WindowServer
(`sample` shows ~93% of main-thread samples there), and the bar answers neither
`--query` nor `--trigger`. The cost grows faster than linearly with the window
count, and it is paid on every start, `--reload`, wake, and once per CG display
reconfiguration event (`bar_manager_display_changed` -> `bar_manager_reset`).

## The change

Create a window only on a bar that actually draws the item; a window that exists
is still kept and parked when its item stops being drawn. Items drawn on every
display are unaffected (see the second synthetic row).

## Environment

- MacBook (Mac17,2, Apple M5), macOS 26.6.2 (25G83)
- 3 displays: 5K external (main), built-in, 1080p external
- sketchybar v2.24.0: Homebrew build vs. this branch built with `make arm64`
- System load average 2.4-4.5 during the runs

## Method

"Ready" is the start of the first 2.5 s stretch in which every poll of
`--query bar` is answered with the full item count. One answered query is not
enough: the main thread can answer once and then block for seconds.

## Synthetic configs (`synthetic.sh`, 3 runs each)

Generated configs, run as a second instance next to the live bar. Reproducible
on any Mac with 2+ displays.

| scenario | items | windows stock | windows patched | cold start stock | cold start patched |
|---|---|---|---|---|---|
| 28 drawn on every display | 28 | 87 | 87 | 0.41s (0.41-1.14) | 0.65s (0.40-0.96) |
| 142 drawn on every display | 142 | 429 | 429 | 18.43s (18.40-18.48) | 17.78s (16.99-18.96) |
| 83 drawn on display 1 only | 83 | 252 | 86 | 4.38s (4.17-4.43) | 0.41s (0.40-0.63) |
| 83 on display 1 + 59 hidden | 142 | 429 | 86 | 13.46s (13.36-13.58) | 0.40s (0.40-0.63) |
| 142 hidden | 142 | 429 | 3 | 11.68s (11.18-11.96) | 0.16s (0.15-0.17) |

## Real config (142 items: AeroSpace workspace pills, most hidden or on one display)

Medians; ready additionally required a workspace pill to be back on its display
(`BENCH_PROBE`), i.e. the event scripts had run.

| | stock | patched | runs |
|---|---|---|---|
| windows | 429 | 122 at start, 108 after use | |
| cold start (`real-config.sh`) | 9.99s (9.84-10.36) | 0.73s (0.54-0.79) | 5 |
| `--reload` | 10.22s | 0.95s (0.51-0.97) | 5 |
| mirror a display into another (`display-change.sh`) | 16.29s (16.15-16.77) | 2.87s (2.79-3.04) | 3 |
| un-mirror it again | 50.96s (49.69-51.39) | 3.26s (3.07-3.48) | 3 |

The stock un-mirror time is not stable across sessions: two later runs took
25 s. The patched build was only measured in one session. One of the five stock
reloads returned in 1.24 s against 9.8-10.4 s for the rest; the median is unaffected.

## First show of a hidden item (`first-show.py`, 5 fresh starts each)

| | stock, first | patched, first | either, repeat |
|---|---|---|---|
| 1 item on 3 displays | 17 ms | 54 ms | 23-24 ms |
| 11 items on 1 display | 101 ms | 117 ms | 25-26 ms |

The patched build pays the window creation on first show, once per item per
display. About 10-15 ms of each figure is spawning the CLI twice.

## Behaviour checked on the patched build

Items land on the right display after each display change; hidden items appear
correctly the first time; clicks and mouse hover reach items; no windows are
created by mouse activity (`window-count.swift` before/after); nothing on stderr.

Not checked: popups, sliders, graphs, aliases, sleep/wake, long uptime.

Behaviour change: `--query <item>` no longer lists a `bounding_rects` entry for
displays the item is not drawn on (stock reports the parked window at -9999).

## Scripts

| script | measures |
|---|---|
| `synthetic.sh <binary> [runs]` | cold start on generated configs, isolated instance |
| `real-config.sh [runs]` | cold start and `--reload` of the running Homebrew service |
| `display-change.sh '<command>'` | unresponsive time after a display reconfiguration |
| `first-show.py <probe> <items...>` | first vs. repeat show of hidden items |
| `window-count.swift [owner]` | WindowServer windows owned by the process |
