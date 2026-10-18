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
            if i > 1 and i <= WeatherEngine.built()
               and P[i - 1].sortRel < p.sortRel then sorted = false end
        end
        t:truthy("bioma " .. bio .. ": nenhum campo NaN/inf", finite)
        t:truthy("bioma " .. bio .. ": lote ordenado do fundo pra frente", sorted)
        t:eq("bioma " .. bio .. ": todas as montadas foram desenhadas", WeatherEngine.undrawn(), 0)
        WeatherEngine.emitLeaf(0.1, WorldRoad._camZ + 3, 0.6, 0.3, { 0.5, 0.6, 0.2 })
        frame(bio)
        local P2, n2 = WeatherEngine._particles()
        local ok2 = true
        for i = 2, WeatherEngine.built() do
            if P2[i - 1].sortRel < P2[i].sortRel then ok2 = false end
        end
        t:truthy("bioma " .. bio .. ": folha emitida entra ordenada no frame seguinte", ok2)
        t:truthy("bioma " .. bio .. ": intercalado em várias fatias (" ..
            WeatherEngine.stats.flushes .. ")", WeatherEngine.stats.flushes >= 3)
    end

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

    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(2)
        frame(2)
        WeatherEngine.setIntensityOverride(1)
        WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5, time = 500 })
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

    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(4)
        for _ = 1, 10 do frame(4) end
        WeatherEngine.update(1 / 30, { biomeId = "abyss", camZ = 5.5, time = 3000, progress = 1 })
        local P0, n0 = WeatherEngine._particles()
        local snowLeft0 = 0
        for i = 1, n0 do if P0[i].pr == WeatherEngine.PRESETS.frost then snowLeft0 = snowLeft0 + 1 end end
        t:truthy("logo após a troca a neve ainda está no ar (sem pop)", snowLeft0 > 50)
        for i = 1, 30 * 7 do
            WeatherEngine.update(1 / 30, { biomeId = "abyss", camZ = 5.5, time = 3000 + i / 30, progress = 1 })
        end
        local P, np = WeatherEngine._particles()
        local snowLeft, ash = 0, 0
        for i = 1, np do
            if P[i].pr == WeatherEngine.PRESETS.frost then snowLeft = snowLeft + 1 end
            if P[i].pr == WeatherEngine.PRESETS.abyss then ash = ash + 1 end
        end
        t:eq("7 s depois a neve aposentada acabou (fade garantido)", snowLeft, 0)
        t:truthy("e a cinza do abismo chegou (" .. ash .. ")", ash > 50)
    end

    do
        WorldRoad.clearCache()
        WorldRoad.setBiome(2)
        frame(2)
        t:eq("unidade = 1 px de tela até 1440p", WeatherEngine.stats.unit, 1)
        for id, pr in pairs(WeatherEngine.PRESETS) do
            if pr.kind ~= "rain" then
                local px1080 = math.floor(pr.size * (1028 / 1000) + 0.5)
                t:truthy(id .. ": partícula pequena (" .. px1080 .. " px ≤ 3 em 1080p)", px1080 <= 3)
            else
                t:truthy(id .. ": chuva translúcida (alpha " .. pr.alpha .. " ≤ 0.65)", pr.alpha <= 0.65)
            end
        end
    end

    do
        local IF = WeatherEngine.intensityFor
        t:truthy("começo do ato é calmo (" .. IF(0) .. ")", IF(0) <= 0.15)
        t:near("porta do castelo = intensidade cheia", IF(1), 1, 1e-6)
        local mono = true
        for k = 1, 20 do if IF(k / 20) < IF((k - 1) / 20) then mono = false end end
        t:truthy("curva cresce sempre (monotônica)", mono)
        local function settle(prog, secs)
            for i = 1, secs * 30 do
                WeatherEngine.update(1 / 30, { biomeId = "frost", camZ = 5.5,
                    time = 4000 + i / 30, progress = prog, luma = 0.9 })
            end
            local P, np = WeatherEngine._particles()
            local main = 0
            for i = 1, np do if not P[i].ff and not P[i].rise then main = main + 1 end end
            return main
        end
        WorldRoad.clearCache(); WorldRoad.setBiome(4); frame(4)
        local n0 = settle(0, 40)
        local n1 = settle(1, 40)
        t:truthy(string.format("começo %d ≪ castelo %d flocos", n0, n1), n0 < n1 * 0.25)
        WorldRoad.clearCache(); WorldRoad.setBiome(2); frame(2)
        local any = false
        for i = 1, 30 * 60 do
            WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5,
                time = 5000 + i / 30, progress = 0.3, luma = 0.6 })
            if WeatherEngine.isStriking() then any = true end
        end
        t:falsy("sem raio na primeira metade do ato", any)
        t:eq("sem tempestade na primeira metade", WeatherEngine.storm(), 0)
    end

    do
        local function ffCount(luma)
            WorldRoad.clearCache(); WorldRoad.setBiome(1); frame(1)
            for i = 1, 30 * 40 do
                WeatherEngine.update(1 / 30, { biomeId = "fields", camZ = 5.5,
                    time = 6000 + i / 30, progress = 0.5, luma = luma })
            end
            local P, np = WeatherEngine._particles()
            local n = 0
            for i = 1, np do if P[i].ff then n = n + 1 end end
            return n
        end
        local day, nightN = ffCount(0.95), ffCount(0.45)
        t:eq("dia claro: nenhum vagalume", day, 0)
        t:truthy("noite: vagalumes acesos (" .. nightN .. ")", nightN >= 10)
        local glowMax, glowMin = 0, 1
        for _, style in ipairs({ "wander", "sparkle", "wisp", "mote" }) do
            for k = 0, 40 do
                local pp = { period = 3, ph = k / 40, life = 5, life0 = 10 }
                local g = WeatherEngine._ffGlow(pp, style)
                glowMax = math.max(glowMax, g); glowMin = math.min(glowMin, g)
            end
        end
        t:truthy(string.format("vagalume: brilho em [0,1] nos 4 estilos (%.2f..%.2f)",
            glowMin, glowMax), glowMax <= 1 and glowMin >= 0)
    end

    do
        local WA = require("src.systems.WeatherAudio")
        local fakeNow = 0
        local realGet = love.timer.getTime
        love.timer.getTime = function() return fakeNow end
        local started, gains = {}, {}
        local function newSrc(code)
            local s = { code = code, t0 = fakeNow, off = 0, pitch = 1, stopped = false }
            function s:getDuration() return 6 end
            function s:tell() return (fakeNow - self.t0) * self.pitch + self.off end
            function s:isPlaying() return not self.stopped and self:tell() < 6 end
            function s:seek(o) self.off = o end
            function s:getPitch() return self.pitch end
            function s:stop() self.stopped = true end
            return s
        end
        local saved = _G.audioSystem
        _G.audioSystem = {
            play = function(_, code, opts)
                local s = newSrc(code)
                s.pitch = (opts and opts.pitch) or 1
                started[#started + 1] = code
                return s
            end,
            setInstanceGain = function(_, code, src, g)
                if g then gains[#gains + 1] = g end
            end,
        }
        WA._reset()
        local st = { biomeId = "highlands", intensity = 1, storm = 1, night = 0.5,
                     rain = 1, gust = 0.8 }
        for i = 1, 30 * 120 do
            fakeNow = i / 30
            WA.update(1 / 30, st)
        end
        local byFam, repeatOk, nBeds = {}, true, 0
        for _, c in ipairs(started) do
            local fam = c:match("^wx:(rain%-heavy)") or c:match("^wx:(rain%-light)")
            if fam then
                nBeds = nBeds + 1
                if byFam[fam] == c then repeatOk = false end
                byFam[fam] = c
            end
        end
        t:truthy("chuva: camas rodaram várias vozes em 2 min (" .. nBeds .. ")", nBeds >= 10)
        t:truthy("chuva: nunca a mesma variante duas vezes seguidas", repeatOk)
        local maxG = 0
        for _, g in ipairs(gains) do maxG = math.max(maxG, g) end
        t:truthy(string.format("ganho de voz ≤ 1 (%.2f)", maxG), maxG <= 1 + 1e-6)
        local prev, okT = nil, true
        for k = 1, 30 do
            local name = WA.thunder((k % 7) / 7)
            if name == prev then okT = false end
            prev = name
        end
        t:truthy("trovão nunca repete a variante anterior", okT)
        local beds = WA._state()
        fakeNow = fakeNow + 1
        for _ = 1, 120 do WA.watchdog(1 / 60) end
        local alive = 0
        for _, bed in pairs(beds) do alive = alive + #bed.voices end
        t:eq("watchdog: sem update do mundo, nenhuma voz de cama viva", alive, 0)
        WA._reset()
        _G.audioSystem = saved
        love.timer.getTime = realGet
        local missing = {}
        local function check(n)
            if not love.filesystem.getInfo("audio/sfx/weather/" .. n .. ".mp3") then
                missing[#missing + 1] = n
            end
        end
        for _, cfg in pairs(WA.BIOMES) do
            for _, b in ipairs(cfg.beds) do for _, v in ipairs(b.vars) do check(v) end end
            for _, o in ipairs(cfg.ones) do for _, v in ipairs(o.vars) do check(v) end end
        end
        for _, list in pairs(WA.THUNDER) do for _, v in ipairs(list) do check(v) end end
        for _, v in ipairs(WA.FIREFLY) do check(v) end
        t:eq("todo som citado existe no disco (" .. table.concat(missing, ",") .. ")", #missing, 0)
    end

    do
        local PA = require("src.systems.PlaceAudio")
        local WA = require("src.systems.WeatherAudio")
        t:eq("estrada (batalha)", PA.placeFor("playing", {}), "road")
        t:eq("salão do chefe", PA.placeFor("playing", { bossRoom = true }), "boss")
        t:eq("mapa/encruzilhada", PA.placeFor("mapSelection", {}), "road")
        t:eq("loja", PA.placeFor("cardReward", { nodeType = "shop" }), "shop")
        t:eq("recompensa", PA.placeFor("cardReward", { nodeType = "battle" }), "reward")
        t:eq("cash out", PA.placeFor("roundEval", {}), "reward")
        t:eq("descanso", PA.placeFor("rest", { restMode = "choose" }), "rest")
        t:eq("forja", PA.placeFor("rest", { restMode = "forge" }), "forge")
        t:eq("evento", PA.placeFor("event", {}), "event")
        t:eq("menu = silêncio", PA.placeFor("menu", {}), nil)

        local fakeNow = 0
        local realGet = love.timer.getTime
        love.timer.getTime = function() return fakeNow end
        local playing = {}
        local gainOf = {}
        local function newSrc(code)
            local s = { code = code, t0 = fakeNow, off = 0, pitch = 1, stopped = false }
            function s:getDuration() return 6 end
            function s:tell() return (fakeNow - self.t0) * self.pitch + self.off end
            function s:isPlaying() return not self.stopped and self:tell() < 6 end
            function s:seek(o) self.off = o end
            function s:getPitch() return self.pitch end
            function s:stop() self.stopped = true end
            return s
        end
        local saved = _G.audioSystem
        local started = {}
        _G.audioSystem = {
            play = function(_, code, opts)
                local s = newSrc(code)
                s.pitch = (opts and opts.pitch) or 1
                started[#started + 1] = code
                playing[s] = code
                gainOf[s] = opts and opts.gain or 1
                return s
            end,
            setInstanceGain = function(_, code, src, g) gainOf[src] = g or 1 end,
        }
        WA._reset(); PA._reset()
        local roadSt = { biomeId = "highlands", intensity = 1, storm = 0.5, night = 0.5,
                         rain = 1, gust = 0.8 }
        local function audible(prefix)
            local sum = 0
            for s, code in pairs(playing) do
                if s:isPlaying() and code:sub(1, #prefix) == prefix then
                    sum = sum + (gainOf[s] or 0)
                end
            end
            return sum
        end
        local function run(secs, state, ctx, roadTicks)
            for _ = 1, math.floor(secs * 30) do
                fakeNow = fakeNow + 1 / 30
                PA.apply(1 / 30, state, ctx)
                if roadTicks then WA.update(1 / 30, roadSt) end
                WA.watchdog(1 / 30)
            end
        end
        run(6, "playing", {}, true)
        t:truthy(string.format("na estrada a chuva soa (%.2f)", audible("wx:rain")), audible("wx:rain") > 0.3)
        local n0 = #started
        run(1.5, "cardReward", { nodeType = "shop" }, true)
        t:truthy(string.format("loja: chuva da estrada calou em 1.5 s (%.3f)", audible("wx:rain")),
            audible("wx:rain") < 0.02)
        t:truthy(string.format("loja: cama da loja tocando (%.2f)", audible("pl:shop-room")),
            audible("pl:shop-room") > 0.3)
        local bell = false
        for k = n0 + 1, #started do if started[k]:find("shop%-bell") then bell = true end end
        t:truthy("loja: sino da porta na entrada", bell)
        run(3, "mapSelection", {}, true)
        t:truthy("de volta à estrada: cama da loja sumiu", audible("pl:shop-room") < 0.02)
        t:truthy("de volta à estrada: chuva voltou", audible("wx:rain") > 0.3)
        for _, c in ipairs({ { "rest", { restMode = "choose" }, "pl:rest-camp" },
                             { "rest", { restMode = "forge" }, "pl:forge-fire" },
                             { "event", {}, "pl:event-drone" },
                             { "playing", { bossRoom = true }, "pl:boss-room" } }) do
            run(2, c[1], c[2], false)
            t:truthy(string.format("%s/%s: cama %s (%.2f) e estrada calada", c[1],
                tostring(c[2].restMode or c[2].bossRoom), c[3], audible(c[3])),
                audible(c[3]) > 0.2 and audible("wx:rain") < 0.02)
        end
        run(2, "menu", {}, false)
        t:truthy(string.format("menu: nenhum ambiente (%.3f)", audible("pl:") + audible("wx:")),
            audible("pl:") + audible("wx:") < 0.02)
        local prevFam, rep = {}, false
        for _, c in ipairs(started) do
            local fam = c:match("^pl:(.-)%-%d+$")
            if fam then
                if prevFam[fam] == c and c ~= "pl:boss-room-1" and c ~= "pl:shop-creak-1"
                   and c ~= "pl:bellows-1" and c ~= "pl:paper-1" and c ~= "pl:boss-rumble-1" then
                    rep = true
                end
                prevFam[fam] = c
            end
        end
        t:falsy("lugares: variante nunca repete seguida (famílias com 2+)", rep)
        PA._reset(); WA._reset()
        _G.audioSystem = saved
        love.timer.getTime = realGet
        local missing = {}
        for _, cfg in pairs(PA.PLACES) do
            local defs = {}
            for _, b in ipairs(cfg.beds) do defs[#defs + 1] = b end
            for _, o in ipairs(cfg.ones) do defs[#defs + 1] = o end
            if cfg.enter then defs[#defs + 1] = cfg.enter end
            for _, d in ipairs(defs) do
                local dir = d.prefix == "pl:" and "audio/sfx/place/" or "audio/sfx/weather/"
                for _, v in ipairs(d.vars) do
                    if not love.filesystem.getInfo(dir .. v .. ".mp3") then missing[#missing + 1] = v end
                end
            end
        end
        t:eq("lugares: todo som citado existe (" .. table.concat(missing, ",") .. ")", #missing, 0)
    end

    do
        local Config = require("src.core.Config")
        local A = Config.Audio
        t:truthy("AMBIENT_VOLUME é baixo (" .. tostring(A.AMBIENT_VOLUME) .. " ≤ 0.12)",
            A.AMBIENT_VOLUME and A.AMBIENT_VOLUME <= 0.12)
        local function db(x) return 20 * math.log10(x) end
        local bed = -22 + db(A.WEATHER_VOLUME * A.AMBIENT_VOLUME * 0.55)
        local musicPeak = -3.5 + db(0.6 * 0.3)
        t:truthy(string.format("cama do clima %.1f dB sob o pico da música (≥ 28)",
            musicPeak - bed), musicPeak - bed >= 28)
        local thunder = -2 + db(A.WEATHER_VOLUME * A.AMBIENT_VOLUME * 0.85)
        t:truthy(string.format("trovão (pico) %.1f dB sob o pico da música (≥ 5)",
            musicPeak - thunder), musicPeak - thunder >= 5)
        for _, f in ipairs({ "src/systems/WeatherAudio.lua", "src/systems/PlaceAudio.lua" }) do
            local src = love.filesystem.read(f) or ""
            t:truthy(f .. ": registra no grupo ambient", src:find('group = "ambient"', 1, true) ~= nil)
            t:truthy(f .. ": usa AMBIENT_VOLUME", src:find("AMBIENT_VOLUME", 1, true) ~= nil)
        end
        local sm = love.filesystem.read("components/SettingsMenu.lua") or ""
        t:truthy("Configurações → Áudio tem o slider Ambiente",
            sm:find('volRow("ambient", "settings.ambient")', 1, true) ~= nil)
        local I18n = require("src.i18n.I18n")
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            local ok, tbl = pcall(require, "src.i18n.locales." .. loc)
            t:truthy(loc .. ": settings.ambient traduzido",
                ok and tbl and tbl.settings and tbl.settings.ambient ~= nil)
        end
        local AM = require("engine.AudioManager")
        t:truthy("AudioManager tem setAmbientVolume", AM.setAmbientVolume ~= nil)
    end

    do
        local SceneGrade = require("engine.SceneGrade")
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 3 do frame(1) end
        t:truthy("véu de profundidade desenhado por fatia (" .. tostring(WeatherEngine.stats.veilBands) .. ")",
            (WeatherEngine.stats.veilBands or 0) >= 3)
        t:truthy("névoa baixa desenhada na base das montanhas (" .. tostring(WeatherEngine.stats.lowFogBands) .. ")",
            (WeatherEngine.stats.lowFogBands or 0) >= 1)
        SceneGrade.begin("fields", 1, nil, 1, { 0.8, 0.8, 0.8 })
        t:truthy("véu mais forte no horizonte que na base",
            WeatherEngine._veilAlphaAt(0) > WeatherEngine._veilAlphaAt(1))
        t:truthy("véu nunca passa de 0,5", WeatherEngine._veilAlphaAt(0) <= 0.5)

        WeatherEngine.disabled = true
        frame(1)
        t:truthy("clima desligado ainda desenha o véu de profundidade", (WeatherEngine.stats.veilBands or 0) >= 3)
        WeatherEngine.disabled = false

        do
            local Wv, Hv = love.graphics.getDimensions()
            local function sideShot(k)
                local saved = WeatherEngine.VEIL_K
                WeatherEngine.VEIL_K = k
                local cv = love.graphics.newCanvas(Wv, Hv)
                love.graphics.setCanvas(cv)
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, 52, Wv, Hv - 52, 1)
                love.graphics.setCanvas()
                WeatherEngine.VEIL_K = saved
                return cv:newImageData()
            end
            local on, off = sideShot(0.55), sideShot(0)
            local yApex = math.floor(52 + (Hv - 52) * 0.40)
            local same = true
            for y = yApex, yApex + 12 do
                for _, x in ipairs({ 2, 6, Wv - 3, Wv - 7 }) do
                    local r1, g1, b1 = on:getPixel(x, y)
                    local r2, g2, b2 = off:getPixel(x, y)
                    if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.01 then same = false end
                end
            end
            t:truthy("véu segue a curva do domo (não pinta o céu nas laterais)", same)
        end

        local W2, H2 = love.graphics.getDimensions()
        local function lowFogShot(tm, rm)
            _G.gameSettings = { reducedMotion = rm }
            local cv = love.graphics.newCanvas(W2, H2)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.2, 0.2, 0.2, 1)
            WeatherEngine.update(0, { biomeId = "fields", camZ = 5.5, time = tm })
            SceneGrade.begin("fields", 0.5, nil, 1, { 0.8, 0.8, 0.8 })
            WeatherEngine.drawLowFog(0, 200, W2, 60, { alpha = 0.4, height = 0.1, drift = 0.02 }, 1)
            love.graphics.setCanvas()
            return cv:newImageData()
        end
        local a1 = lowFogShot(100, false)
        local a2 = lowFogShot(130, false)
        local r0 = select(1, a1:getPixel(10, 100))
        local inside = false
        local moved = false
        for x = 0, W2 - 1, 7 do
            local r, _, _, _ = a1:getPixel(x, 250)
            if math.abs(r - 0.2) > 0.01 then inside = true end
            local rb = a2:getPixel(x, 250)
            if math.abs(r - rb) > 0.005 then moved = true end
        end
        t:truthy("névoa baixa: pinta dentro da faixa", inside)
        t:truthy("névoa baixa: fora da faixa intacto", math.abs(r0 - 0.2) < 0.005)
        t:truthy("névoa baixa: deriva com o tempo", moved)
        local b1 = lowFogShot(100, true)
        local b2 = lowFogShot(130, true)
        t:truthy("reducedMotion: névoa baixa parada (quadros idênticos)", b1:getString() == b2:getString())
        _G.gameSettings = { reducedMotion = false }

        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local pm = src:find("drawMountains(g, x, w, WorldRoad._camZ)", 1, true)
        local pf = pm and src:find("WeatherEngine.drawLowFog(", pm, true)
        local pmf = src:find("drawMountainsFront(g, x, w, WorldRoad._camZ)", 1, true)
        t:truthy("WorldRoad: névoa baixa entre o fundo e a frente das montanhas",
            pm ~= nil and pf ~= nil and pmf ~= nil and pm < pf and pf < pmf)
    end

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local eng = love.filesystem.read("engine/WeatherEngine.lua") or ""
        t:truthy("WorldRoad: flush do clima DENTRO da fatia da grama",
            src:find("drawGrass%(g, x, w, camZ, relLow, grassRel%)%s*\n%s*grassRel = relLow[^\n]*\n%s*WeatherEngine%.flushTo%(relLow%)") ~= nil)
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
