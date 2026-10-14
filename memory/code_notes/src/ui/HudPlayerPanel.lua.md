---
name: code_notes/src/ui/HudPlayerPanel.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HudPlayerPanel.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HudPlayerPanel.lua`

Origem: `src/ui/HudPlayerPanel.lua` em `7dbdb60d` (12 de 38 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/HudPlayerPanel.lua
> Painel minimal estilo STS/Balatro: HP grande + barra fina + badge de armor.
> Sem gradientes de 20 passos, sem glass overlay, sem 3 layers de glow.
> Paleta sepia/pergaminho consistente com o resto do jogo (Palette.lua).

## L41 (em `HudPlayerPanel:update`, junto a `if player then`)

> Ease HP/armor pra number ticker feedback (Balatro-style)

## L62 (em `HudPlayerPanel:draw`, junto a `if self.lastHp and player.health < self.lastHp then`)

> (chip da passiva é desenhado no fim deste método — _drawPassiveChip)

## L107-109 (em `HudPlayerPanel:draw`, junto a `local hp = player.health or 0`)

> ===== HP: número grande + barra =====
> Display usa valor eased (disp.health) pra number "conta" suave quando
> dano chega. Gameplay pipeline usa player.health real.

## L116 (em `HudPlayerPanel:draw`, junto a `local hpFont = FontManager.getResponsiveFont(0.035, 24)`)

> Número HP grande (estilo Balatro)

## L144 (em `HudPlayerPanel:draw`, junto a `love.graphics.setColor(1, 1, 1, 0.25)`)

> Highlight sutil no topo da barra

## L151-154 (em `HudPlayerPanel:draw`, junto a `local armor = math.floor((self.disp.armor or player.armor or 0) + 0.001)`)

> ===== ARMOR BADGE (só aparece quando > 0) =====
> Usa o shield PNG custom gerado via PixelLab (assets/sprites/icons/armor_shield.png).
> Número de armor fica centralizado no shield, com outline preto pra legibilidade.
> Display eased pra number ticker suave quando armor ganha/perde.

## L161-166 (em `HudPlayerPanel:draw`, junto a `local capMax = player.maxArmor or 0`)

> CAP DE BLOQUEIO (30/40/50 por ato). Era invisível: o painel mostrava
> só o valor atual, então o jogador não tinha como saber que a próxima
> defesa seria desperdiçada — decisão tomada às cegas todo turno no
> late game. Aparece só quando PASSA A IMPORTAR (>= 70% do cap);
> mostrar "/50" o tempo todo seria ruído nos turnos em que o teto está
> longe.

## L171-172 (em `HudPlayerPanel:draw`, junto a `local pulse = 0.75 + math.sin(self.animTime * 3) * 0.25`)

> Halo pulsante atrás (feedback de "blocking"). No cap ele vira âmbar:
> a cor muda ANTES de o jogador ler o número.

## L184-185 (em `HudPlayerPanel:draw`, junto a `local rm = _G.gameSettings and _G.gameSettings.reducedMotion`)

> Ambient drift Balatro-style: shield bobs ±1px Y em sin lento (1.2 rad/s)
> pra não ficar congelado quando armor está ativo. Reduced motion zera.

## L209 (em `HudPlayerPanel:draw`, junto a `if nearCap then`)

> Teto, logo abaixo do valor. Só numeral — nada a traduzir.

## L226-229 (em `HudPlayerPanel:draw`, junto a `local StatusTooltip = require("src.ui.StatusTooltip")`)

> ===== Chip da PASSIVA de classe (clareza total — Jul/2026) =====
> A passiva existe DURANTE o combate, não só na tela de seleção: chip com
> o ícone da classe à direita do painel; hover → tooltip com nome+regra;
> brilha ~1s quando a passiva DISPARA (Game seta _passiveFlashT).

