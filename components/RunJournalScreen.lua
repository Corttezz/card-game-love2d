-- components/RunJournalScreen.lua
-- ROTEIRO DA JORNADA — tela cheia com o caminho que o jogador REALMENTE
-- percorreu, ato por ato, terminando no castelo de cada ato.
--
-- Pedido do dono (Set/2026): "um mapa de tudo o que a gente já fez, tudo o que
-- a gente já escolheu, só para acompanhar ato por ato... como se fosse um
-- roteiro do que já passou. No final, ali, seu castelo, tipo um mapa do Slay
-- the Spire, mas sem opções futuras, só opções que já passaram."
--
-- Daí as três leis desta tela:
--   1. UM CAPÍTULO POR ATO, empilhados de cima pra baixo (lê como linha do
--      tempo). O castelo do bioma FECHA cada capítulo, à direita.
--   2. SEM RAMIFICAÇÃO. Uma linha só, o caminho real — nada de "o que eu
--      poderia ter escolhido".
--   3. ATO NÃO JOGADO NÃO APARECE. Faixa vazia lê como buraco na interface.
--
-- Redesenho (Out/2026, "a tela de logs tá muito feia"): a 1ª versão tinha
-- cenário de biblioteca competindo com o conteúdo, paradas todas do mesmo
-- peso, castelos maiores que a trilha e NADA dizia o que aconteceu sem passar
-- o mouse. Agora (memory/run_journal.md, variantes medidas):
--   • superfície lisa, sem cenário — mesmo idioma da loja (memory/shop_layout.md);
--   • uma COLUNA POR ANDAR, então a run inteira lê como grade;
--   • o RESULTADO de cada parada escrito sob ela (o que ganhou, vida, ouro);
--   • chefe/elite com disco maior e aro duplo — hierarquia de relance;
--   • o detalhe completo continua no hover, AO LADO da parada, dentro da
--     faixa do próprio ato (src/ui/RunJournalLayout.lua valida).
--
-- Abrir: clique no indicador de ATO da TopBar OU tecla M. ESC/M/X fecha.

local RunJournalScreen = {}
RunJournalScreen.__index = RunJournalScreen

local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local HintBar      = require("src.ui.HintBar")
local IconLoader   = require("src.ui.IconLoader")
local TextFit      = require("src.ui.TextFit")
local Layout       = require("src.ui.RunJournalLayout")
local CardDatabase = require("src.systems.CardDatabase")
local MapManager   = require("src.systems.MapManager")
local ActSystem    = require("src.systems.ActSystem")
local Sfx          = require("src.systems.Sfx")
local I18n         = require("src.i18n.I18n")
local TextCase     = require("src.i18n.TextCase")
local Debug        = require("src.core.Debug")
local biomes       = require("src.data.biomes")

local SCROLL_STEP = 48
local KEY_STEP    = 120

-- Ícone + cor por tipo de nó. Os nomes batem com MapManager.NODE_META.icon.
-- `major` = parada que decide a run (chefe/elite): disco cheio + aro duplo;
-- as demais usam o disco menor. É a hierarquia que a 1ª versão não tinha.
local NODE_STYLE = {
    battle    = { icon = "sword_short",   color = Palette.PARCHMENT },
    elite     = { icon = "skull",         color = Palette.RUST,  major = true },
    mini_boss = { icon = "skull_horned", color = Palette.BLOOD, major = true },
    boss      = { icon = "skull_crowned", color = Palette.AGED_GOLD_LIGHT, major = true, boss = true },
    shop      = { icon = "coin",          color = Palette.AGED_GOLD },
    rest      = { icon = "heart",         color = Palette.MOSS },
    event     = { icon = "scroll",        color = Palette.ARCANE },
}

-- Cores de texto sobre a superfície escura (as cores-base de acento são
-- escuras demais pra letra de 8px).
local COL_LOSS = Palette.lighten(Palette.BLOOD, 0.35)
local COL_GAIN = Palette.lighten(Palette.MOSS, 0.45)
local COL_GOLD = Palette.AGED_GOLD_LIGHT

-- Avisos de dado faltando saem UMA vez por chave (nada de fallback silencioso
-- — mas também nada de spam a 60fps).
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[roteiro] " .. msg)
end

