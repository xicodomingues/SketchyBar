#!/usr/bin/env bash
# Cold-start and reload timing of the running bar with its real config.
#
# usage: bench/real-config.sh [runs=5]
#
# Restarts the Homebrew service for the cold-start
# samples, so run it against whichever build that service currently points at.
set -u
. "$(dirname "$0")/lib.sh"

RUNS=${1:-5}
CLI=$(command -v sketchybar)
# Homebrew's label is sh.brew.sketchybar (homebrew.mxcl.sketchybar on older brew).
SVC="gui/$(id -u)/$(launchctl list | awk '$3 ~ /\.sketchybar$/ {print $3; exit}')"
want=$(item_count "$CLI")
[ -n "$want" ] || { echo "sketchybar is not answering" >&2; exit 1; }

cold=(); reload=()
for ((i = 1; i <= RUNS; i++)); do
  sleep 2; launchctl kickstart -k "$SVC"; cold+=("$(ready_after "$CLI" "$want")")
done
for ((i = 1; i <= RUNS; i++)); do
  sleep 2; "$CLI" --reload; reload+=("$(ready_after "$CLI" "$want")")
done

echo "$("$CLI" --version), items: $want, windows: $(window_count), runs: $RUNS, load: $(load)"
echo "cold start: $(median "${cold[@]}")"
echo "--reload:   $(median "${reload[@]}")"
