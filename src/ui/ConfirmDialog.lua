-- src/ui/ConfirmDialog.lua
-- Diálogo de confirmação MODAL e genérico (singleton).
--
-- Nasceu do known_gaps 25: "Jogar" com uma corrida salva sobrescrevia o save
-- sem perguntar — um clique distraído no menu apagava horas de run. O StS
-- tem slot único também, mas CONFIRMA. Daí uma peça reutilizável em vez de
-- outra confirmação embutida numa tela (a do PauseMenu é inline na row).
--
-- Uso:
--   ConfirmDialog.show({
--       title   = I18n.t("confirm.new_run_title"),
--       body    = I18n.t("confirm.new_run_body"),
--       confirm = I18n.t("confirm.new_run_yes"),
--       cancel  = I18n.t("common.back"),
--       danger  = true,                 -- botão de confirmar vermelho
--       onConfirm = function() ... end,
--       onCancel  = function() ... end, -- opcional
--   })
--
-- É registrado no InputFocus (main.lua) como MODAL: engole mouse/teclado/
-- roda e apaga o hover de trás. ESC = cancelar, ENTER = confirmar.
-- Layout recalculado em show() e resize() (memory/resize_pattern.md) — a
-- altura do painel vem do wrap REAL do corpo, nunca de constante.

local Button      = require("components.Button")
local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiPanel     = require("src.ui.UiPanel")
local Sfx         = require("src.systems.Sfx")

local ConfirmDialog = {}
ConfirmDialog.__index = ConfirmDialog

local PAD      = 24
local BTN_H    = 34
local BTN_GAP  = 14
local TITLE_GAP = 14
local BODY_GAP  = 20

local state = {
    visible = false,
    opts = nil,
    panel = nil,
    buttons = {},
    bodyLines = {},
}

local function fitFont(text, maxW, startSize, minSize)
    local size = startSize
    while size > minSize do
        local f = FontManager.getFont(size)
        if f:getWidth(text) <= maxW then return f end
        size = size - 1
    end
    return FontManager.getFont(minSize)
end

local function close(confirmed)
    local opts = state.opts
    state.visible = false
    state.opts = nil
    state.buttons = {}
    if not opts then return end
    if confirmed then
        if opts.onConfirm then opts.onConfirm() end
    else
        Sfx.play("menuClose")
        if opts.onCancel then opts.onCancel() end
    end
end

-- Recalcula painel, wrap do corpo e botões a partir do tamanho ATUAL da tela.
local function layout()
    local opts = state.opts
    if not opts then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local pw = math.min(520, sw - 32)
    local innerW = pw - PAD * 2

    state.titleFont = fitFont(opts.title or "", innerW, 22, 12)
    state.bodyFont = FontManager.getFont(sw < 700 and 10 or 12)
    local _, lines = state.bodyFont:getWrap(opts.body or "", innerW)
    state.bodyLines = lines
    local bodyH = #lines * state.bodyFont:getHeight() * 1.25

    local ph = PAD + state.titleFont:getHeight() + TITLE_GAP + bodyH
        + BODY_GAP + BTN_H + PAD
    ph = math.min(ph, sh - 16)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    state.panel = { x = px, y = py, w = pw, h = ph }

    local half = math.floor((innerW - BTN_GAP) / 2)
    local by = py + ph - PAD - BTN_H
    -- Sem `cancel` = AVISO: um botão só, centralizado (ESC e ENTER fecham).
    if not opts.cancel then
        local okBtn = Button:new(math.floor(px + (pw - half) / 2), by, half, BTN_H,
            opts.confirm or "", function() close(true) end, nil, 11)
        okBtn:setOnePress(true)
        state.buttons = { okBtn }
        return
    end
    -- Cancelar à ESQUERDA, confirmar à direita (ação destrutiva longe do
    -- caminho natural do olho; ENTER confirma, ESC cancela).
    local cancelBtn = Button:new(px + PAD, by, half, BTN_H,
        opts.cancel or "", function() close(false) end, nil, 11)
    local okBtn = Button:new(px + PAD + half + BTN_GAP, by, half, BTN_H,
        opts.confirm or "", function() close(true) end, nil, 11)
    if opts.danger then okBtn:setColorScheme("red") end
    okBtn:setOnePress(true)
    state.buttons = { cancelBtn, okBtn }
end

function ConfirmDialog.show(opts)
    state.opts = opts or {}
    state.visible = true
    layout()
    Sfx.play("menuOpen")
end

function ConfirmDialog.hide() close(false) end

-- Objeto registrável no InputFocus (precisa de métodos com ':').
local handle = { ownsNavigation = true }   -- navega sozinha (setas/Enter)
function handle:isVisible() return state.visible end
function handle:keypressed(key) return ConfirmDialog.keypressed(key) end
function handle:mousepressed(x, y, b) return ConfirmDialog.mousepressed(x, y, b) end
function handle:mousereleased(x, y, b) return ConfirmDialog.mousereleased(x, y, b) end
function handle:wheelmoved() return true end
function handle:hide() ConfirmDialog.hide() end
ConfirmDialog.handle = handle

function ConfirmDialog.isVisible() return state.visible end

function ConfirmDialog.resize()
    if state.visible then layout() end
end

function ConfirmDialog.update(dt)
    if not state.visible then return end
    for _, b in ipairs(state.buttons) do b:update(dt) end
end

function ConfirmDialog.draw()
    if not state.visible or not state.panel then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.66)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local p = state.panel
    UiPanel.draw(p.x, p.y, p.w, p.h)

    local opts = state.opts
    local title = opts.title or ""
    local tf = state.titleFont
    love.graphics.setFont(tf)
    local tx = math.floor(p.x + p.w / 2 - tf:getWidth(title) / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(title, tx + 1, p.y + PAD + 1)
    Palette.set(opts.danger and (Palette.BLOOD_LIGHT or Palette.AGED_GOLD_LIGHT)
        or Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, tx, p.y + PAD)

    local bf = state.bodyFont
    love.graphics.setFont(bf)
    Palette.set(Palette.PARCHMENT_LIGHT or Palette.PARCHMENT)
    local y = p.y + PAD + tf:getHeight() + TITLE_GAP
    local lh = bf:getHeight() * 1.25
    for _, line in ipairs(state.bodyLines) do
        love.graphics.print(line,
            math.floor(p.x + p.w / 2 - bf:getWidth(line) / 2), math.floor(y))
        y = y + lh
    end

    for _, b in ipairs(state.buttons) do b:draw() end
    love.graphics.setColor(1, 1, 1, 1)
end

function ConfirmDialog.mousepressed(x, y, button)
    if not state.visible then return false end
    for _, b in ipairs(state.buttons) do b:mousepressed(x, y, button) end
    return true
end

function ConfirmDialog.mousereleased(x, y, button)
    if not state.visible then return false end
    -- Cópia: o onClick fecha o diálogo e zera state.buttons no meio do loop.
    local list = { unpack(state.buttons) }
    for _, b in ipairs(list) do
        if b:mousereleased(x, y, button) then return true end
    end
    return true -- clique fora: continua aberto (não decide por acidente)
end

function ConfirmDialog.keypressed(key)
    if not state.visible then return false end
    if key == "escape" then
        close(false)
    elseif key == "return" or key == "kpenter" then
        close(true)
    end
    return true
end

-- Teste/tools: estado observável.
function ConfirmDialog._state() return state end

return ConfirmDialog
