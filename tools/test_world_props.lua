local TK = require("tools.testkit")
local M = {}

local WORLD = "assets/sprites/world/"
local TREEISH = { tree = true, pine = true, deadtree = true, bush = true }

local function bottomOpaqueWidth(data, row)
    local w, n = data:getWidth(), 0
    for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, row)
        if a >= 0.6 then n = n + 1 end
    end
    return n
end

function M.run()
    local t = TK.new("Props de árvore do mundo (PNG, raízes no chão)")
    local biomes = require("src.data.biomes")
    local props = require("src.data.world_props")
    local WorldRoad = require("src.ui.WorldRoad")

    local TREE_KIND = { fields = "tree", highlands = "pine", abyss = "deadtree",
                        frost = "pine", marsh = "deadtree", dusk = "tree" }
    for _, b in ipairs(biomes) do
        local kinds = {}
        for k in pairs(b.propWeights or {}) do
            if TREEISH[k] then kinds[#kinds + 1] = k end
        end
        table.sort(kinds)
        for _, k in ipairs(kinds) do
            local path = WORLD .. b.id .. "_" .. k .. "_0.png"
            local has = love.filesystem.getInfo(path) ~= nil
            if k == TREE_KIND[b.id] then
                t:truthy(("%s: espécie da parede '%s' tem PNG da variante 0"):format(b.id, k), has)
            elseif not has then
                print(("  [aviso] %s: kind '%s' sorteável sem PNG (procedural)"):format(b.id, k))
            end
        end
    end

    local keys = {}
    for k in pairs(props.sink) do keys[#keys + 1] = k end
    table.sort(keys)
    t:check("tabela de sink não está vazia", #keys > 0)
    t:check("SINK_DEFAULT_FRAC < SINK_MAX_FRAC",
        props.SINK_DEFAULT_FRAC < props.SINK_MAX_FRAC)
    for _, key in ipairs(keys) do
        local sink = props.sink[key]
        local path = WORLD .. key .. ".png"
        local info = love.filesystem.getInfo(path)
        if t:truthy(key .. ": PNG existe", info ~= nil) then
            local data = love.image.newImageData(path)
            local h = data:getHeight()
            t:check(("%s: sink %d dentro de [1, %d%% da altura %d]")
                :format(key, sink, props.SINK_MAX_FRAC * 100, h),
                sink >= 1 and sink <= math.floor(h * props.SINK_MAX_FRAC))
            t:check(key .. ": sem margem transparente embaixo (crop)",
                bottomOpaqueWidth(data, h - 1) > 0)
            t:check(key .. ": linha de contato tem tronco opaco",
                bottomOpaqueWidth(data, h - sink - 1) >= 3)
        end
    end

    local cut0, vis0, h0 = WorldRoad.propCutInfo("tree", 0, "fields")
    t:eq("fields tree v0: sink da tabela", cut0, props.sink.fields_tree_0)
    t:eq("fields tree v0: altura visível = altura - sink", vis0, h0 - cut0)
    local cut2 = WorldRoad.propCutInfo("tree", 2, "fields")
    local hasV2 = love.filesystem.getInfo(WORLD .. "fields_tree_2.png") ~= nil
    if hasV2 then
        t:eq("fields tree v2: sink da própria tabela", cut2, props.sink.fields_tree_2)
    else
        t:eq("fields tree v2 sem PNG: herda o sink da variante 0", cut2, cut0)
    end
    local cutRock = WorldRoad.propCutInfo("rock", 0, "fields")
    t:eq("pedra não enterra", cutRock, 0)
    local cutLum = WorldRoad.propCutInfo("lantern", 0, "fields")
    t:eq("luminária não enterra por aqui (footPad é do LuminaireEngine)", cutLum, 0)
    local cutBush, _, hBush = WorldRoad.propCutInfo("bush", 0, "fields")
    t:eq("arbusto sem entrada: SINK_DEFAULT_FRAC da altura", cutBush,
        math.floor(hBush * props.SINK_DEFAULT_FRAC + 0.5))

    return t:done()
end

return M
