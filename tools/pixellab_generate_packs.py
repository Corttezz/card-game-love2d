#!/usr/bin/env python3
# tools/pixellab_generate_packs.py
# Gera 5 sleeves de booster pack via PixelLab MCP HTTP.
# Usage: python3 tools/pixellab_generate_packs.py
#
# Requer urllib (stdlib). MCP token lido de ~/.claude.json (project-scoped).

import json
import os
import sys
import time
import urllib.request
import base64

PIXELLAB_URL = "https://api.pixellab.ai/mcp"
TOKEN = "89fc4637-1de8-41f9-b0db-3ecbda2d65b2"  # token project-scoped do .claude.json

OUT_DIR = "assets/sprites/packs"

CONTRACT_SUFFIX = (
    "dark fantasy grimoire illustration pixel art, inked engraving style, "
    "earthy desaturated palette (bone white, rust orange, deep blood crimson, "
    "tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), "
    "NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, "
    "detailed shading with clear darks and mid-tones, dramatic silhouette, "
    "moody upper-left lighting, limited 8-color palette, "
    "Slay the Spire and Magic the Gathering card art aesthetic"
)

PACKS = [
    {
        "id": "pack_standard",
        # Standard ficou bom — manter prompt
        "prompt": (
            "ornate sealed parchment envelope tied with red wax seal, scrollwork "
            "edges, cracked aged leather binding, slight glint highlight, "
        ) + CONTRACT_SUFFIX,
    },
    {
        "id": "pack_buffoon",
        # Refeito Apr/27 2026: forçar formato envelope retangular, não chapéu+baú.
        "prompt": (
            "rectangular sealed card pack envelope shape, dark red leather binding "
            "with gold trim borders, tied with diagonal golden cord, single "
            "jester mask with bells emblem embossed in center of envelope, "
            "rounded corners, isometric 3D view, "
        ) + CONTRACT_SUFFIX,
    },
    {
        "id": "pack_arcana",
        # Refeito Apr/27 2026: envelope retangular com olho como emblem, não olho radiante solto.
        "prompt": (
            "rectangular sealed card pack envelope shape, deep indigo parchment "
            "wrapping, tied with purple velvet ribbon and golden buckle, "
            "single golden all-seeing eye sigil embossed in center of envelope, "
            "rounded corners, isometric 3D view, "
        ) + CONTRACT_SUFFIX,
    },
    {
        "id": "pack_celestial",
        # Refeito Apr/27 2026: envelope retangular com luas/estrelas em emblem central.
        "prompt": (
            "rectangular sealed card pack envelope shape, deep navy blue parchment "
            "with silver foil corner accents, tied with silver cord, "
            "crescent moon and star constellation emblem embossed in center, "
            "rounded corners, isometric 3D view, "
        ) + CONTRACT_SUFFIX,
    },
    {
        "id": "pack_spectral",
        # Refeito Apr/27 2026: envelope retangular pálido com caveira como emblem.
        "prompt": (
            "rectangular sealed card pack envelope shape, pale green ghostly "
            "parchment with frayed dark cord wrapping, tied with diagonal cord, "
            "single ethereal skull silhouette emblem embossed in center, "
            "rounded corners, isometric 3D view, "
        ) + CONTRACT_SUFFIX,
    },
]


def mcp_call(method, params, request_id=1):
    """Faz uma chamada JSON-RPC ao PixelLab MCP. Retorna o 'result' ou raise."""
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method,
        "params": params,
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

    # Streaming response: linhas "event: message" + "data: <json>"
    for line in raw.splitlines():
        if line.startswith("data:"):
            payload = json.loads(line[5:].strip())
            if "result" in payload:
                return payload["result"]
            if "error" in payload:
                raise RuntimeError(f"MCP error: {payload['error']}")

    raise RuntimeError(f"Resposta sem result/error: {raw[:200]}")


