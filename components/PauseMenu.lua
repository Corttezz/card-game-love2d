-- components/PauseMenu.lua
-- Menu de pausa (engrenagem da TopBar / ESC) — padrão Slay the Spire +
-- estrutura do create_UIBox_options do Balatro (seed visível, atalhos, ação
-- primária no topo).
--
-- v3 (Out/2026 — "seguir o padrão de hoje"):
--   • ZONAS fixas (memory/ui_layout_invariants.md §1), de cima pra baixo:
--       CABEÇALHO  título
--       RESUMO     classe · jornada · seed / vida · ouro · baralho (só c/ run)
--       ATALHOS    Baralho [D] · Coringas [J] · Roteiro [M]  (só c/ run)
--       AÇÕES      Continuar (PRIMÁRIA) · Configurações · Salvar e sair ·
--                  Abandonar (perigo, confirmação em 2 etapas)
--       RODAPÉ     dica de controles
--     Quando falta altura quem CEDE é o conteúdo (descrições somem, depois os
--     atalhos, depois o resumo vira uma linha) — nunca a posição das zonas.
--     `validate()` checa a não-sobreposição e roda no test_pause_menu.
--   • Navegação por teclado/gamepad (src/ui/MenuKit.lua): setas/WASD, Enter,
--     ESC; foco começa em Continuar; na confirmação de abandono o foco vai
--     pro "Não" (o default seguro).
--   • Entrada animada (painel cai no lugar + véu), som de hover/clique.
--
-- Overlay modal global: main.lua instancia, injeta callbacks via
-- show(game, callbacks) e roteia update/draw/input. _G.togglePauseMenu abre/
-- fecha de qualquer lugar. Registrado no InputFocus como "pause".

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local Button      = require("components.Button")
local I18n        = require("src.i18n.I18n")
local Sfx         = require("src.systems.Sfx")
local UiPanel     = require("src.ui.UiPanel")
local TextFit     = require("src.ui.TextFit")
local MenuKit     = require("src.ui.MenuKit")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

-- Métricas (px). Alturas de texto são MEDIDAS em cima destas.
local PAD          = 22     -- respiro interno do painel
local TITLE_H      = 56     -- zona do título (inclui o filete)
local ROW_PAD_X    = 14
local ROW_PAD_Y    = 10
local TITLE_TO_DESC = 6
local ROW_GAP      = 8
local ZONE_GAP     = 14
local SHORTCUT_H   = 30
local FOOTER_H     = 30
local INFO_CELL_H  = 26     -- rótulo 8 + 4 + valor 12 (+ folga)
local INFO_PAD     = 10
local CHEVRON_W    = 22     -- reserva à direita da row pro ">" de ação

local DANGER_TEXT  = Palette.lighten(Palette.BLOOD, 0.62)

function PauseMenu:new()
    local instance = setmetatable({}, PauseMenu)
    instance.visible = false
    instance.game = nil
    instance.callbacks = {}
    instance.rows = {}            -- ações: {x,y,w,h,btn,key,title,...}
    instance.shortcuts = {}       -- {x,y,w,h,btn,key}
    instance.confirmButtons = {}  -- Sim/Não do abandono
    instance.confirmingAbandon = false
    instance.lines = {}           -- navegação: lista de linhas, cada uma com itens
    instance.focusLine, instance.focusItem = 1, 1
    instance._t = 0
    instance._panel = nil
    instance._zones = nil
    instance._mode = "full"
    return instance
end

function PauseMenu:isVisible() return self.visible end

-- opts.quiet: reabertura vinda das Configurações (sem o "menuOpen" duplicado)
function PauseMenu:show(game, callbacks, opts)
    self.visible = true
    self.game = game or self.game
    self.callbacks = callbacks or self.callbacks or {}
    self.confirmingAbandon = false
    self._pressed = nil
    self._t = (opts and opts.quiet) and MenuKit.ENTER_DUR or 0
    self:rebuild()
    self:_focusKey("resume")
    if not (opts and opts.quiet) then Sfx.play("menuOpen") end
end

