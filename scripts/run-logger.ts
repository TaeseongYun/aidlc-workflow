#!/usr/bin/env -S npx tsx
/**
 * Run-result logger for aidlc-workflow.
 *
 * Records "what results the AI processed" during an agentic run as typed,
 * append-only records, so later runs (and graphify) can retrieve them.
 *
 * Two artifacts per project, both under <project>/aidlc-docs/:
 *   - run-log.ndjson  -> source of truth. One RunLogEntry per line. Append-only.
 *   - run-log.md      -> deterministic Markdown mirror, regenerated on every append.
 *                        graphify ingests Markdown, so a `graphify .` / `--update`
 *                        rebuild picks this up and the run history becomes
 *                        graph-queryable (`graphify query "..."`). The logger never
 *                        calls graphify itself — ingestion is passive, so graphify
 *                        stays a soft dependency. When graphify is absent, `recall`
 *                        reads the NDJSON locally (degraded mode).
 *
 * Protocol (when to append, how to recall): common/run-logging.md
 *
 * Usage:
 *   run-logger.ts append --project . --feature <slug> --skill <name> \
 *                 --phase <p> --kind <k> --result "<text>" \
 *                 [--detail "..."] [--artifacts a,b] [--refs a,b] \
 *                 [--confidence certain|estimated|ai-recommended|undecided] \
 *                 [--mode full|degraded]
 *   run-logger.ts append --project . --json '{"feature":"x",...}'
 *   run-logger.ts append --project . --stdin        # JSON entry piped on stdin
 *   run-logger.ts recall --project . [--feature <slug>] [--kind <k>] [--limit N]   # N=0 -> all
 *   run-logger.ts --selftest
 *
 * Exit codes:  0 = success   2 = usage / validation error   1 = unexpected failure (I/O)
 * Run with `npx tsx` (or bun). Node stdlib only — no package.json / tsconfig.
 */

import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const KINDS = ["gate", "score", "unit", "hallucination", "note"] as const;
type Kind = (typeof KINDS)[number];
const CONFIDENCES = ["certain", "estimated", "ai-recommended", "undecided"] as const;
type Confidence = (typeof CONFIDENCES)[number];
const MODES = ["full", "degraded"] as const;
type Mode = (typeof MODES)[number];

interface RunLogEntry {
  ts: string; // ISO 8601 UTC
  feature: string; // feature slug, or "_project" for project-level
  skill: string; // e.g. "ctx-score-loop"
  phase: string; // e.g. "GATE-2", "score-round-3", "hallucination-audit"
  kind: Kind;
  result: string; // short outcome, e.g. "COMPLETE (over 85)"
  detail?: string;
  artifacts?: string[]; // files produced/touched
  refs?: string[]; // file:line, HAL-NNN, Linear URL, git SHA
  confidence?: Confidence;
  mode?: Mode;
}

function fail(msg: string): never {
  process.stderr.write(`ERROR: ${msg}\n`);
  process.exit(2);
}

function parseJsonOrFail(raw: string, source: string): Partial<RunLogEntry> {
  try {
    return JSON.parse(raw);
  } catch (err) {
    fail(`${source} is not valid JSON: ${(err as Error).message}`);
  }
}

// --- arg parsing (stdlib only): supports "--flag value" and "--flag=value" ---
// Every flag except these takes a value; a value-flag followed by another
// "--token" used to silently become "true" (data corruption in the log).
const BOOLEAN_FLAGS = new Set(["stdin", "selftest"]);
function parseArgs(argv: string[]): { _: string[]; flags: Record<string, string> } {
  const _: string[] = [];
  const flags: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      if (eq !== -1) {
        flags[a.slice(2, eq)] = a.slice(eq + 1);
      } else {
        const name = a.slice(2);
        if (BOOLEAN_FLAGS.has(name)) {
          flags[name] = "true";
        } else {
          const next = argv[i + 1];
          if (next === undefined || next.startsWith("--")) {
            fail(`flag --${name} requires a value (use --${name}=<value> if the value starts with "-")`);
          }
          flags[name] = next;
          i++;
        }
      }
    } else {
      _.push(a);
    }
  }
  return { _, flags };
}

