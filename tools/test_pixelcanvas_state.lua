local TK = require("tools.testkit")
local PixelCanvas = require("src.ui.PixelCanvas")

local M = {}

local function opaqueSamples(canvas)
    local d = canvas:newImageData()
    local n = 0
    for y = 0, d:getHeight() - 1, 12 do
        for x = 0, d:getWidth() - 1, 8 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.5 then n = n + 1 end
        end
    end
    return n
end

function M.run()
    TK.bootstrap()
    local t = TK.new("pixelcanvas: beginDraw isola estado do chamador")

    love.graphics.push()
    love.graphics.translate(500, 500)
    love.graphics.scale(2, 2)
    love.graphics.setScissor(0, 0, 8, 8)

    local c = PixelCanvas.new(32, 32)
    PixelCanvas.beginDraw(c, true)
    PixelCanvas.rect(0, 0, 32, 32, { 1, 0, 0 })
    PixelCanvas.endDraw()

    local tx, ty = love.graphics.transformPoint(0, 0)
    t:eq("transform do chamador restaurada (x)", tx, 500)
    t:eq("transform do chamador restaurada (y)", ty, 500)
    local _, _, sw, sh = love.graphics.getScissor()
    t:eq("scissor do chamador restaurado (w)", sw, 8)
    t:eq("scissor do chamador restaurado (h)", sh, 8)
    love.graphics.setScissor()
    love.graphics.pop()

    local d = c:newImageData()
    local rMid = d:getPixel(16, 16)
    local rEdge = d:getPixel(30, 30)
    t:near("pixel central pintado (transform não vazou)", rMid, 1, 0.02)
    t:near("pixel de borda pintado (scissor não vazou)", rEdge, 1, 0.02)

    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.ui.CardArt")
    local IconFramesLoader = require("src.ui.IconFramesLoader")
    local CardFrame = require("src.ui.CardFrame")

    local db = CardDatabase:new()
    local animCard
    for _, cd in pairs(db:getAllCards()) do
        local art = CardArt.resolve(cd)
        if art.iconName and IconFramesLoader.has(art.iconName) then
            animCard = cd
            break
        end
    end
    t:truthy("existe carta com ícone animado no catálogo", animCard ~= nil)
    if not animCard then return t:done() end

    local card = db:createCardInstance(animCard)
    CardFrame.invalidate(card)
    CardFrame.render(card)

    love.graphics.push()
    love.graphics.translate(300, 620)
    love.graphics.scale(1.3, 1.3)
    local anim = CardFrame.getAnimation(card)
    love.graphics.pop()

    t:truthy("getAnimation sob transform devolve animação", anim ~= nil)
    if anim then
        local blanks = 0
        local ref = opaqueSamples(anim.canvases[1])
        for i, cv in ipairs(anim.canvases) do
            local n = opaqueSamples(cv)
            if n < ref * 0.6 then blanks = blanks + 1 end
        end
        t:eq("nenhum frame em branco/deslocado (bug carta piscando)", blanks, 0)
        t:truthy("frame 0 tem conteúdo", ref > 20)
    end

    return t:done()
end

return M
