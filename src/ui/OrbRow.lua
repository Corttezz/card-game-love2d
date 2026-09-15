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
local StatusTooltip = require("src.ui.StatusTooltip")

local OrbRow = {}

-- SIZE = 48 porque a arte é 48x48 NATIVA (assets/sprites/orbs/): desenhar 1:1
-- é o ponto inteiro de ter gerado no tamanho de uso. Reduzir pra 46 borraria a
-- pedra -- foi arte reduzida virando mancha que derrubou o ícone dentro do
-- orbe na rodada passada.
local SIZE = 48          -- lado da gema (1:1 com o PNG)
local SPACING = 12       -- medido: com 8 as placas vizinhas encostavam
local PLATE_H = 18       -- altura da placa do número (cabe fonte 13 + borda)
local GAP_GEM_PLATE = 2  -- a placa "pendura" na gema, não flutua
-- 16 (era 8): o trilho da fila mora ABAIXO das silhuetas e com 8 ele encostava
-- na banda de pills (visto na captura de validacao).
local GAP_ABOVE_PILLS = 16

OrbRow.COLORS = {
    lightning = { 0.95, 0.85, 0.30 },
    ice       = { 0.45, 0.75, 0.95 },
    dark      = { 0.60, 0.40, 0.85 },
    fire      = { 0.95, 0.50, 0.20 },
    holy      = { 0.95, 0.90, 0.62 },
}
-- (A tabela OrbRow.ICONS saiu: o PNG de 64x64 reduzido pra ~14px dentro do
-- orbe virava mancha -- foi o que a captura de validacao mostrou. Quem
-- identifica o elemento agora e a SILHUETA, e o nome continua no tooltip.)
local EVOKE_CYAN = { 0.25, 0.95, 0.95 }

-- ============================================================================
-- FORMA = ELEMENTO, GLIFO = UNIDADE (Set/2026)
-- ============================================================================
-- Pedido do dono, jogando: "está meio difícil de entender esses círculos ali".
-- A captura `lovec . preview_battle_hud orbs` (cinco tipos lado a lado, no
-- tamanho de uso, sobre o fundo real) mostrou por que: eram cinco DISCOS
-- iguais, QUATRO deles exibindo o mesmo "3", e o ícone do elemento renderizado
-- a ~14px virava uma mancha ilegível. Nada dizia que elemento era, nada dizia
-- o que o número significava, e a fileira era indistinguível da row de pills
-- logo abaixo (também redonda, também do mesmo tamanho).
--
-- Três problemas empilhados, três respostas separadas:
--
--   1. QUE elemento é  -> a SILHUETA. Cor sozinha não ensina, e ícone pequeno
--      não sobrevive ao tamanho de uso; a forma do contorno sobrevive.
--      losango / hexágono / chama / pentágono invertido / sol.
--   2. O QUE ele faz   -> um GLIFO DE UNIDADE ao lado do número, desenhado em
--      vetor (nada de PNG reduzido): X = dano, escudo = bloqueio, cruz = cura,
--      seta = cresce. Duplo-codificado com a cor do glifo.
--   3. QUAL sai primeiro -> trilho com seta apontando pra ESQUERDA sob a
--      fileira + aro duplo claro no próximo a evocar.
--
-- O ícone PNG do elemento saiu de dentro do orbe (era a mancha). Ele continua
-- valendo no fantasma de saída, onde tem espaço, e o nome do elemento continua
-- no tooltip de hover.

-- ARTE POR ELEMENTO: gema lapidada, 48x48 nativa, uma por elemento.
-- Set/2026: as silhuetas VETORIAIS que vieram antes resolveram a leitura
-- (distinguir os cinco de relance, e o glifo de unidade dizendo o que o número
-- era) mas o dono reprovou o visual -- "achei meio feio". O diagnóstico é
-- concreto: contorno colorido com INTERIOR VAZIO é wireframe, não objeto. Num
-- jogo de pixel art com bevel, sombra e desgaste, geometria chapada lê como
-- ícone de aplicativo -- e as pills logo abaixo (arte pixel dentro de aro)
-- pareciam melhores que os orbes.
--
-- O que MUDOU é o material; o que FICOU é a leitura: cada gema tem um corte
-- próprio (marquise / hexágono / gota / brilhante / estrela), o glifo de
-- unidade continua, o trilho FIFO continua e `readout` segue como fonte única.
OrbRow.ART = {
    lightning = "assets/sprites/orbs/lightning.png",
    ice       = "assets/sprites/orbs/ice.png",
    fire      = "assets/sprites/orbs/fire.png",
    dark      = "assets/sprites/orbs/dark.png",
    holy      = "assets/sprites/orbs/holy.png",
}

