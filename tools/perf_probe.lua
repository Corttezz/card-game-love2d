-- tools/perf_probe.lua
-- Sonda de CUSTO DE FRAME das cenas pesadas (revisão de lançamento, Out/2026).
-- Mede, por bioma do WorldRoad, o tempo de CPU de update+draw e as
-- estatísticas do renderer (draw calls, trocas de canvas, memória de textura).
-- Não é teste (não falha): é instrumento — rode antes/depois de mexer em cena.
--
--   love . test_one perf_probe            (janela atual)
--   love . test_one perf_probe 1920x1080  (tamanho pedido)
--
-- Leitura: >16.6 ms de CPU = abaixo de 60 fps só de CPU; draw calls na casa
-- dos milhares em GPU integrada é o primeiro suspeito de queda de fps.

local M = {}

local function measure(label, n, fn)
    -- Mede só o TRABALHO do frame (update+draw+flush), fora do present —
    -- o present espera o vsync e mascararia tudo em ~16.6 ms. O 1º frame
    -- (carga de assets do bioma) sai separado: é o "engasgo" da troca de ato.
    local total, worst, first = 0, 0, nil
    local stats
    for i = 1, n do
        local f0 = love.timer.getTime()
        love.graphics.clear(0, 0, 0, 1)
        fn()
        love.graphics.flushBatch()
        stats = love.graphics.getStats()
        local dt = love.timer.getTime() - f0
        if i == 1 then first = dt else
            total = total + dt
            worst = math.max(worst, dt)
        end
        love.graphics.present()
    end
    local avg = total / math.max(1, n - 1)
    print(string.format("[perf] %-22s 1o frame %6.1f ms", label, first * 1000))
    print(string.format("[perf] %-22s avg %6.2f ms  worst %6.2f ms  draws %5d  canvas %3d  texmem %6.1f MB",
        label, avg * 1000, worst * 1000, stats.drawcalls, stats.canvasswitches,
        stats.texturememory / (1024 * 1024)))
    return avg
end

function M.run(size)
    if size and size ~= "profile" then
        local w, h = size:match("(%d+)x(%d+)")
        if w then love.window.setMode(tonumber(w), tonumber(h)) end
    end
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    -- (setVSync dentro do love.load travava a janela de ferramenta)

    local W, H = love.graphics.getDimensions()
    print(string.format("[perf] janela %dx%d — %s", W, H, love.graphics.getRendererInfo()))

    local WorldRoad = require("src.ui.WorldRoad")
    local topBarH = 52
    for bio = 1, 6 do
        local ok, err = pcall(function()
            for _ = 1, 20 do WorldRoad.update(1 / 60) end
            measure("worldroad bioma " .. bio, 90, function()
                WorldRoad.update(1 / 60)
                WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
                WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
            end)
        end)
        if not ok then print("[perf] bioma " .. bio .. " FALHOU: " .. tostring(err)) end
    end

    -- Decomposição (bioma 1): onde mora o custo?
    do
        local LightEngine = require("engine.LightEngine")
        local tu, td, to = 0, 0, 0
        local N = 60
        for _ = 1, N do
            love.graphics.clear(0, 0, 0, 1)
            local a0 = love.timer.getTime(); WorldRoad.update(1 / 60)
            local a1 = love.timer.getTime(); WorldRoad.draw(0, topBarH, W, H - topBarH, 1)
            local a2 = love.timer.getTime(); WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
            love.graphics.flushBatch()
            local a3 = love.timer.getTime()
            tu, td, to = tu + (a1 - a0), td + (a2 - a1), to + (a3 - a2)
            love.graphics.present()
        end
        print(string.format("[perf] split bioma 1: update %.2f ms  draw %.2f ms  overlays %.2f ms",
            tu / N * 1000, td / N * 1000, to / N * 1000))
        if LightEngine.setEnabled then
            LightEngine.setEnabled(false)
            measure("bioma 1 SEM luz", 60, function()
                WorldRoad.update(1 / 60)
                WorldRoad.draw(0, topBarH, W, H - topBarH, 1)
                WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
            end)
            LightEngine.setEnabled(true)
        end
    end

    -- Perfil por amostragem (LuaJIT jit.profile): top funções do draw.
    if size == "profile" then
        local okp, prof = pcall(require, "jit.profile")
        if okp then
            local counts, total = {}, 0
            prof.start("li1", function(th, samples)
                local where = prof.dumpstack(th, "pl", 1)
                counts[where] = (counts[where] or 0) + samples
                total = total + samples
            end)
            for _ = 1, 120 do
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.update(1 / 60)
                WorldRoad.draw(0, topBarH, W, H - topBarH, 1)
                WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
                love.graphics.flushBatch()
                love.graphics.present()
            end
            prof.stop()
            local list = {}
            for k, v in pairs(counts) do list[#list + 1] = { k, v } end
            table.sort(list, function(x, y) return x[2] > y[2] end)
            for i = 1, math.min(25, #list) do
                print(string.format("[prof] %5.1f%%  %s", list[i][2] * 100 / total, list[i][1]))
            end
        end
    end

    -- Menu (cenário em camadas + velas + fumaça)
    local Menu = require("components.Menu")
    local menu = Menu:new()
    measure("menu", 90, function() menu:update(1 / 60); menu:draw() end)

    return true
end

return M
