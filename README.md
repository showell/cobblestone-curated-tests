# cobblestone-curated-tests

Small Codex programs, each frozen with its expected output, run through several
arms to hunt bugs in the frontend and the backend plugs. Two corpora, kept
separate by origin:

| corpus | count | origin |
|---|---|---|
| [`cobblestone/`](cobblestone/) | 28 | cut from Cobblestone's own 1,727-program corpus (see `cobblestone/PROVENANCE`) |
| [`roc/`](roc/) | 29 | hand-ported from roc-lang/roc's test suite (see `roc/PROVENANCE`) |

Each corpus is self-contained: `units/` holds every program's `.codex` beside
its `.expected`, and the arm scripts live in the corpus directory. Run one arm
from inside a corpus:

    cd cobblestone && ./run-interp.sh
    cd roc && ./ir-irdump.sh

## The arms

Two questions. `run-*` executes the program and checks its output against
`.expected`; `ir-*` compiles it and diffs the IR against `codexir` (upstream's
frontend as a native binary). The suffix names what does the work.

| script | what it runs | checked against | a failure means |
|---|---|---|---|
| `run-interp.sh` | the program, on the Rust interpreter `codexrun` | `.expected` | the interpreter computes the wrong value |
| `run-wasm.sh` | the program, as a wasm module from the wasm plug | `.expected` | the wasm plug is wrong |
| `run-zig.sh` | the program, as a native binary from the zig plug (`codexzig` → `zig build-exe`) | `.expected` | the zig plug is wrong, or refuses a type it should accept |
| `ir-irdump.sh` | `irdump` (Rust `.codex` → IR) | `codexir` | our Rust frontend disagrees with upstream's |
| `ir-interp.sh` | the Codex frontend, interpreted by `codexrun`, → IR | `codexir` | our interpreter runs the frontend wrong |

`run-wasm.sh` builds its module from upstream's IR, so it tests the plug, not
the frontend. `ir-irdump.sh` and `ir-interp.sh` never execute the program.

`run-zig.sh` is the arm for the plug we maintain, and it is the strictest:
`zig build-exe` refuses a program whose types the plug or the frontend left
unresolved, so BUILD-FAILED catches what the interpreter and wasm arms (which
tolerate an unresolved type) run straight past.

Each arm names the `codexir` pin it grades against (`oracle_pin.sh`), so an arm
cannot silently drift to a different language than the oracle.
