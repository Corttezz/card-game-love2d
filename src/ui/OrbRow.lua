-- src/ui/OrbRow.lua
-- Fileira de orbes do jogador (identidade Defect/StS trazida pra tela).
-- Resolve a "mecânica fantasma" (Jul/2026): canalizar não tinha NENHUM
-- feedback visual — orbes viviam só em player.orbs e toasts passageiros.
--
-- O que mostra (espelho de orbs/AbstractOrb.java do StS descompilado):
--   - TODOS os slots (vazio = aro apagado) — ensina o cap de 3 antes de doer;
--   - cada orbe com o VALOR DO PULSO escrito nele (base+Foco, ao vivo — a
--     fórmula vem de EffectSystem.orbPulseValue, fonte única);
--   - fila FIFO: o mais à esquerda é o mais antigo (= próximo a evocar,
--     marcado com um triângulo);
--   - hover → StatusTooltip com pulso e evoke exatos;
--   - preview de evoke: mão sobre carta de Evocar → orbe(s) afetado(s)
--     acendem em ciano e o número vira o VALOR DE EVOKE (showEvokeValue
--     do StS);
--   - animações: pop-in ao canalizar, flash+número flutuante no pulso do
--     fim de turno, flash branco ao evocar.
--
-- Módulo singleton (padrão EnemyHud): EffectSystem notifica via
-- OrbRow.notifyChannel/notifyPulse/notifyEvoke (pcall — headless = no-op).

local Palette = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local IconLoader = require("src.ui.IconLoader")
local StatusTooltip = require("src.ui.StatusTooltip")

local OrbRow = {}

local SIZE = 42          -- diâmetro do slot
local SPACING = 10
local GAP_ABOVE_PILLS = 8

OrbRow.COLORS = {
    lightning = { 0.95, 0.85, 0.30 },
    ice       = { 0.45, 0.75, 0.95 },
    dark      = { 0.60, 0.40, 0.85 },
    fire      = { 0.95, 0.50, 0.20 },
    holy      = { 0.95, 0.90, 0.62 },
}
OrbRow.ICONS = {
    lightning = "bolt",
    ice       = "snowflake",
    dark      = "moon",
    fire      = "flame",
    holy      = "star",
}
local EVOKE_CYAN = { 0.25, 0.95, 0.95 }

-- Estado interno do singleton
local slotPos = nil       -- [i] = {x, y} (centro), calculado no draw
local slotAnim = {}       -- [i] = timer de pop-in (decai 1→0)
local pulseFlash = {}     -- [i] = timer de flash de pulso
local evokeFlash = {}     -- [i] = timer de flash de evoke
local animTime = 0
local previewMode = nil   -- nil | "evoke_one" | "evoke_all" | "channel"

local function decay(tbl, dt)
    for k, v in pairs(tbl) do
        tbl[k] = v - dt
        if tbl[k] <= 0 then tbl[k] = nil end
    end
end

-- ===== Notificações vindas do EffectSystem (pcall — nunca podem quebrar) ====

-- Orbe entrou no slot i (pop-in).
function OrbRow.notifyChannel(i)
    slotAnim[i] = 1.0
end

-- Orbe do slot i pulsou: flash + número flutuante saindo DO orbe.
-- kind: "damage" | "armor" | "heal" | "grow"
function OrbRow.notifyPulse(i, text, kind)
    pulseFlash[i] = 1.0
    if slotPos and slotPos[i] then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and FloatingText.spawn then
            local ftKind = (kind == "damage") and "damage"
                or (kind == "heal") and "heal" or "armor"
            FloatingText.spawn(text, slotPos[i].x, slotPos[i].y - SIZE * 0.7,
                { kind = ftKind, fontSize = 16, lift = 34 })
        end
    end
end

