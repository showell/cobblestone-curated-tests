#!/usr/bin/env bash
# OUR IR through the zig plug: irdump (the Rust front end) -> zigemit (the plug,
# reading IR on stdin) -> zig build-exe -> run, compared to the co-located
# .expected file.
#
#   ./ir-zig.sh
#
# This is the TYPE oracle for our IR. run-zig.sh grades upstream's whole
# pipeline; this arm grades ours, with the same plug. zig's own type checking is
# the test: a hole in our IR (a type variable no phase resolved) is a
# BUILD-FAILED here and nowhere earlier -- the interpreter erases types, and
# codexir agreement cannot see a hole both front ends share.
#
# zigemit is a plug built from a Cobblestone checkout; it must sit beside a
# PROVENANCE that says which, or this arm cannot say what it graded against.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
IRDUMP=${IRDUMP:-$HOME/build/rust-target/release/irdump}
ZIGEMIT=${ZIGEMIT:-$HOME/runs/zigemit-catc2/zigemit}
for f in "$IRDUMP" "$ZIGEMIT"; do
  [ -x "$f" ] || { echo "missing $f" >&2; exit 2; }
done
prov="$(dirname "$ZIGEMIT")/PROVENANCE"
[ -f "$prov" ] || { echo "zigemit at $ZIGEMIT has no PROVENANCE beside it -- cannot say what it is" >&2; exit 2; }
echo "plug: zigemit @ $(grep '^codex-sha' "$prov" | awk '{print substr($2,1,8)}') ($(grep '^codex-branch' "$prov" | awk '{print $2}'))"
command -v zig >/dev/null || { echo "zig not on PATH" >&2; exit 2; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
match=0; differ=0; buildfail=0; refused=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  want=$(cat "${u%.codex}.expected")
  if ! "$IRDUMP" whole "$u" > "$work/$n.ir" 2> "$work/$n.irerr"; then
    refused=$((refused+1)); printf '%-32s REFUSED (irdump)  %s\n' "$n" "$(head -1 "$work/$n.irerr" | cut -c1-60)"; continue
  fi
  "$ZIGEMIT" < "$work/$n.ir" 2> "$work/$n.zig" > /dev/null
  if head -c 14 "$work/$n.zig" | grep -q '^CODEGEN-HALTED' || [ ! -s "$work/$n.zig" ]; then
    refused=$((refused+1)); printf '%-32s REFUSED (zigemit)\n' "$n"; continue
  fi
  if ! (cd "$work" && zig build-exe "$n.zig" -femit-bin="$n.exe") >/dev/null 2>"$work/$n.err"; then
    buildfail=$((buildfail+1)); printf '%-32s BUILD-FAILED  %s\n' "$n" "$(grep -m1 error: "$work/$n.err" | cut -c1-60)"; continue
  fi
  got=$("$work/$n.exe" 2>&1 >/dev/null)
  if [ "$got" = "$want" ]; then match=$((match+1))
  else differ=$((differ+1)); printf '%-32s DIFFERS (got %dB, want %dB)\n' "$n" "${#got}" "${#want}"; fi
done
printf '\n%d match, %d differ, %d build-failed, %d refused, of %d\n' \
  "$match" "$differ" "$buildfail" "$refused" "$((match+differ+buildfail+refused))"
[ "$differ" -eq 0 ] && [ "$buildfail" -eq 0 ] && [ "$refused" -eq 0 ]
