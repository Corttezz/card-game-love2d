-- components/CollectionScreen.lua
-- Tela de coleção: grid com todas as cartas do CardDatabase.
-- Scroll vertical com mouse wheel, filtros por classe, tooltip no hover.
-- Acessível pelo botão "COLEÇÃO" no menu principal, ESC volta.

local Config       = require("src.core.Config")
local FontManager  = require("src.ui.FontManager")
local Theme        = require("src.ui.Theme")
local Palette      = require("src.ui.Palette")
local PixelBackground = require("src.ui.PixelBackground")
local PixelCanvas  = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardDatabase = require("src.systems.CardDatabase")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local CardArt      = require("src.ui.CardArt")
local CardFrame    = require("src.ui.CardFrame")
local CardMesh     = require("src.ui.CardMesh")
local I18n         = require("src.i18n.I18n")
local Sfx          = require("src.systems.Sfx")
local UnlockSystem = require("src.systems.UnlockSystem")
local CardBack     = require("src.ui.CardBack")

local CollectionScreen = {}
CollectionScreen.__index = CollectionScreen

local RARITY_ORDER = { basic = 1, common = 2, uncommon = 3, rare = 4, legendary = 5 }
local CLASS_ORDER  = { warrior = 1, mage = 2, rogue = 3, [""] = 4 }

-- Filtros: id estável + chave I18n p/ label. Resolvido a cada draw via _filters().
local FILTERS = {
    { id = "all",     i18n = "collection.filter_all" },
    { id = "warrior", i18n = "collection.filter_warrior" },
    { id = "mage",    i18n = "collection.filter_mage" },
    { id = "rogue",   i18n = "collection.filter_rogue" },
    { id = "attack",  i18n = "collection.filter_attack" },
    { id = "defense", i18n = "collection.filter_defense" },
    { id = "joker",   i18n = "collection.filter_joker" },
    { id = "effect",  i18n = "collection.filter_effect" },
}

local function filterLabel(f) return I18n.t(f.i18n) end

local CARD_W, CARD_H = 128, 192   -- tamanho renderizado na tela (96×144 × 1.333)
local GAP_X, GAP_Y = 18, 24
local COLS = 5
local TOP_OFFSET = 120            -- espaço pro título + filtros
local BOTTOM_PAD = 40

function CollectionScreen:new()
    local self = setmetatable({}, CollectionScreen)
    self.visible = false
    self.scrollY = 0
    self.maxScrollY = 0
    self.hoverCard = nil
    self.filter = "all"
    self.cardInstances = {}       -- lazy init em show()
    self.filtered = {}
    self.onCloseCallback = nil
    self.inspectedCard = nil      -- carta em modal de zoom
    self.inspectAnim = 0          -- 0..1 (fade/zoom in)
    return self
end

-- Ordena cartas: class > rarity > name (ordena pelo nome localizado pra ficar
-- alfabético no idioma atual)
local function sortCards(list)
    table.sort(list, function(a, b)
        local ca = CLASS_ORDER[a.class or ""] or 99
        local cb = CLASS_ORDER[b.class or ""] or 99
        if ca ~= cb then return ca < cb end
        local ra = RARITY_ORDER[a.rarity or "common"] or 99
        local rb = RARITY_ORDER[b.rarity or "common"] or 99
        if ra ~= rb then return ra < rb end
        return I18n.cardName(a) < I18n.cardName(b)
    end)
end

