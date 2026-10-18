local M = {}

local function outDir(sub)
    local d = love.filesystem.getSource() .. "/tools/preview_out/musica_reativa/"
    if sub then d = d .. sub .. "/" end
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function save(imageData, name, sub)
    local dir = outDir(sub)
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

local function session(id, kind)
    local MR = require("src.systems.MusicReact")
    local MD = require("src.systems.MusicDirector")
    local ScreenShake = require("src.systems.ScreenShake")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local InteriorFX = require("src.ui.InteriorFX")
    local SceneBackground = require("src.ui.SceneBackground")
    local game, act = mount(id)
    local code = MD.BOSS_TRACKS[id]
    if not (code and love.filesystem.getInfo("audio/music/" .. MD.bossFile(id))) then
        code = "musicBoss"
    end
    local data = MR.cuesFor(MR.cueKeyFor(code))
    if not data then
        print("[FAIL] sem cues para " .. id)
        return nil
    end
    local target
    for _, c in ipairs(data.cues) do
        if c.kind == kind then target = c.t break end
    end
    if not target then
        print("[FAIL] " .. id .. " sem cue " .. kind)
        return nil
    end
    local S = { id = id, kind = kind, target = target, pos = math.max(0, target - 2.5) }
    MR.codeProbe = function() return code end
    MR.positionProbe = function() return S.pos end
    MR.reset()
    MR.resetStats()
    local hall = InteriorFX.hallFor(act)
    local w, h = love.graphics.getDimensions()
    S.w, S.h = w, h
    S.tr = SceneBackground.getCoverTransform("castle_hall_" .. hall, w, h)
    S.canvas = love.graphics.newCanvas(w, h)
    function S.frame()
        love.graphics.setCanvas(S.canvas)
        love.graphics.clear(0, 0, 0, 1)
        ScreenShake.push()
        GameplayScene.draw()
        ScreenShake.pop()
        love.graphics.setCanvas()
        return S.canvas:newImageData()
    end
    local dt = 1 / 60
    function S.stepTo(t)
        for _ = 1, math.floor((t - S.pos) / dt + 0.5) do
            love.timer.step()
            S.pos = S.pos + dt
            _G.EventManager.update(dt)
            EnemyRenderer.update(dt)
            InteriorFX.update(dt, hall)
            ScreenShake.update(dt)
            MR.update(dt, { fighting = true, bossId = id, hall = hall })
        end
    end
    function S.close()
        local s = MR.stats()
        print(("[screenshot_musica_reativa] %s %s em %.2fs | cues hit %d drop %d swell %d | tremores %d detritos %d"):format(
            id, kind, target, s.hit, s.drop, s.swell, s.shake, s.debris))
        MR.codeProbe, MR.positionProbe = nil, nil
        MR.reset()
    end
    return S
end

local function shoot(id, kind)
    local S = session(id, kind)
    if not S then return false end
    local target, w, h = S.target, S.w, S.h
    local shots = {
        { "1_antes", target - 0.12 },
        { "2_impacto", target + 0.05 },
        { "3_depois_0.3s", target + 0.30 },
        { "4_depois_0.9s", target + 0.90 },
    }
    local images = {}
    for _, s in ipairs(shots) do
        S.stepTo(s[2])
        local d = S.frame()
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
    S.close()
    return true
end

local function grid(images, cols, rx, ry, rw, rh, k, pad)
    local cw, ch = math.floor(rw * k), math.floor(rh * k)
    local rows = math.ceil(#images / cols)
    local sheet = love.graphics.newCanvas(cols * (cw + pad) + pad, rows * (ch + pad) + pad)
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0.08, 0.08, 0.08, 1)
    love.graphics.setColor(1, 1, 1, 1)
    for i, d in ipairs(images) do
        local img = love.graphics.newImage(d)
        img:setFilter("nearest", "nearest")
        local q = love.graphics.newQuad(rx, ry, rw, rh, img:getWidth(), img:getHeight())
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        love.graphics.draw(img, q, pad + col * (cw + pad), pad + row * (ch + pad), 0, k, k)
    end
    love.graphics.setCanvas()
    return sheet:newImageData()
end

local function shootSeq(id, kind, label)
    local S = session(id, kind)
    if not S then return false end
    local sub = "polish/" .. (label or "depois")
    local tr, target = S.tr, S.target
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    local seq = {}
    for i = 0, 7 do
        S.stepTo(target - 0.1 + i * 0.1)
        seq[#seq + 1] = S.frame()
    end
    local hx, hy = math.floor(ox + 40 * s), math.floor(oy + 10 * s)
    local hw, hh = math.floor(320 * s), math.floor(236 * s)
    save(grid(seq, 4, hx, hy, hw, hh, 0.5, 6), ("%s_%s_seq.png"):format(id, kind), sub)
    local cx, cy = math.floor(ox + 140 * s), math.floor(oy + 12 * s)
    save(grid(seq, 4, cx, cy, math.floor(120 * s), math.floor(70 * s), 1, 6),
        ("%s_%s_teto1x.png"):format(id, kind), sub)
    local floor = {}
    for _, t in ipairs({ 1.1, 1.5, 2.2 }) do
        S.stepTo(target + t)
        floor[#floor + 1] = S.frame()
    end
    local fx, fy = math.floor(ox + 110 * s), math.floor(oy + 178 * s)
    save(grid(floor, 1, fx, fy, math.floor(180 * s), math.floor(60 * s), 2, 6),
        ("%s_%s_chao2x.png"):format(id, kind), sub)
    S.close()
    return true
end

local function perf(id, kind)
    local S = session(id, kind)
    if not S then return false end
    local CD = require("engine.CeilingDebris")
    local MR = require("src.systems.MusicReact")
    local function measure(label, n, before)
        local samples = {}
        local dc = 0
        for i = 1, n do
            if before then before() end
            local s0 = love.graphics.getStats().drawcalls
            local t0 = love.timer.getTime()
            S.frame()
            love.graphics.flushBatch()
            samples[#samples + 1] = (love.timer.getTime() - t0) * 1000
            dc = love.graphics.getStats().drawcalls - s0
            S.stepTo(S.pos + 1 / 60)
        end
        table.sort(samples)
        print(("[perf] %-28s med %5.2f ms  p95 %5.2f ms  draws %4d  detritos vivos %3d"):format(
            label, samples[math.ceil(#samples / 2)], samples[math.ceil(#samples * 0.95)], dc, CD.count()))
    end
    S.stepTo(S.target - 0.5)
    measure("salao sem detrito (repouso)", 60, function() CD.clear() end)
    S.stepTo(S.target + 0.35)
    measure("salao no drop (+0,35 s)", 40)
    S.stepTo(S.target + 1.2)
    measure("salao no quique (+1,2 s)", 40)
    local saved = MR.draw
    MR.draw = function() end
    S.stepTo(S.target + 1.3)
    measure("mesmo quadro sem desenhar", 40)
    MR.draw = saved
    S.close()
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
    local parts = {}
    for p in tostring(which or "carrion_king"):gmatch("[^:]+") do parts[#parts + 1] = p end
    local id = parts[1] or "carrion_king"
    local kind = (parts[2] and parts[2] ~= "") and parts[2] or "drop"
    if parts[3] == "seq" then
        return shootSeq(id, kind, parts[4])
    elseif parts[3] == "perf" then
        return perf(id, kind)
    end
    return shoot(id, kind)
end

return M
