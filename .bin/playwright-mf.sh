#!/usr/bin/env bash
set -euo pipefail
# 1. PATHにmiseを追加（これで絶対パスが不要になります）
export PATH="/home/fumikazu/.local/share/mise/shims:/home/fumikazu/.local/bin:$PATH"

# 2. スクリプト全体の出力をログに回す（各行の >> ~/.playwright-mf.log 2>&1 が不要になります）
exec >> ~/.playwright-mf.log 2>&1
# --- failure notification (added 2026-11-06) ---
notify_failure() {
  rc=$?
  if [ $rc -ne 0 ]; then
    {
      echo "To: zegenvs@gmail.com"
      echo "Subject: [ze] playwright-mf FAILED rc=$rc"
      echo "Content-Type: text/plain; charset=UTF-8"
      echo ""
      echo "playwright-mf.sh failed (rc=$rc)"
      date
      echo "--- last 40 lines of log ---"
      tail -n 40 ~/.playwright-mf.log
    } | /usr/sbin/sendmail -t
  fi
}
trap notify_failure EXIT

rm -f ~/gd/API/assets/*.csv
# 月別XMLは最初に消さない（途中で失敗すると過去月が空になるため）。
# 各月は生成に成功した時点で差し替え、古いものは後段で掃除する。

cd /tmp
rm -rf playwright-mf
git clone https://github.com/freddiefujiwara/playwright-mf.git
cd playwright-mf

npm i
npx playwright install chromium  # added 2026-11-06: keep browser binaries in sync

# アカウント更新
node accounts-update.js 'SBI証券'
node accounts-update.js '大和証券'
node accounts-update.js 'マネックス証券'
node accounts-update.js '楽天証券@freddie'
node accounts-update.js '楽天証券@aojiru.pudding'
node accounts-update.js '楽天証券@chipop'
node accounts-update.js 'イオンカード@chipop'
node accounts-update.js 'イオンカード@freddie'
node accounts-update.js '楽天カード@freddie'
node accounts-update.js '楽天カード@chipop'
node accounts-update.js 'iPhone PASMO@freddie'

sleep 60

node bs-portfolio.js | ~/.bin/mf-to-csv.sh ~/gd/API/assets
node bs-liability.js | ~/.bin/mf-liability-to-csv.sh ~/gd/API/assets

# 入出金は「対象月を絶対指定」で取る。cf.js が見出しと明細の日付を検証し、
# 対象月と違う月は異常終了するので、ズレた月がそのまま保存されることはない。
node cf.js --month "$(date +%Y-%m)" | ~/.bin/mfcf-to-rss.sh > /tmp/mfcf.current.xml
cp /tmp/mfcf.current.xml /usr/share/nginx/a.ze.gs/mfcf.xml
cp /tmp/mfcf.current.xml ~/gd/API/assets/mfcf.$(date +%Y%m).xml

for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  ym=$(date -d "$i months ago" +%Y%m)
  node cf.js --month "$(date -d "$i months ago" +%Y-%m)" | ~/.bin/mfcf-to-rss.sh > /tmp/"mfcf.$ym.xml"
  mv /tmp/"mfcf.$ym.xml" ~/gd/API/assets/
done

# 対象ウィンドウ（当月含む13か月）より古い月別ファイルは残さない
cutoff=$(date -d '12 months ago' +%Y%m)
for f in ~/gd/API/assets/mfcf.[0-9]*.xml; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  ym=${base#mfcf.}
  ym=${ym%.xml}
  if [ "$ym" \< "$cutoff" ]; then
    rm -f "$f"
  fi
done

rm -rf playwright-mf

sleep 60
gas_url=$(cat ~/.config/playwright-mf/gas-url)
curl -sSL "$gas_url" | jq .
