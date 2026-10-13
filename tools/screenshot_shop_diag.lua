-- tools/screenshot_shop_diag.lua
-- Capturas da Loja v3c (balcão na diagonal) em ESTADOS, fiéis à escala de UI
-- (janela falsificada + canvas, como o screenshot_uiscale):
--   rest        repouso (a 1ª oferta nasce selecionada)
--   hovercard   mouse sobre a 2ª carta (sai do cavalete na perpendicular, sem girar)
--   hoverstrip  PRANCHA 1:1 de 8 quadros do hover da 2ª carta (4 entrando,
--               4 saindo) -> diag_hoverstrip_<W>x<H>_<loc>.png
--   guides      repouso com LINHAS GUIA por cima (só na prova): vermelho = a
--               borda pintada medida, ciano = base de cada carta, amarelo =
--               quina do trilho -> diag_guides_<W>x<H>_<loc>.png (recorte 1:1)
--   plates      prancha das duas opções da plaquinha de raridade (em cima:
--               comum SEM placa; embaixo: todas com placa)
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
                local function render(overlay)
                    love.graphics.setCanvas(canvas)
                    love.graphics.clear(0.16, 0.12, 0.09, 1)
                    s:draw()
                    UiScale.setChromeScaled(true)
                    local tb = TopBar:new(); tb:setGame(game); tb:update(1 / 30, game); tb:draw()
                    UiScale.setChromeScaled(false)
                    if overlay then
                        love.graphics.push("all")
                        love.graphics.origin()
                        love.graphics.scale(k, k)
                        overlay()
                        love.graphics.pop()
                    end
                    love.graphics.setCanvas()
                    return canvas:newImageData()
                end
                -- região das cartas (px reais) pra recortes 1:1
                local function cardsBox(pad)
                    local L = s.scene.L
                    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
                    for _, c in ipairs(L.cards) do
                        x0 = math.min(x0, c.rect.x, c.plate.x); x1 = math.max(x1, c.rect.x + c.rect.w, c.plate.x + c.plate.w)
                        y0 = math.min(y0, c.rect.y - c.lift - 14); y1 = math.max(y1, c.tag.box.y + c.tag.box.h, c.plate.y + c.plate.h)
                    end
                    local X0, Y0 = math.max(0, math.floor((x0 - pad) * k)), math.max(0, math.floor((y0 - pad) * k))
                    local X1, Y1 = math.min(w, math.ceil((x1 + pad) * k)), math.min(h, math.ceil((y1 + pad) * k))
                    return X0, Y0, X1 - X0, Y1 - Y0
                end
                local function crop(img, X, Y, W, H)
                    local out = love.image.newImageData(W, H)
                    out:paste(img, 0, 0, X, Y, W, H)
                    return out
                end
                local name = ("diag_%s_%dx%d_%s.png"):format(state, w, h, locale)
                if state == "hoverstrip" then
                    local ShelfItem = require("src.ui.shop.ShelfItem")
                    local it = itemWhere(function(i) return i.kind == "card" and i.index == 2 end)
                    local c = it.geom
                    local X0 = math.floor((c.rect.x - 16) * k)
                    local Y0 = math.floor((c.rect.y - c.lift - 26) * k)
                    local W = math.ceil((c.rect.w + 40) * k)
                    local H = math.ceil((c.tag.box.y + c.tag.box.h + 6 - (c.rect.y - c.lift - 26)) * k)
                    local dt = ShelfItem.HOVER_TIME / 12
                    -- 4 entrando (2, 4, 7, 12 de 12 quadros) e 4 saindo (3, 6, 9, 12)
                    local plan = { { true, 2 }, { true, 2 }, { true, 3 }, { true, 5 },
                                   { false, 3 }, { false, 3 }, { false, 3 }, { false, 3 } }
                    local strip = love.image.newImageData(W * 8 + 7 * 4, H)
                    local cx, cy = it:center()
                    local lifts = {}
                    for f, step in ipairs(plan) do
                        if step[1] then mouseX, mouseY = cx * k, cy * k else mouseX, mouseY = 4, 4 end
                        for _ = 1, step[2] do
                            _G.EventManager.update(dt)
                            s:update(dt)
                        end
                        lifts[#lifts + 1] = ("%.1f"):format(it:liftPx())
                        strip:paste(render(), (f - 1) * (W + 4), 0, X0, Y0, W, H)
                    end
                    strip:encode("png", name)
                    print("[shop_diag] " .. name .. "  lift por quadro: " .. table.concat(lifts, " "))
                elseif state == "guides" then
                    local ShopLayout = require("src.ui.shop.ShopLayout")
                    local L = s.scene.L
                    local cv, E = L.cover, ShopLayout.ART.ledgeEdge
                    local img = render(function()
                        love.graphics.setLineWidth(2 / k)
                        love.graphics.setLineStyle("rough")
                        love.graphics.setColor(1, 0.15, 0.15, 0.9)
                        local function ey(ax) return cv.oy + (E.y0 + E.k * (ax - E.x0)) * cv.s end
                        love.graphics.line(cv.ox + 40 * cv.s, ey(40), cv.ox + 480 * cv.s, ey(480))
                        for _, c in ipairs(L.cards) do
                            local _, _, _, _, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
                            love.graphics.setLineWidth(1 / k)
                            love.graphics.setColor(0.2, 1, 1, 0.95)
                            love.graphics.line(x3 - 6, y3 - 6 * c.frame.k, x2 + 6, y2 + 6 * c.frame.k)
                            love.graphics.setLineWidth(2 / k)
                            love.graphics.setColor(1, 0.9, 0.1, 1)
                            for _, u in ipairs({ -c.railW / 2, c.railW / 2 }) do
                                local px, py = ShopLayout.frameAtF(c.frame, u, 0)
                                love.graphics.rectangle("fill", px - 1.5, py - 1.5, 3, 3)
                            end
                        end
                    end)
                    crop(img, cardsBox(10)):encode("png", name)
                    print("[shop_diag] " .. name)
                elseif state == "plates" then
                    local ShopLayout = require("src.ui.shop.ShopLayout")
                    local old = ShopLayout.PLATE_COMMON
                    local X, Y, W, H = cardsBox(8)
                    local board = love.image.newImageData(W, H * 2 + 6)
                    ShopLayout.PLATE_COMMON = false
                    board:paste(render(), 0, 0, X, Y, W, H)
                    ShopLayout.PLATE_COMMON = true
                    board:paste(render(), 0, H + 6, X, Y, W, H)
                    ShopLayout.PLATE_COMMON = old
                    board:encode("png", name)
                    print("[shop_diag] " .. name)
                else
                    render():encode("png", name)
                    print("[shop_diag] " .. name .. "  k=" .. k)
                end
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
