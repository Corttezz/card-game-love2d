-- tools/screenshot_event.lua
-- Captura a EventScreen em todos os locales — a tela não tinha cobertura
-- visual nenhuma.
--
-- POR QUE POR LOCALE: chave de i18n errada não quebra nada. `I18n.t` cai no
-- fallback, que é justamente o texto PT, então em português a tela fica
-- PERFEITA e só quebra em inglês/alemão — onde ninguém olha. Renderizar nos 5
-- é o único jeito de provar que a chave resolve, e é mais barato que descobrir
-- em produção (foi assim que duas telas saíram bilíngues, ver
-- tools/test_no_hardcoded_pt.lua).
--
-- Roda: love . screenshot_event [locale]
--   sem argumento  → um PNG por locale (pt_BR, en, es, fr, de)
--   com argumento  → só aquele
-- Saída: event_<locale>.png no diretório de save do LÖVE.

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

function M.run(only)
    local I18n        = require("src.i18n.I18n")
    local Events      = require("src.data.events")
    local EventScreen = require("components.EventScreen")
    local Game        = require("src.core.Game")
    local Rng         = require("src.systems.Rng")

    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")

    -- Seed fixa: o MESMO evento nos 5 idiomas, senão a comparação não vale.
    Rng.setActive(Rng.new(20260912))

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    local ev = Events.roll(1, {})
    if not ev then
        print("[screenshot_event] nenhum evento sorteado")
        return false
    end
    print("[screenshot_event] evento: " .. tostring(ev.id)
        .. " (" .. tostring(#(ev.options or {})) .. " opcoes)")

    local list = only and { only } or LOCALES
    local screen = EventScreen:new()

    for _, loc in ipairs(list) do
        I18n.setLocale(loc)
        require("src.ui.FontManager").clearCache()

        screen:show(ev, game, function() end)

        -- ASSENTA a entrada antes de capturar. O tool é anterior à animação
        -- (Set/2026) e capturava em t≈0 — quando a cortina do fade ainda está
        -- fechada, ou seja, PNG preto nos 5 idiomas. Um tool que não avança o
        -- relógio da tela mede o frame errado e não avisa; foi só olhar a
        -- imagem que apareceu. Pump do EventManager + update, como no jogo.
        local EM = require("engine.EventManager")
        for _ = 1, 60 do
            EM.update(1 / 60)
            screen:update(1 / 60)
        end

        -- Canvas em vez de love.graphics.captureScreenshot: o capture é
        -- ASSÍNCRONO (resolve no fim do frame), então num laço de 5 as
        -- capturas se atropelam e saem todas iguais — ou nenhuma. O canvas
        -- resolve na hora e o laço fica determinístico.
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local canvas = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(canvas)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        screen:draw()
        love.graphics.setCanvas()

        local name = "event_" .. loc .. ".png"
        canvas:newImageData():encode("png", name)
        print("[screenshot_event] " .. name)

        screen:hide()
    end

    return true
end

return M
