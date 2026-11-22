"""Monta o mp4 da vinheta do logo do menu a partir do tools/record_menu_sting.lua.

Cada som entra no instante do events.json, com o volume e o tom que o jogo pediu, vezes o volume
padrao do grupo (sfx 0,7; musica 0,3 x 0,43 da faixa do menu, com o fade de entrada do jogo).
uso: python tools/menu_sting_video.py <saida.mp4>   (CARDGAME_IDENTITY = a mesma da gravacao)
"""
import json, os, subprocess, sys

PATHS = {
    "bootVortex": "audio/sfx/boot-vortex.mp3", "jokerTick": "audio/sfx/joker-tick.mp3",
    "bootElectric": "audio/sfx/boot-electric.mp3", "bootImpact": "audio/sfx/boot-impact.mp3",
    "menuHover": "audio/sfx/menu-hover.mp3", "forgeReveal": "audio/sfx/forge-reveal.mp3",
    "eventChoiceSeal": "audio/sfx/event-choice-seal.mp3", "effectChime": "audio/sfx/effect-chime.mp3",
    "menuMusic": "audio/music.mp3",
}
BASE = {"bootVortex": 0.60, "jokerTick": 0.58, "bootElectric": 0.55, "bootImpact": 0.75, "menuHover": 0.15,
        "forgeReveal": 0.65, "eventChoiceSeal": 0.22, "effectChime": 0.50, "menuMusic": 0.43}
SFX_GROUP, MUSIC_GROUP, SR = 0.7, 0.3, 48000

out = sys.argv[1] if len(sys.argv) > 1 else "menu_sting.mp4"
ident = os.environ.get("CARDGAME_IDENTITY", "card-game-cenas")
save = os.path.join(os.environ["APPDATA"], "LOVE", ident, "menu_sting_rec")
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ev = json.load(open(os.path.join(save, "events.json"), encoding="utf-8"))
fps, dur = ev["fps"], ev["duration"]
inputs = ["-framerate", str(fps), "-i", os.path.join(save, "frames", "%05d.png")]
fil, mix = [], []
for e in ev["events"]:
    k = len(mix) + 1
    ms = int(round(e["t"] * 1000))
    if e["music"]:
        inputs += ["-i", PATHS[e["code"]]]
        v = BASE[e["code"]] * MUSIC_GROUP
        fil.append(f"[{k}:a]aresample={SR},atrim=0:{dur - e['t']:.3f},volume={v:.5f},"
                   f"afade=t=in:st=0:d={max(e['fade'], 0.01):.2f},adelay={ms}|{ms}[s{k}]")
    else:
        inputs += ["-i", PATHS[e["code"]]]
        v = BASE[e["code"]] * e["vol"] * SFX_GROUP
        p = e["pitch"]
        fil.append(f"[{k}:a]aresample={SR},asetrate={SR * p:.0f},aresample={SR},volume={v:.5f},"
                   f"adelay={ms}|{ms}[s{k}]")
    mix.append(f"[s{k}]")
fil.append("".join(mix) + f"amix=inputs={len(mix)}:normalize=0,atrim=0:{dur},afade=t=out:st={dur - 0.4:.3f}:d=0.4[a]")
cmd = ["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(fil), "-map", "0:v", "-map", "[a]",
       "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(fps),
       "-c:a", "aac", "-b:a", "192k", "-shortest", out]
subprocess.run(cmd, check=True)
print("ok", out, f"{dur:.2f}s", len(mix), "sons")
