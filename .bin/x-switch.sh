#!/usr/bin/env bash
set -e

DIR="$HOME/.config/x-cli"
cd "$DIR"

case "$1" in
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
