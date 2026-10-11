-- tools/test_interior_fx.lua
-- Regressões dos salões de chefe (Out/2026, dono: "remove todas essas bolas
-- de luz das salas de chefe"):
--
--   1. Draw e update usam o MESMO salão (InteriorFX.hallFor). A v1 tickava
--      as brasas com math.min(3, ato) e desenhava o salão real — nos atos
--      4-6 as brasas saíam da lava do hall 3 ("veias esquisitas").
--   2. Toda chama declarada cai em cima de FOGO PINTADO (pixels claros
--      dentro do retângulo) — âncora vem do que está desenhado.
--   3. Nada de disco: InteriorFX não desenha círculo.
--   4. update/draw/drawFront rodam nos 6 salões em 4:3 e 16:9 sem erro.
--
-- Roda via: love . test_one test_interior_fx

local TK = require("tools.testkit")

local M = {}

local function readSrc(path)
    return love.filesystem.read(path) or ""
end

function M.run()
    local t = TK.new("test_interior_fx")
    local InteriorFX = require("src.ui.InteriorFX")
    local Config = require("src.core.Config")
    local total = Config.TotalActs or 6

    -- 1. fonte única do salão
    for act = 1, total do
        t:eq("ato " .. act .. " usa o próprio salão", InteriorFX.hallFor(act), act)
        t:truthy("salão " .. act .. " tem atmosfera declarada",
            InteriorFX.HALLS[act] ~= nil)
    end
    local scene = readSrc("src/scenes/GameplayScene.lua")
    t:falsy("GameplayScene não ticka InteriorFX com math.min(3, ...)",
        scene:find("InteriorFX%.update%([^\n]*math%.min%(3") ~= nil)
    t:truthy("GameplayScene escolhe o salão por InteriorFX.hallFor",
        scene:find("InteriorFX.hallFor", 1, true) ~= nil)
    for _, tool in ipairs({ "tools/boss_rooms.lua", "tools/screenshot_enemy_scene.lua" }) do
        t:falsy(tool .. " não ticka com math.min(3, ...)",
            readSrc(tool):find("update%([^\n]*math%.min%(3") ~= nil)
    end

    -- 2. chama declarada = fogo pintado
    for hall, cfg in pairs(InteriorFX.HALLS) do
        local ok, data = pcall(love.image.newImageData,
            "assets/sprites/scenes/castle_hall_" .. hall .. ".png")
        t:truthy("salão " .. hall .. " carrega a arte", ok)
        if ok then
            local iw, ih = data:getWidth(), data:getHeight()
            for i, f in ipairs(cfg.flames) do
                local inside = f[1] >= 0 and f[2] >= 0
                    and f[1] + f[3] <= iw and f[2] + f[4] <= ih
                t:truthy(("salão %d chama %d dentro da arte"):format(hall, i), inside)
                local bright = 0
                if inside then
                    for y = f[2], f[2] + f[4] - 1 do
                        for x = f[1], f[1] + f[3] - 1 do
                            local r, g, b = data:getPixel(x, y)
                            if 0.3 * r + 0.59 * g + 0.11 * b > 0.70 then
                                bright = bright + 1
                            end
                        end
                    end
                end
                t:truthy(("salão %d chama %d pousa em fogo pintado (%d px claros)")
                    :format(hall, i, bright), bright >= 6)
            end
        end
    end

    -- 3. sem discos
    t:falsy("InteriorFX não desenha círculo (as 'bolas de luz')",
        readSrc("src/ui/InteriorFX.lua"):find("graphics.circle", 1, true) ~= nil)

    -- 4. smoke nos dois aspectos (janela falsificada — setMode em tool trava)
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local canvas = love.graphics.newCanvas(64, 64)
    for _, size in ipairs({ { 1024, 768 }, { 1920, 1080 } }) do
        love.graphics.getWidth = function() return size[1] end
        love.graphics.getHeight = function() return size[2] end
        for act = 1, total do
            local hall = InteriorFX.hallFor(act)
            t:noerror(("salão %d roda em %dx%d"):format(hall, size[1], size[2]), function()
                InteriorFX.update(1 / 30, hall)
                love.graphics.setCanvas(canvas)
                InteriorFX.draw(hall)
                InteriorFX.drawFront(hall)
                love.graphics.setCanvas()
            end)
        end
    end
    love.graphics.setCanvas()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    InteriorFX.clear()

    return t:done()
end

return M
