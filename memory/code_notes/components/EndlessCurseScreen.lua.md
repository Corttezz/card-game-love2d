---
name: code_notes/components/EndlessCurseScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/EndlessCurseScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/EndlessCurseScreen.lua`

Origem: `components/EndlessCurseScreen.lua` em `7dbdb60d` (4 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/EndlessCurseScreen.lua
> ESCOLHA DE MALDIÇÃO do endless (Out/2026). A cada ciclo de 8 andares
> (RunManager:advanceFloorInAct → RunModifiers.beginEndlessCycle) duas
> maldições ficam ABERTAS em run.endless.pending; esta tela obriga a escolher
> uma (não tem "pular" — StS: Neow impõe a praga; aqui o jogador escolhe QUAL).
>
> Quem abre: EndlessCurseScreen.watch(game, state), chamado todo frame pelo
> love.update. Observar o ESTADO em vez de ser chamado por quem gira o ciclo
> é o que torna a escolha à prova de Continuar: a pendência viaja no save e,
> ao voltar pro mapa, a tela reabre sozinha.
>
> Layout em ZONAS puro (layout + validate), recalculado por frame. Entrada:
> mouse e teclado/gamepad via MenuKit (esquerda/direita escolhe, Enter
> confirma).

## L106-107 (em `Screen:show`, junto a `function Screen:hide()`)

> Fechar SEM escolher só acontece de fora (voltar ao menu); a pendência
> continua no save e a tela reabre no próximo mapa.

## L150 (em `Screen:update`, junto a `local function curseLines(run, id)`)

> Texto da regra de uma maldição com o acúmulo que ela TERIA ao ser escolhida.

## L277-278 (em `Screen:keypressed`, junto a `return true`)

> "back" não fecha: a escolha é obrigatória (o modal captura o teclado,
> então nem a pausa abre por cima — decide-se primeiro).

