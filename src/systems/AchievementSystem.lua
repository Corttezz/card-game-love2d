-- src/systems/AchievementSystem.lua
-- Conquistas. Modulo estatico (sem instancia). Mesmo padrao do Slay the Spire
-- (memory/sts_metagame.md): cada sistema REPORTA o seu evento no ponto exato
-- do codigo, nao existe engine observando estado. Barato e a prova de falso
-- positivo.
--
-- Persistencia (ProfileStats / profile.lua):
--   achievements[id]     = true        (formato historico, mantido)
--   achievementDates[id] = os.time()   (data do desbloqueio; nil em perfis
--                                       que liberaram antes de existir data)
--   counters.*                         (cardsPlayed, forges, bestEndlessFloor)
--
-- Saidas de um unlock: perfil + toast (src/ui/AchievementToast) + sfx +
-- espelho Steam (src/systems/SteamBridge). Uma fonte so: unlock().
--
-- Hooks (quem chama o que):
--   onRunStarted(game, classId)       Game:startNewRun
--   onCardsPlayed(game, turnContext)  Game:playSelectedCards
--   onCardDamage(game, card, dmg)     Game:processCardInCombat (ataque)
--   onArmorCapped(game)               Game:processCardInCombat (defesa)
--   onBattleWon(game)                 Game:_onEnemyDeath
--   onVictory(game)                   Game:checkVictory (1x por run)
--   onForge(game)                     RestScreen:doForge
--   onPoisonApplied(game, enemy)      EffectSystem (apply_debuff poison)
--   onOrbChanneled(game)              EffectSystem:_stepChannelOrb
--   onCardSeen(game, cardId)          Game:addCardToRun
--   install()                         love.load (Steam + UnlockSystem)

local ProfileStats = require("engine.ProfileStats")
local Defs = require("src.data.achievements")
local Sfx = require("src.systems.Sfx")

local AchievementSystem = {}

AchievementSystem.CLASSES = { "warrior", "mage", "rogue" }
AchievementSystem.CLASS_WIN = {
    warrior = "vitoria_guerreiro", mage = "vitoria_mago", rogue = "vitoria_ladino",
}
AchievementSystem.TIERS = { "natural", "build", "skill", "collection" }
-- Vitoria no Selo maximo, por classe (Selos do Grimorio, Out/2026).
AchievementSystem.SEAL_MAX_WIN = {
    warrior = "selo_max_guerreiro", mage = "selo_max_mago", rogue = "selo_max_ladino",
}
-- Marcos de ciclo do endless (andar absoluto; o alvo mora no catalogo).
AchievementSystem.ENDLESS_MARKS = { "ciclo_3", "ciclo_5", "ciclo_10" }

-- Limiares (uma fonte so: descricoes no i18n citam estes numeros).
AchievementSystem.T = {
    POISON = 15, COMBOS = 3, SCORE = 10000, CARD_DAMAGE = 60,
    ORBS = 3, POCKET_DECK = 6, BIG_DECK = 30, ENDLESS_FLOOR = 10,
}

local defsById = {}
for _, d in ipairs(Defs) do defsById[d.id] = d end

local function I18n() return require("src.i18n.I18n") end

-- ===== Estado transitório (nao persiste) =====
-- maos_limpas: inimigo contra o qual um ATAQUE foi jogado. O Enemy e objeto
-- novo a cada batalha, entao comparar identidade dispensa hook de "inicio de
-- batalha".
local attackedEnemy = nil

-- ===== Perfil =====
local function profile() return ProfileStats.get() end

local function unlockedSet()
    local s = profile()
    s.achievements = s.achievements or {}
    return s.achievements
end

local function datesSet()
    local s = profile()
    s.achievementDates = s.achievementDates or {}
    return s.achievementDates
end

local function counter(key)
    local s = profile()
    return (s.counters and s.counters[key]) or 0
end