function PauseMenu:hide()
    self.visible = false
    self.confirmingAbandon = false
    self.rows = {}
    self.shortcuts = {}
    self.confirmButtons = {}
    self.lines = {}
    Sfx.play("menuClose")
end

function PauseMenu:toggle(game, callbacks)
    if self.visible then self:hide() else self:show(game, callbacks) end
end

local function hasRun(game)
    return game and game.runManager and game.runManager.hasActiveRun
        and game.runManager:hasActiveRun() and true or false
end

-- ===================================================================
-- RESUMO DA RUN — dados puros (testável sem desenhar)
-- ===================================================================
-- Retorna lista de células {label, value} na ordem de leitura (2 linhas × 3).
function PauseMenu:runSummary()
    local game = self.game
    if not hasRun(game) then return nil end
    local rm = game.runManager
    local run = rm.currentRun
    local MapManager = require("src.systems.MapManager")

    local className = run.classId
        and I18n.t("classes." .. run.classId .. ".name", nil, run.className)
        or (run.className or "?")
    local journey
    if run.endlessMode then
        journey = I18n.t("top_bar.endless")
    else
        journey = I18n.t("pause.info_journey_value", {
            act = run.actNumber or 1,
            floor = run.floorInAct or 1,
            total = MapManager.FLOORS_PER_ACT,
        })
    end
    local p = game.player
    local hp = p and (math.floor(p.health or 0) .. "/" .. math.floor(p.maxHealth or 0)) or "-"
    local gold = game.economySystem and game.economySystem.currentGold or 0
    local deckN = run.currentDeck and #run.currentDeck or 0

    return {
        { label = I18n.t("pause.info_class"),   value = className },
        { label = I18n.t("pause.info_journey"), value = journey },
        { label = I18n.t("pause.info_seed"),    value = tostring(run.runSeed or "-") },
        { label = I18n.t("pause.info_hp"),      value = hp },
        { label = I18n.t("pause.info_gold"),    value = tostring(math.floor(gold)) },
        { label = I18n.t("pause.info_deck"),
          value = I18n.t("top_bar.deck_cards", { n = deckN }) },
    }
end

-- ===================================================================
-- LAYOUT
-- ===================================================================
local function actionDefs(self, runActive)
    local defs = {
        { key = "resume", primary = true,
          title = I18n.t("pause.resume"), desc = I18n.t("pause.resume_desc"),
          action = function() self:hide() end },
        { key = "settings",
          title = I18n.t("pause.settings"), desc = I18n.t("pause.settings_desc"),
          action = function()
              self:hide()
              if self.callbacks.onOpenSettings then self.callbacks.onOpenSettings() end
          end },
        { key = "save_quit",
          title = runActive and I18n.t("pause.save_quit") or I18n.t("pause.quit_norun"),
          desc = runActive and I18n.t("pause.save_quit_desc") or I18n.t("pause.quit_norun_desc"),
          action = function()
              self:hide()
              if self.callbacks.onSaveQuit then self.callbacks.onSaveQuit() end
          end },
    }
    if runActive then
        table.insert(defs, { key = "abandon", danger = true,
            title = I18n.t("pause.abandon"), desc = I18n.t("pause.abandon_desc"),
            action = function() self:armAbandon() end })
    end
    return defs
end

local function shortcutDefs(self)
    local function open(cb)
        return function()
            self:hide()
            if cb then cb() end
        end
    end
    return {
        { key = "deck",    hotkey = "d", label = I18n.t("pause.shortcut_deck"),
          action = open(self.callbacks.onOpenDeck) },
        { key = "jokers",  hotkey = "j", label = I18n.t("pause.shortcut_jokers"),
          action = open(self.callbacks.onOpenJokers) },
        { key = "journal", hotkey = "m", label = I18n.t("pause.shortcut_journal"),
          action = open(self.callbacks.onOpenJournal) },
    }
end

