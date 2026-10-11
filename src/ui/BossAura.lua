-- src/ui/BossAura.lua
-- Aura ASSINATURA dos chefes (Out/2026): corvos, almas, fagulhas, neve,
-- moscas, eclipse — o tema de cada chefe em volta dele. Dados em
-- src/data/boss_auras.lua; chamado SÓ pelo EnemyRenderer e SÓ com
-- enemy.isBoss.
--
-- Regras:
--   * PIXEL DA ARTE: tudo é desenhado em múltiplos inteiros do pixel do
--     sprite na tela (`scale`) e alinhado à grade dele — partícula de 1px de
--     tela ao lado de um chefe de pixel 2.6x lê como outro dialeto.
--   * PROFUNDIDADE: drawBack antes do sprite, drawFront depois. Órbita usa o
--     seno do ângulo (metade de baixo = mais perto = na frente).
--   * reducedMotion tira MOVIMENTO (órbita congela, emissor para, coroa e
--     círculo não giram) e mantém INFORMAÇÃO (brilhos, círculo, coroa).
--   * Chefe sem entrada nos dados AVISA uma vez (sem fallback mudo).
--   * Barato: só retângulos + um sprite de brilho 16x16 posterizado.

local AURAS = require("src.data.boss_auras")

local BossAura = {}

local warned = {}
local state = {}           -- [id] = { t, parts = {back={}, front={}}, timers }
local glowImg = nil
local edgeCache = {}       -- [id] = { left = {[row]=x}, right = {...}, h }

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

function BossAura.has(id)
    return AURAS[id] ~= nil
end

function BossAura.get(id)
    local a = AURAS[id]
    if not a and id and not warned[id] then
        warned[id] = true
        print("[BossAura] AVISO: chefe sem aura declarada: " .. tostring(id)
            .. " (src/data/boss_auras.lua)")
    end
    return a
end

-- Brilho posterizado (4 degraus), filtro nearest: luz em pixel art é
-- anel, não degradê liso — mesma linguagem do light_dither.
local function getGlow()
    if glowImg then return glowImg end
    local n = 16
    local data = love.image.newImageData(n, n)
    local steps = { 0.55, 0.32, 0.16, 0.06 }
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local dx, dy = (x + 0.5 - n / 2) / (n / 2), (y + 0.5 - n / 2) / (n / 2)
            local d = math.sqrt(dx * dx + dy * dy)
            local a = 0
            if d < 0.30 then a = steps[1]
            elseif d < 0.55 then a = steps[2]
            elseif d < 0.80 then a = steps[3]
            elseif d < 1.00 then a = steps[4] end
            data:setPixel(x, y, 1, 1, 1, a)
        end
    end
    glowImg = love.graphics.newImage(data)
    glowImg:setFilter("nearest", "nearest")
    return glowImg
end

local function rnd(range)
    if type(range) ~= "table" then return range or 0 end
    return range[1] + love.math.random() * (range[2] - range[1])
end

local function getState(id)
    local s = state[id]
    if not s then
        s = { t = 0, back = {}, front = {}, acc = {}, timers = {}, fade = 1 }
        state[id] = s
    end
    return s
end

-- Borda externa da silhueta por linha (quadro 0 do idle), pro brilho que
-- corre pelas asas. Pixels da arte.
local function edges(id)
    if edgeCache[id] ~= nil then return edgeCache[id] end
    local path = "assets/sprites/characters/enemies/" .. id
        .. "/animations/idle/south/0.png"
    local e = false
    if love.filesystem.getInfo(path) then
        local ok, data = pcall(love.image.newImageData, path)
        if ok and data then
            e = { left = {}, right = {}, w = data:getWidth(), h = data:getHeight() }
            for y = 0, e.h - 1 do
                for x = 0, e.w - 1 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.5 then e.left[y] = x; break end
                end
                for x = e.w - 1, 0, -1 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.5 then e.right[y] = x; break end
                end
            end
        end
    end
    if not e then
        print("[BossAura] AVISO: sem quadro 0 do idle pra borda de " .. id)
    end
    edgeCache[id] = e
    return e
