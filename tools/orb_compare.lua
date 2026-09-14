-- tools/orb_compare.lua
-- UMA imagem comparando o design ATUAL da fileira de orbes com as propostas,
-- no tamanho de uso E ampliado, sobre o fundo real da tela.
-- Existe porque aprovacao de arte se faz OLHANDO, e o dono precisa do arquivo.
--   love . orb_compare  ->  orbes_comparacao.png no save dir
local M = {}

local ELEMS   = { "lightning", "ice", "fire", "dark", "holy" }
local VALORES = { "3", "3", "3", "5", "+3" }
local CORES = {
    lightning = { 0.98, 0.85, 0.30 }, ice = { 0.45, 0.75, 0.95 },
    fire = { 0.98, 0.52, 0.20 }, dark = { 0.68, 0.40, 0.90 },
    holy = { 0.96, 0.92, 0.70 },
}

function M.run()
    local OrbRow = require("src.ui.OrbRow")
    local FontManager = require("src.ui.FontManager")
    local Palette = require("src.ui.Palette")

    local SIZE, GAP, Z = 46, 16, 3          -- Z = zoom da imagem inteira
    local COLW = SIZE + GAP
    local W = #ELEMS * COLW + GAP
    local ROWH = SIZE + 62
    local cvW, cvH = W, ROWH * 3 + 16

    local cv = love.graphics.newCanvas(cvW, cvH)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.10, 0.08, 0.07, 1)

    local fLbl = FontManager.getFont(11)
    local fNum = FontManager.getFont(18)
    local fSml = FontManager.getFont(12)

    local function titulo(txt, y)
        love.graphics.setFont(fLbl)
        love.graphics.setColor(0.72, 0.66, 0.54, 1)
        love.graphics.print(txt, GAP, y)
    end

    -- ===== 1: como esta hoje — contorno colorido, interior vazio =====
    titulo("AGORA  (contorno vazio)", 6)
    for i, el in ipairs(ELEMS) do
        local x, y = GAP + (i - 1) * COLW, 24
        local pts = OrbRow._shapePoints and OrbRow._shapePoints(el, x + SIZE / 2, y + SIZE / 2, SIZE / 2 - 2)
        local c = CORES[el]
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.setLineWidth(2)
        if pts then love.graphics.polygon("line", pts)
        else love.graphics.circle("line", x + SIZE / 2, y + SIZE / 2, SIZE / 2 - 2) end
        love.graphics.setLineWidth(1)
        love.graphics.setFont(fNum)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(VALORES[i], x, y + SIZE / 2 - 11, SIZE, "center")
    end

    local function gema(el, x, y)
        local ok, img = pcall(love.graphics.newImage,
            "assets/sprites/orbs_preview/orb_" .. el .. ".png")
        if not ok then return end
        img:setFilter("nearest", "nearest")
        local s = SIZE / img:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, s, s)
    end

    -- ===== 2: gema com o numero POR CIMA =====
    titulo("GEMA  ·  numero sobre a pedra", ROWH + 2)
    for i, el in ipairs(ELEMS) do
        local x, y = GAP + (i - 1) * COLW, ROWH + 20
        gema(el, x, y)
        love.graphics.setFont(fNum)
        FontManager.drawWithOutline(VALORES[i],
            x + SIZE / 2 - fNum:getWidth(VALORES[i]) / 2, y + SIZE / 2 - 11,
            { 1, 1, 1, 1 }, 1.0)
    end

    -- ===== 3: gema com o numero numa placa ABAIXO =====
    titulo("GEMA  ·  numero em placa embaixo", ROWH * 2 + 2)
    for i, el in ipairs(ELEMS) do
        local x, y = GAP + (i - 1) * COLW, ROWH * 2 + 18
        gema(el, x, y)
        local pw, ph = SIZE - 6, 16
        local px, py = x + 3, y + SIZE - 2
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92)
        love.graphics.rectangle("fill", px, py, pw, ph)
        local c = CORES[el]
        love.graphics.setColor(c[1], c[2], c[3], 0.9)
        love.graphics.rectangle("line", px, py, pw, ph)
        love.graphics.setFont(fSml)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(VALORES[i], px, py + 1, pw, "center")
    end

    love.graphics.setCanvas()

    -- salva AMPLIADO (o defeito e a leitura, e o dono precisa enxergar)
    local big = love.graphics.newCanvas(cvW * Z, cvH * Z)
    love.graphics.setCanvas(big)
    love.graphics.clear(0.10, 0.08, 0.07, 1)
    cv:setFilter("nearest", "nearest")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, 0, 0, 0, Z, Z)
    love.graphics.setCanvas()
    big:newImageData():encode("png", "orbes_comparacao.png")

    print("[orb_compare] orbes_comparacao.png (" .. cvW * Z .. "x" .. cvH * Z .. ")")
    love.event.quit(0)
    return true
end
return M
