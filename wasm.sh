#!/usr/bin/env bash
# THE WASM PLUG, over the curated set.
#
#   ./wasm.sh
#
# A THIRD HOST for the same 28 programs. `run.sh` runs them on the Rust
# interpreter and `ir.sh` compiles them two ways; this one takes the IR each
# program compiles to and asks `codex/plugs/wasm/WasmPlug.codex` to turn it
# into a WebAssembly module, then RUNS that module and compares its output to
# the frozen `expected/`.
#
# WHAT IS ACTUALLY UNDER TEST IS THE PLUG, NOT THE FRONTEND. The IR is
# produced by `codexir` -- upstream's own frontend as a native binary -- so
# everything above the IR wire is held fixed and a difference here is the
# plug's. That is the complement of `ir.sh`, which holds the plug out and
# varies the host that runs the frontend.
#
# THE GRADING IS THE TRANSPILER'S OWN, not a copy. `corpus_sweep.py` grades in
# three stages (emit / assemble / run) and its middle stage is the one nothing
# else sees: a builtin the plug has no arm for is not emitted as a bad call --
# the name reaches the funcref path and comes out as `call_indirect` against a
# local nothing declared, which only `wat2wasm` names. `--tests` points it at
# our frozen expectations instead of the checkout's living ones.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
GEN=${CODEXZIG_GEN:-/home/steve/showell_repos/codex-zig-transpiler/generated}
CODEXIR=${CODEXIR:-$GEN/local/codexir}
WASMREPO=${CXWASM:-/home/steve/showell_repos/codex-wasm-transpiler}
export COBBLESTONE_ROOT=${COBBLESTONE_ROOT:-/home/steve/showell_repos/cobblestone-u56-sunday}
export CODEXZIG=${CODEXZIG:-$GEN/local/codexzig}
for f in "$CODEXIR" "$WASMREPO/corpus_sweep.py" "$CODEXZIG"; do
  [ -e "$f" ] || { echo "missing $f" >&2; exit 2; }
done

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  # codexir writes the IR document on stderr and its own chatter on stdout.
  "$CODEXIR" < "$u" 2> "$work/$n.ir" > /dev/null
  # AN EMPTY IR FILE WOULD SWEEP THROUGH AS "emitted 0 of 0" AND LOOK CLEAN.
  head -c 8 "$work/$n.ir" | grep -q '^(chapter' || {
    echo "$n: codexir emitted no IR ($(stat -c%s "$work/$n.ir") B)" >&2; exit 3; }
done

exec "$WASMREPO/corpus_sweep.py" --corpus "$work" --tests "$here/expected"
