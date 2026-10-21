local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local TextFit = require("src.ui.TextFit")
local Ink = require("src.ui.RunJournalInk")
local Layout = require("src.ui.BestiaryLayout")
local Sprites = require("src.ui.BestiarySprites")
local Bestiary = require("src.systems.Bestiary")

local BestiaryCard = {}

BestiaryCard.TIER_COLOR = {
    common = Palette.PARCHMENT_LIGHT,
    elite = Palette.STEEL_LIGHT,
    miniboss = Palette.AGED_GOLD_LIGHT,
    boss = Palette.lighten and Palette.lighten(Palette.BLOOD, 0.35) or Palette.BLOOD,
}
BestiaryCard.TIER_INK = {
    common = Palette.PARCHMENT_DARK,
    elite = Palette.STEEL,
    miniboss = Palette.AGED_GOLD_DARK,
    boss = Palette.BLOOD,
}

function BestiaryCard.name(id)
    return I18n.t(Bestiary.nameKey(id), nil, id)
end

function BestiaryCard.tierLabel(tier)
    return I18n.t("bestiary.ui.tier." .. tostring(tier), nil, tier)
end

function BestiaryCard.biomeId(act)
    local ok, biomes = pcall(require, "src.data.biomes")
    local bm = ok and type(biomes) == "table" and biomes[act] or nil
    return bm and bm.id or nil
end

function BestiaryCard.biomeName(act)
    local id = BestiaryCard.biomeId(act)
    return id and I18n.t("bestiary.ui.biome." .. id, nil, id) or ""
end

function BestiaryCard.actLabel(act)
    local biome = BestiaryCard.biomeName(act)
    return I18n.t("bestiary.ui.act_header", { n = act, biome = biome },
        I18n.t("acts.fallback", { n = act }) .. " · " .. biome)
end

local function optional(key)
    local v = I18n.t(key, nil, "")
    if v == key then return "" end
    return v
end

function BestiaryCard.moveIds(id)
    local kit = Bestiary.kit(id)
    local out, seen = {}, {}
    if not kit then return out end
    local function add(list)
        for _, m in ipairs(list or {}) do
            if m.id and not seen[m.id] then
                seen[m.id] = true
                out[#out + 1] = m.id
            end
        end
    end
    add(kit.moves)
    for _, ph in ipairs(kit.phases or {}) do add(ph.moves) end
    return out
end

function BestiaryCard.texts(entry)
    local id = entry.id
    local defeated = Bestiary.isDefeated(id)
    local moves = BestiaryCard.moveIds(id)
    local t = {
        name = BestiaryCard.name(id),
        epithet = optional("bestiary.creature." .. id .. ".epithet"),
        lore = optional("bestiary.creature." .. id .. ".lore"),
        signature = optional("bestiary.creature." .. id .. ".signature"),
        moveCount = #moves,
        moves = {},
        defeated = defeated,
        statLabels = {
            TextCase.upper(I18n.t("bestiary.ui.stat_seen")),
            TextCase.upper(I18n.t("bestiary.ui.stat_defeated")),
            TextCase.upper(I18n.t("bestiary.ui.stat_killed_you")),
        },
    }
    for i, mid in ipairs(moves) do
        t.moves[i] = defeated and I18n.t("enemy_kit.moves." .. mid .. ".name", nil, mid)
            or I18n.t("bestiary.ui.unknown", nil, "???")
    end
    if not defeated then t.movesHint = I18n.t("bestiary.ui.moves_hidden") end
    return t
end

local function rgba(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1))
end

function BestiaryCard.drawSprite(id, cx, groundY, s, t, alpha, silhouette)
    local img, set = Sprites.frameAt(id, t)
    if not img then return false end
    local box = set.box or { x = 0, y = 0, w = set.fw, h = set.fh }
    local bx = box.x + box.w / 2
    local by = box.y + box.h
    local dx = math.floor(cx - bx * s + 0.5)
    local dy = math.floor(groundY - by * s + 0.5)
    if silhouette then
        local c = Palette.lerp and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.42) or Palette.INK
        rgba(c, alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha or 1)
    end
    love.graphics.draw(img, dx, dy, 0, s, s)
    return true
end

function BestiaryCard.drawGround(cx, groundY, w, alpha)
    local hw = math.floor(w / 2)
    for row = 0, 3 do
        local rw = math.floor(hw * (1 - row * 0.22))
        rgba(Palette.INK, (alpha or 1) * (0.55 - row * 0.1))
        love.graphics.rectangle("fill", math.floor(cx - rw), groundY - 2 + row, rw * 2, 1)
    end
end

local function plate(r, fill, a, line)
    rgba(fill, a)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    rgba(line or Palette.PARCHMENT_DARK, 1)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
