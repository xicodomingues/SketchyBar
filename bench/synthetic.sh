#!/usr/bin/env bash
# Cold-start benchmark on generated configs, isolated from any running bar.
#
# usage: bench/synthetic.sh <path-to-sketchybar-binary> [runs=3]
#
# The binary is copied under another name, so it gets its own mach service and
# runs next to a live sketchybar without touching it (an extra, transparent bar
# appears at the bottom of each display while a scenario runs). Each scenario is
# one batched `--add/--set` call, so the cost measured is window setup, not config
# parsing. Run it with 2+ displays connected: with one display there are no
# "other display" windows to save.
set -u
. "$(dirname "$0")/lib.sh"

BIN=${1:?usage: synthetic.sh <sketchybar-binary> [runs]}
RUNS=${2:-3}
NAME=sbbench
WORK=$(mktemp -d)
cp "$BIN" "$WORK/$NAME"
CLI="$WORK/$NAME"
trap 'pkill -x "$NAME" 2>/dev/null; rm -rf "$WORK"' EXIT

# scenario <file> <drawn> <display-for-drawn or ""> <hidden>
scenario() {
  {
    echo '#!/bin/bash'
    echo "a=(--bar position=bottom height=18 color=0x00000000)"
    echo "for ((i = 1; i <= $2; i++)); do a+=(--add item d\$i left --set d\$i label=\$i label.font='Menlo:Regular:9.0' ${3:+display=$3}); done"
    echo "for ((i = 1; i <= $4; i++)); do a+=(--add item h\$i left --set h\$i label=\$i drawing=off); done"
    echo "\"$CLI\" \"\${a[@]}\""
  } > "$1"
  chmod +x "$1"
}

run() { # <label> <drawn> <display> <hidden>
  local cfg="$WORK/rc" times=() wins="" i pid
  scenario "$cfg" "$2" "$3" "$4"
  for ((i = 1; i <= RUNS; i++)); do
    "$CLI" --config "$cfg" >/dev/null 2>&1 &
    pid=$!
    times+=("$(ready_after "$CLI" $(($2 + $4)))")
    wins=$(window_count "$NAME")
    kill "$pid"; wait "$pid" 2>/dev/null
    sleep 1.5
  done
  printf '| %s | %s | %s | %s |\n' "$1" "$(($2 + $4))" "$wins" "$(median "${times[@]}")"
}

echo "binary: $BIN ($("$BIN" --version 2>&1)), displays: $(system_profiler SPDisplaysDataType 2>/dev/null | grep -c Resolution), runs: $RUNS, load: $(load)"
echo "| scenario | items | windows | cold start, median (min-max) |"
echo "|---|---|---|---|"
run "28 drawn on every display"            28  ""  0
run "142 drawn on every display"           142 ""  0
run "83 drawn on display 1 only"           83  1   0
run "83 on display 1 + 59 hidden"          83  1   59
run "142 hidden"                           0   ""  142
