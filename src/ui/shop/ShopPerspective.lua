-- src/ui/shop/ShopPerspective.lua
-- A PERSPECTIVA ÚNICA DA MESA do Balcão do Mercador (Loja v3c).
--
-- Queixa do dono (13/Out/2026): "os itens não seguem a diagonal da mesa; até
-- a badge do nome tem que seguir a diagonal; TUDO: os preços, as próprias
-- cartas" e "a sensação de que os itens estão flutuando é a pior coisa".
--
-- Uma transformação só, medida na pintura (assets/sprites/shop/counter_scene.png,
-- coordenadas da ARTE 688x384):
--   * a borda do fundo (onde os cavaletes apoiam) sobe ~6,8° pra direita;
--   * a borda da frente do tampo sobe ~11° pra direita;
--   * as duas fogem pro MESMO ponto de fuga VP = (2187, -58).
-- Logo a "diagonal" num ponto qualquer da mesa é a reta até o VP: a
-- inclinação ali é slope = (VP.y - y) / (VP.x - x) (negativa: sobe pra
-- direita). As verticais continuam verticais (a pintura é em perspectiva de
-- dois pontos com o terceiro no infinito). Então todo objeto em pé recebe um
-- CISALHAMENTO vertical (love.graphics.shear(0, slope)) em torno do pé, e
-- tudo que é texto/placa/etiqueta/carta/cavalete usa o mesmo slope.
--
-- Os objetos são desenhados num canvas na resolução da ARTE (688x384) e
-- sobem pro tamanho da tela com nearest, junto da pintura: o cisalhamento
-- acontece em pixel de arte, então o objeto inclinado continua pixel art de
-- verdade (pixel quadrado, escada nítida), na mesma grade do cenário.
--
-- Sombra de CONTATO (nada flutua): faixa curta e escura colada na base de
-- cada coluna que toca a mesa, cauda pra direita ao longo da diagonal (a vela
-- está à esquerda), dither Bayer, sem borda suave, cortada pela máscara do
-- tampo. Nada de elipse.

local ShopPerspective = {}

local ImageCache = require("src.ui.ImageCache")
local Palette    = require("src.ui.Palette")

local floor = math.floor
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Ponto de fuga do eixo longo do balcão (medido: borda do fundo y=181 em
-- x=180 → y=150 em x=440; borda da frente y=316 em x=260 → y=281 em x=440).
ShopPerspective.VP = { x = 2187, y = -58 }

function ShopPerspective.slopeArt(ax, ay)
    local VP = ShopPerspective.VP
    return (VP.y - ay) / (VP.x - ax)
end

-- slope em coordenadas de TELA (o cover-fit é escala uniforme: o slope é o
-- mesmo; só converte o ponto)
function ShopPerspective.slopeAt(cv, sx, sy)
    return ShopPerspective.slopeArt((sx - cv.ox) / cv.s, (sy - cv.oy) / cv.s)
end

-- ============================================================================
-- POSE dos objetos (artes ANTIGAS, frontais ou de três quartos):
--   flip  = espelha (sx = -1): a arte vista "da direita" passa a mostrar o
--           lado esquerdo, como a mesa (pedido do dono pra bancada de coringa)
--   shear = fração do slope da mesa aplicada como cisalhamento (1 = a base
--           inteira na diagonal; menos quando a arte de três quartos já traz
--           parte da inclinação depois do espelho)
--   size  = escala relativa (o pacote é alto: ocupa menos)
-- A MESMA pose vale em repouso, em hover e no pergaminho (só o pergaminho
-- dispensa o cisalhamento: lá a peça é retrato, não está na mesa).
-- ============================================================================
ShopPerspective.POSE = {
    remove_card       = { flip = false, shear = 1.0 },
    joker_slot        = { flip = true,  shear = 0.6 },
    health_upgrade    = { flip = false, shear = 1.0 },
    mana_upgrade      = { flip = true,  shear = 0.8 },
    card_draw_upgrade = { flip = true,  shear = 0.6 },
    interest_cap      = { flip = true,  shear = 0.6 },
    forge_card        = { flip = true,  shear = 0.7 },
    duplicate_card    = { flip = true,  shear = 0.6 },
    damage_upgrade    = { flip = false, shear = 1.0 },
    defense_upgrade   = { flip = false, shear = 1.0 },
    bell              = { flip = false, shear = 1.0 },
    pack              = { flip = false, shear = 1.0, size = 0.95 },
}
local DEFAULT_POSE = { flip = false, shear = 1.0 }

function ShopPerspective.poseFor(kind, offer)
    if kind == "pack" then return ShopPerspective.POSE.pack end
    if kind == "bell" then return ShopPerspective.POSE.bell end
    return (offer and ShopPerspective.POSE[offer.id]) or DEFAULT_POSE
