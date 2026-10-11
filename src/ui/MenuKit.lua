-- src/ui/MenuKit.lua
-- Peças compartilhadas dos MODAIS DE SISTEMA navegáveis por teclado/gamepad
-- (PauseMenu + SettingsMenu, Out/2026). Três coisas que as duas telas tinham
-- que fazer IGUAL — e que antes nenhuma das duas fazia:
--
--   1. NAVEGAÇÃO: tecla → intenção ("up"/"down"/"left"/"right"/"confirm"/
--      "back"/"tab_next"/"tab_prev"). WASD + setas + Enter/Espaço + Tab/Q/E.
--      O gamepad chega aqui já traduzido em tecla (love.gamepadpressed no
--      main.lua), então a tabela é a ÚNICA fonte do mapa de controles.
--   2. ENTRADA: o painel desce do topo com leve overshoot e o véu escurece
--      junto (Balatro: o overlay "cai" no lugar — create_UIBox_generic_options
--      entra por alignment offset). reducedMotion tira o MOVIMENTO, nunca o
--      véu (memory/ui_layout_invariants.md §3: tira movimento, não informação).
--   3. FOCO: anel dourado pulsante em volta do item focado — o mesmo desenho
--      em qualquer modal, pra quem joga no teclado saber ONDE está.

local Palette = require("src.ui.Palette")

local MenuKit = {}

-- Duração da entrada (s). Curta de propósito: pausa é ferramenta, não cena.
MenuKit.ENTER_DUR = 0.24
-- Deslocamento inicial do painel (px, negativo = acima do lugar final).
MenuKit.ENTER_DROP = -36

local NAV = {
    up = "up", w = "up", kp8 = "up",
    down = "down", s = "down", kp2 = "down",
    left = "left", a = "left", kp4 = "left",
    right = "right", d = "right", kp6 = "right",
    ["return"] = "confirm", kpenter = "confirm", space = "confirm",
    escape = "back", backspace = "back",
    tab = "tab_next", e = "tab_next", pagedown = "tab_next",
    q = "tab_prev", pageup = "tab_prev",
}

-- Traduz tecla em intenção. `shift` (bool) inverte o Tab.
function MenuKit.intent(key, shift)
    local it = NAV[key]
    if it == "tab_next" and key == "tab" and shift then return "tab_prev" end
    return it
end

local function shiftDown()
    return love.keyboard and love.keyboard.isDown
        and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
end
MenuKit.shiftDown = shiftDown

-- Progresso eased da entrada (0..1) a partir do tempo desde o show.
-- easeOutBack suave: passa ~4% do lugar e assenta (o "cair" do Balatro).
function MenuKit.enterEase(t)
    local x = math.max(0, math.min(1, (t or 0) / MenuKit.ENTER_DUR))
    local c1 = 1.25
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function reducedMotion()
    return _G.gameSettings and _G.gameSettings.reducedMotion
end

-- Véu do modal: escurece junto com a entrada (sempre, mesmo com
-- reducedMotion — o véu é informação "isto é modal", não movimento).
function MenuKit.drawVeil(t, alpha)
    local x = math.max(0, math.min(1, (t or 0) / MenuKit.ENTER_DUR))
    love.graphics.setColor(0, 0, 0, (alpha or 0.62) * x)
    love.graphics.rectangle("fill", 0, 0,
        love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

-- Empurra a transformação da entrada. Sempre casar com love.graphics.pop().
function MenuKit.pushEnter(t)
    love.graphics.push()
    if reducedMotion() then return end
    local e = MenuKit.enterEase(t)
    love.graphics.translate(0, math.floor((1 - e) * MenuKit.ENTER_DROP))
end

-- Anel de foco: contorno duplo dourado com respiração leve. `pad` afasta o
-- anel do retângulo (default 3) pra não comer a borda do próprio item.
function MenuKit.focusRing(x, y, w, h, time, pad)
    pad = pad or 3
    local pulse = reducedMotion() and 1 or (0.75 + 0.25 * math.sin((time or 0) * 5))
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2)
    Palette.set(Palette.AGED_GOLD_LIGHT, pulse)
    love.graphics.rectangle("line", x - pad, y - pad, w + pad * 2, h + pad * 2, 4, 4)
    Palette.set(Palette.INK, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - pad - 2, y - pad - 2, w + pad * 2 + 4, h + pad * 2 + 4, 5, 5)
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Ponto dentro de retângulo {x,y,w,h}.
function MenuKit.hit(r, x, y)
    return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Retângulos que se cruzam? (usado pelos validate() de layout)
function MenuKit.overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
       and a.y < b.y + b.h and b.y < a.y + a.h
end

return MenuKit
