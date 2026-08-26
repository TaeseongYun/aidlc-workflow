#!/usr/bin/env python3
"""Figma -> platform-agnostic manifest + DTCG design tokens.

Pulls a Figma file (or a specific frame/screen node) via the Figma REST API and
emits two reproducible artifacts that every platform's `*-figma-to-code` skill
consumes:

  - manifest.json : a normalized, platform-agnostic UI tree (the "manifest").
                    Auto-layout is resolved to row/column/gap/padding, sizing to
                    fixed/fill/hug, component instances to {component, props}.
  - tokens.json   : design tokens in W3C DTCG format (color/dimension/typography),
                    extracted from Figma variables when available, else from
                    published styles.

Stdlib only (urllib) — no third-party deps. The manifest/tokens are the contract;
per-platform emitters (documented in each skill's reference.md) walk this tree.

Usage:
    export FIGMA_TOKEN=figd_xxx           # personal access token
    python figma_export.py --file <FILE_KEY> [--node <NODE_ID>] [--out ./out]

    # Offline self-check (no token / no network needed):
    python figma_export.py --demo

The file key and node id come from a Figma URL:
    https://www.figma.com/design/<FILE_KEY>/Name?node-id=<NODE_ID>
(node-id in the URL uses "-", the API uses ":" — this tool accepts either.)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.figma.com/v1"

# Figma node types that behave as containers.
CONTAINER_TYPES = {"FRAME", "GROUP", "COMPONENT", "COMPONENT_SET", "SECTION"}


# --------------------------------------------------------------------------- #
# REST client
# --------------------------------------------------------------------------- #
def _get(path: str, token: str) -> dict:
    req = urllib.request.Request(f"{API}{path}", headers={"X-Figma-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:500]
        raise SystemExit(f"Figma API {e.code} on {path}: {body}") from e
    except urllib.error.URLError as e:  # DNS/timeout/refused — clean exit, not a traceback
        raise SystemExit(f"Figma API network error on {path}: {e.reason}") from e


def fetch_nodes(file_key: str, node_id: str | None, token: str) -> list[dict]:
    """Return the list of Figma document nodes to normalize."""
    fk = urllib.parse.quote(file_key, safe="")  # key is path-segment data, encode it
    if node_id:
        nid = node_id.replace("-", ":")  # URL form -> API form
        data = _get(f"/files/{fk}/nodes?ids={urllib.parse.quote(nid)}", token)
        docs = [n["document"] for n in data.get("nodes", {}).values() if n]
        if not docs:
            raise SystemExit(f"node {node_id} not found in {file_key}")
        return docs
    data = _get(f"/files/{fk}", token)
    # Default: the top-level frames on the first page.
    pages = (data.get("document") or {}).get("children") or []
    if not pages or not pages[0].get("children"):
        raise SystemExit(f"no pages/frames found in {file_key}")
    frames = [c for c in pages[0]["children"] if c.get("type") in CONTAINER_TYPES]
    return frames or pages[0]["children"]


def fetch_variables(file_key: str, token: str) -> dict | None:
    """Local variables (Enterprise plan only). Returns None if unavailable."""
    try:
        fk = urllib.parse.quote(file_key, safe="")
        return _get(f"/files/{fk}/variables/local", token)
    except SystemExit:
        return None  # 403/404 on non-Enterprise plans -> fall back to styles


# --------------------------------------------------------------------------- #
# Normalization: Figma node -> manifest IR
# --------------------------------------------------------------------------- #
def color_to_hex(color: dict, opacity: float | None = None) -> str:
    r = round(color.get("r", 0) * 255)
    g = round(color.get("g", 0) * 255)
    b = round(color.get("b", 0) * 255)
    a = color.get("a", 1) if opacity is None else opacity * color.get("a", 1)
    if a >= 0.999:
        return f"#{r:02x}{g:02x}{b:02x}"
    return f"#{r:02x}{g:02x}{b:02x}{round(a * 255):02x}"


def _solid_fill(node: dict) -> str | None:
    for f in node.get("fills", []):
        if f.get("type") == "SOLID" and f.get("visible", True):
            return color_to_hex(f["color"], f.get("opacity"))
    return None


def _has_image_fill(node: dict) -> bool:
    return any(f.get("type") == "IMAGE" for f in node.get("fills", []))


def _image_ref(node: dict) -> str | None:
    for f in node.get("fills", []):
        if f.get("type") == "IMAGE" and f.get("imageRef"):
            return f["imageRef"]
    return None


_ALIGN = {
    "MIN": "start",
    "CENTER": "center",
    "MAX": "end",
    "SPACE_BETWEEN": "between",
    "BASELINE": "baseline",
}


def _norm_type(node: dict) -> str:
    t = node.get("type", "")
    if t == "TEXT":
        return "text"
    if t == "INSTANCE":
        return "instance"
    if t in ("RECTANGLE", "ELLIPSE") and _has_image_fill(node):
        return "image"
    if t in ("VECTOR", "LINE", "STAR", "POLYGON", "BOOLEAN_OPERATION"):
        return "vector"
    if t in ("RECTANGLE", "ELLIPSE"):
        return "rect"
    if node.get("layoutMode") in ("HORIZONTAL", "VERTICAL"):
        return "stack"
    return "frame"


def _layout(node: dict) -> dict:
    mode = node.get("layoutMode", "NONE")
    direction = {"HORIZONTAL": "row", "VERTICAL": "column"}.get(mode, "none")
    return {
        "direction": direction,
        "gap": node.get("itemSpacing", 0) if direction != "none" else 0,
        "padding": {
            "top": node.get("paddingTop", 0),
            "right": node.get("paddingRight", 0),
            "bottom": node.get("paddingBottom", 0),
            "left": node.get("paddingLeft", 0),
        },
        "justify": _ALIGN.get(node.get("primaryAxisAlignItems", "MIN"), "start"),
        "align": _ALIGN.get(node.get("counterAxisAlignItems", "MIN"), "start"),
        "wrap": node.get("layoutWrap") == "WRAP",
    }


def _size(node: dict) -> dict:
    box = node.get("absoluteBoundingBox") or {}
    # layoutSizing{Horizontal,Vertical}: FIXED | FILL | HUG (auto-layout aware)
    hmode = node.get("layoutSizingHorizontal", "FIXED").lower()
    vmode = node.get("layoutSizingVertical", "FIXED").lower()
    return {
        "width": box.get("width"),
        "height": box.get("height"),
        "widthMode": hmode,
        "heightMode": vmode,
    }


def _text(node: dict) -> dict:
    st = node.get("style", {})
    return {
        "content": node.get("characters", ""),
        "style": {
            "fontFamily": st.get("fontFamily"),
            "fontSize": st.get("fontSize"),
            "fontWeight": st.get("fontWeight"),
            "lineHeight": st.get("lineHeightPx"),
            "letterSpacing": st.get("letterSpacing"),
            "color": _solid_fill(node),
        },
    }


def _style(node: dict) -> dict:
    style = {
        "fill": _solid_fill(node),
        "cornerRadius": node.get("cornerRadius"),
        "opacity": node.get("opacity"),
    }
    strokes = node.get("strokes", [])
    if strokes:
        s = strokes[0]
        if s.get("type") == "SOLID":
            style["border"] = {
                "color": color_to_hex(s["color"], s.get("opacity")),
                "width": node.get("strokeWeight", 1),
            }
    # A bound variable / style ref makes the value a *token*, not a raw literal.
    bound = node.get("boundVariables") or {}
    styles = node.get("styles") or {}
    if bound.get("fills") or styles.get("fill"):
        style["fillToken"] = True
    return {k: v for k, v in style.items() if v is not None}


def normalize_node(node: dict) -> dict:
    """Figma document node -> manifest IR node (recursive)."""
    ntype = _norm_type(node)
    out: dict = {
        "id": node.get("id"),
        "name": node.get("name"),
        "type": ntype,
        "size": _size(node),
    }
    style = _style(node)
    if style:
        out["style"] = style
    if ntype in ("frame", "stack"):
        out["layout"] = _layout(node)
    if ntype == "text":
        out["text"] = _text(node)
    if ntype == "image":
        # Raster fills carry an imageRef; the download URL is resolved separately
        # (fetch_image_fills) since it needs another endpoint.
        out["image"] = {"ref": _image_ref(node), "src": None}
    if ntype == "instance":
        out["component"] = {
            "id": node.get("componentId"),
            "name": node.get("name"),
            # componentProperties: variant/boolean/text overrides -> component props
            "props": {
                k: v.get("value") if isinstance(v, dict) else v
                for k, v in (node.get("componentProperties") or {}).items()
            },
        }
    children = [
        normalize_node(c)
        for c in node.get("children", [])
        if c.get("visible", True)
    ]
    if children:
        out["children"] = children
    return out


def build_manifest(file_key: str, docs: list[dict]) -> dict:
    roots = [normalize_node(d) for d in docs]
    return {
        "figmaFileKey": file_key,
        "screens": roots,
    }


def fetch_image_fills(file_key: str, token: str) -> dict:
    """imageRef -> download URL, for raster image fills."""
    fk = urllib.parse.quote(file_key, safe="")
    data = _get(f"/files/{fk}/images", token)
    return (data.get("meta") or {}).get("images", {}) or {}


def resolve_image_srcs(manifest: dict, images: dict) -> None:
    """Fill each image node's src from the imageRef->URL map, in place."""
    def walk(n: dict) -> None:
        img = n.get("image")
        if img and img.get("ref") in images:
            img["src"] = images[img["ref"]]
        for c in n.get("children", []):
            walk(c)
    for s in manifest.get("screens", []):
        walk(s)