function docsDir(project: string): string {
  return path.join(path.resolve(project), "aidlc-docs");
}
function ndjsonPath(project: string): string {
  return path.join(docsDir(project), "run-log.ndjson");
}
function mirrorPath(project: string): string {
  return path.join(docsDir(project), "run-log.md");
}

function splitList(v?: string): string[] | undefined {
  if (!v) return undefined;
  const items = v
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return items.length ? items : undefined;
}

function readEntries(project: string): RunLogEntry[] {
  const p = ndjsonPath(project);
  if (!fs.existsSync(p)) return [];
  // Tolerant read: a corrupt line is warned about and skipped, never fatal —
  // otherwise one bad line would brick every subsequent append (the mirror
  // rebuild runs after each append and would die forever).
  const entries: RunLogEntry[] = [];
  const lines = fs.readFileSync(p, "utf8").split("\n");
  lines.forEach((raw, idx) => {
    const l = raw.trim();
    if (!l) return;
    try {
      entries.push(JSON.parse(l) as RunLogEntry);
    } catch {
      process.stderr.write(`WARN: run-log.ndjson line ${idx + 1} is not valid JSON — skipped\n`);
    }
  });
  return entries;
}

function validate(e: Partial<RunLogEntry>): RunLogEntry {
  // Type-strict: valid-JSON-with-wrong-types must be rejected BEFORE the append,
  // otherwise the poisoned line breaks every later mirror rebuild.
  for (const k of ["feature", "skill", "phase", "kind", "result"] as const) {
    if (typeof e[k] !== "string" || (e[k] as string).trim() === "")
      fail(`field ${k} must be a non-empty string`);
  }
  for (const k of ["feature", "skill", "phase", "kind"] as const) {
    if (/[\r\n]/.test(e[k] as string))
      fail(`field ${k} must be single-line (newlines break the markdown mirror)`);
  }
  for (const k of ["detail", "ts"] as const) {
    if (e[k] !== undefined && typeof e[k] !== "string") fail(`field ${k} must be a string`);
  }
  for (const k of ["artifacts", "refs"] as const) {
    const v = e[k];
    if (v !== undefined && (!Array.isArray(v) || v.some((x) => typeof x !== "string")))
      fail(`field ${k} must be an array of strings`);
  }
  if (!KINDS.includes(e.kind as Kind)) fail(`--kind must be one of: ${KINDS.join(", ")}`);
  if (e.confidence && !CONFIDENCES.includes(e.confidence))
    fail(`--confidence must be one of: ${CONFIDENCES.join(", ")}`);
  if (e.mode && !MODES.includes(e.mode)) fail(`--mode must be one of: ${MODES.join(", ")}`);
  return {
    ts: e.ts && String(e.ts).trim() ? e.ts! : new Date().toISOString(),
    feature: e.feature!,
    skill: e.skill!,
    phase: e.phase!,
    kind: e.kind!,
    result: e.result!,
    ...(e.detail ? { detail: e.detail } : {}),
    ...(e.artifacts && e.artifacts.length ? { artifacts: e.artifacts } : {}),
    ...(e.refs && e.refs.length ? { refs: e.refs } : {}),
    ...(e.confidence ? { confidence: e.confidence } : {}),
    ...(e.mode ? { mode: e.mode } : {}),
  };
}

