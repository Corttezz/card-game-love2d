local M = {}

local function newCanvas(w, h)
    local cv = love.graphics.newCanvas(w, h)
    cv:setFilter("nearest", "nearest")
    return cv
end

local function save(cv, name)
    local data = cv:newImageData()
    data:encode("png", name)
    local src = love.filesystem.getSaveDirectory() .. "/" .. name
    local dst = "tools/preview_out/shop_props/" .. name
    local f = io.open(src, "rb")
    if f then
        local bytes = f:read("*a"); f:close()
        local ok = pcall(function()
            local g = assert(io.open(dst, "wb")); g:write(bytes); g:close()
        end)
        print("  " .. name .. (ok and (" -> " .. dst) or (" (só no save dir: " .. src .. ")")))
    end
end

local function label(text, x, y)
    love.graphics.setColor(0.85, 0.78, 0.62, 1)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1, 1)
end

local function board(ShopProps, scale, reduced)
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = reduced
    local S = scale
    local W, H = 1000 * (S / 3), 760 * (S / 3)
    W, H = math.floor(math.max(W, 760)), math.floor(math.max(H, 560))
    local cv = newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.11, 0.085, 0.07, 1)
    love.graphics.setFont(love.graphics.newFont(11))

    local l = ShopProps.lantern.new()
    label(reduced and "lanterna (reducedMotion)" or "lanterna: quadros 1..3, niveis de luz", 10, 6)
    local col = 40 * S
    for frame = 1, 3 do
        for level = 1, 3 do
            l.frame, l.level = frame, level
            if reduced then l.frame, l.level = 1, 2 end
            local x = 24 + (frame - 1) * col + (level - 1) * col * 3
            l:draw(x + 16 * S, 22, S)
        end
    end
    label("poca da luz: passos -2..2", 10, 22 + 54 * S)
    for step = -2, 2 do
        l.lookStep = step
        l.frame, l.level = 1, 2
        local x = 24 + (step + 2) * 64 * S
        local y = 36 + 54 * S
        love.graphics.setColor(0.3, 0.24, 0.18, 1)
        love.graphics.rectangle("line", x - 4, y, 60 * S, 68 * S)
        love.graphics.setScissor(x - 4, y, 60 * S, 68 * S)
        l:draw(x + 28 * S, y + 2, S)
        love.graphics.setScissor()
    end

    local cy0 = 36 + 54 * S + 78 * S
    label("copo: repouso / chacoalho (3) / deitado com 3+4", 10, cy0 - 14)
    local cup = ShopProps.diceCup.new()
    local x = 24
    local foot = cy0 + 34 * S
    cup:setState("idle"); cup:update(0)
    cup:draw(x + 16 * S, foot, S); x = x + 40 * S
    cup:setState("shake")
    for i = 0, 2 do
        cup:update(i == 0 and 0.001 or (1 / 11))
        cup:draw(x + 16 * S, foot, S); x = x + 40 * S
    end
    cup:setState("rolled", { a = 3, b = 4 }); cup:update(0)
    cup:draw(x + 16 * S, foot, S); x = x + cup:width(S) + 16
    local fake = { actNumber = 1, floorInAct = 2, mapHistory = {},
        scribeDice = { key = "dice|1|2|0", used = true, dice = { 6, 1 }, sum = 7 } }
    cup:syncRun(fake); cup:update(0)
    cup:draw(x + 16 * S, foot, S)

    local my = foot + 24
    label("mariposa: 4 instantes da travessia (pousada em reducedMotion)", 10, my - 4)
    local moth = ShopProps.moth.new()
    local Moth = ShopProps.moth.Moth
    local ds = { -40, -15, 5, 30 }
    for i, d in ipairs(ds) do
        moth:cross(); moth.dir = 1
        moth.t = 0; moth.flying = true
        moth:update((d + Moth.SPAN) / Moth.SPEED)
        local fx = 24 + (i - 1) * 80 * S + 50 * S
        local fy = my + 34 * S
        love.graphics.setColor(1, 0.72, 0.36, 0.5)
        love.graphics.circle("fill", fx, fy, 3)
        moth:draw(fx, fy, S)
    end

    local ty = my + 44 * S
    label("teia / etiqueta da oferta do dia", 10, ty - 2)
    ShopProps.cobweb.draw(24, ty + 12, S)
    ShopProps.saleTag.draw(24 + 40 * S, ty + 20, S)

    love.graphics.setCanvas()
    return cv
