local TK = require("tools.testkit")
local MusicCues = require("engine.MusicCues")
local CeilingDebris = require("engine.CeilingDebris")
local MR = require("src.systems.MusicReact")
local MD = require("src.systems.MusicDirector")

local M = {}

local function engineCases(t)
    local data = { duration = 10, cues = {
        { t = 1.0, kind = "hit", power = 0.5 },
        { t = 2.0, kind = "drop", power = 0.9 },
        { t = 3.5, kind = "hit", power = 0.4 },
        { t = 9.95, kind = "hit", power = 0.6 },
    } }
    local tr = MusicCues.new(data)
    local got = {}
    local function fire(c, late) got[#got + 1] = { t = c.t, late = late } end
    t:eq("primeira leitura so posiciona", tr:update(0.9, fire), 0)
    local pos = 0.9
    while pos < 4 do
        pos = pos + 1 / 60
        tr:update(pos, fire)
    end
    t:eq("tres cues ate 4 s", #got, 3)
    t:truthy("ordem certa", got[1] and got[1].t == 1.0 and got[2].t == 2.0 and got[3].t == 3.5)
    local maxLate = 0
    for _, g in ipairs(got) do maxLate = math.max(maxLate, g.late) end
    t:truthy("disparo no quadro do cue (atraso <= 1 quadro)", maxLate <= 1 / 60 + 1e-6)

    got = {}
    tr = MusicCues.new(data)
    tr:update(9.9, fire)
    tr:update(9.96, fire)
    t:eq("cue da cauda dispara antes da volta", #got, 1)
    tr:update(0.02, fire)
    t:eq("volta do loop nao duplica nem rajada", #got, 1)
    pos = 0.02
    while pos < 2.1 do
        pos = pos + 1 / 60
        tr:update(pos, fire)
    end
    t:eq("depois da volta os cues recomecam do inicio", #got, 3)

    got = {}
    tr = MusicCues.new(data)
    tr:update(0.5, fire)
    tr:update(3.9, fire)
    t:eq("salto (pausa/foco) nao gera rajada", #got, 0)
    tr:update(3.92, fire)
    t:eq("depois do salto segue mudo ate o proximo cue", #got, 0)

    got = {}
    tr = MusicCues.new(data)
    tr:update(9.0, fire)
    tr:update(1.3, fire)
    t:eq("volta tardia nao dispara cue velho", #got, 0)
end

local function fakeWorld()
    local st = { pos = 0, code = "musicBossCarrionKing", shakes = {}, lights = {}, breaths = 0 }
    MR.codeProbe = function() return st.code end
    MR.positionProbe = function() return st.pos end
    MR.shakeFn = function(i, d) st.shakes[#st.shakes + 1] = { at = st.clock or 0, i = i, d = d } end
    MR.lightFn = function(k, d) st.lights[#st.lights + 1] = k end
    MR.breathFn = function() st.breaths = st.breaths + 1; return true end
    return st
end

local function run(st, secs, ctx)
    local dt = 1 / 60
    local n = math.floor(secs / dt + 0.5)
    for _ = 1, n do
        st.clock = (st.clock or 0) + dt
        st.pos = st.pos + dt
        if st.pos >= st.dur then st.pos = st.pos - st.dur end
        MR.update(dt, ctx)
    end
end

local function reactCases(t)
    local saved = _G.gameSettings
    local data = MR.cuesFor("carrion_king")
    t:truthy("cues do Rei-Carnica carregam", data and #data.cues > 0)
    local ctx = { fighting = true, bossId = "carrion_king", hall = 1 }

    _G.gameSettings = { musicReact = true, reducedMotion = false, screenshake = 1 }
    MR.reset(); MR.resetStats()
    local st = fakeWorld()
    st.dur = data.duration
    run(st, data.duration, ctx)
    local s = MR.stats()
    local nHit, nDrop = 0, 0
    for _, c in ipairs(data.cues) do
        if c.kind == "hit" then nHit = nHit + 1 elseif c.kind == "drop" then nDrop = nDrop + 1 end
    end
    t:truthy("todos os hits da faixa dispararam (" .. s.hit .. "/" .. nHit .. ")", s.hit >= nHit - 1)
    t:eq("drops disparados", s.drop, nDrop)
    t:truthy("tremor aconteceu", #st.shakes > 0)
    t:truthy("detritos cairam", s.debris > 0)
    t:truthy("chefe reagiu no drop", st.breaths > 0)
    local minGap, busy, maxI = math.huge, 0, 0
    for i, sh in ipairs(st.shakes) do
        busy = busy + sh.d
        maxI = math.max(maxI, sh.i)
        if i > 1 then minGap = math.min(minGap, sh.at - st.shakes[i - 1].at) end
    end
    t:truthy(string.format("tremor com teto baixo (maior %.2f px)", maxI), maxI <= 3.5)
    t:truthy(string.format("cooldown impede tremor continuo (menor intervalo %.2fs)", minGap),
        minGap >= 0.34)
    t:truthy(string.format("tremor ocupa menos de 1/3 da faixa (%.0f%%)", busy / data.duration * 100),
        busy / data.duration < 0.34)
    t:truthy("pool de detritos tem teto", CeilingDebris.count() <= CeilingDebris.MAX)

    MR.reset(); MR.resetStats()
    st = fakeWorld(); st.dur = data.duration
    run(st, 20, { fighting = false, bossId = "carrion_king", hall = 1 })
    t:eq("fora da luta do chefe nada dispara", MR.stats().hit + MR.stats().drop, 0)
    t:falsy("inativo fora da luta", MR.isActive())

    MR.reset(); MR.resetStats()
    st = fakeWorld(); st.dur = data.duration; st.code = "musicAct1"
    run(st, 20, ctx)
    t:eq("faixa que nao e de chefe nao reage", MR.stats().hit, 0)

    _G.gameSettings = { musicReact = false }
    MR.reset(); MR.resetStats()
    st = fakeWorld(); st.dur = data.duration
    run(st, 20, ctx)
    t:eq("opcao desligada: nada acontece", MR.stats().hit + MR.stats().light, 0)

    _G.gameSettings = { musicReact = true, reducedMotion = true }
    MR.reset(); MR.resetStats()
    st = fakeWorld(); st.dur = data.duration
    run(st, data.duration, ctx)
    t:eq("reducedMotion: zero tremor", #st.shakes, 0)
    t:eq("reducedMotion: zero detrito", MR.stats().debris, 0)
    t:eq("reducedMotion: chefe parado", st.breaths, 0)
    local maxK = 0
    for _, k in ipairs(st.lights) do maxK = math.max(maxK, k) end
    t:truthy(string.format("reducedMotion: luz segue, bem fraca (%.2f)", maxK), #st.lights > 0 and maxK <= 0.3)

    _G.gameSettings = { musicReact = true }
    MR.reset(); MR.resetStats()
    st = fakeWorld(); st.dur = data.duration
    run(st, 3, ctx)
    local before = MR.stats().hit + MR.stats().drop
    st.pos = st.pos + 20
    run(st, 0.05, ctx)
    t:eq("pausa/foco perdido: salto nao gera rajada", MR.stats().hit + MR.stats().drop, before)

    _G.gameSettings = saved
    MR.codeProbe, MR.positionProbe, MR.shakeFn, MR.lightFn, MR.breathFn = nil, nil, nil, nil, nil
    MR.reset()
end

local function coverageCases(t)
    for id, code in pairs(MD.BOSS_TRACKS) do
        if love.filesystem.getInfo("audio/music/" .. MD.bossFile(id)) then
            local key = MR.cueKeyFor(code)
            local data = MR.cuesFor(key)
            t:truthy("faixa aprovada de " .. id .. " tem cues", data ~= nil and #data.cues > 0)
            if data then
                local sorted, inside = true, true
                for i, c in ipairs(data.cues) do
                    if i > 1 and c.t < data.cues[i - 1].t then sorted = false end
                    if c.t < 0 or c.t > data.duration then inside = false end
                end
                t:truthy(id .. ": cues em ordem e dentro da faixa", sorted and inside)
            end
        end
    end
    for _, code in ipairs({ "musicBoss", "musicBossEclipse" }) do
        local key = MR.cueKeyFor(code)
        t:truthy("faixa generica " .. code .. " tem cues", MR.cuesFor(key) ~= nil)
    end
end

function M.run()
    local t = TK.new("music_react")
    engineCases(t)
    reactCases(t)
    coverageCases(t)
    return TK.verdict(t.fail == 0)
end

return M
