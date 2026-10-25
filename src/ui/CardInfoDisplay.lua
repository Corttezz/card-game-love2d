local Debug = require("src.core.Debug")

local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")
local Palette = require("src.ui.Palette")

local CardInfoDisplay = {}
CardInfoDisplay.__index = CardInfoDisplay

local PAD = 12
local MAX_INNER = 280
local MIN_INNER = 170
local LINE_K = 1.35

function CardInfoDisplay:new()
    local instance = setmetatable({}, CardInfoDisplay)

    instance.showRarity = true
    instance.showStats = true
    instance.showDescription = false
    instance.textColor = { 1, 1, 1, 1 }

    instance.rarityColors = {
        common = { 0.7, 0.7, 0.7 },
        uncommon = { 0.2, 0.8, 0.2 },
        rare = { 0.8, 0.2, 0.8 },
        legendary = { 0.8, 0.6, 0.2 },
        basic = { 0.5, 0.5, 0.5 },
    }

    return instance
end

function CardInfoDisplay:configure(options)
    if options.showRarity ~= nil then self.showRarity = options.showRarity end
    if options.showStats ~= nil then self.showStats = options.showStats end
    if options.showDescription ~= nil then self.showDescription = options.showDescription end
    if options.textColor then self.textColor = options.textColor end
    if options.rarityColors then self.rarityColors = options.rarityColors end
end

local function buildForgeLine(inst)
    if (inst.upgrades or 0) <= 0 then return nil end
    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(inst)
    local lvl = inst.upgrades
    local parts = {}
    if gains.atk then table.insert(parts, "+" .. (gains.atk * lvl) .. " " .. I18n.t("card_info.atk_short")) end
    if gains.def then table.insert(parts, "+" .. (gains.def * lvl) .. " " .. I18n.t("card_info.def_short")) end
    if gains.effect then table.insert(parts, "+" .. (gains.effect * lvl)) end
    local line = I18n.t("card_info.forged", { n = lvl }, "Forjada +" .. lvl)
    if #parts > 0 then
        line = line .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return line
end

local TextCase = require("src.i18n.TextCase")

local function buildElementLine(inst)
    local Resistances = require("src.systems.Resistances")
    local ty, dmg = Resistances.elementOfCard(inst)
    if not ty then return nil end
    local typeName = I18n.t("resist.type." .. ty, nil, ty)
    local key = dmg and "card_info.damage_type" or "card_info.element"
    local Badge = require("src.ui.card.components.CardElementBadge")
    local col = Badge.colors(ty)
    return { text = I18n.t(key, { type = typeName }, typeName), type = ty,
             badge = Badge.has(ty), color = col and col.glyph or Palette.PARCHMENT_LIGHT }
end

CardInfoDisplay.buildElementLine = buildElementLine

local function hasWord(lower, word)
    local from = 1
    while true do
        local i = lower:find(word, from, true)
        if not i then return false end
        if i == 1 or not lower:sub(i - 1, i - 1):match("%a") then return true end
        from = i + 1
    end
end

local function anyWord(lower, byLocale, loc)
    local words = byLocale and (byLocale[loc] or byLocale.en)
    if not words then return false end
    for _, w in ipairs(words) do
        if hasWord(lower, w) then return true end
    end
    return false
end

function CardInfoDisplay.collectKeywords(desc)
    if not desc or desc == "" then return {} end
    local hits = {}
    local lower = TextCase.lower(desc)
    local ok, Keywords = pcall(require, "src.data.keywords")
    if not ok then
        if not CardInfoDisplay._warnedKeywords then
            CardInfoDisplay._warnedKeywords = true
            Debug.warn("[CardInfoDisplay] AVISO: glossario nao carregou: " .. tostring(Keywords))
        end
        return hits
    end
    local loc = I18n.getLocale()
    local groupHit = {}
    for _, kw in ipairs(Keywords) do
        if not (kw.group and groupHit[kw.group]) then
            local ctxOk = (kw.requires == nil) or anyWord(lower, kw.requires, loc)
            if ctxOk and anyWord(lower, kw.match, loc) then
                table.insert(hits, {
                    id   = kw.id,
                    name = I18n.t("keyword." .. kw.id .. ".name", nil, kw.id),
                    text = I18n.t("keyword." .. kw.id .. ".text", nil, ""),
                })
                if kw.group then groupHit[kw.group] = true end
            end
        end
        if #hits >= 3 then break end
    end
    return hits
end
local collectKeywords = CardInfoDisplay.collectKeywords

