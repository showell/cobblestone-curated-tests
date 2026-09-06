# cobblestone-curated-tests

Twenty-eight Codex programs, frozen, each with upstream's own expected output.

    ./run.sh                    # the Rust interpreter
    ./run.sh <other-binary>     # anything that takes a unit on argv

Every `.codex` here is a RESOLVED UNIT: self-contained, citing nothing. There is
no `CODEX_ROOT`, no quire registry, no cite resolution. A program is one file
and its answer is one file.

`PROVENANCE` says which checkout and commit they came from, how the 1,727-program
corpus was cut down to these, and what the set is deliberately thin on.

The point of the set is that we can demand PERFECTION of it. It is small enough
to run in seconds and to read, so "27 of 28" is a bug list, not a statistic.