// Deterministic Markdown mirror — headings so graphify creates stable nodes.
function renderMirror(entries: RunLogEntry[]): string {
  const out: string[] = [
    "# Run Log",
    "",
    "Auto-generated by `scripts/run-logger.ts` from `run-log.ndjson` — **do not edit by hand**.",
    "Structured record of results the AI produced across runs. graphify ingests this file, so a",
    "`graphify .` / `graphify . --update` rebuild makes the history graph-queryable.",
    "",
  ];
  // Group by feature in first-seen order; entries stay chronological (file order).
  const order: string[] = [];
  const byFeature = new Map<string, RunLogEntry[]>();
  for (const e of entries) {
    if (!byFeature.has(e.feature)) {
      byFeature.set(e.feature, []);
      order.push(e.feature);
    }
    byFeature.get(e.feature)!.push(e);
  }
  if (entries.length === 0) out.push("_No entries yet._", "");
  for (const feat of order) {
    out.push(`## Feature: ${String(feat ?? "").replace(/\s*[\r\n]+\s*/g, " ")}`, "");
    for (const e of byFeature.get(feat)!) {
      // NDJSON keeps raw text; the mirror flattens newlines so a multi-line
      // value cannot break the heading/bullet structure graphify ingests.
      // Defensive on types too: pre-validation entries (or hand-edits) with
      // wrong-typed fields must degrade, not brick every later rebuild.
      const oneLine = (s: unknown) => String(s ?? "").replace(/\s*[\r\n]+\s*/g, " ");
      const asList = (v: unknown) => (Array.isArray(v) ? v : [v]).map(oneLine).join(", ");
      out.push(`### ${oneLine(e.ts)} — ${oneLine(e.skill)} · ${oneLine(e.phase)} · ${oneLine(e.kind)}`);
      out.push(`- Result: ${oneLine(e.result)}`);
      if (e.detail) out.push(`- Detail: ${oneLine(e.detail)}`);
      if (e.artifacts && (!Array.isArray(e.artifacts) || e.artifacts.length)) out.push(`- Artifacts: ${asList(e.artifacts)}`);
      if (e.refs && (!Array.isArray(e.refs) || e.refs.length)) out.push(`- Refs: ${asList(e.refs)}`);
      const tags: string[] = [];
      if (e.confidence) tags.push(`Confidence: ${e.confidence}`);
      if (e.mode) tags.push(`Mode: ${e.mode}`);
      if (tags.length) out.push(`- ${tags.join(" · ")}`);
      out.push("");
    }
  }
  return out.join("\n").replace(/\n+$/, "\n");
}

function cmdAppend(flags: Record<string, string>): void {
  const project = flags.project || ".";
  let partial: Partial<RunLogEntry>;

  if (flags.json && flags.json !== "true") {
    partial = parseJsonOrFail(flags.json, "--json");
  } else if (flags.stdin === "true") {
    // Explicit opt-in only. Sniffing isTTY here was backwards for the real
    // callers (agents shelling out): a forgotten --feature flag turned into a
    // blocking read on an inherited pipe instead of a validation error.
    const raw = fs.readFileSync(0, "utf8").trim();
    if (!raw) fail("no entry provided on stdin (use flags, --json, or --stdin with piped JSON)");
    partial = parseJsonOrFail(raw, "stdin");
  } else {
    partial = {
      ts: flags.ts,
      feature: flags.feature,
      skill: flags.skill,
      phase: flags.phase,
      kind: flags.kind as Kind,
      result: flags.result,
      detail: flags.detail,
      artifacts: splitList(flags.artifacts),
      refs: splitList(flags.refs),
      confidence: flags.confidence as Confidence,
      mode: flags.mode as Mode,
    };
  }

  const entry = validate(partial);
  const dir = docsDir(project);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.appendFileSync(ndjsonPath(project), JSON.stringify(entry) + "\n");
  fs.writeFileSync(mirrorPath(project), renderMirror(readEntries(project)));
  process.stdout.write(`OK: appended ${entry.kind} for ${entry.feature} (${entry.phase})\n`);
}

