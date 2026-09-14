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
        -- COLEÇÃO possuída (ilimitada). Reconstruído em jokerSlots via
        -- buildJokerInstances() (só os ATIVOS).
        jokers = {},
        -- Flags de "ativo" paralelas a jokers (jokerActive[i] ↔ jokers[i]).
        -- Só até MAX_JOKER_SLOTS podem estar ativos; o resto fica na bancada.
        -- O jogador troca quais ativar pelo Gerenciador de Coringas.
        jokerActive = {},

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

        -- ROTEIRO da run (Set/2026): uma entrada por NÓ VISITADO, com o que
        -- foi ESCOLHIDO ali. É o que a tela de Roteiro (RunJournalScreen) lê.
        -- Entrada aberta em journalBegin (chooseNode) e fechada em journalEnd
        -- (showMapSelection); as aquisições no meio caem na entrada aberta.
        -- Só tipos serializáveis (number/string/boolean/table) — o save é o
        -- currentRun inteiro via SaveManager.serialize.
        journal = {},
        journalOpen = nil,  -- índice da entrada em aberto (nil = nenhuma)

        -- Estatísticas
        totalDamageDealt = 0,
        totalDamageTaken = 0,
        cardsPlayed = 0,

        -- Histórico de cartas adicionadas
        cardHistory = {},

        -- LINHA DE BASE legada de forja: { cardId -> levelInt }. Desde a forja
        -- POR CÓPIA (Set/2026) nada escreve aqui — o nível novo mora em
        -- currentDeck[i].up. Fica pra saves antigos continuarem lendo o nível
        -- que tinham (ver getEntryLevel).
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

    -- Roteiro: no-op silencioso no deck inicial (nenhum nó aberto ainda).
    self:journalNote({ kind = "card", id = cardId,
                       edition = meta and meta.edition })

    return true
end

-- ===== Jokers (run-scoped, separados do deck — padrão Balatro G.jokers) =====
--
-- MODELO COLEÇÃO + BANCADA (Jul/2026): a run POSSUI jokers ilimitados
-- (currentRun.jokers). Só até MAX_JOKER_SLOTS ficam ATIVOS (jokerActive[i]);
-- os demais ficam na bancada. jokerSlots (instâncias jogáveis) é construído
-- SÓ dos ativos. Comprar um 4º joker NÃO o perde mais — entra na bancada, e o
-- jogador troca os ativos pelo Gerenciador de Coringas. Isso vira estratégia:
-- montar/ajustar o conjunto de coringas ao longo da run.

function RunManager:getMaxJokerSlots()
    -- currentRun.maxJokerSlots é espelhado por Game:recomputeMaxJokerSlots
    -- (bônus de slot da edition Negative). Sem run/sem espelho → base do Config.
    return (self.currentRun and self.currentRun.maxJokerSlots)
        or (Config.Game and Config.Game.MAX_JOKER_SLOTS) or 3
end

-- Nº de coringas atualmente ativos.
function RunManager:getActiveJokerCount()
    if not self.currentRun then return 0 end
    local act = self.currentRun.jokerActive or {}
    local n = 0
    for i = 1, #(self.currentRun.jokers or {}) do
        if act[i] then n = n + 1 end
    end
    return n
end

-- Garante que jokerActive existe e tem o mesmo tamanho de jokers. Saves antigos
-- (sem jokerActive) ativam os primeiros MAX_JOKER_SLOTS; o resto fica na bancada.
function RunManager:_ensureJokerActive()
    if not self.currentRun then return end
    self.currentRun.jokers = self.currentRun.jokers or {}
    local act = self.currentRun.jokerActive
    if not act then
        act = {}
        local cap = self:getMaxJokerSlots()
        for i = 1, #self.currentRun.jokers do
            act[i] = (i <= cap)
        end
        self.currentRun.jokerActive = act
    else
        -- normaliza tamanho + reforça o cap (nunca mais ativos que o teto)
        local cap = self:getMaxJokerSlots()
        local active = 0
        for i = 1, #self.currentRun.jokers do
            if act[i] == nil then act[i] = false end
            if act[i] then
                active = active + 1
                if active > cap then act[i] = false end
            end
        end
    end
end

