PENAI_API_KEY=$(cat ~/.openai)
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 'prompt' [output_filename.png]"
  exit 1
fi
PROMPT="$1"
if [ -n "$2" ]; then
  OUTPUT_FILE="$2"
else
  OUTPUT_FILE="image_$(date +%Y%m%d-%H%M%S).png"
fi
echo "Generating image..."
RESPONSE=$(curl -s https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "{
    \"model\": \"dall-e-3\",
    \"prompt\": \"$PROMPT\",
    \"n\": 1,
    \"size\": \"1024x1024\"
}")
IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data[0].url')
if [ "$IMAGE_URL" = "null" ] || [ -z "$IMAGE_URL" ]; then
  echo "Error: 画像URLの取得に失敗しました。"
  echo "API Response: $RESPONSE"
  exit 1
fi
echo "Downloading to '$OUTPUT_FILE'..."
curl -s "$IMAGE_URL" -o "$OUTPUT_FILE"
echo "Done."
