-- tools/test_navcursor.lua
-- Cursor de foco do teclado/pad (src/ui/NavCursor.lua), isolado: registro de
-- alvos em pixels da tela, vizinho espacial, camadas do InputFocus, foco
-- automático fora da barra do topo, clique sintético no foco, mouse que
-- devolve o controle, recorte por scissor/janela.
--
--   love . test_one test_navcursor
--
-- O fluxo de run inteiro (jogo de verdade) é `love . nav_flow`.

local TK = require("tools.testkit")

local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("cursor de foco (teclado/pad)")
    local NC = require("src.ui.NavCursor")
    local IF = require("src.ui.InputFocus")
    local realPressed, realReleased = love.mousepressed, love.mousereleased
    local clicks = {}
    love.mousepressed = function(x, y, b) clicks[#clicks + 1] = { "p", x, y, b } end
    love.mousereleased = function(x, y, b) clicks[#clicks + 1] = { "r", x, y, b } end

    local ok, err = pcall(function()
        NC._reset()
        IF.resetLayers()
        -- grade 2x2 + item da barra do topo
        -- registra e "fecha" o quadro (beginFrame do próximo)
        NC.beginFrame()
        IF.push(IF.SCENE)
        NC.target("a", 100, 100, 50, 50)
        NC.target("b", 300, 100, 50, 50)
        NC.target("c", 100, 300, 50, 50)
        NC.target("d", 300, 300, 50, 50)
        NC.target("fora", -500, -500, 40, 40)
        love.graphics.setScissor(0, 0, 200, 200)
        NC.target("recortado", 250, 250, 40, 40)
        love.graphics.setScissor()
        IF.pop()
        IF.push(IF.CHROME)
        NC.target("topo", 10, 5, 40, 30)
        IF.pop()
        NC.action("y", function() clicks[#clicks + 1] = { "acao-y" } end, 400, 400, 80, 30)
        NC.beginFrame()

        local keys = {}
        for _, tg in ipairs(NC._targets()) do keys[tg.key] = true end
        t:truthy("alvo fora da tela não entra", not keys.fora)
        t:truthy("alvo recortado pelo scissor não entra", not keys.recortado)
        t:truthy("alvos da cena e do topo entram", keys.a and keys.d and keys.topo)

        t:falsy("começa no modo mouse", NC.isActive())
        NC.intent("down", "keyboard")
        t:truthy("1ª seta liga o modo foco", NC.isActive())
        t:eq("foco automático: conteúdo antes da barra do topo", NC.focusKey(), "a")
        NC.intent("right", "keyboard")
        t:eq("direita → b", NC.focusKey(), "b")
        NC.intent("down", "keyboard")
        t:eq("baixo → d", NC.focusKey(), "d")
        NC.intent("left", "keyboard")
        t:eq("esquerda → c", NC.focusKey(), "c")
        local px, py = NC.position()
        t:eq("o 'mouse' mora no centro do foco (x)", px, 125)
        t:eq("o 'mouse' mora no centro do foco (y)", py, 325)

        clicks = {}
        NC.intent("confirm", "pad")
        t:eq("A sintetiza press+release no foco", #clicks, 2)
        t:truthy("clique no centro do foco", clicks[1] and clicks[1][2] == 125 and clicks[1][3] == 325)
        clicks = {}
        NC.intent("inspect", "pad")
        t:truthy("gatilho = clique direito", clicks[1] and clicks[1][4] == 2)
        clicks = {}
        NC.intent("y", "pad")
        t:truthy("Y roda a ação publicada", clicks[1] and clicks[1][1] == "acao-y")
        t:eq("glifo de pad depois do botão do pad", NC.labelFor("y"), "Y")

        -- barra do topo: só com navegação explícita
        NC.intent("up", "keyboard")
        t:eq("cima → a", NC.focusKey(), "a")
        NC.intent("up", "keyboard")
        t:eq("andando pra cima chega na barra do topo", NC.focusKey(), "topo")

        -- modal por cima: alvos da cena saem
        local modal = { visible = true, isVisible = function(s) return s.visible end }
        IF.clear()
        IF.register("modalTeste", modal)
        t:eq("modal por cima apaga os alvos de trás", #NC._targets(), 0)
        IF.clear()

        -- mouse físico devolve o controle
        NC.mouseMoved(500, 500)
        t:falsy("mexer o mouse desliga o modo foco", NC.isActive())
        t:eq("sem foco, o mouse é o mouse", NC.position(), nil)
        t:eq("glifo de teclado depois do teclado", (NC.intent("down", "keyboard") and NC.labelFor("confirm")), "ENTER")

        t:truthy("telas com navegação própria não são tomadas",
            not NC.claimsInput("gameOver") and not NC.claimsInput("achievements")
            and NC.claimsInput("playing") and not NC.claimsInput("collection", true))
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)
    love.mousepressed, love.mousereleased = realPressed, realReleased
    NC._reset()
    IF.clear()
    return t:done()
end

return M
