local TK = require("tools.testkit")
local B = require("tools.bancada_sombras")

local M = {}

M.GAP_MAX = 1
M.COVER_MIN = 0.5
M.DEPTH_MIN = 3
M.FILL_MIN = 0.6
M.WIDE_DEPTH = 0.2

function M.rows(only)
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    local out = {}
    for _, bid in ipairs(B.BIOMES) do
        if not only or only == bid then
            for _, item in ipairs(B.items(bid)) do
                local shadowed = item.family ~= "clutter" or item.e.solid
                if shadowed then
                    for _, tod in ipairs(B.TODS) do
                        local r = B.measure(cv, bid, item, "near", tod)
                        r.bid, r.name, r.tod, r.family = bid, item.name, tod, item.family
                        out[#out + 1] = r
                    end
                end
            end
        end
    end
    cv:release()
    return out
end

function M.verdict(r)
    local gap = r.shadowTop and (r.shadowTop - r.artBottom) or nil
    local okGap = gap ~= nil and gap <= M.GAP_MAX
    local needCover = r.depthPx and r.depthPx >= M.DEPTH_MIN and r.area and r.area > 0
        and r.family ~= "tree" and not r.flat and (r.fill or 0) >= M.FILL_MIN
    local okCover = not needCover or (r.cover or 0) >= M.COVER_MIN
    local okDepth = not r.baseW or (r.depthPx or 0) >= M.WIDE_DEPTH * r.baseW
    return okGap, okCover, gap, needCover, okDepth
end

function M.run(only)
    require("src.ui.PixelCanvas").enableNearest()
    local t = TK.new("sombras dos itens: nasce na base e cobre a pegada (6 biomas)")
    local rows = M.rows(only)
    t:truthy("bancada mediu sprites (" .. #rows .. ")", #rows >= 40)
    for _, r in ipairs(rows) do
        local okGap, okCover, gap, needCover, okDepth = M.verdict(r)
        local tag = ("%s %s tod %.2f"):format(r.bid, r.name, r.tod)
        t:truthy(tag .. ": sombra colada na arte (vão " .. tostring(gap) .. " px, arte " .. r.artBottom .. ")", okGap)
        if r.baseW then
            t:truthy(("%s: base larga (%.0f px) com pegada de fundo (%.0f px)"):format(tag,
                r.baseW, r.depthPx or 0), okDepth)
        end
        if needCover then
            t:truthy(("%s: cobre a pegada (%.0f%% de %d px, fundo %.0f px)"):format(tag,
                100 * (r.cover or 0), r.area, r.depthPx), okCover)
        end
    end
    return t:done()
end

return M
