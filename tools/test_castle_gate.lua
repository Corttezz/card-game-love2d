local TK = require("tools.testkit")

local M = {}

local DIR_ANIM = "assets/sprites/world/anim/"
local DIR_ART  = "assets/sprites/world/"

local VAO      = { x0 = 0.43, x1 = 0.57, y0 = 0.76, y1 = 0.99 }
local PAREDE_E = { x0 = 0.28, x1 = 0.40, y0 = 0.76, y1 = 0.99 }
local PAREDE_D = { x0 = 0.60, x1 = 0.72, y0 = 0.76, y1 = 0.99 }

local function corMedia(imgData, reg)
    local w, h = imgData:getWidth(), imgData:getHeight()
    local x0 = math.max(0, math.floor(reg.x0 * w))
    local x1 = math.min(w - 1, math.floor(reg.x1 * w))
    local y0 = math.max(0, math.floor(reg.y0 * h))
    local y1 = math.min(h - 1, math.floor(reg.y1 * h))
    local sr, sg, sb, n = 0, 0, 0, 0
    for y = y0, y1 do
        for x = x0, x1 do
            local r, g, b, a = imgData:getPixel(x, y)
            if a > 0.5 then
                sr, sg, sb, n = sr + r, sg + g, sb + b, n + 1
            end
        end
    end
    if n == 0 then return 0, 0, 0 end
    return sr / n, sg / n, sb / n
end

local function distanciaDoMuro(imgData)
    local vr, vg, vb = corMedia(imgData, VAO)
    local er, eg, eb = corMedia(imgData, PAREDE_E)
    local dr, dg, db = corMedia(imgData, PAREDE_D)
    local pr, pg, pb = (er + dr) / 2, (eg + dg) / 2, (eb + db) / 2
    return math.sqrt((vr - pr) ^ 2 + (vg - pg) ^ 2 + (vb - pb) ^ 2)
end

local function fracaoDiferente(a, b)
    local w, h = a:getWidth(), a:getHeight()
    local dif, n = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2),
                               math.abs(b1 - b2), math.abs(a1 - a2))
            if d > 0.12 then dif = dif + 1 end
            n = n + 1
        end
    end
    return dif / math.max(1, n)
end

local function framesDe(dir)
    if not love.filesystem.getInfo(dir) then return nil end
    local frames = {}
    for i = 0, 63 do
        local p = dir .. "/" .. i .. ".png"
        if not love.filesystem.getInfo(p) then break end
        frames[#frames + 1] = p
    end
    return frames
end

function M.run()
    local t = TK.new("test_castle_gate")

    local Biomes = require("src.data.biomes")
    local lista = Biomes.LIST or Biomes.BIOMES or Biomes
    local ids = {}
    for _, b in ipairs(lista) do
        if type(b) == "table" and b.id then ids[#ids + 1] = b.id end
    end
    t:truthy("achei os biomas pra varrer (" .. #ids .. ")", #ids >= 3)

    local conferidos = 0

    for _, bid in ipairs(ids) do
        local base = DIR_ART .. bid .. "_castle.png"
        local frames = framesDe(DIR_ANIM .. bid .. "_castle_door")

        if love.filesystem.getInfo(base) and frames then
            conferidos = conferidos + 1
            local nome = bid .. "_castle_door"

            t:truthy(nome .. ": tem frames suficientes pra animar (" ..
                #frames .. ")", #frames >= 4)

            local arte = love.image.newImageData(base)
            local aw, ah = arte:getWidth(), arte:getHeight()

            local tamanhoOk = true
            for _, p in ipairs(frames) do
                local f = love.image.newImageData(p)
                if f:getWidth() ~= aw or f:getHeight() ~= ah then
                    tamanhoOk = false
                end
            end
            t:truthy(nome .. ": todo frame tem o tamanho da arte base (" ..
                aw .. "x" .. ah .. ")", tamanhoOk)

            if tamanhoOk then
                local f0 = love.image.newImageData(frames[1])
                local dif = fracaoDiferente(arte, f0)
                t:truthy(string.format(
                    "%s: o frame 0 casa com o castelo (difere em %.1f%% dos " ..
                    "pixels; acima de 8%% o jogador ve um PULO quando a " ..
                    "cerimonia comeca)", nome, dif * 100), dif < 0.08)

                local inicio = distanciaDoMuro(f0)
                local fim    = distanciaDoMuro(
                    love.image.newImageData(frames[#frames]))
                t:truthy(string.format(
                    "%s: no fim o vao ainda e um BURACO, nao alvenaria " ..
                    "(distancia ao muro %.3f -> %.3f; despencar significa " ..
                    "que uma porta de pedra desceu no lugar de abrir)",
                    nome, inicio, fim), fim >= inicio * 0.6)
            end
        end
    end

    t:truthy("conferi pelo menos um castelo (" .. conferidos .. ")",
        conferidos >= 1)

    return t:done()
end

return M
