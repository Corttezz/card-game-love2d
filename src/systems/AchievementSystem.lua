-- src/systems/AchievementSystem.lua
-- Conquistas (F4 do gameplay-overhaul-v1). Módulo estático (sem instância):
-- desbloqueio persiste no ProfileStats (profile.lua), toast dourado no
-- MessageSystem do game + sfx. Checks são baratos e chamados de pontos
-- específicos do Game (ver docs/plan/gameplay-overhaul-v1.md §F4).
--
-- API:
--   AchievementSystem.unlock(id, game)        -- idempotente
--   AchievementSystem.isUnlocked(id)
--   AchievementSystem.all()                   -- defs + unlocked flag
--   AchievementSystem.onCardsPlayed(game, turnContext)
--   AchievementSystem.onBattleWon(game)
--   AchievementSystem.onVictory(game)
--   AchievementSystem.onForge(game)
--   AchievementSystem.onPoisonApplied(game, enemy)

local ProfileStats = require("engine.ProfileStats")
local Defs = require("src.data.achievements")
local Sfx = require("src.systems.Sfx")

local AchievementSystem = {}

local defsById = {}
for _, d in ipairs(Defs) do defsById[d.id] = d end

local function unlockedSet()
    local s = ProfileStats.get()
    s.achievements = s.achievements or {}
    return s.achievements
end

function AchievementSystem.isUnlocked(id)
    return unlockedSet()[id] == true
end

function AchievementSystem.all()
    local set = unlockedSet()
    local out = {}
    for _, d in ipairs(Defs) do
        table.insert(out, {
            id = d.id, name = d.name, desc = d.desc,
            icon = d.icon, tier = d.tier,
            unlocked = set[d.id] == true,
        })
    end
    return out
end

function AchievementSystem.countUnlocked()
    local n = 0
    for _ in pairs(unlockedSet()) do n = n + 1 end
    return n, #Defs
end

function AchievementSystem.unlock(id, game)
    local def = defsById[id]
    if not def then return false end
    local set = unlockedSet()
    if set[id] then return false end
    set[id] = true
    ProfileStats.flush()

    if game and game.addMessage then
        game:addMessage("CONQUISTA: " .. def.name .. "!", "success")
    end
    Sfx.play("comboTrigger", { pitch = 1.2 })
    print("[Achievement] desbloqueada: " .. id)
    return true
end

-- ===== Checks por evento =====

-- Chamado em playSelectedCards (após ComboSystem.detect).
function AchievementSystem.onCardsPlayed(game, turnContext)
    local n = turnContext and turnContext.snapshot and #turnContext.snapshot or 0
    if n > 0 then
        ProfileStats.bump("cardsPlayed", n)
        if (ProfileStats.get().counters.cardsPlayed or 0) >= 2500 then
            AchievementSystem.unlock("escriba", game)
        end
    end
    -- Tinta Viva: 4 combos disparados no MESMO turno.
    if turnContext and turnContext.activeCombos
        and #turnContext.activeCombos >= 4 then
        AchievementSystem.unlock("tinta_viva", game)
    end
end

-- Chamado em Game:_onEnemyDeath (batalha vencida, score já fechado).
function AchievementSystem.onBattleWon(game)
    -- Relâmpago Selado: inimigo nunca chegou a agir.
    if (game.battleTurn or 0) == 0 then
        AchievementSystem.unlock("relampago", game)
    end
    -- Fio da Navalha: sobreviveu com exatamente 1 HP.
    if game.player and game.player.health == 1 then
        AchievementSystem.unlock("fio_navalha", game)
    end
    -- Imaculado: chefe sem tomar dano (flawless do ScoreSystem).
    local run = game.isRunMode and game.runManager
        and game.runManager.currentRun or nil
    local sb = game.scoreSystem and game.scoreSystem.lastBattle
    if sb and sb.flawless and run and run.currentNode
        and run.currentNode.type == "boss" then
        AchievementSystem.unlock("imaculado", game)
    end
    -- Escadinha de score (10k; 100k/1M ficam pra quando o endless pedir).
    if (game.score or 0) >= 10000 then
        AchievementSystem.unlock("velas_10k", game)
    end
    -- Além da Última Página: andar 10 do endless.
    if run and run.endlessMode and (run.floorsInEndless or 0) >= 10 then
        AchievementSystem.unlock("alem_da_pagina", game)
    end
    ProfileStats.flush()
end

-- Chamado em Game:checkVictory (boss do ato final morto, uma vez por run).
function AchievementSystem.onVictory(game)
    AchievementSystem.unlock("primeira_pagina", game)
    AchievementSystem.unlock("capitulo_final", game)

    local run = game.runManager and game.runManager.currentRun
    if not run then return end

    -- Trindade: venceu com as 3 classes (winsByClass do perfil).
    local wbc = ProfileStats.get().winsByClass or {}
    if wbc.warrior and wbc.mage and wbc.rogue then
        AchievementSystem.unlock("trindade", game)
    end

    local deck = run.currentDeck or {}
    if #deck <= 6 then AchievementSystem.unlock("grimorio_bolso", game) end
    if #deck >= 30 then AchievementSystem.unlock("enciclopedia", game) end

    if not run._usedShop then
        AchievementSystem.unlock("voto_pobreza", game)
    end
    if not next(run.upgraded or {}) then
        AchievementSystem.unlock("sem_rascunhos", game)
    end
    if not next(run.jokers or {}) and #(game.jokerSlots or {}) == 0 then
        AchievementSystem.unlock("asceta", game)
    end

    -- Tinta Crua: todas as cartas do deck final são common/basic.
    local CardDatabase = require("src.systems.CardDatabase")
    local allCommon = #deck > 0
    for _, id in ipairs(deck) do
        local cd = CardDatabase:getCard(id)
        local r = cd and cd.rarity or "common"
        if r ~= "common" and r ~= "basic" then
            allCommon = false
            break
        end
    end
    if allCommon then AchievementSystem.unlock("tinta_crua", game) end
end

-- Chamado quando a Forja é usada (RestScreen:doForge).
function AchievementSystem.onForge(game)
    ProfileStats.bump("forges", 1)
    if (ProfileStats.get().counters.forges or 0) >= 25 then
        AchievementSystem.unlock("ferreiro", game)
    end
    ProfileStats.flush()
end

-- Chamado quando poison é aplicado num inimigo (EffectSystem).
function AchievementSystem.onPoisonApplied(game, enemy)
    if not enemy or not enemy.statusEffects then return end
    for _, st in ipairs(enemy.statusEffects) do
        if st.name == "poison" and (st.stacks or 0) >= 15 then
            AchievementSystem.unlock("miasma", game)
            return
        end
    end
end

-- Chamado quando o armor do player bate no cap (Game, path de defesa).
function AchievementSystem.onArmorCapped(game)
    AchievementSystem.unlock("muralha", game)
end

-- Chamado quando uma carta nova entra em qualquer deck da run.
function AchievementSystem.onCardSeen(game, cardId)
    ProfileStats.markSeen(cardId)
    local seen = ProfileStats.get().cardsSeen or {}
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    local CardDatabase = require("src.systems.CardDatabase")
    local total = CardDatabase.getTotalCardCount
        and CardDatabase:getTotalCardCount() or 96
    if count >= total then
        AchievementSystem.unlock("bibliotecario", game)
    end
end

return AchievementSystem