local function styleFor(nodeType)
    local s = NODE_STYLE[nodeType]
    if s then return s end
    warnOnce("type:" .. tostring(nodeType),
        "tipo de nó desconhecido: " .. tostring(nodeType) .. " (usando ícone '?')")
    return { icon = "question", color = Palette.STEEL_LIGHT }
end

local function setAlpha(color, a)
    love.graphics.setColor(color[1], color[2], color[3], a)
end

-- ===== Assets (castelo do bioma) =========================================
local imgCache = {}
local function loadImage(path)
    local cached = imgCache[path]
    if cached ~= nil then return cached or nil end
    if not love.filesystem.getInfo(path) then
        imgCache[path] = false
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        imgCache[path] = false
        return nil
    end
    img:setFilter("nearest", "nearest")
    imgCache[path] = img
    return img
end

-- Bioma do ato: MESMA regra do WorldRoad.rawBiome (índice = ato, com wrap),
-- replicada aqui pra não acoplar a tela ao motor de cena.
local function biomeIdForAct(act)
    local n = #biomes
    if n == 0 then return nil end
    return biomes[((((act or 1) - 1) % n) + 1)].id
end

-- Castelo do ato. Conquistado usa o último frame da porta abrindo ("portão
-- aberto"); sem ele cai no castelo normal (o estado também vai escrito no
-- título do capítulo, então isto é enfeite, não dado).
local function castleImageFor(act, conquered)
    local bid = biomeIdForAct(act)
    if not bid then
        warnOnce("biomes", "src/data/biomes.lua vazio — sem castelo pra desenhar")
        return nil
    end
    if conquered then
        local dir = "assets/sprites/world/anim/" .. bid .. "_castle_door/"
        for i = 8, 0, -1 do
            local img = loadImage(dir .. i .. ".png")
            if img then return img end
        end
    end
    local img = loadImage("assets/sprites/world/" .. bid .. "_castle.png")
    if not img then
        warnOnce("castle:" .. bid,
            "sem assets/sprites/world/" .. bid .. "_castle.png — desenhando marco procedural")
    end
    return img
end

-- Opção escolhida num evento, no idioma ATUAL: pela chave do evento
-- (events.<id>.optN). O texto gravado no save (`optionLabel`) é do idioma
-- daquela hora — fica só de fallback (evento sem chave, save antigo).
function RunJournalScreen.optionText(e)
    if not e then return nil end
    if e.eventId and e.optionIndex then
        return I18n.t("events." .. e.eventId .. ".opt" .. e.optionIndex, nil, e.optionLabel)
    end
    return e.optionLabel
end

local function cardNameFor(id)
    local cd = id and CardDatabase:getCard(id)
    if not cd and id then
        warnOnce("card:" .. tostring(id), "carta do roteiro fora do catálogo: " .. tostring(id))
    end
    return cd and I18n.cardName(cd) or tostring(id)
end

-- ===== Ciclo de vida =====================================================

function RunJournalScreen:new()
    local instance = setmetatable({}, RunJournalScreen)
    instance.visible = false
    instance.game = nil
    instance.bands = {}
    instance.scroll = 0
    instance.maxScroll = 0
    instance._openedAt = 0
    instance._hover = nil      -- { band = índice, node = índice }
    return instance
end

-- Agrupa os nós visitados em faixas por ato, na ordem em que foram visitados.
-- Em endless o actNumber trava em totalActs+1, então uma faixa só — que cresce
-- em linhas de 8.
function RunJournalScreen:_build()
    self.bands = {}
    self.totals = { cards = 0, forges = 0, jokers = 0, removed = 0 }
    local rm = self.game and self.game.runManager
    if not rm or not rm.currentRun then
        Debug.log("[roteiro] sem run ativa — nada a mostrar")
        return
    end

    local run = rm.currentRun
    local band = nil
    for _, e in ipairs(rm:getJournal()) do
        if not band or band.act ~= (e.act or 1) then
            band = { act = e.act or 1, nodes = {} }
            table.insert(self.bands, band)
        end
        table.insert(band.nodes, e)
        for _, g in ipairs(e.gains or {}) do
            if g.kind == "card" then self.totals.cards = self.totals.cards + 1
            elseif g.kind == "forge" then self.totals.forges = self.totals.forges + 1
            elseif g.kind == "joker" then self.totals.jokers = self.totals.jokers + 1
            elseif g.kind == "remove" then self.totals.removed = self.totals.removed + 1
            end
        end
    end

    -- Ato concluído = o jogador já cruzou pra um ato posterior. O ato corrente
    -- fica "em progresso" mesmo com o boss no fim da lista, porque a travessia
    -- só acontece no advanceFloorInAct seguinte.
    local curAct = run.actNumber or 1
    for _, b in ipairs(self.bands) do
        b.conquered = b.act < curAct
        b.isEndless = run.endlessMode and b.act >= curAct
    end
