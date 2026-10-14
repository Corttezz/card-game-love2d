---
name: code_notes/src/systems/AchievementSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/AchievementSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/AchievementSystem.lua`

Origem: `src/systems/AchievementSystem.lua` em `7dbdb60d` (16 de 30 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local ProfileStats = require("engine.ProfileStats")`)

> src/systems/AchievementSystem.lua
> Conquistas. Modulo estatico (sem instancia). Mesmo padrao do Slay the Spire
> (memory/sts_metagame.md): cada sistema REPORTA o seu evento no ponto exato
> do codigo, nao existe engine observando estado. Barato e a prova de falso
> positivo.
>
> Persistencia (ProfileStats / profile.lua):
> achievements[id]     = true        (formato historico, mantido)
> achievementDates[id] = os.time()   (data do desbloqueio; nil em perfis
> que liberaram antes de existir data)
> counters.*                         (cardsPlayed, forges, bestEndlessFloor)
>
> Saidas de um unlock: perfil + toast (src/ui/AchievementToast) + sfx +
> espelho Steam (src/systems/SteamBridge). Uma fonte so: unlock().
>
> Hooks (quem chama o que):
> onRunStarted(game, classId)       Game:startNewRun
> onCardsPlayed(game, turnContext)  Game:playSelectedCards
> onCardDamage(game, card, dmg)     Game:processCardInCombat (ataque)
> onArmorCapped(game)               Game:processCardInCombat (defesa)
> onBattleWon(game)                 Game:_onEnemyDeath
> onVictory(game)                   Game:checkVictory (1x por run)
> onForge(game)                     RestScreen:doForge
> onPoisonApplied(game, enemy)      EffectSystem (apply_debuff poison)
> onOrbChanneled(game)              EffectSystem:_stepChannelOrb
> onCardSeen(game, cardId)          Game:addCardToRun
> install()                         love.load (Steam + UnlockSystem)

## L40 (em `AchievementSystem.TIERS`, junto a `AchievementSystem.SEAL_MAX_WIN = {`)

> Vitoria no Selo maximo, por classe (Selos do Grimorio, Out/2026).

## L58-61 (em `I18n`, junto a `local attackedEnemy = nil`)

> ===== Estado transitório (nao persiste) =====
> maos_limpas: inimigo contra o qual um ATAQUE foi jogado. O Enemy e objeto
> novo a cada batalha, entao comparar identidade dispensa hook de "inicio de
> batalha".

## L109-112 (em `classesUnlocked`, junto a `local function achName(d)`)

> ===== Texto exibido =====
> O texto em `Defs` e FALLBACK DE DEV (sem acento de proposito): o que o
> jogador le vem de achievements.list.<id> no i18n. FONTE UNICA — all(),
> unlock() e o toast passam por aqui.

## L156-157 (em `seenCount`, junto a `function AchievementSystem.progressOf(id)`)

> (cur, target) de uma conquista com contador; nil se ela nao tem contador
> (ou se a fonte do valor nao existe — ex. sem UnlockSystem).

## L185-186 (em `AchievementSystem.progressOf`, junto a `if AchievementSystem.isUnlocked(id) then cur = math.max(cur, target) end`)

> Conquista ja liberada mostra a barra cheia (perfil antigo pode ter o
> unlock sem o contador, ex. escriba antes de existir contador).

## L191-192 (em `AchievementSystem.progressOf`, junto a `function AchievementSystem.all()`)

> Entradas prontas pra UI (texto JA traduzido no idioma atual).
> Secreta bloqueada: name/desc viram "???" + dica generica.

## L252-253 (em `AchievementSystem.unlock`, junto a `local function reportProgress(id, before, after)`)

> Progresso pra Steam (IndicateAchievementProgress) em 25/50/75%: a Steam
> mostra o popup de "x/N" — chamar a cada carta seria spam.

## L271-272 (em `AchievementSystem.onRunStarted`, junto a `local run = game and game.runManager and game.runManager.currentRun`)

> Bibliotecario: o deck inicial tambem e "descoberto" (antes so contava
> carta ganha via addCardToRun, entao as iniciais nunca entravam).

## L313-315 (em `currentRun`, junto a `function AchievementSystem.endlessFloor(run)`)

> Andar do modo infinito (1 = primeiro andar depois do ultimo chefe).
> currentFloor comeca em 1 e soma 1 por andar resolvido; os atos ocupam
> TotalActs × FLOORS_PER_ACT andares.

## L351 (em `AchievementSystem.onBattleWon`, junto a `local rm = game.runManager`)

> Coro de Coringas: todos os slots ATIVOS ocupados.

## L412-413 (em `AchievementSystem.onVictory`, junto a `if not game.runManager:hasAnyUpgrade() then`)

> hasAnyUpgrade e nao next(run.upgraded): desde a forja POR COPIA o nivel
> mora em currentDeck[i].up.

## L421-423 (em `AchievementSystem.onVictory`, junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> Tinta Crua: todas as cartas do deck final sao common/basic. A entrada
> do deck pode ser TABELA ({id, up}) desde a forja por copia — getCard
> com a tabela devolvia nil e a carta contava como comum (falso positivo).

## L478 (em `AchievementSystem.onCardSeen`, junto a `function AchievementSystem.checkClassUnlocks(game)`)

> Todos Despertos: le o UnlockSystem (frente progressao) — nunca escreve nele.

## L486-487 (em `AchievementSystem.checkClassUnlocks`, junto a `local installed = false`)

> Chamado uma vez no love.load: liga a Steam (se houver) e assina o
> UnlockSystem pra reagir na hora em que uma classe e liberada.

## L502 (em `AchievementSystem.install`, junto a `AchievementSystem.checkClassUnlocks(nil)`)

> Perfil que ja tem as classes (liberadas antes desta conquista existir).

