-- tools/screenshot_unlock_showcase.lua
-- Capturas das REVELAÇÕES DO MENU (components/UnlockShowcase.lua): um painel
-- de cada tipo (carta, classe, maestria, selo, conquista) sobre o menu, com a
-- janela FALSIFICADA (mesmo truque do screenshot_uiscale).
--
--   love . test_one screenshot_unlock_showcase          → pt_BR + de
--   love . test_one screenshot_unlock_showcase fr       → um idioma
--   SHOWCASE_T=0.45 …                                   → instante da captura
--     (segundos desde a entrada do painel; padrão 1.0 = assentado. Um valor
--     no meio da revelação mostra pop, varredura de luz e clarão.)
--
-- Saída: showcase_<tipo>_<W>x<H>_<loc>[_t<ms>].png no save dir.

local M = {}

local SIZES = { { 1024, 768 }, { 1920, 1080 } }

function M.run(arg)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    local PS = require("engine.ProfileStats")
    local UQ = require("src.systems.UnlockQueue")
    local Showcase = require("components.UnlockShowcase")
    local prevProfile = PS._swapForTests({ runs = 3, wins = 1, losses = 2 })

    local ITEMS = {
        { kind = "card", id = "warrior_berserker_rage" },
        { kind = "class", id = "mage" },
        { kind = "mastery", classId = "warrior", level = 3 },
        { kind = "seal", classId = "warrior", n = 1 },
        { kind = "achievement", id = "primeiro_chefe" },
    }
    -- carta existente com arte (a primeira do pacote 2 do guerreiro)
    do
        local Data = require("src.data.unlocks")
        local b = Data.CLASS_BUNDLES.warrior and Data.CLASS_BUNDLES.warrior[2]
        if b and b.cards[1] then ITEMS[1].id = b.cards[1] end
    end

    local locales = arg and { arg } or { "pt_BR", "de" }
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    for _, loc in ipairs(locales) do
        I18n.setLocale(loc, true)
        for _, sz in ipairs(SIZES) do
            local w, h = sz[1], sz[2]
            love.graphics.getWidth = function() return w end
            love.graphics.getHeight = function() return h end
            love.graphics.getDimensions = function() return w, h end
            FontManager.clearCache()
            local menu = require("components.Menu"):new()
            for _ = 1, 72 do
                if _G.EventManager then _G.EventManager.update(1 / 30) end
                menu:update(1 / 30)
            end
            local canvas = love.graphics.newCanvas(w, h)
            for i, it in ipairs(ITEMS) do
                UQ.clear()
                for j = i, #ITEMS do UQ.push(ITEMS[j]) end
                local s = Showcase:new()
                s:watch("menu", 1)
                s.idx, s.total = i, #ITEMS
                -- assentado (t = 1 s) por padrão; SHOWCASE_T captura no meio
                local tCap = tonumber(os.getenv("SHOWCASE_T") or "") or 1.0
                for _ = 1, math.max(1, math.floor(tCap * 30 + 0.5)) do s:update(1 / 30) end
                -- SHOWCASE_HOVER=1: mouse sobre a carta revelada (sobe + tooltip);
                -- SHOWCASE_INSPECT=1: a inspeção da Coleção aberta nela.
                local mode = ""
                if it.kind == "card" and (os.getenv("SHOWCASE_HOVER") == "1" or os.getenv("SHOWCASE_INSPECT") == "1") then
                    love.graphics.setCanvas(canvas); s:draw(); love.graphics.setCanvas()
                    local r = s._cardBox
                    if r then
                        local k = UiScale.k(w, h)
                        local rm = love.mouse.getPosition
                        love.mouse.getPosition = function() return (r.x + r.w / 2) * k, (r.y + r.h * 0.6) * k end
                        for _ = 1, 20 do
                            s:update(1 / 30)
                            love.graphics.setCanvas(canvas); s:draw(); love.graphics.setCanvas()
                        end
                        if os.getenv("SHOWCASE_INSPECT") == "1" then
                            s:openInspect()
                            for _ = 1, 20 do s:update(1 / 30) end
                            mode = "_inspect"
                        else
                            mode = "_hover"
                        end
                        love.mouse.getPosition = rm
                    end
                end
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                menu:draw()
                s:draw()
                love.graphics.setCanvas()
                local L = Showcase.layout(w / UiScale.k(w, h), h / UiScale.k(w, h))
                local probs = Showcase.validate(L, w / UiScale.k(w, h), h / UiScale.k(w, h))
                local suffix = (os.getenv("SHOWCASE_T") and ("_t" .. math.floor(tCap * 1000)) or "") .. mode
                local name = ("showcase_%s_%dx%d_%s%s.png"):format(it.kind, w, h, loc, suffix)
                canvas:newImageData():encode("png", name)
                print(("[showcase] %s  k=%.2f problemas=%d"):format(name, UiScale.k(w, h), #probs))
            end
        end
    end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    UQ.clear()
    PS._swapForTests(prevProfile)
    FontManager.clearCache()
    print("[showcase] salvos em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
