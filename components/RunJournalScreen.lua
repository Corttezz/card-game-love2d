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
--   1. UMA TRILHA POR ATO, atos empilhados de cima pra baixo (lê como linha
--      do tempo). O castelo do bioma FECHA cada trilha, à direita.
--   2. SEM RAMIFICAÇÃO. Uma linha só, o caminho real. É o que a distingue do
--      mapa do StS e é deliberado — nada de "o que eu poderia ter escolhido".
--   3. ATO NÃO JOGADO NÃO APARECE. Faixa vazia lê como buraco na interface
--      (ver memory/ui_layout_invariants.md §1, corolário "zona vazia").
--
-- Abrir: clique no indicador de ATO da TopBar OU tecla M. ESC/M/X fecha.
-- Mesmo molde do DeckViewerScreen (clique no deck) e do JokerManagerScreen.
--
-- O que veio do StS como INTENÇÃO (zero código copiado): nó percorrido em cor
-- sólida com anel em volta, trilha como cadeia de pontinhos que acende atrás
-- de você, e o marco final grande e fora da fileira dos nós comuns.

local RunJournalScreen = {}
RunJournalScreen.__index = RunJournalScreen

local FontManager     = require("src.ui.FontManager")
local Palette         = require("src.ui.Palette")
local HintBar         = require("src.ui.HintBar")
local SceneBackground = require("src.ui.SceneBackground")
local IconLoader      = require("src.ui.IconLoader")
local CardDatabase    = require("src.systems.CardDatabase")
local MapManager      = require("src.systems.MapManager")
local ActSystem       = require("src.systems.ActSystem")
local Sfx             = require("src.systems.Sfx")
local I18n            = require("src.i18n.I18n")
local Debug           = require("src.core.Debug")
local biomes          = require("src.data.biomes")

-- ===== ZONAS (memory/ui_layout_invariants.md §1) ==========================
--   CABECALHO  título + progresso da run + botão fechar      (altura fixa)
--   TRILHAS    as faixas de ato, empilhadas e roláveis        (flex)
--   RODAPE     HintBar                                        (altura fixa)
-- Dentro de uma faixa de ato, duas sub-bandas que também não se cruzam:
--   TITULO     "ATO I · CATACUMBAS" + estado do ato
--   TRILHA     os nós (à esquerda, serpenteando) + o castelo (à direita)
-- As alturas são ALOCADAS a partir da janela; quem cede quando aperta é a
-- escala do conteúdo (nodeSize/castleW), nunca a posição das bandas.
local HEADER_H     = 84
local FOOTER_H     = 48
local MARGIN       = 24
local BAND_TITLE_H = 28
local BAND_GAP     = 18
local BAND_PAD_B   = 12
local NODE_MIN     = 26
local NODE_MAX     = 76
local NODE_GAP_MIN = 18
local NODE_LABEL_H = 18
local ROW_GAP      = 10
local CASTLE_GAP   = 18
-- Teto de nós por linha que a escala tenta respeitar: um ato normal tem 8
-- paradas e deve caber numa linha só. Em endless (faixa única que cresce sem
-- fim) a trilha serpenteia, e o teto evita que a escala despenque.
local FIT_NODES_CAP = 10
-- Quanto a faixa pode esticar além do necessário quando sobra tela. A folga
-- vai pro CASTELO (ele é o marco, é ele que merece o espaço), não pra um
-- vão morto entre as trilhas.
local BAND_STRETCH  = 2.3

-- Ícone + cor por tipo de nó. Os nomes batem com MapManager.NODE_META.icon e
-- todos existem em assets/sprites/icons/ (IconLoader cai em matriz 16x16 se
-- um sumir, e avisa).
local NODE_STYLE = {
    battle    = { icon = "sword_short",   color = Palette.PARCHMENT_LIGHT },
    elite     = { icon = "skull",         color = Palette.RUST },
    mini_boss = { icon = "skull_crowned", color = Palette.BLOOD },
    boss      = { icon = "skull_crowned", color = Palette.BLOOD },
    shop      = { icon = "coin",          color = Palette.AGED_GOLD_LIGHT },
    rest      = { icon = "heart",         color = Palette.MOSS },
    event     = { icon = "scroll",        color = Palette.ARCANE_LIGHT },
}