end

local function rivets(r, c)
    rgba(c)
    for _, p in ipairs({ { r.x + 3, r.y + 3 }, { r.x + r.w - 6, r.y + 3 },
        { r.x + 3, r.y + r.h - 6 }, { r.x + r.w - 6, r.y + r.h - 6 } }) do
        love.graphics.rectangle("fill", p[1], p[2], 3, 3)
    end
end

local function drawPortrait(C, entry, t)
    local r = C.portrait
    rgba(Palette.INK, 1)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    local bands = 6
    for i = 0, bands - 1 do
        local k = i / (bands - 1)
        local c = Palette.lerp(Palette.ARCANE_INK or Palette.INK, Palette.PARCHMENT_DARK, 0.05 + k * 0.22)
        rgba(c, 1)
        local y0 = r.y + math.floor(r.h * 0.55 * i / bands)
        love.graphics.rectangle("fill", r.x + 2, y0 + 2, r.w - 4, math.ceil(r.h * 0.55 / bands) + 1)
    end
    local groundY = r.y + math.floor(r.h * 0.82)
    rgba(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.3), 1)
    love.graphics.rectangle("fill", r.x + 2, groundY, r.w - 4, r.y + r.h - groundY - 2)
    for x = r.x + 2, r.x + r.w - 4, 2 do
        if (x * 7) % 5 < 2 then
            rgba(Palette.PARCHMENT_DARK, 0.5)
            love.graphics.rectangle("fill", x, groundY + ((x * 3) % 7), 1, 1)
        end
    end
    local tc = BestiaryCard.TIER_INK[entry.tier] or Palette.AGED_GOLD_DARK
    rgba(tc, 0.18)
    love.graphics.rectangle("fill", r.x + 2, groundY - 1, r.w - 4, 1)
    local s = C.spriteS
    BestiaryCard.drawGround(r.x + r.w / 2, groundY + 3, math.floor(Layout.REF_W * s * 0.75), 1)
    Layout.scissor(r.x + 2, r.y + 2, r.w - 4, r.h - 4)
    BestiaryCard.drawSprite(entry.id, r.x + r.w / 2, groundY + 3, s, t, 1, false)
    love.graphics.setScissor()
    rgba(Palette.AGED_GOLD_DARK, 1)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    rgba(Palette.AGED_GOLD, 1)
    love.graphics.rectangle("line", r.x + 3.5, r.y + 3.5, r.w - 7, r.h - 7)
    rivets(r, Palette.AGED_GOLD_LIGHT)
end

local function drawStats(C, entry)
    local st = Bestiary.stats(entry.id)
    local vals = { st.seen, st.defeated, st.killedYou }
    local keys = { "bestiary.ui.stat_seen", "bestiary.ui.stat_defeated", "bestiary.ui.stat_killed_you" }
    local cols = { Palette.INK, Palette.MOSS, Palette.BLOOD }
    for i, r in ipairs(C.statCells) do
        rgba(Palette.PARCHMENT_DARK, 0.18)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        rgba(Palette.PARCHMENT_DARK, 0.9)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
        rgba(cols[i])
        TextFit.print(tostring(vals[i] or 0), r.x, r.y + 8,
            { size = Layout.FONT.stat, maxW = r.w, align = "center", minSize = 8 })
        rgba(Palette.PARCHMENT_DARK)
        Layout.printWrapped(TextCase.upper(I18n.t(keys[i])), r.x + 4,
            r.y + 8 + FontManager.getFont(Layout.FONT.stat):getHeight() + 8, r.w - 8,
            Layout.FONT.statLabel, "center")
    end
end

local function heading(r, text, color)
    rgba(color or Palette.RUST)
    TextFit.print(TextCase.upper(text), r.x, r.y, { size = Layout.FONT.head, maxW = r.w, minSize = 8 })
    local f = FontManager.getFont(Layout.FONT.head)
    rgba(Palette.PARCHMENT_DARK, 0.5)
    love.graphics.rectangle("fill", r.x, r.y + f:getHeight() + 3, r.w, 1)
end

local function navButton(r, label, hot, enabled)
    rgba(hot and enabled and Palette.AGED_GOLD or Palette.PARCHMENT_DARK, enabled and 0.9 or 0.35)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    rgba(Palette.INK, enabled and 1 or 0.4)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    local f = FontManager.getFont(Layout.FONT.nav)
    love.graphics.setFont(f)
    rgba(hot and enabled and Palette.INK or Palette.PARCHMENT_LIGHT, enabled and 1 or 0.5)
    love.graphics.print(label, math.floor(r.x + (r.w - f:getWidth(label)) / 2),
        math.floor(r.y + (r.h - f:getHeight()) / 2) + 1)
