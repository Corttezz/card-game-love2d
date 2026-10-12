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

-- Cache dos ícones de intent (preguiçoso). Mapa kind -> ícone: o kind é a
-- categoria de LEITURA do golpe (src/data/enemies.lua).
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
        print("[EnemyHud] ícone de intent ausente: " .. tostring(name))
    end
    intentIcons[name] = icon or false
    return icon
end
local function getIntentIcon(kind)
    -- kind sem ícone declarado = "?" (desconhecido), nunca um ataque falso
    -- (fallback silencioso proibido: getIconByName já avisa se faltar PNG).
    return getIconByName(INTENT_ICON[kind or "attack"] or "intent_unknown")
end

-- Ícone do status de um debuff (pequeno, ao lado do número).
local DEBUFF_ICON = {
    -- debuffs que o golpe aplica NO JOGADOR: mesmos ícones das pills dele
    weak = "status_weak_self", vulnerable = "status_vulnerable_self",
    frail = "status_frail",
    poison = "status_poison", burn = "status_burn",
}

-- Preview do intent (F1 gameplay-overhaul): usa Enemy:getIntentPreview se
-- existir (kind + valor já com weak/vulnerável aplicados); fallback legado =
-- ataque com enemy.damage.
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

-- O que o box do intent mostra — fonte ÚNICA do desenho, da medida e do
-- tooltip (o número desenhado e o número explicado não podem divergir).
--   text    "12" | "4×3" | "+5" | nil (golpe sem número: debuff/carga/invocação)
--   extras  ícones pequenos depois do número (debuffs do golpe, bloqueio)
--   pierce  golpe que atravessa o Bloqueio (marca vermelha no box)
--   title/body  tooltip: nome do golpe + linhas montadas dos números CONGELADOS
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
    -- PERFURANTE: ícone próprio (lança furando placa) logo depois do número
    -- — o risco vermelho sobre o ícone do ataque lia como "ataque cancelado".
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

    local title = I18n.t("enemy_kit.moves." .. tostring(it.id or kind) .. ".name", nil,
        I18n.t("status.intent_" .. tostring(kind) .. ".name", nil, tostring(kind)))
    -- Golpe pesado tem hierarquia visual (maior, pulsa mais rápido).
    local heavy = (kind == "strong") or (kind == "charge")
    return {
        kind = kind, value = value or 0, text = text, extras = extras,
        pierce = it.pierce and true or false, heavy = heavy,
        title = title, body = table.concat(lines, " "),
    }
end

-- Banda de largura de um ícone extra e do vão entre eles.
local EXTRA_ICON = 24
local EXTRA_GAP = 3

-- ===== HP BAR =====
-- Por default fica sob os pés do sprite. Se `barYOverride` for passado, desenha
-- naquele Y (usado pra posicionar HP acima do sprite, logo abaixo do intent row).
-- Geometria da barra (fonte unica: o desenho abaixo e a previa de dano —
-- src/ui/DamagePreviewPanel — leem daqui).
local function hpBarGeom(cx, groundY, spriteWidth, barYOverride)
    local barW = math.max(160, math.min(260, spriteWidth + 40))
    local barH = 10
    local x = math.floor(cx - barW / 2)
    local y = barYOverride or math.floor(groundY + 10)
    return x, y, barW, barH
end

-- Rect da barra de vida a partir do layout (EnemyHud.layout).
function EnemyHud.hpBarRect(L)
    if not L then return nil end
    local x, y, w, h = hpBarGeom(L.cx, L.groundY, L.sw, L.hpBarY)
    return { x = x, y = y, w = w, h = h }
end

function EnemyHud.drawHpBar(enemy, cx, groundY, spriteWidth, barYOverride)
    if not enemy then return end

    local x, y, barW, barH = hpBarGeom(cx, groundY, spriteWidth, barYOverride)

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

-- Estados do inimigo que mudam as regras e não viviam em statusEffects:
--   block   — enemy.armor, ganho pelo intent "defender". Era INVISÍVEL: o
--             jogador batia e o dano sumia sem explicação.
--   enraged — enemy.attackPattern == "aggressive" (abaixo de 30% de vida o
--             dano vira ×1.5 em Enemy:takeDamage:101). Acontece em TODA batalha
--             e era invisível: sem pill, sem toast, sem som — o número do
--             intent simplesmente subia. Provavelmente o estado escondido mais
--             caro do jogo, porque muda a conta do dano que o jogador leva.
-- Ambos são derivados (leitura pura) — nada é escrito no inimigo aqui.
--
-- FORWARD-COMPAT (combinado com o dono do Enemy.lua): se um dia a fúria virar
-- um status de verdade em `enemy.statusEffects` (nome esperado: "enraged"), a
-- lista de lá VENCE e o derivado é suprimido — assim a transição não duplica a
-- pill em nenhum dos dois lados, aconteça na ordem que acontecer.
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
    for _, e in ipairs(enemy.statusEffects or {}) do
        list[#list + 1] = e
    end
    return list
end

-- Dimensions da row de status pills (sem desenhar). Útil pra layout.
-- `size` opcional: o caller passa o tamanho já ajustado à largura disponível.
function EnemyHud.getStatusPillsDims(enemy, size)
    local pills = EnemyHud.collectPills(enemy)
    return StatusPill.getRowDims(#pills, size or BADGE_SIZE, BADGE_SPACING)
end

-- Desenha os pills começando em (startX, startY) top-left.
-- Se startX/startY forem nil, cai em fallback centralizado em cx/groundY (legado).
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
        pulseHalo = false, -- debuffs do inimigo têm halo estático
    })
