#!/usr/bin/env bats
# .test/x-stats-rss_test.bats
#
# Assumes:
#   - script:   .bin/x-stats-rss.sh
#   - fixture:  .test/x-stats-rss_test.json
#
# Requirements:
#   - jq

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-stats-rss.sh"
  FIXTURE="$BATS_TEST_DIRNAME/x-stats-rss_test.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

@test "prints valid RSS root elements with the xs namespace" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *'<?xml version="1.0" encoding="UTF-8" ?>'* ]]
  [[ "$output" == *'<rss version="2.0" xmlns:xs="https://freddiefujiwara.com/ns/x-stats">'* ]]
  [[ "$output" == *'<channel>'* ]]
  [[ "$output" == *'</channel>'* ]]
  [[ "$output" == *'</rss>'* ]]
}

@test "channel carries account info and xs channel extensions" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<title>X Stats (@testuser)</title>"* ]]
  [[ "$output" == *"<link>https://twitter.com/testuser</link>"* ]]
  [[ "$output" == *"<xs:username>testuser</xs:username>"* ]]
  [[ "$output" == *"<xs:followers>1842</xs:followers>"* ]]
  [[ "$output" == *"<xs:following>836</xs:following>"* ]]
  [[ "$output" == *"<xs:collected-at>2026-11-18T19:16:48.915Z</xs:collected-at>"* ]]
}

@test "emits one <item> per recent post" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  count="$(printf "%s" "$output" | grep -c '<item>')"
  expected="$(jq '.x.recent_posts | length' "$FIXTURE")"
  [ "$count" -eq "$expected" ]
}

@test "items contain correct data" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<title><![CDATA[First post]]></title>"* ]]
  [[ "$output" == *"<link>https://twitter.com/testuser/status/111</link>"* ]]
  [[ "$output" == *"<description><![CDATA[First post]]></description>"* ]]
  [[ "$output" == *"<guid isPermaLink=\"false\">111</guid>"* ]]
  # ISO 8601 posted_at is converted to RFC 822
  [[ "$output" == *"<pubDate>Wed, 18 Nov 2026 12:51:28 +0000</pubDate>"* ]]
  [[ "$output" == *"<pubDate>Tue, 17 Nov 2026 08:47:02 +0000</pubDate>"* ]]
}

@test "metrics are emitted when present, including zero" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<xs:views>89</xs:views>"* ]]
  [[ "$output" == *"<xs:likes>1</xs:likes>"* ]]
  [[ "$output" == *"<xs:reposts>0</xs:reposts>"* ]]
  [[ "$output" == *"<xs:replies>0</xs:replies>"* ]]
}

@test "null metrics are omitted entirely, not zeroed" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  # Post 222 has views=null and reposts=null: only one views and one
  # reposts element may appear in the whole feed that belongs to it.
  # Count all views elements: posts 111 and 333 have views, 222 does not.
  views_count="$(printf "%s" "$output" | grep -c '<xs:views>')"
  [ "$views_count" -eq 2 ]
  reposts_count="$(printf "%s" "$output" | grep -c '<xs:reposts>')"
  [ "$reposts_count" -eq 2 ]
  [[ "$output" != *"<xs:views>null</xs:views>"* ]]
}

@test "works when reading JSON from stdin" {
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' /dev/stdin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<rss version=\"2.0\" xmlns:xs=\"https://freddiefujiwara.com/ns/x-stats\">"* ]]
  [[ "$output" == *"<xs:followers>1842</xs:followers>"* ]]
}
