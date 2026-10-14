local Debug = require("src.core.Debug")

local CardMesh = {}

local function cfg(name, default)
    local ok, Config = pcall(require, "src.core.Config")
    if not ok or not Config.Cards then return default end
    return Config.Cards[name] or default
end

local _meshCache = nil
local _meshW, _meshH = 0, 0

local function buildMesh(w, h)
    local COLS = cfg("MESH_COLS", 8)
    local ROWS = cfg("MESH_ROWS", 12)

    local verts = {}
    local points = {}
    for row = 0, ROWS do
        for col = 0, COLS do
            local u = col / COLS
            local v = row / ROWS
            local x = u * w
            local y = v * h
            table.insert(points, { x, y, u, v, 1, 1, 1, 1 })
        end
    end

    local function pointAt(col, row)
        return points[row * (COLS + 1) + col + 1]
    end

    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local tl = pointAt(col, row)
            local tr = pointAt(col + 1, row)
            local bl = pointAt(col, row + 1)
            local br = pointAt(col + 1, row + 1)
            table.insert(verts, tl)
            table.insert(verts, tr)
            table.insert(verts, bl)
            table.insert(verts, tr)
            table.insert(verts, br)
            table.insert(verts, bl)
        end
    end

    local mesh = love.graphics.newMesh(verts, "triangles", "static")
    return mesh
end

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

local _shader = nil
local _shaderLoaded = false
local _shaderFailed = false

function CardMesh.getShader()
    if _shaderLoaded then return _shader end
    _shaderLoaded = true
    local path = "shaders/card_perspective.glsl"
    if not love.filesystem.getInfo(path) then
        Debug.warn("[CardMesh] shader não encontrado: " .. path)
        _shaderFailed = true
        return nil
    end
    local ok, shader = pcall(love.graphics.newShader, path)
    if not ok or not shader then
        Debug.warn("[CardMesh] falha ao compilar shader: " .. tostring(shader))
        _shaderFailed = true
        return nil
    end
    _shader = shader
    return _shader
end

function CardMesh.setUniforms(shader, mouseUV, hover, time, image)
    shader:send("mouse", mouseUV)
    shader:send("hover", hover or 0)
    shader:send("time", time or 0)
    shader:send("cardSize", { image:getWidth(), image:getHeight() })
    shader:send("quadOn", 0)
    shader:send("silhouette", 0)
end

function CardMesh.setQuad(shader, r0, r1, r2)
    shader:send("hRow0", r0)
    shader:send("hRow1", r1)
    shader:send("hRow2", r2)
    shader:send("quadOn", 1)
end

function CardMesh.draw(image, drawX, drawY, mouseUV, hover, time)
    local shader = CardMesh.getShader()
    if not shader then
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

function CardMesh.clearCache()
    _meshCache = nil
    _meshW, _meshH = 0, 0
end

return CardMesh
