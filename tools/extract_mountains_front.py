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

TOL = {"fields": 16, "highlands": 36, "frost": 34, "abyss": 28, "dusk": 34}
# teto de elevação do cume-detalhe sobre o flood (px): biomas de céu limpo
# aguentam recuperação profunda (frost); céu cheio de nuvem assada/raio de
# sol precisa de teto baixo senão vira mesa/perna (abyss/dusk)
DCAP = {"fields": 32, "highlands": 64, "frost": 64, "abyss": 18, "dusk": 12}
# limiar de "textura" (busy) por bioma: neve lisa do frost tem contraste
# sutil — limiar 26 nao enxerga as faces ao lado da agulha do cume
BUSY_T = {"fields": 26, "highlands": 26, "frost": 12, "abyss": 26, "dusk": 26}
# CORRECOES MANUAIS (v7): segmentos de elevacao do cume onde NENHUMA
# heuristica separa (V entre picos: flood desce comendo a face de tras,
# que e lisa demais pro detector). Lidos do dump numerico do front +
# grid sobre a arte. Aplicados como top = min(top, lerp(p0, p1)).
RIDGE_RAISE = {
    "highlands": [
        ((104, 37), (116, 40)),
        ((143, 25), (163, 35)),
        ((165, 35), (178, 27)),
        ((209, 14), (233, 34)),
        ((276, 36), (292, 38)),
    ],
}
# rebaixamento manual: platô de sobre-oclusão em céu aberto (nuvem
# sumindo antes da encosta). top = max(top, lerp).
RIDGE_CLEAR = {
    "fields": [((58, 45), (88, 34))],
}
# rodapé chapado do strip (degradê pra preto) — o espelho in-engine
# (MIRROR_JUNK no WorldRoad.lua, MESMA tabela) cobre essas linhas no
# strip base; a front NÃO pode re-pintá-las por cima do reflexo
# (feedback: "linha preta em baixo"). Medido por variância de linha
# (scratchpad/measure_footer.py).
FOOT_JUNK = {"fields": 8, "highlands": 14, "abyss": 7, "frost": 0, "dusk": 12}
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
    comps = []
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
                comps.append({"px": comp, "mass": touches_bottom})

    # FUSÃO (feedback biomas 2/6): componente pairando ate 12px ACIMA da
    # massa (pico solto pela nevoa; sol furado pelas listras do horizonte)
    # funde na massa antes do preenchimento — vira silhueta solida junto
    GAP = 12
    def mass_tops():
        tops = [h] * w
        for c in comps:
            if c["mass"]:
                for x, y in c["px"]:
                    if y < tops[x]:
                        tops[x] = y
        return tops
    for _ in range(3):  # cascata: pico gruda, próximo gruda no pico...
        tops = mass_tops()
        changed = False
        for c in comps:
            if not c["mass"] and len(c["px"]) >= 40:
                # migalha <40px NAO funde: fill-down dela viraria pilar
                # fino que morde nuvem no ceu aberto
                for x, y in c["px"]:
                    if y <= tops[x] and tops[x] - y <= GAP:
                        c["mass"] = True
                        changed = True
                        break
        if not changed:
            break

    # CUME POR DETALHE (v6 — faces da MESMA COR do céu, ex. gelo do frost,
    # neve pêssego do fields): céu é LISO, montanha é TEXTURIZADA.
    # busy = contraste local 3×3 > 26; cume-detalhe = 1º y com busy
    # persistente na vertical (≥3 busy nas próximas 6 linhas — filtra as
    # listras horizontais de 1px do céu do dusk). Ridge final = o MAIS
    # ALTO entre flood e detalhe (over-occlusão em nuvem assada/raios de
    # sol = nuvem móvel passa atrás deles — aceitável).
    lum = [[(mp[x, y][0]*3 + mp[x, y][1]*6 + mp[x, y][2]) // 10
            for x in range(w)] for y in range(h)]
    busy = [[False]*w for _ in range(h)]
    for y in range(1, h-1):
        for x in range(1, w-1):
            lo = hi = lum[y][x]
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    v = lum[y+dy][x+dx]
                    if v < lo: lo = v
                    if v > hi: hi = v
            busy[y][x] = (hi - lo) > BUSY_T[bid]
    detail_top = [h]*w
    for x in range(w):
        for y in range(h - 6):
            if busy[y][x]:
                cnt = 0
                for k in range(1, 7):
                    if busy[y+k][x]:
                        cnt += 1
                if cnt >= 3:
                    detail_top[x] = y
                    break
    # mediana janela-5 nas colunas (mata coluna solta de ruído)
    dt2 = detail_top[:]
    for x in range(2, w-2):
        win = sorted(detail_top[x-2:x+3])
        dt2[x] = win[2]
    detail_top = dt2
    # CONSISTÊNCIA DE LINHA (v6.1): cume real é contínuo; pilar de raio de
    # sol/borda de nuvem assada é degrau isolado. detail_top[x] só vale se
    # ≥6 das 12 colunas vizinhas (±6) concordam em ±7px — senão rebaixa
    # pro nível dos vizinhos concordantes (2 passadas).
    for _ in range(2):
        dt3 = detail_top[:]
        for x in range(w):
            agree = 0
            neigh = []
            for k in range(-6, 7):
                if k == 0 or not (0 <= x+k < w):
                    continue
                neigh.append(detail_top[x+k])
                if abs(detail_top[x+k] - detail_top[x]) <= 7:
                    agree += 1
            if agree < 6 and neigh:
                dt3[x] = sorted(neigh)[len(neigh)//2]
        detail_top = dt3

    final = [[False]*w for _ in range(h)]
    tops = mass_tops()
    dcap = DCAP[bid]
    col_top = [h]*w
    for x in range(w):
        top = tops[x]
        # detalhe só ergue a silhueta ATÉ o teto do bioma — acima disso é
        # objeto flutuante (sol/nuvem assada), não face comida
        if detail_top[x] < top and top - detail_top[x] <= dcap:
            top = detail_top[x]
        col_top[x] = top
    # polylines manuais por bioma (V entre picos)
    for (x0, y0), (x1, y1) in RIDGE_RAISE.get(bid, []):
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            yy = round(y0 + (y1 - y0) * t)
            if yy < col_top[x]:
                col_top[x] = yy
    for (x0, y0), (x1, y1) in RIDGE_CLEAR.get(bid, []):
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            yy = round(y0 + (y1 - y0) * t)
            if yy > col_top[x]:
                col_top[x] = yy
    for x in range(w):
        for y in range(col_top[x], h):
            final[y][x] = True
    # v8 (feedback bioma 6): ILHA FLUTUANTE (sol do dusk) NAO oclui mais —
    # sol e astro distante, nuvem passa NA FRENTE dele. Componente solto
    # de qualquer tamanho e descartado do front.

    front = im.copy()
    fp = front.load()
    kept = 0
    cut = h - FOOT_JUNK.get(bid, 0)   # rodapé chapado: sempre transparente
    for y in range(h):
        for x in range(w):
            if final[y][x] and y < cut:
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
