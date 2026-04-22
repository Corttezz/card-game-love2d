-- src/systems/RunManager.lua
-- Gerencia a "corrida" atual (run) como no Slay the Spire

local RunManager = {}
RunManager.__index = RunManager

local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")

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

-- Adiciona uma carta ao deck (recompensa pós-batalha)
function RunManager:addCardToDeck(cardId)
    if not self.currentRun then 
        return false 
    end
    
    table.insert(self.currentRun.currentDeck, cardId)
    self.currentRun.cardsAdded = self.currentRun.cardsAdded + 1
    
    -- Registra no histórico
    table.insert(self.currentRun.cardHistory, {
        cardId = cardId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime()
    })
    
    return true
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

-- Converte deck para instâncias de cartas jogáveis
function RunManager:buildPlayableDeck()
    if not self.currentRun then return {} end
    
    local playableCards = {}
    
    for _, cardId in ipairs(self.currentRun.currentDeck) do
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            local cardInstance = self.cardDatabase:createCardInstance(cardData)
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

-- Serializa valor Lua para string executável via `return`.
-- Suporta number, boolean, string, table (keys string ou number).
local function serialize(o, indent)
    indent = indent or ""
    local t = type(o)
    if t == "number" or t == "boolean" then
        return tostring(o)
    elseif t == "string" then
        return string.format("%q", o)
    elseif t == "table" then
        local parts = { "{\n" }
        local next_indent = indent .. "  "
        for k, v in pairs(o) do
            local keyStr
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                keyStr = k .. " = "
            else
                keyStr = "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
            end
            parts[#parts + 1] = next_indent .. keyStr .. serialize(v, next_indent) .. ",\n"
        end
        parts[#parts + 1] = indent .. "}"
        return table.concat(parts)
    end
    return "nil"
end

local SAVE_FILE = "run.save.lua"

-- Salva a corrida atual em disco (love.filesystem — grava no save directory do jogador).
-- Retorna true se gravou, false/err caso contrário.
function RunManager:saveRun()
    if not self.currentRun then return false, "sem run ativa" end

    local payload = {
        version = "1.0",
        savedAt = os.time(),
        runData = self.currentRun,
    }

    local ok, err = love.filesystem.write(SAVE_FILE, "return " .. serialize(payload))
    if not ok then
        print("[RunManager] falha ao salvar:", err)
        return false, err
    end
    return true
end

-- Carrega do arquivo salvo. Retorna true se restaurou com sucesso.
function RunManager:loadRun()
    if not love.filesystem.getInfo(SAVE_FILE) then return false, "nenhum save" end

    local chunk, err = love.filesystem.load(SAVE_FILE)
    if not chunk then
        print("[RunManager] falha ao carregar save:", err)
        return false, err
    end

    local ok, payload = pcall(chunk)
    if not ok or type(payload) ~= "table" or not payload.runData then
        print("[RunManager] save corrompido")
        return false, "save corrompido"
    end

    self.currentRun = payload.runData
    self.isRunActive = true
    return true
end

-- Remove o arquivo de save (ex: ao concluir/abandonar run).
function RunManager:deleteSave()
    if love.filesystem.getInfo(SAVE_FILE) then
        love.filesystem.remove(SAVE_FILE)
    end
end

-- Informa se existe um save gravado.
function RunManager:hasSavedRun()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
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

