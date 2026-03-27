#!/bin/bash
# Fast watch mode for MoonBit development
# Usage: ./scripts/watch.sh [package] [--test|--check]
#
# Examples:
#   ./scripts/watch.sh                    # Watch all, check only
#   ./scripts/watch.sh lib/effect --test  # Watch lib/effect, run tests
#   ./scripts/watch.sh . --test           # Watch all, run tests

set -e

PACKAGE="${1:-.}"
MODE="${2:---check}"
INTERVAL="${MBT_WATCH_INTERVAL:-0.2}"
TRACE="${MBT_TRACE_ENABLED:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# State
LAST_HASH=""
RUN_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Create marker file
MARKER="/tmp/mbt_watch_$$"
touch "$MARKER"
trap "rm -f $MARKER" EXIT

print_header() {
  clear
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  MoonBit Watch Mode${NC}"
  echo -e "${BLUE}  Package: ${YELLOW}$PACKAGE${NC}  Mode: ${YELLOW}$MODE${NC}"
  echo -e "${BLUE}  Runs: ${NC}$RUN_COUNT  ${GREEN}Pass: ${NC}$PASS_COUNT  ${RED}Fail: ${NC}$FAIL_COUNT"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

run_check() {
  local start=$(date +%s%N)

  if [ "$PACKAGE" = "." ]; then
    moon check --target native 2>&1
  else
    moon check "$PACKAGE" --target native 2>&1
  fi

  local status=$?
  local end=$(date +%s%N)
  local duration=$(( (end - start) / 1000000 ))

  echo ""
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}✓ Check passed${NC} (${duration}ms)"
    return 0
  else
    echo -e "${RED}✗ Check failed${NC} (${duration}ms)"
    return 1
  fi
}

run_test() {
  local start=$(date +%s%N)

  if [ "$PACKAGE" = "." ]; then
    moon test --target native 2>&1
  else
    moon test "$PACKAGE" --target native 2>&1
  fi

  local status=$?
  local end=$(date +%s%N)
  local duration=$(( (end - start) / 1000000 ))

  echo ""
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}✓ Tests passed${NC} (${duration}ms)"
    return 0
  else
    echo -e "${RED}✗ Tests failed${NC} (${duration}ms)"
    return 1
  fi
}

run_cycle() {
  RUN_COUNT=$((RUN_COUNT + 1))
  print_header

  local timestamp=$(date '+%H:%M:%S')
  echo -e "${YELLOW}[$timestamp]${NC} Change detected, running..."
  echo ""

  local success=true

  # Always run check
  if ! run_check; then
    success=false
  fi

  # Run tests if requested and check passed
  if [ "$MODE" = "--test" ] && [ "$success" = true ]; then
    echo ""
    if ! run_test; then
      success=false
    fi
  fi

  echo ""
  if [ "$success" = true ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  SUCCESS${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  fi

  echo ""
  echo -e "${BLUE}Watching for changes... (Ctrl+C to exit)${NC}"
}

# Initial run
run_cycle

# Watch loop
while true; do
  # Find changed .mbt files since marker
  if [ "$PACKAGE" = "." ]; then
    CHANGES=$(find . -name "*.mbt" -newer "$MARKER" 2>/dev/null | head -5)
  else
    CHANGES=$(find "$PACKAGE" -name "*.mbt" -newer "$MARKER" 2>/dev/null | head -5)
  fi

  if [ -n "$CHANGES" ]; then
    touch "$MARKER"
    run_cycle
  fi

  sleep "$INTERVAL"
done