-- Adiciona um joker à COLEÇÃO da run. Não passa pelo deck/hand. meta opcional
-- para edition/seal vindos de Buffoon packs. Ativa automaticamente se houver
-- slot livre; senão entra na bancada. Retorna (index, ativado?).
function RunManager:addJokerToRun(jokerId, meta)
    if not self.currentRun then return nil, false end
    self.currentRun.jokers = self.currentRun.jokers or {}
    self:_ensureJokerActive()

    local entry = jokerId
    if meta and (meta.edition or meta.seal) then
        entry = { id = jokerId, edition = meta.edition, seal = meta.seal }
    end
    table.insert(self.currentRun.jokers, entry)
    local idx = #self.currentRun.jokers

    -- auto-ativa se ainda há slot livre
    local activated = self:getActiveJokerCount() < self:getMaxJokerSlots()
    self.currentRun.jokerActive[idx] = activated

    table.insert(self.currentRun.cardHistory, {
        cardId = jokerId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime(),
        meta = meta,
        slot = "joker",
    })

    self:journalNote({ kind = "joker", id = jokerId, active = activated,
                       edition = meta and meta.edition })

    return idx, activated
end

-- Remove o joker de um índice da coleção (e sua flag). Retorna true se removeu.
function RunManager:removeJokerAt(index)
    if not self.currentRun or not self.currentRun.jokers then return false end
    if not self.currentRun.jokers[index] then return false end
    self:_ensureJokerActive()
    table.remove(self.currentRun.jokers, index)
    table.remove(self.currentRun.jokerActive, index)
    return true
end

-- Remove o primeiro joker com o id dado. Retorna true se removeu.
function RunManager:removeJokerFromRun(jokerId)
    if not self.currentRun or not self.currentRun.jokers then return false end
    self:_ensureJokerActive()
    for i, entry in ipairs(self.currentRun.jokers) do
        local id = type(entry) == "table" and entry.id or entry
        if id == jokerId then
            table.remove(self.currentRun.jokers, i)
            table.remove(self.currentRun.jokerActive, i)
            return true
        end
    end
    return false
end

-- Ativa/desativa o joker de um índice, respeitando o teto de slots. Retorna
-- (ok, motivo). Motivo "cap" = tentou ativar com os slots cheios.
function RunManager:setJokerActive(index, active)
    if not self.currentRun then return false, "no_run" end
    self:_ensureJokerActive()
    if not self.currentRun.jokers[index] then return false, "invalid" end
    if active and not self.currentRun.jokerActive[index] then
        if self:getActiveJokerCount() >= self:getMaxJokerSlots() then
            return false, "cap"
        end
    end
    self.currentRun.jokerActive[index] = active and true or false
    return true
end

function RunManager:isJokerActive(index)
    if not self.currentRun then return false end
    self:_ensureJokerActive()
    return self.currentRun.jokerActive[index] and true or false
end

-- Constrói uma instância de joker a partir de uma entry (string ou tabela).
function RunManager:_instanceFromJokerEntry(entry)
    local id, edition, seal
    if type(entry) == "table" then
        id, edition, seal = entry.id, entry.edition, entry.seal
    else
        id = entry
    end
    local cardData = self.cardDatabase:getCard(id)
    if not cardData then
        print("AVISO: Joker não encontrado no banco de dados: " .. tostring(id))
        return nil
    end
    local instance = self.cardDatabase:createCardInstance(cardData)
    if edition then instance.edition = edition end
    if seal then instance.seal = seal end
    return instance
end

-- Reconstrói as instâncias de joker ATIVAS (as que vão pra jokerSlots).
-- Aplica edition/seal por cópia. Não aplica upgrades (jokers não são forjados).
function RunManager:buildJokerInstances()
    if not self.currentRun or not self.currentRun.jokers then return {} end
    self:_ensureJokerActive()

    local instances = {}
    for i, entry in ipairs(self.currentRun.jokers) do
        if self.currentRun.jokerActive[i] then
            local inst = self:_instanceFromJokerEntry(entry)
            if inst then
                inst._ownedIndex = i
                table.insert(instances, inst)
            end
        end
    end
    return instances
end

-- Constrói instâncias de TODOS os jokers possuídos (ativos + bancada), cada uma
-- marcada com _ownedIndex e _active. Usado pelo Gerenciador de Coringas.
function RunManager:buildAllJokerInstances()
    if not self.currentRun or not self.currentRun.jokers then return {} end
    self:_ensureJokerActive()

    local instances = {}
    for i, entry in ipairs(self.currentRun.jokers) do
        local inst = self:_instanceFromJokerEntry(entry)
        if inst then
            inst._ownedIndex = i
            inst._active = self.currentRun.jokerActive[i] and true or false
            table.insert(instances, inst)
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
            self:journalNote({ kind = "remove", id = cardId })
            return true
        end
    end

    return false
