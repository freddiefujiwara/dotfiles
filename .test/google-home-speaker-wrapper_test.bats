#!/usr/bin/env bats

setup() {
  export TEST_DIR
  TEST_DIR=$(mktemp -d)
  export ROOT
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  mkdir -p "$TEST_DIR/bin"

  cat <<'MOCK' > "$TEST_DIR/bin/catt"
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_DIR/catt_calls"
MOCK

  cat <<'MOCK' > "$TEST_DIR/bin/gtts-cli"
#!/bin/bash
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      shift
      output="$1"
      ;;
  esac
  shift
done
if [ -z "$output" ]; then
  exit 1
fi
echo "$output" > "$TEST_DIR/gtts_output"
mkdir -p "$(dirname "$output")"
: > "$output"
MOCK

  chmod +x "$TEST_DIR/bin/catt" "$TEST_DIR/bin/gtts-cli"
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "正常系: 指定したホスト/音量/文章で実行する" {
  run "$ROOT/.bin/google-home-speaker-wrapper" -v 10 -s "hello" -h "livingroom"

  [ "$status" -eq 0 ]
  [[ "$output" == *"-v 10 -h livingroom -s hello"* ]]

  [ -f "$TEST_DIR/catt_calls" ]
  [ "$(wc -l < "$TEST_DIR/catt_calls")" -eq 4 ]
  [[ "$(sed -n '1p' "$TEST_DIR/catt_calls")" == *"stop"* ]]
  [[ "$(sed -n '2p' "$TEST_DIR/catt_calls")" == *"volume 10"* ]]
  [[ "$(sed -n '3p' "$TEST_DIR/catt_calls")" == *"cast"* ]]
  [[ "$(sed -n '4p' "$TEST_DIR/catt_calls")" == *"status"* ]]

  mp3_path="$(cat "$TEST_DIR/gtts_output")"
  [ ! -f "$mp3_path" ]
}

@test "異常系: 引数不足の場合はエラー" {
  run "$ROOT/.bin/google-home-speaker-wrapper" -v 10 -s "hello"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}
