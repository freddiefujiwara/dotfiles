# Dotfiles

This repository has my basic dotfiles and setup notes.
It is very small and simple.

## What is inside

- `setup.sh`: install and link the dotfiles.
- `test.sh`: run tests with `bats`.
- `vimrc`: basic Vim settings.
- `.muttrc`: Mutt email client settings.
- `.bin/`: small helper commands.
- `.newsboat/`: Newsboat RSS settings.
- `.config/`: app configuration files.

## Commands in `.bin/`

Each file in `.bin/` is a command.

- `dirigera-command`: operate IKEA DIRIGERA lights (on/off/level, by light name, group, or `all`).
- `google-home-speaker-wrapper`: play text on Google Home with `catt` and `gtts-cli`.
- `google-home-speaker-wrapper-change-voice`: switch `google-home-speaker-wrapper` between `openai.fm.sh` and `gtts-cli`.
- `mf-liability-to-csv.sh`: convert MoneyForward liability JSON to CSV.
- `mf-to-csv.sh`: convert MoneyForward account JSON to CSV.
- `mfcf-to-rss.sh`: convert MoneyForward Cash Flow JSON to RSS.
- `openai.fm.sh`: create an MP3 from text using the OpenAI speech API.
- `openai.img.sh`: generate an image using the OpenAI image API.
- `playwright-mf.sh`: run the MoneyForward scrapers (playwright-mf) and regenerate the asset data and cash-flow feeds.
- `playwright-mf-watchdog.sh`: check that the daily playwright-mf outputs (live feed, breakdown CSV, and the last 13 monthly archives) are present, fresh, and month-consistent; mail an alert otherwise.
- `room.sh`: download Rakuten Room collections and items to JSON files.
- `switchbot-ac`: send an AC command to SwitchBot.
- `switchbot-command`: send a basic command to SwitchBot.
- `switchbot-common`: shared functions for SwitchBot scripts.
- `switchbot-custom`: send a custom command to SwitchBot.
- `switchbot-devices`: list SwitchBot devices.
- `switchbot-status`: get SwitchBot device status.
- `switchbot-tv`: set a TV channel with SwitchBot.
- `x-switch.sh`: switch X (Twitter) CLI auth file.
- `x-notify-rss.sh`: convert Twitter notification JSON to RSS.
- `x-to-rss.sh`: convert tweets JSON to RSS.
- `youtube-play`: cast a YouTube video to Google Home with `catt`.

## `.newsboat/` settings

- `config`: basic Newsboat settings (browser, sort order).
- `keys`: key bindings (Vim-like).
- `urls`: RSS feed list.

## `.config/` settings

- `openbox/rc.xml`: Openbox window manager settings (theme, keys, desktops).
- `openbox/autostart`: apps that start with Openbox.
- `tint2/tint2rc`: tint2 panel settings.
- `tgpt/config.toml`: tgpt provider setting.
- `nvim/init.vim`: Neovim settings.

## Before you run `setup.sh`

`setup.sh` copies the files in this repo into `$HOME` and downloads vim-plug with `curl`. That is all it does. The commands in `.bin/` also need tools and credential files that are not in this repo. On a new machine, prepare these first.

### Tools you need on `PATH`

- `bash`, `git`, `curl`: to clone this repo and run `setup.sh`.
- `jq`: used by the MoneyForward converters, `openai.fm.sh`, `openai.img.sh`, `room.sh`, the SwitchBot commands, and the X RSS scripts.
- `wget`, `openssl`: used by the SwitchBot commands.
- `python3`: used by `dirigera-command`.
- `catt`, `gtts-cli`: used by `google-home-speaker-wrapper` and `youtube-play`. Both come from Python packages (see below).
- `x`: the x-cli binary, used by `x-switch.sh` and `x-to-rss.sh`.
- `node`, `npm`: used by `playwright-mf.sh`, which clones and runs the playwright-mf scrapers. Its failure notifications go through `/usr/sbin/sendmail`.
- `newsboat`, `mutt`, Vim or Neovim: the apps whose settings this repo installs (`.newsboat/`, `.muttrc`, `vimrc/`). The settings do nothing until the apps exist.
- `bats`: only for running the tests (`./test.sh`).

### Python packages

Install with `pip` (on my machine they live in the mise Python environment):

- `dirigera`: for `dirigera-command`.
- `catt` and `gTTS`: for the Google Home commands (`gTTS` provides `gtts-cli`).

### Credential files (not in this repo)

Create these by hand on the new machine. The commands that need them fail without them.

- `~/.switchbot.tk`, `~/.switchbot.sc`: SwitchBot API token and secret. Read by `switchbot-common`, so every `switchbot-*` command needs them.
- `~/.openai`: OpenAI API key (the file contains only the key). Read by `openai.fm.sh` and `openai.img.sh`.
- `~/.config/x-cli/`: auth files for the `x` CLI. `x-switch.sh` switches the active file in this directory.
- `~/.dirigera-token`, `~/.dirigera-ip`: DIRIGERA hub token and hub IP address. Read by `dirigera-command`. Keep the token file at mode 600.
- `~/.config/playwright-mf/gas-url`: the Google Apps Script web app URL that `playwright-mf.sh` calls at the end of a run. The URL works like a token, so keep the file at mode 600. The same directory holds `auth.json`, the saved MoneyForward session the scrapers use.

## Quick start

1. Clone the repo to your home directory:

   ```bash
   git clone https://github.com/freddiefujiwara/dotfiles.git ~/.dotfiles
   ```

2. Go into the repo:

   ```bash
   cd ~/.dotfiles
   ```

3. Run setup:

   ```bash
   ./setup.sh
   ```

## What `setup.sh` does

The `setup.sh` command links the files in this repo to your home directory.
If a file already exists, you may need to back it up first.
It also copies `.gemini/settings.json` to `$HOME/.gemini/` if it exists in the repository.

## Update

To get the latest changes:

```bash
git pull
./setup.sh
```

## Test

To run tests:

```bash
./test.sh
```

This uses `bats`. You need to install it first.

## Notes

- This repo is for personal use, but you can read it as an example.
- Please check the files before you run `setup.sh`.
