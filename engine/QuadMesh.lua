-- engine/QuadMesh.lua
-- ============================================================================
-- QUADMESH — lote de quads escrito por FFI e desenhado como 1 Mesh (Out/2026)
-- ============================================================================
-- POR QUE EXISTE: o WorldRoad desenhava o chão do domo, a estrada e a grama
-- com dezenas de milhares de chamadas C por frame (quad:setViewport +
-- love.graphics.draw / rectangle / batch:add / setColor). O custo NÃO era
-- a GPU (o LÖVE já juntava tudo em ~800 draw calls) — era a fronteira
-- Lua→C: cada chamada custa ~0.2-0.5 µs E aborta o trace do JIT, então o
-- laço inteiro rodava no interpretador. Aqui o laço só faz aritmética e
-- escreve floats num ByteData via FFI (o JIT compila), e o envio pra GPU é
-- 1 setVertices + 1 draw por TRECHO.
--
-- MESMOS PIXELS: as fórmulas de vértice/UV/cor replicam as do LÖVE 11
-- (Quad::refresh, Matrix4::setTransformation, toColor32) — a prova pixel a
-- pixel fica em tools/perf_visual_diff.lua. Ordem de desenho = ordem de
-- escrita (painter preservado dentro do lote).
--
-- QUAD SEM TEXTURA no meio de quads texturizados (retângulos chapados da
-- estrada intercalados com o tile): u = UNTEXTURED; o shader do lote
-- devolve só a cor do vértice. Use QuadMesh.untexturedShader() no draw.
--
-- USO:
--   local qm = QuadMesh.new(1024)
--   qm:reset()
--   local a = qm.n
--   qm:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)    -- axis-aligned
--   qm:sprite(...)                                       -- ver abaixo
--   qm:upload(a, qm.n); qm:draw(a, qm.n - a, texture)
-- ============================================================================

local ffi = require("ffi")

pcall(ffi.cdef, [[
typedef struct { float x, y, u, v; uint8_t r, g, b, a; } qm_vertex_t;
]])

local QuadMesh = {}
QuadMesh.__index = QuadMesh

local FORMAT = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
    { "VertexColor", "byte", 4 },
}
local VSIZE = ffi.sizeof("qm_vertex_t")   -- 20 bytes
local CTYPE = "qm_vertex_t*"

-- sentinela de "sem textura" (u muito negativo — nenhum UV real chega perto)
QuadMesh.UNTEXTURED = -4096

local floor, min, max = math.floor, math.min, math.max
-- toColor32 do LÖVE 11: clamp [0,1] e arredonda (×255 + 0.5).
-- SEM if: desvio em função quente vira saída lateral de trace, e as
-- laterais desta cena não compilam (NYICOAL) — min/max são branchless.
local function c8(c)
    return floor(min(1, max(0, c)) * 255 + 0.5)
end
QuadMesh.c8 = c8

local whiteImg
local function white()
    if not whiteImg then
        local d = love.image.newImageData(1, 1)
        d:setPixel(0, 0, 1, 1, 1, 1)
        whiteImg = love.graphics.newImage(d)
    end
    return whiteImg
end

local untexShader
function QuadMesh.untexturedShader()
    if not untexShader then
        untexShader = love.graphics.newShader([[
            vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
                if (uv.x < -2048.0) return color;
                return Texel(tex, uv) * color;
            }
        ]])
    end
    return untexShader
end

-- opts (opcional): { ctype = "<struct>", format = {...} } — vértice
-- próprio (ex.: GrassField, com atributos de vento). A struct precisa
-- bater byte a byte com o format; o chamador escreve via qm:alloc()/qm.v.
function QuadMesh.new(capQuads, opts)
    local self = setmetatable({}, QuadMesh)
    self.n = 0
    self.cap = 0
    self.ctype = opts and (opts.ctype .. "*") or CTYPE
    self.format = opts and opts.format or FORMAT
    self.vsize = opts and ffi.sizeof(opts.ctype) or VSIZE
    self:_grow(math.max(64, capQuads or 1024))
    return self
end

