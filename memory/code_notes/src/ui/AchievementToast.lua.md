---
name: code_notes/src/ui/AchievementToast.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/AchievementToast.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/AchievementToast.lua`

Origem: `src/ui/AchievementToast.lua` em `7dbdb60d` (1 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local Easing = require("engine.Easing")`)

> src/ui/AchievementToast.lua
> Aviso de conquista desbloqueada, desenhado por cima de QUALQUER estado
> (main.lua chama update/draw no fim do frame, abaixo so do cursor).
>
> Antes era uma linha no MessageSystem ("CONQUISTA: X!") misturada com os
> toasts de combate. Agora e um cartao proprio, no idioma escuro-dourado
> (UiPanel), com o EMBLEMA da conquista — o momento tem identidade:
> desce do topo (backOut) → emblema "carimba" (escala 1.35 → 1) com um aro
> de luz → um brilho atravessa o cartao → segura → sobe.
> Fila: varias conquistas no mesmo frame (comum na vitoria) aparecem uma
> por vez, nunca empilhadas por cima uma da outra.
>
> reducedMotion remove MOVIMENTO, nunca INFORMACAO: sem descida/carimbo, o
> cartao aparece parado e some com fade.

