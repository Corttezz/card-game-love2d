local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local TextFit = require("src.ui.TextFit")
local Ink = require("src.ui.RunJournalInk")
local Layout = require("src.ui.BestiaryLayout")
local Sprites = require("src.ui.BestiarySprites")
local Bestiary = require("src.systems.Bestiary")
local BInk = require("src.ui.BestiaryInk")

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
        tier = entry.tier,
        statLabels = {
            I18n.t("bestiary.ui.stat_seen"),
            I18n.t("bestiary.ui.stat_defeated"),
            I18n.t("bestiary.ui.stat_killed_you"),
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

function BestiaryCard.drawSprite(id, cx, groundY, s, t, alpha)
    local img, set, idx = Sprites.frameAt(id, t)
    if not img then return nil end
    local box = set.box or { x = 0, y = 0, w = set.fw, h = set.fh }
    local bx = box.x + box.w / 2
    local by = box.y + box.h
    local dx = math.floor(cx - bx * s + 0.5)
    local dy = math.floor(groundY - by * s + 0.5)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, dx, dy, 0, s, s)
    return { x = dx, y = dy, w = set.fw * s, h = set.fh * s, iw = set.fw, ih = set.fh, scale = s,
        groundY = groundY, cx = cx, clip = "idle", frame = idx or 1 }
end

local function hit(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
BestiaryCard.hit = hit

function BestiaryCard.layoutFor(entry, sw, sh, k)
    local texts = BestiaryCard.texts(entry)
    return Layout.card(sw, sh, k, texts), texts
end

local function heading(r, text, color, seed)
    rgba(color or Palette.RUST)
    local w = TextFit.print(TextCase.upper(text), r.x, r.y, { size = Layout.FONT.head, maxW = r.w, minSize = 8 })
    local f = FontManager.getFont(Layout.FONT.head)
    local y = r.y + f:getHeight() + 3
    Ink.begin()
    Ink.line(r.x, y, r.x + w + 18, y + 1, color or Palette.RUST, 0.7, seed or 1, { wobble = 0.4 })
    Ink.px(r.x + w + 22, y, color or Palette.RUST, 0.7, 2, 2)
    Ink.flush()
end

local function navButton(r, glyph, hot, enabled, seed)
    local a = enabled and 1 or 0.35
    rgba(hot and enabled and Palette.PARCHMENT_LIGHT or Ink.PAPER_DARK, 0.9 * a)
    love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4)
    Ink.begin()
    BInk.frame(r.x + 1, r.y + 1, r.w - 2, r.h - 2, seed, BInk.INK, (hot and 1 or 0.75) * a, { wobble = 0.4 })
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    if glyph == "x" then
        Ink.line(cx - 5, cy - 5, cx + 5, cy + 5, BInk.INK, a, seed + 3, { wobble = 0.2, weight = 2 })
        Ink.line(cx + 5, cy - 5, cx - 5, cy + 5, BInk.INK, a, seed + 4, { wobble = 0.2, weight = 2 })
    else
        local d = glyph == "<" and -1 or 1
        Ink.line(cx - 3 * d, cy - 6, cx + 3 * d, cy, BInk.INK, a, seed + 5, { wobble = 0.2, weight = 2 })
        Ink.line(cx + 3 * d, cy, cx - 3 * d, cy + 6, BInk.INK, a, seed + 6, { wobble = 0.2, weight = 2 })
    end
    Ink.flush()
end

local function drawFigure(C, entry, t)
    local r = C.figure
    local biome = BestiaryCard.biomeId(entry.act)
    local groundY = r.y + math.floor(r.h * 0.84)
    if biome then
        BInk.engrave("assets/sprites/world/" .. biome .. "_mountains.png", r.x + 6, r.y + 8,
            r.w - 12, math.floor((groundY - r.y) * 0.7), 0.45, BInk.SEPIA, 1.3)
    end
    Ink.begin()
    BInk.frame(r.x, r.y, r.w, r.h, entry.act * 41, BInk.SEPIA, 0.55, { wobble = 0.7, overshoot = 5 })
    BInk.hatchGround(r.x + 16, groundY + 3, r.w - 32, entry.act * 17, BInk.SEPIA, 0.7)
    Ink.flush()
    local s = C.spriteS
    local cx = r.x + r.w / 2
    BInk.shadow(cx, groundY + 2, math.floor(Layout.REF_W * s * 0.7), 1.2)
    Layout.scissor(r.x + 1, r.y + 1, r.w - 2, r.h - 2)
    local okA, BossAura = pcall(require, "src.ui.BossAura")
    local aura = entry.tier == "boss" and okA and BossAura.has(entry.id) and not BInk.reduced()
    local img, set = Sprites.frameAt(entry.id, t)
    local rect
    if img and aura then
        local box = set.box or { x = 0, y = 0, w = set.fw, h = set.fh }
        rect = { x = math.floor(cx - (box.x + box.w / 2) * s + 0.5), y = math.floor(groundY + 2 - (box.y + box.h) * s + 0.5),
            w = set.fw * s, h = set.fh * s, iw = set.fw, ih = set.fh, scale = s, groundY = groundY + 2,
            cx = cx, clip = "idle", frame = 1 }
        pcall(BossAura.drawBack, entry.id, rect)
    end
    BestiaryCard.drawSprite(entry.id, cx, groundY + 2, s, t, 1)
    if rect then pcall(BossAura.drawFront, entry.id, rect) end
    love.graphics.setScissor()
