local Debug = require("src.core.Debug")

local ShopPerspective = {}

local ImageCache = require("src.ui.ImageCache")
local Palette    = require("src.ui.Palette")

local floor = math.floor
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function ShopPerspective.slopeArt()
    return require("src.ui.shop.ShopLayout").K
end

function ShopPerspective.slopeAt(cv, sx, sy)
    return ShopPerspective.slopeArt((sx - cv.ox) / cv.s, (sy - cv.oy) / cv.s)
end

function ShopPerspective.edgeY(ax)
    local E = require("src.ui.shop.ShopLayout").ART.ledgeEdge
    return E.y0 + E.k * (ax - E.x0)
end

function ShopPerspective.edgeFrame(slot, cv)
    local E = require("src.ui.shop.ShopLayout").ART.ledgeEdge
    local ax = slot.art and slot.art.x or slot.x
    local ox = floor(cv.ox + ax * cv.s + 0.5)
    local axr = (ox - cv.ox) / cv.s
    local ay = E.y0 + E.k * (axr - E.x0)
    local oy = cv.oy + ay * cv.s
    local k = E.k
    local n = math.sqrt(1 + k * k)
    return {
        ox = ox, oy = oy, k = k,
        ux = 1 / n, uy = k / n,
        nx = k / n, ny = -1 / n,
        s = cv.s,
        art = { x = axr, y = ay },
    }
end

function ShopPerspective.frameAt(f, u, v)
    return f.ox + u, f.oy + f.k * u - (v or 0)
end

function ShopPerspective.angleOf(x0, y0, x1, y1)
    return math.deg(math.atan2(y1 - y0, x1 - x0))
end

ShopPerspective.POSE = {
    remove_card       = { flip = false, shear = 1.0 },
    joker_slot        = { flip = true,  shear = 0.5 },
    health_upgrade    = { flip = false, shear = 0 },
    mana_upgrade      = { flip = false, shear = 0 },
    card_draw_upgrade = { flip = true,  shear = 0.5 },
    interest_cap      = { flip = true,  shear = 0.5 },
    forge_card        = { flip = true,  shear = 0.5 },
    duplicate_card    = { flip = false, shear = 0 },
    damage_upgrade    = { flip = false, shear = 1.0 },
    defense_upgrade   = { flip = false, shear = 1.0 },
    bell              = { flip = false, shear = 0 },
    pack              = { flip = false, shear = 0 },
}
local DEFAULT_POSE = { flip = false, shear = 1.0 }

function ShopPerspective.poseFor(kind, offer)
    if kind == "pack" then return ShopPerspective.POSE.pack end
    if kind == "bell" then return ShopPerspective.POSE.bell end
    return (offer and ShopPerspective.POSE[offer.id]) or DEFAULT_POSE
end

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[ShopPerspective] " .. msg)
end

ShopPerspective.V4_DIR = "assets/sprites/shop/v4/"
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

local function crisp(img)
    if img and img.setFilter then
        local mn = img:getFilter()
        if mn ~= "nearest" then img:setFilter("nearest", "nearest") end
    end
    return img
end
ShopPerspective.crisp = crisp

function ShopPerspective.spriteFor(kind, offer, animate, t)
    local img, p = ShopPerspective._spriteFor(kind, offer, animate, t)
    return crisp(img), p
end

function ShopPerspective._spriteFor(kind, offer, animate, t)
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

