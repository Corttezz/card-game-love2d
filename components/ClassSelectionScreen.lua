-- components/ClassSelectionScreen.lua
-- "O Salão dos Emblemas" (v3, Out/2026). Cada classe é representada pelo
-- seu OBJETO icônico — espada cravada no escudo, orbe arcano, adaga com
-- veneno e sangue — em vez de um herói chibi (o dono achou que o boneco
-- "abre margem para críticas"; ver memory/class_emblems.md). O emblema é
-- o protagonista do painel, com idle procedural (src/ui/ClassEmblem.lua).
--
-- Padrão StS charSelect + polish Balatro:
--   • preview de VIDA, BARALHO inicial (as cartas reais) e da PASSIVA;
--   • classe LIBERADA mostra o nível de MAESTRIA (UnlockSystem);
--   • classe BLOQUEADA: emblema em silhueta acorrentado, requisito escrito
--     e barra de progresso — clicar NÃO inicia run (som de negação + tremor).
-- Layout = ZONAS (src/ui/ClassSelectLayout.lua, com validate()).

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local CardFrame = require("src.ui.CardFrame")
local IconLoader = require("src.ui.IconLoader")
local RadialGlow = require("src.ui.RadialGlow")
local HintBar = require("src.ui.HintBar")
local TextFit = require("src.ui.TextFit")
local ClassEmblem = require("src.ui.ClassEmblem")
local Layout = require("src.ui.ClassSelectLayout")
local UnlockSystem = require("src.systems.UnlockSystem")
local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local Sfx = require("src.systems.Sfx")

-- Cor de identidade por classe (linha da placa de nome + aura).
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
    instance.panels = {}          -- {classId, rect, bandas, btn, info, cards, lift, fx, shake, unlock, mastery}
    instance.cardRegistry = CardRegistry:new()
    instance.selectedClass = nil
    instance._starterCache = {}   -- classId -> {cardInstance, ...}
    instance._locked = false      -- input travado durante o FX de escolha
    instance._sparks = {}         -- faíscas do momento da escolha
    instance.seal = 0             -- Selo do Grimório escolhido (0 = sem selo)

    -- Callbacks
    instance.onClassSelected = nil
    instance.onBackToMenu = nil

    instance:createClassButtons()

    return instance
end

-- Instâncias visuais das cartas iniciais (CardFrame real, cacheado).
function ClassSelectionScreen:_starterCards(classId)
    if self._starterCache[classId] then return self._starterCache[classId] end
    local out = {}
    local ids = self.cardRegistry:getStarterDeckForClass(classId)
    for _, id in ipairs(ids) do
        local cd = CardDatabase:getCard(id)
        if cd then
            local ok, inst = pcall(function()
                return CardDatabase:createCardInstance(cd)
            end)
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

-- Estado de liberação/maestria (relido a cada show/resize — o perfil muda
-- entre uma visita e outra).
function ClassSelectionScreen:_refreshUnlock(panel)
    panel.unlock = UnlockSystem.getClassUnlockInfo(panel.classId)
    panel.unlocked = UnlockSystem.isClassUnlocked(panel.classId)
    panel.mastery = panel.unlocked and UnlockSystem.getClassMastery(panel.classId) or nil
end

