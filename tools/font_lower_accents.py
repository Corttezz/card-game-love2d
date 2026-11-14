"""Afasta do corpo da letra o circunflexo e o til das MINUSCULAS em assets/fonts/pixel.ttf.

Por que existe (14/11/2026): na celula 8x8 da fonte o acento da minuscula fica nas
linhas 6..7, colado no topo do corpo (linha 5). O circunflexo grosso ("..###" /
".##.##") fecha com a barra de cima do "a" e le como anel: "Pântano" saia "Påntano"
no titulo da cena do ato 5. O til fazia o mesmo borrao.

Aqui cada glifo e refeito como o MESMO corpo (linhas 0..5) + uma linha vazia (6) +
o acento nas linhas 7..8. O circunflexo vira um ^ fino de 1 px, no traco do agudo
e do grave da propria fonte; o til mantem o desenho e so sobe uma linha.
As metricas nao mudam (como no tools/font_latin_caps.py, o acento passa do
ascender e a LOVE desenha o glifo inteiro).

Uso: python tools/font_lower_accents.py   (idempotente: glifo ja refeito e pulado)
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables import ttProgram

sys.path.insert(0, "tools")
from font_latin_caps import PATH, pixels, add_runs  # noqa: E402

CIRCUMFLEX = [(3, 8), (2, 7), (4, 7)]          # ^ fino, centrado no corpo (colunas 0..6)
GLYPHS = {ch: "circ" for ch in "âêîôû"}
GLYPHS.update({ch: "tilde" for ch in "ãõñ"})


def main():
    f = TTFont(PATH)
    cmap, gs = f.getBestCmap(), f.getGlyphSet()
    glyf, hmtx = f["glyf"], f["hmtx"]
    built = {}
    for ch, kind in GLYPHS.items():
        g = cmap[ord(ch)]
        if pixels(gs, g, [8]):                  # ja tem acento na linha 8: ja refeito
            continue
        body = pixels(gs, g, range(0, 6))
        if kind == "circ":
            acc = CIRCUMFLEX
        else:
            acc = [(x, y + 1) for x, y in pixels(gs, g, range(6, 8))]
        pen = TTGlyphPen(None)
        add_runs(pen, body + acc)
        built[g] = pen.glyph()
    for g, gl in built.items():
        gl.program = ttProgram.Program()
        gl.program.fromBytecode(b"")
        glyf[g] = gl
        gl.recalcBounds(glyf)
        hmtx[g] = (hmtx[g][0], gl.xMin)
    if built:
        f.save(PATH)
    print("ok: %d glifos refeitos (%s)" % (len(built), "".join(GLYPHS)))


if __name__ == "__main__":
    main()
