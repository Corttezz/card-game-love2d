local M = {}

local DIR = "assets/sprites/world/anim"

local function carregar(pasta)
    local frames = {}
    for i = 0, 63 do
        local p = DIR .. "/" .. pasta .. "/" .. i .. ".png"
        if not love.filesystem.getInfo(p) then break end
        frames[#frames + 1] = love.image.newImageData(p)
    end
    return frames
end

local function centroide(img)
    local w, h = img:getWidth(), img:getHeight()
    local sx, sy, n = 0, 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = img:getPixel(x, y)
            if a > 0.5 then sx, sy, n = sx + x, sy + y, n + 1 end
        end
    end
    if n == 0 then return 0, 0, 0 end
    return sx / n, sy / n, n
end

local function mudancas(a, b)
    local w, h = a:getWidth(), a:getHeight()
    local mask, total, rodape, rodapeTot = {}, 0, 0, 0
    local corte = math.floor(h * 2 / 3)
    for y = 0, h - 1 do
        mask[y] = {}
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2),
                               math.abs(b1 - b2), math.abs(a1 - a2))
            local mudou = d > 0.08
            mask[y][x] = mudou
            if mudou then total = total + 1 end
            if y >= corte then
                rodapeTot = rodapeTot + 1
                if mudou then rodape = rodape + 1 end
            end
        end
    end
    return mask, total, (rodapeTot > 0 and rodape / rodapeTot or 0)
end

local function ilhas(mask, w, h)
    local visto, n = {}, 0
    for y = 0, h - 1 do visto[y] = {} end
    local fila = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if mask[y][x] and not visto[y][x] then
                local tam = 0
                fila[1] = { x, y }; visto[y][x] = true
                local i = 1
                while i <= #fila do
                    local px, py = fila[i][1], fila[i][2]
                    i = i + 1; tam = tam + 1
                    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local nx, ny = px + d[1], py + d[2]
                        if nx >= 0 and nx < w and ny >= 0 and ny < h
                            and mask[ny][nx] and not visto[ny][nx] then
                            visto[ny][nx] = true
                            fila[#fila + 1] = { nx, ny }
                        end
                    end
                end
                for k = #fila, 1, -1 do fila[k] = nil end
                if tam > 2 then n = n + 1 end
            end
        end
    end
    return n
end

function M.run(filtro)
    local pastas = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if item:find("landmark") and ((not filtro) or item:find(filtro, 1, true)) then
            pastas[#pastas + 1] = item
        end
    end
    table.sort(pastas)

    print("")
    print("=== DERIVA E TREMOR DAS ANIMACOES ===")
    print(string.format("%-34s %7s %8s %9s %s",
        "animacao", "desloca", "rodape", "ilhas", "vs ato1"))

    local avisos = 0
    local medido = {}
    for _, pasta in ipairs(pastas) do
        local frames = carregar(pasta)
        if #frames >= 2 then
            local w, h = frames[1]:getWidth(), frames[1]:getHeight()
            local maxDesloc, maxRodape, maxIlhas = 0, 0, 0
            local cxPrev, cyPrev = centroide(frames[1])
            for i = 2, #frames do
                local cx, cy = centroide(frames[i])
                local d = math.sqrt((cx - cxPrev) ^ 2 + (cy - cyPrev) ^ 2)
                if d > maxDesloc then maxDesloc = d end
                cxPrev, cyPrev = cx, cy
                local mask, _, rod = mudancas(frames[i - 1], frames[i])
                if rod > maxRodape then maxRodape = rod end
                local il = ilhas(mask, w, h)
                if il > maxIlhas then maxIlhas = il end
            end
            medido[pasta] = { desloc = maxDesloc, rodape = maxRodape,
                              ilhas = maxIlhas }
        end
    end

    local tipos = { "battle", "elite", "event", "rest", "shop", "shop_hover" }
    for _, tipo in ipairs(tipos) do
        local base = medido["landmark_" .. tipo]
        if base then
            for pasta, m in pairs(medido) do
                local suf = pasta:match("^%a+_landmark_(.+)$")
                if suf == tipo then
                    local razao = (base.rodape > 0.001)
                        and (m.rodape / base.rodape) or 0
                    local flag = ""
                    if razao >= 3.0 then
                        flag = string.format(" TREME %.1fx MAIS QUE O ATO 1!", razao)
                        avisos = avisos + 1
                    end
                    print(string.format("%-34s %6.2fpx %7.1f%% %8d  %4.1fx%s",
                        pasta, m.desloc, m.rodape * 100, m.ilhas, razao, flag))
                end
            end
            print(string.format("%-34s %6.2fpx %7.1f%% %8d  %4s   (referencia)",
                "landmark_" .. tipo, base.desloc, base.rodape * 100,
                base.ilhas, "-"))
        end
    end

    print("")
    print(string.format("%d animacao(oes), %d com aviso.", #pastas, avisos))
    love.event.quit()
    return avisos == 0
end

return M
