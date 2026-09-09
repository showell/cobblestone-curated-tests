#!/usr/bin/env bash
# Run each unit and compare its output to the co-located .expected file.
#
#   ./run-interp.sh              # the Rust interpreter (codexrun)
#   ./run-interp.sh <binary>     # any compiler that takes a unit path on argv
#
# Output may land on stdout (codexrun) or stderr (a zig-plug binary); either
# one matching .expected is a pass.
set -u
BIN="${1:-$HOME/build/rust-target/release/codexrun}"
here=$(cd "$(dirname "$0")" && pwd)
pass=0; fail=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  exp="${u%.codex}.expected"
  o=$("$BIN" "$u" 2>/dev/null); e=$("$BIN" "$u" 2>&1 >/dev/null)
  want=$(cat "$exp")
  if [ "$o" = "$want" ] || [ "$e" = "$want" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    printf '%-32s FAIL  (out %d B, err %d B, want %d B)\n' \
      "$n" "${#o}" "${#e}" "${#want}"
  fi
done
printf '\n%d pass, %d fail, %d total\n' "$pass" "$fail" "$((pass+fail))"
[ "$fail" -eq 0 ]
