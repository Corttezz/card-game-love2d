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
                _G.openCardPicker = _G.openCardPicker or function(_, cb) if cb then pcall(cb) end end
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
                if os.getenv("SHOP_NEW") == "1" and s.scene then
                    for _, it in ipairs(s.scene.items) do
                        if it.card then it.card.isNewDiscovery = true end
                    end
                end
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
                if state == "broke" then
                    game.economySystem.currentGold = 1
                    sim(0.2)
                elseif state == "selectcard" then
                    local it = itemWhere(function(i) return i.kind == "card" and i.index == 3 end)
                    if it then s:setSelectedOffer(it.offer) end
                    sim(0.4)
                elseif state == "bought" then
                    for _, pred in ipairs({
                        function(i) return i.kind == "card" and i.index == 2 end,
                        function(i) return i.kind == "relic" and i.index == 2 end }) do
                        local it = itemWhere(pred)
                        if it then
                            s:setSelectedOffer(it.offer)
                            if s.buyButton and s.buyButton.onClick then pcall(s.buyButton.onClick) end
                            sim(0.8)
                        end
                    end
                    sim(0.6)
                elseif state == "hoverdice" and s.scene and s.scene.L then
                    local D = s.scene.L.dice
                    mouseX, mouseY = (D.rect.x + D.rect.w / 2) * k, (D.rect.y + D.rect.h * 0.6) * k
                    sim(0.6)
                elseif state == "hoverpotion" then
                    local it = itemWhere(function(i) return i.kind == "relic" and i.index == 1 end)
                    if it then it.offer.id = "health_upgrade"; sim(0.1) end
                    hoverItem(it)
                elseif state == "hoverpack" then
                    hoverItem(itemWhere(function(it) return it.kind == "pack" end))
                elseif state:match("^hoverrelic%d$") then
                    local idx = tonumber(state:match("%d"))
                    hoverItem(itemWhere(function(it) return it.kind == "relic" and it.index == idx end))
                elseif state == "hoverbell" and s.scene and s.scene.L then
                    local B = s.scene.L.bell
                    mouseX, mouseY = (B.rect.x + B.rect.w / 2) * k, (B.rect.y + B.rect.h * 0.6) * k
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
                local function cardsBox(pad)
                    local L = s.scene.L
                    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
                    for _, c in ipairs(L.cards) do
                        x0 = math.min(x0, c.rect.x, c.plate.x); x1 = math.max(x1, c.rect.x + c.rect.w, c.plate.x + c.plate.w)
                        y0 = math.min(y0, c.rect.y - c.lift - 14); y1 = math.max(y1, c.plate.y + c.plate.h)
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
                if state == "crt" or state == "crtnocalm" then
                    local CRT = require("src.ui.CRTShader")
                    CRT.load(); CRT.setEnabled(true); CRT.setStrength(0.75); CRT.setPower(1)
                    CRT.setDegrade(1)
                    CRT.beginScene()
                    love.graphics.clear(0.16, 0.12, 0.09, 1)
                    s:draw()
                    UiScale.setChromeScaled(true)
                    local tb = TopBar:new(); tb:setGame(game); tb:update(1 / 30, game); tb:draw()
                    UiScale.setChromeScaled(false)
                    if state == "crtnocalm" then CRT.setCalmRect(0, 0, 0, 0); CRT.setCalmRect2(0, 0, 0, 0) end
                    CRT.endScene(canvas)
                    love.graphics.setCanvas()
                    CRT.setDegrade(0)
                    CRT.setEnabled(false)
                    canvas:newImageData():encode("png", name)
                    print("[shop_diag] " .. name)
                elseif state == "hoverstrip" then
                    local ShelfItem = require("src.ui.shop.ShelfItem")
                    local it = itemWhere(function(i) return i.kind == "card" and i.index == 2 end)
                    local c = it.geom
                    local X0 = math.floor((c.rect.x - 16) * k)
                    local Y0 = math.floor((c.rect.y - c.lift - 26) * k)
                    local W = math.ceil((c.rect.w + 40) * k)
                    local H = math.ceil((c.plate.y + c.plate.h + 6 - (c.rect.y - c.lift - 26)) * k)
                    local dt = ShelfItem.HOVER_TIME / 12
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
                    local cv, Ls = L.cover, ShopLayout.LINES
                    local img = render(function()
                        love.graphics.setLineStyle("rough")
                        local function line(y0, col)
                            love.graphics.setLineWidth(2 / k)
                            love.graphics.setColor(col[1], col[2], col[3], 0.9)
                            love.graphics.line(cv.ox, cv.oy + y0 * cv.s, cv.ox + 640 * cv.s, cv.oy + (y0 - 80) * cv.s)
                        end
                        line(Ls.shelfEdge, { 1, 0.15, 0.15 })
                        line(Ls.tableEdge, { 1, 0.55, 0.1 })
                        line(Ls.objects, { 0.3, 1, 0.3 })
                        for _, c in ipairs(L.cards) do
                            local _, _, _, _, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
                            love.graphics.setLineWidth(1 / k)
                            love.graphics.setColor(0.2, 1, 1, 0.95)
                            love.graphics.line(x3 - 6, y3 - 6 * c.frame.k, x2 + 6, y2 + 6 * c.frame.k)
                            love.graphics.setColor(1, 0.9, 0.1, 1)
                            for _, ax in ipairs({ c.railX0, c.railX1 + 1 }) do
                                local px, py = ShopLayout.toScreen(cv, ax, Ls.shelfEdge - ax / 8)
                                love.graphics.rectangle("fill", px - 1.5, py - 1.5, 3, 3)
                            end
                        end
                        love.graphics.setColor(1, 0.2, 1, 1)
                        for _, o in ipairs(L.objects) do
                            love.graphics.rectangle("fill", o.footX - 2, o.foot - 2, 4, 4)
                        end
                        for _, o in ipairs({ L.bell, L.dice }) do
                            love.graphics.rectangle("fill", o.footX - 2, o.foot - 2, 4, 4)
                        end
                    end)
                    img:encode("png", name)
                    print("[shop_diag] " .. name)
                elseif state == "table" then
                    local Lw = s.scene.L
                    local cv = Lw.cover
                    local LINES = require("src.ui.shop.ShopLayout").LINES
                    local y0 = cv.oy + (LINES.tableBack - 640 / 8 - 70) * cv.s
                    local y1 = cv.oy + (LINES.tableEdge + 30) * cv.s
                    local X0, Y0 = 0, math.max(0, math.floor(y0 * k))
                    local X1, Y1 = w, math.min(h, math.ceil(y1 * k))
                    crop(render(), X0, Y0, X1 - X0, Y1 - Y0):encode("png", name)
                elseif state == "stand" then
                    local it = itemWhere(function(i) return i.kind == "card" and i.index == 2 end)
                    local c = it.geom
                    local x0 = c.plate.x - 10
                    local x1 = c.plate.x + c.plate.w + 14
                    local y0 = c.plate.y - 50
                    local y1 = c.plate.y + c.plate.h + 8
                    local X, Y = math.floor(x0 * k), math.floor(y0 * k)
                    crop(render(), X, Y, math.ceil((x1 - x0) * k), math.ceil((y1 - y0) * k)):encode("png", name)
                    print("[shop_diag] " .. name)
                elseif state == "tilt" then
                    local ShopLayout = require("src.ui.shop.ShopLayout")
                    local SP = require("src.ui.shop.ShopPerspective")
                    local it = itemWhere(function(i) return i.kind == "card" and i.index == 2 end)
                    local c = it.geom
                    local X0 = math.floor((c.rect.x - 22) * k)
                    local Y0 = math.floor((c.rect.y - c.lift - 26) * k)
                    local W = math.ceil((c.rect.w + 52) * k)
                    local H = math.ceil((c.rect.h + c.lift + 40) * k)
                    local r0, r1, r2 = SP.homography(ShopLayout.cardQuad(c, 0, 0))
                    local pts = { { "repouso" }, { "centro", 0.5, 0.5 }, { "sup. esq.", 0.08, 0.08 },
                        { "sup. dir.", 0.92, 0.08 }, { "inf. esq.", 0.08, 0.92 }, { "inf. dir.", 0.92, 0.92 } }
                    local board = love.image.newImageData(W * #pts + (#pts - 1) * 4, H)
                    for i, pt in ipairs(pts) do
                        if pt[2] then
                            local x, y = SP.mapH(r0, r1, r2, pt[2], pt[3])
                            mouseX, mouseY = x * k, y * k
                        else
                            mouseX, mouseY = 4, 4
                        end
                        sim(0.7)
                        board:paste(render(), (i - 1) * (W + 4), 0, X0, Y0, W, H)
                        print(("[shop_diag] tilt %s uv=(%.2f, %.2f)"):format(pt[1], it.tilt.x, it.tilt.y))
                    end
                    board:encode("png", name)
                    print("[shop_diag] " .. name)
                elseif state == "items" then
                    local L = s.scene.L
                    local relic = itemWhere(function(i) return i.kind == "relic" and i.index == 1 end)
                    local pack = itemWhere(function(i) return i.kind == "pack" end)
                    if relic then relic.offer.id = "health_upgrade" end
                    local o1, o4 = L.objects[1], L.objects[#L.objects]
                    local X0 = math.floor((o1.rect.x - 30) * k)
                    local Y0 = math.floor((o4.rect.y - 40) * k)
                    local W = math.ceil((o4.rect.x + o4.rect.w + 40) * k) - X0
                    local H = math.ceil((o1.foot + 30) * k) - Y0
                    local ids = { "pack_standard", "pack_arcana", "pack_buffoon", "pack_celestial", "pack_spectral" }
                    local board = love.image.newImageData(W, H * #ids + (#ids - 1) * 4)
                    for i, id in ipairs(ids) do
                        if pack then pack.offer.id = id end
                        sim(0.1)
                        board:paste(render(), 0, (i - 1) * (H + 4), X0, Y0, W, H)
                    end
                    board:encode("png", name)
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
