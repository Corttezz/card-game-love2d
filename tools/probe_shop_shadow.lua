local M = {}

local ShopPerspective = require("src.ui.shop.ShopPerspective")
local ShopLayout = require("src.ui.shop.ShopLayout")

function M.alphaReader(path, rect)
    local data = love.image.newImageData(path)
    local ox, oy = rect and rect.x or 0, rect and rect.y or 0
    local w, h = data:getWidth(), data:getHeight()
    return function(sx, sy)
        local x, y = ox + sx, oy + sy
        if x < 0 or y < 0 or x >= w or y >= h then return 0 end
        local _, _, _, a = data:getPixel(x, y)
        return a
    end
end

function M.render(o, what)
    local A = ShopLayout.ART
    local c = love.graphics.newCanvas(A.w, A.h)
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    if what == "contact" then
        ShopPerspective.drawContactShadow(o, A.tableMask, 1)
    elseif what == "both" then
        ShopPerspective.drawObjectShadow(o, A.tableMask, 1)
    else
        ShopPerspective.drawCastShadow(o, 1)
    end
    love.graphics.pop()
    local d = c:newImageData()
    local set, n = {}, 0
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for y = 0, A.h - 1 do
        for x = 0, A.w - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.05 then
                set[y * 4096 + x] = true
                n = n + 1
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y < y0 then y0 = y end
                if y > y1 then y1 = y end
            end
        end
    end
    c:release()
    return set, n, (n > 0) and { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } or nil
end

function M.renderObject(o)
    local A = ShopLayout.ART
    local c = love.graphics.newCanvas(A.w, A.h)
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    local q = {}
    for k, v in pairs(o) do q[k] = v end
    q.outline, q.color, q.alpha = 0, { 1, 1, 1 }, 1
    local src = o.prof and o.prof.src
    if src then
        local cv = love.graphics.newCanvas(src.w, src.h)
        cv:setFilter("nearest", "nearest")
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.draw(o.img, love.graphics.newQuad(src.x, src.y, src.w, src.h, o.img:getWidth(), o.img:getHeight()), 0, 0)
        love.graphics.setCanvas(c)
        q.img = cv
    end
    ShopPerspective.drawUpright(q)
    love.graphics.pop()
    local d = c:newImageData()
    c:release()
    local set, low, minX, maxX = {}, {}, math.huge, -math.huge
    for y = 0, A.h - 1 do
        for x = 0, A.w - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.5 then
                set[y * 4096 + x] = true
                if not low[x] or y > low[x] then low[x] = y end
                if x < minX then minX = x end
                if x > maxX then maxX = x end
            end
        end
    end
    return set, low, minX, maxX
end

