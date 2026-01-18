#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_BIN="$TEST_DIR/bin"
  mkdir -p "$TEST_BIN"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
  echo "dummy-token" > "$HOME/.switchbot.tk"
  echo "dummy-secret" > "$HOME/.switchbot.sc"

  export WGET_ARGS_FILE="$TEST_DIR/wget.args"

  cat > "$TEST_BIN/uuidgen" <<'MOCK'
#!/usr/bin/env bash
echo "uuid-1234"
MOCK
  chmod +x "$TEST_BIN/uuidgen"

  cat > "$TEST_BIN/date" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "+%s" ]]; then
  echo "1700000000"
else
  echo "unsupported"
fi
MOCK
  chmod +x "$TEST_BIN/date"

  cat > "$TEST_BIN/openssl" <<'MOCK'
#!/usr/bin/env bash
cat > /dev/null
echo "rawsig"
MOCK
  chmod +x "$TEST_BIN/openssl"

  cat > "$TEST_BIN/base64" <<'MOCK'
#!/usr/bin/env bash
cat > /dev/null
echo "basesig"
MOCK
  chmod +x "$TEST_BIN/base64"

  cat > "$TEST_BIN/wget" <<'MOCK'
#!/usr/bin/env bash
printf "%s\n" "$@" > "$WGET_ARGS_FILE"
echo '{"status":"ok"}'
MOCK
  chmod +x "$TEST_BIN/wget"

  cat > "$TEST_BIN/jq" <<'MOCK'
#!/usr/bin/env bash
cat
MOCK
  chmod +x "$TEST_BIN/jq"

  export PATH="$TEST_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "switchbot_post が共通ヘッダとURLで実行される" {
  run bash -c "source '$ROOT/.bin/switchbot-common'; switchbot_post '/devices/device123/commands' '{\"command\":\"on\"}'"
  [ "$status" -eq 0 ]
  grep -q "https://api.switch-bot.com/v1.1/devices/device123/commands" "$WGET_ARGS_FILE"
  grep -q -- '--header=Authorization: dummy-token' "$WGET_ARGS_FILE"
  grep -q -- '--header=sign: basesig' "$WGET_ARGS_FILE"
  grep -q -- '--post-data={"command":"on"}' "$WGET_ARGS_FILE"
}

@test "switchbot_get が共通ヘッダとURLで実行される" {
  run bash -c "source '$ROOT/.bin/switchbot-common'; switchbot_get '/devices/device123/status'"
  [ "$status" -eq 0 ]
  grep -q "https://api.switch-bot.com/v1.1/devices/device123/status" "$WGET_ARGS_FILE"
  grep -q -- '--header=Authorization: dummy-token' "$WGET_ARGS_FILE"
  grep -q -- '--header=sign: basesig' "$WGET_ARGS_FILE"
}

@test "switchbot_api_base が環境変数を優先する" {
  run bash -c "source '$ROOT/.bin/switchbot-common'; SWITCHBOT_API_BASE='https://example.invalid/v1.1' switchbot_api_base"
  [ "$status" -eq 0 ]
  [ "$output" = "https://example.invalid/v1.1" ]
}

@test "switchbot-common を単体実行すると失敗する" {
  run "$ROOT/.bin/switchbot-common"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
