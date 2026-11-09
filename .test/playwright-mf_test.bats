#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/playwright-mf.sh"
}

@test "playwright-mf.sh is syntactically valid bash" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf.sh embeds no Apps Script URL" {
  run grep -c "script.google.com" "$SCRIPT"
  [ "$output" = "0" ]
}

@test "playwright-mf.sh reads the GAS URL from the external file" {
  run grep -F '$(cat ~/.config/playwright-mf/gas-url)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf.sh fetches cash flow by absolute --month" {
  run grep -F 'node cf.js --month' "$SCRIPT"
  [ "$status" -eq 0 ]
}
