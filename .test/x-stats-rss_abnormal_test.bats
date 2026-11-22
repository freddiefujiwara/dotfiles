#!/usr/bin/env bats
# .test/x-stats-rss_abnormal_test.bats
#
# Abnormal-case tests for .bin/x-stats-rss.sh: a missing or deformed
# account object must fail cleanly with no partial output, and one
# deformed recent post must not kill the whole feed.
#
# Requirements: jq, python3 (XML well-formedness checks)

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-stats-rss.sh"
  OUT="$BATS_TEST_TMPDIR/out.xml"

  command -v jq >/dev/null 2>&1 || skip "jq is required"
  command -v python3 >/dev/null 2>&1 || skip "python3 is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

run_script() {
  local json="$1"
  STATUS=0
  bash "$SCRIPT" "$json" >"$OUT" 2>"$BATS_TEST_TMPDIR/err.txt" || STATUS=$?
}

assert_wellformed() {
  python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$1"
}

assert_no_forbidden_bytes() {
  python3 -c 'import sys; d = open(sys.argv[1], "rb").read(); bad = [b for b in d if b < 0x20 and b not in (9, 10, 13)]; sys.exit(1 if bad else 0)' "$1"
}

write_json() {
  cat >"$BATS_TEST_TMPDIR/$1"
}

@test "missing x object fails with no output at all" {
  write_json nox.json <<'JSON'
{"collected_at": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/nox.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "non-object x fails with no output at all" {
  write_json badx.json <<'JSON'
{"x": "a string", "collected_at": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/badx.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "malformed JSON fails with no output at all" {
  printf 'not json' >"$BATS_TEST_TMPDIR/bad.json"
  run_script "$BATS_TEST_TMPDIR/bad.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "null username does not crash the conversion" {
  write_json nulluser.json <<'JSON'
{"x": {"username": null, "followers": 10, "following": 5, "recent_posts": []},
 "collected_at": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/nulluser.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  ! grep -q 'null' "$OUT"
}

@test "non-object recent posts are skipped, valid posts still emitted" {
  write_json mixed.json <<'JSON'
{"x": {"username": "testuser", "followers": 10, "following": 5,
       "recent_posts": [
         42,
         null,
         {"id": "9", "text": "kept", "posted_at": "2026-01-01T00:00:00.000Z",
          "views": 3, "likes": null, "reposts": null, "replies": null}
       ]},
 "collected_at": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/mixed.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 1 ]
  grep -q 'kept' "$OUT"
  assert_wellformed "$OUT"
}

@test "numeric post id is rendered as text in link and guid" {
  write_json numid.json <<'JSON'
{"x": {"username": "testuser", "followers": 10, "following": 5,
       "recent_posts": [
         {"id": 987, "text": "hi", "posted_at": "2026-01-01T00:00:00.000Z",
          "views": 3, "likes": 1, "reposts": 0, "replies": 0}
       ]},
 "collected_at": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/numid.json"
  [ "$STATUS" -eq 0 ]
  grep -q 'https://twitter.com/testuser/status/987' "$OUT"
  grep -q '<guid isPermaLink="false">987</guid>' "$OUT"
  assert_wellformed "$OUT"
}

@test "C0 control characters in username and text cannot corrupt the XML" {
  jq -n --arg user $'us\x01er' --arg text $'x\x0by' \
    '{x: {username: $user, followers: 1, following: 2,
          recent_posts: [{id: "9", text: $text,
                          posted_at: "2026-01-01T00:00:00.000Z",
                          views: 1, likes: null, reposts: null, replies: null}]},
      collected_at: "2026-01-01T00:00:00Z"}' \
    >"$BATS_TEST_TMPDIR/ctrl.json"
  run_script "$BATS_TEST_TMPDIR/ctrl.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  assert_no_forbidden_bytes "$OUT"
}