# --------------------------------------------------------------------------- #
# Design tokens -> DTCG (https://tr.designtokens.org/format/)
# --------------------------------------------------------------------------- #
def _set(tree: dict, path: list[str], token: dict) -> None:
    node = tree
    for part in path[:-1]:
        node = node.setdefault(part, {})
    node[path[-1]] = token


def _slug(name: str) -> list[str]:
    # "Color/Brand/Primary" or "brand.primary" -> ["color","brand","primary"]
    parts = name.replace(".", "/").split("/")
    return [p.strip().lower().replace(" ", "-") for p in parts if p.strip()]


def tokens_from_variables(vars_payload: dict) -> dict:
    """Figma local variables -> DTCG tokens."""
    meta = vars_payload.get("meta", {})
    collections = meta.get("variableCollections", {})
    out: dict = {}
    for var in meta.get("variables", {}).values():
        coll = collections.get(var.get("variableCollectionId"), {})
        modes = coll.get("modes", [])
        if not modes:
            continue
        default_mode = modes[0]["modeId"]
        raw = var.get("valuesByMode", {}).get(default_mode)
        vtype = var.get("resolvedType")
        if vtype == "COLOR" and isinstance(raw, dict) and "r" in raw:
            token = {"$type": "color", "$value": color_to_hex(raw)}
        elif vtype == "FLOAT" and isinstance(raw, (int, float)):
            token = {"$type": "dimension", "$value": raw}
        elif vtype == "STRING" and isinstance(raw, str):
            token = {"$type": "string", "$value": raw}
        else:
            # BOOLEAN, or an alias ({"type":"VARIABLE_ALIAS",...}) — skip for the
            # baseline rather than emit an invalid DTCG value.
            continue
        _set(out, _slug(var.get("name", "")), token)
    return out


