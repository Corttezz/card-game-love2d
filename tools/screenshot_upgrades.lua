-- tools/screenshot_upgrades.lua
-- Vitrine de UPGRADES (vouchers) da loja: forja, vida maxima, mana maxima.
--
-- Captura o MESMO slot com os 3 upgrades do catalogo, em repouso e em hover,
-- mais um zoom 3x do tile (o defeito mora no detalhe fino: hierarquia de
-- nome/efeito/preco) e o painel de detalhe correspondente.
--
--   love . test_one screenshot_upgrades
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

-- Os 3 upgrades que a loja pode ofertar (ShopSystem:generateUpgradeOffer).
local VARIANTS = {
    { id = "forge_card",     effect = "forge_card",           value = 1,  cost = 5 },
    { id = "health_upgrade", effect = "increase_max_health",  value = 10, cost = 5 },
    { id = "mana_upgrade",   effect = "increase_base_mana",   value = 1,  cost = 25 },
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
            print("[screenshot_upgrades] " .. name)
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
            print("[screenshot_upgrades] " .. name .. " (zoom " .. zoom .. "x)")
        end)
        love.graphics.present()
    end

    -- Slot do voucher: o unico offer.type == "upgrade" da vitrine.
    local voucher, vslot
    for _, o in ipairs(screen.shopOffers) do
        if o.type == "upgrade" then voucher, vslot = o, o._slot break end
    end
    if not voucher then print("[screenshot_upgrades] sem voucher na vitrine"); return false end

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
        snap("upg_" .. v.id .. "_repouso.png")
        snapZoom("upg_" .. v.id .. "_zoom.png", {
            x = math.max(0, pos.x - 24), y = math.max(0, pos.y - 24),
        }, 3)

        local cx = math.floor(pos.x + (pos.w or screen.cardWidth) / 2)
        local cy = math.floor(pos.y + (pos.h or screen.cardHeight) / 2)
        love.mouse.setPosition(cx, cy)
        simulate(0.6)
        print(("  hover -> oferta=%s kind=%s"):format(
            tostring(screen.hoveredOffer and screen.hoveredOffer.id),
            tostring(screen.hoveredKind)))
        snap("upg_" .. v.id .. "_hover.png")
    end

    -- Selecionado (botoes de compra no rodape do painel de detalhe).
    screen:setSelectedOffer(voucher, vslot)
    simulate(0.5)
    snap("upg_selecionado.png")

    -- Sem ouro: o tile inteiro escurece (2o canal, alem do preco vermelho) --
    -- mesma regra do saleDim das cartas.
    screen:clearSelection()
    local savedGold = game.economySystem and game.economySystem.currentGold
    if game.economySystem then game.economySystem.currentGold = 0 end
    love.mouse.setPosition(6, 6)
    simulate(0.4)
    snap("upg_sem_ouro.png")
    if game.economySystem then game.economySystem.currentGold = savedGold or 30 end

    -- ESCALAS: o mesmo tile nos tamanhos que a janela produz, lado a lado.
    -- Mostra ONDE o chip cai e se o texto continua legivel sem depender de
    -- redimensionar a janela de verdade (setMode repetido trava o tool).
    do
        local UpgradeTile = require("src.ui.UpgradeTile")
        local sizes = { { 260, 300 }, { 206, 220 }, { 150, 170 }, { 120, 140 }, { 90, 96 } }
        love.graphics.clear(0.10, 0.08, 0.06, 1)
        local px = 30
        for _, s in ipairs(sizes) do
            UpgradeTile.draw(voucher, { x = px, y = 60, w = s[1], h = s[2] },
                { hover = 0, afford = true, time = 2.0 })
            UpgradeTile.draw(voucher, { x = px, y = 400, w = s[1], h = s[2] },
                { hover = 1, afford = false, time = 2.0 })
            px = px + s[1] + 18
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(require("src.ui.FontManager").getFont(10))
        love.graphics.print("repouso / pagavel", 30, 36)
        love.graphics.print("hover / SEM OURO", 30, 376)
        love.graphics.captureScreenshot(function(d)
            d:encode("png", "upg_escalas.png")
            print("[screenshot_upgrades] upg_escalas.png")
        end)
        love.graphics.present()
    end

    -- reducedMotion: sem bob, sem brasas, sem pulinho -- MAS nome, chip,
    -- preco e destaque de foco continuam todos la (a flag remove movimento,
    -- nunca informacao).
    do
        local UpgradeTile = require("src.ui.UpgradeTile")
        _G.gameSettings = _G.gameSettings or {}
        local prev = _G.gameSettings.reducedMotion
        _G.gameSettings.reducedMotion = true
        love.graphics.clear(0.10, 0.08, 0.06, 1)
        UpgradeTile.draw(voucher, { x = 60, y = 120, w = 206, h = 220 },
            { hover = 0, afford = true, time = 2.0 })
        UpgradeTile.draw(voucher, { x = 320, y = 120, w = 206, h = 220 },
            { hover = 1, afford = true, time = 2.0 })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(require("src.ui.FontManager").getFont(10))
        love.graphics.print("reducedMotion: repouso / hover", 60, 90)
        love.graphics.captureScreenshot(function(d)
            d:encode("png", "upg_reduced_motion.png")
            print("[screenshot_upgrades] upg_reduced_motion.png")
        end)
        love.graphics.present()
        _G.gameSettings.reducedMotion = prev
    end

    -- COMPRA: a reliquia sobe e se apaga, o efeito sobe escrito, o slot vira
    -- VENDIDO. Tres paradas pra ver o gesto inteiro.
    voucher.effect = "increase_max_health"   -- sem abrir o picker da forja
    voucher.id = "health_upgrade"
    voucher.value = 10
    voucher.cost = 5
    voucher.name = I18n.t("shop_items.health_upgrade.name", nil, "health_upgrade")
    simulate(0.2)
    screen:purchaseOffer(voucher, voucher.id)
    simulate(0.12); snap("upg_compra_1.png")
    simulate(0.25); snap("upg_compra_2.png")
    simulate(0.45); snap("upg_compra_3.png")

    return true
end

return M
