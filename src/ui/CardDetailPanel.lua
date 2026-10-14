local CardDetailPanel = {}

local FontManager        = require("src.ui.FontManager")
local Palette            = require("src.ui.Palette")
local CardMesh           = require("src.ui.CardMesh")
local CardArt            = require("src.ui.CardArt")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local UpgradeTile        = require("src.ui.UpgradeTile")
local I18n               = require("src.i18n.I18n")

local PAD = 14

local DARK_PAL = {
    name = Palette.AGED_GOLD_LIGHT, body = Palette.PARCHMENT_LIGHT, dim = Palette.PARCHMENT,
    sep = Palette.PARCHMENT_DARK, divider = Palette.AGED_GOLD, head = Palette.AGED_GOLD,
    price = Palette.AGED_GOLD_LIGHT, mana = Palette.MANA_LIGHT or Palette.PARCHMENT_LIGHT,
    defense = Palette.STEEL_LIGHT, affinity = Palette.AGED_GOLD_LIGHT,
    typeColor = function(c) return Palette.lighten(c, 0.45) end,
    rarity = function(r) return Palette.forRarity(r) end,
}
local function lumC(c)
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
local function onPaper(c)
    local bg = Palette.PARCHMENT_LIGHT
    for _ = 1, 30 do
        local a, b = lumC(c), lumC(bg)
        if (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05) >= 4.5 then break end
        c = Palette.darken(c, 0.88)
    end
    return c
end
CardDetailPanel.onPaper = onPaper
local PARCHMENT_PAL = {
    name = Palette.BLOOD_DARK, body = Palette.INK, dim = onPaper(Palette.PARCHMENT_DARK),
    sep = Palette.PARCHMENT_DARK, divider = Palette.AGED_GOLD_DARK, head = Palette.RUST,
    price = Palette.AGED_GOLD_DARK, mana = Palette.MANA_DEEP or Palette.INK,
    defense = Palette.STEEL, affinity = Palette.RUST,
    typeColor = function(c) return onPaper(Palette.darken(c, 0.75)) end,
    rarity = function(r) return onPaper(Palette.darken(Palette.forRarity(r), 0.55)) end,
}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function fontTier(w)
    if w >= 330 then
        return { name = 15, meta = 10, stat = 12, desc = 10, tiny = 8 }
    elseif w >= 270 then
        return { name = 13, meta = 9, stat = 11, desc = 9, tiny = 8 }
    end
    return { name = 11, meta = 8, stat = 9, desc = 8, tiny = 7 }
end

local function fitFont(strings, maxW, from, to)
    for size = from, to, -1 do
        local f = FontManager.getFont(size)
        local ok = true
        for _, t in ipairs(strings) do
            if f:getWidth(t) > maxW then ok = false; break end
        end
        if ok then return f, size, true end
    end
    return FontManager.getFont(to), to, false
end

local function setC(color, a)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (a or 1))
end

local function divider(x, y, w, alpha, color)
    setC(color or Palette.AGED_GOLD, 0.55 * alpha)
    love.graphics.rectangle("fill", x, y, w, 1)
end

