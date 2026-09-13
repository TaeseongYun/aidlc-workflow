#!/usr/bin/env python3
"""validate_envelope.py — offline checker for bridge message envelopes.

Validates one message (or a captured log of messages) against the envelope
rules in SKILL.md §2. Platform-neutral, standard library only. Use it in guard
mode against real captured traffic, and in generator mode to self-check the
examples a skeleton emits.

Input: a JSON file that is either one envelope object, or an array of envelopes
(e.g. a captured message log). `-` reads stdin.

  python3 validate_envelope.py messages.json
  python3 validate_envelope.py --capabilities bridge.init,device.getInfo msg.json
  cat one.json | python3 validate_envelope.py -

Exit: 0 all valid · 1 one or more violations · 2 bad input.
Findings print one per line as: <index> <severity> <rule> <detail>.
"""
from __future__ import annotations

import argparse
import json
import sys

VALID_TYPES = {"request", "response", "event"}
RESERVED_CODES = {"UNKNOWN_METHOD", "INVALID_PAYLOAD", "PAYLOAD_TOO_LARGE",
                  "TIMEOUT", "INTERNAL"}


def check(env: object, idx: int, caps: set[str] | None, max_bytes: int) -> list[str]:
    f: list[str] = []
    tag = f"[{idx}]"
    if not isinstance(env, dict):
        return [f"{tag} CRITICAL not-an-object envelope must be a JSON object"]

    t = env.get("type")
    if t not in VALID_TYPES:
        f.append(f"{tag} CRITICAL bad-type type must be one of {sorted(VALID_TYPES)}, got {t!r}")
    if not isinstance(env.get("method"), str) or not env.get("method"):
        f.append(f"{tag} CRITICAL missing-method method must be a non-empty string")

    has_id = isinstance(env.get("id"), str) and env.get("id")
    if t in ("request", "response") and not has_id:
        f.append(f"{tag} HIGH missing-id {t} must carry a string id for correlation")
    if t == "event" and env.get("id"):
        f.append(f"{tag} LOW event-has-id event carries no id / reply obligation")

    err = env.get("error")
    if t == "request" and err is not None:
        f.append(f"{tag} HIGH request-has-error error must be null on a request")
    if t == "response" and err is not None:
        if not (isinstance(err, dict) and isinstance(err.get("code"), str)):
            f.append(f"{tag} HIGH bad-error error needs a string code + message")
        elif err.get("payload") is not None and env.get("payload"):
            f.append(f"{tag} MEDIUM error-and-payload a response has either payload OR error, not both")
        elif err.get("code") not in RESERVED_CODES and not str(err.get("code", "")).islower():
            # reserved codes are UPPER; contract codes are allowed but flagged for review
            f.append(f"{tag} LOW nonreserved-code {err.get('code')!r} not in the reserved set — confirm it is in the contract")

    if caps is not None and t == "request" and isinstance(env.get("method"), str):
        if env["method"] not in caps:
            f.append(f"{tag} HIGH unknown-method {env['method']!r} not in capabilities → must return UNKNOWN_METHOD")

    size = len(json.dumps(env).encode("utf-8"))
    if size > max_bytes:
        f.append(f"{tag} MEDIUM payload-too-large {size}B > {max_bytes}B bound")
    return f


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("file", help="JSON file (envelope or array); - for stdin")
    ap.add_argument("--capabilities", help="comma-separated allowed methods (enables UNKNOWN_METHOD check)")
    ap.add_argument("--max-bytes", type=int, default=262144, help="payload size bound (default 256KiB)")
    args = ap.parse_args()

    raw = sys.stdin.read() if args.file == "-" else open(args.file, encoding="utf-8").read()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[input] CRITICAL invalid-json {e}", file=sys.stderr)
        return 2

    caps = set(c.strip() for c in args.capabilities.split(",")) if args.capabilities else None
    msgs = data if isinstance(data, list) else [data]
    findings: list[str] = []
    for i, env in enumerate(msgs):
        findings += check(env, i, caps, args.max_bytes)

    for line in findings:
        print(line)
    print(f"\n{len(msgs)} message(s), {len(findings)} finding(s)", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
