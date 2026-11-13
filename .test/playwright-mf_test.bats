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

@test "playwright-mf.sh reads the account list from the external file" {
  run grep -F 'config/playwright-mf/accounts' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf.sh embeds no account names" {
  run grep -F "node accounts-update.js '" "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "playwright-mf.sh fetches cash flow by absolute --month" {
  run grep -F 'node cf.js --month' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf.sh fetches a 13-month window" {
  run grep -F 'for i in 1 2 3 4 5 6 7 8 9 10 11 12' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "playwright-mf.sh prunes months older than the 13-month window" {
  run grep -F "date -d '12 months ago'" "$SCRIPT"
  [ "$status" -eq 0 ]
}
