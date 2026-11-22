#!/usr/bin/env bats
setup() {
  TMPROOT="$(mktemp -d)"
  TESTBIN="$TMPROOT/bin"
  mkdir -p "$TESTBIN"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # swap HOME (prepare ~/.openai)
  export REAL_HOME=$HOME
  export HOME="$TMPROOT/home"
  mkdir -p "$HOME"
  echo "dummy-key" > "$HOME/.openai"
  # add mocks at PATH start
  export PATH="$TESTBIN:$PATH"
  # mock control
  export MOCK_JQ_URL="https://example.com/test.png"
  export MOCK_API_RESPONSE='{"data":[{"url":"https://example.com/test.png"}]}'
  unset MOCK_CURL_DOWNLOAD_FAIL
  # fix date
  cat > "$TESTBIN/date" <<'EOF'
#!/usr/bin/env bash
echo "20260115-120000"
EOF
  chmod +x "$TESTBIN/date"
  # mock jq
  cat > "$TESTBIN/jq" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "${MOCK_JQ_URL}"
EOF
  chmod +x "$TESTBIN/jq"
  # mock curl
  cat > "$TESTBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -u
args="$*"
if [[ "$args" == *"https://api.openai.com/v1/images/generations"* ]]; then
  printf "%s\n" "${MOCK_API_RESPONSE}"
  exit 0
fi
if [[ "${MOCK_CURL_DOWNLOAD_FAIL:-}" == "1" ]]; then
  exit 22
fi
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then
    shift
    out="$1"
    break
  fi
  shift
done
if [[ -z "$out" ]]; then
  echo "mock curl: missing -o <file>" >&2
  exit 2
fi
: > "$out"
exit 0
EOF
  chmod +x "$TESTBIN/curl"
  # decide the script under test (SUT)
  # 1) use env var SUT if set
  # 2) else use ./openid.img.sh in the current dir
  export SUT="${SUT:-$ROOT/.bin/openai.img.sh}"
  # check file exists and is executable (fail here for clarity)
  if [[ ! -e "$SUT" ]]; then
    echo "SUT not found: $SUT" >&2
    return 1
  fi
  if [[ ! -x "$SUT" ]]; then
    echo "SUT is not executable: $SUT (try: chmod +x $SUT)" >&2
    return 1
  fi
}
teardown() {
  rm -rf "$TMPROOT"
  rm -f output.png image_*.png
}
@test "no args: show usage and exit 1" {
  run "$SUT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
@test "prompt only: succeed with default filename" {
  run "$SUT" "a prompt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generating image..."* ]]
  [[ "$output" == *"Downloading to 'image_20260115-120000.png'..."* ]]
  [[ "$output" == *"Done."* ]]
  [ -f "image_20260115-120000.png" ]
}
@test "output filename set: succeed with given name" {
  run "$SUT" "a prompt" "output.png"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading to 'output.png'..."* ]]
  [ -f "output.png" ]
}
@test "URL is null: exit with error and show response" {
  export MOCK_JQ_URL="null"
  export MOCK_API_RESPONSE='{"data":[{"url":null}]}'
  run "$SUT" "a prompt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"API Response:"* ]]
  [[ "$output" == *"$MOCK_API_RESPONSE"* ]]
}
@test "URL is empty: exit with error and show response" {
  export MOCK_JQ_URL=""
  export MOCK_API_RESPONSE='{"data":[{"url":""}]}'
  run "$SUT" "a prompt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"API Response:"* ]]
}
@test "download curl fails but still reaches Done (current behavior)" {
  export MOCK_CURL_DOWNLOAD_FAIL="1"
  run "$SUT" "a prompt" "output.png"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done."* ]]
  [ ! -f "output.png" ]
}
