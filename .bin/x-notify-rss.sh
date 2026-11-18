#!/usr/bin/env bash
set -euo pipefail

# 入力ファイルの定義
INPUT_FILE="${1:-/dev/stdin}"

# 現在の時刻をRFC 822形式（RSS標準）で取得
PUB_DATE=$(date -R)

# XMLのヘッダー部分を生成
cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:xn="https://freddiefujiwara.com/ns/x-notify">
<channel>
  <title>Twitter Notifications (Converted)</title>
  <link>https://twitter.com/</link>
  <description>RSS feed generated from notify.json</description>
  <pubDate>$PUB_DATE</pubDate>
  <lastBuildDate>$PUB_DATE</lastBuildDate>
EOF

# jqを使用して各通知アイテムをXMLの<item>タグに変換
# 1. .[] で配列を展開
# 2. select(.tweet != null) でツイート情報があるものに限定
# 3. 必要な情報を抽出して整形
# guid は X の entryId（再発行で変わる）を使わず、種別・行為者・ツイートIDから組み立てる
# pubDate はツイートの createdAt（Twitter形式）を RFC 822 形式へ変換する（x-to-rss.sh と同等、UTC表記）
jq -r 'def cdata: gsub("]]>"; "]]]]><![CDATA[>");
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;");
  def rfc822: . as $s | try (strptime("%a %b %d %H:%M:%S %z %Y") | strftime("%a, %d %b %Y %H:%M:%S +0000")) catch $s;
  .[] | select(.tweet != null) | 
  "<item>\n" +
  "  <title><![CDATA[" + ((.actors[0].name // "Unknown") | cdata) + " (@" + (.actors[0].username // "unknown") + ") - " + .kind + "]]></title>\n" +
  "  <link>https://twitter.com/" + .tweet.author.username + "/status/" + .tweet.id + "</link>\n" +
  "  <description><![CDATA[" + (.tweet.text | cdata) + "]]></description>\n" +
  "  <pubDate>" + (.tweet.createdAt | rfc822) + "</pubDate>\n" +
  "  <guid isPermaLink=\"false\">" + "x-notify-" + (.kind // "unknown") + "-" + (.actors[0].username // "unknown") + "-" + .tweet.id + "</guid>\n" +
  "  <xn:kind>" + ((.kind // "unknown") | esc) + "</xn:kind>\n" +
  ((.actors // []) | map("  <xn:actor username=\"" + ((.username // "unknown") | esc) + "\">" + ((.name // "Unknown") | esc) + "</xn:actor>\n") | join("")) +
  "  <xn:tweet-id>" + .tweet.id + "</xn:tweet-id>\n" +
  "  <xn:message>" + ((.message // "") | esc) + "</xn:message>\n" +
  "</item>"' "$INPUT_FILE"

# XMLのフッターを閉じる
echo "</channel></rss>"
