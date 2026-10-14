---
name: code_notes/src/ui/ClassEmblem.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ClassEmblem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ClassEmblem.lua`

Origem: `src/ui/ClassEmblem.lua` em `7dbdb60d` (8 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local RadialGlow = require("src.ui.RadialGlow")`)

> src/ui/ClassEmblem.lua
> EMBLEMA da classe (Out/2026): o objeto icônico que representa cada
> classe no lugar do herói chibi — sem personagem visível (o dono achou que
> o boneco "abre margem para críticas"). Arte PixelLab 128×128 em
> assets/sprites/emblems/<classe>.png; o idle é PROCEDURAL, aqui:
> warrior — espada cravada no escudo: brilho que corre pela lâmina
> mage    — orbe arcano: flutua, pulsa e solta faíscas em órbita
> rogue   — adaga: gotas de veneno e sangue pingando da ponta + fio
> frio correndo pela lâmina
> Bloqueado = silhueta escura + correntes com cadeado (locked_chains.png),
> sem animação nenhuma (a classe "dorme").
>
> Uso:
> ClassEmblem.update(dt)
> ClassEmblem.draw("mage", cx, cy, boxH, { hover = 0..1, locked = bool, flash = 0..1,
> tint = {r,g,b} })   -- tint: escurece (escolha pequena)
> cx/cy = centro da caixa reservada ao emblema; boxH = altura da caixa.
> O desenho NUNCA sai da caixa (escala quantizada em 1/4, pra a arte pixel
> não deformar).

## L26 (em `ClassEmblem`, junto a `ClassEmblem.CANVAS = 128`)

> tamanho de todos os PNGs de emblema

## L35-36 (em `states`, junto a `local function measure(data)`)

> Mede o conteúdo real do PNG (bbox opaca) e a PONTA (pixel opaco mais
> baixo) — a gota da adaga nasce ali, não num offset chutado.

## L83-85 (em `ClassEmblem.get`, junto a `local engravings = {}`)

> GRAVURA (seleção v4): o emblema redesenhado como traço de tinta — só o
> contorno e as sombras do sprite, meio-tom em dither 2×2. É a "prancha" da
> folha do grimório; a silhueta chapada lia como mancha.

## L123-125 (em `alphaAt`, junto a `local SHADER_SRC = [[`)

> Shader de luz aditiva: acende só os pixels CLAROS do sprite (metal,
> núcleo do orbe), opcionalmente numa faixa diagonal (brilho de lâmina).
> A faixa é DURA (step), não gradiente — é pixel art, não vetor.

## L166-172 (em `s`, junto a `ClassEmblem.EMBLEM_REF = { warrior = 124, rogue = 124, mage = 96 }`)

> Escala em meios-pixels que cabe na caixa (pelo conteúdo real).
> Os emblemas escalam por uma ALTURA DE REFERÊNCIA, não pelo conteúdo de
> cada um: escalar pelo conteúdo fazia o orbe (74px de altura) ficar 1.6×
> maior que a espada — três objetos, três tamanhos de pixel. O orbe ganha
> uma referência menor (fica ~25% maior que o "uniforme") pra não sumir
> ao lado de objetos altos. Escala em passos de 1/4 (1/2 deixava a banda
> meio vazia em 720p; 1/4 de pixel não se nota na arte 128px).

## L305-306 (em `ClassEmblem.draw`, junto a `local period = (id == "rogue") and 2.6 or 3.4`)

> brilho correndo pela lâmina: 1 passada a cada ~3.4s (a adaga,
> mais curta e fria, a cada ~2.6s — o "fio" que cintila)

## L350-351 (em `ClassEmblem.draw`, junto a `for _, d in ipairs(st.drops) do`)

> gota = 2×3 px do sprite com contorno ink (lê sobre a lâmina
> ensanguentada e sobre o fundo escuro do salão)

