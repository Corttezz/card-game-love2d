-- tools/test_input_focus.lua
-- Regressão do FOCO DE ENTRADA (bug do dono, Set/2026: "quando estou dentro
-- do menu de pausa o hover continua pegando elementos de trás").
--
-- O que este teste trava, nesta ordem:
--   1. o portão do mouse (src/ui/InputFocus): com overlay visível, quem
--      desenha na camada de trás lê o mouse FORA DA TELA;
--   2. o efeito disso em componentes REAIS (Button do projeto e as rows do
--      PauseMenu de verdade) — hover morre atrás, vive dentro do modal;
--   3. a VOLTA sem mexer o mouse: fechado o overlay, o hover de trás acende
--      no frame seguinte (hover preso apagado é o defeito inverso);
--   4. a distinção modal × cobertura: a TopBar (camada CHROME) morre sob a
--      pausa e sobrevive sob a loja/descanso/mapa;
--   5. a FIAÇÃO no main.lua — porque o mecanismo pode estar perfeito e o
--      dispatch não usá-lo. Sem esta parte, reverter o main.lua passaria.
--
-- Roda: love . test_one test_input_focus

local TK = require("tools.testkit")
local M = {}

-- Overlay de mentira: só precisa responder isVisible().
local function fakeOverlay()
    local o = { visible = false }
    function o:isVisible() return self.visible end
    return o
end

-- Mouse falso + portão instalado do MESMO jeito que o main.lua instala.
local function installFakeMouse(IF)
    local pos = { x = 0, y = 0 }
    local saved = {
        getPosition = love.mouse.getPosition,
        getX = love.mouse.getX,
        getY = love.mouse.getY,
    }
    IF.installMouseGate(nil, function() return pos.x, pos.y end)
    return pos, function()
        love.mouse.getPosition = saved.getPosition
        love.mouse.getX = saved.getX
        love.mouse.getY = saved.getY
    end
end

function M.run()
    local t = TK.new("foco de entrada (overlay captura o hover)")

    local IF = require("src.ui.InputFocus")
    local Button = require("components.Button")

    IF.clear()
    IF.resetLayers()
    local mouse, restoreMouse = installFakeMouse(IF)

    local ok, err = pcall(function()
        -- ===== 1. o portão =====
        local overlay = fakeOverlay()
        IF.register("scene_cover", overlay)

        mouse.x, mouse.y = 150, 120

        IF.push(IF.SCENE)
        local gx, gy = love.mouse.getPosition()
        t:eq("sem overlay: a cena le o mouse de verdade (x)", gx, 150)
        t:eq("sem overlay: a cena le o mouse de verdade (y)", gy, 120)

        overlay.visible = true
        gx, gy = love.mouse.getPosition()
        t:eq("overlay visivel: a cena le FORA da tela (x)", gx, IF.OFFSCREEN)
        t:eq("overlay visivel: a cena le FORA da tela (y)", gy, IF.OFFSCREEN)
        t:eq("getX segue o portao", love.mouse.getX(), IF.OFFSCREEN)
        t:eq("getY segue o portao", love.mouse.getY(), IF.OFFSCREEN)
        IF.pop()

        -- Dentro do overlay o mouse é real (o hover DELE tem que funcionar).
        IF.push("scene_cover")
        gx, gy = love.mouse.getPosition()
        t:eq("dentro do overlay: mouse real (x)", gx, 150)
        t:eq("dentro do overlay: mouse real (y)", gy, 120)
        IF.pop()

        -- Sem camada declarada (cursor do mouse, chrome global): nunca bloqueia.
        t:truthy("camada nenhuma = sempre permitido (cursor)", IF.allows(nil))
        local cx = love.mouse.getPosition()
        t:eq("fora de camada: mouse real", cx, 150)

        -- ===== 2. componente REAL atrás vs dentro =====
        local atras  = Button:new(100, 100, 200, 50, "atras", function() end)
        local dentro = Button:new(100, 100, 200, 50, "dentro", function() end)
        atras:setVariant("invisible")   -- sem som de hover no teste
        dentro:setVariant("invisible")

        overlay.visible = false
        IF.push(IF.SCENE); atras:update(0.016); IF.pop()
        t:truthy("botao da cena: hover ON com overlay fechado", atras.hover)

        overlay.visible = true
        IF.push(IF.SCENE); atras:update(0.016); IF.pop()
        t:falsy("botao da cena: hover OFF com overlay aberto", atras.hover)

        IF.push("scene_cover"); dentro:update(0.016); IF.pop()
        t:truthy("botao DO overlay: hover ON (hover interno preservado)",
            dentro.hover)

        -- ===== 3. a volta, SEM mexer o mouse =====
        overlay.visible = false
        IF.push(IF.SCENE); atras:update(0.016); IF.pop()
        t:truthy("fechou o overlay: hover de tras volta sem mexer o mouse",
            atras.hover)

        -- ===== 4. prioridade + modal x cobertura =====
        IF.clear()
        local cobertura = fakeOverlay()   -- loja/descanso/mapa
        local modal     = fakeOverlay()   -- pausa/configuracoes
        IF.register("cobertura", cobertura, { keepChrome = true })
        IF.register("modal", modal)

        cobertura.visible = true
        t:eq("cobertura visivel e o topo", IF.activeName(), "cobertura")
        t:truthy("cobertura: TopBar (CHROME) continua viva", IF.allows(IF.CHROME))
        t:falsy("cobertura: a CENA atras esta bloqueada", IF.allows(IF.SCENE))
        t:falsy("cobertura NAO captura eventos (o estado roteia)", IF.captor())

        modal.visible = true
        t:eq("modal registrado depois tem prioridade", IF.activeName(), "modal")
        t:falsy("modal: TopBar (CHROME) apagada", IF.allows(IF.CHROME))
        t:falsy("modal: a cobertura de baixo tambem apaga", IF.allows("cobertura"))
        t:truthy("modal: a propria camada enxerga", IF.allows("modal"))
        t:truthy("modal CAPTURA eventos", IF.captor() ~= nil)

        modal.visible = false
        cobertura.visible = false
        t:falsy("nada visivel: sem foco", IF.activeName())
        t:truthy("nada visivel: cena liberada", IF.allows(IF.SCENE))

        -- ===== 5. o PauseMenu de verdade =====
        IF.clear()
        local PauseMenu = require("components.PauseMenu")
        local pause = PauseMenu:new()
        IF.register("pause", pause)
        pause:show(nil, {})
        t:truthy("PauseMenu montou rows", #pause.rows > 0)

        local row = pause.rows[1]
        mouse.x = row.x + math.floor(row.w / 2)
        mouse.y = row.y + math.floor(row.h / 2)

        local fundo = Button:new(row.x, row.y, row.w, row.h, "fundo", function() end)
        fundo:setVariant("invisible")
        IF.push(IF.SCENE); fundo:update(0.016); IF.pop()
        t:falsy("com a PAUSA aberta, o botao exatamente atras NAO hoveria",
            fundo.hover)

        IF.push("pause"); pause:update(0.016); IF.pop()
        t:truthy("a row da PAUSA sob o mouse hoveria", pause.rows[1].btn.hover)

        local captor = IF.captor()
        t:truthy("PauseMenu e o captor de eventos", captor == pause)

        pause:hide()
        IF.push(IF.SCENE); fundo:update(0.016); IF.pop()
        t:truthy("fechada a pausa, o botao de tras volta a hoverar", fundo.hover)

        -- ===== 6. fiacao do main.lua (reverter o dispatch TEM que falhar) =====
        local src = love.filesystem.read("main.lua") or ""
        t:truthy("main.lua instala o portao do mouse",
            src:find("installMouseGate", 1, true) ~= nil)

        local esperados = {
            "map", "rest", "event", "roundEval", "packOpen",
            "deckViewer", "jokerManager", "runJournal", "pause", "settings",
        }
        for _, nome in ipairs(esperados) do
            t:truthy("main.lua registra o overlay '" .. nome .. "'",
                src:find('register("' .. nome .. '"', 1, true) ~= nil)
        end

        -- A camada SCENE tem que envolver o dispatch de ESTADO no update E
        -- no draw, e cada HANDLER de evento tem que perguntar pelo captor.
        -- Fatiamos POR FUNCAO: contar ocorrencias no arquivo inteiro deixava
        -- passar a remocao de uma delas (medido — reverter a camada do
        -- love.update continuava verde).
        local function corpo(nome, fim)
            local a = src:find("function love." .. nome, 1, true)
            if not a then return "" end
            local b = fim and src:find("function love." .. fim, a, true)
            return src:sub(a, (b or #src))
        end

        t:truthy("love.update despacha o estado na camada SCENE",
            corpo("update", "draw"):find("IF.push(IF.SCENE)", 1, true) ~= nil)
        t:truthy("love.draw desenha o estado na camada SCENE",
            corpo("draw", "resize"):find("IF.push(IF.SCENE)", 1, true) ~= nil)
        t:truthy("love.update tica a TopBar na camada CHROME",
            corpo("update", "draw"):find("IF.push(IF.CHROME)", 1, true) ~= nil)
        t:truthy("love.draw desenha a TopBar na camada CHROME",
            corpo("draw", "resize"):find("IF.push(IF.CHROME)", 1, true) ~= nil)

        for _, h in ipairs({
            { "keypressed",    "mousereleased" },
            { "mousereleased", "mousepressed" },
            { "mousepressed",  "wheelmoved" },
            { "wheelmoved",    "mousemoved" },
            { "mousemoved",    nil },
        }) do
            t:truthy("love." .. h[1] .. " pergunta pelo captor",
                corpo(h[1], h[2]):find(".captor()", 1, true) ~= nil)
        end
    end)

    restoreMouse()
    IF.clear()
    IF.resetLayers()

    if not ok then
        t:check("o teste rodou ate o fim (erro: " .. tostring(err) .. ")", false)
    end

    -- ===== COBERTURA vs COBERTURA: quem desenha manda (Set/2026) =====
    -- "Tela de remover carta nenhum clique funciona." `_G.openCardPicker`
    -- reusa o RestScreen e troca currentState pra "rest", mas NAO esconde a
    -- tela que o chamou. Aberto de um EVENTO, o eventScreen seguia visivel e,
    -- por ter sido registrado DEPOIS, roubava o foco: o mouse do picker virava
    -- sentinela e o clique nao tinha em quem cair.
    do
        local IF = require("src.ui.InputFocus")
        IF.clear()
        IF.resetLayers()

        local evento = { vis = false }
        function evento:isVisible() return self.vis end
        local picker = { vis = false }
        function picker:isVisible() return self.vis end
        local pause  = { vis = false }
        function pause:isVisible() return self.vis end

        -- ordem de registro = a do main.lua: rest ANTES de event
        IF.register("rest",  picker, { keepChrome = true })
        IF.register("event", evento, { keepChrome = true })
        IF.register("pause", pause)

        -- Evento aberto; o picker sobe POR CIMA (mesmo estado visivel).
        evento.vis = true
        picker.vis = true

        IF.push("rest")
        t:truthy("o picker que esta desenhando ENXERGA o mouse", IF.allows())
        IF.pop()

        -- E a tela de tras continua bloqueada enquanto o picker desenha.
        IF.push("scene")
        t:falsy("a cena atras continua bloqueada", IF.allows())
        IF.pop()

        -- MODAL ganha de qualquer cobertura: pause por cima do picker.
        pause.vis = true
        IF.push("rest")
        t:falsy("com o pause aberto, nem o picker enxerga", IF.allows())
        IF.pop()
        IF.push("pause")
        t:truthy("o pause enxerga", IF.allows())
        IF.pop()
        pause.vis = false

        -- Fechado o picker, o evento volta a mandar.
        picker.vis = false
        IF.push("event")
        t:truthy("fechado o picker, o evento volta a enxergar", IF.allows())
        IF.pop()

        IF.clear()
        IF.resetLayers()
    end

    return t:done()
end

return M
