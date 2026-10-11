-- src/ui/InteriorFX.lua
-- Atmosfera dos salões de chefe (castle_hall_1..6) — o CLÍMAX de cada ato.
--
-- v2 (Out/2026, dono: "remove todas essas bolas de luz das salas de chefe").
-- A v1 desenhava DISCOS translúcidos chapados em posições RELATIVAS À TELA:
-- calibradas no corte 4:3, em 16:9 caíam fora das chamas (no hall 2 o disco
-- pousava na parede escura ao lado do candelabro; no 4 ficava ao lado do
-- braseiro). E o update rodava com `math.min(3, ato)` enquanto o draw usava
-- o salão real: nos atos 4-6 as brasas nasciam nas posições da LAVA do
-- hall 3 — as "veias esquisitas" saindo do nada.
--
-- Regras da v2:
--   * TUDO em coordenadas da ARTE (pixels da PNG 400×256), convertido pelo
--     MESMO cover-fit do SceneBackground. Âncora vem do que está pintado e
--     acompanha a pintura em qualquer aspecto de janela.
--   * Nenhum disco. A luz da chama é a PRÓPRIA chama pintada redesenhada em
--     modo aditivo com flicker (quad da arte): o brilho tem o formato exato
--     do fogo e nunca vira bola.
--   * Partícula = 1 pixel DA ARTE (posição truncada na grade da PNG, lado =
--     escala do cover-fit). Lê como parte da pintura, não como overlay.
--   * Profundidade: `draw` vem logo depois do fundo (névoa no chão, poeira
--     ao fundo — ATRÁS do chefe); `drawFront` vem depois do chefe (neve,
--     cinza e esporos mais próximos passam NA FRENTE dele).
--   * Salão e partículas usam o mesmo índice: `InteriorFX.hallFor(ato)` é a
--     fonte única (draw e update do GameplayScene perguntam aqui).

local SceneBackground = require("src.ui.SceneBackground")

local InteriorFX = {}

