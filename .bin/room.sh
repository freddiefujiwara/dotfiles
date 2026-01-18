#!/usr/bin/env bash

# Stop the script if an error occurs
set -euo pipefail

# --- Settings ---
# URL for the API (Use default if not set)
BASE_URL=${BASE_URL:-"https://room.rakuten.co.jp/api"}

# Target User ID (override with first CLI arg)
USER_ID=${USER_ID:-""}

# The folder where files will be saved (override with second CLI arg)
WORK_DIR=${WORK_DIR:-""}

# --- Main Logic ---
run_process() {
  if [ -z "$USER_ID" ]; then
    echo "Error: USER_ID is required." >&2
    return 1
  fi

  if [ -z "$WORK_DIR" ]; then
    echo "Error: WORK_DIR is required." >&2
    return 1
  fi
  # Check if the folder exists
  if [ ! -d "$WORK_DIR" ]; then
    echo "Error: Folder $WORK_DIR does not exist." >&2
    return 1
  fi

  # Go to the working folder
  cd "$WORK_DIR"

  # Delete old JSON files to start fresh
  rm -f ./*.json

  # Step 1: Download the list of collections
  curl -s "${BASE_URL}/${USER_ID}/collections" -o collections.json

  # Check if the file exists
  if [ -f collections.json ]; then
    # Loop through each collection
    jq -c '.data[]' collections.json | while read -r collection; do
      # Get ID and Name
      collection_id=$(echo "$collection" | jq -r '.id')
      genre=$(echo "$collection" | jq -r '.name')

      # Show the info
      echo "Genre: ${genre} (collection_id=${collection_id})"

      # Step 2: Download items for this collection (limit 100)
      curl -s "${BASE_URL}/${collection_id}/collects?limit=100" -o "collects_${collection_id}.json"

      # Check if the item file exists
      if [ -f "collects_${collection_id}.json" ]; then
        # Loop through each item
        jq -c '.data[]' "collects_${collection_id}.json" | while read -r collect; do

          # Get the item ID
          collect_id=$(echo "$collect" | jq -r '.id // empty')

          # Show the item ID
          echo "  Collect ID: ${collect_id}"
        done
      fi
    done
  fi
}

# --- Execution ---
# Run the function only if this script is executed directly
# (This allows the script to be tested without running immediately)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ge 1 ]]; then
    USER_ID=$1
  fi
  if [[ $# -ge 2 ]]; then
    WORK_DIR=$2
  fi
  run_process
fi
