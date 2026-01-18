#!/usr/bin/env bats
# .test/x-to-rss.bats
#
# Assumes:
#   - script:   .bin/x-to-rss.sh
#   - fixture:  .test/x-to-rss.json
#
# Run:
#   bats .test/x-to-rss.bats
#
# Requirements:
#   - jq

setup() {
  # Resolve repo root as the parent of .test/
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-to-rss.sh"
  FIXTURE="$BATS_TEST_DIRNAME/x-to-rss.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

@test "prints valid RSS root elements" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *'<?xml version="1.0" encoding="UTF-8"?>'* ]]
  [[ "$output" == *'<rss version="2.0"'* ]]
  [[ "$output" == *'<channel>'* ]]
  [[ "$output" == *'</channel>'* ]]
  [[ "$output" == *'</rss>'* ]]
}

@test "includes default channel metadata when env vars are not set" {
  unset FEED_TITLE FEED_LINK FEED_DESC

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Extract the first <title> inside <channel> ... </channel>
  channel_title="$(
    printf "%s" "$output" |
      awk '
        /<channel>/{inside=1}
        inside && /<title>/{
          line=$0
          sub(/.*<title>/, "", line)
          sub(/<\/title>.*/, "", line)
          print line
          exit
        }
        /<\/channel>/{inside=0}
      '
  )"

  [ -n "$channel_title" ]

  [[ "$output" == *"<link>"*"</link>"* ]]
  [[ "$output" == *"<description>"*"</description>"* ]]
  [[ "$output" == *"<language>"*"</language>"* ]]
}

@test "channel metadata can be overridden via env vars" {
  FEED_TITLE="My Feed" \
  FEED_LINK="https://example.com/feed.xml" \
  FEED_DESC="Hello" \
  run bash "$SCRIPT" "$FIXTURE"

  [ "$status" -eq 0 ]
  [[ "$output" == *"<title>My Feed</title>"* ]]
  [[ "$output" == *"<link>https://example.com/feed.xml</link>"* ]]
  [[ "$output" == *"<description>Hello</description>"* ]]
}

@test "emits one <item> per tweet" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Count occurrences of "<item>"
  count="$(printf "%s" "$output" | grep -c '<item>')"

  # Count tweets in JSON
  expected="$(jq '.tweets | length' "$FIXTURE")"

  [ "$count" -eq "$expected" ]
}

@test "items contain link/guid based on username and id" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Validate a few items derived from fixture JSON
  # (Works even if fixture changes order)
  while IFS=$'\t' read -r id user; do
    link="https://x.com/${user}/status/${id}"
    [[ "$output" == *"<link>${link}</link>"* ]]
    [[ "$output" == *"<guid isPermaLink=\"true\">${link}</guid>"* ]]
  done < <(jq -r '.tweets[] | [.id, .author.username] | @tsv' "$FIXTURE" | head -n 5)
}

@test "tweet text newlines become <br/> in encoded content" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Pick first tweet that contains a newline and ensure it appears as <br/>
  nl_text="$(jq -r '.tweets[].text | select(test("\n"))' "$FIXTURE" | head -n 1)"
  if [[ -z "$nl_text" ]]; then
    skip "fixture has no tweet text with newline"
  fi

  # Convert the same way (newline -> <br/>), then ensure output contains it
  expected="$(printf "%s" "$nl_text" | sed 's/$/<br\/>/; :a;N;$!ba;s/\n/<br\/>/g')"
  [[ "$output" == *"$expected"* ]]
}

@test "tweets are sorted by createdAt descending (newest first)" {
  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]

  # Determine expected newest and oldest tweet ids by createdAt lexicographic (Twitter format is consistent)
  newest_id="$(jq -r '.tweets | sort_by(.createdAt) | last | .id' "$FIXTURE")"
  oldest_id="$(jq -r '.tweets | sort_by(.createdAt) | first | .id' "$FIXTURE")"

  newest_line="$(printf "%s" "$output" | grep -n "status/${newest_id}" | head -n 1 | cut -d: -f1)"
  oldest_line="$(printf "%s" "$output" | grep -n "status/${oldest_id}" | head -n 1 | cut -d: -f1)"

  # newest should appear earlier (smaller line number)
  [ "$newest_line" -lt "$oldest_line" ]
}

@test "works when reading JSON from stdin" {
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' /dev/stdin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<rss version=\"2.0\""* ]]
}