function QuadMesh:_grow(cap)
    local oldData, oldN = self.data, self.n
    local vs = self.vsize
    self.data = love.data.newByteData(cap * 4 * vs)
    self.v = ffi.cast(self.ctype, self.data:getFFIPointer())
    if oldData then
        ffi.copy(self.v, oldData:getFFIPointer(), oldN * 4 * vs)
        oldData:release()
    end
    if self.mesh then self.mesh:release() end
    self.mesh = love.graphics.newMesh(self.format, cap * 4, "triangles", "dynamic")
    -- índices 0,1,2 / 2,1,3 por quad (mesma triangulação do SpriteBatch)
    local idx = love.data.newByteData(cap * 6 * 4)
    local ip = ffi.cast("uint32_t*", idx:getFFIPointer())
    for q = 0, cap - 1 do
        local b, o = q * 4, q * 6
        ip[o], ip[o + 1], ip[o + 2] = b, b + 1, b + 2
        ip[o + 3], ip[o + 4], ip[o + 5] = b + 2, b + 1, b + 3
    end
    self.mesh:setVertexMap(idx, "uint32")
    idx:release()
    self.cap = cap
    -- o que já foi escrito sobe de novo pro Mesh novo (quem reusa trechos
    -- gravados — cache da grama/domo — não pode achar buraco depois)
    if oldN > 0 then self:upload(0, oldN) end
end

function QuadMesh:reset()
    self.n = 0
end

-- reserva 1 quad e devolve o índice do 1º vértice. ATENÇÃO: pode crescer
-- o buffer — releia qm.v DEPOIS de chamar.
local function alloc(self)
    local n = self.n
    if n >= self.cap then self:_grow(self.cap * 2) end
    self.n = n + 1
    return n * 4
end
QuadMesh.alloc = alloc

-- Quad ALINHADO AOS EIXOS: (x,y)-(x+w,y+h), UV (u0,v0)-(u1,v1) normalizados.
-- Vértices na ordem do Quad do LÖVE: (0,0) (0,h) (w,0) (w,h).
function QuadMesh:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)
    local i = alloc(self)
    local vt = self.v
    local R, G, B, A = c8(r), c8(g), c8(b), c8(a)
    local x1, y1 = x + w, y + h
    local p = vt[i]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x, y, u0, v0, R, G, B, A
    p = vt[i + 1]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x, y1, u0, v1, R, G, B, A
    p = vt[i + 2]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x1, y, u1, v0, R, G, B, A
    p = vt[i + 3]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x1, y1, u1, v1, R, G, B, A
end

-- Equivalente de SpriteBatch:add(quad, x, y, 0, sx, sy, ox, oy, kx, 0)
-- com o quad de tamanho qw×qh e UV (u0,v0)-(u1,v1); cor JÁ em bytes.
-- Matrix4::setTransformation do LÖVE 11 com ângulo 0 e ky 0:
--   X = x + sx·(lx − ox) + kx·sx·(ly − oy)      Y = y + sy·(ly − oy)
function QuadMesh:sprite(x, y, sx, sy, ox, oy, kx, qw, qh,
                         u0, v0, u1, v1, R, G, B, A)
    local i = alloc(self)
    local vt = self.v
    local xl, xr = -ox * sx, (qw - ox) * sx
    local shT, shB = kx * sx * (-oy), kx * sx * (qh - oy)
    local yT, yB = y + sy * (-oy), y + sy * (qh - oy)
    local p = vt[i]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x + xl + shT, yT, u0, v0, R, G, B, A
    p = vt[i + 1]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x + xl + shB, yB, u0, v1, R, G, B, A
    p = vt[i + 2]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x + xr + shT, yT, u1, v0, R, G, B, A
    p = vt[i + 3]
    p.x, p.y, p.u, p.v, p.r, p.g, p.b, p.a = x + xr + shB, yB, u1, v1, R, G, B, A
end

-- Sobe pro Mesh os quads [from, to). Só o trecho — o resto do buffer
-- (trechos já desenhados neste frame) não é tocado.
function QuadMesh:upload(from, to)
    if to <= from then return end
    local vs = self.vsize
    local view = love.data.newDataView(self.data, from * 4 * vs,
        (to - from) * 4 * vs)
    self.mesh:setVertices(view, from * 4 + 1)
    view:release()
end

-- Desenha `count` quads a partir de `from` (com a cor global atual).
function QuadMesh:draw(from, count, texture)
    if count <= 0 then return end
    self.mesh:setTexture(texture or white())
    self.mesh:setDrawRange(from * 6 + 1, count * 6)
    love.graphics.draw(self.mesh)
end

return QuadMesh
