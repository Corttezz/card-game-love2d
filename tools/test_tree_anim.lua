local TK = require("tools.testkit")

local M = {}

local WORLD = "assets/sprites/world/"

local function range(prefix, n)
    local out = {}
    for i = 0, n - 1 do out[#out + 1] = prefix .. i end
    return out
end

local function join(...)
    local out = {}
    for _, l in ipairs({ ... }) do
        for _, v in ipairs(l) do out[#out + 1] = v end
    end
    return out
end

M.VEGETATION = {
    fields = join(range("fields_tree_", 6), { "fields_bush_0", "fields_flowers_0", "fields_tuft_0" }),
    highlands = join(range("highlands_pine_", 6), { "highlands_deadtree_0" },
        range("highlands_bush_", 3), range("highlands_grass_", 3)),
    abyss = join(range("abyss_deadtree_", 6), range("abyss_bush_", 3)),
    frost = join(range("frost_pine_", 6), range("frost_deadtree_", 2)),
    marsh = join(range("marsh_deadtree_", 8), { "marsh_bush_0" }, range("marsh_reeds_", 3),
        range("marsh_rock_", 4)),
    dusk = join(range("dusk_tree_", 7), { "dusk_bush_0" }, range("dusk_blooms_", 3)),
}

M.STATIC_OK = require("src.data.world_props").animStatic or {}

local function same(a, b)
    if a:getWidth() ~= b:getWidth() or a:getHeight() ~= b:getHeight() then return false end
    local ok = true
    a:mapPixel(function(x, y, r, g, bl, al)
        if ok then
            local r2, g2, b2, a2 = b:getPixel(x, y)
            if r ~= r2 or g ~= g2 or bl ~= b2 or al ~= a2 then ok = false end
        end
        return r, g, bl, al
    end)
    return ok
end

local function split(name)
    local bid, kind, v = name:match("^(%a+)_(%a+)_(%d+)$")
    return bid, kind, tonumber(v)
end

local function checkOne(t, WorldRoad, name)
    local bid, kind, v = split(name)
    local hasDir = love.filesystem.getInfo("assets/sprites/world/anim/" .. name) ~= nil
    local fr, base = WorldRoad.treeAnim(bid, kind, v)
    t:eq(name .. ": pasta anim e quadros carregados andam juntos", fr ~= nil, hasDir)
    if not fr then return false end
    t:check(name .. ": 4 ou mais quadros", #fr >= 4)
    t:eq(name .. ": quadros do tamanho da base", fr[1]:getWidth() .. "x" .. fr[1]:getHeight(),
        base:getWidth() .. "x" .. base:getHeight())
    local d0 = love.image.newImageData("assets/sprites/world/anim/" .. name .. "/0.png")
    local db = love.image.newImageData(WORLD .. name .. ".png")
    t:check(name .. ": quadro 0 idêntico ao PNG estático", same(d0, db))
    local moved, outside, area = 0, 0, 0
    db:mapPixel(function(x, y, r, g, bl, al)
        if al > 0 then area = area + 1 end
        return r, g, bl, al
    end)
    local worst = 0
    for i = 1, #fr - 1 do
        local di = love.image.newImageData("assets/sprites/world/anim/" .. name .. "/" .. i .. ".png")
        local m = 0
        di:mapPixel(function(x, y, r, g, bl, al)
            local r0, g0, b0, a0 = db:getPixel(x, y)
            if (a0 == 0) ~= (al == 0) then outside = outside + 1 end
            if a0 > 0 and (r ~= r0 or g ~= g0 or bl ~= b0) then m = m + 1 end
            return r, g, bl, al
        end)
        moved = moved + m
        worst = math.max(worst, m)
        di:release()
    end
    d0:release()
    db:release()
    t:eq(name .. ": silhueta idêntica em todos os quadros", outside, 0)
    t:check(name .. ": algo mexe (" .. moved .. " px somados)", moved > 0)
    local cap = 0.15
    t:check(("%s: movimento pequeno (pior quadro %d de %d px)"):format(name, worst, area), worst <= area * cap)
    return true
end

function M.run()
    local t = TK.new("vegetação animada do WorldRoad (quadros PixelLab sobre o balanço)")
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()

    local a = WorldRoad.TREE_ANIM
    t:check(("fps baixo 4 a 6 (obtido %s)"):format(tostring(a.fps)), a.fps >= 4 and a.fps <= 6)
    t:truthy("loop pingpong", a.pingpong)

    local total, animated = 0, 0
    for _, bid in ipairs({ "fields", "highlands", "abyss", "frost", "marsh", "dusk" }) do
        for _, name in ipairs(M.VEGETATION[bid]) do
            if love.filesystem.getInfo(WORLD .. name .. ".png") then
                total = total + 1
                local ok = checkOne(t, WorldRoad, name)
                if ok then
                    animated = animated + 1
                    t:check(name .. ": animado e também listado como estático", not M.STATIC_OK[name])
                else
                    t:check(name .. ": vegetação sem animação precisa de motivo em world_props.animStatic",
                        M.STATIC_OK[name] ~= nil)
                end
            end
        end
    end
    t:check(("vegetação animada %d de %d"):format(animated, total), animated > 0)

    WorldRoad._time = 3.7
    local fr = WorldRoad.treeAnim("fields", "tree", 0)
    local seen = {}
    local n = 0
    for k = 0, 9 do
        local _, _, f = WorldRoad.treeAnim("fields", "tree", 0, k / 10)
        if not seen[f] then seen[f] = true; n = n + 1 end
    end
    t:check(("vizinhas com fase diferente caem em quadros diferentes (%d quadros distintos em 10 fases)"):format(n),
        n >= math.min(#fr, 4))

    local _, _, f1 = WorldRoad.treeAnim("fields", "tree", 0, 0.25)
    WorldRoad._time = 3.7 + 1 / a.fps + 0.001
    local _, _, f2 = WorldRoad.treeAnim("fields", "tree", 0, 0.25)
    t:check("o quadro avança com o relógio", f1 ~= f2)

    for _, kind in ipairs({ "deadtree" }) do
        local efr = WorldRoad.treeAnim("abyss", kind, 0)
        t:check(("abyss %s: brilho respira devagar (fps %s ≤ 3)"):format(kind, tostring(efr and efr.fps)),
            efr ~= nil and efr.fps ~= nil and efr.fps <= 3)
    end

    t:check("luminária não entra pelo caminho da vegetação",
        WorldRoad.treeAnim("fields", "lantern", 0) == nil)

    WorldRoad.clearCache()
    return t:done()
end

return M