end

function BossAura.reset()
    state = {}
end

-- ---------------------------------------------------------------------------
-- UPDATE: emissores + vida das partículas. `id` = chefe na tela (ou nil).
-- dying = clip de death tocando: para de emitir e esvai em 0.6s.
-- ---------------------------------------------------------------------------
function BossAura.update(dt, id, dying)
    if not id then return end
    local spec = AURAS[id]
    if not spec then return end
    local s = getState(id)
    s.t = s.t + dt
    if dying then
        s.fade = math.max(0, s.fade - dt / 0.6)
    else
        s.fade = math.min(1, s.fade + dt / 0.4)
    end

    local still = reducedMotion()
    if not still and not dying and spec.emit then
        for i, em in ipairs(spec.emit) do
            local n = 0
            if em.every then
                s.timers[i] = (s.timers[i] or (em.every * 0.5)) - dt
                if s.timers[i] <= 0 then
                    s.timers[i] = em.every
                    n = em.burst or 1
                end
            else
                s.acc[i] = (s.acc[i] or 0) + dt * (em.rate or 1)
                n = math.floor(s.acc[i])
                s.acc[i] = s.acc[i] - n
            end
            for _ = 1, n do
                local u, v
                if em.points then
                    local p = em.points[love.math.random(#em.points)]
                    u, v = p[1], p[2]
                else
                    local ar = em.area
                    u = ar[1] + love.math.random() * (ar[3] - ar[1])
                    v = ar[2] + love.math.random() * (ar[4] - ar[2])
                end
                local life = rnd(em.life or { 1, 2 })
                local list = em.back and s.back or s.front
                if #list < 90 then
                    list[#list + 1] = {
                        em = em, u = u, v = v, ax = 0, ay = 0,
                        vx = rnd(em.vx), vy = rnd(em.vy),
                        life = life, max = life,
                        ph = love.math.random() * 6.283,
                        big = love.math.random() < (em.big or 0),
                        landed = false,
                    }
                end
            end
        end
    end

    for _, list in ipairs({ s.back, s.front }) do
        for i = #list, 1, -1 do
            local p = list[i]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(list, i)
            elseif not still then
                local em = p.em
                if em.kind == "drip" then
                    if not p.landed then
                        p.vy = p.vy + (em.gravity or 60) * dt
                        p.ay = p.ay + p.vy * dt
                        -- pousa no CHÃO da cena (linha medida no último
                        -- draw, em pixels da arte) e vira poça
                        local g = s.groundArt
                        if g and p.v * (s.ih or 0) + p.ay >= g - 1 then
                            p.landed = true
                            p.ay = g - 1 - p.v * s.ih
                            p.life = math.min(p.life, 0.6)
                        end
                    end
                else
                    p.ax = p.ax + p.vx * dt
                    p.ay = p.ay + p.vy * dt
                    if em.kind == "breath" or em.kind == "smoke" then
                        p.vx = p.vx * (1 - 0.9 * dt)
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- DESENHO
-- r = { x, y, w, h, iw, ih, scale, groundY, cx }
-- ---------------------------------------------------------------------------
local floor = math.floor

-- BLOCO: a partícula/corpo corrente desenha com pixels de K x K pixels da
-- arte, ampliada em torno da âncora (KX, KY). Um chefe a 2x na tela tem
-- pixel da arte de ~2px — corvo de 7 pixels da arte virava cisco. K=2 dobra
-- o desenho e continua na grade da arte (múltiplo inteiro, mesmo dialeto).
local KX, KY, K = 0, 0, 1
local function setK(ax, ay, k)
    KX, KY, K = ax, ay, k or 1
end

-- retângulo de n x m pixels da ARTE na posição de arte (ax, ay)
local function artRect(r, ax, ay, nw, nh)
    if K ~= 1 then
        ax = KX + (ax - KX) * K
        ay = KY + (ay - KY) * K
        nw = (nw or 1) * K
        nh = (nh or 1) * K
    end
    local P = r.scale
    local x = r.x + floor(ax + 0.5) * P
    local y = r.y + floor(ay + 0.5) * P
    love.graphics.rectangle("fill", floor(x), floor(y),
        math.ceil(P * (nw or 1)), math.ceil(P * (nh or 1)))
end

local function drawGlows(r, spec, s, fade)
    if not spec.glows then return end
    local img = getGlow()
    local t = s.t
    local still = reducedMotion()
    love.graphics.setBlendMode("add")
    for i, g in ipairs(spec.glows) do
        local k = 1
        if g.beat then
            -- tum-tum: duas pancadas e pausa, período `beat` segundos
            local ph = (t % g.beat) / g.beat
            local b1 = math.max(0, 1 - math.abs(ph - 0.10) / 0.08)
            local b2 = math.max(0, 1 - math.abs(ph - 0.30) / 0.08)
            k = 0.55 + 0.6 * math.max(b1, b2 * 0.75)
        elseif g.pulse and not still then
            k = 0.78 + 0.22 * math.sin(t * g.pulse + i)
        end
        local a = (g.a or 0.4) * k * fade
        local rad = (g.r or 4) * r.scale * (0.92 + 0.08 * k)
        local x = r.x + g.u * r.w
        local y = r.y + g.v * r.h
        local sc = (rad * 2) / img:getWidth()
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], a)
        love.graphics.draw(img, floor(x - rad), floor(y - rad), 0, sc, sc)
    end
    love.graphics.setBlendMode("alpha")
