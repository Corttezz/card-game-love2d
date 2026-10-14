local TK = require("tools.testkit")
local ShadowEngine = require("engine.ShadowEngine")

local M = {}

local SUNX, FW, TOD, LUMA = 512, 1024, 0.5, 1
local LEN, ALPHA = 0.55 + 0.45 * TOD, 0.15 + 0.15 * LUMA
local SMEAR = { { -1, 0 }, { 0.7, -0.5 }, { 0.35, 0.55 } }
local SCALE = 3

local function loadImg(path)
    local data = love.image.newImageData(path)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img, data
end

local function tipShift(px)
    return math.max(-1, math.min(1, (px - SUNX) / (FW * 0.5)))
end

local function legacyBatch(body, alphaK)
    local W, H = love.graphics.getDimensions()
    local scratch = love.graphics.newCanvas(math.ceil(W / SCALE), math.ceil(H / SCALE),
        { format = "rgba8" })
    scratch:setFilter("nearest", "nearest")
    local prev = love.graphics.getCanvas()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(scratch)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.scale(1 / SCALE)
    body()
    love.graphics.pop()
    love.graphics.setCanvas(prev)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(0, 0, 0, ALPHA * (alphaK or 1))
    love.graphics.draw(scratch, 0, 0, 0, SCALE, SCALE)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local function legacySprite(img, feetX, feetY, s, footPad, flip, lenK)
    legacyBatch(function()
        local iw, ih = img:getWidth(), img:getHeight()
        local shd = tipShift(feetX)
        local d = math.max(1.5, iw * s * 0.035)
        love.graphics.setColor(1, 1, 1, 1)
        for pi = 1, #SMEAR do
            love.graphics.draw(img,
                math.floor(feetX + SMEAR[pi][1] * d),
                math.floor(feetY + SMEAR[pi][2] * d * 0.5), 0,
                s * 1.18 * (flip or 1), -s * LEN * (lenK or 1),
                iw / 2, ih - (footPad or 0), -shd * 0.78, 0)
        end
    end)
end

local function legacySilhouette(feetX, feetY, opts, drawFn)
    legacyBatch(function()
        local shd = tipShift(feetX)
        local d = opts.smear or 4
        local wK = opts.widthK or 1
        local tint = { 1, 1, 1, 1 }
        for pi = 1, #SMEAR do
            love.graphics.push()
            love.graphics.translate(math.floor(feetX + SMEAR[pi][1] * d),
                math.floor(feetY + SMEAR[pi][2] * d * 0.5))
            love.graphics.shear(shd * 0.78, 0)
            love.graphics.scale(1.18 * wK, -LEN * (opts.lenK or 1))
            love.graphics.setColor(tint)
            drawFn(tint)
            love.graphics.pop()
        end
    end, opts.alphaK)
end

local function render(fn)
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    ShadowEngine.setFrame(SUNX, FW, TOD, LUMA)
    fn()
    love.graphics.setCanvas()
    return cv:newImageData()
end

local function measure(id, fx, fy, halfW, footTop, spanX, spanY)
    local W, H = id:getDimensions()
    local x0, x1 = math.max(0, math.floor(fx - spanX)), math.min(W - 1, math.ceil(fx + spanX))
    local y0, y1 = math.max(0, math.floor(fy - spanY)), math.min(H - 1, math.ceil(fy + spanY))
    local n, inside, minY, maxY = 0, 0, math.huge, -math.huge
    for y = y0, y1 do
        for x = x0, x1 do
            local _, _, _, a = id:getPixel(x, y)
            if a > 0.02 then
                n = n + 1
                if y < minY then minY = y end
                if y > maxY then maxY = y end
                if x >= fx - halfW and x <= fx + halfW
                   and y >= footTop and y <= fy then
                    inside = inside + 1
                end
            end
        end
    end
    return n, inside, minY, maxY
end

local function pct(a, b) return (b > 0) and math.floor(100 * a / b + 0.5) or 0 end

