---
name: code_notes/src/ui/TvOsd.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/TvOsd.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/TvOsd.lua`

Origem: `src/ui/TvOsd.lua` em `7dbdb60d` (7 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/TvOsd.lua
> OSD do televisor (on-screen display) — o texto verde-fósforo que TVs
> antigas desenham POR CIMA do programa: canal, volume em bloquinhos,
> relógio, chuvisco de sintonia. Compartilhado por BootScene (sintonia),
> Menu (tag de canal) e SettingsMenu (barras de volume).
> Plano: docs/plan/menu-crt-v2.md. Regra herdada: legibilidade > efeito.

## L12-15 (em `TvOsd`, junto a `TvOsd.AMBER     = { 1.00, 0.72, 0.22 }`)

> Paleta do aparelho: FÓSFORO ÂMBAR (monitores de fósforo P3 reais —
> e âmbar é da família do dourado/sépia do jogo; o verde clássico brigava
> com os botões, feedback do dono Jul/2026). Exceção consciente à regra
> "cores só do Theme": esta é a cor DO TELEVISOR, centralizada aqui.

## L18 (em `TvOsd.AMBER_DIM`, junto a `TvOsd.GREEN     = TvOsd.AMBER`)

> aliases legados (evita quebra se algo ainda referenciar)

## L22-24 (em `TvOsd.AMBER_DIM`, junto a `local noiseFrames = nil`)

> ===== CHUVISCO (static de canal fora do ar) =====
> 4 frames de ruído 160×120 pré-gerados, ciclados a ~12fps, escalados
> nearest pra tela cheia (pixelões de TV). Barato: zero alocação por frame.

## L47-48 (em `TvOsd.staticNoise`, junto a `if not require("src.ui.CRTShader").isEnabled() then return end`)

> chuvisco é artefato do TUBO: com o CRT desligado em Configurações
> (Out/2026, níveis) não existe sinal pra chiar

## L65-67 (em `TvOsd.staticNoise`, junto a `function TvOsd.text(str, x, y, alpha, size)`)

> ===== TEXTO OSD =====
> Verde-fósforo com sombra dura + "ghost" (cópia deslocada, alpha baixo —
> o bleed do fósforo). size default 15.

## L91-93 (em `TvOsd.textWidth`, junto a `function TvOsd.segmentBar(x, y, value, opts)`)

> ===== BARRA DE SEGMENTOS (volume de TV velha) =====
> N bloquinhos: preenchidos verdes, vazios só delineados.
> opts: { segments=10, segW=14, segH=16, gap=3, alpha=1 }

