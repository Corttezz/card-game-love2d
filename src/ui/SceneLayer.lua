-- src/ui/SceneLayer.lua
-- Camadas de cenário animado. Arte rica vem do scene PNG (400×256); animação
-- vem de OVERLAYS de código (partículas + flicker + glow pulsante) pra dar
-- MUITA vida sem precisar re-gerar arte.
--
-- Assets esperados:
--   assets/sprites/scenes/<name>.png         — scene full-res (base)
--   assets/sprites/map_objects/<name>.png    — props individuais (torch, etc.)
--
-- Ver memory/scene_pipeline.md pra pipeline completo.

local SceneBackground = require("src.ui.SceneBackground")

local SceneLayer = {}

local propCache = {}
local propMiss = {}

-- Partículas locais (gerenciadas aqui, não no ParticleSystem global pra não
-- poluir o damage numbers etc):
--   fireEmbers[]   — subindo das tochas
--   crystalSparks[] — orbitando o cristal
--   dustMotes[]    — poeira do chão
local fireEmbers = {}
local crystalSparks = {}
local dustMotes = {}

local function tryLoad(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then return nil end
    img:setFilter("nearest", "nearest")
    return img
end

local function loadProp(name)
    if propCache[name] then return propCache[name] end
    if propMiss[name] then return nil end
    local img = tryLoad("assets/sprites/map_objects/" .. name .. ".png")
    if img then propCache[name] = img else propMiss[name] = true end
    return img
end

-- ============================================================================
-- CONFIG POR ATO
-- ============================================================================
-- Campos:
--   scenePng     : arte base full-res (400×256) com elementos NA PRÓPRIA arte
--   fireEmitters : posições (xr, yr) onde partículas de fogo spawn — casam com
--                  as tochas que foram desenhadas dentro da scene PNG
--   dustColor    : tint de partículas ambientes de pó
--   parallaxY/X  : drift do scene (cria sensação de "camera viva")
--   props        : (vazio por padrão) — só usar se o prop FAÇA SENTIDO na scene
--                  específica. Props genéricos sobrepostos ficam ruins.
SceneLayer.ACT_CONFIGS = {
    [1] = {
        name = "catacumbs",
        scenePng = "catacumbs",
        fallbackScene = "gameplay",
        tint = { 1.00, 0.95, 0.85 },
        parallaxY = 5,
        parallaxX = 3,
        dustColor = { 0.85, 0.75, 0.60, 0.4 },
        -- Desativado: fireEmitters criavam "partículas soltas no ar" sobre as
        -- tochas pintadas, ficava visualmente confuso. A arte já tem o fogo.
        fireEmitters = {},
        props = {},
    },
    [2] = {
        name = "stone_tower",
        scenePng = "stone_tower",
        fallbackScene = "gameplay",
        tint = { 0.90, 0.92, 1.05 },
        parallaxY = 4,
        parallaxX = 2,
        dustColor = { 0.60, 0.55, 0.75, 0.4 },
        fireEmitters = {},
        props = {},
    },
    [3] = {
        name = "abyss",
        scenePng = "abyss",
        fallbackScene = "gameplay",
        tint = { 0.85, 0.78, 1.10 },
        parallaxY = 8,
        parallaxX = 4,
        dustColor = { 0.45, 0.30, 0.70, 0.5 },
        fireEmitters = {},
        props = {},
    },
}

SceneLayer._time = 0
SceneLayer._currentAct = 1
SceneLayer._dustSpawnTimer = 0

-- ============================================================================
-- UPDATE
-- ============================================================================
local function spawnFireEmber(cx, cy)
    table.insert(fireEmbers, {
        x = cx + (love.math.random() - 0.5) * 24,
        y = cy,
        vx = (love.math.random() - 0.5) * 18,
        vy = -60 - love.math.random() * 50,
        life = 1.2 + love.math.random() * 1.0,
        maxLife = 2.2,
        size = 3 + love.math.random(0, 3),      -- 3-6px (antes 2-4)
        hot = love.math.random() > 0.5,
    })
end

local function spawnCrystalSpark(cx, cy, radius)
    local angle = love.math.random() * math.pi * 2
    table.insert(crystalSparks, {
        angle = angle,
        radius = radius + (love.math.random() - 0.5) * 8,
        speed = 1.5 + love.math.random() * 2,   -- velocidade angular rad/s
        cx = cx, cy = cy,
        life = 1.5 + love.math.random() * 1.0,
        maxLife = 2.5,
        size = 1 + love.math.random(0, 1),
        verticalDrift = (love.math.random() - 0.5) * 20,
    })
end

local function spawnDustMote(w, h, color)
    table.insert(dustMotes, {
        x = love.math.random() * w,
        y = h - love.math.random() * 100,      -- nasce perto do chão
        vx = (love.math.random() - 0.5) * 8,
        vy = -(5 + love.math.random() * 10),   -- sobe devagar
        life = 3.0 + love.math.random() * 2.0,
        maxLife = 5.0,
        size = 1 + love.math.random(0, 1),
        color = color,
    })
end

-- Spawn de fire embers a partir dos `fireEmitters` declarados no ACT_CONFIGS.
local fireSpawnTimer = 0
SceneLayer._debugLog = nil -- set true pra habilitar debug
local function tickFireEmitters(cfg, x, y, w, h, dt)
    if not cfg.fireEmitters or #cfg.fireEmitters == 0 then
        if SceneLayer._debugLog then print("[SceneLayer] sem fireEmitters em cfg") end
        return
    end

    local sceneName = cfg.scenePng
    if not (SceneBackground.has and SceneBackground.has(sceneName)) then
        sceneName = cfg.fallbackScene
        if SceneLayer._debugLog then print("[SceneLayer] fallback scene: " .. tostring(sceneName)) end
    end
    local transform = SceneBackground.getCoverTransform and
                      SceneBackground.getCoverTransform(sceneName, w, h)
    if not transform then
        if SceneLayer._debugLog then print("[SceneLayer] transform nil para " .. tostring(sceneName)) end
        return
    end

    fireSpawnTimer = fireSpawnTimer - dt
    if fireSpawnTimer > 0 then return end
    fireSpawnTimer = 0.08 + love.math.random() * 0.05

    for _, em in ipairs(cfg.fireEmitters) do
        local cx = x + transform.ox + em.xr * transform.dw
        local cy = y + transform.oy + em.yr * transform.dh
        spawnFireEmber(cx, cy)
        if SceneLayer._debugLog then
            print(string.format("[SceneLayer] spawn fire em=(%.2f,%.2f) screen=(%d,%d)",
                em.xr, em.yr, cx, cy))
        end
    end
end

-- Debug helper: retorna número de fire embers ativos
function SceneLayer.getFireEmberCount() return #fireEmbers end

function SceneLayer.update(dt)
    SceneLayer._time = SceneLayer._time + dt

    -- Fire emitters: agora spawnam aqui (não em draw) pra independer do estado
    -- de renderização e funcionarem mesmo em screenshots headless.
    local cfg = SceneLayer.ACT_CONFIGS[SceneLayer._currentAct]
    if cfg then
        local sw = love.graphics.getWidth()
        local topBarH = 80 -- aprox; SceneLayer não sabe exatamente
        tickFireEmitters(cfg, 0, topBarH, sw, love.graphics.getHeight() - topBarH, dt)
    end

    -- Fire embers: atualiza
    for i = #fireEmbers, 1, -1 do
        local e = fireEmbers[i]
        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        e.vy = e.vy + 20 * dt               -- gravidade leve (sobe menos com tempo)
        e.vx = e.vx * 0.96                  -- fricção
        e.life = e.life - dt
        if e.life <= 0 then table.remove(fireEmbers, i) end
    end

    -- Crystal sparks: órbita
    for i = #crystalSparks, 1, -1 do
        local s = crystalSparks[i]
        s.angle = s.angle + s.speed * dt
        s.life = s.life - dt
        if s.life <= 0 then table.remove(crystalSparks, i) end
    end

    -- Dust motes
    for i = #dustMotes, 1, -1 do
        local m = dustMotes[i]
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt
        m.life = m.life - dt
        if m.life <= 0 then table.remove(dustMotes, i) end
    end

    -- Spawn dust motes ambient (taxa fixa)
    SceneLayer._dustSpawnTimer = SceneLayer._dustSpawnTimer - dt
    if SceneLayer._dustSpawnTimer <= 0 and #dustMotes < 25 then
        SceneLayer._dustSpawnTimer = 0.15 + love.math.random() * 0.10
        local cfg = SceneLayer.ACT_CONFIGS[SceneLayer._currentAct]
        if cfg and cfg.dustColor then
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            spawnDustMote(sw, sh, cfg.dustColor)
        end
    end
end

-- ============================================================================
-- HELPERS DE DRAW
-- ============================================================================
local function drawFireEmbers()
    for _, e in ipairs(fireEmbers) do
        local alpha = math.min(1, e.life / 1.0)
        local t = 1 - (e.life / e.maxLife)
        local r = 1.0
        local g = e.hot and (1.0 - t * 0.7) or (0.8 - t * 0.6)
        local b = 0.2 - t * 0.2
        local ex, ey = math.floor(e.x), math.floor(e.y)

        -- Glow halo (alpha baixo, size grande) pra visibilidade
        love.graphics.setColor(r, math.max(0, g), math.max(0, b), alpha * 0.35)
        love.graphics.circle("fill", ex + e.size / 2, ey + e.size / 2, e.size * 2.5)

        -- Core ember (cor forte, quadrado nítido)
        love.graphics.setColor(r, math.max(0, g), math.max(0, b), alpha)
        love.graphics.rectangle("fill", ex, ey, e.size, e.size)
    end
end

local function drawCrystalSparks()
    for _, s in ipairs(crystalSparks) do
        local alpha = math.min(1, s.life / 1.0)
        local x = s.cx + math.cos(s.angle) * s.radius
        local y = s.cy + math.sin(s.angle) * s.radius * 0.4 + s.verticalDrift -- elíptica + drift
        love.graphics.setColor(1.0, 0.3, 0.4, alpha * 0.9)
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s.size, s.size)
    end