-- ===== UnlockSystem (frente progressao) — opcional =====
local unlockWarned = false
local function unlockSystem()
    local ok, mod = pcall(require, "src.systems.UnlockSystem")
    if ok and type(mod) == "table" then return mod end
    if not unlockWarned then
        unlockWarned = true
        print("[Achievement] AVISO: src.systems.UnlockSystem ausente — "
            .. "'despertar' fica sem progresso ate o modulo existir")
    end
    return nil
end

local function classesUnlocked()
    local US = unlockSystem()
    if not US then return nil end
    local isReal = US.isClassUnlockedReal or US.isClassUnlocked
    if type(isReal) ~= "function" then return nil end
    local n = 0
    for _, c in ipairs(AchievementSystem.CLASSES) do
        if isReal(c) then n = n + 1 end
    end
    return n
end

-- ===== Texto exibido =====
-- O texto em `Defs` e FALLBACK DE DEV (sem acento de proposito): o que o
-- jogador le vem de achievements.list.<id> no i18n. FONTE UNICA — all(),
-- unlock() e o toast passam por aqui.
local function achName(d)
    return I18n().t("achievements.list." .. d.id .. ".name", nil, d.name or d.id)
end
local function achDesc(d)
    return I18n().t("achievements.list." .. d.id .. ".desc", nil, d.desc or "")
end

AchievementSystem.nameOf = function(id)
    local d = defsById[id]; return d and achName(d) or id
end
AchievementSystem.descOf = function(id)
    local d = defsById[id]; return d and achDesc(d) or ""
end

-- ===== Consulta =====
function AchievementSystem.defs() return Defs end
function AchievementSystem.def(id) return defsById[id] end

function AchievementSystem.isUnlocked(id)
    return unlockedSet()[id] == true
end

function AchievementSystem.unlockedAt(id)
    return datesSet()[id]
end

local function totalCards()
    local CardDatabase = require("src.systems.CardDatabase")
    local n = 0
    for _ in pairs(CardDatabase:getAllCards()) do n = n + 1 end
    return n
end

local function seenCount()
    local CardDatabase = require("src.systems.CardDatabase")
    local all = CardDatabase:getAllCards()
    local n = 0
    for id in pairs(profile().cardsSeen or {}) do
        if all[id] then n = n + 1 end   -- carta removida do catalogo nao conta
    end
    return n
end

-- (cur, target) de uma conquista com contador; nil se ela nao tem contador
-- (ou se a fonte do valor nao existe — ex. sem UnlockSystem).
function AchievementSystem.progressOf(id)
    local d = defsById[id]
    if not d or not d.progress then return nil end
    local p = d.progress
    local target = p.target
    local cur
    if p.stat == "cardsPlayed" or p.stat == "forges"
        or p.stat == "bestEndlessFloor" then
        cur = counter(p.stat)
    elseif p.stat == "wins" then
        cur = profile().wins or 0
    elseif p.stat == "classesWon" then
        local wbc = profile().winsByClass or {}
        cur = 0
        for _, c in ipairs(AchievementSystem.CLASSES) do
            if wbc[c] then cur = cur + 1 end
        end
    elseif p.stat == "classesUnlocked" then
        cur = classesUnlocked()
        if cur == nil then return nil end
    elseif p.stat == "cardsSeen" then
        cur = seenCount()
    else
        print("[Achievement] AVISO: stat de progresso desconhecido: " .. tostring(p.stat))
        return nil
    end
    if target == "all_cards" then target = totalCards() end
    -- Conquista ja liberada mostra a barra cheia (perfil antigo pode ter o
    -- unlock sem o contador, ex. escriba antes de existir contador).
    if AchievementSystem.isUnlocked(id) then cur = math.max(cur, target) end
    return math.min(cur, target), target
end

