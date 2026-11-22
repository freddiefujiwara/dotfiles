# Repository Guidelines

## Project Structure & Module Organization
- `.bin/` contains small CLI helpers (kebab-case names like `google-home-speaker-wrapper`).
- `.config/` and `.newsboat/` hold application configs; `.muttrc`, `vimrc/`, and `.vim/` are editor/mail dotfiles.
- `.test/` contains Bats tests (`*_test.bats`) plus small JSON fixtures.
- `setup.sh` installs/syncs dotfiles into `$HOME`; `test.sh` runs the test suite.

## Build, Test, and Development Commands
- `./setup.sh`: copies dotfiles into `$HOME`, updates `.vimrc`, and installs vim-plug via `curl`.
- `./test.sh`: runs all Bats tests in `.test/` (requires `bats` on your PATH).

## Coding Style & Naming Conventions
- Shell scripts use Bash with `set -euo pipefail`; keep changes compatible with `/usr/bin/env bash`.
- Indentation is 2 spaces in scripts; prefer arrays for argument lists (see `setup.sh`).
- Command scripts in `.bin/` use kebab-case; test files use `*_test.bats`.

## Testing Guidelines
- Tests are written with Bats and live in `.test/`.
- Name tests to match their script, e.g., `.bin/x-to-rss.sh` -> `.test/x-to-rss_test.bats`.
- Run tests via `./test.sh`; there is no explicit coverage target.

## Commit & Pull Request Guidelines
- Commit messages are short and imperative; prefixes like `feat:` and `fix:` appear in history.
- PRs should describe the change, call out any dotfiles impacted, and note test results (or why tests were skipped).

## Configuration & Safety Notes
- `setup.sh` copies files into `$HOME` and can overwrite existing dotfiles; back up first.
- Some scripts call external services (OpenAI, SwitchBot, Google Home); keep API keys out of the repo and document required env vars in PRs.
