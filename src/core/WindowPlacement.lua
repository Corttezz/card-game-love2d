-- src/core/WindowPlacement.lua
-- Lembra em QUAL MONITOR (e onde) a janela estava e reabre la.
--
-- Antes, o jogo abria sempre no monitor 1 (conf.lua `t.window.display = 1`):
-- quem joga no segundo monitor arrastava a janela toda vez. Agora:
--   * no encerramento (AppLoop.shutdown) gravamos em settings.lua:
--       windowDisplay = indice do monitor (1..n)
--       windowX, windowY = posicao da janela DENTRO desse monitor (so em
--                          modo janela — em tela cheia ficam os ultimos
--                          valores de janela, que e o que se quer ao sair
--                          da tela cheia num boot futuro)
--   * no love.load, `restore` move a janela pro monitor salvo ANTES do
--     setFullscreen/setMode (tela cheia "desktop" ocupa o monitor onde a
--     janela esta). Monitor que nao existe mais (notebook sem o externo)
--     cai no 1 — nunca abre fora da tela.
-- As chaves sao extras no settings.lua: SaveManager.loadSettings preserva
-- chave desconhecida, entao nao precisam de default.

local WindowPlacement = {}

-- Monitor salvo, se ainda existe. Puro sobre `count` (testavel).
function WindowPlacement.validDisplay(settings, count)
    local d = tonumber(settings and settings.windowDisplay)
    if d and d >= 1 and d <= (count or 1) and d == math.floor(d) then return d end
    return 1
end

-- Posicao salva se a janela (w x h) cabe inteira no desktop (dw x dh) do
-- monitor; senao nil (quem chama centraliza). Pura (testavel).
function WindowPlacement.validPosition(settings, w, h, dw, dh)
    local x, y = tonumber(settings and settings.windowX), tonumber(settings and settings.windowY)
    if not (x and y and w and h and dw and dh) then return nil end
    if x < 0 or y < 0 or x + w > dw or y + h > dh then return nil end
    return math.floor(x), math.floor(y)
end

-- Boot: leva a janela pro monitor salvo. Devolve o indice do monitor em uso
-- (o love.load mede o desktop DELE pra dimensionar a janela).
function WindowPlacement.restore(settings)
    local count = love.window.getDisplayCount and love.window.getDisplayCount() or 1
    local d = WindowPlacement.validDisplay(settings, count)
    if d ~= 1 then
        local okDim, dw, dh = pcall(love.window.getDesktopDimensions, d)
        if okDim then
            local w, h = love.graphics.getDimensions()
            love.window.setPosition(math.max(0, math.floor((dw - w) / 2)),
                math.max(0, math.floor((dh - h) / 2)), d)
        end
    end
    return d
end

-- Depois do setMode da janela (modo janela): aplica a posicao salva se
-- couber no monitor; senao mantem o centralizado.
function WindowPlacement.restorePosition(settings, display)
    local okDim, dw, dh = pcall(love.window.getDesktopDimensions, display)
    if not okDim then return end
    local w, h = love.graphics.getDimensions()
    local x, y = WindowPlacement.validPosition(settings, w, h, dw, dh)
    if x then love.window.setPosition(x, y, display) end
end

-- Encerramento: grava monitor (+ posicao em modo janela) em `settings`.
-- Devolve true se algo mudou (quem chama decide salvar).
function WindowPlacement.remember(settings)
    if not (love.window and love.window.isOpen and love.window.isOpen()) then return false end
    local x, y, d = love.window.getPosition()
    if not d then return false end
    local changed = settings.windowDisplay ~= d
    settings.windowDisplay = d
    if not love.window.getFullscreen() and not (love.window.isMinimized and love.window.isMinimized()) then
        changed = changed or settings.windowX ~= x or settings.windowY ~= y
        settings.windowX, settings.windowY = x, y
    end
    return changed
end

return WindowPlacement
