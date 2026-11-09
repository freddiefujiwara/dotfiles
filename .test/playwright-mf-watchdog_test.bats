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