local PROFILES = {}
function ShopPerspective.profile(path, img, rect)
    local key = path and (rect and (path .. "#" .. rect.x .. "," .. rect.y .. "," .. rect.w .. "," .. rect.h) or path)
    if key and PROFILES[key] ~= nil then return PROFILES[key] or nil end
    local data
    if path and love.filesystem.getInfo(path) then
        local ok, d = pcall(love.image.newImageData, path)
        if ok then data = d end
    end
    if not data then
        if key then PROFILES[key] = false end
        if img then
            local w, h = img:getWidth(), img:getHeight()
            return { x0 = 0, y0 = 0, x1 = w - 1, y1 = h - 1, w = w, h = h, bottom = {}, left = {}, right = {} }
        end
        return nil
    end
    local ox, oy = 0, 0
    local w, h = data:getWidth(), data:getHeight()
    if rect then ox, oy, w, h = rect.x, rect.y, rect.w, rect.h end
    local x0, y0, x1, y1 = w, h, -1, -1
    local bottom, left, right = {}, {}, {}
    for x = 0, w - 1 do
        for y = h - 1, 0, -1 do
            local _, _, _, a = data:getPixel(ox + x, oy + y)
            if a > 0.5 then
                bottom[x] = y
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y > y1 then y1 = y end
                break
            end
        end
        for y = 0, h - 1 do
            local _, _, _, a = data:getPixel(ox + x, oy + y)
            if a > 0.5 then
                if y < y0 then y0 = y end
                break
            end
        end
    end
    if x1 < 0 then x0, y0, x1, y1 = 0, 0, w - 1, h - 1 end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(ox + x, oy + y)
            if a > 0.5 then
                if not left[y] then left[y] = x end
                right[y] = x
            end
        end
    end
    local p = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, w = w, h = h, bottom = bottom, left = left, right = right,
                src = rect and { x = rect.x, y = rect.y, w = rect.w, h = rect.h } or nil }
    if key then PROFILES[key] = p end
    return p
end

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

local function applyUpright(fx, fy, s, k, flip, prof)
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    love.graphics.translate(fx, fy)
    love.graphics.shear(0, k)
    love.graphics.scale(flip and -s or s, s)
    love.graphics.translate(-cx, -bottom)
end

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

ShopPerspective.SHADOW_INK = Palette.darken(Palette.PARCHMENT_DARK, 0.3)

local castShader, castTried
local function castShadowShader()
    if castTried then return castShader end
    castTried = true
    local ok, sh = pcall(love.graphics.newShader, [[
        extern Image sprite;    // o sprite do objeto (filtro nearest)
        extern vec2 texSize;    // tamanho do PNG
        extern vec4 texRect;    // recorte usado (x, y, w, h): quadro de uma folha
        extern vec2 foot;       // pé (fx, fy) em px de arte, inteiros
        extern float lift;      // px de arte acima da mesa (objeto flutuando)
        extern float poseK;     // cisalhamento da pose (base do sprite em pé)
        extern float scale;     // px de arte por px do sprite
        extern float flip;      // 1 ou -1 (espelho)
        extern vec2 base;       // (cx, bottom) do perfil, em px do sprite
        extern vec2 dir;        // deslocamento por px de altura (ShopLayout.shadowDir)
        extern vec2 band;       // interceptos da faixa do tampo (tableBack, tableEdge)
        extern float run;       // ShopLayout.RUN (8)
        extern vec3 dens;       // (altura com sombra cheia, altura total, densidade da ponta)

        float m2(float x, float y) { return 2.0 * x + 3.0 * y - 4.0 * x * y; }
        // Bayer 4x4 = 4*M2(x%2, y%2) + M2((x/2)%2, (y/2)%2): a mesma matriz do dithered()
        float bayer(float px, float py) {
            return 4.0 * m2(mod(px, 2.0), mod(py, 2.0))
                 + m2(mod(floor(px / 2.0), 2.0), mod(floor(py / 2.0), 2.0));
        }
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            float px = floor(sc.x);
            float py = floor(sc.y);
            float xc = px + 0.5;
            float yc = py + 0.5;
            // faixa do tampo (ShopLayout.ART.tableMask: y0a - x/run < y < y0b - x/run)
            if (yc <= band.x - xc / run || yc >= band.y - xc / run) discard;
            // inversa da projeção: (X, Y) -> altura H sobre a mesa e lx na base
            float den = dir.y - poseK * dir.x;
            float H = (yc - foot.y - poseK * (xc - foot.x)) / den;
            float h = H - lift;
            if (h < 0.0) discard;
            float lx = xc - foot.x - dir.x * H;
            float sx = base.x + lx / (flip * scale);
            float sy = base.y - h / scale;
            if (sx < 0.0 || sy < 0.0 || sx >= texRect.z || sy >= texRect.w) discard;
            vec2 t = (texRect.xy + vec2(floor(sx) + 0.5, floor(sy) + 0.5)) / texSize;
            if (Texel(sprite, t).a <= 0.5) discard;
            float d = 1.0;
            if (H > dens.x) d = mix(1.0, dens.z, clamp((H - dens.x) / max(1.0, dens.y - dens.x), 0.0, 1.0));
            if (bayer(px, py) >= d * 16.0) discard;
            return color;
        }
    ]])
    if ok then castShader = sh else warnOnce("cast", "shader da sombra projetada falhou: " .. tostring(sh)) end
    return castShader
