#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="${DOTFILES_DIR:-$script_dir}"

mkdir -p "$HOME/.bin" "$HOME/.test" "$HOME/.newsboat" "$HOME/.config"
cp -a "$dotfiles_dir/.bin/." "$HOME/.bin/"
cp -a "$dotfiles_dir/.test/." "$HOME/.test/"
cp -a "$dotfiles_dir/.newsboat/." "$HOME/.newsboat/"
cp -a "$dotfiles_dir/.config/." "$HOME/.config/"

rm -rf "$HOME/.vim"
rm -f "$HOME/.vimrc"
ln -s "$dotfiles_dir/vimrc/_vimrc" "$HOME/.vimrc"
mkdir -p "$dotfiles_dir/.vim"
ln -s "$dotfiles_dir/.vim" "$HOME/"

curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
