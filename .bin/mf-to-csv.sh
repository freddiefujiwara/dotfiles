#!/usr/bin/env bash
set -euo pipefail

# 使い方:
#   cat input.json | ./json_to_csv.sh
#   cat input.json | ./json_to_csv.sh outdir
#
# 出力:
#   ./breakdown.csv
#   ./assetClassRatio.csv
#   ./details__<id>__t<index>.csv   (detailsはid+テーブルindexで分割)

OUTDIR="${1:-.}"
mkdir -p "$OUTDIR"

# stdinは1回しか読めないので保存
TMP="$(mktemp)"
cat > "$TMP"

JQ_COMMON='
  # 数値っぽい文字列だけ数値化して、それ以外はそのまま返す
  # 対象例: "9,856円" "12.22%" "1,082マイル" "250ポイント" "1,257" "-9,900円" "111.42"
  def norm:
    if . == null then null
    elif type == "number" then .
    elif type == "string" then
      . as $orig
      | (gsub(",";"")) as $s
      | if ($s | test("^-?[0-9]+(\\.[0-9]+)?(円|%|ポイント|マイル)?$")) then
          # 数字部分だけ取り出して数値化
          ($s | sub("(円|%|ポイント|マイル)$";"") | tonumber)
        else
          $orig
        end
    else
      .
    end;

  # CSV列のための安全なファイル名
  def safe:
    gsub("[/\\\\:*?\\\"<>|]";"_") | gsub("[\\r\\n\\t]";" ");
'

#################################
# 1) breakdown.csv
#################################
jq -r "$JQ_COMMON
  [\"timestamp\",\"category\",\"amount_text_num\",\"amount_yen\",\"percentage_text_num\",\"percentage\"],
  (.timestamp as \$ts
   | .breakdown[]
   | [\$ts, .category, (.amount_text|norm), .amount_yen, (.percentage_text|norm), .percentage]
  )
  | @csv
" "$TMP" > "$OUTDIR/breakdown.csv"

#################################
# 2) assetClassRatio.csv
#################################
jq -r "$JQ_COMMON
  [\"timestamp\",\"name\",\"y\",\"color\"],
  (.timestamp as \$ts
   | .assetClassRatio[]
   | [\$ts, .name, .y, .color]
  )
  | @csv
" "$TMP" > "$OUTDIR/assetClassRatio.csv"

#################################
# 3) details（id + table_indexごとにCSV）
#    - headers を優先（JSONに headers があるので、その順序で列を固定）
#    - ただし headers が無い/不足の可能性も考慮し、items のキーも追加してユニーク化
#################################
jq -r "$JQ_COMMON
  .timestamp as \$ts
  | .details[]
  | .id as \$id
  | .category as \$cat
  | .tables
  | to_entries[] as \$t
  | (\$t.key) as \$tidx
  | (\$t.value.headers // []) as \$hdr
  | (\$t.value.items // []) as \$items
  | (\$items | map(keys) | add | unique) as \$item_keys
  | (\$hdr + (\$item_keys - \$hdr)) as \$cols   # headers優先で列順を作る
  | (\"__FILE__=\" + (\$id|safe) + \"__t\" + (\$tidx|tostring)),
    ([\"timestamp\",\"detail_id\",\"category\",\"table_index\"] + \$cols | @csv),
    (\$items[]
     | . as \$row
     | ([\$ts, \$id, \$cat, \$tidx]
        + (\$cols | map(\$row[.]? | norm))
       )
     | @csv
    )
" "$TMP" | awk -v outdir="$OUTDIR" '
  BEGIN { file=""; }
  /^__FILE__=/ {
    file = outdir "/details__" substr($0,10) ".csv";
    next;
  }
  { if (file != "") print >> file; }
'

rm -f "$TMP"
echo "CSV generated in: $OUTDIR"
echo " - $OUTDIR/breakdown.csv"
echo " - $OUTDIR/assetClassRatio.csv"
echo " - $OUTDIR/details__*.csv"
