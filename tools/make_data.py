"""Gera src/data/game.json e copia a arte do jogo para public/ (o jogo é só lido).

Fontes:
  - tools/out/game_raw.json  (lua tools/extract_game.lua: locales dos 5 idiomas + cartas)
  - tools/out/biomes.json    (lua tools/extract_biomes.lua: cores de cada bioma)
  - inventário do jogo (caminhos, quadros e tamanhos), passado como argumento
Arte em escala nativa; animações viram tiras horizontais. Nada é inventado: todo nome e
número sai das tabelas do jogo.

uso: python -I -X utf8 tools/make_data.py <inventory.json>
"""
import io
import json
import os
import re
import shutil
import sys
import zipfile

from PIL import Image

GAME = "E:/dev/projects/card-game-love2d"
SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUB = os.path.join(SITE, "public")
LOC = ["en", "pt_BR", "es", "fr", "de"]
ORDER = ["fields", "highlands", "abyss", "frost", "marsh", "dusk"]
MECH = {"carrion_king": "swarm", "tower_lich": "runes", "abyss_tyrant": "chains",
        "winter_monarch": "frost", "rot_colossus": "roots", "eclipse_queen": "moon"}
# token do mecanismo de cada chefe (arte do próprio jogo)
TOKEN = {"carrion_king": ("carrion_king/crow", "strip_named"), "tower_lich": ("tower_lich/mechanic/rune_0.png", "copy"),
         "abyss_tyrant": ("abyss_tyrant/mechanic/fireball.png", "copy"), "winter_monarch": ("winter_monarch/mechanic/ice_shard.png", "copy"),
         "rot_colossus": ("rot_colossus/mechanic/root_0.png", "copy"), "eclipse_queen": ("eclipse_queen/mechanic/moon.png", "copy")}
WEATHER = {"fields": "leaf", "highlands": "rain", "abyss": "ember", "frost": "snow", "marsh": "spore", "dusk": "bats"}
SIZE = {}
CONFIG = json.load(open(os.path.join(SITE, "src/data/config.json"), encoding="utf-8"))  # contato num lugar só


def g(p):
    return os.path.join(GAME, p) if not os.path.isabs(p) else p


def save(im, rel, **kw):
    d = os.path.join(PUB, rel)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    im.save(d, **kw)
    SIZE[rel] = os.path.getsize(d)
    return "/" + rel.replace("\\", "/")


def thresh(im):
    im = im.convert("RGBA")
    im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return im


def copy_png(src, rel, th=True):
    im = Image.open(g(src))
    im = thresh(im) if th else im.convert("RGBA")
    url = save(im, rel, optimize=True)
    return {"src": url, "w": im.width, "h": im.height}


def frames_in(folder):
    fs = [f for f in os.listdir(folder) if f.lower().endswith(".png")]
    num = lambda f: int(re.findall(r"(\d+)", f)[-1])
    return [os.path.join(folder, f) for f in sorted(fs, key=num)]


