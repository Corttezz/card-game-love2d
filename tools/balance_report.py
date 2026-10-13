#!/usr/bin/env python3
"""Agregacao e relatorio da bateria (tools/balance.py).

Entrada: lista de `runRec` (tools/autoplay.lua, serializados por
tools/balance_sim.lua via BALANCE_JSON). Saida: dict `report` (JSON) e o
Markdown correspondente. Tudo que e ESTIMATIVA (duracao da run em minutos)
esta rotulado e com as constantes a vista.

    python tools/balance_report.py reports/balance/<label>/records.json   # re-renderiza
"""
import json, math, sys
from collections import defaultdict

ACTS = 6
FLOORS_PER_ACT = 8
CUTS = (9, 17)       # batalhas: fim do A1 (~9a batalha) e do A2 (~17a) — como no balance_sim

# ---- duracao estimada da run (segundos) ------------------------------------
# Calibrado pelos beats do combate (CombatBeats.HOLD, memory/combat_beats.md:
# turno do inimigo ~2,4 s; carta = voo ~0,9 + impacto 0,35 + respiro 0,30 +
# procs) e por tempos TIPICOS de tela. E estimativa, nao medicao: ajustar aqui
# quando houver telemetria real de sessao.
SEC_ENEMY_TURN = 2.4
SEC_LEVA_BASE = 1.3          # voo das cartas + cards_landed
SEC_PER_CARD = 0.75          # impacto + respiro + procs medios
SEC_THINK = {"naive": 4.0, "average": 9.0, "expert": 14.0, "expert_fast": 14.0, "expert_full": 14.0}
SEC_REWARD = 15.0            # tela de espolios + cash out
SEC_NODE = {"shop": 50.0, "rest": 12.0, "event": 20.0}
SEC_MAP = 6.0                # escolha de caminho por andar


def wilson(k, n, z=1.96):
    if n <= 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (p, max(0.0, centre - half), min(1.0, centre + half))


def pct(x):
    return f"{100*x:.0f}%"


def ci_str(k, n):
    p, lo, hi = wilson(k, n)
    return f"{pct(p)} [{pct(lo)}–{pct(hi)}]"


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else 0.0


def key_cps(r):
    return (r.get("class", "?"), r.get("pilot", "?"), int(r.get("seal", 0) or 0))


def estimate_minutes(r):
    pilot = r.get("pilot", "expert")
    turns = r.get("turns", 0) or 0
    plays = r.get("plays") or {}
    levas = plays.get("n", 0) or 0
    cards = plays.get("cards", 0) or 0
    battle = turns * (SEC_ENEMY_TURN + SEC_THINK.get(pilot, 10.0)) + levas * SEC_LEVA_BASE + cards * SEC_PER_CARD
    battles = r.get("battles", 0) or 0
    act = r.get("act", 1) or 1
    floor = r.get("floorInAct", 1) or 1
    floors_visited = (act - 1) * FLOORS_PER_ACT + floor
    other_nodes = max(0, floors_visited - battles)
    eco = r.get("eco") or {}
    shops = len(eco.get("shops") or [])
    rest_event = max(0, other_nodes - shops)
    screens = battles * SEC_REWARD + shops * SEC_NODE["shop"] + rest_event * (SEC_NODE["rest"] + SEC_NODE["event"]) / 2
    return (battle + screens + floors_visited * SEC_MAP) / 60.0


