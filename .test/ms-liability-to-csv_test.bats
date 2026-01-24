#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/ms-liability-to-csv.sh"
  FIXTURE="$BATS_TEST_DIRNAME/ms-liability-to-csv_test.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -f "$SCRIPT" ]]; then
    skip "missing script: $SCRIPT"
  fi

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi

  TMP_OUTPUT_DIR="$(mktemp -d)"
}

@test "works when reading JSON from stdin" {
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' '$TMP_OUTPUT_DIR'"
  [ "$status" -eq 0 ]
  [ -f "$TMP_OUTPUT_DIR/total-liability.csv" ]
}

@test "total-liability.csv has correct header and content" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local total_csv="$TMP_OUTPUT_DIR/total-liability.csv"

  run head -n 1 "$total_csv"
  [ "$output" = '"timestamp","total_text_num","total_yen"' ]

  run tail -n 1 "$total_csv"
  [ "$output" = '"2024-08-01T00:00:00Z",1234567,1234567' ]
}

@test "breakdown-liability.csv has correct header and normalized row" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local breakdown_csv="$TMP_OUTPUT_DIR/breakdown-liability.csv"

  run head -n 1 "$breakdown_csv"
  [ "$output" = '"timestamp","category","amount_text_num","amount_yen","percentage_text_num","percentage"' ]

  run grep "Loans" "$breakdown_csv"
  [ "$output" = '"2024-08-01T00:00:00Z","Loans",1000000,1000000,81,81' ]
}

@test "details__loan-001__t0-liability.csv has headers and normalized values" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local details_csv="$TMP_OUTPUT_DIR/details__loan-001__t0-liability.csv"

  run head -n 1 "$details_csv"
  [ "$output" = '"timestamp","detail_id","category","table_index","Name","Balance","Rate"' ]

  run grep "Main" "$details_csv"
  [ "$output" = '"2024-08-01T00:00:00Z","loan-001","Loans",0,"Main",1000000,1.2' ]
}

@test "details__card-002__t0-liability.csv infers headers" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local details_csv="$TMP_OUTPUT_DIR/details__card-002__t0-liability.csv"

  run head -n 1 "$details_csv"
  [ "$output" = '"timestamp","detail_id","category","table_index","Issuer","Limit"' ]

  run grep "Master" "$details_csv"
  [ "$output" = '"2024-08-01T00:00:00Z","card-002","Cards",0,"Master",134567' ]
}

teardown() {
  rm -rf "$TMP_OUTPUT_DIR"
}
