#!/usr/bin/env python3
"""Draft aidlc-docs/reverse-engineering/component-inventory.md from graphify-out/graph.json.

Reads the graph graphify already built (no model tokens), groups nodes by package
(top-level source directory) and fills the tables of
templates/reverse-engineering/component-inventory.md. Rows the graph cannot classify are
marked "⚠️ UNCERTAIN (auto)" for STEP 1.5 to verify. stdlib only.

Exit codes: 0 written · 3 no graph (do STEP 1.5 by hand) · 4 output exists (use --force).
"""
import argparse
import collections
import json
import os
import subprocess
import sys
import time

INFRA = ("db", "database", "cache", "redis", "queue", "kafka", "storage", "s3", "migration", "infra", "persistence")
COMMON = ("auth", "log", "logging", "error", "util", "utils", "common", "shared", "core", "config")
SRC_ROOTS = ("src", "lib", "app", "pkg", "internal", "cmd", "packages", "modules")


def package(node):
    src = (node.get("source_file") or node.get("file") or "").replace("\\", "/").lstrip("./")
    parts = [p for p in src.split("/") if p]
    if not parts:
        return "(unknown)"
    if len(parts) < 2:
        return "(root)"
    if parts[0] in SRC_ROOTS and len(parts) > 2:
        return parts[0] + "/" + parts[1]
    return parts[0]


def ends(link):
    return link.get("source", link.get("from")), link.get("target", link.get("to"))


def classify(pkg):
    low = pkg.lower()
    if any(k in low for k in INFRA):
        return "infra"
    if any(k in low for k in COMMON):
        return "common"
    return "domain"


def find_cycles(dep):
    """dep: {pkg: set(pkg)} -> sorted (a, b) pairs where b reaches back to a."""
    found = set()
    for a, targets in dep.items():
        for b in targets:
            stack, seen = [b], set()
            while stack:
                x = stack.pop()
                if x == a:
                    found.add(tuple(sorted((a, b))))
                    break
                if x in seen:
                    continue
                seen.add(x)
                stack.extend(dep.get(x, ()))
    return sorted(found)


