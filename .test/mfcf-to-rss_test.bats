#!/usr/bin/env bats
# .test/mfcf-to-rss_test.bats
#
# Assumes:
#   - script:   .bin/mfcf-to-rss.sh
#   - fixture:  .test/mfcf-to-rss_test.json
#
# Run:
#   bats .test/mfcf-to-rss_test.bats
#
# Requirements:
#   - jq

setup() {
  # Resolve repo root as the parent of .test/
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/mfcf-to-rss.sh"
  FIXTURE="$BATS_TEST_DIRNAME/mfcf-to-rss_test.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

@test "prints valid RSS root elements" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *'<?xml version="1.0" encoding="UTF-8"?>'* ]]
  [[ "$output" == *'<rss version="2.0">'* ]]
  [[ "$output" == *'<channel>'* ]]
  [[ "$output" == *'</channel>'* ]]
  [[ "$output" == *'</rss>'* ]]
}

@test "includes default channel metadata when env vars are not set" {
  unset CHANNEL_TITLE CHANNEL_LINK CHANNEL_DESC

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  [[ "$output" == *"<title>Transactions Feed</title>"* ]]
  [[ "$output" == *"<link>https://example.invalid/transactions</link>"* ]]
  [[ "$output" == *"<description>Converted from JSON transactions</description>"* ]]
}

@test "channel metadata can be overridden via env vars" {
  CHANNEL_TITLE="My Feed" \
  CHANNEL_LINK="https://example.com/feed.xml" \
  CHANNEL_DESC="Hello" \
  run bash "$SCRIPT" "$FIXTURE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"<title>My Feed</title>"* ]]
  [[ "$output" == *"<link>https://example.com/feed.xml</link>"* ]]
  [[ "$output" == *"<description>Hello</description>"* ]]
}

@test "emits one <item> per transaction" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  count="$(printf "%s" "$output" | grep -c '<item>')"
  expected="$(jq '.transactions | length' "$FIXTURE")"

  [ "$count" -eq "$expected" ]
}

@test "formats positive and negative amounts in item titles" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  [[ "$output" == *"01/23(金) +¥61,000 振込 サンプル タロウ"* ]] || \
  [[ "$output" == *"01/23(金) +¥61000 振込 サンプル タロウ"* ]]
  [[ "$output" == *"01/24(土) -¥550 コンビニ"* ]]
}

@test "omits amount when amount_yen is null" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  [[ "$output" == *"<title>01/25(日) 貯金</title>"* ]]
}

@test "works when reading JSON from stdin" {
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' /dev/stdin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<rss version=\"2.0\">"* ]]
}
