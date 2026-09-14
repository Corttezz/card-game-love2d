#!/usr/bin/env python3
"""
tools/pixellab_animate_vouchers.py — anima os sprites de UPGRADE da loja
(assets/sprites/vouchers/*.png) e instala os frames no contrato que o
UpgradeTile consome:

    assets/sprites/vouchers_anim/<voucher_id>/frame_NNN.png
    assets/sprites/vouchers_anim/<voucher_id>/meta.lua      (fps)

Irmao de tools/pixellab_animate_card_icons.py — mesma infra, mesmo contrato,
outra pasta. Existe porque o dono olhou a aba de upgrades reformada e disse
que as imagens "ainda estao estaticas e estranhas": a reforma deu moldura,
halo e hierarquia ao tile, mas a peca continuou parada enquanto as cartas ao
lado respiram.

Uso:
  python3 tools/pixellab_animate_vouchers.py run     # fabrica serial (bg)
  python3 tools/pixellab_animate_vouchers.py check   # frames vivos? (md5)

REGRA (memory/card_icon_animation.md): `check` verde e pre-requisito, NUNCA
aprovacao. Olhar o contact sheet antes de instalar — foi assim que tres
animacoes de carta passaram no md5 e estavam quebradas.

EMENDA DO LOOP — medir, e usar PING-PONG quando saltar. O v3 tende a DERIVAR
ao longo do ciclo (o pedestal do cristal clareou de marrom pra cinza; o
liquido do frasco mudou de nivel), entao o ultimo frame nao casa com o
primeiro e a volta PISCA. Isso nao aparece no md5 nem no contact sheet lido da
esquerda pra direita: so aparece comparando frame 0 com frame N.

Criterio: a diferenca media 0->N nao pode passar de ~1,6x a diferenca de um
passo normal (0->1). Acima disso, duplique os frames de volta (0..N seguido de
N-1..1): o ciclo vira ida-e-volta e a emenda deixa de existir por construcao.
Para brilho pulsante isso e ate mais natural que o loop em anel; para chama e
liquido corrente, prefira regerar, porque fogo em marcha a re se percebe.
Medido em Set/2026: forge_card, damage_upgrade e defense_upgrade fecharam
sozinhos; health_upgrade e mana_upgrade precisaram de ping-pong.
"""
import base64
import hashlib
import json
import os
import re
import sys
import time
import urllib.request

URL = "https://api.pixellab.ai/mcp"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/voucher_anim_jobs.json")
OUT_ROOT = os.path.join(ROOT, "assets/sprites/vouchers_anim")
SRC_DIR = os.path.join(ROOT, "assets/sprites/vouchers")

# Nenhum voucher tem object_id proprio (foram gerados em Abr/2026 e os PNGs
# de origem expiraram), entao todos usam o objeto-host + custom_start_frame
# lido do disco. Base64 NUNCA passa por tool call — corrompe (memoria
# pixellab-base64-mcp-http); vai por HTTP daqui.
HOST_OBJECT = "acbad108-e76b-4cf6-8247-dee3ab2427ab"

SUFFIX = (", subtle idle motion, seamless loop, colors and silhouette "
          "unchanged, everything else perfectly static")