def build(records, summary=None):
    rep = {"summary": summary or {}, "groups": {}, "deaths": {}, "acts": {}, "damage": {},
           "deck": {}, "cards": {}, "jokers": {}, "forge": {}, "shop": {}, "length": {}}
    recs = [r for r in records if not r.get("crash")]
    crashes = [r for r in records if r.get("crash")]
    rep["crashes"] = len(crashes)

    # ---- winrate por classe/piloto/selo -----------------------------------
    groups = defaultdict(list)
    for r in recs:
        groups[key_cps(r)].append(r)
    for (cls, pilot, seal), rs in sorted(groups.items()):
        wins = sum(1 for r in rs if r.get("won"))
        p, lo, hi = wilson(wins, len(rs))
        deaths_by_act = defaultdict(int)
        for r in rs:
            if not r.get("won") and r.get("death"):
                deaths_by_act[int(r["death"].get("act", 0))] += 1
        rep["groups"][f"{cls}|{pilot}|{seal}"] = {
            "class": cls, "pilot": pilot, "seal": seal, "runs": len(rs), "wins": wins,
            "winrate": round(p, 4), "ci_lo": round(lo, 4), "ci_hi": round(hi, 4),
            "battles_mean": round(mean(r.get("battles", 0) for r in rs), 1),
            "deck_final_mean": round(mean(len(r.get("deck") or []) for r in rs), 1),
            "deaths_by_act": dict(sorted(deaths_by_act.items())),
            "minutes_mean": round(mean(estimate_minutes(r) for r in rs), 1),
            "cpu_s_mean": round(mean(r.get("cpuSeconds", 0) for r in rs), 2),
        }

    # ---- onde se morre -----------------------------------------------------
    d_node, d_enemy, d_floor = defaultdict(int), defaultdict(int), defaultdict(int)
    for r in recs:
        d = r.get("death")
        if r.get("won") or not d:
            continue
        a = int(d.get("act", 0))
        d_node[f"A{a} {d.get('node', '?')}"] += 1
        d_enemy[f"A{a} {d.get('sprite') or d.get('enemy') or '?'}"] += 1
        d_floor[f"A{a}-F{d.get('floor', '?')}"] += 1
    rep["deaths"] = {"by_node": dict(sorted(d_node.items(), key=lambda kv: -kv[1])),
                     "by_enemy": dict(sorted(d_enemy.items(), key=lambda kv: -kv[1])),
                     "by_floor": dict(sorted(d_floor.items(), key=lambda kv: -kv[1]))}

    # ---- combate por ato (battleLog) ---------------------------------------
    per_act = defaultdict(lambda: {"battles": 0, "turns": 0, "hpLost": 0, "bosses": 0, "bossTurns": 0,
                                   "elites": 0, "eliteTurns": 0, "eliteHpLost": 0, "deaths": 0})
    per_act_pilot = defaultdict(lambda: defaultdict(lambda: {"battles": 0, "turns": 0, "hpLost": 0}))
    for r in recs:
        for b in r.get("battleLog") or []:
            a = int(b.get("act", 1))
            x = per_act[a]
            x["battles"] += 1
            x["turns"] += b.get("turns", 0)
            x["hpLost"] += b.get("hpLost", 0)
            if not b.get("won"):
                x["deaths"] += 1
            if b.get("node") == "boss":
                x["bosses"] += 1
                x["bossTurns"] += b.get("turns", 0)
            if b.get("node") == "elite":
                x["elites"] += 1
                x["eliteTurns"] += b.get("turns", 0)
                x["eliteHpLost"] += b.get("hpLost", 0)
            y = per_act_pilot[r.get("pilot", "?")][a]
            y["battles"] += 1
            y["turns"] += b.get("turns", 0)
            y["hpLost"] += b.get("hpLost", 0)
    for a, x in per_act.items():
        n = max(1, x["battles"])
        rep["acts"][str(a)] = {
            "battles": x["battles"], "turns_per_fight": round(x["turns"] / n, 2),
            "hp_lost_per_fight": round(x["hpLost"] / n, 2),
            "hp_lost_per_turn": round(x["hpLost"] / max(1, x["turns"]), 2),
            "deaths": x["deaths"], "death_rate": round(x["deaths"] / n, 4),
            "boss_turns": round(x["bossTurns"] / max(1, x["bosses"]), 1) if x["bosses"] else None,
            "elite_turns": round(x["eliteTurns"] / max(1, x["elites"]), 1) if x["elites"] else None,
            "elite_hp_lost": round(x["eliteHpLost"] / max(1, x["elites"]), 1) if x["elites"] else None,
        }
    rep["acts_by_pilot"] = {p: {str(a): {"turns_per_fight": round(v["turns"] / max(1, v["battles"]), 2),
                                        "hp_lost_per_fight": round(v["hpLost"] / max(1, v["battles"]), 2)}
                                for a, v in sorted(d.items())}
                            for p, d in per_act_pilot.items()}

    # ---- dano por fonte ----------------------------------------------------
    by_pilot_src = defaultdict(lambda: defaultdict(float))
    by_pilot_parts = defaultdict(lambda: defaultdict(float))
    by_class_src = defaultdict(lambda: defaultdict(float))
    for r in recs:
        for k, v in (r.get("dmg") or {}).items():
            by_pilot_src[r.get("pilot", "?")][k] += v
            by_class_src[r.get("class", "?")][k] += v
        for k, v in (r.get("dmgParts") or {}).items():
            by_pilot_parts[r.get("pilot", "?")][k] += v

    def shares(d):
        tot = sum(v for v in d.values() if v > 0) or 1.0
        return {k: round(v / tot, 4) for k, v in sorted(d.items())}
    rep["damage"] = {"by_source_pilot": {p: shares(d) for p, d in by_pilot_src.items()},
                     "by_source_class": {c: shares(d) for c, d in by_class_src.items()},
                     "card_parts_pilot": {p: shares(d) for p, d in by_pilot_parts.items()}}

    # ---- deck ao longo da run ---------------------------------------------
    deck_curve = defaultdict(lambda: defaultdict(list))
    for r in recs:
        for i, n in enumerate(r.get("deckByBattle") or [], start=1):
            deck_curve[r.get("pilot", "?")][i].append(n)
    rep["deck"] = {p: {str(i): round(mean(v), 1) for i, v in sorted(d.items()) if len(v) >= 3}
                   for p, d in deck_curve.items()}
    rep["deck_final_by_pilot"] = {p: round(mean(len(r.get("deck") or []) for r in rs), 1)
                                  for p, rs in defaultdict(list, {k: [r for r in recs if r.get("pilot") == k]
                                                                    for k in set(r.get("pilot") for r in recs)}).items()}

    # ---- poder de carta (vivas no corte, com x sem, mesma classe) ----------
    cards = {}
    for cut in CUTS:
        alive = [r for r in recs if (r.get("floors") or 0) > cut]
        has = []
        ids = set()
        for r in alive:
            h = {a["id"] for a in (r.get("acquired") or []) if (a.get("floor") or 0) <= cut}
            has.append(h)
            ids |= h
        stats = []
        for cid in ids:
            w = n = wo = no = 0
            fw = fwo = 0
            for r, h in zip(alive, has):
                # mesma classe: carta neutra aparece em todas; de classe so na dela
                if cid in h:
                    n += 1; fw += r.get("floors", 0); w += 1 if r.get("won") else 0
                else:
                    cls_of = cid.split("_")[0]
                    if cls_of in ("warrior", "mage", "rogue") and cls_of != r.get("class"):
                        continue
                    no += 1; fwo += r.get("floors", 0); wo += 1 if r.get("won") else 0
            if n >= 3 and no >= 3:
                stats.append({"id": cid, "with": n, "without": no,
                              "win_with": round(w / n, 3), "win_without": round(wo / no, 3),
                              "depth_with": round(fw / n, 1), "depth_without": round(fwo / no, 1),
                              "d_win": round(w / n - wo / no, 3), "d_depth": round(fw / n - fwo / no, 1)})
        stats.sort(key=lambda s: -s["d_win"])
        cards[str(cut)] = {"alive": len(alive), "ranking": stats}
    offered, picked = defaultdict(int), defaultdict(int)
    for r in recs:
        for cid, n in (r.get("offered") or {}).items():
            offered[cid] += n
        for a in r.get("acquired") or []:
            picked[a["id"]] += 1
    pick_rate = [{"id": c, "offered": o, "picked": picked.get(c, 0), "rate": round(picked.get(c, 0) / o, 3)}
                 for c, o in offered.items() if o >= 5]
    pick_rate.sort(key=lambda s: -s["rate"])
    rep["cards"] = {"power": cards, "pick_rate": pick_rate}

    # ---- coringas ------------------------------------------------------------
    jk = defaultdict(lambda: {"runs": 0, "wins": 0, "active": 0, "depth": 0})
    for r in recs:
        seen = set()
        for j in r.get("jokers") or []:
            if j["id"] in seen:
                continue
            seen.add(j["id"])
            s = jk[j["id"]]
            s["runs"] += 1
            s["wins"] += 1 if r.get("won") else 0
            s["active"] += 1 if j.get("active") else 0
            s["depth"] += r.get("floors", 0)
    base_win = mean(1 if r.get("won") else 0 for r in recs) if recs else 0
    jl = [{"id": k, "runs": s["runs"], "active": s["active"], "win_with": round(s["wins"] / s["runs"], 3),
           "lift": round(s["wins"] / s["runs"] - base_win, 3), "depth_mean": round(s["depth"] / s["runs"], 1)}
          for k, s in jk.items() if s["runs"] >= 3]
    jl.sort(key=lambda s: -s["lift"])
    rep["jokers"] = {"base_winrate": round(base_win, 3), "ranking": jl}

    # ---- forja ---------------------------------------------------------------
    forged_cards = defaultdict(int)
    by_count = defaultdict(lambda: {"runs": 0, "wins": 0})
    for r in recs:
        f = r.get("forges") or []
        b = min(6, len(f))
        by_count[b]["runs"] += 1
        by_count[b]["wins"] += 1 if r.get("won") else 0
        for x in f:
            forged_cards[x.get("id", "?")] += 1
    rep["forge"] = {"winrate_by_forges": {str(k): {"runs": v["runs"], "winrate": round(v["wins"] / max(1, v["runs"]), 3)}
                                          for k, v in sorted(by_count.items())},
                    "most_forged": dict(sorted(forged_cards.items(), key=lambda kv: -kv[1])[:15]),
                    "forges_per_run": round(mean(len(r.get("forges") or []) for r in recs), 2)}

    # ---- compras -------------------------------------------------------------
    buy = defaultdict(lambda: {"runs": 0, "wins": 0, "gold": 0, "count": 0})
    for r in recs:
        kinds = defaultdict(int)
        for p in r.get("purchases") or []:
            k = p.get("id") if p.get("kind") == "upgrade" else p.get("kind")
            kinds[k] += 1
            buy[k]["gold"] += p.get("gold", 0)
            buy[k]["count"] += 1
        for k in kinds:
            buy[k]["runs"] += 1
            buy[k]["wins"] += 1 if r.get("won") else 0
    rep["shop"] = {k: {"runs_bought": v["runs"], "win_when_bought": round(v["wins"] / max(1, v["runs"]), 3),
                       "lift": round(v["wins"] / max(1, v["runs"]) - base_win, 3),
                       "avg_price": round(v["gold"] / max(1, v["count"]), 1), "count": v["count"]}
                   for k, v in sorted(buy.items(), key=lambda kv: -kv[1]["runs"]) if v["runs"] >= 3}

    # ---- duracao ---------------------------------------------------------------
    by_pilot_len = defaultdict(list)
    by_pilot_len_win = defaultdict(list)
    for r in recs:
        by_pilot_len[r.get("pilot", "?")].append(estimate_minutes(r))
        if r.get("won"):
            by_pilot_len_win[r.get("pilot", "?")].append(estimate_minutes(r))
    rep["length"] = {p: {"minutes_mean": round(mean(v), 1),
                         "minutes_win_mean": round(mean(by_pilot_len_win.get(p, [])), 1) if by_pilot_len_win.get(p) else None,
                         "turns_mean": round(mean(r.get("turns", 0) for r in recs if r.get("pilot") == p), 1)}
                     for p, v in by_pilot_len.items()}
    rep["length_constants"] = {"SEC_ENEMY_TURN": SEC_ENEMY_TURN, "SEC_LEVA_BASE": SEC_LEVA_BASE,
                               "SEC_PER_CARD": SEC_PER_CARD, "SEC_THINK": SEC_THINK,
                               "SEC_REWARD": SEC_REWARD, "SEC_NODE": SEC_NODE, "SEC_MAP": SEC_MAP}
    return rep


