#!/usr/bin/env bats

setup() {
  export TEST_DIR
  TEST_DIR=$(mktemp -d)
  export ROOT
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  mkdir -p "$TEST_DIR/.bin"
  cp "$ROOT/.bin/google-home-speaker-wrapper" "$TEST_DIR/.bin/"
  cp "$ROOT/.bin/google-home-speaker-wrapper-change-voice" "$TEST_DIR/.bin/"
}

teardown() {
  rm -rf "$TEST_DIR"
}

assert_openai_enabled() {
  local target="$1"
  run grep -n '^openai\.fm\.sh \$SPEAK \$TEMP_MP3$' "$target"
  [ "$status" -eq 0 ]

  run grep -n '^#gtts-cli \$SPEAK -l ja -o \$TEMP_MP3$' "$target"
  [ "$status" -eq 0 ]
}

assert_gtts_enabled() {
  local target="$1"
  run grep -n '^#openai\.fm\.sh \$SPEAK \$TEMP_MP3$' "$target"
  [ "$status" -eq 0 ]

  run grep -n '^gtts-cli \$SPEAK -l ja -o \$TEMP_MP3$' "$target"
  [ "$status" -eq 0 ]
}

assert_mode_755() {
  local target="$1"
  run stat -c '%a' "$target"
  [ "$status" -eq 0 ]
  [ "$output" = "755" ]
}

@test "openai argument enables openai.fm.sh" {
  target="$TEST_DIR/.bin/google-home-speaker-wrapper"

  run "$TEST_DIR/.bin/google-home-speaker-wrapper-change-voice" openai
  [ "$status" -eq 0 ]

  assert_openai_enabled "$target"
  assert_mode_755 "$target"

  run "$TEST_DIR/.bin/google-home-speaker-wrapper-change-voice" openai
  [ "$status" -eq 0 ]
  assert_openai_enabled "$target"
  assert_mode_755 "$target"
}

@test "no argument keeps gtts-cli enabled" {
  target="$TEST_DIR/.bin/google-home-speaker-wrapper"

  run "$TEST_DIR/.bin/google-home-speaker-wrapper-change-voice"
  [ "$status" -eq 0 ]

  assert_gtts_enabled "$target"
  assert_mode_755 "$target"
}

@test "non-openai argument keeps gtts-cli enabled" {
  target="$TEST_DIR/.bin/google-home-speaker-wrapper"

  run "$TEST_DIR/.bin/google-home-speaker-wrapper-change-voice" gtts
  [ "$status" -eq 0 ]

  assert_gtts_enabled "$target"
  assert_mode_755 "$target"
}
