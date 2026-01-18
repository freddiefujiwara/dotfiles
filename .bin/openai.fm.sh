#!/bin/bash

API_KEY=$(cat ~/.openai)
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 'input_text' 'output_file'"
  exit 1
fi
INPUT_TEXT="$1"
OUTPUT_FILE="$2"

curl -s https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg input "$INPUT_TEXT" '{
    model: "gpt-4o-mini-tts",
    voice: "coral",
    input: $input,
    instructions: "Voice Affect: Calm, composed, and reassuring. Competent and in control, instilling trust.\n\nTone: Sincere, empathetic, with genuine concern for the customer and understanding of the situation.\n\nPacing: Slower during the apology to allow for clarity and processing. Faster when offering solutions to signal action and resolution.\n\nEmotions: Calm reassurance, empathy, and gratitude.\n\nPronunciation: Clear, precise: Ensures clarity, especially with key details. Focus on key words like \"refund\" and \"patience.\" \n\nPauses: Before and after the apology to give space for processing the apology.",
    response_format: "mp3"
  }')" --output $OUTPUT_FILE
echo $OUTPUT_FILE
