-- tools/test_screen_exits.lua
-- Regressão do CONTRATO DE SAÍDA das telas que agora saem com animação
-- (Set/2026): loja/recompensa (CardRewardScreen) e evento (EventScreen).
--
-- O nome é do INVARIANTE, não de uma tela: toda tela cujo fechamento virou
-- uma cerimônia com duração passa a ter um evento agendado entre o clique do
-- jogador e a continuação da run. Quem adicionar a terceira põe o caso aqui.
--
-- A saída deixou de ser `self:hide()` seco e virou uma cerimônia com duração
-- (`CardRewardScreen:_exitWithFlourish`): cartas queimam, painel desliza, som
-- toca e SÓ ENTÃO o callback do fluxo roda. Isso põe um evento agendado entre
-- o clique do jogador e a continuação da run — e evento agendado que não
-- vence é soft-lock: a tela fica visível pra sempre e o mapa nunca aparece.
--
-- Este teste trava isso pelos dois lados que importam:
--   1. o callback SEMPRE roda, e roda UMA vez só (double-click no Seguir não
--      pode avançar dois nós do mapa);
--   2. a tela fica visível DURANTE a cerimônia (senão ela some antes da
--      animação, que é o defeito que se foi consertar);
--   3. com reducedMotion o caminho resolve NA HORA — sem depender do
--      EventManager — porque a flag remove movimento, não o fluxo.
--
-- Roda: love . test_one test_screen_exits

local M = {}

local TK = require("tools.testkit")

local function pumpEM(secs)
    local dt = 1 / 30
    for _ = 1, math.floor((secs or 0) * 30) do
        _G.EventManager.update(dt)
    end
end

-- A fila `base` fica suja entre os casos (cada TK.newRunGame agenda compra de
-- carta, e Card:start_dissolve agenda ease BLOQUEANTE lá — a "pegadinha
-- remanescente" de memory/eventmanager_queues.md). A saída da loja roda em
-- fila própria justamente pra não depender disso; limpar a base entre casos
-- garante que o teste meça a fila CERTA e não o acúmulo do caso anterior.
local function resetQueues()
    _G.EventManager.clear()
end

-- Abre a tela em modo shop com um onSkipped instrumentado.
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

    -- ---- 1. caminho normal: cerimônia roda, callback vem DEPOIS ----------
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

    -- ---- 2. double-click não avança dois nós -----------------------------
    do
        resetQueues()
        local screen, calls = openShop(t)
        screen:_exitWithFlourish()
        screen:_exitWithFlourish()  -- jogador impaciente
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("3 cliques no Seguir = 1 avanço só (guard _closing)", calls.n, 1)
    end

    -- ---- 3. reducedMotion resolve na hora, sem EventManager --------------
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

    -- ---- 4. reabrir depois da saída deixa a tela sã ----------------------
    do
        resetQueues()
        local screen, calls = openShop(t)
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("saída completou", calls.n, 1)

        -- Reabrir: o _closing tem que estar limpo, senão a PRÓXIMA saída
        -- vira no-op e a run trava na loja seguinte.
        local game2 = TK.newRunGame("mage")
        local calls2 = 0
        screen:show(game2, function() end, function() calls2 = calls2 + 1 end, "shop")
        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("segunda abertura também sai (guard foi resetado)", calls2, 1)
    end

    -- ---- 5. A REGRESSÃO QUE IMPORTA: base SUJA não pode travar a saída ---
    -- Condição real: o jogador sai da loja logo depois de uma batalha, e o
    -- rabo do combate ainda ocupa a fila `base` com eventos BLOQUEANTES. Se a
    -- saída agendar lá (como a primeira versão deste código fazia), o
    -- callback que devolve o jogador ao mapa fica preso atrás do combate — a
    -- loja congela na tela. Fila própria = imune.
    do
        resetQueues()
        local screen, calls = openShop(t)

        -- 5 segundos de evento bloqueante na base, como um combate longo.
        _G.EventManager.after(5.0, function() end)

        screen:_exitWithFlourish()
        pumpEM(1.0)
        t:eq("saída completa mesmo com a fila base bloqueada por 5s", calls.n, 1)
        t:falsy("tela fechou apesar da base travada", screen:isVisible())
    end

    -- ======================================================================
    -- EventScreen: mesmo contrato, mesma armadilha
    -- ======================================================================
    -- A saída do evento ganhou fade (`_closeWithFade`). Se o evento agendado
    -- não vencer, o jogador fica preso na tela de evento — pior que na loja,
    -- porque ali não sobra nem botão (eles são limpos ao escolher).
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
        -- A regressão que importa, de novo: base suja não pode prender a saída.
        resetQueues()
        local screen, calls = openEvent()
        _G.EventManager.after(5.0, function() end)
        screen:_closeWithFade()
        pumpEM(1.0)
        t:eq("evento sai mesmo com a base bloqueada por 5s", calls.n, 1)
    end

    do
        -- Input ENGOLIDO durante a animação: o painel é transladado no draw
        -- mas o Button faz hit-test na posição real. Aceitar clique enquanto
        -- os dois discordam deixaria o jogador escolher a opção errada numa
        -- decisão irreversível.
        resetQueues()
        local screen = openEvent()
        t:truthy("entrada em curso conta como animando", screen:_isAnimating())
        pumpEM(0.6)
        t:falsy("depois de assentar, aceita input", screen:_isAnimating())
    end

    -- ======================================================================
    -- RoundEvalScreen: saída diferida + ouro que só entra no POUSO
    -- ======================================================================
    -- Terceira tela com o mesmo contrato, e a de maior risco: aqui o evento
    -- agendado não move só pixels, ele APLICA O OURO. Se não vencer, o
    -- jogador não recebe o pagamento da batalha e fica preso na tela.
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
        -- A armadilha ORIGINAL desta tela: ela abre no frame seguinte à
        -- vitória, com a base cheia do rabo do combate, e agendava TUDO lá.
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
        -- reducedMotion: sem voo, mas o ouro entra e o fluxo segue.
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
