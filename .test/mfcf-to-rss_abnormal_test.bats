#!/usr/bin/env bats
# .test/mfcf-to-rss_abnormal_test.bats
#
# Abnormal-case and invariant tests for .bin/mfcf-to-rss.sh:
# deformed JSON must never yield a partial or corrupt feed, and every
# emitted item pubDate must be a real calendar date.
#
# Requirements: jq, python3 (XML well-formedness checks)

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/mfcf-to-rss.sh"
  OUT="$BATS_TEST_TMPDIR/out.xml"

  command -v jq >/dev/null 2>&1 || skip "jq is required"
  command -v python3 >/dev/null 2>&1 || skip "python3 is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi
}

# Run the script with stdout/stderr captured separately.
# Sets STATUS, and leaves stdout in $OUT.
run_script() {
  local json="$1"
  STATUS=0
  MFCF_YEAR="${MFCF_YEAR:-2026}" bash "$SCRIPT" "$json" >"$OUT" 2>"$BATS_TEST_TMPDIR/err.txt" || STATUS=$?
}

assert_wellformed() {
  python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$1"
}

# Fails if the file contains bytes XML 1.0 forbids (C0 controls other
# than tab / LF / CR).
assert_no_forbidden_bytes() {
  python3 -c 'import sys; d = open(sys.argv[1], "rb").read(); bad = [b for b in d if b < 0x20 and b not in (9, 10, 13)]; sys.exit(1 if bad else 0)' "$1"
}

write_json() {
  # write_json <name> ; JSON on stdin
  cat >"$BATS_TEST_TMPDIR/$1"
}

@test "missing transactions fails with no output at all" {
  write_json notx.json <<'JSON'
{"timestamp": "2026-01-01T00:00:00Z"}
JSON
  run_script "$BATS_TEST_TMPDIR/notx.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "non-array transactions fails with no output at all" {
  write_json badtx.json <<'JSON'
{"transactions": {"date": "01/23(金)"}}
JSON
  run_script "$BATS_TEST_TMPDIR/badtx.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "malformed JSON fails with no output at all" {
  printf 'this is not json' >"$BATS_TEST_TMPDIR/bad.json"
  run_script "$BATS_TEST_TMPDIR/bad.json"
  [ "$STATUS" -ne 0 ]
  [ ! -s "$OUT" ]
}

@test "null and non-object entries are skipped, valid entries still emitted" {
  write_json mixed.json <<'JSON'
{"transactions": [
  null,
  42,
  "a string",
  {"date": "01/23(金)", "content": "Valid", "amount_yen": -100}
]}
JSON
  run_script "$BATS_TEST_TMPDIR/mixed.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 1 ]
  grep -q 'Valid' "$OUT"
  # no empty-title phantom item
  ! grep -q '<title></title>' "$OUT"
  assert_wellformed "$OUT"
}

@test "non-integer amount_yen values are omitted, never rendered as garbage" {
  write_json amounts.json <<'JSON'
{"transactions": [
  {"date": "01/23(金)", "content": "float amount", "amount_yen": 100.5},
  {"date": "01/23(金)", "content": "bool amount", "amount_yen": true},
  {"date": "01/23(金)", "content": "object amount", "amount_yen": {"x": 1}},
  {"date": "01/23(金)", "content": "string amount", "amount_yen": "-500"},
  {"date": "01/23(金)", "content": "good amount", "amount_yen": -500}
]}
JSON
  run_script "$BATS_TEST_TMPDIR/amounts.json"
  [ "$STATUS" -eq 0 ]
  # only the genuine integer amount may appear as money in a title
  count="$(grep '<title>' "$OUT" | grep -o '¥' | wc -l)"
  [ "$count" -eq 1 ]
  grep -q -- '-¥500 good amount' "$OUT"
  ! grep -q '100100' "$OUT"
  assert_wellformed "$OUT"
}