def tokens_from_styles(file_key: str, token: str) -> dict:
    """Fallback: published styles -> DTCG color + typography tokens."""
    fk = urllib.parse.quote(file_key, safe="")
    data = _get(f"/files/{fk}", token)
    styles_meta = data.get("styles", {})
    # Map style-node-id -> its properties by walking the document.
    props: dict[str, dict] = {}

    def walk(n: dict) -> None:
        sid = (n.get("styles") or {}).get("fill")
        if sid:  # any node carrying a fill style with a resolvable solid color
            hexv = _solid_fill(n)
            if hexv:
                props.setdefault(sid, {"type": "color", "value": hexv})
        tid = (n.get("styles") or {}).get("text")
        if tid and n.get("type") == "TEXT":
            props.setdefault(tid, {"type": "typography", "value": _text(n)["style"]})
        for c in n.get("children", []):
            walk(c)

    walk(data["document"])
    out: dict = {}
    for sid, meta in styles_meta.items():
        p = props.get(sid)
        if not p:
            continue
        if p["type"] == "color":
            _set(out, _slug(meta["name"]), {"$type": "color", "$value": p["value"]})
        elif p["type"] == "typography":
            v = p["value"]
            _set(
                out,
                _slug(meta["name"]),
                {
                    "$type": "typography",
                    "$value": {
                        "fontFamily": v.get("fontFamily"),
                        "fontSize": v.get("fontSize"),
                        "fontWeight": v.get("fontWeight"),
                        "lineHeight": v.get("lineHeight"),
                    },
                },
            )
    return out


def extract_tokens(file_key: str, token: str) -> dict:
    vars_payload = fetch_variables(file_key, token)
    if vars_payload:
        toks = tokens_from_variables(vars_payload)
        if toks:
            return toks
    return tokens_from_styles(file_key, token)  # style fallback


