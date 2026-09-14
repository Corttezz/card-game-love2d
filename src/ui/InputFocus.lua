-- src/ui/InputFocus.lua
-- QUEM TEM O FOCO DE ENTRADA.
--
-- O defeito que isto mata (playtest Set/2026): "dentro do menu de pausa o
-- hover continua pegando elementos de trás". Overlays desenhavam por cima e
-- até engoliam o CLIQUE, mas o HOVER deste projeto não passa por evento — ele
-- é POLLING: 43 call sites em 25 arquivos perguntam `love.mouse.getPosition()`
-- dentro do próprio update/draw (Button, Card, TopBar, EnemyHud, OrbRow,
-- JokerSlot, grids das telas cheias...). Enquanto o dispatch do main.lua
-- continuar chamando update/draw da cena de trás — e ele precisa continuar,
-- senão o mundo congela — cada um desses 43 sites enxerga o mouse e acende.
--
-- Consertar isso com `if pauseMenu.visible then return end` espalhado seria
-- 43 remendos, e o próximo overlay nasceria com o mesmo bug. A verdade que
-- FALTAVA é uma só: *de quem é o mouse neste instante*. Este módulo é ela.
--
-- COMO FUNCIONA (duas peças, uma ideia):
--
--   1. REGISTRO de overlays, em ordem de prioridade. Cada um só precisa
--      responder `isVisible()`. O topo visível é quem tem o foco.
--
--   2. CAMADA DE DESPACHO: o main.lua diz, ao redor de cada update/draw, em
--      nome de QUEM está desenhando (`push("scene")` … `pop()`). O patch
--      global de `love.mouse.getPosition` (mesmo ponto onde já mora a lente
--      do CRT) devolve uma posição FORA DA TELA quando a camada corrente não
--      é a dona do foco. Aí os 43 call sites descobrem sozinhos que o mouse
--      "não está sobre eles" — sem uma linha de mudança em nenhum deles.
--
-- Consequências que importam:
--   * overlay NOVO nasce bloqueando: basta registrá-lo (uma linha); a camada
--     "scene" já está declarada e é bloqueada por QUALQUER overlay visível;
--   * fechar o overlay devolve o hover de trás SEM mexer o mouse — o hover é
--     recalculado por polling todo frame, então volta no frame seguinte;
--   * o hover DENTRO do overlay continua vivo: ele desenha na PRÓPRIA camada,
--     que é justamente a que tem o foco.
--
-- DOIS TIPOS DE OVERLAY:
--   modal  (default)      captura os eventos (mouse/teclado/roda) e apaga
--                         TUDO atrás, inclusive a TopBar. Ex.: pausa,
--                         configurações, deck, coringas, roteiro, pacote.
--   cobertura (keepChrome) tapa a CENA mas a TopBar continua viva e clicável,
--                         e os eventos seguem pelo roteamento de estado do
--                         main.lua. Ex.: descanso, evento, mapa, cash out —
--                         telas de ESTADO, onde clicar no ouro/deck/engrenagem
--                         da barra é comportamento desejado.
--
-- Ver também: memory/ui_layout_invariants.md (§ fallback silencioso — aqui
-- nada falha calado: registro inválido AVISA por print).

local InputFocus = {}

-- Nomes canônicos de camada.
InputFocus.SCENE  = "scene"   -- mundo/combate/mão/HUD — o que fica ATRÁS
InputFocus.CHROME = "chrome"  -- TopBar (ouro/deck/ato/engrenagem)

-- Sentinela: longe o bastante pra falhar qualquer hit-test, perto o bastante
-- pra não estourar aritmética de ninguém.
InputFocus.OFFSCREEN = -32000

local overlays = {}   -- lista ordenada; índice maior = mais modal
local stack    = {}   -- pilha de camadas de despacho

-- Estado do patch de mouse (ver installMouseGate).
local rawGetPosition, mapToContent, wrapper

--==========================================================================
-- Registro
--==========================================================================

-- Zera registro e pilha. Existe pros testes/tools — o jogo registra uma vez
-- no love.load.
function InputFocus.clear()
    overlays = {}
    stack = {}
end