end

local function sceneBoard(ShopProps, S)
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    local W, H = 640, 400
    local L = {
        wall = { x = 0, y = 0, w = W, h = H },
        shelfTop = { x = 40, y = 40, w = 380, h = 120 },
        shelfBottom = { x = 40, y = 180, w = 380, h = 90 },
        counter = { x = 20, y = 300, w = 600, h = 80, dice = { x = 300, y = 318, w = 60, h = 56 } },
        scroll = { x = 520, y = 40, w = 100, h = 230 },
        lantern = { x = 440, y = 60, w = 64, h = 104 },
    }
    ShopProps._reset()
    ShopProps.load()
    local fake = { actNumber = 2, floorInAct = 3, mapHistory = {},
        scribeDice = { key = "dice|2|3|0", used = true, dice = { 5, 2 }, sum = 7 } }
    local cv = newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.10, 0.075, 0.06, 1)
    local ctx = { t = 0, reduced = false, hoverX = L.shelfTop.x + 60, hoverY = L.shelfTop.y + 60, run = fake }
    for _ = 1, 90 do ShopProps.update(1 / 30, L, ctx) end
    local sc = ShopProps.scene()
    sc.moth.t = 1.5; sc.moth.flying = true; sc.moth.dir = -1
    ShopProps.drawBack(L, ctx)
    love.graphics.setColor(0.32, 0.22, 0.14, 1)
    love.graphics.rectangle("fill", L.shelfTop.x, L.shelfTop.y + L.shelfTop.h - 10, L.shelfTop.w, 10)
    love.graphics.rectangle("fill", L.shelfBottom.x, L.shelfBottom.y + L.shelfBottom.h - 10, L.shelfBottom.w, 10)
    love.graphics.rectangle("fill", L.counter.x, L.counter.y, L.counter.w, L.counter.h)
    love.graphics.setColor(0.5, 0.42, 0.3, 1)
    love.graphics.rectangle("line", L.lantern.x, L.lantern.y, L.lantern.w, L.lantern.h)
    love.graphics.rectangle("line", L.counter.dice.x, L.counter.dice.y, L.counter.dice.w, L.counter.dice.h)
    love.graphics.rectangle("line", L.scroll.x, L.scroll.y, L.scroll.w, L.scroll.h)
    ShopProps.drawLantern(L.lantern, ctx)
    ShopProps.drawDiceCup(L.counter.dice, ctx)
    ShopProps.drawFront(L, ctx)
    local fx, fy = ShopProps.flameAnchor(L.lantern)
    love.graphics.setColor(0, 1, 1, 0.8)
    love.graphics.circle("line", fx, fy, 3)
    love.graphics.setFont(love.graphics.newFont(11))
    label(("flameAnchor=(%d,%d) lookDx=%d lightLevel=%.2f lookStep=%d"):format(
        fx, fy, ShopProps.lookDx(L.lantern), ShopProps.lightLevel(), sc.lantern.lookStep), 10, H - 16)
    love.graphics.setCanvas()
    return cv
end

function M.run()
    local ShopProps = require("src.ui.shop.ShopProps")
    local S = tonumber(os.getenv("PROPS_SCALE") or "") or 3
    local missing = ShopProps.missingAssets()
    if #missing > 0 then
        print("[preview_shop_props] assets ausentes: " .. table.concat(missing, ", "))
    end
    love.graphics.setColor(1, 1, 1, 1)
    save(board(ShopProps, S, false), "shop_props_sheet.png")
    save(board(ShopProps, S, true), "shop_props_reduced.png")
    save(sceneBoard(ShopProps, S), "shop_props_scene.png")
    _G.gameSettings.reducedMotion = false
    love.event.quit(0)
    return true
end

return M
