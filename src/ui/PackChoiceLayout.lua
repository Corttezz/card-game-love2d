local PackChoiceLayout = {}

PackChoiceLayout.HEADER_H = 60
PackChoiceLayout.TAG_H    = 24
PackChoiceLayout.DETAIL_H = 116
PackChoiceLayout.ACTION_H = 52
PackChoiceLayout.MARGIN   = 14
PackChoiceLayout.GAP_MIN  = 10
PackChoiceLayout.GAP_MAX  = 34
PackChoiceLayout.LIFT_RESERVE = 30

PackChoiceLayout.CARD_SCALE_BASE = 1.90
PackChoiceLayout.CARD_SCALE_CAP  = 2.80
PackChoiceLayout.CARD_SCALE_MIN = 0.80
PackChoiceLayout.CARD_SPACING   = 0.34

local function fixedHeight()
    local L = PackChoiceLayout
    return L.HEADER_H + L.LIFT_RESERVE + L.TAG_H + L.DETAIL_H + L.ACTION_H
end

function PackChoiceLayout.cardScale(n, imgW, imgH, sw, sh)
    local L = PackChoiceLayout
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()

    local fitW = (sw * 0.88) / (imgW * (n + (n - 1) * L.CARD_SPACING))
    local budget = sh - 2 * L.MARGIN - fixedHeight() - 4 * L.GAP_MIN
    local fitH = budget / imgH
    local ceiling = math.min(L.CARD_SCALE_CAP, L.CARD_SCALE_BASE * math.max(1, sh / 768))

    return math.max(L.CARD_SCALE_MIN, math.min(ceiling, fitW, fitH))
end

function PackChoiceLayout.compute(n, imgW, imgH, sw, sh, topInset)
    local L = PackChoiceLayout
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()
    topInset = math.max(0, math.floor(topInset or 0))
    sh = sh - topInset

    local scale = L.cardScale(n, imgW, imgH, sw, sh)
    local cardW, cardH = imgW * scale, imgH * scale

    local leftover = sh - 2 * L.MARGIN - fixedHeight() - cardH
    local gap = math.max(L.GAP_MIN, math.min(L.GAP_MAX, leftover / 4))
    local topPad = L.MARGIN + math.max(0, (leftover - 4 * gap) * 0.5)

    local bandW = math.min(900, sw * 0.86)
    local bandX = math.floor((sw - bandW) * 0.5)

    local gapI  = math.floor(gap)
    local cardHi = math.ceil(cardH)
    local y = math.floor(topPad) + topInset

    local header = { x = bandX, y = y, w = bandW, h = L.HEADER_H }
    y = y + L.HEADER_H + gapI + L.LIFT_RESERVE

    local cards = { x = 0, y = y, w = sw, h = cardHi }
    y = y + cardHi

    local tags = { x = 0, y = y, w = sw, h = L.TAG_H }
    y = y + L.TAG_H + gapI

    local detail = { x = bandX, y = y, w = bandW, h = L.DETAIL_H }
    y = y + L.DETAIL_H + gapI

    local action = { x = bandX, y = y, w = bandW, h = L.ACTION_H }

    local spacing = cardW * L.CARD_SPACING
    local totalW = cardW * n + spacing * math.max(0, n - 1)

    return {
        header = header, cards = cards, tags = tags,
        detail = detail, action = action,
        cardScale = scale, cardW = cardW, cardH = cardH,
        spacing = spacing,
        liftRoom = gapI + L.LIFT_RESERVE,
        rowStartX = (sw - totalW) * 0.5,
    }
end

function PackChoiceLayout.cardPos(zones, i)
    return zones.rowStartX + (i - 1) * (zones.cardW + zones.spacing), zones.cards.y
end

function PackChoiceLayout.validate(zones, sw, sh)
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()
    local problems = {}
    local order = {
        { "header", zones.header }, { "cards", zones.cards },
        { "tags", zones.tags }, { "detail", zones.detail }, { "action", zones.action },
    }
    for i = 1, #order do
        local name, r = order[i][1], order[i][2]
        if r.y < 0 then
            problems[#problems + 1] = name .. " sai pelo topo (y=" .. math.floor(r.y) .. ")"
        end
        if r.y + r.h > sh then
            problems[#problems + 1] = name .. " sai por baixo (fim="
                .. math.floor(r.y + r.h) .. " > " .. sh .. ")"
        end
        if r.x < 0 or r.x + r.w > sw then
            problems[#problems + 1] = name .. " sai pelos lados"
        end
        if i < #order then
            local nxt = order[i + 1]
            if r.y + r.h > nxt[2].y + 0.5 then
                problems[#problems + 1] = string.format("%s invade %s em %.0fpx",
                    name, nxt[1], (r.y + r.h) - nxt[2].y)
            end
        end
    end
    if zones.rowStartX < 0 then
        problems[#problems + 1] = "fileira de cartas sangra pelos lados"
    end
    return #problems == 0, problems
end

return PackChoiceLayout
