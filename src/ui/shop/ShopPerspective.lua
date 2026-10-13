-- src/ui/shop/ShopPerspective.lua
-- A INCLINAÇÃO ÚNICA DA MESA do Balcão do Mercador (Loja v4).
--
-- v4 (13/Out/2026, docs/plan/shop-v4-estudo.md): o ponto de fuga da v3c deu
-- uma borda a 6,83 graus, que na grade da arte vira escadinha irregular
-- (degraus de 8 e 9 px misturados). Agora tudo segue UMA inclinação de pixel
-- art, 1:8 (sobe 1 px de arte a cada 8 px pra direita): as arestas das duas
-- superfícies (pintadas na grade por tools/shop_v4_compose.py), a carta, o
-- cavalete, a plaquinha, a etiqueta, as sombras e os objetos. As verticais
-- continuam verticais (projeção oblíqua).
--
-- Os objetos são desenhados num canvas na resolução da ARTE (640x360) em
-- ESCALA 1 (pixel do sprite = pixel da cena) e sobem pro tamanho da tela com
-- nearest, junto da pintura. Arte antiga frontal recebe cisalhamento inteiro
-- (1:8 ou 1:16: degraus regulares); a arte nova (elixir, pacotes) já vem
-- desenhada na diagonal e não é cisalhada.
--
-- Sombra de CONTATO (nada flutua): faixa curta e escura colada na base de
-- cada coluna que toca a mesa, cauda pra direita ao longo da diagonal (a luz
-- vem da esquerda), dither Bayer, sem borda suave, cortada pela máscara do
-- tampo. Nada de elipse.

local ShopPerspective = {}

local ImageCache = require("src.ui.ImageCache")
local Palette    = require("src.ui.Palette")

local floor = math.floor
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function ShopPerspective.slopeArt()
    return require("src.ui.shop.ShopLayout").K
end

-- slope em coordenadas de TELA (o cover-fit é escala uniforme: o slope é o
-- mesmo; só converte o ponto)
function ShopPerspective.slopeAt(cv, sx, sy)
    return ShopPerspective.slopeArt((sx - cv.ox) / cv.s, (sy - cv.oy) / cv.s)
end

-- ============================================================================
-- FRAME DA BORDA (Loja "reta", 13/Out/2026). Queixa do dono: "as cartas não
-- estão seguindo a mesma reta". Antes a carta usava uma homografia própria
-- (base girada mais que a borda), o trilho seguia a base, e a faixa de
-- raridade/etiqueta outra conta: três ângulos na mesma carta.
--
-- Agora TUDO da carta (carta, trilho do cavalete, plaquinha de raridade,
-- etiqueta de preço, sombra) mora num frame só:
--   origem  = o ponto da BORDA PINTADA (ShopLayout.ART.ledgeEdge, medida na
--             pintura) sob o centro da carta, em px de tela;
--   k       = inclinação da borda (a MESMA reta para as 4 cartas: as bases
--             são colineares com a borda pintada, não só paralelas);
--   u, n    = vetor unitário da borda e a perpendicular "pra cima";
--   s       = escala do cover-fit (px de tela por px de arte).
-- Local (u, v): u = deslocamento horizontal ao longo da borda, v = altura
-- pra cima (as verticais da pintura continuam verticais). frameAt(f, u, v)
-- = (ox + u, oy + k*u - v): é exatamente translate(origem) + shear(0, k).
-- ============================================================================
function ShopPerspective.edgeY(ax)
    local E = require("src.ui.shop.ShopLayout").ART.ledgeEdge
    return E.y0 + E.k * (ax - E.x0)
end

function ShopPerspective.edgeFrame(slot, cv)
    local E = require("src.ui.shop.ShopLayout").ART.ledgeEdge
    local ax = slot.art and slot.art.x or slot.x
    -- origem em px de tela inteiro (a passada da arte e a da UI concordam)
    local ox = floor(cv.ox + ax * cv.s + 0.5)
    local axr = (ox - cv.ox) / cv.s
    local ay = E.y0 + E.k * (axr - E.x0)
    local oy = cv.oy + ay * cv.s
    local k = E.k
    local n = math.sqrt(1 + k * k)
    return {
        ox = ox, oy = oy, k = k,
        ux = 1 / n, uy = k / n,          -- ao longo da borda (pra direita)
        nx = k / n, ny = -1 / n,         -- perpendicular, pra cima
        s = cv.s,
        art = { x = axr, y = ay },
    }
