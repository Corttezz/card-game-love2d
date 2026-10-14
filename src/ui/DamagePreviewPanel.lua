local Debug = require("src.core.Debug")

local DamagePreview = require("src.systems.DamagePreview")
local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local IconLoader = require("src.ui.IconLoader")
local I18n = require("src.i18n.I18n")
local utf8 = require("utf8")

local Panel = {}

local state = {
    live = nil,
    frozen = nil,
    doneT = nil,
    hover = nil,
    badges = {},
}

local HOLD_AFTER = 1.6

function Panel.detailsOn()
    local gs = _G.gameSettings
    return (gs and gs.previewDetails) and true or false
end

function Panel.setDetails(on)
    on = on and true or false
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.previewDetails = on
    local ok, err = pcall(function()
        local SM = require("engine.SaveManager")
        local cur = SM.loadSettings() or {}
        cur.previewDetails = on
        local okS, e = SM.saveSettings(cur)
        if not okS then error(e) end
    end)
    if not ok then Debug.warn("[DamagePreviewPanel] falha ao salvar previewDetails: " .. tostring(err)) end
    return on
end

function Panel.toggleDetails()
    local on = Panel.setDetails(not Panel.detailsOn())
    local okS, Sfx = pcall(require, "src.systems.Sfx")
    if okS and Sfx and Sfx.play then Sfx.play(on and "menuOpen" or "menuClose") end
    return on
end

Panel.hitRect = nil
function Panel.mousepressed(x, y, button)
    local r = Panel.hitRect
    if button ~= 1 or not r then return false end
    if x < r.x or x > r.x + r.w or y < r.y or y > r.y + r.h then return false end
    Panel.toggleDetails()
    return true
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

local function t(key, vars, fb)
    return I18n.t("damage_preview." .. key, vars, fb)
end

