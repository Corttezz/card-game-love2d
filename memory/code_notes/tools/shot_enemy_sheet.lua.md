---
name: code_notes/tools/shot_enemy_sheet.lua
description: Comentários com decisão/regra/histórico colhidos de tools/shot_enemy_sheet.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/shot_enemy_sheet.lua`

Origem: `tools/shot_enemy_sheet.lua` em `7dbdb60d` (5 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/shot_enemy_sheet.lua
> Prancha de TODOS os inimigos (assets/sprites/characters/enemies/*) na
> estrada do bioma deles, pelo caminho real (GameplayScene.draw), com o HUD
> (intent, vida, pills). Serve pra conferir de olho se o HUD está centrado
> no CORPO (Out/2026: "o 29 e a barra estão à esquerda do corpo").
>
> SHOT_SIZE=1920x1080 love . test_one shot_enemy_sheet [id1,id2,...]
>
> SHEET_MODE=feet: recorte 2x no PÉ de cada um (contato com o chão), com
> tiques magenta na linha de chão → enemy_feet_sheet.png.
> SHEET_MODE=death: o mesmo recorte no ÚLTIMO quadro da morte (cadáver)
> → enemy_death_sheet.png.
> Saída: enemy_sheet.png no save dir (recortes lado a lado, com o nome e
> uma marca amarela no eixo do corpo, abaixo do pé).

## L18 (em `M`, junto a `local KEYWORDS = {`)

> bioma de cada inimigo: ROSTER quando ele está lá; senão pelo nome

## L76-77 (em `ids`, junto a `local mode = os.getenv("SHEET_MODE")`)

> SHEET_MODE=feet: recorte AMPLIADO 2x no pé (contato com o chão), com
> tiques magenta na linha de chão pedida, fora do corpo

## L86-88 (em `ids`, junto a `local attackMode = mode == "attack" or mode == "attack_strong"`)

> strip: 6 instantes do idle por inimigo (uma linha cada) — prova de
> que fumaça/raio/gota/brilho pintados SE MEXEM na cena real
> attack: 6 instantes do GOLPE (preparo → apex → volta), na cena real

## L161-162 (em `run.currentNode`, junto a `local foot = EnemyRenderer.getLastFoot()`)

> marca: eixo do corpo (amarelo) abaixo do pé — o HUD (desenhado pelo
> jogo) tem que estar centrado nesta mesma coluna

