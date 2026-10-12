-- tools/screenshot_uiscale.lua
-- Capturas da ESCALA DE UI (src/ui/UiScale.lua) em vários tamanhos, num só
-- processo, com a janela FALSIFICADA (getWidth/getHeight) e render em
-- canvas — sem love.window.setMode (repetido dentro de tool trava).
--
--   love . test_one screenshot_uiscale             → pt_BR, todas as telas, 5 tamanhos
--   love . test_one screenshot_uiscale de          → outro idioma
--   love . test_one screenshot_uiscale pt_BR:shop  → só uma tela
--
-- Saída: uiscale_<tela>_<W>x<H>_<loc>.png no save dir.

local M = {}

local SIZES = {
    { 1024, 768 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 },
}

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function simulate(obj, secs)
    for _ = 1, math.floor(secs * 30) do
        if _G.EventManager then _G.EventManager.update(1 / 30) end
        if obj and obj.update then obj:update(1 / 30) end
    end
end

function M.run(arg)
    local locale, only = tostring(arg or "pt_BR"):match("^([^:]+):?(.*)$")
    if only == "" then only = nil end
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(locale)
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    do
        local run = game.runManager.currentRun
        for _, id in ipairs({ "warrior_strike", "attack_001", "defense_001", "warrior_defend",
                              "warrior_strike", "defense_001", "attack_001", "warrior_defend" }) do
            table.insert(run.currentDeck, id)
        end
        run.actNumber, run.floorInAct = 2, 5
        if game.economySystem then game.economySystem.currentGold = 30 end
        local Rng = require("src.systems.Rng")
        Rng.setActive(Rng.new(4242))
    end

    local shots = {}
    local function add(name, prep)
        if not only or only == name then shots[#shots + 1] = { name = name, prep = prep } end
    end
    local TopBar = require("components.TopBar")

    add("menu", function()
        local m = require("components.Menu"):new(); simulate(m, 2.4); return m
    end)
    add("class", function()
        local cs = require("components.ClassSelectionScreen"):new()
        cs:show(function() end, function() end); simulate(cs, 1.0); return cs
    end)
    add("settings", function()
        local sm = require("components.SettingsMenu"):new(); sm:show(); sm:setTab(2); simulate(sm, 0.5); return sm
    end)
    add("pause", function()
        local p = require("components.PauseMenu"):new(); p:show(game, {}); simulate(p, 0.5); return p
    end)
    add("shop", function()
        local s = require("components.CardRewardScreen"):new(game.shopSystem)
        s:show(game, function() end, function() end, "shop"); simulate(s, 1.4)
        return s, true
    end)
    add("rewards", function()
        local s = require("components.CardRewardScreen"):new(game.shopSystem)
        s:show(game, function() end, function() end, "rewards"); simulate(s, 1.4)
        return s, true
    end)
    add("rest", function()
        local r = require("components.RestScreen"):new(); r:show(game, function() end)
        simulate(r, 0.8); return r, true
    end)
    add("event", function()
        local Events = require("src.data.events")
        local ev = Events.roll(1)
        local e = require("components.EventScreen"):new(); e:show(ev, game, function() end)
        simulate(e, 0.8); return e, true
    end)
    add("deck", function()
        local d = require("components.DeckViewerScreen"):new(); d:show(game); simulate(d, 0.5); return d
    end)
    add("jokers", function()
        local j = require("components.JokerManagerScreen"):new(); j:show(game); simulate(j, 0.5); return j
    end)
    add("journal", function()
        local j = require("components.RunJournalScreen"):new(); j:show(game); simulate(j, 0.5); return j
    end)
    add("collection", function()
        local c = require("components.CollectionScreen"):new(); c:show(function() end)
        simulate(c, 0.8); return c
    end)
    add("achievements", function()
        local a = require("components.AchievementsScreen"):new(); a:show(function() end)
        simulate(a, 0.3); return a
    end)
    add("gameover", function()
        return { draw = function() require("src.scenes.EndScreens").drawGameOver(game) end }
    end)

    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local restore = fakeWindow(w, h)
        FontManager.clearCache()
        for _, shot in ipairs(shots) do
            local ok, err = pcall(function()
                local screen, withBar = shot.prep()
                local canvas = love.graphics.newCanvas(w, h)
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0.16, 0.12, 0.09, 1)
                screen:draw()
                if withBar then
                    UiScale.setChromeScaled(true)
                    local tb = TopBar:new(); tb:setGame(game); tb:update(1 / 30, game); tb:draw()
                end
                love.graphics.setCanvas()
                local name = ("uiscale_%s_%dx%d_%s.png"):format(shot.name, w, h, locale)
                canvas:newImageData():encode("png", name)
                print("[uiscale] " .. name .. "  k=" .. UiScale.k(w, h))
                if screen.hide then pcall(screen.hide, screen) end
            end)
            if not ok then
                love.graphics.setCanvas()
                UiScale.reset()
                print("[uiscale] " .. shot.name .. " " .. w .. "x" .. h .. " FALHOU: " .. tostring(err))
            end
        end
        restore()
    end
    FontManager.clearCache()
    return true
end

return M
