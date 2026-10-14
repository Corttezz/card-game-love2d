---
name: code_notes/tools/test_worldroad_resume.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_worldroad_resume.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_worldroad_resume.lua`

Origem: `tools/test_worldroad_resume.lua` em `7dbdb60d` (7 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_worldroad_resume.lua
> Regressão do CONTINUAR + ENCRUZILHADA (bug do dono, Set/2026:
> "clico em continuar, clico em batalha e a bandeira não sai da frente do
> primeiro inimigo").
>
> A bandeira é o MARCO da bifurcação (assets/sprites/world/landmark_battle.png,
> um estandarte vermelho). A convergência do fork o planta em ARRIVE_REL 7.5 e
> quem o leva embora é a CAMINHADA até o próximo encontro — a viagem que
> GameplayScene dispara quando detecta troca de andar. Retomando do menu, essa
> detecção nascia zerada (lastFloorKey = nil ⇒ "início de run, não anda") e a
> viagem NUNCA acontecia: o marco ficava parado à frente do inimigo
> (BATTLE_REL 9) e, por ser mais perto, desenhado POR CIMA dele.
>
> O teste percorre o caminho do jogador: salva na encruzilhada, carrega,
> retoma (GameplayScene.resumeWorld), escolhe o braço de batalha e cobra a
> caminhada + a saída do marco de cena.
> love . test_one test_worldroad_resume

## L34-35 (em `M.run`, junto a `local gA = TK.newRunGame("warrior")`)

> ===== 1. Uma run que chegou na ENCRUZILHADA e salvou ===================
> (espelho do showMapSelection: o andar avança ANTES de montar o fork)

## L42 (em `M.run`, junto a `for _, n in ipairs(pendA) do n.type = "battle" end`)

> todo braço vira BATALHA: o marco em jogo é o landmark_battle (a bandeira)

## L76-77 (em `gameUI`, junto a `t:eq("câmera no andar ANTERIOR ao do save (a caminhada ainda falta)",`)

> O mundo pertence ao andar ANTERIOR: a caminhada até o andar salvo é
> justamente o que ainda vai acontecer.

## L102 (em `gameUI`, junto a `GameplayScene.update(1 / 30)`)

> ===== 4. A BATALHA: a cena precisa CAMINHAR até o encontro ============

## L113-115 (em `gameUI`, junto a `local lm = WorldRoad._landmark`)

> O cobrador do bug: o marco não pode estar plantado na faixa do inimigo.
> (drawLandmarkFront só o descarta no desenho, com rel < -3; headless
> cobramos a GEOMETRIA, que é o que a tela mostra.)

## L122-124 (em `gameUI`, junto a `local gC = TK.newRunGame("warrior")`)

> ===== 5. Retomar NO MEIO de uma batalha não inventa caminhada =========
> (sem pendentes o mundo JÁ está no andar certo: viajar aqui teleportaria
> o inimigo pra longe no primeiro frame)

