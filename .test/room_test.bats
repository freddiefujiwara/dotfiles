#!/usr/bin/env bats
#
setup() {
  # Create a temp folder
  TEST_DIR=$(mktemp -d)
  export WORK_DIR="$TEST_DIR"
  export USER_ID="1000000000182401"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # --- Create a Fake 'curl' command ---
  # We make a real file named 'curl' so it works even when
  # we run the script directly (bash room.sh)
  mkdir -p "$TEST_DIR/bin"
  
  # Write the fake logic into the new curl file
  cat <<EOF > "$TEST_DIR/bin/curl"
#!/bin/bash
# Mock logic: Check arguments and create dummy files
if [[ "\$*" == *"collections"* ]]; then
  echo '{"data": [{"id": "100", "name": "Test Genre"}]}' > collections.json
elif [[ "\$*" == *"collects"* ]]; then
  echo '{"data": [{"id": "999"}]}' > "collects_100.json"
fi
EOF
  # Make it executable
  chmod +x "$TEST_DIR/bin/curl"
  # Add our temp bin folder to the BEGINNING of the system PATH
  # This makes the system use our fake curl instead of the real one
  export PATH="$TEST_DIR/bin:$PATH"
  # Load the script to test functions
  source "$ROOT/.bin/room.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}
# --- Test Cases ---
@test "Function: Normal run (Success)" {
  run run_process
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ "Genre: Test Genre" ]]
}

@test "Function: Error (Folder missing)" {
  export WORK_DIR="/path/to/nowhere"
  run run_process
  [ "$status" -eq 1 ]
}

@test "Function: Error (Missing USER_ID)" {
  export USER_ID=""
  run run_process
  [ "$status" -eq 1 ]
}

@test "Function: Error (Missing WORK_DIR)" {
  export WORK_DIR=""
  run run_process
  [ "$status" -eq 1 ]
}

@test "Function: Download fails (Empty curl)" {
  # Overwrite curl to do nothing
  echo '#!/bin/bash' > "$TEST_DIR/bin/curl"
  chmod +x "$TEST_DIR/bin/curl"
  run run_process
  [ "$status" -eq 0 ]
  [[ ! "${output}" =~ "Genre:" ]]
}

@test "Script: Run directly (Fill the last 5% coverage)" {
  # This runs the script as a separate process
  # Because we changed PATH, it still uses our fake curl
  run bash "$ROOT/.bin/room.sh" "$USER_ID" "$WORK_DIR"
  
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Genre: Test Genre" ]]
}
