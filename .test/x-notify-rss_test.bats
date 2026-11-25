#!/usr/bin/env bats
# .test/x-notify-rss.bats
#
# Assumes:
#   - script:   .bin/x-notify-rss.sh
#   - fixture:  .test/x-notify-rss.json
#
# Run:
#   bats .test/x-notify-rss.bats
#
# Requirements:
#   - jq

setup() {
  # Resolve repo root as the parent of .test/
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-notify-rss.sh"
  FIXTURE="$BATS_TEST_DIRNAME/x-notify-rss_test.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

@test "prints valid RSS root elements" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *'<?xml version="1.0" encoding="UTF-8" ?>'* ]]
  [[ "$output" == *'<rss version="2.0" xmlns:xn="https://freddiefujiwara.com/ns/x-notify">'* ]]
  [[ "$output" == *'<channel>'* ]]
  [[ "$output" == *'</channel>'* ]]
  [[ "$output" == *'</rss>'* ]]
}

@test "emits one <item> per notification with a tweet" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Count occurrences of "<item>"
  count="$(printf "%s" "$output" | grep -c '<item>')"

  # Count notifications with non-null tweets in JSON
  expected="$(jq 'map(select(.tweet != null)) | length' "$FIXTURE")"

  [ "$count" -eq "$expected" ]
}

@test "items contain correct data" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Test Case 1: Standard notification
  [[ "$output" == *"<title><![CDATA[Alice (@alice) - like]]></title>"* ]]
  [[ "$output" == *"<link>https://twitter.com/testuser/status/12345</link>"* ]]
  [[ "$output" == *"<description><![CDATA[Hello world!]]></description>"* ]]
  [[ "$output" == *"<guid isPermaLink=\"false\">x-notify-like-12345</guid>"* ]]

  # Test Case 2: Notification with newlines in text
  [[ "$output" == *"<description><![CDATA[Another tweet for testing purposes.\\nIt has newlines.]]></description>"* ]]
  [[ "$output" == *"<guid isPermaLink=\"false\">x-notify-retweet-67890</guid>"* ]]

  # Test Case 3: Fallback for missing actor info
  [[ "$output" == *"<title><![CDATA[Unknown (@unknown) - like]]></title>"* ]]
  [[ "$output" == *"<guid isPermaLink=\"false\">x-notify-like-11223</guid>"* ]]
}

@test "guid is built from kind and tweet id, not the notification entry id or the actor" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" != *">notif_1</guid>"* ]]
  [[ "$output" != *">notif_3</guid>"* ]]
  [[ "$output" != *">notif_4</guid>"* ]]
  [[ "$output" != *">notif_5</guid>"* ]]
}

@test "pubDate converts Twitter-format dates to RFC 822 and passes other formats through" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  # Twitter format (as delivered by the X API) is converted
  [[ "$output" == *"<pubDate>Wed, 10 Oct 2018 20:19:24 +0000</pubDate>"* ]]
  # Non-Twitter formats are passed through unchanged (no error text)
  [[ "$output" == *"<pubDate>2024-01-01T00:00:00Z</pubDate>"* ]]
  [[ "$output" != *"does not match format"* ]]
}

@test "items carry the xn extension elements" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Test Case 1: kind / actor / tweet-id / message for a standard notification
  [[ "$output" == *"<xn:kind>like</xn:kind>"* ]]
  [[ "$output" == *"<xn:actor username=\"alice\">Alice</xn:actor>"* ]]
  [[ "$output" == *"<xn:tweet-id>12345</xn:tweet-id>"* ]]
  [[ "$output" == *"<xn:message>Alice liked your post</xn:message>"* ]]

  # Test Case 6: every actor is repeated as its own element
  [[ "$output" == *"<xn:kind>reply</xn:kind>"* ]]
  [[ "$output" == *"<xn:actor username=\"erin\">Erin</xn:actor>"* ]]
  [[ "$output" == *"<xn:actor username=\"frank\">Frank</xn:actor>"* ]]
  [[ "$output" == *"<xn:tweet-id>55555</xn:tweet-id>"* ]]
  [[ "$output" == *"<xn:message>Erin and Frank replied to your post</xn:message>"* ]]

  # Test Case 4: missing actor info falls back like the legacy elements
  [[ "$output" == *"<xn:actor username=\"unknown\">Unknown</xn:actor>"* ]]
}

@test "works when reading JSON from stdin" {
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' /dev/stdin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<rss version=\"2.0\" xmlns:xn=\"https://freddiefujiwara.com/ns/x-notify\">"* ]]
}
