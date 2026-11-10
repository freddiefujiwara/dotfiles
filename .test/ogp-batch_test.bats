#!/usr/bin/env bats
# Tests for ogp-batch. No external network is used: SSRF-blocked URLs
# exercise the fetch path, and fresh cache entries exercise the skip
# path. OGP_HOME / OGP_PUBLISH_PATH are pointed at a temp directory.

setup() {
  export OGP_HOME="$BATS_TEST_TMPDIR/ogp-home"
  export OGP_PUBLISH_PATH="$BATS_TEST_TMPDIR/published/ogp-cache.json"
  mkdir -p "$OGP_HOME" "$(dirname "$OGP_PUBLISH_PATH")"
  BATCH="$(dirname "$BATS_TEST_FILENAME")/../.bin/ogp-batch"
}

seed_cache() { # $1 = url, $2 = status, $3 = age seconds
  python3 - "$OGP_HOME/cache.json" "$1" "$2" "$3" <<'PY'
import json, sys, time
path, url, status, age = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
entry = {"status": status, "fetchedAt": "2026-11-10T00:00:00+09:00",
         "_ts": time.time() - age}
if status == "ok":
    entry.update({"title": "cached", "image": None, "description": None})
json.dump({"version": 1, "entries": {url: entry}}, open(path, "w"))
PY
}

@test "queue is rotated away and the processing file is removed" {
  printf '1\thttps://example.com/a\n' > "$OGP_HOME/queue.tsv"
  seed_cache "https://example.com/a" ok 60
  run "$BATCH"
  [ "$status" -eq 0 ]
  [ ! -e "$OGP_HOME/queue.processing" ]
  [ -f "$OGP_HOME/queue.tsv" ]
  [ ! -s "$OGP_HOME/queue.tsv" ]
}

@test "fresh ok entries are skipped, not refetched" {
  printf '1\thttps://example.com/a\n' > "$OGP_HOME/queue.tsv"
  seed_cache "https://example.com/a" ok 60
  run "$BATCH"
  grep -q "skipped_fresh=1" "$OGP_HOME/batch.log"
  grep -q "fetched_ok=0" "$OGP_HOME/batch.log"
}

@test "duplicate queue lines are fetched only once" {
  printf '1\thttp://127.0.0.1/x\n2\thttp://127.0.0.1/x\n' > "$OGP_HOME/queue.tsv"
  run "$BATCH"
  grep -q "queued=1" "$OGP_HOME/batch.log"
}

@test "private-IP URLs are recorded as ssrf_blocked errors" {
  printf '1\thttp://127.0.0.1/x\n' > "$OGP_HOME/queue.tsv"
  run "$BATCH"
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
e = json.load(open(sys.argv[1]))["entries"]["http://127.0.0.1/x"]
assert e["status"] == "error" and e["error"] == "ssrf_blocked", e
' "$OGP_HOME/cache.json"
  [ "$status" -eq 0 ]
}

@test "published JSON strips internal keys" {
  printf '1\thttp://127.0.0.1/x\n' > "$OGP_HOME/queue.tsv"
  run "$BATCH"
  run python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
e = doc["entries"]["http://127.0.0.1/x"]
assert "_ts" not in e, e
assert doc["version"] == 1 and "generatedAt" in doc
' "$OGP_PUBLISH_PATH"
  [ "$status" -eq 0 ]
}

@test "recent error entries are skipped until the error TTL passes" {
  printf '1\thttp://127.0.0.1/x\n' > "$OGP_HOME/queue.tsv"
  seed_cache "http://127.0.0.1/x" error 60
  run "$BATCH"
  grep -q "skipped_fresh=1" "$OGP_HOME/batch.log"
}

@test "parser unescapes entities and picks up og tags" {
  run python3 - "$BATCH" <<'PY'
import importlib.machinery, sys
mod = importlib.machinery.SourceFileLoader("ogpb", sys.argv[1]).load_module()
p = mod.OgParser()
p.feed("""<html><head>
<meta property="og:title" content="食堂 多万里 (大宮/食堂)">
<meta property="og:image" content="https://tblg.example/r.jpg?token=a&amp;api=v2">
<title>fallback</title></head></html>""")
assert p.meta["og:title"] == "食堂 多万里 (大宮/食堂)", p.meta
assert p.meta["og:image"] == "https://tblg.example/r.jpg?token=a&api=v2", p.meta
PY
  [ "$status" -eq 0 ]
}

@test "public_only rejects local addresses and accepts public IPs" {
  run python3 - "$BATCH" <<'PY'
import importlib.machinery, sys
mod = importlib.machinery.SourceFileLoader("ogpb", sys.argv[1]).load_module()
assert mod.public_only("http://127.0.0.1/x") is False
assert mod.public_only("http://localhost/x") is False
assert mod.public_only("https://something.ze.gs/x") is False
assert mod.public_only("ftp://93.184.216.34/x") is False
assert mod.public_only("http://93.184.216.34/x") is True
PY
  [ "$status" -eq 0 ]
}
