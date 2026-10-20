local TK = require("tools.testkit")
local M = {}

M.MAX_RUN = 7
M.SCALE = 3

local function lowRows(data, below)
    local w = data:getWidth()
    local low = {}
    for x = 0, w - 1 do
        local lr = -1
        for y = below - 1, 0, -1 do
            local _, _, _, a = data:getPixel(x, y)
            if a >= 0.6 then lr = y; break end
        end
        low[x] = lr
    end
    return low
end

local function longestEqual(low, w, minRow)
    local best, run, prev = 0, 0, nil
    for x = 0, w - 1 do
        local v = low[x]
        if v >= 0 and v >= minRow and v == prev then
            run = run + 1
        elseif v >= 0 and v >= minRow then
            run = 1
        else
            run = 0
        end
        prev = v
        if run > best then best = run end
    end
    return best
end
M.longestEqual = longestEqual

local function spriteList()
    local GC = require("engine.GroundCut")
    local PC = require("src.ui.WorldRoad").PropCut
    local out = {}
    local files = love.filesystem.getDirectoryItems("assets/sprites/world")
    table.sort(files)
    for _, f in ipairs(files) do
        local name = f:match("^(.+)%.png$")
        local kind = name and name:match("^%a+_(%a+)_%d+$")
        if kind and (PC.kinds[kind] or GC.FLAT_KINDS[kind]) then
            out[#out + 1] = { name = name, kind = kind, tree = PC.kinds[kind] == true }
        end
    end
    return out
end

local function render(W, H, fn)
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.5, 0.5, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    fn()
    love.graphics.setCanvas()
    local id = cv:newImageData()
    cv:release()
    return id
end

local function luma(id, x, y)
    local r, g, b = id:getPixel(x, y)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

function M.run()
    local t = TK.new("Base de árvore e prop sem linha reta: corte do chão recortado, contato em lente")
    local GC = require("engine.GroundCut")
    local WorldRoad = require("src.ui.WorldRoad")
    local PC = WorldRoad.PropCut
    local CS = require("engine.ContactShadow")

    local oldBad, checked = 0, 0
    for _, it in ipairs(spriteList()) do
        local orig = love.image.newImageData("assets/sprites/world/" .. it.name .. ".png")
        local cd, cut = PC.groundCut(orig, it.name)
        if it.tree then
            local cutRow = orig:getHeight() - cut
            local depth = GC.depthFor(cut)
            local oldRun = longestEqual(lowRows(orig, cutRow), orig:getWidth(), cutRow - 1 - depth)
            if oldRun > M.MAX_RUN then oldBad = oldBad + 1 end
            local run = longestEqual(lowRows(cd, cutRow), cd:getWidth(), cutRow - 1 - depth)
            checked = checked + 1
            t:truthy(("%s: base sem reta (maior trecho %d px de sprite, era %d, máx %d)")
                :format(it.name, run, oldRun, M.MAX_RUN), run <= M.MAX_RUN)
            t:eq(it.name .. ": nada abaixo do corte (sombra não mostra raiz escondida)",
                GC.bottomRow(cd) < cutRow, true)
        else
            local bottom = GC.bottomRow(orig)
            local oldRun = GC.longestRun(orig, bottom)
            if oldRun >= GC.CFG.flatRun then
                local run = longestEqual(lowRows(cd, bottom + 1), cd:getWidth(), bottom - GC.CFG.flatDepth)
                checked = checked + 1
                t:truthy(("%s: base chata recortada (maior trecho %d, era %d)"):format(it.name, run, oldRun),
                    run <= M.MAX_RUN)
            end
        end
        if cd ~= orig then cd:release() end
        orig:release()
    end
    t:truthy(("a régua pega o defeito antigo (%d sprites com base reta no corte antigo)"):format(oldBad), oldBad >= 10)
    t:truthy("sprites conferidos: " .. checked, checked >= 60)

    do
        local s = M.SCALE
        WorldRoad.clearCache()
        local img = WorldRoad._getSprite("tree", 0, "fields")
        local _, ihv = PC.get(img, "tree")
        local W, H = img:getWidth() * s + 40, ihv * s + 40
        local X, Y = math.floor(W / 2), H - 20
        local id = render(W, H, function()
            love.graphics.clear(0, 0, 0, 0)
            PC.draw(img, "tree", X, Y, 0, s, s, 0)
        end)
        local low = {}
        for x = 0, W - 1 do
            local lr = -1
            for y = H - 1, 0, -1 do
                local _, _, _, a = id:getPixel(x, y)
                if a > 0.5 then lr = y; break end
            end
            low[x] = lr
        end
        local run = longestEqual(low, W, Y - 1 - (GC.CFG.depthMax + 1) * s)
        t:truthy(("jogo: carvalho do ato 1 desenhado sem reta na base (maior trecho %d px, máx %d)")
            :format(run, (M.MAX_RUN + 1) * s), run <= (M.MAX_RUN + 1) * s)
        id:release()
    end

    do
        local s = M.SCALE
        local orig = love.image.newImageData("assets/sprites/world/fields_tree_0.png")
        local img = love.graphics.newImage(orig)
        local cut = PC.cutFor(orig:getHeight(), PC.data.sink.fields_tree_0)
        local fp = CS.scan(img, orig, cut)
        local W, H = 1920, 1080
        local FX, FY = 960, 600
        local id = render(W, H, function()
            CS.setFrame(require("src.data.scene_integration").fields.contact, 0.36, 0.22, 0.46)
            CS.queue(img, FX, FY, s, 1, 1, 1)
            CS.flush()
        end)
        local ground = luma(id, 4, 4)
        local x0, x1 = FX - fp.w * s, FX + fp.w * s
        local bot, minX, maxX = {}, nil, nil
        for x = x0, x1 do
            local lr = -1
            for y = FY + 60, FY, -1 do
                if luma(id, x, y) < ground - 0.004 then lr = y; break end
            end
            bot[x - x0] = lr
            if lr >= 0 then
                minX = minX or x
                maxX = x
            end
        end
        local width = minX and (maxX - minX + 1) or 0
        local run = longestEqual(bot, x1 - x0 + 1, FY)
        t:truthy("contato: escureceu", width > 0)
        t:truthy(("contato: fundo em lente, não retângulo (maior reta %d de %d px)"):format(run, width),
            width > 0 and run <= width * 0.45)
        id:release()
        img:release()
        orig:release()
    end

    WorldRoad.clearCache()
    return t:done()
end

return M
