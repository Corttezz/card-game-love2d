-- tools/perf_probe.lua
-- Sonda de CUSTO DE FRAME das cenas pesadas (revisão de lançamento, Out/2026).
-- Mede, por bioma do WorldRoad, o tempo de CPU de update+draw e as
-- estatísticas do renderer (draw calls, trocas de canvas/shader, memória de
-- textura). Não é teste (não falha): é instrumento — rode antes/depois de
-- mexer em cena. A trava de regressão é tools/test_perf_budget.lua.
--
--   love . test_one perf_probe                  (janela atual)
--   love . test_one perf_probe 1920x1080        (tamanho pedido)
--   love . test_one perf_probe profile          (+ jit.profile por linha)
--   love . test_one perf_probe 1920x1080:phases (+ ms por fase do draw)
--
-- Leitura: >16.6 ms de CPU = abaixo de 60 fps só de CPU; draw calls na casa
-- dos milhares em GPU integrada é o primeiro suspeito de queda de fps.
-- Máquina compartilhada = ruído: compare MEDIANA/p95, não média/pior.

local M = {}

local function pct(sorted, p)
    if #sorted == 0 then return 0 end
    local i = math.max(1, math.min(#sorted, math.ceil(#sorted * p)))
    return sorted[i]
end

local function measure(label, n, fn)
    -- Mede só o TRABALHO do frame (update+draw+flush), fora do present —
    -- o present espera o vsync e mascararia tudo em ~16.6 ms. O 1º frame
    -- (carga de assets do bioma) sai separado: é o "engasgo" da troca de ato.
    local samples, first = {}, nil
    local stats
    for i = 1, n do
        local f0 = love.timer.getTime()
        love.graphics.clear(0, 0, 0, 1)
        fn()
        love.graphics.flushBatch()
        stats = love.graphics.getStats()
        local dt = love.timer.getTime() - f0
        if i == 1 then first = dt else samples[#samples + 1] = dt * 1000 end
        love.graphics.present()
    end
    table.sort(samples)
    local med, p95 = pct(samples, 0.5), pct(samples, 0.95)
    print(string.format("[perf] %-22s 1o frame %6.1f ms", label, first * 1000))
    print(string.format("[perf] %-22s med %6.2f ms  p95 %6.2f ms  draws %5d  canvas %3d  shader %3d  texmem %6.1f MB",
        label, med, p95, stats.drawcalls, stats.canvasswitches,
        stats.shaderswitches or -1, stats.texturememory / (1024 * 1024)))
    return med, p95, stats
end
M.measure = measure

function M.run(arg)
    -- arg: "1920x1080", "phases", "profile" ou combinado "1920x1080:phases"
    -- (o dispatcher test_one repassa um único argumento)
    local size, mode = nil, nil
    for part in tostring(arg or ""):gmatch("[^:]+") do
        if part:match("^%d+x%d+$") then size = part else mode = part end
    end
    if size then
        local w, h = size:match("(%d+)x(%d+)")
        if w then love.window.setMode(tonumber(w), tonumber(h)) end
    end
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    -- (setVSync dentro do love.load travava a janela de ferramenta)

    -- jitv: registra TODO abort/flush de trace desde o início (blacklist é
    -- histórico — abortos repetidos no MESMO ponto viram interpretador)
    if mode == "jitv" then
        local jutil = require("jit.util")
        M._aborts = {}
        M._onTrace = function(what, tr, func, pc, otr, oex)
            local key
            if what == "flush" then key = "<FLUSH>"
            elseif what == "abort" then
                local fi = jutil.funcinfo(func, pc)
                key = string.format("abort %s err=%s/%s", tostring(fi.loc),
                    tostring(otr), tostring(oex))
            end
            if key then M._aborts[key] = (M._aborts[key] or 0) + 1 end
        end
        jit.attach(M._onTrace, "trace")
        print("[jit] " .. tostring(jit.version))
    end

    local W, H = love.graphics.getDimensions()
    print(string.format("[perf] janela %dx%d — %s", W, H, love.graphics.getRendererInfo()))

    local WorldRoad = require("src.ui.WorldRoad")
    local topBarH = 52
    local function frame(bio)
        WorldRoad.update(1 / 60)
        WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
    end
    -- "switch": perfil por amostragem SÓ dos 1ºs frames de cada troca de
    -- bioma (onde mora o engasgo) — top linhas acumuladas nas 5 trocas
    local swProf, swCounts, swTotal
    if mode == "switch" then
        local okp, prof = pcall(require, "jit.profile")
        if okp then
            swProf, swCounts, swTotal = prof, {}, 0
        end
    end
    local firsts = {}
    for bio = 1, 6 do
        local ok, err = pcall(function()
            -- 1º frame do bioma SEM aquecimento: é o engasgo da troca de
            -- ato. Os 3 primeiros frames saem separados (o pior deles é o
            -- número que importa); depois a troca de bioma (crossfade de
            -- 2.2s) corre e o regime estável é medido sozinho.
            local worst = 0
            for i = 1, 3 do
                if swProf and bio > 1 then
                    swProf.start("li1", function(th, samples)
                        local where = swProf.dumpstack(th, "pl", 1)
                        swCounts[where] = (swCounts[where] or 0) + samples
                        swTotal = swTotal + samples
                    end)
                end
                local prof = (mode == "switch") and {} or nil
                WorldRoad._prof = prof
                local f0 = love.timer.getTime()
                love.graphics.clear(0, 0, 0, 1)
                frame(bio)
                love.graphics.flushBatch()
                local dt = (love.timer.getTime() - f0) * 1000
                WorldRoad._prof = nil
                if prof and bio > 1 then
                    local parts = {}
                    for k, v in pairs(prof) do
                        if v >= 1 then parts[#parts + 1] = string.format("%s %.0f", k, v) end
                    end
                    table.sort(parts)
                    print(string.format("[switch] bioma %d frame %d: %.1f ms  (%s)",
                        bio, i, dt, table.concat(parts, ", ")))
                end
                if swProf and bio > 1 then swProf.stop() end
                love.graphics.present()
                worst = math.max(worst, dt)
            end
            firsts[#firsts + 1] = worst
            print(string.format("[perf] bioma %d TROCA: pior dos 3 primeiros frames %6.1f ms", bio, worst))
            for _ = 1, 150 do WorldRoad.update(1 / 60) end   -- passa o crossfade
            measure("worldroad bioma " .. bio, 120, function() frame(bio) end)
        end)
        if not ok then print("[perf] bioma " .. bio .. " FALHOU: " .. tostring(err)) end
    end
    if swProf and swTotal > 0 then
        local list = {}
        for k, v in pairs(swCounts) do list[#list + 1] = { k, v } end
        table.sort(list, function(x, y) return x[2] > y[2] end)
        for i = 1, math.min(30, #list) do
            print(string.format("[switch] %5.1f%%  %s", list[i][2] * 100 / swTotal, list[i][1]))
        end
    end
    -- crossfade de bioma (as 2 camadas de chão/castelo/props ao mesmo tempo)
    do
        WorldRoad.setBiome(2)
        for _ = 1, 3 do frame(2) end
        measure("crossfade 1->2", 90, function() frame(1) end)
        for _ = 1, 150 do WorldRoad.update(1 / 60) end
    end

    -- Viagem (câmera andando): o caso sem cache estático
    do
        WorldRoad.setBiome(1)
        for _ = 1, 10 do frame(1) end
        WorldRoad.travel({ distance = 40, duration = 30 })
        measure("bioma 1 VIAJANDO", 120, function() frame(1) end)
        WorldRoad._travel = nil
    end

    -- Decomposição (bioma 1): onde mora o custo?
    if mode == "phases" then
        local GrassField = require("engine.GrassField")
        local ShadowEngine = require("engine.ShadowEngine")
        local LightEngine = require("engine.LightEngine")
        local prof = {}
        local gcalls, gms, gsprites = 0, 0, 0
        local origG = GrassField.draw
        GrassField.draw = function(ctx)
            local t0 = love.timer.getTime()
            origG(ctx)
            love.graphics.flushBatch()
            gms = gms + (love.timer.getTime() - t0) * 1000
            gcalls = gcalls + 1
            gsprites = gsprites + (GrassField._lastCount or 0)
        end
        local origS, sms = ShadowEngine.flush, 0
        ShadowEngine.flush = function()
            local t0 = love.timer.getTime()
            origS()
            love.graphics.flushBatch()
            sms = sms + (love.timer.getTime() - t0) * 1000
        end
        local origL, lms = LightEngine.composite, 0
        LightEngine.composite = function(...)
            local t0 = love.timer.getTime()
            origL(...)
            love.graphics.flushBatch()
            lms = lms + (love.timer.getTime() - t0) * 1000
        end
        local N = 90
        WorldRoad._prof = prof
        collectgarbage("collect")
        collectgarbage("stop")
        local gcBefore = collectgarbage("count")
        for _ = 1, N do
            love.graphics.clear(0, 0, 0, 1)
            frame(1)
            love.graphics.flushBatch()
            love.graphics.present()
        end
        local gcAfter = collectgarbage("count")
        collectgarbage("restart")
        WorldRoad._prof = nil
        GrassField.draw, ShadowEngine.flush, LightEngine.composite = origG, origS, origL
        local keys = {}
        for k in pairs(prof) do
            if not k:match("^kb ") then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return prof[a] > prof[b] end)
        for _, k in ipairs(keys) do
            print(string.format("[phase] %-10s %6.2f ms  %7.1f KB", k, prof[k] / N,
                (prof["kb " .. k] or 0) / N))
        end
        print(string.format("[phase] grass(dentro de props) %6.2f ms em %.1f chamadas/frame  sprites/frame %d",
            gms / N, gcalls / N, math.floor(gsprites / N)))
        print(string.format("[phase] shadow.flush %6.2f ms   light.composite %6.2f ms",
            sms / N, lms / N))
        print(string.format("[phase] alocação Lua %.1f KB/frame (GC parado)",
            (gcAfter - gcBefore) / N))
    end

    -- Diagnóstico do JIT: traces abortados (NYI) nos laços quentes do draw.
    -- Laço que escreve FFI e NÃO compila fica mais lento que chamada C.
    if mode == "jitv" then
        jit.attach(M._onTrace)
        local list = {}
        for k, v in pairs(M._aborts) do list[#list + 1] = { k, v } end
        table.sort(list, function(x, y) return x[2] > y[2] end)
        for i = 1, math.min(40, #list) do
            print(string.format("[jit] %4d  %s", list[i][2], list[i][1]))
        end
    end

    -- Perfil por amostragem (LuaJIT jit.profile): top linhas do draw.
    if mode == "profile" then
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
                frame(1)
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