-- Avisos de dado faltando saem UMA vez por chave (invariante §3: nada de
-- fallback silencioso — mas também nada de spam a 60fps).
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

-- Castelo do ato. `conquered` usa o último frame da porta abrindo como pose
-- "portão aberto"; sem esse frame cai no castelo normal (a etiqueta
-- CONQUISTADO já carrega a informação, então isto é enfeite, não dado).
local function castleImageFor(act, conquered)
    local bid = biomeIdForAct(act)
    if not bid then
        warnOnce("biomes", "src/data/biomes.lua vazio — sem castelo pra desenhar")
        return nil, nil
    end
    if conquered then
        local dir = "assets/sprites/world/anim/" .. bid .. "_castle_door/"
        for i = 8, 0, -1 do
            local img = loadImage(dir .. i .. ".png")
            if img then return img, bid end
        end
    end
    local img = loadImage("assets/sprites/world/" .. bid .. "_castle.png")
    if not img then
        warnOnce("castle:" .. bid,
            "sem assets/sprites/world/" .. bid .. "_castle.png — desenhando marco procedural")
    end
    return img, bid
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
    instance._hover = nil      -- { entry = , cx = , cy = , r = }
    return instance
end

-- Agrupa os nós visitados em faixas por ato, na ordem em que foram visitados.
-- Em endless o actNumber trava em totalActs+1, então uma faixa só — é o que
-- se quer (a "faixa do endless" cresce serpenteando).
function RunJournalScreen:_build()
    self.bands = {}
    local rm = self.game and self.game.runManager
    if not rm or not rm.currentRun then
        Debug.log("[roteiro] sem run ativa — nada a mostrar")
        return
    end

    local run = rm.currentRun
    local entries = rm:getJournal()
    local band = nil
    for _, e in ipairs(entries) do
        if not band or band.act ~= (e.act or 1) then
            band = { act = e.act or 1, nodes = {} }
            table.insert(self.bands, band)
        end
        table.insert(band.nodes, e)
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
    self.scroll = 0
    self._hover = nil
    self._openedAt = love.timer.getTime()
    self:_build()
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
-- coordenada sobrevive a um resize. O que resize() tem a fazer é o scroll:
-- ele é o único estado de posição guardado entre frames, e a janela nova pode
-- ter um maxScroll menor. O draw reclampa também, então trocar de resolução
-- COM A TELA ABERTA (roteiro do §2 dos invariantes: abrir pequeno, apertar f)
-- nunca deixa conteúdo preso fora da vista.
function RunJournalScreen:resize()
    self._hover = nil
    local L = self:_layout()
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll))
    return L
end

function RunJournalScreen:update(dt) end

-- ===== Layout =============================================================

function RunJournalScreen:_closeRect()
    local sw = love.graphics.getWidth()
    return sw - 52, 24, 30, 30
end

