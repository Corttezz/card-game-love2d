import sys, os, cv2, numpy as np
from PIL import Image, ImageDraw, ImageFont

V, t0, t1, out = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
zooms = sys.argv[5] if len(sys.argv) > 5 else ''
cap = cv2.VideoCapture(V)
fps = cap.get(cv2.CAP_PROP_FPS)
cap.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps)))
frames = []
for i in range(int(round((t1 - t0) * fps))):
    ok, f = cap.read()
    if not ok:
        break
    frames.append(f)
sift = cv2.SIFT_create()
bf = cv2.BFMatcher()
scale = [1.0]
prev = cv2.cvtColor(frames[0], cv2.COLOR_BGR2GRAY)
kp, dp = sift.detectAndCompute(prev, None)
for f in frames[1:]:
    g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
    k, d = sift.detectAndCompute(g, None)
    s = 1.0
    if d is not None and dp is not None and len(k) > 8 and len(kp) > 8:
        mm = [a for a, b in bf.knnMatch(d, dp, k=2) if a.distance < 0.7 * b.distance]
        if len(mm) >= 8:
            a = np.float32([k[x.queryIdx].pt for x in mm]); b = np.float32([kp[x.trainIdx].pt for x in mm])
            M, _ = cv2.estimateAffinePartial2D(a, b, method=cv2.RANSAC, ransacReprojThreshold=4)
            if M is not None:
                s = 1 / np.hypot(M[0, 0], M[1, 0])
    scale.append(s)
    kp, dp = k, d
cols = 12
tw = 240
th = int(tw * frames[0].shape[0] / frames[0].shape[1])
rows = (len(frames) + cols - 1) // cols
sheet = Image.new('RGB', (cols * tw, rows * (th + 18)), (10, 10, 10))
dr = ImageDraw.Draw(sheet)
for i, f in enumerate(frames):
    im = Image.fromarray(cv2.cvtColor(cv2.resize(f, (tw, th), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB))
    x, y = (i % cols) * tw, (i // cols) * (th + 18)
    sheet.paste(im, (x, y))
    c = (255, 80, 80) if abs(scale[i] - 1) > 0.03 else (220, 220, 220)
    dr.text((x + 3, y + th + 2), f"{t0 + i / fps:.3f}s esc {scale[i]:.3f}", fill=c)
sheet.save(out)
print(out, len(frames), 'quadros; mudancas de escala > 3% entre quadros vizinhos:',
      [(round(t0 + i / fps, 3), round(s, 3)) for i, s in enumerate(scale) if abs(s - 1) > 0.03])