local ImageCache = require("src.ui.ImageCache")
local gemCache = {}
local warnedGem = {}
local function gemOf(orbType)
    if gemCache[orbType] ~= nil then return gemCache[orbType] or nil end
    local path = OrbRow.ART[orbType]
    local img = path and ImageCache.tryGet(path) or nil
    if img then
        img:setFilter("nearest", "nearest")
    elseif not warnedGem[orbType] then
        -- Fallback silencioso é proibido (CLAUDE.md §9): elemento sem gema AVISA.
        warnedGem[orbType] = true
        print("[OrbRow] sem arte de gema pra '" .. tostring(orbType)
            .. "' — registre em OrbRow.ART (esperado 48x48 nativo)")
    end
    gemCache[orbType] = img or false
    return img
end

-- UNIDADE do número. `mode` = "pulse" (fim de turno) ou "evoke" (ao evocar).
-- Fonte: EffectSystem.orbPulseValue / _evokeOrbEffect -- sombra NÃO pulsa (só
-- engorda) mas EVOCA como dano, e é justamente essa diferença que o glifo
-- ensina quando o jogador passa o mouse numa carta de Evocar.
local UNIT_OF = {
    pulse = { lightning = "damage", fire = "damage", ice = "block",
              holy = "heal", dark = "grow" },
    evoke = { lightning = "damage", fire = "damage", ice = "block",
              holy = "heal", dark = "damage" },
}
local UNIT_COLOR = {
    damage = { 1.00, 0.45, 0.35 },
    block  = { 0.58, 0.78, 1.00 },
    heal   = { 0.50, 0.95, 0.55 },
    grow   = { 0.80, 0.62, 1.00 },
}

-- Expostos pra trava de teste (tools/test_beats.lua bloco 4g): a unidade que o
-- orbe ANUNCIA tem que bater com o que o EffectSystem de fato faz, e duas
-- silhuetas nunca podem coincidir.
OrbRow.UNIT_OF = UNIT_OF

-- O QUE O ORBE DIZ: (valor, unidade). Fonte única do par número+glifo — o
-- desenho e o teste leem daqui.
--   mode "pulse" = fim de turno; "evoke" = ao ser evocado (preview de carta).
-- Sombra é o caso que justifica a função existir: ela NÃO pulsa, então o
-- "valor do pulso" dela é 0 e mostrar 0 seria mentira; o que cresce é o valor
-- acumulado, e é ELE que dobra no evoke.
-- Exposto pro tool de comparacao visual (tools/orb_compare.lua).

function OrbRow.readout(orb, focus, mode)
    local EffectSystem = require("src.systems.EffectSystem")
    if mode == "evoke" then
        return EffectSystem.orbEvokeValue(orb, focus), UNIT_OF.evoke[orb.type]
    end
    if orb.type == "dark" then
        return (orb.value or 1), UNIT_OF.pulse.dark
    end
    return EffectSystem.orbPulseValue(orb, focus), UNIT_OF.pulse[orb.type]
end