-- register(name, obj [, opts])
--   obj precisa expor isVisible().
--   opts.keepChrome = true  → cobertura: não apaga a TopBar nem captura eventos.
-- A ORDEM das chamadas é a prioridade: registre coberturas primeiro e o modal
-- mais "por cima de tudo" (configurações) por último.
function InputFocus.register(name, obj, opts)
    opts = opts or {}
    if type(name) ~= "string" or obj == nil then
        print("[InputFocus] registro invalido (name=" .. tostring(name)
            .. ", obj=" .. tostring(obj) .. ") — overlay IGNORADO")
        return nil
    end
    if type(obj.isVisible) ~= "function" then
        print("[InputFocus] '" .. name .. "' nao expoe isVisible() — ele NAO vai "
            .. "bloquear o hover de tras. Adicione isVisible() na tela.")
        return nil
    end
    local keepChrome = opts.keepChrome and true or false
    local entry = {
        name = name,
        obj = obj,
        keepChrome = keepChrome,
        -- Cobertura não captura evento: o roteamento por ESTADO do main.lua
        -- já entrega o clique pra ela, e a TopBar precisa continuar recebendo.
        capturesEvents = not keepChrome,
    }
    for i, e in ipairs(overlays) do
        if e.name == name then overlays[i] = entry; return entry end
    end
    overlays[#overlays + 1] = entry
    return entry
end

function InputFocus.count() return #overlays end

-- Nomes registrados, da menor pra maior prioridade (diagnóstico/testes).
function InputFocus.names()
    local t = {}
    for i, e in ipairs(overlays) do t[i] = e.name end
    return t
end

--==========================================================================
-- Quem está com o foco
--==========================================================================

local function topVisible()
    for i = #overlays, 1, -1 do
        local e = overlays[i]
        local ok, vis = pcall(e.obj.isVisible, e.obj)
        if not ok then
            print("[InputFocus] isVisible() de '" .. e.name .. "' falhou: "
                .. tostring(vis))
        elseif vis then
            return e
        end
    end
    return nil
end

-- Entrada do overlay no topo (ou nil). Inclui coberturas.
function InputFocus.active() return topVisible() end

-- Nome do overlay no topo (ou nil).
function InputFocus.activeName()
    local e = topVisible()
    return e and e.name or nil
end

-- O overlay que deve RECEBER os eventos (mouse/teclado/roda), ou nil se o
-- roteamento normal por estado deve seguir. Devolve (obj, name).
function InputFocus.captor()
    local e = topVisible()
    if e and e.capturesEvents then return e.obj, e.name end
    return nil
end

--==========================================================================
-- Camadas de despacho
--==========================================================================

function InputFocus.push(layer) stack[#stack + 1] = layer end
function InputFocus.pop() stack[#stack] = nil end
function InputFocus.current() return stack[#stack] end

-- Higiene de frame: um erro no meio de um draw pode deixar a pilha torta.
-- O main.lua zera no começo do update e do draw.
local warnedLeak = false
function InputFocus.resetLayers()
    -- Pilha suja aqui = alguem empurrou camada e nao tirou (return no meio de
    -- um dispatch, por exemplo). Isso BLOQUEIA hover pra sempre — o defeito
    -- inverso, e silencioso. Avisa uma vez e diz qual camada ficou presa.
    if #stack > 0 and not warnedLeak then
        warnedLeak = true
        print("[InputFocus] camada VAZOU entre frames: '"
            .. tostring(stack[#stack]) .. "' (push sem pop no dispatch). "
            .. "Hover de tras pode ficar apagado ate reiniciar.")
    end
    for i = #stack, 1, -1 do stack[i] = nil end
end

-- A camada `layer` (default: a corrente) pode ler o mouse agora?
-- Entrada registrada com este nome, ou nil.
local function entryNamed(name)
    for _, e in ipairs(overlays) do
        if e.name == name then return e end
    end
    return nil
end

function InputFocus.allows(layer)
    if layer == nil then layer = stack[#stack] end
    local e = topVisible()
    if not e then return true end
    -- Camada nenhuma declarada = chrome global (cursor do mouse, tooltips já
    -- agendados). Nunca se bloqueia — senão o cursor pararia de seguir o mouse.
    if layer == nil then return true end
    if layer == e.name then return true end
    if layer == InputFocus.CHROME and e.keepChrome then return true end

    -- COBERTURA vs COBERTURA: quem está DESENHANDO manda.
    --
    -- Coberturas são telas de ESTADO (mapa, descanso/picker, evento, cash
    -- out) e a prioridade entre elas é a ordem de registro — o que está certo
    -- para modais empilhados, e errado aqui, porque duas telas de estado podem
    -- estar visíveis ao mesmo tempo sem uma estar "por cima" da outra.
    --
    -- O caso real (dono, Set/2026: "tela de remover carta nenhum clique
    -- funciona"): `_G.openCardPicker` reusa o RestScreen e troca
    -- `currentState` para "rest", mas NÃO esconde a tela que o chamou. Aberto
    -- a partir de um evento, o `eventScreen` seguia visível e — por ter sido
    -- registrado depois — roubava o foco do picker. O mouse do picker virava a
    -- sentinela, nenhum item ficava sob o cursor e o clique não achava alvo.
    -- O clique CHEGAVA; ele é que não tinha em quem cair.
    --
    -- MODAL continua ganhando de tudo: se o topo captura eventos (pause,
    -- settings, deck viewer...), nenhuma cobertura passa por aqui.
    if not e.capturesEvents then
        local mine = entryNamed(layer)
        if mine and not mine.capturesEvents then
            local ok, vis = pcall(mine.obj.isVisible, mine.obj)
            if ok and vis then return true end
        end
    end

    return false
end

--==========================================================================
-- O portão do mouse
--==========================================================================

-- Devolve (x, y) ou a sentinela, conforme a camada corrente.
function InputFocus.gate(x, y)
    if InputFocus.allows() then return x, y end
    return InputFocus.OFFSCREEN, InputFocus.OFFSCREEN
end

-- Instala o patch global de leitura do mouse.
--   screenToContent : função opcional tela→conteúdo (a lente do CRT).
--   rawFn           : fonte crua opcional (testes injetam um mouse falso).
-- Idempotente: reinstalar não embrulha o próprio wrapper.
function InputFocus.installMouseGate(screenToContent, rawFn)
    if rawFn then
        rawGetPosition = rawFn
    elseif not (rawGetPosition and love.mouse.getPosition == wrapper) then
        rawGetPosition = love.mouse.getPosition
    end
    mapToContent = screenToContent

    wrapper = function()
        local x, y = rawGetPosition()
        if mapToContent then x, y = mapToContent(x, y) end
        return InputFocus.gate(x, y)
    end

    love.mouse.getPosition = wrapper
    love.mouse.getX = function() local x = wrapper(); return x end
    love.mouse.getY = function() local _, y = wrapper(); return y end
    return wrapper
end

return InputFocus
