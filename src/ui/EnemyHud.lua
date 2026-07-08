-- src/ui/EnemyHud.lua
-- HP bar e intent icon ancorados no sprite do inimigo (estilo Slay the Spire).
-- Renderiza FORA do HudManager para ficar próximo ao sprite ao invés de num painel de canto.
--
-- Uso em main.lua após EnemyRenderer.draw():
--   local bbox = EnemyRenderer.draw(game, cx, cy)
--   EnemyHud.draw(game, bbox, cx, cy)
--
-- Se bbox for `false` (sprite não carregado), cai em posição default.

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local IconLoader = require("src.ui.IconLoader")

local EnemyHud = {}

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Cache dos ícones de intent (preguiçoso).
local intentIcons = {}
local function getIntentIcon(kind)
    kind = kind or "attack"
    if intentIcons[kind] ~= nil then return intentIcons[kind] or nil end
    local name = "intent_attack"
    if kind == "defense" or kind == "defend" then
        name = "intent_defense"
    elseif kind == "buff" then
        name = "status_strength"
    end
    local icon = IconLoader.get(name)
    intentIcons[kind] = icon or false
    return icon
end

-- Preview do intent (F1 gameplay-overhaul): usa Enemy:getIntentPreview se
-- existir (kind + valor já com weak/strong aplicados); fallback legado =
-- ataque com enemy.damage.
local function intentPreview(enemy)
    if enemy.getIntentPreview then
        return enemy:getIntentPreview()
    end
    local dmg = enemy.damage or 0
    if enemy.hasStatus and enemy:hasStatus("weak") then
        dmg = math.floor(dmg * 0.75)
    end
    return "attack", dmg
end

-- ===== HP BAR =====
-- Por default fica sob os pés do sprite. Se `barYOverride` for passado, desenha
-- naquele Y (usado pra posicionar HP acima do sprite, logo abaixo do intent row).
function EnemyHud.drawHpBar(enemy, cx, groundY, spriteWidth, barYOverride)
    if not enemy then return end

    local barW = math.max(160, math.min(260, spriteWidth + 40))
    local barH = 10
    local x = math.floor(cx - barW / 2)
    local y = barYOverride or math.floor(groundY + 10)

    -- Usa valor eased (enemy.disp.health) pra feedback Balatro-style.
    -- Enemy:update(dt) tickDa o easing. Fallback ao real se disp não existe.
    local hpReal = enemy.health or 0
    local hp = math.floor(((enemy.disp and enemy.disp.health) or hpReal) + 0.001)
    local maxHp = enemy.maxHealth or 1
    local pct = math.max(0, math.min(1, hp / maxHp))

    -- Sombra sob a barra
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 1, y + 2, barW, barH, 2, 2)

    -- Track
    love.graphics.setColor(0.10, 0.06, 0.04, 0.95)
    love.graphics.rectangle("fill", x, y, barW, barH, 2, 2)

    -- Fill (vermelho sangue; escurece em HP baixo pra urgência visual)
    local fillR, fillG, fillB = Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3]
    if pct < 0.3 then
        fillR = fillR * 1.2 -- mais saturado
    end
    love.graphics.setColor(fillR, fillG, fillB, 1)
    love.graphics.rectangle("fill", x, y, barW * pct, barH, 2, 2)

    -- Highlight topo
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.rectangle("fill", x, y, barW * pct, 3, 2, 2)

    -- Outline tinta
    setColor(Palette.INK, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, barW, barH, 2, 2)

    -- Número HP centralizado (branco outline preto)
    local font = FontManager.getResponsiveFont(0.02, 13)
    love.graphics.setFont(font)
    local txt = hp .. " / " .. maxHp
    local tw = font:getWidth(txt)
    local tx = math.floor(cx - tw / 2)
    local ty = y - font:getHeight() - 1
    -- Quiver Balatro-style: HP crítico (< 25%) faz o número tremer randomicamente.
    -- Replica engine/text.lua:198 do Balatro, mas inline (sem DynaText) pra
    -- minimizar overhead num path quente. Intensidade escala com proximidade da morte.
    if pct < 0.25 and pct > 0 then
        local intensity = (0.25 - pct) / 0.25  -- 0..1 conforme HP cai
        tx = tx + (math.random() - 0.5) * 2 * intensity
        ty = ty + (math.random() - 0.5) * 2 * intensity
    end
    -- Outline pra garantir legibilidade sobre o sprite
    FontManager.drawWithOutline(txt, tx, ty, { 1, 1, 1, 1 }, 0.9)

    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== STATUS EFFECT BADGES (sob o HP bar) =====
