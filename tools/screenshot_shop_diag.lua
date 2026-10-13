-- tools/screenshot_shop_diag.lua
-- Capturas da Loja v3c (balcão na diagonal) em ESTADOS, fiéis à escala de UI
-- (janela falsificada + canvas, como o screenshot_uiscale):
--   rest        repouso (a 1ª oferta nasce selecionada)
--   hovercard   mouse sobre a 2ª carta (gira: direita afunda, esquerda sobe)
--   hoverjoker  mouse sobre a bancada de coringa (MESMO sprite, levantado + contorno)
--   selectjoker bancada selecionada: o pergaminho mostra o MESMO sprite
--   hoverdice   mouse sobre o copo de dados (contorno + nome no hover)
--
--   love . test_one screenshot_shop_diag pt_BR
--   SHOP_SIZES=1280x720 love . test_one screenshot_shop_diag en
--   SHOP_STATES=rest,hovercard love . test_one screenshot_shop_diag
--
-- Saída: diag_<estado>_<W>x<H>_<loc>.png no save dir.

local M = {}

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

function M.run(arg)
    local locale = tostring(arg or "pt_BR")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(locale)
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    local TopBar = require("components.TopBar")

    local sizes = {}
    for w, h in (os.getenv("SHOP_SIZES") or "1920x1080,2560x1440,1024x768"):gmatch("(%d+)x(%d+)") do
        sizes[#sizes + 1] = { tonumber(w), tonumber(h) }
    end
    local wanted = {}
    for s in (os.getenv("SHOP_STATES") or "rest,hovercard,hoverjoker,selectjoker,hoverdice"):gmatch("[%w_]+") do
        wanted[#wanted + 1] = s
    end

    local realMouse = love.mouse.getPosition
    local mouseX, mouseY = 4, 4
    love.mouse.getPosition = function() return mouseX, mouseY end

    for _, sz in ipairs(sizes) do
        local w, h = sz[1], sz[2]
        local restore = fakeWindow(w, h)
        FontManager.clearCache()
        for _, state in ipairs(wanted) do
            local ok, err = pcall(function()
                local Game = require("src.core.Game")
                local game = Game:new()
                game:startNewRun("warrior")
                game:startGame()
                _G.game = game
                local run = game.runManager.currentRun
                run.actNumber, run.floorInAct = 2, 5
                game.economySystem.currentGold = 30
                local Rng = require("src.systems.Rng")
                Rng.setActive(Rng.new(tonumber(os.getenv("SHOP_SEED")) or 4242))
                _G.openScribeDice = _G.openScribeDice or function() end
                mouseX, mouseY = 4, 4
                local s = require("components.CardRewardScreen"):new(game.shopSystem)
                s:show(game, function() end, function() end, "shop")
                local function sim(secs)
                    for _ = 1, math.floor(secs * 30) do
                        _G.EventManager.update(1 / 30)
                        s:update(1 / 30)
                    end
                end
                sim(1.4)
                local k = UiScale.k(w, h)
                local function itemWhere(pred)
                    for _, it in ipairs(s.scene and s.scene.items or {}) do
                        if pred(it) then return it end
                    end
                end
                local function hoverItem(it)
                    if not it then return end
                    local cx, cy = it:center()
                    mouseX, mouseY = cx * k, cy * k
                    sim(0.6)
                end
                if state == "hoverdice" and s.scene and s.scene.L then
                    local D = s.scene.L.dice
                    mouseX, mouseY = (D.rect.x + D.rect.w / 2) * k, (D.rect.y + D.rect.h * 0.6) * k
                    sim(0.6)
                elseif state == "hovercard" then
                    hoverItem(itemWhere(function(it) return it.kind == "card" and it.index == 2 end))
                elseif state == "hoverjoker" or state == "selectjoker" then
                    local it = itemWhere(function(it) return it.offer and it.offer.id == "joker_slot" end)
                    hoverItem(it)
                    if state == "selectjoker" and it then
                        s:setSelectedOffer(it.offer)
                        mouseX, mouseY = 4, 4
                        sim(0.6)
                    end
                end
                local canvas = love.graphics.newCanvas(w, h)
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0.16, 0.12, 0.09, 1)
                s:draw()
                UiScale.setChromeScaled(true)
                local tb = TopBar:new(); tb:setGame(game); tb:update(1 / 30, game); tb:draw()
                love.graphics.setCanvas()
                local name = ("diag_%s_%dx%d_%s.png"):format(state, w, h, locale)
                canvas:newImageData():encode("png", name)
                print("[shop_diag] " .. name .. "  k=" .. k)
                if s.hide then pcall(s.hide, s) end
            end)
            if not ok then
                love.graphics.setCanvas()
                UiScale.reset()
                print("[shop_diag] " .. state .. " " .. w .. "x" .. h .. " FALHOU: " .. tostring(err))
            end
        end
        restore()
    end
    love.mouse.getPosition = realMouse
    FontManager.clearCache()
    return true
end

return M
