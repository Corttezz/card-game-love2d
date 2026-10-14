---
name: code_notes/src/ui/HudManager.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HudManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HudManager.lua`

Origem: `src/ui/HudManager.lua` em `7dbdb60d` (5 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local HudPlayerPanel = require("src.ui.HudPlayerPanel")`)

> src/ui/HudManager.lua
> Gerenciador principal para todos os painéis de HUD

## L15-16 (em `HudManager:new`, junto a `instance.playerPanel = HudPlayerPanel:new()`)

> Painéis ativos. Enemy panel foi aposentado — HP/intent agora ficam
> ancorados no sprite do inimigo via EnemyHud (chamado em main.lua).

## L62-64 (em `HudManager:draw`, junto a `self.playerBuffPills:draw(`)

> Pills de buff ficam logo acima do player panel (row horizontal).
> Passa coords do panel pra alinhamento e o `game` pros estados
> DERIVADOS de coringas ativos (reflexo, regen, sangria, retenção).

## L72-73 (em `HudManager:draw`, junto a `OrbRow.draw(game, self.playerPanel.x, self.playerPanel.y)`)

> Orbes acima das buff pills (a bateria do mago SEMPRE visível;
> slots vazios ensinam o cap de 3 — padrão StS/Defect).

## L77-81 (em `HudManager:draw`, junto a `local Tutorial = require("src.systems.Tutorial")`)

> Âncoras das dicas do tutorial (src/systems/Tutorial): o painel do
> herói (Bloqueio) e o orbe de mana — mesma geometria que acabou de
> ser desenhada. A fileira de orbes ("orbs"/"orb_next") e a pill de
> Foco ("buff_focus") são reportadas por quem as desenha (OrbRow,
> PlayerBuffPills), célula a célula.

