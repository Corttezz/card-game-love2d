local RestScreen = {}
RestScreen.__index = RestScreen

local FontManager     = require("src.ui.FontManager")
local Palette         = require("src.ui.Palette")
local Button          = require("components.Button")
local Panel9          = require("src.ui.Panel9")
local SceneBackground = require("src.ui.SceneBackground")
local IconLoader      = require("src.ui.IconLoader")
local CardDatabase    = require("src.systems.CardDatabase")
local I18n            = require("src.i18n.I18n")
local HintBar         = require("src.ui.HintBar")
local Sfx             = require("src.systems.Sfx")
local FloatingText    = require("src.ui.FloatingText")
local EventManager    = require("engine.EventManager")
local DissolveShader  = require("src.ui.DissolveShader")
local FlashShader     = require("src.ui.FlashShader")
local ImageCache      = require("src.ui.ImageCache")
local ParticlesManager = require("engine.ParticlesManager")
local Moveable        = require("engine.Moveable")

local CARD_W, CARD_H = 96, 144

local FORGE_Q = "forge"

function RestScreen:new()
    local instance = setmetatable({}, RestScreen)
    instance.visible = false
    instance.game = nil
    instance.onClose = nil
    instance.mode = "choose"
    instance.buttons = {}
    instance.cardList = {}
    instance.cardEntries = {}
    instance.page = 1
    instance.pageCount = 1
    instance.busy = false
    instance.forge = nil
    instance.resultText = nil
    instance.resultTimer = 0
    instance.choiceCards = {}
    return instance
end

local PICKER_KEYS = {
    forge     = "rest.pick_forge_",
    remove    = "rest.pick_remove_",
    duplicate = "rest.pick_dup_",
}

local function pickerText(mode, part)
    local prefix = PICKER_KEYS[mode]
    if not prefix then return nil end
    return I18n.t(prefix .. part)
end

local STAT_KEY = {
    atk    = "card_type.attack",
    def    = "card_type.defense",
    effect = "card_type.effect",
}
local function statLabel(which)
    return I18n.t(STAT_KEY[which] or "card_type.unknown")
end

function RestScreen:show(game, onClose, mode)
    self.visible = true
    self.game = game
    self.onClose = onClose
    self.mode = mode or "choose"
    self._directPicker = (self.mode ~= "choose")
    self.resultText = nil
    self.resultTimer = 0
    self.busy = false
    self.forge = nil
    self.page = 1
    self._hoverIdx = nil
    self.lastPickDone = false
    if self._directPicker then
        self:enterForgeMode()
    else
        self:buildChooseButtons()
    end
end

function RestScreen:hide()
    self.visible = false
    EventManager.clear(FORGE_Q)
    self.buttons = {}
    self.cardList = {}
    self.cardEntries = {}
    self.choiceCards = {}
    self.busy = false
    self.forge = nil
    self._hoverIdx = nil
end

function RestScreen:isVisible() return self.visible end

function RestScreen:resize()
    if not self.visible then return end
    if self.mode == "choose" then
        self:buildChooseButtons()
    else
        self:_layoutPage(false)
    end
end

function RestScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw, ph
    if self.mode ~= "choose" then
        pw = math.min(1000, math.floor(sw * 0.92))
        ph = math.min(720, math.floor(sh * 0.90))
    else
        pw = math.min(680, math.floor(sw * 0.72))
        ph = 420
    end
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2) + 10
    return px, py, pw, ph
end

function RestScreen:buildChooseButtons()
    self.buttons = {}
    self.choiceCards = {}
    local px, py, pw = self:panelRect()

    local cw, chh = 250, 200
    local gap = 36
    local cy = py + 150
    local leftX = math.floor(px + pw / 2 - cw - gap / 2)
    local rightX = math.floor(px + pw / 2 + gap / 2)

    local p = self.game and self.game.player
    local healAmt = p and math.floor(p.maxHealth * self:_healPct()) or 0
    local healTo = p and math.min(p.health + healAmt, p.maxHealth) or 0
    local healDetail = p
        and (I18n.t("rest.hp_abbr") .. " " .. p.health .. "/" .. p.maxHealth
             .. "  ->  " .. healTo .. "/" .. p.maxHealth)
        or ""

    local full = p and p.health >= p.maxHealth
    local heal = {
        x = leftX, y = cy, w = cw, h = chh,
        icon = "ui_health", title = I18n.t("rest.heal_title"),
        sub = I18n.t("rest.heal_sub", { n = math.floor(self:_healPct() * 100 + 0.5) }),
        detail = full and I18n.t("rest.heal_full") or healDetail,
        muted = full,
    }
    heal.btn = Button:new(leftX, cy, cw, chh, "",
        function() self:doHeal() end)
    heal.btn:setVariant("invisible")

    local forge = {
        x = rightX, y = cy, w = cw, h = chh,
        icon = "ui_forge", title = I18n.t("rest.forge_title"),
        sub = I18n.t("rest.forge_sub"),
        detail = I18n.t("rest.forge_detail"),
    }
    forge.btn = Button:new(rightX, cy, cw, chh, "",
        function() self:enterForgeMode() end)
    forge.btn:setVariant("invisible")

    self.choiceCards = { heal, forge }
    table.insert(self.buttons, heal.btn)
    table.insert(self.buttons, forge.btn)
end

function RestScreen:_markCampUsed()
    if self._directPicker then return end
    local rm = self.game and self.game.runManager
    local run = rm and rm.currentRun
    if run and run.stage == "rest" then run.stage = "rest_done" end
end

function RestScreen:_healPct()
    local rm = self.game and self.game.runManager
    return (require("src.core.Config").Game.REST_HEAL_PCT or 0.30)
        * require("src.systems.RunModifiers").healMul(rm and rm.currentRun, "rest")
end

