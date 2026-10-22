local TK = require("tools.testkit")

local M = {}

M.MEAN_DB = { -36, -15 }
M.PEAK_MAX = 0.5
M.DUR = { 0.35, 3.0 }

M.BEATS = {
    andar = { stop = true, step = "steps" },
    investida = { skid = true, stop = true },
    brotar = { rise = true, stop = true },
    acordar = { wake = true, land = "anchor", stop = true },
    mergulho = { start = true, stop = true },
    condensar = { start = true, form = true, stop = true },
    flanco = { start = true, stop = true, hop = "hops" },
    montar = { mid = true, stop = true },
}

local function roster()
    return require("tools.test_enemy_entrances").roster()
end

function M.measure(path)
    local ok, sd = pcall(love.sound.newSoundData, path)
    if not ok or not sd then return nil, tostring(sd) end
    local n, rate, ch = sd:getSampleCount(), sd:getSampleRate(), sd:getChannelCount()
    local sumSq, peak = 0, 0
    for s = 0, n - 1 do
        local v = 0
        for c = 1, ch do
            local a = math.abs(sd:getSample(s, c))
            if a > v then v = a end
        end
        sumSq = sumSq + v * v
        if v > peak then peak = v end
    end
    local rms = n > 0 and math.sqrt(sumSq / n) or 0
    local db = rms > 0 and 20 * math.log10(rms) or -99
    sd:release()
    return { dur = n / rate, rms = rms, db = db, peak = peak }
end

local function knownCode(code, Data, Crow, mainSrc)
    if Data.SOUNDS[code] or Crow.MOMENTS[code] then return true end
    return mainSrc:find("%f[%w_]" .. code .. "%f[^%w_]") ~= nil
end

function M.run()
    local t = TK.new("Sons de entrada por criatura (arquivo proprio, beat real, fallback, volume)")
    local Data = require("src.data.enemy_entrances")
    local Crow = require("src.systems.CrowSfx")
    local mainSrc = love.filesystem.read("main.lua") or ""
    local engineSrc = love.filesystem.read("src/ui/EnemyEntrance.lua") or ""
    local list = roster()
    t:eq("36 criaturas", #list, 36)

    t:truthy("main.lua registra a pasta por scan", mainSrc:find("audio/sfx/entrances", 1, true) ~= nil)
    t:truthy("main.lua usa o prefixo dos dados", mainSrc:find('"' .. Data.SFX_PREFIX .. '"', 1, true) ~= nil)
    t:truthy("main.lua le a pasta dos dados", mainSrc:find((Data.SFX_DIR:gsub("/$", "")), 1, true) ~= nil)

    local files = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(Data.SFX_DIR) or {}) do
        local base = f:match("^(.+)%.mp3$")
        if base then files[base] = false end
    end
    local nFiles = 0
    for _ in pairs(files) do nFiles = nFiles + 1 end
    t:truthy("ha arquivos de entrada no disco", nFiles >= 36)

    for _, r in ipairs(list) do
        local spec = Data.BY_ID[r.id]
        t:truthy(r.id .. ": entrada declarada", spec ~= nil)
        if spec then
            local beats = M.BEATS[spec.kind] or {}
            local own = 0
            for mark, codes in pairs(spec.sfx or {}) do
                local fires = beats[mark]
                if type(fires) == "string" then fires = spec[fires] ~= nil end
                t:truthy(r.id .. ": beat '" .. mark .. "' dispara para o tipo " .. spec.kind, fires)
                t:truthy(r.id .. ": motor conhece o beat '" .. mark .. "'",
                    engineSrc:find('"' .. mark .. '"', 1, true) ~= nil)
                local fallback = false
                for i, code in ipairs(codes) do
                    local base = code:match("^" .. Data.SFX_PREFIX .. "(.+)$")
                    if base then
                        own = own + 1
                        t:eq(r.id .. ": som proprio vem primeiro em '" .. mark .. "'", i, 1)
                        t:truthy(r.id .. ": arquivo " .. base .. ".mp3 existe", files[base] ~= nil)
                        t:truthy(r.id .. ": arquivo " .. base .. " e desta criatura", base:sub(1, #r.id + 1) == r.id .. "_")
                        local fileBeat = base:sub(#r.id + 2)
                        t:truthy(r.id .. ": arquivo " .. base .. " e do beat " .. mark,
                            fileBeat == mark or (mark == "land" and fileBeat == "stop") or (mark == "form" and fileBeat == "stop"))
                        files[base] = true
                    else
                        fallback = true
                        t:truthy(r.id .. ": fallback '" .. code .. "' em '" .. mark .. "' e um codigo conhecido",
                            knownCode(code, Data, Crow, mainSrc))
                    end
                end
                t:truthy(r.id .. ": '" .. mark .. "' tem fallback generico", fallback)
            end
            t:truthy(r.id .. ": ao menos um som proprio", own >= 1)
            if spec.kind == "condensar" and spec.sfx then
                t:falsy(r.id .. ": start e form nao coincidem (som dobrado)", spec.sfx.start and spec.sfx.form and not spec.swarm)
            end
        end
    end

    local bases = {}
    for base in pairs(files) do bases[#bases + 1] = base end
    table.sort(bases)
    local worst = { db = 0, peak = 0 }
    for _, base in ipairs(bases) do
        t:truthy("arquivo " .. base .. " e usado por alguma entrada", files[base])
        local path = Data.SFX_DIR .. base .. ".mp3"
        local bytes = love.filesystem.read(path) or ""
        t:truthy("mp3 de verdade: " .. base, bytes:sub(1, 3) == "ID3" or bytes:byte(1) == 0xFF)
        local m, err = M.measure(path)
        t:truthy("decodifica: " .. base .. (m and "" or (" " .. tostring(err))), m ~= nil)
        if m then
            t:truthy(string.format("%s: duracao %.2fs em [%.2f, %.2f]", base, m.dur, M.DUR[1], M.DUR[2]),
                m.dur >= M.DUR[1] and m.dur <= M.DUR[2])
            t:truthy(string.format("%s: volume medio %.1f dB 6 dB abaixo dos corvos [%d, %d]", base, m.db, M.MEAN_DB[1], M.MEAN_DB[2]),
                m.db >= M.MEAN_DB[1] and m.db <= M.MEAN_DB[2])
            t:truthy(string.format("%s: pico %.3f sem clipping", base, m.peak), m.peak <= M.PEAK_MAX)
            if m.db < worst.db then worst = m end
        end
    end

    local fake = { sources = {}, log = {} }
    function fake:loadSound(code, path, vol) self.sources[code] = { path = path, vol = vol } end
    function fake:play(code, opts) self.log[#self.log + 1] = code end
    function fake:playSound(code) self:play(code) end
    local saved = _G.audioSystem
    _G.audioSystem = fake
    for base in pairs(files) do
        fake:loadSound(Data.SFX_PREFIX .. base, Data.SFX_DIR .. base .. ".mp3", Data.SFX_VOLUME)
    end
    local Sfx = require("src.systems.Sfx")
    t:truthy("Sfx.has enxerga o som proprio registrado", Sfx.has(Data.SFX_PREFIX .. bases[1]))
    t:falsy("Sfx.has nega som proprio ausente", Sfx.has(Data.SFX_PREFIX .. "nao_existe_stop"))
    _G.audioSystem = saved

    return t:done()
end

return M