-- Mede a altura de cada ação no modo dado.
local function measureActions(defs, innerW, withDesc, confirming)
    local descFont = FontManager.getFont(9)
    local descLH = math.floor(descFont:getHeight() * 1.35)
    local out, total = {}, 0
    for _, def in ipairs(defs) do
        local m = { def = def }
        if def.key == "abandon" and confirming then
            local qFont = FontManager.getFont(12)
            local _, qLines = qFont:getWrap(I18n.t("pause.abandon_confirm"), innerW)
            m.confirming, m.qFont = true, qFont
            m.h = ROW_PAD_Y + #qLines * math.floor(qFont:getHeight() * 1.3) + 8 + 28 + ROW_PAD_Y
        else
            local size = def.primary and 16 or 13
            local titleFont = (TextFit.fit(def.title, size, innerW, 9))
            m.titleFont = titleFont
            m.descLines = {}
            if withDesc then
                local _, lines = descFont:getWrap(def.desc, innerW)
                m.descLines = lines
            end
            m.descFont, m.descLH = descFont, descLH
            m.h = ROW_PAD_Y + titleFont:getHeight()
                + (#m.descLines > 0 and (TITLE_TO_DESC + #m.descLines * descLH) or 0)
                + ROW_PAD_Y
            if def.primary then m.h = m.h + 4 end
        end
        out[#out + 1] = m
        total = total + m.h
    end
    return out, total + ROW_GAP * math.max(0, #out - 1)
end

-- Monta zonas, rows, atalhos e linhas de navegação. Idempotente: roda em
-- show/resize/confirmação/troca de idioma.
function PauseMenu:rebuild()
    self.rows, self.shortcuts, self.confirmButtons = {}, {}, {}

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.max(280, math.min(540, sw - 32))
    local innerW = pw - PAD * 2
    local rowInnerW = innerW - ROW_PAD_X * 2 - CHEVRON_W   -- texto nunca encosta no ">"
    local runActive = hasRun(self.game)
    local defs = actionDefs(self, runActive)
    local maxH = sh - 24

    -- Modos em ordem de preferência: quem cede é o CONTEÚDO.
    local modes = {
        { name = "full",    desc = true,  shortcuts = true,  info = "grid" },
        { name = "nodesc",  desc = false, shortcuts = true,  info = "grid" },
        { name = "compact", desc = false, shortcuts = false, info = "line" },
    }
    local chosen, measured, actionsH, infoH
    for _, mode in ipairs(modes) do
        measured, actionsH = measureActions(defs, rowInnerW, mode.desc, self.confirmingAbandon)
        if runActive then
            infoH = (mode.info == "grid") and (INFO_PAD * 2 + INFO_CELL_H * 2 + 8) or 22
        else
            infoH = 22   -- "nenhuma jornada" numa linha
        end
        local scH = (runActive and mode.shortcuts) and (SHORTCUT_H + ZONE_GAP) or 0
        local total = PAD + TITLE_H + infoH + ZONE_GAP + scH + actionsH + ZONE_GAP + FOOTER_H
        chosen = mode
        chosen.total = total
        if total <= maxH then break end
    end
    self._mode = chosen.name

    local ph = math.min(chosen.total, maxH)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    self._panel = { x = px, y = py, w = pw, h = ph }

    local x = px + PAD
    local y = py + PAD
    local zones = {}
    zones.title = { x = x, y = y, w = innerW, h = TITLE_H }
    y = y + TITLE_H
    zones.info = { x = x, y = y, w = innerW, h = infoH, mode = runActive and chosen.info or "none" }
    y = y + infoH + ZONE_GAP

    if runActive and chosen.shortcuts then
        zones.shortcuts = { x = x, y = y, w = innerW, h = SHORTCUT_H }
        local gap = 8
        local defsS = shortcutDefs(self)
        local bw = math.floor((innerW - gap * (#defsS - 1)) / #defsS)
        for i, d in ipairs(defsS) do
            local bx = x + (i - 1) * (bw + gap)
            local btn = Button:new(bx, y, bw, SHORTCUT_H, d.label, d.action, nil, 10)
            self.shortcuts[i] = { x = bx, y = y, w = bw, h = SHORTCUT_H,
                key = d.key, hotkey = d.hotkey, btn = btn, action = d.action }
        end
        y = y + SHORTCUT_H + ZONE_GAP
    end

    zones.actions = { x = x, y = y, w = innerW, h = actionsH }
    for _, m in ipairs(measured) do
        local def = m.def
        local row = {
            x = x, y = y, w = innerW, h = m.h,
            key = def.key, title = def.title, desc = def.desc,
            primary = def.primary, danger = def.danger,
            titleFont = m.titleFont, descLines = m.descLines,
            descFont = m.descFont, descLH = m.descLH,
            confirming = m.confirming, qFont = m.qFont,
            action = def.action,
        }
        if m.confirming then
            local half = math.floor((innerW - ROW_PAD_X * 2 - 8) / 2)
            local by = y + m.h - ROW_PAD_Y - 28
            local yes = Button:new(x + ROW_PAD_X, by, half, 28, I18n.t("pause.abandon_yes"),
                function()
                    self:hide()
                    if self.callbacks.onAbandon then self.callbacks.onAbandon() end
                end, nil, 9)
            yes:setColorScheme("red")
            local no = Button:new(x + ROW_PAD_X + half + 8, by, half, 28, I18n.t("pause.abandon_no"),
                function() self:disarmAbandon() end, nil, 9)
            self.confirmButtons = { yes, no }
        else
            -- hitbox invisível (o visual é desenhado pela própria row);
            -- Button cuida do cursor-mão e do portão do InputFocus.
            row.btn = Button:new(x, y, innerW, m.h, "", def.action)
            row.btn:setVariant("invisible")
        end
        table.insert(self.rows, row)
        y = y + m.h + ROW_GAP
    end
    zones.footer = { x = x, y = py + ph - FOOTER_H, w = innerW, h = FOOTER_H - 6 }
    self._zones = zones

    -- Linhas de navegação (ordem visual, de cima pra baixo).
    self.lines = {}
    if #self.shortcuts > 0 then
        local items = {}
        for _, s in ipairs(self.shortcuts) do
            items[#items + 1] = { key = s.key, rect = s, action = s.action }
        end
        self.lines[#self.lines + 1] = items
    end
    for _, row in ipairs(self.rows) do
        if row.confirming then
            local yes, no = self.confirmButtons[1], self.confirmButtons[2]
            self.lines[#self.lines + 1] = {
                { key = "abandon_yes", rect = { x = yes.x, y = yes.y, w = yes.width, h = yes.height },
                  action = yes.onClick },
                { key = "abandon_no", rect = { x = no.x, y = no.y, w = no.width, h = no.height },
                  action = no.onClick },
            }
        else
            self.lines[#self.lines + 1] = { { key = row.key, rect = row, action = row.action } }
        end
    end
    self:_clampFocus()
end

function PauseMenu:resize()
    if not self.visible then return end
    local key = self:focusedKey()
    self:rebuild()
    if key then self:_focusKey(key) end
end

-- Checagem geométrica das zonas (usada pelo test_pause_menu). Lista de
-- problemas; vazia = layout válido.
function PauseMenu:validate()
    local problems = {}
    local p, z = self._panel, self._zones
    if not p or not z then return { "sem layout" } end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then
        problems[#problems + 1] = ("painel fora da janela (%d,%d %dx%d)"):format(p.x, p.y, p.w, p.h)
    end
    local function inside(r, name)
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w or r.y + r.h > p.y + p.h then
            problems[#problems + 1] = name .. " vaza do painel"
        end
    end
    local order = { "title", "info", "shortcuts", "actions", "footer" }
    local prev
    for _, name in ipairs(order) do
        local r = z[name]
        if r then
            inside(r, "zona " .. name)
            if prev and r.y < prev.r.y + prev.r.h then
                problems[#problems + 1] = ("zona %s invade %s"):format(name, prev.name)
            end
            prev = { name = name, r = r }
        end
    end
    local all = {}
    for i, r in ipairs(self.rows) do all[#all + 1] = { "row " .. i, r } end
    for i, s in ipairs(self.shortcuts) do all[#all + 1] = { "atalho " .. i, s } end
    for i = 1, #all do
        inside(all[i][2], all[i][1])
        for j = i + 1, #all do
            if MenuKit.overlaps(all[i][2], all[j][2]) then
                problems[#problems + 1] = all[i][1] .. " sobrepoe " .. all[j][1]
            end
        end
    end
    for _, b in ipairs(self.confirmButtons) do
        local r = { x = b.x, y = b.y, w = b.width, h = b.height }
        inside(r, "botao de confirmacao")
    end
    return problems
end

-- ===================================================================
-- FOCO / NAVEGAÇÃO
-- ===================================================================
function PauseMenu:_clampFocus()
    local n = #self.lines
    if n == 0 then self.focusLine, self.focusItem = 1, 1 return end
    self.focusLine = math.max(1, math.min(n, self.focusLine or 1))
    local items = self.lines[self.focusLine]
    self.focusItem = math.max(1, math.min(#items, self.focusItem or 1))
end

function PauseMenu:focusedKey()
    local items = self.lines[self.focusLine]
    local it = items and items[self.focusItem]
    return it and it.key or nil
end

function PauseMenu:_focusKey(key)
    for li, items in ipairs(self.lines) do
        for ii, it in ipairs(items) do
            if it.key == key then
                self.focusLine, self.focusItem = li, ii
                return true
            end
        end
    end
    return false
end

function PauseMenu:_moveFocus(dl, di)
    local before = self:focusedKey()
    if dl ~= 0 and #self.lines > 0 then
        -- linha seguinte com wrap (menu curto: dar a volta é o esperado)
        self.focusLine = ((self.focusLine - 1 + dl) % #self.lines) + 1
    end
    if di ~= 0 then
        local items = self.lines[self.focusLine]
        self.focusItem = math.max(1, math.min(#items, self.focusItem + di))
    end
    self:_clampFocus()
    if self:focusedKey() ~= before then
        Sfx.playWithVariation("menuHover", 1.0, 0.12)
    end
end

function PauseMenu:_activateFocused()
    local items = self.lines[self.focusLine]
    local it = items and items[self.focusItem]
    if it and it.action then
        Sfx.playWithVariation("buttonClick", 1.0, 0.08)
        it.action()
        return true
    end
    return false
end

function PauseMenu:armAbandon()
    self.confirmingAbandon = true
    self:rebuild()
    self:_focusKey("abandon_no")   -- default SEGURO
end

function PauseMenu:disarmAbandon()
    self.confirmingAbandon = false
    self:rebuild()
    self:_focusKey("abandon")
end

-- ===================================================================
-- UPDATE / INPUT
-- ===================================================================
function PauseMenu:update(dt)
    if not self.visible then return end
    self._t = (self._t or 0) + (dt or 0)
    for _, row in ipairs(self.rows) do if row.btn then row.btn:update(dt) end end
    for _, s in ipairs(self.shortcuts) do s.btn:update(dt) end
    for _, b in ipairs(self.confirmButtons) do b:update(dt) end

    -- Mouse MEXEU → o foco segue o mouse. Mouse parado não rouba o foco do
    -- teclado (quem navega nas setas com o cursor esquecido sobre uma row).
    local mx, my = love.mouse.getPosition()
    if mx ~= self._lastMX or my ~= self._lastMY then
        local first = self._lastMX == nil
        self._lastMX, self._lastMY = mx, my
        if not first then
            for li, items in ipairs(self.lines) do
                for ii, it in ipairs(items) do
                    if MenuKit.hit(it.rect, mx, my)
                        and (li ~= self.focusLine or ii ~= self.focusItem) then
                        self.focusLine, self.focusItem = li, ii
                        -- Rows de ação usam Button invisível (mudo): o som
                        -- de hover sai daqui. Atalhos/confirmação já tocam.
                        if it.rect.btn and it.rect.btn.variant == "invisible" then
                            Sfx.playWithVariation("menuHover", 1.0, 0.12)
                        end
                    end
                end
            end
        end
    end
end

local function itemAt(self, x, y)
    for _, items in ipairs(self.lines) do
        for _, it in ipairs(items) do
            if MenuKit.hit(it.rect, x, y) then return it end
        end
    end
end

function PauseMenu:mousepressed(x, y, button)
    if not self.visible then return false end
    if button == 1 then self._pressed = itemAt(self, x, y) end
    return true -- modal: consome tudo (ação acontece no release)
end

function PauseMenu:mousereleased(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return true end
    local it = itemAt(self, x, y)
    -- Só ativa se o PRESS também nasceu neste item (o release do clique que
    -- ABRIU a pausa pela engrenagem não dispara nada por acidente).
    if it and it == self._pressed and it.action then
        self._pressed = nil
        Sfx.playWithVariation("buttonClick", 1.0, 0.08)
        it.action()
        return true
    end
    self._pressed = nil
    return true -- clique fora: continua modal (não fecha por acidente)
end

function PauseMenu:keypressed(key)
    if not self.visible then return false end
    -- Atalhos de tela da run (mesmas letras do jogo).
    if not self.confirmingAbandon then
        for _, s in ipairs(self.shortcuts) do
            if key == s.hotkey then
                Sfx.playWithVariation("buttonClick", 1.0, 0.08)
                s.action()
                return true
            end
        end
    end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    if it == "back" then
        if self.confirmingAbandon then self:disarmAbandon() else self:hide() end
    elseif it == "up" then self:_moveFocus(-1, 0)
    elseif it == "down" then self:_moveFocus(1, 0)
    elseif it == "left" then self:_moveFocus(0, -1)
    elseif it == "right" then self:_moveFocus(0, 1)
    elseif it == "confirm" then self:_activateFocused()
    end
    return true -- modal: engole teclas (nada de atalho vazando pro jogo)
end

-- ===================================================================
-- DRAW
-- ===================================================================
function PauseMenu:_drawInfo(z)
    if z.mode == "none" then
        Palette.set(Palette.PARCHMENT)
        TextFit.print(I18n.t("pause.no_run"), z.x, z.y + 4,
            { size = 10, maxW = z.w, align = "center" })
        return
    end
    local cells = self:runSummary() or {}
    if z.mode == "line" then
        local parts = {}
        for i = 1, math.min(3, #cells) do parts[#parts + 1] = cells[i].value end
        Palette.set(Palette.PARCHMENT_LIGHT)
        TextFit.print(table.concat(parts, "  ·  "), z.x, z.y + 4,
            { size = 10, maxW = z.w, align = "center" })
        return
    end
    UiPanel.draw(z.x, z.y, z.w, z.h, { depth = "inner" })
    local cols = 3
    local cw = math.floor((z.w - INFO_PAD * 2) / cols)
    for i, c in ipairs(cells) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = z.x + INFO_PAD + col * cw
        local cy = z.y + INFO_PAD + row * (INFO_CELL_H + 8)
        Palette.set(Palette.AGED_GOLD)
        TextFit.print(c.label, cx + 4, cy, { size = 8, maxW = cw - 8 })
        Palette.set(Palette.PARCHMENT_LIGHT)
        TextFit.print(c.value, cx + 4, cy + 12, { size = 12, maxW = cw - 8 })
    end
    -- filetes verticais entre colunas (agrupa sem caixinha por célula)
    Palette.set(Palette.AGED_GOLD_DARK, 0.6)
    for c = 1, cols - 1 do
        love.graphics.rectangle("fill", z.x + INFO_PAD + c * cw - 4, z.y + INFO_PAD, 1, z.h - INFO_PAD * 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu:_drawRow(row, focused)
    local x, y, w, h = row.x, row.y, row.w, row.h
    local fill, outline, titleCol, descCol
    if row.danger or row.confirming then
        fill = focused and Palette.lerp(Palette.BLOOD_DARK, Palette.BLOOD, 0.45) or Palette.BLOOD_DARK
        outline = Palette.BLOOD
        titleCol, descCol = DANGER_TEXT, Palette.PARCHMENT
    elseif row.primary then
        -- PRIMÁRIA: placa dourada cheia, texto tinta (a única no menu).
        fill = focused and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD
        outline = Palette.AGED_GOLD_LIGHT
        titleCol, descCol = Palette.INK, Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.4)
    else
        fill = focused and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.55)
            or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.25)
        outline = focused and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
        titleCol = focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
        descCol = Palette.PARCHMENT
    end
    -- sombra dura + placa + emboss (gramática do Button clean)
    Palette.set(Palette.INK, 0.6)
    love.graphics.rectangle("fill", x + 3, y + 3, w, h, 3, 3)
    Palette.set(fill)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(1, 1, 1, row.primary and 0.22 or 0.06)
    love.graphics.rectangle("fill", x + 2, y + 1, w - 4, 2)
    Palette.set(outline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)

    if row.confirming then
        love.graphics.setFont(row.qFont)
        Palette.set(DANGER_TEXT)
        love.graphics.printf(I18n.t("pause.abandon_confirm"),
            x + ROW_PAD_X, y + ROW_PAD_Y, w - ROW_PAD_X * 2, "left")
        return
    end
    local ty = y + ROW_PAD_Y + (row.primary and 2 or 0)
    love.graphics.setFont(row.titleFont)
    if row.primary then
        Palette.set(Palette.AGED_GOLD_LIGHT, 0.7)
        love.graphics.print(row.title, x + ROW_PAD_X, ty + 1)
    end
    Palette.set(titleCol)
    love.graphics.print(row.title, x + ROW_PAD_X, ty)
    -- chevron à direita: "isto é uma ação" (mesmo idioma do Roteiro)
    local cf = FontManager.getFont(row.primary and 14 or 11)
    love.graphics.setFont(cf)
    Palette.set(titleCol, focused and 1 or 0.55)
    love.graphics.print(">", x + w - ROW_PAD_X - cf:getWidth(">"),
        y + math.floor((h - cf:getHeight()) / 2))
    if #row.descLines > 0 then
        love.graphics.setFont(row.descFont)
        Palette.set(descCol)
        local dy = ty + row.titleFont:getHeight() + TITLE_TO_DESC
        for _, line in ipairs(row.descLines) do
            love.graphics.print(line, x + ROW_PAD_X, dy)
            dy = dy + row.descLH
        end
    end
end

function PauseMenu:draw()
    if not self.visible then return end
    local t = self._t or 0
    MenuKit.drawVeil(t, 0.62)
    MenuKit.pushEnter(t)

    local p = self._panel or { x = 0, y = 0, w = 480, h = 560 }
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local z = self._zones or {}

    -- CABEÇALHO
    if z.title then
        local title = I18n.t("pause.title")
        local tf, shown = TextFit.fit(title, 24, z.title.w, 14)
        love.graphics.setFont(tf)
        local tx = math.floor(z.title.x + (z.title.w - tf:getWidth(shown)) / 2)
        local ty = z.title.y + 4
        Palette.set(Palette.INK, 0.85)
        love.graphics.print(shown, tx + 2, ty + 2)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(shown, tx, ty)
        Palette.set(Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("fill", z.title.x + 24, z.title.y + TITLE_H - 16, z.title.w - 48, 1)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", math.floor(z.title.x + z.title.w / 2) - 3,
            z.title.y + TITLE_H - 18, 6, 5)
    end

    if z.info then self:_drawInfo(z.info) end

    local focusKey = self:focusedKey()
    local focusRect
    for _, s in ipairs(self.shortcuts) do
        s.btn:draw()
        if s.key == focusKey then focusRect = s end
    end
    for _, row in ipairs(self.rows) do
        local focused = (row.key == focusKey) or (row.btn and row.btn.hover)
        self:_drawRow(row, focused)
        if row.key == focusKey then focusRect = row end
    end
    for i, b in ipairs(self.confirmButtons) do
        b:draw()
        local k = (i == 1) and "abandon_yes" or "abandon_no"
        if k == focusKey then focusRect = { x = b.x, y = b.y, w = b.width, h = b.height } end
    end
    if focusRect then MenuKit.focusRing(focusRect.x, focusRect.y, focusRect.w, focusRect.h, t) end

    -- RODAPÉ
    if z.footer then
        local hint = self.confirmingAbandon and I18n.t("pause.hint_confirm") or I18n.t("pause.hint")
        Palette.set(Palette.PARCHMENT)
        TextFit.print(hint, z.footer.x, z.footer.y + math.floor((z.footer.h - 8) / 2),
            { size = 8, maxW = z.footer.w, align = "center" })
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return PauseMenu
