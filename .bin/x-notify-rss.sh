#!/usr/bin/env bash
set -euo pipefail

# 入力ファイルの定義
INPUT_FILE="${1:-/dev/stdin}"

# 現在の時刻をRFC 822形式（RSS標準）で取得
PUB_DATE=$(date -R)

# jqを使用して各通知アイテムをXMLの<item>タグに変換
# 1. .[] で配列を展開
# 2. tweet がオブジェクトでない通知は読み飛ばす
# 3. 必要な情報を抽出して整形
# guid は X の entryId（再発行で変わる）を使わず、種別・行為者・ツイートIDから組み立てる
# pubDate はツイートの createdAt（Twitter形式）を RFC 822 形式へ変換する（x-to-rss.sh と同等、UTC表記）
# 変換を先に済ませてからヘッダーを出すことで、入力が壊れていても
# 中途半端なフィードを書き出さない。
ITEMS="$(jq -r 'def txt: if type == "string" then . elif . == null then "" else tostring end;
  def arr: if type == "array" then . else [] end;
  def obj: if type == "object" then . else {} end;
  def clean: gsub("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]"; "");
  def cdata: txt | clean | gsub("]]>"; "]]]]><![CDATA[>");
  def esc: txt | clean | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;");
  def rfc822: txt | . as $s | try (strptime("%a %b %d %H:%M:%S %z %Y") | strftime("%a, %d %b %Y %H:%M:%S +0000")) catch $s;
  (if type == "array" then . elif (type == "object" and (.notifications | type == "array")) then .notifications else error("notify input must be an array or an object with a notifications array") end)
  | .[]
  | select(type == "object")
  | select(.tweet | type == "object")
  | ((.actors | arr)[0] // {}) as $a0
  | "<item>\n" +
  "  <title><![CDATA[" + (((($a0.name // "Unknown") | txt) + " (@" + (($a0.username // "unknown") | txt) + ") - " + (.kind | txt)) | cdata) + "]]></title>\n" +
  "  <link>https://twitter.com/" + ((.tweet.author | obj).username | txt) + "/status/" + (.tweet.id | txt) + "</link>\n" +
  "  <description><![CDATA[" + (.tweet.text | cdata) + "]]></description>\n" +
  "  <pubDate>" + (.tweet.createdAt | rfc822) + "</pubDate>\n" +
  "  <guid isPermaLink=\"false\">" + "x-notify-" + ((.kind // "unknown") | txt) + "-" + (($a0.username // "unknown") | txt) + "-" + (.tweet.id | txt) + "</guid>\n" +
  "  <xn:kind>" + ((.kind // "unknown") | esc) + "</xn:kind>\n" +
  ((.actors | arr) | map("  <xn:actor username=\"" + ((obj | .username // "unknown") | esc) + "\">" + ((obj | .name // "Unknown") | esc) + "</xn:actor>\n") | join("")) +
  "  <xn:tweet-id>" + (.tweet.id | txt) + "</xn:tweet-id>\n" +
  "  <xn:message>" + ((.message // "") | esc) + "</xn:message>\n" +
  "</item>"' "$INPUT_FILE")"

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

if [[ -n "$ITEMS" ]]; then
  printf '%s\n' "$ITEMS"
fi

# XMLのフッターを閉じる
echo "</channel></rss>"