local function drawCardArt(inst, ax, ay, aw, ah, alpha)
    local img = inst and inst.image
    if not img then return end

    local okCF, CardFrame = pcall(require, "src.ui.CardFrame")
    if okCF and CardFrame and CardFrame.displayImage then
        img = CardFrame.displayImage(inst) or img
    end

    local iw, ih = img:getWidth(), img:getHeight()
    local scale = math.min((aw - 28) / iw, (ah - 16) / ih)
    local dw, dh = iw * scale, ih * scale
    local x = math.floor(ax + (aw - dw) / 2)
    local y = math.floor(ay + (ah - dh) / 2)

    local steps = 20
    for i = steps, 1, -1 do
        local t = i / steps
        local pad = 3 + t * 34
        setC(Palette.AGED_GOLD, 0.05 * ((1 - t) ^ 1.5) * alpha)
        love.graphics.rectangle("fill", x - pad, y - pad, dw + pad * 2, dh + pad * 2, 16, 16)
    end

    local uvx, uvy, hover = 0, 0, 0
    if not reducedMotion() then
        local mx, my = love.mouse.getPosition()
        local cx, cy = x + dw / 2, y + dh / 2
        uvx = math.max(-1, math.min(1, (mx - cx) / (dw / 2)))
        uvy = math.max(-1, math.min(1, (my - cy) / (dh / 2)))
        hover = 0.55 * alpha
    end

    local shDx = -uvx * 9
    local shDy = 8 - uvy * 6

    local shader = CardMesh.getShader()
    if shader then
        local mesh = CardMesh.getMesh(iw, ih)
        mesh:setTexture(img)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, { uvx, uvy }, hover, love.timer.getTime(), img)
        love.graphics.setColor(0, 0, 0, 0.38 * alpha)
        love.graphics.draw(mesh, x + shDx, y + shDy, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(mesh, x, y, 0, scale, scale)
        love.graphics.setShader()
    else
        love.graphics.setColor(0, 0, 0, 0.38 * alpha)
        love.graphics.draw(img, x + shDx, y + shDy, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, x, y, 0, scale, scale)
    end

    if not inst._cachedArt then
        local ok, a = pcall(CardArt.resolve, inst)
        inst._cachedArt = ok and a or { bgPattern = nil }
    end
    pcall(CardAnimationLayer.draw, inst, inst._cachedArt, x, y, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPackArt(offer, ax, ay, aw, ah, alpha)
    local ok, PackSleeve = pcall(require, "src.ui.PackSleeve")
    if not ok or not PackSleeve then return end
    local sw, sh = PackSleeve.getDimensions()
    if not sw or sw <= 0 then return end
    local scale = math.min(aw / sw, ah / sh)
    PackSleeve.drawAt(offer.id, offer.kind,
        math.floor(ax + aw / 2), math.floor(ay + ah / 2), scale, alpha)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawVoucherArt(offer, ax, ay, aw, ah, alpha)
    local t = love.timer.getTime()
    UpgradeTile.drawArt(offer, { x = ax, y = ay, w = aw, h = ah }, {
        alpha = alpha,
        glow = 0.8,
        bob = reducedMotion() and 0 or (math.sin(t * 1.4) * 2),
        animate = true,
        time = t,
    })
end

local function normalized(text)
    return (require("src.i18n.TextCase").lower(tostring(text or "")):gsub("[%p%s]+", " "))
end

local function extraEffects(inst, desc)
    local out = {}
    if not (inst and inst.effects) then return out end
    local hay = normalized(desc)
    for _, e in ipairs(inst.effects) do
        local txt = I18n.effectDesc(e)
        if txt and txt ~= "" and not hay:find(normalized(txt), 1, true) then
            out[#out + 1] = txt
        end
    end
    return out
end

local function wrapLines(text, font, w)
    local out = {}
    for seg in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        local _, wrapped = font:getWrap(seg, w)
        if #wrapped == 0 then out[#out + 1] = "" end
        for _, l in ipairs(wrapped) do out[#out + 1] = l end
    end
    return out
end

local LINE_GAP = 6

local function line(text, font, color, x, y, w, limit, alpha, align)
    if y > limit then return y end
    love.graphics.setFont(font)
    setC(color, alpha)
    local lines = wrapLines(text, font, w)
    local lh = font:getHeight() + LINE_GAP
    for i, l in ipairs(lines) do
        local ly = y + (i - 1) * lh
        if ly + font:getHeight() > limit then return ly end
        love.graphics.printf(l, x, ly, w, align or "left")
    end
    return y + #lines * lh
end

local function typeLabelFor(payload)
    if payload.kind == "pack" then
        return I18n.t("reward.detail_type_pack", nil, "Pacote")
    elseif payload.kind == "voucher" then
        return I18n.t("reward.detail_type_voucher", nil, "Relíquia")
    end
    local inst = payload.instance
    local t = (inst and inst.type) or "unknown"
    return I18n.t("card_type." .. t, nil, I18n.t("card_type.unknown", nil, "CARTA"))
end

function CardDetailPanel.draw(rect, payload, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    if alpha <= 0.01 then return end

    local x, y = math.floor(rect.x), math.floor(rect.y)
    local w, h = math.floor(rect.w), math.floor(rect.h)
    if w < 60 or h < 80 then return end

    if opts.chrome ~= false then
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        setC(Palette.AGED_GOLD_DARK, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(x, y + 10, x, y + h - 10)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local F = fontTier(w)
    local PAL = opts.parchment and PARCHMENT_PAL or DARK_PAL
    local textX = x + PAD
    local textW = w - PAD * 2
    local footerH = opts.footerH or 0
    local bottom = y + h - footerH - PAD

    if not payload or not payload.offer then
        local msg = opts.emptyHint
            or I18n.t("reward.detail_empty", nil,
                      "Passe o mouse sobre uma oferta para ver os detalhes aqui")
        local font = FontManager.getFont(F.desc)
        local lines = wrapLines(msg, font, textW)
        local lh = font:getHeight() + LINE_GAP
        local blockY = y + math.floor((h - #lines * lh) / 2)
        love.graphics.setFont(font)
        setC(PAL.dim, 0.75 * alpha)
        for i, l in ipairs(lines) do
            love.graphics.printf(l, textX, blockY + (i - 1) * lh, textW, "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local offer = payload.offer
    local inst = payload.instance

    local desc = payload.kind == "card"
        and I18n.cardDesc({ id = offer.id, description = offer.description })
        or offer.description
    if not desc or desc == "" then
        desc = I18n.t("card_info.no_desc", nil, "")
    end
    local displayName = payload.kind == "card"
        and I18n.cardName({ id = offer.id, name = offer.name })
        or offer.name or "?"
    local extras = (payload.kind == "card") and extraEffects(inst, desc) or {}
    local chipTxt = (payload.kind == "voucher") and UpgradeTile.effectLabel(offer) or nil
    local flavor = (payload.kind == "voucher") and UpgradeTile.flavor(offer) or nil
    local typeLabel = typeLabelFor(payload)
    local rarityLabel = offer.rarity and I18n.t("rarity." .. offer.rarity, nil, offer.rarity) or nil
    local priceLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
        or I18n.t("reward.detail_free", nil, "Grátis")
    local typeColor = inst and PAL.typeColor(Palette.forCardType(inst.type)) or PAL.dim
    local segs = { { typeLabel, typeColor } }
    if rarityLabel then segs[#segs + 1] = { rarityLabel, PAL.rarity(offer.rarity) } end
    if not opts.priceOnButton then
        segs[#segs + 1] = { priceLabel, opts.canAfford == false and Palette.BLOOD or PAL.price }
    end
    local sep = "  ·  "
    local joined = segs[1][1]
    for i = 2, #segs do joined = joined .. sep .. segs[i][1] end
    local statParts = {}
    if payload.kind == "card" and inst then
        statParts[#statParts + 1] = { I18n.t("card_info.cost", nil, "Custo: ") .. tostring(inst.cost or 0), PAL.mana }
        if inst.type == "attack" and (inst.attack or 0) > 0 then
            statParts[#statParts + 1] = { I18n.t("card_info.damage", nil, "Dano: ") .. tostring(inst.attack), Palette.BLOOD }
        elseif inst.type == "defense" and (inst.defense or 0) > 0 then
            statParts[#statParts + 1] = { I18n.t("card_info.defense", nil, "Defesa: ") .. tostring(inst.defense), PAL.defense }
        end
    end
    local affinityTxt = (offer.affinity and offer.affinityTags)
        and I18n.t("reward.affinity_line", { tags = table.concat(offer.affinityTags, ", ") },
            "Afinidade com seu deck: " .. table.concat(offer.affinityTags, ", ")) or nil

    local function linesH(text, font, w)
        return #wrapLines(text, font, w) * (font:getHeight() + LINE_GAP)
    end
    local function statsLayout(Fx)
        if #statParts == 0 then return 0, nil, false end
        local texts = {}
        for _, p in ipairs(statParts) do texts[#texts + 1] = p[1] end
        local half = math.floor(textW / math.max(1, #statParts)) - 8
        local f, _, fits = fitFont(texts, half, Fx.stat, math.max(6, Fx.stat - 4))
        if fits or #statParts == 1 then return f:getHeight() + 8, f, true end
        f = fitFont(texts, textW, Fx.stat, math.max(6, Fx.stat - 4))
        return (f:getHeight() + 4) * #statParts + 4, f, false
    end
    local function textBlockH(Fx)
        local hgt = linesH(displayName, FontManager.getFont(Fx.name), textW) + 8
        local mf = fitFont({ joined }, textW, Fx.meta, math.max(6, Fx.meta - 3))
        hgt = hgt + mf:getHeight() + 10
        hgt = hgt + (statsLayout(Fx))
        if chipTxt then hgt = hgt + FontManager.getFont(Fx.stat):getHeight() + 16 end
        hgt = hgt + 8 + linesH(desc, FontManager.getFont(Fx.desc), textW)
        if flavor then hgt = hgt + 6 + linesH('"' .. flavor .. '"', FontManager.getFont(Fx.tiny), textW) end
        if #extras > 0 then
            local ft = FontManager.getFont(Fx.tiny)
            hgt = hgt + 4 + ft:getHeight() + LINE_GAP
            for i, txt in ipairs(extras) do
                if i <= 4 then hgt = hgt + linesH("- " .. txt, ft, textW - 6) end
            end
        end
        if affinityTxt then hgt = hgt + 4 + linesH(affinityTxt, FontManager.getFont(Fx.tiny), textW) end
        return hgt
    end
    local avail = h - footerH - PAD * 2 - 18
    local artCap = math.floor((h - footerH) * 0.60)
    if opts.artMaxH then artCap = math.min(artCap, math.floor(opts.artMaxH)) end
    local artMin = math.floor(artCap * 0.45)
    local tiers = { F }
    for _, tf in ipairs({ { name = 13, meta = 9, stat = 11, desc = 9, tiny = 8 },
                          { name = 11, meta = 8, stat = 9, desc = 8, tiny = 7 } }) do
        if tf.desc < tiers[#tiers].desc or tf.name < tiers[#tiers].name then tiers[#tiers + 1] = tf end
    end
    local artH, textH, fits
    for _, tf in ipairs(tiers) do
        F = tf
        textH = textBlockH(F)
        artH = math.min(artCap, avail - textH)
        fits = artH >= artMin
        if fits then break end
    end
    if not fits then artH = artMin end
    artH = math.max(0, math.floor(artH))
    local artY = y + PAD
    local artW = textW
    if payload.kind == "card" then
        drawCardArt(inst, textX, artY, artW, artH, alpha)
    elseif opts.objectArt and opts.objectArt(payload, textX, artY, artW, artH, alpha) then
    elseif payload.kind == "pack" then
        drawPackArt(offer, textX, artY, artW, artH, alpha)
    else
        drawVoucherArt(offer, textX, artY, artW, artH, alpha)
    end

    local cy = artY + artH + 18
    local textTop = cy

    cy = line(displayName, FontManager.getFont(F.name), PAL.name,
              textX, cy, textW, bottom, alpha, "center")
    divider(textX, cy + 2, textW, alpha, PAL.divider)
    cy = cy + 8

    do
        local metaFont = fitFont({ joined }, textW, F.meta, math.max(6, F.meta - 3))
        love.graphics.setFont(metaFont)
        local total = 0
        for i, sg in ipairs(segs) do
            total = total + metaFont:getWidth(sg[1])
            if i < #segs then total = total + metaFont:getWidth(sep) end
        end
        local sx = textX + math.floor((textW - total) / 2)
        for i, sg in ipairs(segs) do
            setC(sg[2], alpha)
            love.graphics.print(sg[1], sx, cy)
            sx = sx + metaFont:getWidth(sg[1])
            if i < #segs then
                setC(PAL.sep, alpha)
                love.graphics.print(sep, sx, cy)
                sx = sx + metaFont:getWidth(sep)
            end
        end
        cy = cy + metaFont:getHeight() + 10
    end

    if #statParts > 0 then
        local hgt, statFont, side = statsLayout(F)
        love.graphics.setFont(statFont)
        if side then
            local gap = math.floor(textW / math.max(1, #statParts))
            for i, p in ipairs(statParts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX + (i - 1) * gap, cy, gap,
                    #statParts == 1 and "center" or (i == 1 and "left" or "right"))
            end
        else
            local yy = cy
            for _, p in ipairs(statParts) do
                setC(p[2], alpha)
                love.graphics.printf(p[1], textX, yy, textW, "center")
                yy = yy + statFont:getHeight() + 4
            end
        end
        cy = cy + hgt
    end

    if chipTxt then
        local th = UpgradeTile.theme(offer)
        local f = FontManager.getFont(F.stat)
        local chipH = f:getHeight() + 10
        local chipW = math.min(textW, f:getWidth(chipTxt) + 28)
        local chipX = textX + math.floor((textW - chipW) / 2)
        setC(Palette.darken(Palette.INK, 0.2), alpha * 0.85)
        love.graphics.rectangle("fill", chipX, cy, chipW, chipH, 3, 3)
        setC(th.accent, alpha * 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", chipX + 0.5, cy + 0.5, chipW - 1, chipH - 1, 3, 3)
        love.graphics.setFont(f)
        setC(th.text, alpha)
        love.graphics.printf(chipTxt, chipX, cy + 5, chipW, "center")
        cy = cy + chipH + 6
    end

    divider(textX, cy, textW, alpha * 0.8, PAL.divider)
    cy = cy + 8

    cy = line(desc, FontManager.getFont(F.desc), PAL.body, textX, cy, textW, bottom, alpha)

    if flavor then
        cy = cy + 6
        cy = line('"' .. flavor .. '"', FontManager.getFont(F.tiny),
                  PAL.dim, textX, cy, textW, bottom, alpha * 0.9, "center")
    end

    if #extras > 0 then
        cy = cy + 4
        cy = line(I18n.t("card_info.effects", nil, "Efeitos"),
                  FontManager.getFont(F.tiny), PAL.head, textX, cy, textW, bottom, alpha)
        local effFont = FontManager.getFont(F.tiny)
        for i, txt in ipairs(extras) do
            if i > 4 then break end
            cy = line("- " .. txt, effFont, PAL.body, textX + 6, cy, textW - 6, bottom, alpha)
        end
    end

    if affinityTxt then
        cy = cy + 4
        cy = line(affinityTxt, FontManager.getFont(F.tiny), PAL.affinity, textX, cy, textW, bottom, alpha)
    end

    if opts.stale and opts.staleHint then
        local f = FontManager.getFont(F.tiny)
        local lines = wrapLines(opts.staleHint, f, textW)
        local lh = f:getHeight() + LINE_GAP
        local topY = y + h - footerH - 8 - #lines * lh
        if topY >= cy + 4 then
            love.graphics.setFont(f)
            setC(PAL.dim, (opts.parchment and 0.8 or 0.45) * alpha)
            for i, l in ipairs(lines) do
                love.graphics.printf(l, textX, topY + (i - 1) * lh, textW, "center")
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    return { fits = fits and cy <= bottom + 1, contentBottom = cy, bottom = bottom, artH = artH,
             textTop = textTop, font = F }
end

return CardDetailPanel
