import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', '..', 'trailer-revisao-som'))
import importlib
ED = importlib.import_module(os.environ.get('TDZ_EDL', 'edl2'))
import remix_engine as E
T = os.path.join(ED.R, 'build', 'trailer')
v = os.path.join(ED.OUT, 'zero_crt.mkv'); a = os.path.join(ED.OUT, os.path.basename(ED.OUT) + '_' + ED.VARIANT, 'mix.wav')
if ED.VARIANT == 'rei':
    E.mux(v, a, os.path.join(T, f'grimoire_zero_{getattr(ED, "OUT_NAME", getattr(ED, "CUT", "corte2"))}_rei_720p.mp4'), scale='1280:720')
else:
    E.mux(v, a, os.path.join(T, f'grimoire_zero_{getattr(ED, "OUT_NAME", getattr(ED, "CUT", "corte2"))}_1080p.mp4'), scale='1920:1080')
    E.mux(v, a, os.path.join(T, f'grimoire_zero_{getattr(ED, "OUT_NAME", getattr(ED, "CUT", "corte2"))}_720p.mp4'), scale='1280:720')
