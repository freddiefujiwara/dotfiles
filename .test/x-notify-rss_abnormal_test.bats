#!/usr/bin/env bats
# .test/x-notify-rss_abnormal_test.bats
#
# Abnormal-case and invariant tests for .bin/x-notify-rss.sh:
# one deformed notification must not kill or corrupt the whole feed,
# structurally invalid input must fail with no partial output, and
# item guids (kind + actor + tweet id) must be stable across runs.
#
# Requirements: jq, python3 (XML well-formedness checks)

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-notify-rss.sh"
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

@test "malformed JSON fails with no output at all" {
  printf 'this is not json' >"$BATS_TEST_TMPDIR/bad.json"
  run_script "$BATS_TEST_TMPDIR/bad.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "top-level object instead of an array fails with no output at all" {
  write_json obj.json <<'JSON'
{"notifications": []}
JSON
  run_script "$BATS_TEST_TMPDIR/obj.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "non-object entries and non-object tweets are skipped" {
  write_json mixed.json <<'JSON'
[
  5,
  "a string",
  null,
  {"kind": "like", "actors": [], "tweet": "not an object"},
  {"kind": "like",
   "actors": [{"name": "Alice", "username": "alice"}],
   "tweet": {"id": "111", "text": "hi",
             "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
             "author": {"username": "bob"}}}
]
JSON
  run_script "$BATS_TEST_TMPDIR/mixed.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 1 ]
  grep -q 'x-notify-like-alice-111' "$OUT"
  assert_wellformed "$OUT"
}

@test "null tweet text becomes an empty description, not a failed feed" {
  write_json nulltext.json <<'JSON'
[{"kind": "like",
  "actors": [{"name": "Alice", "username": "alice"}],
  "tweet": {"id": "111", "text": null,
            "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
            "author": {"username": "bob"}}}]
JSON
  run_script "$BATS_TEST_TMPDIR/nulltext.json"
  [ "$STATUS" -eq 0 ]
  grep -q '<description><!\[CDATA\[\]\]></description>' "$OUT"
  assert_wellformed "$OUT"
}

@test "numeric tweet id is rendered as text in link and guid" {
  write_json numid.json <<'JSON'
[{"kind": "like",
  "actors": [{"name": "Alice", "username": "alice"}],
  "tweet": {"id": 12345, "text": "hi",
            "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
            "author": {"username": "bob"}}}]
JSON
  run_script "$BATS_TEST_TMPDIR/numid.json"
  [ "$STATUS" -eq 0 ]
  grep -q 'https://twitter.com/bob/status/12345' "$OUT"
  grep -q 'x-notify-like-alice-12345' "$OUT"
  assert_wellformed "$OUT"
}

@test "non-array actors fall back to the unknown actor" {
  write_json badactors.json <<'JSON'
[{"kind": "like",
  "actors": "alice",
  "tweet": {"id": "111", "text": "hi",
            "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
            "author": {"username": "bob"}}}]
JSON
  run_script "$BATS_TEST_TMPDIR/badactors.json"
  [ "$STATUS" -eq 0 ]
  grep -q 'x-notify-like-unknown-111' "$OUT"
  assert_wellformed "$OUT"
}

@test "C0 control characters and CDATA terminators in text cannot corrupt the XML" {
  jq -n --arg text $'x\x01y \x0bvt and ]]> end' --arg name $'A\x02lice' \
    '[{kind: "like",
       actors: [{name: $name, username: "alice"}],
       tweet: {id: "111", text: $text,
               createdAt: "Wed Oct 10 20:19:24 +0000 2018",
               author: {username: "bob"}}}]' \
    >"$BATS_TEST_TMPDIR/ctrl.json"
  run_script "$BATS_TEST_TMPDIR/ctrl.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  assert_no_forbidden_bytes "$OUT"
}

@test "guids are identical across two runs of the same input" {
  run_script "$BATS_TEST_DIRNAME/x-notify-rss_test.json"
  [ "$STATUS" -eq 0 ]
  grep -o '<guid isPermaLink="false">[^<]*</guid>' "$OUT" >"$BATS_TEST_TMPDIR/guids1.txt"
  run_script "$BATS_TEST_DIRNAME/x-notify-rss_test.json"
  [ "$STATUS" -eq 0 ]
  grep -o '<guid isPermaLink="false">[^<]*</guid>' "$OUT" >"$BATS_TEST_TMPDIR/guids2.txt"
  cmp "$BATS_TEST_TMPDIR/guids1.txt" "$BATS_TEST_TMPDIR/guids2.txt"
}

@test "duplicate notifications are both emitted (guid collision is by design)" {
  write_json dup.json <<'JSON'
[
  {"kind": "like",
   "actors": [{"name": "Alice", "username": "alice"}],
   "tweet": {"id": "111", "text": "hi",
             "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
             "author": {"username": "bob"}}},
  {"kind": "like",
   "actors": [{"name": "Alice", "username": "alice"}],
   "tweet": {"id": "111", "text": "hi",
             "createdAt": "Wed Oct 10 20:19:24 +0000 2018",
             "author": {"username": "bob"}}}
]
JSON
  run_script "$BATS_TEST_TMPDIR/dup.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 2 ]
  assert_wellformed "$OUT"
}

@test "empty array yields a valid empty feed" {
  printf '[]' >"$BATS_TEST_TMPDIR/empty.json"
  run_script "$BATS_TEST_TMPDIR/empty.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  count="$(grep -c '<item>' "$OUT" || true)"
  [ "$count" -eq 0 ]
}
