local TK = require("tools.testkit")
local AppLoop = require("src.core.AppLoop")
local WP = require("src.core.WindowPlacement")

local M = {}

local function win(o)
    local w = { focused = true, visible = true, minimized = false, vsync = true, refreshrate = 60 }
    for k, v in pairs(o or {}) do w[k] = v end
    return w
end

function M.run()
    local t = TK.new("app_loop")

    local cap, skip = AppLoop.frameCap(win())
    t:eq("foco + vsync: sem teto (vsync manda)", cap, nil)
    t:eq("foco: desenha", skip, false)

    cap, skip = AppLoop.frameCap(win({ focused = false }))
    t:eq("sem foco: teto de fundo", cap, AppLoop.BACKGROUND_FPS)
    t:eq("sem foco: ainda desenha (cena visivel)", skip, false)

    cap, skip = AppLoop.frameCap(win({ minimized = true, focused = false }))
    t:eq("minimizada: teto oculto", cap, AppLoop.HIDDEN_FPS)
    t:eq("minimizada: nao desenha", skip, true)

    cap, skip = AppLoop.frameCap(win({ visible = false }))
    t:eq("oculta: nao desenha", skip, true)

    t:eq("vsync off: teto na taxa do monitor",
        (AppLoop.frameCap(win({ vsync = false, refreshrate = 144 }))), 144)
    t:eq("vsync off sem taxa conhecida: 60",
        (AppLoop.frameCap(win({ vsync = false, refreshrate = 0 }))), 60)
    t:eq("vsync off 360 Hz: limitado",
        (AppLoop.frameCap(win({ vsync = false, refreshrate = 360 }))), AppLoop.NOVSYNC_MAX)

    t:eq("ferramenta nunca estrangula",
        (AppLoop.frameCap(win({ minimized = true }), true)), nil)
    t:truthy("fundo e bem mais lento que 60", AppLoop.BACKGROUND_FPS <= 20)
    t:truthy("oculta mais lenta que fundo", AppLoop.HIDDEN_FPS <= AppLoop.BACKGROUND_FPS)

    t:truthy("AppLoop instalado", AppLoop._installed == true)

    t:eq("sem monitor salvo: 1", WP.validDisplay({}, 2), 1)
    t:eq("monitor 2 existe: 2", WP.validDisplay({ windowDisplay = 2 }, 2), 2)
    t:eq("monitor 2 sumiu (notebook sem externo): 1", WP.validDisplay({ windowDisplay = 2 }, 1), 1)
    t:eq("lixo no settings: 1", WP.validDisplay({ windowDisplay = "x" }, 3), 1)
    t:eq("indice quebrado: 1", WP.validDisplay({ windowDisplay = 1.5 }, 3), 1)
    t:eq("zero: 1", WP.validDisplay({ windowDisplay = 0 }, 3), 1)

    local x, y = WP.validPosition({ windowX = 100, windowY = 50 }, 1600, 900, 1920, 1080)
    t:eq("posicao que cabe: x", x, 100)
    t:eq("posicao que cabe: y", y, 50)
    t:eq("janela sairia pela direita: centraliza",
        WP.validPosition({ windowX = 900, windowY = 50 }, 1600, 900, 1920, 1080), nil)
    t:eq("posicao negativa: centraliza",
        WP.validPosition({ windowX = -10, windowY = 0 }, 800, 600, 1920, 1080), nil)
    t:eq("sem posicao salva: centraliza",
        WP.validPosition({}, 800, 600, 1920, 1080), nil)

    return t:done()
end

return M
