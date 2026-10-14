---
name: code_notes/src/ui/ManaOrb.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ManaOrb.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ManaOrb.lua`

Origem: `src/ui/ManaOrb.lua` em `7dbdb60d` (6 de 22 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/ManaOrb.lua
> Orb circular de mana estilo Balatro (money) / Slay the Spire (energy orb).
> Posicionado bottom-right, mais perto do botão Jogar que o painel do canto,
> encurtando o loop de feedback "olha mana → olha carta → joga".

## L33-34 (em `ManaOrb:update`, junto a `if player then`)

> Ease display do valor de mana toward real. Orb renderiza disp pra
> feedback visual suave (Balatro ease_mana style).

## L43-44 (em `ManaOrb:updatePosition`, junto a `self.x = sw - Config.Utils.getResponsiveSize(0.05, 50, "width")`)

> Canto inferior direito, margem maior que o painel da esquerda
> pra não colidir com a mão de cartas (cartas vão até ~90% do width).

## L55-56 (em `ManaOrb:draw`, junto a `local actual = player.mana or 0`)

> Valor real pra detecção de flash (evento instantâneo) e valor eased
> pra exibição numérica + preenchimento do orb.

## L74-75 (em `ManaOrb:draw`, junto a `do`)

> Hover → tooltip explicando a mana (auditoria de onboarding: o orbe
> mostrava "2/3" e nada dizia o que era).

## L134-135 (em `ManaOrb:draw`, junto a `local bigFont = FontManager.getResponsiveFont(0.04, 26)`)

> Tipografia empilhada com gap: número atual grande em cima, /max médio abaixo.
> Sem overlap. Fonte reduzida (32→26) pra caber no orb r=44 com margem.

