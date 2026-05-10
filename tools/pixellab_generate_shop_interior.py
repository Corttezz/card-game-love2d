#!/usr/bin/env python3
# tools/pixellab_generate_shop_interior.py
# Gera UMA cena dedicada pra background da loja (CardRewardScreen).
# Diferente de path_shop.png que é o ícone do node de loja no mapa.
# Usage: python3 tools/pixellab_generate_shop_interior.py

import json
import os
import sys
import time
import urllib.request
import base64
import re

PIXELLAB_URL = "https://api.pixellab.ai/mcp"
TOKEN = "89fc4637-1de8-41f9-b0db-3ecbda2d65b2"

OUT_PATH = "assets/sprites/scenes/shop_interior.png"

# Contrato visual base (paleta sépia grimório do projeto). Ver sprite_design_queue.md.
CONTRACT_SUFFIX = (
    "dark fantasy grimoire illustration pixel art, inked engraving style, "
    "earthy desaturated palette (bone white, rust orange, deep blood crimson, "
    "tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), "
    "NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, "
    "detailed shading with clear darks and mid-tones, dramatic silhouette, "
    "moody upper-left lighting, limited 8-color palette, "
    "Slay the Spire and Magic the Gathering card art aesthetic"
)

PROMPT = (
    "Cozy interior of a medieval grimoire merchant shop at night, "
    "wide horizontal scene, dark wooden interior with stone arches, "
    "tall wooden shelves on both sides packed with glass potion bottles "
    "in deep colors (red blood, blue mana, green poison, gold elixir), "
    "stacks of leather-bound spellbooks, cauldron bubbling on the right, "
    "open chest of gold coins on the left, hanging oil lanterns casting "
    "warm flickering light, central wooden counter scattered with arcane "
    "scrolls and a brass scale, deep shadow in the corners, "
    "atmospheric and inviting, no characters visible, "
) + CONTRACT_SUFFIX


def mcp_call(method, params, request_id=1):
    body = json.dumps({
        "jsonrpc": "2.0", "id": request_id,
        "method": method, "params": params,
    }).encode("utf-8")
    req = urllib.request.Request(
        PIXELLAB_URL,
        data=body,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode("utf-8")
    for line in raw.splitlines():
        if line.startswith("data:"):
            payload = json.loads(line[5:].strip())
            if "result" in payload:
                return payload["result"]
            if "error" in payload:
                raise RuntimeError(f"MCP error: {payload['error']}")
    raise RuntimeError(f"Resposta sem result/error: {raw[:200]}")


def parse_image_data(get_result):
    contents = get_result.get("content", [])
    for c in contents:
        ctype = c.get("type")
        if ctype == "image":
            b64 = c.get("data")
            if b64:
                return base64.b64decode(b64)
        elif ctype == "text":
            text = c.get("text", "")
            if "data:image/png;base64," in text:
                idx = text.index("data:image/png;base64,") + len("data:image/png;base64,")
                end = text.find('"', idx) if '"' in text[idx:] else len(text)
                b64 = text[idx:end].strip()
                try:
                    return base64.b64decode(b64)
                except Exception:
                    pass
    return None


def main():
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)

    print(f"[queue] shop_interior: '{PROMPT[:80]}...'")
    # Cena horizontal (paisagem) 384×256 — formato wide pra cobrir bem a tela.
    # Cap PixelLab basic mode é 400×400 (160k pixels). 384×256 = 98k, OK.
    result = mcp_call("tools/call", {
        "name": "create_map_object",
        "arguments": {
            "description": PROMPT,
            "width": 384,
            "height": 256,
            "view": "side",
            "outline": "single color outline",
            "shading": "detailed shading",
            "detail": "high detail",
        },
    })
    text = result["content"][0]["text"]
    m = re.search(r"Object ID:\*\*\s*`([0-9a-f-]+)`", text)
    if not m:
        raise RuntimeError(f"Sem object_id em: {text[:200]}")
    obj_id = m.group(1)
    print(f"[queue] shop_interior → {obj_id}")

    print("[wait] aguardando 60s...")
    time.sleep(60)

    for poll_n in range(8):
        try:
            result = mcp_call("tools/call", {
                "name": "get_map_object",
                "arguments": {"object_id": obj_id},
            }, request_id=int(time.time()))
            img_bytes = parse_image_data(result)
            if img_bytes:
                with open(OUT_PATH, "wb") as f:
                    f.write(img_bytes)
                print(f"[done] {OUT_PATH} ({len(img_bytes)} bytes)")
                return 0
        except Exception as e:
            print(f"[poll {poll_n+1}/8] erro: {e}")
        print(f"[poll {poll_n+1}/8] still pending, sleep 30s")
        time.sleep(30)

    print("[fail] timeout — pack não ficou pronto em 4min")
    return 1


if __name__ == "__main__":
    sys.exit(main())
