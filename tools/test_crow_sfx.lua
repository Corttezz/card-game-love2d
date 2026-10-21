local TK = require("tools.testkit")

local M = {}

local OLD_FILES = { "audio/sfx/boss/boss_crows_caw.mp3", "audio/sfx/boss/boss_crows_flee.mp3" }
local OLD_CODES = { "bossCrowsCaw", "bossCrowsFlee", "boss_crows_caw", "boss_crows_flee", "diveSound" }

local function recordingAudio(clock)
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
        log[#log + 1] = { code = code, t = clock(), pitch = opts and opts.pitch,
                          loop = opts and opts.loop }
        return fakeSrc()
    end
    function a:playSound(code) return self:play(code) end
    function a:stop() end
    function a:stopAll() end
    return a
end

local function isCrow(code)
    return code:lower():find("crow") ~= nil
end

local function family(code)
    return (code:gsub("%d+$", ""))
end

local function luaFiles(dir, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = dir .. "/" .. name
        local info = love.filesystem.getInfo(p)
        if info and info.type == "directory" then
            luaFiles(p, out)
        elseif name:match("%.lua$") then
            out[#out + 1] = p
        end
    end
    return out
end

function M.simulate(turns)
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local BC = require("src.ui.BossCinematic")
    local ER = require("src.ui.EnemyRenderer")
    local okC, CrowSfx = pcall(require, "src.systems.CrowSfx")
    love.math.setRandomSeed(4242)
    math.randomseed(4242)
    TK.seedRng(4242)
    local now = 0
    local clock = function() return now end
    local savedAudio, savedNow = _G.audioSystem, okC and CrowSfx.now or nil
    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    _G.audioSystem = recordingAudio(clock)
    if okC then CrowSfx.now = clock; CrowSfx.reset() end
    local phases = {}
    local ok, err = pcall(function()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.3)
        ER.resetRun()
        BC.reset()
        g.enemy = EnemyRoster.spawn(Enemy, "carrion_king", { health = 9999, damage = 6 })
        g.enemy.isBoss = true
        g.enemy.spriteId = "carrion_king"
        g._deathHandled, g._deathStaged = false, false
        g.player.maxHealth = 99999
        g.player.health = 99999
        g.battleTurn = 1
        local stage = {
            cx = 960, cy = 840,
            bbox = { cx = 960, topY = 500, bottomY = 840, width = 300, height = 340 },
            foot = { drawX = 800, drawY = 480, scale = 2.6 },
            hall = 1, w = 1920, h = 1080, tr = { scale = 4.8, ox = 0, oy = -74 },
        }
        local DT = 1 / 30
        local function frame()
            now = now + DT
            TK.pump(g, DT)
            pcall(ER.draw, g, 960, 760)
        end
        local function mark(name) phases[#phases + 1] = { name = name, t = now } end
        mark("intro")
        BC.startIntro(g)
        BC.setStage(stage)
        local el = 0
        while BC.isActive() and el < 20 do
            now = now + DT
            BC.update(DT, g, { inHall = true })
            el = el + DT
        end
        for turn = 1, turns do
            mark("turn" .. turn)
            g.turn = "enemy"
            g._enemyActing = false
            g:enemyTurn()
            for _ = 1, 30 * 8 do frame() end
            g.player.health = g.player.maxHealth
            g.battleTurn = (g.battleTurn or 1) + 1
        end
        mark("death")
        BC.startDeath(g)
        BC.setStage(stage)
        el = 0
        while BC.isActive() and el < 20 do
            now = now + DT
            BC.update(DT, g, { inHall = true })
            el = el + DT
        end
        mark("end")
        BC.reset()
        ER.resetRun()
    end)
    local log = _G.audioSystem.log
    _G.audioSystem = savedAudio
    _G.gameSettings = savedGS
    if okC then CrowSfx.now = savedNow; CrowSfx.reset() end
    return ok, err, log, phases
end

local function phaseOf(phases, t)
    local name = phases[1] and phases[1].name
    for _, p in ipairs(phases) do
        if t >= p.t then name = p.name end
    end
    return name
end

function M.report(log, phases)
    local byFamily, byCode, byPhase = {}, {}, {}
    for _, e in ipairs(log) do
        if isCrow(e.code) then
            local f = family(e.code)
            byFamily[f] = (byFamily[f] or 0) + 1
            byCode[e.code] = (byCode[e.code] or 0) + 1
            local ph = phaseOf(phases, e.t)
            if ph:match("^turn") then ph = "luta" end
            byPhase[ph] = byPhase[ph] or {}
            byPhase[ph][f] = (byPhase[ph][f] or 0) + 1
        end
    end
    print("  [corvo] sons por familia numa luta (entrada + turnos + morte):")
    local fams = {}
    for f in pairs(byFamily) do fams[#fams + 1] = f end
    table.sort(fams)
    for _, f in ipairs(fams) do
        local parts = {}
        for _, ph in ipairs({ "intro", "luta", "death" }) do
            parts[#parts + 1] = ph .. "=" .. tostring((byPhase[ph] or {})[f] or 0)
        end
        print(string.format("    %-14s total=%d  %s", f, byFamily[f], table.concat(parts, " ")))
    end
    return byFamily, byCode
end

function M.run()
    local t = TK.new("corvos: sons novos por momento, sem repetir, com cooldown")
    TK.bootstrap()
    TK.seedRng(4242)
    local CrowSfx = require("src.systems.CrowSfx")

    for _, p in ipairs(OLD_FILES) do
        t:falsy("arquivo antigo removido: " .. p, love.filesystem.getInfo(p))
    end
    local files = {}
    for _, d in ipairs({ "src", "components", "engine" }) do luaFiles(d, files) end
    files[#files + 1] = "main.lua"
    for _, code in ipairs(OLD_CODES) do
        local hit = nil
        for _, p in ipairs(files) do
            local src = love.filesystem.read(p) or ""
            if src:find(code, 1, true) then hit = p end
        end
        t:falsy("ninguem mais referencia " .. code, hit)
    end

    local now = 0
    local savedAudio, savedNow, savedEM = _G.audioSystem, CrowSfx.now, _G.EventManager
    local audio = recordingAudio(function() return now end)
    _G.audioSystem = audio
    CrowSfx.now = function() return now end
    CrowSfx.reset()

    local scanned = CrowSfx.scan()
    local seenPath, seenCode = {}, {}
    for moment in pairs(CrowSfx.MOMENTS) do
        local list = scanned[moment]
        t:truthy(moment .. ": 3+ variantes no disco", #list >= 3)
        t:eq(moment .. ": todas carregadas", #CrowSfx.variants(moment), #list)
        for _, v in ipairs(list) do
            t:falsy("variante usada por um momento so: " .. v.path, seenPath[v.path])
            t:falsy("codigo exclusivo: " .. v.code, seenCode[v.code])
            seenPath[v.path], seenCode[v.code] = moment, moment
            local bytes = love.filesystem.read(v.path) or ""
            local head = bytes:sub(1, 3)
            t:truthy("mp3 de verdade: " .. v.path,
                head == "ID3" or bytes:byte(1) == 0xFF)
        end
    end

    for moment in pairs(CrowSfx.MOMENTS) do
        local prev, repeats, plays = nil, 0, 0
        for _ = 1, 40 do
            now = now + 5
            local code = CrowSfx.play(moment)
            if code then
                plays = plays + 1
                if code == prev then repeats = repeats + 1 end
                prev = code
            end
        end
        t:eq(moment .. ": toca sempre que o cooldown deixa", plays, 40)
        t:eq(moment .. ": mesma variante nunca duas vezes seguidas", repeats, 0)
    end

    _G.EventManager = nil
    CrowSfx.reset()
    now = 1000
    t:truthy("aparecer toca", CrowSfx.play("crowAppear"))
    now = now + 0.5
    t:falsy("aparecer de novo em 0,5 s: segura", CrowSfx.play("crowAppear"))
    now = now + 0.8
    t:truthy("aparecer depois de 1,3 s: toca", CrowSfx.play("crowAppear"))

    CrowSfx.reset()
    now = 2000
    local volley = {}
    for h = 1, 6 do
        local code = CrowSfx.attack(h, 6)
        if code then volley[#volley + 1] = family(code) end
        now = now + 0.9
    end
    t:eq("revoada de 6 golpes: 2 sons no total, nunca um por corvo", #volley, 2)
    t:eq("...abre com o mergulho", volley[1], "crowDive")
    t:eq("...e o bando entra UMA vez, depois do cooldown", volley[2], "crowFlock")
    now = now + 2
    local duo = {}
    for h = 1, 2 do
        local code = CrowSfx.attack(h, 2)
        if code then duo[#duo + 1] = family(code) end
        now = now + 1.5
    end
    t:eq("ataque de 2 corvos: so o mergulho", #duo, 1)
    t:eq("...mergulho", duo[1], "crowDive")
    now = now + 2
    t:truthy("novo ataque", CrowSfx.attack(1, 4))
    now = now + 0.4
    t:falsy("outro ataque em 0,4 s: segura", CrowSfx.attack(1, 4))
    now = now + 0.2
    t:falsy("...e o mergulho tem cooldown proprio tambem", CrowSfx.play("crowDive"))
    now = now - 50
    t:truthy("relogio que volta (suite com relogio falso) nao trava", CrowSfx.play("crowDive"))

    _G.EventManager = savedEM
    _G.audioSystem = savedAudio
    CrowSfx.now = savedNow
    CrowSfx.reset()

    local ok, err, log, phases = M.simulate(10)
    t:truthy("luta simulada roda: " .. tostring(err), ok)
    local byFamily = M.report(log, phases)
    t:truthy("entrada tem o grasnado de cinematica", (byFamily.crowCine or 0) >= 1)
    t:truthy("luta tem mergulho ou revoada",
        ((byFamily.crowDive or 0) + (byFamily.crowFlock or 0)) >= 1)
    t:truthy("invocacao toca o som de aparecer", (byFamily.crowAppear or 0) >= 1)
    local lastBy, tooClose = {}, nil
    for _, e in ipairs(log) do
        if isCrow(e.code) then
            local f = family(e.code)
            local spec = CrowSfx.MOMENTS[f]
            if lastBy[f] and spec and e.t - lastBy[f] < (spec.cooldown or 0) - 1e-6 then
                tooClose = string.format("%s em %.2f s depois de %.2f s (cooldown %.2f)", f, e.t, lastBy[f], spec.cooldown or 0)
            end
            lastBy[f] = e.t
        end
    end
    t:truthy("nenhum som de corvo repete dentro do cooldown na luta" .. (tooClose and (": " .. tooClose) or ""), not tooClose)
    local prevCode, twice = nil, nil
    for _, e in ipairs(log) do
        if isCrow(e.code) then
            if prevCode and family(prevCode) == family(e.code) and prevCode == e.code then
                twice = e.code
            end
            prevCode = e.code
        end
    end
    t:falsy("mesma variante nunca toca duas vezes seguidas na luta", twice)

    return t:done()
end

return M