end

local function drawLedger(C, entry, texts)
    local st = Bestiary.stats(entry.id)
    local vals = { st.seen, st.defeated, st.killedYou }
    local cols = { BInk.INK, Palette.MOSS, BInk.RED }
    local r = C.ledger
    local f = FontManager.getFont(8)
    local nf = FontManager.getFont(10)
    Ink.begin()
    for i = 1, 3 do
        local y = r.y + (i - 1) * r.rowH
        Ink.line(r.x, y + r.rowH - 3, r.x + r.w, y + r.rowH - 2, BInk.SEPIA, 0.35, entry.act * 3 + i,
            { wobble = 0.3, dash = 3, gap = 2 })
    end
    Ink.flush()
    for i = 1, 3 do
        local y = r.y + (i - 1) * r.rowH
        love.graphics.setFont(f)
        rgba(BInk.SEPIA)
        love.graphics.print(texts.statLabels[i], r.x, y + 3)
        local num = tostring(vals[i] or 0)
        love.graphics.setFont(nf)
        rgba(cols[i])
        love.graphics.print(num, r.x + r.w - nf:getWidth(num), y + 1)
        local tx = r.x + math.floor(r.w * 0.52)
        Ink.begin()
        BInk.tally(tx, y + 1, math.min(vals[i] or 0, 15), cols[i], 1, i * 19, 11)
        Ink.flush()
    end
end

local function drawHabitat(C, entry, texts)
    local r = C.habitat
    if not r then return end
    local biome = BestiaryCard.biomeId(entry.act)
    local cap = I18n.t("bestiary.ui.habitat", { biome = BestiaryCard.biomeName(entry.act) })
    local f = FontManager.getFont(8)
    local capY = r.y + r.h - f:getHeight()
    local sketchH = math.min(110, r.h - f:getHeight() - 8)
    if biome and sketchH > 24 then
        local land = entry.tier == "boss" and "_castle.png"
            or (entry.tier == "common" and "_landmark_battle.png" or "_landmark_elite.png")
        local sw = math.min(r.w * 0.45, sketchH * 1.6)
        local sx = r.x + r.w - sw - 6
        local sy = capY - 6 - sketchH
        local path
        for _, cand in ipairs({ biome .. land, land:sub(2), biome .. "_castle.png" }) do
            if not path and love.filesystem.getInfo("assets/sprites/world/" .. cand) then
                path = "assets/sprites/world/" .. cand
            end
        end
        path = path or ("assets/sprites/world/" .. biome .. "_castle.png")
        BInk.engrave(path, sx, sy, sw, sketchH, 0.8, BInk.SEPIA, 1.3)
        Ink.begin()
        Ink.line(sx - 6, sy + sketchH, sx + sw + 6, sy + 1 + sketchH, BInk.SEPIA, 0.6, entry.act * 29, { wobble = 0.5 })
        Ink.flush()
    end
    love.graphics.setFont(f)
    rgba(Palette.RUST)
    local w = f:getWidth(cap)
    love.graphics.print(cap, math.floor(r.x + r.w - w - 6), capY)
end

