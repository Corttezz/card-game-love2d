local M = {}

local ELEMS = { "lightning", "ice", "fire", "dark", "holy" }
local BG = { 0.10, 0.08, 0.07, 1 }
local SIZE = 48

local function lumOf(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

function M.run(zoomArg)
    local OrbRow = require("src.ui.OrbRow")
    local FontManager = require("src.ui.FontManager")
    local ZOOM = tonumber(zoomArg) or 3

    local linhas = {}
    for _, el in ipairs(ELEMS) do
        local anim = OrbRow.animationFor(el)
        if not anim then
            print("[orb_anim_compare] sem frames pra '" .. el
                .. "' em " .. OrbRow.ANIM_ROOT .. " — nada a comparar")
            love.event.quit(1)
            return false
        end
        local estatico = love.image.newImageData("assets/sprites/orbs/" .. el .. ".png")
        local framesData = {}
        for i = 0, #anim.frames - 1 do
            framesData[i + 1] = love.image.newImageData(
                string.format("%s/%s/frame_%03d.png", OrbRow.ANIM_ROOT, el, i))
        end
        local pico, picoN = 1, -1
        local mapa = love.image.newImageData(SIZE, SIZE)
        for i, fd in ipairs(framesData) do
            local n = 0
            for y = 0, SIZE - 1 do
                for x = 0, SIZE - 1 do
                    local r, g, b, a = fd:getPixel(x, y)
                    local r0, g0, b0 = estatico:getPixel(x, y)
                    if a > 0.5 and (r ~= r0 or g ~= g0 or b ~= b0) then
                        n = n + 1
                        mapa:setPixel(x, y, 1, 1, 1, 1)
                    end
                end
            end
            if n > picoN then pico, picoN = i, n end
        end
        for y = 0, SIZE - 1 do
            for x = 0, SIZE - 1 do
                local _, _, _, ma = mapa:getPixel(x, y)
                if ma < 0.5 then
                    local r, g, b, a = estatico:getPixel(x, y)
                    if a > 0.5 then
                        local l = lumOf(r, g, b) * 0.35
                        mapa:setPixel(x, y, l, l, l, 1)
                    end
                end
            end
        end

        linhas[#linhas + 1] = {
            el = el,
            estatico = love.graphics.newImage(estatico),
            frames = anim.frames,
            pico = anim.frames[pico],
            picoIdx = pico - 1,
            picoN = picoN,
            mapa = love.graphics.newImage(mapa),
            fps = anim.fps,
        }
    end

    for _, L in ipairs(linhas) do
        L.estatico:setFilter("nearest", "nearest")
        L.mapa:setFilter("nearest", "nearest")
    end

    local PAD, GAPF = 10, 4
    local nF = #linhas[1].frames
    local colEstatico = SIZE
    local colTira = nF * SIZE + (nF - 1) * GAPF
    local colZoom = SIZE * ZOOM * 2 + 8
    local colMapa = SIZE * ZOOM
    local rowH = math.max(SIZE * ZOOM, 76) + 26
    local W = PAD + colEstatico + PAD * 3 + colTira + PAD + colZoom + PAD + colMapa + PAD
    local H = PAD + 30 + #linhas * rowH + PAD

    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(BG)
    love.graphics.setColor(1, 1, 1, 1)

    local fT = FontManager.getFont(13)
    local fL = FontManager.getFont(11)

    love.graphics.setFont(fT)
    love.graphics.setColor(0.86, 0.80, 0.66, 1)
    love.graphics.print("GEMAS DO MAGO — parado x vivo (1:1 = tamanho de uso)", PAD, PAD)

    local xEst = PAD
    local xTira = xEst + colEstatico + PAD * 3
    local xZoom = xTira + colTira + PAD
    local xMapa = xZoom + colZoom + PAD

    love.graphics.setFont(fL)
    love.graphics.setColor(0.60, 0.55, 0.45, 1)
    love.graphics.print("HOJE", xEst, PAD + 16)
    love.graphics.print("VIVO — o ciclo inteiro, 1:1", xTira, PAD + 16)
    love.graphics.print("ZOOM " .. ZOOM .. "x: parado | pico", xZoom, PAD + 16)
    love.graphics.print("ONDE muda", xMapa, PAD + 16)

    for i, L in ipairs(linhas) do
        local y = PAD + 30 + (i - 1) * rowH
        local yMid = y + math.floor((rowH - 26 - SIZE) / 2)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(L.estatico, xEst, yMid)

        for k, fr in ipairs(L.frames) do
            love.graphics.draw(fr, xTira + (k - 1) * (SIZE + GAPF), yMid)
        end

        love.graphics.draw(L.estatico, xZoom, y, 0, ZOOM, ZOOM)
        love.graphics.draw(L.pico, xZoom + SIZE * ZOOM + 8, y, 0, ZOOM, ZOOM)
        love.graphics.draw(L.mapa, xMapa, y, 0, ZOOM, ZOOM)

        love.graphics.setFont(fL)
        love.graphics.setColor(0.78, 0.72, 0.58, 1)
        love.graphics.print(string.format(
            "%s — %d frames @ %dfps (%.2fs) · pico: frame %d, %d px mudam",
            L.el, #L.frames, L.fps, #L.frames / L.fps, L.picoIdx, L.picoN),
            xEst, y + rowH - 24)
    end

    love.graphics.setCanvas()
    cv:newImageData():encode("png", "orbes_animacao.png")
    print("[orb_anim_compare] orbes_animacao.png (" .. W .. "x" .. H .. ")")
    love.event.quit(0)
    return true
end

return M
