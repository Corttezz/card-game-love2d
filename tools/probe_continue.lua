local M = {}
function M.run()
    local AudioManager = require("engine.AudioManager")
    local MD  = require("src.systems.MusicDirector")
    local Sfx = require("src.systems.Sfx")
    local Game = require("src.core.Game")

    local audio = AudioManager:new()
    _G.audioSystem = audio
    audio:setGroupVolume("master", 0)
    local n = MD.registerTracks(audio)
    audio:loadSound("menuMusic", "audio/music.mp3",
        { volume = 0.6, group = "music", stream = true, loop = true })
    print(("registradas: %d faixas | menuMusic=%s"):format(n, tostring(Sfx.has("menuMusic"))))
    for _, c in ipairs({ "musicAct1", "musicAct2", "musicAct3", "musicBoss", "musicShop", "musicRest" }) do
        io.write(("  %s=%s"):format(c, tostring(Sfx.has(c))))
    end
    print("")

    Sfx.playMusic("menuMusic", { fadeDuration = 1.5 })
    MD.markCurrent("menuMusic")
    audio:update(0.1)
    print(("[1] menu    -> _current=%s  audioSystem=%s"):format(
        tostring(MD._current), tostring(audio.currentMusic)))

    local game = Game:new()
    game:startNewRun("warrior")
    local run = game.runManager.currentRun
    run.actNumber = 2
    run.floorInAct = 4
    run.currentNode = { type = "battle" }
    print(("[2] run     -> ato=%s andar=%s no=%s"):format(
        tostring(run.actNumber), tostring(run.floorInAct),
        tostring(run.currentNode and run.currentNode.type)))

    local estado = "playing"
    local node = run.currentNode
    print(("[3] pick    -> %s"):format(tostring(MD.pick(estado, run, node and node.type))))
    for i = 1, 3 do
        MD.apply(estado, run, node and node.type)
        audio:update(1 / 60)
    end
    print(("[4] depois  -> _current=%s  audioSystem=%s"):format(
        tostring(MD._current), tostring(audio.currentMusic)))

    run.pendingNodes = { { type = "battle" }, { type = "shop" } }
    estado = "mapSelection"
    print(("[5] pick(mapSelection) -> %s"):format(tostring(MD.pick(estado, run, nil))))
    MD.apply(estado, run, nil)
    audio:update(1 / 60)
    print(("[6] fim     -> _current=%s  audioSystem=%s"):format(
        tostring(MD._current), tostring(audio.currentMusic)))

    audio:stopMusic()
    love.event.quit(0)
    return true
end
return M