end

-- Corvo de 7x3 pixels da arte, batida de asa em 3 quadros (asa em cima /
-- planando / asa embaixo). O 3º valor marca o pixel de BRILHO (pena de
-- corvo tem reflexo azul-violeta — sem ele o corvo some no fundo escuro).
local CROW = {
    { { -3, -2, 1 }, { 3, -2, 1 }, { -2, -1 }, { 2, -1 }, { -1, 0 }, { 0, 0 },
      { 1, 0 }, { 0, -1 }, { 0, 1 } },
    { { -3, 0, 1 }, { -2, 0 }, { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 },
      { 3, 0, 1 }, { 0, -1 }, { 0, 1 } },
    { { -3, 1 }, { 3, 1 }, { -2, 0, 1 }, { 2, 0, 1 }, { -1, 0 }, { 0, 0 },
      { 1, 0 }, { 0, -1 }, { 0, 1 } },
}
local CROW_SEQ = { 1, 2, 3, 2 }

-- Runa flutuante 3x3 (quatro glifos alternando).
local RUNES = {
    { { 0, -1 }, { 0, 0 }, { 0, 1 }, { -1, -1 }, { 1, 1 } },
    { { -1, -1 }, { 1, -1 }, { 0, 0 }, { -1, 1 }, { 1, 1 } },
    { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 0, 0 }, { 0, 1 } },
    { { -1, 0 }, { 0, -1 }, { 1, 0 }, { 0, 1 }, { 0, 0 } },
}

