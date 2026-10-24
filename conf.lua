local okRelease, Release = pcall(require, "src.core.Release")
if not okRelease then
    Release = nil
end

local function autoHeadless()
    local env = os.getenv("CARDGAME_HEADLESS")
    if env == "1" then return true end
    if env == "0" then return false end
    for _, a in ipairs(arg or {}) do
        if type(a) == "string" and (a:match("^test_") or a:match("^smoke_") or a:match("^screenshot")
            or a:match("^shot_") or a:match("^perf_") or a:match("^probe_") or a:match("^preview_")
            or a:match("^balance") or a:match("^validate") or a:match("^estrada_")) then
            return true
        end
    end
    return false
end

_G.CARDGAME_AUTO_HEADLESS = autoHeadless()

function love.conf(t)
    t.identity = Release and Release.identity() or (os.getenv("CARDGAME_IDENTITY") or "card-game")
    t.version = "11.5"
    t.console = not (Release and Release.isRelease())
    t.accelerometerjoystick = false
    t.externalstorage = false
    t.gammacorrect = false

    t.window.title = "Grimoire"
    t.window.icon = "assets/branding/icon.png"
    t.window.width = 1024
    t.window.height = 768
    t.window.minwidth = 800
    t.window.minheight = 600
    t.window.resizable = true
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = true
    t.window.msaa = 0
    t.window.depth = nil
    t.window.stencil = nil
    t.window.display = 1
    t.window.highdpi = false
    t.window.usedpiscale = true
    t.window.x = nil
    t.window.y = nil

    if _G.CARDGAME_AUTO_HEADLESS and not (Release and Release.isRelease()) then
        t.window.width, t.window.height = 1, 1
        t.window.minwidth, t.window.minheight = 1, 1
        t.window.borderless = true
        t.window.resizable = false
        t.window.vsync = false
        t.window.x, t.window.y = -32000, -32000
        t.window.icon = nil
        t.console = false
    end

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end
