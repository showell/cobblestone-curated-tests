# cobblestone-curated-tests

Small Codex programs, each frozen with its expected output, run through several
arms to hunt bugs in the frontend and the backend plugs. The corpora here are
kept separate by origin:

| corpus | count | origin |
|---|---|---|
| [`cobblestone/units`](cobblestone/units) | 28 | cut from Cobblestone's own test corpus (`cobblestone/PROVENANCE`) |
| [`roc/units`](roc/units) | 29 | hand-ported from roc-lang/roc's test suite (`roc/PROVENANCE`) |

The arms take any directory of units, so a corpus that lives elsewhere --
safari's exported specs, `~/showell_repos/safari-codex/units` -- is graded the
same way, from the outside.

## A unit

`<name>.codex`, self-contained (its cites already resolved), beside the files
that say what it must produce:

| file | written by | changes when |
|---|---|---|
| `.expected` | the corpus's oracle (Cobblestone's `.expected`, Roc's answer, a spec's own verdict) | almost never |
| `.upstream.ir` | `arms/freeze-upstream-ir`, from the codexir bundle | the pin moves; the re-freeze diff is what the Update changed |
| `.rust.ir` | `arms/freeze-rust-ir`, from irdump | ON PURPOSE only; the re-freeze is reviewed as a diff |

A `.codex` with no `.expected` is refused, not skipped.

## The arms

    arms/<arm> <units-dir>

| arm | runs | checked against | a failure means |
|---|---|---|---|
| `run-interp` | the program on the Rust interpreter `codexrun` | `.expected` | the interpreter computes the wrong value |
| `run-zig` | the program as a native binary from upstream's zig plug (`codexzig` -> `zig build-exe`) | `.expected` | the zig plug is wrong, or upstream's frontend left a type it refuses |
| `run-wasm` | the program as a wasm module from the wasm plug, fed `.upstream.ir` | `.expected` | the wasm plug is wrong |
| `ir-zig` | the program from OUR IR (`irdump` -> `zigemit` -> `zig build-exe`) | `.expected` | our frontend left a type unresolved, or lowered it wrong |
| `ir-rust` | `irdump` | `.rust.ir` | our frontend changed what it emits -- a regression, or an intended change that wants a reviewed re-freeze |
| `ir-diff` | nothing; compares the two frozen files | each other | not a failure: a place to read where the reference and upstream disagree (exit 0) |

`run-zig` and `ir-zig` are the strict pair: `zig build-exe` refuses a program
whose types were left unresolved, which the interpreter and the wasm plug run
straight past. `ir-zig` is the type oracle the Rust compiler is graded by as the
reference; `run-zig` is the attribution (does upstream's whole pipeline share
the break?).

## The tools

`tools.tsv` names each tool's BUNDLE -- an executable beside the provenance
that records what built it -- and every arm prints those lines before its
numbers, so a run always says which language it graded. Override one with its
upper-case name in the environment (`CODEXZIG=... arms/run-zig roc/units`).
A bundle with no provenance is refused.
