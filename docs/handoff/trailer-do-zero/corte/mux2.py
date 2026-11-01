import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', '..', 'trailer-revisao-som'))
import edl2 as ED
import remix_engine as E
T = os.path.join(ED.R, 'build', 'trailer')
v = os.path.join(ED.OUT, 'zero_crt.mkv'); a = os.path.join(ED.OUT, 'zero2_' + ED.VARIANT, 'mix.wav')
if ED.VARIANT == 'rei':
    E.mux(v, a, os.path.join(T, 'grimoire_zero_corte2_rei_720p.mp4'), scale='1280:720')
else:
    E.mux(v, a, os.path.join(T, 'grimoire_zero_corte2_1080p.mp4'), scale='1920:1080')
    E.mux(v, a, os.path.join(T, 'grimoire_zero_corte2_720p.mp4'), scale='1280:720')
