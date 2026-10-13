-- tools/test_holo_shader.lua
-- O holo das cartas raras/lendárias EXISTE de verdade (Out/2026).
--
-- O defeito: src/ui/HoloShader.lua nasceu em Abr/2026 (a182eae) com um
-- `load()` que ninguém chamava — o CLAUDE.md §14 dizia "HoloShader em
-- rare/legendary" desde o mesmo commit, e Card:draw de fato pedia
-- HoloShader.draw(..., 0.75/0.35)... que, sem load, desenhava a carta crua.
-- A edition "holo" (Card:setEdition) caía no mesmo buraco: `isAvailable()`
-- false → _getEditionShader devolvia nil → carta sem efeito, sem aviso.
-- Seis meses de documentação descrevendo um efeito que não existia.
--
-- O que trava aqui:
--   • main.lua carrega o HoloShader no boot (conferido no FONTE, porque o
--     dispatcher de testes roda ANTES do bloco de shaders do love.load);
--   • load() compila shaders/holo.glsl de verdade;
--   • Card:draw aplica o holo: lendária 0.75, rara 0.35, comum nada, e a
--     edition holo numa comum passa pelo shader.
--
--   love . test_one test_holo_shader

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("holo em rara/lendaria: carregado no boot e aplicado no draw")
    TK.bootstrap()
    local HoloShader = require("src.ui.HoloShader")

    -- 1. o boot carrega (fonte)
    local src = love.filesystem.read("main.lua") or ""
    t:truthy("main.lua chama HoloShader.load() no boot",
        src:find('require("src.ui.HoloShader").load()', 1, true) ~= nil)

    -- 2. carrega de verdade
    t:truthy("HoloShader.load() compila shaders/holo.glsl", HoloShader.load())
    t:truthy("isAvailable() depois do load", HoloShader.isAvailable())

    -- 3. aplicado no draw (espiao em HoloShader.draw + love.graphics.setShader)
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return 1.0 end
    local function drawSpied(id, edition)
        local cd = db:getCard(id)
        if not cd then error("carta desconhecida no fixture: " .. tostring(id)) end
        local inst = db:createCardInstance(cd)
        inst.isHovered, inst.hoverStrength, inst.liftOffset = true, 1, 0
        if edition then inst.edition = edition end
        local strengths, shaderSets = {}, 0
        local realDraw, realSet = HoloShader.draw, love.graphics.setShader
        HoloShader.draw = function(img, x, y, strength, ...)
            strengths[#strengths + 1] = strength
            return realDraw(img, x, y, strength, ...)
        end
        love.graphics.setShader = function(s, ...)
            if s then shaderSets = shaderSets + 1 end
            return realSet(s, ...)
        end
        local canvas = love.graphics.newCanvas(400, 560)
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(inst.draw, inst, 200, 280, false, false)
        love.graphics.pop()
        HoloShader.draw, love.graphics.setShader = realDraw, realSet
        canvas:release()
        if not ok then error(err, 0) end
        return inst, strengths, shaderSets
    end

    local okRun, err = pcall(function()
        local leg, s1, sets1 = drawSpied("joker_001")
        t:eq("fixture: lendaria tem visualEffect holo", leg.visualEffect, "holo")
        t:eq("lendaria: HoloShader.draw com forca 0.75", s1[1], 0.75)
        t:truthy("lendaria: um shader de verdade e setado no draw", sets1 > 0)

        -- o efeito vem do ATLAS (src/data/card_art.lua), não só da raridade:
        -- há raras marcadas "holo" (warrior_bastion); juggernaut é rara "glow"
        local rare, s2 = drawSpied("warrior_juggernaut")
        t:eq("fixture: rara tem visualEffect glow", rare.visualEffect, "glow")
        t:eq("rara: HoloShader.draw com forca 0.35", s2[1], 0.35)

        local _, s3 = drawSpied("attack_001")
        t:eq("comum: sem holo", #s3, 0)

        local _, s4 = drawSpied("attack_001", "holo")
        t:eq("edition holo numa comum: HoloShader aplicado (era descartado em silencio)", s4[1], 0.75)
    end)
    love.timer.getTime = realGetTime
    t:check("sem excecao" .. (okRun and "" or (": " .. tostring(err))), okRun)

    return t:done()
end

return M