function ClassSelectionScreen:createClassButtons()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local lay = Layout.compute(sw, sh, #CLASS_ORDER)
    self.layout = lay

    -- preserva animações em andamento (lift/fx/shake) entre rebuilds
    local prev = {}
    for _, p in ipairs(self.panels or {}) do prev[p.classId] = p end

    self.buttons = {}
    self.panels = {}

    for i, classId in ipairs(CLASS_ORDER) do
        local info = self.cardRegistry:getClassInfo(classId)
        if info then
            local r = lay.panels[i]
            local old = prev[classId]
            local panel = {
                classId = classId,
                info = info,
                rect = r,
                cards = self:_starterCards(classId),
                lift = old and old.lift or 0,
                fx = old and old.fx or 0,
                shake = old and old.shake or 0,
            }
            self:_refreshUnlock(panel)
            -- área clicável = o painel inteiro (emblema incluso)
            panel.btn = Button:new(r.x, r.y, r.w, r.h, "",
                function() self:selectClass(classId) end)
            panel.btn:setVariant("invisible")
            table.insert(self.panels, panel)
            self.buttons[classId] = panel.btn
        else
            print("[ClassSelection] AVISO: getClassInfo sem dados para " .. classId)
        end
    end

    -- SELO DO GRIMÓRIO: setas da banda S (o texto é desenhado à parte).
    local sp, sn = lay.sealPrev, lay.sealNext
    -- Setas desenhadas à mão (_drawSealArrow): o Button "tv" num quadrado
    -- de 40px não cabia nem um "<" e virava "...".
    self.buttons.sealPrev = Button:new(sp.x, sp.y, sp.w, sp.h, "",
        function() self:changeSeal(-1) end)
    self.buttons.sealPrev:setVariant("invisible")
    self.buttons.sealNext = Button:new(sn.x, sn.y, sn.w, sn.h, "",
        function() self:changeSeal(1) end)
    self.buttons.sealNext:setVariant("invisible")
    self:_clampSeal()

    local b = lay.back
    self.buttons.back = Button:new(b.x, b.y, b.w, b.h,
        I18n.t("class_select.back"),
        function() self:goBackToMenu() end,
        Theme.Colors.WARNING, 12)
    self.buttons.back:setVariant("tv")

    -- Recria botões ao trocar idioma (textos mudam)
    if not self._localeListenerWired then
        self._localeListenerWired = true
        I18n.onLocaleChanged(function()
            self:createClassButtons()
        end)
    end
end

-- Layout inteiro depende de sw/sh: recriar é o caminho simples e barato
-- (padrão resize_pattern.md). main.lua chama updatePositions no love.resize.
function ClassSelectionScreen:updatePositions()
    self:createClassButtons()
end

function ClassSelectionScreen:resize()
    self:createClassButtons()
end

-- ===== Selos do Grimório =====
-- Maior selo que ALGUMA classe liberada pode usar (o seletor é um só; ao
-- escolher a classe o selo é limitado ao teto DELA — ver selectClass).
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
    else
        Sfx.play("error", { volume = 0.5 })
    end
end

-- Selo efetivo pra uma classe: o escolhido, limitado ao teto dela.
function ClassSelectionScreen:sealFor(classId)
    return math.min(self.seal or 0, UnlockSystem.getMaxSeal(classId))
end

function ClassSelectionScreen:keypressed(key)
    if key == "escape" or key == "backspace" then
        self:goBackToMenu()
    elseif key == "left" or key == "a" or key == "q" then
        self:changeSeal(-1)
    elseif key == "right" or key == "d" or key == "e" then
        self:changeSeal(1)
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
    local panel = self:_panelOf(classId)

    -- BLOQUEADA: nega com som + tremor; nunca inicia run.
    if not UnlockSystem.isClassUnlocked(classId) then
        if panel then panel.shake = 1 end
        Sfx.play("error", { volume = 0.7 })
        return false
    end

    self.selectedClass = classId

    -- O MOMENTO da escolha: flash + anel + faíscas + som, e a confirmação
    -- vem 0.45s depois (EventManager). Sem EM, confirma direto.
    local EM = _G.EventManager
    if panel and EM then
        self._locked = true
        panel.fx = 1
        local e = panel.rect.emblem
        local cx, cy = e.x + e.w / 2, e.y + e.h / 2
        for i = 1, 16 do
            local a = (i / 16) * math.pi * 2 + math.random() * 0.3
            table.insert(self._sparks, {
                x = cx, y = cy,
                vx = math.cos(a) * (90 + math.random() * 120),
                vy = math.sin(a) * (90 + math.random() * 120) - 40,
                t = 0, life = 0.5 + math.random() * 0.3,
            })
        end
        Sfx.play("comboTrigger", { volume = 0.8 })
        if panel.btn and panel.btn.juice_up then panel.btn:juice_up(0.3, 0.1) end
        -- fila PRÓPRIA e não-bloqueante: um evento travado na fila "base"
        -- (sobra de outra tela) não pode segurar o início da run
        EM.parallel(0.45, function()
            self._locked = false
            if self.onClassSelected then
                self.onClassSelected(classId, self:sealFor(classId))
            else
                Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
            end
        end, "class_select")
    else
        if self.onClassSelected then
            self.onClassSelected(classId, self:sealFor(classId))
        else
            Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
        end
    end
    return true
end

function ClassSelectionScreen:goBackToMenu()
    if self._locked then return end
    if self.onBackToMenu then
        self.onBackToMenu()
    end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    self._locked = false
    -- fila própria limpa a cada visita (memory/eventmanager_queues.md)
    if _G.EventManager then _G.EventManager.clear("class_select") end
    self:updatePositions()
end

function ClassSelectionScreen:hide()
    self.visible = false
end

function ClassSelectionScreen:update(dt)
    if not self.visible then return end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end

    -- backdrop vivo (mesma linguagem do menu) — parallax suavizado
    do
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local mx, my = love.mouse.getPosition()
        local tx = math.max(-1, math.min(1, (mx / W - 0.5) * 2))
        local ty = math.max(-1, math.min(1, (my / H - 0.5) * 2))
        local k = math.min(1, dt * 4)
        self._parX = (self._parX or 0) + (tx - (self._parX or 0)) * k
        self._parY = (self._parY or 0) + (ty - (self._parY or 0)) * k
    end

    -- brasas subindo dos braseiros
    self._embers = self._embers or {}
    self._emberTimer = (self._emberTimer or 0) - dt
    if self._emberTimer <= 0 and #self._embers < 8 then
        self._emberTimer = 0.35 + math.random() * 0.5
        table.insert(self._embers, {
            brazier = math.random(2),
            offX = (math.random() - 0.5) * 14,
            t = 0,
            life = 1.2 + math.random() * 1.2,
            sway = math.random() * math.pi * 2,
        })
    end
    for i = #self._embers, 1, -1 do
        local e = self._embers[i]
        e.t = e.t + dt
        if e.t >= e.life then table.remove(self._embers, i) end
    end

    local hovered = {}
    for _, p in ipairs(self.panels) do
        -- lift suavizado (hover = painel acende; bloqueada não "levanta")
        local hov = p.btn and p.btn.hover and not self._locked
        local target = (hov and p.unlocked) and 1 or 0
        p.lift = p.lift + (target - p.lift) * math.min(1, dt * 10)
        p.hovered = hov
        hovered[p.classId] = p.lift
        if p.fx > 0 then p.fx = math.max(0, p.fx - dt / 0.45) end
        if p.shake > 0 then p.shake = math.max(0, p.shake - dt / 0.35) end
    end
    ClassEmblem.update(dt, hovered)

    -- faíscas da escolha
    for i = #self._sparks, 1, -1 do
        local s = self._sparks[i]
        s.t = s.t + dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.vy = s.vy + 300 * dt
        if s.t >= s.life then table.remove(self._sparks, i) end
    end
end

-- ===== Helpers de texto =====

-- Texto multi-linha que CABE na caixa: desce a fonte até caber; no mínimo,
-- corta as linhas excedentes com "...". Retorna nada; desenha.
local function printWrapped(text, r, size, minSize, align)
    text = tostring(text or "")
    local s = size
    local font, lines
    while true do
        font = FontManager.getFont(s)
        local _, wrapped = font:getWrap(text, r.w)
        lines = wrapped
        if #lines * math.ceil(font:getHeight() * 1.2) <= r.h or s <= minSize then break end
        s = s - 1
    end
    local lh = math.ceil(font:getHeight() * 1.2)   -- a fonte pixel cola as linhas
    local maxLines = math.max(1, math.floor(r.h / lh))
    love.graphics.setFont(font)
    local blockH = math.min(#lines, maxLines) * lh
    local y = r.y + math.floor((r.h - blockH) / 2)
    for i = 1, math.min(#lines, maxLines) do
        local line = lines[i]
        if i == maxLines and #lines > maxLines then
            local _, fitted = TextFit.fit(line .. "...", s, r.w, s)
            line = fitted
        end
        local lw = font:getWidth(line)
        local x = r.x
        if align == "center" then x = r.x + math.floor((r.w - lw) / 2) end
        love.graphics.print(line, x, y)
        y = y + lh
    end
end

-- Barra de progresso pixel (trilho ink + preenchimento + contorno).
local function drawBar(x, y, w, h, frac, fillColor)
    frac = math.max(0, math.min(1, frac or 0))
    love.graphics.setColor(0.04, 0.03, 0.02, 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    if frac > 0 then
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x + 1, y + 1, math.max(1, math.floor((w - 2) * frac)), h - 2)
    end
    Palette.set(Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

-- ===== Bandas do painel =====

function ClassSelectionScreen:_drawStatus(p, r, ts)
    if p.unlocked then
        -- MAESTRIA: "MAESTRIA N" + pips (níveis) + barra de XP do nível atual
        local m = p.mastery or { level = 0, maxLevel = 0, xp = 0, xpToNext = 0 }
        local isMax = (m.maxLevel or 0) > 0 and (m.level or 0) >= m.maxLevel
        local label = isMax and I18n.t("class_select.mastery_max")
            or I18n.t("class_select.mastery", { level = m.level or 0 })
        Palette.set(Palette.AGED_GOLD_LIGHT)
        TextFit.print(label, r.x, r.y, { size = math.floor(10 * ts), maxW = r.w,
            align = "center", minSize = 8, shadow = { 0, 0, 0, 0.8 } })
        local pipN = math.max(0, m.maxLevel or 0)
        local pip = math.floor(6 * ts)
        local gap = math.floor(3 * ts)
        local by = r.y + math.floor(14 * ts)
        if pipN > 0 then
            local totalW = pipN * pip + (pipN - 1) * gap
            local x = r.x + math.floor((r.w - totalW) / 2)
            for i = 1, pipN do
                if i <= (m.level or 0) then
                    Palette.set(Palette.AGED_GOLD)
                    love.graphics.rectangle("fill", x, by, pip, pip)
                else
                    love.graphics.setColor(0.04, 0.03, 0.02, 0.85)
                    love.graphics.rectangle("fill", x, by, pip, pip)
                end
                Palette.set(Palette.AGED_GOLD_DARK)
                love.graphics.rectangle("line", x + 0.5, by + 0.5, pip - 1, pip - 1)
                x = x + pip + gap
            end
        end
        local barW = math.floor(r.w * 0.6)
        local barY = by + pip + math.floor(4 * ts)
        local frac = isMax and 1 or ((m.xpToNext or 0) > 0 and (m.xp or 0) / m.xpToNext or 0)
        drawBar(r.x + math.floor((r.w - barW) / 2), barY, barW, math.max(4, math.floor(5 * ts)),
            frac, Palette.AGED_GOLD)
    else
        -- BLOQUEADA: requisito + barra de progresso com "p/g"
        local u = p.unlock or {}
        local req = I18n.t(u.reqKey or "unlock.class.default", u.vars or {})
        love.graphics.setColor(0.86, 0.55, 0.30, 1)  -- ferrugem clara: aviso, não erro
        -- o requisito é A informação do painel bloqueado: nunca truncar.
        -- Não coube numa linha? quebra em duas (fonte menor) e a barra desce.
        local reqSize = math.floor(10 * ts)
        local _, fitted = TextFit.fit(req, reqSize, r.w, 8)
        local textH
        if fitted == req then
            TextFit.print(req, r.x, r.y, { size = reqSize, maxW = r.w,
                align = "center", minSize = 8, shadow = { 0, 0, 0, 0.8 } })
            textH = math.floor(18 * ts)
        else
            local f8 = FontManager.getFont(8)
            local lh = math.ceil(f8:getHeight() * 1.2)  -- mesmo passo do printWrapped
            printWrapped(req, { x = r.x, y = r.y, w = r.w, h = lh * 2 }, 8, 8, "center")
            textH = lh * 2 + 2
        end
        local goal = math.max(1, u.goal or 1)
        local prog = math.max(0, math.min(goal, u.progress or 0))
        local countTxt = ("%d/%d"):format(prog, goal)
        local cf = FontManager.getFont(math.floor(9 * ts))
        local barH = math.max(6, math.floor(8 * ts))
        local barW = math.floor(r.w * 0.62)
        local totalW = barW + 6 + cf:getWidth(countTxt)
        local bx = r.x + math.floor((r.w - totalW) / 2)
        local by = r.y + textH
        drawBar(bx, by, barW, barH, prog / goal, { 0.72, 0.40, 0.20, 1 })
        love.graphics.setFont(cf)
        Palette.set(Palette.PARCHMENT)
        love.graphics.print(countTxt, bx + barW + 6, by + math.floor((barH - cf:getHeight()) / 2))
    end
end

function ClassSelectionScreen:_drawStats(p, r, ts)
    -- VIDA ♥ 60  ·  BARALHO 2 cartas
    local hp = Config.Game.PLAYER_MAX_HEALTH
    local nCards = #self.cardRegistry:getStarterDeckForClass(p.classId)
    local font = FontManager.getFont(math.floor(10 * ts))
    local iconPx = math.floor(14 * ts)
    local items = {
        { icon = "heart",  text = I18n.t("class_select.hp_label") .. " " .. hp },
        { icon = "scroll", text = I18n.t("class_select.deck_count", { n = nCards }) },
    }
    local sep = math.floor(14 * ts)
    local widths, total = {}, 0
    for i, it in ipairs(items) do
        widths[i] = iconPx + 4 + font:getWidth(it.text)
        total = total + widths[i]
    end
    total = total + sep * (#items - 1)
    -- se não couber (idioma longo), cai pra uma fonte menor
    if total > r.w then
        font = FontManager.getFont(math.max(7, math.floor(8 * ts)))
        total = 0
        for i, it in ipairs(items) do
            widths[i] = iconPx + 4 + font:getWidth(it.text)
            total = total + widths[i]
        end
        total = total + sep * (#items - 1)
    end
    local x = r.x + math.floor((r.w - total) / 2)
    local cy = r.y + math.floor(r.h / 2)
    love.graphics.setFont(font)
    for i, it in ipairs(items) do
        local icon = IconLoader.get(it.icon)
        if icon and icon.size then
            icon.draw(x, cy - iconPx / 2, iconPx / icon.size.h)
        end
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.print(it.text, x + iconPx + 4, cy - math.floor(font:getHeight() / 2))
        x = x + widths[i] + sep
    end
end

function ClassSelectionScreen:_drawPassive(p, r, ts, hover)
    if not p.info.passiveName then return end
    love.graphics.setColor(1, 0.72, 0.22, 0.10 + 0.10 * hover)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 0.72, 0.22, 0.35)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    love.graphics.setColor(1, 0.72, 0.22, 1)
    local titleH = math.floor(16 * ts)
    TextFit.print(I18n.t("class_select.passive_label") .. " — " .. TextCase.upper(p.info.passiveName),
        r.x + 4, r.y + 4, { size = math.floor(10 * ts), maxW = r.w - 8, align = "center", minSize = 7 })
    Palette.set(Palette.PARCHMENT)
    printWrapped(p.info.passiveDesc or "",
        { x = r.x + 8, y = r.y + 4 + titleH, w = r.w - 16, h = r.h - titleH - 8 },
        math.floor(9 * ts), 7, "center")
end

function ClassSelectionScreen:_drawCards(p, r, ts, hover)
    local lay = self.layout
    local labelH = math.floor(Layout.CARD_LABEL_H * ts)
    Palette.set(Palette.PARCHMENT_DARK)
    TextFit.print(I18n.t("class_select.starter_label"), r.x, r.y,
        { size = math.floor(8 * ts), maxW = r.w, align = "center", minSize = 7 })
    local s = lay.cardScale
    local cw = Layout.CARD_W * s
    local gap = 12
    local totalCw = #p.cards * cw + math.max(0, #p.cards - 1) * gap
    local x = math.floor(r.x + (r.w - totalCw) / 2)
    local y = r.y + labelH
    for _, inst in ipairs(p.cards) do
        if inst.image then
            -- hover na CLASSE anima os ícones dos starters (icons_anim);
            -- idle = canvas estático (regra do dono, Jul/2026)
            local img = inst.image
            if hover > 0.35 then
                local live = CardFrame.liveImage(inst)
                if live then img = live end
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y, 0, s, s)
        end
        x = x + math.floor(cw + gap)
    end
end

-- Painel de classe v3: emblema protagonista + bandas (ClassSelectLayout).
function ClassSelectionScreen:_drawClassPanel(p)
    local R = p.rect
    local ts = self.layout.ts
    local hover = p.lift
    local col = CLASS_COLORS[p.classId] or { 1, 0.72, 0.22 }
    local shakeX = p.shake > 0 and math.floor(math.sin(p.shake * 40) * 6 * p.shake) or 0
    local liftY = -math.floor(6 * hover)

    love.graphics.push()
    love.graphics.translate(shakeX, liftY)

    -- BACKING translúcido: ink + contorno (dourado liberado / ferrugem bloqueado)
    love.graphics.setColor(0.05, 0.04, 0.03, p.unlocked and 0.62 or 0.72)
    love.graphics.rectangle("fill", R.x, R.y, R.w, R.h)
    if p.unlocked then
        love.graphics.setColor(1, 0.72, 0.22, 0.25 + 0.65 * hover)
    else
        local a = p.hovered and 0.75 or 0.40
        love.graphics.setColor(0.62, 0.34, 0.18, a)
    end
    love.graphics.rectangle("line", R.x + 0.5, R.y + 0.5, R.w - 1, R.h - 1)
    if hover > 0.05 then
        love.graphics.setColor(1, 0.72, 0.22, 0.25 * hover)
        love.graphics.rectangle("line", R.x - 2.5, R.y - 2.5, R.w + 5, R.h + 5)
    end

    -- EMBLEMA (protagonista)
    local e = R.emblem
    if p.unlocked then
        -- chão de luz quente sob o emblema
        local glow = RadialGlow.get()
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.72, 0.30, 0.10 + 0.18 * hover + 0.4 * p.fx)
        love.graphics.draw(glow, e.x + e.w / 2, e.y + e.h * 0.92, 0, e.w / 128 * 1.1, 0.35, 64, 64)
        love.graphics.setColor(col[1], col[2], col[3], 0.10 + 0.16 * hover)
        love.graphics.draw(glow, e.x + e.w / 2, e.y + e.h * 0.92, 0, e.w / 128 * 0.7, 0.25, 64, 64)
        love.graphics.setBlendMode("alpha")
    end
    local drew = ClassEmblem.draw(p.classId, e.x + e.w / 2, e.y + e.h / 2, e.h - 8,
        { hover = hover, locked = not p.unlocked, flash = p.fx, boxW = e.w - 8 })
    if not drew then
        -- asset ausente (já avisado no console): placeholder VISÍVEL, não vazio
        Palette.set(Palette.RUST)
        love.graphics.rectangle("line", e.x + 0.5, e.y + 0.5, e.w - 1, e.h - 1)
    end
    if not p.unlocked then
        -- etiqueta BLOQUEADA ancorada no pé do emblema
        local f = FontManager.getFont(math.floor(10 * ts))
        local txt = I18n.t("class_select.locked")
        local tw = math.min(e.w - 8, f:getWidth(txt) + 16)
        local th = f:getHeight() + 6
        local tx = e.x + math.floor((e.w - tw) / 2)
        local ty = e.y + e.h - th
        love.graphics.setColor(0.08, 0.05, 0.04, 0.92)
        love.graphics.rectangle("fill", tx, ty, tw, th)
        love.graphics.setColor(0.62, 0.34, 0.18, 1)
        love.graphics.rectangle("line", tx + 0.5, ty + 0.5, tw - 1, th - 1)
        love.graphics.setColor(0.90, 0.62, 0.38, 1)
        TextFit.print(txt, tx + 4, ty + 3, { size = math.floor(10 * ts), maxW = tw - 8, align = "center", minSize = 7 })
    end

    -- NOME + linha de cor da classe
    local name = TextCase.upper(p.info.name or p.classId)
    if p.unlocked then
        Palette.set(hover > 0.5 and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    else
        Palette.set(Palette.PARCHMENT_DARK)
    end
    local nr = R.name
    TextFit.print(name, nr.x, nr.y, { size = math.floor(17 * ts), maxW = nr.w,
        align = "center", minSize = 12, shadow = { 0, 0, 0, 0.8 } })
    love.graphics.setColor(col[1], col[2], col[3], p.unlocked and 0.9 or 0.35)
    local lineW = math.floor((64 + 30 * hover) * ts)
    love.graphics.rectangle("fill", nr.x + math.floor((nr.w - lineW) / 2), nr.y + nr.h - 2, lineW, 2)

    -- STATUS (maestria | requisito)
    self:_drawStatus(p, R.status, ts)

    -- DESCRIÇÃO
    Palette.set(Palette.PARCHMENT)
    printWrapped(p.info.description or "", R.desc, math.floor(9 * ts), 7, "center")

    -- STATS, PASSIVA, CARTAS
    self:_drawStats(p, R.stats, ts)
    self:_drawPassive(p, R.passive, ts, hover)
    self:_drawCards(p, R.cards, ts, hover)

    -- bloqueada: véu sobre a parte de "conteúdo" (dá pra espiar, não usar)
    if not p.unlocked then
        local top = R.desc.y - 2
        love.graphics.setColor(0.03, 0.02, 0.02, 0.45)
        love.graphics.rectangle("fill", R.x + 1, top, R.w - 2, R.cards.y + R.cards.h - top + 2)
    end

    -- ANEL do momento da escolha (expande e some)
    if p.fx > 0.02 then
        local k = 1 - p.fx
        love.graphics.setColor(1, 0.85, 0.4, p.fx * 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", e.x + e.w / 2, e.y + e.h / 2, 30 + k * 160)
        love.graphics.setLineWidth(1)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:draw()
    if not self.visible then return end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    self:_drawLivingBackdrop(width, height)
    self:drawTitle()

    for _, p in ipairs(self.panels) do
        self:_drawClassPanel(p)
        -- o painel é um Button invisível que não se desenha: registra o
        -- alvo do foco de teclado/pad (NavCursor) aqui
        local b = p.btn
        if b and b.visible ~= false and not b.disabled then
            require("src.ui.NavCursor").target(b, b.x, b.y, b.width, b.height)
        end
    end

    -- faíscas da escolha (por cima dos painéis)
    for _, s in ipairs(self._sparks) do
        local a = 1 - s.t / s.life
        love.graphics.setColor(1, 0.85, 0.4, a)
        love.graphics.rectangle("fill", math.floor(s.x), math.floor(s.y), 2, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)

    self:_drawSealBand()
    if self.buttons.back then self.buttons.back:draw() end

    -- hint: sobre classe bloqueada, explica por que o clique não vai
    local hint = I18n.t("class_select.description")
    for _, p in ipairs(self.panels) do
        if p.hovered and not p.unlocked then
            hint = I18n.t("class_select.locked_hint")
        end
    end
    HintBar.draw(hint)
end

-- Banda S: [<]  (selo)  SELO 3 · Mercado Caro  [>]
--                      regra do selo / teto da classe em foco
function ClassSelectionScreen:_drawSealBand()
    local r = self.layout and self.layout.seal
    if not r then return end
    local ts = self.layout.ts
    local cap = self:_sealCap()
    local inner = { x = self.layout.sealPrev.x + self.layout.sealPrev.w + 8, y = r.y,
        w = r.w - 2 * (self.layout.sealPrev.w + 8), h = r.h }
    love.graphics.setColor(0.06, 0.04, 0.03, 0.72)
    love.graphics.rectangle("fill", inner.x, inner.y, inner.w, inner.h, 5, 5)
    Palette.set(self.seal > 0 and Palette.BLOOD or Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("line", inner.x, inner.y, inner.w, inner.h, 5, 5)

    local icon = IconLoader.get("seal_grimoire")
    local iconS = math.floor(inner.h - 8)
    local tx = inner.x + 8
    if icon and icon.image then
        love.graphics.setColor(1, 1, 1, self.seal > 0 and 1 or 0.45)
        local sc = iconS / icon.image:getWidth()
        love.graphics.draw(icon.image, tx, inner.y + 4, 0, sc, sc)
    end
    tx = tx + iconS + 8
    local textW = inner.x + inner.w - 8 - tx

    local title, sub
    if cap == 0 then
        title = I18n.t("seal_ui.title")
        sub = I18n.t("seal_ui.locked_all")
    elseif self.seal == 0 then
        title = I18n.t("seal_ui.none")
        sub = I18n.t("seal_ui.hint", { n = cap })
    else
        local def = require("src.systems.RunModifiers").SEALS[self.seal]
        title = I18n.t("seal_ui.label", { n = self.seal }) .. " · "
            .. I18n.t("seals." .. def.id .. ".name")
        sub = I18n.t("seals." .. def.id .. ".desc")
        if self.seal > 1 then
            sub = sub .. " " .. I18n.t("seal_ui.cumulative", { n = self.seal - 1 })
        end
    end
    -- Classe em foco: o teto dela (se for MENOR que o selo escolhido) ou os
    -- RECORDES dela — selo vencido, andar do endless e pontuação.
    for _, p in ipairs(self.panels) do
        if p.hovered and p.unlocked then
            local name = p.info and p.info.name or p.classId
            if UnlockSystem.getMaxSeal(p.classId) < self.seal then
                sub = I18n.t("seal_ui.class_cap", { class = name,
                    n = UnlockSystem.getMaxSeal(p.classId) })
            else
                local rec = UnlockSystem.getClassRecord(p.classId)
                sub = I18n.t("seal_ui.record", { class = name,
                    seal = math.max(0, UnlockSystem.getSealWon(p.classId)),
                    floor = rec.bestEndless, score = rec.bestScore })
            end
        end
    end
    local half = math.floor(inner.h / 2)
    Palette.set(self.seal > 0 and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    printWrapped(title, { x = tx, y = inner.y + 2, w = textW, h = half }, math.floor(12 * ts), 8, "left")
    Palette.set(Palette.PARCHMENT)
    printWrapped(sub, { x = tx, y = inner.y + half, w = textW, h = inner.h - half - 2 },
        math.floor(9 * ts), 6, "left")
    love.graphics.setColor(1, 1, 1, 1)
    self:_drawSealArrow(self.layout.sealPrev, -1, self.seal > 0)
    self:_drawSealArrow(self.layout.sealNext, 1, self.seal < cap)
end

-- Seta do seletor: placa escura + triângulo; apagada quando não há pra onde ir.
function ClassSelectionScreen:_drawSealArrow(r, dir, enabled)
    local mx, my = love.mouse.getPosition()
    local hot = enabled and mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
    love.graphics.setColor(0.06, 0.04, 0.03, hot and 0.95 or 0.72)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Palette.set(hot and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK, enabled and 1 or 0.4)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local a = math.floor(math.min(r.w, r.h) * 0.22)
    Palette.set(enabled and (hot and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
        or Palette.AGED_GOLD_DARK, enabled and 1 or 0.45)
    love.graphics.polygon("fill", cx + dir * a, cy, cx - dir * a, cy - a * 1.2, cx - dir * a, cy + a * 1.2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== backdrop vivo =====
-- Âncoras dos 2 BRASEIROS na imagem do salão minimalista (coords
-- relativas ao PNG 400×256, v2 "limpo" Jul/2026 — ajuste se regenerar).
local BRAZIER_ANCHORS = {
    { xr = 0.380, yr = 0.735, phase = 0.0 },
    { xr = 0.618, yr = 0.735, phase = 2.9 },
}

function ClassSelectionScreen:_drawLivingBackdrop(width, height)
    local t = love.timer.getTime()

    -- CAMADA 1: salão com parallax (folga de zoom, offset clampado)
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

    -- CAMADA 2: fogo dos braseiros (glow radial com flicker de noise)
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

    -- CAMADA 3: respiração quente global (sala à luz de fogo)
    local warm = 0.025 + 0.025 * love.math.noise(t * 2.1, 3.3)
    love.graphics.setColor(1, 0.62, 0.28, warm)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- CAMADA 4: brasas dos braseiros (esfriam amarelo→laranja)
    for _, e in ipairs(self._embers or {}) do
        local anch = BRAZIER_ANCHORS[e.brazier]
        local k = e.t / e.life
        local x = tf.ox + anch.xr * tf.dw + e.offX
            + math.sin(e.t * 3 + e.sway) * 7 * k
        local y = tf.oy + anch.yr * tf.dh - k * 85
        love.graphics.setColor(1, 0.85 - 0.45 * k, 0.30 - 0.20 * k, (1 - k) * 0.85)
        local s = k < 0.15 and 2 or 1
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:drawTitle()
    local r = self.layout.title
    local title = I18n.t("class_select.title")
    local padX, padY = 20, 8
    local size = math.floor(24 * self.layout.ts)
    local titleFont = FontManager.getFont(size)
    -- a faixa do título tem altura reservada: a fonte cede, a banda não
    while size > 12 and titleFont:getHeight() + padY * 2 > r.h do
        size = size - 1
        titleFont = FontManager.getFont(size)
    end
    love.graphics.setFont(titleFont)
    local tw = titleFont:getWidth(title)
    local titleX = math.floor(r.x + (r.w - tw) / 2)
    local bh = titleFont:getHeight() + padY * 2
    local by = r.y + math.floor((r.h - bh) / 2)
    local titleY = by + padY

    local bw = tw + padX * 2
    local bx = titleX - padX
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, Palette.PANEL_OUTLINE_INNER)

    Palette.set(Palette.INK)
    love.graphics.print(title, titleX + 1, titleY + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)
end

function ClassSelectionScreen:mousepressed(x, y, button)
    if not self.visible or self._locked then return end
    for _, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    if self._locked then return end
    for _, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return ClassSelectionScreen
