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

# RSS基本情報（必要なら環境変数で上書き可）
CHANNEL_TITLE="${CHANNEL_TITLE:-Transactions Feed}"
CHANNEL_LINK="${CHANNEL_LINK:-https://example.invalid/transactions}"
CHANNEL_DESC="${CHANNEL_DESC:-Converted from JSON transactions}"

# JSONのtimestamp（ISO8601）をRFC822相当にしてRSSに載せる（失敗したらそのまま）
timestamp_iso="$(jq -r '.timestamp // empty' "$INPUT")"
if [[ -n "${timestamp_iso}" ]]; then
  # macOS(BSD date) / Linux(GNU date) 両対応を試みる
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

xml_escape() {
  # XMLエスケープ（bashのみで簡易対応）
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
  # 3桁区切り
  local with_commas
  with_commas="$(printf "%'d" "$abs" 2>/dev/null || echo "$abs")"
  printf "%s¥%s" "$sign" "$with_commas"
}

# RSS出力開始
cat <<RSS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>$(xml_escape "$CHANNEL_TITLE")</title>
    <link>$(xml_escape "$CHANNEL_LINK")</link>
    <description>$(xml_escape "$CHANNEL_DESC")</description>
    <lastBuildDate>$(xml_escape "$pubdate")</lastBuildDate>
RSS_EOF

# transactions を item にする（amount_yen=nullにも対応）
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

  # title: "01/23(金) +¥61,000 振込 フジワラ フミカズ"
  item_title="$(printf "%s %s %s" "$date_str" "$amount_disp" "$content" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"

  # description はCDDATAにして日本語や記号を安全に
  desc_lines=()
  desc_lines+=("date: $date_str")
  [[ -n "$amount_disp" ]] && desc_lines+=("amount: $amount_disp")
  [[ -n "$account" ]] && desc_lines+=("account: $account")
  [[ -n "$cat_main$cat_sub" ]] && desc_lines+=("category: ${cat_main}${cat_main:+/}${cat_sub}")
  desc_lines+=("is_transfer: $is_transfer")
  [[ -n "$memo" ]] && desc_lines+=("memo: $memo")

  desc="$(printf "%s\n" "${desc_lines[@]}")"

  # guid は内容+日付+金額のハッシュ風（完全ユニークでなくてもOK）
  guid_src="$(printf "%s|%s|%s" "$date_str" "$content" "${amount:-null}")"
  guid="$(printf "%s" "$guid_src" | jq -sRr @uri)"

  cat <<RSS_EOF
    <item>
      <title>$(xml_escape "$item_title")</title>
      <guid isPermaLink="false">$(xml_escape "$guid")</guid>
      <description><![CDATA[$desc]]></description>
    </item>
RSS_EOF
done

# RSS出力終了
cat <<'RSS_EOF'
  </channel>
</rss>
RSS_EOF
