local M = {}

local VW, VH = 960, 540
local DT = 1 / 30
local ffi = require("ffi")

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function bytes(cv)
    local d = cv:newImageData()
    return d, ffi.cast("const uint8_t*", d:getFFIPointer())
end

local function differs(a, b, o, tol)
    return math.abs(a[o] - b[o]) > tol or math.abs(a[o + 1] - b[o + 1]) > tol or math.abs(a[o + 2] - b[o + 2]) > tol
end

function M.check(act, stage)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local LE = require("engine.LuminaireEngine")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")

    local restore = patchDims(VW, VH)
    local cv = love.graphics.newCanvas(VW, VH)
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct, run.currentNode = act, 3, { type = "battle" }
    local WALKERS = { "hollow_farmer", "ram_cultist", "abyss_acolyte", "rime_shaman", "mire_hag", "dullahan" }
    local spriteId = WALKERS[act]
    game.enemy = EnemyRoster.spawn(Enemy, spriteId, ActSystem.getEnemyStats(act, 3, "battle"))
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
    if game.messageSystem then game.messageSystem.messages = {} end
    GameplayScene.resumeWorld(game)
    WorldRoad._rng:setSeed(4242)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(0.5, true)
    for _ = 1, 20 do WorldRoad.update(DT); EnemyRenderer.update(DT) end
    WorldRoad.travel({
        encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
        onComplete = function() EnemyRenderer.triggerArrival() end,
    })
    local enemyZ
    if stage == "chegada" then
        local i = 0
        while WorldRoad._encounter and WorldRoad._encounter.z - WorldRoad._camZ > WorldRoad.BATTLE_REL + 3 and i < 2000 do
            WorldRoad.update(DT); EnemyRenderer.update(DT); i = i + 1
        end
        enemyZ = WorldRoad._encounter.z
    else
        local i = 0
        while WorldRoad.isTraveling() and i < 2000 do
            WorldRoad.update(DT); EnemyRenderer.update(DT); i = i + 1
        end
        local EE = require("src.ui.EnemyEntrance")
        for _ = 1, 90 do WorldRoad.update(DT); EnemyRenderer.update(DT) end
        local j = 0
        while EE.isActive() and j < 600 do WorldRoad.update(DT); EnemyRenderer.update(DT); j = j + 1 end
        enemyZ = WorldRoad._camZ + WorldRoad.BATTLE_REL
    end
    local bid = ({ "fields", "highlands", "abyss", "frost", "marsh", "dusk" })[act]
    local kind = LE.roadKind(bid)
    local post = { kind = kind, bid = bid, z = enemyZ - 2.5, side = 1, lane = LE.ROAD_LANE,
        variant = 0, big = 1, uid = -77, jitter = 0 }
    local origLat = WorldRoad.postLateral
    WorldRoad.postLateral = function() return 0 end
    local origDraw = EnemyRenderer.draw
    local savedEnc = WorldRoad._encounter
    local function render(withPost, withEnemy)
        local props = WorldRoad._props
        local keep = {}
        for _, p in ipairs(props) do
            if p ~= post and p.kind ~= kind then keep[#keep + 1] = p end
        end
        if withPost then keep[#keep + 1] = post end
        WorldRoad._props = keep
        WorldRoad._encounter = withEnemy and savedEnc or nil
        if not withEnemy then EnemyRenderer.draw = function() return nil end end
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        EnemyRenderer.draw = origDraw
        WorldRoad._encounter = savedEnc
        WorldRoad._props = props
        return bytes(cv)
    end
    local LightEngine = require("engine.LightEngine")
    LightEngine.setEnabled(false)
    local dA, A = render(true, true)
    local pb
    for _, he in ipairs(WorldRoad._hitScene) do
        if he.ref == post then pb = { he.x1, he.y1, he.x2, he.y2 - 4 } end
    end
    if os.getenv("PROF_SAVE") then
        love.filesystem.createDirectory("poste_profundidade")
        dA:encode("png", string.format("poste_profundidade/a%d_%s_A.png", act, stage))
    end
    local dB, B = render(true, false)
    if os.getenv("PROF_SAVE") then dB:encode("png", string.format("poste_profundidade/a%d_%s_B.png", act, stage)) end
    local dC, C = render(false, true)
    if os.getenv("PROF_SAVE") then dC:encode("png", string.format("poste_profundidade/a%d_%s_C.png", act, stage)) end
    local dD, D = render(false, false)
    LightEngine.setEnabled(nil)
    WorldRoad.postLateral = origLat
    restore()
    local overlap, wrong = 0, 0
    for o = 0, VW * VH * 4 - 1, 4 do
        local px = o / 4
        local ix, iy = px % VW, math.floor(px / VW)
        if pb and ix >= pb[1] and ix < pb[3] and iy >= pb[2] and iy < pb[4]
           and differs(B, D, o, 24) and differs(C, D, o, 24) then
            overlap = overlap + 1
            local dB2 = math.abs(A[o] - B[o]) + math.abs(A[o + 1] - B[o + 1]) + math.abs(A[o + 2] - B[o + 2])
            local dC2 = math.abs(A[o] - C[o]) + math.abs(A[o + 1] - C[o + 1]) + math.abs(A[o + 2] - C[o + 2])
            if dB2 > 36 and dC2 < dB2 then
                wrong = wrong + 1
                if os.getenv("PROF_SAVE") then dA:setPixel(ix, iy, 1, 0, 1, 1) end
            end
        end
    end
    if os.getenv("PROF_SAVE") then dA:encode("png", string.format("poste_profundidade/a%d_%s_X.png", act, stage)) end
    dA:release(); dB:release(); dC:release(); dD:release()
    cv:release()
    collectgarbage()
    return overlap, wrong
end

function M.run()
    io.stdout:setvbuf("line")
    local ok = true
    for act = 1, 6 do
        for _, stage in ipairs({ "chegada", "batalha" }) do
            local overlap, wrong = M.check(act, stage)
            local good = overlap >= 80 and wrong <= overlap * 0.03
            ok = ok and good
            print(string.format("[%s] ato %d %s: sobreposicao poste x inimigo %d px, inimigo por cima em %d px (%.1f%%)",
                good and "ok" or "FAIL", act, stage, overlap, wrong, overlap > 0 and wrong * 100 / overlap or 0))
        end
    end
    print(ok and "TOTAL ok" or "TOTAL FAIL")
    return ok
end

return M
