#!/usr/bin/env python3
"""Bateria de balanceamento em PARALELO (Out/2026, pipeline instantaneo).

Divide `--runs` por (classe x piloto) em processos do LOVE que rodam
`balance_sim` no relogio instantaneo (tools/instant_engine.lua), um bloco
contiguo de seeds cada, em TODOS os cores. Junta os JSON (BALANCE_JSON) e
escreve o relatorio (Markdown + JSON) em reports/balance/<label>/.

    python tools/balance.py --runs 200 --classes all --seeds 1000 --seal 0
    python tools/balance.py --runs 60 --pilots naive,average,expert --procs 16
    python tools/balance.py --runs 30 --enemy-power 0.8,0.85 --boss-hp 1.1 --label ab1

Mesmas seeds de uma bateria serial (seed+1 .. seed+runs) — comparavel com o
historico de memory/balance_curves.md. Substitui tools/balance_par.py.

Metricas (tools/balance_report.py): winrate com IC 95% (Wilson) por
classe/piloto/selo; onde se morre (ato/andar/no/inimigo); turnos por luta e
vida perdida por luta por ato; dano por fonte; deck ao longo da run;
poder de carta (vitoria/profundidade com x sem, so runs vivas no corte);
coringas; forja; compras; duracao estimada da run em minutos.
"""
import argparse, json, os, subprocess, sys, tempfile, time, shutil

# O relatorio tem Δ/×/– e o console do Windows e cp1252: sem isto o print
# final derrubava o script DEPOIS de gravar o report (Out/2026).
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import balance_report  # noqa: E402

LOVE = os.environ.get("LOVEC", r"C:\Program Files\LOVE\lovec.exe")
ALL_CLASSES = ["warrior", "mage", "rogue"]
ALL_PILOTS = ["naive", "average", "expert"]


