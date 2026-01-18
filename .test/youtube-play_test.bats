#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_BIN="$TEST_DIR/bin"
  mkdir -p "$TEST_BIN"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  export CATT_LOG="$TEST_DIR/catt.log"

  cat > "$TEST_BIN/catt" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$CATT_LOG"
MOCK
  chmod +x "$TEST_BIN/catt"

  export PATH="$TEST_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "引数なし: Usage 表示して exit 1" {
  run "$ROOT/.bin/youtube-play"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "ID/host/volume を指定すると catt を順に呼ぶ" {
  run "$ROOT/.bin/youtube-play" -i abc123 -h livingroom -v 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"-i abc123 -h livingroom -v 10"* ]]
  [ -f "$CATT_LOG" ]
  mapfile -t calls < "$CATT_LOG"
  [ "${calls[0]}" = "-d livingroom stop" ]
  [ "${calls[1]}" = "-d livingroom volume 10" ]
  [ "${calls[2]}" = "-d livingroom cast https://youtu.be/abc123" ]
  [ "${calls[3]}" = "-d livingroom status" ]
}
