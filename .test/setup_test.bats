#!/usr/bin/env bats
#
# .test/setup_test.bats
#

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/setup.sh"

  if [[ ! -f "$SCRIPT" ]]; then
    skip "setup.sh not found"
  fi

  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  export DOTFILES_DIR="$TEST_DIR/dotfiles"

  mkdir -p "$HOME" \
    "$DOTFILES_DIR/.bin" \
    "$DOTFILES_DIR/.test" \
    "$DOTFILES_DIR/.newsboat" \
    "$DOTFILES_DIR/.config" \
    "$DOTFILES_DIR/vimrc"

  echo "stub" > "$DOTFILES_DIR/.bin/example"
  echo "stub" > "$DOTFILES_DIR/.test/example"
  echo "stub" > "$DOTFILES_DIR/.newsboat/example"
  echo "stub" > "$DOTFILES_DIR/.config/example"
  echo "stub" > "$DOTFILES_DIR/.muttrc"
  echo "stub" > "$DOTFILES_DIR/vimrc/_vimrc"

  mkdir -p "$TEST_DIR/bin"
  cat <<'EOF' > "$TEST_DIR/bin/curl"
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$out" ]]; then
  exit 1
fi

mkdir -p "$(dirname "$out")"
echo "stub" > "$out"
EOF
  chmod +x "$TEST_DIR/bin/curl"
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "setup.sh installs dotfiles into HOME" {
  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -d "$HOME/.bin" ]
  [ -d "$HOME/.test" ]
  [ -d "$HOME/.newsboat" ]
  [ -d "$HOME/.config" ]
  [ -f "$HOME/.muttrc" ]
  [ -d "$DOTFILES_DIR/.vim" ]
  [ -L "$HOME/.vimrc" ]
  [ -L "$HOME/.vim" ]
  [ "$(readlink "$HOME/.vimrc")" = "$DOTFILES_DIR/vimrc/_vimrc" ]
  [ "$(readlink "$HOME/.vim")" = "$DOTFILES_DIR/.vim" ]
  [ -f "$HOME/.vim/autoload/plug.vim" ]
  [ -f "$HOME/.local/share/nvim/site/autoload/plug.vim" ]
}
