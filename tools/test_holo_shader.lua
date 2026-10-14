local TK = require("tools.testkit")

local M = {}

local function drawWith(img, strength, kind, anim)
    local HoloShader = require("src.ui.HoloShader")
    local w, h = img:getWidth(), img:getHeight()
    local cv = love.graphics.newCanvas(w, h)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")
    HoloShader.draw(img, 0, 0, strength, 0, 1, 1, 0, 0, { kind = kind, anim = anim })
    love.graphics.pop()
    local data = cv:newImageData()
    cv:release()
    return data
end

local function diffCount(a, b, x0, y0, x1, y1)
    local n = 0
    for y = y0, y1 do
        for x = x0, x1 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            if math.abs(r1 - r2) > 0.01 or math.abs(g1 - g2) > 0.01
                or math.abs(b1 - b2) > 0.01 or math.abs(a1 - a2) > 0.01 then
                n = n + 1
            end
        end
    end
    return n
end

function M.run()
    local t = TK.new("holo em rara/lendaria: boot, gate pelo hover, nao lava a arte")
    TK.bootstrap()
    local HoloShader = require("src.ui.HoloShader")

    local src = love.filesystem.read("main.lua") or ""
    t:truthy("main.lua chama HoloShader.load() no boot",
        src:find('require("src.ui.HoloShader").load()', 1, true) ~= nil)

    t:truthy("HoloShader.load() compila shaders/holo.glsl", HoloShader.load())
    t:truthy("isAvailable() depois do load", HoloShader.isAvailable())

    t:eq("lendaria em repouso: 0.08", HoloShader.strengthFor("holo", 0), 0.08)
    t:eq("lendaria no hover: 0.5", HoloShader.strengthFor("holo", 1), 0.5)
    t:eq("rara em repouso: 0", HoloShader.strengthFor("glow", 0), 0)
    t:eq("rara no hover: 0.25", HoloShader.strengthFor("glow", 1), 0.25)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return 1.0 end
    local function drawSpied(id, hover, edition)
        local cd = db:getCard(id)
        if not cd then error("carta desconhecida no fixture: " .. tostring(id)) end
        local inst = db:createCardInstance(cd)
        inst.isHovered, inst.hoverStrength, inst.liftOffset = hover > 0, hover, 0
        if edition then inst.edition = edition end
        local calls, insideSets = {}, 0
        local realDraw, realSet = HoloShader.draw, love.graphics.setShader
        HoloShader.draw = function(img, x, y, strength, rot, sx, sy, ox, oy, opts)
            calls[#calls + 1] = { strength = strength, kind = opts and opts.kind, anim = opts and opts.anim }
            love.graphics.setShader = function(sh, ...)
                if sh then insideSets = insideSets + 1 end
                return realSet(sh, ...)
            end
            local r = realDraw(img, x, y, strength, rot, sx, sy, ox, oy, opts)
            love.graphics.setShader = realSet
            return r
        end
        local canvas = love.graphics.newCanvas(400, 560)
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(inst.draw, inst, 200, 280, false, false)
        love.graphics.pop()
        HoloShader.draw, love.graphics.setShader = realDraw, realSet
        canvas:release()
        if not ok then error(err, 0) end
        return inst, calls[1], insideSets
    end

    local okRun, err = pcall(function()
        local leg, c, sets = drawSpied("joker_001", 0)
        t:eq("fixture: lendaria tem visualEffect holo", leg.visualEffect, "holo")
        t:truthy("lendaria em repouso: forca 0.08 (brilho tenue no aro)",
            c and math.abs(c.strength - 0.08) < 1e-6)
        t:eq("lendaria em repouso: anim 0 (estatica)", c and c.anim, 0)
        t:eq("lendaria: kind 1 (dourado prismatico)", c and c.kind, 1)
        local _, c2 = drawSpied("joker_001", 1)
        t:truthy("lendaria no hover: forca 0.5", c2 and math.abs(c2.strength - 0.5) < 1e-6)
        t:eq("lendaria no hover: anim 1 (varredura corre)", c2 and c2.anim, 1)

        local rare, c3, sets3 = drawSpied("warrior_juggernaut", 0)
        t:eq("fixture: rara tem visualEffect glow", rare.visualEffect, "glow")
        t:truthy("rara em repouso: forca 0", c3 and c3.strength == 0)
        t:eq("rara em repouso: carta CRUA (nenhum shader dentro do HoloShader.draw)", sets3, 0)
        local _, c4, sets4 = drawSpied("warrior_juggernaut", 1)
        t:truthy("rara no hover: forca 0.25", c4 and math.abs(c4.strength - 0.25) < 1e-6)
        t:eq("rara no hover: kind 0 (prata-azulado)", c4 and c4.kind, 0)
        t:truthy("rara no hover: shader de verdade setado", sets4 > 0)

        local _, c5 = drawSpied("attack_001", 1)
        t:falsy("comum: sem holo nem no hover", c5)

        local _, c6 = drawSpied("attack_001", 1, "holo")
        t:truthy("edition holo numa comum: 0.5 no hover (era descartada em silencio)",
            c6 and math.abs(c6.strength - 0.5) < 1e-6 and c6.kind == 1)
        local _, c7 = drawSpied("attack_001", 0, "holo")
        t:truthy("edition holo em repouso: 0.08, estatica", c7 and math.abs(c7.strength - 0.08) < 1e-6 and c7.anim == 0)

        local img = leg.image
        local w, h = img:getWidth(), img:getHeight()
        local raw = drawWith(img, 0, 1, 0)
        local rawB = drawWith(img, 0, 1, 0)
        t:eq("forca 0: textura identica (pixel a pixel)", diffCount(raw, rawB, 0, 0, w - 1, h - 1), 0)
        local ix0, iy0, ix1, iy1 = 12, 28, w - 13, h - 26
        local legRest = drawWith(img, HoloShader.strengthFor("holo", 0), 1, 0)
        t:eq("lendaria em repouso: miolo da arte intocado", diffCount(raw, legRest, ix0, iy0, ix1, iy1), 0)
        t:truthy("lendaria em repouso: o aro acende (algum pixel muda)", diffCount(raw, legRest, 0, 0, w - 1, h - 1) > 0)
        local rimg = rare.image
        local rraw = drawWith(rimg, 0, 0, 0)
        local rareRest = drawWith(rimg, HoloShader.strengthFor("glow", 0), 0, 0)
        t:eq("rara em repouso: carta inteira identica a crua (pixel a pixel)",
            diffCount(rraw, rareRest, 0, 0, w - 1, h - 1), 0)
        local rareHover = drawWith(rimg, HoloShader.strengthFor("glow", 1), 0, 1)
        local washed = 0
        for y = iy0, iy1 do
            for x = ix0, ix1 do
                local r1, g1, b1 = rraw:getPixel(x, y)
                local r2, g2, b2 = rareHover:getPixel(x, y)
                local changed = math.abs(r1 - r2) > 0.01 or math.abs(g1 - g2) > 0.01 or math.abs(b1 - b2) > 0.01
                local lum = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
                if changed and lum <= 0.74 then washed = washed + 1 end
            end
        end
        t:eq("rara no hover: nenhum pixel escuro/medio da arte muda (so aro e brilhos)", washed, 0)
    end)
    love.timer.getTime = realGetTime
    t:check("sem excecao" .. (okRun and "" or (": " .. tostring(err))), okRun)

    return t:done()
end

return M
