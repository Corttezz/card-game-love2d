local FloatingText = {}

local FontManager = require("src.ui.FontManager")

local active = {}

local KINDS = {
    damage = { color = {1, 0.4, 0.3, 1},   fontSize = 18, weight = "bold" },
    heal   = { color = {0.4, 0.95, 0.5, 1}, fontSize = 16 },
    armor  = { color = {0.55, 0.75, 1.0, 1}, fontSize = 16 },
    gold   = { color = {0.95, 0.85, 0.30, 1}, fontSize = 14 },
    info   = { color = {1, 1, 1, 1}, fontSize = 12 },
    buff   = { color = {0.85, 0.55, 1, 1}, fontSize = 14 },
    chips  = { color = {0.40, 0.75, 1.0, 1}, fontSize = 16 },
    mult   = { color = {1.0, 0.55, 0.20, 1}, fontSize = 16 },
    movename = { color = {0.95, 0.90, 0.78, 1}, fontSize = 15 },
}

function FloatingText.spawn(text, x, y, opts)
    opts = opts or {}
    local kindCfg = KINDS[opts.kind or ""] or {}
    local color = opts.color or kindCfg.color or {1, 1, 1, 1}
    local fontSize = opts.fontSize or kindCfg.fontSize or 14

    local entry = {
        text = tostring(text or ""),
        x = x or 0,
        y = y or 0,
        startY = y or 0,
        color = { color[1], color[2], color[3], color[4] or 1 },
        fontSize = fontSize,
        timer = 0,
        popIn = 0.15,
        hold = opts.hold or 0.35,
        fadeOut = 0.25,
        lift = opts.lift or 24,
        scale = 0,
    }
    table.insert(active, entry)
    return entry
end

function FloatingText.atCard(card, text, opts)
    if not card then return end
    local x = (card.x or 0) + (card.image and card.image:getWidth() or 0) * (card.currentScale or 1) * 0.5
    local y = (card.y or 0) - 8
    return FloatingText.spawn(text, x, y, opts)
end

function FloatingText.update(dt)
    for i = #active, 1, -1 do
        local e = active[i]
        e.timer = e.timer + dt
        local total = e.popIn + e.hold + e.fadeOut

        if e.timer >= total then
            table.remove(active, i)
        else
            local liftT = math.min(1, e.timer / total)
            e.y = e.startY - e.lift * liftT
        end
    end
end

function FloatingText.draw()
    if #active == 0 then return end

    local prevFont = love.graphics.getFont()
    local prevR, prevG, prevB, prevA = love.graphics.getColor()

    for _, e in ipairs(active) do
        local scale = 1
        local alpha = 1

        if e.timer < e.popIn then
            local t = e.timer / e.popIn
            local p = t - 1
            scale = 1 + 1.70158 * p * p * p + 2.70158 * p * p
        elseif e.timer < e.popIn + e.hold then
            scale = 1
        else
            local t = (e.timer - e.popIn - e.hold) / e.fadeOut
            scale = 1 - 0.15 * t
            alpha = 1 - t
        end

        e.scale = scale

        local font = FontManager.getFont(e.fontSize)
        love.graphics.setFont(font)

        local w = font:getWidth(e.text)
        local h = font:getHeight()

        love.graphics.setColor(0, 0, 0, 0.65 * alpha)
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.scale(scale, scale)
        love.graphics.print(e.text, -w * 0.5 + 1, -h * 0.5 + 1)
        love.graphics.pop()

        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.scale(scale, scale)
        love.graphics.print(e.text, -w * 0.5, -h * 0.5)
        love.graphics.pop()
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(prevR, prevG, prevB, prevA)
end

function FloatingText.clear()
    active = {}
end

function FloatingText.count()
    return #active
end

return FloatingText
