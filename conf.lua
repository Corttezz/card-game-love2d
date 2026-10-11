-- DEV x RELEASE vem de src/core/Release.lua (flag unica: build_info.lua, que
-- so o tools/build_release.py escreve). conf.lua roda antes dos modulos
-- love.*, e o Release nao toca nenhum no carregamento.
local okRelease, Release = pcall(require, "src.core.Release")
if not okRelease then
    print("[conf] src.core.Release falhou: " .. tostring(Release))
    Release = nil
end

function love.conf(t)
    -- Save dir: DEV "card-game" (historico), RELEASE "Grimoire".
    -- CARDGAME_IDENTITY sobrepoe (frentes paralelas/smoke nao pisam no save real).
    t.identity = Release and Release.identity() or (os.getenv("CARDGAME_IDENTITY") or "card-game")
    t.version = "11.5"                          -- The LÖVE version this game was made for (string)
    -- Console so em DEV: o executavel publicado nao abre janela preta junto.
    t.console = not (Release and Release.isRelease())
    t.accelerometerjoystick = false            -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
    t.externalstorage = false                   -- True to save files (and read from the save directory) in external storage on Android (boolean) 
    t.gammacorrect = false                      -- Enable gamma-correct rendering, when supported by the system (boolean)

    t.window.title = "Grimoire"                  -- The window title (string)
    t.window.icon = "assets/branding/icon.png"  -- Icone da janela/barra de tarefas (o .exe usa assets/branding/icon.ico via rcedit)
    t.window.width = 1024                       -- The window width (number)
    t.window.height = 768                       -- The window height (number)
    t.window.minwidth = 800                     -- Minimum window width if resizable (number)
    t.window.minheight = 600                    -- Minimum window height if resizable (number)
    t.window.resizable = true                   -- Let the window be user-resizable (boolean)
    t.window.fullscreen = false                 -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop"         -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    t.window.vsync = true                       -- Enable vertical sync (boolean)
    t.window.msaa = 0                           -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.depth = nil                        -- The number of bits per sample in the depth buffer (number)
    t.window.stencil = nil                      -- The number of bits per sample in the stencil buffer (number)
    t.window.display = 1                        -- Index of the monitor to show the window in (number)
    t.window.highdpi = false                    -- Enable high-DPI support for the window on a Retina display (boolean)
    t.window.usedpiscale = true                 -- Enable automatic DPI scaling when highdpi is set to true as well (boolean)
    t.window.x = nil                            -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil                            -- The y-coordinate of the window's position in the specified display (number)

    t.modules.audio = true                      -- Enable the audio module (boolean)
    t.modules.data = true                       -- Enable the data module (boolean)
    t.modules.event = true                      -- Enable the event module (boolean)
    t.modules.font = true                       -- Enable the font module (boolean)
    t.modules.graphics = true                   -- Enable the graphics module (boolean)
    t.modules.image = true                      -- Enable the image module (boolean)
    t.modules.joystick = true                   -- Enable the joystick module (boolean)
    t.modules.keyboard = true                   -- Enable the keyboard module (boolean)
    t.modules.math = true                       -- Enable the math module (boolean)
    t.modules.mouse = true                      -- Enable the mouse module (boolean)
    t.modules.physics = false                   -- Enable the physics module (boolean)
    t.modules.sound = true                      -- Enable the sound module (boolean)
    t.modules.system = true                     -- Enable the system module (boolean)
    t.modules.thread = true                     -- Enable the thread module (boolean)
    t.modules.timer = true                      -- Enable the timer module (boolean)
    t.modules.touch = false                     -- Enable the touch module (boolean)
    t.modules.video = false                     -- Enable the video module (boolean)
    t.modules.window = true                     -- Enable the window module (boolean)
end
