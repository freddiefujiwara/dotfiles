#!/usr/bin/env bats
setup() {
  TMPROOT="$(mktemp -d)"
  TESTBIN="$TMPROOT/bin"
  mkdir -p "$TESTBIN"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REAL_HOME=$HOME
  export HOME="$TMPROOT/home"
  mkdir -p "$HOME"
  echo "dummy-key" > "$HOME/.openai"
  export PATH="$TESTBIN:$PATH"

  cat > "$TESTBIN/jq" <<'JQ'
#!/usr/bin/env bash
printf '%s\n' '{"mock":"payload"}'
JQ
  chmod +x "$TESTBIN/jq"

  cat > "$TESTBIN/curl" <<'CURL'
#!/usr/bin/env bash
set -u
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output" ]]; then
    shift
    out="$1"
    break
  fi
  shift
done
if [[ -z "$out" ]]; then
  echo "mock curl: missing --output <file>" >&2
  exit 2
fi
: > "$out"
exit 0
CURL
  chmod +x "$TESTBIN/curl"

  export SUT="${SUT:-$ROOT/.bin/openai.fm.sh}"
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
  rm -f output.mp3
}

@test "引数なし: Usage 表示して exit 1" {
  run "$SUT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "2引数: mp3出力してファイル名を表示" {
  run "$SUT" "hello" "output.mp3"
  [ "$status" -eq 0 ]
  [ -f "output.mp3" ]
  [[ "$output" == *"output.mp3"* ]]
}