-- Orbe do slot i foi evocado (flash branco; o slot esvazia no próximo draw).
function OrbRow.notifyEvoke(i, orb)
    evokeFlash[i] = 1.0
    if slotPos and slotPos[i] then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and FloatingText.spawn then
            FloatingText.spawn("EVOCADO!", slotPos[i].x, slotPos[i].y - SIZE * 0.8,
                { kind = "movename", fontSize = 14, hold = 0.4, lift = 26 })
        end
    end
end

-- ===== Update/draw (chamados pelo HudManager) =====

function OrbRow.update(dt, game)
    animTime = animTime + (dt or 0)
    decay(slotAnim, (dt or 0) * 3)     -- pop-in ~0.33s
    decay(pulseFlash, (dt or 0) * 1.6) -- flash de pulso ~0.6s
    decay(evokeFlash, (dt or 0) * 1.6)

    -- Preview de evoke/canalização: carta da mão sob o mouse anuncia o que
    -- fará com os orbes ANTES do clique (contrato do intent congelado vale
    -- pros dois lados: o jogador também vê o próprio futuro).
    previewMode = nil
    if game and game.hand then
        for _, c in ipairs(game.hand) do
            if c.isHovered and c.effects then
                for _, e in ipairs(c.effects) do
                    if e.type == "evoke_all_orbs" then
                        previewMode = "evoke_all"
                    elseif e.type == "evoke_orb" and previewMode ~= "evoke_all" then
                        previewMode = "evoke_one"
                    elseif (e.type == "channel_orb" or e.type == "channel_per_turn")
                        and not previewMode then
                        previewMode = "channel"
                    end
                end
            end
        end
    end
end

-- É visível? Mago sempre (slots vazios ensinam o cap); outras classes só
-- quando algum orbe existir (evita ruído de HUD pra warrior/rogue).
local function isVisible(game)
    if not game or not game.player then return false end
    local p = game.player
    if (p.orbSlots or 0) <= 0 then return false end
    return game.selectedClass == "mage" or #(p.orbs or {}) > 0
end

