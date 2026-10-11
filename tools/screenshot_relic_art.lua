-- tools/screenshot_relic_art.lua
-- Confere a ARTE das 4 reliquias de servico que nasceram sem PNG (o tile
-- mostrava so o halo): bancada, tesoura, duplicar e cofre. Mesmo slot da
-- vitrine, repouso + zoom 3x + hover (hover liga o loop de vouchers_anim).
-- Derivado de screenshot_upgrades.lua (so troca as variantes).
--
--   love . test_one screenshot_relic_art
--
-- Saida: save dir do LOVE (~/AppData/Roaming/LOVE/card-game/).
-- Nomes: upg_<id>_repouso.png / upg_<id>_hover.png / upg_<id>_zoom.png

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

-- Servicos do ShopServices.CATALOG que faltavam arte.
local VARIANTS = {
    { id = "joker_slot",     effect = "add_joker_slot",     value = 1, cost = 20 },
    { id = "remove_card",    effect = "remove_card",        value = 1, cost = 8 },
    { id = "duplicate_card", effect = "duplicate_card",     value = 1, cost = 12 },
    { id = "interest_cap",   effect = "raise_interest_cap", value = 1, cost = 15 },
}

function M.run(locale)
    -- Captura DETERMINISTICA no idioma (o force tem que vir antes do init --
    -- ver o comentario em I18n.init). Roda por `test_one`, entao o force que
    -- o main.lua aplica aos tools screenshot_* nao chega aqui.
    _G.TOOL_FORCE_LOCALE = (locale and locale ~= "-") and locale or "pt_BR"
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load(); DissolveShader.load(); FlashShader.load()
    BoosterShader.load(); FoilShader.load()
    PolychromeShader.load(); NegativeShader.load()
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    if game.economySystem then game.economySystem.currentGold = 30 end
    _G.game = game

    local screen = CardRewardScreen:new(game.shopSystem)
    screen:show(game, function() end, function() end, "shop")

    local stepDt = 1 / 60
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

    local function render()
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0.18, 0.13, 0.09, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(1, 1, 1, 1)
        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
    end

    local function snap(name)
        love.graphics.clear(0.05, 0.04, 0.08, 1)
        render()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            print("[screenshot_relic_art] " .. name)
        end)
        love.graphics.present()
    end

    local function snapZoom(name, rect, zoom)
        zoom = zoom or 3
        local sw, sh = love.graphics.getDimensions()
        local canvas = love.graphics.newCanvas(sw, sh)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.18, 0.13, 0.09, 1)
        render()
        love.graphics.setCanvas()
        love.graphics.clear(0.05, 0.04, 0.08, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.push()
        love.graphics.scale(zoom, zoom)
        love.graphics.translate(-rect.x, -rect.y)
        love.graphics.draw(canvas)
        love.graphics.pop()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            print("[screenshot_relic_art] " .. name .. " (zoom " .. zoom .. "x)")
        end)
        love.graphics.present()
    end

    -- Slot do voucher: o unico offer.type == "upgrade" da vitrine.
    local voucher, vslot
    for _, o in ipairs(screen.shopOffers) do
        if o.type == "upgrade" then voucher, vslot = o, o._slot break end
    end
    if not voucher then print("[screenshot_relic_art] sem voucher na vitrine"); return false end

    local pos = screen.cardPositions[vslot]
    print(("voucher slot=%d rect=(%d,%d %dx%d)"):format(vslot, pos.x, pos.y,
        pos.w or screen.cardWidth, pos.h or screen.cardHeight))

    simulate(1.4)

    for _, v in ipairs(VARIANTS) do
        -- Reescreve a oferta em cima do MESMO slot: o tile e o painel sao os
        -- mesmos, so muda o conteudo (e assim se compara maca com maca).
        voucher.id = v.id
        voucher.effect = v.effect
        voucher.value = v.value
        voucher.cost = v.cost
        voucher.name = I18n.t("shop_items." .. v.id .. ".name", nil, v.id)
        voucher.description = I18n.t("shop_items." .. v.id .. ".desc",
            { value = v.value }, "")
        screen:clearSelection()
        screen:_resetDetail()

        love.mouse.setPosition(6, 6)
        simulate(0.5)
        snap("relic_" .. v.id .. "_repouso.png")
        snapZoom("relic_" .. v.id .. "_zoom.png", {
            x = math.max(0, pos.x - 24), y = math.max(0, pos.y - 24),
        }, 3)

        local cx = math.floor(pos.x + (pos.w or screen.cardWidth) / 2)
        local cy = math.floor(pos.y + (pos.h or screen.cardHeight) / 2)
        love.mouse.setPosition(cx, cy)
        simulate(0.6)
        print(("  hover -> oferta=%s kind=%s"):format(
            tostring(screen.hoveredOffer and screen.hoveredOffer.id),
            tostring(screen.hoveredKind)))
        snap("relic_" .. v.id .. "_hover.png")
    end

    return true
end

return M