local function plain(text, x, y, c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
    love.graphics.print(text, math.floor(x), math.floor(y))
end

local function fmtNum(v)
    return string.format("%g", v)
end

local function comboName(combo)
    return I18n.t("combos." .. tostring(combo.id), nil, combo.label or tostring(combo.id))
end

local function fit(font, text, maxW)
    if font:getWidth(text) <= maxW then return text end
    local chars = {}
    for _, code in utf8.codes(text) do chars[#chars + 1] = utf8.char(code) end
    while #chars > 1 do
        chars[#chars] = nil
        local s = table.concat(chars) .. "."
        if font:getWidth(s) <= maxW then return s end
    end
    return text
end

local function isBusy(game)
    local seq = game.combatAnimationSystem
    return seq and (seq.active or (seq.isBlocking and seq:isBlocking())) or false
end

function Panel.update(game, hoverCard, dt)
    Panel.hitRect = nil
    if not game or not game.enemy or not game.player then
        state.live, state.frozen, state.hover = nil, nil, nil
        return
    end
    if isBusy(game) then
        if not state.frozen and state.live then
            state.frozen = { R = state.live, hp0 = state.live.enemyHealth, enemy = game.enemy }
        end
        state.doneT = nil
        state.hover = nil
        state.badges = {}
        return
    end
    if state.frozen and state.frozen.enemy ~= game.enemy then
        state.frozen, state.doneT = nil, nil
    end
    if state.frozen then
        state.doneT = (state.doneT or 0) + (dt or 0)
        if state.doneT > HOLD_AFTER or #game.selectedCards > 0 then
            state.frozen, state.doneT = nil, nil
        end
    end

    local sel = game.selectedCards or {}
    local myTurn = game.turn == "player" and game.enemy:isAlive()
    state.live = (myTurn and #sel > 0) and DamagePreview.simulate(game, sel) or nil

    state.hover = nil
    if myTurn and hoverCard and not game:isCardSelected(hoverCard)
        and game:canPlayCard(hoverCard) and hoverCard.type ~= "joker" then
        local with = {}
        for _, c in ipairs(sel) do with[#with + 1] = c end
        with[#with + 1] = hoverCard
        state.hover = { card = hoverCard, R = DamagePreview.simulate(game, with),
            added = DamagePreview.combosAddedBy(sel, hoverCard, game) }
    end

    state.badges = {}
    if myTurn and #sel > 0 then
        for _, c in ipairs(game.hand or {}) do
            if c.type ~= "joker" and not game:isCardSelected(c) and game:canPlayCard(c) then
                local added = DamagePreview.combosAddedBy(sel, c, game)
                if #added > 0 then state.badges[c] = added end
            end
        end
    end
end

function Panel.current()
    if state.frozen then return state.frozen.R, true end
    return state.live, false
end

local COL_ATK   = Palette.BLOOD
local COL_DEF   = Palette.STEEL_LIGHT
local COL_COMBO = Palette.AGED_GOLD_LIGHT
local COL_JOKER = Palette.ARCANE_LIGHT
local COL_TEXT  = Palette.PARCHMENT_LIGHT
local COL_DIM   = Palette.PARCHMENT
local COL_LETHAL = Palette.MAGENTA

local function stepChips(steps)
    local chips = {}
    for _, s in ipairs(steps or {}) do
        if s.kind == "base" then
            chips[#chips + 1] = { text = fmtNum(s.value), color = COL_TEXT }
        elseif s.kind == "effects" then
            if (s.hits or 1) > 1 then
                chips[#chips + 1] = { text = "×" .. s.hits, color = COL_TEXT }
            else
                chips[#chips + 1] = { text = "+" .. fmtNum(s.delta), color = COL_TEXT }
            end
        elseif s.kind == "stat" then
            chips[#chips + 1] = { text = (s.delta >= 0 and "+" or "") .. fmtNum(s.delta),
                color = COL_TEXT, icon = s.stat == "strength" and "status_strength"
                    or "status_dexterity" }
        elseif s.kind == "combo" then
            chips[#chips + 1] = { text = (s.op == "mult" and "×" or "+") .. fmtNum(s.value),
                color = COL_COMBO }
        elseif s.kind == "joker" then
            chips[#chips + 1] = { text = (s.op == "mult" and "×" or "+") .. fmtNum(s.value),
                color = COL_JOKER }
        elseif s.kind == "edition" then
            local ed = s.edition
            local flat = DamagePreview.EDITION_FLAT[ed]
            local mult = DamagePreview.EDITION_MULT[ed]
            chips[#chips + 1] = { text = flat and ("+" .. flat) or ("×" .. fmtNum(mult)),
                color = Palette.CYAN }
        elseif s.kind == "seal" then
            chips[#chips + 1] = { text = "×" .. fmtNum(s.value), color = COL_ATK }
        elseif s.kind == "weak" or s.kind == "frail" then
            chips[#chips + 1] = { text = "×" .. fmtNum(s.value), color = Palette.PINK,
                icon = "status_" .. s.kind }
        end
    end
    return chips
end

local function buildLines(R, opts)
    local lines = {}
    for _, combo in ipairs(R.combos or {}) do
        local b = combo.bonus or {}
        local what = ""
        if b.type == "damage_multiplier" or b.type == "defense_multiplier" then
            what = "×" .. fmtNum(b.value)
        elseif b.type == "damage_bonus" or b.type == "defense_bonus"
            or b.type == "card_bonus" then
            what = "+" .. fmtNum(b.value)
        end
        lines[#lines + 1] = { kind = "combo", text = comboName(combo), right = what,
            combo = combo }
    end
    local seenJ = {}
    for _, e in ipairs(R.cards or {}) do
        for _, s in ipairs(e.steps or {}) do
            if s.kind == "joker" and s.joker and not seenJ[s.joker] then
                seenJ[s.joker] = true
                lines[#lines + 1] = { kind = "joker", text = I18n.cardName(s.joker),
                    right = (s.op == "mult" and "×" or "+") .. fmtNum(s.value), joker = s.joker }
            end
        end
    end
    for _, e in ipairs(R.cards or {}) do
        if e.type == "attack" or e.type == "defense" then
            local name = I18n.cardName(e.card)
            if e.skipped then
                lines[#lines + 1] = { kind = "card", text = name, right = "-",
                    dim = true, note = t("skipped", nil, "inimigo ja caiu") }
            else
                local chips = stepChips(e.steps)
                if #chips <= 1 then chips = nil end
                lines[#lines + 1] = { kind = "card", text = name, right = fmtNum(e.value),
                    color = e.type == "attack" and COL_ATK or COL_DEF, chips = chips }
            end
        end
    end
    local orb, magic = 0, 0
    for _, x in ipairs(R.extras or {}) do
        if x.kind == "orb" then orb = orb + x.value
        elseif x.kind == "magic" then magic = magic + x.value end
    end
    if magic > 0 then
        lines[#lines + 1] = { kind = "extra", text = t("magic", nil, "Magia"), right = fmtNum(magic) }
    end
    if orb > 0 then
        lines[#lines + 1] = { kind = "extra", text = t("orbs", nil, "Orbes evocados"), right = fmtNum(orb) }
    end
    if R.blocked and R.blocked > 0 then
        lines[#lines + 1] = { kind = "note", text = t("absorbed", { n = R.blocked },
            R.blocked .. " no Bloqueio do inimigo") }
    end
    local vulnHit = false
    for _, e in ipairs(R.cards or {}) do if e.vuln and e.dealt then vulnHit = true end end
    if vulnHit then
        lines[#lines + 1] = { kind = "note", text = I18n.t("status.vulnerable.name", nil,
            "Vulneravel") .. " ×1.5" }
    end
    if R.impetus then
        lines[#lines + 1] = { kind = "note", text = t("impetus", nil, "Impeto: +1 Forca") }
    end
    if R.uncertain then
        lines[#lines + 1] = { kind = "note", text = t("uncertain", nil, "+ efeito aleatorio") }
    end
    if opts and opts.hover then
        local H = opts.hover
        local added = H.added and H.added[1]
        local addedText = added and (comboName(added.combo) .. " +" .. fmtNum(added.value)) or nil
        local txt = t("with_card", { card = I18n.cardName(H.card), n = H.R.damage },
            "+ " .. I18n.cardName(H.card) .. ": " .. H.R.damage)
        if (H.R.block or 0) > (R.block or 0) then
            txt = txt .. " / +" .. H.R.block
        end
        lines[#lines + 1] = { kind = "hover", text = txt,
            right = addedText }
    end
    return lines
end

function Panel.comboDescription(combo, game)
    local rule = combo.rule or combo
    local ComboSystem = require("src.systems.ComboSystem")
    local k = ComboSystem.boostFor(game, rule.id)
    local step = (rule.step or 0) * k
    return t("combo_desc." .. tostring(rule.id), {
        v = fmtNum(step), max = fmtNum(step * (rule.cap or 1)) }, "")
end

local function rowTooltip(l, x, y, w, h, game)
    if not (l.combo or l.joker) then return end
    local mx, my = love.mouse.getPosition()
    if mx < x or mx > x + w or my < y or my > y + h then return end
    local okF, InputFocus = pcall(require, "src.ui.InputFocus")
    if okF and InputFocus.allows and not InputFocus.allows(InputFocus.SCENE) then return end
    local StatusTooltip = require("src.ui.StatusTooltip")
    if l.combo then
        StatusTooltip.show("combo_" .. tostring(l.combo.id), mx, my,
            { title = comboName(l.combo), body = Panel.comboDescription(l.combo, game) })
    else
        StatusTooltip.show("joker_" .. tostring(l.joker.id), mx, my,
            { title = I18n.cardName(l.joker), body = I18n.cardDesc(l.joker) or "" })
    end
end

local function chipsWidth(font, chips, iconS, gap)
    local w = 0
    for i, c in ipairs(chips) do
        w = w + font:getWidth(c.text) + (c.icon and (iconS + 1) or 0)
        if i > 1 then w = w + gap end
    end
    return w
end

local function drawIcon(name, x, y, size)
    local h = IconLoader.get(name)
    if not h or not h.size then return end
    local s = size / h.size.h
    love.graphics.setColor(1, 1, 1, 1)
    h.draw(x, y, s)
end

function Panel.layout(m)
    local pad = m.pad
    local w = math.min(m.maxW, math.max(m.minW, m.anchor.w))
    local bottom = m.anchor.y - m.gap
    local h = pad * 2 + m.headH + (m.hintH or 0)
    local total = 0
    for _, r in ipairs(m.rows or {}) do total = total + r.h end
    if total > 0 then h = h + math.floor(pad / 2) + total end
    local x = math.floor(m.anchor.x + m.anchor.w - w)
    local y = math.floor(bottom - h)
    local L = { x = x, y = y, w = w, h = h, bands = { rows = {} } }
    local cy = y + pad
    L.bands.head = { y = cy, h = m.headH }
    cy = cy + m.headH
    if total > 0 then cy = cy + math.floor(pad / 2) end
    for i, r in ipairs(m.rows or {}) do
        L.bands.rows[i] = { y = cy, h = r.h, kind = r.kind }
        cy = cy + r.h
    end
    L.bands.hint = { y = cy, h = m.hintH or 0 }
    return L
end

local function rowsAvail(m)
    return (m.anchor.y - m.gap) - (m.topLimit or 0) - m.pad * 2 - m.headH
        - (m.hintH or 0) - math.floor(m.pad / 2)
end

function Panel.validate(L, m)
    if L.x < 0 or L.y < (m.topLimit or 0) then return false, "placa acima do limite / fora da tela" end
    if L.x + L.w > m.anchor.x + m.anchor.w + 0.5 then return false, "placa passa da borda do botao" end
    if L.y + L.h > m.anchor.y - m.gap + 0.5 then return false, "placa invade o botao" end
    if L.w < m.anchor.w - 0.5 then return false, "placa mais estreita que o botao" end
    local prev = L.y
    local seq = { L.bands.head }
    for _, r in ipairs(L.bands.rows) do seq[#seq + 1] = r end
    seq[#seq + 1] = L.bands.hint
    for i, b in ipairs(seq) do
        if b.y < prev - 0.5 then return false, "banda " .. i .. " sobrepoe a anterior" end
        if b.y + b.h > L.y + L.h + 0.5 then return false, "banda " .. i .. " sai da placa" end
        prev = b.y + b.h
    end
    return true
end

local function fitRows(lines, avail, lineH, lh)
    local total = 0
    for _, l in ipairs(lines) do total = total + lineH(l) end
    if total <= avail then return lines end
    local kept, dropped, used = {}, 0, 0
    for _, l in ipairs(lines) do
        local hgt = lineH(l)
        if l.kind == "card" and used + hgt > avail - lh then
            dropped = dropped + 1
        elseif used + hgt <= avail then
            kept[#kept + 1] = l
            used = used + hgt
        end
    end
    if dropped > 0 then
        kept[#kept + 1] = { kind = "note", text = t("more_cards", { n = dropped },
            "+" .. dropped .. " cartas") }
    end
    return kept
end

local function summaryChips(R)
    local chips = {}
    for _, combo in ipairs(R.combos or {}) do
        local b = combo.bonus or {}
        local what = ""
        if b.type == "damage_multiplier" or b.type == "defense_multiplier" then
            what = "×" .. fmtNum(b.value)
        elseif b.value then
            what = "+" .. fmtNum(b.value)
        end
        chips[#chips + 1] = { icon = "combo_" .. tostring(combo.id), text = what,
            color = COL_COMBO, combo = combo, name = comboName(combo) }
    end
    local seenJ = {}
    for _, e in ipairs(R.cards or {}) do
        for _, st in ipairs(e.steps or {}) do
            if st.kind == "joker" and st.joker and not seenJ[st.joker] then
                seenJ[st.joker] = true
                chips[#chips + 1] = { icon = "jester_hat",
                    text = (st.op == "mult" and "×" or "+") .. fmtNum(st.value),
                    color = COL_JOKER, joker = st.joker, name = I18n.cardName(st.joker) }
            end
        end
    end
    return chips
end

local function chipTooltip(c, x, y, w, h, game)
    rowTooltip({ combo = c.combo, joker = c.joker }, x, y, w, h, game)
end

function Panel.draw(game, anchor, topLimit)
    if not game or not anchor then return end
    local R, frozen = Panel.current()
    if not R then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local expanded = Panel.detailsOn()

    local bigFont = FontManager.getResponsiveFont(0.034, 36)
    local font = FontManager.getResponsiveFont(0.0165, 18)
    local small = FontManager.getResponsiveFont(0.0135, 15)
    local tiny = FontManager.getResponsiveFont(0.0115, 12)
    local pad = math.max(6, math.floor(sh * 0.010))
    local lh = font:getHeight() + math.max(3, math.floor(sh * 0.004))
    local slh = small:getHeight() + math.max(2, math.floor(sh * 0.003))
    local iconS = small:getHeight()
    local chipS = math.floor(small:getHeight() * 1.6)
    local bigH = bigFont:getHeight()
    local headH = bigH + math.floor(pad / 2)
    local hintH = tiny:getHeight() + 3

    local maxW = math.floor(math.min(sw * (expanded and 0.36 or 0.30), anchor.x + anchor.w - 8))
    local minW = expanded and math.floor(sw * 0.24) or anchor.w

    local dmgText
    if frozen then
        local dealt = math.max(0, (state.frozen.hp0 or 0) - (game.enemy.health or 0))
        dmgText = dealt .. "/" .. R.damage
    else
        dmgText = tostring(R.damage)
    end
    local showDmg = R.damage > 0 or (R.block or 0) == 0
    local headW = 0
    if showDmg then headW = headW + bigH + 4 + bigFont:getWidth(dmgText) + pad end
    if (R.block or 0) > 0 then headW = headW + bigH + 4 + bigFont:getWidth("+" .. R.block) + pad end
    local lethalText = t("lethal", nil, "LETAL")
    local lethalRow = false
    if R.lethal then
        local need = headW + font:getWidth(lethalText)
        if need + pad * 2 <= maxW then
            minW = math.max(minW, math.min(maxW, need + pad * 2))
        else
            lethalRow = true
        end
    else
        minW = math.max(minW, math.min(maxW, headW + pad))
    end

    local lines
    if frozen then
        lines = {}
        local chips = summaryChips(R)
        if #chips > 0 then lines[1] = { kind = "chips", chips = chips } end
    elseif expanded then
        lines = buildLines(R, { hover = state.hover })
    else
        lines = {}
        local chips = summaryChips(R)
        if #chips > 0 then lines[#lines + 1] = { kind = "chips", chips = chips } end
        if R.uncertain then
            lines[#lines + 1] = { kind = "note", text = t("uncertain", nil, "+ efeito aleatorio") }
        end
        if state.hover then
            local hl = buildLines({ cards = {}, combos = {} }, { hover = state.hover })
            if hl[1] then lines[#lines + 1] = hl[1] end
        end
    end
    if lethalRow then table.insert(lines, 1, { kind = "lethal", text = lethalText }) end

    local function lineH(l)
        if l.kind == "card" then
            local hgt = lh
            if l.chips and #l.chips > 0 then hgt = hgt + slh end
            if l.note then hgt = hgt + slh end
            return hgt
        end
        if l.kind == "chips" then return chipS + 2 end
        return (l.kind == "note" or l.kind == "hover") and slh or lh
    end

    local m = { anchor = anchor, topLimit = topLimit or 0, gap = math.max(6, math.floor(sh * 0.01)),
        pad = pad, minW = minW, maxW = maxW, headH = headH, hintH = hintH, rows = {} }
    lines = fitRows(lines, rowsAvail(m), lineH, lh)
    for i, l in ipairs(lines) do m.rows[i] = { kind = l.kind, h = lineH(l) } end
    local L = Panel.layout(m)
    local x, y, w, h = L.x, L.y, L.w, L.h
    local innerW = w - pad * 2

    local mx, my = love.mouse.getPosition()
    local over = mx >= x and mx <= x + w and my >= y and my <= y + h

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 3, y + 4, w, h, 5, 5)
    setColor(Palette.INK, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    setColor(Palette.PARCHMENT_DARK, 0.55)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 4, 4)
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)
    setColor(R.lethal and COL_LETHAL or (over and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK), 0.9)
    love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6, 3, 3)

    local cx = x + pad
    local cy = L.bands.head.y
    love.graphics.setFont(bigFont)
    if showDmg then
        drawIcon("intent_attack", cx, cy, bigH)
        cx = cx + bigH + 4
        FontManager.drawWithOutline(dmgText, cx, cy, { COL_ATK[1] * 1.6, COL_ATK[2] * 1.4,
            COL_ATK[3] * 1.4, 1 }, 0.95)
        cx = cx + bigFont:getWidth(dmgText) + pad
    end
    if (R.block or 0) > 0 then
        drawIcon("armor_shield", cx, cy, bigH)
        cx = cx + bigH + 4
        local bt = "+" .. R.block
        FontManager.drawWithOutline(bt, cx, cy, { COL_DEF[1] * 1.3, COL_DEF[2] * 1.3,
            COL_DEF[3] * 1.3, 1 }, 0.95)
    end
    if R.lethal and not lethalRow then
        love.graphics.setFont(font)
        FontManager.drawWithOutline(lethalText, x + w - pad - font:getWidth(lethalText),
            cy + math.floor((bigH - font:getHeight()) / 2), { 1, 0.45, 0.55, 1 }, 0.95)
    end

    if #lines > 0 then
        local sepY = L.bands.rows[1].y - math.floor(pad / 4) - 1
        setColor(Palette.AGED_GOLD_DARK, 0.8)
        love.graphics.line(x + pad, sepY, x + w - pad, sepY)
    end
    for i, l in ipairs(lines) do
        local ly = L.bands.rows[i].y
        if l.kind == "chips" then
            love.graphics.setFont(small)
            local gap = 8
            local function labelOf(c, mode)
                if mode == 2 then return c.name .. " " .. c.text end
                if mode == 1 then return c.text end
                return ""
            end
            local function width(mode)
                local tw = 0
                for k, c in ipairs(l.chips) do
                    local lab = labelOf(c, mode)
                    tw = tw + chipS + (lab ~= "" and (3 + small:getWidth(lab)) or 0)
                    if k > 1 then tw = tw + gap end
                end
                return tw
            end
            local mode = 2
            while mode > 0 and width(mode) > innerW do mode = mode - 1 end
            local chx = x + pad
            local ty = ly + math.floor((chipS - small:getHeight()) / 2)
            for _, c in ipairs(l.chips) do
                local lab = labelOf(c, mode)
                local cw = chipS + (lab ~= "" and (3 + small:getWidth(lab)) or 0)
                drawIcon(c.icon, chx, ly, chipS)
                if lab ~= "" then plain(lab, chx + chipS + 3, ty, c.color) end
                chipTooltip(c, chx, ly, cw, chipS, game)
                chx = chx + cw + gap
            end
        elseif l.kind == "combo" or l.kind == "joker" then
            love.graphics.setFont(font)
            local col = l.kind == "combo" and COL_COMBO or COL_JOKER
            local right = l.right or ""
            local rw = font:getWidth(right)
            local name = fit(font, l.text, innerW - rw - 6)
            FontManager.drawWithOutline(name, x + pad, ly, col, 0.8)
            if right ~= "" then
                FontManager.drawWithOutline(right, x + w - pad - rw, ly, col, 0.8)
            end
            rowTooltip(l, x, ly, w, lh, game)
        elseif l.kind == "card" or l.kind == "extra" then
            love.graphics.setFont(font)
            local right = l.right or ""
            local rw = font:getWidth(right)
            local name = fit(font, l.text, innerW - rw - 8)
            local a = l.dim and 0.5 or 1
            FontManager.drawWithOutline(name, x + pad, ly, { COL_TEXT[1], COL_TEXT[2], COL_TEXT[3], a }, 0.8)
            local rc = l.color or COL_TEXT
            FontManager.drawWithOutline(right, x + w - pad - rw, ly,
                { math.min(1, rc[1] * 1.6), math.min(1, rc[2] * 1.4), math.min(1, rc[3] * 1.4), a }, 0.9)
            local cy2 = ly + lh
            if l.chips and #l.chips > 0 then
                love.graphics.setFont(small)
                local gap = 5
                local chips = l.chips
                if chipsWidth(small, chips, iconS, gap) > innerW then
                    local cut = {}
                    for k = 1, #chips do cut[k] = chips[k] end
                    while #cut > 2 and chipsWidth(small, cut, iconS, gap) > innerW do
                        table.remove(cut, #cut - 1)
                    end
                    chips = cut
                end
                local chx = x + pad + 6
                for _, c in ipairs(chips) do
                    if c.icon then
                        drawIcon(c.icon, chx, cy2, iconS)
                        chx = chx + iconS + 1
                    end
                    plain(c.text, chx, cy2, c.color)
                    chx = chx + small:getWidth(c.text) + gap
                end
                cy2 = cy2 + slh
            end
            if l.note then
                love.graphics.setFont(small)
                plain(fit(small, l.note, innerW - 6), x + pad + 6, cy2, COL_DIM)
            end
        elseif l.kind == "note" then
            love.graphics.setFont(small)
            plain(fit(small, l.text, innerW), x + pad, ly, COL_DIM)
        elseif l.kind == "hover" then
            love.graphics.setFont(small)
            local txt = fit(small, l.text, innerW)
            plain(txt, x + pad, ly, COL_TEXT)
            local right = l.right or ""
            local room = innerW - small:getWidth(txt) - 8
            if right ~= "" and room > small:getWidth("ABC") then
                local r2 = fit(small, right, room)
                plain(r2, x + w - pad - small:getWidth(r2), ly, COL_COMBO)
            end
        elseif l.kind == "lethal" then
            love.graphics.setFont(font)
            FontManager.drawWithOutline(l.text, x + pad, ly, { 1, 0.45, 0.55, 1 }, 0.9)
        end
    end

    do
        local NavCursor = require("src.ui.NavCursor")
        local glyph = NavCursor.device() == "pad" and NavCursor.PAD_LABEL.confirm or "V"
        local label = (expanded and t("details_hide", nil, "ocultar") or t("details_show", nil, "ver detalhes"))
            .. " [" .. glyph .. "]"
        love.graphics.setFont(tiny)
        label = fit(tiny, label, innerW)
        plain(label, x + w - pad - tiny:getWidth(label), L.bands.hint.y + 1,
            over and Palette.AGED_GOLD_LIGHT or COL_DIM, over and 1 or 0.8)
        NavCursor.target(Panel, x, y, w, h, { key = "dmg_preview_plate", group = "action" })
    end
    love.graphics.setColor(1, 1, 1, 1)

    Panel.lastRect = { x = x, y = y, w = w, h = h,
        firstRowY = L.bands.rows[1] and L.bands.rows[1].y or (y + h),
        expanded = expanded, layout = L, metrics = m }
    local rx1, ry1 = love.graphics.transformPoint(x, y)
    local rx2, ry2 = love.graphics.transformPoint(x + w, y + h)
    Panel.hitRect = { x = math.min(rx1, rx2), y = math.min(ry1, ry2),
        w = math.abs(rx2 - rx1), h = math.abs(ry2 - ry1) }
    require("src.systems.Tutorial").anchor("preview", x, y, w, h)
    return Panel.lastRect
end

function Panel.drawEnemyGhost(game, rect)
    local R, frozen = Panel.current()
    if not R or frozen or not rect or not game.enemy then return end
    if (R.damage or 0) <= 0 then return end
    local e = game.enemy
    local maxHp = math.max(1, e.maxHealth or 1)
    local hp = e.health or 0
    local after = math.max(0, hp - R.damage)
    local x1 = rect.x + rect.w * (after / maxHp)
    local x2 = rect.x + rect.w * (hp / maxHp)
    local pulse = 0.55 + 0.35 * math.sin(love.timer.getTime() * 6)
    if _G.gameSettings and _G.gameSettings.reducedMotion then pulse = 0.8 end
    love.graphics.setColor(1, 0.92, 0.75, pulse)
    love.graphics.rectangle("fill", x1, rect.y, math.max(1, x2 - x1), rect.h)
    local font = FontManager.getResponsiveFont(0.022, 16)
    love.graphics.setFont(font)
    local txt = "-" .. R.damage
    local col = R.lethal and { 1, 0.45, 0.55, 1 } or { 1, 0.85, 0.7, 1 }
    FontManager.drawWithOutline(txt, math.floor(rect.x + rect.w + 6),
        math.floor(rect.y + rect.h / 2 - font:getHeight() / 2), col, 0.95)
    love.graphics.setColor(1, 1, 1, 1)
end

function Panel.drawHandBadges(game)
    if not next(state.badges) then return end
    local font = FontManager.getResponsiveFont(0.014, 11)
    love.graphics.setFont(font)
    local hand = game.hand or {}
    for i, c in ipairs(hand) do
        local added = state.badges[c]
        local label
        if added then
            local parts = {}
            for _, a in ipairs(added) do
                parts[#parts + 1] = comboName(a.combo) .. " +" .. fmtNum(a.value)
            end
            label = table.concat(parts, " ")
        end
        if added and c.renderX then
            local cw = (c.image and c.image.getWidth and c.image:getWidth() or 96)
                * (c.scale or c.baseScale or 1.333)
            local room = cw - 4
            local nxt = hand[i + 1]
            if nxt and nxt.renderX and nxt.renderX > c.renderX then
                room = math.min(room, nxt.renderX - c.renderX - 6)
            end
            if font:getWidth(label) > room then
                local sum = 0
                for _, a in ipairs(added) do sum = sum + (a.value or 0) end
                label = "+" .. fmtNum(sum)
            end
            local tw = font:getWidth(label)
            local bx = math.floor(c.renderX + cw / 2 - tw / 2 - 4)
            local by = math.floor(c.renderY - font:getHeight() - 10)
            setColor(Palette.INK, 0.9)
            love.graphics.rectangle("fill", bx, by, tw + 8, font:getHeight() + 4, 3, 3)
            setColor(Palette.AGED_GOLD_LIGHT, 0.95)
            love.graphics.rectangle("line", bx, by, tw + 8, font:getHeight() + 4, 3, 3)
            FontManager.drawWithOutline(label, bx + 4, by + 2, COL_COMBO, 0.8)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Panel
