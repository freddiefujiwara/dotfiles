#!/usr/bin/env bash
# playwright-mf watchdog (added 2026-11-06): alert when the daily outputs are missing or stale.
FEED=/usr/share/nginx/a.ze.gs/mfcf.xml
CSV=$HOME/gd/API/assets/breakdown.csv
PROBLEMS=""
TODAY=$(date +%F)
[ "$(date -r $FEED +%F 2>/dev/null)" = "$TODAY" ] || PROBLEMS="$PROBLEMS feed-not-updated;"
ITEMS=$(grep -c "<item>" $FEED 2>/dev/null)
ITEMS=${ITEMS:-0}
[ "$ITEMS" -ge 1 ] || PROBLEMS="$PROBLEMS feed-has-0-items;"
[ "$(date -r $CSV +%F 2>/dev/null)" = "$TODAY" ] || PROBLEMS="$PROBLEMS csv-not-updated;"
# Monthly archives (added 2026-11-10): the last 8 months (current month
# included) must all exist, be updated today, hold at least one item, and
# contain dates of their own month only.
for i in 0 1 2 3 4 5 6 7; do
  ym=$(date -d "$i months ago" +%Y%m)
  f=$HOME/gd/API/assets/mfcf.$ym.xml
  if [ ! -f "$f" ]; then
    PROBLEMS="$PROBLEMS mfcf-$ym-missing;"
    continue
  fi
  [ "$(date -r "$f" +%F 2>/dev/null)" = "$TODAY" ] || PROBLEMS="$PROBLEMS mfcf-$ym-not-updated;"
  n=$(grep -c "<item>" "$f" 2>/dev/null)
  n=${n:-0}
  [ "$n" -ge 1 ] || PROBLEMS="$PROBLEMS mfcf-$ym-has-0-items;"
  mon=$(LC_TIME=C date -d "$i months ago" +%b)
  yr=${ym:0:4}
  total=$(grep -o "<pubDate>[^<]*</pubDate>" "$f" 2>/dev/null | wc -l)
  own=$(grep -o "<pubDate>[^<]* $mon $yr [^<]*</pubDate>" "$f" 2>/dev/null | wc -l)
  if [ "$total" -gt 0 ] && [ "$total" != "$own" ]; then
    PROBLEMS="$PROBLEMS mfcf-$ym-date-mismatch($own/$total);"
  fi
done
if [ -n "$PROBLEMS" ]; then
  {
    echo "To: zegenvs@gmail.com"
    echo "Subject: [ze] playwright-mf watchdog alert"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo ""
    echo "Problems:$PROBLEMS"
    date
  } | /usr/sbin/sendmail -t
  echo "$(date) alert:$PROBLEMS" >> ~/.playwright-mf-watchdog.log
fi
