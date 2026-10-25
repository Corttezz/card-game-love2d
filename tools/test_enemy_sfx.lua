local TK = require("tools.testkit")

local M = {}

local function recordingAudio()
    local log = {}
    local a = { sources = {}, groups = { master = 1, music = 1, sfx = 1 }, log = log }
    local function fakeSrc()
        return { stop = function() end, isPlaying = function() return false end,
                 setVolume = function() end, setPitch = function() end }
    end
    function a:loadSound(code, path, opts)
        if type(opts) == "number" then opts = { volume = opts } end
        self.sources[code] = { path = path, volume = (opts and opts.volume) or 1 }
        return self.sources[code]
    end
    function a:play(code, opts)
        if not self.sources[code] then return nil end
        log[#log + 1] = { code = code, pitch = opts and opts.pitch }
        return fakeSrc()
    end
    function a:playSound(code) return self:play(code) end
    function a:stop() end
    function a:stopAll() end
    function a:playMusic() end
    function a:stopMusic() end
    function a:fadeOutMusic() end
    return a
end

local function allIds()
    local Enemies = require("src.data.enemies")
    local ids, seen = {}, {}
    for act = 1, 6 do
        for _, kind in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
            for _, id in ipairs(Enemies.ROSTER[act][kind] or {}) do
                if not seen[id] then seen[id] = true; ids[#ids + 1] = { id = id, kind = kind, act = act } end
            end
        end
    end
    return ids
end

local function clear(l)
    for i = #l, 1, -1 do l[i] = nil end
end

local function fakeEnemy(id, health)
    return { spriteId = id, kitId = id, health = health or 100, maxHealth = 100 }
end

function M.run()
    local t = TK.new("vozes dos inimigos: hurt/death proprios, cooldown, sem repetir, imune calado")
    TK.bootstrap()
    TK.seedRng(777)
    love.math.setRandomSeed(777)
    local EnemySfx = require("src.systems.EnemySfx")
    local Data = require("src.data.enemy_sfx")
    local Debug = require("src.core.Debug")

    local now = 0
    local savedAudio, savedNow, savedWarn = _G.audioSystem, EnemySfx.now, Debug.warn
    local warns = {}
    Debug.warn = function(...)
        warns[#warns + 1] = table.concat({ tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)) }, " ")
    end
    EnemySfx.now = function() return now end

    local ok, err = pcall(function()
        EnemySfx.rescan()
        _G.audioSystem = nil
        t:eq("sem audio: hurt nao faz nada", EnemySfx.hurt(fakeEnemy("grave_thrall"), 5), nil)

        local ids = allIds()
        t:eq("roster tem 42 criaturas", #ids, 42)
        local missing = {}
        for _, e in ipairs(ids) do
            local h, d = EnemySfx.files(e.id, "hurt"), EnemySfx.files(e.id, "death")
            if #h < 3 or #d < 1 then missing[#missing + 1] = e.id .. "(" .. #h .. "/" .. #d .. ")" end
        end
        t:check("toda criatura tem 3+ hurt e 1+ death proprios" .. (#missing > 0 and (": " .. table.concat(missing, ", ")) or ""), #missing == 0)

        local badDur = {}
        local checked = 0
        for _, e in ipairs(ids) do
            for _, ev in ipairs({ "hurt", "death" }) do
                for _, f in ipairs(EnemySfx.files(e.id, ev)) do
                    local okD, dec = pcall(love.sound.newDecoder, f.path)
                    local dur = okD and dec:getDuration() or -1
                    if okD and dec.release then dec:release() end
                    checked = checked + 1
                    local lo, hi = 0.2, 0.65
                    if ev == "death" then lo, hi = 0.55, 1.6 end
                    if dur < lo or dur > hi then badDur[#badDur + 1] = f.path .. "=" .. string.format("%.2f", dur) end
                end
            end
        end
        t:check("todos os " .. checked .. " arquivos decodificam com duracao na faixa" .. (#badDur > 0 and (": " .. table.concat(badDur, ", ")) or ""), #badDur == 0)

        local audio = recordingAudio()
        _G.audioSystem = audio
        EnemySfx.rescan()

        local wrong = {}
        for _, e in ipairs(ids) do
            now = now + 10
            local code = EnemySfx.hurt(fakeEnemy(e.id), 4)
            if type(code) ~= "string" or not code:find("^enemyVoice_" .. e.id .. "_hurt") then wrong[#wrong + 1] = e.id .. ":hurt" end
            now = now + 10
            local dc = EnemySfx.death(fakeEnemy(e.id, 0))
            if type(dc) ~= "string" or not dc:find("^enemyVoice_" .. e.id .. "_death") then wrong[#wrong + 1] = e.id .. ":death" end
        end
        t:check("toda criatura resolve hurt e death PROPRIOS pelo scan" .. (#wrong > 0 and (": " .. table.concat(wrong, ", ")) or ""), #wrong == 0)
        t:check("death proprio nunca toca o enemyDeath generico junto", (function()
            for _, e in ipairs(audio.log) do if e.code == "enemyDeath" then return false end end
            return true
        end)())

        local hv = audio.sources["enemyVoice_grave_thrall_hurt1"]
        t:check("voz de hurt registrada abaixo do impacto (0,55)", hv and hv.volume < 0.55)

        clear(audio.log)
        audio.sources.enemyDeath = { path = "audio/sfx/enemy-death.mp3", volume = 0.48 }
        local nWarn = #warns
        now = now + 10
        t:eq("criatura sem arquivos: death cai no enemyDeath", EnemySfx.death(fakeEnemy("nao_existe", 0)), "enemyDeath")
        t:eq("criatura sem arquivos: hurt so deixa o impacto", EnemySfx.hurt(fakeEnemy("nao_existe"), 5), nil)
        now = now + 10
        EnemySfx.death(fakeEnemy("nao_existe", 0))
        EnemySfx.hurt(fakeEnemy("nao_existe"), 5)
        t:eq("Debug.warn uma vez por criatura e evento", #warns - nWarn, 2)
        t:eq("fallback tocou o generico", audio.log[1] and audio.log[1].code, "enemyDeath")

        local g = fakeEnemy("grave_thrall")
        now = now + 10
        t:truthy("1o golpe toca a voz", EnemySfx.hurt(g, 3))
        now = now + 0.1
        t:eq("2o golpe 0,10 s depois: so impacto (cooldown)", EnemySfx.hurt(g, 3), false)
        now = now + 0.09
        t:truthy("golpe 0,19 s depois do 1o volta a ter voz", EnemySfx.hurt(g, 3))
        t:eq("cooldown de hurt e 0,18 s", Data.EVENTS.hurt.cooldown, 0.18)
        now = now - 50
        t:truthy("relogio que volta (stub) nao trava a voz", EnemySfx.hurt(g, 3))
        now = now + 60

        clear(audio.log)
        local prev, twice, pitchOut = nil, nil, nil
        for i = 1, 40 do
            now = now + 0.2
            local code = EnemySfx.hurt(g, 2)
            if code == prev then twice = code end
            prev = code
        end
        for _, e in ipairs(audio.log) do
            if not e.pitch or math.abs(e.pitch - 1) > 0.04 + 1e-9 then pitchOut = e.pitch end
        end
        t:eq("40 golpes espacados: 40 vozes", #audio.log, 40)
        t:falsy("mesma variante nunca duas vezes seguidas", twice)
        t:falsy("pitch dentro de +-4%", pitchOut)
        local seen = {}
        for _, e in ipairs(audio.log) do seen[e.code] = true end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        t:eq("as 3 variantes aparecem", n, 3)

        now = now + 10
        t:eq("tick imune nao toca hurt", EnemySfx.hurt(g, 5, "immune"), nil)
        t:eq("golpe que nao tira vida (bloqueio) nao toca hurt", EnemySfx.hurt(g, 0), nil)
        t:eq("golpe que mata nao toca hurt (death toca)", EnemySfx.hurt(fakeEnemy("grave_thrall", 0), 9), nil)

        local Enemy = require("src.entities.Enemy")
        local EnemyRoster = require("src.systems.EnemyRoster")
        local imp = EnemyRoster.spawn(Enemy, "ember_imp", { health = 500, damage = 5 })
        clear(audio.log)
        now = now + 10
        imp:takeDamage(20, "fire")
        local voiced = false
        for _, e in ipairs(audio.log) do if e.code:find("^enemyVoice_") then voiced = true end end
        t:falsy("Enemy:takeDamage com fogo no imp (imune) nao toca voz", voiced)
        clear(audio.log)
        now = now + 10
        imp:takeDamage(20, "physical")
        voiced = false
        for _, e in ipairs(audio.log) do if e.code:find("^enemyVoice_ember_imp_hurt") then voiced = true end end
        t:truthy("Enemy:takeDamage fisico no imp toca a voz dele", voiced)

        Data.ALIAS.fake_kin = "grave_thrall"
        now = now + 10
        local ac = EnemySfx.hurt(fakeEnemy("fake_kin"), 3)
        Data.ALIAS.fake_kin = nil
        t:truthy("ALIAS compartilha a pasta de outra criatura", type(ac) == "string" and ac:find("grave_thrall") ~= nil)

        local dir = Data.DIR .. "/zz_scan_probe"
        love.filesystem.createDirectory(dir)
        local bytes = love.filesystem.read("audio/sfx/enemies/grave_thrall/hurt_1.mp3")
        love.filesystem.write(dir .. "/hurt_1.mp3", bytes)
        love.filesystem.write(dir .. "/roar_1.mp3", bytes)
        EnemySfx.rescan()
        t:eq("arquivo novo entra pelo scan sem codigo (hurt)", #EnemySfx.files("zz_scan_probe", "hurt"), 1)
        t:eq("evento opcional roar entra pelo scan", #EnemySfx.files("zz_scan_probe", "roar"), 1)
        now = now + 10
        t:truthy("roar toca quando existe", EnemySfx.roar(fakeEnemy("zz_scan_probe")))
        t:eq("roar sem arquivo devolve nil (generico fica com o chamador)", EnemySfx.roar(g), nil)
        love.filesystem.remove(dir .. "/hurt_1.mp3")
        love.filesystem.remove(dir .. "/roar_1.mp3")
        love.filesystem.remove(dir)
        EnemySfx.rescan()
        t:eq("sonda removida", #EnemySfx.files("zz_scan_probe", "hurt"), 0)

        local g2 = TK.newRunGame("warrior")
        TK.pump(g2, 0.2)
        g2.enemy = EnemyRoster.spawn(Enemy, "frost_troll", { health = 50, damage = 5 })
        g2._deathHandled = false
        clear(audio.log)
        now = now + 10
        pcall(function() g2:_onEnemyDeath() end)
        local own, generic = false, false
        for _, e in ipairs(audio.log) do
            if e.code:find("^enemyVoice_frost_troll_death") then own = true end
            if e.code == "enemyDeath" then generic = true end
        end
        t:truthy("Game:_onEnemyDeath toca a morte do troll", own)
        t:falsy("Game:_onEnemyDeath nao toca mais o enemyDeath generico", generic)
    end)
    t:check("rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)

    _G.audioSystem, EnemySfx.now, Debug.warn = savedAudio, savedNow, savedWarn
    EnemySfx.rescan()
    return t:done()
end

return M
