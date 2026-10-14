local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local FontManager = require("src.ui.FontManager")

local ATOS = {
    { 1, "Campos Arruinados" }, { 2, "Colinas da Torre" },
    { 3, "Estrada do Abismo" }, { 4, "Geleira Espectral" },
    { 5, "Pântano da Podridão" }, { 6, "Campos do Crepúsculo" },
}
local COLUNAS = {
    { "Batalha",  "a", 1 }, { "Elite", "b", 1 }, { "Evento", "b", 2 },
    { "Descanso", "a", 2 }, { "Loja",  "a", 3 },
}
local NOS = {
    a = { { type = "battle" }, { type = "rest" }, { type = "shop" } },
    b = { { type = "elite" }, { type = "event" }, { type = "battle" } },
}

local CEL_W, CEL_H = 132, 150
local ESC = 2
local ESQ, TOPO, GAP = 150, 34, 5

local function cenaDe(ato, conjunto, w, h)
    WorldRoad.clearCache()
    WorldRoad.setBiome(ato)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._camZ = 5.5
    for _ = 1, 30 do WorldRoad.update(1 / 30) end
    WorldRoad.showFork(NOS[conjunto], function() end)
    local cv = love.graphics.newCanvas(w, h)
    for _ = 1, 22 do
        WorldRoad.update(1 / 30)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, 0, w, h, ato)
        WorldRoad.drawLightComposite(0, 0, w, h)
        love.graphics.setCanvas()
    end
    WorldRoad._fork = nil
    return cv
end

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local TW, TH = 1024, 700
    local BRACO = { TW * 0.5 - 0.157 * TW, TW * 0.5, TW * 0.5 + 0.157 * TW }
    local Y0 = 300

    local W = ESQ + #COLUNAS * (CEL_W * ESC + GAP)
    local H = TOPO + #ATOS * (CEL_H * ESC + GAP)
    local grade = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(grade)
    love.graphics.clear(0.07, 0.06, 0.055, 1)

    local fTitulo = FontManager.getFont(20)
    local fAto = FontManager.getFont(17)
    local fSub = FontManager.getFont(12)

    love.graphics.setFont(fTitulo)
    love.graphics.setColor(0.85, 0.76, 0.58, 1)
    for c, col in ipairs(COLUNAS) do
        local x = ESQ + (c - 1) * (CEL_W * ESC + GAP)
        love.graphics.print(col[1], math.floor(x + 6), 8)
    end

    for r, ato in ipairs(ATOS) do
        local oy = TOPO + (r - 1) * (CEL_H * ESC + GAP)
        love.graphics.setColor(0.85, 0.76, 0.58, 1)
        love.graphics.setFont(fAto)
        love.graphics.print("ATO " .. ato[1], 10, oy + 10)
        love.graphics.setFont(fSub)
        love.graphics.setColor(0.58, 0.52, 0.44, 1)
        love.graphics.printf(ato[2], 10, oy + 32, ESQ - 20, "left")

        local cenas = {}
        for _, conj in ipairs({ "a", "b" }) do
            love.graphics.setCanvas()
            cenas[conj] = cenaDe(ato[1], conj, TW, TH)
            love.graphics.setCanvas(grade)
        end

        love.graphics.setColor(1, 1, 1, 1)
        for c, col in ipairs(COLUNAS) do
            local cena = cenas[col[2]]
            local cx = math.floor(BRACO[col[3]] - CEL_W / 2)
            local quad = love.graphics.newQuad(cx, Y0, CEL_W, CEL_H,
                cena:getWidth(), cena:getHeight())
            local ox = ESQ + (c - 1) * (CEL_W * ESC + GAP)
            love.graphics.draw(cena, quad, ox, oy, 0, ESC, ESC)
        end
    end

    love.graphics.setCanvas()
    local dados = grade:newImageData()
    dados:encode("png", "grade_locais_por_ato.png")
    print("[grade] 5 locais x 6 atos -> grade_locais_por_ato.png (" .. W .. "x" .. H .. ")")
    return true
end

return M