-- Glifos de unidade em VETOR, legíveis a ~9px (PNG reduzido não é).
local function drawUnitGlyph(unit, x, y, h)
    local a = h * 0.5
    love.graphics.setLineWidth(2)
    if unit == "damage" then
        -- Faisca de 4 pontas. NAO e um "X": na captura de validacao o X lia
        -- como MULTIPLICADOR ("x3"), que neste jogo e a linguagem dos coringas
        -- -- o glifo de dano estava dizendo a coisa errada.
        local w = a * 0.22   -- pontas finas: "faisca", nao "losango"
        love.graphics.polygon("fill",
            x, y - a,  x + w, y - w,  x + a, y,  x + w, y + w,
            x, y + a,  x - w, y + w,  x - a, y,  x - w, y - w)
    elseif unit == "block" then       -- escudo
        love.graphics.polygon("fill",
            x - a, y - a, x + a, y - a, x + a, y * 1 + a * 0.2,
            x, y + a, x - a, y + a * 0.2)
    elseif unit == "heal" then        -- cruz
        love.graphics.line(x, y - a, x, y + a)
        love.graphics.line(x - a, y, x + a, y)
    elseif unit == "grow" then        -- seta pra cima: acumula
        love.graphics.polygon("fill", x, y - a, x + a, y + a * 0.15, x - a, y + a * 0.15)
        love.graphics.rectangle("fill", x - a * 0.32, y + a * 0.1, a * 0.64, a * 0.9)
    end
end

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
        otype = orb and orb.type,
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

-- Burst tematico ANCORADO no orbe. Existe pro pulso de SOMBRA, que e o unico
-- cujo efeito nao sai da fileira (o orbe engorda a si mesmo) -- a marca dele
-- tem que cair no proprio orbe, nao no inimigo nem no painel. Sem posicao
-- calculada (headless, fileira invisivel) vira no-op.
function OrbRow.burstAtSlot(i, theme, k)
    if not (slotPos and slotPos[i]) then return end
    local ok, CardFeel = pcall(require, "src.systems.CardFeel")
    if ok and CardFeel.burst then
        CardFeel.burst(theme, slotPos[i].x, slotPos[i].y, k or 1)
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
        color = color, otype = orb and orb.type,
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

-- Altura total de uma célula: gema + placa. O slot VAZIO não tem placa (a
-- fileira encolhe sozinha nos turnos sem orbe), mas a ALTURA da banda é a
-- mesma sempre -- senão a row inteira pularia de lugar quando o 1º orbe nasce.
local function cellHeight()
    return SIZE + GAP_GEM_PLATE + PLATE_H
end

