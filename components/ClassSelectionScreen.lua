-- components/ClassSelectionScreen.lua
-- Seleção de classe v4 — "a página do grimório" (Out/2026).
-- O dono achou a v3 poluída e com "cara de IA": três painéis iguais lado a
-- lado, cada um com nome, maestria, barra, descrição, vida, passiva longa e
-- duas cartas — tudo de uma vez. A v4 mostra UMA classe por vez:
--   • à esquerda, o EMBLEMA da classe em foco, grande e vivo (ClassEmblem +
--     o ar em volta, ClassHeroFx) e, no pé, as três classes pequenas pra
--     trocar o foco; ao lado delas o Selo do Grimório (só se já liberado);
--   • à direita, uma folha de grimório (GrimoirePage) com o essencial —
--     nome, uma linha de identidade, a passiva em uma linha, vida/mana/
--     baralho em ícones — e a fita COMEÇAR. O resto (passiva completa,
--     cartas iniciais, maestria, recordes) mora atrás do marcador DETALHES.
-- Classe bloqueada: silhueta acorrentada + a condição de liberação, só.
-- Tipografia: DUAS fontes (nome e corpo); ênfase por cor, não por tamanho.
-- Layout = ZONAS (src/ui/ClassSelectLayout.lua, com validate()).
--
-- Contrato com o main/tools/testes: new/show/hide/update/draw/keypressed/
-- mousepressed/mousereleased/resize/updatePositions, selectClass(id) inicia a
-- run (bloqueada recusa), focusClass(id) só troca o foco, sealFor(id),
-- buttons[classId] = o emblema pequeno da classe, _panelOf(id).

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local SceneBackground = require("src.ui.SceneBackground")
local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local CardFrame = require("src.ui.CardFrame")
local IconLoader = require("src.ui.IconLoader")
local RadialGlow = require("src.ui.RadialGlow")
local TextFit = require("src.ui.TextFit")
local ClassEmblem = require("src.ui.ClassEmblem")
local ClassHeroFx = require("src.ui.ClassHeroFx")
local GrimoirePage = require("src.ui.GrimoirePage")
local Layout = require("src.ui.ClassSelectLayout")
local UnlockSystem = require("src.systems.UnlockSystem")
local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local Sfx = require("src.systems.Sfx")

-- Cor de identidade por classe (traço sob o nome + luz atrás do emblema).
local CLASS_COLORS = {
    warrior = { 0.78, 0.25, 0.18 },   -- carmim
    mage    = { 0.45, 0.55, 0.95 },   -- azul arcano
    rogue   = { 0.42, 0.72, 0.34 },   -- verde veneno
}

-- Ordem FIXA de exibição (pairs() embaralhava a ordem entre sessões)
local CLASS_ORDER = { "warrior", "mage", "rogue" }

local ClassSelectionScreen = {}
ClassSelectionScreen.__index = ClassSelectionScreen
ClassSelectionScreen.CLASS_ORDER = CLASS_ORDER

function ClassSelectionScreen:new()
    local instance = setmetatable({}, ClassSelectionScreen)
    instance.visible = false
    instance.buttons = {}
    instance.panels = {}          -- { classId, info, cards, unlocked, unlock, mastery, shake }
    instance.cardRegistry = CardRegistry:new()
    instance.selectedClass = nil
    instance.focus = nil          -- classe em foco (a da página)
    instance.pageMode = "summary" -- "summary" | "details"
    instance._starterCache = {}
    instance._locked = false      -- input travado durante o FX de escolha
    instance._sparks = {}
    instance._flash = 0           -- emblema "acende" ao entrar em foco
    instance._fade = 1            -- texto da página reaparece na troca
    instance._pick = 0            -- anel do momento da escolha
    instance._sealTip = 0         -- regra do selo visível por um instante
    instance.seal = 0

    instance.onClassSelected = nil
    instance.onBackToMenu = nil

    instance:createClassButtons()
    return instance
end

-- Instâncias visuais das cartas iniciais (CardFrame real, cacheado).
function ClassSelectionScreen:_starterCards(classId)
    if self._starterCache[classId] then return self._starterCache[classId] end
    local out = {}
    for _, id in ipairs(self.cardRegistry:getStarterDeckForClass(classId)) do
        local cd = CardDatabase:getCard(id)
        if cd then
            local ok, inst = pcall(function() return CardDatabase:createCardInstance(cd) end)
            if ok and inst then
                table.insert(out, inst)
            else
                print("[ClassSelection] AVISO: carta inicial não instanciou: " .. tostring(id))
            end
        else
            print("[ClassSelection] AVISO: carta inicial inexistente: " .. tostring(id))
        end
    end
    self._starterCache[classId] = out
    return out
end

-- Estado de liberação/maestria (relido a cada show/resize).
function ClassSelectionScreen:_refreshUnlock(panel)
    panel.unlock = UnlockSystem.getClassUnlockInfo(panel.classId)
    panel.unlocked = UnlockSystem.isClassUnlocked(panel.classId)
    panel.mastery = panel.unlocked and UnlockSystem.getClassMastery(panel.classId) or nil
end

local function invisible(r, onClick)
    local b = Button:new(r.x, r.y, r.w, r.h, "", onClick)
    b:setVariant("invisible")
    return b
end

