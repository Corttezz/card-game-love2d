local Debug = require("src.core.Debug")

local I18n = require("src.i18n.I18n")
local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local UiScale = require("src.ui.UiScale")

local GuideScreen = {}
GuideScreen.__index = GuideScreen
GuideScreen.ownsNavigation = true

local TABS = { "combos", "glossary" }
local PAD = 24
local ROW_GAP = 12
local SCROLL_STEP = 48

local navWarned = false
local function navTarget(id, x, y, w, h)
    local ok, NC = pcall(require, "src.ui.NavCursor")
    if ok and NC.target then return NC.target(id, x, y, w, h) end
    if not navWarned then
        navWarned = true
        Debug.warn("[GuideScreen] AVISO: src.ui.NavCursor indisponível — sem alvos de foco")
    end
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

function GuideScreen:new()
    local o = setmetatable({}, GuideScreen)
    o.visible = false
    o.tab = 1
    o.scroll = 0
    o.maxScroll = 0
    o._openedAt = 0
    return o
end

function GuideScreen:isVisible() return self.visible end

function GuideScreen:show(game)
    self.visible = true
    self.game = game
    self.scroll = 0
    self._openedAt = love.timer.getTime()
    pcall(function() require("src.systems.Sfx").play("menuOpen") end)
end

function GuideScreen:hide()
    if not self.visible then return end
    self.visible = false
    pcall(function() require("src.systems.Sfx").play("menuClose") end)
end

function GuideScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function GuideScreen:resize() self.scroll = math.min(self.scroll, self.maxScroll or 0) end
function GuideScreen:update() end