end

-- ===== INTENT (acima do sprite) =====
-- Estilo Slay the Spire v2 (telegrafia Jul/2026): ícone GRANDE + número, bob
-- vertical contínuo (o olho acha movimento), escala por severidade (strong é
-- maior e pulsa mais rápido) e FLASH DE EXECUÇÃO quando o turno inimigo
-- começa ("é AGORA que ele faz o que anunciou" — IntentFlashAction do StS).

-- Flash de execução: Game:enemyTurn chama EnemyHud.flashIntent() antes de
-- despachar a ação; o box dá zoom+glow por ~0.55s.
local flashUntil = 0
local FLASH_DUR = 0.55
function EnemyHud.flashIntent()
    flashUntil = love.timer.getTime() + FLASH_DUR
end

local ICON_SIZE = 34   -- era 24 — pequeno demais pra ler de relance
-- O set de intents (Out/2026, v2) é desenhado NATIVO em 32x32: computeScale
-- (32, 34) = 1, pixel 1:1. PNG maior que o alvo é reduzido por nearest
-- fracionário e o pixel picota — foi o defeito do set v1 (64px → 0.53).

-- Geometria do box (pura): largura do conteúdo = ícone + número + extras.
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

-- Dimensions do box do intent (sem desenhar). Útil pra layout.
-- `player` opcional (Vulnerável congelado entra no número).
function EnemyHud.getIntentDims(enemy, player)
    if not enemy then return 0, 0 end
    local spec = EnemyHud.intentSpec(enemy, player)
    if not spec then return 0, 0 end
    local g = intentBoxGeom(spec)
    local w, h = g.w, g.h
    -- Golpe pesado ocupa mais espaço (o layout do cluster respeita).
    if spec.heavy then
        w = math.floor(w * 1.12)
        h = math.floor(h * 1.12)
    end
    return w, h
end

-- Desenha o intent box. Se boxXOverride/boxYOverride forem nil, centraliza em cx.
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

    -- Bob vertical contínuo (StS: o intent "flutua" — movimento chama o olho).
    if not rm then
        boxY = boxY + math.floor(math.sin(now * 2.2) * 3 + 0.5)
    end

    -- Escala: golpe pesado é maior (perigo tem hierarquia) + flash de execução
    -- dá zoom no box inteiro. Transform centrado no box.
    local scaleK = spec.heavy and 1.12 or 1.0
    local flashK = 0
    if flashUntil > now then
        flashK = (flashUntil - now) / FLASH_DUR      -- 1→0
        scaleK = scaleK * (1 + 0.35 * flashK)        -- zoom out do flash
    end
    local usedTransform = scaleK ~= 1.0
    if usedTransform then
        local mcx, mcy = boxX + boxW / 2, boxY + boxH / 2
        love.graphics.push()
        love.graphics.translate(mcx, mcy)
        love.graphics.scale(scaleK, scaleK)
        love.graphics.translate(-mcx, -mcy)
    end

    -- Sombra do box
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", boxX + 2, boxY + 3, boxW, boxH, 5, 5)

    -- Fundo pergaminho escuro
    setColor(Palette.PARCHMENT_DARK, 0.97)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    -- Cor semântica do intent: sangue = ataque, aço = defesa, ouro = buff,
    -- violeta = debuff/carga (ameaça que não é dano agora), verde = cura.
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

    -- Flash pulsante (mais forte no golpe pesado — perigo iminente)
    local pulseSpeed = spec.heavy and 5 or 3
    local pulse = 0.5 + math.sin(love.timer.getTime() * pulseSpeed) * 0.5
    local pulseBase = spec.heavy and 0.24 or 0.15
    love.graphics.setColor(accent[1], accent[2], accent[3], pulseBase + pulse * 0.08)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    -- Borda tinta
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 5, 5)

    -- Accent na cor do intent (faixa interna)
    setColor(accent, 0.75)
    love.graphics.rectangle("line", boxX + 2, boxY + 2, boxW - 4, boxH - 4, 4, 4)

    -- Ícone do intent
    local icon = getIntentIcon(kind)
    if icon and icon.draw then
        local iconH = (icon.size and icon.size.h) or 16
        local iw = (icon.size and icon.size.w) or 16
        local scale = IconLoader.computeScale(iconH, iconSize)
        local iconX = boxX + padX + math.floor((iconSize - iw * scale) / 2)
        local iconY = boxY + padY + math.floor((iconSize - iconH * scale) / 2)
        icon.draw(iconX, iconY, scale)
    end

    -- Hover no box → tooltip com o NOME do golpe e o que ele faz, montado dos
    -- números congelados (intentSpec). Clareza total.
    do
        local mx, my = love.mouse.getPosition()
        if mx >= boxX and mx <= boxX + boxW and my >= boxY and my <= boxY + boxH then
            local StatusTooltip = require("src.ui.StatusTooltip")
            StatusTooltip.show("intent_" .. kind, mx, my,
                { value = spec.value, title = spec.title, body = spec.body })
        end
    end

    -- Número à direita, na cor semântica do intent
    local cursorX = boxX + padX + iconSize
    if txt then
        love.graphics.setFont(font)
        local tx = cursorX + gap
        local ty = boxY + math.floor((boxH - font:getHeight()) / 2)
        local numColor = { 1, 0.3, 0.3, 1 }                     -- ataque: vermelho
        if kind == "defend" then numColor = { 0.65, 0.75, 0.9, 1 }
        elseif kind == "buff" then numColor = { 1, 0.85, 0.4, 1 }
        elseif kind == "heal" then numColor = { 0.5, 0.95, 0.55, 1 } end
        FontManager.drawWithOutline(txt, tx, ty, numColor, 0.95)
        cursorX = tx + g.tw
    end

    -- Extras: ícones pequenos dos debuffs do golpe / bloqueio junto do ataque.
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

    -- FLASH DE EXECUÇÃO: lavagem branca + borda acesa enquanto o zoom decai
    -- ("o anúncio virou ação"). Desenhado por cima de tudo do box.
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

