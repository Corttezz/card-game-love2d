local Debug = require("src.core.Debug")
local Sfx = require("src.systems.Sfx")
local Data = require("src.data.music_stingers")

local M = {}

M.LOG_MAX = 256

local clock = 0
local key = nil
local fired = {}
local enemyAlive, playerAlive = nil, nil
local lastState = nil
local scheduled = {}
local holdUntil = 0
local holdStates = nil
local silence = nil
local bossDeadKey = nil
local deathSeenKey = nil
local lowHp = false
local beatT = 0
local entranceKey = nil
local stingAt = nil

M.log = {}

local function audio()
    local a = _G.audioSystem
    if a and a.isAudioAvailable and a:isAudioAvailable() then return a end
    return nil
end

local function note(kind, name, played)
    local log = M.log
    if #log >= M.LOG_MAX then table.remove(log, 1) end
    log[#log + 1] = { t = clock, kind = kind, name = name, played = played }
end

function M.code(name) return Data.PREFIX .. name end

function M.register(audioSystem)
    if not audioSystem then return 0 end
    local n = 0
    for name, def in pairs(Data.STINGERS) do
        local path = def.file or (Data.DIR .. name .. ".mp3")
        if love.filesystem.getInfo(path) then
            audioSystem:loadSound(M.code(name), path, { volume = def.volume or 0.7, group = "sfx", stream = false })
            n = n + 1
        else
            Debug.warn("[MusicMoments] stinger ausente: " .. path)
        end
    end
    return n
end

function M.sting(name, fallback)
    local def = Data.STINGERS[name]
    local code = M.code(name)
    local a = audio()
    local played = false
    if Sfx.has(code) then
        Sfx.play(code)
        played = true
        if a and def and def.duck then
            local d = def.duck
            a:duck("sting:" .. name, d.gain, d.attack, d.hold, d.release)
        end
    elseif fallback and Sfx.has(fallback) then
        Sfx.play(fallback)
        played = true
    end
    note("sting", name, played)
    return played
end

local function schedule(delay, fn, tag)
    scheduled[#scheduled + 1] = { at = clock + delay, fn = fn, tag = tag }
end

local function runScheduled()
    local i = 1
    while i <= #scheduled do
        local s = scheduled[i]
        if clock >= s.at then
            table.remove(scheduled, i)
            s.fn()
        else
            i = i + 1
        end
    end
end

local function setLowHp(on)
    if lowHp == on then return end
    lowHp = on
    local a = audio()
    local L = Data.LOW_HP
    if on then
        beatT = 0
        if a then
            a:holdDuck("lowhp", L.duck, L.attack)
            a:setMusicFilter(L.filter)
        end
    elseif a then
        a:releaseDuck("lowhp", L.release)
        a:setMusicFilter(nil)
    end
    note("lowhp", on and "on" or "off", true)
end

function M.reset()
    local a = audio()
    if a then
        if a.clearDucks then a:clearDucks() end
        if a.setMusicFilter then a:setMusicFilter(nil) end
    end
    key, fired = nil, {}
    enemyAlive, playerAlive = nil, nil
    scheduled = {}
    holdUntil, holdStates = 0, nil
    silence = nil
    bossDeadKey, deathSeenKey = nil, nil
    lowHp = false
    entranceKey, stingAt = nil, nil
end

local function floorKey(run, nodeType)
    if not run then return nil end
    return table.concat({ tostring(run.actNumber), tostring(run.currentFloor), tostring(run.floorInAct),
        tostring(nodeType), tostring(run.floorsInEndless or 0) }, ":")
end

local function currentGame()
    local ok, GS = pcall(require, "src.scenes.GameplayScene")
    local g = ok and GS and GS.getGame and GS.getGame() or nil
    return g or _G.game
end

local function finalAct(run)
    local Config = require("src.core.Config")
    return run and not run.endlessMode and (run.actNumber or 1) >= (Config.TotalActs or 6)
end

local function hold(secs, states)
    holdUntil = math.max(holdUntil, clock + secs)
    holdStates = states
end

local function onEnemyDeath(run, nodeType)
    deathSeenKey = key
    if nodeType == "boss" then
        bossDeadKey = key
        silence = { fade = Data.BOSS_DEATH.fade, boss = true }
        note("music", "boss_fade", true)
        schedule(Data.BOSS_DEATH.passAt, function() M.sting("boss_pass", "bossDeathThud") end, "boss_pass")
        return
    end
    M.sting(Data.ENEMY_DEATH[nodeType] or Data.ENEMY_DEATH.battle, nil)
end

local function onPlayerDeath()
    silence = { fade = Data.PLAYER_DEATH.fade, player = true }
    setLowHp(false)
    M.sting("player_death", "runDefeat")
    hold(Data.PLAYER_DEATH.hold, { playing = true, gameOver = true })
end

local function entrance(state, nodeType, game)
    local spec = Data.ENTRANCE[nodeType]
    local a = audio()
    if not spec then return end
    local ok, EE = pcall(require, "src.ui.EnemyEntrance")
    if not ok then return end
    local S = (state == "playing") and EE.isActive() and EE.state() or nil
    local def = Data.STINGERS[spec.sting] or {}
    if S and not fired.entranceStart then
        fired.entranceStart = true
        entranceKey = key
        if a then a:holdDuck("entrance", spec.preDuck.gain, spec.preDuck.attack) end
        note("duck", "entrance", true)
    end
    if S and fired.entranceStart and not fired.entranceSting and (S.tail or 0) <= (def.hit or 0) then
        fired.entranceSting = true
        stingAt = clock
        M.sting(spec.sting, nil)
    end
    if fired.entranceStart and not fired.entranceRelease then
        local done = not S
        if S and fired.entranceSting and S.stopped then
            local card = EE.cardVisible and EE.cardVisible()
            done = not card and (clock - (stingAt or clock)) >= 1.2
        end
        if done then
            fired.entranceRelease = true
            if a then a:releaseDuck("entrance", spec.release) end
            note("duck", "entrance_release", true)
        end
    end
end

local RUN_STATES = { playing = true, roundEval = true, cardReward = true, mapSelection = true,
    rest = true, event = true, gameOver = true, victory = true }

function M.update(dt, state, run, nodeType)
    dt = dt or (1 / 60)
    clock = clock + dt
    if not RUN_STATES[state] or not run then
        if key ~= nil or lowHp or #scheduled > 0 then M.reset() end
        lastState = state
        return
    end
    runScheduled()

    local k = floorKey(run, nodeType)
    if k ~= key then
        if entranceKey and not fired.entranceRelease then
            local a = audio()
            if a then a:releaseDuck("entrance", 0.6) end
        end
        key = k
        fired = {}
        enemyAlive, playerAlive = nil, nil
        entranceKey, stingAt = nil, nil
        if silence and silence.boss then silence = nil end
    end

    local game = currentGame()
    if state == "playing" and game then
        local e, p = game.enemy, game.player
        if e then
            local alive = (e.health or 0) > 0
            if enemyAlive == true and not alive and not fired.enemyDeath then
                fired.enemyDeath = true
                onEnemyDeath(run, nodeType)
            end
            enemyAlive = alive
        end
        if p then
            local alive = (p.health or 0) > 0
            if playerAlive == true and not alive and not fired.playerDeath then
                fired.playerDeath = true
                onPlayerDeath()
            end
            playerAlive = alive
            local L = Data.LOW_HP
            local frac = (p.maxHealth and p.maxHealth > 0) and (p.health / p.maxHealth) or 1
            if alive and enemyAlive ~= false then
                if not lowHp and frac < L.enter then setLowHp(true)
                elseif lowHp and frac > L.leave then setLowHp(false) end
            elseif lowHp then
                setLowHp(false)
            end
            if lowHp then
                beatT = beatT - dt
                if beatT <= 0 then
                    local kf = math.max(0, math.min(1, frac / L.enter))
                    beatT = L.beatEveryMin + (L.beatEvery - L.beatEveryMin) * kf
                    if Sfx.has(M.code("heartbeat")) then Sfx.play(M.code("heartbeat")) end
                    note("beat", "heartbeat", true)
                end
            end
        end
        entrance(state, nodeType, game)
    elseif lowHp then
        setLowHp(false)
    end

    if state == "victory" and lastState ~= "victory" and lastState ~= nil then
        setLowHp(false)
        silence = nil
        M.sting("run_victory", "runVictory")
        hold(Data.VICTORY.hold, { victory = true })
    end
    if state ~= "playing" and state ~= "gameOver" and silence and silence.player then silence = nil end
    lastState = state
end

function M.cashOutChime(run, nodeType)
    if not key or deathSeenKey ~= key then
        note("chime", "skipped", false)
        return false
    end
    if nodeType == "boss" and not finalAct(run) then
        schedule(Data.ACT_COMPLETE_DELAY, function() M.sting("act_complete", "actComplete") end, "act_complete")
        return true
    end
    if nodeType == "boss" then return false end
    Sfx.play("battleVictory")
    note("chime", "battleVictory", true)
    return true
end

function M.override(state, nodeType)
    if state == "playing" and nodeType == "boss" and bossDeadKey and bossDeadKey == key then
        return Data.BOSS_DEATH.fade
    end
    if silence and silence.player and (state == "playing") then
        return silence.fade
    end
    return nil
end

function M.silenceFade(default)
    if silence then return silence.fade end
    return default
end

function M.holding(state)
    return clock < holdUntil and holdStates ~= nil and holdStates[state] == true
end

function M.lowHp() return lowHp end
function M.clock() return clock end

function M._debug()
    return { key = key, fired = fired, holdUntil = holdUntil, clock = clock, lowHp = lowHp,
        silence = silence, bossDeadKey = bossDeadKey, scheduled = #scheduled }
end

return M
