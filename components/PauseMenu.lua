-- components/PauseMenu.lua
-- Menu de pausa (engrenagem da TopBar) — padrão Slay the Spire: Continuar /
-- Configurações / Salvar e voltar ao menu / Abandonar run (com confirmação).
-- Cada opção tem DESCRIÇÃO do que acontece — nada de botão ambíguo.
--
-- Visual v2 (playtest Jul/2026): painel ESCURO no idioma da loja (fill ink +
-- dual-border dourada + cantos ornamentais) — o Panel9 pergaminho claro da
-- primeira versão parecia a tela de seleção de classe e destoava do modal.
-- Todas as alturas são MEDIDAS pelo texto real (wrap por idioma): nenhuma
-- linha vaza da row, da confirmação ou do rodapé.
--
-- Overlay modal global (como SettingsMenu): main.lua instancia, injeta
-- callbacks via show(game, callbacks) e roteia update/draw/input com
-- prioridade sobre o resto. _G.togglePauseMenu abre/fecha de qualquer lugar.

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local Button      = require("components.Button")
local I18n        = require("src.i18n.I18n")
local Sfx         = require("src.systems.Sfx")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

-- Métricas do layout (alturas de texto são calculadas em cima destas).
local ROW_PAD_X = 14
local ROW_PAD_TOP = 12
local TITLE_TO_DESC = 8
local ROW_PAD_BOTTOM = 12
local ROW_GAP = 12
local HEADER_H = 108          -- título + subtítulo do painel
local FOOTER_H = 44           -- hint do rodapé

function PauseMenu:new()
    local instance = setmetatable({}, PauseMenu)
    instance.visible = false
    instance.game = nil
    instance.callbacks = {}
    instance.rows = {}            -- {x,y,w,h,btn,title,titleFont,descLines,...}
    instance.confirmButtons = {}  -- botões Sim/Não do abandono
    instance.confirmingAbandon = false
    instance._panel = nil
    return instance
end

function PauseMenu:isVisible() return self.visible end

function PauseMenu:show(game, callbacks)
    self.visible = true
    self.game = game or self.game
    self.callbacks = callbacks or self.callbacks
    self.confirmingAbandon = false
    self:rebuild()
    Sfx.play("menuOpen")
end

function PauseMenu:hide()
    self.visible = false
    self.confirmingAbandon = false
    self.rows = {}
    self.confirmButtons = {}
    Sfx.play("menuClose")
end

function PauseMenu:toggle(game, callbacks)
    if self.visible then self:hide() else self:show(game, callbacks) end
end

local function hasRun(game)
    return game and game.runManager and game.runManager.hasActiveRun
        and game.runManager:hasActiveRun()
end

-- Fonte que CABE: tenta o tamanho pedido e desce até o texto caber na largura
-- (idiomas longos — "Speichern und zum Menue" — nunca estouram a row).
local function fitFont(text, maxW, startSize, minSize)
    local size = startSize
    while size > (minSize or 9) do
        local f = FontManager.getFont(size)
        if f:getWidth(text) <= maxW then return f, size end
        size = size - 1
    end
    return FontManager.getFont(minSize or 9), minSize or 9
end

