-- components/RunJournalScreen.lua
-- ROTEIRO DA JORNADA — um MAPA DESENHADO À MÃO, por ato, numa folha de
-- pergaminho envelhecida.
--
-- Pedido do dono (13/Out/2026): "Quero que ele seja literalmente um mapa, bem
-- parecido com o mapa do Slay the Spire, que vai mostrando ali os trilhos que
-- a gente vai seguindo e as decisões que a gente vai tomando. A gente
-- consegue abrir e fechar o mapa para cada ato... como se tivesse sido
-- escrito à mão, apenas com tinta preta e, no máximo, um círculo vermelho.
-- Bem cara de mapa mesmo, com uma folha envelhecida."
--
-- Daí as leis desta tela:
--   1. UMA FOLHA POR ATO, empilhadas; cada uma ABRE e FECHA (o ato em
--      andamento nasce aberto, os anteriores fechados numa tira com o título).
--   2. O mapa SOBE (andar 1 embaixo, castelo no topo), como no StS. Em cada
--      encruzilhada aparecem os ramos que EXISTIAM: o tomado em traço cheio,
--      os outros em pontilhado esmaecido terminando curto (não explorado).
--      A encruzilhada ainda em aberto (pendingNodes) aparece à frente.
--   3. SÓ TINTA PRETA no papel, e no máximo UM círculo vermelho: onde o
--      jogador está. Nada de ícone PNG, foto de castelo nem cor de acento.
--      Os símbolos são glifos de pena (src/ui/RunJournalInk.lua), o traço
--      ondula por seed da run (sempre igual pra mesma run).
--   4. O resultado de cada parada vira ANOTAÇÃO À MARGEM, em letra miúda.
--   5. ATO NÃO JOGADO NÃO APARECE.
--
-- Layout por ZONAS em src/ui/RunJournalLayout.lua (puro, validate()).
-- Abrir: clique no indicador de ATO da TopBar OU tecla M. ESC/M/X fecha.
-- Teclado/pad: setas rolam, Enter/A abre ou fecha o ato focado (NavCursor),
-- 1..9 abre ou fecha o ato N.

local RunJournalScreen = {}
RunJournalScreen.__index = RunJournalScreen

local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local TextFit      = require("src.ui.TextFit")
local Layout       = require("src.ui.RunJournalLayout")
local Ink          = require("src.ui.RunJournalInk")
local CardDatabase = require("src.systems.CardDatabase")
local MapManager   = require("src.systems.MapManager")
local ActSystem    = require("src.systems.ActSystem")
local Sfx          = require("src.systems.Sfx")
local I18n         = require("src.i18n.I18n")
local TextCase     = require("src.i18n.TextCase")
local Debug        = require("src.core.Debug")

local SCROLL_STEP = 48
local KEY_STEP    = 120
local INK, RED    = Ink.INK, Ink.RED

-- Avisos de dado faltando saem UMA vez por chave (nada de fallback silencioso
-- — mas também nada de spam a 60fps).
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[roteiro] " .. msg)
end

local function glyphFor(nodeType)
    if Ink.hasGlyph(nodeType) then return nodeType end
    warnOnce("type:" .. tostring(nodeType),
        "tipo de nó sem glifo: " .. tostring(nodeType) .. " (usando o círculo)")
    return "unknown"
end

local function setAlpha(color, a)
    love.graphics.setColor(color[1], color[2], color[3], a)
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

local function signed(n)
    return (n > 0 and "+" or "") .. tostring(n)
end

-- ===== Ciclo de vida =====================================================

function RunJournalScreen:new()
    local instance = setmetatable({}, RunJournalScreen)
    instance.visible = false
    instance.game = nil
    instance.acts = {}
    instance.scroll = 0
    instance.maxScroll = 0
    instance._openedAt = 0
    instance._hover = nil      -- { sheet = i, node = j } | { sheet = i, stub = k } | { sheet = i, title = true }
    instance._seed = 0
    return instance
