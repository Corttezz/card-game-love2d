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
local animTime = 0
local previewMode = nil   -- nil | "evoke_one" | "evoke_all" | "channel"

-- DIREÇÃO É A PALAVRA (Set/2026, pedido do dono jogando de mago: "canaliza
-- muitas ao mesmo tempo, fica confuso se está dando dano ou se canalizando").
-- Dano vai PARA o inimigo; canalizar vem PARA a fileira; evocar SAI da fileira.
-- Duas listas de FX resolvem os dois sentidos que faltavam:
--   inbound[i] — o orbe está VIAJANDO até o slot i (o slot fica vazio e um
--                cometa da cor do elemento entra na tela até pousar);
--   outbound   — fantasma do orbe que DEIXOU o slot, subindo rumo ao combate.
-- Sem isso o orbe simplesmente aparecia/sumia: mesma leitura de "explodiu algo".
local inbound = {}        -- [i] = { t, dur, color }
local outbound = {}       -- array de { slot, t, dur, color, icon, label }

local FLIGHT_IN  = 0.26   -- s: o cometa tem que pousar DENTRO do beat ORB (0.40)
local FLIGHT_OUT = 0.45

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function decay(tbl, dt)
    for k, v in pairs(tbl) do
        tbl[k] = v - dt
        if tbl[k] <= 0 then tbl[k] = nil end
    end
end

-- Origem do cometa de canalização: o centro do palco, onde a carta resolve.
-- Não é o ponto exato da carta (o EffectSystem não o conhece), e não precisa
-- ser: o que a animação afirma é "isto veio do feitiço e foi PARA a fileira".
local function spellOrigin()
    return love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.52
end

-- ===== Notificações vindas do EffectSystem (pcall — nunca podem quebrar) ====

-- Orbe entrou no slot i: ele VIAJA do feitiço até o slot e só então nasce
-- (pop-in). `orb` opcional dá a cor do elemento ao cometa.
function OrbRow.notifyChannel(i, orb)
    if reducedMotion() then
        -- Tira o MOVIMENTO, nunca a INFORMAÇÃO: sem viagem, mas o orbe ainda
        -- nasce no instante do beat dele (a ordem continua legível).
        slotAnim[i] = 1.0
        return
    end
    inbound[i] = {
        t = 0, dur = FLIGHT_IN,
        color = OrbRow.COLORS[orb and orb.type] or { 0.85, 0.85, 0.85 },
    }
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

-- Orbe do slot i SAIU da fileira. `reason`:
--   "evoke"    — o jogador evocou (a carta pediu);
--   "overflow" — a fileira estava cheia e o mais antigo foi EXPULSO pra abrir
--                vaga. É um acontecimento diferente e precisa dizer isso, senão
--                o jogador vê um orbe sumir e não entende por quê.
function OrbRow.notifyEvoke(i, orb, reason)
    local I18n = require("src.i18n.I18n")
    local isOverflow = (reason == "overflow")
    local label = isOverflow
        and I18n.t("orb.expelled", nil, "EXPULSO")
        or I18n.t("orb.evoked", nil, "EVOCADO")
    local color = OrbRow.COLORS[orb and orb.type] or { 0.95, 0.90, 0.78 }
    if isOverflow then color = { 0.95, 0.72, 0.30 } end

    outbound[#outbound + 1] = {
        slot = i, t = 0, dur = reducedMotion() and 0.0001 or FLIGHT_OUT,
        color = color, icon = orb and OrbRow.ICONS[orb.type] or nil,
    }
    if slotPos and slotPos[i] then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and FloatingText.spawn then
            -- O FloatingText e CENTRADO no x, e o slot 1 fica colado na borda
            -- esquerda: sem esta margem o rotulo sai da tela pela metade
            -- ("XPULSO" na captura de validacao).
            local half = FontManager.getFont(14):getWidth(label) * 0.5
            local x = math.max(slotPos[i].x, half + 6)
            FloatingText.spawn(label, x, slotPos[i].y - SIZE * 0.8,
                { color = color, fontSize = 14, hold = 0.4, lift = 26 })
        end
    end
end

-- ===== Update/draw (chamados pelo HudManager) =====

function OrbRow.update(dt, game)
    animTime = animTime + (dt or 0)
    decay(slotAnim, (dt or 0) * 3)     -- pop-in ~0.33s
    decay(pulseFlash, (dt or 0) * 1.6) -- flash de pulso ~0.6s

    -- Cometa de canalização: quando POUSA, o orbe nasce (pop-in). Enquanto
    -- voa, o slot continua desenhado vazio — o orbe está em trânsito, não lá.
    for i, fx in pairs(inbound) do
        fx.t = fx.t + (dt or 0)
        if fx.t >= fx.dur then
            inbound[i] = nil
            slotAnim[i] = 1.0
        end
    end
    -- Fantasma do orbe que saiu (evoke/overflow).
    for k = #outbound, 1, -1 do
        local fx = outbound[k]
        fx.t = fx.t + (dt or 0)
        if fx.t >= fx.dur then table.remove(outbound, k) end
    end

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

    -- Zona: a fileira de orbes empilha a partir do TOPO da banda de pills.
    -- A altura da banda é do PlayerBuffPills (fonte única) — antes isso era o
    -- número mágico "36 + 6" repetido aqui, que silenciosamente quebraria se a
    -- banda mudasse de tamanho (ui_layout_invariants §1).
    local PlayerBuffPills = require("src.ui.PlayerBuffPills")
    local startX = math.floor(panelX)
    local y = math.floor(PlayerBuffPills.getBandTop(panelY) - GAP_ABOVE_PILLS - SIZE)

    slotPos = {}
    local mx, my = love.mouse.getPosition()
    local font = FontManager.getResponsiveFont(0.024, 15)
    local smallFont = FontManager.getResponsiveFont(0.016, 10)

    for i = 1, (p.orbSlots or 3) do
        local x = startX + (i - 1) * (SIZE + SPACING)
        local cx, cy = x + SIZE / 2, y + SIZE / 2
        slotPos[i] = { x = cx, y = cy }
        -- Orbe em TRÂNSITO ainda não está no slot: o cometa é que o carrega.
        local orb = (not inbound[i]) and p.orbs and p.orbs[i] or nil

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
            -- (Nao existe mais "flash de evoke no slot": quando um orbe sai, a
            -- fila ANDA e o slot ja e de outro orbe — o flash acendia o orbe
            -- errado. Quem conta a saida e o FANTASMA em _drawFx, desenhado na
            -- posicao de onde o orbe saiu.)

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

    OrbRow._drawFx()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Os dois SENTIDOS desenhados. Cometa ENTRANDO (canalizar) e fantasma SAINDO
-- (evocar/expulsar) — a mesma fileira, gestos opostos, para o jogador nunca
-- confundir "ganhei um orbe" com "um orbe agiu".
function OrbRow._drawFx()
    if not slotPos then return end

    -- ENTRANDO: do centro do palco até o slot, acelerando (ease-in quad) —
    -- chega e "pousa", em vez de deslizar e parar.
    local ox, oy = spellOrigin()
    for i, fx in pairs(inbound) do
        local pos = slotPos[i]
        if pos then
            local k = math.min(1, fx.t / fx.dur)
            local e = k * k
            local x = ox + (pos.x - ox) * e
            local y = oy + (pos.y - oy) * e
            local c = fx.color
            -- rastro: 4 cópias atrás, cada vez mais fracas
            for tr = 4, 1, -1 do
                local et = math.max(0, e - tr * 0.06)
                local tx = ox + (pos.x - ox) * et
                local ty = oy + (pos.y - oy) * et
                love.graphics.setColor(c[1], c[2], c[3], 0.16 * (5 - tr))
                love.graphics.circle("fill", tx, ty, SIZE * 0.13 * (1 - tr * 0.12))
            end
            love.graphics.setColor(c[1], c[2], c[3], 0.35)
            love.graphics.circle("fill", x, y, SIZE * 0.30)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", x, y, SIZE * 0.14)
        end
    end

    -- SAINDO: o fantasma sobe do slot rumo ao combate, encolhendo e apagando.
    for _, fx in ipairs(outbound) do
        local pos = slotPos[fx.slot]
        if pos then
            local k = math.min(1, fx.t / fx.dur)
            local e = 1 - (1 - k) * (1 - k)          -- ease-out
            local tx, ty = spellOrigin()
            local x = pos.x + (tx - pos.x) * e * 0.55
            local y = pos.y + (ty - pos.y) * e * 0.55
            local r = (SIZE / 2) * (1 - e * 0.55)
            local c, a = fx.color, 1 - k
            love.graphics.setColor(c[1], c[2], c[3], 0.70 * a)
            love.graphics.circle("fill", x, y, r + 5)
            love.graphics.setColor(0.10, 0.07, 0.05, 0.75 * a)
            love.graphics.circle("fill", x, y, r)
            love.graphics.setColor(1, 1, 1, 0.95 * a)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", x, y, r)
            local icon = fx.icon and IconLoader.get(fx.icon)
            if icon and icon.draw then
                local iw = (icon.size and icon.size.w) or 16
                local ih = (icon.size and icon.size.h) or 16
                local sc = IconLoader.computeScale(ih, math.floor(SIZE * 0.34))
                love.graphics.setColor(1, 1, 1, a)
                icon.draw(math.floor(x - iw * sc / 2), math.floor(y - ih * sc / 2), sc)
            end
        end
    end
end

return OrbRow
