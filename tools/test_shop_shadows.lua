local TK = require("tools.testkit")
local M = {}

M.SIZES = { { 1600, 900 }, { 1920, 1080 }, { 1280, 720 }, { 1024, 768 } }

local function sceneObjects(P, scene)
    local L = scene.L
    local out = {}
    for _, it in ipairs(scene.items) do
        if it.kind ~= "card" and it.rect and not it.sold then
            local o = it:uprightParams(L, false, 0)
            if o then out[#out + 1] = { name = it.kind .. ":" .. tostring(it.offer and it.offer.id), o = o } end
        end
    end
    local bo = scene:_bellParams()
    if bo then out[#out + 1] = { name = "bell", o = bo } end
    local co = scene:_diceShadowParams()
    if co then out[#out + 1] = { name = "dice_cup", o = co } end
    return out
end

local function auditGround(t, P, ShopLayout, ShopPerspective, tag, ob)
    local o = ob.o
    local au = P.groundAudit(o)
    local ax, ay = ShopLayout.shadowDir()
    local Heff = ShopPerspective.flatHeight(o)
    local Htot = Heff + (o.lift or 0)
    t:truthy(("%s %s: pegada medida (%d colunas de contato)"):format(tag, ob.name, au.checked), au.checked >= 3)
    t:eq(("%s %s: sombra colada na pegada (vaos de mesa entre base e sombra) [%s]"):format(tag, ob.name,
        table.concat(au.gapCols, ",")), au.gaps, 0)
    t:truthy(("%s %s: sombra nao desce alem de %d px da base (obtido %d)"):format(tag, ob.name,
        math.ceil(ay * Htot) + 3, au.below), au.below <= math.ceil(ay * Htot) + 3)
    t:truthy(("%s %s: sombra nao passa de %d px a direita da silhueta (obtido %d)"):format(tag, ob.name,
        math.ceil(ax * Htot) + 2, au.right), au.right <= math.ceil(ax * Htot) + 2)
    t:truthy(("%s %s: nada a esquerda da silhueta (obtido %d)"):format(tag, ob.name, au.left), au.left <= 1)
    return au
end

function M.run()
    local t = TK.new("test_shop_shadows")
    local P = require("tools.probe_shop_shadow")
    local ShopPerspective = require("src.ui.shop.ShopPerspective")
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local FP = require("src.data.shop_footprints")
    local screen, scene, restore = P.openShop()
    local L = scene.L
    local objs = P.objects(scene)
    t:truthy(("objetos sondados >= 12 (obtido %d)"):format(#objs), #objs >= 12)
    local ax, ay = ShopLayout.shadowDir()
    t:truthy("sombra cai pra DIREITA (lean > 0)", ax > 0)
    t:truthy("sombra cai pra FRENTE (desce na tela)", ay > 0)

    for path, fp in pairs(FP) do
        t:truthy(("pegada %s: arquivo existe"):format(path), love.filesystem.getInfo(path) ~= nil)
        local data = love.filesystem.getInfo(path) and love.image.newImageData(path)
        if data then
            local fw = path:find("dice_cup", 1, true) and 32 or data:getWidth()
            local bad = 0
            for _, sp in ipairs(fp.spans or {}) do
                for x = sp[1], sp[2] do
                    local any = false
                    for y = 0, data:getHeight() - 1 do
                        if x < fw and select(4, data:getPixel(x, y)) > 0.5 then any = true break end
                    end
                    if not any then bad = bad + 1 end
                end
            end
            t:eq(("pegada %s: toda coluna de contato tem pixel no sprite"):format(path), bad, 0)
        end
    end

    local widths = {}
    for _, ob in ipairs(objs) do
        local o = ob.o
        local name = ob.name
        local set, n, box = P.render(o)
        local rset, rn = P.reference(o, ob.alphaAt)
        local iou = P.iou(set, rset)
        t:truthy(("%s: sombra existe (%d px)"):format(name, n), n > 50)
        t:truthy(("%s: shader == referencia Lua (IoU %.3f, gpu %d / ref %d)"):format(name, iou, n, rn), iou >= 0.97)
        local prof = o.prof
        local path = ob.path
        if name == "bell" then path = "assets/sprites/shop/objects/bell.png" end
        if name == "dice_cup" then path = "assets/sprites/shop/dice_cup.png" end
        t:truthy(("%s: pegada medida em src/data/shop_footprints.lua (%s)"):format(name, tostring(path)),
            path and FP[path] ~= nil)
        if n > 0 then
            local Heff, flat = ShopPerspective.flatHeight(o)
            local W = (prof.x1 - prof.x0 + 1) * o.s
            local fx, fy = math.floor(o.fx), math.floor(o.fy)
            local cb = ShopPerspective.castShadowBox(o)
            local objSet, objLow = P.renderObject(o)
            local cx = (prof.x0 + prof.x1 + 1) / 2
            local bottom = prof.y1 + 1
            local outMask, outBox, aboveGround, leftOfFoot = 0, 0, 0, 0
            for key in pairs(set) do
                local y = math.floor(key / 4096)
                local x = key - y * 4096
                if not ShopLayout.pointInPoly(x + 0.5, y + 0.5, L.art.tableMask) then outMask = outMask + 1 end
                if x < cb.x or x >= cb.x + cb.w or y < cb.y or y >= cb.y + cb.h then outBox = outBox + 1 end
                local lx = x + 0.5 - fx
                local c = math.floor(cx + lx / (o.flip and -o.s or o.s))
                if not objSet[key] and c >= prof.x0 and c <= prof.x1 then
                    local yG = math.floor(fy + (o.k or 0) * lx + (ShopPerspective.groundAt(prof, c) + 1 - bottom) * o.s)
                    local enclosed = objLow[x] and y < objLow[x]
                    if y < yG - 2 and not flat and not enclosed then aboveGround = aboveGround + 1 end
                end
                if x < fx - W / 2 - 1 then leftOfFoot = leftOfFoot + 1 end
            end
            t:eq(name .. ": toda a sombra dentro do tampo", outMask, 0)
            t:eq(name .. ": toda a sombra dentro de castShadowBox (recorte da passada)", outBox, 0)
            t:eq(name .. ": nenhum pixel visivel acima do chao da propria coluna (sem arco)", aboveGround, 0)
            t:eq(name .. ": nada a esquerda da pegada (luz a esquerda)", leftOfFoot, 0)
            local shH = box.y1 - fy + 1
            local reach = box.x1 - (fx + W / 2)
            if flat then
                t:truthy(("%s: objeto deitado (altura %d): sombra rente, alcance %d <= %d"):format(name, Heff, reach,
                    math.ceil(ax * Heff) + 2), reach <= math.ceil(ax * Heff) + 2)
            else
                t:truthy(("%s: achatada: altura %d = %.0f%% do objeto (15..45)"):format(name, shH, 100 * shH / Heff),
                    shH / Heff >= 0.15 and shH / Heff <= 0.45)
                t:truthy(("%s: deitada pra direita: alcance %d >= 25%% da altura %d"):format(name, reach, Heff),
                    reach >= 0.25 * Heff)
            end
            local fill = n / ((box.x1 - box.x0 + 1) * (box.y1 - box.y0 + 1))
            t:truthy(("%s: nao e retangulo (preenche %.0f%% da caixa)"):format(name, fill * 100), fill < 0.9)
            widths[#widths + 1] = box.x1 - box.x0 + 1
            auditGround(t, P, ShopLayout, ShopPerspective, "repouso", ob)
        end
    end
    local distinct = {}
    for _, w in ipairs(widths) do distinct[w] = true end
    local nd = 0
    for _ in pairs(distinct) do nd = nd + 1 end
    t:truthy(("larguras de sombra distintas: %d de %d objetos"):format(nd, #widths), nd >= math.floor(#widths * 0.6))
    local function byName(n) for _, ob in ipairs(objs) do if ob.name == n then return ob end end end
    local sc, bl, pk = byName("remove_card"), byName("bell"), nil
    for _, ob in ipairs(objs) do if ob.name:find("^pack:") then pk = ob end end
    if sc and bl and pk then
        local _, ns, bs = P.render(sc.o)
        local _, nb, bb = P.render(bl.o)
        local _, np, bp = P.render(pk.o)
        local ws, wb, wp = bs.x1 - bs.x0 + 1, bb.x1 - bb.x0 + 1, bp.x1 - bp.x0 + 1
        t:truthy(("tesoura (%d px, %d larg) != sino (%d, %d) != pacote (%d, %d)"):format(ns, ws, nb, wb, np, wp),
            ws ~= wb and wb ~= wp and ws ~= wp and ns ~= nb and nb ~= np)
    else
        t:check("tesoura, sino e pacote sondados", false)
    end

    local book = byName("card_draw_upgrade")
    if book then
        local Heff, flat = ShopPerspective.flatHeight(book.o)
        t:truthy(("livro aberto e deitado: altura de sombra %d < 12 px"):format(Heff), flat and Heff < 12)
    end

    local pot = byName("health_upgrade")
    if pot then
        local o0 = pot.o
        local set0, n0, b0 = P.render(o0)
        local o1 = {}
        for k, v in pairs(o0) do o1[k] = v end
        o1.lift = 12
        local set1, n1, b1 = P.render(o1)
        local rset1 = P.reference(o1, pot.alphaAt)
        t:truthy(("pocao levantada: shader == referencia (IoU %.3f)"):format(P.iou(set1, rset1)), P.iou(set1, rset1) >= 0.97)
        t:truthy(("pocao levantada: sombra mais rala (%d < %d px)"):format(n1, n0), n1 < n0)
        t:truthy(("pocao levantada: sombra fica debaixo dela e encolhe (x %d..%d dentro de %d..%d, y ate %d <= %d)"):format(
            b1.x0, b1.x1, b0.x0, b0.x1, b1.y1, b0.y1),
            b1.x0 >= b0.x0 - 1 and b1.x1 < b0.x1 and b1.y1 <= b0.y1)
        local _, nc1 = P.render(o1, "contact")
        t:eq("pocao levantada: sem linha de contato", nc1, 0)
        local alpha1 = ShopPerspective.castParams(o1).alpha
        local alpha0 = ShopPerspective.castParams(o0).alpha
        t:truthy(("pocao levantada: tinta mais clara (%.2f < %.2f)"):format(alpha1, alpha0), alpha1 < alpha0)
        local cxs = (b1.x0 + b1.x1) / 2
        local fx = math.floor(o1.fx)
        local W1 = (o1.prof.x1 - o1.prof.x0 + 1) * o1.s
        t:truthy(("pocao levantada: centro da sombra %.0f a no maximo meia largura (%.0f) do pe %d"):format(cxs, W1 / 2, fx),
            math.abs(cxs - fx) <= W1 / 2)
    else
        t:check("pocao sondada", false)
    end

    if bl then
        local o = bl.o
        local cset, cn = P.render(o, "contact")
        t:truthy(("sino: contato existe (%d px)"):format(cn), cn >= 3)
        local prof = o.prof
        local cx = (prof.x0 + prof.x1 + 1) / 2
        local bottom = prof.y1 + 1
        local fx, fy = math.floor(o.fx), math.floor(o.fy)
        local bad, outMask = 0, 0
        for key in pairs(cset) do
            local y = math.floor(key / 4096)
            local x = key - y * 4096
            local lx = x + 0.5 - fx
            local c = math.floor(cx + lx / (o.flip and -o.s or o.s))
            local b = prof.bottom[c]
            local yB = b and ShopPerspective.lowestRow(fy, o.k or 0, lx, b, bottom, o.s)
            if not (yB and y > yB and y <= yB + ShopPerspective.CONTACT_ROWS) then bad = bad + 1 end
            if not ShopLayout.pointInPoly(x + 0.5, y + 0.5, L.art.tableMask) then outMask = outMask + 1 end
        end
        t:eq("sino: contato colado sob a ultima linha desenhada do sprite (1 a 2 px)", bad, 0)
        t:eq("sino: contato dentro do tampo", outMask, 0)
    end

    local sh1 = ShopPerspective.castShadowShader()
    local sh2 = ShopPerspective.castShadowShader()
    t:truthy("shader da sombra compilado", sh1 ~= nil)
    t:truthy("shader compilado UMA vez (cache)", sh1 == sh2)
    if bl then
        local A = ShopLayout.ART
        local c = love.graphics.newCanvas(A.w, A.h)
        love.graphics.push("all")
        love.graphics.setCanvas(c)
        for _ = 1, 5 do ShopPerspective.drawObjectShadow(bl.o, A.tableMask, 1) end
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 200 do ShopPerspective.drawObjectShadow(bl.o, A.tableMask, 1) end
        local per = (collectgarbage("count") - k0) / 200
        collectgarbage("restart")
        love.graphics.pop()
        c:release()
        t:truthy(("alocacao por sombra <= 0.5 KB (obtido %.3f KB)"):format(per), per <= 0.5)
    end
    local order = {}
    local realCast, realUp = ShopPerspective.drawCastShadow, ShopPerspective.drawUpright
    ShopPerspective.drawCastShadow = function(...) order[#order + 1] = "shadow" return realCast(...) end
    ShopPerspective.drawUpright = function(...) order[#order + 1] = "object" return realUp(...) end
    local realEllipse = love.graphics.ellipse
    local ellipses = 0
    love.graphics.ellipse = function(...) ellipses = ellipses + 1 return realEllipse(...) end
    local okDraw, err = pcall(function()
        local c = love.graphics.newCanvas(1280, 720)
        love.graphics.push("all")
        love.graphics.setCanvas(c)
        screen:draw()
        love.graphics.pop()
        c:release()
    end)
    love.graphics.ellipse = realEllipse
    ShopPerspective.drawCastShadow, ShopPerspective.drawUpright = realCast, realUp
    t:truthy("cena desenha sem erro" .. (okDraw and "" or (": " .. tostring(err))), okDraw)
    t:eq("nenhuma elipse", ellipses, 0)
    local shadows, firstObj, lastShadow = 0, nil, nil
    for i, what in ipairs(order) do
        if what == "shadow" then shadows = shadows + 1; lastShadow = i
        elseif not firstObj then firstObj = i end
    end
    t:truthy(("cena: %d sombras projetadas (relíquias + pacote + sino + copo = 6)"):format(shadows), shadows == 6)
    t:truthy("cena: todas as sombras ANTES do primeiro objeto da mesa", lastShadow and firstObj and lastShadow < firstObj)
    restore()

    for _, sz in ipairs(M.SIZES) do
        local _, sc2, restore2 = P.openShop(sz[1], sz[2])
        local list = sceneObjects(P, sc2)
        t:truthy(("%dx%d: objetos da mesa na cena (%d)"):format(sz[1], sz[2], #list), #list >= 6)
        for _, ob in ipairs(list) do
            auditGround(t, P, ShopLayout, ShopPerspective, ("%dx%d"):format(sz[1], sz[2]), ob)
        end
        restore2()
    end
    return t:done()
end

return M
