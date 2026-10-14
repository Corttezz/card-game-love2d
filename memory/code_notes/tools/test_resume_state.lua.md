---
name: code_notes/tools/test_resume_state.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_resume_state.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_resume_state.lua`

Origem: `tools/test_resume_state.lua` em `7dbdb60d` (10 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local TK = require("tools.testkit")`)

> tools/test_resume_state.lua
> CONTINUAR NÃO PERDE NADA (Out/2026 — bug do dono: "cliquei em Continuar e
> todos os PONTOS zeraram. Isso nunca pode acontecer").
>
> Joga alguns andares (roteiro determinístico: luta vencida, cash out,
> recompensa, forja, coringa, ouro, pontuação), e em CADA estágio salva →
> Game NOVO → loadRun → resumeRun e compara em profundidade um retrato de
> TODO o estado da run. O retrato é a lista do que precisa sobreviver; o que
> fica de fora está nomeado em TRANSIENT com o porquê. Campo novo no
> currentRun entra de graça (o retrato copia o currentRun inteiro) — e se
> não sobreviver à serialização (função, userdata, chave reservada, inf), a
> diferença aparece aqui com o caminho.
>
> love . test_one test_resume_state

## L20 (em `M`, junto a `local TRANSIENT_RUN = {`)

> Fora do retrato do currentRun, com o motivo:

## L57-58 (em `all`, junto a `local function deckSignature(game)`)

> O baralho que a PRÓXIMA luta monta (forja/edição/selo aplicados). As
> pilhas em memória fora da luta são resto da luta anterior (transitório).

## L69-71 (em `rngStreams`, junto a `local function snapshot(game, battle)`)

> `battle` = estágio de luta: inclui a mão e o inimigo (a luta tem que ser
> a MESMA). Fora da luta eles são descartáveis (o main mata o inimigo
> provisório do resumeRun) e o RNG tem que voltar intocado.

## L116-119 (em `s.enemy`, junto a `s.rng = rngStreams()`)

> Na luta: o RNG retomado tem que estar EXATAMENTE onde a luta original
> estava depois de montada (mesmos sorteios consumidos, em cada stream) —
> senão o golpe seguinte do inimigo já diverge, mesmo com a abertura
> igual. Fora da luta: intocado.

## L189-193 (em `goToNextBattle`, junto a `if stripEnemy then`)

> Nó SEM inimigo pré-sorteado (save antigo, ou evento que caiu pra luta
> comum): o nextPhase sorteia quem luta. Era o caminho em que a luta
> retomada abria com outro golpe — e o roteiro só passava por ele quando
> a encruzilhada sorteada não tinha nó de luta (dependia da ordem das
> suítes). Agora é forçado.

## L240-241 (em `M.run`, junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> Baralho grande o bastante pra mão inicial ser um SORTEIO de verdade
> (com 4 cartas a mão é o deck inteiro e a ordem quase não pesa).

## L265-266 (em `extra`, junto a `rm:chooseNode(1, { hp = game.player.health, maxHp = game.player.maxHealth,`)

> LOJA / DESCANSO / EVENTO (o nó em si já tem cobertura própria; aqui o
> que importa é o estado da run em volta)

## L281-282 (em `extra`, junto a `game.player.health = game.player.health - 7`)

> Jogar um turno: "Salvar e sair" no meio da luta NÃO regrava; o
> Continuar volta ao início dela.

## L288-290 (em `extra`, junto a `for _, strip in ipairs({ false, true }) do`)

> As duas origens do inimigo: pré-sorteado na encruzilhada (caminho
> normal) e sorteado no nextPhase (save antigo / evento que vira luta).
> Antes do conserto, só uma delas batia — e qual dependia do mapa.

