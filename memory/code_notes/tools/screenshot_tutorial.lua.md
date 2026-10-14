---
name: code_notes/tools/screenshot_tutorial.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_tutorial.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_tutorial.lua`

Origem: `tools/screenshot_tutorial.lua` em `7dbdb60d` (4 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/screenshot_tutorial.lua
> Captura o NARRADOR do tutorial (src/systems/Tutorial) sobre as telas da
> jornada — uma PNG por fala da conversa, num tamanho de janela FALSIFICADO.
>
> love . test_one screenshot_tutorial <cena>:<locale>:<WxH>
> cenas: rewards · shop · dice · rest · forge · endless · seals · class · mage
> ex.:   love . test_one screenshot_tutorial shop:de:1920x1080
>
> Saída (save dir): tut_<cena>_<fala>_<locale>_<W>x<H>.png
> A batalha (intro, chefe, elite...) captura pelo screenshot_enemy_scene
> (TUT_TIP=<conversa>:<fala>) e o evento pelo screenshot_event (TUT_TIP).
>
> `mage`: a 1ª batalha do MAGO pelo GameplayScene real, uma PNG por fala das
> conversas de orbe (Tutorial.MAGE_CONVERSATIONS), cada uma com o estado que a
> dispara (orbe do Conduíte, Descarga na mão, 2 orbes canalizados, carta de
> Evocar, fileira cheia, Foco). Saída em tools/preview_out/tutorial_mago/
> (gravada por io.open: fora do save dir, pra ficar junto das outras provas).

## L86-87 (em `drawScreen`, junto a `local US = require("src.systems.UnlockSystem")`)

> 1ª visita de verdade: perfil novo, sem o override de ferramenta
> (mago e ladino acorrentados)

## L146-148 (em `drawScreen`, junto a `function M.mageScene(loc, w, h)`)

> ===========================================================================
> MAGO: a batalha real (GameplayScene.draw) com o corvo por cima, fala a fala.
> ===========================================================================

## L251 (em `game.player.orbs`, junto a `setHand({ "mage_dualcast", "defense_001", "mage_fission" })`)

> 4. Evocar: Conjuração Dupla (e Fissão pra "todos")