def split(n, parts):
    """n runs em `parts` blocos contiguos (tamanhos quase iguais, sem zeros)."""
    parts = max(1, min(parts, n))
    base, extra = divmod(n, parts)
    out, start = [], 0
    for i in range(parts):
        size = base + (1 if i < extra else 0)
        out.append((start, size))
        start += size
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=30, help="runs por classe e por piloto")
    ap.add_argument("--classes", default="all")
    ap.add_argument("--pilots", default="expert", help="naive,average,expert,expert_fast,all")
    ap.add_argument("--seeds", "--seed", dest="seed", type=int, default=720000, help="seed base (run i usa seed+i)")
    ap.add_argument("--seal", type=int, default=0)
    ap.add_argument("--endless", type=int, default=0, help="andares de endless depois da vitoria")
    # Teto padrao: cores - 2 (regra do dono: a maquina continua usavel e o
    # jogo dele nao engasga). PIDs dos processos vao para <out>/<label>/pids.txt
    # para dar para parar a bateria por PID (nunca por nome).
    ap.add_argument("--procs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    ap.add_argument("--enemy-power", default="", help='"dano,vida" (Config.Game.ENEMY_POWER)')
    ap.add_argument("--boss-hp", default="", help="multiplicador da vida de chefe/mini-chefe")
    ap.add_argument("--combo", default="", help='"volley=3,wall=5,pair=4" (step das regras)')
    ap.add_argument("--player-hp", default="")
    ap.add_argument("--enemy-power-act", default="", help='"2:0.9,0.9;3:0.85,0.85" (ato:dano,vida -> ENEMY_POWER_BY_ACT)')
    ap.add_argument("--boss-hp-id", default="", help='"tower_lich=0.8,storm_griffin=0.9" (hpMul do kit)')
    ap.add_argument("--combo-joker", default="", help="multiplicador dos coringas de combo")
    ap.add_argument("--mage-focus", default="", help="Game.MAGE_FOCUS_OFFSET (-1 = 0/1/2)")
    ap.add_argument("--rogue-poison", default="", help="Game.ROGUE_POISON_OFFSET")
    ap.add_argument("--hand", default="", help="mao inicial = compra por turno")
    ap.add_argument("--mana", default="", help="mana maxima do jogador")
    ap.add_argument("--joker-odds", default="", help='"battle:0.04,elite:0.4,mini_boss:0.4,boss:0.7" (Config.Offers.REWARD_JOKER_CHANCE)')
    ap.add_argument("--joker-slot-chance", default="", help='"0.5" ou "0.5:2" (Config.Offers.JOKER_SLOT_SERVICE_CHANCE[:PITY])')
    ap.add_argument("--clock", default="instant", choices=["instant", "frames"])
    ap.add_argument("--dir", default=ROOT, help="arvore do jogo (snapshot/worktree)")
    ap.add_argument("--label", default="")
    ap.add_argument("--env", action="append", default=[], metavar="KEY=VAL",
                    help="knob extra pro balance_sim (ex: --env BALANCE_POTIONS=1); repetivel")
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "balance"))
    ap.add_argument("--keep-logs", action="store_true")
    ap.add_argument("--quiet", action="store_true", help="nao imprime o relatorio inteiro")
    args = ap.parse_args()

    classes = ALL_CLASSES if args.classes == "all" else args.classes.split(",")
    pilots = ALL_PILOTS if args.pilots == "all" else args.pilots.split(",")
    label = args.label or time.strftime("%Y%m%d-%H%M%S")
    outdir = os.path.join(args.out, label)
    os.makedirs(outdir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="balance_")

    env = dict(os.environ)
    env["CARDGAME_HEADLESS"] = "1"      # janela 1x1 fora da tela (conf.lua) + escondida (tools/headless_window.lua)
    env["BALANCE_CLOCK"] = args.clock
    pids_path = os.path.join(outdir, "pids.txt")
    with open(pids_path, "w", encoding="utf-8") as f:
        f.write(f"{os.getpid()} balance.py\n")
    env["BALANCE_SEAL"] = str(args.seal)
    env["BALANCE_ENDLESS"] = str(args.endless)
    env["BALANCE_LABEL"] = label
    if args.enemy_power:
        env["BALANCE_ENEMY_POWER"] = args.enemy_power
    if args.boss_hp:
        env["BALANCE_BOSS_HP"] = args.boss_hp
    if args.combo:
        env["BALANCE_COMBO"] = args.combo
    if args.player_hp:
        env["BALANCE_PLAYER_HP"] = args.player_hp
    for flag, var in (("enemy_power_act", "BALANCE_ENEMY_POWER_ACT"), ("boss_hp_id", "BALANCE_BOSS_HP_ID"),
                      ("combo_joker", "BALANCE_COMBO_JOKER"), ("mage_focus", "BALANCE_MAGE_FOCUS"),
                      ("rogue_poison", "BALANCE_ROGUE_POISON"), ("hand", "BALANCE_HAND"),
                      ("mana", "BALANCE_MANA"), ("joker_odds", "BALANCE_JOKER_ODDS"),
                      ("joker_slot_chance", "BALANCE_JOKER_SLOT_CHANCE")):
        if getattr(args, flag):
            env[var] = getattr(args, flag)
    for kv in args.env:
        k, _, v = kv.partition("=")
        env[k] = v

    # Um job = (piloto, classe, bloco de seeds). Blocos pequenos (~2 por core)
    # pra cauda curta; pilotos caros (expert) ganham mais blocos pra equilibrar;
    # o escalonador abaixo roda ate `procs` por vez.
    jobs = []
    for pilot in pilots:
        for cls in classes:
            blocks = max(1, -(-2 * args.procs // max(1, len(pilots) * len(classes))))
            if pilot in ("expert", "expert_full"):
                blocks = max(blocks, min(args.runs, args.procs))
            for j, (start, size) in enumerate(split(args.runs, blocks)):
                if size <= 0:
                    continue
                jobs.append({"pilot": pilot, "cls": cls, "idx": j, "start": start, "size": size})

    t0 = time.time()
    running = []
    pending = list(jobs)
    done = []

    def launch(job):
        e = dict(env)
        tag = f"{job['pilot']}-{job['cls']}-{job['idx']}"
        e["CARDGAME_IDENTITY"] = f"cg-bal-{label}-{tag}"
        e["BALANCE_JSON"] = os.path.join(work, tag + ".json")
        e["BALANCE_OUT"] = os.path.join(work, tag + ".md")
        log = open(os.path.join(work, tag + ".log"), "w", encoding="utf-8")
        p = subprocess.Popen(
            [LOVE, ".", "balance_sim", str(job["size"]), job["cls"], str(args.seed + job["start"]), job["pilot"]],
            cwd=args.dir, env=e, stdout=log, stderr=subprocess.STDOUT)
        job["proc"], job["log"], job["json"] = p, log, e["BALANCE_JSON"]
        job["t0"] = time.time()
        with open(pids_path, "a", encoding="utf-8") as f:
            f.write(f"{p.pid} lovec {tag}\n")
        running.append(job)

    total = len(jobs)
    while pending or running:
        while pending and len(running) < args.procs:
            launch(pending.pop(0))
        time.sleep(0.2)
        for job in list(running):
            if job["proc"].poll() is not None:
                job["log"].close()
                running.remove(job)
                done.append(job)
                print(f"\r[balance] {len(done)}/{total} blocos prontos ({time.time()-t0:.0f}s)", end="", flush=True)
    print()
    wall = time.time() - t0

    records, metas, failed = [], [], []
    for job in done:
        try:
            with open(job["json"], encoding="utf-8") as f:
                d = json.load(f)
            metas.append(d["meta"])
            records.extend(d["records"])
        except (OSError, json.JSONDecodeError) as ex:
            failed.append(job)
            print(f"[balance] AVISO: bloco {job['pilot']}/{job['cls']}#{job['idx']} sem JSON ({ex}); "
                  f"log: {os.path.join(work, job['pilot'] + '-' + job['cls'] + '-' + str(job['idx']) + '.log')}")

    cpu = sum(m.get("cpuSeconds", 0) for m in metas)
    summary = {
        "label": label, "runsPerClassPilot": args.runs, "classes": classes, "pilots": pilots,
        "seed": args.seed, "seal": args.seal, "endless": args.endless, "clock": args.clock,
        "procs": args.procs, "wallSeconds": round(wall, 1), "cpuSeconds": round(cpu, 1),
        "runs": len(records), "runsPerSecondWall": round(len(records) / max(1e-6, wall), 2),
        "runsPerSecondPerCore": round(len(records) / max(1e-6, cpu), 3),
        "knobs": {"enemyPower": args.enemy_power, "bossHp": args.boss_hp, "combo": args.combo,
                  "playerHp": args.player_hp, "enemyPowerAct": args.enemy_power_act,
                  "bossHpId": args.boss_hp_id, "comboJoker": args.combo_joker,
                  "mageFocus": args.mage_focus, "roguePoison": args.rogue_poison,
                  "hand": args.hand, "mana": args.mana, "env": args.env},
        "anomalies": sum(len(m.get("anomalies", [])) for m in metas),
        "instantStalls": sum(m.get("instantStalls", 0) for m in metas),
        "failedBlocks": len(failed),
    }
    rep = balance_report.build(records, summary)
    md = balance_report.render_markdown(rep)
    with open(os.path.join(outdir, "report.md"), "w", encoding="utf-8") as f:
        f.write(md)
    with open(os.path.join(outdir, "results.json"), "w", encoding="utf-8") as f:
        json.dump({"summary": summary, "report": rep}, f, ensure_ascii=False, indent=1)
    with open(os.path.join(outdir, "records.json"), "w", encoding="utf-8") as f:
        json.dump(records, f, ensure_ascii=False)
    if not args.quiet:
        print(md)
    print(f"[balance] {len(records)} runs | {wall/60:.1f} min de parede | {cpu:.0f}s de CPU | "
          f"{summary['runsPerSecondWall']} runs/s (parede) | {summary['runsPerSecondPerCore']} runs/s/core")
    print(f"[balance] relatorio: {os.path.join(outdir, 'report.md')}")
    if args.keep_logs or failed:
        print(f"[balance] logs: {work}")
    else:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
