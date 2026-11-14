#!/usr/bin/env bash
# Monta o mp4 da cena de abertura de um ato a partir dos quadros do tools/record_act_intro.lua,
# com a música do ato e os SFX nos momentos do events.json, nos volumes padrão do jogo.
# uso: bash tools/act_intro_video.sh <ato> <saida.mp4>   (CARDGAME_IDENTITY = a mesma da gravação)
set -euo pipefail
ACT="${1:-1}"; OUT="${2:-act${ACT}_intro.mp4}"
ID="${CARDGAME_IDENTITY:-card-game-cenas}"
SAVE="$APPDATA/LOVE/$ID/act_intro_rec/act$ACT"
cd "$(dirname "$0")/.."
python -X utf8 - "$SAVE" "$ACT" "$OUT" <<'PY'
import json, subprocess, sys, os
save, act, out = sys.argv[1], sys.argv[2], sys.argv[3]
ev = json.load(open(os.path.join(save, "events.json"), encoding="utf-8"))
fps, dur = ev["fps"], ev["duration"]
# volumes do jogo: música 0,3 (grupo) x 0,6 (faixa); sfx 0,7 (grupo) x volume do SFX; ambiente 1,0
vol = {"actIntro1Wind": 0.9, "actIntro1Crows": 0.6 * 0.7, "actIntroChime": 0.75 * 0.7}
inputs = ["-framerate", str(fps), "-i", os.path.join(save, "frames", "%05d.png"),
          "-i", f"audio/music/music-act{act}.mp3"]
fil = [f"[1:a]atrim=0:{dur},volume=0.18,afade=t=in:st=0:d=2.5,afade=t=out:st={dur-0.9}:d=0.9[m]"]
mix = ["[m]"]
for i, e in enumerate(ev["events"]):
    inputs += ["-stream_loop", "-1" if e["loop"] else "0", "-i", e["path"]]
    k = len(mix) + 1
    # atos 2-6: cama em loop no grupo ambiente (0,9); detalhe vivo no grupo sfx (0,6 x 0,7)
    v = vol.get(e["code"], 0.9 if e["loop"] else 0.6 * 0.7)
    ms = int(e["t"] * 1000)
    chain = f"[{k}:a]atrim=0:{dur - e['t']:.3f},volume={v}"
    if e["loop"]:   # o ambiente acompanha o fade da imagem
        chain += f",afade=t=in:st=0:d=0.8,afade=t=out:st={max(0, dur - e['t'] - 0.9):.3f}:d=0.9"
    chain += f",adelay={ms}|{ms}[s{k}]"
    fil.append(chain); mix.append(f"[s{k}]")
fil.append("".join(mix) + f"amix=inputs={len(mix)}:normalize=0,atrim=0:{dur}[a]")
cmd = ["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(fil), "-map", "0:v", "-map", "[a]",
       "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", "-r", str(fps),
       "-c:a", "aac", "-b:a", "192k", "-shortest", out]
subprocess.run(cmd, check=True)
print("ok", out, f"{dur:.2f}s")
PY
