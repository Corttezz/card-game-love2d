-- src/systems/RunManager.lua
-- Gerencia a "corrida" atual (run) como no Slay the Spire

local RunManager = {}
RunManager.__index = RunManager

local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local SaveManager  = require("engine.SaveManager")
local Rng          = require("src.systems.Rng")
local Config       = require("src.core.Config")

function RunManager:new()
    local instance = setmetatable({}, RunManager)
    instance.cardRegistry = CardRegistry:new()
    instance.cardDatabase = CardDatabase:new()

    -- Estado da corrida atual
    instance.currentRun = nil
    instance.isRunActive = false

    return instance
end

-- Inicia uma nova corrida com a classe selecionada
function RunManager:startNewRun(classId)
    local selectedClass = self.cardRegistry:getClassInfo(classId)
    if not selectedClass then
        error("Classe nao encontrada: " .. tostring(classId))
    end

    -- RNG seedável da run (streams card/shop/map/event/enemy/misc). Toda
    -- decisão de run passa por ele — reprodutível por seed e à prova de
    -- save-scum (estado serializado em rngState no save).
    local rng = Rng.setActive(Rng.new())
    print("[RunManager] nova run com seed " .. tostring(rng.seed))

    self.currentRun = {
        classId = classId,
        className = selectedClass.name,

        -- Seed da run (informativo/debug; o estado vivo mora em rngState).
        runSeed = rng.seed,

        -- Deck dinâmico que cresce durante o jogo
        currentDeck = {},

        -- Jokers da run (separados do deck — padrão Balatro G.jokers).
        -- Array de strings ou {id, edition?, seal?}. Persistem entre batalhas.
        -- Reconstruído em jokerSlots via buildJokerInstances().
        jokers = {},

        -- Progresso
        currentFloor = 1,
        battlesWon = 0,
        cardsAdded = 0,

        -- Estrutura de atos (Fase 4/5): actNumber + floorInAct + endlessMode
        actNumber = 1,
        floorInAct = 1,
        endlessMode = false,

        -- Nodes: pendingNodes = lista de 2-3 escolhas ativas; currentNode = o escolhido
        pendingNodes = nil,
        currentNode = nil,
        mapHistory = {}, -- array de { actNumber, floorInAct, type } escolhidos

        -- Estatísticas
        totalDamageDealt = 0,
        totalDamageTaken = 0,
        cardsPlayed = 0,

        -- Histórico de cartas adicionadas
        cardHistory = {},

        -- Upgrade map: { cardId -> levelInt }. Aplicado em buildPlayableDeck →
        -- todas as cópias da mesma carta no deck recebem +N stats. Forge node
        -- (RestScreen) incrementa via :upgradeCard(id).
        upgraded = {},

        -- Estado do jogador (pode ser expandido)
        playerState = {
            maxHealth = 100,
            currentHealth = 100,
            gold = 99
        }
    }
    
    -- Inicializa o deck com as cartas starter da classe
    self:initializeStarterDeck(classId)
    
    self.isRunActive = true
    return self.currentRun
end

-- Inicializa deck com cartas starter da classe
function RunManager:initializeStarterDeck(classId)
    local starterCards = self.cardRegistry:getStarterDeckForClass(classId)
    for _, cardId in ipairs(starterCards) do
        table.insert(self.currentRun.currentDeck, cardId)
    end
end

-- Retorna o deck atual da corrida
function RunManager:getCurrentDeck()
    if not self.currentRun then return {} end
    return self.currentRun.currentDeck
end

-- Ids normalizados do deck (entries podem ser string OU {id, edition, seal}).
-- Usado pelas ofertas (afinidade/anti-duplicata) e telas de forja.
function RunManager:getDeckCardIds()
    if not self.currentRun then return {} end
    local ids = {}
    for _, entry in ipairs(self.currentRun.currentDeck) do
        local id = type(entry) == "table" and entry.id or entry
        if id then table.insert(ids, id) end
    end
    return ids
end

-- Adiciona uma carta ao deck. meta opcional pra cartas com edition/seal vindas
-- de booster packs. Quando meta presente, deck guarda objeto {id, edition, seal};
-- caso contrário guarda só o id (back-compat com deck antigo).
function RunManager:addCardToDeck(cardId, meta)
    if not self.currentRun then
        return false
    end

    local entry = cardId
    if meta and (meta.edition or meta.seal) then
        entry = { id = cardId, edition = meta.edition, seal = meta.seal }
    end
    table.insert(self.currentRun.currentDeck, entry)
    self.currentRun.cardsAdded = self.currentRun.cardsAdded + 1

    table.insert(self.currentRun.cardHistory, {
        cardId = cardId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime(),
        meta = meta,
    })

    return true
