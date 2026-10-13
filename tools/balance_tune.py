#!/usr/bin/env python3
"""Sweep de knobs contra as BANDAS-ALVO (Out/2026).

Roda baterias paralelas (tools/balance.py) para cada combinacao de knobs e
pontua a distancia das taxas de vitoria por piloto em relacao as bandas de
memory/sts_difficulty_targets.md (tools/balance_targets.json). Imprime as
melhores configuracoes. NAO altera o jogo: os numeros recomendados vao para o
dono dos NUMEROS (frente combate-clareza / Config.lua).

    python tools/balance_tune.py --runs 40 --pilots average,expert_fast \
        --enemy-power 0.8,0.85 0.9,0.9 1.0,1.0 --boss-hp 1.0 1.15 --label sweep1

    # grade pequena so no dano do inimigo:
    python tools/balance_tune.py --runs 30 --enemy-power 0.7,0.85 0.8,0.85 0.9,0.85

Cada ponto da grade e UMA chamada do balance.py (todos os cores). Custo:
pontos x (runs x classes x pilotos) / throughput — com average/expert_fast
~10 runs/s na parede, 40 runs x 3 classes x 2 pilotos ~ 25 s por ponto.

Pontuacao: para cada (piloto, classe) com banda [lo, hi], penalidade =
distancia do winrate ao intervalo (0 dentro), em pontos percentuais,
ponderada pelo peso do piloto; soma = score (menor e melhor). Tambem
reporta a distribuicao de mortes por ato contra a banda "ato dominante".
"""
import argparse, itertools, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGETS = os.path.join(HERE, "balance_targets.json")


