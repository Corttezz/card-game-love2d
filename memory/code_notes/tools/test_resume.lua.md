---
name: code_notes/tools/test_resume.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_resume.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_resume.lua`

Origem: `tools/test_resume.lua` em `7dbdb60d` (8 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local TK = require("tools.testkit")`)

> tools/test_resume.lua
> Regressão do CONTINUAR DENTRO DA LUTA DO CHEFE (bug do dono, Set/2026, com
> captura): "quando estou em um boss, salvo e tento abrir pelo Continuar, ele
> abre com o boss no meio do cenário normal".
>
> Na captura o lich do ato 2 (220/220) está plantado na ESTRADA — grama,
> pinheiros, castelo ao longe — em vez do salão. O diagnóstico que este
> arquivo fixa em números:
>
> 1. O NÓ SOBREVIVE ao save. `currentNode` viaja dentro do `currentRun`
> serializado; depois do loadRun ele volta com `type == "boss"`, e é por
> isso que o inimigo (sprite e vida) vem CERTO. A hipótese "o nó se
> perde" é falsa, e o teste a mata explicitamente.
> 2. O que se perde é a CENA: `bossEntered` é estado de módulo do
> GameplayScene, nasce false e só vira true pela cerimônia da porta —
> que o Continuar nunca dispara (o mundo já nasce ancorado no andar
> salvo, então nenhuma viagem acontece). `isInteriorNode("boss", false)`
> é false ⇒ estrada.
> 3. A MÚSICA é consequência do mesmo nó: com nodeType="boss" o
> MusicDirector pede `musicBoss`. O "ficou a do menu" tinha causa
> própria — o espelho `_current` do diretor — corrigida em 7ffc3c8 e
> coberta aqui de novo, no contexto do chefe.
>
> A correção mora em `src/systems/ResumeFlow.lua`, chamado pelo
> setContinueCallback do main.lua.
> love . test_one test_resume

## L32-34 (em `M`, junto a `local function fakeScene()`)

> Cena de mentira: registra o que o ResumeFlow mandou fazer. É o que torna a
> decisão mensurável sem contexto gráfico — e o que faz este teste FALHAR se
> alguém remover a chamada que entrega o salão.

## L81-84 (em `runA.currentNode`, junto a `t:falsy("sem a cerimônia encenada, o chefe cai na ESTRADA (o defeito)",`)

> ===== 3. A CENA: o que realmente estava quebrado ======================
> A predicata da cena é pura e é a fonte única (memory/
> enemy_pose_and_scene_anchor.md). Com a flag em false — o estado em que
> o Continuar deixava o módulo — ela devolve ESTRADA.

## L101-102 (em `runA.currentNode`, junto a `t:truthy("GameplayScene expõe o gancho que o ResumeFlow usa",`)

> O gancho que o ResumeFlow chama tem que EXISTIR na cena de verdade:
> renomeá-lo sem atualizar o ResumeFlow devolveria a estrada em silêncio.

## L106-108 (em `runA.currentNode`, junto a `for _, tipo in ipairs({ "elite", "mini_boss", "battle" }) do`)

> ===== 4. ELITE continua na ESTRADA (não trocar um bug por outro) =====
> "o hall é o clímax do ato" — elite e mini-boss lutam lá fora de
> propósito (memory/enemy_pose_and_scene_anchor.md).

## L118-122 (em `runA.currentNode`, junto a `local planFork = ResumeFlow.plan({`)

> ===== 5. RESÍDUO DA ENCRUZILHADA =====================================
> showMapSelection NÃO limpa currentNode: salvar na bifurcação logo depois
> de matar o chefe deixa type="boss" como sobra do nó JÁ resolvido. Sem
> esta guarda o Continuar na encruzilhada abriria o salão no lugar da
> estrada que se bifurca.

## L140-141 (em `pendingNodes`, junto a `local AudioManager = require("engine.AudioManager")`)

> Fim a fim, com o AudioManager de verdade: menu tocando, espelho do
> diretor mentindo, e o Continuar num chefe tem que virar musicBoss.

## L164-166 (em `pendingNodes`, junto a `local src = love.filesystem.read("main.lua") or ""`)

> ===== 7. A LIGAÇÃO NO main.lua =======================================
> O ResumeFlow só existe se alguém o chamar. Sem esta trava, remover a
> linha do setContinueCallback devolveria o bug com a suíte toda verde.