-- Delega pro componente StatusPill (fonte única de COLORS/ICONS + renderização).

local StatusPill = require("src.ui.StatusPill")

local BADGE_SIZE = 42
local BADGE_SPACING = 10

-- Dimensions da row de status pills (sem desenhar). Útil pra layout.
function EnemyHud.getStatusPillsDims(enemy)
    if not enemy or not enemy.statusEffects then return 0, 0 end
    return StatusPill.getRowDims(#enemy.statusEffects, BADGE_SIZE, BADGE_SPACING)
end

-- Desenha os pills começando em (startX, startY) top-left.
-- Se startX/startY forem nil, cai em fallback centralizado em cx/groundY (legado).
function EnemyHud.drawStatusEffects(enemy, cx, groundY, startX, startY)
    if not enemy or not enemy.statusEffects or #enemy.statusEffects == 0 then return end

    if not startX then
        local total = StatusPill.getRowDims(#enemy.statusEffects, BADGE_SIZE, BADGE_SPACING)
        startX = math.floor(cx - total / 2)
    end
    local y = startY or math.floor(groundY + 38)

    StatusPill.drawRow(enemy.statusEffects, startX, y, {
        size = BADGE_SIZE,
        spacing = BADGE_SPACING,
        pulseHalo = false, -- debuffs do inimigo têm halo estático
    })
end

-- ===== INTENT (acima do sprite) =====
-- Estilo Slay the Spire: ícone de ataque pequeno + número do dano grande ao lado.
-- Mais compacto horizontalmente que vertical, deixa o sprite respirar.

-- Dimensions do box do intent (sem desenhar). Útil pra layout.
function EnemyHud.getIntentDims(enemy)
    if not enemy then return 0, 0 end
    local _, value = intentPreview(enemy)
    if not value or value <= 0 then return 0, 0 end
    local font = FontManager.getResponsiveFont(0.032, 22)
    local tw = font:getWidth(tostring(value))
    local iconSize, gap, padX, padY = 24, 4, 8, 6
    return iconSize + gap + tw + padX * 2, iconSize + padY * 2
end

-- Desenha o intent box. Se boxXOverride/boxYOverride forem nil, centraliza em cx.
function EnemyHud.drawIntent(enemy, cx, topY, boxXOverride, boxYOverride)
    if not enemy then return end
    local kind, value = intentPreview(enemy)
    if not value or value <= 0 then return end
    local isAttack = (kind == "attack" or kind == "strong")

    -- Layout horizontal: ícone 24x24 + número grande ao lado
    local font = FontManager.getResponsiveFont(0.032, 22)
    local txt = (kind == "buff" and "+" or "") .. tostring(value)
    local tw = font:getWidth(txt)

    local iconSize = 24
    local gap = 4
    local contentW = iconSize + gap + tw
    local padX, padY = 8, 6
    local boxW = contentW + padX * 2
    local boxH = iconSize + padY * 2
    local boxX = boxXOverride or math.floor(cx - boxW / 2)
    local boxY = boxYOverride or math.floor(topY - boxH - 10)

    -- Sombra do box
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", boxX + 2, boxY + 3, boxW, boxH, 5, 5)

    -- Fundo pergaminho escuro
    setColor(Palette.PARCHMENT_DARK, 0.97)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    -- Cor semântica do intent: sangue = ataque, aço = defesa, ouro = buff.
    local accent = Palette.BLOOD
    if kind == "defend" then
        accent = Palette.STEEL or { 0.55, 0.62, 0.70, 1 }
    elseif kind == "buff" then
        accent = Palette.AGED_GOLD
    end

    -- Flash pulsante (mais forte no ataque "strong" — perigo iminente)
    local pulseSpeed = (kind == "strong") and 5 or 3
    local pulse = 0.5 + math.sin(love.timer.getTime() * pulseSpeed) * 0.5
    local pulseBase = (kind == "strong") and 0.24 or 0.15
    love.graphics.setColor(accent[1], accent[2], accent[3], pulseBase + pulse * 0.08)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    -- Borda tinta
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 5, 5)

    -- Accent na cor do intent (faixa interna)
    setColor(accent, 0.75)
    love.graphics.rectangle("line", boxX + 2, boxY + 2, boxW - 4, boxH - 4, 4, 4)

    -- Ícone do intent real (attack/strong/defend/buff)
    local icon = getIntentIcon(kind)
    if icon and icon.draw then
        local iconH = (icon.size and icon.size.h) or 16
        local iw = (icon.size and icon.size.w) or 16
        local scale = IconLoader.computeScale(iconH, iconSize)
        local iconX = boxX + padX + math.floor((iconSize - iw * scale) / 2)
        local iconY = boxY + padY + math.floor((iconSize - iconH * scale) / 2)
        icon.draw(iconX, iconY, scale)
    end

    -- Número à direita, na cor semântica do intent
    love.graphics.setFont(font)
    local tx = boxX + padX + iconSize + gap
    local ty = boxY + math.floor((boxH - font:getHeight()) / 2)
    local numColor = { 1, 0.3, 0.3, 1 }                     -- ataque: vermelho
    if kind == "defend" then numColor = { 0.65, 0.75, 0.9, 1 }
    elseif kind == "buff" then numColor = { 1, 0.85, 0.4, 1 } end
    FontManager.drawWithOutline(txt, tx, ty, numColor, 0.95)

    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== MAIN ENTRY =====
-- bbox: table (from EnemyRenderer.draw) ou false se sprite não renderizou.
-- Layout TOP-STACK (tudo acima do sprite):
--   Linha 1 (mais alta): intent + status pills lado a lado, centralizados
--   Linha 2: HP bar com número acima do bar
--   Linha 3: sprite
-- Deixa a área inferior livre pra cartas da mão.
function EnemyHud.draw(game, bbox, fallbackCx, fallbackGroundY)
    if not game or not game.enemy or game.enemy:isDefeated() then return end

    local cx, groundY, topY, sw
    if type(bbox) == "table" then
        cx, groundY, topY, sw = bbox.cx, bbox.bottomY, bbox.topY, bbox.width
    else
        cx = fallbackCx or love.graphics.getWidth() / 2
        groundY = fallbackGroundY or love.graphics.getHeight() * 0.55
        topY = groundY - 180
        sw = 160
    end

    -- Layout: o cluster inteiro fica acima do sprite.
    -- Espaço necessário pra HP: 13pt font (número) + 4 gap + 10 bar = ~27px
    local iw, ih = EnemyHud.getIntentDims(game.enemy)
    local pw, ph = EnemyHud.getStatusPillsDims(game.enemy)
    local gap = 10
    local bothPresent = (iw > 0 and pw > 0)
    local totalW = iw + (bothPresent and gap or 0) + pw
    local rowH = math.max(ih, ph)

    local hpBlockH = 27      -- número + gap + bar
    local rowGap = 6         -- gap entre row de intent/pills e HP bar
    local topMargin = 8      -- gap do cluster até o topo do sprite

    -- HP bar fica logo acima do sprite; row de intent/pills fica acima do HP bar.
    local hpBarY = math.floor(topY - topMargin - 10) -- 10 = barH
    local rowY = math.floor(hpBarY - rowGap - 13 - rowH) -- 13 = font HP number

    -- Desenha row (intent + pills) se existir
    if totalW > 0 then
        local startX = math.floor(cx - totalW / 2)
        if iw > 0 then
            local boxY = rowY + math.floor((rowH - ih) / 2)
            EnemyHud.drawIntent(game.enemy, cx, topY, startX, boxY)
        end
        if pw > 0 then
            local pillsX = startX + (iw > 0 and (iw + gap) or 0)
            local pillsY = rowY + math.floor((rowH - ph) / 2)
            EnemyHud.drawStatusEffects(game.enemy, cx, groundY, pillsX, pillsY)
        end
    end

    -- HP bar com número acima, posicionado explicitamente
    EnemyHud.drawHpBar(game.enemy, cx, groundY, sw, hpBarY)
end

return EnemyHud
