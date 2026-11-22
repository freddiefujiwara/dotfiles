#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/.config/x-cli"
if [[ ! -d $DIR ]]; then
  echo "Directory not found: $DIR" >&2
  exit 1
fi
cd "$DIR"

mode="${1-}"
case "$mode" in
  anemone)
    ln -sfn auth.json.anemone_cancer auth.json
    ;;
  freddie)
    ln -sfn auth.json.freddiefujiwara auth.json
    ;;
  *)
    echo "Usage: $0 {anemone|freddie}"
    exit 1
    ;;
esac

echo "auth.json -> $(readlink auth.json)"