-- Converte cartas raw → instâncias renderizadas (com CardFrame aplicado).
-- v10.6 (perf — "engasgada ao clicar em COLEÇÃO"): INCREMENTAL com
-- orçamento de tempo por frame. A tela abre instantânea e as cartas
-- aparecem em ondas na ordem do grid (topo primeiro); ~0.3-0.6s pra
-- completar, sem travar frame nenhum. show() constrói a 1ª leva,
-- update() consome o resto.
function CollectionScreen:_buildInstances(budgetSecs)
    if self._buildDone then return end
    if not self._buildList then
        local db = CardDatabase:new()
        local all = db:getAllCards()
        local list = {}
        for _, cd in pairs(all) do list[#list + 1] = cd end
        sortCards(list)
        self._buildList = list
        self._buildIdx = 0
        self._buildDb = db
    end
    local t0 = love.timer.getTime()
    local budget = budgetSecs or 0.006
    while self._buildIdx < #self._buildList do
        self._buildIdx = self._buildIdx + 1
        local cd = self._buildList[self._buildIdx]
        local db = self._buildDb
        if not UnlockSystem.isCardDiscovered(cd.id) then
            -- NÃO DESCOBERTA (Balatro): ocupa o slot mas aparece como verso
            -- "?". Stub leve — nem compõe o canvas da carta (que o jogador
            -- não vai ver), o que também barateia a abertura da tela.
            self.cardInstances[#self.cardInstances + 1] = self:_makeHidden(cd)
        else
            local ok, instance = pcall(function() return db:createCardInstance(cd) end)
            if ok and instance then
                self.cardInstances[#self.cardInstances + 1] = instance
            else
                print("[CollectionScreen] falha ao instanciar carta: " .. tostring(cd.id))
            end
        end
        if (love.timer.getTime() - t0) >= budget then break end
    end
    if self._buildIdx >= #self._buildList then
        self._buildDone = true
        self._buildList = nil
        self._buildDb = nil
        print("[CollectionScreen] " .. #self.cardInstances .. " cartas carregadas")
    end
    -- mantém grid/scroll coerentes com a lista parcial que cresce
    self:_applyFilter()
end

function CollectionScreen:_makeHidden(cd)
    return {
        id = cd.id, name = cd.name, class = cd.class, type = cd.type,
        rarity = cd.rarity, _hidden = true,
        _locked = not UnlockSystem.isCardUnlockedReal(cd.id),
    }
end

-- Reabrir a Coleção depois de uma run: o que foi descoberto nesse meio-tempo
-- vira carta de verdade (e o que estava liberado-mas-oculto atualiza o selo).
function CollectionScreen:_refreshDiscovery()
    if not self._buildDone then return end
    local db
    for i, inst in ipairs(self.cardInstances) do
        if inst._hidden then
            if UnlockSystem.isCardDiscovered(inst.id) then
                db = db or CardDatabase:new()
                local cd = db:getCard(inst.id)
                local ok, real = pcall(function() return db:createCardInstance(cd) end)
                if ok and real then
                    self.cardInstances[i] = real
                else
                    print("[CollectionScreen] falha ao revelar carta: " .. tostring(inst.id))
                end
            else
                inst._locked = not UnlockSystem.isCardUnlockedReal(inst.id)
            end
        end
    end
end

function CollectionScreen:_applyFilter()
    -- Trocar filtro reseta a ordem manual (usuário volta pra sort padrão)
    self._hasManualOrder = false
    self.filtered = {}
    for _, inst in ipairs(self.cardInstances) do
        local match = false
        if self.filter == "all" then
            match = true
        elseif self.filter == "warrior" or self.filter == "mage" or self.filter == "rogue" then
            match = inst.class == self.filter
        elseif self.filter == "attack" or self.filter == "defense"
            or self.filter == "joker" or self.filter == "effect" then
            match = inst.type == self.filter
        end
        if match then self.filtered[#self.filtered + 1] = inst end
    end
    -- Contador "x/y descobertas" da aba (calculado aqui, não no draw).
    local disc = 0
    for _, inst in ipairs(self.filtered) do
        if not inst._hidden then disc = disc + 1 end
    end
    self.discoveredCount = disc
    -- Recalcula scroll máximo
    local rows = math.ceil(#self.filtered / COLS)
    local contentH = rows * (CARD_H + GAP_Y)
    local viewH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
    self.maxScrollY = math.max(0, contentH - viewH)
    self.scrollY = math.min(self.scrollY, self.maxScrollY)
end

function CollectionScreen:show(onClose)
    self.visible = true
    self.scrollY = 0
    self.onCloseCallback = onClose
    -- 1ª leva um pouco maior (preenche o que está na tela de cara);
    -- o resto flui no update sem travar
    self:_refreshDiscovery()
    self:_buildInstances(0.012)
    self:_applyFilter()
end

function CollectionScreen:hide()
    self.visible = false
    self.hoverCard = nil
end

function CollectionScreen:isVisible()
    return self.visible
end

-- gridOrigin/cardRect calculam dinamicamente da window size a cada frame, então
-- o CollectionScreen já é responsivo sem cache de layout. resize() é stub
-- pra contrato uniforme com outras overlay screens.
function CollectionScreen:resize()
    -- O canvas do verso "?" perde o conteúdo em setMode: recompõe sob demanda.
    self._mysteryCanvas = nil
    self:_applyFilter()
end

-- ===== Layout helpers =====

local function gridOrigin()
    local width = love.graphics.getWidth()
    local totalW = COLS * CARD_W + (COLS - 1) * GAP_X
    local startX = (width - totalW) / 2
    return startX, TOP_OFFSET
end

local function cardRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    local ox, oy = gridOrigin()
    return ox + col * (CARD_W + GAP_X), oy + row * (CARD_H + GAP_Y)
end

-- ===== Eventos =====

function CollectionScreen:update(dt)
    if not self.visible then return end
    -- v10.6: consome a fila de instanciação (orçamento por frame)
    if not self._buildDone then self:_buildInstances() end
    -- Anima entrada/saída do modal de inspeção
    if self.inspectedCard then
        self.inspectAnim = math.min(1, self.inspectAnim + dt * 6)
    else
        self.inspectAnim = math.max(0, self.inspectAnim - dt * 8)
    end
    -- No modal ou durante drag, não processa hover do grid
    if self.inspectedCard or self._draggingIdx then
        self.hoverCard = nil
        return
    end
    local mx, my = love.mouse.getPosition()
    local prevHover = self.hoverCard and self.hoverCard.instance or nil
    self.hoverCard = nil
    for i, inst in ipairs(self.filtered) do
        local x, y = cardRect(i)
        y = y - self.scrollY
        if mx >= x and mx <= x + CARD_W and my >= y and my <= y + CARD_H then
            self.hoverCard = { instance = inst, x = x, y = y, index = i }
            break
        end
    end
    -- Tick sutil quando o card em hover muda. Hover de carta usa hoverCard
    -- (sound de carta), não menuHover (sound de UI). Pitch random pra evitar
    -- fadiga ao percorrer a grid rápido. SEM baseVolume — usa Config.Audio.HOVER_VOLUME
    -- (=0.03) carregado em main.lua, ficando baixinho como esperado.
    local newHover = self.hoverCard and self.hoverCard.instance or nil
    if newHover and newHover ~= prevHover then
        Sfx.playWithVariation("hoverCard", 0.95, 0.18)
    end
end

function CollectionScreen:wheelmoved(x, y)
    if not self.visible then return end
    if self.inspectedCard then return end -- scroll desabilitado no modal
    self.scrollY = math.max(0, math.min(self.maxScrollY, self.scrollY - y * 40))
end

function CollectionScreen:keypressed(key)
    if not self.visible then return end
    -- Modal de inspeção consome ESC primeiro
    if self.inspectedCard then
        if key == "escape" or key == "space" or key == "return" then
            Sfx.play("menuClose")
            self.inspectedCard = nil
        elseif key == "left" or key == "a" then
            Sfx.play("collectionFlip")
            self:_inspectNeighbor(-1)
        elseif key == "right" or key == "d" then
            Sfx.play("collectionFlip")
            self:_inspectNeighbor(1)
        end
        return
    end
    if key == "escape" then
        self:hide()
        if self.onCloseCallback then self.onCloseCallback() end
    elseif key == "up" or key == "pageup" then
        self.scrollY = math.max(0, self.scrollY - 100)
    elseif key == "down" or key == "pagedown" then
        self.scrollY = math.min(self.maxScrollY, self.scrollY + 100)
    end
end

-- Navega entre cartas filtradas no modal (setas ← →)
function CollectionScreen:_inspectNeighbor(delta)
    if not self.inspectedCard then return end
    local idx = nil
    for i, inst in ipairs(self.filtered) do
        if inst == self.inspectedCard then idx = i; break end
    end
    if not idx then return end
    local n = #self.filtered
    local newIdx = idx
    for _ = 1, n do
        newIdx = ((newIdx - 1 + delta) % n) + 1
        if not self.filtered[newIdx]._hidden then break end
    end
    self.inspectedCard = self.filtered[newIdx]
    self.inspectAnim = 0.3 -- leve "pop" ao trocar
end

function CollectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    if button == 1 then
        -- Modal de inspeção: clique fora fecha, clique em setas navega
        if self.inspectedCard then
            local w, h = love.graphics.getDimensions()
            -- Área da carta grande (centralizada)
            local cardW, cardH = 384, 576 -- 96×144 × 4
            local cardX = (w - cardW) / 2 - 140 -- empurra à esquerda pra caber texto
            local cardY = (h - cardH) / 2
            -- Setas de navegação (clique em 80px nas laterais)
            local arrowY = h / 2 - 30
            -- Esquerda
            if x >= 20 and x <= 100 and y >= arrowY and y <= arrowY + 60 then
                Sfx.play("collectionFlip")
                self:_inspectNeighbor(-1)
                return
            end
            -- Direita
            if x >= w - 100 and x <= w - 20 and y >= arrowY and y <= arrowY + 60 then
                Sfx.play("collectionFlip")
                self:_inspectNeighbor(1)
                return
            end
            -- Clique em qualquer outro lugar fecha
            if x < cardX or x > cardX + cardW + 320 or y < cardY - 20 or y > cardY + cardH + 20 then
                Sfx.play("menuClose")
                self.inspectedCard = nil
            end
            return
        end
        -- Filtro tabs no topo
        local font = FontManager.getFont(14)
        local tabY = 70
        local tabX = 20
        love.graphics.setFont(font)
        for _, f in ipairs(FILTERS) do
            local w = font:getWidth(filterLabel(f)) + 20
            if x >= tabX and x <= tabX + w and y >= tabY and y <= tabY + 28 then
                Sfx.play("buttonClick")
                self.filter = f.id
                self.scrollY = 0
                self:_applyFilter()
                return
            end
            tabX = tabX + w + 8
        end
        -- Carta na grid: inicia dragPending (click + drag unificados; resolve em release)
        for i, inst in ipairs(self.filtered) do
            local cx, cy = cardRect(i)
            cy = cy - self.scrollY
            if x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
                self._dragPendingIdx = i
                self._dragStartMX = x
                self._dragStartMY = y
                self._dragOffsetX = cx - x
                self._dragOffsetY = cy - y
                self._draggingIdx = nil -- promovido em mousemoved se cruzar threshold
                return
            end
        end
    end
end

-- ===== Drag helpers =====

-- Computa o índice 1..#filtered pra onde uma carta cairia, baseado em (mx, my).
-- Ignora zonas fora da grid (retorna nil quando clampa pros extremos óbvios).
function CollectionScreen:_computeDropIndex(mx, my)
    local total = #self.filtered
    if total <= 1 then return 1 end
    local w = love.graphics.getWidth()
    local totalW = COLS * CARD_W + (COLS - 1) * GAP_X
    local ox = (w - totalW) / 2
    local oy = TOP_OFFSET
    -- Clamp col/row pra dentro da grid (considerando scroll)
    local col = math.floor((mx - ox + GAP_X / 2) / (CARD_W + GAP_X))
    col = math.max(0, math.min(COLS - 1, col))
    local row = math.floor((my - oy + self.scrollY + GAP_Y / 2) / (CARD_H + GAP_Y))
    row = math.max(0, row)
    local idx = row * COLS + col + 1
    return math.max(1, math.min(total, idx))
end

function CollectionScreen:mousemoved(x, y, dx, dy)
    if not self.visible or self.inspectedCard then return end
    if self._dragPendingIdx and not self._draggingIdx then
        local Config = require("src.core.Config")
        local threshold = (Config.Cards and Config.Cards.DRAG_THRESHOLD_PX) or 6
        local distX = x - self._dragStartMX
        local distY = y - self._dragStartMY
        if (distX * distX + distY * distY) > (threshold * threshold) then
            self._draggingIdx = self._dragPendingIdx
        end
    end
end

function CollectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    if button ~= 1 then return end

    -- Drag ativo → reorder (session-only via manualOrder)
    if self._draggingIdx then
        local dropIdx = self:_computeDropIndex(x, y)
        if dropIdx ~= self._draggingIdx then
            local inst = table.remove(self.filtered, self._draggingIdx)
            table.insert(self.filtered, dropIdx, inst)
            Sfx.play("collectionFlip")
            -- Salva a ordem manual atual (vive enquanto a coleção está aberta)
            self._hasManualOrder = true
        end
    elseif self._dragPendingIdx then
        -- Só click (sem drag) → abre modal de inspeção, como era antes
        local inst = self.filtered[self._dragPendingIdx]
        if inst and inst._hidden then
            -- Carta não descoberta não abre zoom (não há o que mostrar); a
            -- dica de como liberar já está no tooltip do hover.
            Sfx.play("buttonClick", { pitch = 0.7 })
        elseif inst then
            Sfx.play("collectionFlip")
            self.inspectedCard = inst
            self.inspectAnim = 0
        end
    end

    self._dragPendingIdx = nil
    self._draggingIdx = nil
end

-- ===== Render =====

local function drawBackground()
    local w, h = love.graphics.getDimensions()
    if SceneBackground.draw("collection", w, h, 0.55) then return end
    -- Fallback
    local bg = PixelBackground.voidStars(w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, 0, 0)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

local function drawTitleAndFilters(self)
    local width = love.graphics.getWidth()

    -- Título
    local titleFont = FontManager.getResponsiveFont(0.05, 36)
    love.graphics.setFont(titleFont)
    local title = I18n.t("collection.title")
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, (width - titleFont:getWidth(title)) / 2, 12)

    -- Subtítulo: count
    local subFont = FontManager.getFont(14)
    love.graphics.setFont(subFont)
    local sub = I18n.t("unlocks.discovered_count",
        { n = self.discoveredCount or #self.filtered, total = #self.filtered })
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, (width - subFont:getWidth(sub)) / 2, 50)

    -- Filtros (tabs horizontais)
    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local tabX = 20
    local tabY = 70
    for _, f in ipairs(FILTERS) do
        local label = filterLabel(f)
        local w = font:getWidth(label) + 20
        local active = self.filter == f.id
        if active then
            love.graphics.setColor(Palette.AGED_GOLD)
        else
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.6)
        end
        love.graphics.rectangle("fill", tabX, tabY, w, 28, 4, 4)
        love.graphics.setColor(Palette.PARCHMENT_DARK)
        love.graphics.rectangle("line", tabX, tabY, w, 28, 4, 4)
        love.graphics.setColor(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        love.graphics.print(label, tabX + 10, tabY + 6)
        tabX = tabX + w + 8
    end

    -- Barra de scroll à direita
    if self.maxScrollY > 0 then
        local barX = width - 12
        local barH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
        local scrollFrac = self.scrollY / self.maxScrollY
        local knobH = math.max(30, barH * (barH / (barH + self.maxScrollY)))
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.5)
        love.graphics.rectangle("fill", barX, TOP_OFFSET, 6, barH)
        love.graphics.setColor(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, TOP_OFFSET + scrollFrac * (barH - knobH), 6, knobH)
    end
end

-- Desenha card mini no grid com perspective warp (mesh+shader) + sombra direcional.
-- Luz fixa acima do centro da tela → sombra cai pro lado oposto à posição + press.
--   mouseUV: vec2 [-1,1] relativa ao centro da carta (0,0 = sem press)
--   hoverStrength: 0..1 (usa pro warp + pro offset tilt da sombra)
local function drawCardMini(instance, x, y, hoverScale, alpha, mouseUV, hoverStrength)
    if not instance.image then return end
    hoverScale = hoverScale or 1
    alpha = alpha or 1
    mouseUV = mouseUV or { 0, 0 }
    hoverStrength = hoverStrength or 0

    -- Grid idle = estático; HOVER anima o ícone (regra do dono, Jul/2026).
    -- Swap temporário de instance.image, restaurado no fim da função.
    local _prevImage = instance.image
    if hoverScale > 1.001 or hoverStrength > 0.05 then
        local live = CardFrame.liveImage(instance)
        if live then instance.image = live end
    end

    local baseScale = CARD_W / instance.image:getWidth()
    local drawScale = baseScale * hoverScale
    local drawW = instance.image:getWidth() * drawScale
    local drawH = instance.image:getHeight() * drawScale
    -- Lift visual quando hover (carta sobe em direção ao cursor)
    local lift = (hoverScale - 1) * 30
    local cx = x + CARD_W / 2
    local cy = y + CARD_H / 2 - lift

    -- Sombra direcional (luz acima do centro + press shift oposto)
    local Config = require("src.core.Config")
    local screenW = love.graphics.getWidth()
    local dirX = (cx - screenW / 2) / (screenW / 2)
    if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
    local shadowMaxX = (Config.Cards and Config.Cards.SHADOW_MAX_HORIZ_OFFSET) or 20
    local shadowBaseY = (Config.Cards and Config.Cards.SHADOW_BASE_OFFSET_Y) or 6
    local shadowPressShift = (Config.Cards and Config.Cards.SHADOW_PRESS_SHIFT) or 14
    local shadowBaseAlpha = (Config.Cards and Config.Cards.SHADOW_ALPHA) or 0.50
    local baseLift = (Config.Cards and Config.Cards.BASE_LIFT) or 3

    local shadowDx = -dirX * shadowMaxX - mouseUV[1] * shadowPressShift * hoverStrength
    local shadowDy = shadowBaseY + (baseLift + lift) * 0.5
                   - mouseUV[2] * shadowPressShift * hoverStrength * 0.7
    local shAlpha = shadowBaseAlpha * alpha + (hoverScale - 1) * 0.4
    if shAlpha > 0.85 then shAlpha = 0.85 end

    local px = math.floor(cx - drawW / 2)
    local py = math.floor(cy - drawH / 2)

    -- Desenha sombra (pode usar mesh pra acompanhar warp)
    -- Perf (Out/2026): em repouso (hoverStrength 0) o warp é IDENTIDADE —
    -- o vertex shader não move nada e o fragment é passthrough. Pular shader+
    -- mesh+uniforms nas cartas paradas tira ~30 shader switches por frame.
    local shader = (hoverStrength > 0.001) and CardMesh.getShader() or nil
    local timeNow = love.timer.getTime()
    if shader then
        local mesh = CardMesh.getMesh(instance.image:getWidth(), instance.image:getHeight())
        mesh:setTexture(instance.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, instance.image)
        -- Sombra primeiro (tint preto + offset)
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(mesh,
            px + shadowDx, py + shadowDy,
            0, drawScale, drawScale)
        -- Card principal
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(mesh, px, py, 0, drawScale, drawScale)
        love.graphics.setShader()
    else
        -- Fallback sem shader: desenho direto
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(instance.image,
            math.floor(px + shadowDx), math.floor(py + shadowDy),
            0, drawScale, drawScale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(instance.image, px, py, 0, drawScale, drawScale)
    end

    -- Icon animations por cima
    if not instance._cachedArt then
        local ok, a = pcall(CardArt.resolve, instance)
        instance._cachedArt = ok and a or { bgPattern = nil }
    end
    CardAnimationLayer.draw(instance, instance._cachedArt, px, py, drawScale, drawScale)
    love.graphics.setColor(1, 1, 1, 1)
    instance.image = _prevImage
end

-- Verso da carta NÃO DESCOBERTA, composto UMA vez num canvas 96×144 (mesma
-- resolução do canvas da carta → mesma escala/nitidez no grid). Plain draw no
-- grid, sem shader: em repouso o warp é identidade.
local function getMysteryCanvas(self)
    if self._mysteryCanvas then return self._mysteryCanvas end
    local W, H = CardFrame.WIDTH, CardFrame.HEIGHT
    local c = love.graphics.newCanvas(W, H)
    c:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.origin()
    -- O 1º uso acontece DENTRO do scissor do grid: sem limpar, o recorte de
    -- tela vale também pro canvas e o verso sai cortado.
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    local img = CardBack.getImage()
    if img then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, 0, 0, 0, W / img:getWidth(), H / img:getHeight())
    else
        print("[CollectionScreen] verso da carta ausente (assets/cards/back.png) — usando fallback chapado")
        love.graphics.setColor(Palette.INK)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(Palette.AGED_GOLD)
        love.graphics.rectangle("line", 1.5, 1.5, W - 3, H - 3)
    end
    -- Véu escuro + "?" dourado no centro.
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.45)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local f = FontManager.getFont(32)
    love.graphics.setFont(f)
    local q = "?"
    local qx = math.floor((W - f:getWidth(q)) / 2)
    local qy = math.floor((H - f:getHeight()) / 2)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(q, qx + 2, qy + 2)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(q, qx, qy)
    love.graphics.pop()
    self._mysteryCanvas = c
    return c
end

local function drawMystery(self, inst, x, y, hoverScale)
    local img = getMysteryCanvas(self)
    local drawScale = (CARD_W / img:getWidth()) * hoverScale
    local drawW, drawH = img:getWidth() * drawScale, img:getHeight() * drawScale
    local lift = (hoverScale - 1) * 30
    local px = math.floor(x + CARD_W / 2 - drawW / 2)
    local py = math.floor(y + CARD_H / 2 - lift - drawH / 2)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.draw(img, px + 4, py + 7, 0, drawScale, drawScale)
    -- Bloqueada = mais apagada que a liberada-mas-não-vista: o jogador lê de
    -- relance o que já pode cair numa run e o que ainda depende de maestria.
    local k = inst._locked and 0.55 or 0.9
    love.graphics.setColor(k, k, k, 1)
    love.graphics.draw(img, px, py, 0, drawScale, drawScale)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHiddenTooltip(self, inst)
    local TIP_W, TIP_H, PAD = 300, 110, 10
    local cx = self.hoverCard.x + CARD_W + 10
    local cy = self.hoverCard.y
    if cx + TIP_W > love.graphics.getWidth() then cx = self.hoverCard.x - TIP_W - 10 end
    if cx < 0 then cx = 0 end
    if cy + TIP_H > love.graphics.getHeight() then cy = love.graphics.getHeight() - TIP_H - 10 end
    PixelCanvas.rect(cx, cy, TIP_W, TIP_H, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(cx, cy, TIP_W, TIP_H, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(cx + 2, cy + 2, TIP_W - 4, TIP_H - 4, Palette.AGED_GOLD_DARK)
    local nameFont = FontManager.getFont(12)
    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print("???", cx + PAD, cy + PAD)
    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    if inst._locked then Palette.set(Palette.BLOOD) else Palette.set(Palette.PARCHMENT) end
    love.graphics.print(I18n.t(inst._locked and "unlocks.locked" or "unlocks.undiscovered"),
        cx + PAD, cy + PAD + 24)
    local key, vars = UnlockSystem.getCardHint(inst.id)
    local descFont = FontManager.getFont(8)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.printf(I18n.t(key, vars), cx + PAD, cy + PAD + 46, TIP_W - PAD * 2)
end

local function drawHoverTooltip(self)
    if not self.hoverCard then return end
    local inst = self.hoverCard.instance
    if inst._hidden then return drawHiddenTooltip(self, inst) end

    local TIP_W = 320
    local TIP_H = 180
    local PAD = 10
    local TEXT_W = TIP_W - PAD * 2   -- largura útil pra printf wrap

    local cx = self.hoverCard.x + CARD_W + 10
    local cy = self.hoverCard.y
    if cx + TIP_W > love.graphics.getWidth() then
        cx = self.hoverCard.x - TIP_W - 10
    end
    if cx < 0 then cx = 0 end
    -- Clamp vertical pra não vazar pelo rodapé
    if cy + TIP_H > love.graphics.getHeight() then
        cy = love.graphics.getHeight() - TIP_H - 10
    end

    -- Fundo pixel (sem cantos arredondados)
    PixelCanvas.rect(cx, cy, TIP_W, TIP_H, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(cx, cy, TIP_W, TIP_H, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(cx + 2, cy + 2, TIP_W - 4, TIP_H - 4, Palette.AGED_GOLD_DARK)

    -- Nome (Press Start 2P size 12) com wrap
    local nameFont = FontManager.getFont(12)
    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.printf(I18n.cardName(inst), cx + PAD, cy + PAD, TEXT_W)

    -- Separador fino
    PixelCanvas.hline(cx + PAD, cy + PAD + 30, TEXT_W, Palette.AGED_GOLD_DARK)

    -- Type / Class / Rarity em 3 linhas separadas (evita overflow horizontal)
    local metaFont = FontManager.getFont(8)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local mY = cy + PAD + 36
    -- Colunas DINÂMICAS com fit (design system Jul/2026): os offsets fixos
    -- 72/172 colidiam entre si e vazavam do tooltip em idiomas longos.
    local TextFit = require("src.ui.TextFit")
    local mX = cx + PAD
    local mEnd = cx + TIP_W - PAD
    Palette.set(typeColor)
    local w1 = TextFit.print(typeLabel, mX, mY,
        { size = 8, maxW = math.floor((mEnd - mX) * 0.34) })
    mX = mX + w1 + 12
    Palette.set(Palette.PARCHMENT)
    local w2 = TextFit.print(classLabel, mX, mY,
        { size = 8, maxW = math.floor((mEnd - mX) * 0.5) })
    mX = mX + w2 + 12
    Palette.set(rarityColor)
    TextFit.print(rarityLabel, mX, mY, { size = 8, maxW = mEnd - mX })

    -- Descrição (wrap)
    local descFont = FontManager.getFont(8)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT_LIGHT)
    local descText = I18n.cardDesc(inst)
    if not descText or descText == "" then descText = I18n.t("card_info.no_desc") end
    love.graphics.printf(descText, cx + PAD, cy + PAD + 54, TEXT_W)

    -- Stats (rodapé)
    local statFont = FontManager.getFont(10)
    love.graphics.setFont(statFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local statLine = I18n.t("card_info.cost") .. tostring(inst.cost or 0)
    if inst.type == "attack" then
        statLine = statLine .. "  ATK: " .. tostring(inst.attack or 0)
    elseif inst.type == "defense" then
        statLine = statLine .. "  DEF: " .. tostring(inst.defense or 0)
    end
    love.graphics.print(statLine, cx + PAD, cy + TIP_H - 20)
end

local function drawInspectArrows(self, width, height)
    if #self.filtered <= 1 then return end
    local arrowY = height / 2 - 30
    local t = love.timer.getTime()
    local pulse = 0.7 + math.sin(t * 3) * 0.2
    local arrowFont = FontManager.getFont(48)
    love.graphics.setFont(arrowFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], pulse)
    love.graphics.print("‹", 40, arrowY)
    love.graphics.print("›", width - 80, arrowY)
end

local function drawInspectModal(self)
    if not self.inspectedCard and self.inspectAnim <= 0 then return end
    local inst = self.inspectedCard or self.lastInspected
    if not inst then return end
    self.lastInspected = inst

    local width, height = love.graphics.getDimensions()
    local anim = self.inspectAnim

    -- Backdrop escurecido
    love.graphics.setColor(0, 0, 0, 0.82 * anim)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Carta em escala grande (4x = 384×576)
    local scale = 4 * (0.85 + 0.15 * anim)
    local cardW = 96 * scale
    local cardH = 144 * scale
    local cardX = (width - cardW) / 2 - 140  -- desloca pra esquerda pra caber painel
    local cardY = (height - cardH) / 2

    -- Render da carta com perspective warp + sombra direcional.
    -- Visualização ampliada SEMPRE anima o ícone (regra do dono, Jul/2026).
    local _prevImage = inst.image
    do
        local live = CardFrame.liveImage(inst)
        if live then inst.image = live end
    end
    if inst.image then
        local mx, my = love.mouse.getPosition()
        -- mouseUV relativo ao centro da carta grande
        local cx = cardX + cardW / 2
        local cy = cardY + cardH / 2
        local uvx = (mx - cx) / (cardW / 2)
        local uvy = (my - cy) / (cardH / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        local uvInside = math.abs(uvx) < 1.05 and math.abs(uvy) < 1.05
        local mouseUV = uvInside and { uvx, uvy } or { 0, 0 }
        local hoverStrength = uvInside and anim or 0

        -- Sombra: cai oposta à posição do card na tela + oposta ao press
        local shadowPressShift = 40 -- modal é grande, offset maior fica natural
        local dirX = (cx - width / 2) / (width / 2)
        if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
        local shDx = -dirX * 30 - uvx * shadowPressShift * hoverStrength
        local shDy = 16 - uvy * shadowPressShift * hoverStrength * 0.7

        local shader = CardMesh.getShader()
        local timeNow = love.timer.getTime()
        if shader then
            local mesh = CardMesh.getMesh(inst.image:getWidth(), inst.image:getHeight())
            mesh:setTexture(inst.image)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, inst.image)
            -- Sombra
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(mesh, cardX + shDx, cardY + shDy, 0, scale, scale)
            -- Card
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(mesh, cardX, cardY, 0, scale, scale)
            love.graphics.setShader()
        else
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(inst.image, cardX + shDx, cardY + shDy, 0, scale, scale)
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(inst.image, cardX, cardY, 0, scale, scale)
        end

        -- Animações do ícone (shine/drip/sparkle/etc) no modal de zoom
        if not inst._cachedArt then
            local ok, a = pcall(CardArt.resolve, inst)
            inst._cachedArt = ok and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(inst, inst._cachedArt, cardX, cardY, scale, scale)
    end
    inst.image = _prevImage

    -- Painel lateral com info detalhada — pixel chrome (sem cantos arredondados)
    local panelX = cardX + cardW + 30
    local panelY = cardY
    local panelW = 340
    local panelH = cardH
    local PAD = 16
    local TEXT_W = panelW - PAD * 2

    -- Fundo pixel com dual outline. rectangle simples respeita anim (alpha fade-in).
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92 * anim)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
    love.graphics.rectangle("line", panelX,     panelY,     panelW,     panelH)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], anim)
    love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

    -- Nome (Press Start 2P é larga; size 16 com wrap cabe em 308px)
    local nameFont = FontManager.getFont(16)
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    love.graphics.printf(I18n.cardName(inst), panelX + PAD, panelY + 18, TEXT_W)

    -- Separador dourado
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

    -- Type / Class / Rarity em 3 linhas separadas (cada uma com sua cor)
    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local metaY = panelY + 84
    local lineH = metaFont:getHeight() + 4
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], anim)
    love.graphics.print(typeLabel, panelX + PAD, metaY)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], anim)
    love.graphics.print(classLabel, panelX + PAD, metaY + lineH)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], anim)
    love.graphics.print(rarityLabel, panelX + PAD, metaY + lineH * 2)

    -- Stats box
    local statFont = FontManager.getFont(12)
    love.graphics.setFont(statFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local statY = metaY + lineH * 3 + 12
    love.graphics.print(I18n.t("card_info.cost") .. tostring(inst.cost or 0), panelX + PAD, statY)
    statY = statY + 20
    if inst.type == "attack" then
        love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], anim)
        love.graphics.print(I18n.t("card_info.damage") .. tostring(inst.attack or 0), panelX + PAD, statY)
        statY = statY + 20
    elseif inst.type == "defense" then
        love.graphics.setColor(Palette.STEEL_LIGHT[1], Palette.STEEL_LIGHT[2], Palette.STEEL_LIGHT[3], anim)
        love.graphics.print(I18n.t("card_info.defense") .. tostring(inst.defense or 0), panelX + PAD, statY)
        statY = statY + 20
    end

    -- Descrição
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, statY + 4, TEXT_W, 1)
    statY = statY + 14
    local descFont = FontManager.getFont(10)
    love.graphics.setFont(descFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local fullDesc = I18n.cardDesc(inst)
    if not fullDesc or fullDesc == "" then fullDesc = I18n.t("card_info.no_desc") end
    love.graphics.printf(fullDesc, panelX + PAD, statY, TEXT_W)

    -- Efeitos listados
    if inst.effects and #inst.effects > 0 then
        local effY = statY + 80
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
        love.graphics.print(I18n.t("card_info.effects"), panelX + PAD, effY)
        love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
        love.graphics.setFont(descFont)
        for i, e in ipairs(inst.effects) do
            local desc = I18n.effectDesc(e)
            love.graphics.printf("- " .. desc, panelX + PAD + 8, effY + 16 * i, TEXT_W - 8)
            if i >= 4 then break end
        end
    end

    -- ID no rodapé do painel (debug-friendly)
    local idFont = FontManager.getFont(8)
    love.graphics.setFont(idFont)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.4 * anim)
    love.graphics.printf(inst.id or "", panelX + PAD, panelY + panelH - 16, TEXT_W)

    -- Setas de navegação se há mais cartas
    drawInspectArrows(self, width, height)

    -- Dica de fechar no rodapé
    local closeFont = FontManager.getFont(13)
    love.graphics.setFont(closeFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    local closeMsg = I18n.t("collection.inspect_help")
    love.graphics.print(closeMsg, (width - closeFont:getWidth(closeMsg)) / 2, height - 30)

    love.graphics.setColor(1, 1, 1, 1)
end

function CollectionScreen:draw()
    if not self.visible then return end
    drawBackground()
    drawTitleAndFilters(self)

    local width, height = love.graphics.getDimensions()
    local dt = love.timer.getDelta()
    local mx, my = love.mouse.getPosition()

    -- self.hoverCard atualizado em update(); usa .index pra identificar
    local hoveringIdx = self.hoverCard and self.hoverCard.index or nil

    -- Interpola posições + hover scales de cada card
    self._cardAnim = self._cardAnim or {}
    local ease = 1 - math.exp(-18 * dt)
    for i, inst in ipairs(self.filtered) do
        local anim = self._cardAnim[inst] or { rx = 0, ry = 0, hs = 1.0, inited = false }
        local tx, ty = cardRect(i)
        ty = ty - self.scrollY
        if not anim.inited then
            anim.rx = tx; anim.ry = ty; anim.inited = true
        end
        -- Target = slot position (ou mouse se dragging)
        if self._draggingIdx == i then
            anim.rx = mx + (self._dragOffsetX or 0)
            anim.ry = my + (self._dragOffsetY or 0)
        else
            anim.rx = anim.rx + (tx - anim.rx) * ease
            anim.ry = anim.ry + (ty - anim.ry) * ease
        end
        -- Hover scale target
        local targetHs = (i == hoveringIdx) and 1.08 or 1.0
        if self._draggingIdx == i then targetHs = 1.10 end
        anim.hs = anim.hs + (targetHs - anim.hs) * ease
        self._cardAnim[inst] = anim
    end

    -- Computa mouseUV relativo à carta em hover (pra passar pro shader warp)
    local function computeMouseUV(anim)
        local cx = anim.rx + CARD_W / 2
        local cy = anim.ry + CARD_H / 2
        local uvx = (mx - cx) / (CARD_W / 2)
        local uvy = (my - cy) / (CARD_H / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        return { uvx, uvy }
    end

    -- hoverStrength = proporção do warp. Só o card em hover tem warp.
    local hoverStrFromScale = function(hs) return math.max(0, math.min(1, (hs - 1.0) / 0.08)) end

    -- Grid com clip (cards não-draged + não-hovered primeiro)
    love.graphics.setScissor(0, TOP_OFFSET, width, height - TOP_OFFSET - BOTTOM_PAD)
    for i, inst in ipairs(self.filtered) do
        if i ~= self._draggingIdx and i ~= hoveringIdx then
            local anim = self._cardAnim[inst]
            if anim and anim.ry + CARD_H >= TOP_OFFSET and anim.ry <= height - BOTTOM_PAD then
                if inst._hidden then
                    drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
                else
                    -- Cards não-hover: sem warp (mouseUV zero, hoverStrength zero)
                    drawCardMini(inst, anim.rx, anim.ry, anim.hs, 1, { 0, 0 }, 0)
                end
            end
        end
    end
    love.graphics.setScissor()

    -- Hovered card por cima com warp ativo
    if hoveringIdx then
        local inst = self.filtered[hoveringIdx]
        local anim = self._cardAnim[inst]
        if anim then
            if inst._hidden then
                drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
            else
                local uv = computeMouseUV(anim)
                local str = hoverStrFromScale(anim.hs)
                drawCardMini(inst, anim.rx, anim.ry, anim.hs, 1, uv, str)
            end
        end
    end

    -- Drag card por cima — mouse sempre no centro (carta segue mouse), sem warp adicional
    if self._draggingIdx then
        local inst = self.filtered[self._draggingIdx]
        local anim = self._cardAnim[inst]
        if anim and inst and inst._hidden then
            drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
        elseif anim and inst then
            drawCardMini(inst, anim.rx, anim.ry, anim.hs, 0.95, { 0, 0 }, 0)
        end
    end

    -- Hover tooltip por cima (fora do scissor, apenas quando modal não está ativo)
    if not self.inspectedCard and self.inspectAnim < 0.1 then
        drawHoverTooltip(self)
    end

    -- Footer com instruções
    local instFont = FontManager.getFont(12)
    love.graphics.setFont(instFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    local inst = I18n.t("collection.footer")
    love.graphics.print(inst, (width - instFont:getWidth(inst)) / 2, height - 22)

    -- Modal de inspeção (por cima de tudo)
    drawInspectModal(self)

    love.graphics.setColor(1, 1, 1, 1)
end

return CollectionScreen
