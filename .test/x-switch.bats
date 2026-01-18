#!/usr/bin/env bats

setup() {
  # create HOME for tests
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export REAL_HOME=$HOME
  export HOME="$TEST_HOME"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  mkdir -p "$HOME/.config/x-cli"

  # create dummy auth file
  echo "anemone" > "$HOME/.config/x-cli/auth.json.anemone_cancer"
  echo "freddie" > "$HOME/.config/x-cli/auth.json.freddiefujiwara"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "with anemone: auth.json points to anemone" {
  run "$ROOT/.bin/x-switch.sh" anemone

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/x-cli/auth.json")" = "auth.json.anemone_cancer" ]
  [[ "$output" == *"auth.json -> auth.json.anemone_cancer"* ]]
}

@test "with freddie: auth.json points to freddie" {
  run "$ROOT/.bin/x-switch.sh" freddie

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/x-cli/auth.json")" = "auth.json.freddiefujiwara" ]
  [[ "$output" == *"auth.json -> auth.json.freddiefujiwara"* ]]
}

@test "invalid args fail" {
  run "$ROOT/.bin/x-switch.sh" unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no args also fail" {
  run "$ROOT/.bin/x-switch.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