-- A PLACA do número. Fica EMBAIXO da gema, não por cima (decisão do dono no
-- comparativo): número branco sobre pedra facetada apaga a pedra -- ganha-se a
-- gema e perde-se a gema. A placa leva o glifo de unidade junto e a borda na
-- cor do elemento, então ela também é identidade, não só suporte.
local function drawPlate(x, y, w, color, unit, value, font)
    love.graphics.setColor(0.07, 0.05, 0.04, 0.95)
    love.graphics.rectangle("fill", x, y, w, PLATE_H)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - 1, y - 1, w + 2, PLATE_H + 2)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("line", x, y, w, PLATE_H)

    local txt = tostring(value)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local gh = PLATE_H - 8
    local gap = 3
    local total = gh + gap + tw
    local cx = x + w / 2
    local cy = y + PLATE_H / 2
    local gx = cx - total / 2 + gh / 2
    local nx = math.floor(cx - total / 2 + gh + gap)
    local ny = math.floor(cy - font:getHeight() / 2)

    local uc = UNIT_COLOR[unit or ""] or { 1, 1, 1 }
    love.graphics.setColor(0, 0, 0, 0.9)
    drawUnitGlyph(unit, gx + 1, cy + 1, gh)
    love.graphics.setColor(uc[1], uc[2], uc[3], 1)
    drawUnitGlyph(unit, gx, cy, gh)

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(txt, nx + 1, ny + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(txt, nx, ny)
end

-- Desenha a gema 1:1 em (x, y). `flash` (0..1) acende a pedra SEM lavá-la:
-- blend aditivo por cima do desenho normal, em vez de multiplicar a cor (que
-- só escureceria a arte).
local function drawGem(orbType, x, y, alpha, flash)
    local img = gemOf(orbType)
    if not img then return false end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, math.floor(x), math.floor(y))
    if flash and flash > 0 then
        local prev = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add")
        love.graphics.setColor(flash * 0.7, flash * 0.7, flash * 0.7, 1)
        love.graphics.draw(img, math.floor(x), math.floor(y))
        love.graphics.setBlendMode(prev)
    end
    return true
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
    local y = math.floor(PlayerBuffPills.getBandTop(panelY)
        - GAP_ABOVE_PILLS - cellHeight())

    slotPos = {}
    local mx, my = love.mouse.getPosition()
    -- Fonte 13: a placa tem 18px de altura, e 15 (a de antes, quando o número
    -- morava DENTRO da silhueta) transbordava a borda.
    local font = FontManager.getResponsiveFont(0.021, 13)
    local plateY = y + SIZE + GAP_GEM_PLATE
    local plateInset = 3
    local plateW = SIZE - plateInset * 2

    for i = 1, (p.orbSlots or 3) do
        local x = startX + (i - 1) * (SIZE + SPACING)
        local cx, cy = x + SIZE / 2, y + SIZE / 2
        slotPos[i] = { x = cx, y = cy }
        -- Orbe em TRÂNSITO ainda não está no slot: o cometa é que o carrega.
        local orb = (not inbound[i]) and p.orbs and p.orbs[i] or nil

        if not orb then
            -- Slot VAZIO: aro apagado e MENOR, sem placa. A fileira encolhe
            -- sozinha nos turnos sem orbe, e "sem elemento" continua sendo a
            -- única coisa redonda e oca da fileira.
            love.graphics.setColor(0.10, 0.07, 0.05, 0.55)
            love.graphics.circle("fill", cx, cy, SIZE / 2 - 8)
            love.graphics.setColor(0.45, 0.40, 0.32, 0.45)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, SIZE / 2 - 8)
            -- Preview de canalização: próximo slot livre pisca convidando
            if previewMode == "channel" and (p.orbs and #p.orbs + 1 == i or (not p.orbs and i == 1)) then
                -- Sem movimento a piscada vira realce fixo: o slot que vai
                -- receber continua APONTADO, so nao pisca.
                local blink = reducedMotion() and 0.9
                    or (0.5 + math.sin(animTime * 6) * 0.4)
                love.graphics.setColor(0.95, 0.85, 0.30, blink * 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, SIZE / 2 - 4)
            end
        else
            local color = OrbRow.COLORS[orb.type] or { 0.7, 0.7, 0.7 }
            local inEvokePreview = (previewMode == "evoke_all")
                or (previewMode == "evoke_one" and i == 1)

            -- bob sutil + pulinho do pop-in. Sem ESCALA: a gema é pixel art
            -- 1:1, e escalar em fração faria a pedra tremer (shimmer). O
            -- "nasceu agora" vem de subir e acender, não de inchar.
            local kick = slotAnim[i] or 0
            -- reducedMotion tira o MOVIMENTO e nada mais: some o flutuar e o
            -- pulinho de chegada, FICA o clarao do pop-in (que e o que diz
            -- "este nasceu agora") e ficam todos os numeros.
            local bob = 0
            if not reducedMotion() then
                bob = math.sin(animTime * 2.2 + i * 1.3) * 2 - kick * 6
            end
            local gy = y + bob

            -- Halo: brilho difuso ATRÁS da pedra (a gema tem corpo, então o
            -- halo não precisa mais desenhar a forma).
            local haloC = inEvokePreview and EVOKE_CYAN or color
            local haloA = 0.26 * (0.75 + math.sin(animTime * 3 + i) * 0.25)
            if inEvokePreview then haloA = 0.50 + math.sin(animTime * 6) * 0.18 end
            if reducedMotion() then haloA = inEvokePreview and 0.58 or 0.26 end
            love.graphics.setColor(haloC[1], haloC[2], haloC[3], haloA)
            love.graphics.circle("fill", cx, gy + SIZE / 2, SIZE * 0.42)

            -- A GEMA, 1:1.
            local pf = pulseFlash[i] or 0
            if not drawGem(orb.type, x, gy, 1, math.max(pf * 0.8, kick * 0.6)) then
                -- Sem arte: aro de emergência (o aviso já saiu em gemOf).
                love.graphics.setColor(color[1], color[2], color[3], 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, gy + SIZE / 2, SIZE / 2 - 6)
            end

            -- PLACA do número, pendurada na pedra.
            local shown, unit = OrbRow.readout(orb, focus,
                inEvokePreview and "evoke" or "pulse")
            drawPlate(x + plateInset, plateY, plateW,
                inEvokePreview and EVOKE_CYAN or color,
                unit, shown, font)
            if inEvokePreview then
                -- No preview de evoke o número também é outro: pinta o valor de
                -- ciano por cima pra ninguém ler o de pulso.
                local txt = tostring(shown)
                love.graphics.setFont(font)
                local tw = font:getWidth(txt)
                local gh = PLATE_H - 8
                local total = gh + 3 + tw
                love.graphics.setColor(EVOKE_CYAN[1], EVOKE_CYAN[2], EVOKE_CYAN[3], 1)
                love.graphics.print(txt,
                    math.floor(x + plateInset + plateW / 2 - total / 2 + gh + 3),
                    math.floor(plateY + PLATE_H / 2 - font:getHeight() / 2))
            end

            -- PRÓXIMO A SAIR (FIFO): moldura clara em volta da CÉLULA inteira
            -- (pedra + placa). Antes era um aro na silhueta; com a gema não há
            -- polígono, e a moldura da célula lê melhor — marca "este bloco",
            -- não "esta borda".
            if i == 1 and #p.orbs > 0 then
                local a = reducedMotion() and 0.9
                    or (0.70 + math.sin(animTime * 3.5) * 0.2)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", x - 3, y - 3,
                    SIZE + 6, cellHeight() + 6)
            end
        end

        -- Hover → tooltip com números exatos (stacks=pulso, duration=evoke —
        -- reuso do StatusTooltip; as descs de status.orb_* nomeiam os campos).
        if mx >= x and mx <= x + SIZE and my >= y and my <= y + cellHeight() then
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

    -- TRILHO DA FILA: uma linha sob a fileira com a ponta de seta à ESQUERDA.
    -- Ensina a regra inteira de uma vez -- "entram pela direita, saem pela
    -- esquerda" -- sem texto e sem depender de marcador por orbe.
    if #(p.orbs or {}) > 0 then
        local railY = y + cellHeight() + 6
        local railX2 = startX + (math.min(#p.orbs, p.orbSlots or 3) - 1)
            * (SIZE + SPACING) + SIZE / 2
        love.graphics.setColor(0.72, 0.66, 0.52, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(startX + 2, railY, railX2, railY)
        love.graphics.polygon("fill",
            startX - 5, railY, startX + 3, railY - 4, startX + 3, railY + 4)
        -- Losango no trilho sob o PRIMEIRO orbe: liga "este aqui" a "a saida e
        -- por ali". Nao depende da cor do orbe, ao contrario do aro.
        local fx = startX + SIZE / 2
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.polygon("fill",
            fx, railY - 4, fx + 4, railY, fx, railY + 4, fx - 4, railY)
    end

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
            -- A cabeça do cometa JÁ É a gema que vai nascer -- a MESMA arte,
            -- não um substituto. Ela viaja em escala INTEIRA (1:1) com um brilho
            -- por trás que cresce: escalar a pedra em fração faria ela tremer,
            -- e meio pixel de tremor num voo de 0,26s lê como sujeira.
            love.graphics.setColor(c[1], c[2], c[3], 0.30 + 0.35 * e)
            love.graphics.circle("fill", x, y, SIZE * (0.18 + 0.24 * e))
            if not drawGem(fx.otype, x - SIZE / 2, y - SIZE / 2, 1, 0.35 * (1 - e)) then
                love.graphics.setColor(1, 1, 1, 0.85)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", x, y, SIZE * 0.3)
            end
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
            local c, a = fx.color, 1 - k
            -- O fantasma é a PRÓPRIA gema saindo, apagando -- também 1:1, pelo
            -- mesmo motivo do cometa. Quem diz "isto está indo embora" é o
            -- alpha + o halo da cor (âmbar quando é expulsão), não uma forma
            -- diferente: forma diferente leria como outro orbe.
            love.graphics.setColor(c[1], c[2], c[3], 0.65 * a)
            love.graphics.circle("fill", x, y, SIZE * 0.40)
            if not drawGem(fx.otype, x - SIZE / 2, y - SIZE / 2, a, 0.5 * a) then
                love.graphics.setColor(1, 1, 1, 0.95 * a)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", x, y, SIZE * 0.35)
            end
        end
    end
end

return OrbRow
