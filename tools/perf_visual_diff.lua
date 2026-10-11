-- tools/perf_visual_diff.lua
-- PROVA VISUAL de otimização do WorldRoad: renderiza casos DETERMINÍSTICOS
-- (relógio congelado, RNGs semeados) e compara pixel a pixel com uma
-- referência gravada ANTES da mudança. Otimização de desenho que muda
-- pixel não é otimização, é regressão.
--
--   love . test_one perf_visual_diff ref            (grava referência)
--   love . test_one perf_visual_diff cmp            (compara; PNG de diff)
--   love . test_one perf_visual_diff ref:1920x1080  (idem noutro tamanho)
--
-- Saída: <save dir>/perfdiff/<WxH>/{ref,cur,diff}_<caso>.png + resumo no
-- console (px diferentes, maior delta por canal). Não roda no test_all:
-- a referência é da máquina/driver de quem mede.

local M = {}

local CASES = {
    -- nome, bioma, nº de updates antes do frame, extra(state)
    { "b1_static", 1, 200 },
    { "b2_static", 2, 200 },
    { "b3_static", 3, 200 },
    { "b4_static", 4, 200 },
    { "b5_static", 5, 200 },
    { "b6_static", 6, 200 },
    { "b3_blend",  3, 50 },                  -- meio do crossfade de bioma
    { "b1_travel", 1, 200, "travel" },       -- câmera andando
    { "b2_fork",   2, 200, "fork" },         -- encruzilhada (3 braços)
}

local function setupCase(WorldRoad, c)
    love.math.setRandomSeed(42)
    math.randomseed(42)
    WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    WorldRoad._time = 0
    WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(0.6, true)
end

function M.run(arg)
    local mode, size = "cmp", nil
    for part in tostring(arg or ""):gmatch("[^:]+") do
        if part:match("^%d+x%d+$") then size = part else mode = part end
    end
    if size then
        local w, h = size:match("(%d+)x(%d+)")
        love.window.setMode(tonumber(w), tonumber(h))
    end
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()

    local W, H = love.graphics.getDimensions()
    local dir = string.format("perfdiff/%dx%d", W, H)
    love.filesystem.createDirectory(dir)
    local WorldRoad = require("src.ui.WorldRoad")
    local canvas = love.graphics.newCanvas(W, H)
    local realGetTime = love.timer.getTime
    local realMouse = love.mouse.getPosition
    local allOk = true
    local topBarH = 52

    for _, c in ipairs(CASES) do
        local name, bio, n, extra = c[1], c[2], c[3], c[4]
        setupCase(WorldRoad, c)
        -- relógio de parede congelado: flicker de luminária/brasas usam
        -- love.timer.getTime (o resto é o relógio do mundo)
        love.timer.getTime = function() return 1000 end
        -- mouse fora da janela: o hover do fork (fogo acelera, marco
        -- clareia) lê a posição REAL do cursor de quem roda a ferramenta
        love.mouse.getPosition = function() return -10000, -10000 end
        -- 1º draw instala bioma/props; depois os updates avançam o mundo
        love.graphics.setCanvas(canvas)
        WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
        love.graphics.setCanvas()
        if extra == "travel" then
            WorldRoad.travel({ distance = 60, duration = 40 })
        elseif extra == "fork" then
            WorldRoad.showFork({ { type = "battle" }, { type = "rest" },
                { type = "shop" } }, function() end)
        end
        for i = 1, n do
            WorldRoad.update(1 / 60)
            -- frames intermediários desenhados: o motor tem estado por
            -- frame (cache de fileiras, broto) que só evolui no draw
            if i % 10 == 0 or i > n - 3 then
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
                WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
                love.graphics.setCanvas()
            end
        end
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
        love.graphics.setCanvas()
        love.timer.getTime = realGetTime
        love.mouse.getPosition = realMouse
        local img = canvas:newImageData()

        if mode == "ref" then
            img:encode("png", dir .. "/ref_" .. name .. ".png")
            print(string.format("[vdiff] ref gravada: %s/ref_%s.png", dir, name))
        else
            img:encode("png", dir .. "/cur_" .. name .. ".png")
            local refPath = dir .. "/ref_" .. name .. ".png"
            if not love.filesystem.getInfo(refPath) then
                print("[vdiff] SEM referência pra " .. name .. " — rode o modo ref antes")
                allOk = false
            else
                local ref = love.image.newImageData(refPath)
                local diff = love.image.newImageData(W, H)
                local nDiff, maxD = 0, 0
                for y = 0, H - 1 do
                    for x = 0, W - 1 do
                        local r1, g1, b1 = img:getPixel(x, y)
                        local r2, g2, b2 = ref:getPixel(x, y)
                        local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2),
                            math.abs(b1 - b2))
                        if d > 1.5 / 255 then
                            nDiff = nDiff + 1
                            if d > maxD then maxD = d end
                            diff:setPixel(x, y, 1, 0, 1, 1)
                        else
                            local l = (r2 + g2 + b2) / 3 * 0.35
                            diff:setPixel(x, y, l, l, l, 1)
                        end
                    end
                end
                diff:encode("png", dir .. "/diff_" .. name .. ".png")
                local frac = nDiff / (W * H)
                print(string.format("[vdiff] %-10s px diferentes %7d (%.3f%%)  maior delta %.0f/255",
                    name, nDiff, frac * 100, maxD * 255))
            end
        end
    end
    print("[vdiff] pasta: " .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    return allOk
end

return M
