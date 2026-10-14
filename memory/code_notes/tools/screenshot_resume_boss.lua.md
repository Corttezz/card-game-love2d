---
name: code_notes/tools/screenshot_resume_boss.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_resume_boss.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_resume_boss.lua`

Origem: `tools/screenshot_resume_boss.lua` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/screenshot_resume_boss.lua
> Prova VISUAL do Continuar dentro da luta do chefe (bug do dono, Set/2026).
>
> Diferente de `screenshot_enemy_scene 2_boss`, que FORÇA o salão chamando
> `_debugForceBossEntered` (prova que a arte existe, não que o jogo escolhe
> a cena certa), este tool percorre o caminho do jogador:
>
> salva numa luta de chefe → Game novo → loadRun → resumeRun
> → setGame (zera o estado de módulo da cena, como o menu faz)
> → ResumeFlow.apply → GameplayScene.draw
>
> love . screenshot_resume_boss          → com a correção  (salão)
> love . screenshot_resume_boss antes    → sem a correção  (estrada: o bug)
>
> Saída: resume_boss_<modo>.png no save-dir.

## L59-60 (em `runA.currentNode`, junto a `GameplayScene.setGame(game)`)

> setGame é o que o menu faz ao trocar de Game: zera turnStage E
> bossEntered. É exatamente o estado em que o Continuar cai.

