local M = {}

local DT = 1 / 30

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function pump(secs, pred)
    local t = 0
    while t < secs do
        love.update(DT)
        love.graphics.origin()
        love.draw()
        t = t + DT
        if pred and pred() then return true end
    end
    return pred and pred() or false
end

local function shoot(name, w, h)
    local CRTShader = require("src.ui.CRTShader")
    local canvas = love.graphics.newCanvas(w, h)
    local realEnd = CRTShader.endScene
    CRTShader.endScene = function() return realEnd(canvas) end
    local realSet = love.graphics.setCanvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.update(DT)
    love.graphics.origin()
    local ok, err = pcall(love.draw)
    CRTShader.endScene = realEnd
    realSet()
    if not ok then error(err, 0) end
    local file = ("cheat_%s_%dx%d.png"):format(name, w, h)
    canvas:newImageData():encode("png", file)
    print(love.filesystem.getSaveDirectory() .. "/" .. file)
end

function M.run(arg)
    local w, h = 1600, 900
    local sw, sh = tostring(arg or ""):match("^(%d+)x(%d+)$")
    if sw then w, h = tonumber(sw), tonumber(sh) end
    local restore = fakeWindow(w, h)
    local CheatMode = require("src.systems.CheatMode")
    local ok, err = pcall(function()
        love.load({})
        require("src.i18n.I18n").setLocale(os.getenv("TOOL_LOCALE") or "pt_BR")
        if _G.audioSystem and _G.audioSystem.setMasterVolume then _G.audioSystem:setMasterVolume(0) end
        require("src.ui.UiScale").force(nil)
        love.resize(w, h)
        CheatMode.activate({ isolate = false })
        pump(2, function() return state() ~= "boot" end)
        love.keypressed("return")
        pump(6, function() return state() == "menu" end)
        shoot("menu", w, h)

        api().startGame("warrior", 0)
        pump(30, function() return CheatMode.combatReady(true) end)
        pump(0.6)
        CheatMode.toggleGod()
        shoot("combate", w, h)

        CheatMode.advanceFloor()
        pump(4, function()
            local f = require("src.ui.WorldRoad")._fork
            return f and (f.animIn or 0) >= 1
        end)
        pump(0.5)
        shoot("mapa", w, h)

        CheatMode.panelOpen = false
        shoot("recolhido", w, h)
        CheatMode.panelOpen = true
    end)
    CheatMode.deactivate()
    restore()
    if not ok then
        print("[screenshot_cheat] FALHOU: " .. tostring(err))
        return false
    end
    return true
end

return M
