-- components/PauseMenu.lua
-- Menu de pausa (engrenagem da TopBar / ESC) — padrão Slay the Spire +
-- estrutura do create_UIBox_options do Balatro (seed visível, atalhos, ação
-- primária no topo).
--
-- v4 (Out/2026 — dono: "muita coisinha", feio). Hierarquia de StS/Balatro:
-- poucas coisas, grandes e legíveis, véu escuro atrás.
--   • ZONAS fixas (memory/ui_layout_invariants.md §1), de cima pra baixo:
--       CABEÇALHO  título com filetes
--       RESUMO     "classe · jornada" + semente miúda (vida/ouro/baralho
--                  saíram: a TopBar já mostra)
--       ATALHOS    três ícones — Baralho [D] · Coringas [J] · Roteiro [M]
--       AÇÕES      Continuar (PRIMÁRIA) · Configurações · Salvar e sair —
--                  placas centradas, sem descrição
--       PERIGO     "Abandonar" como link discreto; armado, vira pergunta +
--                  Sim/Não no mesmo lugar (2 etapas, foco no Não)
--     Sem rodapé de dica (regra do projeto). Quando falta altura quem CEDE é
--     o conteúdo (placas mais baixas, depois somem atalhos e semente) —
--     nunca a posição das zonas. `validate()` roda no test_pause_menu.
--   • Navegação por teclado/gamepad (src/ui/MenuKit.lua): setas/WASD, Enter,
--     ESC; foco começa em Continuar.
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
local PAD_BOTTOM   = 18
local PANEL_MAX_W  = 440
local MAIN_MAX_W   = 340    -- placas de ação: largas o bastante, não a parede toda
local TITLE_H      = 50     -- zona do título (inclui o ornamento)
local INFO_H       = 36     -- linha da jornada + semente miúda
local INFO_H_LINE  = 20
local ROW_GAP      = 8
local ZONE_GAP     = 14
local SHORTCUT_H   = 58     -- ícone + rótulo curto
local SHORTCUT_MAX_W = 120
local DANGER_H     = 24
local CONFIRM_BTN_H = 28

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
        { key = "deck",    hotkey = "d", icon = "deck", label = I18n.t("pause.shortcut_deck"),
          action = open(self.callbacks.onOpenDeck) },
        { key = "jokers",  hotkey = "j", icon = "jester_hat", label = I18n.t("pause.shortcut_jokers"),
          action = open(self.callbacks.onOpenJokers) },
        { key = "journal", hotkey = "m", icon = "scroll", label = I18n.t("pause.shortcut_journal"),
          action = open(self.callbacks.onOpenJournal) },
    }
end

