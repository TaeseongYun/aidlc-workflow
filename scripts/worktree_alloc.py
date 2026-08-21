#!/usr/bin/env python3
"""Worktree allocation mode for aidlc-workflow.

Detects how many parallel git worktrees a multi-feature roadmap needs and
creates one worktree (+ branch) per parallel-safe feature.

Detection signal — parsed from the project's aidlc-docs/_roadmap.md
(structure defined by templates/feature-roadmap.md):
  - Section 2 "Feature List"  -> maps F-N to a kebab-case slug
  - Section 4 "Dependency Graph" -> `Resolution` column == parallel-safe
  - Section 5 "Allocation" -> a phase whose execution-mode cell says parallel
The roadmap may be Korean or English, so both `parallel`/`병렬` and the
verbatim enum value `parallel-safe` are matched.

Usage:
  worktree_alloc.py plan   [--roadmap PATH]
  worktree_alloc.py create [--roadmap PATH] [--base DIR] [--slugs a,b,c] [--count N]
  worktree_alloc.py list
  worktree_alloc.py prune
  worktree_alloc.py --selftest

stdlib only; requires `git` on PATH.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

FEATURE_ID = re.compile(r"F-\d+")
KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PARALLEL = re.compile(r"parallel|병렬", re.IGNORECASE)


class AllocationError(ValueError):
    """Invalid allocator input that should be shown without a traceback."""


# ── git helpers ───────────────────────────────────────────────────────────
def git(*args: str, cwd: str | None = None) -> str:
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def current_toplevel() -> Path:
    return Path(git("rev-parse", "--show-toplevel"))


def main_worktree() -> Path:
    """First entry of `git worktree list --porcelain` is the main worktree."""
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            return Path(line[len("worktree "):])
    return current_toplevel()


def existing_worktree_paths() -> set[str]:
    out = git("worktree", "list", "--porcelain")
    return {
        str(Path(line[len("worktree "):]).resolve())
        for line in out.splitlines()
        if line.startswith("worktree ")
    }


def branch_exists(name: str) -> bool:
    return subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{name}"]
    ).returncode == 0


# ── roadmap parsing ───────────────────────────────────────────────────────
def _cells(row: str) -> list[str]:
    return [c.strip() for c in row.strip().strip("|").split("|")]


def _tables(md: str) -> list[dict]:
    """Return every markdown table as {'header': [...], 'rows': [[...], ...]}."""
    tables, lines, i = [], md.splitlines(), 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|") and i + 1 < len(lines) and re.match(
            r"^\s*\|?[\s:\-|]+\|?\s*$", lines[i + 1]
        ):
            header = _cells(lines[i])
            rows, j = [], i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                rows.append(_cells(lines[j]))
                j += 1
            tables.append({"header": header, "rows": rows})
            i = j
        else:
            i += 1
    return tables


def _find_table(tables: list[dict], *needles: str) -> dict | None:
    for t in tables:
        head = " ".join(t["header"]).lower()
        if all(n.lower() in head for n in needles):
            return t
    return None


def _col(header: list[str], *needles: str) -> int:
    for idx, h in enumerate(header):
        hl = h.lower()
        if any(n.lower() in hl for n in needles):
            return idx
    return -1


def parse_roadmap(md: str) -> dict:
    """-> {'features': {F-N: slug}, 'parallel': [(F-N, slug), ...]}."""
    tables = _tables(md)
    features: dict[str, str] = {}

    ft = _find_table(tables, "feature", "slug")
    if ft:
        slug_i = _col(ft["header"], "slug")
        for row in ft["rows"]:
            fid = next((c for c in row if FEATURE_ID.fullmatch(c)), None)
            slug = row[slug_i] if 0 <= slug_i < len(row) else ""
            if fid and KEBAB.match(slug):
                features[fid] = slug

    parallel_ids: list[str] = []

    # Primary signal: allocation phase whose execution-mode cell says parallel.
    alloc = _find_table(tables, "phase", "feature")
    if alloc:
        for row in alloc["rows"]:
            if any(PARALLEL.search(c) for c in row):
                for c in row:
                    parallel_ids += FEATURE_ID.findall(c)

    # Fallback / cross-check: dependency Resolution == parallel-safe.
    if not parallel_ids:
        dep = _find_table(tables, "resolution")
        if dep:
            for row in dep["rows"]:
                if any("parallel-safe" in c.lower() for c in row):
                    src = next((c for c in row if FEATURE_ID.fullmatch(c)), None)
                    if src:
                        parallel_ids.append(src)

    seen, parallel = set(), []
    for fid in parallel_ids:
        slug = features.get(fid)
        if slug and fid not in seen:
            seen.add(fid)
            parallel.append((fid, slug))
    return {"features": features, "parallel": parallel}


# ── commands ──────────────────────────────────────────────────────────────
def _load_roadmap(path: str | None) -> str:
    p = Path(path) if path else Path("aidlc-docs/_roadmap.md")
    if not p.exists():
        raise AllocationError(
            f"roadmap not found: {p}  (run from the project root, or pass --roadmap / --slugs)"
        )
    return p.read_text(encoding="utf-8")


def _targets(args) -> list[tuple[str, str]]:
    """Resolve the (label, slug) worktrees to act on, from flags or roadmap."""
    if getattr(args, "slugs", None):
        slugs = [s.strip() for s in args.slugs.split(",") if s.strip()]
        invalid = [slug for slug in slugs if not KEBAB.fullmatch(slug)]
        if invalid:
            raise AllocationError(
                "invalid slug(s): " + ", ".join(invalid) + " (expected kebab-case)"
            )
        if len(slugs) != len(set(slugs)):
            raise AllocationError("duplicate slugs are not allowed")
        return [(s, s) for s in slugs]
    if getattr(args, "count", None) is not None:
        if args.count < 1:
            raise AllocationError("--count must be at least 1")
        return [(f"feature-{i}", f"feature-{i}") for i in range(1, args.count + 1)]
    detected = parse_roadmap(_load_roadmap(args.roadmap))["parallel"]
    return [(fid, slug) for fid, slug in detected]


def cmd_plan(args) -> int:
    targets = _targets(args)
    base = (Path(args.base) if args.base else main_worktree().parent).resolve()
    if not targets:
        print("No parallel-safe features detected in the roadmap. Nothing to allocate.")
        return 0
    print(f"Detected {len(targets)} worktree(s) to allocate (base: {base}):")
    for label, slug in targets:
        print(f"  {label:<12} -> {base / slug}   (branch: {slug})")
    print("\nRun `worktree_alloc.py create` with the same flags to create them.")
    return 0


def cmd_create(args) -> int:
    targets = _targets(args)
    if not targets:
        print("Nothing to create.")
        return 0
    base = (Path(args.base) if args.base else main_worktree().parent).resolve()
    base.mkdir(parents=True, exist_ok=True)
    existing = existing_worktree_paths()
    created = skipped = failed = 0
    for _label, slug in targets:
        dest = (base / slug).resolve()
        if str(dest) in existing or dest.exists():
            print(f"skip  {slug}: worktree path already exists ({dest})")
            skipped += 1
            continue
        add = ["worktree", "add", str(dest)]
        add += [slug] if branch_exists(slug) else ["-b", slug]  # reuse or create branch
        try:
            git(*add)
            print(f"create {slug}: {dest}  (branch: {slug})")
            created += 1
        except subprocess.CalledProcessError as e:
            print(f"FAIL  {slug}: git {' '.join(add)} -> {e}")
            failed += 1
    print(f"\n{created} created, {skipped} skipped, {failed} failed.")
    return 1 if failed else 0


def cmd_list(_args) -> int:
    print(git("worktree", "list"))
    return 0


def cmd_prune(_args) -> int:
    print(git("worktree", "prune", "-v") or "nothing to prune")
    return 0


# ── selftest (the one runnable check) ─────────────────────────────────────
def selftest() -> int:
    sample = """
