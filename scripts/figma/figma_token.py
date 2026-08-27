#!/usr/bin/env python3
"""Manage the Figma access token for the scripts/figma tools.

Resolution order used by every script (see resolve_token):
  1. Environment variable (default FIGMA_TOKEN)
  2. Token file ~/.figma-token (chmod 600), overridable via FIGMA_TOKEN_FILE

Commands:
  --check   Report whether a token is resolvable (never prints the value)
  --save    Prompt with hidden input (getpass) and persist to the token file.
            Reads stdin when piped, so a non-TTY caller can do:
              printf '%s' "$TOKEN" | python3 scripts/figma/figma_token.py --save
  --clear   Delete the token file

The token value is never echoed, logged, or written anywhere except the
600-permission token file.
"""
from __future__ import annotations

import argparse
import os
import stat
import sys
from pathlib import Path


def token_file_path() -> Path:
    override = os.environ.get("FIGMA_TOKEN_FILE", "").strip()
    return Path(override).expanduser() if override else Path.home() / ".figma-token"


def read_token_file() -> str:
    path = token_file_path()
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def resolve_token(token_env: str = "FIGMA_TOKEN") -> tuple[str, str]:
    """Return (token, source) where source is 'env', 'file', or ''."""
    token = os.environ.get(token_env, "").strip()
    if token:
        return token, "env"
    token = read_token_file()
    if token:
        return token, "file"
    return "", ""


def save_token() -> int:
    if sys.stdin.isatty():
        import getpass
        token = getpass.getpass("Figma personal access token (input hidden): ").strip()
    else:
        token = sys.stdin.read().strip()
    if not token:
        print("[error] empty token; nothing saved", file=sys.stderr)
        return 2
    path = token_file_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    # Create with owner-only permissions before writing the secret.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(token + "\n")
    os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    print(f"[ok] token saved to {path} (chmod 600). "
          f"Scripts will pick it up automatically.", file=sys.stderr)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--save", action="store_true")
    group.add_argument("--clear", action="store_true")
    parser.add_argument("--token-env", default="FIGMA_TOKEN")
    args = parser.parse_args(argv)

    if args.check:
        _, source = resolve_token(args.token_env)
        if source == "env":
            print(f"[ok] token available from ${args.token_env}")
        elif source == "file":
            print(f"[ok] token available from {token_file_path()}")
        else:
            print("[missing] no token in environment or token file")
            return 1
        return 0
    if args.save:
        return save_token()
    if args.clear:
        path = token_file_path()
        if path.exists():
            path.unlink()
            print(f"[ok] removed {path}", file=sys.stderr)
        else:
            print("[ok] no token file to remove", file=sys.stderr)
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