-- Entradas prontas pra UI (texto JA traduzido no idioma atual).
-- Secreta bloqueada: name/desc viram "???" + dica generica.
function AchievementSystem.all()
    local set = unlockedSet()
    local dates = datesSet()
    local out = {}
    for _, d in ipairs(Defs) do
        local unlocked = set[d.id] == true
        local secret = d.hidden and not unlocked
        local cur, target = AchievementSystem.progressOf(d.id)
        table.insert(out, {
            id = d.id, tier = d.tier, steam = d.steam,
            hidden = d.hidden == true, secret = secret,
            name = secret and I18n().t("achievements.secret_name", nil, "???") or achName(d),
            desc = secret and I18n().t("achievements.secret_desc", nil,
                "Conquista secreta. Continue jogando.") or achDesc(d),
            unlocked = unlocked,
            unlockedAt = dates[d.id],
            progress = (cur and not secret) and { cur = cur, target = target } or nil,
        })
    end
    return out
end

-- So conta ids do catalogo ATUAL (perfil pode ter id aposentado).
function AchievementSystem.countUnlocked()
    local set = unlockedSet()
    local n = 0
    for _, d in ipairs(Defs) do
        if set[d.id] then n = n + 1 end
    end
    return n, #Defs
end

-- ===== Desbloqueio =====
function AchievementSystem.unlock(id, game)
    local def = defsById[id]
    if not def then
        print("[Achievement] AVISO: unlock de id desconhecido: " .. tostring(id))
        return false
    end
    local set = unlockedSet()
    if set[id] then return false end
    set[id] = true
    datesSet()[id] = os.time()
    ProfileStats.flush()

    local okT, Toast = pcall(require, "src.ui.AchievementToast")
    if okT then
        Toast.push({ id = id, name = achName(def), desc = achDesc(def), tier = def.tier })
    else
        print("[Achievement] AVISO: toast indisponivel: " .. tostring(Toast))
    end
    Sfx.play("comboTrigger", { pitch = 1.2 })
    require("src.systems.SteamBridge").unlock(def.steam)
    print("[Achievement] desbloqueada: " .. id)
    return true
end

-- Progresso pra Steam (IndicateAchievementProgress) em 25/50/75%: a Steam
-- mostra o popup de "x/N" — chamar a cada carta seria spam.
local function reportProgress(id, before, after)
    local d = defsById[id]
    if not d or not d.progress or AchievementSystem.isUnlocked(id) then return end
    local target = d.progress.target
    if type(target) ~= "number" then return end
    for _, f in ipairs({ 0.25, 0.5, 0.75 }) do
        local m = math.floor(target * f)
        if before < m and after >= m then
            require("src.systems.SteamBridge").indicateProgress(d.steam, after, target)
        end
    end
end

-- ===== Checks por evento =====

function AchievementSystem.onRunStarted(game, classId)
    attackedEnemy = nil
    -- Bibliotecario: o deck inicial tambem e "descoberto" (antes so contava
    -- carta ganha via addCardToRun, entao as iniciais nunca entravam).
    local run = game and game.runManager and game.runManager.currentRun
    local RunManager = require("src.systems.RunManager")
    for _, e in ipairs(run and run.currentDeck or {}) do
        ProfileStats.markSeen(RunManager.entryId(e))
    end
    ProfileStats.flush()
end

function AchievementSystem.onCardsPlayed(game, turnContext)
    local cards = turnContext and turnContext.allSelectedCards or {}
    local n = #cards
    if n > 0 then
        local before = counter("cardsPlayed")
        ProfileStats.bump("cardsPlayed", n)
        local after = counter("cardsPlayed")
        reportProgress("escriba", before, after)
        if after >= defsById.escriba.progress.target then
            AchievementSystem.unlock("escriba", game)
        end
    end
    for _, c in ipairs(cards) do
        if c.type == "attack" then attackedEnemy = game and game.enemy end
    end
    if turnContext and turnContext.activeCombos
        and #turnContext.activeCombos >= AchievementSystem.T.COMBOS then
        AchievementSystem.unlock("tinta_viva", game)
    end
end

function AchievementSystem.onCardDamage(game, card, damage)
    if (damage or 0) >= AchievementSystem.T.CARD_DAMAGE then
        AchievementSystem.unlock("golpe_tinta", game)
    end