-- Monta zonas, rows, atalhos e linhas de navegação. Idempotente: roda em
-- show/resize/confirmação/troca de idioma.
function PauseMenu:rebuild()
    self.rows, self.shortcuts, self.confirmButtons = {}, {}, {}

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    -- Escala: mora no UiScale (espaço virtual ~1280x720, scale(k) no
    -- desenho). Aqui é 1:1; S() fica pra um ajuste fino futuro.
    local u = 1
    self._u = u
    local function S(v) return math.floor(v * u + 0.5) end
    local PAD, PAD_BOTTOM, TITLE_H = S(PAD), S(PAD_BOTTOM), S(TITLE_H)
    local INFO_H, INFO_H_LINE = S(INFO_H), S(INFO_H_LINE)
    local ROW_GAP, ZONE_GAP = S(ROW_GAP), S(ZONE_GAP)
    local SHORTCUT_H, SHORTCUT_MAX_W = S(SHORTCUT_H), S(SHORTCUT_MAX_W)
    local DANGER_H, CONFIRM_BTN_H = S(DANGER_H), S(CONFIRM_BTN_H)
    local MAIN_MAX_W = S(MAIN_MAX_W)
    local pw = math.max(280, math.min(S(PANEL_MAX_W), sw - 32))
    local innerW = pw - PAD * 2
    local runActive = hasRun(self.game)
    local defs = actionDefs(self, runActive)
    local maxH = sh - 24

    -- Pedido de confirmação do abandono: pergunta quebrada + Sim/Não.
    local qFont = FontManager.getFont(S(11))
    local _, qLines = qFont:getWrap(I18n.t("pause.abandon_confirm"), innerW - 16)
    local qLH = math.floor(qFont:getHeight() * 1.3)
    local confirmH = S(8) + #qLines * qLH + S(8) + CONFIRM_BTN_H + S(8)

    -- Modos em ordem de preferência: quem cede é o CONTEÚDO (altura das
    -- placas, depois os atalhos, depois a semente) — nunca a ordem das zonas.
    local modes = {
        { name = "full",    primaryH = S(50), rowH = S(42), shortcuts = true,  seed = true },
        { name = "nodesc",  primaryH = S(42), rowH = S(34), shortcuts = true,  seed = true },
        { name = "compact", primaryH = S(38), rowH = S(30), shortcuts = false, seed = false },
    }
    local chosen
    for _, mode in ipairs(modes) do
        local infoH = runActive and (mode.seed and INFO_H or INFO_H_LINE) or INFO_H_LINE
        local actionsH = mode.primaryH + (#defs - (runActive and 2 or 1)) * (mode.rowH + ROW_GAP)
        local dangerH = runActive and ((self.confirmingAbandon and confirmH or DANGER_H) + ZONE_GAP) or 0
        local scH = (runActive and mode.shortcuts) and (SHORTCUT_H + ZONE_GAP) or 0
        mode.infoH, mode.actionsH = infoH, actionsH
        mode.total = PAD + TITLE_H + infoH + ZONE_GAP + scH + actionsH + dangerH + PAD_BOTTOM
        chosen = mode
        if mode.total <= maxH then break end
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
    zones.info = { x = x, y = y, w = innerW, h = chosen.infoH,
        mode = runActive and (chosen.seed and "full" or "line") or "none" }
    y = y + chosen.infoH + ZONE_GAP

    -- ATALHOS: três placas de ícone (os MESMOS ícones dos blocos da TopBar
    -- que eles abrem), rótulo curto embaixo. Centradas, largura contida.
    if runActive and chosen.shortcuts then
        zones.shortcuts = { x = x, y = y, w = innerW, h = SHORTCUT_H }
        local defsS = shortcutDefs(self)
        local gap = S(10)
        local bw = math.min(SHORTCUT_MAX_W, math.floor((innerW - gap * (#defsS - 1)) / #defsS))
        local bx0 = x + math.floor((innerW - (bw * #defsS + gap * (#defsS - 1))) / 2)
        for i, d in ipairs(defsS) do
            local bx = bx0 + (i - 1) * (bw + gap)
            local btn = Button:new(bx, y, bw, SHORTCUT_H, "", d.action)
            btn:setVariant("invisible")
            self.shortcuts[i] = { x = bx, y = y, w = bw, h = SHORTCUT_H, icon = d.icon,
                key = d.key, hotkey = d.hotkey, label = d.label, btn = btn, action = d.action }
        end
        y = y + SHORTCUT_H + ZONE_GAP
    end

    -- AÇÕES: placas grandes, texto centrado, SEM descrição (o nome basta).
    local mainW = math.min(innerW, MAIN_MAX_W)
    local mainX = x + math.floor((innerW - mainW) / 2)
    zones.actions = { x = mainX, y = y, w = mainW, h = chosen.actionsH }
    local dangerDef
    for _, def in ipairs(defs) do
        if def.danger then
            dangerDef = def
        else
            local h = def.primary and chosen.primaryH or chosen.rowH
            local row = { x = mainX, y = y, w = mainW, h = h, key = def.key,
                title = def.title, primary = def.primary, action = def.action }
            row.btn = Button:new(mainX, y, mainW, h, "", def.action)
            row.btn:setVariant("invisible")
            table.insert(self.rows, row)
            y = y + h + ROW_GAP
        end
    end
    y = zones.actions.y + chosen.actionsH + ZONE_GAP

    -- PERIGO: "Abandonar" é um link discreto no pé do painel; armado, vira
    -- a pergunta + Sim/Não no MESMO lugar (o resto do painel não mexe).
    if dangerDef then
        local h = self.confirmingAbandon and confirmH or DANGER_H
        zones.danger = { x = x, y = y, w = innerW, h = h }
        local row = { key = dangerDef.key, title = dangerDef.title, danger = true,
            action = dangerDef.action }
        if self.confirmingAbandon then
            row.x, row.y, row.w, row.h = x, y, innerW, h
            row.confirming, row.qFont, row.qLines, row.qLH = true, qFont, qLines, qLH
            local bw = math.min(S(170), math.floor((innerW - 16 - 10) / 2))
            local bx = x + math.floor((innerW - (bw * 2 + 10)) / 2)
            local by = y + h - S(8) - CONFIRM_BTN_H
            local yes = Button:new(bx, by, bw, CONFIRM_BTN_H, I18n.t("pause.abandon_yes"),
                function()
                    self:hide()
                    if self.callbacks.onAbandon then self.callbacks.onAbandon() end
                end, nil, S(9))
            yes:setColorScheme("red")
            local no = Button:new(bx + bw + 10, by, bw, CONFIRM_BTN_H, I18n.t("pause.abandon_no"),
                function() self:disarmAbandon() end, nil, S(9))
            self.confirmButtons = { yes, no }
        else
            local f = FontManager.getFont(S(10))
            local tw = math.min(innerW, f:getWidth(dangerDef.title) + S(28))
            row.x, row.y, row.w, row.h = x + math.floor((innerW - tw) / 2), y, tw, h
            row.btn = Button:new(row.x, row.y, row.w, row.h, "", dangerDef.action)
            row.btn:setVariant("invisible")
        end
        table.insert(self.rows, row)
    end
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
    local order = { "title", "info", "shortcuts", "actions", "danger" }
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
-- Métrica escalada pelo fator do último rebuild (fonte e respiro do desenho).
local function S(self, v) return math.floor(v * (self._u or 1) + 0.5) end

-- Uma linha "classe · jornada" e a semente miúda embaixo. Vida/ouro/baralho
-- NÃO entram: a TopBar já mostra, e repetir é ruído (v3 tinha 6 células).
function PauseMenu:_drawInfo(z)
    if z.mode == "none" then
        Palette.set(Palette.PARCHMENT)
        TextFit.print(I18n.t("pause.no_run"), z.x, z.y + 4,
            { size = S(self, 10), maxW = z.w, align = "center" })
        return
    end
    local cells = self:runSummary() or {}
    local line = (cells[1] and cells[1].value or "?") .. "  ·  " .. (cells[2] and cells[2].value or "?")
    Palette.set(Palette.PARCHMENT_LIGHT)
    TextFit.print(line, z.x, z.y + 2, { size = S(self, 12), maxW = z.w, align = "center" })
    if z.mode == "full" and cells[3] then
        Palette.set(Palette.AGED_GOLD_DARK)
        TextFit.print(cells[3].label .. "  " .. cells[3].value, z.x, z.y + S(self, 22),
            { size = S(self, 8), maxW = z.w, align = "center" })
    end
end

-- Placa de atalho: ícone grande + rótulo curto. Sem moldura em repouso
-- (respiro separa); focada ganha a placa escura e o rótulo acende.
function PauseMenu:_drawShortcut(s, focused)
    if focused then
        Palette.set(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.45))
        love.graphics.rectangle("fill", s.x, s.y, s.w, s.h, 4, 4)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.rectangle("line", s.x + 0.5, s.y + 0.5, s.w - 1, s.h - 1, 4, 4)
    end
    local size = S(self, 32)
    local icon
    if s.icon == "deck" then
        local img = require("src.ui.ImageCache").get("assets/icons/deck.png")
        local sc = size / math.max(img:getWidth(), img:getHeight())
        icon = function(ix, iy) love.graphics.draw(img, ix, iy, 0, sc, sc) end
    else
        local ic = require("src.ui.IconLoader").get(s.icon)
        icon = function(ix, iy) ic.draw(ix, iy, size / 64) end
    end
    local ix = math.floor(s.x + (s.w - size) / 2)
    local iy = s.y + S(self, 6) + (focused and -1 or 0)
    love.graphics.setColor(1, 1, 1, focused and 1 or 0.78)
    icon(ix, iy)
    Palette.set(focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT)
    TextFit.print(s.label, s.x + 2, s.y + s.h - S(self, 15), { size = S(self, 8), maxW = s.w - 4, align = "center" })
end

function PauseMenu:_drawRow(row, focused, t)
    local x, y, w, h = row.x, row.y, row.w, row.h
    if row.confirming then
        Palette.set(Palette.BLOOD_DARK, 0.85)
        love.graphics.rectangle("fill", x, y, w, h, 3, 3)
        Palette.set(Palette.BLOOD)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
        love.graphics.setFont(row.qFont)
        Palette.set(DANGER_TEXT)
        local qy = y + S(self, 8)
        for _, line in ipairs(row.qLines) do
            love.graphics.printf(line, x + 8, qy, w - 16, "center")
            qy = qy + row.qLH
        end
        return
    end
    if row.danger then
        -- link discreto: texto vermelho apagado; foco acende + sublinha.
        Palette.set(focused and DANGER_TEXT or Palette.lerp(Palette.BLOOD, Palette.PARCHMENT_DARK, 0.35))
        local f = FontManager.getFont(S(self, 10))
        love.graphics.setFont(f)
        local tw = f:getWidth(row.title)
        local tx = math.floor(x + (w - tw) / 2)
        local ty = y + math.floor((h - f:getHeight()) / 2)
        love.graphics.print(row.title, tx, ty)
        if focused then love.graphics.rectangle("fill", tx, ty + f:getHeight() + 1, tw, 1) end
        return
    end
    local fill, outline, titleCol
    if row.primary then
        -- PRIMÁRIA: placa dourada cheia, texto tinta (a única no menu).
        fill = focused and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD
        outline = Palette.AGED_GOLD_LIGHT
        titleCol = Palette.INK
    else
        fill = focused and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.55)
            or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.25)
        outline = focused and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
        titleCol = focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
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

    local font, shown = TextFit.fit(row.title, S(self, row.primary and 16 or 13), w - 24, 9)
    love.graphics.setFont(font)
    local tx = math.floor(x + (w - font:getWidth(shown)) / 2)
    local ty = y + math.floor((h - font:getHeight()) / 2) + 1
    if row.primary then
        Palette.set(Palette.AGED_GOLD_LIGHT, 0.7)
        love.graphics.print(shown, tx, ty + 1)
    end
    Palette.set(titleCol)
    love.graphics.print(shown, tx, ty)
end

function PauseMenu:draw()
    if not self.visible then return end
    local t = self._t or 0
    MenuKit.drawVeil(t, 0.68)
    MenuKit.pushEnter(t)

    local p = self._panel or { x = 0, y = 0, w = 480, h = 560 }
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local z = self._zones or {}

    -- CABEÇALHO: título + filetes com losango (mesma gramática da loja)
    if z.title then
        local title = I18n.t("pause.title")
        local tf, shown = TextFit.fit(title, S(self, 24), z.title.w - 80, 14)
        love.graphics.setFont(tf)
        local tw = tf:getWidth(shown)
        local tx = math.floor(z.title.x + (z.title.w - tw) / 2)
        local ty = z.title.y + 2
        Palette.set(Palette.INK, 0.85)
        love.graphics.print(shown, tx + 2, ty + 2)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(shown, tx, ty)
        local ly = ty + math.floor(tf:getHeight() / 2)
        local span = math.min(S(self, 70), math.floor((z.title.w - tw) / 2) - 18)
        if span > 12 then
            Palette.set(Palette.AGED_GOLD_DARK)
            love.graphics.rectangle("fill", tx - 12 - span, ly, span, 1)
            love.graphics.rectangle("fill", tx + tw + 12, ly, span, 1)
            Palette.set(Palette.AGED_GOLD)
            love.graphics.rectangle("fill", tx - 12 - span - 3, ly - 1, 3, 3)
            love.graphics.rectangle("fill", tx + tw + 12 + span, ly - 1, 3, 3)
        end
    end

    if z.info then self:_drawInfo(z.info) end

    local focusKey = self:focusedKey()
    local focusRect
    for _, s in ipairs(self.shortcuts) do
        local focused = (s.key == focusKey) or (s.btn and s.btn.hover)
        self:_drawShortcut(s, focused)
        if s.key == focusKey then focusRect = s end
    end
    for _, row in ipairs(self.rows) do
        local focused = (row.key == focusKey) or (row.btn and row.btn.hover)
        self:_drawRow(row, focused, t)
        if row.key == focusKey and not row.danger then focusRect = row end
    end
    for i, b in ipairs(self.confirmButtons) do
        b:draw()
        local k = (i == 1) and "abandon_yes" or "abandon_no"
        if k == focusKey then focusRect = { x = b.x, y = b.y, w = b.width, h = b.height } end
    end
    if focusRect then MenuKit.focusRing(focusRect.x, focusRect.y, focusRect.w, focusRect.h, t) end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return PauseMenu