end

function RunJournalScreen:show(game)
    self.visible = true
    self.game = game
    self._hover = nil
    self._openedAt = love.timer.getTime()
    self:_build()
    -- Abre no FIM (o ato em andamento — é onde o jogador está). O layout
    -- clampa pro maxScroll real.
    self.scroll = math.huge
    self:_layout()
    Sfx.play("menuOpen")
end

function RunJournalScreen:hide()
    self.visible = false
    self.bands = {}
    self._hover = nil
    Sfx.play("menuClose")
end

function RunJournalScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function RunJournalScreen:isVisible() return self.visible end

-- O layout inteiro é DERIVADO da janela a cada frame (_layout()); nenhuma
-- coordenada sobrevive a um resize. O único estado de posição guardado é o
-- scroll, e a janela nova pode ter um maxScroll menor — _layout reclampa.
function RunJournalScreen:resize()
    self._hover = nil
    return self:_layout()
end

function RunJournalScreen:update(dt) end

-- ===== Layout =============================================================

function RunJournalScreen:_closeRect()
    local sw = love.graphics.getWidth()
    return sw - 46, 18, 30, 30
end

function RunJournalScreen:_layout()
    local spec = {}
    for i, b in ipairs(self.bands) do spec[i] = { count = #b.nodes } end
    local L = Layout.compute(love.graphics.getWidth(), love.graphics.getHeight(),
        spec, self.scroll)
    self.scroll, self.maxScroll = L.scroll, L.maxScroll
    for i, lb in ipairs(L.bands) do lb.src = self.bands[i] end
    return L
end

-- ===== Input ==============================================================

function RunJournalScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * SCROLL_STEP))
    return true
end

function RunJournalScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "m" then
        self:hide()
    elseif key == "up" then
        self.scroll = math.max(0, self.scroll - SCROLL_STEP)
    elseif key == "down" then
        self.scroll = math.min(self.maxScroll, self.scroll + SCROLL_STEP)
    elseif key == "pageup" then
        self.scroll = math.max(0, self.scroll - KEY_STEP * 3)
    elseif key == "pagedown" then
        self.scroll = math.min(self.maxScroll, self.scroll + KEY_STEP * 3)
    elseif key == "home" then
        self.scroll = 0
    elseif key == "end" then
        self.scroll = self.maxScroll
    end
    return true   -- consome tudo enquanto aberta
end

function RunJournalScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    return true
end

function RunJournalScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    -- O RELEASE do mesmo clique que abriu (press na TopBar) chega aqui e
    -- fecharia a tela no mesmo frame — mesma armadilha do DeckViewerScreen.
    if love.timer.getTime() - (self._openedAt or 0) < 0.25 then return true end
    if button ~= 1 then return true end
    local cx, cy, cw, ch = self:_closeRect()
    if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
        self:hide()
    end
    return true
end

-- ===== Conteúdo de uma parada =============================================

-- A linha de RESULTADO sob a parada: o ganho mais importante, ou a opção do
-- evento. Devolve texto, cor, quantos ganhos ficaram de fora, e se é remoção
-- (desenhada riscada).
local function primaryOutcome(e)
    local gains = e.gains or {}
    if #gains > 0 then
        -- Prioridade: coringa > carta > forja > remoção (o que mais muda a run).
        local order = { joker = 1, card = 2, forge = 3, remove = 4 }
        local best = gains[1]
        for _, g in ipairs(gains) do
            if (order[g.kind] or 9) < (order[best.kind] or 9) then best = g end
        end
        local name = cardNameFor(best.id)
        if best.kind == "joker" then
            return name, COL_GOLD, #gains - 1
        elseif best.kind == "forge" then
            return name .. " +" .. (best.lvl or 1), Palette.lighten(Palette.RUST, 0.35), #gains - 1
        elseif best.kind == "remove" then
            return name, COL_LOSS, #gains - 1, true
        elseif best.kind ~= "card" then
            warnOnce("gain:" .. tostring(best.kind),
                "tipo de ganho desconhecido no roteiro: " .. tostring(best.kind))
        end
        return name, Palette.PARCHMENT_LIGHT, #gains - 1
    end
    if e.optionLabel then return RunJournalScreen.optionText(e), Palette.ARCANE_LIGHT, 0 end
    return nil