end

-- ===== Jokers (run-scoped, separados do deck — padrão Balatro G.jokers) =====

-- Adiciona um joker à run. Não passa pelo deck/hand. meta opcional para
-- edition/seal vindos de Buffoon packs.
function RunManager:addJokerToRun(jokerId, meta)
    if not self.currentRun then return false end
    self.currentRun.jokers = self.currentRun.jokers or {}

    local entry = jokerId
    if meta and (meta.edition or meta.seal) then
        entry = { id = jokerId, edition = meta.edition, seal = meta.seal }
    end
    table.insert(self.currentRun.jokers, entry)

    table.insert(self.currentRun.cardHistory, {
        cardId = jokerId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime(),
        meta = meta,
        slot = "joker",
    })
    return true
end

-- Remove o primeiro joker com o id dado. Retorna true se removeu.
function RunManager:removeJokerFromRun(jokerId)
    if not self.currentRun or not self.currentRun.jokers then return false end
    for i, entry in ipairs(self.currentRun.jokers) do
        local id = type(entry) == "table" and entry.id or entry
        if id == jokerId then
            table.remove(self.currentRun.jokers, i)
            return true
        end
    end
    return false
end

-- Reconstrói as instâncias de joker (análogo a buildPlayableDeck mas só pra jokers).
-- Aplica edition/seal por cópia. Não aplica upgrades (jokers não são forjados).
function RunManager:buildJokerInstances()
    if not self.currentRun or not self.currentRun.jokers then return {} end

    local instances = {}
    for _, entry in ipairs(self.currentRun.jokers) do
        local id, edition, seal
        if type(entry) == "table" then
            id, edition, seal = entry.id, entry.edition, entry.seal
        else
            id = entry
        end

        local cardData = self.cardDatabase:getCard(id)
        if cardData then
            local instance = self.cardDatabase:createCardInstance(cardData)
            if edition then instance.edition = edition end
            if seal then instance.seal = seal end
            table.insert(instances, instance)
        else
            print("AVISO: Joker não encontrado no banco de dados: " .. tostring(id))
        end
    end
    return instances
end

-- Remove uma carta do deck (mecânica de upgrade/remoção)
function RunManager:removeCardFromDeck(cardId)
    if not self.currentRun then return false end
    
    for i, deckCardId in ipairs(self.currentRun.currentDeck) do
        if deckCardId == cardId then
            table.remove(self.currentRun.currentDeck, i)
            return true
        end
    end
    
    return false
end

-- Completa uma batalha e gera recompensas
function RunManager:completeBattle()
    if not self.currentRun then return nil end

    self.currentRun.battlesWon = self.currentRun.battlesWon + 1
    self.currentRun.currentFloor = self.currentRun.currentFloor + 1

    -- Gera 3 cartas de recompensa (padrão Slay the Spire)
    local cardRewards = self.cardRegistry:generateCardRewards(self.currentRun.classId, 3,
        { deckIds = self:getDeckCardIds() })

    return {
        cardRewards = cardRewards,
        gold = Rng.get():random("misc", 10, 25),
        floor = self.currentRun.currentFloor,
        canSkipReward = true -- Opção de pular recompensa
    }
end

-- ===== Fase 4: map/nodes =====

-- Gera pendingNodes para o proximo andar dentro do ato.
-- floorsPerAct: Fase 5 tornara dinamico; por ora usa o default do MapManager.
function RunManager:generateNextNodes(numNodes)
    if not self.currentRun then return nil end
    local MapManager = require("src.systems.MapManager")
    local act = self.currentRun.actNumber or 1
    local floorInAct = self.currentRun.floorInAct or 1
    self.currentRun.pendingNodes = MapManager.generate(floorInAct, act, numNodes or 3)
    return self.currentRun.pendingNodes
end

-- Confirma a escolha de um node e avanca floorInAct. Se ultrapassar floorsPerAct,
-- incrementa actNumber e zera floorInAct. Endless e disparado pelo ActSystem (Fase 5).
function RunManager:chooseNode(index)
    if not self.currentRun or not self.currentRun.pendingNodes then return nil end
    local node = self.currentRun.pendingNodes[index]
    if not node then return nil end

    self.currentRun.currentNode = node
    self.currentRun.pendingNodes = nil
    table.insert(self.currentRun.mapHistory, {
        actNumber = self.currentRun.actNumber,
        floorInAct = self.currentRun.floorInAct,
        type = node.type,
    })

    return node
