-- tools/test_nav_flow.lua
-- RUN INTEIRA SÓ POR TECLADO/PAD (meta Steam Deck Verified): o jogo de
-- verdade (main.lua depois do love.load), sem mouse nenhum —
--   menu → classe → batalha (seleciona e joga) → cash out → espólio →
--   encruzilhada → loja (compra) → encruzilhada → descanso → encruzilhada →
--   evento → pausa → configurações → volta.
-- Cada passo navega com SETAS/D-PAD de verdade (o motorista escolhe a
-- direção que aproxima o foco do alvo e aperta a tecla), confirma com
-- Enter/A, e confere que o foco nunca cai fora da tela.
--
--   love . nav_flow                (sai com 0/1)
--   NAV_PART=2 love . nav_flow     (2º roteiro: coleção, conquistas, coringas,
--                                   deck, roteiro, pacote, vitória → endless)
--
-- Trapaças declaradas (não são navegação): inimigo com 1 de vida (a luta não
-- é o que se testa) e o tipo dos nós da encruzilhada forçado (loja, descanso,
-- evento) pra o roteiro ser determinístico.

local M = {}

local pass, fail = 0, 0
local function check(name, cond)
    if cond then pass = pass + 1; print("  [ok] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name) end
end

local NavCursor = require("src.ui.NavCursor")
local function state() return _G.getCurrentState and _G.getCurrentState() end

local function frames(n) for _ = 1, n or 1 do coroutine.yield() end end
-- espera TEMPO de jogo (sem vsync o tool roda a centenas de quadros/s: contar
-- quadros não espera animação nenhuma)
local function sleep(secs)
    local t = 0
    while t < secs do t = t + (coroutine.yield() or 0) end
end

-- Capturas com o anel de foco (NAV_SHOTS=1): nav_<nome>_<W>x<H>.png
local function snap(name)
    if not os.getenv("NAV_SHOTS") then return end
    sleep(1.2)   -- entradas/cascatas assentam
    local file = ("nav_%s_%dx%d.png"):format(name, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.captureScreenshot(function(img)
        img:encode("png", file)
        print("    [shot] " .. file)
    end)
    frames(2)
end
local function key(k) love.keypressed(k); frames(2) end
local function pad(b) love.gamepadpressed(nil, b); frames(2) end

local function waitFor(pred, maxFrames, label)
    for _ = 1, maxFrames or 600 do
        if pred() then return true end
        frames(1)
    end
    print("    (timeout esperando: " .. tostring(label) .. ", estado=" .. tostring(state()) .. ")")
    return false
end

-- foco dentro da tela (pixels reais)
local function focusOnScreen()
    local t = NavCursor.focused()
    if not t then return true end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    return t.x >= 0 and t.y >= 0 and t.x + t.w <= W + 1 and t.y + t.h <= H + 1
end
local offscreen = 0
local function noteFocus()
    if NavCursor.isActive() and not focusOnScreen() then offscreen = offscreen + 1 end
end

-- Navega com SETAS até o alvo que satisfaz `match(target)`; devolve true se
-- o foco chegou nele. Escolhe a direção pelo vetor foco→alvo.
local function navigateTo(match, label, useKeys)
    local press = useKeys == false and function(d) pad("dp" .. d) end or key
    if not NavCursor.isActive() then press("down") end
    for _ = 1, 40 do
        noteFocus()
        local f = NavCursor.focused()
        if f and match(f) then return true end
        local goal
        for _, t in ipairs(NavCursor._targets()) do
            if match(t) then goal = t break end
        end
        if not goal or not f then frames(2) else
            local fx, fy = f.x + f.w / 2, f.y + f.h / 2
            local gx, gy = goal.x + goal.w / 2, goal.y + goal.h / 2
            local dx, dy = gx - fx, gy - fy
            local dir
            if math.abs(dy) > math.abs(dx) * 0.6 then dir = dy > 0 and "down" or "up"
            else dir = dx > 0 and "right" or "left" end
            press(dir)
        end
    end
    print("    (não alcancei: " .. tostring(label) .. ")")
    return false
end

local function isButtonText(text)
    return function(t) return type(t.key) == "table" and t.key.text == text end
end
local function isKey(prefix)
    return function(t) return type(t.key) == "string" and t.key:sub(1, #prefix) == prefix end
end

function M.script()
    local I18n = require("src.i18n.I18n")
    print("---- fluxo de run só por teclado/pad ----")
    frames(10)
    -- boot → menu
    waitFor(function()
        if state() == "boot" then love.keypressed("return") end
        return state() == "menu"
    end, 600, "menu")
    frames(150)   -- intro do menu (cascata dos botões)
    check("menu alcançado", state() == "menu")

    -- Jogar (setas até o botão + Enter)
    local playLabel = I18n.t("menu.play")
    check("menu: setas chegam no Jogar", navigateTo(isButtonText(playLabel), "Jogar"))
    snap("menu")
    key("return")
    frames(30)
    -- confirmação de "jogar com save" (se existir): Enter confirma
    if require("src.ui.ConfirmDialog").isVisible() then key("left"); key("return"); frames(10) end
    waitFor(function() return state() == "classSelection" end, 300, "classSelection")
    check("classe: tela aberta pelo teclado", state() == "classSelection")
    frames(60)

    -- classe: foco num painel (pad: D-pad) e A
    local ok = navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text == "" and b.width > 150
    end, "painel de classe", false)
    check("classe: D-pad chega num painel", ok)
    snap("class")
    pad("a")
    waitFor(function() return state() == "playing" end, 600, "playing")
    check("batalha: A no painel começa a run", state() == "playing")

    local GS = require("src.scenes.GameplayScene")
    local game = GS.getGame()
    frames(240)   -- viagem/chegada do inimigo
    waitFor(function() return game.turn == "player" and #game.hand > 0
        and not game.combatAnimationSystem:isBlocking() end, 900, "turno do jogador")
    frames(60)
    game.enemy.health = 1
    game.enemy.armor = 0
    -- LB/RB andam na mão; A seleciona; Y joga
    pad("rightshoulder")
    -- RB anda pela mão até uma carta de ATAQUE (a de defesa não mata)
    for _ = 1, 6 do
        local c = NavCursor.focused()
        if c and type(c.key) == "table" and c.key.type == "attack" then break end
        pad("rightshoulder")
    end
    local f = NavCursor.focused()
    check("batalha: RB foca uma carta da mão", f and f.group == "hand")
    local card = f and f.key
    local handBefore = #game.hand
    snap("battle_hand")
    pad("a")
    snap("battle_selected")
    pad("a"); pad("a")   -- desmarca e marca de novo (A alterna)
    check("batalha: A seleciona a carta focada", card and game:isCardSelected(card))
    noteFocus()
    waitFor(function() return not game.combatAnimationSystem:isBlocking() end, 300, "jogar liberado")
    pad("y")
    frames(5)
    check("batalha: Y joga as cartas (mão " .. handBefore .. " → " .. #game.hand .. ")",
        #game.hand < handBefore)
    waitFor(function() return state() ~= "playing" end, 3000, "fim da batalha")
    check("batalha: vitória leva adiante (" .. tostring(state()) .. ")",
        state() == "roundEval" or state() == "cardReward")

    -- cash out: Enter até sair
    for i = 1, 30 do
        if state() ~= "roundEval" then break end
        key("return"); frames(20)
    end
    waitFor(function() return state() == "cardReward" end, 600, "espólio")
    check("espólio aberto pelo teclado", state() == "cardReward")
    frames(90)

    -- força a próxima encruzilhada: loja / descanso / evento
    local MapManager = require("src.systems.MapManager")
    local realGen = MapManager.generate
    local forced = { "shop", "rest", "event" }
    local idx = 0
    MapManager.generate = function(...)
        local nodes = realGen(...)
        idx = idx + 1
        local want = forced[idx]
        if want and nodes then
            for _, n in ipairs(nodes) do n.type = want end
        end
        return nodes
    end

    -- espólio: escolhe a 1ª carta (foco + Enter) e confirma pelo botão
    ok = navigateTo(function(t) return type(t.key) == "table" and t.key.shopOffer ~= nil end, "carta do espólio")
    check("espólio: setas chegam numa carta", ok)
    key("return"); frames(20)
    local takeOk = navigateTo(function(t)
        return type(t.key) == "table" and t.key.text and t.key.text ~= ""
            and t.key.text ~= I18n.t("reward.skip", nil, "?") and t.key.onClick ~= nil
            and t.key.y and t.key.y > 0 and t.key.width and t.key.width < 400
    end, "botão de pegar")
    if takeOk then key("return") end
    waitFor(function() return state() == "mapSelection" end, 600, "encruzilhada")
    check("espólio resolvido → encruzilhada", state() == "mapSelection")
    frames(120)

    local function chooseFork(label)
        ok = navigateTo(function(t)
            return type(t.key) == "string" and (t.key:sub(1, 5) == "fork:" or t.key:sub(1, 5) == "node:")
        end, label)
        check("encruzilhada: setas chegam num marco (" .. label .. ")", ok)
        snap("fork_" .. label)
        key("return")
    end

    -- LOJA
    chooseFork("loja")
    waitFor(function() return state() == "cardReward" end, 900, "loja")
    check("loja aberta pela encruzilhada", state() == "cardReward")
    frames(120)
    snap("shop_open")
    local gold0 = game.economySystem.currentGold
    game.economySystem.currentGold = 999
    ok = navigateTo(function(t) return type(t.key) == "table" and t.key.shopOffer ~= nil end, "carta da loja")
    check("loja: setas chegam numa carta", ok)
    snap("shop_card")
    key("return"); frames(20)
    local deckBefore = #(game.runManager.currentRun.currentDeck or {})
    local buy = navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text and b.text:find("%$") and b.width and b.width < 400
            and b.text:upper() == b.text   -- "COMPRAR $N"
    end, "comprar")
    if buy then key("return") end
    frames(40)
    check("loja: compra pelo teclado (deck " .. deckBefore .. " → "
        .. #(game.runManager.currentRun.currentDeck or {}) .. ")",
        #(game.runManager.currentRun.currentDeck or {}) > deckBefore)
    game.economySystem.currentGold = gold0
    -- sai da loja: X/Q é o reroll; o Continuar é botão — navega até ele
    local cont = navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text and b.text:find("%(%+%$")
    end, "continuar")
    if cont then key("return") end
    waitFor(function() return state() == "mapSelection" end, 600, "encruzilhada 2")
    check("loja → encruzilhada", state() == "mapSelection")
    frames(120)

    -- DESCANSO
    chooseFork("descanso")
    waitFor(function() return state() == "rest" end, 900, "descanso")
    check("descanso aberto", state() == "rest")
    frames(60)
    pad("dpdown")
    ok = navigateTo(function(t) return type(t.key) == "table" and t.key.variant == "invisible" end,
        "cartão do descanso", false)
    check("descanso: D-pad chega numa escolha", ok)
    snap("rest")
    pad("a")
    waitFor(function() return state() == "mapSelection" end, 900, "encruzilhada 3")
    check("descanso → encruzilhada", state() == "mapSelection")
    frames(120)

    -- EVENTO
    chooseFork("evento")
    waitFor(function() return state() == "event" end, 900, "evento")
    check("evento aberto", state() == "event")
    frames(60)
    ok = navigateTo(function(t) return type(t.key) == "table" and t.key.text and t.key.text ~= "" end,
        "opção do evento")
    check("evento: setas chegam numa opção", ok)
    snap("event")
    for _ = 1, 6 do
        if state() ~= "event" then break end
        key("return"); frames(30)
        if state() == "event" then
            navigateTo(function(t) return type(t.key) == "table" and t.key.text and t.key.text ~= "" end, "botão do evento")
        end
    end
    waitFor(function() return state() ~= "event" end, 600, "saída do evento")
    check("evento resolvido pelo teclado (" .. tostring(state()) .. ")", state() ~= "event")
    MapManager.generate = realGen

    -- PAUSA → CONFIGURAÇÕES → volta (pad: START, D-pad, A, B)
    frames(60)
    pad("start")
    local IF = require("src.ui.InputFocus")
    check("START abre a pausa", IF.activeName() == "pause")
    pad("dpdown"); pad("a")
    check("pausa: D-pad + A abre as configurações", IF.activeName() == "settings")
    pad("b")
    check("B volta pra pausa", IF.activeName() == "pause")
    pad("b")
    check("B fecha a pausa", IF.activeName() ~= "pause")

    M.finish()
end

function M.finish()
    check("o foco nunca saiu da tela (" .. offscreen .. " quadros fora)", offscreen == 0)
    print(("  TOTAL: %d pass / %d fail"):format(pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
end

-- ajudantes pro 2º roteiro (tools/test_nav_flow2.lua)
M.frames, M.sleep, M.key, M.pad = frames, sleep, key, pad
M.waitFor, M.navigateTo, M.check, M.snap = waitFor, navigateTo, check, snap
M.isButtonText, M.isKey, M.state = isButtonText, isKey, state

function M.start()
    -- tamanho da janela por ambiente (uma chamada só, no começo)
    local W, H = tonumber(os.getenv("NAV_W")), tonumber(os.getenv("NAV_H"))
    if W and H then love.window.setMode(W, H, { resizable = true }) ; if love.resize then love.resize(W, H) end end
    -- NAV_PART=2: o 2º roteiro (tools/test_nav_flow2.lua)
    local script = os.getenv("NAV_PART") == "2" and require("tools.test_nav_flow2").script or M.script
    local co = coroutine.create(script)
    local self = {}
    function self.step(dt)
        if coroutine.status(co) == "dead" then return end
        noteFocus()
        local ok, err = coroutine.resume(co, dt)
        if not ok then
            print("  ERRO no fluxo: " .. tostring(err))
            print(debug.traceback(co))
            love.event.quit(1)
        end
    end
    return self
end

return M
