#!/usr/bin/env bash
# RUST COMPILING CODEX DIRECTLY, over the curated set.
#
#   ./native.sh
#
# The other three scripts all have a Codex compiler somewhere in the loop.
# This one does not: `irdump` is Rust reading a .codex unit and producing IR
# itself, and the question is whether it reaches the document `codexir` --
# upstream's own frontend -- produces from the same bytes.
#
# THE UNITS ARE ALREADY RESOLVED, SO NOTHING RESOLVES THEM AGAIN. The
# compiler's own `ladder/native.py` runs `cite_resolve` first, which is right
# for a raw corpus program and wrong here: re-resolving a frozen unit
# duplicates its cited chapters (normalize-eq goes 4256 -> 7965 bytes) and the
# ORACLE then halts on the duplicates. That reads as 20 of 28 programs the
# oracle refused, which is a broken control wearing the costume of a result.
#
# THREE VERDICTS, AND ONLY ONE OF THEM IS A BUG. `irdump` returns the reason
# it could not compile a definition rather than guessing, so REFUSED is a
# named hole in a front end that is still being built. DIFFERS is the one that
# means the lowering is wrong.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
IRDUMP=${IRDUMP:-$HOME/build/rust-target/release/irdump}
CODEXIR=${CODEXIR:-$GEN/local/codexir}
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
