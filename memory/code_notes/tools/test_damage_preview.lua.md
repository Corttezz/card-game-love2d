---
name: code_notes/tools/test_damage_preview.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_damage_preview.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_damage_preview.lua`

Origem: `tools/test_damage_preview.lua` em `7dbdb60d` (2 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local TK = require("tools.testkit")`)

> tools/test_damage_preview.lua
> PREVIA == RESULTADO (Out/2026). A previa de dano (src/systems/DamagePreview)
> e o que o jogador le antes de jogar; se ela errar, ensina a conta errada —
> pior que nao ter previa. Este teste joga centenas de levas ALEATORIAS pelo
> combate de verdade (selectCard -> playSelectedCards -> fila de beats) e
> confere carta a carta: vida que o inimigo perdeu, Bloqueio dele consumido e
> Bloqueio que o jogador ganhou batem com a previa.
>
> Cobre: Forca/Destreza (e scaling em dobro), multi-golpe, combos, coringas
> (maior multiplicador vence, planos, Eco), edicoes e selos, Fraco/Fragil,
> Vulneravel (ja ativo e aplicado NO MEIO da leva), armadura do inimigo,
> orbes (canalizar com fileira cheia, evocar, evocar todos, Foco), inimigo
> morrendo no meio da leva, Impeto do guerreiro.
> love . test_one test_damage_preview

## L160-164 (em `ids`, junto a `do`)

> ===== PREVIA SEM EFEITO COLATERAL (bug do dono, Out/2026) =====
> Calice do Sabio (heal_multiplier 1.5) soltava "×1.5 PV" do nada no
> hover: a previa chamava applyHealMultiplier SEM sink e o proc disparava
> direto no JokerProcFx, todo quadro. A previa roda N vezes = 0 procs;
> jogar a carta de verdade = exatamente 1.

