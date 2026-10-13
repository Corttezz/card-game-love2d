-- tools/screenshot_class_select.lua
-- Seleção de classe v4 ("página do grimório", Out/2026 — memory/class_emblems.md).
-- Renderiza cada estado num CANVAS do tamanho pedido com a janela
-- FALSIFICADA (getWidth/getHeight) — setMode repetido dentro de tool trava
-- (memory/ui_layout_invariants.md). Passa pelo UiScale de verdade (a tela é
-- adotada no love.load). Gera, no save dir:
--   class_select_<W>x<H>_<estado>.png
-- estados:
--   fresh    — perfil novo: só o guerreiro liberado, foco nele
--   locked   — perfil novo, foco no ladino bloqueado (silhueta + condição)
--   all      — todas liberadas, foco no mago (resumo)
--   details  — mago com o marcador DETALHES aberto
--   starter_hover — carta inicial em hover (lift + tooltip ao lado)
--   inspect  — a inspeção da Coleção aberta na carta inicial
--   seal     — Selo 7, foco no guerreiro, mouse na faixa do selo (regra)
--   seal_cap — Selo 7, foco no ladino que só vai até o 1 (aviso de teto)
--   pick     — momento da escolha (anel + faíscas)
--   denied   — clique em COMEÇAR numa bloqueada (tremor; NÃO inicia run)
-- 1280x800 sai com o multiplicador do Steam Deck (125%), como no aparelho.
-- CS_LOCALE=de troca o idioma; CS_SIZES=1024x768,1920x1080 filtra tamanhos.
--   love . test_one screenshot_class_select

local M = {}

local SIZES = { { 1024, 768 }, { 1280, 800 }, { 1920, 1080 } }

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

-- Mouse num retângulo VIRTUAL da tela (o UiScale divide o mouse real por k).
local function hoverRect(r)
    if not r then mouseX, mouseY = 2, 2 return end
    local k = require("src.ui.UiScale").k()
    mouseX, mouseY = (r.x + r.w / 2) * k, (r.y + r.h / 2) * k
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
    local file = ("class_select_%dx%d_%s%s.png"):format(w, h,
        os.getenv("CS_LOCALE") and (os.getenv("CS_LOCALE") .. "_") or "", name)
    canvas:newImageData():encode("png", file)
    print("[class_select] " .. file .. " salvo")
end

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    if os.getenv("CS_LOCALE") then require("src.i18n.I18n").setLocale(os.getenv("CS_LOCALE")) end
    if os.getenv("CS_SIZES") then
        SIZES = {}
        for w, h in os.getenv("CS_SIZES"):gmatch("(%d+)x(%d+)") do
            SIZES[#SIZES + 1] = { tonumber(w), tonumber(h) }
        end
    end
    require("src.ui.PixelCanvas").enableNearest()
    local US = require("src.systems.UnlockSystem")
    M._orig = { US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery,
        US.getMaxSeal, US.getSealWon, US.getClassRecord }

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
    local UiScale = require("src.ui.UiScale")
    local ok, err = pcall(function()
        for _, sz in ipairs(SIZES) do
            fakeW, fakeH = sz[1], sz[2]
            UiScale.setDeviceMultiplier((sz[1] == 1280 and sz[2] == 800) and 1.25 or 1)
            require("src.ui.FontManager").clearCache()
            local Screen = require("components.ClassSelectionScreen")
            local function fresh(st, focus)
                scenario(US, st)
                hoverRect(nil)
                local screen = Screen:new()
                screen:show(function() end, function() end)
                if focus then screen:focusClass(focus) end
                pump(screen, 1.2)
                return screen
            end

            local s1 = fresh("fresh")
            shoot(s1, sz[1], sz[2], "fresh")
            local s2 = fresh("fresh", "rogue")
            shoot(s2, sz[1], sz[2], "locked")
            print("[class_select] COMEÇAR no ladino bloqueado aceito? " .. tostring(s2:selectClass("rogue")))
            pump(s2, 0.07)
            shoot(s2, sz[1], sz[2], "denied")

            local s3 = fresh("all", "mage")
            shoot(s3, sz[1], sz[2], "all")
            s3:toggleDetails()
            pump(s3, 0.6)
            shoot(s3, sz[1], sz[2], "details")
            -- carta inicial em hover (lift + tooltip ao lado) e a inspeção
            local r1 = s3._starterRects and s3._starterRects[1]
            if r1 then
                hoverRect({ x = r1.x, y = r1.y + r1.h * 0.2, w = r1.w, h = r1.h * 0.6 })
                pump(s3, 0.6)
                shoot(s3, sz[1], sz[2], "starter_hover")
                s3:openInspect(1)
                hoverRect(nil)
                pump(s3, 0.6)
                shoot(s3, sz[1], sz[2], "inspect")
                s3.inspectModal:hide()
            end

            -- Selos: guerreiro liberou até o 10, mago até o 4, ladino até o 1.
            local caps = { warrior = 10, mage = 4, rogue = 1 }
            US.getMaxSeal = function(id) return caps[id] or 0 end
            US.getSealWon = function(id) return (caps[id] or 0) - 1 end
            US.getClassRecord = function(id)
                return { bestScore = id == "warrior" and 48210 or 9050,
                    bestEndless = id == "warrior" and 19 or 0 }
            end
            local s4 = fresh("all")
            s4.seal = 7
            s4:_clampSeal()
            hoverRect(s4.layout.seal)
            pump(s4, 0.3)
            shoot(s4, sz[1], sz[2], "seal")
            hoverRect(nil)
            s4:focusClass("rogue")
            pump(s4, 0.6)
            shoot(s4, sz[1], sz[2], "seal_cap")
            US.getMaxSeal, US.getSealWon, US.getClassRecord = M._orig[4], M._orig[5], M._orig[6]

            local s5 = fresh("all", "mage")
            s5:selectClass("mage")
            pump(s5, 0.15)
            shoot(s5, sz[1], sz[2], "pick")
        end
        UiScale.setDeviceMultiplier(1)
    end)
    restore()
    US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery = M._orig[1], M._orig[2], M._orig[3]
    US.getMaxSeal, US.getSealWon, US.getClassRecord = M._orig[4], M._orig[5], M._orig[6]
    if not ok then print("[class_select] ERRO: " .. tostring(err)) end
    love.event.quit()
end

return M