def strip(folder, rel, fps=8, max_frames=None):
    fr = frames_in(g(folder))
    if max_frames:
        fr = fr[:max_frames]
    ims = [thresh(Image.open(f)) for f in fr]
    w, h = max(i.width for i in ims), max(i.height for i in ims)
    sheet = Image.new("RGBA", (w * len(ims), h))
    for k, im in enumerate(ims):
        sheet.alpha_composite(im, (k * w + (w - im.width) // 2, h - im.height))
    url = save(sheet, rel, optimize=True)
    return {"src": url, "w": w, "h": h, "frames": len(ims), "fps": fps}


def raw(src, rel):
    d = os.path.join(PUB, rel)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copyfile(g(src), d)
    SIZE[rel] = os.path.getsize(d)
    return "/" + rel.replace("\\", "/")


def L(locs, path, default=None):
    """{lang: valor} a partir de um caminho 'a.b.c' em cada locale."""
    out = {}
    for l in LOC:
        cur = locs[l]
        for k in path.split("."):
            cur = cur.get(k) if isinstance(cur, dict) else None
        out[l] = cur if cur is not None else default
    return out


def fill(tpl, vars_):
    if not isinstance(tpl, str):
        return tpl
    def rep(m):
        v = vars_.get(m.group(1))
        if v is None:
            return m.group(0)
        if isinstance(v, float) and v.is_integer():
            v = int(v)
        return str(v)
    return re.sub(r"\{(\w+)\}", rep, tpl)


def main(inv_path):
    inv = json.load(open(inv_path, encoding="utf-8"))
    rawd = json.load(open(os.path.join(SITE, "tools/out/game_raw.json"), encoding="utf-8"))
    pal = {b["id"]: b for b in json.load(open(os.path.join(SITE, "tools/out/biomes.json"), encoding="utf-8"))}
    locs = rawd["locales"]
    data = {"biomes": [], "classes": [], "cards": [], "jokersBoss": [], "jokersCounter": [], "seals": [], "curses": [], "combos": [], "ui": {}}

    # ---------- marca ----------
    brand = {}
    lf = Image.open("E:/dev/projects/card-game-trailer/build/trailer/brand_runemoire/logo_final.png").convert("RGBA")
    lf = lf.crop(lf.getbbox())
    wm = Image.open(g("assets/branding/wordmark.png"))
    # o logo final é pixel art ampliada: volta à escala nativa pela largura da palavra (289 px)
    k = None
    for cand in range(1, 9):
        if abs(lf.width / cand - wm.width) <= 2 or abs(lf.width / cand - 289) <= 2:
            k = cand
            break
    k = k or max(1, round(lf.width / 289))
    native = lf.resize((round(lf.width / k), round(lf.height / k)), Image.NEAREST)
    brand["logo"] = {"src": save(thresh(native), "img/brand/logo.png", optimize=True), "w": native.width, "h": native.height}
    brand["seal"] = copy_png("assets/branding/seal.png", "img/brand/seal.png")
    brand["wordmark"] = copy_png("assets/branding/wordmark.png", "img/brand/wordmark.png")
    # ícones do site só com a marca do jogo: o selo-bússola do menu (assets/branding/seal.png), sem o "R" (Daniel, 11/11)
    seal = Image.open(g("assets/branding/seal.png")).convert("RGBA")
    def seal_icon(size, bg=None):
        k = size // seal.width
        if k >= 1:
            art = seal.resize((seal.width * k, seal.height * k), Image.NEAREST)  # escala inteira, sem borrar a pixel art
        else:
            art = seal.resize((size, size), Image.LANCZOS)  # menor que o original: reduzir é inevitável
        canvas = Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))
        canvas.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
        return canvas
    for s_ in (32, 48):
        save(seal_icon(s_), f"img/brand/seal_{s_}.png", optimize=True)
    for s_ in (180, 192, 512):
        save(seal_icon(s_, (11, 10, 13, 255)), f"img/brand/seal_{s_}.png", optimize=True)
    seal_icon(48).save(os.path.join(PUB, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    brand["icon"] = "/img/brand/seal_192.png"
    data["brand"] = brand
    data["scene"] = {"menu": copy_png("assets/sprites/scenes/menu.png", "img/scene/menu.png", th=False)}

    # ---------- biomas / atos ----------
    mus = {m["biome"]: m["path"] for m in inv["audio"]["music"]["acts"]}
    for a in sorted(inv["acts"], key=lambda x: x["act"]):
        bid = a["biome_id"]
        b = {"id": bid, "act": a["act"], "name": a["biome_name"], "actTitle": a["act_title"], "fog": bool(a["intent_fog"]),
             "weather": WEATHER[bid], "palette": pal[bid]}
        b["castle"] = copy_png(a["castle"]["static"]["path"], f"img/world/{bid}_castle.png")
        # quadro estático já em 2x (vizinho mais próximo): é o elemento LCP do herói; em 2x ele conta pelo tamanho exibido
        _c = thresh(Image.open(g(a["castle"]["static"]["path"])))
        _c2 = _c.resize((_c.width * 2, _c.height * 2), Image.NEAREST)
        b["castle2x"] = {"src": save(_c2, f"img/world/{bid}_castle_2x.png", optimize=True), "w": _c2.width, "h": _c2.height}
        b["castleAnim"] = strip(a["castle"]["anim"]["dir"], f"img/world/{bid}_castle_anim.png", fps=6)
        sb = a["sky_backdrop"]
        b["mtn"] = copy_png(sb["mountains"]["path"], f"img/world/{bid}_mountains.png", th=False)
        _m = Image.open(g(sb["mountains"]["path"])).convert("RGB")
        _row = [_m.getpixel((x, 0)) for x in range(_m.width)]
        b["mtnTop"] = "#%02x%02x%02x" % tuple(sum(px[i] for px in _row) // len(_row) for i in range(3))
        mf = sb.get("mountains_front")
        b["mtnFront"] = copy_png(mf["path"], f"img/world/{bid}_mountains_front.png") if mf and mf.get("path") else None
        b["hall"] = copy_png(a["boss_hall"]["path"], f"img/boss/{bid}_hall.png", th=False)
        bo = a["boss"]
        bk = bo["id"]
        cre = lambda l, key: (locs[l].get("bestiary", {}).get("creature", {}).get(bk, {}) or {}).get(key)
        boss = {"id": bk, "name": bo["name"],
                "epithet": L(locs, f"boss_cinematics.{bk}.epithet"),
                "signature": {l: cre(l, "signature") for l in LOC},
                "lore": {l: cre(l, "lore") for l in LOC},
                "mechanic": L(locs, f"enemy_kit.status.{MECH[bk]}.name"),
                "idle": strip(bo["idle"]["dir"], f"img/boss/{bk}_idle.png", fps=8)}
        src, kind = TOKEN[bk]
        tp = os.path.join(GAME, "assets/sprites/characters/enemies", src)
        boss["token"] = strip(tp, f"img/boss/{bk}_token.png", fps=8) if kind == "strip_named" else copy_png(tp, f"img/boss/{bk}_token.png")
        b["boss"] = boss
        roster = list(a.get("enemies", []))
        if a.get("mini_boss"):
            mb = a["mini_boss"] if isinstance(a["mini_boss"], list) else [a["mini_boss"]]
            roster += [m for m in mb if m["id"] not in {e["id"] for e in roster}]
        b["enemies"] = []
        for e in roster:
            ek = e["id"]
            ent = {"id": ek, "role": e.get("role"), "name": e["name"],
                   "lore": {l: ((locs[l].get("bestiary", {}).get("creature", {}).get(ek, {}) or {}).get("lore")) for l in LOC},
                   "idle": strip(e["idle"]["dir"], f"img/enemy/{ek}_idle.png", fps=8)}
            b["enemies"].append(ent)
        if bid in mus:
            b["music"] = raw(mus[bid], f"media/music/{bid}.mp3")
        data["biomes"].append(b)
    data["biomes"].sort(key=lambda x: ORDER.index(x["id"]))

    # ---------- classes ----------
    raw_cards = rawd["cards"]
    starter = {"warrior": ["warrior_strike", "warrior_defend"], "mage": ["mage_zap", "defense_001"], "rogue": ["rogue_strike", "rogue_defend"]}
    for c in inv["classes"]:
        cid = c["id"]
        data["classes"].append({
            "id": cid, "name": L(locs, f"classes.{cid}.name"), "desc": L(locs, f"classes.{cid}.desc"),
            "passiveName": L(locs, f"classes.{cid}.passive_name"), "passiveDesc": L(locs, f"classes.{cid}.passive_desc"),
            "emblem": copy_png(c["emblem"]["path"], f"img/class/{cid}.png"),
            "starter": [{"id": s, "name": L(locs, f"cards.{s}.name")} for s in starter[cid]],
            "cardCount": sum(1 for x in raw_cards.values() if x.get("class") == cid and x.get("type") != "joker"),
        })

    # ---------- cartas ----------
    art = rawd.get("card_art", {})
    boss_j = {j["id"] for j in inv["jokers"]["boss_jokers"]["list"]}
    counter_j = {j["id"] for j in (inv["jokers"]["counter_jokers"]["list"] if isinstance(inv["jokers"]["counter_jokers"], dict) else inv["jokers"]["counter_jokers"])}
    icons_done = {}
    for cid, c in sorted(raw_cards.items()):
        icon = art.get(cid, cid)
        if icon not in icons_done:
            folder = os.path.join(GAME, "assets/sprites/icons_anim", icon)
            fps = 8
            meta = os.path.join(folder, "meta.lua")
            if os.path.exists(meta):
                m = re.search(r"fps\s*=\s*(\d+)", open(meta, encoding="utf-8").read())
                fps = int(m.group(1)) if m else 8
            icons_done[icon] = strip(folder, f"img/cards/{icon}.png", fps=fps)
        vars_ = c.get("vars") or {}
        card = {"id": cid, "rarity": c["rarity"], "type": c["type"], "cost": c["cost"], "atk": c.get("attack") or 0,
                "def": c.get("defense") or 0, "class": c.get("class"), "tags": c.get("tags") or [],
                "name": L(locs, f"cards.{cid}.name"),
                "desc": {l: fill((locs[l].get("cards", {}).get(cid) or {}).get("desc"), vars_) for l in LOC},
                "icon": icons_done[icon]}
        if cid in boss_j:
            data["jokersBoss"].append(card)
        elif cid in counter_j:
            data["jokersCounter"].append(card)
        data["cards"].append(card)
    data["cardCounts"] = {r: sum(1 for x in raw_cards.values() if x["rarity"] == r) for r in ["common", "uncommon", "rare", "legendary"]}
    data["cardCounts"]["total"] = len(raw_cards)

    # ---------- combos, selos, maldições ----------
    for cb in inv["combos"]["rules"]:
        desc = L(locs, f"damage_preview.combo_desc.{cb['id']}")
        desc = {l: fill(v, {"v": cb.get("step"), "max": cb.get("step") * cb.get("cap")}) for l, v in desc.items()}
        data["combos"].append({"id": cb["id"], "name": L(locs, f"combos.{cb['id']}"), "step": cb.get("step"), "cap": cb.get("cap"), "desc": desc})
    for i, s in enumerate(inv["endless_and_seals"]["seals"], 1):
        sid = s["id"]
        data["seals"].append({"n": i, "id": sid, "name": L(locs, f"seals.{sid}.name"), "desc": L(locs, f"seals.{sid}.desc")})
    for cu in inv["endless_and_seals"]["curses"]:
        k = cu["id"]
        data["curses"].append({"id": k, "name": L(locs, f"endless_curses.{k}.name"), "desc": L(locs, f"endless_curses.{k}.desc")})

    # ---------- textos de interface tirados do jogo ----------
    data["ui"] = {
        "subtitle": L(locs, "menu.subtitle"), "sealsTitle": L(locs, "seal_ui.title"), "endless": L(locs, "acts.endless"),
        "endTurn": L(locs, "play_button.end_turn"), "playCards": L(locs, "play_button.label"), "block": L(locs, "keyword.block.name"),
        "fogName": L(locs, "keyword.fog.name"), "fogDesc": L(locs, "keyword.fog.text"), "blockDesc": L(locs, "keyword.block.text"), "combo": L(locs, "battle.combo"),
        "yourTurn": L(locs, "battle.your_turn"), "enemyTurn": L(locs, "battle.enemy_turn"), "mana": L(locs, "tutorial.status.mana.name"),
        "damage": L(locs, "pack.chip_damage"), "hiddenIntent": L(locs, "status.intent_unknown.name"),
        "classSelect": L(locs, "class_select.title"),
        "rarity": {r: L(locs, f"rarity.{r}") for r in ["common", "uncommon", "rare", "legendary"]},
    }

    # ---------- ícones e sprites de interface ----------
    icons = {}
    for n in ["intent_attack", "intent_multi", "intent_defense", "intent_unknown", "intent_strong", "intent_buff"]:
        icons[n] = copy_png(f"assets/sprites/icons/{n}.png", f"img/icons/{n}.png")
    for n in ["ui_mana", "ui_deck", "ui_jokers", "ui_score_star", "ui_health"]:
        icons[n] = copy_png(f"assets/sprites/icons/{n}.png", f"img/icons/{n}.png")
    for n in ["stat_sword", "stat_shield", "seal_common", "seal_uncommon", "seal_rare", "seal_legendary", "cursor_hand", "corner_flourish"]:
        icons[n] = copy_png(f"assets/sprites/ui/{n}.png", f"img/ui/{n}.png")
    data["icons"] = icons
    data["cloud"] = copy_png("assets/sprites/world/cloud_0.png", "img/world/cloud.png")

    # ---------- capturas (galeria e imprensa) ----------
    shots = {}
    for lang in ["en", "pt_BR"]:
        d = os.path.join(GAME, "steam/store/screenshots", lang)
        arr = []
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png"):
                continue
            im = Image.open(os.path.join(d, f)).convert("RGB")
            base = os.path.splitext(f)[0]
            full = save(im, f"img/shots/{lang}/{base}.webp", quality=90, method=6)
            th = save(im.resize((im.width // 2, im.height // 2), Image.NEAREST), f"img/shots/{lang}/{base}_s.webp", quality=82, method=6)
            arr.append({"id": base, "full": full, "thumb": th, "png": os.path.join(d, f)})
        shots[lang] = arr
    data["shots"] = {k: [{x: y for x, y in s.items() if x != "png"} for s in v] for k, v in shots.items()}

    # ---------- som ----------
    sfx = {}
    for n in ["menu-open", "combo-trigger", "card-play-attack", "card-play-defense", "battle-victory", "button-click", "joker-tick", "card-draw", "enemy-attack"]:
        p = os.path.join(GAME, "audio/sfx", n + ".mp3")
        if os.path.exists(p):
            sfx[n] = raw(p, f"media/sfx/{n}.mp3")
    data["sfx"] = sfx

    # ---------- fonte (OFL) ----------
    from fontTools.ttLib import TTFont
    os.makedirs(os.path.join(PUB, "fonts"), exist_ok=True)
    f = TTFont(g("assets/fonts/pixel.ttf"))
    f.flavor = "woff2"
    f.save(os.path.join(PUB, "fonts/pixel.woff2"))
    SIZE["fonts/pixel.woff2"] = os.path.getsize(os.path.join(PUB, "fonts/pixel.woff2"))
    # aviso de licença completo (OFL 1.1), o mesmo trecho que o jogo distribui
    notes = open(g("dist/THIRD_PARTY_NOTICES.txt"), encoding="utf-8").read()
    start = notes.index("Font: Grimoire Pixel")
    end = notes.find("\n====", start + 10)
    open(os.path.join(PUB, "fonts/OFL.txt"), "w", encoding="utf-8").write(notes[start:end if end > 0 else None].strip() + "\n")

    # ---------- kit de imprensa (.zip) ----------
    zpath = os.path.join(PUB, "media/runemoire-presskit.zip")
    os.makedirs(os.path.dirname(zpath), exist_ok=True)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write("E:/dev/projects/card-game-trailer/build/trailer/brand_runemoire/logo_final.png", "logo/runemoire_logo_1920x1080.png")
        z.write(g("steam/store/library_logo_1280x720.png"), "logo/runemoire_logo_transparent_1280x720.png")
        z.write(g("assets/branding/seal.png"), "logo/runemoire_seal_113.png")
        z.write(g("steam/store/header_capsule_920x430.png"), "art/header_capsule_920x430.png")
        z.write(g("steam/store/library_hero_3840x1240.png"), "art/hero_3840x1240.png")
        z.write(g("steam/store/main_capsule_1232x706.png"), "art/main_capsule_1232x706.png")
        for s in shots["en"]:
            z.write(s["png"], f"screenshots/en/{os.path.basename(s['png'])}")
        for s in shots["pt_BR"]:
            z.write(s["png"], f"screenshots/pt_BR/{os.path.basename(s['png'])}")
        z.writestr("README.txt", PRESS_README.replace("{contact}", CONFIG["contact"]))
    SIZE["media/runemoire-presskit.zip"] = os.path.getsize(zpath)
    data["presskit"] = {"src": "/media/runemoire-presskit.zip", "bytes": SIZE["media/runemoire-presskit.zip"]}

    out = os.path.join(SITE, "src/data/game.json")
    json.dump(data, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    tot = sum(SIZE.values())
    print(f"game.json ok; {len(SIZE)} arquivos em public/, {tot/1e6:.1f} MB no total")
    for k in sorted(SIZE, key=SIZE.get, reverse=True)[:8]:
        print(f"  {SIZE[k]/1e3:8.1f} KB  {k}")


PRESS_README = """RUNEMOIRE — press kit
=====================

Runemoire is a pixel-art roguelike deckbuilder by Daniel Cortez / DC Solutions.
Six acts, six bosses with signature curses, three classes, 145 animated cards,
an endless mode and ten Grimoire Seals. Formerly known as Grimoire.

Contents
  logo/         logo, transparent logo, seal
  art/          key art (capsules and hero)
  screenshots/  in-game screenshots, English and Brazilian Portuguese (1920x1080)

Trailers: https://runemoire.com/#trailers
Contact: {contact}

You may use these assets in coverage, reviews, streams and videos about the game.
"""

if __name__ == "__main__":
    main(sys.argv[1])
