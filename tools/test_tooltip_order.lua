-- tools/test_tooltip_order.lua
-- ORDEM DE DESENHO DA MÃO (dono, Out/2026: "o +COMBO da carta ao lado fica
-- POR CIMA do tooltip da carta em hover"). O tooltip da carta em hover é o
-- ÚLTIMO desenho da mão: depois dos selos +COMBO, da prévia de dano e dos
-- toasts. Mede a ordem real no GameplayScene.draw instrumentando as funções.
--
--   love . test_one test_tooltip_order

local TK = require("tools.testkit")

local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("tooltip da carta acima dos selos da mão")
    require("src.ui.PixelCanvas").enableNearest()
    local GameplayScene = require("src.scenes.GameplayScene")
    local DamagePreviewPanel = require("src.ui.DamagePreviewPanel")
    local CardInfoDisplay = require("src.ui.CardInfoDisplay")
    local MessageSystem = require("src.systems.MessageSystem")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local realMouse = love.mouse.getPosition
    local log = {}
    local saved = {
        badges = DamagePreviewPanel.drawHandBadges,
        panel = DamagePreviewPanel.draw,
        tip = CardInfoDisplay.draw,
        toast = MessageSystem.draw,
    }
    DamagePreviewPanel.drawHandBadges = function(...) log[#log + 1] = "badges"; return saved.badges(...) end
    DamagePreviewPanel.draw = function(...) log[#log + 1] = "preview"; return saved.panel(...) end
    CardInfoDisplay.draw = function(...) log[#log + 1] = "tooltip"; return saved.tip(...) end
    MessageSystem.draw = function(...) log[#log + 1] = "toasts"; return saved.toast(...) end

    local ok, err = pcall(function()
        local game = TK.newRunGame("warrior")
        local topBar = TopBar:new(); topBar:setGame(game)
        GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
            playButton = Button:new(800, 600, 150, 46, "Jogar"),
            endTurnButton = Button:new(800, 660, 150, 34, "Fim") })
        GameplayScene.setGame(game)
        local db = game.deckManager.cardDatabase
        game.hand = {}
        for _, id in ipairs({ "warrior_strike", "warrior_strike", "warrior_bash", "warrior_defend" }) do
            game.hand[#game.hand + 1] = db:createCardInstance(db:getCard(id))
        end
        game.player.mana, game.player.maxMana = 9, 9
        game.turn = "player"
        game:selectCard(game.hand[1])   -- seleção → selos +COMBO nas vizinhas
        game:addMessage("toast de teste", "info")
        local cv = love.graphics.newCanvas(1024, 768)
        love.graphics.setCanvas({ cv, stencil = true })
        for _ = 1, 30 do GameplayScene.update(1 / 30) end
        local sx, sp, cy = GameplayScene.handLayout()
        local mx, my = sx + 2 * sp + 50, cy + 70     -- hover na 3ª carta
        love.mouse.getPosition = function() return mx, my end
        for _ = 1, 20 do GameplayScene.update(1 / 30) end
        GameplayScene.draw()   -- aquece o hover (retângulo do último desenho)
        GameplayScene.update(1 / 30)
        log = {}
        GameplayScene.draw()
        love.graphics.setCanvas()

        local pos = {}
        for i, k in ipairs(log) do pos[k] = i end   -- última ocorrência
        t:truthy("houve tooltip de carta no quadro", pos.tooltip ~= nil)
        t:truthy("houve selos +COMBO no quadro", pos.badges ~= nil)
        t:truthy("tooltip DEPOIS dos selos +COMBO", pos.tooltip and pos.badges and pos.tooltip > pos.badges)
        t:truthy("tooltip DEPOIS da prévia de dano", pos.tooltip and pos.preview and pos.tooltip > pos.preview)
        t:truthy("tooltip DEPOIS dos toasts", pos.tooltip and pos.toasts and pos.tooltip > pos.toasts)
        print("    ordem: " .. table.concat(log, " > "))
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)
    DamagePreviewPanel.drawHandBadges, DamagePreviewPanel.draw = saved.badges, saved.panel
    CardInfoDisplay.draw, MessageSystem.draw = saved.tip, saved.toast
    love.mouse.getPosition = realMouse
    return t:done()
end

return M
