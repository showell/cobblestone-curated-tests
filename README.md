# cobblestone-curated-tests

Twenty-eight Codex programs, frozen, each with upstream's own expected output.

    ./run.sh                    # the Rust interpreter runs each program
    ./run.sh <other-binary>     # anything that takes a unit on argv
    ./ir.sh                     # two HOSTS for one frontend, IR compared

Every `.codex` here is a RESOLVED UNIT: self-contained, citing nothing. There is
no `CODEX_ROOT`, no quire registry, no cite resolution. A program is one file
and its answer is one file.

`PROVENANCE` says which checkout and commit they came from, how the 1,727-program
corpus was cut down to these, and what the set is deliberately thin on.

`ir.sh` asks the other question: the Rust interpreter INTERPRETS the Codex
frontend to compile each unit, `codexir` is that same frontend as a native
binary compiling the same unit, and the two IR documents must be identical
bytes. The only thing that varies is the host, so a difference is an
interpreter defect with no third explanation. Thirty-six seconds for the set,
against days for the same question over the whole corpus.

The point of the set is that we can demand PERFECTION of it. It is small enough
to run in seconds and to read, so "27 of 28" is a bug list, not a statistic.

## How the set was chosen

`curate.py` and `curate2.py` are here rather than in a tool repository because
what they encode is the SELECTION CRITERIA. A set whose criteria live somewhere
else cannot answer "why is this program in it, and what would put another one
in".

    CODEX_ROOT=<checkout> ./curate.py <workdir> 300    # stage 1 and the screen
    ./curate2.py <workdir> 80 300                      # stages 2-6 and the pick

Both write every row to disk as it is measured (`screen.tsv`, `gates.tsv`,
`native.tsv`) and resume from those files, because an earlier version held
results in memory and lost eleven minutes of compiles to one interruption.