def load_targets(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def score_point(groups, targets):
    """groups: report['groups'] (classe|piloto|selo). Devolve (score, detalhes)."""
    total = 0.0
    details = []
    bands = targets["winrate"]
    weights = targets.get("pilot_weight", {})
    for g in groups.values():
        band = bands.get(g["pilot"])
        if not band:
            continue
        lo, hi = band["lo"], band["hi"]
        wr = g["winrate"]
        pen = 0.0
        if wr < lo:
            pen = (lo - wr) * 100
        elif wr > hi:
            pen = (wr - hi) * 100
        w = weights.get(g["pilot"], 1.0)
        total += pen * w
        details.append((g["pilot"], g["class"], wr, lo, hi, pen * w))
    return total, details


def run_point(args, knobs, label):
    cmd = [sys.executable, os.path.join(HERE, "balance.py"), "--runs", str(args.runs),
           "--classes", args.classes, "--pilots", args.pilots, "--seeds", str(args.seed),
           "--seal", str(args.seal), "--procs", str(args.procs), "--label", label, "--quiet",
           "--out", args.out]
    if knobs.get("enemy_power"):
        cmd += ["--enemy-power", knobs["enemy_power"]]
    if knobs.get("boss_hp"):
        cmd += ["--boss-hp", knobs["boss_hp"]]
    if knobs.get("combo"):
        cmd += ["--combo", knobs["combo"]]
    if knobs.get("player_hp"):
        cmd += ["--player-hp", knobs["player_hp"]]
    for k, flag in (("enemy_power_act", "--enemy-power-act"), ("boss_hp_id", "--boss-hp-id"),
                    ("combo_joker", "--combo-joker"), ("mage_focus", "--mage-focus"),
                    ("rogue_poison", "--rogue-poison"), ("hand", "--hand"), ("mana", "--mana")):
        if knobs.get(k):
            cmd += [flag, knobs[k]]
    if args.dir:
        cmd += ["--dir", args.dir]
    subprocess.run(cmd, cwd=ROOT, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    with open(os.path.join(args.out, label, "results.json"), encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=30)
    ap.add_argument("--classes", default="all")
    ap.add_argument("--pilots", default="average,expert_fast")
    ap.add_argument("--seed", "--seeds", dest="seed", type=int, default=720000)
    ap.add_argument("--seal", type=int, default=0)
    ap.add_argument("--procs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--enemy-power", nargs="*", default=[""], help='valores "dano,vida"')
    ap.add_argument("--boss-hp", nargs="*", default=[""])
    ap.add_argument("--combo", nargs="*", default=[""])
    ap.add_argument("--player-hp", nargs="*", default=[""])
    ap.add_argument("--enemy-power-act", nargs="*", default=[""], help='"2:0.9,0.9;3:0.85,0.85"')
    ap.add_argument("--boss-hp-id", nargs="*", default=[""], help='"tower_lich=0.8"')
    ap.add_argument("--combo-joker", nargs="*", default=[""])
    ap.add_argument("--mage-focus", nargs="*", default=[""])
    ap.add_argument("--rogue-poison", nargs="*", default=[""])
    ap.add_argument("--hand", nargs="*", default=[""])
    ap.add_argument("--mana", nargs="*", default=[""])
    ap.add_argument("--dir", default="", help="arvore do jogo (worktree) a medir")
    ap.add_argument("--targets", default=TARGETS)
    ap.add_argument("--label", default=time.strftime("tune-%Y%m%d-%H%M%S"))
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "balance"))
    args = ap.parse_args()

    targets = load_targets(args.targets)
    grid = list(itertools.product(args.enemy_power, args.boss_hp, args.combo, args.player_hp,
                                  args.enemy_power_act, args.boss_hp_id, args.combo_joker,
                                  args.mage_focus, args.rogue_poison, args.hand, args.mana))
    print(f"[tune] {len(grid)} pontos x ({args.runs} runs x {args.classes} x {args.pilots})")
    results = []
    t0 = time.time()
    for i, (ep, bh, cb, php, epa, bid, cj, mf, rp, hd, mn) in enumerate(grid, 1):
        knobs = {"enemy_power": ep, "boss_hp": bh, "combo": cb, "player_hp": php,
                 "enemy_power_act": epa, "boss_hp_id": bid, "combo_joker": cj,
                 "mage_focus": mf, "rogue_poison": rp, "hand": hd, "mana": mn}
        label = f"{args.label}-p{i:02d}"
        tp = time.time()
        res = run_point(args, knobs, label)
        sc, det = score_point(res["report"]["groups"], targets)
        results.append({"knobs": knobs, "score": round(sc, 1), "label": label,
                        "groups": {k: {"winrate": v["winrate"], "runs": v["runs"], "deaths": v["deaths_by_act"]}
                                   for k, v in res["report"]["groups"].items()},
                        "acts": res["report"].get("acts", {})})
        desc = " ".join(f"{k}={v}" for k, v in knobs.items() if v) or "(base)"
        print(f"[tune] {i}/{len(grid)} {desc}: score {sc:.1f} ({time.time()-tp:.0f}s)")
        for pilot, cls, wr, lo, hi, pen in det:
            flag = "" if pen == 0 else f"  <- fora da banda {lo:.0%}-{hi:.0%}"
            print(f"         {pilot:12s} {cls:8s} {wr:5.0%}{flag}")
        # contexto além da vitória: quem mata (muro) e ritmo das lutas tardias
        rep = res["report"]
        by_enemy = list(rep.get("deaths", {}).get("by_enemy", {}).items())[:3]
        acts = rep.get("acts", {})
        late = " · ".join(f"A{a} {acts[a]['turns_per_fight']}t/{acts[a]['boss_turns']}b"
                          for a in sorted(acts) if a in acts)
        print(f"         muros: {', '.join(f'{k} {v}' for k, v in by_enemy)} | turnos/luta(/chefe): {late}")
        results[-1]["walls"] = dict(by_enemy)
    results.sort(key=lambda r: r["score"])
    print(f"\n[tune] melhores configuracoes ({(time.time()-t0)/60:.1f} min):")
    for r in results[:5]:
        desc = " ".join(f"{k}={v}" for k, v in r["knobs"].items() if v) or "(base)"
        wr = ", ".join(f"{k.split('|')[1]}/{k.split('|')[0]} {v['winrate']:.0%}" for k, v in r["groups"].items())
        print(f"  score {r['score']:6.1f}  {desc}  | {wr}  | {r['label']}")
    outp = os.path.join(args.out, args.label + "-summary.json")
    with open(outp, "w", encoding="utf-8") as f:
        json.dump({"targets": targets, "results": results}, f, ensure_ascii=False, indent=1)
    print(f"[tune] resumo: {outp}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