function cmdRecall(flags: Record<string, string>): void {
  const project = flags.project || ".";
  let entries = readEntries(project);
  if (flags.feature) entries = entries.filter((e) => e.feature === flags.feature);
  if (flags.kind) entries = entries.filter((e) => e.kind === flags.kind);
  let limit = 20;
  if (flags.limit !== undefined) {
    if (!/^\d+$/.test(flags.limit)) fail(`--limit must be a non-negative integer (0 = all), got "${flags.limit}"`);
    limit = parseInt(flags.limit, 10);
  }
  const slice = limit > 0 ? entries.slice(-limit) : entries;
  process.stderr.write(
    `# ${slice.length} entr${slice.length === 1 ? "y" : "ies"}` +
      ` — when a graph is present, prefer: graphify query "<question>"\n`,
  );
  for (const e of slice) process.stdout.write(JSON.stringify(e) + "\n");
}

function selftest(): void {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "runlog-"));
  // Track the exit code and exit AFTER the finally block: process.exit()
  // inside try skips finally, which leaked the temp dir on every success.
  let rc = 0;
  try {
    cmdAppend({
      project: dir,
      feature: "demo",
      skill: "ctx-score-loop",
      phase: "score-round-1",
      kind: "score",
      result: "COMPLETE (over 85)",
      refs: "dependency-check.md:120",
    });
    cmdAppend({
      project: dir,
      feature: "demo",
      skill: "ctx-hallucination-audit",
      phase: "round-2",
      kind: "hallucination",
      result: "1 refuted, 1 corrected, score 91",
    });
    const lines = fs.readFileSync(ndjsonPath(dir), "utf8").trim().split("\n");
    assert(lines.length === 2, `expected 2 ndjson lines, got ${lines.length}`);
    const first = JSON.parse(lines[0]) as RunLogEntry;
    assert(!!first.ts && first.kind === "score", "first entry not well-formed");
    const md = fs.readFileSync(mirrorPath(dir), "utf8");
    assert(md.includes("## Feature: demo"), "mirror missing feature heading");
    assert(md.includes("COMPLETE (over 85)"), "mirror missing result text");
    assert(md.includes("Refs: dependency-check.md:120"), "mirror missing refs");
    // recall filter round-trips
    const captured: string[] = [];
    const orig = process.stdout.write.bind(process.stdout);
    (process.stdout.write as unknown as (s: string) => boolean) = (s: string) => {
      captured.push(s);
      return true;
    };
    try {
      cmdRecall({ project: dir, kind: "hallucination" });
    } finally {
      (process.stdout.write as unknown) = orig;
    }
    const recalled = captured.join("").trim().split("\n").filter(Boolean);
    assert(recalled.length === 1, `recall(kind=hallucination) expected 1, got ${recalled.length}`);
    // corrupt-line tolerance: a bad NDJSON line must not brick appends
    fs.appendFileSync(ndjsonPath(dir), "{not json}\n");
    cmdAppend({
      project: dir,
      feature: "demo",
      skill: "ctx-score-loop",
      phase: "score-round-2",
      kind: "score",
      result: "after corrupt line",
    });
    assert(
      fs.readFileSync(mirrorPath(dir), "utf8").includes("after corrupt line"),
      "append after corrupt ndjson line did not reach the mirror",
    );
    process.stderr.write("selftest: PASS\n");
  } catch (err) {
    process.stderr.write(`selftest: FAIL — ${(err as Error).message}\n`);
    rc = 1;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  process.exit(rc);
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function main(): void {
  const argv = process.argv.slice(2);
  if (argv.includes("--selftest")) return selftest();
  const { _, flags } = parseArgs(argv);
  const cmd = _[0];
  switch (cmd) {
    case "append":
      return cmdAppend(flags);
    case "recall":
      return cmdRecall(flags);
    default:
      fail(`unknown command "${cmd ?? ""}". Use: append | recall | --selftest`);
  }
}

try {
  main();
} catch (err) {
  // I/O faults (permissions, missing mount) get a clean message, not a stack dump.
  process.stderr.write(`ERROR: ${(err as Error).message}\n`);
  process.exit(1);
}
