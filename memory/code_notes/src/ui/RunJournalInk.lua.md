---
name: code_notes/src/ui/RunJournalInk.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/RunJournalInk.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/RunJournalInk.lua`

Origem: `src/ui/RunJournalInk.lua` em `7dbdb60d` (12 de 24 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/RunJournalInk.lua
> PENA E PAPEL do Roteiro da jornada (components/RunJournalScreen.lua).
>
> O dono pediu um mapa "como se tivesse sido escrito à mão, apenas com tinta
> preta e, no máximo, um círculo vermelho, com uma folha envelhecida". Este
> módulo é o material: folha de pergaminho procedural (pixel art, borda
> rasgada, manchas) e um traço de pena de 1 px com imperfeição DETERMINÍSTICA
> (seed da run): nada de forma vetorial suave, que o dono chama de "cara de
> IA". Todo pixel de tinta sai por UM SpriteBatch (uma chamada de desenho por
> folha), então o mapa inteiro custa o que custa uma imagem.
>
> Paleta: SÓ papel (PARCHMENT_*), tinta (INK) e sangue (BLOOD, o círculo).
> A trava `test_journal_map` varre a captura e conta cor fora dessa família.

## L80-83 (em `Ink.px`, junto a `function Ink.line(x1, y1, x2, y2, color, alpha, seed, opts)`)

> ===== traço de pena ======================================================
> Reta com ondulação lenta (duas senoides por seed) e "pressão" ocasional
> (um pixel a mais no lado). opts: wobble (px, default 1.2), dash/gap
> (comprimentos; nil = contínua), weight (1|2).

## L117-118 (em `Ink.line`, junto a `function Ink.ring(cx, cy, r, color, alpha, seed, weight)`)

> Anel desenhado à mão: raio ondula, o traço passa do ponto de partida (a
> pena fecha o círculo com sobra), espessura varia.

## L148-151 (em `Ink.hatch`, junto a `local RAW = {`)

> ===== glifos (bitmaps 1-bit, desenhados a traço) =========================
> Cada tipo de parada tem um símbolo pequeno, do jeito que se desenha num
> mapa à mão: espadas cruzadas, caveira, fogueira, ponto de interrogação,
> saco de moedas, torre, castelo. '#' = tinta.

## L186 (em `boss`, junto a `boss = {`)

> usado só em endless (fora dele o castelo grande ocupa o lugar)

## L277-278 (em `Ink.hasGlyph`, junto a `function Ink.glyph(name, cx, cy, scale, color, alpha, seed, faded)`)

> Glifo centrado em (cx, cy), escala inteira. `faded` = alpha menor +
> pixels pulados (traço de lápis fraco).

## L291-292 (em `Ink.glyph`, junto a `function Ink.castle(x, y, scale, color, alpha, seed, faded)`)

> Castelo (canto superior esquerdo em x, y), escala inteira; `faded` =
> ainda não alcançado (traço fraco e falhado).

## L303-306 (em `Ink.castleSize`, junto a `local noiseImg`)

> ===== papel ==============================================================
> Textura base 256×256 (gerada uma vez, por pixel, determinística, tileável
> porque o ruído é hash de (x, y) com células que fecham no 256): três tons
> de pergaminho com pontilhado de fibra e zonas levemente mais escuras.

## L342-343 (em `paperNoise`, junto a `local function tornProfile(len, seed, side, amp)`)

> Perfil rasgado de uma borda: deslocamento por posição (0..amp), com
> pequenas mordidas. Determinístico por seed + lado.

## L359-360 (em `off`, junto a `function Ink.paper(w, h, seed)`)

> Folha w×h como Canvas (cacheada por tamanho+seed). Borda rasgada com aro
> escuro, manchas ditheradas. Desenhe com love.graphics.draw(canvas, x, y).

## L371-372 (em `Ink.paper`, junto a `love.graphics.setScissor()`)

> O scissor da zona rolável do chamador vale TAMBÉM dentro do canvas:
> sem limpar, as primeiras linhas da folha nasciam transparentes.

## L461-462 (em `Ink.clearPaperCache`, junto a `function Ink.drawSheet(canvas, x, y)`)

> Sombra da folha = a própria silhueta deslocada, em tinta: segue a borda
> rasgada de graça.

