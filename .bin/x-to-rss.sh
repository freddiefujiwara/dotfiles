#!/usr/bin/env bash
set -euo pipefail

# x-to-rss.sh
# Usage:
#   ./x-to-rss.sh tweets.json > feed.xml
# Requirements:
#   - jq
#   - (optional but recommended) date (GNU date preferred)

JSON_FILE="${1:-/dev/stdin}"

# Feed metadata (customize as you like)
FEED_TITLE="${FEED_TITLE:-Tweets JSON Feed}"
FEED_LINK="${FEED_LINK:-https://x.com/home}"
FEED_DESC="${FEED_DESC:-Converted from JSON to RSS 2.0}"

# Convert Twitter-style createdAt ("Sat Jan 17 03:39:29 +0000 2026") to RFC822.
# Tries GNU date; falls back to original string if parsing fails.
to_rfc822() {
  local s="$1"
  if date -u -d "$s" "+%a, %d %b %Y %H:%M:%S %z" >/dev/null 2>&1; then
    date -u -d "$s" "+%a, %d %b %Y %H:%M:%S %z"
  else
    # macOS/BSD date fallback attempt
    if date -u -j -f "%a %b %d %H:%M:%S %z %Y" "$s" "+%a, %d %b %Y %H:%M:%S %z" >/dev/null 2>&1; then
      date -u -j -f "%a %b %d %H:%M:%S %z %Y" "$s" "+%a, %d %b %Y %H:%M:%S %z"
    else
      echo "$s"
    fi
  fi
}

# Build RSS items with jq. We pass pubDate in after converting in bash (portable).
# Escape XML special chars safely in jq.
jq -r '
  def xesc:
    gsub("&"; "&amp;")
    | gsub("<"; "&lt;")
    | gsub(">"; "&gt;")
    | gsub("\""; "&quot;")
    | gsub("\u0027"; "&apos;");
  def brs: gsub("\r\n|\n|\r"; "<br/>");

  .tweets
  | sort_by(.createdAt) | reverse
  | map({
      id,
      title: (.author.name + " (@" + .author.username + ")"),
      author_name: .author.name,
      author_user: .author.username,
      text: .text,
      createdAt
    })
' "$JSON_FILE" \
| jq -c '.[]' \
| {
  # RSS header
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>${FEED_TITLE}</title>
    <link>${FEED_LINK}</link>
    <description>${FEED_DESC}</description>
    <language>ja</language>
    <atom:link href="${FEED_LINK}" rel="self" type="application/rss+xml" />
EOF

  # Items
  while IFS= read -r row; do
    id="$(jq -r '.id' <<<"$row")"
    title="$(jq -r '.title' <<<"$row")"
    author_name="$(jq -r '.author_name' <<<"$row")"
    author_user="$(jq -r '.author_user' <<<"$row")"
    text="$(jq -r '.text' <<<"$row")"
    createdAt="$(jq -r '.createdAt' <<<"$row")"

    link="https://x.com/${author_user}/status/${id}"
    guid="$link"
    pubDate="$(to_rfc822 "$createdAt")"

    # XML-escape title/author; put content in CDATA (still safe for most readers)
    esc_title="$(jq -nr --arg s "$title" '$s
      | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("\u0027"; "&apos;")
    ')"
    esc_author="$(jq -nr --arg s "$author_name" '$s
      | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("\u0027"; "&apos;")
    ')"
    # Make HTML-ish content: keep line breaks as <br/>
    html_body="$(jq -nr --arg s "$text" '$s
      | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("\u0027"; "&apos;")
      | gsub("\r\n|\n|\r"; "<br/>")
    ')"

    cat <<EOF
    <item>
      <title>${esc_title}</title>
      <link>${link}</link>
      <guid isPermaLink="true">${guid}</guid>
      <pubDate>${pubDate}</pubDate>
      <author>${esc_author}</author>
      <description><![CDATA[${html_body}]]></description>
      <content:encoded><![CDATA[
        <p><strong>${esc_author}</strong> (@${author_user})</p>
        <p>${html_body}</p>
        <p><a href="${link}">${link}</a></p>
      ]]></content:encoded>
    </item>
EOF
  done

  # RSS footer
  cat <<EOF
  </channel>
</rss>
EOF
}
