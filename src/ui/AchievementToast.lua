-- src/ui/AchievementToast.lua
-- Aviso de conquista desbloqueada, desenhado por cima de QUALQUER estado
-- (main.lua chama update/draw no fim do frame, abaixo so do cursor).
--
-- Antes era uma linha no MessageSystem ("CONQUISTA: X!") misturada com os
-- toasts de combate. Agora e um cartao proprio, no idioma escuro-dourado
-- (UiPanel), com o EMBLEMA da conquista — o momento tem identidade:
--   desce do topo (backOut) → emblema "carimba" (escala 1.35 → 1) com um aro
--   de luz → um brilho atravessa o cartao → segura → sobe.
-- Fila: varias conquistas no mesmo frame (comum na vitoria) aparecem uma
-- por vez, nunca empilhadas por cima uma da outra.
--
-- reducedMotion remove MOVIMENTO, nunca INFORMACAO: sem descida/carimbo, o
-- cartao aparece parado e some com fade.

local Easing = require("engine.Easing")
local Palette = require("src.ui.Palette")

local AchievementToast = {}

AchievementToast.IN = 0.45
AchievementToast.HOLD = 3.4
AchievementToast.OUT = 0.35

local queue = {}
local current = nil

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

function AchievementToast.push(entry)
    table.insert(queue, entry)
end

function AchievementToast.isBusy()
    return current ~= nil or #queue > 0
end

function AchievementToast.pending() return #queue + (current and 1 or 0) end

function AchievementToast.clear()
    queue = {}
    current = nil
end

local function total()
    return AchievementToast.IN + AchievementToast.HOLD + AchievementToast.OUT
end

function AchievementToast.update(dt)
    if not current then
        if #queue == 0 then return end
        current = table.remove(queue, 1)
        current.t = 0
    end
    current.t = current.t + dt
    if current.t >= total() then current = nil end
end

-- Geometria (pura, testavel): retangulo do cartao para a janela atual.
function AchievementToast.rect(sw, sh)
    local w = math.min(460, math.floor(sw - 32))
    local h = 84
    local x = math.floor((sw - w) / 2)
    local y = 60   -- abaixo da TopBar (52) + respiro
    if sh < 420 then y = 8 end
    return x, y, w, h
end

function AchievementToast.draw()
    local c = current
    if not c then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local x, y, w, h = AchievementToast.rect(sw, sh)
    local t = c.t
    local rm = reducedMotion()

    -- Entrada / saida.
    local alpha, dy = 1, 0
    if t < AchievementToast.IN then
        local k = t / AchievementToast.IN
        if rm then alpha = k else dy = -(1 - Easing.backOut(k)) * (h + y + 10) end
    elseif t > AchievementToast.IN + AchievementToast.HOLD then
        local k = (t - AchievementToast.IN - AchievementToast.HOLD) / AchievementToast.OUT
        alpha = 1 - k
        if not rm then dy = -Easing.easeIn(k) * 24 end
    end
    y = math.floor(y + dy)

    love.graphics.push("all")
    -- Cartao (gramatica UiPanel com alpha).
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", x + 4, y + 4, w, h, 6, 6)
    love.graphics.setColor(0.10, 0.07, 0.05, 0.96 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    local g = Palette.AGED_GOLD
    love.graphics.setColor(g[1], g[2], g[3], alpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    local gd = Palette.AGED_GOLD_DARK
    love.graphics.setColor(gd[1], gd[2], gd[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 4, y + 4, w - 8, h - 8, 4, 4)

    -- Brilho que atravessa o cartao uma vez (logo depois do carimbo).
    local sweepT = (t - AchievementToast.IN) / 0.7
    if not rm and sweepT > 0 and sweepT < 1 then
        love.graphics.setScissor(x, y, w, h)
        local bx = x - 60 + (w + 120) * sweepT
        love.graphics.setColor(1, 0.92, 0.7, 0.16 * alpha)
        love.graphics.polygon("fill", bx, y, bx + 26, y, bx - 4, y + h, bx - 30, y + h)
        love.graphics.setScissor()
    end

    -- Emblema "carimbado".
    local icon = 64   -- 1:1 com o PNG (pixel nitido)
    local ex, ey = x + 14 + icon / 2, y + h / 2
    local stamp = 1
    if not rm and t < AchievementToast.IN + 0.25 then
        local k = math.min(1, math.max(0, (t - AchievementToast.IN * 0.6) / 0.35))
        stamp = 1.35 - 0.35 * Easing.backOut(k)
    end
    -- aro de luz que expande no carimbo
    local ringK = (t - AchievementToast.IN * 0.6) / 0.6
    if not rm and ringK > 0 and ringK < 1 then
        local gl = Palette.AGED_GOLD_LIGHT
        love.graphics.setColor(gl[1], gl[2], gl[3], (1 - ringK) * 0.8 * alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", ex, ey, icon * 0.5 + ringK * 26)
    end
    require("src.ui.AchievementIcons").draw(c.id, false, ex, ey, icon * stamp, alpha)

    -- Texto: rotulo + nome (+ descricao curta).
    local I18n = require("src.i18n.I18n")
    local TextFit = require("src.ui.TextFit")
    local tx = x + 14 + icon + 14
    local tw = w - (tx - x) - 14
    local gl = Palette.AGED_GOLD_LIGHT
    love.graphics.setColor(gl[1], gl[2], gl[3], alpha)
    TextFit.print(I18n.t("achievements.toast_label", nil, "CONQUISTA DESBLOQUEADA"),
        tx, y + 14, { size = 8, maxW = tw })
    local pl = Palette.PARCHMENT_LIGHT
    love.graphics.setColor(pl[1], pl[2], pl[3], alpha)
    TextFit.print(c.name or c.id, tx, y + 30, { size = 14, maxW = tw, minSize = 9 })
    local pa = Palette.PARCHMENT
    love.graphics.setColor(pa[1], pa[2], pa[3], alpha * 0.9)
    TextFit.print(c.desc or "", tx, y + 56, { size = 8, maxW = tw })

    love.graphics.pop()
end

-- Testes: estado atual.
function AchievementToast._current() return current end

return AchievementToast