end

-- P3.1 (rebalance Jul/2026): RunManager:completeBattle REMOVIDO — era caminho
-- MORTO (único caller: Game:completeBattle, que também não tem caller nenhum)
-- e usava o rollRarity default 37/37/25/1 fora do pipeline vivo de ofertas
-- (CardRewardScreen → ShopSystem → pickRewardCard, com pesos POR ATO). O fluxo
-- real de recompensa pós-batalha é showCardRewards em main.lua.

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
--
-- snapshot opcional { hp, maxHp, gold }: abre a entrada do ROTEIRO com o estado
-- do jogador ANTES do nó (o caller tem o Game; o RunManager não).
function RunManager:chooseNode(index, snapshot)
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

    self:journalBegin(node, snapshot)

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

-- ============================================================================
-- ROTEIRO DA RUN (journal) — Set/2026
-- ============================================================================
-- "um mapa de tudo o que a gente já fez, tudo o que a gente já escolheu, só
-- para acompanhar ato por ato" (pedido do dono). O que existia antes era
-- `mapHistory`, que guarda ato/andar/tipo e NUNCA foi lido por ninguém — o
-- roteiro estende esse registro com o RESULTADO e as ESCOLHAS de cada nó.
--
-- Ciclo de vida de uma entrada:
--   journalBegin(node, snapshot)  ← chooseNode          (abre, grava hp/ouro de entrada)
--   journalNote{...}              ← sinks do RunManager (carta/coringa/forja/remoção)
--   journalEnd(snapshot)          ← showMapSelection    (fecha, grava hp/ouro de saída)
--
-- Instrumentar os sinks DAQUI (addCardToDeck, addJokerToRun, upgradeCard,
-- registerPaidForge, removeCardFromDeck) cobre loja, recompensa, fogueira,
-- eventos e packs sem espalhar chamadas por cinco telas.
--
-- Persistência: `journal` é só number/string/boolean/table, então viaja no
-- save junto do resto do currentRun — sem migration. Save antigo entra com
-- journal nil; getJournal() faz backfill a partir do mapHistory.

-- Entrada atualmente aberta, ou nil.
function RunManager:_openJournalEntry()
    local run = self.currentRun
    if not run or not run.journalOpen then return nil end
    return run.journal and run.journal[run.journalOpen]
end

-- Abre a entrada do nó. snapshot = { hp, maxHp, gold } (opcional).
function RunManager:journalBegin(node, snapshot)
    local run = self.currentRun
    if not run or not node then return nil end
    run.journal = run.journal or {}
    snapshot = snapshot or {}

    -- Fecha uma entrada esquecida em aberto (nó que resolveu por um caminho
    -- que não passou pelo journalEnd) em vez de empilhar entradas zumbis.
    if run.journalOpen then
        self:journalEnd(snapshot)
    end

    table.insert(run.journal, {
        act    = run.actNumber or 1,
        floor  = run.floorInAct or 1,
        -- andar GLOBAL: em endless o par (act, floor) se repete (act trava em
        -- totalActs+1 e floor cicla 1..8), então ele não identifica um nó.
        gfloor = run.currentFloor or 1,
        type   = node.type,
        hpIn   = snapshot.hp,
        maxHp  = snapshot.maxHp,
        goldIn = snapshot.gold,
        gains  = {},
        -- os.time() e NAO love.timer.getTime(): getTime e relativo a sessao e
        -- vira lixo depois de um load (armadilha ja existente no cardHistory).
        at     = os.time(),
    })
    run.journalOpen = #run.journal
    return run.journal[run.journalOpen]
end

-- Anexa uma escolha à entrada aberta. entry = { kind, id, lvl?, label? }.
-- No-op LEGÍTIMO quando não há nó aberto: deck inicial da classe, efeitos de
-- teste e qualquer aquisição fora de um nó. Não é fallback silencioso de
-- recurso faltando — por isso vai em trace, não em warn.
function RunManager:journalNote(entry)
    if not entry then return false end
    local open = self:_openJournalEntry()
    if not open then
        local Debug = require("src.core.Debug")
        Debug.trace("[roteiro] nota fora de no:", entry.kind, tostring(entry.id))
        return false
    end
    open.gains = open.gains or {}
    table.insert(open.gains, entry)
    return true