-- Desenha a fileira. panelX/panelY = top-left do HudPlayerPanel; a fileira
-- fica ACIMA da row de buff pills (que fica acima do painel).
function OrbRow.draw(game, panelX, panelY)
    if not isVisible(game) then
        slotPos = nil
        return
    end
    local p = game.player
    local focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    local EffectSystem = require("src.systems.EffectSystem")

    local pillRow = 36 + 6 -- BADGE_SIZE + gap do PlayerBuffPills
    local startX = math.floor(panelX)
    local y = math.floor(panelY - pillRow - GAP_ABOVE_PILLS - SIZE)

    slotPos = {}
    local mx, my = love.mouse.getPosition()
    local font = FontManager.getResponsiveFont(0.024, 15)
    local smallFont = FontManager.getResponsiveFont(0.016, 10)

    for i = 1, (p.orbSlots or 3) do
        local x = startX + (i - 1) * (SIZE + SPACING)
        local cx, cy = x + SIZE / 2, y + SIZE / 2
        slotPos[i] = { x = cx, y = cy }
        local orb = p.orbs and p.orbs[i]

        -- bob sutil (orbes "flutuam", slots vazios não)
        local bob = orb and math.sin(animTime * 2.2 + i * 1.3) * 2 or 0
        cy = cy + bob

        if not orb then
            -- Slot VAZIO: aro apagado — o cap existe antes de importar.
            love.graphics.setColor(0.10, 0.07, 0.05, 0.55)
            love.graphics.circle("fill", cx, cy, SIZE / 2 - 2)
            love.graphics.setColor(0.45, 0.40, 0.32, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, SIZE / 2 - 2)
            -- Preview de canalização: próximo slot livre pisca convidando
            if previewMode == "channel" and (p.orbs and #p.orbs + 1 == i or (not p.orbs and i == 1)) then
                local blink = 0.5 + math.sin(animTime * 6) * 0.4
                love.graphics.setColor(0.95, 0.85, 0.30, blink * 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, SIZE / 2)
            end
        else
            local color = OrbRow.COLORS[orb.type] or { 0.7, 0.7, 0.7 }
            -- pop-in: escala 1.35→1.0
            local kick = slotAnim[i] or 0
            local scale = 1 + kick * 0.35
            local r = (SIZE / 2) * scale

            -- Este orbe está na mira do preview de evoke?
            local inEvokePreview = (previewMode == "evoke_all")
                or (previewMode == "evoke_one" and i == 1)

            -- Halo (pulsante; ciano se em preview de evoke)
            local haloC = inEvokePreview and EVOKE_CYAN or color
            local haloA = 0.30 * (0.75 + math.sin(animTime * 3 + i) * 0.25)
            if inEvokePreview then haloA = 0.55 + math.sin(animTime * 6) * 0.2 end
            love.graphics.setColor(haloC[1], haloC[2], haloC[3], haloA)
            love.graphics.circle("fill", cx, cy, r + 3)

            -- Corpo
            love.graphics.setColor(0.10, 0.07, 0.05, 0.95)
            love.graphics.circle("fill", cx, cy, r)
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 1)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, r)
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, r - 1)

            -- Flash de pulso (cor do orbe) / evoke (branco)
            local pf = pulseFlash[i]
            if pf then
                love.graphics.setColor(color[1], color[2], color[3], pf * 0.5)
                love.graphics.circle("fill", cx, cy, r)
            end
            local ef = evokeFlash[i]
            if ef then
                love.graphics.setColor(1, 1, 1, ef * 0.7)
                love.graphics.circle("fill", cx, cy, r + 2)
            end

            -- Ícone do elemento (pequeno, no topo do orbe)
            local icon = IconLoader.get(OrbRow.ICONS[orb.type] or "orb")
            if icon and icon.draw then
                local iconH = (icon.size and icon.size.h) or 16
                local iconW = (icon.size and icon.size.w) or 16
                local iscale = IconLoader.computeScale(iconH, math.floor(SIZE * 0.34))
                icon.draw(math.floor(cx - iconW * iscale / 2),
                    math.floor(cy - r * 0.62), iscale)
            end

            -- NÚMERO central: pulso por padrão; vira EVOKE (ciano) no preview.
            -- Dark não pulsa — mostra o valor acumulado (o que dobra ao evocar).
            local shown, numC
            if inEvokePreview then
                shown = EffectSystem.orbEvokeValue(orb, focus)
                numC = EVOKE_CYAN
            elseif orb.type == "dark" then
                shown = (orb.value or 1)
                numC = color
            else
                shown = EffectSystem.orbPulseValue(orb, focus)
                numC = { 1, 1, 1 }
            end
            love.graphics.setFont(font)
            local txt = tostring(shown)
            local tw = font:getWidth(txt)
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.print(txt, cx - tw / 2 + 1, cy - font:getHeight() / 2 + 3)
            love.graphics.setColor(numC[1], numC[2], numC[3], 1)
            love.graphics.print(txt, cx - tw / 2, cy - font:getHeight() / 2 + 2)

            -- Marcador de "próximo a evocar" (fila FIFO): triângulo sob o 1º
            if i == 1 and #p.orbs > 0 then
                love.graphics.setColor(0.85, 0.80, 0.65, 0.85)
                love.graphics.polygon("fill",
                    cx - 4, y + SIZE + 3, cx + 4, y + SIZE + 3, cx, y + SIZE + 8)
                love.graphics.setFont(smallFont)
            end
        end

        -- Hover → tooltip com números exatos (stacks=pulso, duration=evoke —
        -- reuso do StatusTooltip; as descs de status.orb_* nomeiam os campos).
        if mx >= x and mx <= x + SIZE and my >= y and my <= y + SIZE then
            if orb then
                StatusTooltip.show("orb_" .. orb.type, mx, my, {
                    stacks = EffectSystem.orbPulseValue(orb, focus),
                    duration = EffectSystem.orbEvokeValue(orb, focus),
                })
            else
                StatusTooltip.show("orb_empty", mx, my, {
                    stacks = p.orbSlots or 3, duration = 0,
                })
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return OrbRow
