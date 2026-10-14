---
name: code_notes/src/data/enemy_emissives.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/enemy_emissives.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/enemy_emissives.lua`

Origem: `src/data/enemy_emissives.lua` em `7dbdb60d` (15 de 166 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `return {`)

> src/data/enemy_emissives.lua
> EMISSIVOS POR MONSTRO (LightEngine) — dados puros, sem lógica.
>
> Cada inimigo lista âncoras de luz sobre pixels que a ARTE pintou como
> emissivos (olhos, chamas, cristais, runas, orbes). O EnemyRenderer emite
> uma micro-luz sutil por âncora (pulso lento, some na morte).
>
> Campos por âncora:
> xr, yr      posição relativa ao sprite (fração da largura/altura, y do topo)
> r           raio da luz em FRAÇÃO DA ALTURA do sprite (0.05 olho, ~0.10 orbe)
> color       {r,g,b} — cor do pixel emissivo (média do cluster)
> intensity   opcional (default 0.35) — SUTIL é a regra; 0.5 só pra núcleos
>
> PIPELINE PADRÃO (novo monstro): rode
> python3 tools/extract_enemy_emissives.py <enemy_id>
> revise a folha anotada (tools/preview_out/enemy_emissives_sheet.png) —
> o detector confunde DOURADO/PALHA com emissivo — e adicione a entrada
> aqui à mão. Regra: só ganha luz o que BRILHA na arte; skull de osso com
> órbita escura NÃO ganha olho de luz. Ver memory/lighting_engine.md.

## L30-31 (em `harvest_reaper`, junto a `{ xr = 0.445, yr = 0.170, r = 0.042, color = { 1.00, 0.55, 0.15 },`)

> REGRA (Jul/2026): todo monstro tem OLHOS emitindo na cor deles —
> órbitas escuras de caveira ganham brasa (posição medida no osso)

## L48-49 (em `grave_slime`, junto a `{ xr = 0.50, yr = 0.26, r = 0.060, color = { 0.60, 0.95, 0.40 },`)

> a caveira tem UMA órbita grande — luz única centrada nela
> (dois olhos criavam brilho nas bordas do crânio, lia estranho)

## L69 (em `moon_gargoyle`, junto a `intensity = 0.50 },`)

> olho esq (medido)

## L71 (em `moon_gargoyle`, junto a `intensity = 0.50 },`)

> olho dir (medido)

## L131-132 (em `abyss_wraith`, junto a `{ xr = 0.461, yr = 0.250, r = 0.028, color = { 1.00, 0.20, 0.15 },`)

> dois olhos MEDIDOS (1px cada); raio pequeno — raio 0.04 tingia
> a caveira branca inteira de rosa ("lugar estranho")

## L142 (em `frost_wight`, junto a `intensity = 0.45 },`)

> olho esq (medido)

## L166-167 (em `bog_ghoul`, junto a `{ xr = 0.410, yr = 0.245, r = 0.045, color = { 0.50, 0.95, 0.55 },`)

> intensidade acima do padrão: verde-sobre-verde some no ambiente
> do marsh (revisão visual Jul/2026)

## L169 (em `bog_ghoul`, junto a `intensity = 0.55 },`)

> olho esq (medido)

## L171 (em `bog_ghoul`, junto a `intensity = 0.55 },`)

> olho dir (medido)

## L193 (em `dusk_shade`, junto a `intensity = 0.50 },`)

> olho esq (medido)

## L216 (em `eclipse_queen`, junto a `intensity = 0.30 },`)

> gema do peito (medida)

## L219-221 (em `eclipse_queen`, junto a `hollow_farmer = {`)

> LEVA NOVA (Out/2026) — 4 por ato (tools/pixellab_new_enemies.py).
> Olhos medidos por scan de pixel no south.png (= idle quadro 0).
> Ato 1 · campos ---------------------------------------------------

## L316 (em `frost_troll`, junto a `{ xr = 0.603, yr = 0.307, r = 0.035, color = { 0.70, 0.90, 1.00 } },  -- olho esq`)

> órbitas fundas sob a sobrancelha: brilho gelado (regra dos olhos)

## L354-355 (em `leech_horror`, junto a `{ xr = 0.479, yr = 0.224, r = 0.050, color = { 0.85, 0.20, 0.15 },`)

> sem olhos na arte: brasa vermelha FUNDA na goela da ventosa
> central faz o papel de "olho" (regra dos olhos, adaptada)