end

local function drawDustMotes()
    for _, m in ipairs(dustMotes) do
        local alpha = math.min(1, m.life / 2.0) * (m.color[4] or 0.4)
        love.graphics.setColor(m.color[1], m.color[2], m.color[3], alpha)
        love.graphics.rectangle("fill", math.floor(m.x), math.floor(m.y), m.size, m.size)
    end
end

-- ============================================================================
-- BG FAR: scene PNG com tint + parallax 2D dramático
-- ============================================================================
local function drawBgFar(cfg, x, y, w, h)
    local sceneName = cfg.scenePng
    local hasScene = SceneBackground.has and SceneBackground.has(sceneName)
    if not hasScene and cfg.fallbackScene then
        sceneName = cfg.fallbackScene
        hasScene = SceneBackground.has and SceneBackground.has(sceneName)
    end

    -- Parallax 2D mais forte (antes era só Y ±1.5, agora XY)
    local parallaxY = (cfg.parallaxY or 0) * math.sin(SceneLayer._time * 0.25)
    local parallaxX = (cfg.parallaxX or 0) * math.sin(SceneLayer._time * 0.17)

    love.graphics.push()
    love.graphics.translate(parallaxX, parallaxY)
    love.graphics.setColor(cfg.tint[1], cfg.tint[2], cfg.tint[3], 1)
    local drawn = SceneBackground.draw(sceneName, w + math.abs(parallaxX) * 2, h + math.abs(parallaxY) * 2, 0.25)
    love.graphics.pop()

    if not drawn then
        love.graphics.setColor(cfg.tint[1], cfg.tint[2], cfg.tint[3], 1)
        love.graphics.rectangle("fill", x, y, w, h)
    end

    -- Pulse escuro mais forte (antes era ±0.02, agora ±0.05)
    local pulse = 0.10 + math.sin(SceneLayer._time * 0.6) * 0.05
    love.graphics.setColor(0, 0, 0, pulse)
    love.graphics.rectangle("fill", x, y, w, h)
