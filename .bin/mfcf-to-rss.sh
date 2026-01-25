#!/usr/bin/env bash
set -euo pipefail

# mfcf-to-rss.sh
# Usage:
#   ./mfcf-to-rss.sh input.json > feed.xml
#   cat input.json | ./mfcf-to-rss.sh > feed.xml

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: '$1' is required." >&2
    exit 1
  }
}

require_cmd jq

INPUT="${1:-/dev/stdin}"
TMP_INPUT=""
if [[ "$INPUT" == "/dev/stdin" ]]; then
  TMP_INPUT="$(mktemp)"
  trap 'rm -f "$TMP_INPUT"' EXIT
  cat > "$TMP_INPUT"
  INPUT="$TMP_INPUT"
fi

# RSS basics (override with env vars if needed)
CHANNEL_TITLE="${CHANNEL_TITLE:-Transactions Feed}"
CHANNEL_LINK="https://moneyforward.com/cf"
CHANNEL_DESC="${CHANNEL_DESC:-Converted from JSON transactions}"

# Convert JSON timestamp (ISO8601) to RFC822 for RSS (keep raw if it fails)
timestamp_iso="$(jq -r '.timestamp // empty' "$INPUT")"
if [[ -n "${timestamp_iso}" ]]; then
  # Try macOS (BSD date) and Linux (GNU date)
  if pubdate="$(date -u -d "$timestamp_iso" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null)"; then
    :
  elif pubdate="$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp_iso%%.*}" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null)"; then
    :
  else
    pubdate="$timestamp_iso"
  fi
else
  pubdate="$(date -u "+%a, %d %b %Y %H:%M:%S %z")"
fi

format_rfc822_from_iso() {
  local iso="$1"
  if formatted="$(date -d "$iso" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null)"; then
    printf '%s' "$formatted"
    return
  fi
  if formatted="$(date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null)"; then
    printf '%s' "$formatted"
    return
  fi
  printf '%s' "$iso"
}

pubdate_from_mfcf_date() {
  local date_str="$1"
  local year month day iso
  if [[ "$date_str" =~ ^([0-9]{2})/([0-9]{2}) ]]; then
    month="${BASH_REMATCH[1]}"
    day="${BASH_REMATCH[2]}"
    year="$(date "+%Y")"
    iso="${year}-${month}-${day}T00:00:00"
    format_rfc822_from_iso "$iso"
    return
  fi
  printf '%s' "$date_str"
}

xml_escape() {
  # Simple XML escape in bash
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "$s"
}

money_fmt() {
  # -550 -> "-¥550", 30000 -> "+¥30,000"
  local n="$1"
  if [[ "$n" == "null" || -z "$n" ]]; then
    printf '%s' ""
    return
  fi
  local sign="+"
  if [[ "$n" =~ ^- ]]; then sign="-"; fi
  local abs="${n#-}"
  # Add thousands separators
  local with_commas
  with_commas="$(printf "%'d" "$abs" 2>/dev/null || echo "$abs")"
  printf "%s¥%s" "$sign" "$with_commas"
}

# Start RSS output
cat <<RSS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>$(xml_escape "$CHANNEL_TITLE")</title>
    <link>$(xml_escape "$CHANNEL_LINK")</link>
    <description>$(xml_escape "$CHANNEL_DESC")</description>
    <lastBuildDate>$(xml_escape "$pubdate")</lastBuildDate>
RSS_EOF

# Convert transactions to items (supports amount_yen=null)
jq -c '.transactions[]' "$INPUT" | while IFS= read -r tx; do
  date_str="$(jq -r '.date // ""' <<<"$tx")"
  content="$(jq -r '.content // ""' <<<"$tx")"
  amount="$(jq -r '.amount_yen // empty | tostring' <<<"$tx")"
  account="$(jq -r '.account // ""' <<<"$tx")"
  cat_main="$(jq -r '.category_main // ""' <<<"$tx")"
  cat_sub="$(jq -r '.category_sub // ""' <<<"$tx")"
  memo="$(jq -r '.memo // ""' <<<"$tx")"
  is_transfer="$(jq -r '.is_transfer // false' <<<"$tx")"

  amount_disp="$(money_fmt "${amount:-}")"
  item_pubdate="$(pubdate_from_mfcf_date "$date_str")"

  # title: "01/23(Fri) +¥61,000 Transfer Sample Taro"
  item_title="$(printf "%s %s %s" "$date_str" "$amount_disp" "$content" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"

  # Put description in CDATA for safe text
  desc_lines=()
  desc_lines+=("date: $date_str")
  [[ -n "$amount_disp" ]] && desc_lines+=("amount: $amount_disp")
  [[ -n "$account" ]] && desc_lines+=("account: $account")
  [[ -n "$cat_main$cat_sub" ]] && desc_lines+=("category: ${cat_main}${cat_main:+/}${cat_sub}")
  desc_lines+=("is_transfer: $is_transfer")
  [[ -n "$memo" ]] && desc_lines+=("memo: $memo")

  desc="$(printf "%s\n" "${desc_lines[@]}")"

  # guid uses content+date+amount (does not need to be perfectly unique)
  guid_src="$(printf "%s|%s|%s" "$date_str" "$content" "${amount:-null}")"
  guid="$(printf "%s" "$guid_src" | jq -sRr @uri)"

  cat <<RSS_EOF
    <item>
      <title>$(xml_escape "$item_title")</title>
      <pubDate>$(xml_escape "$item_pubdate")</pubDate>
      <link>$(xml_escape "$CHANNEL_LINK")</link>
      <guid isPermaLink="false">$(xml_escape "$guid")</guid>
      <description><![CDATA[$desc]]></description>
    </item>
RSS_EOF
done

# End RSS output
cat <<'RSS_EOF'
  </channel>
</rss>
RSS_EOF