end

-- Linhas do detalhe completo (hover). Linha só aparece quando o valor MUDOU:
-- "Vida 56 -> 56" numa loja é ruído.
local function detailLines(e)
    local lines = {
        { t = MapManager.labelFor(e.type), c = Palette.lighten(styleFor(e.type).color, 0.25), big = true },
        { t = I18n.t("run_journal.node_at", { act = e.act or 1, floor = e.floor or 1 },
            "Ato " .. (e.act or 1) .. " - andar " .. (e.floor or 1)), c = Palette.STEEL_LIGHT },
    }
    if e.partial then
        table.insert(lines, { t = I18n.t("run_journal.no_details", nil,
            "Sem detalhes registrados"), c = Palette.STEEL_LIGHT })
        return lines
    end
    if e.hpIn and e.hpOut and e.hpIn ~= e.hpOut then
        table.insert(lines, {
            t = I18n.t("run_journal.hp_line", { from = e.hpIn, to = e.hpOut },
                "Vida " .. e.hpIn .. " -> " .. e.hpOut),
            c = (e.hpOut < e.hpIn) and COL_LOSS or COL_GAIN,
        })
    end
    if e.goldIn and e.goldOut and e.goldIn ~= e.goldOut then
        table.insert(lines, {
            t = I18n.t("run_journal.gold_line", { from = e.goldIn, to = e.goldOut },
                "Ouro " .. e.goldIn .. " -> " .. e.goldOut),
            c = COL_GOLD,
        })
    end
    if e.optionLabel then
        local opt = RunJournalScreen.optionText(e)
        table.insert(lines, { t = I18n.t("run_journal.event_option",
            { option = opt }, "Escolha: " .. opt), c = Palette.ARCANE_LIGHT })
    end
    for _, g in ipairs(e.gains or {}) do
        local name = cardNameFor(g.id)
        local txt, col
        if g.kind == "card" then
            txt = I18n.t("run_journal.gain_card", { name = name }, "Carta: " .. name)
            col = Palette.PARCHMENT_LIGHT
        elseif g.kind == "joker" then
            txt = I18n.t("run_journal.gain_joker", { name = name }, "Coringa: " .. name)
            col = COL_GOLD
        elseif g.kind == "forge" then
            txt = I18n.t("run_journal.gain_forge", { name = name, lvl = g.lvl or 1 },
                "Forja: " .. name .. " +" .. (g.lvl or 1))
            col = Palette.lighten(Palette.RUST, 0.35)
        elseif g.kind == "remove" then
            txt = I18n.t("run_journal.gain_remove", { name = name }, "Removida: " .. name)
            col = COL_LOSS
        else
            warnOnce("gain:" .. tostring(g.kind),
                "tipo de ganho desconhecido no roteiro: " .. tostring(g.kind))
            txt = tostring(g.kind) .. ": " .. name
            col = Palette.STEEL_LIGHT
        end
        table.insert(lines, { t = txt, c = col })
    end
    return lines
end

-- ===== Render =============================================================

-- Superfície lisa com luz central suave — o MESMO fundo da loja (Out/2026,
-- memory/shop_layout.md: o cenário pintado competia com o conteúdo).
local function drawBackdrop(sw, sh)
    Palette.set(Palette.darken(Palette.INK, 0.55))
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    local steps = 24
    for i = steps, 1, -1 do
        local k = i / steps
        love.graphics.setColor(Palette.INK[1] * 1.6, Palette.INK[2] * 1.6,
            Palette.INK[3] * 1.6, 0.10)
        love.graphics.ellipse("fill", sw * 0.5, sh * 0.45, sw * 0.62 * k, sh * 0.62 * k)
    end
end

-- Filete que desvanece pra fora (respiro, não moldura).
local function drawFadeRule(x0, y, len, side, color, alpha)
    local seg = len / 8
    for s = 0, 7 do
        setAlpha(color, alpha * (1 - s / 8))
        local sx = x0 + side * seg * s
        love.graphics.rectangle("fill", math.min(sx, sx + side * seg), y, seg, 1)
    end
end