local function exampleCards(tag, classId)
    local CardDatabase = require("src.systems.CardDatabase")
    local TagSystem = require("src.systems.TagSystem")
    local mine, other = {}, {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.type ~= "joker" and TagSystem.cardHasTag(cd, tag) then
            local entry = { id = id, name = I18n.cardName(cd) }
            if classId and cd.class == classId then mine[#mine + 1] = entry
            else other[#other + 1] = entry end
        end
    end
    local function byName(a, b) return a.name < b.name end
    table.sort(mine, byName); table.sort(other, byName)
    local out = {}
    for _, list in ipairs({ mine, other }) do
        for _, e in ipairs(list) do
            if #out < 3 then out[#out + 1] = e.name end
        end
    end
    return out
end

local function ruleTags(rule)
    if rule.rule == "pair_tags" then return rule.requires or {} end
    return { rule.tag }
end

function GuideScreen.comboEntries(classId)
    local ComboSystem = require("src.systems.ComboSystem")
    local Panel = require("src.ui.DamagePreviewPanel")
    local out = {}
    for _, rule in ipairs(ComboSystem.RULES) do
        local names = {}
        for _, tag in ipairs(ruleTags(rule)) do
            for _, n in ipairs(exampleCards(tag, classId)) do
                if #names < 3 then names[#names + 1] = n end
            end
        end
        out[#out + 1] = {
            id = rule.id,
            title = I18n.t("combos." .. rule.id, nil, rule.label or rule.id),
            effect = Panel.comboDescription(rule),
            examples = (#names > 0) and I18n.t("tutorial.guide.examples",
                { cards = table.concat(names, ", ") }, table.concat(names, ", ")) or "",
        }
    end
    return out
end

function GuideScreen.glossaryEntries()
    local out = {}
    for _, kw in ipairs(require("src.data.keywords")) do
        out[#out + 1] = {
            id = kw.id,
            title = I18n.t("keyword." .. kw.id .. ".name", nil, kw.id),
            effect = I18n.t("keyword." .. kw.id .. ".text", nil, ""),
        }
    end
    return out
end

function GuideScreen:layout()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local fTitle = FontManager.getFont(20)
    local fTab = FontManager.getFont(12)
    local L = { W = W, H = H }
    local panelW = math.min(W - PAD * 2, 860)
    L.panel = { x = math.floor((W - panelW) / 2), y = 16, w = panelW, h = H - 32 }
    L.title = { x = L.panel.x, y = L.panel.y + 14, w = panelW, h = fTitle:getHeight() }
    L.close = { x = L.panel.x + panelW - 40, y = L.panel.y + 10, w = 30, h = 30 }
    local tabY = L.title.y + L.title.h + 14
    local tabW = 170
    L.tabs = {}
    for i = 1, #TABS do
        L.tabs[i] = { x = L.panel.x + PAD + (i - 1) * (tabW + 8), y = tabY, w = tabW, h = fTab:getHeight() + 14 }
    end
    L.hint = { x = L.tabs[#L.tabs].x + tabW + 16, y = tabY + 4 }
    local cy = tabY + L.tabs[1].h + 14
    L.content = { x = L.panel.x + PAD, y = cy, w = panelW - PAD * 2, h = L.panel.y + L.panel.h - cy - 14 }
    return L
end

function GuideScreen:_rows(L)
    local classId = self.game and self.game.selectedClass
    local entries = (TABS[self.tab] == "combos") and GuideScreen.comboEntries(classId)
        or GuideScreen.glossaryEntries()
    local fName = FontManager.getFont(12)
    local fBody = FontManager.getFont(10)
    local w = L.content.w - 24
    local rows = {}
    if TABS[self.tab] == "combos" then
        local _, lines = fBody:getWrap(I18n.t("tutorial.guide.intro"), L.content.w)
        rows[#rows + 1] = { intro = true, lines = lines, h = #lines * fBody:getHeight() * 1.2 + 6 }
    end
    for _, e in ipairs(entries) do
        local parts = {}
        local function add(label, text, color)
            if not text or text == "" then return end
            local s = label and (label .. ": " .. text) or text
            local _, ls = fBody:getWrap(s, w)
            parts[#parts + 1] = { lines = ls, color = color }
        end
        add(nil, e.effect, Palette.PARCHMENT_LIGHT)
        add(nil, e.examples, Palette.PARCHMENT)
        local h = fName:getHeight() + 8
        for _, p in ipairs(parts) do h = h + #p.lines * fBody:getHeight() * 1.2 end
        rows[#rows + 1] = { entry = e, parts = parts, h = math.floor(h + 16) }
    end
    return rows
end

function GuideScreen:setTab(i)
    local n = #TABS
    i = ((i - 1) % n) + 1
    if i ~= self.tab then
        self.tab = i
        self.scroll = 0
        pcall(function() require("src.systems.Sfx").play("menuHover") end)
    end
end

function GuideScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "g" then self:hide()
    elseif key == "left" or key == "pageup" or key == "q" then self:setTab(self.tab - 1)
    elseif key == "right" or key == "pagedown" or key == "e" or key == "tab" then self:setTab(self.tab + 1)
    elseif key == "up" then self.scroll = math.max(0, self.scroll - SCROLL_STEP)
    elseif key == "down" then self.scroll = math.min(self.maxScroll, self.scroll + SCROLL_STEP)
    end
    return true
end

function GuideScreen:wheelmoved(_, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * SCROLL_STEP))
    return true
end

local function hit(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function GuideScreen:mousepressed() return self.visible end

function GuideScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if love.timer.getTime() - self._openedAt < 0.25 or button ~= 1 then return true end
    local L = self:layout()
    if hit(L.close, x, y) then self:hide() return true end
    for i, r in ipairs(L.tabs) do
        if hit(r, x, y) then self:setTab(i) return true end
    end
    return true
end

function GuideScreen:draw()
    if not self.visible then return end
    local L = self:layout()
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(0.03, 0.02, 0.02, 0.88)
    love.graphics.rectangle("fill", 0, 0, L.W, L.H)
    local p = L.panel
    setColor(Palette.INK, 0.96)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 8, 8)
    setColor(Palette.AGED_GOLD, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 8, 8)
    love.graphics.setLineWidth(1)

    local fTitle = FontManager.getFont(20)
    love.graphics.setFont(fTitle)
    local title = I18n.t("tutorial.guide.title")
    setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, math.floor(L.title.x + (L.title.w - fTitle:getWidth(title)) / 2), L.title.y)

    local c = L.close
    local ch = hit(c, mx, my)
    setColor(ch and Palette.BLOOD or Palette.PARCHMENT, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.line(c.x + 8, c.y + 8, c.x + c.w - 8, c.y + c.h - 8)
    love.graphics.line(c.x + c.w - 8, c.y + 8, c.x + 8, c.y + c.h - 8)
    love.graphics.setLineWidth(1)
    navTarget("guide:close", c.x, c.y, c.w, c.h)

    local fTab = FontManager.getFont(12)
    love.graphics.setFont(fTab)
    for i, r in ipairs(L.tabs) do
        local on = (i == self.tab)
        local hv = hit(r, mx, my)
        setColor(on and Palette.AGED_GOLD or Palette.INK, on and 0.95 or 1)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
        setColor(Palette.AGED_GOLD, (on or hv) and 1 or 0.6)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
        local label = I18n.t("tutorial.guide.tab_" .. TABS[i])
        setColor(on and Palette.INK or Palette.PARCHMENT_LIGHT)
        love.graphics.print(label, math.floor(r.x + (r.w - fTab:getWidth(label)) / 2),
            math.floor(r.y + (r.h - fTab:getHeight()) / 2))
        navTarget("guide:tab" .. i, r.x, r.y, r.w, r.h)
    end
    local fHint = FontManager.getFont(9)
    love.graphics.setFont(fHint)
    setColor(Palette.PARCHMENT, 0.75)
    love.graphics.print(I18n.t("tutorial.guide.close_hint"), L.hint.x, L.hint.y + 4)

    local z = L.content
    local rows = self:_rows(L)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.h + ROW_GAP end
    self.maxScroll = math.max(0, total - z.h)
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll))
    love.graphics.setScissor(z.x, z.y, z.w, z.h)
    local fName = FontManager.getFont(12)
    local fBody = FontManager.getFont(10)
    local y = z.y - self.scroll
    for _, r in ipairs(rows) do
        if y + r.h >= z.y and y <= z.y + z.h then
            if r.intro then
                love.graphics.setFont(fBody)
                setColor(Palette.AGED_GOLD_LIGHT, 0.9)
                local ly = y
                for _, l in ipairs(r.lines) do
                    love.graphics.print(l, z.x, math.floor(ly)); ly = ly + fBody:getHeight() * 1.2
                end
            else
                setColor(Palette.PARCHMENT_DARK or { 0.25, 0.2, 0.15, 1 }, 0.35)
                love.graphics.rectangle("fill", z.x, y, z.w, r.h, 6, 6)
                setColor(Palette.AGED_GOLD, 0.45)
                love.graphics.rectangle("line", z.x, y, z.w, r.h, 6, 6)
                love.graphics.setFont(fName)
                setColor(Palette.AGED_GOLD_LIGHT)
                love.graphics.print(r.entry.title, z.x + 12, math.floor(y + 8))
                local ly = y + 8 + fName:getHeight() + 6
                love.graphics.setFont(fBody)
                for _, part in ipairs(r.parts) do
                    setColor(part.color or Palette.PARCHMENT_LIGHT)
                    for _, l in ipairs(part.lines) do
                        love.graphics.print(l, z.x + 12, math.floor(ly)); ly = ly + fBody:getHeight() * 1.2
                    end
                end
            end
        end
        y = y + r.h + ROW_GAP
    end
    love.graphics.setScissor()
    if self.maxScroll > 0 then
        local frac = self.scroll / self.maxScroll
        local knob = math.max(30, z.h * z.h / (z.h + self.maxScroll))
        setColor(Palette.INK, 0.8)
        love.graphics.rectangle("fill", p.x + p.w - 10, z.y, 4, z.h, 2, 2)
        setColor(Palette.AGED_GOLD, 0.9)
        love.graphics.rectangle("fill", p.x + p.w - 10, z.y + frac * (z.h - knob), 4, knob, 2, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

UiScale.adopt(GuideScreen)
return GuideScreen
