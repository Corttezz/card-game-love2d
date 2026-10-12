-- src/ui/NavCursor.lua
-- NAVEGAÇÃO POR TECLADO E GAMEPAD EM TODAS AS TELAS (Out/2026 — meta Steam
-- Deck Verified).
--
-- Em vez de ensinar 20 telas a navegar, o cursor de foco se apoia no que
-- elas JÁ fazem: o hover deste jogo é por POLLING (`love.mouse.getPosition`,
-- 40+ call sites) e o clique é `mousepressed/mousereleased`. Então:
--
--   1. ALVOS: quem desenha algo clicável registra o retângulo no quadro
--      (`NavCursor.target`). Button:draw e Card:draw já registram — o resto
--      (tiles da loja, nós do mapa, quadros...) chama `target` no draw. O
--      retângulo é convertido pra PIXELS DA TELA na hora (transformPoint),
--      então escala de UI, slide-in e scissor não importam pra navegação.
--      A camada de foco (InputFocus) de quem registrou vai junto: só valem
--      os alvos da camada que tem o foco (modal por cima apaga os de trás).
--   2. FOCO: no modo teclado/pad, o mouse "mora" no centro do alvo focado
--      (InputFocus.setPositionOverride): hover, tooltip, lift de carta — tudo
--      que já reage ao mouse reage ao foco, de graça. Foco = hover.
--   3. AÇÕES: A/Enter sintetiza o clique no foco (o MESMO caminho do mouse);
--      gatilho = clique direito (inspecionar); B/Esc = a tecla Esc; X/Y e
--      ombros = ações de contexto que a tela publica (`NavCursor.action`).
--   4. MOUSE E PAD CONVIVEM: mexer o mouse desliga o modo (some o anel);
--      apertar tecla/botão religa, focando o que estava sob o mouse.
--
-- Telas com navegação PRÓPRIA (pausa, configurações, confirmação, dados do
-- escriba, fim de jogo, conquistas — MenuKit) declaram `ownsNavigation` e
-- recebem as teclas como antes; o pad vira tecla pra elas.

local NavCursor = {}

local targets, prev = {}, {}     -- alvos do quadro corrente / do último completo
local actions, prevActions = {}, {}
local active = false
local device = "mouse"            -- "mouse" | "keyboard" | "pad"
local focusKey = nil
local focusPt = nil               -- último ponto focado (pra reescolher)
local focusExplicit = false       -- o jogador ANDOU até ele (vs. escolha automática)
local lastMouseX, lastMouseY
NavCursor.synthesizing = false    -- main.lua: clique sintético não passa pela lente do CRT

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

function NavCursor.isActive() return active end
function NavCursor.device() return device end

-- ===== registro (durante o draw) =====
-- opts: key (identidade estável; default = obj/retângulo), group ("hand"...),
--       px, py (ponto do cursor em fração do retângulo; default 0.5/0.5)
function NavCursor.target(obj, x, y, w, h, opts)
    if not (x and y and w and h) or w <= 1 or h <= 1 then return end
    local g = love.graphics
    local x1, y1 = g.transformPoint(x, y)
    local x2, y2 = g.transformPoint(x + w, y + h)
    if x2 < x1 then x1, x2 = x2, x1 end
    if y2 < y1 then y1, y2 = y2, y1 end
    -- recorte do scissor corrente (em pixels reais — o UiScale devolve o
    -- scissor no espaço virtual: volta pra tela multiplicando pelo k)
    local sx, sy, sw, sh = g.getScissor()
    if sx then
        local k = require("src.ui.UiScale").activeK()
        sx, sy, sw, sh = sx * k, sy * k, sw * k, sh * k
        x1, y1 = math.max(x1, sx), math.max(y1, sy)
        x2, y2 = math.min(x2, sx + sw), math.min(y2, sy + sh)
    end
    local W, H = require("src.ui.UiScale").realDimensions()
    x1, y1, x2, y2 = math.max(0, x1), math.max(0, y1), math.min(W, x2), math.min(H, y2)
    if x2 - x1 < 4 or y2 - y1 < 4 then return end   -- fora da tela / recortado
    opts = opts or {}
    targets[#targets + 1] = {
        key = opts.key or obj, x = x1, y = y1, w = x2 - x1, h = y2 - y1,
        px = opts.px or 0.5, py = opts.py or 0.5, group = opts.group,
        layer = require("src.ui.InputFocus").current(),
    }
