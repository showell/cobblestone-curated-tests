#!/usr/bin/env bash
# Compile each Roc port's IR (from codexir) to a wasm module with the wasm
# plug, run it, and compare its output to the co-located .expected.
#
#   ./run-wasm.sh
#
# The IR comes from upstream's frontend, so this tests the plug on the corpus.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
CODEXIR=${CODEXIR:-$GEN/local/codexir}
WASMREPO=${CXWASM:-/home/steve/showell_repos/codex-wasm-transpiler}
export CODEXZIG=${CODEXZIG:-$GEN/local/codexzig}
# COBBLESTONE_ROOT decides the wasm plug's language; derive it from the same
# checkout codexir was built from so the plug and the oracle never grade
# different languages.
export COBBLESTONE_ROOT=${COBBLESTONE_ROOT:-$(grep -m1 '^checkout' "$GEN/PROVENANCE.oracles" | awk '{print $2}')}
for f in "$CODEXIR" "$WASMREPO/corpus_sweep.py" "$CODEXZIG" "$COBBLESTONE_ROOT/codex/compiler/opening.codex"; do
  [ -e "$f" ] || { echo "missing $f" >&2; exit 2; }
done
. "$here/oracle_pin.sh"
oracle_pin "$GEN" || exit 2

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  # codexir writes the IR document on stderr and its own chatter on stdout.
  "$CODEXIR" < "$u" 2> "$work/$n.ir" > /dev/null
  # AN EMPTY IR FILE WOULD SWEEP THROUGH AS "emitted 0 of 0" AND LOOK CLEAN.
  head -c 8 "$work/$n.ir" | grep -q '^(chapter' || {
    echo "$n: codexir emitted no IR ($(stat -c%s "$work/$n.ir") B)" >&2; exit 3; }
done

exec "$WASMREPO/corpus_sweep.py" --corpus "$work" --tests "$here/units"
