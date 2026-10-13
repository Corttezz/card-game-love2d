-- components/UnlockShowcase.lua
-- REVELAÇÕES NO MENU (Out/2026, pedido do dono: "igual ao Balatro: terminou
-- a run e voltou pro menu, mostra tudo o que desbloqueou").
--
-- Um painel por vez sobre o menu escurecido, na ordem da fila
-- (src/systems/UnlockQueue.lua): carta nova (com a moldura, grande), classe
-- nova (emblema), nível de maestria, Selo liberado, conquista. Cada painel tem
-- título curto, o item grande com um efeito de revelação, nome, uma linha do
-- que ele significa, o contador "2 de 5" e os botões Continuar (clique / A /
-- Enter) e Pular tudo (Esc / B).
--
-- REVELAÇÃO NA GRADE DA ARTE (v2, Out/2026 — o dono achou os raios v1,
-- triângulos vetoriais translúcidos girando, "muito tosco"): o palco é um
-- shader por célula de 2 px (shaders/reveal_stage.glsl — halo posterizado com
-- dither Bayer + espinhos de 1 célula girando em saltos), faíscas de 1-2
-- células que piscam, e o item desenhado num canvas de MEIA resolução (1 px
-- do canvas = 1 célula) — assim selo, emblema, ícone e carta nascem na mesma
-- grade, a varredura de luz da carta inédita (DiscoveryMark) passa por todos
-- com a mesma faixa chunky, e o clarão é a SILHUETA do item em aditivo, não
-- um retângulo branco. Cartas raras/lendárias mantêm o holo delas.
-- reducedMotion: halo parado, sem espinhos, faíscas, varredura nem pop.
--
-- Abre SOZINHO: watch() roda todo frame e, com o jogador no menu, nenhum
-- outro modal na frente e fila não vazia, mostra. A fila mora no perfil, então
-- o que não foi visto (jogo fechado no meio) aparece no próximo boot.
--
-- Layout em ZONAS puro (layout + validate) no espaço virtual do UiScale
-- (a classe é adotada no fim do arquivo). reducedMotion tira o movimento
-- (pop, giro, flutuação), nunca a informação.

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiPanel     = require("src.ui.UiPanel")
local MenuKit     = require("src.ui.MenuKit")
local TextFit     = require("src.ui.TextFit")
local I18n        = require("src.i18n.I18n")
local Easing      = require("engine.Easing")
local Sfx         = require("src.systems.Sfx")
local UnlockQueue = require("src.systems.UnlockQueue")

local Showcase = {}
Showcase.__index = Showcase

-- Navega sozinha (MenuKit): o NavCursor não toma as teclas; o pad chega
-- como tecla. Os botões ainda publicam alvos pro anel de foco.
Showcase.ownsNavigation = true

-- Respiro do menu antes do primeiro painel (a intro do menu assenta).
Showcase.OPEN_DELAY = 0.6
-- Cada painel ignora entrada no começo: Enter segurado/duplo não pula dois.
Showcase.INPUT_DELAY = 0.25

local PAD, GAP = 22, 12

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- ===================================================================
-- DADOS DO PAINEL (puro: textos do item)
-- ===================================================================

local function className(id)
    return I18n.t("classes." .. tostring(id) .. ".name")
end

local function sealDef(n)
    local RM = require("src.systems.RunModifiers")
    return RM.SEALS and RM.SEALS[n]
end

-- { title, name, sub } de um item da fila.
function Showcase.texts(it)
    if not it then return { title = "", name = "", sub = "" } end
    if it.kind == "card" then
        return { title = I18n.t("unlock_showcase.title_card"),
                 name = I18n.cardName(it.id), sub = I18n.t("unlock_showcase.card_sub") }
    elseif it.kind == "class" then
        return { title = I18n.t("unlock_showcase.title_class"),
                 name = className(it.id), sub = I18n.t("unlock_showcase.class_sub") }
    elseif it.kind == "mastery" then
        local sub = I18n.t("unlock_showcase.mastery_sub", { class = className(it.classId) })
        -- "novas cartas" só quando o nível traz pacote (nível vazio não mente)
        local bundles = require("src.data.unlocks").CLASS_BUNDLES[it.classId or ""]
        local b = bundles and bundles[it.level or 0]
        if b and b.cards and #b.cards > 0 then
            sub = sub .. ". " .. I18n.t("unlock_showcase.mastery_cards")
        end
        return { title = I18n.t("unlock_showcase.title_mastery"),
                 name = I18n.t("unlock_showcase.mastery_level", { level = it.level or "?" }),
                 sub = sub }
    elseif it.kind == "seal" then
        local d = sealDef(it.n)
        local rule = d and I18n.t("seals." .. d.id .. ".desc") or ""
        return { title = I18n.t("unlock_showcase.title_seal", { n = it.n or "?" }),
                 name = d and I18n.t("seals." .. d.id .. ".name") or "",
                 sub = I18n.t("unlock_showcase.seal_sub", { class = className(it.classId), rule = rule }) }
    elseif it.kind == "achievement" then
        local AS = require("src.systems.AchievementSystem")
        return { title = I18n.t("unlock_showcase.title_achievement"),
                 name = AS.nameOf(it.id), sub = AS.descOf(it.id) }
    end
    print("[UnlockShowcase] AVISO: tipo de item desconhecido: " .. tostring(it.kind))
    return { title = "", name = tostring(it.id), sub = "" }
end

-- ===================================================================
-- LAYOUT (puro)
-- ===================================================================

function Showcase.layout(sw, sh)
    local pw = math.min(660, sw - 32)
    local ph = math.min(600, sh - 32)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local inner = pw - PAD * 2
    local L = { panel = { x = px, y = py, w = pw, h = ph } }
    local x0, y = px + PAD, py + PAD
    L.title = { x = x0, y = y, w = inner, h = 28 }; y = y + 28 + 4
    L.counter = { x = x0, y = y, w = inner, h = 12 }; y = y + 12 + GAP
    local actionsH, subH, nameH = 40, 34, 26
    local stageH = (py + ph - PAD) - y - (GAP + nameH + 4 + subH + GAP + actionsH)
    L.stage = { x = x0, y = y, w = inner, h = stageH }; y = y + stageH + GAP
    L.name = { x = x0, y = y, w = inner, h = nameH }; y = y + nameH + 4
    L.sub = { x = x0, y = y, w = inner, h = subH }; y = y + subH + GAP
    local bw = math.min(240, math.floor((inner - GAP) / 2))
    local rowW = bw * 2 + GAP
    local bx = math.floor(px + (pw - rowW) / 2)
    L.buttons = {
        { key = "continue", x = bx, y = y, w = bw, h = actionsH, primary = true },
        { key = "skip", x = bx + bw + GAP, y = y, w = bw, h = actionsH },
    }
    L.actions = { x = bx, y = y, w = rowW, h = actionsH }
    return L
end

function Showcase.validate(L, sw, sh)
    local probs = {}
    local p = L.panel
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then
        probs[#probs + 1] = ("painel fora da tela (%dx%d em %dx%d)"):format(p.w, p.h, sw, sh)
    end
    if L.stage.h < 120 then probs[#probs + 1] = "palco pequeno demais (" .. L.stage.h .. ")" end
    local zones = { { L.title, "title" }, { L.counter, "counter" }, { L.stage, "stage" },
        { L.name, "name" }, { L.sub, "sub" }, { L.buttons[1], "continue" }, { L.buttons[2], "skip" } }
    for i, a in ipairs(zones) do
        local r = a[1]
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w or r.y + r.h > p.y + p.h then
            probs[#probs + 1] = a[2] .. " fora do painel"
        end
        for j = i + 1, #zones do
            if MenuKit.overlaps(r, zones[j][1]) then
                probs[#probs + 1] = a[2] .. " sobrepoe " .. zones[j][2]
            end
        end
    end
    return probs
end

-- ===================================================================
-- CICLO
-- ===================================================================

function Showcase:new()
    return setmetatable({ visible = false, t = 0, idx = 0, total = 0,
        focus = 1, menuTime = 0, item = nil }, Showcase)
end

function Showcase:isVisible() return self.visible end

local SOUND = {
    card = { "cardDiscovered" }, class = { "packSealBreak" }, mastery = { "actComplete" },
    seal = { "packSealBreak" }, achievement = { "comboTrigger", { pitch = 1.2 } },
}

function Showcase:_enterItem()
    self.item = UnlockQueue.peek()
    self.t = 0
    self.focus = 1
    self.pressed = nil
    self.cardInst = nil
    local s = self.item and SOUND[self.item.kind]
    if s then Sfx.play(s[1], s[2]) end
end

-- Abre na primeira revelação da fila. false = fila vazia.
function Showcase:show()
    if UnlockQueue.count() == 0 then return false end
    self.visible = true
    self.total = UnlockQueue.count()
    self.idx = 1
    Sfx.play("menuOpen")
    self:_enterItem()
    return true
end

function Showcase:hide()
    if not self.visible then return end
    self.visible = false
    self.item = nil
    self.cardInst = nil
    Sfx.play("menuClose")
end

function Showcase:resize() end

-- Chamado todo frame pelo main: no menu, sem outro modal, com fila → abre.
function Showcase:watch(state, dt)
    if self.visible then return end
    if state ~= "menu" then self.menuTime = 0 return end
    self.menuTime = self.menuTime + (dt or 0)
    if self.menuTime < Showcase.OPEN_DELAY or UnlockQueue.count() == 0 then return end
    if require("src.ui.InputFocus").captor() then return end
    self:show()
end

-- Continuar: o painel atual sai da fila (visto) e vem o próximo.
function Showcase:advance()
    UnlockQueue.pop()
    if UnlockQueue.count() == 0 then self:hide() return end
    self.idx = self.idx + 1
    -- coisa nova entrou na fila com o painel aberto (raro): o total acompanha
    self.total = math.max(self.total, self.idx + UnlockQueue.count() - 1)
    self:_enterItem()
end

-- Pular tudo: esvazia a fila (tudo conta como visto).
function Showcase:skipAll()
    UnlockQueue.clear()
    self:hide()
end

function Showcase:_ready() return self.visible and self.t >= Showcase.INPUT_DELAY end

function Showcase:_activate(key)
    Sfx.playWithVariation("buttonClick", 1.0, 0.08)
    if key == "skip" then self:skipAll() else self:advance() end
end

function Showcase:update(dt)
    if not self.visible then return end
    self.t = self.t + (dt or 0)
    local L = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local mx, my = love.mouse.getPosition()
    if mx ~= self._mx or my ~= self._my then
        local first = self._mx == nil
        self._mx, self._my = mx, my
        for i, b in ipairs(L.buttons) do
            if not first and MenuKit.hit(b, mx, my) and self.focus ~= i then
                self.focus = i
                Sfx.playWithVariation("menuHover", 1.0, 0.12)
            end
        end
    end
end

-- ===================================================================
-- ENTRADA
-- ===================================================================

local function buttonAt(L, x, y)
    for i, b in ipairs(L.buttons) do
        if MenuKit.hit(b, x, y) then return i end
    end
end

function Showcase:mousepressed(x, y, button)
    if not self.visible then return false end
    if button == 1 and self:_ready() then
        self.pressed = buttonAt(Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight()), x, y)
    end
    return true
end

function Showcase:mousereleased(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return true end
    local L = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local i = self:_ready() and buttonAt(L, x, y)
    local pressed = self.pressed
    self.pressed = nil
    if i and i == pressed then self:_activate(L.buttons[i].key) end
    return true
end

function Showcase:wheelmoved() return true end

function Showcase:keypressed(key)
    if not self.visible then return false end
    if not self:_ready() then return true end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    if it == "left" or it == "up" or it == "tab_prev" then
        if self.focus ~= 1 then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        self.focus = 1
    elseif it == "right" or it == "down" or it == "tab_next" then
        if self.focus ~= 2 then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        self.focus = 2
    elseif it == "confirm" then
        self:_activate(self.focus == 2 and "skip" or "continue")
    elseif it == "back" then
        self:_activate("skip")
    end
    return true
end

-- ===================================================================
-- DRAW
-- ===================================================================

local cardDb = nil
local function cardImage(self, id)
    if self.cardInst == nil then
        self.cardInst = false
        local CardDatabase = require("src.systems.CardDatabase")
        cardDb = cardDb or CardDatabase:new()
        local cd = cardDb:getCard(id)
        if cd then
            local ok, inst = pcall(function() return cardDb:createCardInstance(cd) end)
            if ok and inst then self.cardInst = inst
            else print("[UnlockShowcase] AVISO: falha ao montar a carta " .. tostring(id)) end
        else
            print("[UnlockShowcase] AVISO: carta desconhecida na fila: " .. tostring(id))
        end
    end
    return self.cardInst and self.cardInst.image
end

-- ===================================================================
-- PALCO na grade da arte
-- ===================================================================

-- Célula da grade (px virtuais): 1 px da arte das cartas em 1024x768.
Showcase.CELL = 2

local stageShader, stageShaderTried, whitePx
local function getStageShader()
    if stageShaderTried then return stageShader end
    stageShaderTried = true
    local ok, s = pcall(love.graphics.newShader, "shaders/reveal_stage.glsl")
    if ok then stageShader = s
    else print("[UnlockShowcase] AVISO: shader do palco falhou: " .. tostring(s)) end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    whitePx = love.graphics.newImage(data)
    whitePx:setFilter("nearest", "nearest")
    return stageShader
end

local function rgb(c) return { c[1], c[2], c[3] } end

-- Halo posterizado + espinhos girando, tudo por célula (o shader).
local function drawGlow(cx, cy, r, t, alpha)
    local sh = getStageShader()
    if not sh then return end
    local motion = not reducedMotion()
    local size = math.floor(r * 2)
    sh:send("size", { size, size })
    sh:send("cell", Showcase.CELL)
    sh:send("levels", 4)
    sh:send("rays", 12)
    sh:send("rot", motion and t * 0.22 or 0)
    sh:send("rayOn", motion and 1 or 0)
    sh:send("pulse", motion and (0.86 + 0.14 * math.sin(t * 2.4)) or 1)
    sh:send("glowCol", rgb(Palette.AGED_GOLD))
    sh:send("rayCol", rgb(Palette.AGED_GOLD_LIGHT))
    love.graphics.setShader(sh)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(whitePx, math.floor(cx - size / 2), math.floor(cy - size / 2), 0, size, size)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Faíscas douradas: pontos de 1 célula que piscam (cruz de 3 no pico), em
-- posições fixas por item (hash do seed) — nunca por cima do centro do palco.
local function hash(seed, i, k)
    local v = math.sin(i * 127.1 + k * 311.7 + seed * 74.7) * 43758.5453
    return v - math.floor(v)
end

local function drawSparkles(cx, cy, r, t, alpha, seed)
    if reducedMotion() then return end
    local cell = Showcase.CELL
    local function snap(v) return math.floor(v / cell) * cell end
    for i = 1, 14 do
        local ang = hash(seed, i, 1) * math.pi * 2
        local rad = r * (0.42 + 0.56 * hash(seed, i, 2))
        local phase = hash(seed, i, 3) * math.pi * 2
        local speed = 1.6 + hash(seed, i, 4) * 1.8
        local b = math.sin(t * speed + phase)
        if b > 0.45 then
            local x, y = snap(cx + math.cos(ang) * rad), snap(cy + math.sin(ang) * rad)
            Palette.set(b > 0.9 and Palette.PARCHMENT_LIGHT or Palette.AGED_GOLD_LIGHT, alpha)
            love.graphics.rectangle("fill", x, y, cell, cell)
            if b > 0.8 then
                Palette.set(Palette.AGED_GOLD_LIGHT, alpha * 0.8)
                love.graphics.rectangle("fill", x - cell, y, cell, cell)
                love.graphics.rectangle("fill", x + cell, y, cell, cell)
                love.graphics.rectangle("fill", x, y - cell, cell, cell)
                love.graphics.rectangle("fill", x, y + cell, cell, cell)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Disco em DEGRAUS (coords do canvas do palco, 1 px = 1 célula): linhas
-- horizontais de largura inteira — círculo vetorial liso destoava da grade.
local function steppedDisc(cx, cy, r)
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
    for dy = -r, r do
        local half = math.floor(math.sqrt(math.max(0, r * r - dy * dy)))
        love.graphics.rectangle("fill", cx - half, cy + dy, half * 2 + 1, 1)
    end
end

-- Selo de cera (os selos não têm arte própria): disco sangue + número.
local function drawSeal(n, cx, cy, size)
    local r = size / 2
    Palette.set(Palette.INK, 0.6)
    steppedDisc(cx + 2, cy + 3, r)
    Palette.set(Palette.BLOOD_DARK)
    steppedDisc(cx, cy, r)
    Palette.set(Palette.BLOOD)
    steppedDisc(cx, cy, r * 0.82)
    Palette.set(Palette.BLOOD_DARK)
    steppedDisc(cx, cy, r * 0.68)
    Palette.set(Palette.BLOOD)
    steppedDisc(cx, cy, r * 0.60)
    local f = FontManager.getFont(math.max(8, math.floor(size * 0.36)))
    love.graphics.setFont(f)
    local s = tostring(n or "?")
    Palette.set(Palette.INK, 0.8)
    love.graphics.print(s, math.floor(cx - f:getWidth(s) / 2) + 1, math.floor(cy - f:getHeight() / 2) + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(s, math.floor(cx - f:getWidth(s) / 2), math.floor(cy - f:getHeight() / 2))
end

-- Desenha o item no CANVAS do palco (coords do canvas: 1 px = 1 célula);
-- devolve o retângulo da arte nessas coords. Escalas inteiras quando ≥ 1.
function Showcase:_drawItem(it, st)
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    if it.kind == "card" then
        local img = cardImage(self, it.id)
        if img then
            local s = math.min(st.h / img:getHeight(), st.w / img:getWidth())
            if s >= 1 then s = math.floor(s) end
            local w, h = img:getWidth() * s, img:getHeight() * s
            local x, y = math.floor(cx - w / 2), math.floor(cy - h / 2)
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.rectangle("fill", x + 3, y + 4, w, h)
            love.graphics.setColor(1, 1, 1, 1)
            local fx = self.cardInst and self.cardInst.visualEffect
            if fx == "holo" or fx == "glow" then
                require("src.ui.HoloShader").draw(img, x, y, fx == "holo" and 0.75 or 0.35, 0, s, s)
            else
                love.graphics.draw(img, x, y, 0, s, s)
            end
            return { x = x, y = y, w = w, h = h, image = img, scale = s }
        end
    elseif it.kind == "class" or it.kind == "mastery" then
        local ClassEmblem = require("src.ui.ClassEmblem")
        local id = it.id or it.classId
        local boxH = st.h * (it.kind == "class" and 0.92 or 0.72)
        if ClassEmblem.draw(id, cx, cy, boxH, { hover = 1 }) then
            return { x = cx - boxH / 2, y = cy - boxH / 2, w = boxH, h = boxH }
        end
    elseif it.kind == "seal" then
        local size = math.min(st.h, st.w) * 0.7
        drawSeal(it.n, cx, cy, size)
        return { x = cx - size / 2, y = cy - size / 2, w = size, h = size }
    elseif it.kind == "achievement" then
        local AchievementIcons = require("src.ui.AchievementIcons")
        local img = AchievementIcons.get(it.id, false)
        local size = math.min(st.h, st.w) * 0.8
        if img and size >= img:getWidth() then size = math.floor(size / img:getWidth()) * img:getWidth() end
        AchievementIcons.draw(it.id, false, cx, cy, size, 1)
        return { x = cx - size / 2, y = cy - size / 2, w = size, h = size }
    end
    return nil
end

-- Canvas do palco em meia resolução (1 px = 1 célula), reaproveitado.
local stageCanvas, snapCanvas, stageCW, stageCH
local function getStageCanvas(w, h)
    if not stageCanvas or stageCW ~= w or stageCH ~= h then
        stageCanvas = love.graphics.newCanvas(w, h)
        stageCanvas:setFilter("nearest", "nearest")
        snapCanvas = love.graphics.newCanvas(w, h)
        snapCanvas:setFilter("nearest", "nearest")
        stageCW, stageCH = w, h
    end
    return stageCanvas, snapCanvas
end

-- Item + varredura + clarão de silhueta, com o pop. `st` = zona do palco.
function Showcase:_drawStageItem(it, st, t)
    local cell = Showcase.CELL
    local cw, ch = math.floor(st.w / cell), math.floor(st.h / cell)
    if cw < 8 or ch < 8 then return end
    local cv, snap = getStageCanvas(cw, ch)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    local art = self:_drawItem(it, { x = 0, y = 0, w = cw, h = ch })
    -- varredura de luz (a mesma da carta inédita) por cima do item, na grade
    if art then
        local DiscoveryMark = require("src.ui.DiscoveryMark")
        if art.image then
            DiscoveryMark.drawSweep(art.image, art.x, art.y, art.scale, t, 1, true)
        else
            -- itens sem imagem única (emblema, selo, ícone): varre uma cópia
            -- do canvas do palco; a faixa segue a silhueta do que foi desenhado
            love.graphics.setCanvas(snap)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.draw(cv, 0, 0)
            love.graphics.setCanvas(cv)
            DiscoveryMark.drawSweep(snap, 0, 0, 1, t, 1, true)
        end
    end
    love.graphics.pop()

    local motion = not reducedMotion()
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    local k = math.min(1, t / 0.45)
    local e = motion and Easing.backOut(k) or 1
    local bob = (motion and it.kind == "card") and math.floor(math.sin(t * 2) * 3 / cell) * cell or 0
    love.graphics.push()
    love.graphics.translate(cx, cy + bob)
    love.graphics.scale(math.max(0.01, e), math.max(0.01, e))
    love.graphics.translate(-cx, -cy)
    local dx, dy = math.floor(cx - cw * cell / 2), math.floor(cy - ch * cell / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, dx, dy, 0, cell, cell)
    -- clarão: a silhueta do item em aditivo (não um retângulo por cima)
    local flash = math.max(0, 1 - t / 0.35)
    if flash > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.85 * flash)
        love.graphics.draw(cv, dx, dy, 0, cell, cell)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    return art ~= nil
end

local function drawButton(b, label, focused)
    local fill, outline, col
    if b.primary then
        fill = focused and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD
        outline, col = Palette.AGED_GOLD_LIGHT, Palette.INK
    else
        fill = focused and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.55)
            or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.25)
        outline = focused and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
        col = focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
    end
    Palette.set(Palette.INK, 0.6)
    love.graphics.rectangle("fill", b.x + 3, b.y + 3, b.w, b.h, 3, 3)
    Palette.set(fill)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3, 3)
    love.graphics.setColor(1, 1, 1, b.primary and 0.22 or 0.06)
    love.graphics.rectangle("fill", b.x + 2, b.y + 1, b.w - 4, 2)
    Palette.set(outline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1, 3, 3)
    Palette.set(col)
    local f = TextFit.fit(label, 14, b.w - 20, 8)
    TextFit.print(label, b.x + 10, b.y + math.floor((b.h - f:getHeight()) / 2),
        { size = 14, maxW = b.w - 20, align = "center", minSize = 8 })
end

function Showcase:draw()
    if not self.visible or not self.item then return end
    local it = self.item
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local L = Showcase.layout(sw, sh)
    local t = self.t
    local first = (self.idx == 1)
    MenuKit.drawVeil(first and t or MenuKit.ENTER_DUR, 0.78)
    if first then MenuKit.pushEnter(t) else love.graphics.push() end

    local p = L.panel
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local tx = Showcase.texts(it)

    -- título + contador
    Palette.set(Palette.AGED_GOLD_LIGHT)
    TextFit.print(tx.title, L.title.x, L.title.y, { size = 22, maxW = L.title.w, align = "center",
        minSize = 10, shadow = { 0, 0, 0, 0.8 } })
    Palette.set(Palette.PARCHMENT)
    TextFit.print(I18n.t("unlock_showcase.counter", { i = self.idx, n = self.total }),
        L.counter.x, L.counter.y, { size = 10, maxW = L.counter.w, align = "center", minSize = 8 })

    -- palco: halo + espinhos na grade, item com pop, varredura e clarão, faíscas
    local st = L.stage
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    local r = math.min(st.w, st.h) * 0.62
    local seed = (self.idx or 1) * 17 + #tostring(it.id or it.classId or "")
    drawGlow(cx, cy, r, t, math.min(1, t / 0.3))
    self:_drawStageItem(it, st, t)
    drawSparkles(cx, cy, r, t, math.min(1, math.max(0, (t - 0.2) / 0.4)), seed)

    -- nome + descrição (até 2 linhas)
    Palette.set(Palette.PARCHMENT_LIGHT)
    TextFit.print(tx.name, L.name.x, L.name.y, { size = 18, maxW = L.name.w, align = "center",
        minSize = 9, shadow = { 0, 0, 0, 0.8 } })
    local df = FontManager.getFont(10)
    local _, lines = df:getWrap(tx.sub or "", L.sub.w)
    if #lines > 2 then df = FontManager.getFont(8); _, lines = df:getWrap(tx.sub or "", L.sub.w) end
    love.graphics.setFont(df)
    Palette.set(Palette.PARCHMENT)
    local lh = math.ceil(df:getHeight() * 1.3)
    for i = 1, math.min(2, #lines) do
        love.graphics.print(lines[i], math.floor(L.sub.x + (L.sub.w - df:getWidth(lines[i])) / 2),
            L.sub.y + (i - 1) * lh)
    end

    -- botões
    local labels = { I18n.t("unlock_showcase.continue"), I18n.t("unlock_showcase.skip") }
    local NavCursor = require("src.ui.NavCursor")
    for i, b in ipairs(L.buttons) do
        drawButton(b, labels[i], i == self.focus)
        NavCursor.target("showcase:" .. b.key, b.x, b.y, b.w, b.h, { key = "showcase:" .. b.key })
    end
    if self:_ready() then
        local b = L.buttons[self.focus]
        MenuKit.focusRing(b.x, b.y, b.w, b.h, t)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Escala de UI: a tela vive no espaço virtual (layout, hit-test e mouse).
require("src.ui.UiScale").adopt(Showcase)

return Showcase
