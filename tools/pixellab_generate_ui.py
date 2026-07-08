#!/usr/bin/env python3
"""
tools/pixellab_generate_ui.py — gera os painéis 9-slice do UI Overhaul (F0)
via PixelLab MCP por HTTP (bypass validado — ver memory/pixellab_queue_packs.md).

Uso:
  python3 tools/pixellab_generate_ui.py queue    # enfileira os 3 painéis
  python3 tools/pixellab_generate_ui.py poll     # baixa os prontos p/ assets/sprites/ui/

IDs dos jobs ficam em tools/preview_out/ui_jobs.json.
Requer só stdlib. Plano: docs/plan/ui-ux-overhaul-v1.md §6.
"""
import json
import os
import sys
import time
import urllib.request

URL = "https://api.pixellab.ai/mcp"
TOKEN = "89fc4637-1de8-41f9-b0db-3ecbda2d65b2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/ui_jobs.json")
OUT_DIR = os.path.join(ROOT, "assets/sprites/ui")

PALETTE = ("limited sepia palette (bone white #d8c9a3, dark leather #6b5334, "
           "charcoal ink #2a2119, aged gold #b08a3e), crisp 1px outlines, "
           "no anti-aliasing, clean pixel art")

ASSETS = {
    "panel_main": {
        "description": (
            "ornate medieval grimoire UI panel frame, aged parchment center, "
            "dark ink border with brass corner filigree and rivets, weathered "
            "leather trim, flat fillable center, " + PALETTE),
        "color_palette": "sepia parchment, aged gold, dark leather brown",
        "width": 192, "height": 192,
    },
    "panel_inner": {
        "description": (
            "simple dark medieval UI panel, charcoal ink background with thin "
            "aged gold double border, flat fillable center, subtle corner "
            "notches, " + PALETTE),
        "color_palette": "charcoal ink, aged gold",
        "width": 192, "height": 192,
    },
    "panel_gold": {
        "description": (
            "ornate golden hero UI panel frame, radiant aged gold border with "
            "engraved filigree corners, dark parchment center, medieval "
            "grimoire style, flat fillable center, " + PALETTE),
        "color_palette": "aged gold, dark sepia",
        "width": 192, "height": 192,
    },
}


def rpc(method, params, timeout=90):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method,
                       "params": params}).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    })
    raw = urllib.request.urlopen(req, timeout=timeout).read().decode()
    for line in raw.splitlines():
        if line.startswith("data:"):
            return json.loads(line[5:])
    raise RuntimeError("sem data: na resposta")


def tool(name, arguments):
    resp = rpc("tools/call", {"name": name, "arguments": arguments})
    parts = resp["result"]["content"]
    return parts


def queue():
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    jobs = {}
    for name, spec in ASSETS.items():
        parts = tool("create_ui_asset", {
            "description": spec["description"],
            "color_palette": spec["color_palette"],
            "width": spec["width"], "height": spec["height"],
            "name": name,
        })
        text = " ".join(p.get("text", "") for p in parts if p.get("type") == "text")
        # extrai UUID do texto de resposta
        import re
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        jobs[name] = m.group(0) if m else None
        print(f"[queue] {name}: {jobs[name]}  ({text[:90]})")
        time.sleep(2)
    json.dump(jobs, open(JOBS_FILE, "w"), indent=1)
    print(f"[queue] ids salvos em {JOBS_FILE}")


def poll():
    import base64
    import re
    jobs = json.load(open(JOBS_FILE))
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, jid in jobs.items():
        if not jid:
            print(f"[poll] {name}: sem id")
            continue
        out = os.path.join(OUT_DIR, f"{name}.png")
        if os.path.exists(out):
            print(f"[poll] {name}: já baixado")
            continue
        parts = tool("get_ui_asset", {"ui_asset_id": jid,
                                      "include_preview": True})
        saved = False
        for p in parts:
            if p.get("type") == "image":
                data = base64.b64decode(p["data"])
                open(out, "wb").write(data)
                print(f"[poll] {name}: salvo em {out} ({len(data)} bytes)")
                saved = True
                break
        if not saved:
            text = " ".join(p.get("text", "") for p in parts
                            if p.get("type") == "text")
            m = re.search(r"https://\S+download\S*", text)
            if m:
                urllib.request.urlretrieve(m.group(0).rstrip(')."'), out)
                print(f"[poll] {name}: baixado via URL")
            else:
                print(f"[poll] {name}: ainda processando — {text[:120]}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "queue"
    if cmd == "queue":
        queue()
    else:
        poll()
