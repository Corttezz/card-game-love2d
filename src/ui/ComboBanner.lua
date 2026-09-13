-- src/ui/ComboBanner.lua
-- Banner de COMBO: faixa full-width que anuncia, com NUMERO na tela, todo
-- combo disparado no turno. Nasceu de um pedido direto do dono: "so o texto
-- ao lado no chat de log nao e claro o suficiente" — o toast de 12px do
-- MessageSystem some no meio das outras mensagens e o jogador nunca ve de
-- onde veio o dano/bloqueio extra.
--
-- ESTRUTURA: clonada do src/ui/TurnBanner.lua (precedente ja validado
-- visualmente) — faixa parada num canvas pre-renderizado que MATERIALIZA e
-- DISSOLVE com o mesmo DissolveShader das cartas. O que muda:
--   · acento proprio (violeta arcano do Palette) — nem ouro (turno do
--     jogador) nem sangue (turno do inimigo);
--   · altura variavel: titulo + uma linha por combo;
--   · o GANHO aparece escrito (x1.4 / +6 / +4 HP) — e o ponto do banner.
--
-- ===== ZONA (v2, feedback do dono Set/2026) =====
-- "pode subir mais... esta ficando debaixo em profundidade das cartas usadas
-- no turno, da nem pra ler". Duas correcoes:
--   (a) PROFUNDIDADE — a chamada de draw migrou pro FIM do frame de gameplay,
--       depois da mao E depois do combatAnimationSystem (as cartas que voam).
--       Ver src/scenes/GameplayScene.lua.
--   (b) POSICAO — o banner deixou de ser "logo abaixo do TurnBanner" (ancora
--       vizinho-a-vizinho, o anti-pattern do memory/ui_layout_invariants.md
--       §1) e passou a morar numa ZONA DE ANUNCIO declarada: do rodape da
--       TopBar ate a LINHA DE POUSO das cartas do turno. O rodape do banner
--       encosta no teto do pouso e ele cresce PRA CIMA. Se o conteudo nao
--       couber na zona (4 combos num turno), quem cede e a ESCALA do
--       conteudo — as bandas nao se mexem.
--
-- OCUPANTE UNICO: TurnBanner e ComboBanner dividem a mesma faixa de tela, e
-- por isso NUNCA aparecem juntos — a fila abaixo segura o combo enquanto o
-- banner de turno estiver no ar. Nao e ajuste fino de pixel, e exclusao por
-- construcao. (Na pratica quase nunca espera: o combo so dispara no IMPACTO
-- da carta, bem depois do banner de turno ter cumprido a funcao.)
--
-- FILA (decisao): combos do MESMO turno viram UM banner de varias linhas,
-- nao N banners em sequencia. Motivo: eles nao sao eventos separados — se
-- compoem sobre as MESMAS cartas (x1.4 e depois +6 no mesmo golpe), entao
-- ler os dois juntos e o que explica o numero final. Em fila, 3 combos
-- custariam ~3s e o ultimo cairia depois da animacao de combate que ele
-- deveria estar explicando. Turnos DIFERENTES enfileiram de verdade, um apos
-- o outro — dois banners nunca dividem a tela.
--
-- Uso: ComboBanner.show(combos) · update(dt) · draw(topBarH) · isActive()
--      · clear()
--   combos = lista de regras do ComboSystem ({ id, label, bonus })

local Config         = require("src.core.Config")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local I18n           = require("src.i18n.I18n")
local DissolveShader = require("src.ui.DissolveShader")
local TurnBanner     = require("src.ui.TurnBanner")

local ComboBanner = {}

local queue  = {}    -- entradas aguardando a vez
local active = nil   -- { rows, key, h, dur, t, born, geo }
local canvasCache = {}
local canvasCount = 0

-- Metricas do conteudo em escala 1 (px logicos). A escala efetiva sai de
-- fitScale(), aplicada as fontes E as alturas — nunca um scale no draw, que
-- estreitaria a faixa full-width e borraria o pixel art.
local PAD_V      = 10
local TITLE_H    = 30
local ROW_H      = 30
local TITLE_FONT = 24
local LABEL_FONT = 20
local VALUE_FONT = 26   -- o GANHO e o motivo do banner existir: vem maior

