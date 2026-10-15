local Debug = require("src.core.Debug")

local Sfx = require("src.systems.Sfx")

local MusicDirector = {}

MusicDirector.TRACKS = {
    musicAct1 = "music-act1.mp3",
    musicAct2 = "music-act2.mp3",
    musicAct3 = "music-act3.mp3",
    musicAct4 = "music-act4.mp3",
    musicAct5 = "music-act5.mp3",
    musicAct6 = "music-act6.mp3",
    musicBoss = "music-boss.mp3",
    musicBossEclipse = "music-boss-eclipse.mp3",
    musicShop = "music-shop.mp3",
    musicRest = "music-rest.mp3",
}

MusicDirector.BOSS_TRACKS = {
    carrion_king = "musicBossCarrionKing",
    tower_lich = "musicBossTowerLich",
    abyss_tyrant = "musicBossAbyssTyrant",
    winter_monarch = "musicBossWinterMonarch",
    rot_colossus = "musicBossRotColossus",
    eclipse_queen = "musicBossEclipse",
}

MusicDirector.GENERIC_BOSS = "musicBoss"
MusicDirector.SILENCE = "silence"

function MusicDirector.bossFile(id)
    return "boss-" .. id .. ".mp3"
end

function MusicDirector.registerTracks(audioSystem)
    if not audioSystem then return 0 end
    local loaded = 0
    local function load(code, path)
        if love.filesystem.getInfo(path) then
            audioSystem:loadSound(code, path, {
                volume = 0.6, group = "music", stream = true, loop = true,
            })
            loaded = loaded + 1
        end
    end
    for code, file in pairs(MusicDirector.TRACKS) do
        load(code, "audio/music/" .. file)
    end
    for id, code in pairs(MusicDirector.BOSS_TRACKS) do
        load(code, "audio/music/" .. MusicDirector.bossFile(id))
    end
    require("src.systems.MusicSections").scan(MusicDirector.BOSS_TRACKS)
    return loaded
end

local FADE_FAST = 1.2
local FADE_SLOW = 2.5
MusicDirector.FADE_SILENCE = 5.0

MusicDirector.enabled = true
MusicDirector._current = nil

local FALLBACK = {
    musicAct1 = "menuMusic",
    musicAct2 = "musicAct1",
    musicAct3 = "musicAct2",
    musicAct4 = "musicAct3",
    musicAct5 = "musicAct4",
    musicAct6 = "musicAct5",
    musicBoss = "musicAct3",
    musicShop = "musicAct1",
    musicRest = "musicAct1",
    menuMusic = nil,
}

local BOSS_CODES = {}
for _, code in pairs(MusicDirector.BOSS_TRACKS) do
    BOSS_CODES[code] = true
    FALLBACK[code] = MusicDirector.GENERIC_BOSS
end
BOSS_CODES[MusicDirector.GENERIC_BOSS] = true

function MusicDirector.isBossCode(code)
    return BOSS_CODES[code] == true
end

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn(msg)
end

local function resolve(code)
    local seen = 0
    local asked = code
    while code and seen < 8 do
        if Sfx.has(code) then
            if code ~= asked and BOSS_CODES[asked] then
                warnOnce("faixa:" .. asked, "[Musica] faixa do chefe ausente: " .. tostring(asked)
                    .. " -> usando " .. tostring(code))
            end
            return code
        end
        code = FALLBACK[code]
        seen = seen + 1
    end
    return nil
end

local function bossIdOf(run)
    local node = run and run.currentNode
    if node and node.enemyId then return node.enemyId end
    if not run or run.endlessMode then return nil end
    local Config = require("src.core.Config")
    local act = run.actNumber or 1
    if act < 1 or act > (Config.TotalActs or 6) then return nil end
    local roster = require("src.data.enemies").ROSTER[act]
    return roster and roster.boss and roster.boss[1] or nil
end

function MusicDirector.bossTrack(run)
    local id = bossIdOf(run)
    local code = id and MusicDirector.BOSS_TRACKS[id]
    if code then return code end
    if id then
        warnOnce("chefe:" .. id, "[Musica] chefe sem faixa propria: " .. tostring(id)
            .. " -> " .. MusicDirector.GENERIC_BOSS)
    end
    return MusicDirector.GENERIC_BOSS
end

function MusicDirector.forkOffersBoss(run)
    local pending = run and run.pendingNodes
    if not pending then return false end
    for _, node in ipairs(pending) do
        if node and node.type == "boss" then return true end
    end
    return false
end

