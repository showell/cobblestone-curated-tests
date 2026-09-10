# Roc porting curriculum

The order we port roc-lang tests into `roc/units/`, chosen so each cluster
FORCES the next piece of the Rust compiler's type engine. Roc is the grounded
oracle (its `.expected` is a mature compiler's answer, and its tests aim at the
type corners); where a cluster is thin, a custom probe fills it (a minimal
program whose answer is unarguable, so we can be the oracle safely).

Source: roc-lang/roc `src/eval/test/`, ~28 `.zig` files, each a category of
small `main = <expr>` snippets with an asserted result.

## Porting notes (apply to every port)

- Roc `main = <expr>` -> a Codex `opening : [Console] Nothing = act ...
  print-line-uni (show <expr>) ... end`, one printed line per checked value.
- Roc prints `6.0` where Codex Integer prints `6`; Roc `"[]"`/`"(1, 2, 3)"`
  inspect-forms are Roc's, not Codex's. The VALUE is the oracle, format is
  adapted -- say so in each unit's prose.
- SKIP Roc-only surface Codex lacks: optional fields (`?:`), default fields
  (`??`, `.?x`), and anything requiring Roc's `inspect`. These test Roc syntax,
  not the shared type system.
- Each unit names the file and case it came from, and the adaptation made.

## The clusters, in order

### 1. zonk-and-default (monomorphic ambiguity) -- STARTED
Forces: a final per-definition pass that resolves every variable and defaults
any inference left ambiguous, so no hole reaches a plug.
- Shapes: an unconstrained empty container (element only measured, never read);
  an unread binding; a value whose type no context pins.
- Roc source: `eval_tests.zig` (`main = []`, unused-binding blocks),
  `eval_interpreter_style_tests.zig`. Roc numeric literals default too, but
  Codex literals are already int-default, so those are not forcing here.
- Have: `roc-alias-empty` (empty list orphan -> checker default, `4d0c8e4`).
- Ported 2026-09-10 (`roc/raw/` holds the unresolved chapters): `roc-rec-arith-eval`,
  `roc-rec-json-list`, `roc-rec-rose-tree`, `roc-rec-logic-match`, `roc-rec-wrapper-match`,
  `roc-rec-record-field`, `roc-mutual-even-odd` (recursive data, phase 2),
  `roc-match-color-rank` (match tests), `roc-poly-closures`, `roc-poly-capture-id`
  (polymorphism, phase 3). All ten green on every arm, both front ends agreeing.
- Custom probes fill the shapes Roc's file does not isolate.

### 2. bidirectional check (expected type flows down)
Forces: an explicit `check(e, expected)` mode beside `infer(e)`, for the cases
where a node takes its type from context rather than from itself.
- Shapes: an empty list initialising a typed record field or passed to a typed
  parameter; a lambda whose parameter type comes from its callee; a constructor
  whose field types come from its declaration.
- Roc source: `eval_match_tests.zig` (a pattern's type from the scrutinee),
  `eval_recursive_data_tests.zig`, record/tag construction in `eval_tests.zig`.

### 3. generic vs orphan (and the monomorphization question)
Forces: the decision to keep a genuinely-generic value as a comptime parameter
the zig plug can emit, versus specialising it -- and to never let an unbound
residue reach the plug.
- Shapes: a polymorphic function used at one type; a generic lifted closure (the
  iter cluster); polymorphic recursion.
- Roc source: `eval_polymorphism_tests.zig`, `lambda_mono_generated_corpus.zig`
  + `lambda_mono_differential_runner.zig` (Roc's own monomorphization corpus --
  the closest thing to a spec for this phase), `eval_closure_recursion_tests.zig`
  (partly ported; the iter cluster lives here).

## Files set aside (not type-curriculum)

Backend/runtime/feature specifics, not the shared type engine: `boxy_abi`,
`builtin_doc`, `eval_crypto`, `eval_iter_alloc`, `eval_low_level`, `eval_set`,
`eval_simd`, `host_effects*`, `host_trampoline*`, `rc_conformance`, `stack`,
`lir_inline`, `parallel`, `trmc*`, `eval_comptime_finalization`. Revisit
`eval_highest_lowest` (numbers), `eval_recursive_data`, `eval_issue_tests` /
`eval_regression_repros` (targeted bug repros -- often sharp forcing cases) as
each phase needs more pressure.