-- ===== MAIN ENTRY =====
-- bbox: table (from EnemyRenderer.draw) ou false se sprite não renderizou.
-- Layout TOP-STACK (tudo acima do sprite):
--   Linha 1 (mais alta): intent + status pills lado a lado, centralizados
--   Linha 2: HP bar com número acima do bar
--   Linha 3: sprite
-- Deixa a área inferior livre pra cartas da mão.
-- Geometria do cluster (intent + pills + HP) — PURA, sem desenhar. Fonte
-- única do draw e da régua do palco da batalha (tools/test_enemy_stage):
-- quem mede se o inimigo colide com a carta em hover precisa do MESMO
-- retângulo que a tela pinta. `rect` = união do cluster + sprite.
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

    -- Layout: o cluster inteiro fica acima do sprite.
    -- Espaço necessário pra HP: 13pt font (número) + 4 gap + 10 bar = ~27px
    local iw, ih = EnemyHud.getIntentDims(game.enemy, game.player)
    local gap = 10
    -- Zona: o cluster (intent + pills) não pode passar de 90% da largura da
    -- tela. Com estados novos (Bloqueio, Enfurecido) a row cresceu — quem cede
    -- é a ESCALA das pills, nunca a posição do intent (ui_layout_invariants §1).
    local pillCount = #EnemyHud.collectPills(game.enemy)
    local pillSize = StatusPill.fitSize(pillCount,
        love.graphics.getWidth() * 0.9 - iw - (iw > 0 and gap or 0),
        BADGE_SIZE, BADGE_SPACING)
    local pw, ph = EnemyHud.getStatusPillsDims(game.enemy, pillSize)
    local bothPresent = (iw > 0 and pw > 0)
    local totalW = iw + (bothPresent and gap or 0) + pw
    local rowH = math.max(ih, ph)

    local rowGap = 6         -- gap entre row de intent/pills e HP bar
    local topMargin = 8      -- gap do cluster até o topo do sprite

    -- HP bar fica logo acima do sprite; row de intent/pills fica acima do HP bar.
    local hpBarY = math.floor(topY - topMargin - 10) -- 10 = barH
    local rowY = math.floor(hpBarY - rowGap - 13 - rowH) -- 13 = font HP number

    local barW = math.max(160, math.min(260, sw + 40))
    local clusterW = math.max(totalW, barW)
    -- +3: bob do intent (±3px) — a régua mede o pior quadro, não o médio
    local top = (totalW > 0) and (rowY - 3) or (hpBarY - 13)
    local spriteL = cx - sw / 2
    local left = math.min(cx - clusterW / 2, spriteL)
    local right = math.max(cx + clusterW / 2, spriteL + sw)
    return {
        cx = cx, groundY = groundY, topY = topY, sw = sw,
        iw = iw, ih = ih, pw = pw, ph = ph, gap = gap,
        pillSize = pillSize, totalW = totalW, rowH = rowH,
        hpBarY = hpBarY, rowY = rowY,
        rect = { x = left, y = top, w = right - left, h = groundY - top },
    }
end

function EnemyHud.draw(game, bbox, fallbackCx, fallbackGroundY)
    if not game or not game.enemy or game.enemy:isDefeated() then return end
    local L = EnemyHud.layout(game, bbox, fallbackCx, fallbackGroundY)

    -- Desenha row (intent + pills) se existir
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

    -- HP bar com número acima, posicionado explicitamente
    EnemyHud.drawHpBar(game.enemy, L.cx, L.groundY, L.sw, L.hpBarY)
end

return EnemyHud
