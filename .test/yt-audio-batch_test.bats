#!/usr/bin/env bats
# Tests for yt-audio-batch config handling. The publish path comes
# from a local-only hosts.conf (ZE_GS_HOSTS_CONF) or the
# YT_AUDIO_PUBLISH_PATH environment variable; there is no default.

setup() {
  export YT_AUDIO_HOME="$BATS_TEST_TMPDIR/yt-audio-home"
  export ZE_GS_HOSTS_CONF="$BATS_TEST_TMPDIR/hosts.conf"
  PUBLISHED="$BATS_TEST_TMPDIR/published/audio-urls.json"
  printf 'YT_AUDIO_PUBLISH_PATH=%s\n' "$PUBLISHED" > "$ZE_GS_HOSTS_CONF"
  mkdir -p "$YT_AUDIO_HOME" "$(dirname "$PUBLISHED")"
  BATCH="$(dirname "$BATS_TEST_FILENAME")/../.bin/yt-audio-batch"
}

@test "empty queue publishes an empty JSON object to the configured path" {
  run "$BATCH"
  [ "$status" -eq 0 ]
  [ -f "$PUBLISHED" ]
  run python3 -c 'import json, sys; assert json.load(open(sys.argv[1])) == {}' "$PUBLISHED"
  [ "$status" -eq 0 ]
}

@test "missing local host config is a clear error, not a silent default" {
  run env ZE_GS_HOSTS_CONF="$BATS_TEST_TMPDIR/no-such.conf" "$BATCH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"local host config missing or incomplete"* ]]
}

# The tail-verification scenarios stub out yt-dlp and the range
# probe; see yt-audio-batch_verify_driver.py for the expectations.
run_verify_driver() {
  run env YT_AUDIO_PUBLISH_PATH="$PUBLISHED" \
    python3 "$(dirname "$BATS_TEST_FILENAME")/yt-audio-batch_verify_driver.py" "$1" "$BATCH"
  [ "$status" -eq 0 ]
}

@test "range-limited URL is not cached and is requeued for the next run" {
  run_verify_driver limited
}

@test "fully reachable URL is cached and published" {
  run_verify_driver good
}

@test "URL whose size cannot be probed is cached anyway (fail-open)" {
  run_verify_driver nosize
}

@test "small file whose tail answers is cached" {
  run_verify_driver tiny
}

