-- src/ui/TurnBanner.lua
-- Banner de TURNO v2 (identidade grimório — Jul/2026): placa central de
-- tinta com borda e filigrana douradas (mesma receita das pills do fork /
-- headers de carta), no lugar da faixa translúcida neon full-width v1
-- ("não faz sentido com a nossa identidade visual").
-- Acento por dono do turno: SEU TURNO = ouro envelhecido; INIMIGO = sangue.
--
-- Uso: TurnBanner.show("player"|"enemy") · update(dt) · draw()

local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")

local TurnBanner = {}

local active = nil  -- { kind, t }

-- Paleta sépia (base ink igual pros dois; só o ACENTO muda)
local STYLE = {
    player = {
        border = { 0.55, 0.44, 0.24 },   -- ouro envelhecido (pill do fork)
        text   = { 0.92, 0.82, 0.58 },   -- dourado claro
        gleam  = { 1.00, 0.90, 0.55 },   -- filigrana/losango
    },
    enemy = {
        border = { 0.52, 0.16, 0.12 },   -- sangue (Palette.BLOOD família)
        text   = { 0.95, 0.60, 0.48 },   -- vermelho pergaminho
        gleam  = { 0.85, 0.30, 0.20 },
    },
}

local DUR = 1.05   -- entra 0.22 · segura 0.55 · sai 0.28

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
    local st = STYLE[active.kind] or STYLE.player
    local t = active.t

    -- envelope: desliza POUCO (placa, não trem) + fade — elegante, não neon
    local dir = (active.kind == "enemy") and 1 or -1
    local dx, alpha
    if t < 0.22 then
        local k = t / 0.22
        local e = 1 - (1 - k) * (1 - k)           -- ease-out
        dx = dir * 70 * (1 - e)
        alpha = e
    elseif t < 0.77 then
        dx, alpha = 0, 1
    else
        local k = (t - 0.77) / 0.28
        dx = -dir * 40 * k * k                     -- deriva pro lado oposto
        alpha = 1 - k * k
    end

    local text = I18n.t(active.kind == "enemy"
        and "battle.enemy_turn" or "battle.your_turn")
    local font = FontManager.getFont(20)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local fh = font:getHeight()

    local pw = tw + 56
    local ph = 38
    local px = math.floor((sw - pw) / 2 + dx)
    local py = math.floor(sh * 0.22)
    local cy = py + ph / 2

    -- FILIGRANA lateral: linha dupla dourada afinando pra fora, com losango
    -- na ponta (chrome de grimório — mesma família dos headers de carta)
    local flLen = math.min(110, sw * 0.12)
    for side = -1, 1, 2 do
        local x0 = (side < 0) and px or (px + pw)
        local x1 = x0 + side * flLen
        love.graphics.setColor(st.border[1], st.border[2], st.border[3],
            0.85 * alpha)
        love.graphics.setLineWidth(2)
        love.graphics.line(x0, cy - 3, x1, cy - 3)
        love.graphics.setColor(st.border[1], st.border[2], st.border[3],
            0.45 * alpha)
        love.graphics.line(x0, cy + 3, x1 - side * 18, cy + 3)
        -- losango na ponta da linha principal
        local d = 5
        love.graphics.setColor(st.gleam[1], st.gleam[2], st.gleam[3],
            0.95 * alpha)
        love.graphics.polygon("fill", x1 - side * d, cy - 3 - d,
            x1, cy - 3, x1 - side * d, cy - 3 + d, x1 - side * 2 * d, cy - 3)
    end
    love.graphics.setLineWidth(1)

    -- PLACA: sombra dura → fundo tinta → borda dupla (acento + fio interno)
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", px + 3, py + 3, pw, ph, 7, 7)
    love.graphics.setColor(0.09, 0.07, 0.05, 0.94 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 7, 7)
    love.graphics.setColor(st.border[1], st.border[2], st.border[3],
        0.95 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 7, 7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(st.border[1], st.border[2], st.border[3],
        0.35 * alpha)
    love.graphics.rectangle("line", px + 3, py + 3, pw - 6, ph - 6, 5, 5)

    -- losangos-guarda nos cantos superiores da placa (detalhe ourives)
    for side = -1, 1, 2 do
        local gx = (side < 0) and (px + 10) or (px + pw - 10)
        love.graphics.setColor(st.gleam[1], st.gleam[2], st.gleam[3],
            0.75 * alpha)
        love.graphics.polygon("fill", gx, cy - 2 - 3, gx + 3, cy - 2,
            gx, cy - 2 + 3, gx - 3, cy - 2)
    end

    -- TEXTO: sombra ink + corpo no acento (receita drawWithOutline)
    local tx = math.floor((sw - tw) / 2 + dx)
    local ty = py + math.floor((ph - fh) / 2)
    love.graphics.setColor(0, 0, 0, 0.75 * alpha)
    love.graphics.print(text, tx + 2, ty + 2)
    love.graphics.setColor(st.text[1], st.text[2], st.text[3], alpha)
    love.graphics.print(text, tx, ty)

    love.graphics.setColor(1, 1, 1, 1)
end

return TurnBanner
