---
name: code_notes/src/systems/UnlockSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/UnlockSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/UnlockSystem.lua`

Origem: `src/systems/UnlockSystem.lua` em `7dbdb60d` (16 de 42 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local ProfileStats = require("engine.ProfileStats")`)

> src/systems/UnlockSystem.lua
> Desbloqueio de CARTAS e CLASSES (meta-progressão fora da run).
> Dados em src/data/unlocks.lua; estado persistido em ProfileStats
> (profile.lua → campo `unlocks`). Documentação: memory/unlocks.md.
>
> Três conceitos DIFERENTES (Balatro separa assim e o jogador sente a diferença):
> * DESBLOQUEADA  — pode aparecer em ofertas (recompensa/loja/pacote/evento).
> * DESCOBERTA    — o jogador já VIU a carta (ofertada ou possuída); só então
> ela aparece revelada na Coleção. Desbloqueada-mas-não-vista
> continua "?" (Balatro: "undiscovered").
> * CLASSE        — guerreiro sempre; mago/ladino por feitos.
>
> Contrato público (a tela de seleção de classe e as conquistas programam
> contra ESTA lista — não mude assinatura sem avisar as frentes):
> UnlockSystem.isCardUnlocked(cardId) -> bool
> UnlockSystem.isCardDiscovered(cardId) -> bool
> UnlockSystem.markDiscovered(cardId) -> bool   (true = era inédita)
> UnlockSystem.takeFreshInCollection() -> { [id]=true }
> UnlockSystem.isClassUnlocked(classId) -> bool
> UnlockSystem.isClassUnlockedReal(classId) -> bool   (ignora override)
> UnlockSystem.getClassUnlockInfo(classId) -> { unlocked, reqKey, vars, progress, goal }
> UnlockSystem.getClassMastery(classId) -> { level, maxLevel, xp, xpToNext }
> UnlockSystem.onRunEnded(summary) -> { newCards, newClasses, levelsGained, ... }
> UnlockSystem.onBossDefeated(actNumber, game)
> UnlockSystem.unlockedCount() -> cardsUnlocked, totalCards, classesUnlocked, totalClasses
> UnlockSystem.onUnlock(fn)            -- fn(kind "card"|"class", id)
> UnlockSystem.setOverrideAll(bool)    -- tools/autoplay: catálogo inteiro
> UnlockSystem.setRevealAll(bool)      -- tools de captura: coleção toda revelada
> UnlockSystem.getMaxSeal(classId) -> 0..10   (maior Selo SELECIONÁVEL)
> UnlockSystem.getSealWon(classId) -> -1..10  (maior Selo VENCIDO; -1 = nunca venceu)
> UnlockSystem.getClassRecord(classId) -> { bestScore, bestEndless }  (recordes por classe)

## L41-42 (em `listeners`, junto a `local pendingRun = { cards = {}, classes = {} }`)

> Desbloqueios ocorridos NESTA run antes do fim (chefe vencido no meio da
> run libera classe na hora — o reveal do fim de run mostra também).

## L70-71 (em `totalActs`, junto a `local function clampAct(n)`)

> Metas de ato são escritas pensando em 6 atos; num jogo de N atos o alvo
> nunca passa de N (senão "complete o ato 4" seria impossível sem endless).

## L92-94 (em `discovered`, junto a `local function migrateLegacy(s, u)`)

> Migração de perfis antigos (antes do UnlockSystem existir). Regra do dono:
> NÃO punir quem já jogou. O perfil antigo só guarda agregados (runs, wins,
> bestAct, winsByClass, cardsSeen), então o XP é ESTIMADO e generoso.

## L137-139 (em `state`, junto a `if type(u.sealsWon) ~= "table" then`)

> Selos do Grimório (Out/2026): maior selo VENCIDO por classe. Ausente =
> nunca venceu. Perfil antigo com vitória da classe conta como selo 0
> vencido (não punir quem já jogou — mesma regra do migrateLegacy).

## L149-151 (em `u.sealsWon`, junto a `local SEAL_MAX = 10`)

> ===== Selos do Grimório =====
> Desbloqueio POR CLASSE, um degrau por vitória (StS: Ascensão N+1 só depois
> de vencer a N com o MESMO personagem). Vencer com o selo k libera o k+1.

## L160-161 (em `UnlockSystem.getSealWon`, junto a `function UnlockSystem.getClassRecord(classId)`)

> Recordes POR CLASSE (pós-jogo, Out/2026): melhor pontuação e andar mais
> fundo do endless. Gravados em onRunEnded (toda run termina por lá).

## L174-175 (em `UnlockSystem.getMaxSeal`, junto a `function UnlockSystem.ensure()`)

> Garante o estado (e a migração) ANTES de qualquer contador do perfil mudar.
> Chamado no boot e no começo de cada run.

## L203-204 (em `UnlockSystem.getClassMastery`, junto a `function UnlockSystem.computeRunXP(summary)`)

> XP de uma run. summary: { actNumber, floorInAct, victory, endlessMode,
> floorsInEndless, actsCleared? }.

## L213-214 (em `UnlockSystem.computeRunXP`, junto a `if summary.endlessMode and not summary.victory then`)

> Morte NO endless: a parte "normal" da run já pagou XP na vitória
> (checkVictory chamou onRunEnded). Aqui só conta o que veio depois.

## L276-282 (em `UnlockSystem.isCardDiscovered`, junto a `function UnlockSystem.markDiscovered(cardId)`)

> Marca como vista. NÃO grava em disco (seria 1 write por oferta): o perfil é
> descarregado nos pontos de flush já existentes (fim de batalha, fim de run).
> Devolve true quando a carta era INÉDITA: quem mostra a oferta usa isso pro
> selo "NOVA" (src/ui/DiscoveryMark.lua) — a descoberta já virou, então a
> pergunta tem que ser feita AQUI, no instante da virada, e não depois.
> A carta inédita também entra em `freshInCollection` (persistido): a Coleção
> pulsa a entrada uma vez na próxima visita (takeFreshInCollection).

## L411 (em `snapshot`, junto a `local function orderedCardIds()`)

> Ordem estável (dados) pra reveal e testes.

## L454-455 (em `pendingRun`, junto a `function UnlockSystem.onBossDefeated(actNumber, game)`)

> Chefe de ato vencido (Game:_onEnemyDeath). Libera na HORA o que dependia
> disso (classe/marco) com toast — o reveal do fim de run repete em destaque.

## L485-488 (em `UnlockSystem.onBossDefeated`, junto a `function UnlockSystem.onRunEnded(summary)`)

> Fim de run (vitória OU derrota). summary:
> { classId, victory, actNumber, floorInAct, endlessMode, floorsInEndless, score }
> Retorna { newCards, newClasses, levelsGained, xpGained, classId,
> before = mastery, after = mastery, bundles = { {level, theme, cards} } }.

## L560-561 (em `result`, junto a `require("src.systems.UnlockQueue").addRunResult(result)`)

> Revelações do menu (Balatro): o que esta run liberou entra na fila do
> perfil e aparece, um painel por vez, quando o jogador voltar ao menu.

## L568-569 (em `result`, junto a `function UnlockSystem._resetForTests()`)

> Só pra testes: esquece pendentes/flags. NÃO apaga listeners: as conquistas
> assinam onUnlock no boot e a suite roda tudo no mesmo processo.