end

-- Avanca floorInAct apos resolver um node (batalha vencida, loja saida, etc).
-- Retorna "act_complete" se cruzou para novo ato, "endless_start" se saiu do ultimo,
-- "advanced" caso normal.
function RunManager:advanceFloorInAct(totalActs)
    totalActs = totalActs or 3
    if not self.currentRun then return "advanced" end
    local MapManager = require("src.systems.MapManager")

    self.currentRun.floorInAct = self.currentRun.floorInAct + 1
    self.currentRun.currentFloor = self.currentRun.currentFloor + 1

    if self.currentRun.floorInAct > MapManager.FLOORS_PER_ACT then
        if self.currentRun.actNumber >= totalActs then
            self.currentRun.endlessMode = true
            self.currentRun.floorInAct = 1
            self.currentRun.actNumber = totalActs + 1 -- "ato endless"
            return "endless_start"
        end
        self.currentRun.actNumber = self.currentRun.actNumber + 1
        self.currentRun.floorInAct = 1
        return "act_complete"
    end
    return "advanced"
end

function RunManager:getCurrentNode()
    return self.currentRun and self.currentRun.currentNode
end

function RunManager:getPendingNodes()
    return self.currentRun and self.currentRun.pendingNodes
end

-- ===== Upgrade map (Fase 3.1 do refactor Balatro; infinito desde Jul/2026) =====

-- Cap por carta vem de Config.Game.UPGRADE_LEVEL_CAP (0 = SEM CAP — forja
-- infinita; o freio de balance é o custo: fogueira = 1 grátis por acampamento,
-- loja = custo crescente por forja paga). Valor > 0 restaura o teto antigo.
function RunManager.getUpgradeCap()
    local cap = Config.Game.UPGRADE_LEVEL_CAP
    if cap == nil then return 5 end
    return cap
end

-- Incrementa o nível de upgrade de uma carta. Aplica a TODAS as cópias dessa
-- carta no deck na próxima buildPlayableDeck (todas refletem o "+N").
-- Retorna o novo nível, ou nil se já está no cap (caller deve checar pra
-- bloquear a forge na UI). Com cap 0 (infinito) nunca retorna nil.
function RunManager:upgradeCard(cardId)
    if not self.currentRun then return 0 end
    self.currentRun.upgraded = self.currentRun.upgraded or {}
    local current = self.currentRun.upgraded[cardId] or 0
    local cap = RunManager.getUpgradeCap()
    if cap > 0 and current >= cap then
        return nil
    end
    local lvl = current + 1
    self.currentRun.upgraded[cardId] = lvl
    return lvl
end

-- True se a carta pode ser forjada novamente (não atingiu o cap E a forja
-- tem ALGO pra melhorar nela — carta sem stat básico nem effect upgradável
-- não entra na bigorna).
function RunManager:canUpgrade(cardId)
    if not self.currentRun then return false end
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData or next(RunManager.getForgeGains(cardData)) == nil then
        return false
    end
    local cap = RunManager.getUpgradeCap()
    if cap <= 0 then return true end
    local lvl = (self.currentRun.upgraded and self.currentRun.upgraded[cardId]) or 0
    return lvl < cap
end

-- Custo da PRÓXIMA forja comprada (oferta "Forja" da loja). Cresce por forja
-- PAGA na run: base × mult^n, teto em FORGE_COST_MAX. A da fogueira é grátis.
function RunManager:getPaidForgeCost()
    local n = (self.currentRun and self.currentRun.paidForges) or 0
    local cfg = Config.Offers
    local cost = cfg.FORGE_COST_BASE * (cfg.FORGE_COST_MULT ^ n)
    return math.min(cfg.FORGE_COST_MAX, math.floor(cost + 0.5))
end

-- Registra uma forja paga (chamado pela loja ao vender a oferta "Forja").
function RunManager:registerPaidForge()
    if not self.currentRun then return end
    self.currentRun.paidForges = (self.currentRun.paidForges or 0) + 1
end

-- Lê nível de upgrade. Default 0 se carta nunca forjada.
function RunManager:getUpgrades(cardId)
    if not self.currentRun or not self.currentRun.upgraded then return 0 end
    return self.currentRun.upgraded[cardId] or 0
end

