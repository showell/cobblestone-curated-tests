#!/usr/bin/env bash
# Compile each unit to IR with irdump (Rust) and diff it, byte for byte,
# against codexir (upstream's frontend as a native binary).
#
#   ./ir-irdump.sh
#
# Verdicts: agree, DIFFERS (irdump's lowering disagrees), REFUSED (irdump
# cannot type it yet). Units are pre-resolved; nothing re-resolves them.
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
[ "$differs" -eq 0 ]
