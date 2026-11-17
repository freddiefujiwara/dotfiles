#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/.bin/update-region-weights"
  DRIVER="$BATS_TEST_TMPDIR/driver.py"
  cat > "$DRIVER" <<'PYEOF'
import importlib.util
import sys
from importlib.machinery import SourceFileLoader

spec = importlib.util.spec_from_loader(
    "urw", SourceFileLoader("urw", sys.argv[1])
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

ACWI_TEXT = """MSCI ACWI Index (USD)
OCT 30, 2026 Index Factsheet
COUNTRY WEIGHTS
United States 64.63% Japan 5.08% Taiwan 3.23% United Kingdom 3.12%
"""
WORLD_TEXT = """MSCI World Index (USD)
OCT 30, 2026 Index Factsheet
COUNTRY WEIGHTS
United States 72.77% Japan 5.72% United Kingdom 3.52% Canada 3.44%
"""

mode = sys.argv[2]
if mode == "parse":
    print(mod.parse_factsheet(ACWI_TEXT))
    print(mod.parse_factsheet(WORLD_TEXT))
elif mode == "derive":
    sets = mod.derive(64.63, 5.08, 5.72)
    print(sets["acwi"]["emerging"], sets["acwi"]["developed_other"])
    print(sets["developed"]["us"], sets["developed"]["developed_other"])
elif mode == "csv":
    sets = mod.derive(64.63, 5.08, 5.72)
    sys.stdout.write(mod.build_csv(sets, "2026-10-30"))
elif mode == "reject":
    try:
        mod.derive(64.63, 5.72, 5.08)
    except mod.Fail:
        print("REJECTED")
    else:
        print("NOT_REJECTED")
PYEOF
}

@test "update-region-weights is syntactically valid python" {
  run python3 -m py_compile "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "update-region-weights uses the MSCI factsheet URLs" {
  run grep -F 'msci.com/documents/10199/dad48a28-fafb-4e4a-bfff-8ff7ddf9df90' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -F 'msci.com/documents/10199/255599/msci-world-index-usd-net.pdf' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "update-region-weights does not use the retired ishares endpoint" {
  run grep -c 'ishares.com' "$SCRIPT"
  [ "$output" = "0" ]
}

@test "update-region-weights parses factsheet date and country weights" {
  run python3 "$DRIVER" "$SCRIPT" parse
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "('2026-10-30', 64.63, 5.08)" ]
  [ "${lines[1]}" = "('2026-10-30', 72.77, 5.72)" ]
}

@test "update-region-weights derives the seed weights" {
  run python3 "$DRIVER" "$SCRIPT" derive
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "11.19 19.1" ]
  [ "${lines[1]}" = "77.19 22.81" ]
}

@test "update-region-weights rejects World Japan not exceeding ACWI Japan" {
  run python3 "$DRIVER" "$SCRIPT" reject
  [ "$status" -eq 0 ]
  [ "$output" = "REJECTED" ]
}

@test "update-region-weights builds the seed csv format" {
  run python3 "$DRIVER" "$SCRIPT" csv
  [ "$status" -eq 0 ]
  expected="weight_set,bucket,weight,effective_date
acwi,japan,5.08,2026-10-30
acwi,us,64.63,2026-10-30
acwi,developed_other,19.1,2026-10-30
acwi,emerging,11.19,2026-10-30
acwi,other,0,2026-10-30
developed,japan,0,2026-10-30
developed,us,77.19,2026-10-30
developed,developed_other,22.81,2026-10-30
developed,emerging,0,2026-10-30
developed,other,0,2026-10-30
emerging,japan,0,2026-10-30
emerging,us,0,2026-10-30
emerging,developed_other,0,2026-10-30
emerging,emerging,100,2026-10-30
emerging,other,0,2026-10-30"
  [ "$output" = "$expected" ]
}