end

function ShopPerspective.frameAt(f, u, v)
    return f.ox + u, f.oy + f.k * u - (v or 0)
end

-- Ângulo (graus) do segmento (x0,y0)-(x1,y1): a trava de "uma reta só".
function ShopPerspective.angleOf(x0, y0, x1, y1)
    return math.deg(math.atan2(y1 - y0, x1 - x0))
end

-- ============================================================================
-- POSE dos objetos:
--   flip  = espelha (sx = -1): a arte vista "da direita" passa a mostrar o
--           lado esquerdo, como a mesa (pedido do dono pra bancada de coringa)
--   shear = fração da inclinação 1:8 aplicada como cisalhamento: SÓ 1 (1:8),
--           0,5 (1:16) ou 0 (arte já desenhada na diagonal). Fração qualquer
--           daria degraus irregulares (o defeito da v3c).
--   size  = escala relativa
-- A MESMA pose vale em repouso, em hover e no pergaminho (só o pergaminho
-- dispensa o cisalhamento: lá a peça é retrato, não está na mesa).
-- ============================================================================
ShopPerspective.POSE = {
    remove_card       = { flip = false, shear = 1.0 },
    joker_slot        = { flip = true,  shear = 0.5 },
    health_upgrade    = { flip = false, shear = 0 },     -- arte v4 na diagonal
    mana_upgrade      = { flip = false, shear = 0 },     -- arte v5 (cristal redondo)
    card_draw_upgrade = { flip = true,  shear = 0.5 },
    interest_cap      = { flip = true,  shear = 0.5 },
    forge_card        = { flip = true,  shear = 0.5 },
    duplicate_card    = { flip = false, shear = 0 },     -- arte v5 (prensa já de canto)
    damage_upgrade    = { flip = false, shear = 1.0 },
    defense_upgrade   = { flip = false, shear = 1.0 },
    bell              = { flip = false, shear = 0 },
    pack              = { flip = false, shear = 0 },     -- arte v4 na diagonal
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

-- Arte v4 desenhada NA DIAGONAL da mesa (assets/sprites/shop/v4/): o elixir
-- e os pacotes. Quando existe, substitui a antiga na mesa E no pergaminho
-- (a mesma peça nos dois lugares).
ShopPerspective.V4_DIR = "assets/sprites/shop/v4/"
-- v5 (Out/2026): capas de pacote refeitas como pacotes de verdade, cristal e
-- prensa novos. A v5 vale antes da v4.
ShopPerspective.V5_DIR = "assets/sprites/shop/v5/"
local function v4Art(id)
    if not id then return nil end
    for _, dir in ipairs({ ShopPerspective.V5_DIR, ShopPerspective.V4_DIR }) do
        local p = dir .. id .. ".png"
        if love.filesystem.getInfo(p) then return ImageCache.tryGet(p), p end
    end
    return nil
end
ShopPerspective.v4Art = v4Art

-- Animação v5 (PixelLab animate_object sobre a arte v5/v4, quadro 0 = o PNG
-- estático): assets/sprites/shop/v5_anim/<id>/<i>.png, 8 fps. Só no HOVER
-- (regra do dono: animação na interação). Mesmo tamanho de canvas do PNG.
ShopPerspective.V5_ANIM_DIR = "assets/sprites/shop/v5_anim/"
ShopPerspective.ANIM_FPS = 8
local animFrames = {}
function ShopPerspective.animFrames(id)
    if not id then return nil end
    if animFrames[id] ~= nil then return animFrames[id] or nil end
    local frames = {}
    for i = 0, 63 do
        local p = ShopPerspective.V5_ANIM_DIR .. id .. "/" .. i .. ".png"
        if not love.filesystem.getInfo(p) then break end
        frames[#frames + 1] = ImageCache.tryGet(p)
    end
    animFrames[id] = (#frames > 1) and frames or false
    return animFrames[id] or nil
end

function ShopPerspective.spriteFor(kind, offer, animate, t)
    local id = offer and offer.id
    if kind == "relic" or kind == "pack" then
        local img, p = v4Art(id)
        if img then
            if animate and kind == "relic" then
                local fr = ShopPerspective.animFrames(id)
                if fr then
                    local k = math.floor((t or 0) * ShopPerspective.ANIM_FPS) % #fr + 1
                    return fr[k] or img, p
                end
            end
            return img, p
        end
    end
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
    -- v5 r2c (dono, duas vezes: "a sombra ainda está errada"): a sombra é
    -- uma PEGADA NO PLANO DA MESA, não o contorno do sprite. Cada coluna da
    -- silhueta recebe sombra na reta 1:8 que passa pelo pé (yT = fy + k*lx),
    -- cheia na largura inteira do objeto:
    --   apoiado   = 2 linhas: a de cima sólida onde a base ENCOSTA (gap <= 2 px)
    --               e em dither onde o objeto só pende sobre a mesa (livro
    --               aberto, bojo da poção), a de baixo em dither mais ralo;
    --   levantado = 4 linhas sólidas (a mancha fechada de um objeto no ar),
    --               1 coluna a mais de cada lado em dither.
    -- Seguir o contorno de baixo (versão anterior) fazia a sombra da poção
    -- virar um arco subindo pelos lados e a do item flutuando sumir.
    local lifted = (o.lift or 0) > 0.5
    local contactTol = math.max(2, 2 * s)
    local n = 0
    local right = nil
    local lightK = 1
    local lastHad = false
    local x0c, x1c = floor(fx - halfW) - 1, math.ceil(fx + halfW) + 1
    for dx = x0c, x1c do
        local lx = dx + 0.5 - fx
        local sx = cx + lx / (o.flip and -s or s)
        local b = prof.bottom[floor(sx)]
        local has = b ~= nil
        local edge = false
        if not has and lifted then
            -- 1 coluna de borda de cada lado da pegada
            local bl = prof.bottom[floor(cx + (lx - 1) / (o.flip and -s or s))]
            local br = prof.bottom[floor(cx + (lx + 1) / (o.flip and -s or s))]
            if bl or br then has, edge = true, true end
        elseif not has and lastHad then
            has = true                          -- buraco de 1 coluna: fecha
        end
        if has then
            local yT = floor(fy + k * lx)
            local gap = b and (bottom - (b + 1)) * s or contactTol
            if lifted then
                for row = 0, 3 do
                    local dens = edge and 0.5 or 1
                    if dithered(dx, yT + row, dens * lightK) and (not mask or inPoly(dx + 0.5, yT + row + 0.5, mask)) then
                        n = n + 1; pts[n] = { dx + 0.5, yT + row + 0.5 }
                    end
                end
            else
                local touch = gap <= contactTol
                local d0 = touch and 1 or 0.55
                local d1 = touch and 0.5 or 0.3
                for row = 0, 1 do
                    local dens = (row == 0) and d0 or d1
                    if dithered(dx, yT + row, dens * lightK) and (not mask or inPoly(dx + 0.5, yT + row + 0.5, mask)) then
                        n = n + 1; pts[n] = { dx + 0.5, yT + row + 0.5 }
                    end
                end
            end
            right = dx
        end
        lastHad = b ~= nil
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
    love.graphics.setColor(ink[1], ink[2], ink[3], (lifted and 0.95 or 0.9) * (alpha or 1))
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

-- Inversa: ponto (x, y) da tela -> (u, v) do quadrado unitário (o mouse no
-- espaço da carta, pro tilt do hover). nil se a matriz for singular.
function ShopPerspective.unmapH(r0, r1, r2, x, y)
    local a, b, c = r0[1], r0[2], r0[3]
    local d, e, f = r1[1], r1[2], r1[3]
    local g, h, i = r2[1], r2[2], r2[3]
    local A, B, C = e * i - f * h, -(d * i - f * g), d * h - e * g
    local det = a * A + b * B + c * C
    if math.abs(det) < 1e-12 then return nil end
    local D, E, F = -(b * i - c * h), a * i - c * g, -(a * h - b * g)
    local G, H, I = b * f - c * e, -(a * f - c * d), a * e - b * d
    local u = (A * x + D * y + G) / det
    local v = (B * x + E * y + H) / det
    local w = (C * x + F * y + I) / det
    if math.abs(w) < 1e-12 then return nil end
    return u / w, v / w
end

-- Mapeia (u, v) do quadrado unitário pelo resultado de homography().
function ShopPerspective.mapH(r0, r1, r2, u, v)
    local w = r2[1] * u + r2[2] * v + r2[3]
    return (r0[1] * u + r0[2] * v + r0[3]) / w, (r1[1] * u + r1[2] * v + r1[3]) / w
end

return ShopPerspective
