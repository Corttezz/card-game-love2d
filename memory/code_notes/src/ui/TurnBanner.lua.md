---
name: code_notes/src/ui/TurnBanner.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/TurnBanner.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/TurnBanner.lua`

Origem: `src/ui/TurnBanner.lua` em `7dbdb60d` (12 de 26 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/TurnBanner.lua
> Banner de TURNO (clareza do ritmo): faixa full-width que desliza no
> terço superior anunciando "SEU TURNO" / "TURNO DO INIMIGO" a cada
> virada. v2.1 (feedback Jul/2026): a ESTRUTURA v1 (faixa + slide) era a
> certa — a tentativa de placa central "ficou pior". O que muda da v1 é
> só a PALETA: sai o verde/vermelho neon, entra a base de tinta sépia com
> acento ouro envelhecido (seu turno) / sangue (inimigo) — as cores do
> grimório (pills do fork, headers de carta).
>
> Uso: TurnBanner.show("player"|"enemy") · update(dt) · draw()

## L21-23 (em `canvasCache`, junto a `function TurnBanner.clearCache() canvasCache = {} end`)

> Resize/fullscreen: love.window.setMode apaga o CONTEÚDO de todo Canvas (o
> objeto sobrevive) — voltar a uma largura já vista mostrava faixa vazia.
> Chamado no love.resize junto do CardFrame.clearCache.

## L40-42 (em `active`, junto a `TurnBanner._ensureCanvas(active.kind)`)

> pré-renderiza o canvas AQUI (update, fora do frame de draw): criar
> canvas no meio do love.draw — dentro da cena CRT / com scissor do
> WorldRoad vivo — corrompia o conteúdo (artefatos no topo da tela)

## L57-58 (em `TurnBanner.isActive`, junto a `function TurnBanner.bandRect()`)

> Retângulo da faixa (y, altura). Fonte ÚNICA da geometria: o ComboBanner
> se ancora NISSO pra nunca desenhar por cima do banner de turno.

## L63-64 (em `TurnBanner.bandRect`, junto a `local function bandCanvas(kind, sw)`)

> Renderiza a faixa COMPLETA (fundo + linhas + losangos + texto) num canvas
> full-width — o dissolve queima o conjunto como uma coisa só (igual carta).

## L66-67 (em `bandCanvas`, junto a `local key = kind .. sw .. "|" .. tostring(I18n.getLocale and I18n.getLocale())`)

> Idioma NA CHAVE: a faixa tem o texto "SEU TURNO" assado no canvas —
> sem o locale, trocar de idioma deixava a faixa no idioma antigo.

## L70-71 (em `bandCanvas`, junto a `local sx0, sy0, sw0, sh0 = love.graphics.getScissor()`)

> scissor herdado do frame recortaria o clear/draw do canvas (o glClear
> RESPEITA scissor) — desliga durante o render off-screen

## L116 (em `TurnBanner._ensureCanvas`, junto a `local BURN = {`)

> Chamas do dissolve por dono do turno (mesma linguagem das cartas)

## L127-130 (em `TurnBanner.draw`, junto a `local dissolve`)

> v2.2 (feedback: "deslizar com o quadrado faltando é estranho — usa a
> animação das cartas"): a faixa fica PARADA e MATERIALIZA/DISSOLVE com
> o shader de queima das cartas (Balatro). Envelope:
> 0.00–0.30 materialize (dissolve 1→0) · hold · 0.75–1.05 dissolve 0→1

## L142-143 (em `TurnBanner.draw`, junto a `if not DissolveShader.isAvailable() and not TurnBanner._shaderTried then`)

> lazy-load do shader (contextos que não passam pelo love.load completo
> — ferramentas de screenshot — caíam no fallback de fade silencioso)

## L152-153 (em `TurnBanner.draw`, junto a `local ns = { 5.5 * sw / BAND_H, 5.5 }`)

> noise anisotrópico: célula ~quadrada em pixels na faixa full-width
> (sem isso a queima estica em "faixas fantasmas")

## L159-160 (em `ns`, junto a `local gx0, gy0, gw0, gh0 = love.graphics.getScissor()`)

> scissor-guard: por construção NADA pinta fora do retângulo da faixa
> (blindagem contra o artefato de topo visto na validação)

