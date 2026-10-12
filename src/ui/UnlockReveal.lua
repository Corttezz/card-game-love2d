-- src/ui/UnlockReveal.lua
-- REVELAÇÃO PÓS-RUN (StS UnlockScreen + popup de desbloqueio do Balatro):
-- a barra de MAESTRIA da classe enche com o XP da run (atravessando níveis com
-- flash + som), depois as cartas/classes liberadas aparecem UMA POR VEZ com pop.
--
-- Consumido por src/scenes/EndScreens.lua (gameOver/victory). Sem update
-- externo: tica no draw via love.timer.getDelta, igual ao título DynaText das
-- telas finais. Recomeça sozinho quando recebe um `result` novo (identidade).
--
-- Layout = UMA banda (x,y,w,h) recebida de quem chama; dentro dela, sub-bandas
-- fixas (cabeçalho / barra / vitrine / rodapé). Falta de espaço encolhe a
-- ESCALA das cartas, nunca empurra as bandas (lei de layout do projeto).

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local I18n        = require("src.i18n.I18n")
local Easing      = require("engine.Easing")
local Sfx         = require("src.systems.Sfx")

local UnlockReveal = {}

-- Tempos (s). Uma tabela só pra tunar o ritmo.
local T = {
    START_DELAY  = 0.6,   -- respira depois do CRT religar
    BAR_PER_LVL  = 0.8,   -- tempo pra encher UM nível inteiro
    LEVEL_HOLD   = 0.3,  -- pausa no flash de nível
    ITEM_GAP     = 0.24,  -- entre uma carta/classe e a próxima
    POP          = 0.42,  -- duração do pop de cada carta
}

local st = nil   -- estado da animação corrente

local function className(id)
    return I18n.t("classes." .. tostring(id) .. ".name", nil, tostring(id))
end

