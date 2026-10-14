---
name: code_notes/src/data/run_modifiers.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/run_modifiers.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/run_modifiers.lua`

Origem: `src/data/run_modifiers.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local M = {}`)

> src/data/run_modifiers.lua
> DADOS dos modificadores de corrida (Out/2026): os SELOS DO GRIMÓRIO
> (dificuldade escolhida na seleção de classe, estilo Ascensão) e as
> MALDIÇÕES do endless (mutadores que o jogador escolhe 1-de-2 a cada ciclo).
> O COMPORTAMENTO mora em src/systems/RunModifiers.lua; o desenho e a
> pesquisa (Balatro/StS/Monster Train/Hades) em memory/endless_and_seals.md.
>
> Cada regra é um par (campo, valor) que RunModifiers soma ou multiplica:
> eliteWeight  ×  peso de elite no mapa
> restHeal     ×  cura da fogueira
> actHeal      ×  cura entre atos / entre ciclos do endless
> price        ×  todo preço da loja (cartas, relíquias, pacotes, reroll)
> hpNormal     ×  vida de inimigo comum e elite
> hpBoss       ×  vida de chefe e mini-chefe
> dmgElite     ×  dano de elite
> dmgAll       ×  dano de todo inimigo
> hpAll        ×  vida de todo inimigo
> startGold    =  ouro inicial (substitui os $10)
> victoryGold  +  ouro da vitória por batalha (negativo = menos)
> rewardCards  +  cartas na recompensa pós-batalha (negativo = menos)
> enemyBlock   +  Bloqueio inicial do inimigo, em fração da vida máxima
> Textos: i18n `seals.<id>.name/desc` e `endless_curses.<id>.name/desc`.

## L26-28 (em `M`, junto a `M.SEALS = {`)

> SELOS: CUMULATIVOS (o selo 5 traz as regras de 1 a 5). Um por nível, na
> ordem em que entram. Cada um mexe num sistema diferente de propósito: o
> jogador sente cada degrau, em vez de "+5% de vida" dez vezes.

## L42-45 (em `M.SEALS`, junto a `M.CURSES = {`)

> MALDIÇÕES do endless: EMPILHÁVEIS (a mesma pode ser escolhida de novo e
> conta por acúmulo). `score` = bônus de pontuação por acúmulo — é o que paga
> o risco (Balatro paga a aposta maior com a própria pontuação). `max` =
> teto de acúmulos (some do sorteio ao bater).