-- ===== ZONA DE ANUNCIO =====
-- Teto: rodape da TopBar (draw() recebe a altura real; 52 e o valor de
-- components/TopBar.lua, barra de altura FIXA — serve de default no 1o frame
-- e nas ferramentas que desenham sem TopBar).
-- Piso: topo das cartas que pousam no centro. O pouso vem do CombatSequence
-- (centro em screenH * 0.45); a carta e o canvas 144px do CardFrame na
-- BASE_SCALE, e HOP_MARGIN cobre o pulinho do impacto (Moveable.hop_up).
local TOP_BAR_H_DEFAULT = 52
local TOP_MARGIN        = 8
local CARD_IMG_H        = 144
local LAND_RATIO        = 0.45
local HOP_MARGIN        = 26

local topInset = TOP_BAR_H_DEFAULT

local function announceZone()
    local sh = love.graphics.getHeight()
    local cardH = CARD_IMG_H * (Config.Cards and Config.Cards.BASE_SCALE or 1.333)
    local bottom = math.floor(sh * LAND_RATIO - cardH / 2 - HOP_MARGIN)
    local top = topInset + TOP_MARGIN
    return top, bottom
end

-- Envelope temporal, igual em espirito ao TurnBanner:
-- materialize 0.30 · hold · dissolve 0.30. O hold cresce com o numero de
-- linhas (mais texto = mais tempo de leitura).
local FADE_IN, FADE_OUT = 0.30, 0.30
local HOLD_BASE, HOLD_PER_ROW = 0.55, 0.30

-- Guarda-chuva anti-fantasma: se a cena parar de tickar (batalha acabou no
-- meio do banner e o jogo foi pro cardReward), a entrada nao pode reaparecer
-- na batalha seguinte. Expira por relogio de parede.
local STALE_AFTER = 5.0

local function rgba(c, a)
    return { c[1], c[2], c[3], a or 1 }
end

local function now()
    return (love.timer and love.timer.getTime and love.timer.getTime()) or 0
end

-- ============================================================================
-- TEXTO DO GANHO — o que o dono quer enxergar
-- ============================================================================

-- Formata o bonus da regra do jeito que o jogador le no resto do jogo:
-- multiplicador vira "×1.4" (mesma convencao dos procs de joker no
-- EffectSystem), bonus plano vira "+6". Tipos de evento (debuff/cura/evoke)
-- dizem o que ganharam.
local function formatBonus(b)
    if not b then return nil end
    local t = b.type
    if t == "damage_multiplier" or t == "defense_multiplier" then
        return "×" .. string.format("%g", b.value or 1)
    elseif t == "damage_bonus" or t == "defense_bonus" then
        return "+" .. string.format("%g", b.value or 0)
    elseif t == "heal" then
        return "+" .. string.format("%g", b.value or 0) .. " HP"
    elseif t == "apply_debuff" then
        local name = I18n.t("status." .. (b.debuff or "poison") .. ".name",
            nil, b.debuff or "")
        return "+" .. string.format("%g", b.stacks or 1) .. " " .. name
    elseif t == "evoke_on_combo" then
        return I18n.t("battle.combo_evoke", { n = b.value or 1 })
    end
    return nil
end

-- Nome do combo: i18n primeiro (combos.<id>), rule.label como fallback —
-- os dois existem hoje e a tabela do locale estava orfa; com o banner dando
-- destaque ao texto, a fonte de verdade passa a ser o i18n.
local function comboName(combo)
    return I18n.t("combos." .. tostring(combo.id), nil,
        combo.label or tostring(combo.id))
end

-- ============================================================================
-- GEOMETRIA — recalculada sempre que a janela muda de tamanho
-- ============================================================================

-- Resolve as metricas do banner pra tela ATUAL. Invariante 2 do
-- memory/ui_layout_invariants.md: estado cacheado (canvas + alturas) tem que
-- acompanhar o resize. Como esta scene nao tem resize() proprio, o recalculo
-- mora aqui e e chamado por show() E por update() — os dois rodam FORA do
-- love.draw, que e onde o canvas pode ser criado com seguranca.
local function ensureGeometry(entry)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if entry.geo and entry.geo.sw == sw and entry.geo.sh == sh
        and entry.geo.inset == topInset then
        return entry.geo
    end

    local n = #entry.rows
    local natural = PAD_V * 2 + TITLE_H + n * ROW_H
    local zTop, zBottom = announceZone()
    local zoneH = math.max(40, zBottom - zTop)
    -- conteudo cede, banda nao (invariante 1)
    local s = math.min(1, zoneH / natural)

    local geo = {
        sw = sw, sh = sh, inset = topInset, scale = s,
        padV    = math.floor(PAD_V * s),
        titleH  = math.floor(TITLE_H * s),
        rowH    = math.floor(ROW_H * s),
        titleF  = math.max(10, math.floor(TITLE_FONT * s)),
        labelF  = math.max(9,  math.floor(LABEL_FONT * s)),
        valueF  = math.max(10, math.floor(VALUE_FONT * s)),
    }
    geo.h = geo.padV * 2 + geo.titleH + n * geo.rowH
    -- rodape encostado no piso da zona; cresce pra cima
    geo.y = math.max(zTop, zBottom - geo.h)
    geo.key = entry.key .. "|" .. sw .. "|" .. geo.h
    entry.geo = geo
    return geo
