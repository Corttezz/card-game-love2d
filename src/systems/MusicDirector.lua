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

function MusicDirector.registerTracks(audioSystem)
    if not audioSystem then return 0 end
    local loaded = 0
    for code, file in pairs(MusicDirector.TRACKS) do
        local path = "audio/music/" .. file
        if love.filesystem.getInfo(path) then
            audioSystem:loadSound(code, path, {
                volume = 0.6, group = "music", stream = true, loop = true,
            })
            loaded = loaded + 1
        end
    end
    return loaded
end

local FADE_FAST = 1.2
local FADE_SLOW = 2.5

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
    musicBossEclipse = "musicBoss",
    musicShop = "musicAct1",
    musicRest = "musicAct1",
    menuMusic = nil,
}

local function resolve(code)
    local seen = 0
    while code and seen < 8 do
        if Sfx.has(code) then return code end
        code = FALLBACK[code]
        seen = seen + 1
    end
    return nil
end

MusicDirector.FINAL_BOSS_ID = "eclipse_queen"
MusicDirector.FINAL_BOSS_TRACK = "musicBossEclipse"

local function isFinalBoss(run)
    local node = run and run.currentNode
    if node and node.enemyId then return node.enemyId == MusicDirector.FINAL_BOSS_ID end
    local Config = require("src.core.Config")
    return run ~= nil and (run.actNumber or 1) == (Config.TotalActs or 6) and not run.endlessMode
end

function MusicDirector.pick(state, run, nodeType, inHall)
    if state == "boot" or state == "menu" or state == "classSelection"
        or state == "collection" or state == "achievements" or state == "credits"
        or state == "gameOver" or state == "victory" then
        return "menuMusic"
    end

    if state == "cardReward" then
        return (nodeType == "shop") and "musicShop" or nil
    end
    if state == "roundEval" then return nil end

    if state == "rest" then return "musicRest" end

    if state == "playing" and nodeType == "boss" then
        if inHall and isFinalBoss(run) then return MusicDirector.FINAL_BOSS_TRACK end
        return "musicBoss"
    end

    local act = (run and run.actNumber) or 1
    local Config = require("src.core.Config")
    local ultimo = Config.TotalActs or 3
    act = math.max(1, math.min(act, ultimo))
    return "musicAct" .. act
end

local function tocandoAgora()
    local a = _G.audioSystem
    return a and a.currentMusic or nil
end

MusicDirector.hallProbe = nil
local function inHallNow(nodeType)
    if MusicDirector.hallProbe then return MusicDirector.hallProbe(nodeType) and true or false end
    if nodeType ~= "boss" then return false end
    local ok, GS = pcall(require, "src.scenes.GameplayScene")
    if ok and GS and GS.inBossRoom then
        local ok2, res = pcall(GS.inBossRoom, nodeType)
        return ok2 and res and true or false
    end
    return false
end

function MusicDirector.apply(state, run, nodeType)
    if not MusicDirector.enabled then return end

    local wanted = MusicDirector.pick(state, run, nodeType, inHallNow(nodeType))
    if not wanted then return end

    local code = resolve(wanted)
    if not code then return end

    local atual = tocandoAgora() or MusicDirector._current

    if wanted ~= MusicDirector._lastWanted then
        MusicDirector._lastWanted = wanted
        Debug.log(string.format("[Musica] quer %s -> resolveu %s | tocando %s (estado=%s, no=%s)",
            tostring(wanted), tostring(code), tostring(atual),
            tostring(state), tostring(nodeType or "-")))
    end

    if code == atual then
        MusicDirector._current = atual
        return
    end

    local saindoDoMenu = (atual == "menuMusic" and code ~= "menuMusic")
    local fade = (code == "musicBoss" or code == MusicDirector.FINAL_BOSS_TRACK or saindoDoMenu)
        and FADE_FAST or FADE_SLOW
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
