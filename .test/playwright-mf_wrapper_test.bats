#!/usr/bin/env bats
# .test/playwright-mf_wrapper_test.bats
#
# Behavioural invariant tests for .bin/playwright-mf.sh (the monthly
# mfcf rotation wrapper), run against a fully stubbed environment:
# no network, no real account, no real Money Forward session.
#
# Invariants pinned here:
#   - the window is the current month plus the past 12 months
#     (13 monthly files), crossing year boundaries via `date`
#   - a month whose scrape fails keeps its previous file byte-for-byte
#     (replace only on success); the run reports failure
#   - months older than the window are pruned
#   - every generated file is well-formed XML whose item pubDates all
#     belong to the month named by the file
#
# Requirements: jq, python3

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WRAPPER="$ROOT/.bin/playwright-mf.sh"

  command -v jq >/dev/null 2>&1 || skip "jq is required"
  command -v python3 >/dev/null 2>&1 || skip "python3 is required"

  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  STUBBIN="$BATS_TEST_TMPDIR/stubbin"
  ASSETS="$FAKE_HOME/gd/API/assets"
  mkdir -p "$FAKE_HOME/.bin" "$FAKE_HOME/.config/playwright-mf" "$ASSETS" "$STUBBIN"

  # The converter under test is the real one; the CSV converters are
  # out of scope for the rotation invariants and are stubbed.
  cp "$ROOT/.bin/mfcf-to-rss.sh" "$FAKE_HOME/.bin/mfcf-to-rss.sh"
  chmod +x "$FAKE_HOME/.bin/mfcf-to-rss.sh"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"$FAKE_HOME/.bin/mf-to-csv.sh"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"$FAKE_HOME/.bin/mf-liability-to-csv.sh"
  chmod +x "$FAKE_HOME/.bin/mf-to-csv.sh" "$FAKE_HOME/.bin/mf-liability-to-csv.sh"

  # Synthetic account list (the real one lives outside the repo).
  printf 'DummyBank@dummy\n' >"$FAKE_HOME/.config/playwright-mf/accounts"

  # git stub: "clone" just creates the checkout directory.
  cat >"$STUBBIN/git" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
  mkdir -p "$(basename "$2" .git)"
fi
exit 0
SH

  # node stub: cf.js answers with one in-month transaction for the
  # requested --month, or fails for $FAIL_MONTH. Other scripts succeed
  # with minimal output.
  cat >"$STUBBIN/node" <<'SH'
#!/usr/bin/env bash
script="$1"
shift || true
case "$script" in
  cf.js)
    month=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--month" ]]; then
        month="$2"
        shift 2
      else
        shift
      fi
    done
    if [[ -n "${FAIL_MONTH:-}" && "$FAIL_MONTH" == "$month" ]]; then
      echo "stub cf.js: simulated scrape failure for $month" >&2
      exit 1
    fi
    mm="${month:5:2}"
    printf '{"timestamp":"%s-15T00:00:00.000Z","transactions":[{"date":"%s/15(月)","content":"Stub Tx","amount_yen":-100,"account":"Stub Bank","category_main":"Stub","category_sub":"","memo":"","is_transfer":false}]}\n' "$month" "$mm"
    ;;
  bs-portfolio.js|bs-liability.js)
    printf '{}'
    ;;
esac
exit 0
SH

  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/npm"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/npx"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/sleep"
  chmod +x "$STUBBIN/git" "$STUBBIN/node" "$STUBBIN/npm" "$STUBBIN/npx" "$STUBBIN/sleep"
}

teardown() {
  rm -rf /tmp/playwright-mf
}

run_wrapper() {
  STATUS=0
  env HOME="$FAKE_HOME" PATH="$STUBBIN:$PATH" FAIL_MONTH="${FAIL_MONTH:-}" \
    bash "$WRAPPER" || STATUS=$?
}

ym_months_ago() {
  date -d "$1 months ago" +%Y%m
}

ym_hyphen_months_ago() {
  date -d "$1 months ago" +%Y-%m
}

@test "generates exactly the 13-month window of well-formed monthly files" {
  run_wrapper
  [ "$STATUS" -eq 0 ]

  count="$(ls "$ASSETS"/mfcf.[0-9]*.xml | wc -l)"
  [ "$count" -eq 13 ]

  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12; do
    ym="$(ym_months_ago "$i")"
    [ -f "$ASSETS/mfcf.$ym.xml" ]
  done

  # Every file parses as XML and every item pubDate belongs to the
  # month in the file name.
  python3 - "$ASSETS" <<'PYEOF'
import sys, glob, re, xml.dom.minidom, email.utils
assets = sys.argv[1]
files = sorted(glob.glob(assets + "/mfcf.[0-9]*.xml"))
assert len(files) == 13, files
for path in files:
    ym = re.search(r"mfcf\.(\d{6})\.xml$", path).group(1)
    doc = xml.dom.minidom.parse(path)
    items = doc.getElementsByTagName("item")
    assert len(items) >= 1, path
    for item in items:
        text = item.getElementsByTagName("pubDate")[0].firstChild.data
        dt = email.utils.parsedate_to_datetime(text)
        assert dt is not None, (path, text)
        assert "%04d%02d" % (dt.year, dt.month) == ym, (path, text, ym)
print("all monthly files OK")
PYEOF
}

@test "a failed month keeps its previous file byte-for-byte" {
  fail_ym="$(ym_months_ago 3)"
  fail_month="$(ym_hyphen_months_ago 3)"
  later_ym="$(ym_months_ago 4)"
  printf 'SENTINEL failed month %s\n' "$fail_ym" >"$ASSETS/mfcf.$fail_ym.xml"
  printf 'SENTINEL later month %s\n' "$later_ym" >"$ASSETS/mfcf.$later_ym.xml"
  cp "$ASSETS/mfcf.$fail_ym.xml" "$BATS_TEST_TMPDIR/sentinel-failed.xml"
  cp "$ASSETS/mfcf.$later_ym.xml" "$BATS_TEST_TMPDIR/sentinel-later.xml"

  FAIL_MONTH="$fail_month" run_wrapper
  [ "$STATUS" -ne 0 ]

  # The failed month was not overwritten or truncated.
  cmp "$BATS_TEST_TMPDIR/sentinel-failed.xml" "$ASSETS/mfcf.$fail_ym.xml"
  # Months after the failure were not reached either; their files are
  # likewise untouched (never replaced by a partial run).
  cmp "$BATS_TEST_TMPDIR/sentinel-later.xml" "$ASSETS/mfcf.$later_ym.xml"

  # Months before the failure were regenerated normally.
  current_ym="$(ym_months_ago 0)"
  grep -q 'Stub Tx' "$ASSETS/mfcf.$current_ym.xml"
  grep -q 'Stub Tx' "$ASSETS/mfcf.$(ym_months_ago 2).xml"
}

@test "files older than the 13-month window are pruned" {
  old_ym="$(ym_months_ago 13)"
  edge_ym="$(ym_months_ago 12)"
  printf 'SENTINEL old %s\n' "$old_ym" >"$ASSETS/mfcf.$old_ym.xml"
  printf 'SENTINEL edge %s\n' "$edge_ym" >"$ASSETS/mfcf.$edge_ym.xml"

  run_wrapper
  [ "$STATUS" -eq 0 ]

  [ ! -e "$ASSETS/mfcf.$old_ym.xml" ]
  # The boundary month is inside the window and was regenerated.
  [ -f "$ASSETS/mfcf.$edge_ym.xml" ]
  grep -q 'Stub Tx' "$ASSETS/mfcf.$edge_ym.xml"
}