-- Monta as opções (dados → medidas → botões). Recalculado em show/resize/
-- confirmação. A ALTURA de cada row vem do wrap real da descrição.
function PauseMenu:rebuild()
    self.rows = {}
    self.confirmButtons = {}

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(480, math.floor(sw * 0.62))
    local rowW = pw - 64
    local innerW = rowW - ROW_PAD_X * 2
    local runActive = hasRun(self.game)

    local descFont = FontManager.getFont(9)
    local descLH = math.floor(descFont:getHeight() * 1.35)

    local defs = {
        {
            key = "resume",
            title = I18n.t("pause.resume"),
            desc = I18n.t("pause.resume_desc"),
            action = function() self:hide() end,
        },
        {
            key = "settings",
            title = I18n.t("pause.settings"),
            desc = I18n.t("pause.settings_desc"),
            action = function()
                self:hide()
                if self.callbacks.onOpenSettings then self.callbacks.onOpenSettings() end
            end,
        },
        {
            key = "save_quit",
            title = runActive and I18n.t("pause.save_quit") or I18n.t("pause.quit_norun"),
            desc = runActive and I18n.t("pause.save_quit_desc") or I18n.t("pause.quit_norun_desc"),
            action = function()
                self:hide()
                if self.callbacks.onSaveQuit then self.callbacks.onSaveQuit() end
            end,
        },
    }
    if runActive then
        table.insert(defs, {
            key = "abandon",
            title = I18n.t("pause.abandon"),
            desc = I18n.t("pause.abandon_desc"),
            danger = true,
            action = function()
                -- Duas etapas: o primeiro clique arma a confirmação.
                self.confirmingAbandon = true
                self:rebuild()
            end,
        })
    end

    -- ===== MEDIDA: altura de cada row pelo conteúdo real =====
    local totalRowsH = 0
    local measured = {}
    for _, def in ipairs(defs) do
        local m = { def = def }
        if def.key == "abandon" and self.confirmingAbandon then
            -- Row de confirmação: pergunta (com wrap) + linha de botões.
            local qFont = FontManager.getFont(12)
            local _, qLines = qFont:getWrap(I18n.t("pause.abandon_confirm"), innerW)
            m.confirming = true
            m.qFont = qFont
            m.qLines = #qLines
            local qH = #qLines * math.floor(qFont:getHeight() * 1.3)
            m.h = ROW_PAD_TOP + qH + 10 + 30 + ROW_PAD_BOTTOM
        else
            local titleFont = select(1, fitFont(def.title, innerW, 14, 10))
            local _, descLines = descFont:getWrap(def.desc, innerW)
            m.titleFont = titleFont
            m.descLines = descLines
            local descH = #descLines * descLH
            m.h = ROW_PAD_TOP + titleFont:getHeight() + TITLE_TO_DESC
                + descH + ROW_PAD_BOTTOM
        end
        table.insert(measured, m)
        totalRowsH = totalRowsH + m.h
    end
    totalRowsH = totalRowsH + ROW_GAP * math.max(0, #measured - 1)

    -- Painel de altura DINÂMICA (conteúdo + header + footer), clamp na tela.
    local ph = math.min(math.floor(sh * 0.92), HEADER_H + totalRowsH + FOOTER_H + 24)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    self._panel = { x = px, y = py, w = pw, h = ph }

    -- ===== POSICIONA =====
    local x = math.floor(px + (pw - rowW) / 2)
    local y = py + HEADER_H

    for _, m in ipairs(measured) do
        local def = m.def
        local row = {
            x = x, y = y, w = rowW, h = m.h,
            title = def.title, desc = def.desc,
            danger = def.danger, key = def.key,
            titleFont = m.titleFont,
            descLines = m.descLines,
            descFont = descFont,
            descLH = descLH,
            confirming = m.confirming,
            qFont = m.qFont,
        }
        if m.confirming then
            local half = math.floor((rowW - ROW_PAD_X * 2 - 8) / 2)
            local by = y + m.h - ROW_PAD_BOTTOM - 28
            local yesBtn = Button:new(x + ROW_PAD_X, by, half, 28,
                I18n.t("pause.abandon_yes"), function()
                    self:hide()
                    if self.callbacks.onAbandon then self.callbacks.onAbandon() end
                end, nil, 9)
            yesBtn:setColorScheme("red")
            local noBtn = Button:new(x + ROW_PAD_X + half + 8, by, half, 28,
                I18n.t("pause.abandon_no"), function()
                    self.confirmingAbandon = false
                    self:rebuild()
                end, nil, 9)
            table.insert(self.confirmButtons, yesBtn)
            table.insert(self.confirmButtons, noBtn)
        else
            row.btn = Button:new(x, y, rowW, m.h, "", def.action)
            row.btn:setVariant("invisible")
        end
        table.insert(self.rows, row)
        y = y + m.h + ROW_GAP
    end
end

function PauseMenu:resize()
    if self.visible then self:rebuild() end
end

function PauseMenu:update(dt)
    if not self.visible then return end
    for _, row in ipairs(self.rows) do
        if row.btn then row.btn:update(dt) end
    end
    for _, b in ipairs(self.confirmButtons) do b:update(dt) end
end

-- Painel escuro canônico do design system (fonte única: src/ui/UiPanel.lua —
-- o idioma da loja). Mantido como wrapper local pra estabilidade do call site.
local UiPanel = require("src.ui.UiPanel")
local function drawDarkPanel(x, y, w, h)
    UiPanel.draw(x, y, w, h)
end

function PauseMenu:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Véu escuro sobre o jogo (modal).
    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    local p = self._panel or { x = 0, y = 0, w = 480, h = 560 }
    local px, py, pw, ph = p.x, p.y, p.w, p.h
    drawDarkPanel(px, py, pw, ph)

    -- Título (dourado sobre o fundo escuro — não mais tinta sobre pergaminho)
    local title = I18n.t("pause.title")
    local titleFont = select(1, fitFont(title, pw - 48, 24, 16))
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2) + 1, py + 28 + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2), py + 28)

    -- Subtítulo: onde a jornada está (ato/andar/classe).
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    local sub
    if run then
        local MapManager = require("src.systems.MapManager")
        sub = I18n.t("pause.progress", {
            act = run.actNumber or 1,
            floor = run.floorInAct or 1,
            total = MapManager.FLOORS_PER_ACT,
            class = run.className or "?",
        })
    else
        sub = I18n.t("pause.no_run")
    end
    local subFont = select(1, fitFont(sub, pw - 48, 10, 8))
    love.graphics.setFont(subFont)
    Palette.set(Palette.PARCHMENT)
    love.graphics.print(sub,
        math.floor(px + pw / 2 - subFont:getWidth(sub) / 2), py + 68)

    -- Separador dourado sob o header.
    Palette.set(Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("fill", px + 24, py + HEADER_H - 14, pw - 48, 1)

    -- Rows de opção: título + descrição (wrap pré-medido no rebuild).
    for _, row in ipairs(self.rows) do
        local hover = row.btn and row.btn.hover
        local lift = hover and -2 or 0
        local y = row.y + lift

        local fill = { 0.14, 0.11, 0.085, 0.94 }
        local outline = Palette.AGED_GOLD_DARK
        if row.danger or row.confirming then
            fill = hover and { 0.26, 0.09, 0.07, 0.96 } or { 0.19, 0.075, 0.055, 0.94 }
            outline = Palette.BLOOD
        elseif hover then
            fill = { 0.21, 0.16, 0.11, 0.96 }
            outline = Palette.AGED_GOLD
        end

        PixelCanvas.rect(row.x, y, row.w, row.h, fill)
        PixelCanvas.rectOutline(row.x, y, row.w, row.h, outline)
        if hover and not row.confirming then
            PixelCanvas.rectOutline(row.x + 2, y + 2, row.w - 4, row.h - 4,
                Palette.AGED_GOLD_DARK)
        end

        if row.confirming then
            love.graphics.setFont(row.qFont)
            Palette.set(Palette.BLOOD_LIGHT or { 0.95, 0.5, 0.4, 1 })
            love.graphics.printf(I18n.t("pause.abandon_confirm"),
                row.x + ROW_PAD_X, y + ROW_PAD_TOP,
                row.w - ROW_PAD_X * 2, "left")
        else
            love.graphics.setFont(row.titleFont)
            Palette.set(row.danger and (Palette.BLOOD_LIGHT or { 0.95, 0.5, 0.4, 1 })
                or (hover and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT))
            love.graphics.print(row.title, row.x + ROW_PAD_X, y + ROW_PAD_TOP)

            love.graphics.setFont(row.descFont)
            Palette.set(Palette.PARCHMENT)
            local dy = y + ROW_PAD_TOP + row.titleFont:getHeight() + TITLE_TO_DESC
            for _, line in ipairs(row.descLines or {}) do
                love.graphics.print(line, row.x + ROW_PAD_X, dy)
                dy = dy + row.descLH
            end
        end
    end

    for _, b in ipairs(self.confirmButtons) do b:draw() end

    -- Rodapé: atalho (fit — some elegante se a tela for minúscula).
    local hint = I18n.t("pause.hint")
    local hf = select(1, fitFont(hint, pw - 48, 8, 7))
    love.graphics.setFont(hf)
    Palette.set(Palette.PARCHMENT)
    love.graphics.print(hint,
        math.floor(px + pw / 2 - hf:getWidth(hint) / 2), py + ph - 28)

    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu:mousepressed(x, y, button)
    if not self.visible then return false end
    return true -- modal: consome tudo (ação acontece no release)
end

function PauseMenu:mousereleased(x, y, button)
    if not self.visible then return false end
    for _, b in ipairs(self.confirmButtons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    for _, row in ipairs(self.rows) do
        if row.btn and row.btn.hover and not row.btn.disabled then
            row.btn.onClick()
            return true
        end
    end
    return true -- clique fora das rows: continua modal (não fecha por acidente)
end

function PauseMenu:keypressed(key)
    if not self.visible then return false end
    if key == "escape" then
        if self.confirmingAbandon then
            self.confirmingAbandon = false
            self:rebuild()
        else
            self:hide()
        end
        return true
    end
    return true -- modal: engole teclas (nada de atalho vazando pro jogo)
end

return PauseMenu
