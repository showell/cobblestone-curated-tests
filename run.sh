#!/usr/bin/env bash
# Every unit, through one compiler or interpreter, against upstream's own answer.
#
#   ./run.sh                    the Rust interpreter (codexrun)
#   ./run.sh <path-to-binary>   anything else that takes a unit on argv
#
# **THE TWO ARMS USE OPPOSITE STREAMS.** `codexrun` prints a program's output on
# STDOUT; a program compiled by `codexzig` and linked by zig prints it on
# STDERR, the same convention `codexzig` and `codexir` use for their own output.
# Reading one stream reports every program as failing against a file it
# reproduces byte for byte -- which is exactly what happened twice while this
# set was being built, once in each direction. So take whichever stream the
# program actually wrote, and say which when it fails.
set -u
BIN="${1:-$HOME/build/rust-target/release/codexrun}"
here=$(cd "$(dirname "$0")" && pwd)
pass=0; fail=0
for u in "$here"/units/*.codex; do
  n=$(basename "$u" .codex)
  exp="$here/expected/$n.expected"
  o=$("$BIN" "$u" 2>/dev/null); e=$("$BIN" "$u" 2>&1 >/dev/null)
  want=$(cat "$exp")
  if [ "$o" = "$want" ] || [ "$e" = "$want" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    printf '%-32s FAIL  (out %d B, err %d B, want %d B)\n' \
      "$n" "${#o}" "${#e}" "${#want}"
  fi
done
printf '\n%d pass, %d fail, %d total\n' "$pass" "$fail" "$((pass+fail))"
[ "$fail" -eq 0 ]
