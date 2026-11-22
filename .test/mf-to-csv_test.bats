#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/mf-to-csv.sh"
  FIXTURE="$BATS_TEST_DIRNAME/mf-to-csv_test.json"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  if [[ ! -x "$SCRIPT" ]]; then
    chmod +x "$SCRIPT" 2>/dev/null || true
  fi

  # Create a temporary directory for test output
  TMP_OUTPUT_DIR="$(mktemp -d)"
}

@test "works when reading JSON from stdin" {
  # Note: The script outputs to a directory, so we must provide one.
  # We check for one of the output files to confirm success.
  run bash -c "cat '$FIXTURE' | bash '$SCRIPT' '$TMP_OUTPUT_DIR'"
  [ "$status" -eq 0 ]
  [ -f "$TMP_OUTPUT_DIR/breakdown.csv" ]
}

@test "breakdown.csv has correct header and content" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local breakdown_csv="$TMP_OUTPUT_DIR/breakdown.csv"

  # Check header
  run head -n 1 "$breakdown_csv"
  [ "$output" = '"timestamp","category","amount_text_num","amount_yen","percentage_text_num","percentage"' ]

  # Check row count (header + 3 data rows)
  run wc -l < "$breakdown_csv"
  [ "$output" -eq 4 ]

  # Check a specific data row for correct values and normalization
  run grep "Stocks" "$breakdown_csv"
  [ "$output" = '"2024-07-30T12:00:00Z","Stocks",1250000,1250000,50.0,50.0' ]
}

@test "assetClassRatio.csv has correct header and content" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local asset_csv="$TMP_OUTPUT_DIR/assetClassRatio.csv"

  # Check header
  run head -n 1 "$asset_csv"
  [ "$output" = '"timestamp","name","y","color"' ]

  # Check row count (header + 3 data rows)
  run wc -l < "$asset_csv"
  [ "$output" -eq 4 ]

  # Check a specific data row
  run grep "Domestic Equity" "$asset_csv"
  [ "$output" = '"2024-07-30T12:00:00Z","Domestic Equity",60.0,"#7cb5ec"' ]
}

@test "details__stock-001__t0.csv has correct header and content" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local details_csv="$TMP_OUTPUT_DIR/details__stock-001__t0.csv"

  # Check header (from JSON headers)
  run head -n 1 "$details_csv"
  [ "$output" = '"timestamp","detail_id","category","table_index","Ticker","Name","Quantity","Price"' ]

  # Check row count (header + 2 data rows)
  run wc -l < "$details_csv"
  [ "$output" -eq 3 ]
}

@test "details__real-estate-002__t0.csv has correct normalized numbers" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local details_csv="$TMP_OUTPUT_DIR/details__real-estate-002__t0.csv"

  # Check for correct normalization of "5,000,000円"
  run grep "Main St Office" "$details_csv"
  [[ "$output" == *',5000000,'* ]]
}

@test "details__real-estate-002__t1.csv has correct inferred header" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]
  local details_csv="$TMP_OUTPUT_DIR/details__real-estate-002__t1.csv"

  # Check header (inferred from item keys)
  run head -n 1 "$details_csv"
  [ "$output" = '"timestamp","detail_id","category","table_index","Asset","Value"' ]
}

teardown() {
  # Clean up the temporary directory
  rm -rf "$TMP_OUTPUT_DIR"
}

@test "generates all expected CSV files" {
  run bash "$SCRIPT" "$TMP_OUTPUT_DIR" < "$FIXTURE"
  [ "$status" -eq 0 ]

  # Check for the main CSV files
  [ -f "$TMP_OUTPUT_DIR/breakdown.csv" ]
  [ -f "$TMP_OUTPUT_DIR/assetClassRatio.csv" ]

  # Check for the details CSV files generated from the fixture
  [ -f "$TMP_OUTPUT_DIR/details__stock-001__t0.csv" ]
  [ -f "$TMP_OUTPUT_DIR/details__real-estate-002__t0.csv" ]
  [ -f "$TMP_OUTPUT_DIR/details__real-estate-002__t1.csv" ]
}
