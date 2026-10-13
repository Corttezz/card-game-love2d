-- tools/test_sustain_knobs.lua
-- wip/sustain (Out/2026): os flags das 3 propostas de sustento DISPARAM de
-- verdade (senão a bateria mede um no-op) e, desligados, o jogo é o de antes.
--   love . test_one test_sustain_knobs

local TK = require("tools.testkit")
local M = {}

local function body()
    local t = TK.new("wip/sustain: fogueira, poção, elite por andar, vaga de sustento")
    TK.bootstrap()
    local Config = require("src.core.Config")
    local ActSystem = require("src.systems.ActSystem")
    local CG, CO = Config.Game, Config.Offers

    -- 1) defaults = jogo atual
    t:eq("REST_HEAL_PCT default 0,30", CG.REST_HEAL_PCT, 0.30)
    t:falsy("POTIONS desligadas por padrão", CG.POTIONS)
    t:falsy("ELITE_RAMP desligado por padrão", CG.ELITE_RAMP)
    -- Sustento garantido foi ADOTADO (13/Out/2026): o default é LIGADO.
    t:truthy("SUSTAIN_GUARANTEE ligado por padrão", CO.SUSTAIN_GUARANTEE)
    t:eq("SUSTAIN_WEIGHT_BONUS 1.0 por padrão", CO.SUSTAIN_WEIGHT_BONUS, 1.0)
    -- Daqui em diante o teste controla os dois knobs à mão (o teardown restaura).
    CO.SUSTAIN_GUARANTEE, CO.SUSTAIN_WEIGHT_BONUS = false, 0

    -- 2) elite por andar: só rebaixa, 1º andar = START, 8º = eliteHPMul
    local off1 = ActSystem.getEnemyStats(3, 1, "elite").health
    local off8 = ActSystem.getEnemyStats(3, 8, "elite").health
    local base1 = ActSystem.getEnemyStats(3, 1, "battle").health
    CG.ELITE_RAMP = true
    local on1 = ActSystem.getEnemyStats(3, 1, "elite").health
    local on8 = ActSystem.getEnemyStats(3, 8, "elite").health
    local on4 = ActSystem.getEnemyStats(3, 4, "elite").health
    CG.ELITE_RAMP = false
    t:check("ramp: 1º andar do A3 cai (" .. off1 .. " -> " .. on1 .. ")", on1 < off1)
    t:check("ramp: 1º andar ≈ base × 1,4 (" .. on1 .. " vs " .. math.floor(base1 * 1.4) .. ")",
        math.abs(on1 - base1 * 1.4) <= 2)
    t:eq("ramp: 8º andar inalterado", on8, off8)
    t:check("ramp: andar do meio fica entre os dois", on4 > on1 and on4 < off8)
    t:eq("ramp desligado volta ao valor antigo", ActSystem.getEnemyStats(3, 1, "elite").health, off1)

    -- 3) poção: cai de elite, cura 20%, 1 vaga, só com o flag
    local game = TK.newRunGame("warrior")
    local run = game.runManager.currentRun
    run.currentNode = { type = "elite" }
    game.turn = "player"
    game.player.health = 10
    t:falsy("sem flag: usePotion não bebe nada", (game:usePotion()))
    game._deathHandled = false
    game:_onEnemyDeath()
    t:eq("sem flag: elite não deixa poção", run.potions or 0, 0)
    CG.POTIONS = true
    game._deathHandled = false
    game:_onEnemyDeath()
    t:eq("com flag: elite deixa 1 poção", run.potions, 1)
    game._deathHandled = false
    game:_onEnemyDeath()
    t:eq("1 vaga: segunda elite não acumula", run.potions, 1)
    local ok, amt = game:usePotion()
    t:truthy("bebeu a poção", ok)
    t:eq("poção cura 20% da vida máxima", amt, math.floor(game.player.maxHealth * 0.2))
    t:eq("vida subiu", game.player.health, 10 + amt)
    t:eq("poção gasta", run.potions, 0)
    t:falsy("sem poção não bebe", (game:usePotion()))
    run.currentNode = { type = "battle" }
    game._deathHandled = false
    game:_onEnemyDeath()
    t:eq("batalha comum não deixa poção", run.potions, 0)
    CG.POTIONS = false

    -- 4) vaga de sustento na recompensa de elite/chefe (contexto único)
    local ShopSystem = require("src.systems.ShopSystem")
    local CardRegistry = require("src.systems.CardRegistry")
    run.currentNode = { type = "elite" }
    local ctx = ShopSystem.runContext(game, "rewards")
    t:eq("runContext: elite pisa uncommon", ctx.minRarity, "uncommon")
    t:eq("runContext: nodeType viaja", ctx.nodeType, "elite")
    t:truthy("runContext: pesos por ato", ctx.rarityWeights)
    run.currentNode = { type = "boss" }
    t:eq("runContext: chefe pisa rare", ShopSystem.runContext(game, "rewards").minRarity, "rare")
    t:falsy("runContext: loja não pisa raridade", ShopSystem.runContext(game, "shop").minRarity)
    run.currentNode = { type = "elite" }
    t:eq("deck inicial sem sustento", game.runManager.cardRegistry:countSustain(game.runManager:getDeckCardIds()), 0)

    local shop = game.shopSystem
    shop:setMode("rewards")
    shop:setContext(ShopSystem.runContext(game, "rewards"))
    shop:generateOffers()
    local anySlot = false
    for _, o in ipairs(shop:getCurrentOffers()) do if o.sustainSlot then anySlot = true end end
    t:falsy("guarantee desligado: nenhuma vaga reservada", anySlot)

    CO.SUSTAIN_GUARANTEE = true
    local hits, tries = 0, 0
    for _, cls in ipairs({ "warrior", "mage", "rogue" }) do
        local g = TK.newRunGame(cls)
        g.runManager.currentRun.currentNode = { type = "elite" }
        g.shopSystem:setMode("rewards")
        g.shopSystem:setContext(ShopSystem.runContext(g, "rewards"))
        g.shopSystem:generateOffers()
        local offers = g.shopSystem:getCurrentOffers()
        tries = tries + 1
        local first = offers[1]
        if first and first.sustainSlot and CardRegistry.isSustainCard(g.deckManager.cardDatabase:getCard(first.id)) then
            hits = hits + 1
        else
            print("  (" .. cls .. ": 1ª oferta " .. tostring(first and first.id) .. " sem sustento)")
        end
    end
    t:eq("com flag: 1ª vaga de elite é sustento nas 3 classes", hits, tries)
    -- deck já com 2 fontes: vaga volta a ser livre
    local g2 = TK.newRunGame("warrior")
    local reg = g2.runManager.cardRegistry
    local sustainId
    for id, cd in pairs(g2.deckManager.cardDatabase:getAllCards()) do
        if cd.class == "warrior" and CardRegistry.isSustainCard(cd) then sustainId = id; break end
    end
    t:truthy("guerreiro tem carta de sustento no catálogo", sustainId)
    if sustainId then
        g2:addCardToRun(sustainId); g2:addCardToRun(sustainId)
        t:check("deck com 2 fontes", reg:countSustain(g2.runManager:getDeckCardIds()) >= 2)
        g2.runManager.currentRun.currentNode = { type = "elite" }
        g2.shopSystem:setMode("rewards")
        g2.shopSystem:setContext(ShopSystem.runContext(g2, "rewards"))
        g2.shopSystem:generateOffers()
        local slot = false
        for _, o in ipairs(g2.shopSystem:getCurrentOffers()) do if o.sustainSlot then slot = true end end
        t:falsy("com 2 fontes no deck a vaga não é reservada", slot)
    end
    CO.SUSTAIN_GUARANTEE = false

    -- 5) peso extra: sustento sai mais com o bônus (amostra grande, mesma seed)
    local function sustainShare(bonus)
        CO.SUSTAIN_WEIGHT_BONUS = bonus
        TK.seedRng(4242)
        local g = TK.newRunGame("warrior")
        local n, s = 0, 0
        for _ = 1, 300 do
            local pick = g.runManager.cardRegistry:pickRewardCard({
                classId = "warrior", deckIds = g.runManager:getDeckCardIds(), actNumber = 1 })
            if pick then
                n = n + 1
                if CardRegistry.isSustainCard(g.deckManager.cardDatabase:getCard(pick.cardId)) then s = s + 1 end
            end
        end
        CO.SUSTAIN_WEIGHT_BONUS = 0
        return s / math.max(1, n)
    end
    local base, boosted = sustainShare(0), sustainShare(2.0)
    t:check(("peso extra sobe a fatia de sustento (%.0f%% -> %.0f%%)"):format(base * 100, boosted * 100),
        boosted > base)

    return t:done()
end

function M.run()
    local Config = require("src.core.Config")
    local saved = { rest = Config.Game.REST_HEAL_PCT, pot = Config.Game.POTIONS, ramp = Config.Game.ELITE_RAMP,
        sg = Config.Offers.SUSTAIN_GUARANTEE, sw = Config.Offers.SUSTAIN_WEIGHT_BONUS }
    local ok, res = pcall(body)
    Config.Game.REST_HEAL_PCT, Config.Game.POTIONS, Config.Game.ELITE_RAMP = saved.rest, saved.pot, saved.ramp
    Config.Offers.SUSTAIN_GUARANTEE, Config.Offers.SUSTAIN_WEIGHT_BONUS = saved.sg, saved.sw
    if not ok then error(res, 0) end
    return res
end

return M