## 2. Feature List
| Feature ID | Slug (kebab-case) | 1-line Responsibility | Type |
|------------|-------------------|------------------------|------|
| F-1        | shared-core       | foundation            | foundation-core |
| F-2        | coupon-issue      | issue coupons         | domain-feature |
| F-3        | coupon-redeem     | redeem coupons        | domain-feature |

## 4. Dependency Graph
### 4-1
| Source Feature | Depends On | Reason | Resolution |
|----------------|------------|--------|------------|
| F-2 | F-1 | model | parallel-safe |
| F-3 | F-1 | model | parallel-safe |

## 5. Allocation Recommendation
### 5-1
| Phase | Feature(s) | Execution Mode | Note |
|-------|-----------|----------------|------|
| 1 | F-1 | serial (blocking) | |
| 2 | F-2, F-3 | parallel | |
"""
    r = parse_roadmap(sample)
    assert r["features"] == {
        "F-1": "shared-core", "F-2": "coupon-issue", "F-3": "coupon-redeem"
    }, r["features"]
    assert [s for _, s in r["parallel"]] == ["coupon-issue", "coupon-redeem"], r["parallel"]

    # Korean roadmap + fallback path (no allocation table) must also work.
    ko = """
## 2. 피처 목록
| Feature ID | Slug (kebab-case) | 책임 | Type |
|---|---|---|---|
| F-1 | alpha | a | domain-feature |
| F-2 | beta | b | domain-feature |
## 4. 의존 그래프
| Source Feature | Depends On | Reason | Resolution |
|---|---|---|---|
| F-1 | - | - | parallel-safe |
| F-2 | - | - | serialized |
"""
    r2 = parse_roadmap(ko)
    assert [s for _, s in r2["parallel"]] == ["alpha"], r2["parallel"]  # only parallel-safe

    class Args:
        roadmap = None
        base = None
        count = None

    args = Args()
    args.slugs = "alpha,beta-two"
    assert _targets(args) == [("alpha", "alpha"), ("beta-two", "beta-two")]
    args.slugs = "../escape"
    try:
        _targets(args)
        raise AssertionError("path-like slug must be rejected")
    except AllocationError:
        pass
    args.slugs = None
    args.count = 0
    try:
        _targets(args)
        raise AssertionError("zero count must be rejected")
    except AllocationError:
        pass
    print("selftest OK")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Allocate git worktrees for parallel-safe roadmap features.")
    p.add_argument("--selftest", action="store_true", help="run the parser self-check and exit")
    sub = p.add_subparsers(dest="cmd")

    def add_common(sp):
        sp.add_argument("--roadmap", help="path to _roadmap.md (default: aidlc-docs/_roadmap.md)")
        sp.add_argument("--base", help="base dir for new worktrees (default: sibling of main worktree)")
        override = sp.add_mutually_exclusive_group()
        override.add_argument("--slugs", help="comma-separated slugs; overrides roadmap detection")
        override.add_argument(
            "--count", type=int,
            help="create N generic worktrees (feature-1..N); overrides roadmap",
        )

    add_common(sub.add_parser("plan", help="dry-run: show detected worktrees"))
    add_common(sub.add_parser("create", help="create the worktrees"))
    sub.add_parser("list", help="git worktree list")
    sub.add_parser("prune", help="git worktree prune")

    args = p.parse_args()
    try:
        if args.selftest:
            return selftest()
        return {
            "plan": cmd_plan, "create": cmd_create, "list": cmd_list, "prune": cmd_prune
        }.get(args.cmd, lambda _a: (p.print_help() or 1))(args)
    except AllocationError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