@test "non-existent and garbled dates are not emitted as items" {
  write_json dates.json <<'JSON'
{"transactions": [
  {"date": "02/30(日)", "content": "feb30", "amount_yen": -100},
  {"date": "13/01(木)", "content": "month13", "amount_yen": -100},
  {"date": "04/31(木)", "content": "apr31", "amount_yen": -100},
  {"date": "00/10(土)", "content": "month00", "amount_yen": -100},
  {"date": "01/00(土)", "content": "day00", "amount_yen": -100},
  {"date": "garbage", "content": "garbage date", "amount_yen": -100},
  {"date": "02/29(日)", "content": "feb29 non-leap", "amount_yen": -100},
  {"date": "01/15(木)", "content": "valid row", "amount_yen": -100}
]}
JSON
  MFCF_YEAR=2026 run_script "$BATS_TEST_TMPDIR/dates.json"
  [ "$STATUS" -eq 0 ]
  count="$(grep -c '<item>' "$OUT")"
  [ "$count" -eq 1 ]
  grep -q 'valid row' "$OUT"
  ! grep -q '2026-02-30' "$OUT"
  ! grep -q '2026-13-01' "$OUT"
  assert_wellformed "$OUT"
}

@test "leap day is accepted in a leap year" {
  write_json leap.json <<'JSON'
{"transactions": [
  {"date": "02/29(火)", "content": "leap day", "amount_yen": -100}
]}
JSON
  MFCF_YEAR=2028 run_script "$BATS_TEST_TMPDIR/leap.json"
  [ "$STATUS" -eq 0 ]
  grep -q '29 Feb 2028' "$OUT"
  grep -q 'leap day' "$OUT"
}

@test "C0 control characters in text cannot corrupt the XML" {
  jq -n --arg content $'bad\x01ctrl \x0bvt' --arg memo $'bell\x07' \
    '{transactions: [{date: "01/23(金)", content: $content, amount_yen: -100, memo: $memo}]}' \
    >"$BATS_TEST_TMPDIR/ctrl.json"
  run_script "$BATS_TEST_TMPDIR/ctrl.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  assert_no_forbidden_bytes "$OUT"
  grep -q 'badctrl' "$OUT"
}

@test "every emitted pubDate is a real date in the transaction month" {
  # Systematic sweep: for each month, emit the 1st, the 28th and the
  # month's last day; all pubDates must parse and stay in that month.
  for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
    case "$m" in
      02) last=28 ;;
      04|06|09|11) last=30 ;;
      *) last=31 ;;
    esac
    jq -n --arg m "$m" --arg last "$last" \
      '{transactions: [
        {date: "\($m)/01(月)", content: "first", amount_yen: 1},
        {date: "\($m)/28(月)", content: "mid", amount_yen: 1},
        {date: "\($m)/\($last)(月)", content: "last", amount_yen: 1}
      ]}' >"$BATS_TEST_TMPDIR/sweep.json"
    MFCF_YEAR=2026 run_script "$BATS_TEST_TMPDIR/sweep.json"
    [ "$STATUS" -eq 0 ]
    count="$(grep -c '<item>' "$OUT")"
    [ "$count" -eq 3 ]
    while IFS= read -r pd; do
      python3 -c 'import sys, email.utils; dt = email.utils.parsedate_to_datetime(sys.argv[1]); assert dt is not None and "%02d" % dt.month == sys.argv[2], sys.argv[1]' "$pd" "$m"
    done < <(grep -o '<pubDate>[^<]*</pubDate>' "$OUT" | sed 's/<[^>]*>//g')
  done
}

@test "empty transactions yields a valid empty feed" {
  write_json empty.json <<'JSON'
{"timestamp": "2026-01-01T00:00:00Z", "transactions": []}
JSON
  run_script "$BATS_TEST_TMPDIR/empty.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
  count="$(grep -c '<item>' "$OUT" || true)"
  [ "$count" -eq 0 ]
}

@test "same input produces byte-identical output on a second run" {
  run_script "$BATS_TEST_DIRNAME/mfcf-to-rss_test.json"
  [ "$STATUS" -eq 0 ]
  cp "$OUT" "$BATS_TEST_TMPDIR/first.xml"
  run_script "$BATS_TEST_DIRNAME/mfcf-to-rss_test.json"
  [ "$STATUS" -eq 0 ]
  cmp "$BATS_TEST_TMPDIR/first.xml" "$OUT"
}

@test "very long content still produces a well-formed feed" {
  jq -n --arg content "$(printf 'a%.0s' $(seq 1 100000))" \
    '{transactions: [{date: "01/23(金)", content: $content, amount_yen: 1}]}' \
    >"$BATS_TEST_TMPDIR/long.json"
  run_script "$BATS_TEST_TMPDIR/long.json"
  [ "$STATUS" -eq 0 ]
  assert_wellformed "$OUT"
}