local function orbitOne(r, o, s, front)
    local still = reducedMotion()
    local t = still and 0 or s.t
    local fade = s.fade
    for i = 1, o.n do
        local base = (i - 1) / o.n * 6.283
        local ang = base + t * o.speed * ((o.kind == "fly") and (0.8 + 0.1 * i) or 1)
        local sn = math.sin(ang)
        local isFront = sn > 0
        if isFront == front then
            local cu, cv = o.cu, o.cv
            local ru, rv = o.ru, o.rv
            local u, v
            if o.kind == "fly" then
                -- Lissajous + tremido: mosca não faz órbita limpa
                u = cu + ru * math.cos(ang) * (0.6 + 0.4 * math.sin(t * 1.7 + i))
                v = cv + rv * math.sin(ang * 1.6 + i)
                if not still then
                    u = u + (love.math.random() - 0.5) * 0.012
                    v = v + (love.math.random() - 0.5) * 0.012
                end
            elseif o.kind == "flake" then
                -- redemoinho: cada floco sobe devagar e volta pro pé
                local rise = ((t * (o.rise or 0.05) + i * 0.137) % 1)
                v = cv + 0.40 - rise * 0.85 + rv * sn
                u = cu + ru * math.cos(ang) * (0.75 + 0.25 * rise)
            else
                u = cu + ru * math.cos(ang)
                v = cv + rv * sn
            end
            local ax, ay = u * r.iw, v * r.ih
            local near = isFront and 1 or 0.6
            setK(ax, ay, o.px or 1)
            if o.kind == "crow" then
                local fr = CROW[CROW_SEQ[(floor(t * 7 + i * 1.7) % 4) + 1]]
                local c = o.color
                local hi = o.color2
                local al = fade * (isFront and 1 or 0.75)
                for _, d in ipairs(fr) do
                    local cc = d[3] and hi or c
                    love.graphics.setColor(cc[1], cc[2], cc[3], al)
                    artRect(r, ax + d[1], ay + d[2], 1, 1)
                end
            elseif o.kind == "rune" then
                local g = RUNES[(i - 1) % #RUNES + 1]
                local c = isFront and o.color or o.color2
                love.graphics.setBlendMode("add")
                local pulse = still and 1 or (0.7 + 0.3 * math.sin(s.t * 2.4 + i * 1.3))
                love.graphics.setColor(c[1], c[2], c[3], fade * near * 0.9 * pulse)
                for _, d in ipairs(g) do artRect(r, ax + d[1], ay + d[2], 1, 1) end
                love.graphics.setColor(c[1], c[2], c[3], fade * near * 0.25 * pulse)
                artRect(r, ax - 2, ay - 2, 5, 5)
                love.graphics.setBlendMode("alpha")
            elseif o.kind == "mote" then
                local c = isFront and o.color or o.color2
                love.graphics.setBlendMode("add")
                love.graphics.setColor(c[1], c[2], c[3], 0.9 * fade * near)
                artRect(r, ax, ay, 1, 1)
                love.graphics.setColor(c[1], c[2], c[3], 0.35 * fade * near)
                artRect(r, ax - math.cos(ang) * 1.5, ay - sn * 0.8, 1, 1)
                love.graphics.setBlendMode("alpha")
            elseif o.kind == "flake" then
                local c = isFront and o.color or o.color2
                love.graphics.setColor(c[1], c[2], c[3], fade * (isFront and 0.95 or 0.55))
                if isFront and i % 3 == 0 then
                    -- floco grande em cruz (perto da câmera)
                    artRect(r, ax, ay, 1, 1)
                    love.graphics.setColor(c[1], c[2], c[3], fade * 0.55)
                    artRect(r, ax - 1, ay, 1, 1); artRect(r, ax + 1, ay, 1, 1)
                    artRect(r, ax, ay - 1, 1, 1); artRect(r, ax, ay + 1, 1, 1)
                else
                    artRect(r, ax, ay, 1, 1)
                end
            elseif o.kind == "fly" then
                local c = isFront and o.color or o.color2
                love.graphics.setColor(c[1], c[2], c[3], fade * (isFront and 1 or 0.7))
                artRect(r, ax, ay, 1, 1)
                -- asinhas claras piscando: sem elas a mosca preta some
                -- em cima do corpo escuro do colosso
                local wing = (floor(s.t * 30 + i) % 2 == 0) and -1 or 1
                love.graphics.setColor(0.82, 0.88, 0.74, 0.75 * fade)
                artRect(r, ax + wing * 0.5, ay - 1, 1, 1)
            end
        end
    end
end

local function orbitBodies(r, spec, s, front)
    setK(0, 0, 1)
    if spec.orbit then orbitOne(r, spec.orbit, s, front) end
    if spec.orbits then
        for _, o in ipairs(spec.orbits) do orbitOne(r, o, s, front) end
    end
end

local function drawParticles(r, list, fade)
    for _, p in ipairs(list) do
        setK(0, 0, 1)
        local em = p.em
        local k = p.life / p.max             -- 1 nasceu → 0 morre
        local ax = p.u * r.iw + p.ax
        local ay = p.v * r.ih + p.ay
        if em.sway then ax = ax + math.sin(p.ph + (p.max - p.life) * 2.2) * em.sway * 0.3 end
        setK(ax, ay, em.px or 1)
        local c1, c2 = em.color, em.color2 or em.color
        local mix = 1 - k
        local cr = c1[1] + (c2[1] - c1[1]) * mix
        local cg = c1[2] + (c2[2] - c1[2]) * mix
        local cb = c1[3] + (c2[3] - c1[3]) * mix
        local a = (em.a or 1) * math.min(1, k * 2.5) * math.min(1, (1 - k) * 8 + 0.2) * fade
        local kind = em.kind
        if kind == "feather" then
            love.graphics.setColor(cr, cg, cb, a)
            -- pena: 2x1 que vira 1x2 conforme balança (rodopio barato)
            if math.sin(p.ph + (p.max - p.life) * 3) > 0 then
                artRect(r, ax, ay, 2, 1)
            else
                artRect(r, ax, ay, 1, 2)
            end
            love.graphics.setColor(c2[1], c2[2], c2[3], a * 0.8)
            artRect(r, ax, ay, 1, 1)
        elseif kind == "petal" then
            love.graphics.setColor(cr, cg, cb, a)
            local f = floor(p.ph + (p.max - p.life) * 2.5) % 3
            local b = p.big and 1 or 0
            if f == 0 then artRect(r, ax, ay, 2 + b, 1)
            elseif f == 1 then artRect(r, ax, ay, 1 + b, 1 + b)
            else artRect(r, ax, ay, 1, 2 + b) end
            love.graphics.setColor(c2[1], c2[2], c2[3], a * 0.7)
            artRect(r, ax, ay, 1, 1)
        elseif kind == "wisp" or kind == "spore" or kind == "ember" or kind == "spark" then
            love.graphics.setBlendMode("add")
            if kind == "spark" and love.math.random() < 0.15 then a = a * 0.3 end
            love.graphics.setColor(cr, cg, cb, a)
            local sz = p.big and 2 or 1
            artRect(r, ax, ay, sz, sz)
            if kind == "wisp" then
                -- rastro de 2 pixels esmaecendo pra baixo
                love.graphics.setColor(cr, cg, cb, a * 0.45)
                artRect(r, ax, ay + 1, 1, 1)
                love.graphics.setColor(cr, cg, cb, a * 0.2)
                artRect(r, ax, ay + 2, 1, 1)
            end
            love.graphics.setBlendMode("alpha")
        elseif kind == "smoke" or kind == "breath" then
            local n = (kind == "breath") and (1 + floor((1 - k) * 2.5)) or (2 + floor((1 - k) * 2))
            love.graphics.setColor(cr, cg, cb, a * 0.8)
            artRect(r, ax - n / 2, ay - n / 2 + 0.5, n, math.max(1, n - 1))
        elseif kind == "sparkle" then
            love.graphics.setBlendMode("add")
            local n = (k > 0.5) and 2 or 1
            love.graphics.setColor(cr, cg, cb, a)
            artRect(r, ax, ay, 1, 1)
            for d = 1, n do
                artRect(r, ax + d, ay, 1, 1); artRect(r, ax - d, ay, 1, 1)
                artRect(r, ax, ay + d, 1, 1); artRect(r, ax, ay - d, 1, 1)
            end
            love.graphics.setBlendMode("alpha")
        elseif kind == "drip" then
            if p.landed then
                -- poça respingando: 3 px que abrem e somem
                love.graphics.setColor(cr, cg, cb, a * 0.85)
                artRect(r, ax - 1, ay, 3, 1)
                if k > 0.15 then
                    artRect(r, ax - 2, ay - 1, 1, 1)
                    artRect(r, ax + 2, ay - 1, 1, 1)
                end
            else
                love.graphics.setColor(cr, cg, cb, a)
                artRect(r, ax, ay, p.big and 2 or 1, (p.vy > 20) and 3 or 2)
            end
        end
    end
end

-- Círculo rúnico no chão (elipse pontilhada que gira + marcas de runa).
local function drawFloor(r, spec, s)
    local f = spec.floor
    if not f then return end
    local still = reducedMotion()
    local t = s.t
    local rx = f.ru * r.iw
    local ry = f.rv * r.iw
    local cxArt = (r.cx - r.x) / r.scale
    local cyArt = (r.groundY - r.y) / r.scale
    local rot = still and 0 or t * f.speed
    local pulse = still and 1 or (0.75 + 0.25 * math.sin(t * 1.3))
    local a = f.a * s.fade * pulse
    love.graphics.setBlendMode("add")
    local n = 44
    for i = 0, n - 1 do
        local ang = i / n * 6.283 + rot
        local c = (i % 11 == 0) and f.color2 or f.color
        love.graphics.setColor(c[1], c[2], c[3], a * ((i % 2 == 0) and 1 or 0.45))
        artRect(r, cxArt + math.cos(ang) * rx, cyArt + math.sin(ang) * ry, 1, 1)
        -- runas: traço radial a cada 11 pontos
        if i % 11 == 0 then
            artRect(r, cxArt + math.cos(ang) * rx * 0.86, cyArt + math.sin(ang) * ry * 0.86, 1, 1)
        end
    end
    -- anel interno contra-rotativo, mais fraco
    for i = 0, 27 do
        local ang = i / 28 * 6.283 - rot * 1.4
        love.graphics.setColor(f.color2[1], f.color2[2], f.color2[3], a * 0.4)
        if i % 3 ~= 0 then
            artRect(r, cxArt + math.cos(ang) * rx * 0.62, cyArt + math.sin(ang) * ry * 0.62, 1, 1)
        end
    end
    love.graphics.setBlendMode("alpha")
end

-- Eclipse: disco escuro + coroa de raios que gira, atrás da cabeça.
local function drawCorona(r, spec, s)
    local c = spec.corona
    if not c then return end
    local still = reducedMotion()
    local t = s.t
    local cxA, cyA = c.u * r.iw, c.v * r.ih
    local R = c.r
    local fade = s.fade
    -- raios: 24 setores, comprimento oscilando, girando devagar. Mistura
    -- NORMAL, não aditiva: a sala 6 é um feixe de luz BRANCA — luz somada
    -- em branco some; cor pintada por cima lê.
    local rot = still and 0 or t * c.speed
    for i = 0, 23 do
        local ang = i / 24 * 6.283 + rot
        local len = 3 + 3 * (0.5 + 0.5 * math.sin(i * 2.1 + (still and 0 or t * 1.3)))
        for d = 0, floor(len) do
            local k = d / (len + 1)
            local col = (d < 2) and c.color or c.color2
            love.graphics.setColor(col[1], col[2], col[3], (0.55 - 0.45 * k) * fade)
            artRect(r, cxA + math.cos(ang) * (R + d), cyA + math.sin(ang) * (R + d), 1, 1)
        end
    end
    -- anel de luz colado no disco
    for i = 0, 71 do
        local ang = i / 72 * 6.283
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.85 * fade)
        artRect(r, cxA + math.cos(ang) * R, cyA + math.sin(ang) * R, 1, 1)
    end
    -- disco (lua cobrindo o sol): uma linha por pixel da arte, OPACA —
    -- linhas translúcidas se sobrepõem no arredondamento e listram o disco
    love.graphics.setColor(c.dark[1], c.dark[2], c.dark[3], fade)
    for dy = -R + 1, R - 1 do
        local half = floor(math.sqrt(math.max(0, (R - 0.6) ^ 2 - dy * dy)) + 0.5)
        artRect(r, cxA - half, cyA + dy, half * 2, 1)
    end
