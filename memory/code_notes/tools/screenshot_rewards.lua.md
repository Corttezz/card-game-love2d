---
name: code_notes/tools/screenshot_rewards.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_rewards.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_rewards.lua`

Origem: `tools/screenshot_rewards.lua` em `7dbdb60d` (4 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/screenshot_rewards.lua
> Valida a reforma do modo REWARDS da CardRewardScreen (Jul/2026): véu sobre
> o mundo (sem interior de loja), pills fora das cartas, Seguir com texto
> inteiro, botões Pegar/X largos, sem ouro no title bar.
> love . screenshot_rewards → rewards_idle + rewards_selected + 3 de RESIZE
>
> A tortura existe porque NASCER grande != CRESCER: capturar a tela já criada
> no tamanho final não exercita o caminho "layout calculado num tamanho, janela
> muda, layout reaproveitado" (memory/ui_layout_invariants.md).

## L33-35 (em `M.run`, junto a `screen.lastScreenWidth = love.graphics.getWidth()`)

> REPRO fiel ao jogo real: pré-seta lastScreenWidth/Height pra NÃO cair
> no branch de resize do update() (que recria as instâncias e mascarava
> o bug das cartas invisíveis).

## L49-52 (em `simulate`, junto a `love.graphics.clear(0, 0, 0, 1)`)

> CRÍTICO (lição do bug y+=entryOy): o DRAW muta estado das cartas
> (Card:draw grava self.x/y). Sem desenhar por frame, o simulador
> NÃO reproduz feedback loops de draw — foi assim que o bug das
> cartas fora da tela passou batido duas vezes.

## L98-102 (em `capture`, junto a `local steps = {`)

> ===================== TORTURA DE RESIZE =====================
> Roda SEMPRE (main.lua chama este tool sem argumentos). Mantém a carta
> SELECIONADA — é o estado com mais geometria derivada (botões Pegar/X
> ancorados na carta). NASCER grande != CRESCER: só capturar a tela já
> criada no tamanho final não exercita este caminho.

