local M = {}

local SIZES = { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }

local SEEN = {
    "cursed_scarecrow", "hollow_farmer", "plague_rats", "harvest_reaper", "wicker_effigy", "carrion_king",
    "moon_gargoyle", "storm_harpy", "rune_golem", "tower_lich",
    "ember_imp", "hellhound", "pit_brute",
}
local DEFEATED = { "cursed_scarecrow", "hollow_farmer", "plague_rats", "harvest_reaper", "carrion_king", "moon_gargoyle" }
local KILLED = { "harvest_reaper", "carrion_king" }
local FRESH_KEEP = { storm_harpy = true, tower_lich = true, ember_imp = true, hellhound = true, pit_brute = true }

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function seedProfile(Bestiary)
    for _, id in ipairs(SEEN) do Bestiary.markSeen(id) end
    for _, id in ipairs(SEEN) do Bestiary.markSeen(id) end
    for _, id in ipairs(DEFEATED) do Bestiary.markDefeated(id) end
    for _, id in ipairs(DEFEATED) do Bestiary.markDefeated(id) end
    Bestiary.markDefeated("carrion_king")
    for _, id in ipairs(KILLED) do Bestiary.markKilledYou(id) end
    for _, id in ipairs(SEEN) do
        if not FRESH_KEEP[id] then Bestiary.clearNew(id) end
    end
end

function M.run(arg)
    local locale = tostring(arg or "pt_BR")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(locale)
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    UiScale.adoptDefaults()
    local ProfileStats = require("engine.ProfileStats")
    local prevProfile = ProfileStats._swapForTests({})
    local Bestiary = require("src.systems.Bestiary")
    Bestiary._resetForTests()
    Bestiary.resetRun({})
    seedProfile(Bestiary)
    local Sprites = require("src.ui.BestiarySprites")

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("mage")
    game:startGame()
    _G.game = game
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 2, 6
    run.turnsTotal, run.playSeconds = 87, 1934
    game.enemy.spriteId = "tower_lich"
    Bestiary.attachRun(run)
    for _, id in ipairs({ "storm_harpy", "tower_lich", "ember_imp" }) do run.bestiaryNew[#run.bestiaryNew + 1] = id end

    love.filesystem.createDirectory("bestiario")
    local outs = {}
    local function shoot(name, w, h, draw)
        local canvas = love.graphics.newCanvas(w, h)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.05, 0.04, 0.08, 1)
        draw()
        love.graphics.setCanvas()
        local file = ("bestiario/%s_%dx%d_%s.png"):format(name, w, h, locale)
        canvas:newImageData():encode("png", file)
        canvas:release()
        outs[#outs + 1] = file
        print("[bestiario] " .. file)
    end

    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local restore = fakeWindow(w, h)
        FontManager.clearCache()
        local okRun, err = pcall(function()
            local mx, my = -100, -100
            local realMouse = love.mouse.getPosition
            love.mouse.getPosition = function() return mx, my end
            local c = require("components.CollectionScreen"):new()
            c:show(function() end)
            c:setSection("creatures")
            for _ = 1, 400 do
                c:update(1 / 30)
                Sprites.pump(1)
                if Sprites.pendingCount() == 0 then break end
            end
            for _ = 1, 20 do c:update(1 / 30) end
            shoot("aba", w, h, function() c:draw() end)
            c.bestiary.scrollY = 9999
            c:draw()
            c:update(1 / 30)
            shoot("aba_fim", w, h, function() c:draw() end)
            c.bestiary.scrollY = 0
            local function openId(id)
                for i, e in ipairs(c.bestiary.entries) do
                    if e.id == id then c.bestiary:open(i) end
                end
                for _ = 1, 20 do c:update(1 / 30) end
            end
            openId("cursed_scarecrow")
            shoot("ficha_comum", w, h, function() c:draw() end)
            c.bestiary:close()
            openId("carrion_king")
            shoot("ficha_chefe", w, h, function() c:draw() end)
            c.bestiary:close()
            openId("tower_lich")
            shoot("ficha_chefe_invicto", w, h, function() c:draw() end)
            c.bestiary:close()
            c:hide()
            love.mouse.getPosition = realMouse
            local ES = require("src.scenes.EndScreens")
            ES._enter("gameOver", game, 2)
            shoot("fim_corrida", w, h, function() ES.drawGameOver(game) end)
        end)
        if not okRun then
            love.graphics.setCanvas()
            UiScale.reset()
            print("[bestiario] FALHOU " .. w .. "x" .. h .. ": " .. tostring(err))
        end
        restore()
    end
    ProfileStats._swapForTests(prevProfile)
    FontManager.clearCache()
    print("[bestiario] TOTAL " .. #outs .. " em " .. love.filesystem.getSaveDirectory() .. "/bestiario")
    return true
end

return M
