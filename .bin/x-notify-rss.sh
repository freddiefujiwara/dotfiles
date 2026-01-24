#!/bin/bash

# 入力ファイルの定義
INPUT_FILE="${1:-/dev/stdin}"

# 現在の時刻をRFC 822形式（RSS標準）で取得
PUB_DATE=$(date -R)

# XMLのヘッダー部分を生成
cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
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
jq -r '.[] | select(.tweet != null) | 
  "<item>\n" +
  "  <title><![CDATA[" + (.actors[0].name // "Unknown") + " (@" + (.actors[0].username // "unknown") + ") - " + .kind + "]]></title>\n" +
  "  <link>https://twitter.com/" + .tweet.author.username + "/status/" + .tweet.id + "</link>\n" +
  "  <description><![CDATA[" + .tweet.text + "]]></description>\n" +
  "  <pubDate>" + .tweet.createdAt + "</pubDate>\n" +
  "  <guid isPermaLink=\"false\">" + .id + "</guid>\n" +
  "</item>"' "$INPUT_FILE"

# XMLのフッターを閉じる
echo "</channel></rss>"
