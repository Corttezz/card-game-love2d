import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import remix_engine as E
T = r'E:\dev\projects\card-game-trailer\build\trailer'
MAP = {'B': 'grimoire_kinetic_new', 'A': 'grimoire_kinetic_hook30', 'C': 'grimoire_trailer_v9_kinetic'}
for n in sys.argv[1:]:
    base = MAP[n]; mix = os.path.join(E.OUT, n, 'mix.wav')
    E.mux(os.path.join(T, base + '_1080p.mp4'), mix, os.path.join(T, base + '_som_1080p.mp4'))
    E.mux(os.path.join(T, base + '.mp4'), mix, os.path.join(T, base + '_som.mp4'))
    E.mux(os.path.join(T, base + '_1080p.mp4'), mix, os.path.join(T, base + '_som_720p.mp4'), scale='1280:720')