-- Aplica +N ao instance criado. Ganhos por nível vêm de Config.Offers
-- (FORGE_ATK/DEF/EFFECT_PER_LVL — fonte única com a UI, que mostra o mesmo
-- número no tooltip/preview). Cost permanece igual — você pagou pra upgradar,
-- não vai pagar mais mana pra usar.
local UPGRADABLE_EFFECT_TYPES = {
    instant_heal = true, magic_damage = true, aoe_magic_damage = true,
    add_armor = true, damage_bonus = true, defense_bonus = true,
    damage_bonus_self = true, gain_strength = true, gain_dexterity = true,
}

-- ===== Regra de forja por CENÁRIO de carta (playtest Jul/2026) =====
-- Bug original: `if instance.defense` é true até pra defense=0 (0 é truthy em
-- Lua) — carta de ATAQUE PURO ganhava "+2 DEF" fantasma por nível e o tooltip
-- mostrava fielmente o absurdo. A forja melhora O QUE A CARTA TEM:
--   attack > 0      → +FORGE_ATK_PER_LVL por nível
--   defense > 0     → +FORGE_DEF_PER_LVL por nível
--   sem stat básico → +FORGE_EFFECT_PER_LVL no PRIMEIRO effect upgradável
--                     (cartas de efeito puro: poções, utilitárias)
--   nenhum ganho    → carta NÃO forjável (canUpgrade barra; picker esconde)
--   joker           → não forjável (invariante existente, nunca chega aqui)
-- getForgeGains é a FONTE ÚNICA: applyUpgradesToInstance, CardInfoDisplay e
-- RestScreen (preview + resultado) leem daqui — a UI nunca mente.
-- Matriz completa em memory/rng_and_offers.md §forja.
function RunManager.getForgeGains(cardData)
    if not cardData then return {} end
    local gains = {}
    local hasBasic = false
    if (cardData.attack or 0) > 0 then
        gains.atk = Config.Offers.FORGE_ATK_PER_LVL
        hasBasic = true
    end
    if (cardData.defense or 0) > 0 then
        gains.def = Config.Offers.FORGE_DEF_PER_LVL
        hasBasic = true
    end
    if not hasBasic and cardData.effects then
        for i, eff in ipairs(cardData.effects) do
            if eff.value and UPGRADABLE_EFFECT_TYPES[eff.type] then
                gains.effectIndex = i
                gains.effectType = eff.type
                gains.effect = Config.Offers.FORGE_EFFECT_PER_LVL
                break
            end
        end
    end
    return gains
end

function RunManager:applyUpgradesToInstance(instance, level)
    if not instance or not level or level <= 0 then return instance end
    instance.upgrades = level
    local gains = RunManager.getForgeGains(instance)
    if gains.atk then
        instance.attack = instance.attack + gains.atk * level
    end
    if gains.def then
        instance.defense = instance.defense + gains.def * level
    end
    if gains.effectIndex and instance.effects
        and instance.effects[gains.effectIndex] then
        local eff = instance.effects[gains.effectIndex]
        eff.value = eff.value + gains.effect * level
    end
    -- F5: re-renderiza a moldura DEPOIS dos stats upados — antes a arte era
    -- gerada no createCardInstance com os números base (carta forjada mentia
    -- na moldura) e sem o selo +N.
    local ok, img = pcall(function()
        return require("src.ui.CardFrame").render(instance)
    end)
    if ok and img then instance.image = img end
    return instance
end

-- Migra qualquer joker que esteja em currentDeck (saves antigos) para currentRun.jokers.
-- Idempotente: só roda quando encontra. Modifica currentDeck in-place.
function RunManager:_migrateJokersFromDeck()
    if not self.currentRun or not self.currentRun.currentDeck then return end
    self.currentRun.jokers = self.currentRun.jokers or {}
    for i = #self.currentRun.currentDeck, 1, -1 do
        local entry = self.currentRun.currentDeck[i]
        local cardId = type(entry) == "table" and entry.id or entry
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData and cardData.type == "joker" then
            table.insert(self.currentRun.jokers, entry)
            table.remove(self.currentRun.currentDeck, i)
            print("[RunManager] migrou joker de currentDeck → jokers: " .. tostring(cardId))
        end
    end
end

