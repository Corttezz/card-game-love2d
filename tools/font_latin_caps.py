"""Redesenha as MAIUSCULAS acentuadas do Latin-1 em assets/fonts/pixel.ttf.

Por que existe (Out/2026): a Press Start 2P original encolhe a letra para
caber o acento dentro da celula 8x8 -- "É" vira um "e" com acento, e um titulo
como CRÉDITOS saia "CRéDITOS". Aqui cada maiuscula acentuada e refeita como
LETRA CHEIA (a propria maiuscula da fonte, linhas 1..7) + o acento da
minuscula correspondente deslocado 2 pixels para cima (linhas 8..9), no mesmo
grid de pixels. O Ç ganha a cedilha abaixo da linha de base.

As metricas (hhea/OS2) NAO mudam: a altura de linha continua a mesma e o
acento sobe acima do ascender, como nas fontes pixel de 8px que tem acento em
caixa alta. A LOVE desenha o glifo inteiro (nao recorta no ascender).

Licenca: OFL 1.1 com Reserved Font Name "Press Start 2P" -- versao modificada
NAO pode usar esse nome, entao a familia e renomeada para "Grimoire Pixel".
O aviso de copyright original e mantido (dist/THIRD_PARTY_NOTICES.txt).

Uso: python tools/font_latin_caps.py   (idempotente: recusa rodar duas vezes)
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables import ttProgram
from fontTools.pens.pointInsidePen import PointInsidePen

PATH = "assets/fonts/pixel.ttf"
PX = 125            # 1000 upm / 8 pixels
NEW_FAMILY = "Grimoire Pixel"
NEW_PS = "GrimoirePixel-Regular"

# maiuscula -> (letra base, minuscula de onde vem o acento, deslocamento em px)
CAPS = {}
for up, base in (("ÀÁÂÃÄÅ", "A"), ("ÈÉÊË", "E"), ("ÌÍÎÏ", "I"), ("Ñ", "N"),
                 ("ÒÓÔÕÖ", "O"), ("ÙÚÛÜ", "U"), ("Ý", "Y")):
    for ch in up:
        CAPS[ch] = (base, ch.lower(), +2)


def pixels(gs, name, rows):
    """Pixels acesos do glifo nas linhas pedidas (amostra no centro do pixel)."""
    out = []
    for py in rows:
        for px in range(8):
            pen = PointInsidePen(gs, (px * PX + PX // 2, py * PX + PX // 2))
            gs[name].draw(pen)
            if pen.getResult():
                out.append((px, py))
    return out


def add_runs(pen, pts):
    """Desenha os pixels como retangulos (uma corrida horizontal por linha),
    sentido horario como os contornos externos do TrueType."""
    rows = {}
    for px, py in pts:
        rows.setdefault(py, []).append(px)
    for py, xs in rows.items():
        xs.sort()
        start = prev = xs[0]
        for x in xs[1:] + [None]:
            if x is not None and x == prev + 1:
                prev = x
                continue
            x0, x1, y0, y1 = start * PX, (prev + 1) * PX, py * PX, (py + 1) * PX
            pen.moveTo((x0, y0)); pen.lineTo((x0, y1))
            pen.lineTo((x1, y1)); pen.lineTo((x1, y0)); pen.closePath()
            if x is not None:
                start = prev = x


def main():
    f = TTFont(PATH)
    name = f["name"]
    if name.getDebugName(1) == NEW_FAMILY:
        sys.exit("pixel.ttf ja foi modificada (familia %s) -- nada a fazer" % NEW_FAMILY)
    cmap = f.getBestCmap()
    gs = f.getGlyphSet()
    glyf, hmtx = f["glyf"], f["hmtx"]

    jobs = dict(CAPS)
    jobs["Ç"] = ("C", "ç", -1)

    built = {}
    for ch, (base, src, shift) in jobs.items():
        gname, bname, sname = cmap[ord(ch)], cmap[ord(base)], cmap[ord(src)]
        if shift > 0:
            # acento = tudo acima do corpo da minuscula (corpo vai ate a linha 5)
            body_top = max(py for _, py in pixels(gs, sname, range(1, 6)))
            acc = pixels(gs, sname, range(body_top + 1, 9))
        else:
            acc = pixels(gs, sname, range(0, 2))   # cedilha (linhas 0..1 do ç)
        acc = [(x, y + shift) for x, y in acc]
        pen = TTGlyphPen(None)
        gs[bname].draw(pen)
        add_runs(pen, acc)
        built[gname] = (pen.glyph(), bname)

    for gname, (g, bname) in built.items():
        g.program = ttProgram.Program()
        g.program.fromBytecode(b"")
        glyf[gname] = g
        g.recalcBounds(glyf)
        hmtx[gname] = (hmtx[bname][0], g.xMin)

    for rec in name.names:
        nid = rec.nameID
        if nid == 1:
            rec.string = NEW_FAMILY
        elif nid == 3:
            rec.string = "3.000;GRIM;" + NEW_PS
        elif nid == 4:
            rec.string = NEW_FAMILY + " Regular"
        elif nid == 5:
            rec.string = "Version 3.000; modified Latin-1 capitals (Grimoire)"
        elif nid == 6:
            rec.string = NEW_PS
    f.save(PATH)
    print("ok: %d glifos refeitos, familia -> %s" % (len(built), NEW_FAMILY))


if __name__ == "__main__":
    main()
