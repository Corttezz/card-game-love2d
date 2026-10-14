---
name: code_notes/tools/test_enemies.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemies.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemies.lua`

Origem: `tools/test_enemies.lua` em `7dbdb60d` (12 de 34 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemies.lua
> TRAVA do kit dos inimigos (Out/2026, src/data/enemies.lua).
>
> Auditoria de conteúdo: todo inimigo jogava igual (uma tabela de intents só),
> ninguém debuffava o jogador, o roster era um monstro por ato e o chefe era
> um saco de vida. Esta suíte trava o que a frente consertou:
> 1. todo sprite do roster tem kit; todo golpe tem nome nos 5 idiomas;
> 2. todo golpe de todo kit resolve pela fila de beats (e a vez volta);
> 3. o intent é CONGELADO — inclusive multi-golpe e Vulnerável;
> 4. Fraco/Frágil do jogador fazem a conta certa e duram o combinado;
> 5. o roster não repete o último inimigo (seed fixa);
> 6. cada chefe dispara a mecânica-assinatura;
> 7. a mesma seed reproduz o combate (intents + embaralhamento).
>
> love . test_one test_enemies

## L28-29 (em `LOCALES`, junto a `local function battleWith(id, moveId, hp, dmg)`)

> Monta uma batalha de run com o inimigo `id` (vida alta pra ninguém morrer
> no meio da asserção) e o golpe `moveId` anunciado.

## L60-62 (em `M.run`, junto a `local seenIds = {}`)

> ======================================================================
> 1. DADOS: roster -> kit -> golpes -> i18n -> sprite
> ======================================================================

## L81-82 (em `elites`, junto a `local foreign = {}`)

> REGRA DO DONO (Out/2026): só criatura DO BIOMA do ato. Emprestar sprite
> de outro ato fazia aparecer "monstros sem relação com o bioma".

## L95-96 (em `foreign`, junto a `local endlessOk = true`)

> Endless: o bioma do inimigo é o MESMO que a cena desenha (fórmula do
> GameplayScene: 4 + floor((andar - 25) / 8), embrulhado em 6).

## L157-159 (em `ids`, junto a `local broken = {}`)

> ======================================================================
> 2. TODO golpe de TODO kit resolve pela fila de beats
> ======================================================================

## L187-189 (em `broken`, junto a `do`)

> ======================================================================
> 3. INTENT CONGELADO (CLAUDE.md §6) — multi-golpe e Vulnerável
> ======================================================================

## L235-237 (em `broken`, junto a `do`)

> ======================================================================
> 4. FRACO / FRÁGIL / DoT NO JOGADOR
> ======================================================================

## L266 (em `broken`, junto a `local g = battleWith("cursed_scarecrow", "rusty_scythe", 500, 5)`)

> Integração: carta de ataque com o jogador Fraco causa 75%.

## L294-296 (em `card2`, junto a `do`)

> ======================================================================
> 5. ROSTER: sorteio seedado, sem repetir o último
> ======================================================================

## L336-338 (em `nodes`, junto a `do`)

> ======================================================================
> 6. MECÂNICAS DOS CHEFES
> ======================================================================

## L420-422 (em `ids`, junto a `do`)

> ======================================================================
> 7. A MESMA SEED REPRODUZ O COMBATE
> ======================================================================

