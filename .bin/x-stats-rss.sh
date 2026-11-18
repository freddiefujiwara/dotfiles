#!/usr/bin/env bash
set -euo pipefail

# 入力ファイルの定義
INPUT_FILE="${1:-/dev/stdin}"

# 現在の時刻をRFC 822形式（RSS標準）で取得
PUB_DATE=$(date -R)

# XMLのヘッダー部分を生成
cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:xs="https://freddiefujiwara.com/ns/x-stats">
<channel>
EOF

# jqを使用してチャンネル情報と各投稿をXMLに変換
# チャンネルには拡張要素で username / followers / following / collected-at を出す
# item の拡張要素（views / likes / reposts / replies）は、値が null の指標は
# 要素ごと省略する（0 は実測値としてそのまま出す）
jq -r --arg pubdate "$PUB_DATE" 'def cdata: gsub("]]>"; "]]]]><![CDATA[>");
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;");
  def rfc822: . as $s | try (sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%a, %d %b %Y %H:%M:%S +0000")) catch $s;
  def num: if . == null then "" else tostring end;
  def metric($name; $v): if $v == null then "" else "  <xs:" + $name + ">" + ($v | tostring) + "</xs:" + $name + ">\n" end;
  .x as $x |
  "  <title>X Stats (@" + ($x.username | esc) + ")</title>\n" +
  "  <link>https://twitter.com/" + ($x.username | esc) + "</link>\n" +
  "  <description>RSS feed generated from stats.json</description>\n" +
  "  <pubDate>" + $pubdate + "</pubDate>\n" +
  "  <lastBuildDate>" + $pubdate + "</lastBuildDate>\n" +
  "  <xs:username>" + ($x.username | esc) + "</xs:username>\n" +
  "  <xs:followers>" + ($x.followers | num) + "</xs:followers>\n" +
  "  <xs:following>" + ($x.following | num) + "</xs:following>\n" +
  "  <xs:collected-at>" + ((.collected_at // "") | esc) + "</xs:collected-at>\n" +
  (($x.recent_posts // []) | map(
    "<item>\n" +
    "  <title><![CDATA[" + ((.text // "") | cdata) + "]]></title>\n" +
    "  <link>https://twitter.com/" + ($x.username | esc) + "/status/" + .id + "</link>\n" +
    "  <description><![CDATA[" + ((.text // "") | cdata) + "]]></description>\n" +
    "  <pubDate>" + (.posted_at | rfc822) + "</pubDate>\n" +
    "  <guid isPermaLink=\"false\">" + .id + "</guid>\n" +
    metric("views"; .views) +
    metric("likes"; .likes) +
    metric("reposts"; .reposts) +
    metric("replies"; .replies) +
    "</item>") | join("\n") | if . == "" then "" else . + "\n" end)' "$INPUT_FILE"

# XMLのフッターを閉じる
echo "</channel></rss>"
