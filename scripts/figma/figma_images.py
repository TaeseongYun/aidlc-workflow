#!/usr/bin/env python3
"""Export binary assets + frame renders for a figma_export manifest.

Complements figma_export.py: the manifest records *which* nodes need binary
assets (image fills, vectors/icons, export-flagged nodes), and the image-fill
`src` URLs it resolves are signed and expire — this tool renders those nodes
through the Figma images API into durable local files the platform skills
wire in.

  assets mode (default): manifest -> assets/ + assets-index.json
                         (svg for vectors/icons, webp for image fills — the
                         Figma API renders png; converted locally via cwebp
                         or Pillow so shipped assets stay small)
  --frames             : render each manifest screen as PNG -> frames/ +
                         frames-index.json (visual reference of what was
                         captured, never an implementation source)
  --list               : print asset candidates as JSON and exit (offline)

Usage:
    python3 scripts/figma/figma_images.py --manifest ./out/manifest.json
    python3 scripts/figma/figma_images.py --manifest ./out/manifest.json --frames
    python3 scripts/figma/figma_images.py --demo    # offline self-check

Stdlib only. Token: $FIGMA_TOKEN, else ~/.figma-token (figma_token.py --save).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from figma_token import resolve_token  # noqa: E402

API = "https://api.figma.com/v1"

ICON_NAME_HINTS = ("icon", "ic_", "ic-", "ic/", "logo", "glyph", "symbol")
MAX_ICON_SIZE = 64  # px; small icon-named containers are exported whole
MAX_DOWNLOAD_BYTES = 50 * 1024 * 1024
WEBP_QUALITY = 90


def _default_fmt(kind: str) -> str:
    """Vectors ship as svg; rasters ship as webp (smaller than png in-app)."""
    return "svg" if kind == "vector" else "webp"


def has_webp_encoder() -> bool:
    if shutil.which("cwebp"):
        return True
    try:
        import PIL  # noqa: F401
        return True
    except ImportError:
        return False


def encode_webp(png_path: str, webp_path: str) -> None:
    """PNG -> WebP via cwebp (libwebp), else Pillow. Removes the png on success."""
    if shutil.which("cwebp"):
        subprocess.run(["cwebp", "-quiet", "-q", str(WEBP_QUALITY),
                        png_path, "-o", webp_path], check=True)
    else:
        from PIL import Image
        Image.open(png_path).save(webp_path, "WEBP", quality=WEBP_QUALITY)
    os.unlink(png_path)


def _get(path: str, token: str) -> dict:
    req = urllib.request.Request(f"{API}{path}", headers={"X-Figma-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:500]
        raise SystemExit(f"Figma API {e.code} on {path}: {body}") from e
    except urllib.error.URLError as e:
        raise SystemExit(f"Figma API network error on {path}: {e.reason}") from e


def download_binary(url: str, dest: str) -> None:
    """Download a signed render URL (token-free) with a size cap."""
    if urllib.parse.urlparse(url).scheme != "https":
        raise ValueError(f"refusing non-https download: {url[:60]}")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    total = 0
    with urllib.request.urlopen(urllib.request.Request(url), timeout=60) as resp, \
            open(tmp, "wb") as fh:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_DOWNLOAD_BYTES:
                os.unlink(tmp)
                raise ValueError(f"download exceeded {MAX_DOWNLOAD_BYTES} bytes")
            fh.write(chunk)
    os.replace(tmp, dest)


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value or "").strip("-._").lower()
    return slug or "node"


# --------------------------------------------------------------------------- #
# Candidate collection (offline — walks the manifest IR)
# --------------------------------------------------------------------------- #
def _is_icon_container(node: dict) -> bool:
    """A container that only wraps vectors, or is small and icon-named."""
    children = node.get("children") or []
    if children and all(c.get("type") == "vector" for c in children):
        return True
    size = node.get("size") or {}
    small = ((size.get("width") or 9999) <= MAX_ICON_SIZE
             and (size.get("height") or 9999) <= MAX_ICON_SIZE)
    named_icon = any(h in (node.get("name") or "").lower() for h in ICON_NAME_HINTS)
    return small and named_icon


def collect_candidates(manifest: dict) -> list[dict]:
    """Walk the manifest; a matched node absorbs its subtree (no double export)."""
    candidates: list[dict] = []

    def walk(node: dict) -> None:
        kind = None
        if node.get("type") == "image":
            kind = "image-fill"
        elif node.get("exportHint"):
            kind = "export-setting"
        elif node.get("type") == "vector" or _is_icon_container(node):
            kind = "vector"
        if kind:
            candidates.append({
                "nodeId": node.get("id"),
                "name": node.get("name"),
                "type": node.get("type"),
                "kind": kind,
                "size": node.get("size"),
            })
            return  # do not descend: export the whole node once
        for child in node.get("children") or []:
            walk(child)

    for screen in manifest.get("screens", []):
        walk(screen)

    seen: set[str] = set()
    return [c for c in candidates
            if c["nodeId"] and c["nodeId"] not in seen and not seen.add(c["nodeId"])]


# --------------------------------------------------------------------------- #
# Rendering via the images API
# --------------------------------------------------------------------------- #
def render_urls(file_key: str, ids: list[str], fmt: str, scale: float,
                token: str) -> dict:
    fk = urllib.parse.quote(file_key, safe="")
    urls: dict = {}
    for start in range(0, len(ids), 50):  # API accepts batches; keep them modest
        chunk = ",".join(ids[start:start + 50])
        params = {"ids": chunk, "format": fmt}
        if fmt in ("png", "jpg"):
            params["scale"] = scale
        data = _get(f"/images/{fk}?{urllib.parse.urlencode(params)}", token)
        urls.update(data.get("images") or {})
    return urls


def _download_group(file_key: str, items: list[dict], fmt: str, scale: float,
                    token: str, out_dir: str, subdir: str) -> tuple[list, list]:
    exported, failures = [], []
    # The images API cannot emit webp — render png and convert locally.
    api_fmt = "png" if fmt == "webp" else fmt
    urls = render_urls(file_key, [c["nodeId"] for c in items], api_fmt, scale, token)
    for cand in items:
        url = urls.get(cand["nodeId"])
        if not url:
            failures.append({**cand, "reason": "no render url"})
            continue
        filename = f"{slugify(cand['name'] or cand['nodeId'])}-{slugify(cand['nodeId'])}.{fmt}"
        dest = os.path.join(out_dir, filename)
        try:
            if fmt == "webp":
                download_binary(url, dest + ".png")
                encode_webp(dest + ".png", dest)
            else:
                download_binary(url, dest)
        except (ValueError, OSError, subprocess.CalledProcessError) as err:
            failures.append({**cand, "reason": str(err)})
            continue
        exported.append({**cand, "format": fmt, "file": f"{subdir}/{filename}"})
        print(f"[ok] {cand['name']} -> {subdir}/{filename}", file=sys.stderr)
    return exported, failures


def export_assets(manifest: dict, file_key: str, bundle_dir: str,
                  args: argparse.Namespace, token: str) -> int:
    candidates = collect_candidates(manifest)
    if args.max:
        candidates = candidates[:args.max]
    if not candidates:
        print("[ok] no exportable image/icon nodes found", file=sys.stderr)
        return 0
    out_dir = os.path.join(bundle_dir, "assets")
    webp_ok = has_webp_encoder()
    if args.format == "webp" and not webp_ok:
        raise SystemExit("no WebP encoder: install cwebp (brew install webp) "
                         "or Pillow (pip install pillow)")
    if not args.format and not webp_ok:
        print("[warn] no WebP encoder (cwebp/Pillow) — falling back to png; "
              "install cwebp to keep shipped assets small", file=sys.stderr)
    groups: dict[str, list[dict]] = {}
    for cand in candidates:
        fmt = args.format or _default_fmt(cand["kind"])
        if fmt == "webp" and not webp_ok:
            fmt = "png"
        groups.setdefault(fmt, []).append(cand)
    exported, failures = [], []
    for fmt, group in groups.items():
        done, failed = _download_group(file_key, group, fmt, args.scale, token,
                                       out_dir, "assets")
        exported += done
        failures += failed
    index_path = os.path.join(bundle_dir, "assets-index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({"fileKey": file_key, "exported": exported, "failures": failures},
                  f, indent=2, ensure_ascii=False)
    print(f"[ok] {len(exported)} assets exported, {len(failures)} failed -> {index_path}",
          file=sys.stderr)
    return 0  # partial failures are recorded in the index, not fatal


def export_frames(manifest: dict, file_key: str, bundle_dir: str,
                  args: argparse.Namespace, token: str) -> int:
    screens = [{"nodeId": s.get("id"), "name": s.get("name"),
                "type": s.get("type"), "size": s.get("size")}
               for s in manifest.get("screens", []) if s.get("id")]
    if not screens:
        print("[ok] no screens to render", file=sys.stderr)
        return 0
    out_dir = os.path.join(bundle_dir, "frames")
    scale = args.scale if args.scale != 2.0 else 1.0  # frames default to 1x
    exported, failures = _download_group(file_key, screens, "png", scale, token,
                                         out_dir, "frames")
    index_path = os.path.join(bundle_dir, "frames-index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({"fileKey": file_key, "frames": exported, "failures": failures},
                  f, indent=2, ensure_ascii=False)
    print(f"[ok] {len(exported)} frames rendered, {len(failures)} failed -> {index_path}",
          file=sys.stderr)
    return 0


# --------------------------------------------------------------------------- #
# Offline self-check (ponytail: one runnable check, no network)
# --------------------------------------------------------------------------- #
SAMPLE_MANIFEST = {
    "figmaFileKey": "DEMOKEY",
    "screens": [{
        "id": "1:2", "name": "OrderCard", "type": "stack",
        "size": {"width": 320, "height": 120},
        "children": [
            {"id": "1:3", "name": "Title", "type": "text"},
            {"id": "1:5", "name": "Hero", "type": "image",
             "image": {"ref": "abc123", "src": None}},
            {"id": "1:6", "name": "ic_close", "type": "frame",
             "size": {"width": 24, "height": 24},
             "children": [{"id": "1:7", "name": "path", "type": "vector"}]},
            {"id": "1:8", "name": "Banner", "type": "rect", "exportHint": True,
             "children": [{"id": "1:9", "name": "inner", "type": "image",
                           "image": {"ref": "zzz", "src": None}}]},
        ],
    }],
}


def demo() -> int:
    cands = collect_candidates(SAMPLE_MANIFEST)
    by_id = {c["nodeId"]: c for c in cands}
    assert "1:5" in by_id and by_id["1:5"]["kind"] == "image-fill"
    assert "1:6" in by_id and by_id["1:6"]["kind"] == "vector"  # icon container, whole
    assert "1:7" not in by_id  # absorbed by its container
    assert "1:8" in by_id and by_id["1:8"]["kind"] == "export-setting"
    assert "1:9" not in by_id  # absorbed by the export-flagged parent
    assert "1:3" not in by_id  # plain text is not an asset
    assert slugify("Ic/Close 24") == "ic-close-24"
    assert _default_fmt("vector") == "svg"
    assert _default_fmt("image-fill") == "webp"      # rasters ship as webp, not png
    assert _default_fmt("export-setting") == "webp"
    if has_webp_encoder():  # exercise the real conversion when a codec exists
        import struct, tempfile, zlib

        def _chunk(t: bytes, d: bytes) -> bytes:
            return (struct.pack(">I", len(d)) + t + d
                    + struct.pack(">I", zlib.crc32(t + d)))
        png = (b"\x89PNG\r\n\x1a\n"
               + _chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
               + _chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00"))
               + _chunk(b"IEND", b""))
        with tempfile.TemporaryDirectory() as td:
            src = os.path.join(td, "t.png")
            dst = os.path.join(td, "t.webp")
            with open(src, "wb") as f:
                f.write(png)
            encode_webp(src, dst)
            with open(dst, "rb") as f:
                assert f.read(4) == b"RIFF"          # webp container magic
            assert not os.path.exists(src)           # png removed after convert
    print("figma_images self-check: OK")
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", help="path to figma_export manifest.json")
    ap.add_argument("--format", choices=("webp", "png", "jpg", "svg", "pdf"),
                    help="force one format (default: svg for vectors, webp otherwise)")
    ap.add_argument("--scale", type=float, default=2.0, help="png/jpg scale (default 2)")
    ap.add_argument("--max", type=int, default=0, help="cap exported assets (0 = all)")
    ap.add_argument("--list", action="store_true",
                    help="print candidates as JSON and exit (offline, no token)")
    ap.add_argument("--frames", action="store_true",
                    help="render each manifest screen as PNG into frames/")
    ap.add_argument("--demo", action="store_true", help="run offline self-check and exit")
    args = ap.parse_args()

    if args.demo:
        return demo()
    if not args.manifest:
        ap.error("need --manifest (or use --demo)")

    with open(args.manifest, encoding="utf-8") as f:
        manifest = json.load(f)
    file_key = manifest.get("figmaFileKey")

    if args.list:
        print(json.dumps({"fileKey": file_key,
                          "candidates": collect_candidates(manifest)},
                         indent=2, ensure_ascii=False))
        return 0
    if not file_key:
        raise SystemExit("manifest has no figmaFileKey; cannot call the images API")

    # Outputs land next to the manifest; confine that to the working tree,
    # same rule as figma_export --out.
    bundle_dir = os.path.realpath(os.path.dirname(os.path.abspath(args.manifest)))
    cwd = os.path.realpath(os.getcwd())
    if os.path.commonpath([bundle_dir, cwd]) != cwd:
        raise SystemExit(f"manifest must live under {cwd}")

    token, _source = resolve_token()
    if not token:
        raise SystemExit("no Figma token: export FIGMA_TOKEN or run "
                         "'python3 scripts/figma/figma_token.py --save'")

    if args.frames:
        return export_frames(manifest, file_key, bundle_dir, args, token)
    return export_assets(manifest, file_key, bundle_dir, args, token)


if __name__ == "__main__":
    sys.exit(main())
