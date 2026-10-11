-- tools/test_weather.lua
-- Travas do WeatherEngine (clima com profundidade do WorldRoad, Out/2026):
--
--   1. Todo bioma do jogo tem clima declarado (tipo conhecido, cores).
--   2. Densidade limitada pelo preset e nada vira NaN em 2 min simulados.
--   3. PAINTER: o lote sai ordenado do fundo pra frente e o WorldRoad
--      desenha TODAS as partículas montadas no frame (nenhuma sobra fora
--      das fatias de profundidade) — em várias fatias, não numa camada só.
--   4. Multiply-only: tempestade + raio nunca levam o ambiente acima de 1
--      e o clarão nunca escurece além da tempestade.
--   5. Fotossensibilidade: ≥5 s entre raios e ≤3 acendimentos por segundo.
--   6. reducedMotion: sem raio/clarão, densidade cortada.
--   7. Troca de bioma: o clima velho some sozinho (frente de tempo, sem pop).
--   8. Fonte: flush dentro das fatias da grama, zero stencil.
--
-- Roda via: love . test_one test_weather

local TK = require("tools.testkit")

local M = {}

local KINDS = { snow = true, rain = true, ash = true, leaf = true, seed = true }

function M.run()
    local t = TK.new("test_weather")
    local WeatherEngine = require("engine.WeatherEngine")
    local WorldRoad = require("src.ui.WorldRoad")
    local biomes = require("src.data.biomes")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    -- 1. preset por bioma
    local list = biomes.list or biomes
    local n = 0
    for _, b in ipairs(list) do
        n = n + 1
        local pr = WeatherEngine.PRESETS[b.id]
        t:truthy("bioma " .. tostring(b.id) .. " tem clima", pr ~= nil)
        if pr then
            t:truthy(b.id .. ": tipo conhecido (" .. tostring(pr.kind) .. ")", KINDS[pr.kind])
            t:truthy(b.id .. ": tem cores", pr.colors and #pr.colors > 0)
        end
    end
    t:truthy("encontrou os biomas do jogo", n >= 6)

    local W, H = love.graphics.getDimensions()
    local function frame(bio)
        WorldRoad.update(1 / 30)
        WorldRoad.draw(0, 60, W, H - 60, bio)
        WorldRoad.drawOverlays(0, 60, W, H - 60)
    end

    -- 2 + 3. densidade, sanidade e painter em todos os biomas
    for bio = 1, 6 do
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        for _ = 1, 45 do frame(bio) end
        local P, np = WeatherEngine._particles()
        local pr = WeatherEngine.PRESETS[list[((bio - 1) % #list) + 1].id]
        local cap = pr and (pr.count + (pr.rise and pr.rise.count or 0) + 28) or 0
        t:truthy("bioma " .. bio .. ": tem partículas vivas", np > 0)
        t:truthy("bioma " .. bio .. ": densidade ≤ preset (" .. np .. " ≤ " .. cap .. ")", np <= cap)
        local finite, sorted = true, true
        for i = 1, np do
            local p = P[i]
            for _, k in ipairs({ "lx", "z", "hg", "vf" }) do
                local v = p[k]
                if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
                    finite = false
                end
            end
            if i > 1 and P[i - 1].sortRel < p.sortRel then sorted = false end
        end
        t:truthy("bioma " .. bio .. ": nenhum campo NaN/inf", finite)
        t:truthy("bioma " .. bio .. ": lote ordenado do fundo pra frente", sorted)
        t:eq("bioma " .. bio .. ": todas as montadas foram desenhadas", WeatherEngine.undrawn(), 0)
        t:truthy("bioma " .. bio .. ": intercalado em várias fatias (" ..
            WeatherEngine.stats.flushes .. ")", WeatherEngine.stats.flushes >= 3)
    end

    -- 2b. 2 minutos simulados (só update — barato) sem estourar
    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(4)
        frame(4)
        local maxN, ok = 0, true
        for i = 1, 3600 do
            WeatherEngine.update(1 / 30, { biomeId = "frost", camZ = 5.5 + i * 0.01,
                time = 100 + i / 30 })
            local _, np = WeatherEngine._particles()
            if np > maxN then maxN = np end
        end
        local P, np = WeatherEngine._particles()
        for i = 1, np do
            local p = P[i]
            if p.hg ~= p.hg or p.lx ~= p.lx then ok = false end
        end
        t:truthy("2 min de neve com câmera andando: sem NaN", ok)
        t:truthy("2 min de neve: pico ≤ preset+folhas (" .. maxN .. ")",
            maxN <= WeatherEngine.PRESETS.frost.count + 28)
    end

    -- 4. multiply-only (tempestade + raio)
    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(2)
        frame(2)
        WeatherEngine.setIntensityOverride(1)
        WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5, time = 500 })
        -- (o 1º update pode já ter disparado um raio; 1.5 s depois ele acabou
        -- e o próximo só vem ≥5 s depois — o ambiente medido é só tempestade)
        WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5, time = 501.5 })
        local amb = { 0.67, 0.69, 0.86 }
        local darkest = 1
        local stormOnly = WeatherEngine.modulateAmbient(amb)
        local s1, s2, s3 = stormOnly[1], stormOnly[2], stormOnly[3]
        WeatherEngine.strike(0.5)
        local over, darker = false, false
        for i = 0, 30 do
            WeatherEngine.update(1 / 60, { biomeId = "highlands", camZ = 5.5,
                time = 501.5 + i / 60 })
            local m = WeatherEngine.modulateAmbient(amb)
            for k = 1, 3 do if m[k] > 1 + 1e-6 then over = true end end
            if m[1] < s1 - 1e-6 or m[2] < s2 - 1e-6 or m[3] < s3 - 1e-6 then darker = true end
            darkest = math.min(darkest, m[1])
        end
        t:falsy("clarão nunca passa de 1 (multiply-only)", over)
        t:falsy("clarão nunca escurece além da tempestade", darker)
        t:truthy("tempestade escurece o ambiente", s1 < amb[1])
        WeatherEngine.setIntensityOverride(nil)
    end

    -- 5. fotossensibilidade
    do
        local edges, prev, maxPerSec = {}, 0, 0
        for i = 0, 120 do
            local f = WeatherEngine._flashAt(i / 120)
            if f > 0.5 and prev <= 0.5 then edges[#edges + 1] = i / 120 end
            prev = f
        end
        t:truthy("um raio acende ≤3 vezes no 1º segundo (" .. #edges .. ")", #edges <= 3)
        WorldRoad.clearCache()
        WorldRoad.setBiome(2)
        frame(2)
        WeatherEngine.setIntensityOverride(1)
        local times, was = {}, false
        for i = 1, 30 * 120 do
            WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5,
                time = 1000 + i / 30 })
            local now = WeatherEngine.isStriking()
            if now and not was then times[#times + 1] = i / 30 end
            was = now
        end
        local minGap = math.huge
        for i = 2, #times do minGap = math.min(minGap, times[i] - times[i - 1]) end
        t:truthy("tempestade cheia gera raios (" .. #times .. " em 2 min)", #times >= 4)
        t:truthy("≥5 s entre raios (mín " .. string.format("%.1f", minGap) .. ")", minGap >= 5)
        WeatherEngine.setIntensityOverride(nil)
    end

    -- 6. reducedMotion
    do
        _G.gameSettings = { reducedMotion = true }
        WorldRoad.clearCache()
        WorldRoad.setBiome(2)
        frame(2)
        WeatherEngine.setIntensityOverride(1)
        local any = false
        for i = 1, 30 * 40 do
            WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5,
                time = 2000 + i / 30 })
            if WeatherEngine.isStriking() or WeatherEngine.flash() > 0 then any = true end
        end
        frame(2)
        local _, np = WeatherEngine._particles()
        t:falsy("reducedMotion: nenhum raio/clarão em 40 s de tempestade", any)
        t:truthy("reducedMotion: densidade cortada (" .. np .. ")",
            np <= WeatherEngine.PRESETS.highlands.count * 0.4)
        WeatherEngine.setIntensityOverride(nil)
        _G.gameSettings = { reducedMotion = false }
    end

    -- 7. troca de bioma: o clima velho some sozinho
    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(4)
        for _ = 1, 10 do frame(4) end
        WeatherEngine.update(1 / 30, { biomeId = "abyss", camZ = 5.5, time = 3000 })
        local P0, n0 = WeatherEngine._particles()
        local snowLeft0 = 0
        for i = 1, n0 do if P0[i].pr == WeatherEngine.PRESETS.frost then snowLeft0 = snowLeft0 + 1 end end
        t:truthy("logo após a troca a neve ainda está no ar (sem pop)", snowLeft0 > 50)
        for i = 1, 30 * 60 do
            WeatherEngine.update(1 / 30, { biomeId = "abyss", camZ = 5.5, time = 3000 + i / 30 })
        end
        local P, np = WeatherEngine._particles()
        local snowLeft, ash = 0, 0
        for i = 1, np do
            if P[i].pr == WeatherEngine.PRESETS.frost then snowLeft = snowLeft + 1 end
            if P[i].pr == WeatherEngine.PRESETS.abyss then ash = ash + 1 end
        end
        t:eq("60 s depois a neve acabou", snowLeft, 0)
        t:truthy("e a cinza do abismo chegou (" .. ash .. ")", ash > 50)
    end

    -- 8. fonte
    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local eng = love.filesystem.read("engine/WeatherEngine.lua") or ""
        t:truthy("WorldRoad: flush do clima DENTRO da fatia da grama",
            src:find("drawGrass%(g, x, w, camZ, relLow, grassRel%)%s*\n%s*grassRel = relLow[^\n]*\n[^\n]*\n[^\n]*\n%s*WeatherEngine%.flushTo%(relLow%)") ~= nil)
        t:truthy("WorldRoad: clima além da crista antes do domo",
            src:find("WeatherEngine%.flushTo%(REL_CREST%)%s*\n%s*_profMark%('castle'%)%s*\n%s*drawDome") ~= nil)
        t:truthy("WorldRoad: raio entre nuvens e montanhas da frente",
            src:find("WeatherEngine%.drawSky%(g, x, w%)%s*\n%s*drawMountainsFront") ~= nil)
        t:falsy("WeatherEngine não usa stencil", eng:find("love.graphics.stencil", 1, true) ~= nil)
    end

    WorldRoad.clearCache()
    WeatherEngine.reset()
    _G.gameSettings = savedSettings
    return t:done()
end

return M
