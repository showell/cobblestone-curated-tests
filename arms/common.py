"""What every arm shares: the tool bundles, the units, the verdict lines.

A UNIT is `<name>.codex` beside `<name>.expected` in one directory, self-
contained (its cites already resolved) and frozen with the output the program
must produce. A `.codex` with no `.expected` is refused, not skipped.

A TOOL is a bundle named in `tools.tsv` at the repository root: an executable
beside the provenance that records what built it. `provenance()` is what each
arm prints before its numbers, so a run always says which language it graded.
"""
import os
import pathlib
import resource
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def tools():
    """-> {name: path} from tools.tsv, each overridable by its upper-case env var."""
    out = {}
    for line in (ROOT / "tools.tsv").read_text().splitlines():
        line = line.split("#")[0].rstrip()
        if not line.strip():
            continue
        name, path = line.split("\t", 1)
        out[name.strip()] = pathlib.Path(os.environ.get(name.strip().upper(), path.strip())).expanduser()
    return out


def _line(path, prefix):
    for l in path.read_text(errors="replace").splitlines():
        if l.startswith(prefix):
            return l[len(prefix):].strip()
    return None


def provenance(name, path):
    """One line naming what this bundle is. Refuses a bundle that cannot say."""
    if name == "codexzig":
        exe, prov = path / "codexzig", path / "PROVENANCE"
        pin = _line(prov, "checkout") if prov.is_file() else None
    elif name == "codexir":
        exe, prov = path / "codexir", path / "PROVENANCE.oracles"
        pin = None
        if prov.is_file():
            ls = prov.read_text().splitlines()
            for i, l in enumerate(ls):
                if l.startswith("checkout") and i + 1 < len(ls):
                    pin = ls[i + 1].strip()
    elif name == "zigemit":
        exe, prov = path / "zigemit", path / "PROVENANCE"
        pin = (_line(prov, "codex-sha") or "")[:8] + " " + (_line(prov, "codex-branch") or "") if prov.is_file() else None
    elif name == "codexwasm":
        exe, prov = path / "corpus_sweep.py", path / "generated" / "PROVENANCE"
        pin = _line(prov, "checkout") or _line(prov, "built") if prov.is_file() else None
    elif name == "rust":
        exe, pin = path / "irdump", f"{path} (codexrun, irdump)"
    elif name == "zig":
        exe, pin = path, "zig"
    else:
        raise SystemExit(f"unknown tool {name}")
    if not os.access(exe, os.X_OK):
        raise SystemExit(f"missing {exe}")
    if not pin:
        raise SystemExit(f"{name} at {path} carries no provenance -- cannot say what it is")
    return f"{name:<9} {pin}"


def gaps(dirpath):
    """-> {name: (arm, why)} from `arm-gaps.tsv` in the units directory: units
    whose output through a named arm differs for a reason that is FILED and is
    not ours. The `.expected` stays the CORRECT value; the arm is what is
    wrong, and the verdict is `differs-filed`, reported and never fatal."""
    out = {}
    f = pathlib.Path(dirpath) / "arm-gaps.tsv"
    if f.is_file():
        for line in f.read_text().splitlines():
            line = line.split("#")[0].rstrip()
            if line.strip():
                name, arm, why = (line.split("\t", 2) + ["", ""])[:3]
                out.setdefault(name.strip(), {})[arm.strip()] = why.strip()
    return out


def differs(tally, name, arm, note, gapmap):
    """A wrong output is `differs`, or `differs-filed` when the gap file names it for this arm."""
    filed = gapmap.get(name, {}).get(arm)
    if filed is not None:
        tally.verdict(name, "differs-filed", filed[:70])
    else:
        tally.verdict(name, "differs", note)


def units(dirpath):
    d = pathlib.Path(dirpath)
    found = sorted(d.glob("*.codex"))
    if not found:
        raise SystemExit(f"no units in {d}")
    for u in found:
        if not u.with_suffix(".expected").is_file():
            raise SystemExit(f"{u.name} has no .expected beside it")
    return found


def expected(unit):
    """The .expected as the comparison sees it: no CR, no leading console byte."""
    want = unit.with_suffix(".expected").read_text(errors="replace").replace("\r", "")
    return want[1:] if want.startswith("\x01") else want


def _big_stack():
    # A debug irdump overflows the default stack on a large unit; the
    # release one does not. Unlimited costs nothing when unused.
    try:
        resource.setrlimit(resource.RLIMIT_STACK, (resource.RLIM_INFINITY, resource.RLIM_INFINITY))
    except (ValueError, OSError):
        pass


def run(cmd, stdin=None, cwd=None, timeout=300):
    """-> CompletedProcess with text stdout/stderr; never raises on exit code."""
    with (open(stdin, "rb") if stdin else open(os.devnull, "rb")) as fin:
        try:
            return subprocess.run([str(c) for c in cmd], stdin=fin, capture_output=True,
                                  cwd=cwd, timeout=timeout, preexec_fn=_big_stack)
        except subprocess.TimeoutExpired:
            return subprocess.CompletedProcess(cmd, -1, b"", f"TIMEOUT after {timeout}s".encode())


def text(b):
    return b.decode("utf-8", errors="replace").replace("\r", "")


class Tally:
    """Per-unit verdicts and the closing line. `bad` verdicts fail the run."""

    def __init__(self, good=("match", "agree"), soft=("differs-filed",)):
        self.counts = {}
        self.good, self.soft = set(good), set(soft)

    def verdict(self, name, verdict, note=""):
        self.counts[verdict] = self.counts.get(verdict, 0) + 1
        shown = verdict if verdict in self.good or verdict in self.soft else verdict.upper()
        print(f"{name:<34} {shown:<14} {note}".rstrip(), flush=True)

    def close(self):
        total = sum(self.counts.values())
        parts = ", ".join(f"{v} {k}" for k, v in sorted(self.counts.items(), key=lambda kv: -kv[1]))
        print(f"\n{parts}, of {total}")
        bad = sum(v for k, v in self.counts.items() if k not in self.good and k not in self.soft)
        return 0 if bad == 0 else 1


def header(arm, dirpath, *tool_names):
    t = tools()
    print(f"{arm}: {pathlib.Path(dirpath).resolve()}")
    for n in tool_names:
        print(provenance(n, t[n]))
    print()
    return t


def arg_dir():
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {pathlib.Path(sys.argv[0]).name} <units-dir>")
    return sys.argv[1]


def freeze(tally, unit, out, content, ok):
    """Write `out` if the producer answered, and say whether it moved."""
    if not ok:
        tally.verdict(unit.stem, "refused", (text(content).strip().splitlines() or ["no output"])[-1][:80])
        return
    if out.is_file() and out.read_bytes() == content:
        tally.verdict(unit.stem, "unchanged", f"{len(content)} bytes")
    else:
        was = out.stat().st_size if out.is_file() else None
        out.write_bytes(content)
        tally.verdict(unit.stem, "frozen", f"{len(content)} bytes" + (f" (was {was})" if was is not None else ""))
