-- src/ui/RunJournalInk.lua
-- PENA E PAPEL do Roteiro da jornada (components/RunJournalScreen.lua).
--
-- O dono pediu um mapa "como se tivesse sido escrito à mão, apenas com tinta
-- preta e, no máximo, um círculo vermelho, com uma folha envelhecida". Este
-- módulo é o material: folha de pergaminho procedural (pixel art, borda
-- rasgada, manchas) e um traço de pena de 1 px com imperfeição DETERMINÍSTICA
-- (seed da run): nada de forma vetorial suave, que o dono chama de "cara de
-- IA". Todo pixel de tinta sai por UM SpriteBatch (uma chamada de desenho por
-- folha), então o mapa inteiro custa o que custa uma imagem.
--
-- Paleta: SÓ papel (PARCHMENT_*), tinta (INK) e sangue (BLOOD, o círculo).
-- A trava `test_journal_map` varre a captura e conta cor fora dessa família.

local Palette = require("src.ui.Palette")
local Layout  = require("src.ui.RunJournalLayout")

local Ink = {}

local hash = Layout.hash
Ink.hash = hash

local function lerp(a, b, t) return a + (b - a) * t end
local function mix(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), 1 }
end

Ink.INK    = Palette.INK
Ink.RED    = Palette.BLOOD
Ink.PAPER  = mix(Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, 0.22)   -- tom base da folha
Ink.PAPER_LIGHT = mix(Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, 0.08)
Ink.PAPER_DARK  = mix(Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, 0.42)
Ink.PAPER_STAIN = Palette.PARCHMENT
Ink.PAPER_RIM   = Palette.PARCHMENT_DARK
Ink.BACKDROP    = Palette.darken(Palette.INK, 0.55)

-- ===== lote de pixels =====================================================
local dot, batch
local function ensureBatch()
    if batch then return end
    local id = love.image.newImageData(1, 1)
    id:setPixel(0, 0, 1, 1, 1, 1)
    dot = love.graphics.newImage(id)
    dot:setFilter("nearest", "nearest")
    batch = love.graphics.newSpriteBatch(dot, 8192, "stream")
end

local curColor = { 0, 0, 0, 1 }
local function setBatchColor(c, a)
    local r, g, b = c[1], c[2], c[3]
    a = a == nil and 1 or a
    if curColor[1] ~= r or curColor[2] ~= g or curColor[3] ~= b or curColor[4] ~= a then
        curColor[1], curColor[2], curColor[3], curColor[4] = r, g, b, a
        batch:setColor(r, g, b, a)
    end
end

function Ink.begin()
    ensureBatch()
    batch:clear()
    curColor[1], curColor[2], curColor[3], curColor[4] = -1, -1, -1, -1
end

function Ink.flush()
    if not batch then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    batch:clear()
end

-- Um pixel (ou um retângulo de w×h pixels) de tinta.
function Ink.px(x, y, color, alpha, w, h)
    setBatchColor(color, alpha)
    if batch:getCount() >= batch:getBufferSize() then
        batch:setBufferSize(batch:getBufferSize() * 2)
    end
    batch:add(math.floor(x), math.floor(y), 0, w or 1, h or 1)
end

-- ===== traço de pena ======================================================
-- Reta com ondulação lenta (duas senoides por seed) e "pressão" ocasional
-- (um pixel a mais no lado). opts: wobble (px, default 1.2), dash/gap
-- (comprimentos; nil = contínua), weight (1|2).
function Ink.line(x1, y1, x2, y2, color, alpha, seed, opts)
    opts = opts or {}
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then Ink.px(x1, y1, color, alpha); return end
    local nx, ny = -dy / len, dx / len
    local wob = opts.wobble or 1.2
    local p1 = hash(seed, 1) * 6.2832
    local p2 = hash(seed, 2) * 6.2832
    local f1 = 0.17 + hash(seed, 3) * 0.08
    local dash, gap = opts.dash, opts.gap or 3
    local period = dash and (dash + gap) or 0
    local weight = opts.weight or 1
    local lastX, lastY
    for i = 0, math.floor(len) do
        local on = true
        if dash then on = (i % period) < dash end
        if on then
            local t = i / len
            local w = (math.sin(i * f1 + p1) * 0.6 + math.sin(i * 0.055 + p2) * 0.5) * wob
            local x = math.floor(x1 + dx * t + nx * w + 0.5)
            local y = math.floor(y1 + dy * t + ny * w + 0.5)
            if x ~= lastX or y ~= lastY then
                Ink.px(x, y, color, alpha)
                if weight > 1 or hash(seed, i, 7) < 0.12 then
                    Ink.px(x + (math.abs(nx) > 0.5 and 1 or 0), y + (math.abs(nx) > 0.5 and 0 or 1), color, alpha)
                end
                lastX, lastY = x, y
            end
        end
    end