end

-- Brilho correndo pela borda externa da silhueta (dos dois lados).
local function drawGlint(r, spec, s)
    local g = spec.glint
    if not g or reducedMotion() then return end
    local e = edges(r.id)
    if not e then return end
    local ph = (s.t % g.period) / g.period
    if ph > 0.6 then return end
    local k = ph / 0.6
    local row0 = floor((g.v0 + (g.v1 - g.v0) * k) * e.h)
    love.graphics.setBlendMode("add")
    for d = 0, 4 do
        local row = row0 - d
        local a = (1 - d / 5) * 0.9 * s.fade * math.sin(k * math.pi)
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], a)
        if e.left[row] then artRect(r, e.left[row] + 1, row, 1, 1) end
        if e.right[row] then artRect(r, e.right[row] - 1, row, 1, 1) end
    end
    love.graphics.setBlendMode("alpha")
end

function BossAura.drawBack(id, r)
    local spec = BossAura.get(id)
    if not spec then return end
    local s = getState(id)
    if s.fade <= 0 then return end
    r.id = id
    -- chão em pixels da arte, pro update pousar as gotas
    s.groundArt = (r.groundY - r.y) / r.scale
    s.ih = r.ih
    love.graphics.push("all")
    drawFloor(r, spec, s)
    drawCorona(r, spec, s)
    orbitBodies(r, spec, s, false)
    drawParticles(r, s.back, s.fade)
    setK(0, 0, 1)
    love.graphics.pop()