# voucher_id (== nome do PNG em assets/sprites/vouchers/) -> movimento.
# Doutrina: OLHAR a arte antes de escrever o prompt. O que cada uma e, de
# fato (conferido no contact sheet tools/preview_out/vouchers.png):
#   forge_card          bigorna escura com chama alaranjada em cima e martelo
#   health_upgrade      frasco de vidro com liquido vermelho e rotulo com cruz
#   mana_upgrade        cristal azul facetado sobre pedestal de pedra
#   damage_upgrade      duas espadas cruzadas em chamas
#   defense_upgrade     escudo dourado com cabeca de leao em relevo
#   card_draw_upgrade   livro aberto com paginas escritas
# O movimento vai no que e FLUIDO (chama, liquido, luz) e nunca na estrutura
# (metal, pedra, vidro) — estrutura que se mexe le como a arte derretendo,
# que foi exatamente o defeito das animacoes reprovadas do lote de cartas.
ANIMS = {
    "forge_card": {
        "anim": ("the orange flame on top of the anvil flickering and licking "
                 "upward, a few tiny embers drifting up from it, the anvil "
                 "the hammer and the wooden base stay completely frozen and "
                 "solid, the metal never fades and never becomes transparent"),
        "fps": 8,
    },
    "health_upgrade": {
        "anim": ("the red liquid inside the glass bottle swaying very gently "
                 "with a slow surface ripple and a faint highlight sliding on "
                 "the glass, the bottle the cork and the paper label with the "
                 "cross stay completely frozen, the glass outline never moves"),
        "fps": 7,
    },
    "mana_upgrade": {
        "anim": ("a soft blue inner light pulsing slowly inside the crystal, "
                 "brightening and dimming gently, a faint highlight travelling "
                 "down one facet, the crystal facets and the stone pedestal "
                 "stay completely frozen, the blue never turns cyan or white, "
                 "no overexposure, no white flash"),
        "fps": 7,
    },
    "damage_upgrade": {
        "anim": ("the flames along both crossed sword blades flickering and "
                 "licking upward, the steel blades the golden crossguards and "
                 "the pommels stay completely frozen and solid"),
        "fps": 8,
    },
    "defense_upgrade": {
        "anim": ("a faint warm light glint slowly travelling across the polished "
                 "golden shield surface and over the lion relief, the shield "
                 "shape the lion and the banner stay completely frozen, the gold "
                 "never turns white, no overexposure"),
        "fps": 6,
    },
    "card_draw_upgrade": {
        "anim": ("the open page corners lifting and settling very slightly as "
                 "if in a faint draft, barely perceptible, the book covers the "
                 "spine and the written lines stay completely frozen, no pages "
                 "turning, no text changing"),
        "fps": 6,
    },
}

def token():
    """Bearer do PixelLab: ~/.claude.json (mcpServers.pixellab) — não versionar."""
    env = os.environ.get("PIXELLAB_TOKEN")
    if env:
        return env
    path = os.path.expanduser("~/.claude.json")
    try:
        with open(path) as f:
            cfg = json.load(f)
        for proj in cfg.get("projects", {}).values():
            srv = proj.get("mcpServers", {}).get("pixellab")
            if srv:
                auth = srv.get("headers", {}).get("Authorization", "")
                if auth.startswith("Bearer "):
                    return auth[len("Bearer "):]
        srv = cfg.get("mcpServers", {}).get("pixellab")
        if srv:
            auth = srv.get("headers", {}).get("Authorization", "")
            if auth.startswith("Bearer "):
                return auth[len("Bearer "):]
    except Exception as e:
        print(f"[token] falha lendo {path}: {e}")
    raise SystemExit("token PixelLab não encontrado (~/.claude.json ou $PIXELLAB_TOKEN)")


TOKEN = token()


def rpc(method, params, timeout=120):
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


def tool_text(result):
    return "\n".join(p.get("text", "") for p in result["result"]["content"]
                     if p.get("type") == "text")


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


def queue():
    jobs = load_jobs()
    queued = 0
    for icon, spec in ANIMS.items():
        if icon in jobs and jobs[icon].get("group"):
            continue
        if os.path.isdir(os.path.join(OUT_ROOT, icon)):
            continue
        try:
            args = {
                "object_id": spec.get("object_id") or HOST_OBJECT,
                "animation_description": spec["anim"] + SUFFIX,
                "display_name": icon + "_idle",
                "mode": "v3",
                "frame_count": 8,
            }
            if not spec.get("object_id"):
                # Ícone sem objeto próprio: o PNG do ícone vira o start frame
                # (frame 0 idêntico ao estático) e o host só hospeda o grupo.
                icon_png = os.path.join(ROOT, "assets/sprites/icons",
                                        icon + ".png")
                with open(icon_png, "rb") as f:
                    args["custom_start_frame_base64"] = \
                        base64.b64encode(f.read()).decode()
            result = rpc("tools/call", {
                "name": "animate_object",
                "arguments": args,
            })
            text = tool_text(result)
            m = re.search(r"group:\s*([0-9a-f-]{36})", text)
            if m:
                jobs[icon] = {"object_id": args["object_id"], "group": m.group(1)}
                queued += 1
                print(f"[queue] {icon} -> group {m.group(1)}")
            else:
                print(f"[queue] {icon}: sem group — {text[:120]}")
        except Exception as e:
            print(f"[queue] {icon}: FALHOU {e}")
        save_jobs(jobs)
        time.sleep(1.5)
    print(f"[queue] {queued} novos jobs")


