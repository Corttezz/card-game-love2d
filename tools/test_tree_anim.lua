local TK = require("tools.testkit")

local M = {}

local FIELDS = 6

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

function M.run()
    local t = TK.new("árvores animadas do WorldRoad (quadros PixelLab sobre o balanço)")
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()

    local a = WorldRoad.TREE_ANIM
    t:check(("fps baixo 4 a 6 (obtido %s)"):format(tostring(a.fps)), a.fps >= 4 and a.fps <= 6)
    t:truthy("loop pingpong", a.pingpong)

    local animated = 0
    for v = 0, FIELDS - 1 do
        local name = "fields_tree_" .. v
        local fr, base = WorldRoad.treeAnim("fields", "tree", v)
        local hasDir = love.filesystem.getInfo("assets/sprites/world/anim/" .. name) ~= nil
        t:eq(name .. ": pasta anim e quadros carregados andam juntos", fr ~= nil, hasDir)
        if fr then
            animated = animated + 1
            t:check(name .. ": 4 ou mais quadros", #fr >= 4)
            t:eq(name .. ": quadros do tamanho da base", fr[1]:getWidth() .. "x" .. fr[1]:getHeight(),
                base:getWidth() .. "x" .. base:getHeight())
            local d0 = love.image.newImageData("assets/sprites/world/anim/" .. name .. "/0.png")
            local db = love.image.newImageData("assets/sprites/world/" .. name .. ".png")
            t:check(name .. ": quadro 0 idêntico ao PNG estático", same(d0, db))
            local moved, outside = 0, 0
            for i = 1, #fr - 1 do
                local di = love.image.newImageData("assets/sprites/world/anim/" .. name .. "/" .. i .. ".png")
                di:mapPixel(function(x, y, r, g, bl, al)
                    local r0, g0, b0, a0 = db:getPixel(x, y)
                    if (a0 == 0) ~= (al == 0) then outside = outside + 1 end
                    if a0 > 0 and (r ~= r0 or g ~= g0 or bl ~= b0) then moved = moved + 1 end
                    return r, g, bl, al
                end)
            end
            t:eq(name .. ": silhueta idêntica em todos os quadros", outside, 0)
            t:check(name .. ": a copa mexe (" .. moved .. " px somados)", moved > 0)
        end
    end

    t:check(("ao menos 2 árvores dos campos animadas (obtido %d)"):format(animated), animated >= 2)

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

    t:check("bioma sem pasta anim cai no sprite estático",
        WorldRoad.treeAnim("highlands", "pine", 0) == nil
        or love.filesystem.getInfo("assets/sprites/world/anim/highlands_pine_0") ~= nil)

    WorldRoad.clearCache()
    return t:done()
end

return M
