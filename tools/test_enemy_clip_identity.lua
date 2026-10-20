local TK = require("tools.testkit")
local M = {}

local ROOT = "assets/sprites/characters/enemies/"
local CLIPS = { "attack", "attack_strong", "hurt", "death" }
M.MAX_DIFF = 20
M.MAX_SIZE = 3

local function bbox(d)
    local w, h = d:getWidth(), d:getHeight()
    local x0, y0, x1, y1 = w, h, -1, -1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.1 then
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y < y0 then y0 = y end
                if y > y1 then y1 = y end
            end
        end
    end
    if x1 < 0 then return nil end
    return x0, y0, x1 - x0 + 1, y1 - y0 + 1
end

function M.compare(a, b)
    local ax, ay, aw, ah = bbox(a)
    local bx, by, bw, bh = bbox(b)
    if not ax or not bx then return math.huge, math.huge end
    local w, h = math.min(aw, bw), math.min(ah, bh)
    local sum = 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = a:getPixel(ax + x, ay + (ah - h) + y)
            local r2, g2, b2, a2 = b:getPixel(bx + x, by + (bh - h) + y)
            local l1 = (0.3 * r1 + 0.59 * g1 + 0.11 * b1) * a1
            local l2 = (0.3 * r2 + 0.59 * g2 + 0.11 * b2) * a2
            sum = sum + math.abs(l1 - l2)
        end
    end
    return sum / (w * h) * 255, math.max(math.abs(aw - bw), math.abs(ah - bh))
end

function M.run()
    local t = TK.new("todo clip do inimigo comeca no desenho do idle (mesma geracao de arte)")
    local R = require("src.data.enemies").ROSTER
    local fails, n = {}, 0
    for act = 1, 6 do
        for _, kind in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
            for _, id in ipairs(R[act][kind] or {}) do
                local idle = love.image.newImageData(ROOT .. id .. "/animations/idle/south/0.png")
                for _, clip in ipairs(CLIPS) do
                    local p = ROOT .. id .. "/animations/" .. clip .. "/south/0.png"
                    if love.filesystem.getInfo(p) then
                        n = n + 1
                        local d, ds = M.compare(idle, love.image.newImageData(p))
                        if d > M.MAX_DIFF or ds > M.MAX_SIZE then
                            fails[#fails + 1] = string.format("%s/%s(dif %.1f, tam %d)", id, clip, d, ds)
                        end
                    end
                end
            end
        end
    end
    t:truthy("clips comparados (" .. n .. ")", n >= 150)
    t:eq("quadro 0 de ataque/forte/golpe/morte igual ao idle 0: " .. table.concat(fails, " "), #fails, 0)
    return t:done()
end

return M