end
ShopPerspective.castShadowShader = castShadowShader

function ShopPerspective.castShadowBox(o)
    local prof = o.prof
    if not prof then return nil end
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local ax, ay = ShopLayout.shadowDir()
    local s = o.s
    local w = (prof.x1 - prof.x0 + 1) * s
    local H = (prof.y1 - prof.y0 + 1) * s + (o.lift or 0)
    local fx, fy = floor(o.fx), floor(o.fy)
    local skew = math.abs(o.k or 0) * w / 2
    local x0 = fx - w / 2 + math.min(0, ax * H) - 1
    local x1 = fx + w / 2 + math.max(0, ax * H) + 1
    local y0 = fy - skew + math.min(0, ay * H) - 1
    local y1 = fy + skew + math.max(0, ay * H) + 2
    return { x = floor(x0), y = floor(y0), w = math.ceil(x1) - floor(x0), h = math.ceil(y1) - floor(y0) }
end

local U = { texSize = { 0, 0 }, texRect = { 0, 0, 0, 0 }, foot = { 0, 0 }, base = { 0, 0 },
            dir = { 0, 0 }, band = { 0, 0 }, dens = { 0, 0, 0 } }

function ShopPerspective.castParams(o)
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local SH = ShopLayout.SHADOW
    local img, prof = o.img, o.prof
    local s = o.s
    local src = prof.src
    local H = (prof.y1 - prof.y0 + 1) * s
    local lift = o.lift or 0
    U.texSize[1], U.texSize[2] = img:getWidth(), img:getHeight()
    U.texRect[1], U.texRect[2] = src and src.x or 0, src and src.y or 0
    U.texRect[3], U.texRect[4] = src and src.w or img:getWidth(), src and src.h or img:getHeight()
    U.foot[1], U.foot[2] = floor(o.fx), floor(o.fy)
    U.lift = lift
    U.poseK = o.k or 0
    U.scale = s
    U.flip = o.flip and -1 or 1
    U.base[1], U.base[2] = (prof.x0 + prof.x1 + 1) / 2, prof.y1 + 1
    U.dir[1], U.dir[2] = ShopLayout.shadowDir()
    U.band[1], U.band[2] = ShopLayout.LINES.tableBack, ShopLayout.LINES.tableEdge
    U.run = ShopLayout.RUN
    U.dens[1], U.dens[2], U.dens[3] = SH.solid * H, H + lift, SH.top
    U.alpha = SH.alpha * (1 - SH.liftFade * clamp(lift / SH.liftRef, 0, 1))
    return U
end

function ShopPerspective.drawCastShadow(o, alpha)
    local img, prof = o.img, o.prof
    if not (img and prof) then return end
    local sh = castShadowShader()
    if not sh then return end
    local box = ShopPerspective.castShadowBox(o)
    local u = ShopPerspective.castParams(o)
    sh:send("sprite", img)
    sh:send("texSize", u.texSize)
    sh:send("texRect", u.texRect)
    sh:send("foot", u.foot)
    sh:send("lift", u.lift)
    sh:send("poseK", u.poseK)
    sh:send("scale", u.scale)
    sh:send("flip", u.flip)
    sh:send("base", u.base)
    sh:send("dir", u.dir)
    sh:send("band", u.band)
    sh:send("run", u.run)
    sh:send("dens", u.dens)
    local ink = ShopPerspective.SHADOW_INK
    love.graphics.push("all")
    love.graphics.setShader(sh)
    love.graphics.setColor(ink[1], ink[2], ink[3], u.alpha * (alpha or 1))
    love.graphics.rectangle("fill", box.x, box.y, box.w, box.h)
    love.graphics.pop()
