#!/usr/bin/env bash
# State which codexir a gate grades against, and refuse one that cannot say
# what it is. The native and ir gates used to trust whatever binary sat at
# $GEN/local/codexir, so a run never said which pin it measured -- and a codexir
# from the wrong checkout would have graded silently. codexir is owned by
# codex-zig-transpiler (build_codexir.py maintains its own freshness), so this
# does not re-fingerprint it; it reads the pin the transpiler recorded and
# prints it, and refuses if there is no codexir or no provenance to read.
oracle_pin() {
  local gen="$1" prov="$1/PROVENANCE.oracles"
  [ -x "$gen/local/codexir" ] || { echo "no codexir at $gen/local/codexir" >&2; return 2; }
  [ -f "$prov" ] || { echo "codexir at $gen has no PROVENANCE.oracles -- cannot say what it is" >&2; return 2; }
  echo "oracle: codexir @ $(grep -A1 '^checkout' "$prov" | tail -1 | sed 's/^ *//')"
}