function RestScreen:doHeal()
    self:_markCampUsed()
    local amt = math.floor(self.game.player.maxHealth * self:_healPct())
    self.game.player:heal(amt)
    self.resultText = I18n.t("rest.heal_result", { n = amt })
    self.resultTimer = 1.5
    self.buttons = {}
    self.choiceCards = {}
    Sfx.play("restComplete")

    Sfx.play("healShimmer", { pitch = 0.95, volume = 0.55 })

    local cx = love.graphics.getWidth() * 0.5
    local cy = love.graphics.getHeight() * 0.42
    FloatingText.spawn("+" .. amt .. " " .. I18n.t("rest.hp_abbr"), cx, cy,
        { kind = "heal", lift = 34 })

    local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
    if okCF and CardFeel.burst then
        CardFeel.burst("heal", cx, cy, 1.2)
    end
end

local function cloneEffects(inst)
    if not inst.effects then return end
    local copy = {}
    for i, eff in ipairs(inst.effects) do
        local c = {}
        for k, v in pairs(eff) do c[k] = v end
        copy[i] = c
    end
    inst.effects = copy
end

function RestScreen:_makeInstance(cardId, level)
    local cd = CardDatabase:getCard(cardId)
    if not cd then return nil end
    local ok, inst = pcall(function() return CardDatabase:createCardInstance(cd) end)
    if not ok or not inst then return nil end
    if level and level > 0 and self.game and self.game.runManager
        and self.game.runManager.applyUpgradesToInstance then
        cloneEffects(inst)
        self.game.runManager:applyUpgradesToInstance(inst, level)
    end
    return inst
end

function RestScreen:_gridRect()
    local px, py, pw, ph = self:panelRect()
    local gx = px + 30
    local gy = py + 112
    local gw = pw - 60
    local gh = math.max(150, ph - 112 - 126)
    return gx, gy, gw, gh
end

function RestScreen:_gridMetrics()
    local gx, gy, gw, gh = self:_gridRect()
    local n = #self.cardList
    local gapX, gapY = 18, 28

    local cols = 5
    if n > 0 and n < cols then cols = n end
    local maxCols = math.max(2, math.floor((gw + gapX) / (74 + gapX)))
    cols = math.max(1, math.min(cols, maxCols))

    local rows = 2
    if n > 0 and n <= cols then rows = 1 end
    if rows == 2 and ((gh - gapY) / 2) < 120 then rows = 1 end

    local cellW = (gw - gapX * (cols - 1)) / cols
    local cellH = (gh - gapY * (rows - 1)) / rows
    local scale = math.min(cellW / CARD_W, cellH / CARD_H, 1.6)

    return {
        gx = gx, gy = gy, gw = gw, gh = gh,
        cols = cols, rows = rows, gapX = gapX, gapY = gapY,
        scale = scale,
        cw = CARD_W * scale, ch = CARD_H * scale,
        perPage = cols * rows,
    }
end

function RestScreen:enterForgeMode()
    if self.mode == "choose" then self.mode = "forge" end
    self.choiceCards = {}
    self.cardList = {}
    self.page = 1
    self._anchorIdx = 1
    self.cardEntries = {}
    self._hoverIdx = nil

    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if not run then
        self.cardEntries = {}
        self:_buildFooterButtons()
        return
    end

    local rm = self.game.runManager
    for i, entry in ipairs(run.currentDeck) do
        local id = type(entry) == "table" and entry.id or entry
        if id and (self.mode ~= "forge" or rm:canUpgradeAt(i)) then
            table.insert(self.cardList, i)
        end
    end

    self:_layoutPage(true)
end

local function gridPositions(m, count)
    local pos = {}
    local rowsOnPage = math.max(1, math.ceil(count / m.cols))
    local totalH = rowsOnPage * m.ch + (rowsOnPage - 1) * m.gapY
    local startY = m.gy + math.floor((m.gh - totalH) / 2)
    local idx = 0
    for r = 0, rowsOnPage - 1 do
        local inRow = math.min(m.cols, count - r * m.cols)
        local totalW = inRow * m.cw + (inRow - 1) * m.gapX
        local startX = m.gx + math.floor((m.gw - totalW) / 2)
        for c = 0, inRow - 1 do
            idx = idx + 1
            pos[idx] = {
                x = math.floor(startX + c * (m.cw + m.gapX)),
                y = math.floor(startY + r * (m.ch + m.gapY)),
            }
        end
    end
    return pos
end

local function placeEntry(e, p, m)
    e.x, e.y, e.w, e.h = p.x, p.y, m.cw, m.ch
    local inst = e.inst
    if not inst then return end
    inst.x, inst.y = p.x, p.y
    inst.homeX, inst.homeY = p.x, p.y
    inst.layoutX, inst.layoutY = p.x, p.y
    inst.baseScale = m.scale
    inst.currentScale = m.scale
    inst.targetScale = m.scale
    inst.isRewardCard = true
    inst.noHoverLift = false
end

function RestScreen:_makeEntries(first, count)
    local entries = {}
    local rm = self.game and self.game.runManager
    local run = rm and rm.currentRun
    for i = 1, count do
        local deckIdx = self.cardList[first + i - 1]
        local deckEntry = deckIdx and run and run.currentDeck[deckIdx]
        local cardId = deckEntry and
            (type(deckEntry) == "table" and deckEntry.id or deckEntry)
        local level = deckEntry and rm:getEntryLevel(deckEntry) or 0
        local inst = cardId and self:_makeInstance(cardId, level) or nil
        if inst then
            table.insert(entries, {
                idx = deckIdx, id = cardId, inst = inst, level = level,
                x = 0, y = 0, w = 0, h = 0,
            })
        end
    end
    return entries
end

