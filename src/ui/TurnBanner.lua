-- src/ui/TurnBanner.lua
-- Banner de TURNO (clareza do ritmo): faixa full-width que desliza no
-- terço superior anunciando "SEU TURNO" / "TURNO DO INIMIGO" a cada
-- virada. v2.1 (feedback Jul/2026): a ESTRUTURA v1 (faixa + slide) era a
-- certa — a tentativa de placa central "ficou pior". O que muda da v1 é
-- só a PALETA: sai o verde/vermelho neon, entra a base de tinta sépia com
-- acento ouro envelhecido (seu turno) / sangue (inimigo) — as cores do
-- grimório (pills do fork, headers de carta).
--
-- Uso: TurnBanner.show("player"|"enemy") · update(dt) · draw()

local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")

local TurnBanner = {}

local active = nil  -- { kind, t }

-- Base de TINTA igual pros dois; só o acento (linhas/texto) muda.
local COLORS = {
    player = { band = { 0.09, 0.07, 0.05, 0.88 },
               text = { 0.92, 0.82, 0.58, 1 },     -- dourado pergaminho
               line = { 0.72, 0.58, 0.32, 1 } },   -- ouro envelhecido
    enemy  = { band = { 0.10, 0.05, 0.04, 0.88 },
               text = { 0.95, 0.58, 0.45, 1 },     -- vermelho pergaminho
               line = { 0.62, 0.20, 0.14, 1 } },   -- sangue
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

    -- faixa de tinta full-width + linhas de borda no acento do dono
    love.graphics.setColor(c.band)
    love.graphics.rectangle("fill", 0, y, sw, bandH)
    love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.9)
    love.graphics.rectangle("fill", 0, y, sw, 2)
    love.graphics.rectangle("fill", 0, y + bandH - 2, sw, 2)

    -- v2.1: losango-guarda de cada lado do texto (detalhe ourives discreto,
    -- único ornamento novo — o resto é a v1 com paleta sépia)
    local cyt = y + bandH / 2
    for side = -1, 1, 2 do
        local gx = math.floor(sw / 2 + side * (tw / 2 + 26))
        love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.95)
        love.graphics.polygon("fill", gx, cyt - 4, gx + 4, cyt,
            gx, cyt + 4, gx - 4, cyt)
    end

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