end

-- ============================================================================
-- SPRITE de um objeto: a arte ANTIGA (vouchers/ e packs/). A animação de
-- vouchers_anim/ entra no hover (quadro 0 = o PNG estático, conferido): é a
-- MESMA peça na MESMA pose, nunca outra imagem.
--   devolve img, srcKey (srcKey = de onde veio: igual em repouso e hover)
-- ============================================================================
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print("[ShopPerspective] " .. msg)
end

function ShopPerspective.spriteFor(kind, offer, animate, t)
    if kind == "relic" then
        local UpgradeTile = require("src.ui.UpgradeTile")
        local img = UpgradeTile.spriteFor(offer and offer.id, animate, t)
        if not img then warnOnce("relic:" .. tostring(offer and offer.id),
            "voucher sem arte: " .. tostring(offer and offer.id)) end
        return img, "assets/sprites/vouchers/" .. tostring(offer and offer.id) .. ".png"
    elseif kind == "pack" then
        local ok, PackSleeve = pcall(require, "src.ui.PackSleeve")
        if ok and PackSleeve then
            return PackSleeve.getImage(offer and offer.id, offer and offer.kind),
                "assets/sprites/packs/" .. tostring(offer and offer.id) .. ".png"
        end
        warnOnce("packsleeve", "PackSleeve indisponivel")
        return nil, nil
    elseif kind == "bell" then
        local p = "assets/sprites/shop/objects/bell.png"
        return ImageCache.tryGet(p), p
    end
    return nil, nil
end

-- ============================================================================
-- PERFIL da silhueta (ImageData lida uma vez por arquivo): caixa opaca e a
-- linha mais baixa de cada coluna (o "pé" real da arte, não o fim do PNG).
-- ============================================================================
local PROFILES = {}
function ShopPerspective.profile(path, img)
    if path and PROFILES[path] ~= nil then return PROFILES[path] or nil end
    local data
    if path and love.filesystem.getInfo(path) then
        local ok, d = pcall(love.image.newImageData, path)
        if ok then data = d end
    end
    if not data then
        if path then PROFILES[path] = false end
        if img then
            local w, h = img:getWidth(), img:getHeight()
            return { x0 = 0, y0 = 0, x1 = w - 1, y1 = h - 1, w = w, h = h, bottom = {}, left = {}, right = {} }
        end
        return nil
    end
    local w, h = data:getWidth(), data:getHeight()
    local x0, y0, x1, y1 = w, h, -1, -1
    local bottom, left, right = {}, {}, {}
    for x = 0, w - 1 do
        for y = h - 1, 0, -1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                bottom[x] = y
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y > y1 then y1 = y end
                break
            end
        end
        for y = 0, h - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                if y < y0 then y0 = y end
                break
            end
        end
    end
    if x1 < 0 then x0, y0, x1, y1 = 0, 0, w - 1, h - 1 end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                if not left[y] then left[y] = x end
                right[y] = x
            end
        end
    end
    local p = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, w = w, h = h, bottom = bottom, left = left, right = right }
    if path then PROFILES[path] = p end
    return p
end

-- ============================================================================
-- CANVAS NA RESOLUÇÃO DA ARTE + passada
-- ============================================================================
local canvas, canvasW, canvasH
local quadBlit
local function getCanvas(w, h)
    if canvas and canvasW == w and canvasH == h then return canvas end
    local ok, c = pcall(love.graphics.newCanvas, w, h)
    if not ok then
        warnOnce("canvas", "canvas da mesa falhou: " .. tostring(c))
        return nil
    end
    c:setFilter("nearest", "nearest")
    canvas, canvasW, canvasH = c, w, h
    return c
end

-- Desenha `fn()` em coordenadas da ARTE e sobe o recorte `box` (arte) pra
-- tela pelo cover-fit. Sem canvas (falha de driver), desenha direto na tela
-- com a mesma transformação (perde só o pixel quadrado; AVISA).
function ShopPerspective.artPass(L, box, fn)
    local A, cv = L.art, L.cover
    local c = getCanvas(A.w, A.h)
    if not c then
        love.graphics.push()
        love.graphics.translate(cv.ox, cv.oy)
        love.graphics.scale(cv.s, cv.s)
        fn()
        love.graphics.pop()
        return
    end
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    fn()
    love.graphics.pop()
    local x0 = clamp(floor(box and box.x or 0), 0, A.w)
    local y0 = clamp(floor(box and box.y or 0), 0, A.h)
    local x1 = clamp(math.ceil(box and (box.x + box.w) or A.w), 0, A.w)
    local y1 = clamp(math.ceil(box and (box.y + box.h) or A.h), 0, A.h)
    if x1 <= x0 or y1 <= y0 then return end
    if not quadBlit then quadBlit = love.graphics.newQuad(0, 0, 1, 1, A.w, A.h) end
    quadBlit:setViewport(x0, y0, x1 - x0, y1 - y0, A.w, A.h)
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c, quadBlit, cv.ox + x0 * cv.s, cv.oy + y0 * cv.s, 0, cv.s, cv.s)
    love.graphics.pop()
