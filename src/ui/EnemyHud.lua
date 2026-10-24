local Debug = require("src.core.Debug")

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local IconLoader = require("src.ui.IconLoader")

local EnemyHud = {}

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local INTENT_ICON = {
    attack = "intent_attack", strong = "intent_strong", multi = "intent_multi",
    defend = "intent_defense", defense = "intent_defense",
    buff = "intent_buff", heal = "intent_heal",
    debuff = "intent_debuff", charge = "intent_charge", summon = "intent_summon",
    unknown = "intent_unknown",
}
local intentIcons = {}
local function getIconByName(name)
    if intentIcons[name] ~= nil then return intentIcons[name] or nil end
    local icon = IconLoader.get(name)
    if not icon then
        Debug.warn("[EnemyHud] ícone de intent ausente: " .. tostring(name))
    end
    intentIcons[name] = icon or false
    return icon
end
local function getIntentIcon(kind)
    return getIconByName(INTENT_ICON[kind or "attack"] or "intent_unknown")
end

local DEBUFF_ICON = {
    weak = "status_weak_self", vulnerable = "status_vulnerable_self",
    frail = "status_frail",
    poison = "status_poison", burn = "status_burn",
}

local function intentPreview(enemy, player)
    if enemy.getIntentPreview then
        return enemy:getIntentPreview(player)
    end
    local dmg = enemy.damage or 0
    if enemy.hasStatus and enemy:hasStatus("weak") then
        dmg = math.floor(dmg * 0.75)
    end
    return "attack", dmg
end

