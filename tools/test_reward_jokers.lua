local TK = require("tools.testkit")

local M = {}

local NODE_TYPES = { "battle", "elite", "mini_boss", "boss" }
local TRIALS = 400

local function fakeGame(classId, act, nodeType, deckIds, jokers)
    local run = {
        classId = classId, actNumber = act,
        currentNode = { type = nodeType },
        jokers = jokers or {},
    }
    return {
        selectedClass = classId,
        runManager = {
            currentRun = run,
            getDeckCardIds = function() return deckIds end,
        },
    }
end

local function rewardHasJoker(shop, cdb)
    local n = 0
    for _, o in ipairs(shop:getCurrentOffers()) do
        local cd = o.type == "card" and cdb:getCard(o.id)
        if cd and cd.type == "joker" then n = n + 1 end
    end
    return n
end

function M.measure(classId, act, nodeType, trials, seed, jokers)
    local ShopSystem = require("src.systems.ShopSystem")
    local CardRegistry = require("src.systems.CardRegistry")
    TK.seedRng(seed)
    local deck = CardRegistry.STARTER_DECKS[classId]
    local shop = ShopSystem:new()
    local hits, multi = 0, 0
    for _ = 1, trials do
        shop:setContext(ShopSystem.runContext(fakeGame(classId, act, nodeType, deck, jokers), "rewards"))
        shop:setMode("rewards")
        shop:generateOffers()
        local n = rewardHasJoker(shop, shop.cardDatabase)
        if n > 0 then hits = hits + 1 end
        if n > 1 then multi = multi + 1 end
    end
    return hits / trials, multi
end

function M.table(trials)
    trials = trials or TRIALS
    local out = {}
    for _, nodeType in ipairs(NODE_TYPES) do
        out[nodeType] = {}
        for act = 1, 6 do
            local sum = 0
            for ci, cls in ipairs({ "warrior", "mage", "rogue" }) do
                sum = sum + M.measure(cls, act, nodeType, trials, 9100 + act * 31 + ci * 7)
            end
            out[nodeType][act] = sum / 3
        end
    end
    return out
end

