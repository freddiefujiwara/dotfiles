#!/usr/bin/env bats

setup() {
  # テスト用 HOME を作る
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export REAL_HOME=$HOME
  export HOME="$TEST_HOME"

  mkdir -p "$HOME/.config/x-cli"

  # ダミー auth ファイル作成
  echo "anemone" > "$HOME/.config/x-cli/auth.json.anemone_cancer"
  echo "freddie" > "$HOME/.config/x-cli/auth.json.freddiefujiwara"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "anemone を指定すると auth.json が anemone を指す" {
  run $REAL_HOME/.bin/x-switch.sh anemone

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/x-cli/auth.json")" = "auth.json.anemone_cancer" ]
  [[ "$output" == *"auth.json -> auth.json.anemone_cancer"* ]]
}

@test "freddie を指定すると auth.json が freddie を指す" {
  run $REAL_HOME/.bin/x-switch.sh freddie

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/x-cli/auth.json")" = "auth.json.freddiefujiwara" ]
  [[ "$output" == *"auth.json -> auth.json.freddiefujiwara"* ]]
}

@test "不正な引数を渡すと失敗する" {
  run $REAL_HOME/.bin/x-switch.sh unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "引数なしの場合も失敗する" {
  run $REAL_HOME/.bin/x-switch.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
