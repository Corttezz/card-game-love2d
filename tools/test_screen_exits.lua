local M = {}

local TK = require("tools.testkit")

local function pumpEM(secs)
    local dt = 1 / 30
    for _ = 1, math.floor((secs or 0) * 30) do
        _G.EventManager.update(dt)
    end
end

local function resetQueues()
    _G.EventManager.clear()
end

local function openShop(t)
    local game = TK.newRunGame("warrior")
    local CardRewardScreen = require("components.CardRewardScreen")
    local screen = CardRewardScreen:new(game.shopSystem)
    local calls = { n = 0 }
    screen:show(game, function() end, function() calls.n = calls.n + 1 end, "shop")
    t:truthy("loja abriu visível", screen:isVisible())
    return screen, calls
end

function M.run()
    TK.bootstrap()
    TK.seedRng(4242)
    local t = TK.new("test_screen_exits")

    do
        local screen, calls = openShop(t)
        screen:_exitWithFlourish()

        t:eq("callback NÃO dispara no clique (a cerimônia roda antes)", calls.n, 0)
        t:truthy("tela continua visível durante a cerimônia", screen:isVisible())

        pumpEM(0.3)
        t:truthy("ainda visível no meio da saída (0.3s)", screen:isVisible())

        pumpEM(0.6)
        t:eq("callback disparou ao fim da cerimônia", calls.n, 1)
        t:falsy("tela fechou junto com o callback", screen:isVisible())
    end

    do
        resetQueues()
        local screen, calls = openShop(t)
        screen:_exitWithFlourish()
        screen:_exitWithFlourish()
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("3 cliques no Seguir = 1 avanço só (guard _closing)", calls.n, 1)
    end

    do
        resetQueues()
        local screen, calls = openShop(t)
        local eco = screen.game.economySystem
        local before = eco.currentGold
        t:truthy("(pre) loja tem botao Pular", screen.skipButton ~= nil)
        screen.skipButton.onClick()
        local once = eco.currentGold - before
        screen.skipButton.onClick()
        screen.skipButton.onClick()
        t:eq("3 cliques no Pular pagam o bonus UMA vez", eco.currentGold - before, once)
        t:truthy("clique durante a saida e engolido",
            screen:mousepressed(10, 10, 1) == true)
        pumpEM(1.0)
        t:eq("e a loja avanca uma vez so", calls.n, 1)
    end

    do
        resetQueues()
        local prev = _G.gameSettings and _G.gameSettings.reducedMotion
        _G.gameSettings = _G.gameSettings or {}
        _G.gameSettings.reducedMotion = true

        local screen, calls = openShop(t)
        screen:_exitWithFlourish()
        t:eq("reducedMotion: callback imediato (sem pump)", calls.n, 1)
        t:falsy("reducedMotion: tela fecha na hora", screen:isVisible())

        _G.gameSettings.reducedMotion = prev
    end

    do
        resetQueues()
        local screen, calls = openShop(t)
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("saída completou", calls.n, 1)

        local game2 = TK.newRunGame("mage")
        local calls2 = 0
        screen:show(game2, function() end, function() calls2 = calls2 + 1 end, "shop")
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("segunda abertura também sai (guard foi resetado)", calls2, 1)
    end

    do
        resetQueues()
        local screen, calls = openShop(t)

        _G.EventManager.after(5.0, function() end)

        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("saída completa mesmo com a fila base bloqueada por 5s", calls.n, 1)
        t:falsy("tela fechou apesar da base travada", screen:isVisible())
    end

    local EventScreen = require("components.EventScreen")
    local Events      = require("src.data.events")

    local function openEvent()
        local game = TK.newRunGame("warrior")
        local ev = Events.roll(1, {})
        local screen = EventScreen:new()
        local calls = { n = 0 }
        screen:show(ev, game, function() calls.n = calls.n + 1 end)
        return screen, calls
    end

    do
        resetQueues()
        local screen, calls = openEvent()
        t:truthy("evento abriu visível", screen:isVisible())

        screen:_closeWithFade()
        t:eq("callback do evento não vem no clique", calls.n, 0)
        t:truthy("evento visível durante o fade", screen:isVisible())

        pumpEM(1.0)
        t:eq("callback do evento veio ao fim do fade", calls.n, 1)
        t:falsy("evento fechou", screen:isVisible())
    end

    do
        resetQueues()
        local screen, calls = openEvent()
        screen:_closeWithFade()
        screen:_closeWithFade()
        screen:_closeWithFade()
        pumpEM(1.0)
        t:eq("evento: 3 fechamentos = 1 avanço só", calls.n, 1)
    end

    do
        resetQueues()
        local screen, calls = openEvent()
        _G.EventManager.after(5.0, function() end)
        screen:_closeWithFade()
        pumpEM(1.0)
        t:eq("evento sai mesmo com a base bloqueada por 5s", calls.n, 1)
    end

    do
        resetQueues()
        local screen = openEvent()
        t:truthy("entrada em curso conta como animando", screen:_isAnimating())
        pumpEM(0.6)
        t:falsy("depois de assentar, aceita input", screen:_isAnimating())
    end

    local RoundEvalScreen = require("components.RoundEvalScreen")

    local function openEval()
        local game = TK.newRunGame("warrior")
        local screen = RoundEvalScreen:new()
        local calls = { n = 0 }
        screen:show(game, {
            { label = "Vitoria", dollars = 5 },
            { label = "Juros",   dollars = 3 },
        }, function() calls.n = calls.n + 1 end)
        return screen, calls, game
    end

    do
        resetQueues()
        local screen, calls, game = openEval()
        local before = game.economySystem.currentGold

        screen:_onCashOutClick()
        t:eq("ouro NÃO entra no clique (entra no pouso da moeda)",
            game.economySystem.currentGold, before)
        t:eq("callback do cash out não vem no clique", calls.n, 0)

        pumpEM(2.0)
        t:eq("ouro creditado uma vez", game.economySystem.currentGold, before + 8)
        t:eq("callback do cash out veio", calls.n, 1)
        t:falsy("cash out fechou", screen:isVisible())
    end

    do
        resetQueues()
        local screen, calls, game = openEval()
        local before = game.economySystem.currentGold
        screen:_onCashOutClick()
        screen:_onCashOutClick()
        screen:_onCashOutClick()
        pumpEM(2.0)
        t:eq("3 cliques em Resgatar = 1 pagamento só",
            game.economySystem.currentGold, before + 8)
        t:eq("3 cliques em Resgatar = 1 avanço só", calls.n, 1)
    end

    do
        resetQueues()
        local screen, calls, game = openEval()
        local before = game.economySystem.currentGold
        _G.EventManager.after(5.0, function() end)
        screen:_onCashOutClick()
        pumpEM(2.0)
        t:eq("paga mesmo com a base bloqueada por 5s",
            game.economySystem.currentGold, before + 8)
        t:eq("avança mesmo com a base bloqueada por 5s", calls.n, 1)
    end

    do
        resetQueues()
        _G.gameSettings = _G.gameSettings or {}
        local prev = _G.gameSettings.reducedMotion
        _G.gameSettings.reducedMotion = true

        local screen, calls, game = openEval()
        local before = game.economySystem.currentGold
        screen:_onCashOutClick()
        pumpEM(1.0)
        t:eq("reducedMotion: ouro entra igual",
            game.economySystem.currentGold, before + 8)
        t:eq("reducedMotion: fluxo segue", calls.n, 1)

        _G.gameSettings.reducedMotion = prev
    end

    return t:done()
end

return M
