#!/usr/bin/env bash
set -euo pipefail

# mfcf-to-rss.sh
# Usage:
#   ./mfcf-to-rss.sh input.json > feed.xml
#   cat input.json | ./mfcf-to-rss.sh > feed.xml
#
# Env vars:
#   MFCF_YEAR: year for item pubDates. Transaction dates carry no year
#              (MM/DD only), so the caller passes the target month's year.
#              Defaults to the current year.

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

# Fail before printing anything when the payload does not have the
# expected shape; a half-written feed must never reach the caller.
if ! jq -e '.transactions | type == "array"' "$INPUT" >/dev/null; then
  echo "Error: input JSON must be an object with a 'transactions' array." >&2
  exit 1
fi

# RSS basics (override with env vars if needed)
CHANNEL_TITLE="${CHANNEL_TITLE:-Transactions Feed}"
CHANNEL_LINK="https://moneyforward.com/cf"
CHANNEL_DESC="${CHANNEL_DESC:-Converted from JSON transactions}"

# Convert JSON timestamp (ISO8601) to RFC822 for RSS (keep raw if it fails)
timestamp_iso="$(jq -r '.timestamp // empty' "$INPUT")"
if [[ -n "${timestamp_iso}" ]]; then
  # Try macOS (BSD date) and Linux (GNU date)
  if pubdate="$(LC_ALL=C TZ=UTC date -u -d "$timestamp_iso" "+%a, %d %b %Y %H:%M:%S +0000" 2>/dev/null)"; then
    :
  elif pubdate="$(LC_ALL=C TZ=UTC date -u -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp_iso%%.*}" "+%a, %d %b %Y %H:%M:%S +0000" 2>/dev/null)"; then
    :
  else
    pubdate="$timestamp_iso"
  fi
else
  pubdate="$(LC_ALL=C TZ=UTC date -u "+%a, %d %b %Y %H:%M:%S +0000")"
fi

format_rfc822_from_iso() {
  local iso="$1"
  if formatted="$(LC_ALL=C TZ=UTC date -u -d "$iso" "+%a, %d %b %Y %H:%M:%S +0000" 2>/dev/null)"; then
    printf '%s' "$formatted"
    return
  fi
  if formatted="$(LC_ALL=C TZ=UTC date -u -j -f "%Y-%m-%dT%H:%M:%S" "$iso" "+%a, %d %b %Y %H:%M:%S +0000" 2>/dev/null)"; then
    printf '%s' "$formatted"
    return
  fi
  printf '%s' "$iso"
}

mfcf_date_is_real() {
  # $1: a transaction date like "01/23(金)". Returns success only when
  # the MM/DD part forms a real calendar date in the MFCF_YEAR year;
  # non-existent dates (02/30, month 13, ...) must never be published.
  local date_str="$1" month day year max_day
  if [[ ! "$date_str" =~ ^([0-9]{2})/([0-9]{2}) ]]; then
    return 1
  fi
  month=$((10#${BASH_REMATCH[1]}))
  day=$((10#${BASH_REMATCH[2]}))
  year="${MFCF_YEAR:-$(date "+%Y")}"
  case "$month" in
    1|3|5|7|8|10|12) max_day=31 ;;
    4|6|9|11) max_day=30 ;;
    2)
      if (( year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) )); then
        max_day=29
      else
        max_day=28
      fi
      ;;
    *) return 1 ;;
  esac
  (( day >= 1 && day <= max_day ))
}

pubdate_from_mfcf_date() {
  local date_str="$1"
  local year month day iso
  if [[ "$date_str" =~ ^([0-9]{2})/([0-9]{2}) ]]; then
    month="${BASH_REMATCH[1]}"
    day="${BASH_REMATCH[2]}"
    year="${MFCF_YEAR:-$(date "+%Y")}"
    iso="${year}-${month}-${day}T00:00:00"
    format_rfc822_from_iso "$iso"
    return
  fi
  printf '%s' "$date_str"
}

strip_xml_controls() {
  # XML 1.0 forbids C0 control characters other than tab/LF/CR; a stray
  # control byte in source text would corrupt the whole feed.
  printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037'
}

xml_escape() {
  # Simple XML escape in bash
  local s="$1"
  s="$(strip_xml_controls "$s")"
  # Normalize common malformed entity placeholders.
  s="${s//&lt;/<}"
  s="${s//&gt;/>}"
  s="${s//<lt;/<}"
  s="${s//>gt;/>}"
  s="${s//&/\&amp;}"
  s="${s//</\&lt;}"
  s="${s//>/\&gt;}"
  s="${s//\"/\&quot;}"
  s="${s//\'/\&apos;}"
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
jq -c '.transactions[] | select(type == "object")' "$INPUT" | while IFS= read -r tx; do
  date_str="$(jq -r '.date // ""' <<<"$tx")"
  if ! mfcf_date_is_real "$date_str"; then
    echo "Warning: skipping transaction with invalid date: $date_str" >&2
    continue
  fi
  content="$(jq -r '.content // ""' <<<"$tx")"
  amount="$(jq -r '.amount_yen | if type == "number" and . == floor then tostring else empty end' <<<"$tx")"
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
  desc="$(strip_xml_controls "$desc")"
  # A field containing "]]>" would break out of the CDATA section below
  # and inject raw markup into the published feed; split it the standard
  # way so the text survives as data.
  desc="$(printf "%s" "$desc" | sed 's/]]>/]]]]><![CDATA[>/g')"

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

