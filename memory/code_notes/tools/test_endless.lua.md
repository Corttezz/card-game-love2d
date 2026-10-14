---
name: code_notes/tools/test_endless.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_endless.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_endless.lua`

Origem: `tools/test_endless.lua` em `7dbdb60d` (2 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local TK = require("tools.testkit")`)

> tools/test_endless.lua
> O ENDLESS É ALCANÇÁVEL a partir da vitória (auditoria Out/2026, BLOCKER).
>
> O defeito: depois do chefe final, checkVictory apagava o save e a tela de
> vitória só oferecia "jogar de novo"/menu. O único lugar que ligava o
> endlessMode era RunManager:advanceFloorInAct — que nunca mais rodava depois
> do último chefe. Resultado: a conquista "Além da Página" (andar 10 do
> endless) era impossível, e o XP por andar de endless era código morto.
>
> O contrato travado aqui:
> 1. a vitória é registrada UMA vez (perfil + maestria) no checkVictory;
> 2. "Seguir no Endless" (Game:enterEndless) só funciona DEPOIS disso e
> mantém a run viva — salva, retoma, avança andares, a dificuldade cresce;
> 3. morrer (ou abandonar) no endless NÃO conta outra vitória nem uma
> derrota: só o XP dos andares extras;
> 4. o andar 10 do endless é alcançável e dispara a conquista.
>
> love . test_one test_endless

## L156 (em `run.currentNode`, junto a `local g3 = TK.newRunGame("rogue")`)

> Abandono no endless: mesmo tratamento