-- ---------------------------------------------------------------------------
-- DADOS POR SALÃO (coordenadas em pixels da PNG 400×256)
--   flames   {x, y, w, h}  retângulo da chama PINTADA (medido por cluster de
--            luma na arte). O flicker redesenha esse pedaço em aditivo e as
--            brasas nascem no topo dele.
--   pulses   {x, y, w, h, speed, amp, th=, beat=}  luz grande pintada que
--            RESPIRA devagar (vão iluminado, cascata de lava, feixe do
--            eclipse). th = luma mínima que acende (default PULSE_LUMA);
--            beat = pulso duplo de coração em vez de seno.
--   ember    cor das brasas (nil = salão sem brasa)
--   ambient  partículas de clima: style dust|ash|snow|spores|motes, rate
--            (por segundo), color, region {x, y, w, h} de nascimento
--   fog      névoa rente ao chão: y (topo da faixa), h, color, alpha
--   vignette força do escurecimento das bordas (0..1)
-- ---------------------------------------------------------------------------
local HALLS = {
    -- ATO 1 — salão do rei-carniça: seis arandelas nas colunas e o vão
    -- âmbar atrás do trono (contraste pro corvo escuro).
    [1] = {
        flames = {
            { 72, 112, 10, 13 }, { 102, 122, 10, 13 }, { 158, 128, 8, 11 },
            { 234, 128, 8, 11 }, { 289, 122, 10, 13 }, { 319, 112, 10, 13 },
        },
        pulses = { { 182, 78, 36, 100, 0.9, 0.16 } },
        ember = { 1.00, 0.62, 0.22 },
        ambient = { style = "dust", rate = 7, color = { 1.00, 0.80, 0.50 },
                    region = { 150, 60, 100, 130 } },
        fog = { y = 172, h = 40, color = { 0.30, 0.20, 0.14 }, alpha = 0.45 },
        vignette = 0.75,
    },
    -- ATO 2 — catedral do lich: quatro candelabros, luar no vitral.
    [2] = {
        flames = {
            { 14, 122, 44, 20 }, { 88, 148, 30, 18 },
            { 284, 148, 30, 18 }, { 342, 122, 44, 20 },
        },
        pulses = { { 172, 8, 56, 125, 0.5, 0.10 } },
        ember = { 1.00, 0.86, 0.55 },
        ambient = { style = "dust", rate = 9, color = { 0.82, 0.72, 1.00 },
                    region = { 120, 30, 160, 170 } },
        fog = { y = 196, h = 36, color = { 0.28, 0.20, 0.40 }, alpha = 0.50 },
        vignette = 0.80,
    },
    -- ATO 3 — cidadela infernal: braseiros, cascata de lava no portão-caveira.
    [3] = {
        flames = {
            { 25, 123, 26, 36 }, { 95, 147, 18, 21 },
            { 288, 147, 18, 21 }, { 348, 123, 26, 36 },
        },
        pulses = { { 186, 100, 28, 84, 1.4, 0.22 },
                   { 128, 140, 30, 44, 1.1, 0.12 }, { 242, 140, 30, 44, 1.25, 0.12 } },
        ember = { 1.00, 0.42, 0.14 },
        ambient = { style = "ash", rate = 26, color = { 0.55, 0.50, 0.48 },
                    region = { 0, -10, 400, 20 } },
        fog = { y = 178, h = 40, color = { 0.45, 0.10, 0.04 }, alpha = 0.40 },
        vignette = 0.85,
    },
    -- ATO 4 — cidadela glacial: dois braseiros de chama azul-branca.
    [4] = {
        flames = { { 136, 155, 14, 22 }, { 251, 155, 14, 22 } },
        pulses = {},
        ember = { 0.62, 0.85, 1.00 },
        ambient = { style = "snow", rate = 22, color = { 0.85, 0.93, 1.00 },
                    region = { 0, -10, 400, 20 } },
        fog = { y = 182, h = 44, color = { 0.55, 0.72, 0.95 }, alpha = 0.42 },
        vignette = 0.70,
    },
    -- ATO 5 — coração pútrido: fogos-fátuos verdes entre as raízes e o
    -- coração de raízes pairando no fundo do túnel, acima da cabeça do chefe.
    [5] = {
        flames = { { 106, 152, 22, 28 }, { 272, 150, 24, 32 } },
        pulses = { { 108, 226, 18, 10, 0.7, 0.20 }, { 272, 226, 18, 12, 0.8, 0.20 },
                   -- o coração podre ao fundo do túnel BATE (tum-tum, pausa)
                   { 160, 54, 88, 120, 1.2, 0.55, th = 0.14, beat = true } },
        ember = { 0.55, 1.00, 0.42 },
        ambient = { style = "spores", rate = 12, color = { 0.62, 1.00, 0.45 },
                    region = { 40, 150, 320, 100 } },
        fog = { y = 190, h = 46, color = { 0.20, 0.36, 0.12 }, alpha = 0.58 },
        vignette = 0.80,
    },
    -- ATO 6 — corte do eclipse: sem fogo pintado (a luz é o vão do fundo);
    -- poeira só DENTRO do feixe.
    [6] = {
        flames = {},
        pulses = { { 170, 60, 62, 130, 0.35, 0.08 } },
        ember = nil,
        ambient = { style = "motes", rate = 10, color = { 1.00, 0.97, 0.90 },
                    region = { 172, 40, 58, 150 } },
        fog = { y = 186, h = 40, color = { 0.62, 0.60, 0.66 }, alpha = 0.38 },
        vignette = 0.65,
    },
}
InteriorFX.HALLS = HALLS

local MAX_PARTICLES = 220
local particles = {}
local spawnAcc = 0
local emberAcc = 0
local time = 0

-- Recursos gerados uma vez (ImageData → Image, nearest): textura de névoa
-- pontilhada e vinheta pontilhada, ambas na resolução da arte.
local fogImg, vignetteImg
local hallImgs = {}
local quads = {}
local avisou = {}

-- ruído de valor barato (determinístico) pra textura da névoa
local function hash(x, y)
    local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)
end

local function vnoise(x, y)
    local xi, yi = math.floor(x), math.floor(y)
    local fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    local a = hash(xi, yi)
    local b = hash(xi + 1, yi)
    local c = hash(xi, yi + 1)
    local d = hash(xi + 1, yi + 1)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end

local FOG_W, FOG_H = 200, 24

