local TK = require("tools.testkit")
local M = {}

local function poolArgs(tod)
    return { gx = 128, gy = 64, flameH = 80, t = 1, seed = 3, capR = 1e9, alphaK = 1, tod = tod }
end

local function grassPixels(Spill)
    local d = love.image.newImageData(2, 2)
    d:mapPixel(function() return 0.10, 0.16, 0.06, 1 end)
    local img = love.graphics.newImage(d)
    local cv = love.graphics.newCanvas(256, 128)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    local sh = Spill.spriteShader()
    love.graphics.setShader(sh)
    love.graphics.draw(img, 0, 0, 0, 128, 64)
    love.graphics.setShader()
    love.graphics.setCanvas()
    love.graphics.pop()
    local out = cv:newImageData()
    local function at(x, y) local r, g, b = out:getPixel(x, y); return r + g + b end
    local res = { center = at(128, 66), edge = at(128 + 60, 66), outside = at(4, 4),
        below = at(128, 74), above = at(128, 54) }
    out:release(); cv:release(); img:release(); d:release()
    return res, sh ~= nil
end

function M.run()
    local t = TK.new("Luz das luminárias derrama na grama e no mato (LightSpill)")
    local Lum = require("engine.LuminaireEngine")
    local LightEngine = require("engine.LightEngine")
    local Spill = require("engine.LightSpill")
    local GF = require("engine.GrassField")
    LightEngine.setEnabled(true)

    local okG, errG = pcall(love.graphics.newShader, GF.SHADER_PIXEL, GF.SHADER_VERTEX)
    t:truthy("shader da grama compila com o derrame (" .. tostring(okG and "" or errG) .. ")", okG)

    Spill.beginFrame()
    Lum.drawPool("fields", "lantern", poolArgs(0.30))
    t:eq("de dia: nada registrado", Spill.count(), 0)

    Spill.beginFrame()
    Lum.drawPool("fields", "lantern", poolArgs(1.0))
    t:eq("ao anoitecer: a poça registra o derrame", Spill.count(), 1)
    local p, c = Spill.at(1)
    t:near("centro x = base da luminária", p[1], 128, 1)
    t:near("centro y = base da luminária", p[2], 64, 1)
    t:truthy("cor quente (R > B)", c[1] > c[3])
    t:truthy("metade de trás mais curta (upK > 1)", c[4] > 1)

    local px, hasSh = grassPixels(Spill)
    t:truthy("shader de sprite disponível", hasSh)
    t:truthy("grama no centro da poça clareia", px.center > px.outside + 0.15)
    t:truthy("queda suave: borda mais fraca que o centro", px.edge < px.center and px.edge >= px.outside - 1e-3)
    t:truthy("fora da poça: grama intacta", math.abs(px.outside - (0.10 + 0.16 + 0.06)) < 0.02)
    t:truthy("frente da base recebe mais que atrás", px.below > px.above)

    Spill.beginFrame()
    t:eq("frame novo zera o derrame", Spill.count(), 0)
    t:truthy("sem luz registrada: sem shader extra", Spill.spriteShader() == nil)

    LightEngine.setEnabled(false)
    Spill.beginFrame()
    Lum.drawPool("fields", "lantern", poolArgs(1.0))
    t:eq("iluminação desligada: sem derrame", Spill.count(), 0)
    LightEngine.setEnabled(nil)
    Spill.beginFrame()
    return t:done()
end

return M