function M.groundAudit(o)
    local objSet, low, minX, maxX = M.renderObject(o)
    local shSet = M.render(o, "both")
    local prof = o.prof
    local s = o.s
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local fx = math.floor(o.fx)
    local mask = ShopLayout.ART.tableMask
    local checked, gaps, gapCols = 0, 0, {}
    for x = minX, maxX do
        local lx = x + 0.5 - fx
        local c = math.floor(cx + lx / (o.flip and -s or s))
        local y = low[x]
        if y and prof.contact and prof.contact[c] and ShopLayout.pointInPoly(x + 0.5, y + 1.5, mask) then
            checked = checked + 1
            if not shSet[(y + 1) * 4096 + x] then
                gaps = gaps + 1
                gapCols[#gapCols + 1] = x
            end
        end
    end
    local objMaxY = -math.huge
    for _, y in pairs(low) do if y > objMaxY then objMaxY = y end end
    local below, right, left = 0, 0, 0
    for key in pairs(shSet) do
        if not objSet[key] then
            local y = math.floor(key / 4096)
            local x = key - y * 4096
            if y - objMaxY > below then below = y - objMaxY end
            if x > maxX and x - maxX > right then right = x - maxX end
            if x < minX and minX - x > left then left = minX - x end
        end
    end
    return { checked = checked, gaps = gaps, gapCols = gapCols, below = below, right = right, left = left,
             objW = maxX - minX + 1 }
end

function M.reference(o, alphaAt)
    local ref = ShopPerspective.castShadowRef(o, alphaAt)
    local set, n = {}, 0
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #ref, 2 do
        local x, y = ref[i], ref[i + 1]
        set[y * 4096 + x] = true
        n = n + 1
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
    end
    return set, n, (n > 0) and { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } or nil
end

function M.iou(a, b)
    local inter, union = 0, 0
    for k in pairs(a) do union = union + 1; if b[k] then inter = inter + 1 end end
    for k in pairs(b) do if not a[k] then union = union + 1 end end
    if union == 0 then return 0 end
    return inter / union
end

function M.openShop(w, h)
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.i18n.I18n").init()
    w, h = w or 1280, h or 720
    local rw, rh = love.graphics.getWidth, love.graphics.getHeight
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    local realMouse = love.mouse.getPosition
    love.mouse.getPosition = function() return 5, 5 end
    local EM = require("engine.EventManager")
    local game = TK.newRunGame("warrior")
    game.economySystem.currentGold = 60
    _G.openScribeDice = _G.openScribeDice or function() end
    local screen = require("components.CardRewardScreen"):new(game.shopSystem)
    screen:show(game, function() end, function() end, "shop")
    for _ = 1, 90 do EM.update(1 / 60); screen:update(1 / 60) end
    return screen, screen.scene, function()
        love.graphics.getWidth, love.graphics.getHeight = rw, rh
        love.mouse.getPosition = realMouse
    end
end

M.RELICS = { "remove_card", "joker_slot", "health_upgrade", "mana_upgrade", "duplicate_card",
             "forge_card", "card_draw_upgrade", "interest_cap", "damage_upgrade", "defense_upgrade" }

function M.objects(scene)
    local L = scene.L
    local out = {}
    local relic, pack
    for _, it in ipairs(scene.items) do
        if it.kind == "relic" and not relic then relic = it end
        if it.kind == "pack" then pack = it end
    end
    if relic then
        local origId = relic.offer.id
        for _, id in ipairs(M.RELICS) do
            relic.offer.id = id
            local o = relic:uprightParams(L, false, 0)
            local _, path = ShopPerspective.spriteFor("relic", relic.offer, false, 0)
            if o and path and love.filesystem.getInfo(path) then
                out[#out + 1] = { name = id, o = o, alphaAt = M.alphaReader(path), item = relic, path = path }
            else
                print(("[probe] %s: sem sprite/perfil (%s)"):format(id, tostring(path)))
            end
        end
        relic.offer.id = origId
    end
    if pack then
        local o = pack:uprightParams(L, false, 0)
        local _, path = ShopPerspective.spriteFor("pack", pack.offer, false, 0)
        if o and path then out[#out + 1] = { name = "pack:" .. tostring(pack.offer.id), o = o, alphaAt = M.alphaReader(path), item = pack, path = path } end
    end
    local bo = scene:_bellParams()
    if bo then out[#out + 1] = { name = "bell", o = bo, alphaAt = M.alphaReader("assets/sprites/shop/objects/bell.png") } end
    local co = scene:_diceShadowParams()
    if co then out[#out + 1] = { name = "dice_cup", o = co, alphaAt = M.alphaReader("assets/sprites/shop/dice_cup.png", co.prof.src) } end
    return out
end

function M.run()
    local screen, scene, restore = M.openShop()
    local objs = M.objects(scene)
    print(("[probe] %d objetos; direção da sombra = (%.2f, %.3f) por px de altura"):format(#objs, ShopLayout.shadowDir()))
    for _, ob in ipairs(objs) do
        local o = ob.o
        local set, n, box = M.render(o)
        local rset, rn, rbox = M.reference(o, ob.alphaAt)
        local H = (o.prof.y1 - o.prof.y0 + 1) * o.s
        local W = (o.prof.x1 - o.prof.x0 + 1) * o.s
        print(("[probe] %-22s gpu=%4d ref=%4d iou=%.3f  obj %dx%d pé=(%d,%d)  caixa gpu=%s  ref=%s"):format(
            ob.name, n, rn, M.iou(set, rset), W, H, math.floor(o.fx), math.floor(o.fy),
            box and ("%d..%d x %d..%d"):format(box.x0, box.x1, box.y0, box.y1) or "-",
            rbox and ("%d..%d x %d..%d"):format(rbox.x0, rbox.x1, rbox.y0, rbox.y1) or "-"))
        local au = M.groundAudit(o)
        print(("[probe] %-22s pegada: %d colunas, vaos %d [%s]  abaixo %d  direita %d  esquerda %d"):format(
            ob.name, au.checked, au.gaps, table.concat(au.gapCols, ","), au.below, au.right, au.left))
    end
    for _, ob in ipairs(objs) do
        if ob.name == "health_upgrade" then
            local o = {}
            for k, v in pairs(ob.o) do o[k] = v end
            o.lift = 12
            local set, n, box = M.render(o)
            local _, cn = M.render(o, "contact")
            print(("[probe] %-22s levantado 12: gpu=%4d contato=%d caixa=%s"):format(ob.name, n, cn,
                box and ("%d..%d x %d..%d"):format(box.x0, box.x1, box.y0, box.y1) or "-"))
        end
    end
    restore()
    return true
end

return M