# --------------------------------------------------------------------------- #
# Offline self-check (ponytail: one runnable check, no network)
# --------------------------------------------------------------------------- #
SAMPLE_NODE = {
    "id": "1:2",
    "name": "OrderCard",
    "type": "FRAME",
    "layoutMode": "VERTICAL",
    "itemSpacing": 8,
    "paddingTop": 16,
    "paddingLeft": 16,
    "paddingRight": 16,
    "paddingBottom": 16,
    "counterAxisAlignItems": "CENTER",
    "primaryAxisAlignItems": "MIN",
    "absoluteBoundingBox": {"width": 320, "height": 120},
    "layoutSizingHorizontal": "FILL",
    "layoutSizingVertical": "HUG",
    "cornerRadius": 12,
    "fills": [{"type": "SOLID", "visible": True, "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
    "children": [
        {
            "id": "1:3",
            "type": "TEXT",
            "name": "Title",
            "characters": "Order #42",
            "style": {"fontFamily": "Inter", "fontSize": 18, "fontWeight": 600, "lineHeightPx": 24},
            "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.1, "b": 0.1, "a": 1}}],
        },
        {
            "id": "1:4",
            "type": "INSTANCE",
            "name": "PrimaryButton",
            "componentId": "9:9",
            "componentProperties": {"label": {"type": "TEXT", "value": "Pay"}},
            "absoluteBoundingBox": {"width": 288, "height": 44},
        },
        {
            "id": "1:5",
            "type": "RECTANGLE",
            "name": "Hero",
            "absoluteBoundingBox": {"width": 288, "height": 160},
            "fills": [{"type": "IMAGE", "imageRef": "abc123", "scaleMode": "FILL"}],
        },
    ],
}


def demo() -> int:
    m = build_manifest("DEMOKEY", [SAMPLE_NODE])
    root = m["screens"][0]
    assert root["type"] == "stack", root["type"]
    assert root["layout"]["direction"] == "column"
    assert root["layout"]["gap"] == 8
    assert root["layout"]["padding"]["left"] == 16
    assert root["layout"]["align"] == "center"
    assert root["size"]["widthMode"] == "fill"
    assert root["size"]["heightMode"] == "hug"
    assert root["style"]["cornerRadius"] == 12
    assert root["style"]["fill"] == "#ffffff"
    title, button, hero = root["children"]
    assert title["type"] == "text"
    assert title["text"]["content"] == "Order #42"
    assert title["text"]["style"]["fontSize"] == 18
    assert title["text"]["style"]["color"] == "#1a1a1a"
    assert button["type"] == "instance"
    assert button["component"]["props"]["label"] == "Pay"
    assert hero["type"] == "image"
    assert hero["image"]["ref"] == "abc123"
    assert hero["image"]["src"] is None  # resolved online via fetch_image_fills

    resolve_image_srcs(m, {"abc123": "https://img.example/hero.png"})
    assert m["screens"][0]["children"][2]["image"]["src"] == "https://img.example/hero.png"

    toks = tokens_from_variables(
        {
            "meta": {
                "variableCollections": {"c1": {"modes": [{"modeId": "m1"}]}},
                "variables": {
                    "v1": {
                        "name": "Color/Brand/Primary",
                        "variableCollectionId": "c1",
                        "resolvedType": "COLOR",
                        "valuesByMode": {"m1": {"r": 0.2, "g": 0.4, "b": 1, "a": 1}},
                    },
                    "v2": {
                        "name": "Space/md",
                        "variableCollectionId": "c1",
                        "resolvedType": "FLOAT",
                        "valuesByMode": {"m1": 16},
                    },
                },
            }
        }
    )
    assert toks["color"]["brand"]["primary"] == {"$type": "color", "$value": "#3366ff"}
    assert toks["space"]["md"] == {"$type": "dimension", "$value": 16}

    # An aliased FLOAT must be skipped, never emitted as an invalid dimension.
    assert tokens_from_variables({
        "meta": {
            "variableCollections": {"c1": {"modes": [{"modeId": "m1"}]}},
            "variables": {"v3": {"name": "Space/alias", "variableCollectionId": "c1",
                                 "resolvedType": "FLOAT",
                                 "valuesByMode": {"m1": {"type": "VARIABLE_ALIAS", "id": "v2"}}}},
        }
    }) == {}
    print("figma_export self-check: OK")
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", help="Figma file key")
    ap.add_argument("--node", help="node id (frame/screen); default = top frames")
    ap.add_argument("--out", default=".", help="output dir (default: cwd)")
    ap.add_argument("--demo", action="store_true", help="run offline self-check and exit")
    args = ap.parse_args()

    if args.demo:
        return demo()

    token = os.environ.get("FIGMA_TOKEN")
    if not token or not args.file:
        ap.error("need FIGMA_TOKEN env and --file (or use --demo)")

    # Confine output to the working tree before doing any work — --out is not a
    # place to escape to.
    out = os.path.realpath(args.out)
    cwd = os.path.realpath(os.getcwd())
    if os.path.commonpath([out, cwd]) != cwd:
        ap.error(f"--out must stay under {cwd}")

    docs = fetch_nodes(args.file, args.node, token)
    manifest = build_manifest(args.file, docs)
    try:
        resolve_image_srcs(manifest, fetch_image_fills(args.file, token))
    except SystemExit:
        pass  # image-fills endpoint optional; image nodes keep their ref, src=None
    tokens = extract_tokens(args.file, token)

    os.makedirs(out, exist_ok=True)
    mpath = os.path.join(out, "manifest.json")
    tpath = os.path.join(out, "tokens.json")
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    with open(tpath, "w", encoding="utf-8") as f:
        json.dump(tokens, f, indent=2, ensure_ascii=False)
    print(f"wrote {mpath} ({len(manifest['screens'])} screen(s)) and {tpath} ({len(tokens)} token group(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
