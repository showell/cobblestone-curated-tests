#!/usr/bin/env bash
# Run the Codex frontend over each unit two ways -- our interpreter (codexrun)
# and codexir (that same frontend as a native binary) -- and diff the IR.
#
#   ./ir-interp.sh
#
# Only the host varies, so any difference is an interpreter defect.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
BIN=${CODEXRUN:-$HOME/build/rust-target/release/codexrun}
CODEXIR=${CODEXIR:-$GEN/local/codexir}
SUBJECT=$GEN/codexir-subject.codex
. "$here/oracle_pin.sh"
oracle_pin "$GEN" || exit 2
for f in "$BIN" "$CODEXIR" "$SUBJECT"; do
  [ -e "$f" ] || { echo "missing $f" >&2; exit 2; }
done

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
python3 - "$SUBJECT" "$work/frontend.codex" <<'PY'
import sys, pathlib
s = pathlib.Path(sys.argv[1]).read_text()
H = 'Chapter: Parsmi--CodexIrHarness'
assert s.count(H) == 1, f'{s.count(H)} harness chapters, expected 1'
pathlib.Path(sys.argv[2]).write_text(s[:s.index(H)])
PY

pass=0; fail=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  # Same entry chapter "Program" and refusal wording as the driver, so the
  # two IR documents compare as raw bytes.
  cat "$work/frontend.codex" > "$work/prog.codex"
  cat >> "$work/prog.codex" <<HARNESS

Chapter: Parsmi--Hosts

Section: Halt
  hosts-halted : List Diagnostic -> Text
  hosts-halted (es) =
   let n = list-length es
   in let e0 = list-at es 0
   in "CODEGEN-HALTED: " & show n & " error(s); no IR emitted; first CDX" & show (e0.code) & " " & (e0.message) & "\n"

Section: Entry
  opening : [Console, FileSystem] Nothing = act
    src <- read-file-uni "$u"
    let mb = init-phase-allocator
    in let db = __heap-save
    in let ds = __deck-set db
    in let da = __heap-advance 536870912
    in let fe = compile-frontend-ir src "Program" compile-flags-default
    in if bag-has-errors (fe.bag) then print-uni (hosts-halted (bag-errors (fe.bag)))
    else let lifted-ir = lift-ir-for-emit (fe.ir) compile-flags-default
    in print-uni (emit-ir-chapter (ir-prune-unreachable-roots lifted-ir ir-emit-roots) (fe.text-meta) (fe.type-defs))
  end
HARNESS
  ours=$("$BIN" "$work/prog.codex" 2>/dev/null)
  gold=$("$CODEXIR" < "$u" 2>&1 >/dev/null)
  # Both arms print IR on a stream we pick; a wrong pick yields "" from both,
  # which would compare equal. Every IR document starts `(chapter`, so demand it.
  if [ "${gold:0:8}" != "(chapter" ]; then
    fail=$((fail+1)); printf '%-32s ORACLE EMITTED NO IR (%d B)\n' "$n" "${#gold}"; continue
  fi
  if [ "$ours" = "$gold" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    printf '%-32s DIFFERS  (ours %d B, codexir %d B)\n' "$n" "${#ours}" "${#gold}"
  fi
done
printf '\n%d identical, %d differ, %d total\n' "$pass" "$fail" "$((pass+fail))"
[ "$fail" -eq 0 ]