function RestScreen:_layoutPage(rebuild)
    local m = self:_gridMetrics()
    local n = #self.cardList

    if self.busy or self.forge then
        local pos = gridPositions(m, #self.cardEntries)
        for i, e in ipairs(self.cardEntries) do
            if pos[i] then placeEntry(e, pos[i], m) end
        end
        if self.forge then self:_layoutForge(self.forge) end
        self:_buildFooterButtons()
        return
    end

    self.pageCount = math.max(1, math.ceil(n / m.perPage))
    if rebuild then
        self.page = math.max(1, math.min(self.pageCount, self.page))
    else
        local anchor = self._anchorIdx or 1
        self.page = math.max(1, math.min(self.pageCount,
            math.floor((anchor - 1) / m.perPage) + 1))
    end

    local first = (self.page - 1) * m.perPage + 1
    local count = math.max(0, math.min(n, self.page * m.perPage) - first + 1)
    self._anchorIdx = first

    if not rebuild then
        local sameCount = (#self.cardEntries == count)
        local sameFirst = (count == 0)
            or (self.cardEntries[1] ~= nil
                and self.cardEntries[1].idx == self.cardList[first])
        rebuild = not (sameCount and sameFirst)
    end

    self._hoverIdx = nil
    if rebuild then
        self.cardEntries = self:_makeEntries(first, count)
    end

    local pos = gridPositions(m, #self.cardEntries)
    for i, e in ipairs(self.cardEntries) do
        if pos[i] then placeEntry(e, pos[i], m) end
    end

    self:_buildFooterButtons()
end

function RestScreen:_buildFooterButtons()
    self.buttons = {}
    local px, py, pw, ph = self:panelRect()

    if self.pageCount > 1 then
        local by = py + ph - 104
        local prev = Button:new(math.floor(px + pw / 2 - 150), by, 110, 34,
            I18n.t("rest.page_prev"), function() self:_changePage(-1) end, nil, 10)
        local nxt = Button:new(math.floor(px + pw / 2 + 40), by, 110, 34,
            I18n.t("rest.page_next"), function() self:_changePage(1) end, nil, 10)
        if self.page <= 1 then prev:setEnabled(false) end
        if self.page >= self.pageCount then nxt:setEnabled(false) end
        table.insert(self.buttons, prev)
        table.insert(self.buttons, nxt)
    end

    local back = Button:new(
        math.floor(px + pw / 2 - 80), py + ph - 60, 160, 40,
        I18n.t("common.back"),
        function()
            if self._directPicker then
                local cb = self.onClose
                self:hide()
                if cb then cb() end
            else
                self:show(self.game, self.onClose)
            end
        end
    )
    back:setIcon("x_close")
    table.insert(self.buttons, back)
end

function RestScreen:_changePage(delta)
    if self.busy then return end
    local target = self.page + delta
    if target < 1 or target > self.pageCount then return end
    self.page = target
    Sfx.play("menuHover")
    self:_layoutPage(true)
end

function RestScreen:_onPickCard(entry)
    if self.busy or not entry then return end
    if self.mode == "remove" then
        self:doRemove(entry)
    elseif self.mode == "duplicate" then
        self:doDuplicate(entry)
    else
        self:doForge(entry)
    end
end

function RestScreen:_finishWith(text, hold)
    self.resultText = text
    self.resultTimer = hold or 1.5
    self.buttons = {}
    self.busy = false
    self._hoverIdx = nil
end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function jiggle(amount)
    if reducedMotion() then return end
    if _G.jiggleScreen then _G.jiggleScreen(amount) end
end

local function flash(intensity, duration)
    if reducedMotion() then return end
    if FlashShader and FlashShader.trigger then
        FlashShader.trigger(intensity, duration)
    end
end

local function playFirst(codes, opts)
    for _, code in ipairs(codes) do
        if Sfx.has(code) then
            Sfx.play(code, opts)
            return code
        end
    end
    return nil
end

function RestScreen:doRemove(entry)
    if not self.game or not self.game.runManager or not entry then return end
    local cardId = entry.id
    local run = self.game.runManager.currentRun
    if not run or #run.currentDeck <= 2 then
        self:_finishWith(I18n.t("rest.remove_too_thin"), 1.5)
        return
    end
    local cd = CardDatabase:getCard(cardId)
    local displayName = I18n.cardName(cd or cardId)
    self.game.runManager:removeCardAt(entry.idx)
    self.lastPickDone = true
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    Sfx.play("restComplete")

    local text = I18n.t("rest.removed", { name = displayName })
    if entry.inst and entry.inst.start_dissolve and not reducedMotion() then
        self.busy = true
        self.buttons = {}
        self._hoverIdx = nil
        jiggle(0.4)
        entry.inst:start_dissolve(DissolveShader.palette("exhaust"),
            false, 0.6, false, function()
                self:_finishWith(text, 1.0)
            end)
    else
        self:_finishWith(text, 1.5)
    end
end

function RestScreen:doDuplicate(entry)
    if not self.game or not self.game.runManager or not entry then return end
    local cardId = entry.id
    local cd = CardDatabase:getCard(cardId)
    local displayName = I18n.cardName(cd or cardId)
    self.game.runManager:duplicateCardAt(entry.idx)
    self.lastPickDone = true
    if self.game.synchronizeRunDeck then self.game:synchronizeRunDeck() end
    Sfx.play("restComplete")

    if entry.inst then
        entry.inst:juice_up(0.35, 0.1)
        FloatingText.spawn(I18n.t("rest.dup_popup"),
            math.floor(entry.x + entry.w / 2), math.floor(entry.y + 12),
            { kind = "buff" })
    end
    self:_finishWith(I18n.t("rest.duplicated", { name = displayName }), 1.5)
end

local FORGE_T = {
    lift   = 0.34,
    clang1 = 0.46,
    clang2 = 0.74,
    clang3 = 1.00,
    settle = 1.22,
    hold   = 1.35,
}

local CLANG_AT = {
    { 0.16, 0.32 },
    { 0.78, 0.58 },
    { 0.46, 0.12 },
}

local SPARK_COLOURS = {
    { 1.00, 0.82, 0.35, 1 },
    { 1.00, 0.55, 0.12, 1 },
    { 1.00, 0.93, 0.72, 1 },
}

local PLATE_PAD = 14

local function clearHoverPose(inst)
    if not inst then return end
    inst.isHovered = false
    inst.liftOffset = 0
    inst.hoverBob = 0
    inst.hoverStrength = 0
    inst.offsetHoverX, inst.offsetHoverY = 0, 0
    inst.tiltX, inst.tiltY = 0, 0
    inst._velTilt = 0
    inst.perspectiveRotation = 0
    inst.shadowOffsetX, inst.shadowOffsetY = 0, 0
    inst.shadowScale = 0.9
end

function RestScreen:_buildForgeLines(cd, gains, lvl)
    local lines = {}
    local function add(label, old, new, delta, kind)
        table.insert(lines, {
            label = label,
            old = tostring(old), new = tostring(new), delta = delta, kind = kind,
            oldA = 1, oldS = 1, newA = 0, newS = 1, hot = 0,
        })
    end
    if gains.atk then
        local cur = (cd.attack or 0) + gains.atk * lvl
        add(statLabel("atk"), cur, cur + gains.atk, "+" .. gains.atk, "damage")
    end
    if gains.def then
        local cur = (cd.defense or 0) + gains.def * lvl
        add(statLabel("def"), cur, cur + gains.def, "+" .. gains.def, "armor")
    end
    if gains.effectIndex and cd.effects and cd.effects[gains.effectIndex] then
        local base = cd.effects[gains.effectIndex].value or 0
        local cur = base + gains.effect * lvl
        add(statLabel("effect"), cur, cur + gains.effect, "+" .. gains.effect, "buff")
    end
    if #lines == 0 then
        add(I18n.t("rest.forge_level"), "+" .. lvl, "+" .. (lvl + 1), "+1", "buff")
    end
    return lines
end

local function applyPose(f)
    local p = f.pose or 0
    f.cx = f.startX + (f.heroX - f.startX) * p
    f.cy = f.startY + (f.heroY - f.startY) * p
    f.scale = f.startScale + (f.heroScale - f.startScale) * p
end

function RestScreen:_layoutForge(f)
    local gx, gy, gw, gh = self:_gridRect()

    local labelFont = FontManager.getFont(11)
    local numFont = FontManager.getFont(18)
    local arrowFont = FontManager.getFont(13)
    local stampFont = FontManager.getFont(20)

    local lblW, numW = 0, 0
    for _, ln in ipairs(f.lines) do
        lblW = math.max(lblW, labelFont:getWidth(ln.label))
        numW = math.max(numW, numFont:getWidth(ln.old), numFont:getWidth(ln.new))
    end
    local arrowW = arrowFont:getWidth("->")
    local innerW = lblW + 16 + numW + 14 + arrowW + 14 + numW
    local lineH = math.floor(numFont:getHeight() * 1.5)
    local stampH = math.floor(stampFont:getHeight() * 1.35)
    local plateW = innerW + PLATE_PAD * 2
    local plateH = PLATE_PAD * 2 + #f.lines * lineH + stampH

    local gridScale = (f.entry.w > 0) and (f.entry.w / CARD_W)
        or (f.entry.inst and f.entry.inst.baseScale) or 1
    local heroScale = math.min(2.0, gridScale * 1.35)
    local maxBlockH = gh - 12
    local blockGap = 14
    while heroScale > 0.75
        and (CARD_H * heroScale + blockGap + plateH) > maxBlockH do
        heroScale = heroScale - 0.05
    end
    local hw, hh = CARD_W * heroScale, CARD_H * heroScale
    local blockH = hh + blockGap + plateH
    local topY = gy + math.floor((gh - blockH) / 2)
    if topY < gy then topY = gy end

    f.heroX = gx + math.floor((gw - hw) / 2)
    f.heroY = topY
    f.heroScale = heroScale
    f.heroW, f.heroH = hw, hh

    f.startX, f.startY = f.entry.x, f.entry.y
    f.startScale = gridScale

    f.plate = {
        x = gx + math.floor((gw - plateW) / 2),
        y = topY + hh + blockGap,
        w = plateW, h = plateH,
        lineH = lineH, stampH = stampH,
        lblX = PLATE_PAD,
        oldCx = PLATE_PAD + lblW + 16 + numW / 2,
        arrowCx = PLATE_PAD + lblW + 16 + numW + 7 + arrowW / 2,
        newCx = PLATE_PAD + lblW + 16 + numW + 14 + arrowW + 14 + numW / 2,
    }

    applyPose(f)
end

function RestScreen:_buildForge(entry, cardId, cd, gains, newLvl, resultText)
    local f = {
        entry = entry, cardId = cardId, newLvl = newLvl, gains = gains,
        resultText = resultText,
        lines = self:_buildForgeLines(cd, gains, newLvl - 1),
        pose = 0,
        veil = 0, glow = 0, plateA = 0,
        stampA = 0, stampS = 1, stampText = "+" .. newLvl,
        clangs = {},
    }
    self:_layoutForge(f)
    return f
end

function RestScreen:_clang(n)
    local f = self.forge
    if not f then return end
    local at = CLANG_AT[n] or CLANG_AT[1]
    local x = f.heroX + f.heroW * at[1]
    local y = f.heroY + f.heroH * at[2]

    playFirst({ "forgeStrike", "restComplete" },
        { pitch = 0.92 + (n - 1) * 0.09 })
    jiggle(n == 2 and 1.3 or 0.85)

    local decal = {
        fx = at[1], fy = at[2],
        rot = love.math.random() * math.pi * 2,
        a = 0.85, s = 0.30,
    }
    table.insert(f.clangs, decal)
    EventManager.parallelEase(decal, "a", 0, 0.55, "smooth", FORGE_Q)
    EventManager.parallelEase(decal, "s", 1.45, 0.55, "easeout", FORGE_Q)

    ParticlesManager.spawn(x - 5, y - 5, 10, 10, {
        fill = true,
        timer = 0.004,
        lifespan = 0.55,
        scale = 0.32,
        speed = 250,
        vel_variation = 1,
        gravity = 950,
        colours = SPARK_COLOURS,
        pulse_max = 26,
        max = 32,
        layer = 9,
    })
end

function RestScreen:_forgeTurn()
    local f = self.forge
    if not f then return end
    local reduced = reducedMotion()

    local upgraded = self:_makeInstance(f.cardId, f.newLvl)
    if upgraded then
        upgraded.x, upgraded.y = f.cx, f.cy
        upgraded.homeX, upgraded.homeY = f.entry.x, f.entry.y
        upgraded.layoutX, upgraded.layoutY = f.entry.x, f.entry.y
        upgraded.baseScale = f.scale
        upgraded.currentScale = f.scale
        upgraded.targetScale = f.scale
        upgraded.isRewardCard = true
        clearHoverPose(upgraded)
        f.entry.inst = upgraded
        f.entry.level = f.newLvl
        if not reduced then upgraded:juice_up(0.4, 0.10) end
    end

    if not reduced then
        flash(0.32, 0.22)
        f.glow = 1
        EventManager.parallel(0.12, function()
            EventManager.parallelEase(f, "glow", 0, 0.95, "smooth", FORGE_Q)
        end, FORGE_Q)
    end

    local plate = f.plate
    local POP_FONT = 15
    local POP_GAP  = 18
    local popFont = FontManager.getFont(POP_FONT)
    local popHalf = 0
    for _, ln in ipairs(f.lines) do
        popHalf = math.max(popHalf, popFont:getWidth(ln.delta .. " " .. ln.label) * 0.5)
    end
    local popX = math.floor(plate.x + plate.w + POP_GAP + popHalf)
    if popX + popHalf > love.graphics.getWidth() - 12 then
        popX = math.floor(plate.x - POP_GAP - popHalf)
    end
    popX = math.max(math.floor(popHalf + 12), popX)
    for i, ln in ipairs(f.lines) do
        local delay = (i - 1) * 0.07
        local popY = math.floor(plate.y + PLATE_PAD
            + (i - 1) * plate.lineH + plate.lineH / 2)
        if reduced then
            ln.oldA, ln.oldS, ln.newA, ln.newS, ln.hot = 0.30, 0.82, 1, 1, 0
            FloatingText.spawn(ln.delta .. " " .. ln.label, popX, popY,
                { kind = ln.kind, hold = 0.8, fontSize = POP_FONT })
        else
            EventManager.parallel(delay, function()
                EventManager.parallelEase(ln, "oldA", 0.30, 0.22, "smooth", FORGE_Q)
                EventManager.parallelEase(ln, "oldS", 0.82, 0.22, "smooth", FORGE_Q)
                ln.newA = 1
                ln.newS = 2.1
                ln.hot = 1
                EventManager.parallelEase(ln, "newS", 1, 0.30, "easeout", FORGE_Q)
                EventManager.parallelEase(ln, "hot", 0, 0.80, "smooth", FORGE_Q)
                FloatingText.spawn(ln.delta .. " " .. ln.label, popX, popY,
                    { kind = ln.kind, hold = 0.6, fontSize = POP_FONT })
            end, FORGE_Q)
        end
    end
end

function RestScreen:_forgeStamp()
    local f = self.forge
    if not f then return end
    f.stampA = 1
    if reducedMotion() then
        f.stampS = 1
        return
    end
    f.stampS = 2.4
    EventManager.parallelEase(f, "stampS", 1, 0.30, "backout", FORGE_Q)
end

function RestScreen:doForge(entry)
    if not self.game or not self.game.runManager or not entry then return end
    local cardId = entry.id
    local cd = CardDatabase:getCard(cardId)
    local displayName = I18n.cardName(cd or cardId)

    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(cd)

    local newLvl = self.game.runManager:upgradeCardAt(entry.idx)
    if newLvl then
        self:_markCampUsed()
        self.lastPickDone = true
    end
    if not newLvl then
        self:_finishWith(I18n.t("rest.forge_capped", { name = displayName }), 1.0)
        return
    end

    local parts = {}
    if gains.atk then
        table.insert(parts, "+" .. (gains.atk * newLvl) .. " " .. statLabel("atk"))
    end
    if gains.def then
        table.insert(parts, "+" .. (gains.def * newLvl) .. " " .. statLabel("def"))
    end
    if gains.effect then
        table.insert(parts, "+" .. (gains.effect * newLvl) .. " " .. statLabel("effect"))
    end
    local suffix = #parts > 0
        and ("  " .. I18n.t("rest.forged_gains",
            { parts = table.concat(parts, ", ") }))
        or ""
    local resultText = I18n.t("rest.forged",
        { name = displayName, lvl = newLvl }) .. suffix

    require("src.systems.AchievementSystem").onForge(self.game)

    if not entry.inst or not cd then
        playFirst({ "forgeStrike", "restComplete" })
        self:_finishWith(resultText, 1.5)
        return
    end

    self.busy = true
    self.buttons = {}
    self._hoverIdx = nil

    local f = self:_buildForge(entry, cardId, cd, gains, newLvl, resultText)
    self.forge = f
    clearHoverPose(entry.inst)

    local reduced = reducedMotion()

    if reduced then
        f.pose = 1
        applyPose(f)
        f.veil, f.plateA = 1, 1
        EventManager.parallel(0.18, function()
            self:_forgeTurn()
            self:_forgeStamp()
        end, FORGE_Q)
        EventManager.parallel(0.18 + FORGE_T.hold, function()
            self:_finishWith(resultText, 0.01)
        end, FORGE_Q)
        return
    end

    EventManager.parallelEase(f, "pose", 1, FORGE_T.lift, "smooth", FORGE_Q)
    EventManager.parallelEase(f, "veil", 1, FORGE_T.lift, "smooth", FORGE_Q)
    EventManager.parallelEase(f, "plateA", 1, FORGE_T.lift * 1.2, "smooth", FORGE_Q)
    if entry.inst.swell_up then entry.inst:swell_up(0.10, FORGE_T.lift) end

    EventManager.parallel(FORGE_T.clang1, function() self:_clang(1) end, FORGE_Q)
    EventManager.parallel(FORGE_T.clang2, function()
        self:_clang(2)
        self:_forgeTurn()
    end, FORGE_Q)
    EventManager.parallel(FORGE_T.clang3, function()
        self:_clang(3)
        self:_forgeStamp()
    end, FORGE_Q)

    EventManager.parallel(FORGE_T.settle, function()
        playFirst({ "forgeReveal" })
        local inst = f.entry.inst
        if inst and inst.juice_up then inst:juice_up(0.18, 0.04) end
    end, FORGE_Q)
    EventManager.parallel(FORGE_T.settle + FORGE_T.hold, function()
        self:_finishWith(resultText, 0.01)
    end, FORGE_Q)
end

function RestScreen:_drawForge(px, py, pw, ph)
    local f = self.forge
    if not f then return end

    if (f.veil or 0) > 0 then
        love.graphics.setColor(0.05, 0.035, 0.02, 0.60 * f.veil)
        love.graphics.rectangle("fill", px, py, pw, ph)
    end

    local inst = f.entry.inst
    local cw = CARD_W * f.scale
    local chh = CARD_H * f.scale

    if (f.glow or 0) > 0.01 then
        love.graphics.setBlendMode("add")
        for i = 1, 4 do
            local pad = 6 + i * 9
            love.graphics.setColor(0.55, 0.36, 0.10, 0.16 * f.glow / i)
            love.graphics.rectangle("fill",
                f.cx - pad, f.cy - pad, cw + pad * 2, chh + pad * 2, pad * 0.5)
        end
        love.graphics.setBlendMode("alpha")
    end

    if inst then
        inst.baseScale = f.scale
        inst.targetScale = f.scale
        inst.currentScale = f.scale
        inst.isHovered = false
        inst:draw(math.floor(f.cx), math.floor(f.cy), false, true)
    end

    local decalImg = ImageCache.get("assets/sprites/packs/effects/burst.png")
    if decalImg and decalImg:getWidth() > 1 then
        love.graphics.setBlendMode("add")
        local dw, dh = decalImg:getWidth(), decalImg:getHeight()
        for _, d in ipairs(f.clangs) do
            if (d.a or 0) > 0.01 then
                local dx = f.heroX + f.heroW * d.fx
                local dy = f.heroY + f.heroH * d.fy
                local s = (d.s or 0.3) * (cw / dw) * 1.1
                love.graphics.setColor(1, 0.86, 0.55, d.a)
                love.graphics.draw(decalImg, dx, dy, d.rot, s, s, dw / 2, dh / 2)
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    self:_drawForgePlate()
    love.graphics.setColor(1, 1, 1, 1)
end

local function printCentered(font, text, cx, cy, scale)
    love.graphics.setFont(font)
    love.graphics.print(text, math.floor(cx), math.floor(cy), 0,
        scale, scale, font:getWidth(text) / 2, font:getHeight() / 2)
end

function RestScreen:_drawForgePlate()
    local f = self.forge
    local p = f.plate
    local a = f.plateA or 0
    if a <= 0.01 then return end

    Panel9.draw("panel_inner", p.x, p.y, p.w, p.h, {
        fill = { 0.10, 0.08, 0.06, 0.95 * a },
    })

    local labelFont = FontManager.getFont(11)
    local numFont = FontManager.getFont(18)
    local arrowFont = FontManager.getFont(13)

    for i, ln in ipairs(f.lines) do
        local cy = p.y + PLATE_PAD + (i - 1) * p.lineH + p.lineH / 2

        love.graphics.setFont(labelFont)
        Palette.set(Palette.RUST, a)
        love.graphics.print(ln.label, math.floor(p.x + p.lblX),
            math.floor(cy - labelFont:getHeight() / 2))

        Palette.set(Palette.PARCHMENT, a * (ln.oldA or 1))
        printCentered(numFont, ln.old, p.x + p.oldCx, cy, ln.oldS or 1)

        Palette.set(Palette.AGED_GOLD_DARK, a * 0.9)
        printCentered(arrowFont, "->", p.x + p.arrowCx, cy, 1)

        if (ln.newA or 0) > 0.01 then
            local s = ln.newS or 1
            if (ln.hot or 0) > 0.01 then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.95, 0.80, a * ln.hot * 0.85)
                printCentered(numFont, ln.new, p.x + p.newCx, cy, s * 1.12)
                love.graphics.setBlendMode("alpha")
            end
            Palette.set(Palette.AGED_GOLD_LIGHT, a * ln.newA)
            printCentered(numFont, ln.new, p.x + p.newCx, cy, s)
        end
    end

    if (f.stampA or 0) > 0.01 then
        local stampFont = FontManager.getFont(20)
        local cy = p.y + PLATE_PAD + #f.lines * p.lineH + p.stampH / 2
        local cx = p.x + p.w / 2
        local s = f.stampS or 1
        if s > 1.02 then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 0.92, 0.70, a * 0.5 * (s - 1))
            printCentered(stampFont, f.stampText, cx, cy, s * 1.15)
            love.graphics.setBlendMode("alpha")
        end
        Palette.set(Palette.AGED_GOLD_LIGHT, a * f.stampA)
        printCentered(stampFont, f.stampText, cx, cy, s)
    end
end

local PANEL_MAX_INNER = 230
local PANEL_PAD = 12

function RestScreen:_hoverPanelContent(entry)
    local cd = CardDatabase:getCard(entry.id)
    local inst = entry.inst
    local I18n = require("src.i18n.I18n")
    local name = (inst and I18n.cardName and I18n.cardName(inst))
        or (cd and cd.name) or tostring(entry.id)
    if (entry.level or 0) > 0 then
        name = name .. " +" .. entry.level
    end

    local gainLines = {}
    if self.mode == "forge" and cd then
        local RunManager = require("src.systems.RunManager")
        local gains = RunManager.getForgeGains(cd)
        local lvl = entry.level or 0
        if gains.atk then
            local cur = (cd.attack or 0) + gains.atk * lvl
            table.insert(gainLines, statLabel("atk")
                .. "  " .. cur .. "  ->  " .. (cur + gains.atk))
        end
        if gains.def then
            local cur = (cd.defense or 0) + gains.def * lvl
            table.insert(gainLines, statLabel("def")
                .. "  " .. cur .. "  ->  " .. (cur + gains.def))
        end
        if gains.effectIndex and cd.effects and cd.effects[gains.effectIndex] then
            local base = cd.effects[gains.effectIndex].value or 0
            local cur = base + gains.effect * lvl
            table.insert(gainLines, statLabel("effect")
                .. "  " .. cur .. "  ->  " .. (cur + gains.effect))
        end
        table.insert(gainLines, I18n.t("rest.forge_level")
            .. "  +" .. lvl .. "  ->  +" .. (lvl + 1))
    elseif self.mode == "remove" then
        table.insert(gainLines, I18n.t("rest.warn_remove"))
    elseif self.mode == "duplicate" then
        table.insert(gainLines, I18n.t("rest.warn_dup"))
    end

    local desc = nil
    if inst and I18n.cardDesc then desc = I18n.cardDesc(inst) end
    if (not desc or desc == "") and cd then desc = cd.description end
    if desc == "" then desc = nil end

    return name, gainLines, desc
end

function RestScreen:_drawHoverPanel(entry)
    local name, gainLines, desc = self:_hoverPanelContent(entry)

    local nameFont = FontManager.getFont(12)
    local gainFont = FontManager.getFont(12)
    local descFont = FontManager.getFont(9)
    local nameLH = math.floor(nameFont:getHeight() * 1.2)
    local gainLH = math.floor(gainFont:getHeight() * 1.45)
    local descLH = math.floor(descFont:getHeight() * 1.35)

    local _, nameLines = nameFont:getWrap(name, PANEL_MAX_INNER)
    local descLines = {}
    if desc then _, descLines = descFont:getWrap(desc, PANEL_MAX_INNER) end

    local innerW = 150
    for _, l in ipairs(nameLines) do innerW = math.max(innerW, nameFont:getWidth(l)) end
    for _, l in ipairs(descLines) do innerW = math.max(innerW, descFont:getWidth(l)) end
    innerW = math.min(innerW, PANEL_MAX_INNER)
    for _, l in ipairs(gainLines) do innerW = math.max(innerW, gainFont:getWidth(l)) end
    innerW = math.min(innerW,
        math.max(PANEL_MAX_INNER, love.graphics.getWidth() * 0.34))

    local panelH = PANEL_PAD
        + #nameLines * nameLH
        + ((#gainLines > 0) and (8 + #gainLines * gainLH) or 0)
        + ((#descLines > 0) and (8 + #descLines * descLH) or 0)
        + PANEL_PAD
    local panelW = innerW + PANEL_PAD * 2

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local panelX = entry.x + entry.w + 14
    if panelX + panelW > sw - 10 then panelX = entry.x - panelW - 14 end
    if panelX < 10 then panelX = 10 end
    local panelY = entry.y
    if panelY + panelH > sh - 10 then panelY = sh - 10 - panelH end
    if panelY < 10 then panelY = 10 end

    Panel9.draw("panel_inner", panelX, panelY, panelW, panelH, {
        fill = { 0.12, 0.095, 0.075, 0.96 },
    })

    local tx = panelX + PANEL_PAD
    local ty = panelY + PANEL_PAD

    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    for _, l in ipairs(nameLines) do
        love.graphics.print(l, tx, ty)
        ty = ty + nameLH
    end

    if #gainLines > 0 then
        ty = ty + 4
        Palette.set(Palette.AGED_GOLD_DARK, 0.8)
        love.graphics.rectangle("fill", tx, ty, innerW, 1)
        ty = ty + 4
        love.graphics.setFont(gainFont)
        for _, l in ipairs(gainLines) do
            Palette.set(self.mode == "remove" and Palette.BLOOD
                or Palette.AGED_GOLD_LIGHT)
            love.graphics.print(l, tx, ty)
            ty = ty + gainLH
        end
    end

    if #descLines > 0 then
        ty = ty + 4
        Palette.set(Palette.AGED_GOLD_DARK, 0.6)
        love.graphics.rectangle("fill", tx, ty, innerW, 1)
        ty = ty + 4
        love.graphics.setFont(descFont)
        Palette.set(Palette.PARCHMENT)
        for _, l in ipairs(descLines) do
            love.graphics.print(l, tx, ty)
            ty = ty + descLH
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RestScreen:update(dt)
    if not self.visible then return end
    for _, b in ipairs(self.buttons) do b:update(dt) end

    if self.forge then
        applyPose(self.forge)
        if self.forge.entry.inst then
            Moveable.updateJuice(self.forge.entry.inst, dt)
        end
    end

    if self.mode ~= "choose" and not self.forge then
        local mx, my = love.mouse.getPosition()
        local hoverIdx = nil
        if not self.busy and not self.resultText then
            for i = #self.cardEntries, 1, -1 do
                local e = self.cardEntries[i]
                if mx >= e.x and mx <= e.x + e.w
                    and my >= e.y - 12 and my <= e.y + e.h then
                    hoverIdx = i
                    break
                end
            end
        end
        for i, e in ipairs(self.cardEntries) do
            if e.inst and e.inst.updateMouse then
                e.inst:updateMouse(mx, my, dt, i == hoverIdx)
            end
        end
        self._hoverIdx = hoverIdx
    end

    if self.resultTimer > 0 then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            local cb = self.onClose
            self:hide()
            if cb then cb() end
        end
    end
end

local function drawChoiceCard(c)
    local hover = c.btn and c.btn.hover
    local lift = hover and -4 or 0
    local y = c.y + lift

    Panel9.draw("panel_inner", c.x, y, c.w, c.h, {
        fill = hover and { 0.20, 0.15, 0.10, 0.94 }
            or { 0.12, 0.095, 0.075, 0.94 },
        tint = hover and { 1.15, 1.1, 0.85, 1 } or nil,
    })

    love.graphics.setColor(1, 1, 1, 1)
    IconLoader.drawFit(c.icon, c.x + c.w / 2, y + 26 + 28, 52)

    local tf = FontManager.getFont(16)
    love.graphics.setFont(tf)
    Palette.set(hover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT, c.muted and 0.5 or 1)
    love.graphics.print(c.title,
        math.floor(c.x + c.w / 2 - tf:getWidth(c.title) / 2), y + 96)

    local TextFit = require("src.ui.TextFit")
    Palette.set(Palette.AGED_GOLD)
    TextFit.print(c.sub, c.x + 12, y + 126,
        { size = 10, maxW = c.w - 24, align = "center" })

    local size, lines, df = 10
    repeat
        df = FontManager.getFont(size)
        lines = select(2, df:getWrap(c.detail or "", c.w - 24))
        size = size - 1
    until #lines <= 2 or size < 8
    love.graphics.setFont(df)
    Palette.set(c.muted and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT)
    local lh = math.floor(df:getHeight() * 1.35)
    local dy = y + 150
    for i = 1, math.min(2, #lines) do
        local line = lines[i]
        love.graphics.print(line, math.floor(c.x + c.w / 2 - df:getWidth(line) / 2), dy)
        dy = dy + lh
    end
end

function RestScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local drawn = SceneBackground.draw("path_rest", sw, sh, 0.35)
    if not drawn then
        love.graphics.setColor(0.07, 0.05, 0.04, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    local titleFont = FontManager.getFont(24)
    love.graphics.setFont(titleFont)
    Palette.set(Palette.INK)
    local title = pickerText(self.mode, "title") or I18n.t("rest.camp_title")
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2), py + 44)

    local subFont = FontManager.getFont(10)
    love.graphics.setFont(subFont)
    Palette.set(Palette.RUST)
    local sub = pickerText(self.mode, "sub") or I18n.t("rest.camp_sub")
    love.graphics.print(sub,
        math.floor(px + pw / 2 - subFont:getWidth(sub) / 2), py + 84)

    for _, c in ipairs(self.choiceCards) do drawChoiceCard(c) end

    if self.mode ~= "choose" then
        local forgeInst = self.forge and self.forge.entry.inst
        for i, e in ipairs(self.cardEntries) do
            if i ~= self._hoverIdx and e.inst and e.inst ~= forgeInst then
                e.inst:draw(e.x, e.y, false, true)
            end
        end
        local hoverEntry = self._hoverIdx and self.cardEntries[self._hoverIdx]
        if hoverEntry and hoverEntry.inst and hoverEntry.inst ~= forgeInst then
            hoverEntry.inst:draw(hoverEntry.x, hoverEntry.y, false, true)
        end

        if #self.cardList == 0 then
            local ef = FontManager.getFont(13)
            love.graphics.setFont(ef)
            Palette.set(Palette.RUST)
            local msg = pickerText(self.mode, "empty")
                or I18n.t("rest.pick_forge_empty")
            love.graphics.print(msg,
                math.floor(px + pw / 2 - ef:getWidth(msg) / 2),
                math.floor(py + ph / 2 - 20))
        end

        if self.pageCount > 1 then
            local pf = FontManager.getFont(11)
            love.graphics.setFont(pf)
            Palette.set(Palette.PARCHMENT_LIGHT)
            local ptxt = self.page .. " / " .. self.pageCount
            love.graphics.print(ptxt,
                math.floor(px + pw / 2 - pf:getWidth(ptxt) / 2), py + ph - 96)
        end
    end

    if self.forge then self:_drawForge(px, py, pw, ph) end

    for _, b in ipairs(self.buttons) do b:draw() end
    if self.mode == "choose" then
        require("src.systems.Tutorial").anchorList("rest_options", self.buttons)
    elseif self.mode == "forge" and not self.forge then
        require("src.systems.Tutorial").anchorList("forge_cards", self.cardEntries)
    end

    if self.mode ~= "choose" and not self.resultText and not self.busy
        and not self.forge then
        local e = self._hoverIdx and self.cardEntries[self._hoverIdx]
        if e then self:_drawHoverPanel(e) end
    end

    if self.resultText and not self.forge then
        local rf = FontManager.getFont(14)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 96)
    end

    HintBar.draw(pickerText(self.mode, "hint") or I18n.t("rest.camp_hint"))

    love.graphics.setColor(1, 1, 1, 1)
end

function RestScreen:mousepressed(x, y, button) return self.visible end

function RestScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.busy then return true end

    local e = self._hoverIdx and self.cardEntries[self._hoverIdx]
    if e and not self.resultText then
        self:_onPickCard(e)
        return true
    end

    for _, b in ipairs(self.buttons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    return false
end

function RestScreen:keypressed(key)
    if not self.visible or self.mode == "choose" or self.busy then return false end
    if key == "left" or key == "pageup" then
        self:_changePage(-1)
        return true
    elseif key == "right" or key == "pagedown" then
        self:_changePage(1)
        return true
    end
    return false
end

return RestScreen