local function buildFog()
    local data = love.image.newImageData(FOG_W, FOG_H)
    for y = 0, FOG_H - 1 do
        -- densa no meio da faixa, some nas bordas de cima/baixo
        local v = y / (FOG_H - 1)
        local band = math.sin(v * math.pi)
        for x = 0, FOG_W - 1 do
            -- período horizontal = FOG_W (tileável): ruído sobre um círculo
            local ang = x / FOG_W * 2 * math.pi
            local n = vnoise(math.cos(ang) * 4 + 10, math.sin(ang) * 4 + y * 0.35) * 0.65
                + vnoise(math.cos(ang) * 9 + 30, math.sin(ang) * 9 + y * 0.7) * 0.35
            local dens = band * (n * 1.5 - 0.35)
            -- posterizado em 3 níveis (manchas de pixel art, não gradiente
            -- liso nem tela pontilhada)
            local lvl = math.max(0, math.min(3, math.floor(dens * 4)))
            data:setPixel(x, y, 1, 1, 1, lvl / 3)
        end
    end
    fogImg = love.graphics.newImage(data)
    fogImg:setFilter("nearest", "nearest")
    fogImg:setWrap("repeat", "clamp")
end

local function buildVignette()
    local w, h = 400, 256
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local dx = (x - w / 2) / (w / 2)
            local dy = (y - h * 0.46) / (h / 2)
            local r = math.sqrt(dx * dx * 0.9 + dy * dy * 1.1)
            local d = math.max(0, math.min(1, (r - 0.55) / 0.6))
            d = d * d
            -- degraus de 1/8 na grade da arte (pontilhado aqui virava
            -- "tela de mosquiteiro" por cima da pintura)
            data:setPixel(x, y, 1, 1, 1, math.floor(d * 8 + 0.5) / 8)
        end
    end
    vignetteImg = love.graphics.newImage(data)
    vignetteImg:setFilter("nearest", "nearest")
end

-- Máscara EMISSIVA do salão: só os pixels claros de dentro dos retângulos
-- de chama/pulso, com alpha pela luma. Desenhada em aditivo, ilumina o fogo
-- PINTADO e nada em volta — redesenhar o retângulo cru clareava o fundo
-- escuro junto e aparecia uma caixa em volta do braseiro.
local FLAME_LUMA, PULSE_LUMA = 0.50, 0.32

local function stampEmissive(src, dst, r, th)
    local iw, ih = src:getWidth(), src:getHeight()
    for y = math.max(0, r[2]), math.min(ih - 1, r[2] + r[4] - 1) do
        for x = math.max(0, r[1]), math.min(iw - 1, r[1] + r[3] - 1) do
            local cr, cg, cb = src:getPixel(x, y)
            local l = 0.3 * cr + 0.59 * cg + 0.11 * cb
            if l > th then
                local _, _, _, pa = dst:getPixel(x, y)
                local a = math.min(1, (l - th) / (1 - th) * 1.6)
                if a > pa then dst:setPixel(x, y, cr, cg, cb, a) end
            end
        end
    end
end

local function hallImage(hall)
    if hallImgs[hall] ~= nil then return hallImgs[hall] or nil end
    local cfg = HALLS[hall]
    local path = "assets/sprites/scenes/castle_hall_" .. hall .. ".png"
    local ok, src = pcall(love.image.newImageData, path)
    if not ok or not src then
        print("[InteriorFX] AVISO: não carregou " .. path .. " — sem luz nas chamas")
        hallImgs[hall] = false
        return nil
    end
    local dst = love.image.newImageData(src:getWidth(), src:getHeight())
    for _, f in ipairs(cfg.flames) do stampEmissive(src, dst, f, FLAME_LUMA) end
    for _, pz in ipairs(cfg.pulses) do stampEmissive(src, dst, pz, pz.th or PULSE_LUMA) end
    local img = love.graphics.newImage(dst)
    img:setFilter("nearest", "nearest")
    hallImgs[hall] = img
    quads[hall] = {}
    return img
end

local function quadFor(hall, key, r)
    local q = quads[hall][key]
    if not q then
        local img = hallImgs[hall]
        q = love.graphics.newQuad(r[1], r[2], r[3], r[4], img:getWidth(), img:getHeight())
        quads[hall][key] = q
    end
    return q
end

-- Salão que o ato usa — fonte ÚNICA pra draw e update. Ato sem PNG cai no
-- salão 3 e AVISA (fallback silencioso é proibido).
local hallMemo = {}
function InteriorFX.hallFor(act)
    local a = math.max(1, act or 1)
    if hallMemo[a] then return hallMemo[a] end
    local res = a
    if not love.filesystem.getInfo("assets/sprites/scenes/castle_hall_" .. a .. ".png") then
        res = math.min(3, a)
        if not avisou[a] then
            avisou[a] = true
            print(("[cena] sem castle_hall_%d.png — caindo no salão %d"):format(a, res))
        end
    end
    hallMemo[a] = res
    return res
