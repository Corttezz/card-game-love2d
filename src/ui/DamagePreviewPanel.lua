-- src/ui/DamagePreviewPanel.lua
-- PREVIA DE DANO na batalha (Out/2026, pedido do dono: "nao fica claro quanto
-- de dano vai dar — o jogador joga as cartas e ve um dano enorme sem entender
-- o que aconteceu").
--
-- Tres lugares, cada um ANCORADO no objeto de que fala (lei do projeto: nada
-- de tarja de rodape):
--   1. PAINEL acima do botao JOGAR (banda de ACAO da coluna direita): o total
--      que o inimigo vai perder, o Bloqueio que voce ganha e, carta a carta,
--      a conta que explica o numero — base -> Forca -> combo (dourado) ->
--      coringa (violeta) -> edicao/selo -> Fraco. Durante a resolucao o painel
--      congela a previa e mostra o total CORRENDO ate fechar.
--   2. BARRA DE VIDA do inimigo: o trecho que a leva vai arrancar pisca por
--      cima da barra (e o numero "-34" ao lado). Letal = a barra inteira.
--   3. CARTAS DA MAO: a carta que fecharia um combo NOVO com a selecao atual
--      ganha um selo "+COMBO" em cima; em hover, o painel mostra o total COM
--      ela ("+ Pancada: 51").
--
-- A conta vem de src/systems/DamagePreview.lua — a MESMA funcao que o combate
-- usa (previa == resultado; trava em tools/test_damage_preview.lua).

local DamagePreview = require("src.systems.DamagePreview")
local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local IconLoader = require("src.ui.IconLoader")
local I18n = require("src.i18n.I18n")
local utf8 = require("utf8")

local Panel = {}

local state = {
    live = nil,      -- previa da selecao atual (fora da resolucao)
    frozen = nil,    -- { R, hp0 } congelado no clique em Jogar
    doneT = nil,     -- tempo desde que a resolucao terminou
    hover = nil,     -- { card, R } previa da selecao + carta em hover
    badges = {},     -- [card] = combo que ela dispararia
}

local HOLD_AFTER = 1.6   -- s que o total final fica na tela apos resolver

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

local function t(key, vars, fb)
    return I18n.t("damage_preview." .. key, vars, fb)
end

-- texto pequeno SEM contorno: o painel ja e escuro, e o contorno de 1px
-- empasta a fonte pixel em corpo pequeno (o "8" virava "&").
local function plain(text, x, y, c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
    love.graphics.print(text, math.floor(x), math.floor(y))
end

local function fmtNum(v)
    return string.format("%g", v)
end

local function comboName(combo)
    return I18n.t("combos." .. tostring(combo.id), nil, combo.label or tostring(combo.id))
end

-- corta texto por CARACTERE (UTF-8 seguro) ate caber em maxW
local function fit(font, text, maxW)
    if font:getWidth(text) <= maxW then return text end
    local chars = {}
    for _, code in utf8.codes(text) do chars[#chars + 1] = utf8.char(code) end
    while #chars > 1 do
        chars[#chars] = nil
        local s = table.concat(chars) .. "."
        if font:getWidth(s) <= maxW then return s end
    end
    return text
end

local function isBusy(game)
    local seq = game.combatAnimationSystem
    return seq and (seq.active or (seq.isBlocking and seq:isBlocking())) or false
end

-- ===========================================================================
-- UPDATE
-- ===========================================================================

function Panel.update(game, hoverCard, dt)
    if not game or not game.enemy or not game.player then
        state.live, state.frozen, state.hover = nil, nil, nil
        return
    end
    if isBusy(game) then
        if not state.frozen and state.live then
            state.frozen = { R = state.live, hp0 = state.live.enemyHealth }
        end
        state.doneT = nil
        state.hover = nil
        state.badges = {}
        return
    end
    if state.frozen then
        state.doneT = (state.doneT or 0) + (dt or 0)
        if state.doneT > HOLD_AFTER or #game.selectedCards > 0 then
            state.frozen, state.doneT = nil, nil
        end
    end

    local sel = game.selectedCards or {}
    local myTurn = game.turn == "player" and game.enemy:isAlive()
    state.live = (myTurn and #sel > 0) and DamagePreview.simulate(game, sel) or nil

    -- carta em hover (nao selecionada e pagavel): previa COM ela
    state.hover = nil
    if myTurn and hoverCard and not game:isCardSelected(hoverCard)
        and game:canPlayCard(hoverCard) and hoverCard.type ~= "joker" then
        local with = {}
        for _, c in ipairs(sel) do with[#with + 1] = c end
        with[#with + 1] = hoverCard
        state.hover = { card = hoverCard, R = DamagePreview.simulate(game, with),
            added = DamagePreview.combosAddedBy(sel, hoverCard) }
    end

    -- selos "+COMBO" na mao (so com selecao: e a selecao que define o combo)
    state.badges = {}
    if myTurn and #sel > 0 then
        for _, c in ipairs(game.hand or {}) do
            if c.type ~= "joker" and not game:isCardSelected(c) and game:canPlayCard(c) then
                local added = DamagePreview.combosAddedBy(sel, c)
                if #added > 0 then state.badges[c] = added[1] end
            end
        end
    end
end

function Panel.reset()
    state.live, state.frozen, state.doneT, state.hover = nil, nil, nil, nil
    state.badges = {}
end

-- Previa visivel agora (live ou congelada) — usada pela barra do inimigo.
function Panel.current()
    if state.frozen then return state.frozen.R, true end
    return state.live, false
end

-- ===========================================================================
-- Linhas do painel (medidas e desenhadas pela mesma lista)
-- ===========================================================================

local COL_ATK   = Palette.BLOOD
local COL_DEF   = Palette.STEEL_LIGHT
local COL_COMBO = Palette.AGED_GOLD_LIGHT
local COL_JOKER = Palette.ARCANE_LIGHT
local COL_TEXT  = Palette.PARCHMENT_LIGHT
local COL_DIM   = Palette.PARCHMENT
local COL_LETHAL = Palette.MAGENTA

-- Converte os passos de uma carta em fichas coloridas { text, color, icon }.
local function stepChips(steps)
    local chips = {}
    for _, s in ipairs(steps or {}) do
        if s.kind == "base" then
            chips[#chips + 1] = { text = fmtNum(s.value), color = COL_TEXT }
        elseif s.kind == "effects" then
            if (s.hits or 1) > 1 then
                chips[#chips + 1] = { text = "×" .. s.hits, color = COL_TEXT }
            else
                chips[#chips + 1] = { text = "+" .. fmtNum(s.delta), color = COL_TEXT }
            end
        elseif s.kind == "stat" then
            chips[#chips + 1] = { text = (s.delta >= 0 and "+" or "") .. fmtNum(s.delta),
                color = COL_TEXT, icon = s.stat == "strength" and "status_strength"
                    or "status_dexterity" }
        elseif s.kind == "combo" then
            chips[#chips + 1] = { text = (s.op == "mult" and "×" or "+") .. fmtNum(s.value),
                color = COL_COMBO }
        elseif s.kind == "joker" then
            chips[#chips + 1] = { text = (s.op == "mult" and "×" or "+") .. fmtNum(s.value),
                color = COL_JOKER }
        elseif s.kind == "edition" then
            local ed = s.edition
            local flat = DamagePreview.EDITION_FLAT[ed]
            local mult = DamagePreview.EDITION_MULT[ed]
            chips[#chips + 1] = { text = flat and ("+" .. flat) or ("×" .. fmtNum(mult)),
                color = Palette.CYAN }
        elseif s.kind == "seal" then
            chips[#chips + 1] = { text = "×" .. fmtNum(s.value), color = COL_ATK }
        elseif s.kind == "weak" or s.kind == "frail" then
            chips[#chips + 1] = { text = "×" .. fmtNum(s.value), color = Palette.PINK,
                icon = "status_" .. s.kind }
        end
    end
    return chips
end

-- Monta a lista de linhas do painel a partir de uma previa.
local function buildLines(R, opts)
    local lines = {}
    -- combos ativos (nome + o que fazem)
    for _, combo in ipairs(R.combos or {}) do
        local b = combo.bonus or {}
        local what = ""
        if b.type == "damage_multiplier" or b.type == "defense_multiplier" then
            what = "×" .. fmtNum(b.value)
        elseif b.type == "damage_bonus" or b.type == "defense_bonus" then
            what = "+" .. fmtNum(b.value)
        end
        lines[#lines + 1] = { kind = "combo", text = comboName(combo), right = what,
            combo = combo }
    end
    -- coringas que mexeram no numero (violeta, como as fichas deles)
    local seenJ = {}
    for _, e in ipairs(R.cards or {}) do
        for _, s in ipairs(e.steps or {}) do
            if s.kind == "joker" and s.joker and not seenJ[s.joker] then
                seenJ[s.joker] = true
                lines[#lines + 1] = { kind = "joker", text = I18n.cardName(s.joker),
                    right = (s.op == "mult" and "×" or "+") .. fmtNum(s.value), joker = s.joker }
            end
        end
    end
    -- carta a carta
    for _, e in ipairs(R.cards or {}) do
        if e.type == "attack" or e.type == "defense" then
            local name = I18n.cardName(e.card)
            if e.skipped then
                lines[#lines + 1] = { kind = "card", text = name, right = "-",
                    dim = true, note = t("skipped", nil, "inimigo ja caiu") }
            else
                local chips = stepChips(e.steps)
                if #chips <= 1 then chips = nil end   -- so a base: o numero ja diz tudo
                lines[#lines + 1] = { kind = "card", text = name, right = fmtNum(e.value),
                    color = e.type == "attack" and COL_ATK or COL_DEF, chips = chips }
            end
        end
    end
    -- extras: orbes / magia
    local orb, magic = 0, 0
    for _, x in ipairs(R.extras or {}) do
        if x.kind == "orb" then orb = orb + x.value
        elseif x.kind == "magic" then magic = magic + x.value end
    end
    if magic > 0 then
        lines[#lines + 1] = { kind = "extra", text = t("magic", nil, "Magia"), right = fmtNum(magic) }
    end
    if orb > 0 then
        lines[#lines + 1] = { kind = "extra", text = t("orbs", nil, "Orbes evocados"), right = fmtNum(orb) }
    end
    -- alvo: Vulneravel / Bloqueio do inimigo
    if R.blocked and R.blocked > 0 then
        lines[#lines + 1] = { kind = "note", text = t("absorbed", { n = R.blocked },
            R.blocked .. " no Bloqueio do inimigo") }
    end
    local vulnHit = false
    for _, e in ipairs(R.cards or {}) do if e.vuln and e.dealt then vulnHit = true end end
    if vulnHit then
        lines[#lines + 1] = { kind = "note", text = I18n.t("status.vulnerable.name", nil,
            "Vulneravel") .. " ×1.5" }
    end
    if R.impetus then
        lines[#lines + 1] = { kind = "note", text = t("impetus", nil, "Impeto: +1 Forca") }
    end
    if R.uncertain then
        lines[#lines + 1] = { kind = "note", text = t("uncertain", nil, "+ efeito aleatorio") }
    end
    -- hover: o total com a carta a mais
    if opts and opts.hover then
        local H = opts.hover
        local added = H.added and H.added[1]
        local txt = t("with_card", { card = I18n.cardName(H.card), n = H.R.damage },
            "+ " .. I18n.cardName(H.card) .. ": " .. H.R.damage)
        if (H.R.block or 0) > (R.block or 0) then
            txt = txt .. " / +" .. H.R.block
        end
        lines[#lines + 1] = { kind = "hover", text = txt,
            right = added and comboName(added) or nil }
    end
    return lines
end

-- O que o combo FAZ, montado dos numeros da propria regra (texto e dado nunca
-- divergem). Multiplicador ganha a lei do "maior vence" junto.
function Panel.comboDescription(combo)
    local b = combo.bonus or {}
    local body = t("combo_desc." .. tostring(combo.id), {
        n = combo.minCount or 2, v = fmtNum(b.value or 0), stacks = b.stacks or 1 }, "")
    if b.type == "damage_multiplier" or b.type == "defense_multiplier" then
        body = body .. " " .. t("combo_desc.rule_mult", nil, "")
    end
    return body
end

-- Hover numa linha de combo/coringa: tooltip com o que ele faz.
local function rowTooltip(l, x, y, w, h)
    if not (l.combo or l.joker) then return end
    local mx, my = love.mouse.getPosition()
    if mx < x or mx > x + w or my < y or my > y + h then return end
    local okF, InputFocus = pcall(require, "src.ui.InputFocus")
    if okF and InputFocus.allows and not InputFocus.allows(InputFocus.SCENE) then return end
    local StatusTooltip = require("src.ui.StatusTooltip")
    if l.combo then
        StatusTooltip.show("combo_" .. tostring(l.combo.id), mx, my,
            { title = comboName(l.combo), body = Panel.comboDescription(l.combo) })
    else
        StatusTooltip.show("joker_" .. tostring(l.joker.id), mx, my,
            { title = I18n.cardName(l.joker), body = I18n.cardDesc(l.joker) or "" })
    end
end

-- ===========================================================================
-- DRAW — painel acima do botao Jogar
-- ===========================================================================

local function chipsWidth(font, chips, iconS, gap)
    local w = 0
    for i, c in ipairs(chips) do
        w = w + font:getWidth(c.text) + (c.icon and (iconS + 1) or 0)
        if i > 1 then w = w + gap end
    end
    return w
end

local function drawIcon(name, x, y, size)
    local h = IconLoader.get(name)
    if not h or not h.size then return end
    local s = size / h.size.h
    love.graphics.setColor(1, 1, 1, 1)
    h.draw(x, y, s)
end

-- `anchor` = { x, y, w } (topo e largura do botao Jogar). `topLimit` = y
-- minimo que o painel pode ocupar (abaixo da top bar / quadro de coringas).
function Panel.draw(game, anchor, topLimit)
    if not game or not anchor then return end
    local R, frozen = Panel.current()
    if not R then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local bigFont = FontManager.getResponsiveFont(0.034, 36)
    local font = FontManager.getResponsiveFont(0.0165, 18)
    local small = FontManager.getResponsiveFont(0.0135, 15)
    local pad = math.max(6, math.floor(sh * 0.010))
    local lh = font:getHeight() + math.max(3, math.floor(sh * 0.004))
    local slh = small:getHeight() + math.max(2, math.floor(sh * 0.003))
    local iconS = small:getHeight()

    -- largura: a do botao, crescendo ate 36% da tela se o texto pedir
    local maxW = math.floor(math.min(sw * 0.36, anchor.x + anchor.w - 8))
    local w = math.max(anchor.w, math.floor(sw * 0.24))
    w = math.min(w, maxW)
    local innerW = w - pad * 2

    local lines = frozen and {} or buildLines(R, { hover = state.hover })
    if frozen then
        for _, combo in ipairs(R.combos or {}) do
            lines[#lines + 1] = { kind = "combo", text = comboName(combo) }
        end
    end

    -- LETAL cabe no cabecalho? (mede o mesmo que o desenho abaixo)
    local lethalRow = false
    if R.lethal then
        local hw = 0
        local dmgW = frozen and bigFont:getWidth("000/" .. R.damage) or bigFont:getWidth(tostring(R.damage))
        if R.damage > 0 or (R.block or 0) == 0 then hw = hw + bigFont:getHeight() + 4 + dmgW + pad end
        if (R.block or 0) > 0 then hw = hw + bigFont:getHeight() + 4 + bigFont:getWidth("+" .. R.block) + pad end
        if hw + font:getWidth(t("lethal", nil, "LETAL")) > innerW then
            lethalRow = true
            table.insert(lines, 1, { kind = "lethal", text = t("lethal", nil, "LETAL") })
        end
    end

    -- altura de cada linha (card = nome + fichas)
    local function lineH(l)
        if l.kind == "card" then
            local hgt = lh
            if l.chips and #l.chips > 0 then hgt = hgt + slh end
            if l.note then hgt = hgt + slh end
            return hgt
        end
        return (l.kind == "note" or l.kind == "hover") and slh or lh
    end

    local headH = bigFont:getHeight() + pad
    local bottom = anchor.y - math.max(6, math.floor(sh * 0.01))
    local avail = bottom - (topLimit or 0) - pad * 2 - headH
    -- falta espaco: as linhas de CARTA cedem primeiro (o total fica sempre)
    local total = 0
    for _, l in ipairs(lines) do total = total + lineH(l) end
    if total > avail then
        local kept = {}
        local dropped = 0
        local used = 0
        for _, l in ipairs(lines) do
            local hgt = lineH(l)
            if l.kind == "card" and used + hgt > avail - lh then
                dropped = dropped + 1
            elseif used + hgt <= avail then
                kept[#kept + 1] = l
                used = used + hgt
            end
        end
        if dropped > 0 then
            kept[#kept + 1] = { kind = "note", text = t("more_cards", { n = dropped },
                "+" .. dropped .. " cartas") }
        end
        lines = kept
        total = 0
        for _, l in ipairs(lines) do total = total + lineH(l) end
    end

    local h = pad * 2 + headH + total + (#lines > 0 and math.floor(pad / 2) or 0)
    local x = math.floor(anchor.x + anchor.w - w)
    local y = math.floor(bottom - h)

    -- moldura (dialeto do StatusTooltip: pergaminho escuro, tinta, ouro)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 3, y + 4, w, h, 5, 5)
    setColor(Palette.INK, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    setColor(Palette.PARCHMENT_DARK, 0.55)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 4, 4)
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)
    setColor(R.lethal and COL_LETHAL or Palette.AGED_GOLD_DARK, 0.9)
    love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6, 3, 3)

    -- CABECALHO: dano (espada) e bloqueio (escudo), grandes
    local cx = x + pad
    local cy = y + pad
    local bigH = bigFont:getHeight()
    love.graphics.setFont(bigFont)
    local dmgText
    if frozen then
        local dealt = math.max(0, (state.frozen.hp0 or 0) - (game.enemy.health or 0))
        dmgText = dealt .. "/" .. R.damage
    else
        dmgText = tostring(R.damage)
    end
    if R.damage > 0 or (R.block or 0) == 0 then
        drawIcon("intent_attack", cx, cy + math.floor((bigH - bigH) / 2), bigH)
        cx = cx + bigH + 4
        FontManager.drawWithOutline(dmgText, cx, cy, { COL_ATK[1] * 1.6, COL_ATK[2] * 1.4,
            COL_ATK[3] * 1.4, 1 }, 0.95)
        cx = cx + bigFont:getWidth(dmgText) + pad
    end
    if (R.block or 0) > 0 then
        drawIcon("armor_shield", cx, cy, bigH)
        cx = cx + bigH + 4
        local bt = "+" .. R.block
        FontManager.drawWithOutline(bt, cx, cy, { COL_DEF[1] * 1.3, COL_DEF[2] * 1.3,
            COL_DEF[3] * 1.3, 1 }, 0.95)
        cx = cx + bigFont:getWidth(bt) + pad
    end
    -- rotulo LETAL a direita do cabecalho (sem espaco: virou linha, la em cima)
    if R.lethal and not lethalRow then
        love.graphics.setFont(font)
        local lt = t("lethal", nil, "LETAL")
        FontManager.drawWithOutline(lt, x + w - pad - font:getWidth(lt),
            cy + math.floor((bigH - font:getHeight()) / 2), { 1, 0.45, 0.55, 1 }, 0.95)
    end

    -- LINHAS
    local ly = y + pad + headH
    if #lines > 0 then
        setColor(Palette.AGED_GOLD_DARK, 0.8)
        love.graphics.line(x + pad, ly - math.floor(pad / 2), x + w - pad, ly - math.floor(pad / 2))
    end
    for _, l in ipairs(lines) do
        if l.kind == "combo" or l.kind == "joker" then
            love.graphics.setFont(font)
            local col = l.kind == "combo" and COL_COMBO or COL_JOKER
            local right = l.right or ""
            local rw = font:getWidth(right)
            local name = fit(font, l.text, innerW - rw - 6)
            FontManager.drawWithOutline(name, x + pad, ly, col, 0.8)
            if right ~= "" then
                FontManager.drawWithOutline(right, x + w - pad - rw, ly, col, 0.8)
            end
            rowTooltip(l, x, ly, w, lh)
            ly = ly + lh
        elseif l.kind == "card" or l.kind == "extra" then
            love.graphics.setFont(font)
            local right = l.right or ""
            local rw = font:getWidth(right)
            local name = fit(font, l.text, innerW - rw - 8)
            local a = l.dim and 0.5 or 1
            FontManager.drawWithOutline(name, x + pad, ly, { COL_TEXT[1], COL_TEXT[2], COL_TEXT[3], a }, 0.8)
            local rc = l.color or COL_TEXT
            FontManager.drawWithOutline(right, x + w - pad - rw, ly,
                { math.min(1, rc[1] * 1.6), math.min(1, rc[2] * 1.4), math.min(1, rc[3] * 1.4), a }, 0.9)
            ly = ly + lh
            if l.chips and #l.chips > 0 then
                love.graphics.setFont(small)
                local gap = 5
                -- fichas cabem? se nao, as do meio somem atras de "..."
                local chips = l.chips
                if chipsWidth(small, chips, iconS, gap) > innerW then
                    local cut = {}
                    for i = 1, #chips do cut[i] = chips[i] end
                    while #cut > 2 and chipsWidth(small, cut, iconS, gap) > innerW do
                        table.remove(cut, #cut - 1)
                    end
                    chips = cut
                end
                local chx = x + pad + 6
                for i, c in ipairs(chips) do
                    if c.icon then
                        drawIcon(c.icon, chx, ly, iconS)
                        chx = chx + iconS + 1
                    end
                    plain(c.text, chx, ly, c.color)
                    chx = chx + small:getWidth(c.text) + gap
                end
                ly = ly + slh
            end
            if l.note then
                love.graphics.setFont(small)
                plain(fit(small, l.note, innerW - 6), x + pad + 6, ly, COL_DIM)
                ly = ly + slh
            end
        elseif l.kind == "note" then
            love.graphics.setFont(small)
            plain(fit(small, l.text, innerW), x + pad, ly, COL_DIM)
            ly = ly + slh
        elseif l.kind == "hover" then
            -- o NUMERO vem primeiro: o nome do combo e que cede espaco
            love.graphics.setFont(small)
            local txt = fit(small, l.text, innerW)
            plain(txt, x + pad, ly, COL_TEXT)
            local right = l.right or ""
            local room = innerW - small:getWidth(txt) - 8
            if right ~= "" and room > small:getWidth("ABC") then
                local r2 = fit(small, right, room)
                plain(r2, x + w - pad - small:getWidth(r2), ly, COL_COMBO)
            end
            ly = ly + slh
        elseif l.kind == "lethal" then
            love.graphics.setFont(font)
            FontManager.drawWithOutline(l.text, x + pad, ly, { 1, 0.45, 0.55, 1 }, 0.9)
            ly = ly + lh
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    -- geometria do ultimo quadro (tools de captura miram o hover por aqui)
    Panel.lastRect = { x = x, y = y, w = w, h = h, firstRowY = y + pad + headH }
    return Panel.lastRect
end

-- ===========================================================================
-- Barra de vida do inimigo: o trecho que a leva arranca
-- ===========================================================================

-- `rect` = { x, y, w, h } da barra (EnemyHud.hpBarRect).
function Panel.drawEnemyGhost(game, rect)
    local R, frozen = Panel.current()
    if not R or frozen or not rect or not game.enemy then return end
    if (R.damage or 0) <= 0 then return end
    local e = game.enemy
    local maxHp = math.max(1, e.maxHealth or 1)
    local hp = e.health or 0
    local after = math.max(0, hp - R.damage)
    local x1 = rect.x + rect.w * (after / maxHp)
    local x2 = rect.x + rect.w * (hp / maxHp)
    local pulse = 0.55 + 0.35 * math.sin(love.timer.getTime() * 6)
    if _G.gameSettings and _G.gameSettings.reducedMotion then pulse = 0.8 end
    love.graphics.setColor(1, 0.92, 0.75, pulse)
    love.graphics.rectangle("fill", x1, rect.y, math.max(1, x2 - x1), rect.h)
    -- numero ao lado da barra
    local font = FontManager.getResponsiveFont(0.022, 16)
    love.graphics.setFont(font)
    local txt = "-" .. R.damage
    local col = R.lethal and { 1, 0.45, 0.55, 1 } or { 1, 0.85, 0.7, 1 }
    FontManager.drawWithOutline(txt, math.floor(rect.x + rect.w + 6),
        math.floor(rect.y + rect.h / 2 - font:getHeight() / 2), col, 0.95)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===========================================================================
-- Selos "+COMBO" nas cartas da mao
-- ===========================================================================

function Panel.drawHandBadges(game)
    if not next(state.badges) then return end
    local font = FontManager.getResponsiveFont(0.014, 11)
    love.graphics.setFont(font)
    local label = t("combo_badge", nil, "+COMBO")
    local tw = font:getWidth(label)
    for _, c in ipairs(game.hand or {}) do
        if state.badges[c] and c.renderX then
            local cw = (c.image and c.image.getWidth and c.image:getWidth() or 96)
                * (c.scale or c.baseScale or 1.333)
            local bx = math.floor(c.renderX + cw / 2 - tw / 2 - 4)
            local by = math.floor(c.renderY - font:getHeight() - 10)
            setColor(Palette.INK, 0.9)
            love.graphics.rectangle("fill", bx, by, tw + 8, font:getHeight() + 4, 3, 3)
            setColor(Palette.AGED_GOLD_LIGHT, 0.95)
            love.graphics.rectangle("line", bx, by, tw + 8, font:getHeight() + 4, 3, 3)
            FontManager.drawWithOutline(label, bx + 4, by + 2, COL_COMBO, 0.8)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Panel