function ClassSelectionScreen:createClassButtons()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local lay = Layout.compute(sw, sh, #CLASS_ORDER)
    self.layout = lay

    local prev = {}
    for _, p in ipairs(self.panels or {}) do prev[p.classId] = p end
    self.buttons = {}
    self.panels = {}
    for i, classId in ipairs(CLASS_ORDER) do
        local info = self.cardRegistry:getClassInfo(classId)
        if info then
            local panel = {
                classId = classId, info = info,
                cards = self:_starterCards(classId),
                shake = prev[classId] and prev[classId].shake or 0,
                hover = prev[classId] and prev[classId].hover or 0,
                medallion = lay.medallions[i],
            }
            self:_refreshUnlock(panel)
            panel.btn = invisible(lay.medallions[i], function() self:focusClass(classId) end)
            table.insert(self.panels, panel)
            self.buttons[classId] = panel.btn
        else
            print("[ClassSelection] AVISO: getClassInfo sem dados para " .. classId)
        end
    end
    if not self.focus or not self:_panelOf(self.focus) then
        self.focus = self:_defaultFocus()
    end

    self.buttons.start = invisible(lay.start, function() self:selectClass(self.focus) end)
    self.buttons.details = invisible(lay.details, function() self:toggleDetails() end)
    self.buttons.sealPrev = invisible(lay.sealPrev, function() self:changeSeal(-1) end)
    self.buttons.sealNext = invisible(lay.sealNext, function() self:changeSeal(1) end)
    self.buttons.back = invisible(lay.back, function() self:goBackToMenu() end)
    self:_clampSeal()
    self:_syncButtons()

    if not self._localeListenerWired then
        self._localeListenerWired = true
        I18n.onLocaleChanged(function() self:createClassButtons() end)
    end
end

-- Botões que dependem do estado (classe bloqueada não tem COMEÇAR nem
-- DETALHES; sem selo liberado o seletor some).
function ClassSelectionScreen:_syncButtons()
    local p = self:_panelOf(self.focus)
    local open = p and p.unlocked
    if self.buttons.start then self.buttons.start:setVisible(open and true or false) end
    if self.buttons.details then self.buttons.details:setVisible(open and true or false) end
    local sealOn = self:_sealCap() > 0
    if self.buttons.sealPrev then self.buttons.sealPrev:setVisible(sealOn) end
    if self.buttons.sealNext then self.buttons.sealNext:setVisible(sealOn) end
    if self.buttons.back then
        -- área clicável = o texto do link (a fonte só existe no draw)
        local f = FontManager.getFont(self.layout.bodyFont)
        self.buttons.back.width = math.min(f:getWidth(self:_backLabel()) + 12,
            self.layout.seal.x - self.layout.back.x - 8)
    end
end

function ClassSelectionScreen:_backLabel()
    return "< " .. I18n.t("class_select.back")
end

function ClassSelectionScreen:_defaultFocus()
    if self.selectedClass and UnlockSystem.isClassUnlocked(self.selectedClass) then
        return self.selectedClass
    end
    for _, id in ipairs(CLASS_ORDER) do
        if UnlockSystem.isClassUnlocked(id) then return id end
    end
    return CLASS_ORDER[1]
end

function ClassSelectionScreen:updatePositions() self:createClassButtons() end
function ClassSelectionScreen:resize() self:createClassButtons() end

-- ===== Selos do Grimório =====
function ClassSelectionScreen:_sealCap()
    local cap = 0
    for _, classId in ipairs(CLASS_ORDER) do
        if UnlockSystem.isClassUnlocked(classId) then
            cap = math.max(cap, UnlockSystem.getMaxSeal(classId))
        end
    end
    return cap
end

function ClassSelectionScreen:_clampSeal()
    self.seal = math.max(0, math.min(self.seal or 0, self:_sealCap()))
    if self.buttons.sealPrev then self.buttons.sealPrev:setEnabled(self.seal > 0) end
    if self.buttons.sealNext then self.buttons.sealNext:setEnabled(self.seal < self:_sealCap()) end
end

function ClassSelectionScreen:changeSeal(delta)
    if self._locked then return end
    local before = self.seal
    self.seal = (self.seal or 0) + delta
    self:_clampSeal()
    if self.seal ~= before then
        Sfx.play("cardSelect", { pitch = 0.9 + self.seal * 0.03 })
        self._sealTip = 2.5
    else
        Sfx.play("error", { volume = 0.5 })
    end
end

function ClassSelectionScreen:sealFor(classId)
    return math.min(self.seal or 0, UnlockSystem.getMaxSeal(classId))
end

-- ===== Foco / detalhes =====
function ClassSelectionScreen:focusClass(classId)
    if self._locked or not self:_panelOf(classId) then return end
    if classId == self.focus then return end
    self.focus = classId
    self._flash, self._fade = 1, 0
    local p = self:_panelOf(classId)
    if p and not p.unlocked then self.pageMode = "summary" end
    if self._heroBox and p and p.unlocked then ClassHeroFx.burst(classId, self._heroBox) end
    Sfx.play("cardSelect", { pitch = p and p.unlocked and 1.0 or 0.8 })
    self:_syncButtons()
end

function ClassSelectionScreen:cycleFocus(delta)
    local idx = 1
    for i, id in ipairs(CLASS_ORDER) do if id == self.focus then idx = i end end
    self:focusClass(CLASS_ORDER[(idx - 1 + delta) % #CLASS_ORDER + 1])
end

function ClassSelectionScreen:toggleDetails()
    if self._locked then return end
    local p = self:_panelOf(self.focus)
    if not (p and p.unlocked) then return end
    self.pageMode = (self.pageMode == "details") and "summary" or "details"
    self._fade = 0
    Sfx.play("collectionFlip", { volume = 0.6 })
end

function ClassSelectionScreen:keypressed(key)
    if key == "escape" or key == "backspace" then
        self:goBackToMenu()
    elseif key == "a" then
        self:cycleFocus(-1)
    elseif key == "d" then
        self:cycleFocus(1)
    elseif key == "tab" then
        self:toggleDetails()
    end
end

function ClassSelectionScreen:_panelOf(classId)
    for _, p in ipairs(self.panels) do
        if p.classId == classId then return p end
    end
end

-- Retorna true se a escolha foi aceita (classe liberada).
function ClassSelectionScreen:selectClass(classId)
    if self._locked then return false end
    classId = classId or self.focus
    local panel = self:_panelOf(classId)

    -- BLOQUEADA: nega com som + tremor; nunca inicia run.
    if not UnlockSystem.isClassUnlocked(classId) then
        if panel then panel.shake = 1 end
        if classId ~= self.focus then self:focusClass(classId) end
        Sfx.play("error", { volume = 0.7 })
        return false
    end

    if classId ~= self.focus then self:focusClass(classId) end
    self.selectedClass = classId

    local function confirm()
        if self.onClassSelected then
            self.onClassSelected(classId, self:sealFor(classId))
        else
            Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
        end
    end
    -- O MOMENTO da escolha: emblema acende, anel, faíscas, som; a
    -- confirmação vem 0.45s depois (fila própria e não-bloqueante).
    local EM = _G.EventManager
    if EM then
        self._locked = true
        self._pick, self._flash = 1, 1
        local b = self._heroBox
        if b then
            for i = 1, 18 do
                local a = (i / 18) * math.pi * 2 + math.random() * 0.3
                table.insert(self._sparks, {
                    x = b.cx, y = b.cy,
                    vx = math.cos(a) * (90 + math.random() * 140),
                    vy = math.sin(a) * (90 + math.random() * 140) - 40,
                    t = 0, life = 0.5 + math.random() * 0.3,
                })
            end
        end
        Sfx.play("comboTrigger", { volume = 0.8 })
        EM.parallel(0.45, function()
            self._locked = false
            confirm()
        end, "class_select")
    else
        confirm()
    end
    return true
end

function ClassSelectionScreen:goBackToMenu()
    if self._locked then return end
    if self.onBackToMenu then self.onBackToMenu() end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    self._locked = false
    self.pageMode = "summary"
    self.focus = nil
    ClassHeroFx.reset()
    if _G.EventManager then _G.EventManager.clear("class_select") end
    self:updatePositions()
end

function ClassSelectionScreen:hide()
    self.visible = false
end

-- Caixa do emblema grande (centro, tamanho desenhado, pixel do sprite).
function ClassSelectionScreen:_heroGeometry()
    local h = self.layout.hero
    local boxH = math.floor(math.min(h.h * 0.62, h.w * 0.55))
    local cx = h.x + math.floor(h.w * 0.5)
    local cy = h.y + math.floor(h.h * 0.47)
    local id = self.focus
    local m = ClassEmblem.get(id)
    local s = ClassEmblem.scaleFor(id, boxH, h.w * 0.8)
    local cw = m and (m.right - m.left + 1) * s or boxH
    local ch = m and (m.bottom - m.top + 1) * s or boxH
    return { cx = cx, cy = cy, w = cw, h = ch, boxH = boxH, px = math.max(2, math.floor(s * 0.75)) }
end

function ClassSelectionScreen:update(dt)
    if not self.visible then return end
    for _, button in pairs(self.buttons) do button:update(dt) end

    -- backdrop vivo — parallax suavizado
    do
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local mx, my = love.mouse.getPosition()
        local tx = math.max(-1, math.min(1, (mx / W - 0.5) * 2))
        local ty = math.max(-1, math.min(1, (my / H - 0.5) * 2))
        local k = math.min(1, dt * 4)
        self._parX = (self._parX or 0) + (tx - (self._parX or 0)) * k
        self._parY = (self._parY or 0) + (ty - (self._parY or 0)) * k
    end

    -- brasas dos braseiros do salão
    self._embers = self._embers or {}
    self._emberTimer = (self._emberTimer or 0) - dt
    if self._emberTimer <= 0 and #self._embers < 8 then
        self._emberTimer = 0.35 + math.random() * 0.5
        table.insert(self._embers, {
            brazier = math.random(2), offX = (math.random() - 0.5) * 14,
            t = 0, life = 1.2 + math.random() * 1.2, sway = math.random() * math.pi * 2,
        })
    end
    for i = #self._embers, 1, -1 do
        local e = self._embers[i]
        e.t = e.t + dt
        if e.t >= e.life then table.remove(self._embers, i) end
    end

    local hovered = {}
    for _, p in ipairs(self.panels) do
        local hov = p.btn and p.btn.hover and not self._locked
        p.hover = p.hover + ((hov and 1 or 0) - p.hover) * math.min(1, dt * 10)
        p.hovered = hov
        if p.shake > 0 then p.shake = math.max(0, p.shake - dt / 0.35) end
    end
    hovered[self.focus or ""] = 0.6
    ClassEmblem.update(dt, hovered)

    self._flash = math.max(0, self._flash - dt / 0.35)
    self._fade = math.min(1, self._fade + dt / 0.25)
    self._pick = math.max(0, self._pick - dt / 0.45)
    self._sealTip = math.max(0, self._sealTip - dt)

    self._heroBox = self:_heroGeometry()
    local fp = self:_panelOf(self.focus)
    ClassHeroFx.update(dt, (fp and fp.unlocked) and self.focus or nil, self._heroBox)

    for i = #self._sparks, 1, -1 do
        local s = self._sparks[i]
        s.t = s.t + dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.vy = s.vy + 300 * dt
        if s.t >= s.life then table.remove(self._sparks, i) end
    end
end

-- ===== Texto =====

-- Parágrafo quebrado na largura, na fonte dada (sem encolher: a tela tem só
-- duas fontes). Devolve a altura usada; `maxLines` corta o excedente com "...".
local function paragraph(text, x, y, w, size, maxLines)
    local font = FontManager.getFont(size)
    local _, lines = font:getWrap(tostring(text or ""), w)
    local lh = math.ceil(font:getHeight() * 1.5)
    love.graphics.setFont(font)
    local n = math.min(#lines, maxLines or #lines)
    for i = 1, n do
        local line = lines[i]
        if i == n and #lines > n then
            local _, fitted = TextFit.fit(line .. "...", size, w, size)
            line = fitted
        end
        love.graphics.print(line, x, y + (i - 1) * lh)
    end
    return n * lh
end

local function ink(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

-- Barra de pixel em tinta (trilho + preenchimento + contorno).
local function inkBar(x, y, w, h, frac, fill, alpha)
    frac = math.max(0, math.min(1, frac or 0))
    ink(Palette.PARCHMENT_DARK, 0.35 * alpha)
    love.graphics.rectangle("fill", x, y, w, h)
    if frac > 0 then
        ink(fill, alpha)
        love.graphics.rectangle("fill", x + 1, y + 1, math.max(1, math.floor((w - 2) * frac)), h - 2)
    end
    ink(Palette.INK, alpha)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

-- ===== Desenho =====

function ClassSelectionScreen:draw()
    if not self.visible then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local lay = self.layout
    local NavCursor = require("src.ui.NavCursor")

    self:_drawLivingBackdrop(W, H)
    -- o salão recua: a cena é o emblema e a página
    love.graphics.setColor(0.02, 0.015, 0.01, 0.42)
    love.graphics.rectangle("fill", 0, 0, W, H)

    self:_drawHero()
    self:_drawChooser()
    self:_drawSealBand()
    self:_drawPage()
    self:_drawBack()

    -- alvos do foco (teclado/pad): a ordem de leitura da tela
    for _, p in ipairs(self.panels) do
        local b = p.btn
        if b then NavCursor.target(b, b.x, b.y, b.width, b.height) end
    end
    for _, key in ipairs({ "start", "details", "sealPrev", "sealNext", "back" }) do
        local b = self.buttons[key]
        if b and b.visible ~= false and not b.disabled then
            NavCursor.target(b, b.x, b.y, b.width, b.height)
        end
    end
    if self.buttons.details and self.buttons.details.visible ~= false then
        local b = self.buttons.details
        NavCursor.action("y", function() self:toggleDetails() end, b.x, b.y, b.width, b.height)
    end
    if self:_sealCap() > 0 then
        for dir, b in pairs({ [-1] = self.buttons.sealPrev, [1] = self.buttons.sealNext }) do
            NavCursor.action(dir < 0 and "lb" or "rb", function() self:changeSeal(dir) end,
                b.x, b.y, b.width, b.height)
        end
        -- âncora do narrador do tutorial (Pena): a faixa do selo
        local r = lay.seal
        require("src.systems.Tutorial").anchor("seal_band", r.x, r.y, r.w, r.h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:_drawHero()
    local b = self._heroBox or self:_heroGeometry()
    local p = self:_panelOf(self.focus)
    if not p then return end
    local col = CLASS_COLORS[p.classId] or { 1, 0.72, 0.22 }
    local shakeX = p.shake > 0 and math.floor(math.sin(p.shake * 40) * 8 * p.shake) or 0

    if p.unlocked then
        -- luz da classe atrás do objeto + chão quente
        local glow = RadialGlow.get()
        love.graphics.setBlendMode("add")
        love.graphics.setColor(col[1], col[2], col[3], 0.20 + 0.25 * self._flash)
        local r = math.max(b.w, b.h) * 0.85
        love.graphics.draw(glow, b.cx, b.cy, 0, r / 64, r / 64, 64, 64)
        love.graphics.setColor(1, 0.70, 0.32, 0.16)
        love.graphics.draw(glow, b.cx, b.cy + b.h * 0.52, 0, b.w / 64, b.w * 0.18 / 64, 64, 64)
        love.graphics.setBlendMode("alpha")
    end
    ClassHeroFx.draw(1)
    local drew = ClassEmblem.draw(p.classId, b.cx + shakeX, b.cy, b.boxH,
        { hover = 0.6, locked = not p.unlocked, flash = self._flash,
          boxW = self.layout.hero.w * 0.8 })
    if not drew then
        Palette.set(Palette.RUST)
        love.graphics.rectangle("line", b.cx - b.boxH / 2, b.cy - b.boxH / 2, b.boxH, b.boxH)
    end

    -- anel do momento da escolha
    if self._pick > 0.02 then
        local k = 1 - self._pick
        love.graphics.setLineStyle("rough")
        love.graphics.setColor(1, 0.85, 0.4, self._pick * 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", b.cx, b.cy, 40 + k * 220)
        love.graphics.setLineWidth(1)
        love.graphics.setLineStyle("smooth")
    end
    for _, s in ipairs(self._sparks) do
        love.graphics.setColor(1, 0.85, 0.4, 1 - s.t / s.life)
        love.graphics.rectangle("fill", math.floor(s.x), math.floor(s.y), 3, 3)
    end
end

-- As três classes pequenas: em foco = cor plena e marcador dourado embaixo;
-- as outras recuam (escurecidas); bloqueada = silhueta acorrentada.
function ClassSelectionScreen:_drawChooser()
    local lay = self.layout
    local c = lay.chooser
    -- traço de tinta: a "estante" onde as classes repousam
    ink(Palette.AGED_GOLD_DARK, 0.55)
    love.graphics.rectangle("fill", c.x, c.y + c.h - 6, c.w, 2)
    for _, p in ipairs(self.panels) do
        local m = p.medallion
        local focus = (p.classId == self.focus)
        local shakeX = p.shake > 0 and math.floor(math.sin(p.shake * 40) * 4 * p.shake) or 0
        local lift = math.floor(-3 * p.hover)
        local boxH = math.floor(m.h * (focus and 0.95 or 0.82))
        local k = focus and 1 or (0.62 + 0.30 * p.hover)
        ClassEmblem.draw(p.classId, m.x + m.w / 2 + shakeX, m.y + m.h / 2 + lift, boxH,
            { hover = 0, locked = not p.unlocked, boxW = m.w, tint = { k, k, k } })
        if p.hover > 0.05 and not focus then
            -- nome sob demanda: só quando o mouse/foco passa pela classe
            local f = FontManager.getFont(self.layout.bodyFont)
            local label = p.info.name or p.classId
            local lx = math.floor(m.x + m.w / 2 - f:getWidth(label) / 2)
            local ly = m.y - f:getHeight() - 6
            love.graphics.setFont(f)
            ink(Palette.INK, 0.9 * p.hover)
            for dx = -1, 1 do for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then love.graphics.print(label, lx + dx, ly + dy) end
            end end
            ink(Palette.PARCHMENT_LIGHT, p.hover)
            love.graphics.print(label, lx, ly)
        end
        if focus then
            -- marcador: losango dourado sob a classe escolhida
            local mx, my = m.x + math.floor(m.w / 2), c.y + c.h - 5
            ink(Palette.AGED_GOLD_LIGHT)
            love.graphics.polygon("fill", mx, my - 5, mx + 5, my, mx, my + 5, mx - 5, my)
            ink(Palette.INK)
            love.graphics.polygon("line", mx, my - 5, mx + 5, my, mx, my + 5, mx - 5, my)
        end
    end
end

function ClassSelectionScreen:_drawSealBand()
    local cap = self:_sealCap()
    if cap <= 0 then return end          -- nada a escolher ainda: nada na tela
    local lay = self.layout
    local r = lay.seal
    local body = lay.bodyFont
    local p = self:_panelOf(self.focus)
    local capped = p and p.unlocked and UnlockSystem.getMaxSeal(p.classId) < self.seal

    -- faixa de couro escuro com costura dourada
    love.graphics.setColor(0.07, 0.045, 0.03, 0.88)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    ink(capped and Palette.BLOOD or Palette.AGED_GOLD_DARK)
    for x = r.x + 4, r.x + r.w - 6, 6 do
        love.graphics.rectangle("fill", x, r.y + 3, 3, 1)
        love.graphics.rectangle("fill", x, r.y + r.h - 4, 3, 1)
    end
    self:_drawSealArrow(lay.sealPrev, -1, self.seal > 0)
    self:_drawSealArrow(lay.sealNext, 1, self.seal < cap)

    local inner = { x = lay.sealPrev.x + lay.sealPrev.w + 6, w = r.w - 2 * (lay.sealPrev.w + 6) }
    local icon = IconLoader.get("seal_grimoire")
    local iconS = r.h - 12
    local tx = inner.x
    if icon and icon.image then
        love.graphics.setColor(1, 1, 1, self.seal > 0 and 1 or 0.4)
        local sc = math.floor(iconS / icon.image:getWidth() * 4) / 4
        love.graphics.draw(icon.image, tx, r.y + 6, 0, sc, sc)
        tx = tx + math.floor(icon.image:getWidth() * sc) + 6
    end
    local title
    if self.seal == 0 then
        title = I18n.t("seal_ui.title")
    else
        local def = require("src.systems.RunModifiers").SEALS[self.seal]
        title = I18n.t("seal_ui.label", { n = self.seal }) .. " · " .. I18n.t("seals." .. def.id .. ".name")
    end
    ink(self.seal > 0 and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT)
    local f = FontManager.getFont(body)
    -- sem caber, o título encurta pra "Selo N" (o nome vai pra dica) — nunca "..."
    if f:getWidth(title) > inner.x + inner.w - tx then
        title = I18n.t("seal_ui.label", { n = self.seal })
    end
    TextFit.print(title, tx, r.y + math.floor((r.h - f:getHeight()) / 2),
        { size = body, minSize = body, maxW = inner.x + inner.w - tx })

    -- a REGRA do selo (e o teto da classe em foco) aparece sob demanda:
    -- mouse/foco na faixa, ou logo depois de trocar o selo
    local mx, my = love.mouse.getPosition()
    local hot = mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
    if hot or self._sealTip > 0 or capped then
        local sub
        if capped then
            sub = I18n.t("seal_ui.class_cap", { class = p.info.name, n = UnlockSystem.getMaxSeal(p.classId) })
        elseif self.seal == 0 then
            sub = I18n.t("seal_ui.none") .. ". " .. I18n.t("seal_ui.hint", { n = cap })
        else
            local def = require("src.systems.RunModifiers").SEALS[self.seal]
            sub = I18n.t("seal_ui.label", { n = self.seal }) .. " · "
                .. I18n.t("seals." .. def.id .. ".name") .. ": " .. I18n.t("seals." .. def.id .. ".desc")
            if self.seal > 1 then sub = sub .. " " .. I18n.t("seal_ui.cumulative", { n = self.seal - 1 }) end
        end
        local _, lines = f:getWrap(sub, r.w - 20)
        local lh = math.ceil(f:getHeight() * 1.5)
        local th = #lines * lh + 12
        local ty = r.y + r.h + 6          -- a faixa mora no alto: a dica desce
        love.graphics.setColor(0.07, 0.045, 0.03, 0.94)
        love.graphics.rectangle("fill", r.x, ty, r.w, th)
        ink(Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", r.x + 0.5, ty + 0.5, r.w - 1, th - 1)
        ink(capped and Palette.TOAST_DANGER or Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(f)
        for i, line in ipairs(lines) do love.graphics.print(line, r.x + 10, ty + 6 + (i - 1) * lh) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:_drawSealArrow(r, dir, enabled)
    local mx, my = love.mouse.getPosition()
    local hot = enabled and mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
    local cx, cy = math.floor(r.x + r.w / 2), math.floor(r.y + r.h / 2)
    local a = 6
    ink(enabled and (hot and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT) or Palette.AGED_GOLD_DARK,
        enabled and 1 or 0.45)
    love.graphics.polygon("fill", cx + dir * a, cy, cx - dir * a, cy - a - 2, cx - dir * a, cy + a + 2)
end

-- A FOLHA: essencial (resumo) | detalhes | bloqueada.
function ClassSelectionScreen:_drawPage()
    local lay = self.layout
    local pg = lay.page
    local p = self:_panelOf(self.focus)
    if not p then return end
    GrimoirePage.draw(pg.x, pg.y, pg.w, pg.h, 7)

    local r = lay.pageInner
    local big, body = lay.bigFont, lay.bodyFont
    local fb = FontManager.getFont(body)
    local lh = math.ceil(fb:getHeight() * 1.5)
    local a = 0.25 + 0.75 * self._fade
    local y = r.y

    -- cabeçalho do capítulo
    ink(Palette.PARCHMENT_DARK, a)
    TextFit.print(I18n.t("class_select.title"), r.x, y, { size = body, minSize = body, maxW = r.w })
    y = y + lh + math.floor(lh * 0.8)

    -- NOME + traço de pincel na cor da classe
    local col = CLASS_COLORS[p.classId] or { 1, 0.72, 0.22 }
    local name = TextCase.upper(p.info.name or p.classId)
    ink(Palette.INK, p.unlocked and a or 0.55 * a)
    local nw, nh = TextFit.print(name, r.x, y, { size = big, minSize = big - 6, maxW = r.w })
    y = y + nh + 6
    love.graphics.setColor(col[1], col[2], col[3], (p.unlocked and 0.95 or 0.4) * a)
    local strokeW = math.max(48, math.floor(nw * 0.85))
    love.graphics.rectangle("fill", r.x, y, strokeW, 3)
    love.graphics.rectangle("fill", r.x + 3, y + 3, strokeW - 10, 1)
    love.graphics.rectangle("fill", r.x + strokeW, y + 1, 4, 1)
    y = y + 3 + math.floor(lh * 1.0)

    if not p.unlocked then
        self:_drawPlate(p, r, a * 0.5)
        self:_drawLockedPage(p, r, y, a)
    elseif self.pageMode == "details" then
        self:_drawDetailsPage(p, r, y, a)
    else
        self:_drawSummaryPage(p, r, y, a)
    end

    if p.unlocked then
        self:_drawDetailsTab()
        self:_drawStartRibbon()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:_drawSummaryPage(p, r, y, a)
    local body = self.layout.bodyFont
    local fb = FontManager.getFont(body)
    local lh = math.ceil(fb:getHeight() * 1.5)
    self:_drawPlate(p, r, a)
    -- identidade (uma ideia, no máximo 3 linhas)
    ink(Palette.INK, a)
    y = y + paragraph(p.info.description, r.x, y, r.w, body, 3) + lh

    -- passiva: nome em sangue, a regra numa linha curta
    ink(Palette.BLOOD, a)
    TextFit.print(p.info.passiveName or "", r.x, y, { size = body, minSize = body, maxW = r.w })
    y = y + lh
    ink(Palette.INK, a)
    local short = I18n.t("classes." .. p.classId .. ".passive_short", nil, p.info.passiveDesc)
    y = y + paragraph(short, r.x, y, r.w, body, 3) + lh

    -- vida · mana · baralho, em ícones
    local items = {
        { icon = "heart", n = Config.Game.PLAYER_MAX_HEALTH },
        { icon = "crystal", n = Config.Game.PLAYER_MAX_MANA },
        { icon = "scroll", n = #self.cardRegistry:getStarterDeckForClass(p.classId) },
    }
    local iconPx = math.floor(fb:getHeight() * 1.8)
    local sy = y
    local x = r.x
    love.graphics.setFont(fb)
    for _, it in ipairs(items) do
        local icon = IconLoader.get(it.icon)
        if icon and icon.size then
            love.graphics.setColor(1, 1, 1, a)
            icon.draw(x, sy, iconPx / icon.size.h)
        end
        ink(Palette.INK, a)
        local txt = tostring(it.n)
        love.graphics.print(txt, x + iconPx + 4, sy + math.floor((iconPx - fb:getHeight()) / 2))
        x = x + iconPx + 4 + fb:getWidth(txt) + math.floor(iconPx * 0.9)
    end
end

-- GRAVURA: o objeto da classe desenhado em tinta, apagado, no pé da folha
-- (as pranchas dos grimórios). Ocupa o papel que sobra sem dizer nada.
function ClassSelectionScreen:_drawPlate(p, r, a)
    local m = ClassEmblem.get(p.classId)
    local img = ClassEmblem.engraving(p.classId)
    if not (m and img) then return end
    local cw, ch = m.right - m.left + 1, m.bottom - m.top + 1
    local boxH = r.h * 0.50
    local s = math.max(1, math.floor(math.min(boxH / ch, r.w * 0.7 / cw)))
    local x = math.floor(r.x + r.w / 2 - (m.left + cw / 2) * s)
    local y = math.floor(r.y + r.h - 8 - (m.bottom + 1) * s)
    ink(Palette.PARCHMENT_DARK, 0.36 * a)
    love.graphics.draw(img, x, y, 0, s, s)
end

function ClassSelectionScreen:_drawDetailsPage(p, r, y, a)
    local body = self.layout.bodyFont
    local fb = FontManager.getFont(body)
    local lh = math.ceil(fb:getHeight() * 1.5)
    ink(Palette.BLOOD, a)
    TextFit.print(p.info.passiveName or "", r.x, y, { size = body, minSize = body, maxW = r.w })
    y = y + lh
    ink(Palette.INK, a)
    y = y + paragraph(p.info.passiveDesc, r.x, y, r.w, body, 5) + math.floor(lh * 0.8)

    -- cartas iniciais (as de verdade, animadas)
    ink(Palette.PARCHMENT_DARK, a)
    TextFit.print(I18n.t("class_select.starter_label"), r.x, y, { size = body, minSize = body, maxW = r.w })
    y = y + lh
    local masteryH = lh * 3
    local availH = r.y + r.h - masteryH - y
    local n = #p.cards
    local s = math.min(availH / Layout.CARD_H_SRC, (r.w - (n - 1) * 10) / (n * Layout.CARD_W_SRC))
    s = math.max(0.4, math.floor(s * 4) / 4)
    local cx = r.x
    for _, inst in ipairs(p.cards) do
        local img = (CardFrame.liveImage and CardFrame.liveImage(inst)) or inst.image
        if img then
            love.graphics.setColor(0, 0, 0, 0.25 * a)
            love.graphics.draw(img, cx + 3, y + 4, 0, s, s)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, cx, y, 0, s, s)
        end
        cx = cx + math.floor(Layout.CARD_W_SRC * s) + 10
    end

    -- maestria + recorde, no pé da folha
    local my = r.y + r.h - masteryH
    local m = p.mastery or { level = 0, maxLevel = 0, xp = 0, xpToNext = 0 }
    local isMax = (m.maxLevel or 0) > 0 and (m.level or 0) >= m.maxLevel
    ink(Palette.INK, a)
    local label = isMax and I18n.t("class_select.mastery_max") or I18n.t("class_select.mastery", { level = m.level or 0 })
    local lw = TextFit.print(label, r.x, my, { size = body, minSize = body, maxW = r.w * 0.55 })
    local frac = isMax and 1 or ((m.xpToNext or 0) > 0 and (m.xp or 0) / m.xpToNext or 0)
    local bx = r.x + lw + 10
    inkBar(bx, my + 2, math.max(40, r.x + r.w - bx), fb:getHeight() - 4, frac, Palette.AGED_GOLD, a)
    local rec = UnlockSystem.getClassRecord(p.classId)
    if rec and ((rec.bestScore or 0) > 0 or UnlockSystem.getSealWon(p.classId) >= 0) then
        ink(Palette.PARCHMENT_DARK, a)
        paragraph(I18n.t("class_select.record", { score = rec.bestScore or 0,
            seal = math.max(0, UnlockSystem.getSealWon(p.classId)), floor = rec.bestEndless or 0 }),
            r.x, my + lh, r.w, body, 2)
    end
end

function ClassSelectionScreen:_drawLockedPage(p, r, y, a)
    local body = self.layout.bodyFont
    local fb = FontManager.getFont(body)
    local lh = math.ceil(fb:getHeight() * 1.5)
    ink(Palette.BLOOD, a)
    TextFit.print(I18n.t("class_select.locked"), r.x, y, { size = body, minSize = body, maxW = r.w })
    y = y + lh * 2
    local u = p.unlock or {}
    ink(Palette.INK, a)
    y = y + paragraph(I18n.t(u.reqKey or "unlock.class.default", u.vars or {}), r.x, y, r.w, body, 4) + lh
    local goal = math.max(1, u.goal or 1)
    local prog = math.max(0, math.min(goal, u.progress or 0))
    local txt = ("%d/%d"):format(prog, goal)
    local barW = math.floor(r.w * 0.6)
    inkBar(r.x, y + 2, barW, fb:getHeight() - 2, prog / goal, Palette.RUST, a)
    ink(Palette.INK, a)
    love.graphics.setFont(fb)
    love.graphics.print(txt, r.x + barW + 10, y)
end

-- Marcador DETALHES / RESUMO: fita presa na borda esquerda da folha.
function ClassSelectionScreen:_drawDetailsTab()
    local t = self.layout.details
    local b = self.buttons.details
    local hot = b and b.hover
    local open = self.pageMode == "details"
    local base = open and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
    local x = t.x - (hot and 4 or 0)
    ink(Palette.INK, 0.6)
    love.graphics.rectangle("fill", x + 3, t.y + 3, t.w, t.h)
    ink(hot and Palette.AGED_GOLD_LIGHT or base)
    -- corpo da fita com ponta em V à esquerda (rabo de andorinha)
    love.graphics.rectangle("fill", x + 8, t.y, t.w - 8, t.h)
    love.graphics.polygon("fill", x + 8, t.y, x, t.y, x + 8, t.y + 14)
    love.graphics.polygon("fill", x + 8, t.y + t.h, x, t.y + t.h, x + 8, t.y + t.h - 14)
    love.graphics.rectangle("fill", x + 4, t.y + 7, 4, t.h - 14)
    ink(Palette.INK)
    love.graphics.rectangle("fill", x + 8, t.y, 1, t.h)
    local label = I18n.t(open and "class_select.summary" or "class_select.details")
    local size = self.layout.bodyFont
    local f = FontManager.getFont(size)
    if f:getWidth(label) > t.h - 16 then size = 8; f = FontManager.getFont(size) end
    love.graphics.setFont(f)
    local tw = f:getWidth(label)
    ink(Palette.INK)
    love.graphics.print(label, x + math.floor(t.w / 2) - math.floor(f:getHeight() / 2) + 3,
        t.y + math.floor((t.h + tw) / 2), -math.pi / 2)
end

-- Fita COMEÇAR pendurada no pé da folha (a ação principal da tela).
function ClassSelectionScreen:_drawStartRibbon()
    local r = self.layout.start
    local b = self.buttons.start
    local hot = b and b.hover
    local y = r.y - (hot and 2 or 0)
    local notch = 12
    ink(Palette.INK, 0.55)
    love.graphics.rectangle("fill", r.x + 4, y + 5, r.w, r.h)
    -- pontas em rabo de andorinha (mais escuras: a fita dobra por trás)
    ink(Palette.BLOOD_DARK)
    love.graphics.polygon("fill", r.x - notch, y + 6, r.x + 10, y + 6, r.x + 10, y + r.h + 4,
        r.x - notch, y + r.h + 4, r.x - notch + 8, y + r.h / 2 + 5)
    love.graphics.polygon("fill", r.x + r.w + notch, y + 6, r.x + r.w - 10, y + 6,
        r.x + r.w - 10, y + r.h + 4, r.x + r.w + notch, y + r.h + 4, r.x + r.w + notch - 8, y + r.h / 2 + 5)
    ink(hot and Palette.lighten(Palette.BLOOD, 0.15) or Palette.BLOOD)
    love.graphics.rectangle("fill", r.x, y, r.w, r.h)
    ink(Palette.AGED_GOLD_LIGHT, hot and 1 or 0.75)
    love.graphics.rectangle("fill", r.x, y + 3, r.w, 1)
    love.graphics.rectangle("fill", r.x, y + r.h - 4, r.w, 1)
    -- brilho que corre a fita de tempos em tempos (convite, não alarme)
    local t = love.timer.getTime() % 3.2
    if t < 0.6 and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
        local gx = r.x + math.floor((t / 0.6) * (r.w + 20)) - 10
        love.graphics.setColor(1, 0.92, 0.7, 0.35)
        love.graphics.rectangle("fill", math.max(r.x, gx), y + 5, math.min(6, r.x + r.w - gx), r.h - 10)
    end
    local label = TextCase.upper(I18n.t("class_select.start"))
    local size = self.layout.bodyFont
    local f = FontManager.getFont(size)
    ink(Palette.INK, 0.8)
    TextFit.print(label, r.x + 8 + 1, y + math.floor((r.h - f:getHeight()) / 2) + 1,
        { size = size, minSize = size - 2, maxW = r.w - 16, align = "center" })
    ink(Palette.PARCHMENT_LIGHT)
    TextFit.print(label, r.x + 8, y + math.floor((r.h - f:getHeight()) / 2),
        { size = size, minSize = size - 2, maxW = r.w - 16, align = "center" })
end

function ClassSelectionScreen:_drawBack()
    local b = self.buttons.back
    if not b then return end
    local f = FontManager.getFont(self.layout.bodyFont)
    love.graphics.setFont(f)
    ink(b.hover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT, b.hover and 1 or 0.8)
    love.graphics.print(self:_backLabel(), b.x + 4, b.y + math.floor((b.height - f:getHeight()) / 2))
end

-- ===== backdrop vivo =====
-- Âncoras dos 2 BRASEIROS na imagem do salão (coords relativas ao PNG
-- 400×256, v2 "limpo" Jul/2026 — ajuste se regenerar).
local BRAZIER_ANCHORS = {
    { xr = 0.380, yr = 0.735, phase = 0.0 },
    { xr = 0.618, yr = 0.735, phase = 2.9 },
}

function ClassSelectionScreen:_drawLivingBackdrop(width, height)
    local t = love.timer.getTime()
    local ok, tf = SceneBackground.drawParallax("classSelection", width, height,
        0.15, (self._parX or 0) * -12, (self._parY or 0) * -7, 1.07)
    if not ok then
        if not SceneBackground.draw("menu", width, height, 0.55) then
            Theme.Utils.drawVerticalGradient(0, 0, width, height, {
                { 0.1, 0.1, 0.2, 1 }, { 0.05, 0.05, 0.1, 1 } })
        end
        return
    end
    self._sceneTf = tf
    local glow = RadialGlow.get()
    love.graphics.setBlendMode("add")
    for _, a in ipairs(BRAZIER_ANCHORS) do
        local x = tf.ox + a.xr * tf.dw
        local y = tf.oy + a.yr * tf.dh
        local flick = 0.65 + 0.35 * love.math.noise(t * 6.0, a.phase)
        local r = tf.dw * 0.060 * (0.9 + 0.16 * love.math.noise(t * 3.1, a.phase + 5))
        love.graphics.setColor(1, 0.48, 0.14, 0.28 * flick)
        love.graphics.draw(glow, x, y, 0, r * 2 / 128, r * 1.5 / 128, 64, 64)
        love.graphics.setColor(1, 0.78, 0.38, 0.30 * flick)
        love.graphics.draw(glow, x, y, 0, r / 128, r * 0.8 / 128, 64, 64)
    end
    love.graphics.setBlendMode("alpha")
    local warm = 0.025 + 0.025 * love.math.noise(t * 2.1, 3.3)
    love.graphics.setColor(1, 0.62, 0.28, warm)
    love.graphics.rectangle("fill", 0, 0, width, height)
    for _, e in ipairs(self._embers or {}) do
        local anch = BRAZIER_ANCHORS[e.brazier]
        local k = e.t / e.life
        local x = tf.ox + anch.xr * tf.dw + e.offX + math.sin(e.t * 3 + e.sway) * 7 * k
        local y = tf.oy + anch.yr * tf.dh - k * 85
        love.graphics.setColor(1, 0.85 - 0.45 * k, 0.30 - 0.20 * k, (1 - k) * 0.85)
        local s = k < 0.15 and 2 or 1
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:mousepressed(x, y, button)
    if not self.visible or self._locked then return end
    for _, btn in pairs(self.buttons) do btn:mousepressed(x, y, button) end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible or self._locked then return end
    for _, btn in pairs(self.buttons) do btn:mousereleased(x, y, button) end
end

return ClassSelectionScreen