end

-- ============================================================================
-- SILHUETA (contorno claro de 1 px de arte no hover)
-- ============================================================================
local silShader, silTried
local function silhouette()
    if silTried then return silShader end
    silTried = true
    local ok, sh = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            float a = Texel(tex, uv).a;
            return vec4(color.rgb, color.a * step(0.5, a));
        }
    ]])
    if ok then silShader = sh else warnOnce("sil", "shader de silhueta falhou: " .. tostring(sh)) end
    return silShader
end
ShopPerspective.silhouette = silhouette

-- Transformação de um objeto EM PÉ, em coordenadas da arte:
--   pé (fx, fy), escala s (px de arte por px do sprite), slope k já com o
--   fator da pose, espelho. O pé da ARTE (perfil) cai exatamente no ponto.
local function applyUpright(fx, fy, s, k, flip, prof)
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    love.graphics.translate(fx, fy)
    love.graphics.shear(0, k)
    love.graphics.scale(flip and -s or s, s)
    love.graphics.translate(-cx, -bottom)
end

-- Desenha o objeto em pé (+ contorno de hover) no canvas da arte.
--   o = { img, prof, fx, fy, s, k, flip, lift, outline (0..1), color, alpha }
function ShopPerspective.drawUpright(o)
    local img, prof = o.img, o.prof
    if not (img and prof) then return end
    local fy = o.fy - (o.lift or 0)
    local a = o.alpha or 1
    if (o.outline or 0) > 0.01 then
        local sh = silhouette()
        if sh then
            love.graphics.setShader(sh)
            local c = o.outlineColor or Palette.PARCHMENT_LIGHT
            love.graphics.setColor(c[1], c[2], c[3], o.outline * a)
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                love.graphics.push()
                applyUpright(floor(o.fx) + d[1], floor(fy) + d[2], o.s, o.k, o.flip, prof)
                love.graphics.draw(img, 0, 0)
                love.graphics.pop()
            end
            love.graphics.setShader()
        end
    end
    local col = o.color or { 1, 1, 1 }
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.push()
    applyUpright(floor(o.fx), floor(fy), o.s, o.k, o.flip, prof)
    love.graphics.draw(img, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Caixa (arte) ocupada pelo objeto em pé (pra recorte da passada e hit-test).
function ShopPerspective.uprightBox(o)
    local prof = o.prof
    if not prof then return nil end
    local s = o.s
    local w = (prof.x1 - prof.x0 + 1) * s
    local h = (prof.y1 - prof.y0 + 1) * s
    local skew = math.abs(o.k) * w / 2
    return { x = o.fx - w / 2 - 2, y = o.fy - h - skew - (o.lift or 0) - 2,
             w = w + 4, h = h + skew * 2 + (o.lift or 0) + 6 }
end

-- Ponto (arte) na borda DIREITA da silhueta a `frac` da altura (a partir da
-- base): onde o cordão da etiqueta de preço se amarra no objeto.
function ShopPerspective.tiePoint(o, frac)
    local prof = o.prof
    if not (prof and prof.left) then return o.fx, o.fy end
    local s = o.s
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    local row = floor(prof.y1 - (prof.y1 - prof.y0) * (frac or 0.35))
    local sx
    for dy = 0, 6 do
        sx = o.flip and prof.left[row - dy] or prof.right[row - dy]
        if sx then row = row - dy break end
    end
    if not sx then return o.fx, o.fy end
    local lx = o.flip and -s * (sx - cx) or s * (sx + 1 - cx)
    local ly = s * (row + 0.5 - bottom)
    return o.fx + lx - 1, o.fy - (o.lift or 0) + ly + o.k * lx
end

-- ============================================================================
-- SOMBRA DE CONTATO (dither Bayer 4x4, sem borda suave)
-- ============================================================================
local BAYER = {
    { 0, 8, 2, 10 },
    { 12, 4, 14, 6 },
    { 3, 11, 1, 9 },
    { 15, 7, 13, 5 },
}
local function dithered(x, y, density)
    if density >= 1 then return true end
    if density <= 0 then return false end
    return BAYER[(y % 4) + 1][(x % 4) + 1] < density * 16
end
ShopPerspective.dithered = dithered

local pts = {}
-- mask = polígono (arte) onde a sombra pode cair; nil = sem corte.
function ShopPerspective.drawContactShadow(o, mask, alpha)
    local prof = o.prof
    if not prof then return end
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local inPoly = ShopLayout.pointInPoly
    local s, k = o.s, o.k
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    local fx, fy = floor(o.fx), floor(o.fy)
    local halfW = (prof.x1 - prof.x0 + 1) * s / 2
    local tol = math.max(2, 3 * s)          -- coluna "encosta" se a base está a ≤ 3 px do pé
    local n = 0
    local right = nil
    local lightK = 1 - clamp((o.lift or 0) / 6, 0, 0.6)  -- levantado: sombra mais rala
    for dx = floor(fx - halfW) - 1, math.ceil(fx + halfW) + 1 do
        local lx = dx + 0.5 - fx
        local sx = cx + lx / (o.flip and -s or s)
        local b = prof.bottom[floor(sx)]
        if b then
            local gap = (bottom - (b + 1)) * s
            if gap <= tol then
                local by = fy + k * lx - gap
                local yy = floor(by)
                for row = 0, 1 do
                    local dens = (row == 0) and 0.85 or 0.4
                    if dithered(dx, yy + row, dens * lightK) and (not mask or inPoly(dx + 0.5, yy + row + 0.5, mask)) then
                        n = n + 1; pts[n] = { dx + 0.5, yy + row + 0.5 }
                    end
                end
                right = dx
            end
        end
    end
    -- cauda pra direita, ao longo da diagonal (vela à esquerda): rala e curta
    if right then
        local tail = math.max(3, floor(halfW * 0.4))
        for i = 1, tail do
            local dx = right + i
            local lx = dx + 0.5 - fx
            local yy = floor(fy + k * lx)
            local dens = (0.95 - 0.7 * (i / (tail + 1))) * lightK
            for row = -1, 0 do
                if dithered(dx, yy + row, dens * (row == 0 and 1 or 0.6)) and (not mask or inPoly(dx + 0.5, yy + row + 0.5, mask)) then
                    n = n + 1; pts[n] = { dx + 0.5, yy + row + 0.5 }
                end
            end
        end
    end
    for i = n + 1, #pts do pts[i] = nil end
    if n == 0 then return end
    local ink = Palette.darken and Palette.darken(Palette.INK, 0.35) or Palette.INK
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.78 * (alpha or 1))
    love.graphics.points(pts)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Pontos de contato (arte) de um objeto: usados pelo teste "nada flutua"
