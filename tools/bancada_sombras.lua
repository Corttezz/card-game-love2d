local M = {}

local BIOMES = { "fields", "highlands", "abyss", "frost", "marsh", "dusk" }
M.BIOMES = BIOMES
local TREEISH = { tree = true, pine = true, deadtree = true, bush = true }
local SKIP = { castle = true, mountains = true, mountains_front = true }
local REF_H = 1080
local UNIT = REF_H * 0.115 * 1.25
M.PERSP = { near = 0.29, mid = 0.15 }
M.TODS = { 0.65, 0.95 }

local ffi = require("ffi")

local function loadScanned(path)
    if not love.filesystem.getInfo(path) then return nil end
    local data = love.image.newImageData(path)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    require("engine.ContactShadow").scan(img, data)
    local name = path:match("([^/]+)%.png$")
    local dir = path:match("anim/([^/]+)/")
    require("engine.ContactShadow").setFootRows(img,
        require("src.data.world_props").footRows[dir or name])
    return img
end

local function firstFrame(key)
    local dir = "assets/sprites/world/anim/" .. key
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then return nil end
    local files = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if f:match("%.png$") then files[#files + 1] = f end
    end
    table.sort(files, function(a, b)
        local na, nb = tonumber(a:match("^(%d+)")), tonumber(b:match("^(%d+)"))
        if na and nb then return na < nb end
        return a < b
    end)
    return files[1] and loadScanned(dir .. "/" .. files[1]) or nil
end

local function clutterOf(bid)
    local out = {}
    for _, e in ipairs(require("src.data.ground_clutter").biomes[bid] or {}) do out[e.kind] = e end
    return out
end

function M.items(bid)
    local WR = require("src.ui.WorldRoad")
    local LE = require("engine.LuminaireEngine")
    local clut = clutterOf(bid)
    local list = {}
    local files = love.filesystem.getDirectoryItems("assets/sprites/world")
    table.sort(files)
    for _, f in ipairs(files) do
        local name = f:match("^(.+)%.png$")
        if name then
            local lmType = (bid == "fields" and name:match("^landmark_(%a+)$"))
                or name:match("^" .. bid .. "_landmark_(%a+)$")
            local kind, var = name:match("^" .. bid .. "_([%a]+)_(%d+)$")
            if lmType then
                local img = firstFrame(name) or loadScanned("assets/sprites/world/" .. f)
                list[#list + 1] = { name = name, key = name, img = img, family = "landmark" }
            elseif kind and not SKIP[kind] then
                var = tonumber(var)
                local item = { name = name, kind = kind, variant = var, bid = bid }
                if LE.def(bid, kind) then
                    item.family = "luminaire"
                    item.img = firstFrame(name) or loadScanned("assets/sprites/world/" .. f)
                    item.anc = LE.anchor(bid, kind, var, "assets/sprites/world/" .. f)
                    item.def = LE.def(bid, kind)
                elseif clut[kind] and not ({ rock = 1, stump = 1, tuft = 1, flowers = 1, mushroom = 1 })[kind] then
                    item.family = "clutter"
                    item.e = clut[kind]
                    item.img = loadScanned("assets/sprites/world/" .. f)
                else
                    item.family = TREEISH[kind] and "tree" or "prop"
                    local _, base = WR.treeAnim(bid, kind, var)
                    item.img = base
                end
                if item.img then list[#list + 1] = item end
            end
        end
    end
    return list
end

local function lmCfg(tbl, key)
    local v = tbl[key]
    if v ~= nil then return v end
    return tbl[key:match("(landmark_.+)$") or key]
end

local function sizeOf(item)
    local WR = require("src.ui.WorldRoad")
    if item.family == "landmark" then return lmCfg(WR.LANDMARK_SIZE, item.key) or 2.0 end
    if item.family == "luminaire" then return item.def.size end
    if item.family == "clutter" then return (item.e.k or 1) * 0.6 end
    local KS = { tree = 6.3, pine = 6.7, deadtree = 5.9, fence = 1.55, sign = 1.7,
        bush = 1.35, rock = 1.05, flowers = 0.7, stump = 0.9, ruin = 2.9, tuft = 0.5 }
    return KS[item.kind] or 1.0
end

function M.scaleFor(item, which, maxH)
    local ih = item.img:getHeight()
    local s = sizeOf(item) * UNIT * M.PERSP[which] / ih
    if maxH and ih * s > maxH then s = maxH / ih end
    return math.max(0.35, s)
end

function M.place(item, fx, fy, s, t, opts)
    opts = opts or {}
    local WR = require("src.ui.WorldRoad")
    local SE = require("engine.ShadowEngine")
    local Contact = require("engine.ContactShadow")
    local Grade = require("engine.SceneGrade")
    local img = item.img
    local iw, ih = img:getDimensions()
    local spec = { x = fx, feetY = fy }
    local fam = item.family
    local c = {}
    if fam == "landmark" then
        local pad = (os.getenv("BANCADA_PAD") ~= "tabela" and Contact.padOf(img))
            or lmCfg(WR.LANDMARK_SHADOW_PAD, item.key) or 0
        local shY = fy - 1 - pad * s
        if not opts.noShadow then
            SE.sprite(img, fx, shY, s, { footPad = pad,
                baseK = (lmCfg(WR.SHADOW_PROFILE, item.key) or {}).baseK,
                riseK = (lmCfg(WR.SHADOW_PROFILE, item.key) or {}).riseK,
                lenK = (lmCfg(WR.SHADOW_PROFILE, item.key) or {}).lenK })
            Contact.queue(img, fx, shY, s, t, 1, 1)
        end
        spec.drawY, spec.oy, spec.pad, spec.shY = fy, ih, pad, shY
        if not opts.noSprite then
            Grade.color("landmark", t, c)
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.draw(img, math.floor(fx), math.floor(fy), 0, s, s, iw / 2, ih)
            SE.mask(img, nil, math.floor(fx), math.floor(fy), 0, s, s, iw / 2, ih, 0, t)
        end
        return spec
    end
    local prof = WR.SHADOW_PROFILE[item.kind]
    local pad, sink, flip, ox = 0, 0, 1, 0
    local fy0 = fy
    if fam == "tree" then
        pad = select(1, WR.propCutInfo(item.kind, item.variant, item.bid)) or 0
        prof = prof or Grade.cfg("shadow").tree
    elseif fam == "luminaire" then
        pad = item.anc.footPad or 0
        sink = pad * s
        fx = fx - (item.anc.offX or 0) * s
    end
    if not opts.noShadow and (fam ~= "clutter" or item.e.solid) then
        local o = { footPad = pad, flip = flip }
        if prof then o.baseK, o.riseK, o.lenK = prof.baseK, prof.riseK, prof.lenK end
        SE.queue(img, fx, fy0 - 1, s, o, t)
        if item.kind ~= "tuft" and item.kind ~= "flowers" then
            Contact.queue(img, fx, fy0, s, t, 1, flip)
        end
    end
    spec.x, spec.drawY, spec.pad = fx, fy0 + sink, pad
    if not opts.noSprite then
        Grade.color(Grade.familyOf(item.kind, fam == "luminaire"), t, c)
        love.graphics.setColor(math.min(1, c[1]), math.min(1, c[2]), math.min(1, c[3]), 1)
        if fam == "tree" and pad > 0 then
            M.quads = M.quads or setmetatable({}, { __mode = "k" })
            local q = M.quads[img]
            if not q then
                q = love.graphics.newQuad(0, 0, iw, ih - pad, iw, ih)
                M.quads[img] = q
            end
            love.graphics.draw(img, q, math.floor(fx), math.floor(fy0), 0, s * flip, s, iw / 2, ih - pad)
            SE.mask(img, q, math.floor(fx), math.floor(fy0), 0, s * flip, s, iw / 2, ih - pad, 0, t)
        else
            love.graphics.draw(img, math.floor(fx), math.floor(fy0 + sink), 0, s * flip, s, iw / 2, ih)
            SE.mask(img, nil, math.floor(fx), math.floor(fy0 + sink), 0, s * flip, s, iw / 2, ih, 0, t)
        end
    end
    return spec
end

local function groundColor(bid)
    local b
    for _, bb in ipairs(require("src.data.biomes")) do if bb.id == bid then b = bb end end
    local Grade = require("engine.SceneGrade")
    local g0 = Grade.color("ground", 1, {})
    local gb = b.grassB
    return { gb[1] * 0.78 * g0[1] * 1.6, gb[2] * 0.78 * g0[2] * 1.6, gb[3] * 0.78 * g0[3] * 1.6 }, b
end

function M.beginBiome(bid, tod)
    local Grade = require("engine.SceneGrade")
    Grade.begin(bid, tod, nil, 1, { 1, 1, 1 })
    Grade.setDepth(1)
end

function M.renderCell(cv, bid, item, which, tod, opts)
    opts = opts or {}
    local SE = require("engine.ShadowEngine")
    local Contact = require("engine.ContactShadow")
    local Grade = require("engine.SceneGrade")
    M.beginBiome(bid, tod)
    local gc, b = groundColor(bid)
    local W, H = cv:getDimensions()
    local s = M.scaleFor(item, which, H * 0.55)
    local t = which == "near" and 0.8 or 0.5
    local fx, fy = math.floor(W * 0.5), math.floor(H * 0.62)
    local xr = (b.celestial and b.celestial.xr) or 0.5
    local side = xr > 0.5 and 0.30 or 0.70
    local sunX = fx - (side - xr) * 1920
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.origin()
    if opts.white then love.graphics.clear(1, 1, 1, 1) else love.graphics.clear(gc[1], gc[2], gc[3], 1) end
    SE.setFrame(sunX, 1920, tod, 0.35 + 0.65 * tod)
    local sh = Grade.cfg("shadow")
    SE.setAlphaK(sh.alphaK)
    SE.FADE = sh.fade or 0.45
    local shc = sh.color or { 0.42, 0.42, 0.5 }
    SE.setTint(shc[1], shc[2], shc[3])
    Contact.setFrame(Grade.cfg("contact"), Grade.shadowTint())
    local spec = M.place(item, fx, fy, s, t, opts)
    SE.endFrame(Contact.drawAcc)
    Contact.endFrame()
    love.graphics.pop()
    spec.s, spec.t, spec.sunRight = s, t, sunX > fx
    return spec
end

local function pixels(cv)
    local d = cv:newImageData()
    return d, ffi.cast("const uint8_t*", d:getFFIPointer()), d:getWidth(), d:getHeight()
end

function M.measure(cv, bid, item, which, tod)
    local Contact = require("engine.ContactShadow")
    local spec = M.renderCell(cv, bid, item, which, tod, { noShadow = true, white = true })
    local dA, pa, W, H = pixels(cv)
    M.renderCell(cv, bid, item, which, tod, { noSprite = true, white = true })
    local dS, ps = pixels(cv)
    local function art(x, y)
        local o = (y * W + x) * 4
        return pa[o] < 250 or pa[o + 1] < 250 or pa[o + 2] < 250
    end
    local function dark(x, y)
        local o = (y * W + x) * 4
        return ps[o] < 247 or ps[o + 1] < 247 or ps[o + 2] < 247
    end
    local artBottom, ax0, ax1 = -1, W, -1
    for y = H - 1, 0, -1 do
        for x = 0, W - 1 do
            if art(x, y) then
                if artBottom < 0 then artBottom = y end
                break
            end
        end
        if artBottom >= 0 then break end
    end
    local shadowTop = nil
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            if dark(x, y) then shadowTop = y; break end
        end
        if shadowTop then break end
    end
    local fp = Contact.footprint(item.img)
    local ih = item.img:getHeight()
    local s = spec.s
    local prof = item.kind and require("src.ui.WorldRoad").SHADOW_PROFILE[item.kind]
    local res = { artBottom = artBottom, shadowTop = shadowTop, s = s,
        flat = (prof and prof.riseK == 0) or item.kind == "flowers" or item.kind == "tuft" }
    local WR = require("src.ui.WorldRoad")
    local profiled = item.family == "tree" or prof ~= nil
        or (item.family == "landmark" and lmCfg(WR.SHADOW_PROFILE, item.key) ~= nil)
    if fp and fp.pivot then
        local piv = profiled and fp.pivot or (fp.footPivot or fp.pivot)
        local depthRows = fp.bottom - piv
        res.depthPx = depthRows * s
        res.baseW = (not profiled and fp.baseW) and fp.baseW * s or nil
        local pivotY = math.floor(artBottom - depthRows * s + 0.5)
        res.pivotY = pivotY
        local x0, x1 = W, -1
        for x = 0, W - 1 do
            if art(x, math.max(0, pivotY)) then
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
            end
        end
        local cx, hw = (x0 + x1) * 0.5, (x1 - x0 + 1) * 0.5
        local filled = 0
        for x = math.max(0, x0), x1 do
            if art(x, math.max(0, pivotY)) then filled = filled + 1 end
        end
        res.fill = x1 >= x0 and filled / (x1 - x0 + 1) or 0
        local area, cov = 0, 0
        if depthRows >= 2 and hw > 1 then
            for y = pivotY, artBottom do
                local f = (y - pivotY) / math.max(1, artBottom - pivotY)
                local half = hw * math.sqrt(math.max(0, 1 - f * f))
                local xa = spec.sunRight and math.floor(cx - half) or math.floor(cx)
                local xb = spec.sunRight and math.ceil(cx) or math.ceil(cx + half)
                for x = xa, xb do
                    if x >= 0 and x < W then
                        area = area + 1
                        if dark(x, y) then cov = cov + 1 end
                    end
                end
            end
        end
        res.area, res.cover = area, area > 0 and cov / area or nil
    end
    dA:release(); dS:release()
    return res
end

local CELL = 300

local blitQuad
local function blit(sheet, cv, sx, sy, sw, sh, dx, dy, k)
    love.graphics.push("all")
    love.graphics.setCanvas(sheet)
    love.graphics.origin()
    local cw, ch = cv:getDimensions()
    if not blitQuad then blitQuad = love.graphics.newQuad(sx, sy, sw, sh, cw, ch) end
    blitQuad:setViewport(sx, sy, sw, sh, cw, ch)
    local q = blitQuad
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, q, dx, dy, 0, k, k)
    love.graphics.pop()
end

function M.sheet(bid, tag)
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    cv:setFilter("nearest", "nearest")
    local items = M.items(bid)
    local cols = { { "near", 0.65 }, { "near", 0.95 }, { "mid", 0.65 }, { "mid", 0.95 } }
    local nCol = #cols + 2
    local sheet = love.graphics.newCanvas(nCol * CELL, (#items) * (CELL + 18) + 24)
    love.graphics.push("all")
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0.08, 0.07, 0.06, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(bid .. " (" .. tag .. ")  colunas: perto 0,65 | perto 0,95 | meio 0,65 | meio 0,95 | base 3x perto 0,65 | base 3x perto 0,95", 6, 4)
    love.graphics.pop()
    for i, item in ipairs(items) do
        local y0 = 24 + (i - 1) * (CELL + 18)
        love.graphics.push("all")
        love.graphics.setCanvas(sheet)
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.print(item.name .. " [" .. item.family .. "]", 6, y0)
        love.graphics.pop()
        for ci, c in ipairs(cols) do
            local spec = M.renderCell(cv, bid, item, c[1], c[2])
            local ih = item.img:getHeight()
            local hpx = ih * spec.s
            local box = math.max(CELL, math.min(H, hpx * 1.8))
            local k = CELL / box
            blit(sheet, cv, W * 0.5 - box / 2, H * 0.62 - box * 0.66, box, box,
                (ci - 1) * CELL, y0 + 16, k)
        end
        for zi, tod in ipairs({ 0.65, 0.95 }) do
            local spec = M.renderCell(cv, bid, item, "near", tod)
            local iw = item.img:getWidth() * spec.s
            local bw = math.max(40, math.min(CELL / 3, iw * 1.4))
            local cxs = spec.x + (spec.sunRight and -0.2 or 0.2) * bw
            blit(sheet, cv, cxs - bw / 2, H * 0.62 - bw * 0.55, bw, bw,
                (#cols + zi - 1) * CELL, y0 + 16, CELL / bw)
        end
    end
    cv:release()
    return sheet
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local tag = arg or "depois"
    local only = nil
    if tag:find(":") then tag, only = tag:match("^([^:]+):(.+)$") end
    love.filesystem.createDirectory("sombras_item/" .. tag)
    for _, bid in ipairs(BIOMES) do
        if not only or only == bid then
            local sheet = M.sheet(bid, tag)
            local path = "sombras_item/" .. tag .. "/" .. bid .. ".png"
            local data = sheet:newImageData()
            data:encode("png", path)
            data:release()
            sheet:release()
            collectgarbage("collect")
            print("[bancada] " .. love.filesystem.getSaveDirectory() .. "/" .. path)
        end
    end
    return true
end

return M
