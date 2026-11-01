import sys, cv2, numpy as np
real = cv2.imread(sys.argv[1]); ai = cv2.imread(sys.argv[2]); out = sys.argv[3]
H, W = real.shape[:2]; gh = round(W * 9 / 16); y0 = (H - gh) // 2
real169 = real[y0:y0 + gh]
small = cv2.resize(ai, (W, gh), interpolation=cv2.INTER_AREA)
ls = cv2.cvtColor(small, cv2.COLOR_BGR2LAB).astype(np.float32)
lr = cv2.cvtColor(real169, cv2.COLOR_BGR2LAB).astype(np.float32)
P = [0.5, 2, 10, 25, 50, 75, 90, 98, 99.5]
src = np.percentile(ls[..., 0], P); dst = np.percentile(lr[..., 0], P)
emis = ls[..., 0] > np.percentile(ls[..., 0], 97)
L = np.interp(ls[..., 0], src, dst)
L[emis] = np.maximum(L[emis], np.interp(ls[..., 0][emis], [src[-2], 255], [dst[-1], 255]))
ca = ls[..., 1] - 128; cb = ls[..., 2] - 128
chr_s = np.sqrt(ca ** 2 + cb ** 2); chr_r = np.sqrt((lr[..., 1] - 128) ** 2 + (lr[..., 2] - 128) ** 2)
k = float(sys.argv[4]) if len(sys.argv) > 4 else np.median(chr_r) / max(1e-6, np.median(chr_s))
kr = float(sys.argv[5]) if len(sys.argv) > 5 else k
kk = np.where(emis, max(k, 1.0), np.where(ca > 14, kr, k))
lab = np.stack([L, 128 + ca * kk, 128 + cb * kk], -1)
img = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR).astype(np.float32)
pal_src = np.concatenate([real.reshape(-1, 3), small[emis].reshape(-1, 3)]).astype(np.float32)
crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
_, _, pal = cv2.kmeans(pal_src, 64, None, crit, 3, cv2.KMEANS_PP_CENTERS)
d = ((img[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
q = pal[d.argmin(-1)].astype(np.uint8)
cv2.imwrite(out + '_ai_tratado2.png', cv2.resize(q, (1920, 1080), interpolation=cv2.INTER_NEAREST))
def st(im):
    g = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY).astype(np.float32); hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
    return dict(luma=round(float(g.mean()), 1), desvio=round(float(g.std()), 1), p2=float(np.percentile(g, 2)), p98=float(np.percentile(g, 98)), sat=round(float(hsv[..., 1].mean()), 1))
for n in ['_real', '_ai_cru', '_ai_tratado', '_ai_tratado2']:
    print(n, st(cv2.imread(out + n + '.png')))
