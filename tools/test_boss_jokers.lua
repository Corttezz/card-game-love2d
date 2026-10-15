local TK = require("tools.testkit")

local M = {}

local BOSSES = {
    carrion_king   = "joker_boss_carrion",
    tower_lich     = "joker_boss_lich",
    abyss_tyrant   = "joker_boss_tyrant",
    winter_monarch = "joker_boss_winter",
    rot_colossus   = "joker_boss_colossus",
    eclipse_queen  = "joker_boss_eclipse",
}

local function fakeBoss(id, run)
    return {
        enemy = { spriteId = id, isBoss = true, isAlive = function() return true end },
        _deathHandled = false,
        runManager = run and { currentRun = run } or nil,
    }
end

local function body()
    local t = TK.new("coringa do chefe: carta, oferta, cinematica")
    TK.bootstrap()
    local BossJokers = require("src.systems.BossJokers")
    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.data.card_art")
    local I18n = require("src.i18n.I18n")

    for bossId, cardId in pairs(BOSSES) do
        local cd = CardDatabase:getCard(cardId)
        t:truthy(bossId .. ": carta existe", cd)
        t:eq(bossId .. ": mapeado pelo bossId", BossJokers.cardFor(bossId), cardId)
        t:eq(bossId .. ": e coringa", cd and cd.type, "joker")
        t:eq(bossId .. ": lendaria", cd and cd.rarity, "legendary")
        t:eq(bossId .. ": classe propria de chefe", cd and cd.class, "boss")
        t:truthy(bossId .. ": atlas", CardArt[cardId] and CardArt[cardId].icon == cardId)
        t:truthy(bossId .. ": icone", love.filesystem.getInfo("assets/sprites/icons/" .. cardId .. ".png"))
        t:truthy(bossId .. ": icone animado", love.filesystem.getInfo("assets/sprites/icons_anim/" .. cardId .. "/frame_000.png"))
        t:truthy(bossId .. ": assinatura sonora", love.filesystem.getInfo("audio/sfx/joker-sig/" .. cardId .. ".mp3"))
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            I18n.setLocale(loc)
            local name = I18n.cardName(cardId)
            local desc = I18n.cardDesc(cardId)
            t:truthy(bossId .. ": nome " .. loc, name ~= "" and name ~= cardId)
            t:falsy(bossId .. ": desc sem placeholder " .. loc, desc:find("{", 1, true))
        end
        I18n.setLocale("pt_BR")
    end
    t:eq("seis coringas de chefe", #BossJokers.all(), 6)

    local CardRegistry = require("src.systems.CardRegistry")
    local reg = CardRegistry:new()
    for _, cls in ipairs({ "warrior", "mage", "rogue" }) do
        for _, r in ipairs({ "rare", "legendary" }) do
            for _, id in ipairs(reg:_poolFor(cls, r)) do
                t:falsy("pool " .. cls .. "/" .. r .. " sem coringa de chefe (" .. id .. ")",
                    BossJokers.isBossJoker(id))
            end
        end
    end
    for _, id in ipairs(reg:_poolFor(nil, "legendary")) do
        t:falsy("pool sem classe sem coringa de chefe (" .. id .. ")", BossJokers.isBossJoker(id))
    end
    local BPS = require("src.systems.BoosterPackSystem")
    local leaked = false
    for seed = 1, 40 do
        TK.seedRng(9100 + seed)
        local ok, items = pcall(BPS.generateContents, { kind = "Buffoon", size = 4, classId = "warrior" })
        for _, inst in ipairs((ok and items) or {}) do
            if BossJokers.isBossJoker(inst.id) then leaked = true end
        end
        ok, items = pcall(BPS.generateContents, { kind = "Buffoon", size = 4 })
        for _, inst in ipairs((ok and items) or {}) do
            if BossJokers.isBossJoker(inst.id) then leaked = true end
        end
    end
    t:falsy("pacote de coringas nunca sorteia coringa de chefe", leaked)

    local ShopSystem = require("src.systems.ShopSystem")
    for bossId, cardId in pairs(BOSSES) do
        local g = TK.newRunGame("warrior")
        local run = g.runManager.currentRun
        run.currentNode = { type = "boss", enemyId = bossId }
        g.shopSystem:setMode("rewards")
        g.shopSystem:setContext(ShopSystem.runContext(g, "rewards"))
        g.shopSystem:generateOffers()
        local offers = g.shopSystem:getCurrentOffers()
        local n, hit, nCards = 0, nil, 0
        for _, o in ipairs(offers) do
            if o.type == "card" then nCards = nCards + 1 end
            if o.id == cardId then n = n + 1; hit = o end
            if o.type == "card" and o.id ~= cardId then
                t:falsy(bossId .. ": nenhum OUTRO coringa de chefe na escolha", BossJokers.isBossJoker(o.id))
            end
        end
        t:eq(bossId .. ": recompensa do chefe traz o coringa dele", n, 1)
        t:eq(bossId .. ": coringa ocupa UMA vaga (3 cartas)", nCards, 3)
        t:truthy(bossId .. ": marcado como coringa de chefe", hit and hit.bossJoker)
        t:eq(bossId .. ": gratis como toda recompensa", hit and hit.cost, 0)
        t:truthy(bossId .. ": descoberto na colecao", require("src.systems.UnlockSystem").isCardDiscovered(cardId))

        g:addJokerToRun(cardId)
        g.shopSystem:generateOffers()
        local again = false
        for _, o in ipairs(g.shopSystem:getCurrentOffers()) do
            if o.id == cardId then again = true end
        end
        t:falsy(bossId .. ": ja possuido (endless) nao volta", again)

        run.currentNode = { type = "elite", enemyId = bossId }
        g.shopSystem:setContext(ShopSystem.runContext(g, "rewards"))
        g.shopSystem:generateOffers()
        local inElite = false
        for _, o in ipairs(g.shopSystem:getCurrentOffers()) do
            if BossJokers.isBossJoker(o.id) then inElite = true end
        end
        t:falsy(bossId .. ": fora do no de chefe nao aparece", inElite)
    end

    local BC = require("src.ui.BossCinematic")
    local Trophy = require("src.ui.BossTrophy")
    local TData = require("src.data.boss_trophy")
    local savedSettings = _G.gameSettings
    local DT = 1 / 60
    local stage = {
        cx = 960, cy = 840,
        bbox = { cx = 960, topY = 500, bottomY = 840, width = 300, height = 340 },
        foot = { drawX = 800, drawY = 480, scale = 2.6 },
        hall = 1, w = 1920, h = 1080, tr = { scale = 4.8, ox = 0, oy = -74 },
    }
    for _, reduced in ipairs({ false, true }) do
        _G.gameSettings = { reducedMotion = reduced }
        for bossId, cardId in pairs(BOSSES) do
            local tag = bossId .. (reduced and " (reduced)" or "")
            BC.reset()
            BC.setStage(stage)
            local gd = fakeBoss(bossId, { jokers = {} })
            gd._deathHandled = true
            BC.update(DT, gd, { inHall = true })
            t:truthy(tag .. ": morte comecou", BC.isActive() and BC.phase() == "death")
            local el, sawSpin, sawStop, lastState, sawCard = 0, false, false, nil, nil
            while BC.isActive() and el < 30 do
                BC.update(DT, gd, { inHall = true })
                el = el + DT
                local s = Trophy.state()
                if s then
                    sawCard = s.card
                    if s.spinning then sawSpin = true end
                    if s.phase == "stopped" then
                        sawStop = true
                        lastState = s
                    end
                end
            end
            t:falsy(tag .. ": morte termina", BC.isActive())
            t:falsy(tag .. ": espolios liberados", BC.holdsEnd())
            t:eq(tag .. ": a carta que sobe e o coringa do chefe", sawCard, cardId)
            t:truthy(tag .. ": a carta PARA no ar", sawStop)
            if reduced then
                t:falsy(tag .. ": sem giro", sawSpin)
            else
                t:truthy(tag .. ": a carta gira subindo", sawSpin)
            end
            t:truthy(tag .. ": parada de FRENTE", lastState and math.cos(lastState.angle) > 0.999)
            t:truthy(tag .. ": parada ja revelada", lastState and lastState.revealed)
            t:falsy(tag .. ": trofeu limpo no fim", Trophy.isActive())
        end
    end
    _G.gameSettings = { reducedMotion = false }

    BC.reset()
    BC.setStage(stage)
    local owned = fakeBoss("carrion_king", { jokers = { "joker_boss_carrion" } })
    owned._deathHandled = true
    BC.update(DT, owned, { inHall = true })
    local sawOwned = false
    local el = 0
    while BC.isActive() and el < 30 do
        BC.update(DT, owned, { inHall = true })
        el = el + DT
        if Trophy.isActive() then sawOwned = true end
    end
    t:falsy("coringa ja possuido: sem carta subindo", sawOwned)

    BC.reset()
    BC.setStage(stage)
    local gr = fakeBoss("tower_lich", { jokers = {} })
    gr._deathHandled = true
    BC.markDeathSeen(gr)
    for _ = 1, 30 do BC.update(DT, gr, { inHall = true }) end
    t:falsy("Continuar com o chefe morto: a carta nao sobe de novo", Trophy.isActive() or BC.isActive())

    BC.reset()
    BC.setStage(stage)
    local gs = fakeBoss("abyss_tyrant", { jokers = {} })
    gs._deathHandled = true
    BC.update(DT, gs, { inHall = true })
    for _ = 1, math.floor((BC.SKIP_AFTER + 0.2) / DT) do BC.update(DT, gs, { inHall = true }) end
    BC.skip()
    t:falsy("pular a morte encerra a carta junto", Trophy.isActive())
    t:truthy("tempo de troféu cabe no roteiro", TData.step.dur > TData.timing.delay
        + TData.timing.rise + TData.timing.settle + TData.timing.fade)

    BC.reset()
    _G.gameSettings = savedSettings
    return t:done()
end

function M.run()
    local saved = _G.gameSettings
    local ok, res = pcall(body)
    _G.gameSettings = saved
    if not ok then error(res, 0) end
    return res
end

return M