def fetch(url):
    # Bearer SÓ pra api.pixellab.ai — o bucket backblaze é público, MAS
    # bloqueia o User-Agent default do urllib (403) e rejeita Authorization
    # que não entende. curl funciona; urllib precisa de UA "normal".
    headers = {"User-Agent": "curl/8.4.0"}
    if "api.pixellab.ai" in url:
        headers["Authorization"] = f"Bearer {TOKEN}"
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=120).read()


def _has_frames(icon):
    d = os.path.join(OUT_ROOT, icon)
    return os.path.isdir(d) and any(
        re.match(r"frame_\d+\.png$", f) for f in os.listdir(d))


def _submit(icon, spec):
    """Submete UMA animação. Retorna (object_id, group) ou (None, None)."""
    args = {
        "object_id": spec.get("object_id") or HOST_OBJECT,
        "animation_description": spec["anim"] + SUFFIX,
        "display_name": icon + "_idle",
        "mode": "v3",
        "frame_count": 8,
        "replace_existing": True,
    }
    if not spec.get("object_id"):
        icon_png = os.path.join(SRC_DIR, icon + ".png")
        with open(icon_png, "rb") as f:
            args["custom_start_frame_base64"] = base64.b64encode(f.read()).decode()
    text = tool_text(rpc("tools/call", {"name": "animate_object",
                                        "arguments": args}))
    m = re.search(r"group:\s*([0-9a-f-]{36})", text)
    if not m:
        print(f"[run] {icon}: SEM GROUP — {text[:150]}", flush=True)
        return None, None
    return args["object_id"], m.group(1)


def _try_download(icon, object_id, group):
    """Uma checada: se o group está completo no get_object, baixa. True = ok."""
    try:
        text = tool_text(rpc("tools/call", {
            "name": "get_object",
            "arguments": {"object_id": object_id}}))
    except Exception as e:
        print(f"[run] {icon}: erro no get_object ({e})", flush=True)
        return False
    blk = re.search(
        r"\[group: " + re.escape(group) +
        r"\].*?unknown:\s*(\S+)/\{i\}\.png\s+\(i=0\.\.(\d+)\)",
        text, re.S)
    if not blk:
        return False
    base, last = blk.group(1), int(blk.group(2))
    out_dir = os.path.join(OUT_ROOT, icon)
    os.makedirs(out_dir, exist_ok=True)
    for i in range(last + 1):
        with open(os.path.join(out_dir, f"frame_{i:03d}.png"), "wb") as f:
            f.write(fetch(f"{base}/{i}.png"))
    fps = ANIMS.get(icon, {}).get("fps", 8)
    with open(os.path.join(out_dir, "meta.lua"), "w") as f:
        f.write(f"return {{ fps = {fps} }}\n")
    print(f"[run] {icon}: {last + 1} frames + meta.lua (fps={fps})", flush=True)
    return True