end

function InteriorFX.clear()
    for i = #particles, 1, -1 do particles[i] = nil end
    spawnAcc = 0
    emberAcc = 0
end

local rnd = love.math.random

local function spawnAmbient(cfg)
    local amb = cfg.ambient
    local r = amb.region
    local p = {
        x = r[1] + rnd() * r[3], y = r[2] + rnd() * r[4],
        kind = amb.style, front = rnd() < 0.35,
        phase = rnd() * 6.28, life = 0, color = amb.color,
    }
    local st = amb.style
    if st == "dust" or st == "motes" then
        p.vx, p.vy = (rnd() - 0.5) * 3, (rnd() - 0.5) * 2.5
        p.maxLife = 4 + rnd() * 4
        p.front = false
    elseif st == "ash" then
        p.vx, p.vy = (rnd() - 0.5) * 6, 6 + rnd() * 8
        p.maxLife = 30
    elseif st == "snow" then
        p.vx, p.vy = (rnd() - 0.5) * 4, 8 + rnd() * 9
        p.maxLife = 30
    elseif st == "spores" then
        p.vx, p.vy = (rnd() - 0.5) * 3, -(2 + rnd() * 4)
        p.maxLife = 5 + rnd() * 5
        p.blink = rnd() < 0.3          -- vaga-lume: pisca forte
    end
    particles[#particles + 1] = p
end

local function spawnEmber(cfg)
    local fl = cfg.flames
    if #fl == 0 then return end
    local f = fl[rnd(1, #fl)]
    particles[#particles + 1] = {
        x = f[1] + f[3] * (0.3 + rnd() * 0.4), y = f[2] + 1,
        vx = (rnd() - 0.5) * 5, vy = -(10 + rnd() * 12),
        kind = "ember", front = false, phase = rnd() * 6.28,
        life = 0, maxLife = 0.8 + rnd() * 0.9, color = cfg.ember,
    }
end

local currentHall = nil
local step

-- Troca de salão: zera e PRÉ-AQUECE o clima, senão a sala abre vazia e a
-- neve/cinza leva ~20s pra cobrir a tela (e partículas do salão anterior,
-- com a cor dele, ficariam no novo).
local function enterHall(hall)
    currentHall = hall
    InteriorFX.clear()
    for _ = 1, 250 do step(0.1, hall) end
end

function InteriorFX.update(dt, hall)
    if hall ~= currentHall then enterHall(hall) end
    step(dt, hall)
end

step = function(dt, hall)
    time = time + dt
    local cfg = HALLS[hall or 1]
    if not cfg then return end

    if #particles < MAX_PARTICLES then
        spawnAcc = spawnAcc + dt * cfg.ambient.rate
        while spawnAcc >= 1 do
            spawnAcc = spawnAcc - 1
            spawnAmbient(cfg)
        end
        if cfg.ember then
            emberAcc = emberAcc + dt * 3 * #cfg.flames
            while emberAcc >= 1 do
                emberAcc = emberAcc - 1
                spawnEmber(cfg)
            end
        end
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life + dt
        local k = p.kind
        if k == "ember" then
            p.vy = p.vy + 9 * dt               -- desacelera subindo
            p.vx = p.vx * (1 - dt * 1.5)
        elseif k == "ash" or k == "snow" then
            p.vx = p.vx + math.sin(time * 1.3 + p.phase) * 4 * dt   -- balanço
        elseif k == "spores" then
            p.vx = p.vx + math.sin(time * 0.9 + p.phase) * 3 * dt
        end
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.life >= p.maxLife or p.y > 262 or p.y < -14
            or p.x < -10 or p.x > 410 then
            particles[i] = particles[#particles]
            particles[#particles] = nil
        end
    end
end

-- alpha de vida: entra e sai suave (dust/motes/spores/brasas)
local function lifeAlpha(p)
    local t = p.life / p.maxLife
    if p.kind == "ash" or p.kind == "snow" then return 1 end
    return math.min(1, t * 5) * math.min(1, (1 - t) * 3)
end

local function drawParticles(tr, front)
    local s = tr.scale
    local ox, oy = tr.ox, tr.oy
    for i = 1, #particles do
        local p = particles[i]
        if p.front == front then
            local c = p.color
            local a = lifeAlpha(p)
            if p.kind == "ember" then
                local t = p.life / p.maxLife
                love.graphics.setColor(c[1], math.max(0.1, c[2] - t * 0.35), c[3], a)
            elseif p.blink then
                a = a * (0.25 + 0.75 * math.max(0, math.sin(time * 4 + p.phase)))
                love.graphics.setColor(c[1], c[2], c[3], a)
            else
                local tw = 0.65 + 0.35 * math.sin(time * 2.2 + p.phase)
                love.graphics.setColor(c[1], c[2], c[3], a * tw * (front and 0.95 or 0.7))
            end
            love.graphics.rectangle("fill",
                math.floor(ox + math.floor(p.x) * s), math.floor(oy + math.floor(p.y) * s),
                math.ceil(s), math.ceil(s))
        end
    end
end

local function flicker(i)
    return 0.62 + 0.22 * math.sin(time * 11 + i * 2.4)
        + 0.12 * math.sin(time * 27 + i * 7.1)
        + 0.06 * math.sin(time * 53 + i * 3.3)
end

-- Fundo do salão: luz respirando nas chamas/vãos PINTADOS, névoa no chão,
-- vinheta e partículas de trás. Chamado logo após o SceneBackground (antes
-- do chefe).
function InteriorFX.draw(hall)
    local cfg = HALLS[hall or 1]
    if not cfg then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tr = SceneBackground.getCoverTransform("castle_hall_" .. hall, w, h)
    if not tr then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    if not fogImg then buildFog() end
    if not vignetteImg then buildVignette() end

    -- 1) a própria arte, aditiva, nas fontes de luz (formato exato do fogo)
    local img = hallImage(hall)
    if img then
        love.graphics.setBlendMode("add")
        for i, f in ipairs(cfg.flames) do
            love.graphics.setColor(1, 1, 1, 0.75 * flicker(i))
            love.graphics.draw(img, quadFor(hall, "f" .. i, f), ox + f[1] * s, oy + f[2] * s, 0, s, s)
        end
        for i, pz in ipairs(cfg.pulses) do
            local a
            if pz.beat then
                -- tum (forte) … tum (fraco) … pausa
                local ph = (time * pz[5]) % 1
                a = pz[6] * (math.exp(-((ph - 0.08) / 0.05) ^ 2)
                    + 0.6 * math.exp(-((ph - 0.30) / 0.06) ^ 2))
            else
                a = pz[6] * (0.5 + 0.5 * math.sin(time * pz[5] + i * 1.7))
            end
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, quadFor(hall, "p" .. i, pz), ox + pz[1] * s, oy + pz[2] * s, 0, s, s)
        end
        love.graphics.setBlendMode("alpha")
    end

    -- 2) névoa rente ao chão: duas camadas pontilhadas em sentidos opostos
    local fog = cfg.fog
    local fc = fog.color
    local sy = fog.h / FOG_H
    for layer = 1, 2 do
        local speed = layer == 1 and 3 or -5
        local off = math.floor((time * speed) % FOG_W)
        local yy = oy + (fog.y + (layer - 1) * fog.h * 0.35) * s
        love.graphics.setColor(fc[1], fc[2], fc[3], fog.alpha * (layer == 1 and 1 or 0.7))
        -- dois ladrilhos de FOG_W cobrem os 400px da arte com rolagem
        for k = -1, 2 do
            love.graphics.draw(fogImg, ox + (k * FOG_W - off) * s, yy, 0, s, s * sy)
        end
    end

    -- 3) vinheta: pavor nas bordas, o centro (chefe) fica limpo
    love.graphics.setColor(0.02, 0.01, 0.01, cfg.vignette)
    love.graphics.draw(vignetteImg, ox, oy, 0, s, s)

    -- 4) partículas de trás (poeira no feixe, brasas, clima distante)
    drawParticles(tr, false)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Clima que passa NA FRENTE do chefe (neve/cinza/esporos próximos).
-- Chamado logo depois do EnemyRenderer.draw no salão — e isso é DEPOIS da
-- TopBar, então recorta na janela da cena (abaixo de `clipTop`): sem o
-- recorte a neve pintava pontos brancos por cima da barra superior.
function InteriorFX.drawFront(hall, clipTop)
    if not HALLS[hall or 1] then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tr = SceneBackground.getCoverTransform("castle_hall_" .. hall, w, h)
    if not tr then return end
    local top = math.max(0, math.floor(clipTop or 0))
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, top, w, h - top)
    drawParticles(tr, true)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    love.graphics.setColor(1, 1, 1, 1)
end

return InteriorFX