local function drawDots(x1, y1, x2, y2, color, alpha)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end
    local n = math.max(1, math.floor(dist / 8))
    setAlpha(color, alpha)
    for i = 1, n - 1 do
        local t = i / n
        love.graphics.rectangle("fill", math.floor(x1 + dx * t) - 1, math.floor(y1 + dy * t) - 1, 2, 2)
    end
end

function RunJournalScreen:_drawHeader(L)
    local sw = L.sw
    local run = self.game and self.game.runManager and self.game.runManager.currentRun

    local tf = FontManager.getFont(L.sw >= 900 and 20 or 16)
    love.graphics.setFont(tf)
    local title = I18n.t("run_journal.title", nil, "ROTEIRO DA JORNADA")
    local tw = tf:getWidth(title)
    local tx = math.floor((sw - tw) / 2)
    local ty = 16
    FontManager.drawWithOutline(title, tx, ty, Palette.AGED_GOLD_LIGHT, 0.9)
    local ruleY = ty + math.floor(tf:getHeight() / 2)
    local ruleW = math.min(170, math.floor(sw * 0.15))
    drawFadeRule(tx - 18, ruleY, ruleW, -1, Palette.AGED_GOLD, 0.85)
    drawFadeRule(tx + tw + 18, ruleY, ruleW, 1, Palette.AGED_GOLD, 0.85)

    if run then
        local maxW = sw - 140
        setAlpha(Palette.PARCHMENT, 0.9)
        TextFit.print(I18n.t("run_journal.subtitle", {
            act = run.actNumber or 1,
            floor = run.floorInAct or 1,
            total = MapManager.FLOORS_PER_ACT,
            stops = #(run.mapHistory or {}),
        }, "ato " .. (run.actNumber or 1) .. " - andar " .. (run.floorInAct or 1))
            -- Selo do Grimório / ciclo e maldições do endless
            .. ((function() local m = require("src.ui.RunModsText").short(run)
                return m ~= "" and ("  ·  " .. m) or "" end)()),
            70, ty + tf:getHeight() + 12, { size = 10, maxW = maxW, align = "center" })

        local T = self.totals or {}
        setAlpha(Palette.AGED_GOLD, 0.85)
        TextFit.print(I18n.t("run_journal.summary", {
            cards = T.cards or 0, forges = T.forges or 0,
            jokers = T.jokers or 0, removed = T.removed or 0,
        }, "Cartas +" .. (T.cards or 0)),
            70, ty + tf:getHeight() + 30, { size = 9, maxW = maxW, align = "center" })
    end

    -- botão fechar
    local mx, my = love.mouse.getPosition()
    local cx, cy, cw, ch = self:_closeRect()
    require("src.ui.NavCursor").target("close", cx, cy, cw, ch)   -- foco de teclado/pad
    local hot = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
    setAlpha(hot and Palette.BLOOD or Palette.PANEL_FILL, 1)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
    setAlpha(Palette.AGED_GOLD, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)
    local xf = FontManager.getFont(14)
    love.graphics.setFont(xf)
    setAlpha(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.print("X", cx + (cw - xf:getWidth("X")) / 2, cy + (ch - xf:getHeight()) / 2)
end

function RunJournalScreen:_drawBandTitle(L, lb)
    local b = lb.src
    local label
    if b.isEndless then
        label = I18n.t("run_journal.endless", nil, "ENDLESS")
    else
        label = I18n.t("run_journal.act_label", { n = b.act }, "ATO " .. b.act)
            .. "  ·  " .. TextCase.upper(ActSystem.getActName(b.act))
    end

    local state, stateCol
    if b.isEndless then
        state = I18n.t("run_journal.stops", { n = #b.nodes }, #b.nodes .. " paradas")
        stateCol = Palette.PARCHMENT
    elseif b.conquered then
        state = I18n.t("run_journal.conquered", nil, "CONQUISTADO")
        stateCol = COL_GOLD
    else
        state = I18n.t("run_journal.act_progress",
            { x = #b.nodes, total = MapManager.FLOORS_PER_ACT },
            #b.nodes .. "/" .. MapManager.FLOORS_PER_ACT)
        stateCol = Palette.PARCHMENT
    end

    -- Estado à direita primeiro: o nome do ato cede (TextFit) se não couber.
    local sf = FontManager.getFont(9)
    local stateW = math.min(sf:getWidth(state), math.floor(lb.w * 0.4))
    setAlpha(stateCol, 0.95)
    TextFit.print(state, lb.x + lb.w - stateW, lb.y + 6, { size = 9, maxW = stateW, align = "right" })

    setAlpha(b.conquered and COL_GOLD or Palette.PARCHMENT_LIGHT, 1)
    TextFit.print(label, lb.x, lb.y + 4, { size = 12, maxW = lb.w - stateW - 16 })

    setAlpha(Palette.AGED_GOLD_DARK, 0.6)
    love.graphics.rectangle("fill", lb.x, lb.y + Layout.TITLE_H - 6, lb.w, 1)
end

function RunJournalScreen:_drawCell(L, cell, e, hovered, isCurrent)
    local st = styleFor(e.type)
    local d = st.major and L.disc or L.smallDisc
    local r = d / 2
    local fade = e.partial and 0.5 or 1

    if hovered then
        setAlpha(Palette.AGED_GOLD, 0.10)
        love.graphics.rectangle("fill", cell.x + 2, cell.y - 3, cell.w - 4, cell.h + 4, 4, 4)
    end

    -- número do andar, discreto no canto (a coluna já diz, isto confirma)
    love.graphics.setFont(FontManager.getFont(8))
    setAlpha(Palette.PARCHMENT_DARK, 0.9)
    love.graphics.print(tostring(e.floor or "?"), cell.x + 4, cell.y)

    -- disco
    setAlpha(Palette.INK, 0.95)
    love.graphics.circle("fill", cell.cx, cell.cy, r)
    local ringA = fade
    if isCurrent then ringA = 0.6 + (math.cos(love.timer.getTime() * 5) + 1) * 0.2 end
    love.graphics.setLineWidth(st.major and 3 or 2)
    setAlpha(st.color, ringA)
    love.graphics.circle("line", cell.cx, cell.cy, r)
    if st.major then
        -- aro duplo: chefe/elite se destaca na grade sem precisar ler nada
        love.graphics.setLineWidth(1)
        setAlpha(st.color, 0.55 * fade)
        love.graphics.circle("line", cell.cx, cell.cy, r + 4)
    end
    if hovered then
        love.graphics.setLineWidth(1)
        setAlpha(Palette.AGED_GOLD_LIGHT, 0.9)
        love.graphics.circle("line", cell.cx, cell.cy, r + (st.major and 7 or 4))
    end

    local icon = IconLoader.get(st.icon)
    if icon and icon.size then
        local sc = (d * 0.62) / icon.size.h
        love.graphics.setColor(1, 1, 1, fade)
        icon.draw(cell.cx - icon.size.w * sc / 2, cell.cy - icon.size.h * sc / 2, sc)
    end

    -- ===== resultado (2 linhas sob o disco) =====
    local pad = 4
    local maxW = cell.w - pad * 2
    local y1 = cell.textY
    local y2 = y1 + L.lineH
    local size = L.lineSize

    local txt, col, extra, struck = primaryOutcome(e)
    if txt then
        -- Ganhos além do principal viram PIPS dourados, não "+N": "+1" ao lado
        -- de um nome já significa forja nesta tela.
        local pips = math.min(3, extra or 0)
        local pipW = pips > 0 and (pips * 5 + 3) or 0
        setAlpha(col, fade)
        local w = TextFit.print(txt, cell.x + pad, y1,
            { size = size, maxW = maxW - pipW, align = "center", minSize = 8 })
        local tx = cell.x + pad + math.floor((maxW - pipW - w) / 2)
        if struck then
            love.graphics.rectangle("fill", tx, y1 + math.floor(size / 2), w, 1)
        end
        setAlpha(COL_GOLD, 0.9 * fade)
        for k = 1, pips do
            love.graphics.rectangle("fill", tx + w + 3 + (k - 1) * 5,
                y1 + math.floor(size / 2) - 1, 3, 3)
        end
    end

    -- Vida e ouro: número com sinal + ícone pequeno (independe de idioma).
    if isCurrent then
        setAlpha(COL_GOLD, ringA)
        TextFit.print(I18n.t("run_journal.now", nil, "AGORA"), cell.x + pad, y2,
            { size = size, maxW = maxW, align = "center" })
    elseif not e.partial then
        local parts = {}
        if e.hpIn and e.hpOut and e.hpIn ~= e.hpOut then
            local dlt = e.hpOut - e.hpIn
            parts[#parts + 1] = { icon = "heart", t = (dlt > 0 and "+" or "") .. dlt,
                c = dlt < 0 and COL_LOSS or COL_GAIN }
        end
        if e.goldIn and e.goldOut and e.goldIn ~= e.goldOut then
            local dlt = e.goldOut - e.goldIn
            parts[#parts + 1] = { icon = "coin", t = (dlt > 0 and "+" or "") .. dlt, c = COL_GOLD }
        end
        if #parts > 0 then
            local font = FontManager.getFont(size)
            local iconS = size + 2
            local gap = 6
            local total = 0
            for _, p in ipairs(parts) do total = total + iconS + 2 + font:getWidth(p.t) end
            total = total + gap * (#parts - 1)
            -- Coluna estreita demais pros dois: fica só a vida (o ouro está
            -- no detalhe e no subtítulo).
            if total > maxW and #parts > 1 then
                parts = { parts[1] }
                total = iconS + 2 + font:getWidth(parts[1].t)
            end
            local x = cell.x + math.floor((cell.w - total) / 2)
            love.graphics.setFont(font)
            for _, p in ipairs(parts) do
                local ic = IconLoader.get(p.icon)
                if ic and ic.size then
                    local sc = iconS / ic.size.h
                    love.graphics.setColor(1, 1, 1, 1)
                    ic.draw(x, y2 - 1, sc)
                end
                x = x + iconS + 2
                setAlpha(p.c, 1)
                love.graphics.print(p.t, x, y2)
                x = x + font:getWidth(p.t) + gap
            end
        end
    end
end

function RunJournalScreen:_drawCastle(lb)
    local b = lb.src
    local r = lb.castle
    local img = castleImageFor(b.act, b.conquered)
    if img then
        local sc = math.min(r.w / img:getWidth(), r.h / img:getHeight())
        local dw, dh = img:getWidth() * sc, img:getHeight() * sc
        if b.conquered then
            love.graphics.setColor(1, 1, 1, 1)
        else
            -- Ainda não conquistado: silhueta ao longe (escura, mas legível).
            love.graphics.setColor(0.40, 0.37, 0.40, 0.9)
        end
        love.graphics.draw(img, math.floor(r.x + (r.w - dw) / 2),
            math.floor(r.y + (r.h - dh) / 2), 0, sc, sc)
    else
        local w = math.min(r.w, r.h * 0.8)
        local x = r.x + (r.w - w) / 2
        setAlpha(b.conquered and Palette.PARCHMENT_DARK or Palette.INK, 0.95)
        love.graphics.rectangle("fill", x, r.y + r.h * 0.25, w, r.h * 0.75)
        setAlpha(b.conquered and Palette.AGED_GOLD or Palette.STEEL, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, r.y + r.h * 0.25, w, r.h * 0.75)
    end
end

-- Monta as linhas do detalhe cortadas à altura disponível e devolve o
-- retângulo já resolvido pelo layout. Exposto pros testes (validate do hover).
function RunJournalScreen:_tipFor(L, bi, ni)
    local lb = L.bands[bi]
    local cell = lb and lb.cells[ni]
    local e = lb and lb.src and lb.src.nodes[ni]
    if not cell or not e then return nil end

    local fBig, fSm = FontManager.getFont(12), FontManager.getFont(9)
    local padX, padY, gap = 10, 8, 4
    local lines = detailLines(e)
    local maxH = Layout.maxTipH(L, lb)
    local function heightOf(n)
        local h = padY * 2
        for i = 1, n do
            h = h + (lines[i].big and fBig or fSm):getHeight() + (i > 1 and gap or 0)
        end
        return h
    end
    -- Faixa quase toda rolada pra fora: não há onde ancorar o detalhe sem
    -- invadir a vizinha — melhor nenhum (a parada continua com o resultado).
    if heightOf(1) > maxH then return nil end
    -- Corta até caber; a última linha visível vira "+N mais".
    if heightOf(#lines) > maxH then
        local n = #lines
        while n > 1 and heightOf(n) > maxH do n = n - 1 end
        local hidden = #lines - n + 1
        for i = #lines, n, -1 do lines[i] = nil end
        if n > 1 then
            lines[n] = { t = I18n.t("run_journal.more", { n = hidden }, "+" .. hidden),
                c = Palette.STEEL_LIGHT }
        end
    end

    local maxW = math.min(380, Layout.tipRoom(L, cell))
    local w = 0
    for _, l in ipairs(lines) do
        w = math.max(w, (l.big and fBig or fSm):getWidth(l.t))
    end
    w = math.min(maxW, w + padX * 2)
    local h = heightOf(#lines)
    local rect = Layout.tipRect(L, lb, cell, w, h)
    return { rect = rect, band = bi, cell = cell, lines = lines,
             padX = padX, padY = padY, gap = gap }
end

function RunJournalScreen:_drawTip(tip)
    local r = tip.rect
    setAlpha(Palette.INK, 0.97)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
    setAlpha(Palette.AGED_GOLD, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
    local ty = r.y + tip.padY
    for i, l in ipairs(tip.lines) do
        local size = l.big and 12 or 9
        setAlpha(l.c, 1)
        local _, fh = TextFit.print(l.t, r.x + tip.padX, ty,
            { size = size, maxW = r.w - tip.padX * 2, minSize = l.big and 9 or 8 })
        ty = ty + FontManager.getFont(size):getHeight() + tip.gap
    end
end

function RunJournalScreen:draw()
    if not self.visible then return end
    local L = self:_layout()
    local sw, sh = L.sw, L.sh
    local mx, my = love.mouse.getPosition()

    drawBackdrop(sw, sh)
    self:_drawHeader(L)

    if #L.bands == 0 then
        setAlpha(Palette.PARCHMENT, 0.85)
        TextFit.print(I18n.t("run_journal.empty", nil, "Nenhum caminho percorrido ainda."),
            20, math.floor(L.zone.y + L.zone.h / 3), { size = 12, maxW = sw - 40, align = "center" })
        HintBar.draw(I18n.t("run_journal.hint", nil, "M ou ESC fecha"))
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- ===== ZONA CAPÍTULOS =====
    local z = L.zone
    local mouseInZone = my >= z.y and my <= z.y + z.h
    self._hover = nil
    love.graphics.setScissor(0, z.y, sw, z.h)
    local rm = self.game and self.game.runManager

    for bi, lb in ipairs(L.bands) do
        if lb.y + lb.h >= z.y and lb.y <= z.y + z.h then
            self:_drawBandTitle(L, lb)

            -- trilha: pontilhado por linha, passando pelo centro dos discos
            for i = 1, #lb.cells - 1 do
                local a, c = lb.cells[i], lb.cells[i + 1]
                if a.row == c.row then
                    drawDots(a.cx, a.cy, c.cx, c.cy, Palette.AGED_GOLD, 0.55)
                end
            end
            local last = lb.cells[#lb.cells]
            if last and last.row == lb.rows - 1 then
                drawDots(last.cx, last.cy, lb.castle.x + 6, last.cy,
                    Palette.AGED_GOLD, lb.src.conquered and 0.55 or 0.18)
            end

            for ni, cell in ipairs(lb.cells) do
                local e = lb.src.nodes[ni]
                local hovered = mouseInZone and mx >= cell.x and mx < cell.x + cell.w
                    and my >= cell.y and my < cell.y + cell.h
                local isCurrent = rm and rm.isJournalEntryOpen
                    and rm:isJournalEntryOpen(e) or false
                self:_drawCell(L, cell, e, hovered, isCurrent)
                if hovered then self._hover = { band = bi, node = ni } end
            end

            self:_drawCastle(lb)
        end
    end
    love.graphics.setScissor()

    -- barra de rolagem (só existe quando há o que rolar)
    if L.maxScroll > 0 then
        local barX = sw - 9
        local frac = L.scroll / L.maxScroll
        local knobH = math.max(30, z.h * (z.h / (z.h + L.maxScroll)))
        setAlpha(Palette.INK, 0.7)
        love.graphics.rectangle("fill", barX, z.y, 4, z.h, 2, 2)
        setAlpha(Palette.AGED_GOLD, 0.9)
        love.graphics.rectangle("fill", barX, z.y + frac * (z.h - knobH), 4, knobH, 2, 2)
    end

    if self._hover then
        local tip = self:_tipFor(L, self._hover.band, self._hover.node)
        if tip then self:_drawTip(tip) end
    end

    HintBar.draw(I18n.t("run_journal.hint", nil,
        "PASSE O MOUSE numa parada pra ver tudo  ·  RODA ou SETAS rolam  ·  M ou ESC fecha"))
    love.graphics.setColor(1, 1, 1, 1)
end

return RunJournalScreen
