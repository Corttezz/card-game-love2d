local CastleFoot = {}

CastleFoot.FEET = require("src.data.castle_feet")
CastleFoot.MARGIN = 2
CastleFoot.MARGIN_K = 0.003

function CastleFoot.margin(h)
    return math.max(CastleFoot.MARGIN, math.floor((h or 0) * CastleFoot.MARGIN_K))
end

function CastleFoot.limit(g, bid, cx, s, iw, ih)
    local f = CastleFoot.FEET[bid]
    if not f or f.iw ~= iw or f.ih ~= ih then return nil end
    local gap = f.gap
    local left = cx - iw * s / 2
    local need = -math.huge
    for c = 1, iw do
        local gc = gap[c]
        if gc >= 0 then
            local xa = left + (c - 1) * s - 1
            local xb = left + c * s + 1
            local cy = math.max(g.crestYAt(xa), g.crestYAt(xb))
            local y = cy + gc * s
            if y > need then need = y end
        end
    end
    if need == -math.huge then return nil end
    return need + CastleFoot.margin(g.h) + 1
end

return CastleFoot