-- Converte deck para instâncias de cartas jogáveis. Aplica upgrades + edition/seal
-- por cópia individual (deck pode conter strings ou objetos {id, edition, seal}).
function RunManager:buildPlayableDeck()
    if not self.currentRun then return {} end

    -- Migração defensiva: garante que nenhum joker esteja em currentDeck antes
    -- de construir o deck jogável (saves antigos pré-Fase joker-split).
    self:_migrateJokersFromDeck()

    local playableCards = {}
    local upgradedMap = self.currentRun.upgraded or {}

    for _, entry in ipairs(self.currentRun.currentDeck) do
        local cardId, edition, seal
        if type(entry) == "table" then
            cardId = entry.id
            edition = entry.edition
            seal = entry.seal
        else
            cardId = entry
        end

        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            local cardInstance = self.cardDatabase:createCardInstance(cardData)
            local lvl = upgradedMap[cardId] or 0
            if lvl > 0 then
                self:applyUpgradesToInstance(cardInstance, lvl)
            end
            -- Edition/seal por cópia (vindo de booster pack).
            if edition then cardInstance.edition = edition end
            if seal then cardInstance.seal = seal end
            table.insert(playableCards, cardInstance)
        else
            print("AVISO: Carta não encontrada no banco de dados: " .. cardId)
        end
    end

    return playableCards
end

-- Estatísticas da corrida atual
function RunManager:getCurrentRunStats()
    if not self.currentRun then return nil end
    
    return {
        class = self.currentRun.className,
        floor = self.currentRun.currentFloor,
        battlesWon = self.currentRun.battlesWon,
        deckSize = #self.currentRun.currentDeck,
        cardsAdded = self.currentRun.cardsAdded,
        averageCardsPerFloor = self.currentRun.cardsAdded / math.max(1, self.currentRun.currentFloor - 1),
        
        -- Análise do deck
        deckComposition = self:analyzeDeckComposition()
    }
end

-- Analisa composição do deck atual
function RunManager:analyzeDeckComposition()
    if not self.currentRun then return {} end
    
    local composition = {
        attack = 0,
        defense = 0,
        joker = 0,
        totalCards = #self.currentRun.currentDeck,
        rarityDistribution = {
            common = 0,
            uncommon = 0,
            rare = 0
        }
    }
    
    for _, cardId in ipairs(self.currentRun.currentDeck) do
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            -- Conta tipos
            if cardData.type == "attack" then
                composition.attack = composition.attack + 1
            elseif cardData.type == "defense" then
                composition.defense = composition.defense + 1
            elseif cardData.type == "joker" then
                composition.joker = composition.joker + 1
            end
            
            -- Conta raridades
            local rarity = cardData.rarity or "common"
            composition.rarityDistribution[rarity] = (composition.rarityDistribution[rarity] or 0) + 1
        end
    end
    
    return composition
end

-- Persistência delegada ao SaveManager (atomic write + migrations).

function RunManager:saveRun()
    if not self.currentRun then return false, "sem run ativa" end
    -- Snapshot do RNG viaja no save: load restaura o estado EXATO de cada
    -- stream (getState/setState) — reabrir o jogo não re-rola nada.
    self.currentRun.rngState = Rng.get():getState()
    local ok, err = SaveManager.saveRun(self.currentRun)
    if not ok then
        print("[RunManager] falha ao salvar:", err)
        return false, err
    end
    return true
end

function RunManager:loadRun()
    local runData = SaveManager.loadRun()
    if not runData then return false, "nenhum save válido" end

    self.currentRun = runData
    self.isRunActive = true

    -- Restaura o RNG da run. Save antigo sem rngState: fromState devolve um
    -- Rng novo (seed fresca) — a run continua, só não reproduz o passado.
    Rng.setActive(Rng.fromState(runData.rngState))
    if not runData.rngState then
        print("[RunManager] save sem rngState (pré-seed) — RNG novo gerado")
    end
    return true
end

function RunManager:deleteSave()
    SaveManager.deleteRun()
end

function RunManager:hasSavedRun()
    return SaveManager.hasRun()
end

-- Termina a corrida atual
function RunManager:endRun(victory)
    if not self.currentRun then return nil end

    local finalStats = self:getCurrentRunStats()
    finalStats.victory = victory
    finalStats.finalScore = self:calculateFinalScore(victory)

    self.currentRun = nil
    self.isRunActive = false
    Rng.clearActive()

    return finalStats
end

-- Calcula pontuação final
function RunManager:calculateFinalScore(victory)
    if not self.currentRun then return 0 end
    
    local baseScore = self.currentRun.battlesWon * 100
    local floorBonus = self.currentRun.currentFloor * 50
    local victoryBonus = victory and 1000 or 0
    
    return baseScore + floorBonus + victoryBonus
end

-- Verifica se há uma corrida ativa
function RunManager:hasActiveRun()
    return self.isRunActive and self.currentRun ~= nil
end

-- Retorna informações da classe atual
function RunManager:getCurrentClassInfo()
    if not self.currentRun then return nil end
    return self.cardRegistry:getClassInfo(self.currentRun.classId)
end

return RunManager

