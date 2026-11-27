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

# Escape a single value for XML output (also strips the C0 control
# characters XML 1.0 forbids, so source text cannot corrupt the feed).
xml_escape_text() {
  jq -nr --arg s "$1" '$s
    | gsub("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]"; "")
    | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("'"'"'"; "&apos;")
  '
}

# Like xml_escape_text, but renders line breaks as <br/> for the
# HTML-ish body copies.
xml_escape_html() {
  jq -nr --arg s "$1" '$s
    | gsub("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]"; "")
    | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("'"'"'"; "&apos;")
    | gsub("\r\n|\n|\r"; "<br/>")
  '
}

# Build RSS items with jq. We pass pubDate in after converting in bash (portable).
# The conversion runs before anything is printed, so deformed input
# fails without emitting a partial feed.
ROWS="$(jq -r '
  def obj: if type == "object" then . else {} end;

  .tweets
  | if type == "array" then . else error("tweets must be an array") end
  | map(select(type == "object"))
  | sort_by(.createdAt) | reverse
  | map({
      id: (.id // ""),
      title: (((.author | obj).name // "") + " (@" + ((.author | obj).username // "") + ")"),
      author_name: ((.author | obj).name // ""),
      author_user: ((.author | obj).username // ""),
      text: (.text // ""),
      createdAt: (.createdAt // "")
    })
' "$JSON_FILE" \
| jq -c '.[]')"

# Channel metadata is used as both XML text and an attribute.
esc_feed_title="$(xml_escape_text "$FEED_TITLE")"
esc_feed_link="$(xml_escape_text "$FEED_LINK")"
esc_feed_desc="$(xml_escape_text "$FEED_DESC")"

{
  # RSS header
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>${esc_feed_title}</title>
    <link>${esc_feed_link}</link>
    <description>${esc_feed_desc}</description>
    <language>ja</language>
    <atom:link href="${esc_feed_link}" rel="self" type="application/rss+xml" />
EOF

  # Items
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    id="$(jq -r '.id' <<<"$row")"
    title="$(jq -r '.title' <<<"$row")"
    author_name="$(jq -r '.author_name' <<<"$row")"
    author_user="$(jq -r '.author_user' <<<"$row")"
    text="$(jq -r '.text' <<<"$row")"
    createdAt="$(jq -r '.createdAt' <<<"$row")"

    link="https://x.com/${author_user}/status/${id}"
    guid="$link"
    pubDate="$(to_rfc822 "$createdAt")"

    # XML-escape title/author/link; put content in CDATA (still safe for most readers)
    esc_title="$(xml_escape_text "$title")"
    esc_author="$(xml_escape_text "$author_name")"
    esc_author_user="$(xml_escape_text "$author_user")"
    esc_link="$(xml_escape_text "$link")"
    esc_pubdate="$(xml_escape_text "$pubDate")"
    # Make HTML-ish content: keep line breaks as <br/>
    html_body="$(xml_escape_html "$text")"

    cat <<EOF
    <item>
      <title>${esc_title}</title>
      <link>${esc_link}</link>
      <guid isPermaLink="true">${esc_link}</guid>
      <pubDate>${esc_pubdate}</pubDate>
      <author>${esc_author}</author>
      <description><![CDATA[${html_body}]]></description>
      <content:encoded><![CDATA[
        <p><strong>${esc_author}</strong> (@${esc_author_user})</p>
        <p>${html_body}</p>
        <p><a href="${esc_link}">${esc_link}</a></p>
      ]]></content:encoded>
    </item>
EOF
  done

  # RSS footer
  cat <<EOF
  </channel>
</rss>
EOF
} <<<"$ROWS"
