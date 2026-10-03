#!/usr/bin/env bash
# Time how long the bar stays unresponsive after a display reconfiguration.
#
# usage: bench/display-change.sh '<command that changes the display layout>' [timeout-s]
#   e.g. bench/display-change.sh 'displayplacer "id:A+B res:1512x982 ..."'
#
# Any command that fires CG display reconfiguration callbacks works (mirroring
# two displays and un-mirroring them is an easy reversible pair). The sketchybar
# PID is printed before and after to show the process was not restarted.
set -u
. "$(dirname "$0")/lib.sh"

CMD=${1:?usage: display-change.sh '<command>' [timeout-s]}
CLI=$(command -v sketchybar)
want=$(item_count "$CLI")
pid=$(pgrep -x sketchybar)
t0=$(now)
bash -c "$CMD" >/dev/null 2>&1
cmd_s=$(perl -e "printf '%.2f', $(now)-$t0")
bar_s=$(ready_after "$CLI" "$want" "${2:-120}")
echo "command ${cmd_s}s + bar unresponsive ${bar_s}s (pid $pid -> $(pgrep -x sketchybar), windows $(window_count), load $(load))"
