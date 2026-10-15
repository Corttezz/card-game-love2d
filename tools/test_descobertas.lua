local TK = require("tools.testkit")

local M = {}

local function queueIds(UnlockQueue)
    local out = {}
    for _, it in ipairs(UnlockQueue.items()) do
        if it.kind == "card" then out[it.id] = true end
    end
    return out
end

function M.run()
    local t = TK.new("descobertas: modelo Balatro (descobrir calado, desbloquear anuncia)")
    TK.bootstrap()
    local ProfileStats = require("engine.ProfileStats")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local UnlockQueue = require("src.systems.UnlockQueue")
    local BoosterPackSystem = require("src.systems.BoosterPackSystem")
    local EndScreens = require("src.scenes.EndScreens")
    local I18n = require("src.i18n.I18n")

    local prevOverride = UnlockSystem.isOverrideAll()
    local prevProfile = ProfileStats._swapForTests({ runs = 0, wins = 0 })
    local origPos = love.mouse.getPosition
    UnlockSystem._resetForTests()
    UnlockSystem.setOverrideAll(false)
    UnlockSystem.ensure()
    UnlockQueue.clear()

    local ok, err = pcall(function()
        local game = TK.newRunGame("warrior")
        TK.seedRng(9090)
        t:eq("run nova: nenhuma descoberta contada", UnlockSystem.runDiscoveries(), 0)
        t:eq("deck inicial não vira novidade na Coleção", UnlockSystem.freshCount(), 0)

        local seen = {}
        for _ = 1, 4 do
            local offer = game.shopSystem:generateCardOffer()
            if offer and offer.id then seen[offer.id] = true end
        end
        for _, p in ipairs(game.runManager.cardRegistry:generateCardRewards("warrior", 3, { stream = "card" })) do
            seen[p.cardId] = true
        end
        for _, inst in ipairs(BoosterPackSystem.generateContents({ kind = "Standard", size = 3, classId = "warrior" })) do
            seen[inst.id] = true
        end
        local n = 0
        for id in pairs(seen) do
            n = n + 1
            t:truthy("vista em oferta/loja/pacote descobre: " .. id, UnlockSystem.isCardDiscovered(id))
        end
        t:truthy("viu cartas novas", n >= 3)
        t:eq("descobrir não enfileira revelação", UnlockQueue.count(), 0)
        t:truthy("descobertas da run contadas", UnlockSystem.runDiscoveries() >= 3)
        t:truthy("Coleção ganha novidade", UnlockSystem.freshCount() >= 3)

        local target
        for id, cd in pairs(require("src.systems.CardDatabase"):new():getAllCards()) do
            if cd.class == "warrior" and cd.type ~= "joker" and UnlockSystem.isCardUnlockedReal(id)
                and not UnlockSystem.isCardDiscovered(id) then
                target = id; break
            end
        end
        local msgs = {}
        local prevAdd = game.addMessage
        game.addMessage = function(_, text) msgs[#msgs + 1] = text end
        game:addCardToRun(target)
        game.addMessage = prevAdd
        t:eq("ganhar carta inédita no meio da run: nenhum toast", #msgs, 0)
        t:truthy("carta ganha fica descoberta", UnlockSystem.isCardDiscovered(target))
        t:eq("ganhar carta inédita não enfileira revelação", UnlockQueue.count(), 0)

        local discoveredOnly = {}
        for id in pairs(seen) do discoveredOnly[id] = true end
        discoveredOnly[target] = true

        t:falsy("joker_001 bloqueado antes do chefe", UnlockSystem.isCardUnlockedReal("joker_001"))
        UnlockSystem.onBossDefeated(1, game)
        t:truthy("chefe do ato 1 desbloqueia joker_001", UnlockSystem.isCardUnlockedReal("joker_001"))
        ProfileStats.get().unlocks.mastery.warrior = 95
        local discBefore = UnlockSystem.runDiscoveries()
        game.runManager.currentRun.actNumber = 2
        game.runManager.currentRun.floorInAct = 1
        game.unlockResult = UnlockSystem.onRunEnded(game:_unlockSummary(false))
        local r = game.unlockResult
        local q = queueIds(UnlockQueue)
        t:truthy("desbloqueio por condição (chefe) enfileira revelação", q.joker_001)
        t:truthy("subiu maestria", (r.levelsGained or 0) >= 1)
        local bundle = UnlockSystem.getBundles("warrior")[1]
        for _, id in ipairs(bundle.cards) do
            t:truthy("desbloqueio por maestria enfileira revelação: " .. id, q[id])
        end
        for id in pairs(discoveredOnly) do
            t:falsy("carta só descoberta fora da fila: " .. id, q[id])
            for _, nc in ipairs(r.newCards or {}) do
                t:truthy("carta só descoberta fora da revelação do fim: " .. id, nc ~= id)
            end
        end

        t:eq("fim de run guarda a CONTAGEM de descobertas", r.newDiscoveries, discBefore)
        local sum = EndScreens.summary("gameOver", game)
        local label = I18n.t("end_screen.label_discoveries")
        local cell
        for _, c in ipairs(sum.cells) do if c.label == label then cell = c end end
        t:truthy("fim de run mostra 'novas descobertas' como número", cell and cell.value == tostring(discBefore))
        for _, c in ipairs(sum.cells) do
            for id in pairs(discoveredOnly) do
                t:falsy("resumo não lista o nome da descoberta " .. id,
                    c.value:find(I18n.cardName(id), 1, true) ~= nil)
            end
        end
        t:truthy("rótulo da revelação diz desbloqueadas",
            I18n.t("unlocks.reveal.new_cards") ~= I18n.t("unlocks.discovered_count", { n = 1, total = 1 }))

        UnlockQueue.clear()
        local CollectionScreen = require("components.CollectionScreen")
        local screen = CollectionScreen:new()
        screen:show(function() end)
        local guard = 0
        while not screen._buildDone and guard < 4000 do
            screen:_buildInstances(0.05); guard = guard + 1
        end
        screen.filter = "all"
        screen:_applyFilter()
        local states = { locked = 0, hidden = 0, shown = 0 }
        local byId = {}
        for _, inst in ipairs(screen.cardInstances) do
            byId[inst.id] = inst
            if inst._hidden and inst._locked then states.locked = states.locked + 1
            elseif inst._hidden then states.hidden = states.hidden + 1
            else states.shown = states.shown + 1 end
        end
        t:truthy("Coleção: há bloqueadas (cadeado)", states.locked > 0)
        t:truthy("Coleção: há desbloqueadas não descobertas (?)", states.hidden > 0)
        t:truthy("Coleção: há descobertas (arte)", states.shown > 0)
        t:falsy("descoberta aparece com arte", byId[target]._hidden)
        local lockedId = "joker_002"
        t:truthy("bloqueada aparece como bloqueada", byId[lockedId] and byId[lockedId]._hidden and byId[lockedId]._locked)
        local hintKey = UnlockSystem.getCardHint(lockedId)
        t:truthy("bloqueada traz a condição", hintKey ~= "unlocks.hint.undiscovered")
        love.mouse.getPosition = function() return 2, 2 end
        screen:update(1 / 60)
        screen:draw()
        t:truthy("verso com cadeado desenhado", screen._lockedCanvas ~= nil)
        t:truthy("verso com ? desenhado", screen._mysteryCanvas ~= nil)
        t:truthy("cadeado e ? são versos diferentes", screen._lockedCanvas ~= screen._mysteryCanvas)
        t:truthy("aba 'todas' marca novidade", screen:freshInFilter("all"))

        local before = UnlockSystem.freshCount()
        t:truthy("novidade pendente antes de ver", UnlockSystem.isFresh(target))
        local idx
        for i, inst in ipairs(screen.filtered) do if inst.id == target then idx = i end end
        screen.scrollY = 0
        local W = love.graphics.getWidth()
        local col, row = (idx - 1) % 5, math.floor((idx - 1) / 5)
        local ox = (W - (5 * 128 + 4 * 18)) / 2
        screen.scrollY = math.max(0, math.min(screen.maxScrollY, row * (192 + 24)))
        local cy = 120 + row * (192 + 24) - screen.scrollY + 96
        love.mouse.getPosition = function() return ox + col * (128 + 18) + 64, cy end
        screen:update(1 / 60)
        t:eq("passou o mouse: hover na carta nova", screen.hoverCard and screen.hoverCard.instance.id, target)
        t:falsy("novidade some depois de vista", UnlockSystem.isFresh(target))
        t:eq("contagem da marca cai 1", UnlockSystem.freshCount(), before - 1)
        screen:hide()

        for id in pairs(UnlockSystem.freshSet()) do UnlockSystem.clearFresh(id) end
        t:eq("tudo visto: menu sem marca", UnlockSystem.freshCount(), 0)
    end)
    t:truthy("suite rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)

    love.mouse.getPosition = origPos
    UnlockQueue.clear()
    UnlockSystem._resetForTests()
    UnlockSystem.setOverrideAll(prevOverride)
    ProfileStats._swapForTests(prevProfile)
    return t:done()
end

return M
