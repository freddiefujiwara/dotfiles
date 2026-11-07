#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
  echo "dummy-token" > "$HOME/.dirigera-token"
  echo "192.0.2.1" > "$HOME/.dirigera-ip"

  export DIRIGERA_CALLS_FILE="$TEST_DIR/calls.log"
  : > "$DIRIGERA_CALLS_FILE"

  # Stub the dirigera Python package: the real one talks to the hub,
  # this one returns canned lights and records every call it receives.
  PYLIB="$TEST_DIR/pylib"
  mkdir -p "$PYLIB"
  cat > "$PYLIB/dirigera.py" <<'MOCK'
import os


def _record(line):
    with open(os.environ["DIRIGERA_CALLS_FILE"], "a") as f:
        f.write(line + "\n")


class _Attributes:
    def __init__(self, custom_name, is_on, light_level):
        self.custom_name = custom_name
        self.is_on = is_on
        self.light_level = light_level


class _Room:
    def __init__(self, name):
        self.name = name


class _Light:
    def __init__(self, custom_name, room, is_on, light_level):
        self.attributes = _Attributes(custom_name, is_on, light_level)
        self.room = _Room(room)

    def set_light(self, lamp_on):
        _record(f"set_light {self.attributes.custom_name} {lamp_on}")

    def set_light_level(self, light_level):
        _record(f"set_light_level {self.attributes.custom_name} {light_level}")


class Hub:
    def __init__(self, token, ip_address):
        _record(f"Hub token={token} ip={ip_address}")

    def get_lights(self):
        return [
            _Light("Light 3", "Kids' room", True, 100),
            _Light("Down light 02", "Dining room", False, 80),
            _Light("Down light 01", "Dining room", True, 100),
        ]
MOCK

  export PYTHONPATH="$PYLIB"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "no args: show usage and exit 2" {
  run "$ROOT/.bin/dirigera-command"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "list: print lights sorted by room and name, with state and level" {
  run "$ROOT/.bin/dirigera-command" list
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"Down light 01"* ]]
  [[ "${lines[0]}" == *"Dining room"* ]]
  [[ "${lines[0]}" == *"on"* ]]
  [[ "${lines[1]}" == *"Down light 02"* ]]
  [[ "${lines[1]}" == *"off"* ]]
  [[ "${lines[1]}" == *"80"* ]]
  [[ "${lines[2]}" == *"Light 3"* ]]
  [[ "${lines[2]}" == *"Kids' room"* ]]
  grep -q "Hub token=dummy-token ip=192.0.2.1" "$DIRIGERA_CALLS_FILE"
}

@test "on: turn on the named light" {
  run "$ROOT/.bin/dirigera-command" on "Down light 02"
  [ "$status" -eq 0 ]
  [[ "$output" == *"on: Down light 02"* ]]
  grep -q "set_light Down light 02 True" "$DIRIGERA_CALLS_FILE"
}

@test "off: name match is case-insensitive" {
  run "$ROOT/.bin/dirigera-command" off "down light 01"
  [ "$status" -eq 0 ]
  grep -q "set_light Down light 01 False" "$DIRIGERA_CALLS_FILE"
}

@test "on all: turn on every light" {
  run "$ROOT/.bin/dirigera-command" on all
  [ "$status" -eq 0 ]
  [ "$(grep -c 'set_light' "$DIRIGERA_CALLS_FILE")" -eq 3 ]
  grep -q "set_light Light 3 True" "$DIRIGERA_CALLS_FILE"
}

@test "level: set the light level of the named light" {
  run "$ROOT/.bin/dirigera-command" level "Down light 01" 50
  [ "$status" -eq 0 ]
  [[ "$output" == *"level 50: Down light 01"* ]]
  grep -q "set_light_level Down light 01 50" "$DIRIGERA_CALLS_FILE"
}

@test "level: reject out-of-range values without calling the hub" {
  run "$ROOT/.bin/dirigera-command" level "Down light 01" 0
  [ "$status" -eq 2 ]
  [[ "$output" == *"level must be 1-100"* ]]
  ! grep -q "set_light_level" "$DIRIGERA_CALLS_FILE"
}

@test "unknown light name: exit 2 and list the available names" {
  run "$ROOT/.bin/dirigera-command" on "No such light"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no light named 'No such light'"* ]]
  [[ "$output" == *"Down light 01"* ]]
  ! grep -q "set_light " "$DIRIGERA_CALLS_FILE"
}
