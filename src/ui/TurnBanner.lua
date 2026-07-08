-- src/ui/TurnBanner.lua
-- Banner de TURNO (clareza do ritmo — Jul/2026): faixa que desliza no
-- terço superior anunciando "SEU TURNO" / "TURNO DO INIMIGO" a cada
-- virada. O jogador nunca fica em dúvida de quem age agora.
--
-- Uso: TurnBanner.show("player"|"enemy") · update(dt) · draw()

local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")

local TurnBanner = {}

local active = nil  -- { kind, t, dur }

local COLORS = {
    player = { band = { 0.10, 0.16, 0.08, 0.88 }, text = { 0.75, 0.95, 0.55, 1 },
               line = { 0.55, 0.85, 0.35, 1 } },
    enemy  = { band = { 0.16, 0.06, 0.05, 0.88 }, text = { 1.0, 0.45, 0.35, 1 },
               line = { 0.85, 0.25, 0.18, 1 } },
}

local DUR = 1.05   -- slide-in 0.22 · hold 0.55 · slide-out 0.28

function TurnBanner.show(kind)
    active = { kind = kind or "player", t = 0 }
end

function TurnBanner.update(dt)
    if not active then return end
    active.t = active.t + dt
    if active.t >= DUR then active = nil end
end

function TurnBanner.isActive() return active ~= nil end

function TurnBanner.draw()
    if not active then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local c = COLORS[active.kind] or COLORS.player
    local t = active.t

    -- progresso do slide: entra da esquerda (player) / direita (enemy)
    local x
    local dir = (active.kind == "enemy") and 1 or -1
    if t < 0.22 then
        local k = t / 0.22
        local e = 1 - (1 - k) * (1 - k)          -- ease-out
        x = dir * sw * (1 - e)
    elseif t < 0.77 then
        x = 0
    else
        local k = (t - 0.77) / 0.28
        x = -dir * sw * k * k                     -- sai pro lado oposto
    end

    local bandH = 46
    local y = math.floor(sh * 0.24)
    local text = I18n.t(active.kind == "enemy"
        and "battle.enemy_turn" or "battle.your_turn")
    local font = FontManager.getFont(22)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)

    love.graphics.push()
    love.graphics.translate(x, 0)

    -- faixa translúcida full-width + linhas de borda na cor do dono do turno
    love.graphics.setColor(c.band)
    love.graphics.rectangle("fill", 0, y, sw, bandH)
    love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.9)
    love.graphics.rectangle("fill", 0, y, sw, 2)
    love.graphics.rectangle("fill", 0, y + bandH - 2, sw, 2)

    -- texto central com sombra
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(text, math.floor((sw - tw) / 2) + 2,
        y + math.floor((bandH - font:getHeight()) / 2) + 2)
    love.graphics.setColor(c.text)
    love.graphics.print(text, math.floor((sw - tw) / 2),
        y + math.floor((bandH - font:getHeight()) / 2))

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return TurnBanner
