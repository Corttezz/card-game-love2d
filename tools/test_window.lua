local TK = require("tools.testkit")
local Config = require("src.core.Config")

local M = {}

function M.run()
    local t = TK.new("window")
    local f = Config.Utils.tamanhoJanelaInicial

    local w, h = f(1920, 1080, 1024)
    t:eq("1080p: largura", w, 1632)
    t:eq("1080p: altura",  h, 918)

    w, h = f(2560, 1440, 1024)
    t:eq("1440p: largura", w, 2176)
    t:eq("1440p: altura",  h, 1224)

    w, h = f(3024, 1964, 1024)
    t:eq("MacBook Pro 14: largura", w, 2570)
    t:eq("MacBook Pro 14: altura",  h, 1669)

    t:truthy("sobra margem na largura", select(1, f(1920, 1080, 1024)) < 1920)
    t:truthy("sobra margem na altura",  select(2, f(1920, 1080, 1024)) < 1080)

    t:eq("janela ja grande fica quieta", f(1920, 1080, 1632), nil)
    t:eq("janela maior que o alvo fica quieta", f(1920, 1080, 1800), nil)

    t:eq("monitor 800x600 nao e mexido", f(800, 600, 1024), nil)

    t:eq("desktop nil", f(nil, nil, 1024), nil)
    t:eq("desktop zerado", f(0, 0, 1024), nil)
    t:eq("desktop negativo", f(-1920, -1080, 1024), nil)

    t:eq("sem largura atual ainda decide", (f(1920, 1080, nil)), 1632)

    return t:done()
end

return M
