local Debug = require("src.core.Debug")

local AppLoop = {}

AppLoop.BACKGROUND_FPS = 15
AppLoop.HIDDEN_FPS     = 8
AppLoop.MAX_DT         = 0.25
AppLoop.NOVSYNC_MIN    = 60
AppLoop.NOVSYNC_MAX    = 240

function AppLoop.frameCap(win, headless)
    if headless then return nil, false end
    if win.minimized or not win.visible then
        return AppLoop.HIDDEN_FPS, true
    end
    if not win.focused then
        return AppLoop.BACKGROUND_FPS, false
    end
    if not win.vsync then
        local hz = tonumber(win.refreshrate) or 0
        if hz <= 0 then hz = AppLoop.NOVSYNC_MIN end
        return math.max(AppLoop.NOVSYNC_MIN, math.min(AppLoop.NOVSYNC_MAX, hz)), false
    end
    return nil, false
end

local winState = { focused = true, visible = true, minimized = false,
                   vsync = true, refreshrate = 60 }
local modeCheckedAt = -math.huge

local function readWindow(now)
    local w = love.window
    if not (w and w.isOpen and w.isOpen()) then
        winState.visible = false
        return winState
    end
    winState.focused   = w.hasFocus()
    winState.visible   = w.isVisible()
    winState.minimized = w.isMinimized and w.isMinimized() or false
    if now - modeCheckedAt > 1 then
        modeCheckedAt = now
        local _, _, flags = w.getMode()
        winState.vsync = (flags.vsync or 0) ~= 0
        winState.refreshrate = flags.refreshrate
    end
    return winState
end

function AppLoop.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end
    local dt = 0
    return function()
        local frameStart = love.timer.getTime()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        AppLoop.shutdown()
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        dt = math.min(love.timer.step(), AppLoop.MAX_DT)
        local cap, skipDraw = AppLoop.frameCap(readWindow(frameStart), _G.HEADLESS_TOOL)

        if love.update then love.update(dt) end
        if not skipDraw and love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then love.draw() end
            love.graphics.present()
        end

        local rest = cap and (1 / cap - (love.timer.getTime() - frameStart)) or 0
        love.timer.sleep(rest > 0.001 and rest or 0.001)
    end
end

local didShutdown = false
function AppLoop.shutdown()
    if didShutdown then return end
    didShutdown = true
    local function step(name, fn)
        local ok, err = pcall(fn)
        if not ok then Debug.warn("[AppLoop] AVISO: shutdown/" .. name .. " falhou: " .. tostring(err)) end
    end
    if not _G.HEADLESS_TOOL then
        step("janela", function()
            local settings = _G.persistedSettings
            if settings and require("src.core.WindowPlacement").remember(settings) then
                require("engine.SaveManager").saveSettings(settings)
            end
        end)
    end
    step("steam", function() require("src.systems.SteamBridge").shutdown() end)
    step("log", function() require("src.core.Release").flushLog() end)
end

function AppLoop.install()
    if AppLoop._installed then return end
    AppLoop._installed = true
    love.run = AppLoop.run
end

return AppLoop
