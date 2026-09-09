#!/usr/bin/env bash
# Compile each Roc port with the zig plug (codexzig -> zig build-exe), run it, and
# compare its output to the co-located .expected file.
#
#   ./run-zig.sh
#
# zig's own type checking is part of the test: BUILD-FAILED means zig refused a
# program the earlier arms accepted -- a type the zig plug or our IR got wrong.
# codexzig prints its zig on stderr; a compiled Codex program prints on stderr too.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
CODEXZIG=${CODEXZIG:-$GEN/local/codexzig}
. "$here/oracle_pin.sh"
oracle_pin "$GEN" || exit 2
[ -x "$CODEXZIG" ] || { echo "missing $CODEXZIG" >&2; exit 2; }
command -v zig >/dev/null || { echo "zig not on PATH" >&2; exit 2; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
match=0; differ=0; buildfail=0; refused=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  want=$(cat "${u%.codex}.expected")
  "$CODEXZIG" < "$u" 2> "$work/$n.zig" > /dev/null
  if head -c 14 "$work/$n.zig" | grep -q '^CODEGEN-HALTED' || [ ! -s "$work/$n.zig" ]; then
    refused=$((refused+1)); printf '%-32s REFUSED (codexzig)\n' "$n"; continue
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