end

local function hit(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
BestiaryCard.hit = hit

function BestiaryCard.layoutFor(entry, sw, sh, k)
    local texts = BestiaryCard.texts(entry)
    return Layout.card(sw, sh, k, texts), texts
end

function BestiaryCard.draw(C, texts, entry, opts)
    opts = opts or {}
    local anim = opts.anim or 1
    local sw, sh = love.graphics.getDimensions()
    rgba(Palette.INK, 0.84 * anim)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    local p = C.page
    local lift = math.floor((1 - anim) * 18)
    love.graphics.push()
    love.graphics.translate(0, lift)
    Ink.drawSheet(Ink.paper(p.w, p.h, 7), p.x, p.y)
    local mx, my = opts.mx or -1, (opts.my or -1) - lift

    rgba(Palette.INK)
    love.graphics.setFont(FontManager.getFont(C.fonts.name))
    love.graphics.print(texts.name, C.name.x, C.name.y)
    if texts.epithet ~= "" then
        rgba(Palette.RUST)
        Layout.printWrapped(texts.epithet, C.epithet.x, C.epithet.y, C.epithet.w, C.fonts.epithet)
    end
    local meta = BestiaryCard.actLabel(entry.act) .. "  ·  " .. BestiaryCard.tierLabel(entry.tier)
    rgba(BestiaryCard.TIER_INK[entry.tier] or Palette.PARCHMENT_DARK)
    TextFit.print(TextCase.upper(meta), C.meta.x, C.meta.y, { size = Layout.FONT.meta, maxW = C.meta.w })
    rgba(Palette.AGED_GOLD_DARK, 0.9)
    love.graphics.rectangle("fill", C.rule.x, C.rule.y, C.rule.w, 1)
    rgba(Palette.AGED_GOLD, 0.6)
    love.graphics.rectangle("fill", C.rule.x, C.rule.y + 2, math.floor(C.rule.w * 0.4), 1)

    drawPortrait(C, entry, opts.t or 0)
    drawStats(C, entry)

    heading(C.loreHead, I18n.t("bestiary.ui.lore"))
    rgba(Palette.INK)
    Layout.printWrapped(texts.lore, C.lore.x, C.lore.y, C.lore.w, C.fonts.lore)

    if C.sigBox then
        local r = C.sigBox
        rgba(Palette.BLOOD, 0.10)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        rgba(Palette.BLOOD, 0.75)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
        rgba(Palette.BLOOD, 1)
        love.graphics.rectangle("fill", r.x, r.y, 3, r.h)
        heading(C.sigHead, I18n.t("bestiary.ui.signature"), Palette.BLOOD)
        rgba(Palette.INK)
        Layout.printWrapped(texts.signature, C.signature.x, C.signature.y, C.signature.w, C.fonts.signature)
    end

    heading(C.movesHead, I18n.t("bestiary.ui.moves"))
    local bf = FontManager.getFont(C.fonts.body)
    for i, r in ipairs(C.moveCells) do
        local label = texts.moves[i] or ""
        local cy = r.y + math.floor((r.h - bf:getHeight()) / 2)
        rgba(texts.defeated and Palette.RUST or Palette.PARCHMENT_DARK)
        love.graphics.rectangle("fill", r.x + 1, cy + 1, 4, 4)
        love.graphics.rectangle("fill", r.x + 2, cy, 2, 6)
        rgba(texts.defeated and Palette.INK or Palette.PARCHMENT_DARK)
        TextFit.print(label, r.x + 12, cy, { size = C.fonts.body, maxW = r.w - 12, minSize = 8 })
    end
    if C.movesHint then
        rgba(Palette.PARCHMENT_DARK)
        Layout.printWrapped(texts.movesHint, C.movesHint.x, C.movesHint.y, C.movesHint.w, C.fonts.body)
    end

    local canNav = opts.canNav ~= false
    navButton(C.prev, "<", hit(C.prev, mx, my), canNav)
    navButton(C.next, ">", hit(C.next, mx, my), canNav)
    navButton(C.close, "X", hit(C.close, mx, my), true)
    if opts.counter then
        rgba(Palette.PARCHMENT_DARK)
        TextFit.print(opts.counter, C.counter.x, C.counter.y + 10,
            { size = Layout.FONT.meta, maxW = C.counter.w, align = "center" })
    end
    local NavCursor = require("src.ui.NavCursor")
    NavCursor.target("bst:prev", C.prev.x, C.prev.y + lift, C.prev.w, C.prev.h)
    NavCursor.target("bst:next", C.next.x, C.next.y + lift, C.next.w, C.next.h)
    NavCursor.target("bst:close", C.close.x, C.close.y + lift, C.close.w, C.close.h)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return BestiaryCard