-- Segmentos da barra: lista de { from=0..1, to=0..1, level=n, levelUp=bool }.
local function buildSegments(before, after)
    local segs = {}
    if not before or not after then return segs end
    local lvl = before.level
    local frac = (before.xpToNext > 0) and (before.xp / before.xpToNext) or 1
    while lvl < after.level do
        segs[#segs + 1] = { from = frac, to = 1, level = lvl, levelUp = true }
        lvl = lvl + 1
        frac = 0
    end
    local toFrac = (after.xpToNext > 0) and (after.xp / after.xpToNext) or 1
    segs[#segs + 1] = { from = frac, to = toFrac, level = lvl, levelUp = false }
    return segs
end

function UnlockReveal.start(result)
    st = {
        result = result, t = 0, items = {}, segs = {},
        sfxBar = {}, sfxItem = {}, flash = 0,
    }
    if not result then return end
    st.segs = buildSegments(result.before, result.after)
    -- Duração de cada segmento proporcional ao trecho da barra.
    local t = T.START_DELAY
    for _, sg in ipairs(st.segs) do
        sg.t0 = t
        sg.dur = math.max(0.25, (sg.to - sg.from) * T.BAR_PER_LVL)
        t = t + sg.dur + (sg.levelUp and T.LEVEL_HOLD or 0)
    end
    st.barEnd = t
    -- Itens: classes primeiro (é o maior evento), depois cartas.
    for _, c in ipairs(result.newClasses or {}) do
        st.items[#st.items + 1] = { kind = "class", id = c }
    end
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    for _, id in ipairs(result.newCards or {}) do
        local cd = db:getCard(id)
        if cd then
            local ok, inst = pcall(function() return db:createCardInstance(cd) end)
            if ok and inst then
                st.items[#st.items + 1] = { kind = "card", id = id, inst = inst }
            else
                print("[UnlockReveal] falha ao instanciar " .. tostring(id))
            end
        else
            print("[UnlockReveal] carta desconhecida no resultado: " .. tostring(id))
        end
    end
    for i, it in ipairs(st.items) do
        it.t0 = st.barEnd + 0.15 + (i - 1) * T.ITEM_GAP
    end
end

-- Pra ferramentas de captura: pula a animação pro estado final.
function UnlockReveal.finish()
    if st then st.t = 1e6 end
end

function UnlockReveal.isDone()
    if not st then return true end
    local last = st.items[#st.items]
    return st.t >= ((last and last.t0 + T.POP) or st.barEnd)
end

local function setC(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

local function printCentered(text, font, cx, y)
    love.graphics.setFont(font)
    love.graphics.print(text, math.floor(cx - font:getWidth(text) / 2), math.floor(y))
end

-- Banda: x,y,w,h. result = game.unlockResult.
function UnlockReveal.draw(result, x, y, w, h)
    if not result then return end
    if not st or st.result ~= result then UnlockReveal.start(result) end
    local prevT = st.t
    -- dtOverride: ferramentas de captura avançam o relógio em passos fixos.
    local dt = UnlockReveal.dtOverride or love.timer.getDelta()
    st.t = st.t + dt
    local t = st.t
    st.flash = math.max(0, st.flash - dt * 2.5)

    local cx = x + w / 2
    -- Placa escura atrás da banda: o fundo das telas finais é ilustração
    -- cheia de detalhe e a barra/rotulos sumiam nele.
    setC(Palette.INK, 0.72 * math.min(1, t / 0.3))
    love.graphics.rectangle("fill", x, y - 8, w, h + 8)
    setC(Palette.AGED_GOLD_DARK, 0.8 * math.min(1, t / 0.3))
    love.graphics.rectangle("line", x + 0.5, y - 7.5, w - 1, h + 7)
    local headF = FontManager.getFont(h < 260 and 12 or 14)
    local smallF = FontManager.getFont(10)

    -- ===== Banda 1: cabeçalho (classe + XP) =====
    local headH = headF:getHeight() + 8
    if result.classId and result.after then
        local alpha = math.min(1, t / 0.4)
        setC(Palette.AGED_GOLD_LIGHT, alpha)
        printCentered(I18n.t("unlocks.reveal.title", { class = require("src.i18n.TextCase").upper(className(result.classId)) }),
            headF, cx, y)
    end

    -- ===== Banda 2: barra de maestria =====
    local barW = math.min(560, w * 0.8)
    local barH = 16
    local barX = math.floor(cx - barW / 2)
    local barY = math.floor(y + headH + smallF:getHeight() + 6)
    local segs = st.segs
    if #segs > 0 then
        -- Segmento corrente e fração.
        local cur, frac = segs[1], segs[1].from
        for _, sg in ipairs(segs) do
            if t >= sg.t0 then
                cur = sg
                local k = math.min(1, (t - sg.t0) / sg.dur)
                frac = sg.from + (sg.to - sg.from) * Easing.outQuart(k)
                -- Som: tick a cada ~12% enchido; nível = acorde grande.
                local bucket = math.floor(frac * 8)
                local key = sg.level .. ":" .. bucket
                if k < 1 and not st.sfxBar[key] and prevT > 0 then
                    st.sfxBar[key] = true
                    Sfx.play("coinClink", { pitch = 0.9 + bucket * 0.06, volume = 0.5 })
                end
                if sg.levelUp and k >= 1 and not st.sfxBar["up" .. sg.level] then
                    st.sfxBar["up" .. sg.level] = true
                    st.flash = 1
                    Sfx.play("actComplete")
                end
            end
        end
        local after = result.after
        local maxed = after.level >= after.maxLevel and cur == segs[#segs]
        -- Rótulos sobre a barra: nível à esquerda, xp à direita.
        love.graphics.setFont(smallF)
        local lvlShown = cur.level + ((cur.levelUp and frac >= 1) and 1 or 0)
        local lvlTxt = maxed and I18n.t("unlocks.reveal.max")
            or I18n.t("unlocks.reveal.level", { level = lvlShown })
        setC(Palette.PARCHMENT_LIGHT)
        love.graphics.print(lvlTxt, barX, barY - smallF:getHeight() - 3)
        local xpTxt = I18n.t("unlocks.reveal.xp", { xp = result.xpGained or 0 })
        setC(Palette.AGED_GOLD_LIGHT, math.min(1, t / 0.6))
        love.graphics.print(xpTxt, barX + barW - smallF:getWidth(xpTxt), barY - smallF:getHeight() - 3)
        -- Trilho + preenchimento + brilho de flash.
        setC(Palette.INK, 0.85)
        love.graphics.rectangle("fill", barX - 2, barY - 2, barW + 4, barH + 4)
        setC(Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", barX - 2, barY - 2, barW + 4, barH + 4)
        local fillW = math.floor(barW * math.max(0, math.min(1, frac)))
        setC(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, barY, fillW, barH)
        setC(Palette.AGED_GOLD_LIGHT)
        love.graphics.rectangle("fill", barX, barY, fillW, 3)
        if st.flash > 0 then
            love.graphics.setColor(1, 1, 1, st.flash * 0.7)
            love.graphics.rectangle("fill", barX - 2, barY - 2, barW + 4, barH + 4)
            local upF = FontManager.getFont(12)
            setC(Palette.AGED_GOLD_LIGHT, st.flash)
            printCentered(I18n.t("unlocks.reveal.level_up"), upF, cx,
                barY + barH + 4 - (1 - st.flash) * 10)
        end
    end

    -- ===== Banda 3: vitrine (classes + cartas) =====
    local vitY = barY + barH + 22
    local vitH = (y + h) - vitY
    if vitH <= 20 then return end
    local items = st.items
    if #items == 0 then
        if t >= st.barEnd then
            setC(Palette.PARCHMENT, math.min(1, (t - st.barEnd) / 0.5))
            printCentered(I18n.t("unlocks.reveal.none"), smallF, cx, vitY + 8)
        end
        return
    end

    -- Cabeçalho da vitrine (nome dos pacotes liberados nesta run).
    local labelH = smallF:getHeight() + 6
    if t >= st.barEnd then
        local parts = {}
        for _, b in ipairs(result.bundles or {}) do
            parts[#parts + 1] = I18n.t("unlocks.bundle." .. b.theme, nil, b.theme)
        end
        local label = I18n.t("unlocks.reveal.new_cards")
        if #parts > 0 then label = label .. "  -  " .. table.concat(parts, "  /  ") end
        setC(Palette.AGED_GOLD_LIGHT, math.min(1, (t - st.barEnd) / 0.4))
        printCentered(label, smallF, cx, vitY)
    end

    -- Escala das cartas: cabe em altura e em largura (nunca empurra banda).
    local nCards, nClasses = 0, 0
    for _, it in ipairs(items) do
        if it.kind == "card" then nCards = nCards + 1 else nClasses = nClasses + 1 end
    end
    local classW = 0
    if nClasses > 0 then classW = math.min(220, w * 0.3) end
    local gap = 12
    local availH = vitH - labelH - 8
    local availW = w * 0.94 - (nClasses > 0 and (classW * nClasses + gap * nClasses) or 0)
    local scale = math.min(availH / 144, 1.6)
    if nCards > 0 then
        scale = math.min(scale, (availW - gap * (nCards - 1)) / (96 * nCards))
    end
    scale = math.max(0.35, scale)
    local cw, ch = 96 * scale, 144 * scale
    local rowW = nCards * cw + math.max(0, nCards - 1) * gap
        + nClasses * (classW + gap)
    local ix = cx - rowW / 2
    local iy = vitY + labelH + 4

    for _, it in ipairs(items) do
        local k = (t - it.t0) / T.POP
        if k >= 0 and not st.sfxItem[it] then
            st.sfxItem[it] = true
            if it.kind == "class" then Sfx.play("packSealBreak")
            else
                st.nPopped = (st.nPopped or 0) + 1
                Sfx.play("packCardReveal", { pitch = 0.92 + st.nPopped * 0.04 })
            end
        end
        if it.kind == "class" then
            if k > 0 then
                local e = Easing.backOut(math.min(1, k))
                local bx, by = ix, iy + ch / 2 - 40
                love.graphics.push()
                love.graphics.translate(bx + classW / 2, by + 40)
                love.graphics.scale(e, e)
                setC(Palette.INK, 0.92)
                love.graphics.rectangle("fill", -classW / 2, -40, classW, 80)
                setC(Palette.AGED_GOLD)
                love.graphics.rectangle("line", -classW / 2, -40, classW, 80)
                local f1 = FontManager.getFont(10)
                local f2 = FontManager.getFont(16)
                setC(Palette.PARCHMENT_LIGHT)
                printCentered(I18n.t("unlocks.reveal.new_class"), f1, 0, -30)
                local pulse = 0.85 + 0.15 * math.sin(t * 4)
                setC(Palette.AGED_GOLD_LIGHT, pulse)
                printCentered(className(it.id), f2, 0, -4)
                love.graphics.pop()
            end
            ix = ix + classW + gap
        else
            if k > 0 and it.inst and it.inst.image then
                local e = Easing.backOut(math.min(1, k))
                local img = it.inst.image
                local s = scale * e
                local wob = (1 - math.min(1, k)) * 0.25
                local px, py = ix + cw / 2, iy + ch / 2
                love.graphics.setColor(0, 0, 0, 0.45 * math.min(1, k))
                love.graphics.draw(img, px + 5, py + 8, wob, s, s,
                    img:getWidth() / 2, img:getHeight() / 2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, px, py, wob, s, s,
                    img:getWidth() / 2, img:getHeight() / 2)
                -- Brilho de entrada (some em ~0.4s).
                if k < 1 then
                    love.graphics.setColor(1, 1, 1, (1 - k) * 0.6)
                    love.graphics.rectangle("fill", px - cw / 2 * e, py - ch / 2 * e, cw * e, ch * e)
                end
            end
            ix = ix + cw + gap
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return UnlockReveal
