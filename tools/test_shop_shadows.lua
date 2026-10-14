local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("test_shop_shadows")
    local P = require("tools.probe_shop_shadow")
    local ShopPerspective = require("src.ui.shop.ShopPerspective")
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local screen, scene, restore = P.openShop()
    local L = scene.L
    local objs = P.objects(scene)
    t:truthy(("objetos sondados >= 12 (obtido %d)"):format(#objs), #objs >= 12)
    local ax, ay = ShopLayout.shadowDir()
    t:truthy("sombra cai pra DIREITA (lean > 0)", ax > 0)
    t:truthy("sombra cai pra FRENTE (desce na tela)", ay > 0)

    local widths, counts = {}, {}
    for _, ob in ipairs(objs) do
        local o = ob.o
        local name = ob.name
        local set, n, box = P.render(o)
        local rset, rn = P.reference(o, ob.alphaAt)
        local iou = P.iou(set, rset)
        t:truthy(("%s: sombra existe (%d px)"):format(name, n), n > 50)
        t:truthy(("%s: shader == referencia Lua (IoU %.3f, gpu %d / ref %d)"):format(name, iou, n, rn), iou >= 0.97)
        if n > 0 then
            local W = (o.prof.x1 - o.prof.x0 + 1) * o.s
            local H = (o.prof.y1 - o.prof.y0 + 1) * o.s
            local fx, fy = math.floor(o.fx), math.floor(o.fy)
            local cb = ShopPerspective.castShadowBox(o)
            local outMask, outBox, aboveBase, leftOfFoot = 0, 0, 0, 0
            for key in pairs(set) do
                local y = math.floor(key / 4096)
                local x = key - y * 4096
                if not ShopLayout.pointInPoly(x + 0.5, y + 0.5, L.art.tableMask) then outMask = outMask + 1 end
                if x < cb.x or x >= cb.x + cb.w or y < cb.y or y >= cb.y + cb.h then outBox = outBox + 1 end
                local lx = x + 0.5 - fx
                local baseY = math.floor(fy + (o.k or 0) * lx)
                if y < baseY - 1 then aboveBase = aboveBase + 1 end
                if x < fx - W / 2 - 1 then leftOfFoot = leftOfFoot + 1 end
            end
            t:eq(name .. ": toda a sombra dentro do tampo", outMask, 0)
            t:eq(name .. ": toda a sombra dentro de castShadowBox (recorte da passada)", outBox, 0)
            t:eq(name .. ": nenhum pixel acima da base (sem arco pelas laterais)", aboveBase, 0)
            t:eq(name .. ": nada à esquerda da pegada (luz à esquerda)", leftOfFoot, 0)
            local shH = box.y1 - fy + 1
            local reach = box.x1 - (fx + W / 2)
            t:truthy(("%s: achatada: altura %d = %.0f%% do objeto (20..45)"):format(name, shH, 100 * shH / H),
                shH / H >= 0.2 and shH / H <= 0.45)
            t:truthy(("%s: deitada pra direita: alcance %d >= 25%% da altura %d"):format(name, reach, H),
                reach >= 0.25 * H)
            local fill = n / ((box.x1 - box.x0 + 1) * (box.y1 - box.y0 + 1))
            t:truthy(("%s: nao e retangulo (preenche %.0f%% da caixa)"):format(name, fill * 100), fill < 0.9)
            widths[#widths + 1] = box.x1 - box.x0 + 1
            counts[#counts + 1] = n
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

    local pot = byName("health_upgrade")
    if pot then
        local o0 = pot.o
        local set0, n0, b0 = P.render(o0)
        local o1 = {}
        for k, v in pairs(o0) do o1[k] = v end
        o1.lift = 12
        local set1, n1, b1 = P.render(o1)
        local rset1, rn1 = P.reference(o1, pot.alphaAt)
        t:truthy(("pocao levantada: shader == referencia (IoU %.3f)"):format(P.iou(set1, rset1)), P.iou(set1, rset1) >= 0.97)
        t:truthy(("pocao levantada: sombra mais rala (%d < %d px)"):format(n1, n0), n1 < n0)
        local dx, dy = b1.x0 - b0.x0, b1.y0 - b0.y0
        t:truthy(("pocao levantada: desloca pela projecao (dx %d ~ %.0f, dy %d ~ %.0f)"):format(dx, ax * 12, dy, ay * 12),
            math.abs(dx - ax * 12) <= 2 and math.abs(dy - ay * 12) <= 2)
        local _, nc1 = P.render(o1, "contact")
        t:eq("pocao levantada: sem linha de contato", nc1, 0)
        local alpha1 = ShopPerspective.castParams(o1).alpha
        local alpha0 = ShopPerspective.castParams(o0).alpha
        t:truthy(("pocao levantada: tinta mais clara (%.2f < %.2f)"):format(alpha1, alpha0), alpha1 < alpha0)
    else
        t:check("pocao sondada", false)
    end

    if bl then
        local o = bl.o
        local cset, cn = P.render(o, "contact")
        t:truthy(("sino: linha de contato existe (%d px)"):format(cn), cn >= 3)
        local prof = o.prof
        local cx = (prof.x0 + prof.x1 + 1) / 2
        local bottom = prof.y1 + 1
        local fx, fy = math.floor(o.fx), math.floor(o.fy)
        local bad, outMask = 0, 0
        for key in pairs(cset) do
            local y = math.floor(key / 4096)
            local x = key - y * 4096
            local lx = x + 0.5 - fx
            local b = prof.bottom[math.floor(cx + lx / (o.flip and -o.s or o.s))]
            local yB = b and math.floor(fy + (o.k or 0) * lx + (b + 1 - bottom) * o.s)
            if not (yB and y == yB + 1) then bad = bad + 1 end
            if not ShopLayout.pointInPoly(x + 0.5, y + 0.5, L.art.tableMask) then outMask = outMask + 1 end
        end
        t:eq("sino: contato = exatamente 1 px abaixo do contorno de baixo", bad, 0)
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
    return t:done()
end

return M