end

local function currentRun(game)
    return game and game.isRunMode and game.runManager
        and game.runManager.currentRun or nil
end

-- Andar do modo infinito (1 = primeiro andar depois do ultimo chefe).
-- currentFloor comeca em 1 e soma 1 por andar resolvido; os atos ocupam
-- TotalActs × FLOORS_PER_ACT andares.
function AchievementSystem.endlessFloor(run)
    if not run or not run.endlessMode then return 0 end
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local acts = (Config.TotalActs or 6) * MapManager.FLOORS_PER_ACT
    return math.max(0, (run.currentFloor or 0) - acts)
end

function AchievementSystem.onBattleWon(game)
    local run = currentRun(game)
    local node = run and run.currentNode
    local isBoss = node and node.type == "boss"

    if (game.battleTurn or 0) == 0 then
        AchievementSystem.unlock("relampago", game)
    end
    if game.player and game.player.health == 1 then
        AchievementSystem.unlock("fio_navalha", game)
    end
    if game.enemy and attackedEnemy ~= game.enemy then
        AchievementSystem.unlock("maos_limpas", game)
    end
    local sb = game.scoreSystem and game.scoreSystem.lastBattle
    if isBoss and sb and sb.flawless then
        AchievementSystem.unlock("imaculado", game)
    end
    if isBoss and not run.endlessMode then
        AchievementSystem.unlock("primeiro_chefe", game)
        if (run.actNumber or 0) >= 3 then
            AchievementSystem.unlock("capitulo_final", game)
        end
    end
    if (game.score or 0) >= AchievementSystem.T.SCORE then
        AchievementSystem.unlock("velas_10k", game)
    end
    -- Coro de Coringas: todos os slots ATIVOS ocupados.
    local rm = game.runManager
    local maxSlots = rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots() or 0
    if maxSlots > 0 and #(game.jokerSlots or {}) >= maxSlots then
        AchievementSystem.unlock("coro_coringas", game)
    end
    -- Alem da Ultima Pagina: recorde de andar no infinito (contador).
    local ef = AchievementSystem.endlessFloor(run)
    if ef > 0 then
        local s = profile()
        s.counters = s.counters or {}
        local before = s.counters.bestEndlessFloor or 0
        if ef > before then
            s.counters.bestEndlessFloor = ef
            reportProgress("alem_da_pagina", before, ef)
        end
        if ef >= AchievementSystem.T.ENDLESS_FLOOR then
            AchievementSystem.unlock("alem_da_pagina", game)
        end
        -- Ciclos do endless: mesmo contador, alvos do catalogo.
        for _, id in ipairs(AchievementSystem.ENDLESS_MARKS) do
            local d = defsById[id]
            if d and ef > before then reportProgress(id, before, ef) end
            if d and ef >= d.progress.target then AchievementSystem.unlock(id, game) end
        end
    end
    ProfileStats.flush()
end

