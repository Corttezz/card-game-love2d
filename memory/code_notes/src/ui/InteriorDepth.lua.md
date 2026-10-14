---
name: code_notes/src/ui/InteriorDepth.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/InteriorDepth.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/InteriorDepth.lua`

Origem: `src/ui/InteriorDepth.lua` em `7dbdb60d` (2 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local SceneBackground = require("src.ui.SceneBackground")`)

> src/ui/InteriorDepth.lua
> CONTATO do chefe com o chão do salão (Out/2026, dono: "o tirano parece
> flutuar"). A sombra de contato do EnemyRenderer é uma elipse lisa e fraca;
> sobre pedra escura ela some e o pé fica sem peso. Aqui entra a oclusão de
> ambiente que jogo 2D usa pra vender contato: uma POÇA ESCURA em degraus,
> na grade da arte, achatada no plano do chão, densa logo sob os pés e se
> abrindo pra frente quando a luz vem do fundo da sala (sombra projetada
> no piso, não um disco).
>
> Só quem APOIA (pose grounded). Flutuante já tem a sombra deslocada do
> EnemyRenderer — poça sob quem paira contradiria a pose.
>
> Desenhado ANTES do chefe (o pé cobre a parte de cima da poça). A largura
> vem do bbox do quadro anterior (o chefe não muda de largura de um quadro
> pro outro); no primeiro quadro não há poça.

## L23-24 (em `InteriorDepth`, junto a `InteriorDepth.STRENGTH = {`)

> Força da poça por salão (piso claro pede menos, pedra escura pede a cor
> mais funda pra ainda separar). Cor = tinta quase preta da paleta grimório.