def _wait_download(icon, object_id, group, timeout=480):
    """Espera o group concluir no get_object e baixa os frames. True = ok."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(25)
        try:
            if _try_download(icon, object_id, group):
                return True
        except Exception as e:
            # Timeout de rede num download NÃO pode derrubar a fábrica —
            # frames parciais serão re-baixados na próxima iteração.
            print(f"[run] {icon}: erro transitório ({e}), tentando de novo",
                  flush=True)
    print(f"[run] {icon}: TIMEOUT ({timeout}s) — fica pro próximo run",
          flush=True)
    return False


def run():
    """FÁBRICA SERIAL: processa todo ANIMS sem frames, UM por vez (a API
    descarta jobs de interpolação concorrentes — memory/card_icon_animation).
    ~3-6 min por carta; rodar em background e validar por blocos."""
    jobs = load_jobs()
    todo = [(i, s) for i, s in ANIMS.items() if not _has_frames(i)]
    print(f"[run] fila: {len(todo)} animações", flush=True)
    ok, fail = 0, 0
    for n, (icon, spec) in enumerate(todo, 1):
        print(f"[run] ({n}/{len(todo)}) {icon}…", flush=True)
        # Job de run anterior pode ter concluído depois do timeout — checar
        # antes de gastar outra geração.
        prev = jobs.get(icon)
        if prev and prev.get("group"):
            try:
                if _try_download(icon, prev["object_id"], prev["group"]):
                    ok += 1
                    continue
            except Exception as e:
                print(f"[run] {icon}: pre-check falhou ({e}), resubmetendo",
                      flush=True)
        try:
            object_id, group = _submit(icon, spec)
        except Exception as e:
            print(f"[run] {icon}: FALHOU submit ({e})", flush=True)
            fail += 1
            continue
        if not group:
            fail += 1
            continue
        # RELOAD do disco antes de salvar: runs longos NÃO podem ressuscitar
        # entradas removidas externamente (ex: reprovação manual apagou o
        # group pra forçar regen — clobber flagrado no caso joker_vampire).
        jobs = load_jobs()
        jobs[icon] = {"object_id": object_id, "group": group}
        save_jobs(jobs)
        if _wait_download(icon, object_id, group):
            ok += 1
        else:
            fail += 1
    print(f"[run] FIM: {ok} ok, {fail} falhas", flush=True)


def poll():
    jobs = load_jobs()
    pending = 0
    for icon, job in jobs.items():
        out_dir = os.path.join(OUT_ROOT, icon)
        has_frames = os.path.isdir(out_dir) and any(
            re.match(r"frame_\d+\.png$", f) for f in os.listdir(out_dir))
        if has_frames or not job.get("group"):
            continue
        try:
            result = rpc("tools/call", {
                "name": "get_object",
                "arguments": {"object_id": job["object_id"]},
            })
            text = tool_text(result)
            # Bloco da NOSSA animação: [group: <uuid>] ... unknown: <url>/{i}.png (i=0..N)
            blk = re.search(
                r"\[group: " + re.escape(job["group"]) + r"\]"
                r".*?unknown:\s*(\S+)/\{i\}\.png\s+\(i=0\.\.(\d+)\)",
                text, re.S)
            if not blk:
                print(f"[poll] {icon}: aguardando (group {job['group'][:8]}…)")
                pending += 1
                continue
            base, last = blk.group(1), int(blk.group(2))
            os.makedirs(out_dir, exist_ok=True)
            for i in range(last + 1):
                png = fetch(f"{base}/{i}.png")
                with open(os.path.join(out_dir, f"frame_{i:03d}.png"), "wb") as f:
                    f.write(png)
            fps = ANIMS.get(icon, {}).get("fps", 8)
            with open(os.path.join(out_dir, "meta.lua"), "w") as f:
                f.write(f"return {{ fps = {fps} }}\n")
            print(f"[poll] {icon}: {last + 1} frames + meta.lua (fps={fps})")
        except Exception as e:
            print(f"[poll] {icon}: erro {e}")
            pending += 1
    print(f"[poll] pendentes: {pending}")


def check():
    """Animação viva = frames com conteúdo distinto (v3 às vezes anima morto)."""
    bad = 0
    for icon in sorted(os.listdir(OUT_ROOT)) if os.path.isdir(OUT_ROOT) else []:
        d = os.path.join(OUT_ROOT, icon)
        if not os.path.isdir(d):
            continue
        hashes = set()
        n = 0
        for f in sorted(os.listdir(d)):
            if re.match(r"frame_\d+\.png$", f):
                with open(os.path.join(d, f), "rb") as fh:
                    hashes.add(hashlib.md5(fh.read()).hexdigest())
                n += 1
        distinct = len(hashes)
        status = "OK" if distinct >= max(2, n // 2) else "MORTA?"
        if status != "OK":
            bad += 1
        print(f"[check] {icon}: {n} frames, {distinct} distintos — {status}")
    if bad:
        print(f"[check] {bad} animação(ões) suspeitas — regerar com descrição "
              "mais explícita de movimento (replace_existing=true)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "queue"
    if cmd == "queue":
        queue()
    elif cmd == "poll":
        poll()
    elif cmd == "check":
        check()
    elif cmd == "run":
        run()
    else:
        print(__doc__)