function MusicDirector.pick(state, run, nodeType, inHall, introPlaying)
    if state == "boot" then return nil end
    if state == "menu" or state == "classSelection"
        or state == "collection" or state == "achievements"
        or state == "gameOver" or state == "victory" then
        return "menuMusic"
    end

    if state == "cardReward" then
        return (nodeType == "shop") and "musicShop" or nil
    end
    if state == "roundEval" then return nil end

    if state == "rest" then return "musicRest" end

    if state == "mapSelection" and MusicDirector.forkOffersBoss(run) then
        return MusicDirector.SILENCE
    end

    if state == "playing" and nodeType == "boss" then
        if inHall == false or introPlaying == true or introPlaying == "intro" then
            return MusicDirector.SILENCE
        end
        if introPlaying == "death" then return nil end
        return MusicDirector.bossTrack(run)
    end

    return MusicDirector.actTrack(run)
end

function MusicDirector.actTrack(run)
    local act = (run and run.actNumber) or 1
    local Config = require("src.core.Config")
    local ultimo = Config.TotalActs or 3
    act = math.max(1, math.min(act, ultimo))
    return "musicAct" .. act
end

MusicDirector.KEEP_STATES = { roundEval = true, cardReward = true }

local function audioReal()
    local a = _G.audioSystem
    if a and a.isAudioAvailable and a:isAudioAvailable() then return a end
    return nil
end

local function tocandoAgora()
    local a = audioReal()
    return a and a.currentMusic or nil
end

local function atualDe()
    if audioReal() then return tocandoAgora() end
    return MusicDirector._current
end

MusicDirector.hallProbe = nil
local function inHallNow(nodeType)
    if MusicDirector.hallProbe then return MusicDirector.hallProbe(nodeType) and true or false end
    if nodeType ~= "boss" then return false end
    local ok, GS = pcall(require, "src.scenes.GameplayScene")
    if ok and GS and GS.inBossRoom then
        if GS.SCENE_MODE ~= "worldroad" then return true end
        local ok2, res = pcall(GS.inBossRoom, nodeType)
        return ok2 and res and true or false
    end
    return false
end

MusicDirector.introProbe = nil
local function introNow(nodeType)
    if MusicDirector.introProbe then return MusicDirector.introProbe(nodeType) and true or false end
    if nodeType ~= "boss" then return false end
    local ok, BC = pcall(require, "src.ui.BossCinematic")
    return (ok and BC and BC.phase and BC.phase()) or false
end

function MusicDirector.apply(state, run, nodeType)
    if not MusicDirector.enabled then return end

    local wanted = MusicDirector.pick(state, run, nodeType, inHallNow(nodeType), introNow(nodeType))
    if not wanted and MusicDirector.KEEP_STATES[state] then
        local atual = atualDe()
        if atual == "menuMusic"
            or (atual == nil and MusicDirector._current ~= MusicDirector.SILENCE) then
            wanted = MusicDirector.actTrack(run)
        end
    end
    if not wanted then return end

    if wanted == MusicDirector.SILENCE then
        if wanted ~= MusicDirector._lastWanted then
            MusicDirector._lastWanted = wanted
            Debug.log(string.format("[Musica] silencio | tocando %s (estado=%s, no=%s)",
                tostring(tocandoAgora()), tostring(state), tostring(nodeType or "-")))
        end
        if tocandoAgora() then Sfx.silenceMusic(MusicDirector.FADE_SILENCE) end
        MusicDirector._current = MusicDirector.SILENCE
        return
    end

    local Sections = require("src.systems.MusicSections")
    if Sections.has(wanted) then
        local tocando = Sections.drive(wanted, FADE_FAST)
        if tocando then
            MusicDirector._lastWanted = wanted
            MusicDirector._current = tocando
            return
        end
    end

    local code = resolve(wanted)
    if not code then return end

    local atual = atualDe()

    if wanted ~= MusicDirector._lastWanted then
        MusicDirector._lastWanted = wanted
        Debug.log(string.format("[Musica] quer %s -> resolveu %s | tocando %s (estado=%s, no=%s)",
            tostring(wanted), tostring(code), tostring(atual),
            tostring(state), tostring(nodeType or "-")))
    end

    if code == atual then
        MusicDirector._current = atual
        local a = audioReal()
        local e = a and a.sources[code]
        if e and e.template and not e.template:isPlaying() and not a.musicCrossfade then
            Sfx.playMusic(code, { fadeDuration = FADE_FAST })
        end
        return
    end

    local saindoDoMenu = (atual == "menuMusic" and code ~= "menuMusic")
    local fade = (BOSS_CODES[code] or saindoDoMenu) and FADE_FAST or FADE_SLOW
    Debug.log(string.format("[Musica] %s -> %s (estado=%s, no=%s)",
        tostring(atual or "nada"), tostring(code), tostring(state),
        tostring(nodeType or "-")))
    Sfx.playMusic(code, { fadeDuration = fade })
    MusicDirector._current = code
end

function MusicDirector.markCurrent(code)
    MusicDirector._current = code
end

return MusicDirector