end

-- ============================================================================
-- CANVAS (pre-renderizado fora do frame de draw — ver TurnBanner)
-- ============================================================================

local function bannerCanvas(entry)
    local geo = entry.geo
    if canvasCache[geo.key] then return canvasCache[geo.key] end

    -- scissor herdado do frame recortaria o clear do canvas (glClear RESPEITA
    -- scissor) — mesma blindagem do TurnBanner.
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    love.graphics.setScissor()

    local sw, h = geo.sw, geo.h
    local titleFont = FontManager.getFont(geo.titleF)
    local rowFont   = FontManager.getFont(geo.labelF)
    local valueFont = FontManager.getFont(geo.valueF)

    local canvas = love.graphics.newCanvas(sw, h)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()

    -- fundo + filetes
    love.graphics.setColor(rgba(Palette.ARCANE_INK, 0.90))
    love.graphics.rectangle("fill", 0, 0, sw, h)
    love.graphics.setColor(rgba(Palette.ARCANE, 0.95))
    love.graphics.rectangle("fill", 0, 0, sw, 2)
    love.graphics.rectangle("fill", 0, h - 2, sw, 2)

    -- titulo + losangos-guarda (mesmo detalhe ourives do TurnBanner)
    local title = I18n.t("battle.combo")
    love.graphics.setFont(titleFont)
    local tw = titleFont:getWidth(title)
    local titleY = geo.padV + math.floor((geo.titleH - titleFont:getHeight()) / 2)
    local cyt = geo.padV + math.floor(geo.titleH / 2)
    for side = -1, 1, 2 do
        local gx = math.floor(sw / 2 + side * (tw / 2 + 26))
        love.graphics.setColor(rgba(Palette.ARCANE, 0.95))
        love.graphics.polygon("fill", gx, cyt - 5, gx + 5, cyt,
            gx, cyt + 5, gx - 5, cyt)
    end
    FontManager.drawWithOutline(title, math.floor((sw - tw) / 2), titleY,
        Palette.ARCANE_LIGHT, 0.75)

    -- uma linha por combo: NOME (pergaminho) + GANHO (violeta, destacado)
    local gap = math.max(8, math.floor(14 * geo.scale))
    for i, row in ipairs(entry.rows) do
        local lw = rowFont:getWidth(row.label)
        local vw = row.value and valueFont:getWidth(row.value) or 0
        local total = lw + (row.value and (gap + vw) or 0)
        local x = math.floor((sw - total) / 2)
        local rowY = geo.padV + geo.titleH + (i - 1) * geo.rowH
        -- cada texto centra pela PROPRIA altura (fontes diferentes na linha)
        love.graphics.setFont(rowFont)
        FontManager.drawWithOutline(row.label, x,
            rowY + math.floor((geo.rowH - rowFont:getHeight()) / 2),
            Palette.PARCHMENT_LIGHT, 0.8)
        if row.value then
            love.graphics.setFont(valueFont)
            FontManager.drawWithOutline(row.value, x + lw + gap,
                rowY + math.floor((geo.rowH - valueFont:getHeight()) / 2),
                Palette.ARCANE_LIGHT, 0.95)
        end
    end

    love.graphics.setCanvas()
    love.graphics.pop()
    if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) end

    -- cache limitado: os combos possiveis sao poucos, mas resize gera chaves
    -- novas — nao deixa crescer pra sempre.
    if canvasCount > 24 then
        canvasCache = {}
        canvasCount = 0
    end
    canvasCache[geo.key] = canvas
    canvasCount = canvasCount + 1
    return canvas
end

-- ============================================================================
-- API
-- ============================================================================