end

-- ============================================================================
-- BG MID: vinheta + poeira ambiente visível
-- ============================================================================
local function drawBgMid(cfg, x, y, w, h)
    -- Vinheta inferior
    local gradH = math.floor(h * 0.28)
    for i = 0, gradH do
        local alpha = (i / gradH) * 0.35
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", x, y + h - gradH + i, w, 1)
    end

    -- Partículas de poeira (atrás dos props)
    drawDustMotes()
end

-- ============================================================================
-- FG PROPS (tochas com flicker FORTE, cristal com sparks orbitando)
-- ============================================================================
local function drawProp(prop, baseX, baseY, w, h)
    local img = loadProp(prop.id)
    if not img then return end

    local iw, ih = img:getWidth(), img:getHeight()
    local scale = prop.scale or 2
    local px = baseX + math.floor(w * prop.xr) - (iw * scale) / 2
    local py = baseY + math.floor(h * prop.yr) - ih * scale

    local alpha = 1
    local tintR, tintG, tintB = 1, 1, 1

    -- Bounding box centro-topo (onde fogo nasce pra tochas)
    local cx = px + (iw * scale) / 2
    local cyTop = py + (ih * scale) * 0.20

    if prop.anim == "torch" then
        -- FLICKER FORTE: 0.70 a 1.25 (antes era 0.85 a 1.03)
        local flickerMain = math.sin(SceneLayer._time * 17 + prop.xr * 47) * 0.5 + 0.5
        local flickerFast = math.sin(SceneLayer._time * 31 + prop.xr * 23) * 0.3 + 0.3
        alpha = 0.70 + flickerMain * 0.30 + flickerFast * 0.15
        tintR = 1.0
        tintG = 0.85 + flickerMain * 0.15
        tintB = 0.55 + flickerFast * 0.15

        -- Spawn fire embers subindo (2-4 por segundo por tocha)
        if love.math.random() < 0.12 then
            spawnFireEmber(cx, cyTop)
        end

    elseif prop.anim == "crystal" then
        -- PULSE MAIS FORTE: 0.65 a 1.25
        local pulse = math.sin(SceneLayer._time * 2.2) * 0.5 + 0.5
        alpha = 0.65 + pulse * 0.60
        tintR = 1.0
        tintG = 0.6 + pulse * 0.2
        tintB = 0.6 + pulse * 0.2

        -- Spawn sparks orbitando (continuamente)
        if love.math.random() < 0.15 then
            spawnCrystalSpark(cx, cyTop, 35)
        end
    end

    -- Draw sprite
    love.graphics.setColor(tintR, tintG, tintB, alpha)
    if prop.flipH then
        love.graphics.draw(img, px + iw * scale, py, 0, -scale, scale)
    else
        love.graphics.draw(img, px, py, 0, scale, scale)
    end

    -- Glow atras MUITO mais forte
    if prop.anim == "torch" then
        -- Glow pulsando com raio variável (30-65px)
        local glowRadius = 40 + math.sin(SceneLayer._time * 17) * 12 + math.sin(SceneLayer._time * 31) * 8
        for i = 1, 3 do
            local ringAlpha = (0.10 / i) * alpha
            love.graphics.setColor(1.0, 0.55, 0.25, ringAlpha)
            love.graphics.circle("fill", cx, cyTop, glowRadius * i * 0.6)
        end
    elseif prop.anim == "crystal" then
        -- Glow vermelho pulsando
        local glowRadius = 30 + math.sin(SceneLayer._time * 2.2) * 18
        for i = 1, 2 do
            local ringAlpha = (0.20 / i) * alpha
            love.graphics.setColor(1.0, 0.3, 0.4, ringAlpha)
            love.graphics.circle("fill", cx, cyTop, glowRadius * i * 0.7)
        end
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function SceneLayer.draw(x, y, w, h, actNumber)
    local eff = math.min(math.max(1, actNumber or 1), 3)
    SceneLayer._currentAct = eff
    local cfg = SceneLayer.ACT_CONFIGS[eff]
    if not cfg then return end

    drawBgFar(cfg, x, y, w, h)
    drawBgMid(cfg, x, y, w, h)

    -- Props (vazio por padrão após a limpeza). Scene PNG traz os elementos dela.
    for _, prop in ipairs(cfg.props or {}) do
        drawProp(prop, x, y, w, h)
    end

    -- Partículas de fogo/sparks desenhadas por cima de tudo
    drawFireEmbers()
    drawCrystalSparks()

    love.graphics.setColor(1, 1, 1, 1)
end

function SceneLayer.drawForeground(x, y, w, h, actNumber)
end

function SceneLayer.clearCache()
    propCache = {}
    propMiss = {}
    fireEmbers = {}
    crystalSparks = {}
    dustMotes = {}
end

return SceneLayer
