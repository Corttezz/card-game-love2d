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
local DissolveShader = require("src.ui.DissolveShader")

local TurnBanner = {}

local active = nil  -- { kind, t }
local canvasCache = {}   -- key kind..w -> canvas (faixa pré-renderizada)

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
    -- pré-renderiza o canvas AQUI (update, fora do frame de draw): criar
    -- canvas no meio do love.draw — dentro da cena CRT / com scissor do
    -- WorldRoad vivo — corrompia o conteúdo (artefatos no topo da tela)
    TurnBanner._ensureCanvas(active.kind)
end

function TurnBanner.update(dt)
    if not active then return end
    active.t = active.t + dt
    if active.t >= DUR then active = nil end
end

function TurnBanner.isActive() return active ~= nil end

local BAND_H = 46

-- Renderiza a faixa COMPLETA (fundo + linhas + losangos + texto) num canvas
-- full-width — o dissolve queima o conjunto como uma coisa só (igual carta).
local function bandCanvas(kind, sw)
    local key = kind .. sw
    if canvasCache[key] then return canvasCache[key] end
    -- scissor herdado do frame recortaria o clear/draw do canvas (o glClear
    -- RESPEITA scissor) — desliga durante o render off-screen
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    love.graphics.setScissor()
    local c = COLORS[kind] or COLORS.player
    local text = I18n.t(kind == "enemy"
        and "battle.enemy_turn" or "battle.your_turn")
    local font = FontManager.getFont(22)
    local canvas = love.graphics.newCanvas(sw, BAND_H)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setColor(c.band)
    love.graphics.rectangle("fill", 0, 0, sw, BAND_H)
    love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.9)
    love.graphics.rectangle("fill", 0, 0, sw, 2)
    love.graphics.rectangle("fill", 0, BAND_H - 2, sw, 2)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    -- losango-guarda de cada lado do texto (detalhe ourives discreto)
    local cyt = BAND_H / 2
    for side = -1, 1, 2 do
        local gx = math.floor(sw / 2 + side * (tw / 2 + 26))
        love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.95)
        love.graphics.polygon("fill", gx, cyt - 4, gx + 4, cyt,
            gx, cyt + 4, gx - 4, cyt)
    end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(text, math.floor((sw - tw) / 2) + 2,
        math.floor((BAND_H - font:getHeight()) / 2) + 2)
    love.graphics.setColor(c.text)
    love.graphics.print(text, math.floor((sw - tw) / 2),
        math.floor((BAND_H - font:getHeight()) / 2))
    love.graphics.setCanvas()
    love.graphics.pop()
    if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) end
    canvasCache[key] = canvas
    return canvas
end

-- Pré-render (chamado pelo show(), fora do frame de draw)
function TurnBanner._ensureCanvas(kind)
    bandCanvas(kind, love.graphics.getWidth())
end

-- Chamas do dissolve por dono do turno (mesma linguagem das cartas)
local BURN = {
    player = { { 1.00, 0.85, 0.35, 1.0 }, { 0.85, 0.55, 0.15, 1.0 } }, -- ouro
    enemy  = { { 0.85, 0.20, 0.10, 1.0 }, { 1.00, 0.50, 0.10, 1.0 } }, -- fogo
}

function TurnBanner.draw()
    if not active then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local t = active.t

    -- v2.2 (feedback: "deslizar com o quadrado faltando é estranho — usa a
    -- animação das cartas"): a faixa fica PARADA e MATERIALIZA/DISSOLVE com
    -- o shader de queima das cartas (Balatro). Envelope:
    --   0.00–0.30 materialize (dissolve 1→0) · hold · 0.75–1.05 dissolve 0→1
    local dissolve
    if t < 0.30 then
        local k = t / 0.30
        dissolve = 1 - k * k * (3 - 2 * k)        -- smoothstep invertido
    elseif t < 0.75 then
        dissolve = 0
    else
        local k = math.min(1, (t - 0.75) / 0.30)
        dissolve = k * k * (3 - 2 * k)
    end

    -- lazy-load do shader (contextos que não passam pelo love.load completo
    -- — ferramentas de screenshot — caíam no fallback de fade silencioso)
    if not DissolveShader.isAvailable() and not TurnBanner._shaderTried then
        TurnBanner._shaderTried = true
        DissolveShader.load()
    end

    local canvas = bandCanvas(active.kind, sw)
    local y = math.floor(sh * 0.24)
    love.graphics.setColor(1, 1, 1, 1)
    -- noise anisotrópico: célula ~quadrada em pixels na faixa full-width
    -- (sem isso a queima estica em "faixas fantasmas")
    local ns = { 5.5 * sw / BAND_H, 5.5 }
    if not DissolveShader.apply(canvas, dissolve, BURN[active.kind], false, ns) then
        -- fallback sem shader: fade simples
        love.graphics.setColor(1, 1, 1, 1 - dissolve)
    end
    -- scissor-guard: por construção NADA pinta fora do retângulo da faixa
    -- (blindagem contra o artefato de topo visto na validação)
    local gx0, gy0, gw0, gh0 = love.graphics.getScissor()
    love.graphics.setScissor(0, y, sw, BAND_H)
    love.graphics.draw(canvas, 0, y)
    love.graphics.setScissor(gx0, gy0, gw0, gh0)
    DissolveShader.clear()
    love.graphics.setColor(1, 1, 1, 1)
end

return TurnBanner
