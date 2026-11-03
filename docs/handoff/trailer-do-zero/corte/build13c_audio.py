import os, sys, subprocess
import numpy as np
sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')
os.environ.setdefault('TRAILER_SRC', os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-c11', 'trailer'))
B = r'E:\dev\projects\card-game-trailer\build\trailer'
import trailer_v3 as v
import trailer_c13c_cut as c

spec = c.CUTS[c.NAME]
st, tot = v.plan(spec['edl'])
os.environ['TRAILER_STEM'] = os.path.join(B, c.NAME + '_music.f32')
a = v.mix_audio(spec, st, tot)
f32 = os.path.join(B, c.NAME + '.f32')
a.astype(np.float32).tofile(f32)
src = os.path.join(B, 'grimoire_trailer_c13_raw.mp4')
out = os.path.join(B, c.NAME + '_raw.mp4')
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', src, '-f', 'f32le', '-ar', '48000', '-ac', '2', '-i', f32,
                '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k', '-shortest', '-movflags', '+faststart', out], check=True)
os.remove(f32)
print('[ok]', out, round(tot, 3))
