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
local VSIZE = ffi.sizeof("qm_vertex_t")
local CTYPE = "qm_vertex_t*"

QuadMesh.UNTEXTURED = -4096

local floor, min, max = math.floor, math.min, math.max
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
    self.fp = ffi.cast("float*", self.data:getFFIPointer())
    self.bp = ffi.cast("uint8_t*", self.data:getFFIPointer())
    if oldData then
        ffi.copy(self.v, oldData:getFFIPointer(), oldN * 4 * vs)
        oldData:release()
    end
    if self.mesh then self.mesh:release() end
    self.mesh = love.graphics.newMesh(self.format, cap * 4, "triangles", "dynamic")
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
    if oldN > 0 then self:upload(0, oldN) end
end

function QuadMesh:reset()
    self.n = 0
end

local function alloc(self)
    local n = self.n
    if n >= self.cap then self:_grow(self.cap * 2) end
    self.n = n + 1
    return n * 4
end
QuadMesh.alloc = alloc

local function put(fp, bp, vi, x, y, u, v, R, G, B, A)
    local fo, bo = vi * 5, vi * 20 + 16
    fp[fo], fp[fo + 1], fp[fo + 2], fp[fo + 3] = x, y, u, v
    bp[bo], bp[bo + 1], bp[bo + 2], bp[bo + 3] = R, G, B, A
end

function QuadMesh:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)
    local i = alloc(self)
    local fp, bp = self.fp, self.bp
    local R, G, B, A = c8(r), c8(g), c8(b), c8(a)
    local x1, y1 = x + w, y + h
    put(fp, bp, i, x, y, u0, v0, R, G, B, A)
    put(fp, bp, i + 1, x, y1, u0, v1, R, G, B, A)
    put(fp, bp, i + 2, x1, y, u1, v0, R, G, B, A)
    put(fp, bp, i + 3, x1, y1, u1, v1, R, G, B, A)
end

function QuadMesh:rectSkew(x, y, w, h, u0, u1, vL, vR, dvv, r, g, b, aL, aR)
    local i = alloc(self)
    local fp, bp = self.fp, self.bp
    local R, G, B = c8(r), c8(g), c8(b)
    local AL, AR = c8(aL), c8(aR)
    local x1, y1 = x + w, y + h
    put(fp, bp, i, x, y, u0, vL, R, G, B, AL)
    put(fp, bp, i + 1, x, y1, u0, vL + dvv, R, G, B, AL)
    put(fp, bp, i + 2, x1, y, u1, vR, R, G, B, AR)
    put(fp, bp, i + 3, x1, y1, u1, vR + dvv, R, G, B, AR)
end

function QuadMesh:sprite(x, y, sx, sy, ox, oy, kx, qw, qh,
                         u0, v0, u1, v1, R, G, B, A)
    local i = alloc(self)
    local fp, bp = self.fp, self.bp
    local xl, xr = -ox * sx, (qw - ox) * sx
    local shT, shB = kx * sx * (-oy), kx * sx * (qh - oy)
    local yT, yB = y + sy * (-oy), y + sy * (qh - oy)
    put(fp, bp, i, x + xl + shT, yT, u0, v0, R, G, B, A)
    put(fp, bp, i + 1, x + xl + shB, yB, u0, v1, R, G, B, A)
    put(fp, bp, i + 2, x + xr + shT, yT, u1, v0, R, G, B, A)
    put(fp, bp, i + 3, x + xr + shB, yB, u1, v1, R, G, B, A)
end

function QuadMesh:upload(from, to)
    if to <= from then return end
    local vs = self.vsize
    local view = love.data.newDataView(self.data, from * 4 * vs,
        (to - from) * 4 * vs)
    self.mesh:setVertices(view, from * 4 + 1)
    view:release()
end

function QuadMesh:draw(from, count, texture)
    if count <= 0 then return end
    self.mesh:setTexture(texture or white())
    self.mesh:setDrawRange(from * 6 + 1, count * 6)
    love.graphics.draw(self.mesh)
end

return QuadMesh
