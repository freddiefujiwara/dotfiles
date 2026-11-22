#!/usr/bin/env bats
# Tests for the `ogp` trigger (queue append only).

setup() {
  export OGP_HOME="$BATS_TEST_TMPDIR/ogp-home"
  OGP_BIN="$(dirname "$BATS_TEST_FILENAME")/../.bin/ogp"
}

@test "appends one TSV line for an https URL" {
  run "$OGP_BIN" "https://tabelog.com/saitama/A1101/A110101/11000180/"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$OGP_HOME/queue.tsv")" -eq 1 ]
  grep -q $'\t'"https://tabelog.com/saitama/A1101/A110101/11000180/" "$OGP_HOME/queue.tsv"
}

@test "appends a second URL as a second line" {
  "$OGP_BIN" "https://example.com/a?x=1&y=2"
  "$OGP_BIN" "https://example.com/b"
  [ "$(wc -l < "$OGP_HOME/queue.tsv")" -eq 2 ]
  grep -q "https://example.com/a?x=1&y=2" "$OGP_HOME/queue.tsv"
}

@test "ignores non-http(s) arguments" {
  run "$OGP_BIN" "ftp://example.com/x"
  [ "$status" -eq 0 ]
  [ ! -e "$OGP_HOME/queue.tsv" ]
}

@test "ignores a missing argument" {
  run "$OGP_BIN"
  [ "$status" -eq 0 ]
  [ ! -e "$OGP_HOME/queue.tsv" ]
}

@test "ignores URLs longer than 1024 chars" {
  long="https://example.com/$(printf 'a%.0s' $(seq 1 1100))"
  run "$OGP_BIN" "$long"
  [ "$status" -eq 0 ]
  [ ! -e "$OGP_HOME/queue.tsv" ]
}