function M.printTable(t)
    print(string.format("%-10s %s", "no", "ato1   ato2   ato3   ato4   ato5   ato6"))
    for _, nodeType in ipairs(NODE_TYPES) do
        local row = {}
        for act = 1, 6 do row[#row + 1] = string.format("%5.1f%%", t[nodeType][act] * 100) end
        print(string.format("%-10s %s", nodeType, table.concat(row, " ")))
    end
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_reward_jokers")
    local Config = require("src.core.Config")
    local odds = Config.Offers.REWARD_JOKER_CHANCE

    local tab = M.table(TRIALS)
    M.printTable(tab)

    t:truthy("Config.Offers.REWARD_JOKER_CHANCE existe", type(odds) == "table")
    if type(odds) == "table" then
        for _, nodeType in ipairs(NODE_TYPES) do
            local want = odds[nodeType]
            for act = 1, 6 do
                local got = tab[nodeType][act]
                t:check(string.format("%s ato %d: %.1f%% ~ %.0f%% (+-6pp)", nodeType, act, got * 100, want * 100),
                    math.abs(got - want) <= 0.06)
            end
        end
        t:check("comum raro (<= 8% medio)", (function()
            local s = 0
            for act = 1, 6 do s = s + tab.battle[act] end
            return s / 6 <= 0.08
        end)())
        t:check("chefe > elite > comum", tab.boss[1] > tab.elite[1] and tab.elite[1] > tab.battle[1])
    end

    local ShopSystem = require("src.systems.ShopSystem")
    local _, multi = M.measure("warrior", 3, "boss", 200, 4242)
    t:eq("nunca mais de um coringa por recompensa", multi, 0)

    local shopHits = 0
    TK.seedRng(777)
    local shop = ShopSystem:new()
    for _ = 1, 200 do
        shop:setContext(ShopSystem.runContext(fakeGame("mage", 2, "shop", { "mage_zap" }), "shop"))
        shop:setMode("shop")
        shop:generateOffers()
        if rewardHasJoker(shop, shop.cardDatabase) > 0 then shopHits = shopHits + 1 end
    end
    t:check(string.format("loja segue oferecendo coringa (%d/200)", shopHits), shopHits > 20)

    local CardDatabase = require("src.systems.CardDatabase")
    local cdb = CardDatabase:new()
    local owned = {}
    for id, cd in pairs(cdb:getAllCards()) do
        if cd.type == "joker" then owned[#owned + 1] = id end
    end
    table.sort(owned)
    local allOwned = M.measure("rogue", 2, "boss", 100, 31337, owned)
    t:eq("todos os coringas possuidos: nenhum oferecido", allOwned, 0)

    TK.seedRng(5150)
    local shop2 = ShopSystem:new()
    local sustainOk, sustainN = 0, 0
    local CardRegistry = require("src.systems.CardRegistry")
    for _ = 1, 150 do
        shop2:setContext(ShopSystem.runContext(fakeGame("warrior", 2, "boss", { "warrior_strike", "warrior_defend" }), "rewards"))
        shop2:setMode("rewards")
        shop2:generateOffers()
        local first = shop2:getCurrentOffers()[1]
        sustainN = sustainN + 1
        if first and first.sustainSlot and CardRegistry.isSustainCard(cdb:getCard(first.id)) then
            sustainOk = sustainOk + 1
        end
    end
    t:eq("vaga de sustento garantida segue na 1a carta do chefe", sustainOk, sustainN)

    M.revealChecks(t)

    return t:done()
end

local function openRewards(battleOdds, reduced)
    local Config = require("src.core.Config")
    local odds = Config.Offers.REWARD_JOKER_CHANCE
    local saved = odds.battle
    odds.battle = battleOdds
    _G.gameSettings = _G.gameSettings or {}
    local savedReduced = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = reduced
    TK.seedRng(2024)
    local Game = require("src.core.Game")
    local CardRewardScreen = require("components.CardRewardScreen")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local screen = CardRewardScreen:new(game.shopSystem)
    screen.lastScreenWidth, screen.lastScreenHeight = love.graphics.getDimensions()
    screen:show(game, function() end, function() end, "rewards")
    odds.battle = saved
    local function restore() _G.gameSettings.reducedMotion = savedReduced end
    return screen, restore
end

local function revealed(screen)
    local list = {}
    for _, o in ipairs(screen.shopOffers) do
        if o._rareReveal then list[#list + 1] = o end
    end
    return list
end

local function pumpScreen(screen, secs)
    local EventManager = require("engine.EventManager")
    for _ = 1, math.floor(secs * 60) do
        EventManager.update(1 / 60)
        screen:update(1 / 60)
    end
end

function M.revealChecks(t)
    local RareReveal = require("src.ui.RareReveal")
    local CardDatabase = require("src.systems.CardDatabase")
    local cdb = CardDatabase:new()

    local screen, restore = openRewards(1, false)
    local list = revealed(screen)
    t:eq("com coringa: uma revelacao", #list, 1)
    local o = list[1]
    t:truthy("a revelacao e do coringa", o and cdb:getCard(o.id) and cdb:getCard(o.id).type == "joker")
    t:eq("coringa entra por ultimo (ultima vaga)", o and o._slot, #screen.shopOffers)
    t:truthy("coringa escondido no comeco (antes da carga)", o and screen:_isRareHidden(o))
    for _, b in ipairs(screen.cardButtons) do
        if b.onClick then b.onClick() end
    end
    t:falsy("carta escondida nao pode ser escolhida", screen.selectedOffer == o)
    screen:clearSelection()
    pumpScreen(screen, 0.6)
    t:truthy("ainda escondido durante a entrada das outras", o and screen:_isRareHidden(o))
    pumpScreen(screen, 3.4)
    t:falsy("revelado depois do atraso", o and screen:_isRareHidden(o))
    t:truthy("explosao disparou", o and o._rareReveal.burstDone)
    t:truthy("assinatura do coringa tocou", o and o._rareReveal.sigDone)
    t:truthy("revelacao assentou", o and RareReveal.settled(o._rareReveal))
    screen:hide()
    restore()

    screen, restore = openRewards(0, false)
    t:eq("sem coringa: nenhuma revelacao", #revealed(screen), 0)
    local anyJoker = false
    for _, so in ipairs(screen.shopOffers) do
        local cd = cdb:getCard(so.id)
        if cd and cd.type == "joker" then anyJoker = true end
    end
    t:falsy("sem coringa na oferta com chance 0", anyJoker)
    screen:hide()
    restore()

    screen, restore = openRewards(1, true)
    list = revealed(screen)
    t:eq("movimento reduzido: revelacao existe (selo)", #list, 1)
    t:falsy("movimento reduzido: nunca escondido", list[1] and screen:_isRareHidden(list[1]))
    pumpScreen(screen, 2.0)
    t:truthy("movimento reduzido: som tocou sem explosao visual", list[1] and list[1]._rareReveal.burstDone
        and not RareReveal.haloParams(list[1]._rareReveal, 120, 180).motion)
    screen:hide()
    restore()
end

return M
