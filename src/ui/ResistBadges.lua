local Palette = require("src.ui.Palette")
local IconLoader = require("src.ui.IconLoader")
local Resistances = require("src.systems.Resistances")
require("src.ui.ResistFx")

local ResistBadges = {}

ResistBadges.SIZE = 24
ResistBadges.GAP = 4

ResistBadges.BORDER = {
    immune = Palette.BLOOD,
    resist = Palette.STEEL_LIGHT,
    weak = Palette.ORANGE,
}

ResistBadges.lastRects = {}

local SLASH = { math.min(1, Palette.BLOOD[1] * 1.6), Palette.BLOOD[2] * 1.3, Palette.BLOOD[3] * 1.3, 1 }

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

function ResistBadges.width(enemy, size)
    local n = #Resistances.entries(enemy)
    if n == 0 then return 0 end
    size = size or ResistBadges.SIZE
    return n * size + (n - 1) * ResistBadges.GAP
end

function ResistBadges.tooltip(entry)
    local I18n = require("src.i18n.I18n")
    local tname = I18n.t("resist.type." .. entry.type, nil, entry.type)
    local title = I18n.t("resist.title." .. entry.level, { type = tname }, tname)
    local body = I18n.t("resist.desc." .. entry.level, { type = tname }, "")
    if entry.type == "poison" or entry.type == "fire" then
        local extra = I18n.t("resist.status_note." .. entry.type .. "_" .. entry.level, nil, "")
        if extra ~= "" then body = body .. " " .. extra end
    end
    return title, body
end

local function px(x, y, w, h)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), w, h)
end

local function drawMark(level, x, y, s)
    local u = math.max(1, math.floor(s / 12))
    if level == "immune" then
        local n = math.floor(s / u) - 2
        setColor(Palette.INK, 1)
        for i = 0, n - 1 do
            px(x + s - u * 3 - i * u, y + u + i * u, u * 4, u * 2)
        end
        setColor(SLASH, 1)
        for i = 0, n - 1 do
            px(x + s - u * 2 - i * u, y + u + i * u, u * 2, u)
        end
    else
        local col = level == "weak" and Palette.ORANGE or Palette.STEEL_LIGHT
        local bx, by = x + s - u * 6, y + s - u * 5
        setColor(Palette.INK, 1)
        px(bx - u, by - u, u * 7, u * 5)
        setColor(col, 1)
        if level == "weak" then
            px(bx + u * 2, by, u, u)
            px(bx + u, by + u, u * 3, u)
            px(bx, by + u * 2, u * 5, u)
        else
            px(bx, by, u * 5, u)
            px(bx + u, by + u, u * 3, u)
            px(bx + u * 2, by + u * 2, u, u)
        end
    end
end

function ResistBadges.drawChip(entry, x, y, s)
    local border = ResistBadges.BORDER[entry.level] or Palette.STEEL_LIGHT
    setColor(Palette.INK, 0.9)
    love.graphics.rectangle("fill", x - 1, y - 1, s + 2, s + 2, 3, 3)
    setColor(Palette.PARCHMENT_DARK, 0.95)
    love.graphics.rectangle("fill", x + 1, y + 1, s - 2, s - 2, 2, 2)
    setColor(border, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, s - 1, s - 1, 2, 2)
    local icon = Resistances.ICON[entry.type]
    if icon then
        love.graphics.setColor(1, 1, 1, entry.level == "immune" and 0.8 or 1)
        IconLoader.drawFit(icon, x + s / 2, y + s / 2, s - 6)
    end
    drawMark(entry.level, x, y, s)
    love.graphics.setColor(1, 1, 1, 1)
end

function ResistBadges.draw(enemy, rightX, centerY, size)
    local list = Resistances.entries(enemy)
    ResistBadges.lastRects = {}
    if #list == 0 then return 0 end
    size = size or ResistBadges.SIZE
    local total = ResistBadges.width(enemy, size)
    local x0 = math.floor(rightX - total)
    local y = math.floor(centerY - size / 2)
    local mx, my = love.mouse.getPosition()
    local NavCursor = require("src.ui.NavCursor")
    for i, e in ipairs(list) do
        local x = x0 + (i - 1) * (size + ResistBadges.GAP)
        ResistBadges.drawChip(e, x, y, size)
        ResistBadges.lastRects[i] = { x = x, y = y, w = size, h = size, entry = e }
        NavCursor.target("resist:" .. e.type, x, y, size, size)
        if mx >= x and mx <= x + size and my >= y and my <= y + size then
            local title, body = ResistBadges.tooltip(e)
            require("src.ui.StatusTooltip").show("resist_" .. e.type, mx, my,
                { title = title, body = body })
        end
    end
    return total
end

return ResistBadges
