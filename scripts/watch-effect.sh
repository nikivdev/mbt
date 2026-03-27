#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-test}"
INTERVAL="${WATCH_INTERVAL:-0.2}"

sig_linux() {
  find lib/effect -type f -name "*.mbt" -print0 \
    | xargs -0 stat -c "%Y %s %n" 2>/dev/null \
    | sort
}

sig_macos() {
  find lib/effect -type f -name "*.mbt" -print0 \
    | xargs -0 stat -f "%m %z %N" 2>/dev/null \
    | sort
}

sig() {
  if stat -f "%m" . >/dev/null 2>&1; then
    sig_macos
  else
    sig_linux
  fi
}

run_cmd() {
  local cmd
  if [[ "$MODE" == "check" ]]; then
    cmd="moon check lib/effect"
  else
    cmd="moon test lib/effect"
  fi
  echo "$(date +%H:%M:%S) $cmd"
  ( $cmd )
}

last=""
while true; do
  current="$(sig)"
  if [[ "$current" != "$last" ]]; then
    run_cmd || true
    last="$current"
  fi
  sleep "$INTERVAL"
done
