#!/usr/bin/env bash
# oracle_pin <gen-dir>: print the codexir pin the arms grade against, and
# refuse a codexir that carries no PROVENANCE to identify itself.
oracle_pin() {
  local gen="$1" prov="$1/PROVENANCE.oracles"
  [ -x "$gen/local/codexir" ] || { echo "no codexir at $gen/local/codexir" >&2; return 2; }
  [ -f "$prov" ] || { echo "codexir at $gen has no PROVENANCE.oracles -- cannot say what it is" >&2; return 2; }
  echo "oracle: codexir @ $(grep -A1 '^checkout' "$prov" | tail -1 | sed 's/^ *//')"
}