function EnemyHud.intentSpec(enemy, player)
    if not enemy then return nil end
    local kind, value, it = intentPreview(enemy, player)
    it = it or {}
    local I18n = require("src.i18n.I18n")
    local hits = it.hits or 0
    local text
    if (it.perHit or 0) > 0 and value and value > 0 then
        text = (hits > 1) and (value .. "×" .. hits) or tostring(value)
    elseif kind == "buff" and (value or 0) > 0 then
        text = "+" .. value
    elseif (kind == "defend" or kind == "heal") and (value or 0) > 0 then
        text = tostring(value)
    end

    local extras = {}
    local lines = {}
    if it.pierce and (it.perHit or 0) > 0 then
        extras[#extras + 1] = "intent_pierce"
    end
    if (it.armor or 0) > 0 and kind ~= "defend" then
        extras[#extras + 1] = "intent_defense"
    end
    if (it.perHit or 0) > 0 and value and value > 0 then
        if hits > 1 then
            lines[#lines + 1] = I18n.t("enemy_kit.intent.multi",
                { hits = hits, value = value, total = value * hits })
        else
            lines[#lines + 1] = I18n.t("enemy_kit.intent.hit", { value = value })
        end
        if it.pierce then lines[#lines + 1] = I18n.t("enemy_kit.intent.pierce") end
    end
    if (it.armor or 0) > 0 then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.armor", { value = it.armor })
    end
    for _, d in ipairs(it.debuffs or {}) do
        extras[#extras + 1] = DEBUFF_ICON[d.name] or "status_weak"
        local nm = I18n.t("enemy_kit.status." .. d.name .. "_self.name", nil,
            I18n.t("enemy_kit.status." .. d.name .. ".name", nil, d.name))
        if d.name == "poison" or d.name == "burn" then
            lines[#lines + 1] = I18n.t("enemy_kit.intent.dot",
                { name = nm, stacks = d.stacks, duration = d.duration })
        else
            lines[#lines + 1] = I18n.t("enemy_kit.intent.debuff",
                { name = nm, duration = d.duration })
        end
    end
    if (it.strength or 0) > 0 then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.strength", { value = it.strength })
    end
    if (it.heal or 0) > 0 then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.heal", { value = it.heal })
    end
    if (it.summon or 0) > 0 then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.summon", { value = it.summon })
    end
    if it.charge then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.charge")
    end
    if it.frost then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.frost", { value = it.frost })
    end
    if it.fullMoon then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.full_moon")
    end
    if it.newMoon then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.new_moon")
    end
    if it.staggered then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.staggered")
    end
    if it.runes then
        lines[#lines + 1] = I18n.t("enemy_kit.intent.runes", { hits = hits })
        if hits <= 0 then text = "0" end
    end

    local title = I18n.t("enemy_kit.moves." .. tostring(it.id or kind) .. ".name", nil,
        I18n.t("status.intent_" .. tostring(kind) .. ".name", nil, tostring(kind)))
    local heavy = (kind == "strong") or (kind == "charge")

    local visibility = (enemy.getIntentVisibility and enemy:getIntentVisibility()) or "full"
    local veilColor = nil
    if visibility ~= "full" then
        local IV = require("src.systems.IntentVisibility")
        veilColor = IV.veilColor(enemy)
        local enemyName = I18n.t("end_screen.enemy." .. tostring(enemy.spriteId or enemy.kitId), nil,
            tostring(enemy.spriteId or enemy.kitId or "?"))
        lines = {}
        if visibility == "hidden" then
            kind, text, extras, heavy = "unknown", nil, {}, false
            title = I18n.t("enemy_kit.intent.veil_title")
            lines[#lines + 1] = I18n.t("enemy_kit.intent.veil_all")
        else
            text = I18n.t("enemy_kit.intent.unknown_value", nil, "?")
            title = I18n.t("status.intent_" .. tostring(kind) .. ".name", nil,
                I18n.t("enemy_kit.moves." .. tostring(kind) .. ".name", nil, tostring(kind)))
            lines[#lines + 1] = I18n.t("enemy_kit.intent.veil_number")
            if it.pierce and (it.perHit or 0) > 0 then
                lines[#lines + 1] = I18n.t("enemy_kit.intent.pierce")
            end
            for _, d in ipairs(it.debuffs or {}) do
                local nm = I18n.t("enemy_kit.status." .. d.name .. "_self.name", nil,
                    I18n.t("enemy_kit.status." .. d.name .. ".name", nil, d.name))
                lines[#lines + 1] = I18n.t("enemy_kit.intent.veil_debuff", { name = nm })
            end
            if it.frost then
                lines[#lines + 1] = I18n.t("enemy_kit.intent.frost", { value = it.frost })
            end
        end
        if enemy.intentVeilCause == "veil" then
            lines[#lines + 1] = I18n.t("enemy_kit.intent.veil_enemy", { name = enemyName })
        end
        lines[#lines + 1] = I18n.t("enemy_kit.intent.veil_hint")
    end
    return {
        kind = kind, value = (visibility == "full") and (value or 0) or 0,
        text = text, extras = extras,
        pierce = it.pierce and true or false, heavy = heavy,
        title = title, body = table.concat(lines, " "),
        visibility = visibility, veilColor = veilColor,
    }
end

local EXTRA_ICON = 24
local EXTRA_GAP = 3

local function hpBarGeom(cx, groundY, spriteWidth, barYOverride)
    local barW = math.max(160, math.min(260, spriteWidth + 40))
    local barH = 10
    local x = math.floor(cx - barW / 2)
    local y = barYOverride or math.floor(groundY + 10)
    return x, y, barW, barH
end

function EnemyHud.hpBarRect(L)
    if not L then return nil end
    local x, y, w, h = hpBarGeom(L.cx, L.groundY, L.sw, L.hpBarY)
    return { x = x, y = y, w = w, h = h }
end

function EnemyHud.drawHpBar(enemy, cx, groundY, spriteWidth, barYOverride)
    if not enemy then return end

    local x, y, barW, barH = hpBarGeom(cx, groundY, spriteWidth, barYOverride)

    local hpReal = enemy.health or 0
    local hp = math.floor(((enemy.disp and enemy.disp.health) or hpReal) + 0.001)
    local maxHp = enemy.maxHealth or 1
    local pct = math.max(0, math.min(1, hp / maxHp))

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 1, y + 2, barW, barH, 2, 2)

    love.graphics.setColor(0.10, 0.06, 0.04, 0.95)
    love.graphics.rectangle("fill", x, y, barW, barH, 2, 2)

    local fillR, fillG, fillB = Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3]
    if pct < 0.3 then
        fillR = fillR * 1.2
    end
    love.graphics.setColor(fillR, fillG, fillB, 1)
    love.graphics.rectangle("fill", x, y, barW * pct, barH, 2, 2)

    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.rectangle("fill", x, y, barW * pct, 3, 2, 2)

    setColor(Palette.INK, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, barW, barH, 2, 2)

    for _, f in ipairs(require("src.systems.BossMechanics").hpMarks(enemy)) do
        local mx = math.floor(x + barW * f)
        setColor(Palette.INK, 1)
        love.graphics.rectangle("fill", mx - 2, y - 4, 4, barH + 8)
        setColor(Palette.AGED_GOLD, 1)
        love.graphics.rectangle("fill", mx - 1, y - 3, 2, barH + 6)
    end

    local font = FontManager.getResponsiveFont(0.02, 13)
    love.graphics.setFont(font)
    local txt = hp .. " / " .. maxHp
    local tw = font:getWidth(txt)
    local tx = math.floor(cx - tw / 2)
    local ty = y - font:getHeight() - 1
    if pct < 0.25 and pct > 0 then
        local intensity = (0.25 - pct) / 0.25
        tx = tx + (math.random() - 0.5) * 2 * intensity
        ty = ty + (math.random() - 0.5) * 2 * intensity
    end
    FontManager.drawWithOutline(txt, tx, ty, { 1, 1, 1, 1 }, 0.9)

    love.graphics.setColor(1, 1, 1, 1)
end

local StatusPill = require("src.ui.StatusPill")
local ResistBadges = require("src.ui.ResistBadges")
local Resistances = require("src.systems.Resistances")

EnemyHud.RESIST_GAP = 8

local BADGE_SIZE = 42
local BADGE_SPACING = 10

local function hasStatus(enemy, name)
    for _, e in ipairs(enemy.statusEffects or {}) do
        if e.name == name then return true end
    end
    return false
end

function EnemyHud.collectPills(enemy)
    if not enemy then return {} end
    local list = {}

    local armor = math.floor(enemy.armor or 0)
    if armor > 0 and not hasStatus(enemy, "block") then
        list[#list + 1] = { name = "block", stacks = armor, duration = 1 }
    end
    if enemy.attackPattern == "aggressive" and not hasStatus(enemy, "enraged") then
        list[#list + 1] = { name = "enraged", stacks = 1, duration = 1, showStacks = false }
    end
    local BossMechanics = require("src.systems.BossMechanics")
    for _, e in ipairs(enemy.statusEffects or {}) do
        local vars = BossMechanics.pillVars(enemy, e.name)
        if vars and vars.stacks then vars.showStacks = false end
        local dotType = Resistances.DOT_TYPE[e.name]
        local lvl = dotType and Resistances.level(enemy, dotType)
        if lvl then
            vars = vars or {}
            vars.variant = lvl
        end
        if vars then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            for k, v in pairs(vars) do copy[k] = v end
            list[#list + 1] = copy
        else
            list[#list + 1] = e
        end
    end
    return list
end

function EnemyHud.getStatusPillsDims(enemy, size)
    local pills = EnemyHud.collectPills(enemy)
    return StatusPill.getRowDims(#pills, size or BADGE_SIZE, BADGE_SPACING)
end

function EnemyHud.drawStatusEffects(enemy, cx, groundY, startX, startY, size)
    local pills = EnemyHud.collectPills(enemy)
    if #pills == 0 then return end
    size = size or BADGE_SIZE

    if not startX then
        local total = StatusPill.getRowDims(#pills, size, BADGE_SPACING)
        startX = math.floor(cx - total / 2)
    end
    local y = startY or math.floor(groundY + 38)

    StatusPill.drawRow(pills, startX, y, {
        size = size,
        spacing = BADGE_SPACING,
        pulseHalo = false,
    })
end

local flashUntil = 0
local FLASH_DUR = 0.55
function EnemyHud.flashIntent()
    flashUntil = love.timer.getTime() + FLASH_DUR
end

local ICON_SIZE = 34

local function intentBoxGeom(spec)
    local font = FontManager.getResponsiveFont(0.036, 26)
    local tw = spec.text and font:getWidth(spec.text) or 0
    local nExtra = #spec.extras
    local gap = 6
    local contentW = ICON_SIZE
    if tw > 0 then contentW = contentW + gap + tw end
    if nExtra > 0 then
        contentW = contentW + gap + nExtra * EXTRA_ICON + (nExtra - 1) * EXTRA_GAP
    end
    local padX, padY = 10, 7
    return {
        font = font, tw = tw, gap = gap, padX = padX, padY = padY,
        w = contentW + padX * 2, h = ICON_SIZE + padY * 2,
    }
end

function EnemyHud.getIntentDims(enemy, player)
    if not enemy then return 0, 0 end
    local spec = EnemyHud.intentSpec(enemy, player)
    if not spec then return 0, 0 end
    local g = intentBoxGeom(spec)
    local w, h = g.w, g.h
    if spec.heavy then
        w = math.floor(w * 1.12)
        h = math.floor(h * 1.12)
    end
    return w, h
end

function EnemyHud.drawIntent(enemy, cx, topY, boxXOverride, boxYOverride, player)
    if not enemy then return end
    local spec = EnemyHud.intentSpec(enemy, player)
    if not spec then return end
    local kind = spec.kind
    local now = love.timer.getTime()
    local rm = _G.gameSettings and _G.gameSettings.reducedMotion

    local g = intentBoxGeom(spec)
    local font, txt = g.font, spec.text
    local iconSize, gap, padX, padY = ICON_SIZE, g.gap, g.padX, g.padY
    local boxW, boxH = g.w, g.h
    local boxX = boxXOverride or math.floor(cx - boxW / 2)
    local boxY = boxYOverride or math.floor(topY - boxH - 10)

    if not rm then
        boxY = boxY + math.floor(math.sin(now * 2.2) * 3 + 0.5)
    end

    local scaleK = spec.heavy and 1.12 or 1.0
    local flashK = 0
    if flashUntil > now then
        flashK = (flashUntil - now) / FLASH_DUR
        scaleK = scaleK * (1 + 0.35 * flashK)
    end
    local usedTransform = scaleK ~= 1.0
    if usedTransform then
        local mcx, mcy = boxX + boxW / 2, boxY + boxH / 2
        love.graphics.push()
        love.graphics.translate(mcx, mcy)
        love.graphics.scale(scaleK, scaleK)
        love.graphics.translate(-mcx, -mcy)
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", boxX + 2, boxY + 3, boxW, boxH, 5, 5)

    setColor(Palette.PARCHMENT_DARK, 0.97)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    local accent = Palette.BLOOD
    if kind == "defend" then
        accent = Palette.STEEL or { 0.55, 0.62, 0.70, 1 }
    elseif kind == "buff" or kind == "summon" then
        accent = Palette.AGED_GOLD
    elseif kind == "debuff" or kind == "charge" then
        accent = { 0.62, 0.40, 0.85, 1 }
    elseif kind == "heal" then
        accent = { 0.40, 0.80, 0.50, 1 }
    end

    local pulseSpeed = spec.heavy and 5 or 3
    local pulse = 0.5 + math.sin(love.timer.getTime() * pulseSpeed) * 0.5
    local pulseBase = spec.heavy and 0.24 or 0.15
    love.graphics.setColor(accent[1], accent[2], accent[3], pulseBase + pulse * 0.08)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 5, 5)

    setColor(accent, 0.75)
    love.graphics.rectangle("line", boxX + 2, boxY + 2, boxW - 4, boxH - 4, 4, 4)

    local icon = getIntentIcon(kind)
    if icon and icon.draw then
        local iconH = (icon.size and icon.size.h) or 16
        local iw = (icon.size and icon.size.w) or 16
        local scale = IconLoader.computeScale(iconH, iconSize)
        local iconX = boxX + padX + math.floor((iconSize - iw * scale) / 2)
        local iconY = boxY + padY + math.floor((iconSize - iconH * scale) / 2)
        icon.draw(iconX, iconY, scale)
    end

    require("src.systems.Tutorial").anchor("intent", boxX, boxY, boxW, boxH)

    require("src.ui.NavCursor").target("enemy:intent", boxX, boxY, boxW, boxH)
    do
        local mx, my = love.mouse.getPosition()
        if mx >= boxX and mx <= boxX + boxW and my >= boxY and my <= boxY + boxH then
            local StatusTooltip = require("src.ui.StatusTooltip")
            StatusTooltip.show("intent_" .. kind, mx, my,
                { value = spec.value, title = spec.title, body = spec.body })
        end
    end

    local cursorX = boxX + padX + iconSize
    if txt then
        love.graphics.setFont(font)
        local tx = cursorX + gap
        local ty = boxY + math.floor((boxH - font:getHeight()) / 2)
        local numColor = { 1, 0.3, 0.3, 1 }
        if kind == "defend" then numColor = { 0.65, 0.75, 0.9, 1 }
        elseif kind == "buff" then numColor = { 1, 0.85, 0.4, 1 }
        elseif kind == "heal" then numColor = { 0.5, 0.95, 0.55, 1 } end
        if spec.visibility ~= "full" then numColor = { 0.88, 0.88, 0.92, 1 } end
        FontManager.drawWithOutline(txt, tx, ty, numColor, 0.95)
        cursorX = tx + g.tw
    end

    if #spec.extras > 0 then
        local ex = cursorX + gap
        local ey = boxY + math.floor((boxH - EXTRA_ICON) / 2)
        for _, name in ipairs(spec.extras) do
            local ic = getIconByName(name)
            if ic and ic.draw then
                local ih2 = (ic.size and ic.size.h) or 16
                local iw2 = (ic.size and ic.size.w) or 16
                local sc = IconLoader.computeScale(ih2, EXTRA_ICON)
                love.graphics.setColor(1, 1, 1, 1)
                ic.draw(ex + math.floor((EXTRA_ICON - iw2 * sc) / 2),
                    ey + math.floor((EXTRA_ICON - ih2 * sc) / 2), sc)
            end
            ex = ex + EXTRA_ICON + EXTRA_GAP
        end
    end

    require("src.ui.IntentVeil").draw(boxX, boxY, boxW, boxH, spec.visibility,
        spec.veilColor, enemy)

    if flashK > 0 then
        love.graphics.setColor(1, 1, 0.95, 0.45 * flashK)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.9 * flashK)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", boxX - 2, boxY - 2, boxW + 4, boxH + 4, 6, 6)
        love.graphics.setLineWidth(1)
    end

    if usedTransform then love.graphics.pop() end
    love.graphics.setColor(1, 1, 1, 1)
end

function EnemyHud.layout(game, bbox, fallbackCx, fallbackGroundY)
    if not game or not game.enemy then return nil end
    local cx, groundY, topY, sw
    if type(bbox) == "table" then
        cx, groundY, topY, sw = bbox.cx, bbox.bottomY, bbox.topY, bbox.width
    else
        cx = fallbackCx or love.graphics.getWidth() / 2
        groundY = fallbackGroundY or love.graphics.getHeight() * 0.55
        topY = groundY - 180
        sw = 160
    end

    local iw, ih = EnemyHud.getIntentDims(game.enemy, game.player)
    local gap = 10
    local pillCount = #EnemyHud.collectPills(game.enemy)
    local pillSize = StatusPill.fitSize(pillCount,
        love.graphics.getWidth() * 0.9 - iw - (iw > 0 and gap or 0),
        BADGE_SIZE, BADGE_SPACING)
    local pw, ph = EnemyHud.getStatusPillsDims(game.enemy, pillSize)
    local bothPresent = (iw > 0 and pw > 0)
    local totalW = iw + (bothPresent and gap or 0) + pw
    local rowH = math.max(ih, ph)

    local rowGap = 6
    local topMargin = 8

    local hpBarY = math.floor(topY - topMargin - 10)
    local rowY = math.floor(hpBarY - rowGap - 13 - rowH)

    local barW = math.max(160, math.min(260, sw + 40))
    local clusterW = math.max(totalW, barW)
    local top = (totalW > 0) and (rowY - 3) or (hpBarY - 13)
    local spriteL = cx - sw / 2
    local left = math.min(cx - clusterW / 2, spriteL)
    local resistW = ResistBadges.width(game.enemy)
    if resistW > 0 then
        left = math.min(left, math.floor(cx - barW / 2) - EnemyHud.RESIST_GAP - resistW)
        top = math.min(top, hpBarY + 5 - ResistBadges.SIZE / 2)
    end
    local right = math.max(cx + clusterW / 2, spriteL + sw)
    return {
        cx = cx, groundY = groundY, topY = topY, sw = sw,
        iw = iw, ih = ih, pw = pw, ph = ph, gap = gap,
        pillSize = pillSize, totalW = totalW, rowH = rowH,
        hpBarY = hpBarY, rowY = rowY, resistW = resistW,
        rect = { x = left, y = top, w = right - left, h = groundY - top },
    }
end

function EnemyHud.draw(game, bbox, fallbackCx, fallbackGroundY)
    if not game or not game.enemy or game.enemy:isDefeated() then return end
    local L = EnemyHud.layout(game, bbox, fallbackCx, fallbackGroundY)

    if L.totalW > 0 then
        local startX = math.floor(L.cx - L.totalW / 2)
        if L.iw > 0 then
            local boxY = L.rowY + math.floor((L.rowH - L.ih) / 2)
            EnemyHud.drawIntent(game.enemy, L.cx, L.topY, startX, boxY, game.player)
        end
        if L.pw > 0 then
            local pillsX = startX + (L.iw > 0 and (L.iw + L.gap) or 0)
            local pillsY = L.rowY + math.floor((L.rowH - L.ph) / 2)
            EnemyHud.drawStatusEffects(game.enemy, L.cx, L.groundY, pillsX, pillsY, L.pillSize)
        end
    end

    EnemyHud.drawHpBar(game.enemy, L.cx, L.groundY, L.sw, L.hpBarY)
    EnemyHud.drawResistances(game.enemy, L)
end

function EnemyHud.resistAnchor(L)
    local bar = EnemyHud.hpBarRect(L)
    if not bar then return nil end
    return bar.x - EnemyHud.RESIST_GAP, bar.y + bar.h / 2
end

function EnemyHud.drawResistances(enemy, L)
    if not enemy or not L then return 0 end
    local rx, cy = EnemyHud.resistAnchor(L)
    if not rx then return 0 end
    return ResistBadges.draw(enemy, rx, cy)
end

return EnemyHud
