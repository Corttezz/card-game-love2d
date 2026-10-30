# make_patches.py: masks that hide the joker strip ("JOKERS 3/3", face jokers) of the combat HUD in deck8 and boss8.
# The combat camera is still, so the strip is replaced by the same pixels of a clean frame taken before the HUD appears.
# Writes <shot>_clean.png and <shot>_mask.png (1080p) next to this script.
import os, subprocess, numpy as np, cv2
TAKES = os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-v9', 'trailer')
HERE = os.path.dirname(os.path.abspath(__file__))
RECT = (60, 40, 560, 330)
SPEC = {'deck8': (580, [640, 700, 760, 830, 868, 900, 946, 989, 1000, 1043, 1083, 1100, 1138]),
        'boss8': (1195, [1210, 1260, 1300, 1380, 1422, 1448, 1470, 1519, 1540, 1564, 1585, 1600, 1640, 1655])}

def tga(shot, f):
    b = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(TAKES, shot, f'{f:05d}.tga'), '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(b, np.uint8).reshape(1080, 1920, 3).copy()

x0, y0, x1, y1 = RECT
for shot, (clean_f, frames) in SPEC.items():
    clean = tga(shot, clean_f)
    m = np.zeros((1080, 1920), np.uint8)
    for f in frames:
        d = np.abs(tga(shot, f).astype(np.int16) - clean.astype(np.int16)).max(axis=2)
        m[y0:y1, x0:x1] |= (d[y0:y1, x0:x1] > 18).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 400: keep[lab == i] = 1
    keep = cv2.dilate(keep, np.ones((13, 13), np.uint8))
    ys, xs = np.where(keep)
    cv2.imwrite(os.path.join(HERE, f'{shot}_clean.png'), clean)
    cv2.imwrite(os.path.join(HERE, f'{shot}_mask.png'), keep * 255)
    print(shot, 'clean', clean_f, 'mask bbox', xs.min(), ys.min(), xs.max(), ys.max(), 'px', int(keep.sum()))
