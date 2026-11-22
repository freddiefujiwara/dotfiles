#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 'prompt' [output_filename.png]"
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

API_KEY_FILE="$HOME/.openai"
if [ ! -f "$API_KEY_FILE" ]; then
  echo "API key file not found: $API_KEY_FILE" >&2
  exit 1
fi
OPENAI_API_KEY=$(<"$API_KEY_FILE")

PROMPT="$1"
if [ -n "${2:-}" ]; then
  OUTPUT_FILE="$2"
else
  OUTPUT_FILE="image_$(date +%Y%m%d-%H%M%S).png"
fi

echo "Generating image..."
PAYLOAD="$(jq -n --arg prompt "$PROMPT" '{
  model: "dall-e-3",
  prompt: $prompt,
  n: 1,
  size: "1024x1024"
}')"
RESPONSE="$(curl -sS https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$PAYLOAD")"
IMAGE_URL="$(echo "$RESPONSE" | jq -r '.data[0].url')"
if [ "$IMAGE_URL" = "null" ] || [ -z "$IMAGE_URL" ]; then
  echo "Error: 画像URLの取得に失敗しました。"
  echo "API Response: $RESPONSE"
  exit 1
fi
echo "Downloading to '$OUTPUT_FILE'..."
curl -sS "$IMAGE_URL" -o "$OUTPUT_FILE" || true
echo "Done."