end

function BossAura.drawFront(id, r)
    local spec = AURAS[id]
    if not spec then return end
    local s = getState(id)
    if s.fade <= 0 then return end
    r.id = id
    love.graphics.push("all")
    drawGlows(r, spec, s, s.fade)
    drawGlint(r, spec, s)
    orbitBodies(r, spec, s, true)
    drawParticles(r, s.front, s.fade)
    setK(0, 0, 1)
    love.graphics.pop()
end

-- CONTORNO DE CHEFE: a silhueta do quadro atual, na cor do tema, 1 pixel
-- da arte pra fora nas 4 direções, atrás do corpo. É o "este é o chefe"
-- que se lê de longe, mesmo com o fundo da sala brigando (fornalha laranja
-- atrás do tirano, feixe branco atrás da rainha). drawFn(x, y, tint)
-- desenha o quadro corrente com o shader de silhueta ativo.
local rimShader = nil
local function getRimShader()
    if rimShader ~= nil then return rimShader end
    local ok, sh = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            float a = Texel(tex, uv).a;
            return vec4(color.rgb, color.a * step(0.1, a));
        }
    ]])
    if not ok then
        print("[BossAura] AVISO: shader de contorno não compilou: " .. tostring(sh))
        sh = false
    end
    rimShader = sh
    return rimShader
end

function BossAura.drawRim(id, r, drawFn)
    local spec = AURAS[id]
    if not spec or not spec.rim then return end
    local s = getState(id)
    if s.fade <= 0 then return end
    local sh = getRimShader()
    if not sh then return end
    local rim = spec.rim
    local k = 1
    if rim.pulse and not reducedMotion() then
        k = 0.7 + 0.3 * math.sin(s.t * rim.pulse)
    end
    local P = math.max(1, floor(r.scale + 0.5))
    love.graphics.push("all")
    love.graphics.setShader(sh)
    -- a cor vai como TINT: o SpriteAnimation:draw reseta o setColor pra
    -- branco no fim de cada quadro desenhado
    local col = { rim.color[1], rim.color[2], rim.color[3],
                  (rim.a or 0.5) * k * s.fade }
    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        drawFn(r.x + d[1] * P, r.y + d[2] * P, col)
    end
    love.graphics.pop()
end

-- Testes: contagem de partículas vivas (o emissor emite e o morto para).
function BossAura._debugCount(id)
    local s = state[id]
    if not s then return 0 end
    return #s.back + #s.front, s.fade
end

return BossAura
