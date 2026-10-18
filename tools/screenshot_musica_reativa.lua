local M = {}

local function outDir()
    local d = love.filesystem.getSource() .. "/tools/preview_out/musica_reativa/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function save(imageData, name)
    local dir = outDir()
    local fd = imageData:encode("png")
    local f = assert(io.open(dir .. name, "wb"))
    f:write(fd:getString())
    f:close()
    print("[screenshot_musica_reativa] " .. dir .. name)
end

local ACT = { carrion_king = 1, tower_lich = 2, abyss_tyrant = 3, winter_monarch = 4,
              rot_colossus = 5, eclipse_queen = 6 }

local function mount(id)
    local Game = require("src.core.Game")
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local act = ACT[id] or 1

    _G.EventManager.clear()
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 8
    run.currentNode = { type = "boss", enemyId = id }
    local stats = ActSystem.getEnemyStats(act, 8, "boss")
    game.enemy = EnemyRoster.spawn(Enemy, id, stats, act)
    game.enemy.isBoss = true
    game.messageSystem = nil
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local w, h = love.graphics.getDimensions()
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
    })
    GameplayScene.setGame(game)
    GameplayScene._debugForceBossEntered()
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(1, true)
    return game, act
end

local function shoot(id, kind)
    local MR = require("src.systems.MusicReact")
    local MD = require("src.systems.MusicDirector")
    local ScreenShake = require("src.systems.ScreenShake")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local InteriorFX = require("src.ui.InteriorFX")
    local game, act = mount(id)
    local code = MD.BOSS_TRACKS[id]
    local data = MR.cuesFor(MR.cueKeyFor(code))
    if not data then
        print("[FAIL] sem cues para " .. id)
        return false
    end
    local target
    for _, c in ipairs(data.cues) do
        if c.kind == kind then target = c.t break end
    end
    if not target then
        print("[FAIL] " .. id .. " sem cue " .. kind)
        return false
    end
    local pos = math.max(0, target - 2.5)
    MR.codeProbe = function() return code end
    MR.positionProbe = function() return pos end
    MR.reset()
    local hall = InteriorFX.hallFor(act)
    local w, h = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(w, h)
    local function frame()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        ScreenShake.push()
        GameplayScene.draw()
        ScreenShake.pop()
        love.graphics.setCanvas()
    end
    local dt = 1 / 60
    local function step(secs)
        for _ = 1, math.floor(secs / dt + 0.5) do
            love.timer.step()
            pos = pos + dt
            _G.EventManager.update(dt)
            EnemyRenderer.update(dt)
            InteriorFX.update(dt, hall)
            ScreenShake.update(dt)
            MR.update(dt, { fighting = true, bossId = id, hall = hall })
        end
    end
    local shots = {
        { "1_antes", target - 0.12 },
        { "2_impacto", target + 0.05 },
        { "3_depois_0.3s", target + 0.30 },
        { "4_depois_0.9s", target + 0.90 },
    }
    local images = {}
    for _, s in ipairs(shots) do
        step(s[2] - pos)
        frame()
        local d = canvas:newImageData()
        images[#images + 1] = d
        save(d, ("%s_%s_%s.png"):format(id, kind, s[1]))
    end
    local sheet = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0, 0, 0, 1)
    for i, d in ipairs(images) do
        local img = love.graphics.newImage(d)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, ((i - 1) % 2) * w / 2, math.floor((i - 1) / 2) * h / 2, 0, 0.5, 0.5)
    end
    love.graphics.setCanvas()
    save(sheet:newImageData(), ("%s_%s_sheet.png"):format(id, kind))
    local s = MR.stats()
    print(("[screenshot_musica_reativa] %s %s em %.2fs | cues hit %d drop %d swell %d | tremores %d detritos %d"):format(
        id, kind, target, s.hit, s.drop, s.swell, s.shake, s.debris))
    MR.codeProbe, MR.positionProbe = nil, nil
    MR.reset()
    return true
end

function M.run(which)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    _G.gameSettings.musicReact = true
    _G.gameSettings.screenshake = 1
    local id, kind = (which or "carrion_king"):match("^([%w_]+):?(%a*)$")
    if kind == "" then kind = "drop" end
    return shoot(id or "carrion_king", kind)
end

return M