-- (todo pé de coluna encostado tem que estar DENTRO do tampo).
function ShopPerspective.contactPoints(o)
    local prof = o.prof
    if not prof then return {} end
    local s, k = o.s, o.k
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    local fx, fy = floor(o.fx), floor(o.fy)
    local halfW = (prof.x1 - prof.x0 + 1) * s / 2
    local out = {}
    for dx = floor(fx - halfW), math.ceil(fx + halfW) do
        local lx = dx + 0.5 - fx
        local sx = cx + lx / (o.flip and -s or s)
        local b = prof.bottom[floor(sx)]
        if b and (bottom - (b + 1)) * s <= math.max(2, 3 * s) then
            out[#out + 1] = { dx + 0.5, fy + k * lx - (bottom - (b + 1)) * s }
        end
    end
    return out
end

-- ============================================================================
-- HOMOGRAFIA (quadrado unitário → quadrilátero): a carta no cavalete.
-- Cantos em ordem TL, TR, BR, BL. Devolve as 3 linhas da matriz.
-- ============================================================================
function ShopPerspective.homography(x0, y0, x1, y1, x2, y2, x3, y3)
    local sx = x0 - x1 + x2 - x3
    local sy = y0 - y1 + y2 - y3
    local g, h = 0, 0
    if math.abs(sx) > 1e-6 or math.abs(sy) > 1e-6 then
        local dx1, dx2 = x1 - x2, x3 - x2
        local dy1, dy2 = y1 - y2, y3 - y2
        local den = dx1 * dy2 - dx2 * dy1
        if math.abs(den) > 1e-9 then
            g = (sx * dy2 - dx2 * sy) / den
            h = (dx1 * sy - sx * dy1) / den
        end
    end
    local a = x1 - x0 + g * x1
    local b = x3 - x0 + h * x3
    local d = y1 - y0 + g * y1
    local e = y3 - y0 + h * y3
    return { a, b, x0 }, { d, e, y0 }, { g, h, 1 }
end

-- Mapeia (u, v) do quadrado unitário pelo resultado de homography().
function ShopPerspective.mapH(r0, r1, r2, u, v)
    local w = r2[1] * u + r2[2] * v + r2[3]
    return (r0[1] * u + r0[2] * v + r0[3]) / w, (r1[1] * u + r1[2] * v + r1[3]) / w
end

return ShopPerspective
