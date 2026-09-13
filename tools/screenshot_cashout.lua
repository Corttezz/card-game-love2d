-- tools/screenshot_cashout.lua
-- Contact sheet do VOO DAS MOEDAS do cash out (item "animação da moeda sendo
-- resgatada").
--
-- O voo dura ~0,83s e passa por cima do painel enquanto ele desliza — num
-- screenshot único não se vê nada. Captura em instantes fixos e monta lado a
-- lado. Também confirma que as moedas MIRAM no bloco de ouro da TopBar (o
-- alvo vem de _G.topBar; sem ele iriam pro centro e ninguém notaria).
--
-- Roda: love . screenshot_cashout
-- Saída: cashout_fly.png

local M = {}

local AT = { 0.00, 0.12, 0.28, 0.46, 0.70, 0.95 }

function M.run()
    local I18n            = require("src.i18n.I18n")
    local Game            = require("src.core.Game")
    local RoundEvalScreen = require("components.RoundEvalScreen")
    local TopBar          = require("components.TopBar")
    local EM              = require("engine.EventManager")
    local Rng             = require("src.systems.Rng")

    I18n.init()
    I18n.setLocale("pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or EM
    Rng.setActive(Rng.new(4242))

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    -- TopBar real: e ela quem define o alvo das moedas.
    local topBar = TopBar:new()
    topBar:setGame(game)
    _G.topBar = topBar

    local screen = RoundEvalScreen:new()
    screen:show(game, {
        { label = "Vitoria",  dollars = 5 },
        { label = "HP cheio", dollars = 3 },
        { label = "Juros",    dollars = 5 },
    }, function() end)

    local DT = 1 / 60
    local function step()
        EM.update(DT)
        topBar:update(DT, game)
        screen:update(DT)
    end

    -- Adianta ate o botao Resgatar estar pronto, depois clica.
    for _ = 1, 60 * 6 do step() end
    print("[cashout] botao pronto: " .. tostring(screen.cashOutReady))
    screen:_onCashOutClick()

    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local frames, labels, t, idx = {}, {}, 0, 1
    while idx <= #AT do
        if t >= AT[idx] - 1e-6 then
            local c = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(c)
            love.graphics.origin()
            love.graphics.clear(0.08, 0.07, 0.09, 1)
            if screen.visible then screen:draw() end
            topBar:draw()
            love.graphics.setCanvas()
            frames[#frames + 1] = love.graphics.newImage(c:newImageData())
            local live = 0
            for _, co in ipairs(screen._coins or {}) do
                if (co.a or 0) > 0.01 then live = live + 1 end
            end
            labels[#labels + 1] = string.format("t=%.2fs moedas=%d ouro=%d",
                t, live, game.economySystem.currentGold or 0)
            idx = idx + 1
        else
            step()
            t = t + DT
        end
    end

    local S = 0.30
    local tw, th = math.floor(W * S), math.floor(H * S)
    local pad = 6
    local out = love.graphics.newCanvas(tw * #frames + pad * (#frames + 1), th + pad * 2 + 16)
    love.graphics.setCanvas(out)
    love.graphics.clear(0.10, 0.09, 0.11, 1)
    love.graphics.setFont(love.graphics.newFont(11))
    for i, img in ipairs(frames) do
        local x = pad + (i - 1) * (tw + pad)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, pad, 0, S, S)
        love.graphics.setColor(0.95, 0.85, 0.45, 1)
        love.graphics.print(labels[i], x, pad + th + 3)
    end
    love.graphics.setCanvas()
    out:newImageData():encode("png", "cashout_fly.png")
    print("[cashout] cashout_fly.png")
    return true
end

return M