function AchievementSystem.onVictory(game)
    AchievementSystem.unlock("primeira_pagina", game)

    local run = game.runManager and game.runManager.currentRun
    if not run then return end

    local classId = run.classId or game.selectedClass
    if AchievementSystem.CLASS_WIN[classId] then
        AchievementSystem.unlock(AchievementSystem.CLASS_WIN[classId], game)
    end
    -- Selos do Grimorio: qualquer selo vencido; o 10 por classe.
    local seal = run.seal or 0
    if seal >= 1 then AchievementSystem.unlock("primeiro_selo", game) end
    if seal >= 10 and AchievementSystem.SEAL_MAX_WIN[classId] then
        AchievementSystem.unlock(AchievementSystem.SEAL_MAX_WIN[classId], game)
    end
    local won = AchievementSystem.progressOf("trindade")
    if won and won >= 3 then AchievementSystem.unlock("trindade", game) end
    if (profile().wins or 0) >= defsById.veterano.progress.target then
        AchievementSystem.unlock("veterano", game)
    end

    local deck = run.currentDeck or {}
    if #deck <= AchievementSystem.T.POCKET_DECK then
        AchievementSystem.unlock("grimorio_bolso", game)
    end
    if #deck >= AchievementSystem.T.BIG_DECK then
        AchievementSystem.unlock("enciclopedia", game)
    end
    if not run._usedShop then
        AchievementSystem.unlock("voto_pobreza", game)
    end
    -- hasAnyUpgrade e nao next(run.upgraded): desde a forja POR COPIA o nivel
    -- mora em currentDeck[i].up.
    if not game.runManager:hasAnyUpgrade() then
        AchievementSystem.unlock("sem_rascunhos", game)
    end
    if not next(run.jokers or {}) and #(game.jokerSlots or {}) == 0 then
        AchievementSystem.unlock("asceta", game)
    end

    -- Tinta Crua: todas as cartas do deck final sao common/basic. A entrada
    -- do deck pode ser TABELA ({id, up}) desde a forja por copia — getCard
    -- com a tabela devolvia nil e a carta contava como comum (falso positivo).
    local CardDatabase = require("src.systems.CardDatabase")
    local RunManager = require("src.systems.RunManager")
    local allCommon = #deck > 0
    for _, entry in ipairs(deck) do
        local cd = CardDatabase:getCard(RunManager.entryId(entry))
        local r = cd and cd.rarity
        if r ~= "common" and r ~= "basic" then
            allCommon = false
            break
        end
    end
    if allCommon then AchievementSystem.unlock("tinta_crua", game) end

    AchievementSystem.checkClassUnlocks(game)
end

function AchievementSystem.onForge(game)
    local before = counter("forges")
    ProfileStats.bump("forges", 1)
    reportProgress("ferreiro", before, before + 1)
    if counter("forges") >= defsById.ferreiro.progress.target then
        AchievementSystem.unlock("ferreiro", game)
    end
    ProfileStats.flush()
end

function AchievementSystem.onPoisonApplied(game, enemy)
    if not enemy or not enemy.statusEffects then return end
    for _, st in ipairs(enemy.statusEffects) do
        if st.name == "poison" and (st.stacks or 0) >= AchievementSystem.T.POISON then
            AchievementSystem.unlock("miasma", game)
            return
        end
    end
end

function AchievementSystem.onArmorCapped(game)
    AchievementSystem.unlock("muralha", game)
end

function AchievementSystem.onOrbChanneled(game)
    local p = game and game.player
    if p and #(p.orbs or {}) >= AchievementSystem.T.ORBS then
        AchievementSystem.unlock("conduite_pleno", game)
    end
end

function AchievementSystem.onCardSeen(game, cardId)
    ProfileStats.markSeen(cardId)
    if seenCount() >= totalCards() then
        AchievementSystem.unlock("bibliotecario", game)
    end
end

-- Todos Despertos: le o UnlockSystem (frente progressao) — nunca escreve nele.
function AchievementSystem.checkClassUnlocks(game)
    local n = classesUnlocked()
    if n and n >= #AchievementSystem.CLASSES then
        AchievementSystem.unlock("despertar", game)
    end
end

-- Chamado uma vez no love.load: liga a Steam (se houver) e assina o
-- UnlockSystem pra reagir na hora em que uma classe e liberada.
local installed = false
function AchievementSystem.install()
    if installed then return end
    installed = true
    local SteamBridge = require("src.systems.SteamBridge")
    if SteamBridge.init() then
        SteamBridge.syncAll(Defs, AchievementSystem.isUnlocked)
    end
    local US = unlockSystem()
    if US and type(US.onUnlock) == "function" then
        US.onUnlock(function(kind)
            if kind == "class" then AchievementSystem.checkClassUnlocks(nil) end
        end)
    end
    -- Perfil que ja tem as classes (liberadas antes desta conquista existir).
    AchievementSystem.checkClassUnlocks(nil)
end

-- Testes: zera o estado transitório.
function AchievementSystem._resetTransient()
    attackedEnemy = nil
end

return AchievementSystem
