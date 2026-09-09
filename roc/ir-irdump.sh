#!/usr/bin/env bash
# Compile each Roc port to IR with irdump (Rust) and diff it against codexir
# (upstream's frontend) -- the frontend-agreement hunt for this corpus.
#
#   ./ir-irdump.sh
#
# Only REFUSED (irdump cannot type it) fails the run. DIFFERS is reported for
# a human to read, not treated as failure: some ports differ from codexir on
# type-variable numbering alone, same output; PROVENANCE says which and why.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
IRDUMP=${IRDUMP:-$HOME/build/rust-target/release/irdump}
CODEXIR=${CODEXIR:-$GEN/local/codexir}
. "$here/oracle_pin.sh"
oracle_pin "$GEN" || exit 2
for f in "$IRDUMP" "$CODEXIR"; do
  [ -e "$f" ] || { echo "missing $f" >&2; exit 2; }
done

agree=0; differs=0; refused=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  ours=$("$IRDUMP" whole "$u" Program 2>"$here/.why"); rc=$?
  gold=$("$CODEXIR" < "$u" 2>&1 >/dev/null)
  # The oracle emitting no IR would make every arm's "" compare equal.
  if [ "${gold:0:8}" != "(chapter" ]; then
    printf '%-32s ORACLE EMITTED NO IR (%d B)\n' "$n" "${#gold}"; differs=$((differs+1)); continue
  fi
  if [ $rc -ne 0 ]; then
    refused=$((refused+1))
    printf '%-32s REFUSED   %s\n' "$n" "$(tail -1 "$here/.why" | cut -c1-72)"
  elif [ "$ours" = "$gold" ]; then
    agree=$((agree+1)); printf '%-32s agree     %d bytes\n' "$n" "${#ours}"
  else
    differs=$((differs+1))
    printf '%-32s DIFFERS   %d vs codexir %d\n' "$n" "${#ours}" "${#gold}"
  fi
done
rm -f "$here/.why"
printf '\nagree: %d  DIFFERS: %d  REFUSED: %d  of %d\n' \
  "$agree" "$differs" "$refused" "$((agree+differs+refused))"
[ "$refused" -eq 0 ]
