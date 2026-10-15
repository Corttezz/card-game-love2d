local M = {}

local function outDir(label)
    local d = love.filesystem.getSource() .. "/tools/preview_out/descobertas/" .. label .. "/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function save(cv, dir, name)
    local f = assert(io.open(dir .. name, "wb"))
    f:write(cv:newImageData():encode("png"):getString())
    f:close()
    print("[screenshot_descobertas] " .. dir .. name)
end

local function seeCards(game)
    local BoosterPackSystem = require("src.systems.BoosterPackSystem")
    for _ = 1, 4 do game.shopSystem:generateCardOffer() end
    BoosterPackSystem.generateContents({ kind = "Standard", size = 3, classId = "warrior" })
end

local function newRun(seed)
    local TK = require("tools.testkit")
    TK.seedRng(seed)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    return game
end

local function endScreen(cv, dir, name, game)
    local EndScreens = require("src.scenes.EndScreens")
    local UnlockReveal = require("src.ui.UnlockReveal")
    local EventManager = require("engine.EventManager")
    UnlockReveal.dtOverride = 1 / 60
    EndScreens._enter("gameOver", game, 0)
    for _ = 1, 300 do
        EventManager.update(1 / 60)
        love.graphics.setCanvas(cv)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        EndScreens.drawGameOver(game)
        love.graphics.setCanvas()
    end
    UnlockReveal.dtOverride = nil
    save(cv, dir, name)
end

function M.run(label)
    label = label or "depois"
    local dir = outDir(label)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("pt_BR", true)
    require("src.ui.PixelCanvas").enableNearest()
    local ProfileStats = require("engine.ProfileStats")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local UnlockQueue = require("src.systems.UnlockQueue")
    UnlockSystem.setOverrideAll(false)
    local w, h = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(w, h)

    local prev = ProfileStats._swapForTests({ runs = 0 })
    UnlockSystem._resetForTests()
    UnlockSystem.ensure()
    local game = newRun(5150)
    seeCards(game)
    game.runManager.currentRun.floorInAct = 4
    game.score = 820
    game.unlockResult = UnlockSystem.onRunEnded(game:_unlockSummary(false))
    endScreen(cv, dir, "1_fim_morte_so_descobertas.png", game)

    ProfileStats._swapForTests({ runs = 0 })
    UnlockSystem._resetForTests()
    UnlockSystem.ensure()
    UnlockQueue.clear()
    ProfileStats.get().unlocks.mastery.warrior = 90
    game = newRun(5151)
    seeCards(game)
    game.runManager.currentRun.floorInAct = 4
    game.score = 910
    game.unlockResult = UnlockSystem.onRunEnded(game:_unlockSummary(false))
    endScreen(cv, dir, "2_fim_morte_com_desbloqueio.png", game)

    local Menu = require("components.Menu")
    local menu = Menu:new()
    for _ = 1, 72 do
        _G.EventManager.update(1 / 30)
        menu:update(1 / 30)
    end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    love.graphics.setCanvas()
    save(cv, dir, "3_menu_marca_colecao.png")

    local Showcase = require("components.UnlockShowcase")
    local s = Showcase:new()
    s:watch("menu", 1)
    for _ = 1, 40 do s:update(1 / 30) end
    for _ = 1, 3 do
        if s.visible and s:_card() then break end
        s:advance()
        for _ = 1, 40 do s:update(1 / 30) end
    end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    s:draw()
    love.graphics.setCanvas()
    save(cv, dir, "4_revelacao_desbloqueio.png")
    UnlockQueue.clear()

    local CollectionScreen = require("components.CollectionScreen")
    local screen = CollectionScreen:new()
    screen:show(function() end)
    local guard = 0
    while not screen._buildDone and guard < 4000 do
        screen:_buildInstances(0.05); guard = guard + 1
    end
    screen:_applyFilter()
    screen.filter = "warrior"
    screen:_applyFilter()
    local origPos = love.mouse.getPosition
    love.mouse.getPosition = function() return 2, 2 end
    for _ = 1, 30 do screen:update(1 / 60) end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    save(cv, dir, "5_colecao_tres_estados.png")

    local target
    for i, inst in ipairs(screen.filtered) do
        if inst._hidden and inst._locked then target = i; break end
    end
    if target and screen.cardRectFor then
        local r = screen:cardRectFor(target)
        love.mouse.getPosition = function() return r.x + r.w / 2, r.y + r.h / 2 end
    elseif target then
        local W = love.graphics.getWidth()
        local col, row = (target - 1) % 5, math.floor((target - 1) / 5)
        local ox = (W - (5 * 128 + 4 * 18)) / 2
        love.mouse.getPosition = function() return ox + col * 146 + 64, 120 + row * 216 + 96 end
    end
    for _ = 1, 30 do screen:update(1 / 60) end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    save(cv, dir, "6_colecao_bloqueada_hover.png")
    love.mouse.getPosition = origPos

    ProfileStats._swapForTests(prev)
    UnlockSystem._resetForTests()
    UnlockSystem.setOverrideAll(true)
    return true
end

return M
