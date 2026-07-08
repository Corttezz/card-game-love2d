-- src/systems/RunManager.lua
-- Gerencia a "corrida" atual (run) como no Slay the Spire

local RunManager = {}
RunManager.__index = RunManager

local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local SaveManager  = require("engine.SaveManager")

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

    self.currentRun = {
        classId = classId,
        className = selectedClass.name,

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
    local cardRewards = self.cardRegistry:generateCardRewards(self.currentRun.classId, 3)

    return {
        cardRewards = cardRewards,
        gold = love.math.random(10, 25),
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

-- ===== Upgrade map (Fase 3.1 do refactor Balatro) =====

-- Cap por carta. Sem isso, forge stackava infinitamente: +1 atk × 20 = absurdo.
-- 5 níveis = +10 atk/def numa carta — já é forte sem virar bola de neve.
RunManager.UPGRADE_LEVEL_CAP = 5

-- Incrementa o nível de upgrade de uma carta. Aplica a TODAS as cópias dessa
-- carta no deck na próxima buildPlayableDeck (todas refletem o "+N").
-- Retorna o novo nível, ou nil se já está no cap (caller deve checar pra
-- bloquear a forge na UI).
function RunManager:upgradeCard(cardId)
    if not self.currentRun then return 0 end
    self.currentRun.upgraded = self.currentRun.upgraded or {}
    local current = self.currentRun.upgraded[cardId] or 0
    if current >= RunManager.UPGRADE_LEVEL_CAP then
        return nil
    end
    local lvl = current + 1
    self.currentRun.upgraded[cardId] = lvl
    return lvl
end

-- True se a carta pode ser forjada novamente (não atingiu o cap).
function RunManager:canUpgrade(cardId)
    if not self.currentRun then return false end
    local lvl = (self.currentRun.upgraded and self.currentRun.upgraded[cardId]) or 0
    return lvl < RunManager.UPGRADE_LEVEL_CAP
end

-- Lê nível de upgrade. Default 0 se carta nunca forjada.
function RunManager:getUpgrades(cardId)
    if not self.currentRun or not self.currentRun.upgraded then return 0 end
    return self.currentRun.upgraded[cardId] or 0
end

-- Aplica +N ao instance criado. Cada nível: +2 attack, +2 defense, +1 valor
-- do primeiro effect (se tipo numérico simples). Cost permanece igual — você
-- pagou pra upgradar, não vai pagar mais mana pra usar.
local UPGRADE_ATK_PER_LVL = 2
local UPGRADE_DEF_PER_LVL = 2
local UPGRADE_EFFECT_PER_LVL = 1
local UPGRADABLE_EFFECT_TYPES = {
    instant_heal = true, magic_damage = true, aoe_magic_damage = true,
    add_armor = true, damage_bonus = true, defense_bonus = true,
    damage_bonus_self = true, gain_strength = true, gain_dexterity = true,
}

function RunManager:applyUpgradesToInstance(instance, level)
    if not instance or not level or level <= 0 then return instance end
    instance.upgrades = level
    if instance.attack then
        instance.attack = instance.attack + UPGRADE_ATK_PER_LVL * level
    end
    if instance.defense then
        instance.defense = instance.defense + UPGRADE_DEF_PER_LVL * level
    end
    -- Boost no primeiro effect numérico simples (heurística pra healing/damage cards).
    if instance.effects and instance.effects[1] and instance.effects[1].value then
        local etype = instance.effects[1].type
        if UPGRADABLE_EFFECT_TYPES[etype] then
            instance.effects[1].value = instance.effects[1].value + UPGRADE_EFFECT_PER_LVL * level
        end
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

