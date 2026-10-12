-- src/ui/ClassHeroFx.lua
-- Atmosfera do emblema em FOCO na seleção de classe v4 (Out/2026). O idle
-- do próprio objeto (lâmina que brilha, orbe que flutua, gotas da adaga) mora
-- no ClassEmblem; aqui fica o AR em volta, um por classe:
--   warrior — brasas subindo da base e faíscas de aço
--   mage    — poeira arcana em órbita lenta, piscando
--   rogue   — névoa de veneno escorrendo e um brilho de lâmina que corre
-- Tudo em quadradinhos de pixel no tamanho do pixel do emblema (sem
-- partícula suave). `burst` = a classe acabou de entrar em foco.
--
--   ClassHeroFx.update(dt, classId, box)   box = { cx, cy, w, h, px }
--   ClassHeroFx.draw(alpha)
--   ClassHeroFx.burst(classId, box)

local ClassHeroFx = {}

local parts = {}
local spawnT = 0
local current

local PALETTE = {
    warrior = { { 1.0, 0.82, 0.42 }, { 1.0, 0.55, 0.20 }, { 0.80, 0.26, 0.12 } },
    mage    = { { 0.86, 0.80, 1.0 }, { 0.62, 0.50, 0.98 }, { 0.52, 0.78, 1.0 } },
    rogue   = { { 0.62, 0.80, 0.30 }, { 0.40, 0.58, 0.20 }, { 0.70, 0.12, 0.12 } },
}

local function pick(t) return t[love.math.random(#t)] end

local function spawn(classId, box)
    local r = love.math.random
    local cols = PALETTE[classId] or PALETTE.warrior
    if classId == "warrior" then
        parts[#parts + 1] = {
            x = box.cx + (r() - 0.5) * box.w * 0.8, y = box.cy + box.h * 0.45,
            vx = (r() - 0.5) * 10, vy = -(30 + r() * 40), life = 1.4 + r(), t = 0,
            col = pick(cols), sway = r() * 6.28, kind = "ember",
        }
    elseif classId == "mage" then
        local a = r() * 6.28
        local rr = box.w * (0.45 + r() * 0.25)
        parts[#parts + 1] = {
            a = a, rr = rr, spin = (r() < 0.5 and -1 or 1) * (0.25 + r() * 0.35),
            yk = 0.35 + r() * 0.25, life = 2.2 + r() * 1.6, t = 0,
            col = pick(cols), kind = "mote", tw = r() * 6.28,
        }
    else
        parts[#parts + 1] = {
            x = box.cx + (r() - 0.5) * box.w * 0.5, y = box.cy + box.h * (0.15 + r() * 0.3),
            vx = (r() - 0.5) * 6, vy = 8 + r() * 10, life = 1.8 + r(), t = 0,
            col = pick({ cols[1], cols[2] }), kind = "mist",
        }
    end
end

function ClassHeroFx.reset()
    parts, spawnT, current = {}, 0, nil
end

function ClassHeroFx.burst(classId, box)
    local cols = PALETTE[classId] or PALETTE.warrior
    for i = 1, 14 do
        local a = (i / 14) * 6.28 + love.math.random() * 0.3
        local sp = 60 + love.math.random() * 90
        parts[#parts + 1] = {
            x = box.cx, y = box.cy, vx = math.cos(a) * sp, vy = math.sin(a) * sp * 0.7,
            life = 0.45 + love.math.random() * 0.3, t = 0, col = pick(cols), kind = "burst",
        }
    end
end

function ClassHeroFx.update(dt, classId, box)
    if classId ~= current then
        -- troca de foco: o ar da classe anterior se dissipa rápido
        for _, p in ipairs(parts) do if p.kind ~= "burst" then p.life = math.min(p.life, p.t + 0.25) end end
        current = classId
    end
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    spawnT = spawnT - dt
    local rate = (classId == "mage") and 0.22 or (classId == "rogue" and 0.30 or 0.16)
    if not reduced and classId and box and spawnT <= 0 and #parts < 40 then
        spawnT = rate * (0.6 + love.math.random() * 0.8)
        spawn(classId, box)
    end
    for i = #parts, 1, -1 do
        local p = parts[i]
        p.t = p.t + dt
        if p.kind == "mote" then
            p.a = p.a + p.spin * dt
        elseif p.kind == "ember" then
            p.x = p.x + (p.vx + math.sin(p.t * 3 + p.sway) * 12) * dt
            p.y = p.y + p.vy * dt
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            if p.kind == "burst" then p.vx, p.vy = p.vx * 0.9, p.vy * 0.9 end
        end
        if p.t >= p.life then table.remove(parts, i) end
    end
    ClassHeroFx._box = box
end

function ClassHeroFx.draw(alpha)
    alpha = alpha or 1
    local box = ClassHeroFx._box
    if not box then return end
    local px = box.px or 2
    for _, p in ipairs(parts) do
        local k = p.t / p.life
        local a = (1 - k) * alpha
        local x, y = p.x, p.y
        if p.kind == "mote" then
            x = box.cx + math.cos(p.a) * p.rr
            y = box.cy - box.h * 0.08 + math.sin(p.a) * p.rr * p.yk - k * 18
            a = a * (0.45 + 0.55 * math.abs(math.sin(p.t * 3 + p.tw)))
            if math.sin(p.a) < 0 then a = a * 0.5 end   -- atrás do orbe: mais fraca
        elseif p.kind == "mist" then
            a = a * 0.6
        end
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], a)
        local s = (p.kind == "burst" or (p.kind == "ember" and k < 0.2)) and px * 2 or px
        love.graphics.rectangle("fill", math.floor(x / px) * px, math.floor(y / px) * px, s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ClassHeroFx