function M.run()
    local t = TK.new("sombras do mundo (pegada: fogueira, baú, pedra, cadáver × árvore, estandarte, loja)")
    local W, H = love.graphics.getDimensions()
    local FX, FY = math.floor(W * 0.5), math.floor(H * 0.62)
    local WR = require("src.ui.WorldRoad")
    local PROF = WR.SHADOW_PROFILE

    local TALL = {
        { "fields_tree_0", 2.5, 0 }, { "highlands_pine_0", 1.6, 0 },
        { "dusk_sign_0", 2.5, 0 }, { "fields_lantern_0", 3, 2 },
        { "fields_lantern_0", 3, 2, -1 },
        { "landmark_battle", 3, 0 },
        { "highlands_landmark_battle", 3, 0 },
        { "landmark_shop", 3, 3 },
        { "highlands_landmark_shop", 3, 4 }, { "abyss_landmark_shop", 3, 11 },
        { "landmark_event", 3, 3 }, { "marsh_landmark_event", 3, 5 },
        { "landmark_elite", 3, 2 }, { "landmark_miniboss", 3, 0 },
        { "abyss_ruin_0", 1.2, 0 },
    }
    for _, c in ipairs(TALL) do
        local key, s, pad, flip = c[1], c[2], c[3], c[4]
        local img = loadImg("assets/sprites/world/" .. key .. ".png")
        local iw, ih = img:getDimensions()
        local new = render(function()
            t:truthy(key .. ": motor desenhou",
                ShadowEngine.sprite(img, FX, FY, s, { footPad = pad, flip = flip }))
        end)
        local old = render(function() legacySprite(img, FX, FY, s, pad, flip) end)
        t:truthy(key .. (flip and " (flip)" or "") .. ": IDÊNTICO ao v8.4 pixel a pixel",
            new:getString() == old:getString())
        local n, _, minY, maxY = measure(new, FX, FY, iw * s, FY, iw * s * 2, ih * s * 1.5)
        t:truthy(key .. ": sombra existe e é LONGA (" .. (maxY - FY) .. "px, conteúdo "
            .. math.floor((ih - pad) * s) .. "px)", n > 0 and (maxY - FY) >= 0.5 * (ih - pad) * s)
        t:truthy(key .. ": nasce na linha de contato (topo " .. (minY - FY) .. "px)",
            minY >= FY - pad * s - 4 and minY <= FY + 2)
    end

    local LOW = {
        { "landmark_rest", 3, 1, "landmark_rest" },
        { "highlands_landmark_rest", 3, 1, "highlands_landmark_rest" },
        { "abyss_landmark_rest", 3, 5, "abyss_landmark_rest" },
        { "frost_landmark_rest", 3, 3, "frost_landmark_rest" },
        { "marsh_landmark_rest", 3, 5, "marsh_landmark_rest" },
        { "dusk_landmark_rest", 3, 4, "dusk_landmark_rest" },
        { "landmark_chest", 3, 2, "landmark_chest" },
        { "fields_rock_0", 3, 0, "rock" }, { "abyss_rock_0", 2, 0, "rock" },
        { "highlands_rock_0", 2, 0, "rock" }, { "frost_rock_0", 2, 0, "rock" },
        { "fields_stump_0", 3, 0, "stump" }, { "fields_bush_0", 3, 0, "bush" },
        { "fields_flowers_0", 3, 0, "flowers" }, { "fields_tuft_0", 3, 5, "tuft" },
    }
    for _, c in ipairs(LOW) do
        local key, s, pad, pk = c[1], c[2], c[3], c[4]
        local prof = PROF[pk]
        t:truthy(key .. ": perfil de pegada declarado (" .. pk .. ")", prof ~= nil)
        if prof then
            local img = loadImg("assets/sprites/world/" .. key .. ".png")
            local iw, ih = img:getDimensions()
            local contentH = (ih - pad) * s
            local baseH = prof.baseK * contentH
            local d = math.max(1.5, iw * s * 0.035)
            local opts = { footPad = pad, baseK = prof.baseK, riseK = prof.riseK, lenK = prof.lenK }
            local new = render(function() ShadowEngine.sprite(img, FX, FY, s, opts) end)
            local halfW = iw * s * 0.59 + d
            local n, inside, minY, maxY = measure(new, FX, FY, halfW, FY - baseH,
                iw * s * 2, ih * s * 1.5)
            local old = render(function() legacySprite(img, FX, FY, s, pad) end)
            local n0, in0, _, maxY0 = measure(old, FX, FY, halfW, FY - baseH,
                iw * s * 2, ih * s * 1.5)
            local rim = math.max(6, 0.4 * baseH + 2 * d)
            print(string.format("    %-26s pegada %3dpx | v9: %5d px, %3d%% dentro, topo %+4d, orla %+4d (teto %d) | v8.4: %3d%% dentro, orla %+4d",
                key, math.floor(baseH), n, pct(inside, n), minY - FY, maxY - FY, math.floor(rim),
                pct(in0, n0), maxY0 - FY))
            t:truthy(key .. ": sombra existe", n > 0)
            t:truthy(key .. ": nasce DENTRO da pegada, encostada na linha de contato",
                minY >= FY - baseH - 2 and minY <= FY + 2)
            t:truthy(key .. ": ≥ 70% dos pixels dentro da pegada (" .. pct(inside, n) .. "%)",
                inside >= 0.70 * n)
            t:truthy(key .. ": só uma orla abaixo da linha de contato (" .. (maxY - FY)
                .. "px ≤ " .. math.floor(rim) .. ")", maxY - FY <= rim)
            t:truthy(key .. ": era cópia inteira no v8.4 (" .. pct(in0, n0) .. "% dentro)",
                in0 < 0.5 * n0)
        end
    end

    do
        local img = loadImg("assets/sprites/world/fields_rock_0.png")
        local opts = { baseK = PROF.rock.baseK, lenK = PROF.rock.lenK }
        local solo = render(function() ShadowEngine.sprite(img, FX, FY, 3, opts) end)
        local queued = render(function()
            ShadowEngine.queue(img, FX, FY, 3, opts)
            ShadowEngine.flush()
        end)
        t:truthy("fila (queue/flush) = chamada solo, pixel a pixel",
            solo:getString() == queued:getString())
    end

    do
        local img = loadImg("assets/sprites/world/fields_rock_0.png")
        local id = render(function()
            t:truthy("fissura (riseK 0): motor responde true (sem fallback de elipse)",
                ShadowEngine.sprite(img, FX, FY, 3, { baseK = 1, riseK = 0 }))
        end)
        local n = measure(id, FX, FY, 1, FY, 300, 300)
        t:eq("fissura (riseK 0): zero pixels de sombra", n, 0)
    end

    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyPoses = require("src.data.enemy_poses")
    local function frameOf(id, clip, idx)
        local path = "assets/sprites/characters/enemies/" .. id .. "/animations/"
            .. clip .. "/south/" .. idx .. ".png"
        local img, data = loadImg(path)
        local g, _, _, _, top = EnemyRenderer._groundOf(data)
        return img, data:getHeight() - 1 - g, g - top + 1
    end
    local function silOpts(iw, s, extra)
        local o = { smear = iw * s * 0.035 }
        for k, v in pairs(extra or {}) do o[k] = v end
        return o
    end
    local function drawer(img, s, pad)
        local iw, ih = img:getDimensions()
        return function()
            love.graphics.draw(img, -(iw * s) / 2, -(ih * s) + pad * s, 0, s, s)
        end
    end

    do
        local img, pad = frameOf("hollow_farmer", "idle", 0)
        local s = 2
        local o = silOpts(img:getWidth(), s)
        local new = render(function() ShadowEngine.silhouette(FX, FY, o, drawer(img, s, pad)) end)
        local old = render(function() legacySilhouette(FX, FY, o, drawer(img, s, pad)) end)
        t:truthy("bípede em pé (hollow_farmer): IDÊNTICO ao v8.4", new:getString() == old:getString())
        local bk, rk, lk = EnemyRenderer.shadowProfile(EnemyPoses.get("hollow_farmer"), "idle", 100, 100)
        t:truthy("shadowProfile bípede em pé = sem pegada", bk == 0 and rk == nil and lk == 1)
    end

    do
        local img, pad = frameOf("dusk_shade", "idle", 0)
        local pose = EnemyPoses.get("dusk_shade")
        local s = 2
        local o = silOpts(img:getWidth(), s, { widthK = pose.shadowK, lenK = pose.shadowK,
            alphaK = pose.shadowA })
        local dx = ShadowEngine.tipShiftAt(FX + 200)
        local new = render(function()
            ShadowEngine.silhouette(FX + 200 + 20, FY, o, drawer(img, s, pad)) end)
        local old = render(function()
            legacySilhouette(FX + 200 + 20, FY, o, drawer(img, s, pad)) end)
        t:truthy("flutuante (dusk_shade): sombra solta IDÊNTICA ao v8.4", new:getString() == old:getString())
        t:truthy("flutuante: pose sem pegada", (pose.shadowBaseK or 0) == 0 and dx ~= nil)
    end

    do
        local id = "plague_rats"
        local img, pad, fh = frameOf(id, "idle", 0)
        local pose = EnemyPoses.get(id)
        t:truthy("plague_rats declara shadowBaseK", (pose.shadowBaseK or 0) > 0)
        local s = 2
        local bk, rk, lk = EnemyRenderer.shadowProfile(pose, "idle", fh, fh)
        local o = silOpts(img:getWidth(), s, { baseK = bk, riseK = rk, lenK = lk, contentH = fh * s })
        local new = render(function() ShadowEngine.silhouette(FX, FY, o, drawer(img, s, pad)) end)
        local old = render(function() legacySilhouette(FX, FY, silOpts(img:getWidth(), s), drawer(img, s, pad)) end)
        local baseH = bk * fh * s
        local iw = img:getWidth()
        local n, inside, minY, maxY = measure(new, FX, FY, iw * s * 0.59 + 8, FY - baseH, iw * s * 2, fh * s * 2)
        local n0, _, _, maxY0 = measure(old, FX, FY, iw * s * 0.59 + 8, FY - baseH, iw * s * 2, fh * s * 2)
        print(string.format("    %-26s pegada %3dpx | v9: %5d px, %3d%% dentro, topo %+4d, orla %+4d | v8.4: %5d px, orla %+4d",
            id .. " (em pé)", math.floor(baseH), n, pct(inside, n), minY - FY, maxY - FY, n0, maxY0 - FY))
        t:truthy("ratos: sombra nasce dentro da pegada", n > 0 and minY >= FY - baseH - 2 and minY <= FY + 2)
        t:truthy("ratos: sombra encurta (orla " .. (maxY - FY) .. " < " .. (maxY0 - FY) .. " do v8.4)",
            maxY - FY < 0.6 * (maxY0 - FY))
    end

    for _, id in ipairs({ "blight_bull", "hollow_farmer", "plague_rats" }) do
        local dir = "assets/sprites/characters/enemies/" .. id .. "/animations/death/south"
        local files = love.filesystem.getDirectoryItems(dir)
        local last = -1
        for _, f in ipairs(files) do
            local k = tonumber(f:match("^(%d+)%.png$"))
            if k and k > last then last = k end
        end
        local img, pad, fh = frameOf(id, "death", last)
        local _, _, idleH = frameOf(id, "idle", 0)
        local pose = EnemyPoses.get(id)
        local bk, rk, lk = EnemyRenderer.shadowProfile(pose, "death", fh, idleH)
        t:truthy(id .. " cadáver: altura cai (" .. fh .. " de " .. idleH .. ") → pegada ≥ 0.4",
            fh < 0.8 * idleH and bk >= 0.4)
        local s = 2
        local o = silOpts(img:getWidth(), s, { baseK = bk, riseK = rk, lenK = lk, contentH = fh * s })
        local new = render(function() ShadowEngine.silhouette(FX, FY, o, drawer(img, s, pad)) end)
        local old = render(function() legacySilhouette(FX, FY, silOpts(img:getWidth(), s), drawer(img, s, pad)) end)
        local baseH = bk * fh * s
        local iw = img:getWidth()
        local n, inside, minY, maxY = measure(new, FX, FY, iw * s * 0.59 + 8, FY - baseH, iw * s * 2, fh * s * 3)
        local n0, in0, _, maxY0 = measure(old, FX, FY, iw * s * 0.59 + 8, FY - baseH, iw * s * 2, fh * s * 3)
        local rim = math.max(6, 0.4 * baseH + 8)
        print(string.format("    %-26s pegada %3dpx | v9: %5d px, %3d%% dentro, topo %+4d, orla %+4d (teto %d) | v8.4: %3d%% dentro, orla %+4d",
            id .. " (cadáver)", math.floor(baseH), n, pct(inside, n), minY - FY, maxY - FY, math.floor(rim),
            pct(in0, n0), maxY0 - FY))
        t:truthy(id .. " cadáver: sombra existe e nasce dentro da pegada",
            n > 0 and minY >= FY - baseH - 2 and minY <= FY + 2)
        t:truthy(id .. " cadáver: ≥ 70% dentro da pegada (" .. pct(inside, n) .. "%)", inside >= 0.7 * n)
        t:truthy(id .. " cadáver: só orla abaixo do contato (" .. (maxY - FY) .. " ≤ " .. math.floor(rim) .. ")",
            maxY - FY <= rim)
        t:truthy(id .. " cadáver: era segundo cadáver no v8.4 (" .. pct(in0, n0) .. "% dentro)", in0 < 0.5 * n0)
    end

    do
        local sp = EnemyRenderer.shadowProfile
        local gr = { shadowBaseK = 0.35 }
        local b, r, l = sp(gr, "idle", 100, 100)
        t:truthy("perfil: pose com pegada 0.35 → baseK 0.35, lenK 0.58", b == 0.35 and r == nil and math.abs(l - 0.58) < 1e-9)
        b, r, l = sp(nil, "death", 100, 100)
        t:truthy("perfil: death no 1º quadro (altura cheia) = em pé", b == 0 and l == 1)
        b, r, l = sp(nil, "death", 45, 100)
        t:truthy("perfil: death deitada (45%) → baseK 0.55, lenK 0.65", math.abs(b - 0.55) < 1e-9 and math.abs(l - 0.65) < 1e-9)
        b, r, l = sp(nil, "death", 82.5, 100)
        t:truthy("perfil: death a meio caminho (82.5%) → baseK 0.275, lenK 0.825", math.abs(b - 0.275) < 1e-9 and math.abs(l - 0.825) < 1e-9)
        b, r, l = sp(nil, "death", 70, 100)
        t:truthy("perfil: touro deitado (70% da altura) já conta como deitado (baseK ≥ 0.45)", b >= 0.45)
        b = sp(gr, "death", 45, 100)
        t:truthy("perfil: pegada da pose nunca diminui na morte", b >= 0.55)
        b = sp({ shadowBaseK = 0.7 }, "death", 45, 100)
        t:truthy("perfil: pegada maior da pose vence", b == 0.7)
    end

    do
        local img, pad = frameOf("hollow_farmer", "idle", 0)
        local s = 2
        local o = silOpts(img:getWidth(), s, { baseK = 0.3 })
        local n = select(1, measure(render(function()
            ShadowEngine.silhouette(FX, FY, o, drawer(img, s, pad)) end), FX, FY, 1, FY, 300, 300))
        t:truthy("perfil sem contentH não some (desenhou " .. n .. " px)", n > 0)
    end

    for _, f in ipairs(love.filesystem.getDirectoryItems("assets/sprites/world")) do
        local key = f:match("^(.*landmark_rest)%.png$")
        if key then
            t:truthy("fogueira " .. key .. " com perfil de pegada",
                PROF[key] ~= nil or PROF.landmark_rest ~= nil)
        end
    end

    return t:done()
end

return M
