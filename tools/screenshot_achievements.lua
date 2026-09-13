-- tools/screenshot_achievements.lua
-- Galeria de conquistas (components/AchievementsScreen.lua) nos 5 idiomas.
--
--   love . screenshot_achievements            → pt_BR
--   love . screenshot_achievements de         → um idioma
--   love . screenshot_achievements all        → os 5, num processo só
--
-- POR QUE EXISTE: as 20 conquistas foram traduzidas (Set/2026) e a tela é um
-- GRID de 2 colunas com nome + descrição por célula. Nome alemão é o pior caso
-- de largura. O `TextFit` encolhe até caber, mas encolher tem piso (minSize) —
-- se o texto passar disso ele vaza, e isso só aparece OLHANDO.
--
-- Desbloqueia metade das conquistas de propósito: bloqueada e desbloqueada
-- usam cores e fontes diferentes, então as duas precisam ser conferidas.

local M = {}

local I18n             = require("src.i18n.I18n")
local AchievementSystem = require("src.systems.AchievementSystem")
local ProfileStats     = require("engine.ProfileStats")
local Defs             = require("src.data.achievements")

local ALL = { "pt_BR", "en", "es", "fr", "de" }

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[conquistas] " .. name .. " salvo")
    end)
    love.graphics.present()
end

function M.run(arg)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    -- Sandbox de tool: ProfileStats.flush() é no-op com HEADLESS_TOOL, então
    -- mexer no set de desbloqueadas aqui não toca o perfil do jogador.
    local set = ProfileStats.get().achievements or {}
    ProfileStats.get().achievements = set
    for i, d in ipairs(Defs) do
        set[d.id] = (i % 2 == 1) or nil     -- metade desbloqueada
    end

    local screen = require("components.AchievementsScreen"):new()
    screen:show(function() end)

    local locales = (arg == "all") and ALL or { arg or "pt_BR" }
    for _, loc in ipairs(locales) do
        I18n.setLocale(loc)
        -- countUnlocked/all são lidos no draw, então basta redesenhar.
        love.graphics.clear(0, 0, 0, 1)
        screen:draw()
        capture("achievements_" .. loc .. ".png")
    end

    love.event.quit()
end

return M
