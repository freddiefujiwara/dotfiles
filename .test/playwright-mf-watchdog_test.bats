#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/playwright-mf-watchdog.sh"
}

@test "playwright-mf-watchdog.sh is syntactically valid bash" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf-watchdog.sh checks the monthly archives" {
  run grep -F 'mfcf.$ym.xml' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf-watchdog.sh verifies pubDate months" {
  run grep -F '<pubDate>' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf-watchdog.sh checks a 13-month window" {
  run grep -F 'for i in 0 1 2 3 4 5 6 7 8 9 10 11 12' "$SCRIPT"
  [ "$status" -eq 0 ]
}
