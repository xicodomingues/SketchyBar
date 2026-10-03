# Shared helpers. Source this file; do not execute it.
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

now() { perl -MTime::HiRes=time -e 'printf "%.2f\n", time'; }
load() { sysctl -n vm.loadavg | awk '{print $2}'; }

# item_count <cli>: number of items the instance reports, empty if it does not answer.
item_count() {
  "$1" --query bar 2>/dev/null |
    python3 -c 'import sys,json;print(len(json.load(sys.stdin)["items"]))' 2>/dev/null
}

# With BENCH_PROBE=<item> set, "ready" additionally requires that item to be
# associated with a display. Use an item whose display a script assigns (e.g. a
# workspace indicator): after a display change the bar can answer queries well
# before its event scripts have run and re-placed such items.
probe_ok() {
  [ -z "${BENCH_PROBE:-}" ] && return 0
  local m
  m=$("$1" --query "$BENCH_PROBE" 2>/dev/null | grep -o '"associated_display_mask": *[0-9]*' | grep -o '[0-9]*$')
  [ -n "$m" ] && [ "$m" != 0 ]
}

# ready_after <cli> <min-items> [timeout-s]: seconds until the instance is responsive.
# "Responsive" = the start of the first 2.5s stretch in which EVERY poll is answered
# with at least <min-items> items. A single answered query is not enough: the main
# thread can answer one query and then block for seconds draining window updates.
ready_after() {
  local cli=$1 want=$2 limit=${3:-120} t0 ok="" el n
  t0=$(now)
  while :; do
    el=$(perl -e "printf '%.2f', $(now)-$t0")
    n=$(item_count "$cli")
    if [ -n "$n" ] && [ "$n" -ge "$want" ] && probe_ok "$cli"; then : "${ok:=$el}"; else ok=""; fi
    [ -n "$ok" ] && perl -e "exit(($el-$ok >= 2.5) ? 0 : 1)" && break
    perl -e "exit(($el > $limit) ? 0 : 1)" && { ok=nan; break; }
    sleep 0.1
  done
  echo "$ok"
}

# median v1 v2 ... -> "median (min-max)"
median() {
  python3 -c 'import sys,statistics as s; v=[float(x) for x in sys.argv[1:]]; print(f"{s.median(v):.2f}s ({min(v):.2f}-{max(v):.2f})")' "$@"
}

window_count() { swift "$BENCH_DIR/window-count.swift" "${1:-sketchybar}" 2>/dev/null | tail -1; }
