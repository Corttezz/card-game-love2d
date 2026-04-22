-- src/ui/CardMesh.lua
-- Mesh tessellada reutilizável pra cartas + wrapper do vertex shader de warp.
-- Estilo Balatro: grid 8×12 vertices sobre o canvas da carta, vertex shader
-- deforma cada vertex baseado em mouse/hover/time pra efeito de perspective
-- pressando um canto.
--
-- Uso:
--   local mesh = CardMesh.getMesh(imageWidth, imageHeight)  -- geometria cacheada
--   local shader = CardMesh.getShader()                      -- pode ser nil
--   mesh:setTexture(image)
--   if shader then
--     love.graphics.setShader(shader)
--     CardMesh.setUniforms(shader, mouseUV, hover, time, image)
--     love.graphics.draw(mesh, x, y, rot, sx, sy)
--     love.graphics.setShader()
--   end

local CardMesh = {}

-- Config via Config.Cards (fallback defaults se Config não carregado)
local function cfg(name, default)
    local ok, Config = pcall(require, "src.core.Config")
    if not ok or not Config.Cards then return default end
    return Config.Cards[name] or default
end

-- ===== Mesh geometry (compartilhada) =====
local _meshCache = nil       -- único mesh reaproveitado
local _meshW, _meshH = 0, 0  -- dimensões que geraram o cache atual

-- Gera vertices em grid COLS × ROWS com UV normalizado [0..1] e posição em pixels.
-- Triângulos: 2 por célula. Total vertices por célula = 6 (dois triangle com shared verts).
-- Usamos triangle-list simples em vez de strip pra evitar gotchas de ordem.
local function buildMesh(w, h)
    local COLS = cfg("MESH_COLS", 8)
    local ROWS = cfg("MESH_ROWS", 12)

    local verts = {}
    -- Grid de pontos (COLS+1) × (ROWS+1)
    local points = {}
    for row = 0, ROWS do
        for col = 0, COLS do
            local u = col / COLS
            local v = row / ROWS
            local x = u * w
            local y = v * h
            -- Vertex format default LÖVE: {x, y, u, v, r, g, b, a}
            table.insert(points, { x, y, u, v, 1, 1, 1, 1 })
        end
    end

    local function pointAt(col, row)
        return points[row * (COLS + 1) + col + 1]
    end

    -- Emite 2 triângulos por célula (triangle-list)
    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local tl = pointAt(col, row)
            local tr = pointAt(col + 1, row)
            local bl = pointAt(col, row + 1)
            local br = pointAt(col + 1, row + 1)
            -- Triangle 1: tl, tr, bl
            table.insert(verts, tl)
            table.insert(verts, tr)
            table.insert(verts, bl)
            -- Triangle 2: tr, br, bl
            table.insert(verts, tr)
            table.insert(verts, br)
            table.insert(verts, bl)
        end
    end

    local mesh = love.graphics.newMesh(verts, "triangles", "static")
    return mesh
end

-- Retorna mesh compartilhada, reconstruindo só se dimensões mudaram.
function CardMesh.getMesh(width, height)
    width = width or 96
    height = height or 144
    if _meshCache and _meshW == width and _meshH == height then
        return _meshCache
    end
    _meshCache = buildMesh(width, height)
    _meshW, _meshH = width, height
    return _meshCache
end

-- ===== Shader =====
local _shader = nil
local _shaderLoaded = false
local _shaderFailed = false

-- Lazy-load do shader. Retorna nil se falhar (fallback gracioso).
function CardMesh.getShader()
    if _shaderLoaded then return _shader end
    _shaderLoaded = true
    local path = "shaders/card_perspective.glsl"
    if not love.filesystem.getInfo(path) then
        print("[CardMesh] shader não encontrado: " .. path)
        _shaderFailed = true
        return nil
    end
    local ok, shader = pcall(love.graphics.newShader, path)
    if not ok or not shader then
        print("[CardMesh] falha ao compilar shader: " .. tostring(shader))
        _shaderFailed = true
        return nil
    end
    _shader = shader
    return _shader
end

-- Seta uniforms do shader.
-- mouseUV: vec2 em [-1, 1] (0,0 = sem press)
-- hover: float 0..1
-- time: segundos
-- image: drawable ativo (pra pegar getWidth/getHeight)
function CardMesh.setUniforms(shader, mouseUV, hover, time, image)
    shader:send("mouse", mouseUV)
    shader:send("hover", hover or 0)
    shader:send("time", time or 0)
    shader:send("cardSize", { image:getWidth(), image:getHeight() })
end

-- Helper de draw completo (setShader + uniforms + mesh + setShader nil).
-- Assume que caller já aplicou push/translate/rotate/scale no contexto.
function CardMesh.draw(image, drawX, drawY, mouseUV, hover, time)
    local shader = CardMesh.getShader()
    if not shader then
        -- Fallback: draw imagem direto
        love.graphics.draw(image, drawX, drawY)
        return
    end
    local mesh = CardMesh.getMesh(image:getWidth(), image:getHeight())
    mesh:setTexture(image)
    love.graphics.setShader(shader)
    CardMesh.setUniforms(shader, mouseUV, hover, time, image)
    love.graphics.draw(mesh, drawX, drawY)
    love.graphics.setShader()
end

-- Invalida cache (ex: config mudou MESH_COLS/ROWS em runtime)
function CardMesh.clearCache()
    _meshCache = nil
    _meshW, _meshH = 0, 0
end

return CardMesh
