#!/usr/bin/env bats
setup() {
  TMPROOT="$(mktemp -d)"
  TESTBIN="$TMPROOT/bin"
  mkdir -p "$TESTBIN"
  # HOME差し替え（~/.openai を用意）
  export REAL_HOME=$HOME
  export HOME="$TMPROOT/home"
  mkdir -p "$HOME"
  echo "dummy-key" > "$HOME/.openai"
  # PATH先頭にモック
  export PATH="$TESTBIN:$PATH"
  # モック制御
  export MOCK_JQ_URL="https://example.com/test.png"
  export MOCK_API_RESPONSE='{"data":[{"url":"https://example.com/test.png"}]}'
  unset MOCK_CURL_DOWNLOAD_FAIL
  # date固定
  cat > "$TESTBIN/date" <<'EOF'
#!/usr/bin/env bash
echo "20260115-120000"
EOF
  chmod +x "$TESTBIN/date"
  # jqモック
  cat > "$TESTBIN/jq" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "${MOCK_JQ_URL}"
EOF
  chmod +x "$TESTBIN/jq"
  # curlモック
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
  # テスト対象スクリプト（SUT）を決定
  # 1) 環境変数 SUT があればそれ
  # 2) なければカレントの ./openid.img.sh を試す
  export SUT="${SUT:-$REAL_HOME/.bin/openai.img.sh}"
  # 存在・実行可能チェック（ここで落として原因を明確化）
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
@test "引数なし: Usage 表示して exit 1" {
  run "$SUT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
@test "プロンプトのみ: デフォルトファイル名で成功" {
  run "$SUT" "a prompt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generating image..."* ]]
  [[ "$output" == *"Downloading to 'image_20260115-120000.png'..."* ]]
  [[ "$output" == *"Done."* ]]
  [ -f "image_20260115-120000.png" ]
}
@test "出力ファイル名指定: 指定名で成功" {
  run "$SUT" "a prompt" "output.png"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading to 'output.png'..."* ]]
  [ -f "output.png" ]
}
@test "URL が null: エラー終了しレスポンスを表示" {
  export MOCK_JQ_URL="null"
  export MOCK_API_RESPONSE='{"data":[{"url":null}]}'
  run "$SUT" "a prompt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"API Response:"* ]]
  [[ "$output" == *"$MOCK_API_RESPONSE"* ]]
}
@test "URL が空: エラー終了しレスポンスを表示" {
  export MOCK_JQ_URL=""
  export MOCK_API_RESPONSE='{"data":[{"url":""}]}'
  run "$SUT" "a prompt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error:"* ]]
  [[ "$output" == *"API Response:"* ]]
}
@test "ダウンロードcurl失敗でも Done まで進む（現状仕様）" {
  export MOCK_CURL_DOWNLOAD_FAIL="1"
  run "$SUT" "a prompt" "output.png"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done."* ]]
  [ ! -f "output.png" ]
}
