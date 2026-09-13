-- tools/test_window.lua
-- Testa com que tamanho a janela deve NASCER.
--
-- Existe porque o defeito é invisível na máquina de quem programa: 1024x768
-- num monitor 1920x1080 parece aceitável, e num 2560x1440 lê como selo
-- postal. O dono pediu que o jogo "nunca abra em modo janela pequeno" em
-- Windows E macOS — ou seja, a regra tem que valer em monitores que eu não
-- tenho. Testar abrindo janela de verdade não serviria: não é reproduzível
-- entre máquinas, e `love.window.setMode` repetido dentro de um tool não
-- retorna (memory/ui_layout_invariants.md).

local TK = require("tools.testkit")
local Config = require("src.core.Config")

local M = {}

function M.run()
    local t = TK.new("window")
    local f = Config.Utils.tamanhoJanelaInicial

    -- Monitores reais, janela nascendo no 1024 do conf.lua.
    local w, h = f(1920, 1080, 1024)
    t:eq("1080p: largura", w, 1632)
    t:eq("1080p: altura",  h, 918)

    w, h = f(2560, 1440, 1024)
    t:eq("1440p: largura", w, 2176)
    t:eq("1440p: altura",  h, 1224)

    -- macOS Retina (o dono joga nos dois sistemas).
    w, h = f(3024, 1964, 1024)
    t:eq("MacBook Pro 14: largura", w, 2570)
    t:eq("MacBook Pro 14: altura",  h, 1669)

    -- Nunca ocupa a tela inteira: barra de tarefas / menu bar / dock.
    t:truthy("sobra margem na largura", select(1, f(1920, 1080, 1024)) < 1920)
    t:truthy("sobra margem na altura",  select(2, f(1920, 1080, 1024)) < 1080)

    -- Só cresce: janela que já está grande não encolhe.
    t:eq("janela ja grande fica quieta", f(1920, 1080, 1632), nil)
    t:eq("janela maior que o alvo fica quieta", f(1920, 1080, 1800), nil)

    -- Monitor pequeno: 85% de 1024x768 daria 870x652, abaixo do minheight
    -- de 600? nao — 652 passa. Ja 800x600 daria 680x510, abaixo do minimo,
    -- e ai NAO se mexe: o setMode devolveria uma janela maior que a pedida
    -- e o layout nasceria com dimensao que a tela nao tem.
    t:eq("monitor 800x600 nao e mexido", f(800, 600, 1024), nil)

    -- Entradas ruins não podem estourar no boot.
    t:eq("desktop nil", f(nil, nil, 1024), nil)
    t:eq("desktop zerado", f(0, 0, 1024), nil)
    t:eq("desktop negativo", f(-1920, -1080, 1024), nil)

    -- Sem largura atual (chamador que não sabe), ainda devolve alvo.
    t:eq("sem largura atual ainda decide", (f(1920, 1080, nil)), 1632)

    return t:done()
end

return M
