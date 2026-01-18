# Dotfiles

This repository has my basic dotfiles and setup notes.
It is very small and simple.

## What is inside

- `setup.sh`: install and link the dotfiles.
- `test.sh`: run tests with `bats`.
- `vimrc`: basic Vim settings.
- `.bin/`: small helper commands.
- `.newsboat/`: Newsboat RSS settings.
- `.config/`: app configuration files.

## Commands in `.bin/`

Each file in `.bin/` is a command.

- `google-home-speaker-wrapper`: play text on Google Home with `catt` and `gtts-cli`.
- `google-home-speaker-wrapper-change-voice`: switch `google-home-speaker-wrapper` between `openai.fm.sh` and `gtts-cli`.
- `openai.fm.sh`: create an MP3 from text using the OpenAI speech API.
- `openai.img.sh`: generate an image using the OpenAI image API.
- `room.sh`: download Rakuten Room collections and items to JSON files.
- `switchbot-ac`: send an AC command to SwitchBot.
- `switchbot-command`: send a basic command to SwitchBot.
- `switchbot-custom`: send a custom command to SwitchBot.
- `switchbot-devices`: list SwitchBot devices.
- `switchbot-status`: get SwitchBot device status.
- `switchbot-tv`: set a TV channel with SwitchBot.
- `x-switch.sh`: switch X (Twitter) CLI auth file.
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