end

-- Anel desenhado à mão: raio ondula, o traço passa do ponto de partida (a
-- pena fecha o círculo com sobra), espessura varia.
function Ink.ring(cx, cy, r, color, alpha, seed, weight)
    local n = math.max(12, math.floor(r * 7))
    local p1 = hash(seed, 11) * 6.2832
    local start = hash(seed, 12) * 6.2832
    local lastX, lastY
    for i = 0, math.floor(n * 1.07) do
        local a = start + (i / n) * 6.2832
        local rr = r + math.sin(a * 2 + p1) * 0.9 + math.sin(a * 5 + p1 * 2) * 0.5
        local x = math.floor(cx + math.cos(a) * rr + 0.5)
        local y = math.floor(cy + math.sin(a) * rr + 0.5)
        if x ~= lastX or y ~= lastY then
            Ink.px(x, y, color, alpha)
            if (weight or 1) > 1 or hash(seed, i, 13) < 0.3 then
                Ink.px(x + (math.cos(a) > 0 and 1 or -1), y, color, alpha)
            end
            lastX, lastY = x, y
        end
    end
end

-- Hachura curta (marca "não explorado"): três risquinhos subindo.
function Ink.hatch(x, y, color, alpha, seed, len)
    len = len or 5
    for k = -1, 1 do
        local ox = k * 3
        Ink.line(x + ox, y, x + ox + 1, y - len, color, alpha, seed + k * 17, { wobble = 0.4, dash = 2, gap = 1 })
    end
end

-- ===== glifos (bitmaps 1-bit, desenhados a traço) =========================
-- Cada tipo de parada tem um símbolo pequeno, do jeito que se desenha num
-- mapa à mão: espadas cruzadas, caveira, fogueira, ponto de interrogação,
-- saco de moedas, torre, castelo. '#' = tinta.
local RAW = {
    battle = {
        "#.......#",
        ".#.....#.",
        "..#...#..",
        "...#.#...",
        "....#....",
        "...#.#...",
        "..#...#..",
        ".###.###.",
        ".#.....#.",
    },
    elite = {
        "..#####..",
        ".#######.",
        ".##.#.##.",
        ".##.#.##.",
        ".#######.",
        "..##.##..",
        "..#.#.#..",
        "...###...",
        ".........",
    },
    mini_boss = {
        ".#.#.#.#.",
        ".#######.",
        "..#...#..",
        "..#.#.#..",
        "..#...#..",
        "..#.#.#..",
        "..#...#..",
        "..#.#.#..",
        ".#######.",
    },
    boss = {   -- usado só em endless (fora dele o castelo grande ocupa o lugar)
        "#.#...#.#",
        "###...###",
        "#.#####.#",
        "#.......#",
        "#..###..#",
        "#.#...#.#",
        "#.#...#.#",
        "#.#...#.#",
        "###...###",
    },
    rest = {
        "....#....",
        "...#.#...",
        "...#.#...",
        "..#...#..",
        "..#.#.#..",
        "...###...",
        "#.......#",
        ".#######.",
        "#.......#",
    },
    event = {
        "..#####..",
        ".##...##.",
        ".#.....#.",
        ".......#.",
        "......#..",
        ".....#...",
        "....#....",
        ".........",
        "....#....",
    },
    shop = {
        "...###...",
        "..#...#..",
        "...#.#...",
        "..##.##..",
        ".#.....#.",
        "#...#...#",
        "#..###..#",
        "#...#...#",
        ".#######.",
    },
    unknown = {
        "...###...",
        "..#...#..",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        "..#...#..",
        "...###...",
    },
}

Ink.CASTLE_RAW = {
    "#.#.#...........#.#.#",
    "#####...........#####",
    "#...#...........#...#",
    "#...#.#.#.#.#.#.#...#",
    "#...#############...#",
    "#...##.........##...#",
    "#...##.........##...#",
    "#...##...###...##...#",
    "#...##..#...#..##...#",
    "#...##..#...#..##...#",
    "#...##..#...#..##...#",
    "#...##..#...#..##...#",
    "#########...#########",
}