-- Enfileira UM banner com todos os combos recebidos.
function ComboBanner.show(combos)
    if type(combos) ~= "table" or #combos == 0 then return end

    local rows, keyParts = {}, {}
    for _, combo in ipairs(combos) do
        rows[#rows + 1] = {
            label = comboName(combo),
            value = formatBonus(combo.bonus),
        }
        keyParts[#keyParts + 1] = tostring(combo.id)
    end

    local entry = {
        rows = rows,
        key  = table.concat(keyParts, "+"),
        dur  = FADE_IN + FADE_OUT + HOLD_BASE + HOLD_PER_ROW * #rows,
        t    = 0,
        born = now(),
    }
    -- pre-render AQUI (fora do love.draw): criar canvas no meio do frame,
    -- com o scissor do WorldRoad vivo, corrompia o conteudo (TurnBanner v2.1)
    ensureGeometry(entry)
    bannerCanvas(entry)
    queue[#queue + 1] = entry
end

function ComboBanner.update(dt)
    local tnow = now()
    -- descarta entradas velhas (cena ficou sem tickar entre batalhas)
    for i = #queue, 1, -1 do
        if tnow - queue[i].born > STALE_AFTER then table.remove(queue, i) end
    end
    if active and tnow - active.born > active.dur + STALE_AFTER then
        active = nil
    end
    if not active then
        -- OCUPANTE UNICO da zona de anuncio: espera o banner de turno sair.
        if TurnBanner.isActive() then return end
        active = table.remove(queue, 1)
        if not active then return end
        active.t = 0
        active.born = tnow
    end
    -- resize: recalcula metricas e re-renderiza o canvas AQUI (fora do draw)
    local geo = ensureGeometry(active)
    if not canvasCache[geo.key] then bannerCanvas(active) end

    active.t = active.t + dt
    if active.t >= active.dur then active = nil end
end

function ComboBanner.isActive() return active ~= nil end

-- Limpa tudo (troca de batalha/run). Seguro de chamar a qualquer momento.
function ComboBanner.clear()
    active = nil
    for i = #queue, 1, -1 do queue[i] = nil end
end

-- Chamas do dissolve: mesma familia violeta/magenta do pack de booster —
-- le como "arcano", nao como fogo (ataque) nem como ouro (turno).
local BURN = { { 0.55, 0.30, 0.85, 1.0 }, { 0.95, 0.65, 0.95, 1.0 } }

-- topBarH: altura real da TopBar (GameplayScene passa a sua). Define o TETO
-- da zona de anuncio; sem ela usa o default fixo de components/TopBar.lua.
function ComboBanner.draw(topBarH)
    if topBarH and topBarH > 0 then topInset = topBarH end
    if not active then return end
    local geo = active.geo
    if not geo then return end
    local sw = geo.sw
    local t = active.t

    -- Acessibilidade: com reducedMotion o banner CONTINUA aparecendo (e
    -- informacao de jogo, nao enfeite) — some so a queima. No lugar dela,
    -- um fade curto, pra nao dar pop seco na tela.
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion

    local dissolve, alpha = 0, 1
    if reduced then
        local FADE = 0.12
        if t < FADE then
            alpha = t / FADE
        elseif t > active.dur - FADE then
            alpha = math.max(0, (active.dur - t) / FADE)
        end
    else
        local outStart = active.dur - FADE_OUT
        if t < FADE_IN then
            local k = t / FADE_IN
            dissolve = 1 - k * k * (3 - 2 * k)          -- smoothstep invertido
        elseif t < outStart then
            dissolve = 0
        else
            local k = math.min(1, (t - outStart) / FADE_OUT)
            dissolve = k * k * (3 - 2 * k)
        end
    end

    -- lazy-load do shader (ferramentas de screenshot nao passam pelo
    -- love.load completo e caiam no fallback de fade silencioso)
    if not reduced and not DissolveShader.isAvailable()
        and not ComboBanner._shaderTried then
        ComboBanner._shaderTried = true
        DissolveShader.load()
    end

    local canvas = canvasCache[geo.key]
    if not canvas then return end   -- canvas so nasce fora do draw (ver update)
    local y = geo.y

    love.graphics.setColor(1, 1, 1, alpha)
    if not reduced then
        -- noise anisotropico: celula ~quadrada na faixa full-width (sem isso
        -- a queima estica em "faixas fantasmas")
        local ns = { 5.5 * sw / geo.h, 5.5 }
        if not DissolveShader.apply(canvas, dissolve, BURN, false, ns) then
            love.graphics.setColor(1, 1, 1, 1 - dissolve)
        end
    end
    -- scissor-guard: por construcao nada pinta fora do retangulo da faixa
    local gx0, gy0, gw0, gh0 = love.graphics.getScissor()
    love.graphics.setScissor(0, y, sw, geo.h)
    love.graphics.draw(canvas, 0, y)
    love.graphics.setScissor(gx0, gy0, gw0, gh0)
    DissolveShader.clear()
    love.graphics.setColor(1, 1, 1, 1)
end

return ComboBanner