end

-- Registra o evento sorteado e a opção escolhida na entrada aberta.
function RunManager:journalEvent(eventId, optionIndex, optionLabel)
    local open = self:_openJournalEntry()
    if not open then return false end
    if eventId then open.eventId = eventId end
    if optionIndex then open.optionIndex = optionIndex end
    if optionLabel then open.optionLabel = optionLabel end
    return true
end

-- Fecha a entrada aberta. Idempotente: showMapSelection pode rodar duas vezes
-- (o guard de pendingNodes existe justamente porque isso acontece).
function RunManager:journalEnd(snapshot)
    local run = self.currentRun
    if not run or not run.journalOpen then return false end
    local open = run.journal and run.journal[run.journalOpen]
    run.journalOpen = nil
    if not open then return false end
    snapshot = snapshot or {}
    open.hpOut   = snapshot.hp
    open.goldOut = snapshot.gold
    if snapshot.maxHp then open.maxHp = snapshot.maxHp end
    return true
end

-- Roteiro pronto pra UI: os nós na ORDEM em que foram visitados, com backfill
-- das runs que começaram antes deste sistema existir.
--
-- Ordem cronológica (e não ordenação por ato/andar) porque em endless o par
-- (act, floor) se repete e deixaria de ser chave.
--
-- Backfill: `mapHistory` e `journal` são alimentados na MESMA chamada
-- (chooseNode), então as J entradas do journal são sempre os J últimos nós.
-- Os `#mapHistory - #journal` primeiros são os nós anteriores a esta feature:
-- entram como entradas `partial = true` (a tela diz "sem detalhes" em vez de
-- fingir que o nó não teve escolhas). Uma run em andamento ganha o caminho
-- retroativo sem duplicar nada.
function RunManager:getJournal()
    local run = self.currentRun
    if not run then return {} end

    local mh = run.mapHistory or {}
    local jn = run.journal or {}
    local legacyCount = math.max(0, #mh - #jn)

    local out = {}
    for k = 1, legacyCount do
        local h = mh[k]
        table.insert(out, {
            act = h.actNumber or 1,
            floor = h.floorInAct or 1,
            gfloor = k,
            type = h.type,
            gains = {},
            partial = true,
        })
    end
    for _, e in ipairs(jn) do
        table.insert(out, e)
    end
    return out
end

-- True se a entrada é a que está em aberto agora (o nó em que o jogador está).
function RunManager:isJournalEntryOpen(entry)
    local open = self:_openJournalEntry()
    return open ~= nil and open == entry
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

-- ===== Forja POR CÓPIA (Set/2026) =====
--
-- ANTES: o nível morava em currentRun.upgraded[cardId] — um mapa POR ID. Duas
-- "Golpe" no deck eram, pra forja, a MESMA carta: forjar uma subia as duas. Foi
-- por isso que o picker da bigorna deduplicava a grade (mostrar duas cartas
-- idênticas que sempre andam juntas é mentira de UI) — e a queixa do dono
-- ("se eu tiver duas cartas iguais, na tela de forjar só aparece uma") é a
-- ponta visível disso.
--
-- AGORA: o nível mora NA CÓPIA, no próprio item de currentDeck (campo `up`).
-- A identidade de uma cópia é o ÍNDICE dela em currentDeck — nunca o id.
--
-- Back-compat SEM migração destrutiva: o nível efetivo de uma cópia é
--     entry.up  OU  currentRun.upgraded[id]  OU  0
-- (ver getEntryLevel). Save antigo continua lendo o mapa por id como LINHA DE
-- BASE compartilhada; a primeira forja daquela cópia grava `up` e a partir daí
-- ela anda sozinha. Nada se perde e nenhuma ordem de migração importa.

-- Nível de forja de UMA CÓPIA. `entry` é um item de currentDeck: string (id)
-- OU { id, edition, seal, up }.
function RunManager:getEntryLevel(entry)
    if entry == nil then return 0 end
    if type(entry) == "table" then
        if entry.up then return entry.up end
        local legacy = self.currentRun and self.currentRun.upgraded
        return (legacy and legacy[entry.id]) or 0
    end
    local legacy = self.currentRun and self.currentRun.upgraded
    return (legacy and legacy[entry]) or 0
end

-- Id de uma entrada do deck (string OU {id,...}).
function RunManager.entryId(entry)
    if entry == nil then return nil end
    if type(entry) == "table" then return entry.id end
    return entry
end

-- Nível da cópia no índice `index` de currentDeck.
function RunManager:getUpgradesAt(index)
    if not self.currentRun then return 0 end
    return self:getEntryLevel(self.currentRun.currentDeck[index])
end

-- Promove a entrada do índice a TABELA (é onde o nível por cópia mora) e
-- devolve a tabela. Preserva edition/seal e a linha de base legada.
function RunManager:_entryTableAt(index)
    local deck = self.currentRun and self.currentRun.currentDeck
    local entry = deck and deck[index]
    if not entry then return nil end
    if type(entry) == "table" then
        entry.up = entry.up or self:getEntryLevel(entry)
        return entry
    end
    local t = { id = entry, up = self:getEntryLevel(entry) }
    deck[index] = t
    return t
end

-- Lista NORMALIZADA de cópias do deck, uma entrada POR CÓPIA (duas "Golpe"
-- viram duas entradas). É o que as telas de forja/remoção/duplicação devem
-- percorrer — percorrer ids colapsa cópias.
function RunManager:getDeckCopies()
    local out = {}
    if not self.currentRun then return out end
    for i, entry in ipairs(self.currentRun.currentDeck) do
        local id = RunManager.entryId(entry)
        if id then
            table.insert(out, {
                index = i,
                id = id,
                level = self:getEntryLevel(entry),
                edition = type(entry) == "table" and entry.edition or nil,
                seal = type(entry) == "table" and entry.seal or nil,
            })
        end
    end
    return out
end

-- True se ALGUMA carta da run já foi forjada (conquista "sem_rascunhos").
-- Precisa olhar as duas fontes: o mapa legado E o `up` por cópia.
function RunManager:hasAnyUpgrade()
    if not self.currentRun then return false end
    if next(self.currentRun.upgraded or {}) then return true end
    for _, entry in ipairs(self.currentRun.currentDeck or {}) do
        if type(entry) == "table" and (entry.up or 0) > 0 then return true end
    end
    return false
end

-- Forja UMA CÓPIA (índice em currentDeck). Retorna o novo nível, ou nil se a
-- cópia não existe / já está no cap. Com cap 0 (infinito) nunca retorna nil.
function RunManager:upgradeCardAt(index)
    if not self.currentRun then return nil end
    local entry = self.currentRun.currentDeck[index]
    if not entry then
        print("[RunManager] upgradeCardAt: indice fora do deck: " .. tostring(index))
        return nil
    end
    local current = self:getEntryLevel(entry)
    local cap = RunManager.getUpgradeCap()
    if cap > 0 and current >= cap then
        return nil
    end
    local t = self:_entryTableAt(index)
    if not t then return nil end
    t.up = current + 1
    -- Roteiro: a forja é anotada AQUI e não em registerPaidForge — este é o
    -- ponto que sabe O QUÊ foi forjado (fogueira, loja e eventos passam todos
    -- por aqui); registerPaidForge só conta o custo e duplicaria a entrada.
    self:journalNote({ kind = "forge", id = t.id, lvl = t.up })
    return t.up
end

-- True se a CÓPIA do índice pode ser forjada (tem ganho E não bateu o cap).
function RunManager:canUpgradeAt(index)
    if not self.currentRun then return false end
    local entry = self.currentRun.currentDeck[index]
    local id = RunManager.entryId(entry)
    if not id then return false end
    local cardData = self.cardDatabase:getCard(id)
    if not cardData or next(RunManager.getForgeGains(cardData)) == nil then
        return false
    end
    local cap = RunManager.getUpgradeCap()
    if cap <= 0 then return true end
    return self:getEntryLevel(entry) < cap
end

-- Remove UMA CÓPIA pelo índice (a que o jogador apontou, com o nível dela).
-- removeCardFromDeck(id) remove a PRIMEIRA cópia — errado quando o jogador
-- escolheu a terceira.
function RunManager:removeCardAt(index)
    if not self.currentRun then return false end
    local entry = self.currentRun.currentDeck[index]
    if not entry then return false end
    local id = RunManager.entryId(entry)
    table.remove(self.currentRun.currentDeck, index)
    self:journalNote({ kind = "remove", id = id })
    return true
end

-- Duplica UMA CÓPIA pelo índice. A cópia nova nasce igual à escolhida — mesmo
-- edition/seal e MESMO nível de forja (duplicar "Golpe +2" entrega "Golpe +2",
-- não uma Golpe crua). Retorna o índice da nova cópia.
function RunManager:duplicateCardAt(index)
    if not self.currentRun then return nil end
    local entry = self.currentRun.currentDeck[index]
    if not entry then return nil end
    local id = RunManager.entryId(entry)
    local lvl = self:getEntryLevel(entry)
    local meta = nil
    if type(entry) == "table" and (entry.edition or entry.seal) then
        meta = { edition = entry.edition, seal = entry.seal }
    end
    if not self:addCardToDeck(id, meta) then return nil end
    local newIndex = #self.currentRun.currentDeck
    if lvl > 0 then
        local t = self:_entryTableAt(newIndex)
        if t then t.up = lvl end
    end
    return newIndex
end

-- Forja POR ID (legado — eventos, autoplay e a loja, que não têm índice em
-- mão). Escolhe UMA cópia: a de MENOR nível entre as forjáveis, pra que forjar
-- "Golpe" repetidamente espalhe os níveis em vez de empilhar tudo numa só.
-- Retorna o novo nível, ou nil se nenhuma cópia dessa carta pode ser forjada.
function RunManager:upgradeCard(cardId)
    if not self.currentRun then return 0 end
    local best, bestLvl = nil, nil
    for i, entry in ipairs(self.currentRun.currentDeck) do
        if RunManager.entryId(entry) == cardId and self:canUpgradeAt(i) then
            local lvl = self:getEntryLevel(entry)
            if not bestLvl or lvl < bestLvl then best, bestLvl = i, lvl end
        end
    end
    if not best then
        -- Sem fallback silencioso: quem chamou achou que tinha essa carta.
        print("[RunManager] upgradeCard: nenhuma copia forjavel de " .. tostring(cardId))
        return nil
    end
    return self:upgradeCardAt(best)
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
    -- Com cap finito: basta UMA cópia abaixo do teto. (Sem cópia no deck cai
    -- na linha de base legada — o comportamento antigo.)
    local any = false
    for i, entry in ipairs(self.currentRun.currentDeck or {}) do
        if RunManager.entryId(entry) == cardId then
            any = true
            if self:getEntryLevel(entry) < cap then return true end
        end
    end
    if any then return false end
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

-- Lê nível de upgrade POR ID (legado). Com nível por cópia não existe "o"
-- nível de uma carta: devolve o MAIOR entre as cópias no deck (é o que
-- interessa a quem pergunta "essa carta já foi forjada?"). Quem precisa de uma
-- cópia específica usa getUpgradesAt(index).
function RunManager:getUpgrades(cardId)
    if not self.currentRun then return 0 end
    local best = 0
    for _, entry in ipairs(self.currentRun.currentDeck or {}) do
        if RunManager.entryId(entry) == cardId then
            best = math.max(best, self:getEntryLevel(entry))
        end
    end
    -- Carta fora do deck (já removida): resta a linha de base legada.
    if best == 0 and self.currentRun.upgraded then
        best = self.currentRun.upgraded[cardId] or 0
    end
    return best
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
    self:_ensureJokerActive()   -- flags coerentes ANTES de migrar
    local cap = self:getMaxJokerSlots()
    -- percorre em ordem crescente pra preservar a ordem original dos jokers
    for i = 1, #self.currentRun.currentDeck do
        local entry = self.currentRun.currentDeck[i]
        local cardId = type(entry) == "table" and entry.id or entry
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData and cardData.type == "joker" then
            table.insert(self.currentRun.jokers, entry)
            -- migrado ativa se ainda há slot livre (senão vai pra bancada)
            local activated = self:getActiveJokerCount() < cap
            self.currentRun.jokerActive[#self.currentRun.jokers] = activated
            print("[RunManager] migrou joker de currentDeck → jokers: " .. tostring(cardId))
        end
    end
    -- remove os jokers do deck (de trás pra frente)
    for i = #self.currentRun.currentDeck, 1, -1 do
        local entry = self.currentRun.currentDeck[i]
        local cardId = type(entry) == "table" and entry.id or entry
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData and cardData.type == "joker" then
            table.remove(self.currentRun.currentDeck, i)
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
            -- Nível POR CÓPIA (entry.up); o mapa por id fica como linha de base
            -- pra saves anteriores à forja por cópia.
            local lvl = (type(entry) == "table" and entry.up)
                or upgradedMap[cardId] or 0
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