local function parse(rows)
    local pts, w, h = {}, 0, #rows
    for y, row in ipairs(rows) do
        w = math.max(w, #row)
        for x = 1, #row do
            if row:sub(x, x) == "#" then pts[#pts + 1] = { x - 1, y - 1 } end
        end
    end
    return { pts = pts, w = w, h = h }
end

local GLYPHS = {}
for name, rows in pairs(RAW) do GLYPHS[name] = parse(rows) end
local CASTLE = parse(Ink.CASTLE_RAW)
Ink.GLYPH_NAMES = { "battle", "elite", "mini_boss", "boss", "rest", "event", "shop", "unknown" }

function Ink.hasGlyph(name) return GLYPHS[name] ~= nil end

-- Glifo centrado em (cx, cy), escala inteira. `faded` = alpha menor +
-- pixels pulados (traço de lápis fraco).
function Ink.glyph(name, cx, cy, scale, color, alpha, seed, faded)
    local g = GLYPHS[name] or GLYPHS.unknown
    scale = scale or 1
    local ox = math.floor(cx - g.w * scale / 2)
    local oy = math.floor(cy - g.h * scale / 2)
    for i, p in ipairs(g.pts) do
        if not faded or hash(seed or 0, i, 5) > 0.22 then
            Ink.px(ox + p[1] * scale, oy + p[2] * scale, color, alpha, scale, scale)
        end
    end
end

-- Castelo (canto superior esquerdo em x, y), escala inteira; `faded` =
-- ainda não alcançado (traço fraco e falhado).
function Ink.castle(x, y, scale, color, alpha, seed, faded)
    for i, p in ipairs(CASTLE.pts) do
        if not faded or hash(seed or 0, i, 6) > 0.35 then
            Ink.px(x + p[1] * scale, y + p[2] * scale, color, alpha, scale, scale)
        end
    end
end

function Ink.castleSize() return CASTLE.w, CASTLE.h end

-- ===== papel ==============================================================
-- Textura base 256×256 (gerada uma vez, por pixel, determinística, tileável
-- porque o ruído é hash de (x, y) com células que fecham no 256): três tons
-- de pergaminho com pontilhado de fibra e zonas levemente mais escuras.
local noiseImg
local function smoothNoise(x, y, cell, salt)
    local cx, cy = math.floor(x / cell), math.floor(y / cell)
    local n = 256 / cell
    local fx, fy = (x / cell) - cx, (y / cell) - cy
    local function v(i, j) return hash((i % n), (j % n), salt) end
    local a = lerp(v(cx, cy), v(cx + 1, cy), fx)
    local b = lerp(v(cx, cy + 1), v(cx + 1, cy + 1), fx)
    return lerp(a, b, fy)
end

local function paperNoise()
    if noiseImg then return noiseImg end
    local id = love.image.newImageData(256, 256)
    local P0, P1, P2 = Ink.PAPER, Ink.PAPER_LIGHT, Ink.PAPER_DARK
    id:mapPixel(function(x, y)
        local low = smoothNoise(x, y, 32, 41)
        local mid = smoothNoise(x, y, 8, 42)
        local fine = hash(x, y, 43)
        local c = P0
        if fine < 0.045 then
            c = P2                                  -- fibra
        elseif low > 0.68 and mid > 0.5 and fine < 0.55 then
            c = P2                                  -- zona envelhecida (dither)
        elseif low < 0.32 and fine < 0.5 then
            c = P1                                  -- zona clara
        end
        return c[1], c[2], c[3], 1
    end)
    noiseImg = love.graphics.newImage(id)
    noiseImg:setFilter("nearest", "nearest")
    noiseImg:setWrap("repeat", "repeat")
    return noiseImg
end

-- Perfil rasgado de uma borda: deslocamento por posição (0..amp), com
-- pequenas mordidas. Determinístico por seed + lado.
local function tornProfile(len, seed, side, amp)
    local off = {}
    local p1, p2 = hash(seed, side, 1) * 6.28, hash(seed, side, 2) * 6.28
    for i = 0, len do
        local w = (math.sin(i * 0.09 + p1) + math.sin(i * 0.23 + p2) * 0.6 + 1.6) / 3.2
        local o = math.floor(w * amp + hash(seed, side, i) * 1.6)
        if hash(seed, side, i, 9) < 0.03 then o = o + 2 end   -- mordida
        off[i] = math.max(0, o)
    end
    return off
end

local paperCache, paperOrder = {}, {}
local PAPER_CACHE_MAX = 12

-- Folha w×h como Canvas (cacheada por tamanho+seed). Borda rasgada com aro
-- escuro, manchas ditheradas. Desenhe com love.graphics.draw(canvas, x, y).
function Ink.paper(w, h, seed)
    w, h = math.max(8, math.floor(w)), math.max(8, math.floor(h))
    local key = w .. "x" .. h .. ":" .. tostring(seed or 0)
    local c = paperCache[key]
    if c then return c end

    local canvas = love.graphics.newCanvas(w, h)
    canvas:setFilter("nearest", "nearest")
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.push("all")
    -- O scissor da zona rolável do chamador vale TAMBÉM dentro do canvas:
    -- sem limpar, as primeiras linhas da folha nasciam transparentes.
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")

    -- base: textura tileada, deslocada por seed (duas folhas não são iguais)
    local img = paperNoise()
    local ox = math.floor(hash(seed or 0, 21) * 256)
    local oy = math.floor(hash(seed or 0, 22) * 256)
    local quad = love.graphics.newQuad(ox, oy, w, h, 256, 256)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, quad, 0, 0)

    -- manchas: elipses ditheradas, densidade caindo do centro pra borda
    Ink.begin()
    local nStains = 3 + math.floor(hash(seed or 0, 23) * 3)
    for s = 1, nStains do
        local cx = hash(seed or 0, 30, s) * w
        local cy = hash(seed or 0, 31, s) * h
        local rx = 10 + hash(seed or 0, 32, s) * math.min(60, w * 0.12)
        local ry = 6 + hash(seed or 0, 33, s) * math.min(30, h * 0.12)
        local alpha = 0.14 + hash(seed or 0, 34, s) * 0.12
        for y = math.max(0, math.floor(cy - ry)), math.min(h - 1, math.floor(cy + ry)) do
            for x = math.max(0, math.floor(cx - rx)), math.min(w - 1, math.floor(cx + rx)) do
                local dx, dy = (x - cx) / rx, (y - cy) / ry
                local d = dx * dx + dy * dy
                if d < 1 and hash(x, y, s) < (1 - d) * 0.75 then
                    Ink.px(x, y, Ink.PAPER_STAIN, alpha)
                end
            end
        end
    end
    Ink.flush()

    -- borda rasgada: recorta (replace transparente) e põe o aro escuro
    local amp = math.max(2, math.min(5, math.floor(math.min(w, h) / 40)))
    local top, bot = tornProfile(w, seed or 0, 1, amp), tornProfile(w, seed or 0, 2, amp)
    local left, right = tornProfile(h, seed or 0, 3, amp), tornProfile(h, seed or 0, 4, amp)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    for x = 0, w - 1 do
        if top[x] > 0 then love.graphics.rectangle("fill", x, 0, 1, top[x]) end
        if bot[x] > 0 then love.graphics.rectangle("fill", x, h - bot[x], 1, bot[x]) end
    end
    for y = 0, h - 1 do
        if left[y] > 0 then love.graphics.rectangle("fill", 0, y, left[y], 1) end
        if right[y] > 0 then love.graphics.rectangle("fill", w - right[y], y, right[y], 1) end
    end
    love.graphics.setBlendMode("alpha")
    Ink.begin()
    for x = 0, w - 1 do
        Ink.px(x, top[x], Ink.PAPER_RIM, 0.85)
        Ink.px(x, h - 1 - bot[x], Ink.PAPER_RIM, 0.85)
        -- faixa interna levemente escurecida (dither): papel gasto na borda
        if hash(x, 1, 50) < 0.45 then Ink.px(x, top[x] + 1, Ink.PAPER_DARK, 0.9) end
        if hash(x, 2, 50) < 0.45 then Ink.px(x, h - 2 - bot[x], Ink.PAPER_DARK, 0.9) end
    end
    for y = 0, h - 1 do
        Ink.px(left[y], y, Ink.PAPER_RIM, 0.85)
        Ink.px(w - 1 - right[y], y, Ink.PAPER_RIM, 0.85)
        if hash(3, y, 50) < 0.45 then Ink.px(left[y] + 1, y, Ink.PAPER_DARK, 0.9) end
        if hash(4, y, 50) < 0.45 then Ink.px(w - 2 - right[y], y, Ink.PAPER_DARK, 0.9) end
    end
    Ink.flush()

    love.graphics.setCanvas(prevCanvas)
    love.graphics.pop()

    paperCache[key] = canvas
    paperOrder[#paperOrder + 1] = key
    if #paperOrder > PAPER_CACHE_MAX then
        local old = table.remove(paperOrder, 1)
        local oc = paperCache[old]
        paperCache[old] = nil
        if oc and oc.release then oc:release() end
    end
    return canvas
end

function Ink.clearPaperCache()
    for _, key in ipairs(paperOrder) do
        local c = paperCache[key]
        if c and c.release then c:release() end
    end
    paperCache, paperOrder = {}, {}
end

-- Sombra da folha = a própria silhueta deslocada, em tinta: segue a borda
-- rasgada de graça.
function Ink.drawSheet(canvas, x, y)
    love.graphics.setColor(Ink.INK[1], Ink.INK[2], Ink.INK[3], 0.6)
    love.graphics.draw(canvas, x + 2, y + 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, x, y)
end

return Ink