end

-- Agrupa os nós visitados em atos, na ordem em que foram visitados, e decide
-- a LINHA de cada parada no mapa: andar (ato normal) ou índice (endless, em
-- que o par ato/andar se repete).
function RunJournalScreen:_build()
    self.acts = {}
    self.totals = { cards = 0, forges = 0, jokers = 0, removed = 0 }
    local rm = self.game and self.game.runManager
    if not rm or not rm.currentRun then
        Debug.log("[roteiro] sem run ativa — nada a mostrar")
        return
    end

    local run = rm.currentRun
    self._seed = tonumber(run.runSeed) or 0
    local band = nil
    for _, e in ipairs(rm:getJournal()) do
        if not band or band.act ~= (e.act or 1) then
            band = { act = e.act or 1, nodes = {} }
            table.insert(self.acts, band)
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
    for i, b in ipairs(self.acts) do
        b.conquered = b.act < curAct
        b.isEndless = run.endlessMode and b.act >= curAct
        b.open = (i == #self.acts)     -- o ato em andamento nasce aberto
        -- linhas
        local lastRow = 0
        for j, e in ipairs(b.nodes) do
            local row
            if b.isEndless then
                row = j
            else
                row = math.max(1, math.min(Layout.FLOORS, tonumber(e.floor) or j))
                if row <= lastRow then row = math.min(Layout.FLOORS, lastRow + 1) end
            end
            e._row = row
            lastRow = row
        end
        -- a encruzilhada ainda em aberto só existe no ÚLTIMO ato
        b.pending = nil
        if i == #self.acts and run.pendingNodes and #run.pendingNodes > 0 then
            local row = lastRow + 1
            if b.isEndless or row <= Layout.FLOORS then
                b.pending = { row = row, types = {} }
                for k, nd in ipairs(run.pendingNodes) do b.pending.types[k] = nd.type end
            end
        end
        -- legenda: os tipos que aparecem na folha (tomados, ramos e à frente)
        local seen, list = {}, {}
        local function note(t)
            t = glyphFor(t)
            if not seen[t] then seen[t] = true; list[#list + 1] = t end
        end
        for _, e in ipairs(b.nodes) do
            note(e.type)
            for _, t in ipairs(e.branches or {}) do note(t) end
        end
        for _, t in ipairs((b.pending and b.pending.types) or {}) do note(t) end
        b.legend = list
    end
end

function RunJournalScreen:show(game)
    self.visible = true
    self.game = game
    self._hover = nil
    self._openedAt = love.timer.getTime()
    self:_build()
    -- Abre com o ato em andamento (a última folha) visível por inteiro.
    self.scroll = 0
    local L = self:_layout()
    local last = L.sheets[#L.sheets]
    if last then
        self.scroll = math.max(0, last.y + L.scroll - L.zone.y - Layout.TOP_SLACK)
        self:_layout()
    end
    Sfx.play("menuOpen")
end

function RunJournalScreen:hide()
    self.visible = false
    self.acts = {}
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
    Ink.clearPaperCache()
    return self:_layout()
end

function RunJournalScreen:update(dt) end

-- ===== Layout =============================================================

function RunJournalScreen:_closeRect()
    local sw = love.graphics.getWidth()
    return sw - 46, 16, 30, 30
end

function RunJournalScreen:_spec()
    local spec = {}
    for i, b in ipairs(self.acts) do
        local nodes = {}
        for j, e in ipairs(b.nodes) do
            nodes[j] = { row = e._row, n = e.branches and #e.branches or 1, pick = e.pick or 1 }
        end
        spec[i] = {
            open = b.open, isEndless = b.isEndless, nodes = nodes,
            pending = b.pending and { row = b.pending.row, n = #b.pending.types } or nil,
            legend = #(b.legend or {}),
        }
    end
    return spec
end

function RunJournalScreen:_layout()
    local L = Layout.compute(love.graphics.getWidth(), love.graphics.getHeight(),
        self:_spec(), self.scroll, self._seed)
    self.scroll, self.maxScroll = L.scroll, L.maxScroll
    for i, S in ipairs(L.sheets) do S.src = self.acts[i] end
    return L
end

-- Abre/fecha a folha do ato i. Ao abrir, rola pra ela aparecer do topo.
function RunJournalScreen:toggleAct(i)
    local b = self.acts[i]
    if not b then return false end
    b.open = not b.open
    local L = self:_layout()
    if b.open then
        local S = L.sheets[i]
        self.scroll = math.max(0, math.min(self.maxScroll,
            S.y + L.scroll - L.zone.y - Layout.TOP_SLACK))
        self:_layout()
    end
    Sfx.play(b.open and "menuOpen" or "menuClose")
    return true
end

function RunJournalScreen:isActOpen(i)
    return self.acts[i] and self.acts[i].open or false
end

-- ===== Input ==============================================================

function RunJournalScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * SCROLL_STEP))
    return true
end

-- Índice do ato cujo título está sob (x, y), ou nil.
function RunJournalScreen:_titleAt(x, y)
    local L = self:_layout()
    if y < L.zone.y or y > L.zone.y + L.zone.h then return nil end
    for i, S in ipairs(L.sheets) do
        local t = S.title
        if x >= S.x and x <= S.x + S.w and y >= t.y and y <= t.y + t.h then return i end
    end
    return nil
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
    elseif key == "return" or key == "kpenter" or key == "space" then
        -- o ato FOCADO (NavCursor) ou, sem foco de teclado, o sob o mouse
        local NavCursor = require("src.ui.NavCursor")
        local fk = NavCursor.focusKey and NavCursor.focusKey()
        local i = type(fk) == "string" and tonumber(fk:match("^act:(%d+)$"))
        if not i then i = self:_titleAt(love.mouse.getPosition()) end
        if i then self:toggleAct(i) end
    elseif key:match("^%d$") and key ~= "0" then
        self:toggleAct(tonumber(key))
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
        return true
    end
    local i = self:_titleAt(x, y)
    if i then self:toggleAct(i) end
    return true
end

-- ===== Conteúdo de uma parada =============================================

-- A anotação à margem: o ganho mais importante, ou a opção do evento.
-- Devolve texto, quantos ganhos ficaram de fora, e se é remoção (riscada).
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
        if best.kind == "forge" then
            return name .. " +" .. (best.lvl or 1), #gains - 1
        elseif best.kind == "remove" then
            return name, #gains - 1, true
        elseif best.kind ~= "card" and best.kind ~= "joker" then
            warnOnce("gain:" .. tostring(best.kind),
                "tipo de ganho desconhecido no roteiro: " .. tostring(best.kind))
        end
        return name, #gains - 1
    end
    if e.optionLabel then return RunJournalScreen.optionText(e), 0 end
    return nil
end

-- Linhas do detalhe completo (hover). Linha só aparece quando o valor MUDOU:
-- "Vida 56 -> 56" numa loja é ruído.
local function detailLines(e)
    local lines = {
        { t = MapManager.labelFor(e.type), big = true },
        { t = I18n.t("run_journal.node_at", { act = e.act or 1, floor = e.floor or 1 },
            "Ato " .. (e.act or 1) .. " - andar " .. (e.floor or 1)) },
    }
    if e.partial then
        table.insert(lines, { t = I18n.t("run_journal.no_details", nil, "Sem detalhes registrados") })
        return lines
    end
    if e.branches and #e.branches > 1 then
        local names = {}
        for k, t in ipairs(e.branches) do
            if k ~= e.pick then names[#names + 1] = MapManager.labelFor(t) end
        end
        table.insert(lines, { t = I18n.t("run_journal.not_taken_list",
            { list = table.concat(names, ", ") }, "Nao tomados: " .. table.concat(names, ", ")) })
    end
    if e.hpIn and e.hpOut and e.hpIn ~= e.hpOut then
        table.insert(lines, { t = I18n.t("run_journal.hp_line", { from = e.hpIn, to = e.hpOut },
            "Vida " .. e.hpIn .. " -> " .. e.hpOut) })
    end
    if e.goldIn and e.goldOut and e.goldIn ~= e.goldOut then
        table.insert(lines, { t = I18n.t("run_journal.gold_line", { from = e.goldIn, to = e.goldOut },
            "Ouro " .. e.goldIn .. " -> " .. e.goldOut) })
    end
    if e.optionLabel then
        local opt = RunJournalScreen.optionText(e)
        table.insert(lines, { t = I18n.t("run_journal.event_option", { option = opt }, "Escolha: " .. opt) })
    end
    for _, g in ipairs(e.gains or {}) do
        local name = cardNameFor(g.id)
        local txt
        if g.kind == "card" then
            txt = I18n.t("run_journal.gain_card", { name = name }, "Carta: " .. name)
        elseif g.kind == "joker" then
            txt = I18n.t("run_journal.gain_joker", { name = name }, "Coringa: " .. name)
        elseif g.kind == "forge" then
            txt = I18n.t("run_journal.gain_forge", { name = name, lvl = g.lvl or 1 },
                "Forja: " .. name .. " +" .. (g.lvl or 1))
        elseif g.kind == "remove" then
            txt = I18n.t("run_journal.gain_remove", { name = name }, "Removida: " .. name)
        else
            warnOnce("gain:" .. tostring(g.kind),
                "tipo de ganho desconhecido no roteiro: " .. tostring(g.kind))
            txt = tostring(g.kind) .. ": " .. name
        end
        table.insert(lines, { t = txt })
    end
    return lines
end

-- ===== Render =============================================================

function RunJournalScreen:_drawHeader(L)
    local sw = L.sw
    local run = self.game and self.game.runManager and self.game.runManager.currentRun

    local tf = FontManager.getFont(L.sw >= 900 and 18 or 14)
    love.graphics.setFont(tf)
    local title = I18n.t("run_journal.title", nil, "ROTEIRO DA JORNADA")
    local tw = tf:getWidth(title)
    local tx = math.floor((sw - tw) / 2)
    local ty = 12
    FontManager.drawWithOutline(title, tx, ty, Palette.PARCHMENT_LIGHT, 0.9)

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
            70, ty + tf:getHeight() + 8, { size = 9, maxW = maxW, align = "center" })
    end

    -- botão fechar (tinta + papel, sem cor de acento)
    local mx, my = love.mouse.getPosition()
    local cx, cy, cw, ch = self:_closeRect()
    require("src.ui.NavCursor").target("close", cx, cy, cw, ch)   -- foco de teclado/pad
    local hot = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
    setAlpha(hot and Palette.PARCHMENT or Palette.INK, 1)
    love.graphics.rectangle("fill", cx, cy, cw, ch)
    setAlpha(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)
    local xf = FontManager.getFont(14)
    love.graphics.setFont(xf)
    setAlpha(hot and Palette.INK or Palette.PARCHMENT_LIGHT, 1)
    love.graphics.print("X", cx + (cw - xf:getWidth("X")) / 2, cy + (ch - xf:getHeight()) / 2)
end

-- Título da folha (aberta ou fechada): marca de dobra [+]/[-], nome do ato,
-- estado à direita. Toda a banda é o alvo do clique.
function RunJournalScreen:_drawTitle(L, S, i, hovered)
    local b = S.src
    local t = S.title
    local seed = self._seed + i * 101

    local label
    if b.isEndless then
        label = I18n.t("run_journal.endless", nil, "SEM FIM")
    else
        label = I18n.t("run_journal.act_label", { n = b.act }, "ATO " .. b.act)
            .. "  ·  " .. TextCase.upper(ActSystem.getActName(b.act))
    end
    local state
    if b.isEndless then
        state = I18n.t("run_journal.stops", { n = #b.nodes }, #b.nodes .. " paradas")
    elseif b.conquered then
        state = I18n.t("run_journal.conquered", nil, "CONQUISTADO")
    else
        state = I18n.t("run_journal.act_progress",
            { x = #b.nodes, total = MapManager.FLOORS_PER_ACT },
            #b.nodes .. "/" .. MapManager.FLOORS_PER_ACT)
    end

    local ty = t.y + math.floor((t.h - 10) / 2)
    -- marca de dobra: quadradinho com + (fechado) ou - (aberto)
    local bx, by = t.x, ty
    Ink.line(bx, by, bx + 9, by, INK, 1, seed + 1, { wobble = 0.3 })
    Ink.line(bx + 9, by, bx + 9, by + 9, INK, 1, seed + 2, { wobble = 0.3 })
    Ink.line(bx + 9, by + 9, bx, by + 9, INK, 1, seed + 3, { wobble = 0.3 })
    Ink.line(bx, by + 9, bx, by, INK, 1, seed + 4, { wobble = 0.3 })
    Ink.px(bx + 3, by + 4, INK, 1, 4, 2)
    if not b.open then Ink.px(bx + 4, by + 3, INK, 1, 2, 4) end

    local sf = FontManager.getFont(9)
    local stateW = math.min(sf:getWidth(state), math.floor(t.w * 0.4))
    setAlpha(INK, 0.9)
    TextFit.print(state, t.x + t.w - stateW, ty + 1, { size = 9, maxW = stateW, align = "right" })

    setAlpha(INK, 1)
    local lw = TextFit.print(label, t.x + 16, ty, { size = 11, maxW = t.w - stateW - 28 })
    if hovered then
        -- sublinhado de pena no hover (foco = hover)
        Ink.line(t.x + 16, ty + 13, t.x + 16 + lw, ty + 13, INK, 0.9, seed + 5, { wobble = 0.6 })
    end
    -- filete sob o título da folha aberta
    if b.open then
        Ink.line(t.x, t.y + t.h - 2, t.x + t.w, t.y + t.h - 2, INK, 0.55, seed + 6, { wobble = 0.5 })
    end
end

function RunJournalScreen:_drawMap(L, S, i)
    local b = S.src
    local rm = self.game and self.game.runManager
    local gs = L.glyphScale
    local seed = self._seed + i * 7919
    local mx, my = love.mouse.getPosition()
    local NavCursor = require("src.ui.NavCursor")

    -- numerais dos andares (ato normal: 1..8 sempre; endless: o andar de cada
    -- parada na linha dela)
    local nf = FontManager.getFont(8)
    love.graphics.setFont(nf)
    setAlpha(INK, 0.8)
    if b.isEndless then
        for j, e in ipairs(b.nodes) do
            local y = S.rowY[e._row]
            if y then love.graphics.print(tostring(e.floor or j), S.floorCol.x + 2, y - 4) end
        end
    else
        for r = 1, S.rows do
            love.graphics.print(tostring(r), S.floorCol.x + 2, S.rowY[r] - 4)
        end
    end

    -- castelo do ato: alcançado = traço cheio; ainda não = esmaecido
    if S.castle then
        Ink.castle(S.castle.x, S.castle.y, gs, INK, S.castle.reached and 1 or 0.4, seed + 3, not S.castle.reached)
    end

    -- trilha de entrada e o caminho percorrido (traço cheio, contínuo)
    local first = S.nodes[1]
    if first then
        Ink.line(S.start.x, S.start.y, first.x, first.y, INK, 0.9, seed + 11, { wobble = 0.8 })
    end
    for k, seg in ipairs(S.segments) do
        Ink.line(seg.x1, seg.y1, seg.x2, seg.y2, INK, 1, seed + 100 + k, { wobble = 1.2 })
    end

    -- ramos NÃO tomados: pontilhado esmaecido até o símbolo, e hachura curta
    -- acima dele ("não explorado")
    for k, st in ipairs(S.stubs) do
        local e = b.nodes[st.node]
        local t = e and e.branches and e.branches[st.slot] or "unknown"
        Ink.line(st.fromX, st.fromY, st.x, st.y, INK, 0.5, seed + 300 + k, { wobble = 0.8, dash = 3, gap = 3 })
        Ink.glyph(glyphFor(t), st.x, st.y, gs, INK, 0.45, seed + 400 + k, true)
        Ink.hatch(st.x, st.y - math.floor(L.glyph / 2) - 3, INK, 0.4, seed + 500 + k, 4)
        local gr = Layout.glyphRect(L, st)
        NavCursor.target("stub:" .. i .. ":" .. k, gr.x, gr.y, gr.w, gr.h)
        if mx >= gr.x and mx < gr.x + gr.w and my >= gr.y and my < gr.y + gr.h then
            self._hover = { sheet = i, stub = k }
        end
    end

    -- a encruzilhada em aberto (à frente): pontilhado ainda mais fraco
    for k, pd in ipairs(S.pending or {}) do
        local t = b.pending and b.pending.types[k] or "unknown"
        Ink.line(pd.fromX, pd.fromY, pd.x, pd.y, INK, 0.35, seed + 600 + k, { wobble = 0.6, dash = 2, gap = 4 })
        Ink.glyph(glyphFor(t), pd.x, pd.y, gs, INK, 0.35, seed + 700 + k, true)
    end

    -- paradas tomadas: glifo cheio (o chefe do ato é o próprio castelo)
    local lineH = L.noteSize + 3
    for j, p in ipairs(S.nodes) do
        local e = b.nodes[j]
        local isCastle = S.castle and S.castle.reached and j == #S.nodes and e.type == "boss"
        if not isCastle then
            Ink.glyph(glyphFor(e.type), p.x, p.y, gs, INK, e.partial and 0.6 or 1, seed + 800 + j, false)
        end
        local gr = Layout.glyphRect(L, p)
        NavCursor.target("node:" .. i .. ":" .. j, gr.x, gr.y, gr.w, gr.h)
        if mx >= gr.x and mx < gr.x + gr.w and my >= gr.y and my < gr.y + gr.h then
            self._hover = { sheet = i, node = j }
        end

        -- o ÚNICO círculo vermelho: onde o jogador está
        local isCurrent = rm and rm.isJournalEntryOpen and rm:isJournalEntryOpen(e) or false
        if isCurrent then
            local r = math.floor(L.glyph / 2) + 4 + gs
            if isCastle then r = math.floor(S.castle.w / 2) + 3 end
            Ink.ring(p.x, p.y, r, RED, 1, seed + 900, 1)
        end

        -- anotação à margem: resultado + vida/ouro, em letra miúda
        local nx = S.noteCol.x
        local maxW = S.noteCol.w - 4
        local y1 = p.y - lineH + 1
        local y2 = y1 + lineH
        local txt, extra, struck = primaryOutcome(e)
        if txt then
            setAlpha(INK, e.partial and 0.6 or 0.95)
            local w = TextFit.print(txt, nx, y1, { size = L.noteSize, maxW = maxW, minSize = 8 })
            if struck then
                Ink.line(nx, y1 + math.floor(L.noteSize / 2), nx + w, y1 + math.floor(L.noteSize / 2),
                    INK, 0.9, seed + 950 + j, { wobble = 0.4 })
            end
            -- ganhos além do principal: risquinhos de contagem
            for k = 1, math.min(3, extra or 0) do
                Ink.px(nx + w + 3 + (k - 1) * 3, y1 + 1, INK, 0.8, 1, L.noteSize - 2)
            end
        end
        local parts = {}
        if isCurrent then
            parts[1] = I18n.t("run_journal.now", nil, "AGORA")
        elseif not e.partial then
            if e.hpIn and e.hpOut and e.hpIn ~= e.hpOut then
                parts[#parts + 1] = I18n.t("run_journal.delta_hp", { n = signed(e.hpOut - e.hpIn) },
                    "vida " .. signed(e.hpOut - e.hpIn))
            end
            if e.goldIn and e.goldOut and e.goldIn ~= e.goldOut then
                parts[#parts + 1] = I18n.t("run_journal.delta_gold", { n = signed(e.goldOut - e.goldIn) },
                    "ouro " .. signed(e.goldOut - e.goldIn))
            end
        end
        if #parts > 0 then
            setAlpha(INK, 0.8)
            TextFit.print(table.concat(parts, "  "), nx, y2, { size = L.noteSize, maxW = maxW, minSize = 8 })
        end
    end

    -- legenda: glifo + nome, pros tipos que aparecem nesta folha
    if S.legend and b.legend then
        local lf = FontManager.getFont(8)
        love.graphics.setFont(lf)
        for k, t in ipairs(b.legend) do
            local col = (k - 1) % S.legend.cols
            local row = math.floor((k - 1) / S.legend.cols)
            local x = S.legend.x + col * S.legend.itemW
            local y = S.legend.y + row * Layout.LEGEND_H
            Ink.glyph(t, x + 5, y + 7, 1, INK, 0.9, seed + k, false)
            setAlpha(INK, 0.85)
            TextFit.print(MapManager.labelFor(t), x + 14, y + 3,
                { size = 8, maxW = S.legend.itemW - 18, minSize = 8 })
        end
    end
end

-- Monta as linhas do detalhe cortadas à altura disponível e devolve o
-- retângulo já resolvido pelo layout. Exposto pros testes (validate do hover).
function RunJournalScreen:_tipFor(L, si, hover)
    local S = L.sheets[si]
    if not S or not S.open then return nil end
    local lines, p
    if hover.node then
        p = S.nodes[hover.node]
        local e = S.src and S.src.nodes[hover.node]
        if not p or not e then return nil end
        lines = detailLines(e)
    elseif hover.stub then
        p = S.stubs[hover.stub]
        local e = p and S.src and S.src.nodes[p.node]
        if not p or not e then return nil end
        local t = e.branches and e.branches[p.slot] or "unknown"
        lines = { { t = MapManager.labelFor(t), big = true },
                  { t = I18n.t("run_journal.not_taken", nil, "Caminho nao tomado") } }
    else
        return nil
    end

    local fBig, fSm = FontManager.getFont(11), FontManager.getFont(9)
    local padX, padY, gap = 8, 7, 4
    local maxH = Layout.maxTipH(L, S)
    local function heightOf(n)
        local h = padY * 2
        for k = 1, n do
            h = h + (lines[k].big and fBig or fSm):getHeight() + (k > 1 and gap or 0)
        end
        return h
    end
    if heightOf(1) > maxH then return nil end
    if heightOf(#lines) > maxH then
        local n = #lines
        while n > 1 and heightOf(n) > maxH do n = n - 1 end
        local hidden = #lines - n + 1
        for k = #lines, n, -1 do lines[k] = nil end
        if n > 1 then
            lines[n] = { t = I18n.t("run_journal.more", { n = hidden }, "+" .. hidden) }
        end
    end

    local maxW = math.min(360, Layout.tipRoom(L, S, p))
    local w = 0
    for _, l in ipairs(lines) do
        w = math.max(w, (l.big and fBig or fSm):getWidth(l.t))
    end
    w = math.min(maxW, w + padX * 2)
    local h = heightOf(#lines)
    local rect = Layout.tipRect(L, S, p, w, h)
    return { rect = rect, sheet = si, node = p, lines = lines,
             padX = padX, padY = padY, gap = gap }
end

-- O detalhe é um pedacinho de papel com moldura de pena, texto em tinta.
function RunJournalScreen:_drawTip(tip)
    local r = tip.rect
    local seed = self._seed + 31337
    love.graphics.setColor(Ink.PAPER_LIGHT[1], Ink.PAPER_LIGHT[2], Ink.PAPER_LIGHT[3], 1)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    Ink.begin()
    Ink.line(r.x, r.y, r.x + r.w - 1, r.y, INK, 1, seed + 1, { wobble = 0.5 })
    Ink.line(r.x + r.w - 1, r.y, r.x + r.w - 1, r.y + r.h - 1, INK, 1, seed + 2, { wobble = 0.5 })
    Ink.line(r.x + r.w - 1, r.y + r.h - 1, r.x, r.y + r.h - 1, INK, 1, seed + 3, { wobble = 0.5 })
    Ink.line(r.x, r.y + r.h - 1, r.x, r.y, INK, 1, seed + 4, { wobble = 0.5 })
    Ink.flush()
    local ty = r.y + tip.padY
    for _, l in ipairs(tip.lines) do
        local size = l.big and 11 or 9
        setAlpha(INK, 1)
        TextFit.print(l.t, r.x + tip.padX, ty,
            { size = size, maxW = r.w - tip.padX * 2, minSize = l.big and 9 or 8 })
        ty = ty + FontManager.getFont(size):getHeight() + tip.gap
    end
end

function RunJournalScreen:draw()
    if not self.visible then return end
    local L = self:_layout()
    local sw, sh = L.sw, L.sh
    local mx, my = love.mouse.getPosition()
    local NavCursor = require("src.ui.NavCursor")

    -- superfície lisa (mesa) em tinta; as folhas ficam por cima
    love.graphics.setColor(Ink.BACKDROP[1], Ink.BACKDROP[2], Ink.BACKDROP[3], 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    self:_drawHeader(L)

    if #L.sheets == 0 then
        setAlpha(Palette.PARCHMENT, 0.85)
        TextFit.print(I18n.t("run_journal.empty", nil, "Nenhum caminho percorrido ainda."),
            20, math.floor(L.zone.y + L.zone.h / 3), { size = 12, maxW = sw - 40, align = "center" })
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- ===== ZONA FOLHAS =====
    local z = L.zone
    local mouseInZone = my >= z.y and my <= z.y + z.h
    self._hover = nil
    love.graphics.setScissor(0, z.y, sw, z.h)

    for i, S in ipairs(L.sheets) do
        if S.y + S.h >= z.y and S.y <= z.y + z.h then
            Ink.drawSheet(Ink.paper(S.w, S.h, self._seed + i * 13), S.x, S.y)
            local t = S.title
            NavCursor.target("act:" .. i, S.x, t.y, S.w, t.h, { key = "act:" .. i })
            local titleHot = mouseInZone and mx >= S.x and mx <= S.x + S.w
                and my >= t.y and my <= t.y + t.h
            if titleHot then self._hover = { sheet = i, title = true } end
            Ink.begin()
            self:_drawTitle(L, S, i, titleHot)
            if S.open then self:_drawMap(L, S, i) end
            Ink.flush()
        end
    end
    love.graphics.setScissor()

    -- barra de rolagem (só existe quando há o que rolar), em papel
    if L.maxScroll > 0 then
        local barX = sw - 9
        local frac = L.scroll / L.maxScroll
        local knobH = math.max(30, z.h * (z.h / (z.h + L.maxScroll)))
        setAlpha(Palette.PARCHMENT_DARK, 0.6)
        love.graphics.rectangle("fill", barX, z.y, 4, z.h)
        setAlpha(Palette.PARCHMENT, 0.95)
        love.graphics.rectangle("fill", barX, z.y + frac * (z.h - knobH), 4, knobH)
    end

    if self._hover and (self._hover.node or self._hover.stub) and mouseInZone then
        local tip = self:_tipFor(L, self._hover.sheet, self._hover)
        if tip then self:_drawTip(tip) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return RunJournalScreen