-- Resolve as zonas e a posição de cada nó/castelo para a janela ATUAL.
-- Duas passadas: mede as alturas, clampa o scroll, depois posiciona — assim o
-- scroll nunca aponta pra fora do conteúdo que acabou de ser medido.
function RunJournalScreen:_layout()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local zoneY = HEADER_H
    local zoneH = math.max(40, sh - HEADER_H - FOOTER_H)
    local nBands = math.max(1, #self.bands)

    -- Largura do castelo sai da JANELA, não do nó: assim a largura da trilha
    -- não depende da escala do nó e o cálculo abaixo não fica circular.
    local castleW = math.max(84, math.min(280, math.floor(sw * 0.16)))
    local trailX  = MARGIN
    local trailW  = math.max(120, sw - MARGIN * 2 - castleW - CASTLE_GAP)

    -- Escala do nó: o maior valor que respeita AS DUAS restrições (mesma
    -- lógica do PackChoiceLayout.cardScale — a altura é a que se esquece).
    local maxNodes = 1
    for _, b in ipairs(self.bands) do maxNodes = math.max(maxNodes, #b.nodes) end
    local fitNodes = math.min(maxNodes, FIT_NODES_CAP)
    local byWidth  = math.floor(trailW / fitNodes) - NODE_GAP_MIN

    local bandBudget = (zoneH - BAND_GAP * (nBands - 1)) / nBands
    local byHeight   = math.floor(bandBudget - BAND_TITLE_H - 6 - BAND_PAD_B - NODE_LABEL_H)

    local nodeSize = math.max(NODE_MIN, math.min(NODE_MAX, byWidth, byHeight))
    local perRow   = math.max(1, math.floor(trailW / (nodeSize + NODE_GAP_MIN)))
    local rowH     = nodeSize + NODE_LABEL_H

    local L = {
        sw = sw, sh = sh,
        nodeSize = nodeSize, castleW = castleW,
        trailX = trailX, trailW = trailW,
        perRow = perRow, rowH = rowH,
        zoneY = zoneY, zoneH = zoneH,
        bands = {},
    }

    -- 1ª passada: alturas. Quando sobra tela, a faixa ESTICA (até BAND_STRETCH)
    -- e a folga vai pro castelo — o marco cresce, os nós não.
    local contentH = 0
    for _, b in ipairs(self.bands) do
        local rows = math.max(1, math.ceil(#b.nodes / perRow))
        local natural = rows * rowH + (rows - 1) * ROW_GAP
        local room = bandBudget - BAND_TITLE_H - 6 - BAND_PAD_B
        local trailH = math.max(natural, math.min(natural * BAND_STRETCH, room))
        local h = BAND_TITLE_H + 6 + trailH + BAND_PAD_B
        contentH = contentH + h + BAND_GAP
        table.insert(L.bands, {
            src = b, rows = rows, natural = natural, trailH = trailH, h = h,
        })
    end
    contentH = math.max(0, contentH - BAND_GAP)
    L.contentH = contentH
    self.maxScroll = math.max(0, contentH - zoneH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end
    if self.scroll < 0 then self.scroll = 0 end

    -- 2ª passada: posições (scroll já embutido — hit-test fica trivial).
    -- Sem scroll o bloco fica centrado na zona; com scroll ele ancora no topo.
    local slack = (self.maxScroll > 0) and 0
        or math.max(0, math.floor((zoneH - contentH) / 2))
    local y = zoneY + slack - self.scroll
    local spacing = trailW / perRow
    for _, lb in ipairs(L.bands) do
        lb.y = y
        lb.titleY = y
        lb.trailY = y + BAND_TITLE_H + 6
        -- Trilha centrada verticalmente na faixa esticada.
        local rowTop = lb.trailY + math.floor((lb.trailH - lb.natural) / 2)
        lb.nodes = {}
        for i, e in ipairs(lb.src.nodes) do
            local r = math.floor((i - 1) / perRow)
            local c = (i - 1) % perRow
            -- Serpentina: linha ímpar corre da direita pra esquerda, então a
            -- ligação entre linhas é uma descida curta em vez de um salto.
            if r % 2 == 1 then c = perRow - 1 - c end
            table.insert(lb.nodes, {
                entry = e,
                cx = math.floor(trailX + (c + 0.5) * spacing),
                cy = math.floor(rowTop + r * (rowH + ROW_GAP) + nodeSize / 2),
                row = r,
            })
        end
        lb.castle = {
            x = trailX + trailW + CASTLE_GAP,
            y = lb.trailY,
            w = castleW,
            h = lb.trailH,
        }
        y = y + lb.h + BAND_GAP
    end

    return L
end

-- ===== Input ==============================================================

function RunJournalScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * 48))
    return true
end

function RunJournalScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "m" then
        self:hide()
    elseif key == "up" or key == "pageup" then
        self.scroll = math.max(0, self.scroll - 120)
    elseif key == "down" or key == "pagedown" then
        self.scroll = math.min(self.maxScroll, self.scroll + 120)
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

-- ===== Render =============================================================

local function setAlpha(color, a)
    love.graphics.setColor(color[1], color[2], color[3], a)
end

-- Trilha entre dois nós: cadeia de pontinhos (intenção do StS — a trilha
-- percorrida ACENDE; aqui tudo que existe já foi percorrido, então o que o
-- estado muda é a intensidade).
local function drawTrailDots(x1, y1, x2, y2, color, alpha)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end
    local step = 9
    local n = math.max(1, math.floor(dist / step))
    for i = 1, n - 1 do
        local t = i / n
        setAlpha(color, alpha)
        love.graphics.circle("fill", x1 + dx * t, y1 + dy * t, 2)
    end
end

function RunJournalScreen:_drawNode(n, nodeSize, isHover, isCurrent)
    local e = n.entry
    local st = styleFor(e.type)
    local radius = nodeSize / 2

    -- disco
    setAlpha(Palette.INK, 0.92)
    love.graphics.circle("fill", n.cx, n.cy, radius)

    -- aro: cor do tipo. Nó ATUAL pulsa (o único "em aberto" da tela).
    local ringA = 1.0
    if isCurrent then
        ringA = 0.72 + (math.cos(love.timer.getTime() * 5) + 1) / 7
    end
    love.graphics.setLineWidth(isHover and 3 or 2)
    setAlpha(st.color, ringA)
    love.graphics.circle("line", n.cx, n.cy, radius)

    -- halo do visitado (StS: nó percorrido ganha anel em volta)
    setAlpha(Palette.AGED_GOLD, isHover and 0.85 or 0.42)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", n.cx, n.cy, radius + (isHover and 5 or 3))

    -- ícone
    local icon = IconLoader.get(st.icon)
    if icon and icon.size then
        local target = nodeSize * 0.62
        local sc = target / icon.size.h
        love.graphics.setColor(1, 1, 1, e.partial and 0.55 or 1)
        icon.draw(n.cx - icon.size.w * sc / 2, n.cy - icon.size.h * sc / 2, sc)
    end

    -- pip dourado: este nó teve escolhas registradas
    if e.gains and #e.gains > 0 then
        setAlpha(Palette.AGED_GOLD_LIGHT, 1)
        love.graphics.circle("fill", n.cx + radius * 0.72, n.cy - radius * 0.72, 3)
        setAlpha(Palette.INK, 1)
        love.graphics.circle("line", n.cx + radius * 0.72, n.cy - radius * 0.72, 3)
    end

    -- andar sob o nó
    local f = FontManager.getFont(9)
    love.graphics.setFont(f)
    local txt = tostring(e.floor or "?")
    setAlpha(isCurrent and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT, 0.9)
    love.graphics.print(txt, n.cx - f:getWidth(txt) / 2, n.cy + radius + 3)
end

function RunJournalScreen:_drawCastle(lb)
    local b = lb.src
    local r = lb.castle
    local conquered = b.conquered
    local img = castleImageFor(b.act, conquered)

    local drawH = r.h - 18
    if img then
        local sc = math.min(r.w / img:getWidth(), drawH / img:getHeight())
        local dw, dh = img:getWidth() * sc, img:getHeight() * sc
        local dx = r.x + (r.w - dw) / 2
        -- Ancorado no CHÃO da faixa: a etiqueta abaixo fica colada no castelo
        -- em vez de flutuar longe quando o PNG é mais baixo que a faixa.
        local dy = r.y + drawH - dh
        if conquered then
            love.graphics.setColor(1, 1, 1, 1)
        else
            -- Ainda não conquistado: silhueta ao longe (escura, mas legível —
            -- o jogador precisa VER que o marco existe).
            love.graphics.setColor(0.46, 0.42, 0.44, 0.95)
        end
        love.graphics.draw(img, math.floor(dx), math.floor(dy), 0, sc, sc)
    else
        -- Marco procedural (o aviso já saiu uma vez em castleImageFor).
        local w = math.min(r.w, drawH * 0.8)
        local x = r.x + (r.w - w) / 2
        local y = r.y + drawH * 0.25
        setAlpha(conquered and Palette.PARCHMENT_DARK or Palette.INK, 0.95)
        love.graphics.rectangle("fill", x, y, w, drawH * 0.75)
        setAlpha(conquered and Palette.AGED_GOLD or Palette.STEEL, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, drawH * 0.75)
    end

    -- Etiqueta de estado sob o castelo
    local f = FontManager.getFont(9)
    love.graphics.setFont(f)
    local total = MapManager.FLOORS_PER_ACT
    local txt
    if conquered then
        txt = I18n.t("run_journal.conquered", nil, "CONQUISTADO")
        setAlpha(Palette.AGED_GOLD_LIGHT, 1)
    else
        local reached = #b.nodes
        txt = I18n.t("run_journal.act_progress", { x = reached, total = total },
            reached .. "/" .. total)
        setAlpha(Palette.PARCHMENT, 0.85)
    end
    love.graphics.print(txt, r.x + (r.w - f:getWidth(txt)) / 2, r.y + r.h - 14)
end

-- Tooltip ANCORADO no nó (invariante §1: informação de hover mora colada no
-- objeto que descreve, nunca numa tarja fixa atravessando a tela).
function RunJournalScreen:_drawTooltip(n, nodeSize)
    local e = n.entry
    local lines = {}
    local typeLabel = MapManager.labelFor(e.type)
    table.insert(lines, { t = typeLabel, c = styleFor(e.type).color, big = true })
    table.insert(lines, {
        t = I18n.t("run_journal.node_at", { act = e.act or 1, floor = e.floor or 1 },
            "Ato " .. (e.act or 1) .. " - andar " .. (e.floor or 1)),
        c = Palette.PARCHMENT,
    })

    if e.partial then
        table.insert(lines, {
            t = I18n.t("run_journal.no_details", nil, "Sem detalhes registrados"),
            c = Palette.STEEL_LIGHT,
        })
    else
        -- Linha só aparece quando o valor MUDOU: "Vida 56 -> 56" numa loja é
        -- ruído, e ruído some a informação que importa (o que foi escolhido).
        if e.hpIn and e.hpOut and e.hpIn ~= e.hpOut then
            local delta = e.hpOut - e.hpIn
            table.insert(lines, {
                t = I18n.t("run_journal.hp_line", { from = e.hpIn, to = e.hpOut },
                    "Vida " .. e.hpIn .. " -> " .. e.hpOut),
                c = (delta < 0) and Palette.BLOOD or Palette.MOSS,
            })
        end
        if e.goldIn and e.goldOut and e.goldIn ~= e.goldOut then
            table.insert(lines, {
                t = I18n.t("run_journal.gold_line", { from = e.goldIn, to = e.goldOut },
                    "Ouro " .. e.goldIn .. " -> " .. e.goldOut),
                c = Palette.AGED_GOLD_LIGHT,
            })
        end
        if e.optionLabel then
            table.insert(lines, {
                t = I18n.t("run_journal.event_option", { option = e.optionLabel },
                    "Escolha: " .. e.optionLabel),
                c = Palette.ARCANE_LIGHT,
            })
        end
        for _, g in ipairs(e.gains or {}) do
            local cd = g.id and CardDatabase:getCard(g.id)
            if not cd and g.id then
                warnOnce("card:" .. tostring(g.id),
                    "carta do roteiro fora do catálogo: " .. tostring(g.id))
            end
            local name = cd and I18n.cardName(cd) or tostring(g.id)
            local txt, col
            if g.kind == "card" then
                txt = I18n.t("run_journal.gain_card", { name = name }, "Carta: " .. name)
                col = Palette.PARCHMENT_LIGHT
            elseif g.kind == "joker" then
                txt = I18n.t("run_journal.gain_joker", { name = name }, "Coringa: " .. name)
                col = Palette.AGED_GOLD_LIGHT
            elseif g.kind == "forge" then
                txt = I18n.t("run_journal.gain_forge", { name = name, lvl = g.lvl or 1 },
                    "Forja: " .. name .. " +" .. (g.lvl or 1))
                col = Palette.RUST
            elseif g.kind == "remove" then
                txt = I18n.t("run_journal.gain_remove", { name = name }, "Removida: " .. name)
                col = Palette.BLOOD
            else
                warnOnce("gain:" .. tostring(g.kind),
                    "tipo de ganho desconhecido no roteiro: " .. tostring(g.kind))
                txt = tostring(g.kind) .. ": " .. name
                col = Palette.STEEL_LIGHT
            end
            table.insert(lines, { t = txt, c = col })
        end
    end

    local fBig = FontManager.getFont(12)
    local fSm  = FontManager.getFont(9)
    local padX, padY, lineGap = 10, 8, 4
    local w, h = 0, 0
    for _, l in ipairs(lines) do
        local f = l.big and fBig or fSm
        w = math.max(w, f:getWidth(l.t))
        h = h + f:getHeight() + lineGap
    end
    w = w + padX * 2
    h = h - lineGap + padY * 2

    -- Ancora acima do nó; vira pra baixo se não couber, e clampa nas bordas.
    local x = n.cx - w / 2
    local y = n.cy - nodeSize / 2 - h - 8
    if y < 4 then y = n.cy + nodeSize / 2 + 18 end
    x = math.max(6, math.min(love.graphics.getWidth() - w - 6, x))
    y = math.max(6, math.min(love.graphics.getHeight() - h - 6, y))

    setAlpha(Palette.INK, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    setAlpha(Palette.AGED_GOLD, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)

    local ty = y + padY
    for _, l in ipairs(lines) do
        local f = l.big and fBig or fSm
        love.graphics.setFont(f)
        setAlpha(l.c, 1)
        love.graphics.print(l.t, x + padX, ty)
        ty = ty + f:getHeight() + lineGap
    end
end

function RunJournalScreen:draw()
    if not self.visible then return end
    local L = self:_layout()
    local sw, sh = L.sw, L.sh
    local mx, my = love.mouse.getPosition()

    -- Fundo (mesma vibe das outras telas cheias)
    if not SceneBackground.draw("collection", sw, sh, 0.30) then
        love.graphics.setColor(0.05, 0.04, 0.03, 0.96)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    else
        -- Véu mais fechado que o do DeckViewer: aqui o conteúdo é fino
        -- (discos, pontinhos, texto de 9px) e os castiçais da cena de fundo
        -- disputavam leitura com os nós.
        love.graphics.setColor(0.04, 0.03, 0.02, 0.84)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    -- ===== ZONA CABECALHO =====
    local tf = FontManager.getResponsiveFont(0.045, 30)
    love.graphics.setFont(tf)
    local title = I18n.t("run_journal.title", nil, "ROTEIRO DA JORNADA")
    setAlpha(Palette.AGED_GOLD_LIGHT, 1)
    love.graphics.print(title, math.floor((sw - tf:getWidth(title)) / 2), 20)

    local run = self.game and self.game.runManager and self.game.runManager.currentRun
    if run then
        local sf = FontManager.getFont(11)
        love.graphics.setFont(sf)
        local sub = I18n.t("run_journal.subtitle", {
            act = run.actNumber or 1,
            floor = run.floorInAct or 1,
            total = MapManager.FLOORS_PER_ACT,
            stops = #(run.mapHistory or {}),
        }, "ato " .. (run.actNumber or 1) .. " - andar " .. (run.floorInAct or 1))
        setAlpha(Palette.PARCHMENT, 0.9)
        love.graphics.print(sub, math.floor((sw - sf:getWidth(sub)) / 2), 58)
    end

    do  -- botão fechar
        local cx, cy, cw, ch = self:_closeRect()
        local hot = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
        setAlpha(hot and Palette.BLOOD or Palette.PANEL_FILL or Palette.INK, 1)
        love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
        setAlpha(Palette.AGED_GOLD, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)
        local xf = FontManager.getFont(14)
        love.graphics.setFont(xf)
        setAlpha(Palette.PARCHMENT_LIGHT, 1)
        love.graphics.print("X", cx + (cw - xf:getWidth("X")) / 2,
            cy + (ch - xf:getHeight()) / 2)
    end

    -- Roteiro vazio: diz isso em palavras, não com uma zona em branco.
    if #L.bands == 0 then
        local ef = FontManager.getFont(12)
        love.graphics.setFont(ef)
        local txt = I18n.t("run_journal.empty", nil,
            "Nenhum caminho percorrido ainda.")
        setAlpha(Palette.PARCHMENT, 0.85)
        love.graphics.print(txt, math.floor((sw - ef:getWidth(txt)) / 2),
            math.floor(L.zoneY + L.zoneH / 2))
        HintBar.draw(I18n.t("run_journal.hint", nil, "M ou ESC fecha"))
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- ===== ZONA TRILHAS =====
    local mouseInZone = my >= L.zoneY and my <= L.zoneY + L.zoneH
    self._hover = nil
    love.graphics.setScissor(0, L.zoneY, sw, L.zoneH)

    for _, lb in ipairs(L.bands) do
        -- fora da vista: nem desenha (e não pode virar hover)
        if lb.y + lb.h >= L.zoneY and lb.y <= L.zoneY + L.zoneH then
            local b = lb.src

            -- sub-banda TITULO
            local bf = FontManager.getFont(13)
            love.graphics.setFont(bf)
            local actLabel
            if b.isEndless then
                actLabel = I18n.t("run_journal.endless", nil, "ENDLESS")
            else
                actLabel = I18n.t("run_journal.act_label", { n = b.act },
                    "ATO " .. b.act) .. "  -  " .. ActSystem.getActName(b.act)
            end
            setAlpha(b.conquered and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT, 1)
            love.graphics.print(actLabel, L.trailX, lb.y + 4)

            -- régua sutil separando a faixa
            setAlpha(Palette.AGED_GOLD_DARK, 0.55)
            love.graphics.rectangle("fill", L.trailX, lb.y + BAND_TITLE_H - 2,
                L.trailW + L.castleW + CASTLE_GAP, 1)

            -- sub-banda TRILHA: pontinhos entre nós consecutivos, depois nós
            for i = 1, #lb.nodes - 1 do
                local a, c = lb.nodes[i], lb.nodes[i + 1]
                drawTrailDots(a.cx, a.cy, c.cx, c.cy, Palette.AGED_GOLD, 0.75)
            end
            -- último nó -> castelo (apagado enquanto o ato não fechou)
            local last = lb.nodes[#lb.nodes]
            if last then
                drawTrailDots(last.cx, last.cy,
                    lb.castle.x + lb.castle.w * 0.3, last.cy,
                    Palette.AGED_GOLD, b.conquered and 0.75 or 0.22)
            end

            local rm = self.game and self.game.runManager
            for _, n in ipairs(lb.nodes) do
                local half = L.nodeSize / 2 + 4
                local hovered = mouseInZone
                    and math.abs(mx - n.cx) <= half and math.abs(my - n.cy) <= half
                local isCurrent = rm and rm.isJournalEntryOpen
                    and rm:isJournalEntryOpen(n.entry) or false
                self:_drawNode(n, L.nodeSize, hovered, isCurrent)
                if hovered then self._hover = n end
            end

            self:_drawCastle(lb)
        end
    end

    love.graphics.setScissor()

    -- barra de scroll
    if self.maxScroll > 0 then
        local barX = sw - 10
        local frac = self.scroll / self.maxScroll
        local knobH = math.max(30, L.zoneH * (L.zoneH / (L.zoneH + self.maxScroll)))
        setAlpha(Palette.INK, 0.5)
        love.graphics.rectangle("fill", barX, L.zoneY, 5, L.zoneH)
        setAlpha(Palette.AGED_GOLD, 1)
        love.graphics.rectangle("fill", barX, L.zoneY + frac * (L.zoneH - knobH), 5, knobH)
    end

    -- tooltip por cima de tudo (fora do scissor)
    if self._hover then
        self:_drawTooltip(self._hover, L.nodeSize)
    end

    -- ===== ZONA RODAPE =====
    HintBar.draw(I18n.t("run_journal.hint", nil,
        "PASSE O MOUSE num marco pra ver o que foi escolhido  ·  RODA rola  ·  M ou ESC fecha"))

    love.graphics.setColor(1, 1, 1, 1)
end

return RunJournalScreen