def git_sha(root):
    try:
        return subprocess.check_output(["git", "-C", root, "rev-parse", "--short", "HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:  # not a git repo, or git missing
        return "unknown"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="project root containing graphify-out/")
    ap.add_argument("--out", help="output path (default: <root>/aidlc-docs/reverse-engineering/component-inventory.md)")
    ap.add_argument("--force", action="store_true", help="overwrite an existing output file")
    ap.add_argument("--top", type=int, default=10, help="god nodes to list as reuse candidates")
    a = ap.parse_args()

    gpath = os.path.join(a.root, "graphify-out", "graph.json")
    if not os.path.isfile(gpath):
        print(f"graph_inventory: no graph at {gpath} — run `graphify .` or do STEP 1.5 by hand", file=sys.stderr)
        sys.exit(3)
    out = a.out or os.path.join(a.root, "aidlc-docs", "reverse-engineering", "component-inventory.md")
    if os.path.exists(out) and not a.force:
        print(f"graph_inventory: {out} exists (use --force to overwrite)", file=sys.stderr)
        sys.exit(4)

    with open(gpath, encoding="utf-8") as f:
        g = json.load(f)
    nodes = {n["id"]: n for n in g.get("nodes", []) if n.get("id") is not None}
    links = [l for l in g.get("links", g.get("edges", [])) if all(x is not None for x in ends(l))]

    deg = collections.Counter()
    for l in links:
        s, t = ends(l)
        deg[s] += 1
        deg[t] += 1
    pkg_of = {i: package(n) for i, n in nodes.items()}
    members = collections.defaultdict(list)
    for i in nodes:
        members[pkg_of[i]].append(i)

    edges, extracted, dep = collections.Counter(), collections.Counter(), collections.defaultdict(set)
    for l in links:
        s, t = ends(l)
        ps, pt = pkg_of.get(s, "(unknown)"), pkg_of.get(t, "(unknown)")
        if ps == pt:
            continue
        key = (ps, pt, l.get("relation") or l.get("label") or "uses")
        edges[key] += 1
        if (l.get("confidence") or "EXTRACTED") == "EXTRACTED":
            extracted[key] += 1
        dep[ps].add(pt)
    cycles = find_cycles(dep)

    def label(i):
        return str(nodes[i].get("label") or i)

    def top(ids, k=3):
        return ", ".join(f"`{label(i)}`" for i in sorted(ids, key=lambda i: -deg[i])[:k])

    def community(ids):
        c = collections.Counter(nodes[i].get("community") for i in ids).most_common(1)
        return "-" if not c or c[0][0] is None else str(c[0][0])

    by_cat = collections.defaultdict(list)
    for p in sorted(members, key=lambda p: -len(members[p])):
        by_cat[classify(p)].append(p)
    god = sorted(nodes, key=lambda i: -deg[i])[: a.top]
    built = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(os.path.getmtime(gpath)))

    md = [
        f"<!-- workflow-step: STEP-1.5 | producer: scripts/graph_inventory.py (draft from graphify-out/graph.json) "
        f"| code commit: {git_sha(a.root)} | graph built: {built} | verify every ⚠️ UNCERTAIN row before GATE-2 -->",
        "# Component Inventory", "",
        f"Draft generated from the code graph: {len(nodes)} nodes, {len(links)} edges, {len(members)} packages. "
        "Package = top-level source directory; roles are graph-derived candidates, not confirmed facts.", "",
        "## Domain Components", "",
        "| Component | Package/Module Path | Role | Core Entities |", "|---------|---------------|------|-----------|",
    ]
    for p in by_cat["domain"] or []:
        md.append(f"| {p} | `{p}/` | ⚠️ UNCERTAIN (auto) — {len(members[p])} nodes, community {community(members[p])} | {top(members[p])} |")
    if not by_cat["domain"]:
        md.append("| (none detected automatically) | | | |")
    md += ["", "## Infrastructure Components", "", "| Component | Type | Purpose | Config Location |", "|---------|------|------|---------|"]
    for p in by_cat["infra"]:
        md.append(f"| {p} | ⚠️ UNCERTAIN (auto) — DB / cache / queue / storage | {len(members[p])} nodes: {top(members[p])} | `{p}/` |")
    if not by_cat["infra"]:
        md.append("| (none detected automatically — check config files by hand) | | | |")
    md += ["", "## Common Components", "", "| Component | Package/Module Path | Role |", "|---------|---------------|------|"]
    for p in by_cat["common"]:
        md.append(f"| {p} | `{p}/` | ⚠️ UNCERTAIN (auto) — auth / logging / error handling / utilities; top: {top(members[p])} |")
    if not by_cat["common"]:
        md.append("| (none detected automatically) | | |")
    md += ["", "## Key Dependencies", "", "| Source → Target | Dependency Type | Notes |", "|-----------|---------|------|"]
    for (ps, pt, rel), n in sorted(edges.items(), key=lambda kv: -kv[1]):
        pct = round(100 * extracted[(ps, pt, rel)] / n)
        note = "" if pct == 100 else f"⚠️ verify — only {pct}% EXTRACTED"
        md.append(f"| {ps} → {pt} | {rel} ({n} edge{'s' if n > 1 else ''}) | {note} |")
    if not edges:
        md.append("| (no cross-package edges) | | |")
    md += ["", "Circular dependency present: " + ("yes — " + ", ".join(f"{x} ↔ {y}" for x, y in cycles) if cycles else "no"), ""]
    md += ["## Reuse Candidates", "", "| Component | Reusable Scope | Conditions/Constraints |", "|---------|--------------|---------|"]
    for i in god:
        n = nodes[i]
        md.append(f"| `{label(i)}` | {pkg_of[i]} (`{n.get('source_file') or '?'}`) | degree {deg[i]}, community {n.get('community', '-')}; ⚠️ UNCERTAIN (auto) — confirm reuse scope |")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")

    print(f"graph_inventory: {len(nodes)} nodes, {len(links)} edges, {len(members)} packages -> {out}")
    print("packages: " + ", ".join(f"{p} ({len(members[p])})" for p in sorted(members, key=lambda p: -len(members[p]))[:10]))
    print("cycles: " + (", ".join(f"{x} ↔ {y}" for x, y in cycles) if cycles else "none"))
    print("god nodes: " + ", ".join(f"{label(i)} ({deg[i]})" for i in god[:5]))
    print("next: verify ⚠️ UNCERTAIN rows; read graphify-out/GRAPH_REPORT.md sections '## God Nodes' and '## Communities' for architecture-overview.md")


if __name__ == "__main__":
    main()
