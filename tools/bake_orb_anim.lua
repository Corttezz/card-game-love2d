local M = {}

local ELEMS = { "lightning", "ice", "fire", "dark", "holy" }
local SRC   = "assets/sprites/orbs/%s.png"
local OUT   = "bake/orbs_anim/%s"

local MIN_LUM = 0.30
local MAX_STEP = 0.16

local function lumOf(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function toHsv(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, (mx > 0 and d / mx or 0), mx
end

local function hueDist(a, b)
    local d = math.abs(a - b) % 1
    return math.min(d, 1 - d)
end

local function buildRamp(data)
    local w, h = data:getWidth(), data:getHeight()
    local seen, list = {}, {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0.5 then
                local key = string.format("%d,%d,%d",
                    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                    math.floor(b * 255 + 0.5))
                if not seen[key] then
                    local hh, ss, _ = toHsv(r, g, b)
                    local c = { r = r, g = g, b = b, l = lumOf(r, g, b), h = hh, s = ss }
                    seen[key] = c
                    list[#list + 1] = c
                end
            end
        end
    end

    for _, c in ipairs(list) do
        local best, bestScore = nil, math.huge
        for _, d in ipairs(list) do
            local dl = d.l - c.l
            if dl > 0.02 and dl <= MAX_STEP then
                local score = hueDist(c.h, d.h) * 4.0
                    + math.abs(c.s - d.s) * 1.5
                    + dl
                if score < bestScore then best, bestScore = d, score end
            end
        end
        c.twin = (best and hueDist(c.h, best.h) < 0.09) and best or c
    end
    return seen
end

local function bandHit(x, y, center, halfW)
    local p = (x - y) * 0.70710678
    return math.abs(p - center) <= halfW
end

function M.run(halfWArg, framesArg, fpsArg)
    local halfW = tonumber(halfWArg) or 5
    local frames = tonumber(framesArg) or 24
    local fps = tonumber(fpsArg) or 12

    love.filesystem.createDirectory("bake/orbs_anim")
    local relatorio = {}

    for _, el in ipairs(ELEMS) do
        local path = string.format(SRC, el)
        local ok, data = pcall(love.image.newImageData, path)
        if not ok or not data then
            print("[bake_orb_anim] nao abriu " .. path)
            love.event.quit(1)
            return false
        end
        local w, h = data:getWidth(), data:getHeight()
        local ramp = buildRamp(data)
        local dir = string.format(OUT, el)
        love.filesystem.createDirectory(dir)

        local span = (w - 1) * 0.70710678
        local from, to = -span - halfW - 1, span + halfW + 1

        local totalOpacos, somaMudados, maxMudados = 0, 0, 0
        for f = 0, frames - 1 do
            local center = from + (to - from) * (f / (frames - 1))
            local out = love.image.newImageData(w, h)
            local mudados = 0
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local r, g, b, a = data:getPixel(x, y)
                    if a > 0.5 then
                        if f == 0 then totalOpacos = totalOpacos + 1 end
                        local l = lumOf(r, g, b)
                        if l >= MIN_LUM and bandHit(x, y, center, halfW) then
                            local key = string.format("%d,%d,%d",
                                math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                                math.floor(b * 255 + 0.5))
                            local c = ramp[key]
                            if c and c.twin ~= c then
                                r, g, b = c.twin.r, c.twin.g, c.twin.b
                                mudados = mudados + 1
                            end
                        end
                    end
                    out:setPixel(x, y, r, g, b, a)
                end
            end
            somaMudados = somaMudados + mudados
            maxMudados = math.max(maxMudados, mudados)
            out:encode("png", string.format("%s/frame_%03d.png", dir, f))
        end

        love.filesystem.write(dir .. "/meta.lua",
            string.format("return { fps = %d }\n", fps))
        relatorio[#relatorio + 1] = string.format(
            "%-9s %d frames | %d px opacos | pico %d px (%.1f%%) | media %.1f px",
            el, frames, totalOpacos, maxMudados,
            100 * maxMudados / math.max(1, totalOpacos), somaMudados / frames)
    end

    print(string.format("[bake_orb_anim] halfW=%d frames=%d fps=%d (%.2fs)", halfW, frames, fps, frames / fps))
    for _, l in ipairs(relatorio) do print("  " .. l) end
    print("[bake_orb_anim] saida: <save>/bake/orbs_anim/<tipo>/")
    love.event.quit(0)
    return true
end

return M
