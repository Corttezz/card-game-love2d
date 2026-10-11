-- tools/screenshot_class_select.lua
-- Valida o "Salão dos Emblemas" (v3, Out/2026 — memory/class_emblems.md).
-- Renderiza cada estado num CANVAS do tamanho pedido com a janela
-- FALSIFICADA (getWidth/getHeight) — setMode repetido dentro de tool trava
-- (memory/ui_layout_invariants.md). Gera, no save dir:
--   class_select_<W>x<H>_<estado>.png
-- estados:
--   fresh  — perfil novo: só o guerreiro liberado (mago/ladino acorrentados)
--   mixed  — mago liberado (maestria 3/5), ladino bloqueado com progresso 2/4
--   all    — todas liberadas, hover no mago (emblema animado + aura)
--   pick   — momento da escolha (flash + anel + faíscas)
--   denied — clique numa bloqueada (tremor; NÃO inicia run)
--   love . screenshot_class_select

local M = {}

local SIZES = { { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1920, 1080 } }

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH

local realMouse = love.mouse.getPosition
local mouseX, mouseY = 2, 2

local function installFake()
    love.mouse.getPosition = function() return mouseX, mouseY end
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end

local function restore()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.mouse.getPosition = realMouse
end

local function hoverPanel(screen, id)
    if not id then mouseX, mouseY = 2, 2 return end
    local b = screen.buttons[id]
    mouseX, mouseY = b.x + b.width / 2, b.y + b.height / 2
end

-- Cenários do UnlockSystem (monkeypatch das 3 funções do contrato — vale
-- tanto pro stub quanto pra versão real da frente progressão).
local function scenario(US, name)
    local orig = M._orig
    if name == "fresh" then
        US.isClassUnlocked = function(id) return id == "warrior" end
        US.getClassUnlockInfo = function(id)
            if id == "mage" then return { unlocked = false, reqKey = "unlock.class.mage_req", vars = { act = 2 }, progress = 0, goal = 2 } end
            if id == "rogue" then return { unlocked = false, reqKey = "unlock.class.rogue_req", vars = { act = 4 }, progress = 0, goal = 4 } end
            return { unlocked = true, reqKey = "unlock.class.default", vars = {}, progress = 1, goal = 1 }
        end
        US.getClassMastery = function() return { level = 1, maxLevel = 5, xp = 30, xpToNext = 100 } end
    elseif name == "mixed" then
        US.isClassUnlocked = function(id) return id ~= "rogue" end
        US.getClassUnlockInfo = function(id)
            if id == "rogue" then return { unlocked = false, reqKey = "unlock.class.rogue_req", vars = { act = 4 }, progress = 2, goal = 4 } end
            return { unlocked = true, reqKey = "unlock.class.default", vars = {}, progress = 1, goal = 1 }
        end
        US.getClassMastery = function(id)
            if id == "mage" then return { level = 3, maxLevel = 5, xp = 140, xpToNext = 200 } end
            return { level = 5, maxLevel = 5, xp = 0, xpToNext = 0 }
        end
    else -- all
        US.isClassUnlocked = function() return true end
        US.getClassUnlockInfo = function() return { unlocked = true, reqKey = "unlock.class.default", vars = {}, progress = 1, goal = 1 } end
        US.getClassMastery = function() return { level = 2, maxLevel = 5, xp = 50, xpToNext = 150 } end
    end
end

local function pump(screen, secs)
    local dt = 1 / 30
    for _ = 1, math.floor(secs / dt) do
        _G.EventManager.update(dt)
        screen:update(dt)
    end
end

local function shoot(screen, w, h, name)
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    local file = ("class_select_%dx%d_%s.png"):format(w, h, name)
    canvas:newImageData():encode("png", file)
    print("[class_select] " .. file .. " salvo")
end

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local US = require("src.systems.UnlockSystem")
    M._orig = { US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery }

    -- TIRA DE ANIMAÇÃO: cada emblema em 8 instantes (0.15s) + versão
    -- acorrentada — valida o idle procedural sem precisar de vídeo.
    do
        local ClassEmblem = require("src.ui.ClassEmblem")
        local ids = { "warrior", "mage", "rogue" }
        local cell = 160
        local canvas = love.graphics.newCanvas(cell * 9, cell * #ids)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.16, 0.12, 0.10, 1)
        for f = 0, 7 do
            for row, id in ipairs(ids) do
                ClassEmblem.draw(id, f * cell + cell / 2, (row - 1) * cell + cell / 2, cell - 16,
                    { hover = 1 })
            end
            for _ = 1, 9 do ClassEmblem.update(1 / 60, { warrior = 1, mage = 1, rogue = 1 }) end
        end
        for row, id in ipairs(ids) do
            ClassEmblem.draw(id, 8 * cell + cell / 2, (row - 1) * cell + cell / 2, cell - 16,
                { locked = true })
        end
        love.graphics.setCanvas()
        canvas:newImageData():encode("png", "class_emblems_strip.png")
        print("[class_select] class_emblems_strip.png salvo")
    end

    installFake()
    local ok, err = pcall(function()
        for _, sz in ipairs(SIZES) do
            fakeW, fakeH = sz[1], sz[2]
            require("src.ui.FontManager").clearCache()
            local Screen = require("components.ClassSelectionScreen")

            for _, st in ipairs({ "fresh", "mixed", "all" }) do
                scenario(US, st)
                local screen = Screen:new()
                screen:show(function() end, function() end)
                hoverPanel(screen, st == "all" and "mage" or nil)
                pump(screen, 1.2)
                shoot(screen, sz[1], sz[2], st)

                if st == "all" then
                    screen:selectClass("mage")
                    pump(screen, 0.15)
                    shoot(screen, sz[1], sz[2], "pick")
                elseif st == "fresh" then
                    local accepted = screen:selectClass("rogue")
                    print("[class_select] clique no ladino bloqueado aceito? " .. tostring(accepted))
                    hoverPanel(screen, "rogue")
                    pump(screen, 0.07)
                    shoot(screen, sz[1], sz[2], "denied")
                end
            end
        end
    end)
    restore()
    US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery = M._orig[1], M._orig[2], M._orig[3]
    if not ok then print("[class_select] ERRO: " .. tostring(err)) end
    love.event.quit()
end

return M