function BestiaryCard.draw(C, texts, entry, opts)
    opts = opts or {}
    local anim = opts.anim or 1
    local sw, sh = love.graphics.getDimensions()
    rgba(Palette.INK, 0.8 * math.min(1, anim * 1.5))
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    local p = C.page
    local lift = math.floor((1 - anim) * 26)
    local slide = math.floor((1 - anim) * 34 * (opts.turn or 0))
    love.graphics.push()
    love.graphics.translate(slide, lift)
    rgba(Palette.INK, 0.6)
    love.graphics.rectangle("fill", p.x + 5, p.y + 7, p.w, p.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(BInk.paper(p.w, p.h, 7), p.x, p.y)
    local mx, my = (opts.mx or -1) - slide, (opts.my or -1) - lift

    rgba(BInk.INK)
    love.graphics.setFont(FontManager.getFont(C.fonts.name))
    love.graphics.print(texts.name, C.name.x, C.name.y)
    if C.seal then
        Ink.begin()
        BInk.seal(C.seal.x, C.seal.y, C.seal.r, entry.tier, entry.act * 11)
        Ink.flush()
    end
    if texts.epithet ~= "" then
        rgba(Palette.RUST)
        Layout.printWrapped(texts.epithet, C.epithet.x, C.epithet.y, C.epithet.w, C.fonts.epithet)
    end
    local meta = BestiaryCard.actLabel(entry.act) .. "  ·  " .. BestiaryCard.tierLabel(entry.tier)
    rgba(BInk.SEPIA)
    TextFit.print(TextCase.upper(meta), C.meta.x, C.meta.y, { size = Layout.FONT.meta, maxW = C.meta.w })
    Ink.begin()
    Ink.line(C.rule.x, C.rule.y, C.rule.x + C.rule.w, C.rule.y + 1, BInk.SEPIA, 0.8, entry.act, { wobble = 0.8 })
    Ink.line(C.rule.x + 30, C.rule.y + 3, C.rule.x + math.floor(C.rule.w * 0.45), C.rule.y + 4,
        BInk.SEPIA, 0.4, entry.act + 9, { wobble = 0.6 })
    Ink.flush()

    drawFigure(C, entry, opts.t or 0)
    drawLedger(C, entry, texts)

    heading(C.loreHead, I18n.t("bestiary.ui.lore"), Palette.RUST, 3)
    rgba(BInk.INK)
    Layout.printWrapped(texts.lore, C.lore.x, C.lore.y, C.lore.w, C.fonts.lore)

    if C.sigBox then
        local r = C.sigBox
        Ink.begin()
        Ink.line(r.x + 6, r.y, r.x + 4, r.y + r.h, BInk.RED, 0.9, 61, { wobble = 0.9, weight = 2 })
        Ink.line(r.x + 2, r.y + 2, r.x + 10, r.y + 2, BInk.RED, 0.8, 62, { wobble = 0.3 })
        Ink.line(r.x + 1, r.y + r.h, r.x + 9, r.y + r.h - 1, BInk.RED, 0.8, 63, { wobble = 0.3 })
        Ink.flush()
        rgba(BInk.RED)
        TextFit.print(TextCase.upper(I18n.t("bestiary.ui.signature")), C.sigHead.x, C.sigHead.y,
            { size = 8, maxW = C.sigHead.w, minSize = 7 })
        Layout.printWrapped(texts.signature, C.signature.x, C.signature.y, C.signature.w, C.fonts.signature)
    end

    heading(C.movesHead, I18n.t("bestiary.ui.moves"), Palette.RUST, 5)
    local bf = FontManager.getFont(C.fonts.body)
    for i, r in ipairs(C.moveCells) do
        local label = texts.moves[i] or ""
        local cy = r.y + math.floor((r.h - bf:getHeight()) / 2)
        Ink.begin()
        local bc = texts.defeated and BInk.INK or BInk.FADED
        Ink.px(r.x + 2, cy + 3, bc, 1, 3, 3)
        Ink.px(r.x + 1, cy + 4, bc, 0.7, 1, 1)
        Ink.px(r.x + 5, cy + 2, bc, 0.6, 1, 1)
        Ink.flush()
        rgba(texts.defeated and BInk.INK or BInk.FADED)
        TextFit.print(label, r.x + 12, cy, { size = C.fonts.body, maxW = r.w - 12, minSize = 8 })
    end
    if C.movesHint then
        rgba(BInk.SEPIA)
        Layout.printWrapped(texts.movesHint, C.movesHint.x, C.movesHint.y, C.movesHint.w, 8)
    end
    drawHabitat(C, entry, texts)

    local canNav = opts.canNav ~= false
    navButton(C.prev, "<", hit(C.prev, mx, my), canNav, 101)
    navButton(C.next, ">", hit(C.next, mx, my), canNav, 107)
    navButton(C.close, "x", hit(C.close, mx, my), true, 113)
    if opts.counter then
        rgba(BInk.SEPIA)
        TextFit.print(opts.counter, C.counter.x, C.counter.y + 9,
            { size = Layout.FONT.meta, maxW = C.counter.w, align = "center" })
    end
    local NavCursor = require("src.ui.NavCursor")
    NavCursor.target("bst:prev", C.prev.x, C.prev.y, C.prev.w, C.prev.h)
    NavCursor.target("bst:next", C.next.x, C.next.y, C.next.w, C.next.h)
    NavCursor.target("bst:close", C.close.x, C.close.y, C.close.w, C.close.h)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return BestiaryCard
