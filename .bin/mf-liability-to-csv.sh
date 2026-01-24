#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cat input.json | ./mf-liability-to-csv.sh
#   cat input.json | ./mf-liability-to-csv.sh outdir
#
# Output:
#   ./total-liability.csv
#   ./breakdown-liability.csv
#   ./details__<id>__t<index>-liability.csv

OUTDIR="${1:-.}"
mkdir -p "$OUTDIR"

TMP="$(mktemp)"
cat > "$TMP"

JQ_COMMON='
  def norm:
    if . == null then null
    elif type == "number" then .
    elif type == "string" then
      . as $orig
      | (gsub(",";"")) as $s
      | if ($s | test("^-?[0-9]+(\\.[0-9]+)?(円|%|ポイント|マイル)?$")) then
          ($s | sub("(円|%|ポイント|マイル)$";"") | tonumber)
        else
          $orig
        end
    else
      .
    end;

  def safe:
    gsub("[/\\\\:*?\\\"<>|]";"_") | gsub("[\\r\\n\\t]";" ");
'

#################################
# 0) total-liability.csv
#################################
jq -r "$JQ_COMMON
  [\"timestamp\",\"total_text_num\",\"total_yen\"],
  (.timestamp as \$ts
   | [\$ts, (.total.total_text|norm), .total.total_yen]
  )
  | @csv
" "$TMP" > "$OUTDIR/total-liability.csv"

#################################
# 1) breakdown-liability.csv
#################################
jq -r "$JQ_COMMON
  [\"timestamp\",\"category\",\"amount_text_num\",\"amount_yen\",\"percentage_text_num\",\"percentage\"],
  (.timestamp as \$ts
   | (.breakdown // [])[]
   | [\$ts, .category, (.amount_text|norm), .amount_yen, (.percentage_text|norm), .percentage]
  )
  | @csv
" "$TMP" > "$OUTDIR/breakdown-liability.csv"

#################################
# 2) details__*-liability.csv
#################################
rm -f "$OUTDIR"/details__*-liability.csv 2>/dev/null || true

jq -r "$JQ_COMMON
  .timestamp as \$ts
  | (.details // [])[]
  | .id as \$id
  | .category as \$cat
  | (.tables // [])
  | to_entries[] as \$t
  | (\$t.key) as \$tidx
  | (\$t.value.headers // []) as \$hdr
  | (\$t.value.items // []) as \$items
  | (\$items | map(keys) | add // [] | unique) as \$item_keys
  | (\$hdr + (\$item_keys - \$hdr)) as \$cols
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
    file = outdir "/details__" substr($0,10) "-liability.csv";
    system("rm -f \"" file "\"");
    next;
  }
  { if (file != "") print >> file; }
'

rm -f "$TMP"

echo "CSV generated in: $OUTDIR"
echo " - $OUTDIR/total-liability.csv"
echo " - $OUTDIR/breakdown-liability.csv"
echo " - $OUTDIR/details__*-liability.csv"
