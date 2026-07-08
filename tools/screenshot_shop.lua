-- tools/screenshot_shop.lua
-- Captura screenshot da CardRewardScreen em modo "shop" pra validação visual.
-- Roda: love . screenshot_shop [phase]
-- phase: 0 = imediatamente após show (intro animation), 1 = settled idle
-- Saída: ~/.local/share/love/card-game/shop_<phase>.png

local M = {}

local Game             = require("src.core.Game")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local FlashShader      = require("src.ui.FlashShader")
local BoosterShader    = require("src.ui.BoosterShader")
local FoilShader       = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local NegativeShader   = require("src.ui.NegativeShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local CardRewardScreen = require("components.CardRewardScreen")
local I18n             = require("src.i18n.I18n")

-- phase 2 = compra a 1ª carta e captura 0.25s depois (valida F2: slot VENDIDO,
-- carta voando pro deck, popup -$N, demais cartas paradas no lugar).
local PHASE_TIMES = { [0] = 0.20, [1] = 1.20, [2] = 1.20 }

function M.run(phase)
    phase = tonumber(phase or 1) or 1
    local targetT = PHASE_TIMES[phase] or 1.20

    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    NegativeShader.load()
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    -- Dá uns 30 ouro pra aparecer "afford" verde nos preços.
    if game.economySystem then
        game.economySystem.currentGold = 30
    end
    _G.game = game

    local screen = CardRewardScreen:new(game.shopSystem)
    screen:show(game,
        function(_) end,
        function() end,
        "shop"  -- modo shop (4 cards + 1 voucher + 2 packs)
    )

    -- Debug: dump positions e sizes pra validar layout aplicado.
    print("=== Layout debug ===")
    print(("mode=%s slotCount=%s cardW=%s cardH=%s"):format(tostring(screen.mode), tostring(screen.slotCount), tostring(screen.cardWidth), tostring(screen.cardHeight)))
    print(("buttonsColX=%s buttonsColY=%s"):format(tostring(screen.buttonsColX), tostring(screen.buttonsColY)))
    print(("skipButtonX=%s skipButtonY=%s"):format(tostring(screen.skipButtonX), tostring(screen.skipButtonY)))
    if screen.refreshButton then
        print(("refreshButton x=%s y=%s w=%s h=%s"):format(tostring(screen.refreshButton.x), tostring(screen.refreshButton.y), tostring(screen.refreshButton.width), tostring(screen.refreshButton.height)))
    end
    for i, p in ipairs(screen.cardPositions or {}) do
        print(("  pos[%d] x=%d y=%d row=%s kind=%s w=%s"):format(i, p.x, p.y, tostring(p.row), tostring(p.kind), tostring(p.w)))
    end
    for i, o in ipairs(screen.shopOffers or {}) do
        print(("  offer[%d] type=%s name=%s cost=%s"):format(i, o.type, o.name, tostring(o.cost)))
    end

    -- Avança simulação (slide-in + materialize cascade dos cards).
    local stepDt = 1/60
    local function simulate(secs)
        local elapsed = 0
        while elapsed < secs do
            EventManager.update(stepDt)
            FloatingText.update(stepDt)
            FlashShader.update(stepDt)
            ScreenShake.update(stepDt)
            CardParticles.update(stepDt)
            screen:update(stepDt)
            elapsed = elapsed + stepDt
        end
    end
    simulate(targetT)

    if phase == 2 then
        -- Compra a primeira oferta de carta e deixa o FX no meio do voo.
        for _, offer in ipairs(screen.shopOffers) do
            if offer.type == "card" then
                screen:purchaseOffer(offer, offer.id)
                break
            end
        end
        simulate(0.25)
    end

    love.graphics.clear(0.05, 0.04, 0.08, 1)
    -- Backdrop sépia (simula gameplay por trás).
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0.18, 0.13, 0.09, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    screen:draw()
    CardParticles.draw()
    FloatingText.draw()
    FlashShader.draw()

    love.graphics.captureScreenshot(function(imageData)
        local path = string.format("shop_phase_%d_t%.2f.png", phase, targetT)
        imageData:encode("png", path)
        print("[screenshot_shop] " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