function CardInfoDisplay:draw(cardInstance, x, y, options)
    if not cardInstance then return end

    local localOptions = options or {}
    local showRarity = localOptions.showRarity ~= nil and localOptions.showRarity or self.showRarity
    local showStats = localOptions.showStats ~= nil and localOptions.showStats or self.showStats
    local showDescription = localOptions.showDescription ~= nil and localOptions.showDescription or self.showDescription

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local nameFont = FontManager.getFont(13)
    local forgeFont = FontManager.getFont(9)
    local bodyFont = FontManager.getFont(10)
    local kwFont = FontManager.getFont(9)
    local statFont = FontManager.getFont(11)

    local nameLH = math.floor(nameFont:getHeight() * 1.2)
    local bodyLH = math.floor(bodyFont:getHeight() * LINE_K)
    local kwLH = math.floor(kwFont:getHeight() * LINE_K)

    local name = I18n.cardName(cardInstance)
    local desc = showDescription and I18n.cardDesc(cardInstance) or nil
    if desc == "" then desc = nil end
    local forgeLine = buildForgeLine(cardInstance)
    local elemLine = buildElementLine(cardInstance)
    local Badge = require("src.ui.card.components.CardElementBadge")
    local elemLH = math.max(kwLH, Badge.SIZE + 1)
    local elemIndent = Badge.SIZE + 5
    local kwHits = desc and collectKeywords(desc) or {}

    local rarityText = nil
    if showRarity and cardInstance.rarity then
        rarityText = require("src.i18n.TextCase").upper(I18n.t("rarity." .. cardInstance.rarity, nil, cardInstance.rarity))
    end

    local _, nameLines = nameFont:getWrap(name or "", MAX_INNER)
    local descLines = {}
    if desc then _, descLines = bodyFont:getWrap(desc, MAX_INNER) end
    local kwBlocks = {}
    local kwSep = I18n.t("keyword.sep", nil, ": ")
    for _, kw in ipairs(kwHits) do
        local full = kw.name .. kwSep .. kw.text
        local _, lines = kwFont:getWrap(full, MAX_INNER)
        table.insert(kwBlocks, lines)
    end

    local innerW = MIN_INNER
    for _, l in ipairs(nameLines) do innerW = math.max(innerW, nameFont:getWidth(l)) end
    for _, l in ipairs(descLines) do innerW = math.max(innerW, bodyFont:getWidth(l)) end
    for _, block in ipairs(kwBlocks) do
        for _, l in ipairs(block) do innerW = math.max(innerW, kwFont:getWidth(l)) end
    end
    if forgeLine then
        innerW = math.max(innerW, math.min(MAX_INNER, forgeFont:getWidth(forgeLine)))
    end
    if elemLine then
        innerW = math.max(innerW, math.min(MAX_INNER, kwFont:getWidth(elemLine.text) + elemIndent))
    end
    innerW = math.min(innerW, MAX_INNER)

    local panelH = PAD
    panelH = panelH + #nameLines * nameLH
    if forgeLine then panelH = panelH + kwLH + 2 end
    if elemLine then panelH = panelH + elemLH + 2 end
    if #descLines > 0 then
        panelH = panelH + 7 + #descLines * bodyLH
    end
    for _, block in ipairs(kwBlocks) do
        panelH = panelH + 4 + #block * kwLH
    end
    if rarityText then panelH = panelH + 8 + 18 end
    if showStats then panelH = panelH + 8 + 16 end
    panelH = panelH + PAD

    local panelW = innerW + PAD * 2

    local GAP = 6
    local topMin = localOptions.minY or 8
    local panelX = math.floor(x - panelW / 2 + 70)
    local panelY
    if localOptions.below then
        panelY = math.floor(y + GAP)
        if panelY + panelH > sh - 8 then panelY = sh - 8 - panelH end
    else
        panelY = math.floor(y - panelH - GAP)
        if panelY < topMin then panelY = topMin end
    end
    if localOptions.side and localOptions.cardW then
        local cx0 = localOptions.cardX or x
        local cw = localOptions.cardW
        local right = cx0 + cw + GAP
        local left = cx0 - GAP - panelW
        panelX = (left >= 10) and left or right
        panelY = math.floor(y)
        if panelY + panelH > sh - 8 then panelY = sh - 8 - panelH end
        if panelY < topMin then panelY = topMin end
        panelX = math.floor(panelX)
    end
    if panelX < 10 then panelX = 10 end
    if panelX + panelW > sw - 10 then panelX = sw - panelW - 10 end
    self.lastRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 3, panelY + 4, panelW, panelH, 6, 6)
    love.graphics.setColor(Palette.PANEL_FILL and Palette.PANEL_FILL[1] or 0.10,
        Palette.PANEL_FILL and Palette.PANEL_FILL[2] or 0.06,
        Palette.PANEL_FILL and Palette.PANEL_FILL[3] or 0.03, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6, 6)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 6, 6)
    Palette.set(Palette.AGED_GOLD_DARK, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 3, panelY + 3, panelW - 6, panelH - 6, 4, 4)

    local tx = panelX + PAD
    local cy = panelY + PAD

    love.graphics.setFont(nameFont)
    for _, line in ipairs(nameLines) do
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.print(line, tx + 1, cy + 1)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(line, tx, cy)
        cy = cy + nameLH
    end

    if forgeLine then
        love.graphics.setColor(0.55, 0.85, 0.45, 1)
        require("src.ui.TextFit").print(forgeLine, tx, cy + 2,
            { size = 9, maxW = innerW })
        cy = cy + kwLH + 2
    end

    if elemLine then
        local lx = tx
        if elemLine.badge then
            Badge.drawAt(tx, cy + 1, elemLine.type)
            lx = tx + elemIndent
        end
        love.graphics.setColor(elemLine.color[1], elemLine.color[2], elemLine.color[3], 1)
        require("src.ui.TextFit").print(elemLine.text, lx,
            cy + 1 + math.floor((elemLH - kwFont:getHeight()) / 2),
            { size = 9, maxW = innerW - (lx - tx) })
        cy = cy + elemLH + 2
    end

    if #descLines > 0 then
        Palette.set(Palette.AGED_GOLD_DARK, 0.9)
        love.graphics.rectangle("fill", tx, cy + 3, innerW, 1)
        cy = cy + 7
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.PARCHMENT_LIGHT)
        for _, line in ipairs(descLines) do
            love.graphics.print(line, tx, cy)
            cy = cy + bodyLH
        end
    end

    for i, kw in ipairs(kwHits) do
        cy = cy + 4
        love.graphics.setFont(kwFont)
        local head = (kw.name .. kwSep):gsub("%s+$", "")
        local block = kwBlocks[i]
        for j, line in ipairs(block) do
            if j == 1 and line:sub(1, #head) == head then
                Palette.set(Palette.AGED_GOLD)
                love.graphics.print(head, tx, cy)
                Palette.set(Palette.PARCHMENT)
                love.graphics.print(line:sub(#head + 1), tx + kwFont:getWidth(head), cy)
            else
                Palette.set(Palette.PARCHMENT)
                love.graphics.print(line, tx, cy)
            end
            cy = cy + kwLH
        end
    end

    if rarityText then
        cy = cy + 8
        local rc = (Palette.forRarity and Palette.forRarity(cardInstance.rarity))
            or self.rarityColors[cardInstance.rarity] or { 1, 1, 1 }
        love.graphics.setFont(kwFont)
        local rw = kwFont:getWidth(rarityText) + 12
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.22)
        love.graphics.rectangle("fill", tx, cy, rw, 16, 3, 3)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, cy, rw, 16, 3, 3)
        love.graphics.print(rarityText, tx + 6, cy + 3)
        cy = cy + 18
    end

    if showStats then
        cy = cy + 8
        love.graphics.setFont(statFont)
        local statH = statFont:getHeight()
        local sx = tx
        local function statPair(icon, value, color)
            if icon then
                local s = statH / icon:getHeight()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(icon, sx, cy, 0, s, s)
                sx = sx + math.ceil(icon:getWidth() * s) + 6
            end
            love.graphics.setColor(color or { 1, 1, 1, 1 })
            love.graphics.print(tostring(value), sx, cy)
            sx = sx + statFont:getWidth(tostring(value)) + 14
        end
        if cardInstance.attack and cardInstance.attack > 0 then
            statPair(cardInstance.attackIcon, cardInstance.attack, { 1, 0.45, 0.35, 1 })
        end
        if cardInstance.defense and cardInstance.defense > 0 then
            statPair(cardInstance.armorIcon, cardInstance.defense, { 0.6, 0.75, 0.95, 1 })
        end
        if require("src.ui.CardFrame").showsManaCost(cardInstance) then
            statPair(cardInstance.manaIcon, cardInstance.cost or 0, { 0.55, 0.75, 1, 1 })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return CardInfoDisplay