def queue_pack(pack):
    """Queue um job de create_map_object pra um pack. Retorna object_id."""
    print(f"[queue] {pack['id']}: '{pack['prompt'][:60]}...'")
    result = mcp_call("tools/call", {
        "name": "create_map_object",
        "arguments": {
            "description": pack["prompt"],
            "width": 128,
            "height": 192,
            "view": "side",
            "outline": "single color outline",
            "shading": "detailed shading",
            "detail": "high detail",
        },
    })

    text = result["content"][0]["text"]
    # extrai object_id da string `**Object ID:** \`...\``
    import re
    m = re.search(r"Object ID:\*\*\s*`([0-9a-f-]+)`", text)
    if not m:
        raise RuntimeError(f"Sem object_id em: {text[:200]}")
    obj_id = m.group(1)
    print(f"[queue] {pack['id']} → {obj_id}")
    return obj_id


def get_pack(object_id):
    """Pega status/imagem do object_id. Retorna o conteúdo bruto."""
    return mcp_call("tools/call", {
        "name": "get_map_object",
        "arguments": {"object_id": object_id},
    }, request_id=int(time.time()))


def parse_image_data(get_result):
    """Procura base64 ou path de imagem no resultado de get_map_object.
    Retorna bytes se conseguiu decodar, None se ainda processando."""
    contents = get_result.get("content", [])
    for c in contents:
        ctype = c.get("type")
        if ctype == "image":
            b64 = c.get("data")
            if b64:
                return base64.b64decode(b64)
        elif ctype == "text":
            text = c.get("text", "")
            # Algumas respostas embedam base64 no texto (data:image/png;base64,...)
            if "data:image/png;base64," in text:
                idx = text.index("data:image/png;base64,") + len("data:image/png;base64,")
                end = text.find('"', idx) if '"' in text[idx:] else len(text)
                b64 = text[idx:end].strip()
                try:
                    return base64.b64decode(b64)
                except Exception:
                    pass
            # Senão pode ter "Status: Processing" ou link de download
            if "Status:" in text and "complete" not in text.lower() and "ready" not in text.lower():
                return None
    return None


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # 1) Queue todos.
    jobs = []
    for pack in PACKS:
        try:
            obj_id = queue_pack(pack)
            jobs.append((pack, obj_id))
        except Exception as e:
            print(f"[fail-queue] {pack['id']}: {e}")

    if not jobs:
        print("[!] Nenhum job na fila. Abortando.")
        return 1

    print(f"\n[wait] {len(jobs)} jobs em fila. Aguardando 60s antes do primeiro poll...")
    time.sleep(60)

    # 2) Poll cada um até obter PNG ou desistir.
    done = []
    failed = []
    pending = list(jobs)

    max_polls = 8  # 8 polls × 30s = ~4min max por job
    poll_interval = 30

    for poll_n in range(max_polls):
        if not pending:
            break
        print(f"\n[poll {poll_n + 1}/{max_polls}] {len(pending)} pendentes")
        next_pending = []
        for pack, obj_id in pending:
            try:
                result = get_pack(obj_id)
                img_bytes = parse_image_data(result)
                if img_bytes:
                    out_path = os.path.join(OUT_DIR, f"{pack['id']}.png")
                    with open(out_path, "wb") as f:
                        f.write(img_bytes)
                    print(f"[done] {pack['id']} → {out_path} ({len(img_bytes)} bytes)")
                    done.append(pack["id"])
                else:
                    next_pending.append((pack, obj_id))
            except Exception as e:
                print(f"[fail-poll] {pack['id']}: {e}")
                failed.append(pack["id"])

        pending = next_pending
        if pending:
            time.sleep(poll_interval)

    print(f"\n=== Resumo ===")
    print(f"  done:    {len(done)}: {', '.join(done) or '—'}")
    print(f"  failed:  {len(failed)}: {', '.join(failed) or '—'}")
    print(f"  timeout: {len(pending)}: {', '.join(p[0]['id'] for p in pending) or '—'}")
    return 0 if not failed and not pending else 1


if __name__ == "__main__":
    sys.exit(main())
