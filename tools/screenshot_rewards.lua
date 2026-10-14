local M = {}

local Game             = require("src.core.Game")
local CardRewardScreen = require("components.CardRewardScreen")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local I18n             = require("src.i18n.I18n")

function M.run()
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load(); DissolveShader.load(); ScreenShake.install()

    local game = Game:new()
    game:startNewRun("mage")
    game:startGame()
    _G.game = game

    local screen = CardRewardScreen:new(game.shopSystem)
    screen.lastScreenWidth = love.graphics.getWidth()
    screen.lastScreenHeight = love.graphics.getHeight()
    screen:show(game, function() end, function() end, "rewards")

    local stepDt = 1 / 60
    local function simulate(secs)
        local t = 0
        while t < secs do
            EventManager.update(stepDt)
            FloatingText.update(stepDt)
            ScreenShake.update(stepDt)
            CardParticles.update(stepDt)
            screen:update(stepDt)
            love.graphics.clear(0, 0, 0, 1)
            screen:draw()
            t = t + stepDt
        end
    end
    simulate(1.2)

    for i, inst in ipairs(screen.cardInstances or {}) do
        print(("  inst[%d] dissolve=%.2f entryOy=%.1f x=%s y=%s scaleAnim=%s"):format(
            i, inst.dissolve or -1, inst._entryOy or -1,
            tostring(inst.x), tostring(inst.y),
            tostring(screen.cardAnimations[i] and screen.cardAnimations[i].scale)))
    end

    local function capture(name)
        CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
        CRTShader.beginScene()
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0.16, 0.12, 0.08, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(0.30, 0.22, 0.12, 1)
        love.graphics.rectangle("fill", 0, sh * 0.6, sw, sh * 0.4)
        screen:draw()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[rewards] " .. name .. " salvo")
        end)
        love.graphics.present()
    end

    capture("rewards_idle.png")

    for _, offer in ipairs(screen.shopOffers) do
        if offer.type == "card" then
            screen:setSelectedOffer(offer, offer._slot)
            break
        end
    end
    simulate(0.3)
    capture("rewards_selected.png")

    local steps = {
        { 800, 600, "rewards_resize_1_pequena" },
        { 1920, 1080, "rewards_resize_2_cresceu" },
        { 1280, 720, "rewards_resize_3_medio" },
    }
    local failures = 0
    for _, st in ipairs(steps) do
        love.window.setMode(st[1], st[2], { resizable = true })
        require("src.ui.FontManager").clearCache()
        simulate(0.40)
        local bad = screen:validateLayout()
        print(("=== %dx%d (%s) — cartas %dx%d, %d violacao(oes)"):format(
            st[1], st[2], st[3], screen.cardWidth, screen.cardHeight, #bad))
        for _, msg in ipairs(bad) do
            failures = failures + 1
            print("    VIOLACAO: " .. msg)
        end
        if screen.skipButton then
            print(("    botao %q x=%d y=%d w=%d"):format(screen.skipButton.text,
                screen.skipButton.x, screen.skipButton.y, screen.skipButton.width))
        end
        for bi, b in ipairs(screen._selectionButtons or {}) do
            print(("    escolha[%d] x=%d y=%d w=%d"):format(bi, b.x, b.y, b.width))
        end
        capture(st[3] .. ".png")
    end
    print(failures == 0 and "=== RESIZE OK: nenhuma violacao ==="
        or ("=== RESIZE FALHOU: " .. failures .. " violacao(oes) ==="))

    love.event.quit()
end

return M