def render_markdown(rep):
    s = rep.get("summary", {})
    out = []
    p = out.append
    p(f"# Bateria de balanceamento — {s.get('label', '')}")
    p("")
    p(f"{s.get('runs', '?')} runs | {s.get('runsPerClassPilot', '?')} por classe×piloto | seed base {s.get('seed', '?')} | "
      f"selo {s.get('seal', 0)} | relogio {s.get('clock', '?')} | {s.get('procs', '?')} processos | "
      f"{s.get('wallSeconds', 0)/60:.1f} min de parede | {s.get('cpuSeconds', 0):.0f} s de CPU | "
      f"{s.get('runsPerSecondWall', 0)} runs/s (parede) · {s.get('runsPerSecondPerCore', 0)} runs/s/core")
    k = s.get("knobs") or {}
    knobs = ", ".join(f"{a}={b}" for a, b in k.items() if b)
    if knobs:
        p(f"Knobs: {knobs}")
    if rep.get("crashes"):
        p(f"**CRASHES: {rep['crashes']}**")
    if s.get("anomalies"):
        p(f"Anomalias do piloto: {s['anomalies']}")
    p("")
    p("## Winrate por classe × piloto × selo (IC 95% Wilson)")
    p("")
    p("| classe | piloto | selo | runs | vitorias | winrate | batalhas | deck final | mortes por ato | min/run (est.) | s CPU/run |")
    p("|---|---|---|---|---|---|---|---|---|---|---|")
    for g in rep["groups"].values():
        deaths = " · ".join(f"A{a} {n}" for a, n in g["deaths_by_act"].items())
        p(f"| {g['class']} | {g['pilot']} | {g['seal']} | {g['runs']} | {g['wins']} | {ci_str(g['wins'], g['runs'])} | "
          f"{g['battles_mean']} | {g['deck_final_mean']} | {deaths} | {g['minutes_mean']} | {g['cpu_s_mean']} |")
    # por piloto (todas as classes)
    p("")
    p("| piloto | runs | winrate | mortes A1 | A2 | A3 | A4 | A5 | A6 |")
    p("|---|---|---|---|---|---|---|---|---|")
    pil = defaultdict(lambda: {"runs": 0, "wins": 0, "d": defaultdict(int)})
    for g in rep["groups"].values():
        x = pil[g["pilot"]]
        x["runs"] += g["runs"]; x["wins"] += g["wins"]
        for a, n in g["deaths_by_act"].items():
            x["d"][int(a)] += n
    for name, x in pil.items():
        ds = " | ".join(f"{x['d'].get(a, 0)} ({pct(x['d'].get(a, 0)/max(1, x['runs']))})" for a in range(1, 7))
        p(f"| {name} | {x['runs']} | {ci_str(x['wins'], x['runs'])} | {ds} |")
    p("")
    p("## Combate por ato")
    p("")
    p("| ato | batalhas | turnos/luta | vida perdida/luta | vida perdida/turno | mortes | taxa de morte/luta | turnos/chefe | turnos/elite | vida perdida/elite |")
    p("|---|---|---|---|---|---|---|---|---|---|")
    for a, x in sorted(rep["acts"].items(), key=lambda kv: int(kv[0])):
        p(f"| {a} | {x['battles']} | {x['turns_per_fight']} | {x['hp_lost_per_fight']} | {x['hp_lost_per_turn']} | "
          f"{x['deaths']} | {pct(x['death_rate'])} | {x['boss_turns'] or '-'} | {x['elite_turns'] or '-'} | {x['elite_hp_lost'] or '-'} |")
    if rep.get("acts_by_pilot"):
        p("")
        p("| piloto | turnos/luta A1..A6 | vida perdida/luta A1..A6 |")
        p("|---|---|---|")
        for pn, d in rep["acts_by_pilot"].items():
            t = " · ".join(str(d[a]["turns_per_fight"]) for a in sorted(d, key=int))
            h = " · ".join(str(d[a]["hp_lost_per_fight"]) for a in sorted(d, key=int))
            p(f"| {pn} | {t} | {h} |")
    p("")
    p("## Onde se morre")
    p("")
    p("| ato + no | mortes |  | ato + inimigo | mortes |")
    p("|---|---|---|---|---|")
    nodes = list(rep["deaths"]["by_node"].items())
    enemies = list(rep["deaths"]["by_enemy"].items())
    for i in range(max(len(nodes), len(enemies), 1)):
        a = nodes[i] if i < len(nodes) else ("", "")
        b = enemies[i] if i < len(enemies) else ("", "")
        p(f"| {a[0]} | {a[1]} |  | {b[0]} | {b[1]} |")
    p("")
    p("## Dano no inimigo por fonte (parte do total, por piloto)")
    p("")
    srcs = ["card", "orb", "magic", "dot", "thorn", "effect", "other"]
    p("| piloto | " + " | ".join(srcs) + " |")
    p("|---|" + "---|" * len(srcs))
    for pn, d in rep["damage"]["by_source_pilot"].items():
        p(f"| {pn} | " + " | ".join(pct(d.get(k, 0)) for k in srcs) + " |")
    p("")
    p("Composicao do valor das cartas de ATAQUE (DamagePreview.cardValue, por piloto):")
    p("")
    parts = ["base", "effects", "stat", "combo", "joker", "edition", "debuff"]
    p("| piloto | " + " | ".join(parts) + " |")
    p("|---|" + "---|" * len(parts))
    for pn, d in rep["damage"]["card_parts_pilot"].items():
        p(f"| {pn} | " + " | ".join(pct(d.get(k, 0)) for k in parts) + " |")
    p("")
    p("## Tamanho do deck ao longo da run (media no inicio da batalha N)")
    p("")
    for pn, d in rep["deck"].items():
        pts = [f"{i}:{v}" for i, v in d.items() if int(i) in (1, 3, 5, 8, 10, 13, 16, 20, 24, 28, 32, 36, 40)]
        p(f"- **{pn}**: " + " · ".join(pts) + f" — final {rep['deck_final_by_pilot'].get(pn, '?')}")
    p("")
    for cut, c in rep["cards"]["power"].items():
        p(f"## Poder de carta (runs vivas na batalha {cut}: {c['alive']})")
        p("")
        p("Vitoria e profundidade (batalhas) de quem TINHA a carta ate o corte x quem nao tinha (mesma classe).")
        p("")
        p("| carta | com | sem | win com | win sem | Δ win | prof. com | prof. sem | Δ prof. |")
        p("|---|---|---|---|---|---|---|---|---|")
        rk = c["ranking"]
        show = rk[:15] + ([None] if len(rk) > 30 else []) + rk[-10:] if len(rk) > 25 else rk
        for x in show:
            if x is None:
                p("| … | | | | | | | | |")
            else:
                p(f"| {x['id']} | {x['with']} | {x['without']} | {pct(x['win_with'])} | {pct(x['win_without'])} | "
                  f"{100*x['d_win']:+.0f}pp | {x['depth_with']} | {x['depth_without']} | {x['d_depth']:+.1f} |")
        p("")
    p("## Taxa de escolha (adquirida / ofertada, ≥5 ofertas)")
    p("")
    p("| carta | ofertada | adquirida | taxa |")
    p("|---|---|---|---|")
    pr = rep["cards"]["pick_rate"]
    for x in pr[:20]:
        p(f"| {x['id']} | {x['offered']} | {x['picked']} | {pct(x['rate'])} |")
    if len(pr) > 30:
        p("| … | | | |")
        for x in pr[-10:]:
            p(f"| {x['id']} | {x['offered']} | {x['picked']} | {pct(x['rate'])} |")
    p("")
    p(f"## Coringas (winrate base {pct(rep['jokers']['base_winrate'])})")
    p("")
    p("| coringa | runs que possuiam | ativo no fim | win com | lift | prof. media |")
    p("|---|---|---|---|---|---|")
    for x in rep["jokers"]["ranking"]:
        p(f"| {x['id']} | {x['runs']} | {x['active']} | {pct(x['win_with'])} | {100*x['lift']:+.0f}pp | {x['depth_mean']} |")
    p("")
    p(f"## Forja ({rep['forge']['forges_per_run']} forjas/run)")
    p("")
    p("| forjas na run | runs | winrate |")
    p("|---|---|---|")
    for k, v in rep["forge"]["winrate_by_forges"].items():
        p(f"| {k}{'+' if k == '6' else ''} | {v['runs']} | {pct(v['winrate'])} |")
    p("")
    p("Mais forjadas: " + ", ".join(f"{k} ({v})" for k, v in rep["forge"]["most_forged"].items()))
    p("")
    p("## Compras na loja (valor: winrate de quem comprou x base)")
    p("")
    p("| item | runs que compraram | win quando comprou | lift | preco medio | compras |")
    p("|---|---|---|---|---|---|")
    for k, v in rep["shop"].items():
        p(f"| {k} | {v['runs_bought']} | {pct(v['win_when_bought'])} | {100*v['lift']:+.0f}pp | ${v['avg_price']} | {v['count']} |")
    p("")
    p("## Duracao estimada da run")
    p("")
    c = rep["length_constants"]
    p(f"Estimativa: turnos × ({c['SEC_ENEMY_TURN']} s de turno inimigo + tempo de decisao por piloto {c['SEC_THINK']}) + "
      f"levas × {c['SEC_LEVA_BASE']} s + cartas × {c['SEC_PER_CARD']} s + espolios {c['SEC_REWARD']} s/batalha + "
      f"loja/descanso/evento {c['SEC_NODE']} + mapa {c['SEC_MAP']} s/andar. Calibrar com telemetria real.")
    p("")
    p("| piloto | turnos/run | min/run (todas) | min/run (vitorias) |")
    p("|---|---|---|---|")
    for pn, v in rep["length"].items():
        p(f"| {pn} | {v['turns_mean']} | {v['minutes_mean']} | {v['minutes_win_mean'] if v['minutes_win_mean'] is not None else '-'} |")
    p("")
    return "\n".join(out)


if __name__ == "__main__":
    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    recs = data["records"] if isinstance(data, dict) else data
    rep = build(recs, {"label": path})
    print(render_markdown(rep))
