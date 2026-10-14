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

    for hall, cfg in pairs(InteriorFX.HALLS) do
        local flows = cfg.anim and cfg.anim.flows or {}
        if #flows > 0 then
            local data = love.image.newImageData("assets/sprites/scenes/castle_hall_" .. hall .. ".png")
            for i, r in ipairs(flows) do
                local lava, total = 0, r[3] * r[4]
                for y = r[2], r[2] + r[4] - 1 do
                    for x = r[1], r[1] + r[3] - 1 do
                        local cr, cg, cb = data:getPixel(x, y)
                        if 0.3 * cr + 0.59 * cg + 0.11 * cb > 0.45 then lava = lava + 1 end
                    end
                end
                t:truthy(("salão %d cascata %d cobre lava pintada (%d%%)")
                    :format(hall, i, math.floor(lava / total * 100)), lava / total >= 0.3)
            end
        end
    end

    do
        local GS = require("src.scenes.GameplayScene")
        t:eq("4:3 não muda o chefe", GS.hallScreenK("castle_hall_3", 1024, 768), 1)
        t:near("1080p: chefe 1.3x (4.8/3.7)",
            GS.hallScreenK("castle_hall_3", 1920, 1080), 4.8 / 3.7, 1e-6)
        t:near("1440p mantém a proporção da sala (6.4/3.7)",
            GS.hallScreenK("castle_hall_3", 2560, 1440), 6.4 / 3.7, 1e-6)
        t:near("4K mantém a proporção da sala (9.6/3.7)",
            GS.hallScreenK("castle_hall_3", 3840, 2160), 9.6 / 3.7, 1e-6)
        t:eq("1366x768 não muda o chefe", GS.hallScreenK("castle_hall_3", 1366, 768), 1)
        t:eq("cena que não é salão não muda", GS.hallScreenK("gameplay", 2560, 1440), 1)
    end

    do
        local D = require("src.ui.InteriorDepth")
        local canvas = love.graphics.newCanvas(32, 32)
        t:noerror("InteriorDepth desenha sob o tirano", function()
            D.noteBbox({ width = 300, height = 330 })
            love.graphics.setCanvas(canvas)
            D.drawContact(3, "abyss_tyrant", 512, 560)
            D.drawContact(2, "tower_lich", 512, 560)
            love.graphics.setCanvas()
        end)
        D.reset()
    end

    t:falsy("InteriorFX não desenha círculo (as 'bolas de luz')",
        readSrc("src/ui/InteriorFX.lua"):find("graphics.circle", 1, true) ~= nil)

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

    t:eq("sem hook: véu zero", InteriorFX.renderedFog(), 0)
    InteriorFX.fogHook = function() return 1 end
    for _ = 1, 60 do InteriorFX.update(1 / 30, 4) end
    t:truthy("hook=1: véu assenta acima de 0.9 em 2 s (" .. string.format("%.2f", InteriorFX.renderedFog()) .. ")",
        InteriorFX.renderedFog() > 0.9)
    t:noerror("salão com véu desenha (chão + camada da frente)", function()
        love.graphics.setCanvas(canvas)
        InteriorFX.draw(4)
        InteriorFX.drawFront(4, 80)
        love.graphics.setCanvas()
    end)
    InteriorFX.fogHook = function() return 0 end
    for _ = 1, 15 do InteriorFX.update(1 / 30, 4) end
    t:truthy("hook=0: véu cai (não some num corte)",
        InteriorFX.renderedFog() < 0.9 and InteriorFX.renderedFog() > 0.05)
    InteriorFX.fogHook = function() return "lixo" end
    t:noerror("hook que devolve lixo não derruba o update", function() InteriorFX.update(1 / 30, 4) end)
    InteriorFX.fogHook = nil
    InteriorFX.clear()
    t:eq("clear zera o véu", InteriorFX.renderedFog(), 0)

    return t:done()
end

return M