end

-- Ação de contexto publicada pela tela neste quadro.
--   button: "x" | "y" | "lb" | "rb"; fn: o que faz; rect opcional: onde
--   desenhar o glifo (canto do botão que a ação aciona — nada de rodapé).
function NavCursor.action(button, fn, x, y, w, h)
    local r
    if x then
        local g = love.graphics
        local x1, y1 = g.transformPoint(x, y)
        local x2, y2 = g.transformPoint(x + w, y + h)
        r = { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
    end
    actions[button] = { fn = fn, rect = r,
        layer = require("src.ui.InputFocus").current() }
end

-- Começo do draw: o quadro anterior vira a referência de navegação.
function NavCursor.beginFrame()
    prev, targets = targets, {}
    prevActions, actions = actions, {}
end

local function eligible()
    local IF = require("src.ui.InputFocus")
    local out = {}
    for _, t in ipairs(prev) do
        if IF.allows(t.layer) then out[#out + 1] = t end
    end
    return out
end

local function center(t) return t.x + t.w * t.px, t.y + t.h * t.py end

local function find(list, key)
    for _, t in ipairs(list) do if t.key == key then return t end end
end

local function under(list, x, y)
    for i = #list, 1, -1 do   -- desenhado por último = por cima
        local t = list[i]
        if x >= t.x and x <= t.x + t.w and y >= t.y and y <= t.y + t.h then return t end
    end
end

-- Alvo inicial: o que está sob o mouse; senão o mais perto do último foco;
-- senão o primeiro em ordem de leitura (cima→baixo, esquerda→direita).
local function pickDefault(list)
    if #list == 0 then return nil end
    -- a barra do topo (camada chrome) só ganha o foco se não houver mais nada:
    -- o conteúdo da tela é o que o jogador veio usar
    local IF = require("src.ui.InputFocus")
    local main = {}
    for _, t in ipairs(list) do
        if t.layer ~= IF.CHROME then main[#main + 1] = t end
    end
    if #main > 0 then list = main end
    if lastMouseX then
        local t = under(list, lastMouseX, lastMouseY)
        if t then return t end
    end
    if focusPt then
        local best, bd
        for _, t in ipairs(list) do
            local cx, cy = center(t)
            local d = (cx - focusPt[1]) ^ 2 + (cy - focusPt[2]) ^ 2
            if not bd or d < bd then best, bd = t, d end
        end
        return best
    end
    local best
    for _, t in ipairs(list) do
        if not best or t.y < best.y - 8 or (math.abs(t.y - best.y) <= 8 and t.x < best.x) then
            best = t
        end
    end
    return best
end

-- Foco atual (revalidado contra os alvos do último quadro).
local function current()
    local list = eligible()
    local t = focusKey and find(list, focusKey)
    -- foco AUTOMÁTICO parado na barra do topo enquanto o conteúdo da tela
    -- ainda não existia (botão que surge depois de uma animação): quando o
    -- conteúdo aparece, o foco vai pra ele
    if t and not focusExplicit and t.layer == require("src.ui.InputFocus").CHROME then
        for _, c in ipairs(list) do
            if c.layer ~= t.layer then t = nil break end
        end
    end
    if not t then
        focusExplicit = false
        t = pickDefault(list)
        focusKey = t and t.key
    end
    if t then focusPt = { center(t) } end
    return t, list
end
NavCursor.focused = function() return (current()) end

-- ===== modo =====
local function activate(dev)
    device = dev
    if not active then
        active = true
        focusKey = nil       -- reescolhe a partir do que está sob o mouse
    end
end

function NavCursor.deactivate()
    active = false
    device = "mouse"
end

-- Mouse físico se mexeu (love.mousemoved real): devolve o controle ao mouse.
function NavCursor.mouseMoved(x, y)
    if NavCursor.synthesizing then return end
    lastMouseX, lastMouseY = x, y
    if active then NavCursor.deactivate() end
end

-- Posição do "mouse" no modo foco (InputFocus consulta isto). nil = mouse real.
function NavCursor.position()
    if not active then return nil end
    local t = current()
    if not t then return nil end
    return center(t)
end

-- ===== navegação =====
-- Vizinho espacial: menor distância na direção, desvio lateral pesa 2x.
-- Duas passadas: primeiro só dentro do cone de 45° (o que está "naquela
-- direção" de verdade); sem ninguém no cone, qualquer um à frente — senão um
-- alvo quase alinhado longe perdia pra um vizinho de outra fileira e havia
-- botão que a seta nunca alcançava (Continuar da loja vindo do pacote).
local function neighbor(list, from, dx, dy)
    local fx, fy = center(from)
    local function pass(cone)
        local best, bd
        for _, t in ipairs(list) do
            if t.key ~= from.key then
                local cx, cy = center(t)
                local vx, vy = cx - fx, cy - fy
                local along = vx * dx + vy * dy
                if along > 2 then
                    local side = math.abs(vx * dy) + math.abs(vy * dx)
                    if not cone or side <= along then
                        local d = along + side * 2
                        if not bd or d < bd then best, bd = t, d end
                    end
                end
            end
        end
        return best
    end
    return pass(true) or pass(false)
end

local DIRS = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

function NavCursor.move(dir)
    local t, list = current()
    if not t then return false end
    local d = DIRS[dir]
    local n = neighbor(list, t, d[1], d[2])
    if n then
        focusKey = n.key
        focusExplicit = true
        focusPt = { center(n) }
        local ok, Sfx = pcall(require, "src.systems.Sfx")
        if ok then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        return true
    end
    -- nada naquela direção: a tela rola (grade comprida — coleção, deck...)
    if (dir == "up" or dir == "down") and love.wheelmoved then
        NavCursor.synthesizing = true
        local ok, err = pcall(love.wheelmoved, 0, dir == "up" and 1 or -1)
        NavCursor.synthesizing = false
        if not ok then error(err, 0) end
    end
    return false
end

-- Ombros: anda dentro do GRUPO do foco (a mão no combate); sem grupo, é
-- esquerda/direita.
function NavCursor.cycle(step)
    local t, list = current()
    if not t then return false end
    local group = t.group
    if not group then
        for _, c in ipairs(list) do if c.group == "hand" then group = "hand" break end end
    end
    if not group then return NavCursor.move(step < 0 and "left" or "right") end
    local members = {}
    for _, c in ipairs(list) do if c.group == group then members[#members + 1] = c end end
    table.sort(members, function(a, b) return a.x < b.x end)
    local idx = 0
    for i, c in ipairs(members) do if c.key == t.key then idx = i end end
    local n = members[((idx - 1 + step) % #members) + 1]
    if n then focusKey = n.key; focusExplicit = true; focusPt = { center(n) } end
    return n ~= nil
end

-- Clique sintético no foco (botão 1 = escolher, 2 = inspecionar).
function NavCursor.click(button)
    local t = current()
    if not t then return false end
    local x, y = center(t)
    NavCursor.synthesizing = true
    local ok, err = pcall(function()
        if love.mousepressed then love.mousepressed(x, y, button or 1) end
        if love.mousereleased then love.mousereleased(x, y, button or 1) end
    end)
    NavCursor.synthesizing = false
    if not ok then error(err, 0) end
    return true
end

function NavCursor.runAction(button)
    local a = prevActions[button]
    if a and require("src.ui.InputFocus").allows(a.layer) then
        a.fn()
        return true
    end
    return false
end

-- ===== entrada =====
-- Intenções: up/down/left/right/confirm/back/inspect/x/y/lb/rb
-- Devolve true se consumiu.
function NavCursor.intent(it, dev)
    if not it then return false end
    dev = dev or "keyboard"
    if DIRS[it] then
        local wasActive = active
        activate(dev)
        if not wasActive then current(); return true end   -- 1º toque só mostra o anel
        NavCursor.move(it)
        return true
    elseif it == "confirm" then
        local wasActive = active
        activate(dev)
        local t = current()
        if not t then return false end
        if not wasActive then return true end   -- 1º toque só mostra o anel
        -- a barra do topo só recebe Enter se o jogador ANDOU até ela (o foco
        -- automático cai nela quando a tela ainda não tem conteúdo)
        if t.layer == require("src.ui.InputFocus").CHROME and not focusExplicit then
            return true
        end
        return NavCursor.click(1)
    elseif it == "inspect" then
        if not active then activate(dev) end
        return NavCursor.click(2)
    elseif it == "lb" or it == "rb" or it == "x" or it == "y" then
        -- ação de contexto publicada pela tela (JOGAR, ENCERRAR, reroll...)
        if NavCursor.runAction(it) then device = dev; return true end
        if it == "lb" or it == "rb" then
            activate(dev)
            return NavCursor.cycle(it == "lb" and -1 or 1)
        end
    end
    return false
end

-- Último aparelho usado (glifo de pad × tecla), sem ligar o anel.
function NavCursor.noteDevice(dev) device = dev end

-- Telas que NAVEGAM SOZINHAS (MenuKit/setas próprias): o cursor não toma
-- as teclas delas. `extraOwned`: caso pontual do main (zoom da coleção).
NavCursor.STATE_OWNS = { boot = true, gameOver = true, victory = true, achievements = true }
function NavCursor.claimsInput(state, extraOwned)
    if extraOwned then return false end
    local captor = require("src.ui.InputFocus").captor()
    if captor then return not captor.ownsNavigation end
    return not NavCursor.STATE_OWNS[state]
end

-- Teclado → intenção (setas, Enter/Espaço, e as letras de contexto).
NavCursor.KEYS = {
    up = "up", down = "down", left = "left", right = "right",
    ["return"] = "confirm", kpenter = "confirm", space = "confirm",
    e = "y", q = "x", z = "lb", c = "rb", i = "inspect",
}
-- Glifo de teclado de cada ação (o que aparece no botão em modo teclado).
NavCursor.KEY_LABEL = { confirm = "ENTER", y = "E", x = "Q", lb = "Z", rb = "C", inspect = "I", back = "ESC" }
NavCursor.PAD_LABEL = { confirm = "A", y = "Y", x = "X", lb = "LB", rb = "RB", inspect = "RT", back = "B" }

-- Gamepad → intenção.
NavCursor.PAD = {
    dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
    a = "confirm", b = "back", x = "x", y = "y",
    leftshoulder = "lb", rightshoulder = "rb",
}

-- Analógico esquerdo (repetição com zona morta). Chamado do love.update.
local stick = { dir = nil, t = 0 }
function NavCursor.updateStick(dt, joystick)
    if not joystick or not joystick.isGamepad or not joystick:isGamepad() then return end
    local ax = joystick:getGamepadAxis("leftx") or 0
    local ay = joystick:getGamepadAxis("lefty") or 0
    local dir
    if math.abs(ax) > 0.55 and math.abs(ax) >= math.abs(ay) then dir = ax < 0 and "left" or "right"
    elseif math.abs(ay) > 0.55 then dir = ay < 0 and "up" or "down" end
    -- gatilhos: inspecionar (borda de subida)
    local rt = joystick:getGamepadAxis("triggerright") or 0
    local lt = joystick:getGamepadAxis("triggerleft") or 0
    local trig = (rt > 0.6 or lt > 0.6)
    if trig and not stick.trig then NavCursor.intent("inspect", "pad") end
    stick.trig = trig
    if dir ~= stick.dir then
        stick.dir, stick.t = dir, 0.35
        if dir then NavCursor.intent(dir, "pad") end
    elseif dir then
        stick.t = stick.t - dt
        if stick.t <= 0 then
            stick.t = 0.12
            NavCursor.intent(dir, "pad")
        end
    end
end

-- ===== desenho =====
-- Glifo de botão: pad = círculo com a letra (cores Xbox/Deck); teclado =
-- tecla com o rótulo. Pixel art: retângulos e degraus, sem anti-alias.
local PAD_COLORS = {
    A = { 0.30, 0.62, 0.30 }, B = { 0.72, 0.24, 0.20 },
    X = { 0.25, 0.45, 0.78 }, Y = { 0.85, 0.68, 0.20 },
}
function NavCursor.drawGlyph(label, x, y, size)
    size = size or 16
    local FontManager = require("src.ui.FontManager")
    local Palette = require("src.ui.Palette")
    local f = FontManager.getFont(math.max(10, math.floor(size * 0.55)))
    local g = love.graphics
    g.setFont(f)
    if device == "pad" then
        local c = PAD_COLORS[label] or { 0.35, 0.33, 0.30 }
        local w = math.max(size, f:getWidth(label) + 8)
        Palette.set(Palette.INK, 0.9)
        g.rectangle("fill", x + 1, y + 2, w, size, size / 2, size / 2)
        g.setColor(c[1], c[2], c[3], 1)
        g.rectangle("fill", x, y, w, size, size / 2, size / 2)
        g.setColor(1, 1, 1, 0.25)
        g.rectangle("fill", x + 3, y + 2, w - 6, 2)
        Palette.set(Palette.PARCHMENT_LIGHT)
        g.print(label, math.floor(x + (w - f:getWidth(label)) / 2), math.floor(y + (size - f:getHeight()) / 2))
        return w
    end
    local w = math.max(size, f:getWidth(label) + 8)
    Palette.set(Palette.INK, 0.9)
    g.rectangle("fill", x, y + 2, w, size)
    Palette.set(Palette.PARCHMENT_LIGHT)
    g.rectangle("fill", x, y, w, size - 2)
    Palette.set(Palette.PARCHMENT_DARK)
    g.rectangle("line", x + 0.5, y + 0.5, w - 1, size - 2)
    Palette.set(Palette.INK)
    g.print(label, math.floor(x + (w - f:getWidth(label)) / 2), math.floor(y + (size - 2 - f:getHeight()) / 2))
    return w
end

local function labelFor(action)
    local t = device == "pad" and NavCursor.PAD_LABEL or NavCursor.KEY_LABEL
    return t[action] or action
end
NavCursor.labelFor = labelFor

-- Anel de foco (gramática do MenuKit) + glifo de confirmação no canto do
-- foco + glifos das ações de contexto nos botões que elas acionam. Desenha
-- em PIXELS DA TELA, fora de qualquer escala (chamado no fim do love.draw).
function NavCursor.draw()
    if not active then return end
    local t = current()
    local k = require("src.ui.UiScale").k()
    -- glifo legível no Deck (7"): nunca menor que 26px de tela
    local size = math.max(26, math.floor(22 * k))
    if t then
        local MenuKit = require("src.ui.MenuKit")
        MenuKit.focusRing(t.x, t.y, t.w, t.h, love.timer.getTime(), math.floor(3 * k))
        -- glifo de confirmar POR FORA do canto superior direito (dentro ele
        -- cobria o selo de preço/custo das cartas)
        local lw = math.max(size, math.floor(size * 0.55) * #labelFor("confirm") + 8)
        NavCursor.drawGlyph(labelFor("confirm"), t.x + t.w - lw * 0.5, t.y - size * 0.85, size)
    end
    local IF = require("src.ui.InputFocus")
    for button, a in pairs(prevActions) do
        if a.rect and IF.allows(a.layer) then
            NavCursor.drawGlyph(labelFor(button), a.rect.x - size * 0.35, a.rect.y - size * 0.35, size)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Testes/tools: estado interno.
function NavCursor._reset()
    targets, prev, actions, prevActions = {}, {}, {}, {}
    active, device, focusKey, focusPt = false, "mouse", nil, nil
    lastMouseX, lastMouseY = nil, nil
end
function NavCursor._targets() return eligible() end
function NavCursor.focusKey() return focusKey end

return NavCursor
