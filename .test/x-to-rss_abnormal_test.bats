#!/usr/bin/env bats
# .test/x-to-rss_abnormal_test.bats
#
# Abnormal-case tests for .bin/x-to-rss.sh: deformed tweet payloads
# must not kill the conversion, leak literal "null" strings, or break
# the XML through unescaped ids/usernames.
#
# Requirements: jq, python3 (XML well-formedness checks)

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/x-to-rss.sh"
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

@test "missing tweets fails with no output at all" {
  write_json notweets.json <<'JSON'
{"something_else": []}
JSON
  run_script "$BATS_TEST_TMPDIR/notweets.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "non-array tweets fails with no output at all" {
  write_json badtweets.json <<'JSON'
{"tweets": {"id": "1"}}
JSON
  run_script "$BATS_TEST_TMPDIR/badtweets.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "malformed JSON fails with no output at all" {
  printf 'not json' >"$BATS_TEST_TMPDIR/bad.json"
  run_script "$BATS_TEST_TMPDIR/bad.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "non-object tweet entries are skipped" {
  write_json mixed.json <<'JSON'
{"tweets": [
  42,
  null,
  {"id": "2", "author": {"name": "Ann", "username": "ann"},
   "text": "kept", "createdAt": "Wed Oct 10 20:19:24 +0000 2018"}
]}
JSON
  run_script "$BATS_TEST_TMPDIR/mixed.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 1 ]
  grep -q 'kept' "$OUT"
  assert_wellformed "$OUT"
}

@test "null author and text never leak literal null strings" {
  write_json nulls.json <<'JSON'
{"tweets": [
  {"id": "1", "author": null, "text": null,
   "createdAt": "Wed Oct 10 20:19:24 +0000 2018"}
]}
JSON
  run_script "$BATS_TEST_TMPDIR/nulls.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  ! grep -q '<author>null</author>' "$OUT"
  ! grep -q '<!\[CDATA\[null\]\]>' "$OUT"
}

@test "markup in username and id cannot break the XML" {
  write_json inject.json <<'JSON'
{"tweets": [
  {"id": "1</guid><evil>x",
   "author": {"name": "Ann", "username": "a</link><evil>"},
   "text": "hi", "createdAt": "Wed Oct 10 20:19:24 +0000 2018"}
]}
JSON
  run_script "$BATS_TEST_TMPDIR/inject.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  ! grep -q '<evil>' "$OUT"
}

@test "C0 control characters in text and name cannot corrupt the XML" {
  jq -n --arg text $'ctrl\x01x \x0b' --arg name $'A\x02nn' \
    '{tweets: [{id: "1", author: {name: $name, username: "ann"},
                text: $text,
                createdAt: "Wed Oct 10 20:19:24 +0000 2018"}]}' \
    >"$BATS_TEST_TMPDIR/ctrl.json"
  run_script "$BATS_TEST_TMPDIR/ctrl.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  assert_no_forbidden_bytes "$OUT"
}

@test "same input produces byte-identical output on a second run" {
  run_script "$BATS_TEST_DIRNAME/x-to-rss_test.json"
  [ "$STATUS" -eq 0 ]
  cp "$OUT" "$BATS_TEST_TMPDIR/first.xml"
  run_script "$BATS_TEST_DIRNAME/x-to-rss_test.json"
  [ "$STATUS" -eq 0 ]
  cmp "$BATS_TEST_TMPDIR/first.xml" "$OUT"
}

@test "empty tweets yields a valid empty feed" {
  printf '{"tweets": []}' >"$BATS_TEST_TMPDIR/empty.json"
  run_script "$BATS_TEST_TMPDIR/empty.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  count="$(grep -c '<item>' "$OUT" || true)"
  [ "$count" -eq 0 ]
}
