# v4: camada frontal SOLIDA (feedback: "apenas a parte mais escura
# funcionou" — neve clara era marcada como ceu e virava buraco).
# 1) flood do ceu pelo topo (tol por bioma, mediana 3x3, salto 2)
# 2) front bruto = nao-ceu; componentes:
#    - massa CONECTADA AO CHAO (borda inferior): preenchida coluna a
#      coluna do 1o pixel da massa ate a base -> silhueta sem furos
#    - ilha grande (>=600px, ex. sol do dusk): mantida como esta
#    - fragmento solto pequeno: descartado (nuvem passa na frente, ok)
from PIL import Image, ImageFilter
from collections import deque

SRC = r"E:\dev\projects\card-game-love2d\assets\sprites\world"
OUT_PROOF = r"C:\Users\corte\AppData\Roaming\LOVE\card-game\ridge_proof.png"

TOL = {"fields": 26, "highlands": 36, "frost": 34, "abyss": 28, "dusk": 34}
BIOMES = ["fields", "highlands", "abyss", "frost", "dusk"]  # marsh: sem overlay (nevoa)

def extract(bid):
    im = Image.open(f"{SRC}\\{bid}_mountains.png").convert("RGBA")
    w, h = im.size
    med = im.convert("RGB").filter(ImageFilter.MedianFilter(3))
    mp = med.load()
    tol = TOL[bid]

    def dist(a, b):
        return ((a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2) ** 0.5

    sky = [[False]*w for _ in range(h)]
    q = deque()
    for x in range(w):
        sky[0][x] = True
        q.append((x, 0))
    while q:
        x, y = q.popleft()
        c = mp[x, y]
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(2,0),(-2,0),(0,2)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and not sky[ny][nx]:
                if dist(c, mp[nx, ny]) <= tol:
                    sky[ny][nx] = True
                    q.append((nx, ny))

    # abertura morfológica (v3): erode h±2/v±1 -> re-flood do topo ->
    # dilate restrito — mata canais finos de vazamento que desconectavam
    # picos da massa do chão (sem isso o pico central do frost caía fora)
    def flood_top(passable):
        seen2 = [[False]*w for _ in range(h)]
        q3 = deque()
        for x in range(w):
            if passable(x, 0):
                seen2[0][x] = True
                q3.append((x, 0))
        while q3:
            x, y = q3.popleft()
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and not seen2[ny][nx] and passable(nx, ny):
                    seen2[ny][nx] = True
                    q3.append((nx, ny))
        return seen2

    er = [[sky[y][x] and all(sky[y][max(0,min(w-1,x+k))] for k in (-2,-1,1,2))
           and all(sky[max(0,min(h-1,y+k))][x] for k in (-1,1))
           for x in range(w)] for y in range(h)]
    sky2 = flood_top(lambda x, y: er[y][x])
    for _ in range(2):
        nxt = [row[:] for row in sky2]
        for y in range(h):
            for x in range(w):
                if not sky2[y][x] and sky[y][x]:
                    if (x > 0 and sky2[y][x-1]) or (x < w-1 and sky2[y][x+1]):
                        nxt[y][x] = True
        sky2 = nxt

    raw = [[not sky2[y][x] for x in range(w)] for y in range(h)]

    # componentes do front bruto
    seen = [[False]*w for _ in range(h)]
    final = [[False]*w for _ in range(h)]
    for y0 in range(h):
        for x0 in range(w):
            if raw[y0][x0] and not seen[y0][x0]:
                comp, q2 = [], deque([(x0, y0)])
                seen[y0][x0] = True
                touches_bottom = False
                while q2:
                    x, y = q2.popleft()
                    comp.append((x, y))
                    if y >= h - 2:
                        touches_bottom = True
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = x+dx, y+dy
                        if 0 <= nx < w and 0 <= ny < h and raw[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q2.append((nx, ny))
                if touches_bottom:
                    # massa do chao: preenche do topo da massa ate a base
                    # por coluna (silhueta solida — neve incluida)
                    tops = {}
                    for x, y in comp:
                        if x not in tops or y < tops[x]:
                            tops[x] = y
                    for x, yt in tops.items():
                        for y in range(yt, h):
                            final[y][x] = True
                elif len(comp) >= 600:
                    for x, y in comp:
                        final[y][x] = True
                # senao: fragmento solto -> descartado

    front = im.copy()
    fp = front.load()
    kept = 0
    for y in range(h):
        for x in range(w):
            if final[y][x]:
                kept += 1
            else:
                r, g, b, _ = fp[x, y]
                fp[x, y] = (r, g, b, 0)
    front.save(f"{SRC}\\{bid}_mountains_front.png")
    print(f"{bid}: frente solida = {kept/(w*h):.1%} (tol {tol})")
    return front

fronts = [extract(b) for b in BIOMES]
scale = 3
w = max(f.size[0] for f in fronts) * scale
row_h = max(f.size[1] for f in fronts) * scale + 8
sheet = Image.new("RGB", (w, row_h * len(fronts)), (255, 0, 255))
for i, f in enumerate(fronts):
    big = f.resize((f.size[0]*scale, f.size[1]*scale), Image.NEAREST)
    sheet.paste(big, (0, i * row_h), big)
sheet.save(OUT_PROOF)
print("prova:", OUT_PROOF)
