---
name: code_notes/tools/test_enemy_axis.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemy_axis.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemy_axis.lua`

Origem: `tools/test_enemy_axis.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemy_axis.lua
> HUD (intent, barra de vida, pills) centrado no CORPO de todo inimigo
> (Out/2026, dono: "o 29 e a barra estão à esquerda do corpo").
>
> love . test_one test_enemy_axis
>
> O bbox que o EnemyRenderer devolve (e que o EnemyHud usa como cx) era o
> centro do CANVAS do sprite — arma, cajado, capa ou margem de um lado só
> tiravam o HUD do corpo em até 36px a 1080p. Agora é o EIXO DO CORPO
> (EnemyRenderer.bodyAxis: automático, ou override `axisX` da pose).
> Para TODO diretório de inimigo:
> (a) o eixo cai dentro do conteúdo opaco do quadro 0
> (b) o cx do HUD fica a <= 3 px DA ARTE do eixo do corpo desenhado
> (c) o eixo do corpo cai no ponto pedido (âncora da cena) ± 1 px da arte

## L34-35 (em `ids`, junto a `local savedSettings = _G.gameSettings`)

> sem a deriva lateral dos flutuantes (balanço, não posição): é ela que
> reducedMotion tira, e é a POSIÇÃO que se mede aqui

## L64-65 (em `game`, junto a `local axis, src = EnemyRenderer.bodyAxis("winter_monarch")`)

> overrides declarados continuam valendo (o automático erra com escudo
> largo / quadrúpede de frente / orbe grande — conferido com régua)