end

function ShopPerspective.castShadowRef(o, alphaAt)
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local inPoly = ShopLayout.pointInPoly
    local u = ShopPerspective.castParams(o)
    local box = ShopPerspective.castShadowBox(o)
    local out = {}
    local den = u.dir[2] - u.poseK * u.dir[1]
    for py = box.y, box.y + box.h - 1 do
        for px = box.x, box.x + box.w - 1 do
            local xc, yc = px + 0.5, py + 0.5
            if inPoly(xc, yc, ShopLayout.ART.tableMask) then
                local H = (yc - u.foot[2] - u.poseK * (xc - u.foot[1])) / den
                local h = H - u.lift
                if h >= 0 then
                    local lx = xc - u.foot[1] - u.dir[1] * H
                    local sx = u.base[1] + lx / (u.flip * u.scale)
                    local sy = u.base[2] - h / u.scale
                    if sx >= 0 and sy >= 0 and sx < u.texRect[3] and sy < u.texRect[4]
                        and alphaAt(floor(sx), floor(sy)) > 0.5 then
                        local d = 1
                        if H > u.dens[1] then
                            d = 1 + (u.dens[3] - 1) * clamp((H - u.dens[1]) / math.max(1, u.dens[2] - u.dens[1]), 0, 1)
                        end
                        if dithered(px, py, d) then out[#out + 1] = px; out[#out + 1] = py end
                    end
                end
            end
        end
    end
    return out
end

local pts = {}
function ShopPerspective.drawContactShadow(o, mask, alpha)
    local prof = o.prof
    if not prof then return end
    if (o.lift or 0) > 0.5 then return end
    local ShopLayout = require("src.ui.shop.ShopLayout")
    local inPoly = ShopLayout.pointInPoly
    local s, k = o.s, o.k or 0
    local cx = (prof.x0 + prof.x1 + 1) / 2
    local bottom = prof.y1 + 1
    local fx, fy = floor(o.fx), floor(o.fy)
    local objW = (prof.x1 - prof.x0 + 1) * s
    local halfW = objW / 2
    local G = math.max(3, floor(objW * 0.22))
    local n = 0
    for dx = floor(fx - halfW) - 1, math.ceil(fx + halfW) + 1 do
        local lx = dx + 0.5 - fx
        local b = prof.bottom[floor(cx + lx / (o.flip and -s or s))]
        if b ~= nil then
            local yG = floor(fy + k * lx)
            local yB = floor(fy + k * lx + (b + 1 - bottom) * s)
            if yG - yB <= G and (not mask or inPoly(dx + 0.5, yB + 1.5, mask)) then
                pts[n + 1], pts[n + 2] = dx + 0.5, yB + 1.5
                n = n + 2
            end
        end
    end
    for i = n + 1, #pts do pts[i] = nil end
    if n == 0 then return end
    local ink = ShopPerspective.SHADOW_INK
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.9 * (alpha or 1))
    love.graphics.points(pts)
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopPerspective.drawObjectShadow(o, mask, alpha)
    ShopPerspective.drawCastShadow(o, alpha)
    ShopPerspective.drawContactShadow(o, mask, alpha)
end

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

function ShopPerspective.mapH(r0, r1, r2, u, v)
    local w = r2[1] * u + r2[2] * v + r2[3]
    return (r0[1] * u + r0[2] * v + r0[3]) / w, (r1[1] * u + r1[2] * v + r1[3]) / w
end

return ShopPerspective
