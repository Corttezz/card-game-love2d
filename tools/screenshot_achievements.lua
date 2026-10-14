local M = {}

local I18n              = require("src.i18n.I18n")
local AchievementSystem = require("src.systems.AchievementSystem")
local ProfileStats      = require("engine.ProfileStats")
local Defs              = require("src.data.achievements")

local ALL = { "pt_BR", "en", "es", "fr", "de" }
local SIZES = { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 720, 640 } }

local function seedProfile()
    local s = ProfileStats.get()
    s.achievements, s.achievementDates = {}, {}
    s.counters = { cardsPlayed = 1840, forges = 11, bestEndlessFloor = 4 }
    s.wins = 3
    s.winsByClass = { warrior = true, mage = true }
    local now = os.time()
    for i, d in ipairs(Defs) do
        if i % 2 == 1 and d.id ~= "alem_da_pagina" then
            s.achievements[d.id] = true
            s.achievementDates[d.id] = now - i * 86400
        end
    end
    s.achievements.fio_navalha = true
    s.achievementDates.fio_navalha = now
    s.achievements.maos_limpas = nil
end

local function withSize(w, h, fn)
    local gw, gh = love.graphics.getWidth, love.graphics.getHeight
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.06, 0.05, 1)
    local ok, err = pcall(fn)
    love.graphics.setCanvas()
    love.graphics.getWidth, love.graphics.getHeight = gw, gh
    if not ok then error(err) end
    return canvas
end

local function save(canvas, name)
    canvas:newImageData():encode("png", name)
    print("[conquistas] " .. name .. " salvo")
end

function M.run(arg)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    seedProfile()

    local screen = require("components.AchievementsScreen"):new()
    screen:show(function() end)
    screen.t = 0.4

    local locales, sizes
    if arg == "all" then
        locales, sizes = ALL, { { 1280, 720 } }
    else
        locales, sizes = { arg or "pt_BR" }, SIZES
    end

    for _, loc in ipairs(locales) do
        I18n.setLocale(loc)
        screen:_refresh()
        for i, e in ipairs(screen.entries) do
            if e.id == "escriba" then screen.selected = i end
        end
        for _, sz in ipairs(sizes) do
            save(withSize(sz[1], sz[2], function() screen:draw() end),
                ("achievements_%s_%dx%d.png"):format(loc, sz[1], sz[2]))
        end
        local Toast = require("src.ui.AchievementToast")
        Toast.clear()
        Toast.push({ id = "golpe_tinta", name = AchievementSystem.nameOf("golpe_tinta"),
            desc = AchievementSystem.descOf("golpe_tinta"), tier = "skill" })
        Toast.update(0)
        Toast.update(Toast.IN + 0.9)
        save(withSize(1280, 720, function() Toast.draw() end),
            ("achievements_toast_%s.png"):format(loc))
        Toast.clear()
    end

    love.event.quit()
end

return M
