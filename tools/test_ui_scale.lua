-- tools/test_ui_scale.lua
-- ESCALA GLOBAL DE UI (src/ui/UiScale.lua): fator por janela, espaço virtual
-- dentro do contexto (dimensões, mouse, scissor, fonte), adoção das telas
-- (layout + clique no mesmo espaço), higiene de vazamento e a opção
-- "Escala da interface" das Configurações.
--
--   love . test_one test_ui_scale
--
-- Janela e mouse FALSIFICADOS; tudo restaurado no fim (inclusive o force(1)
-- que o testkit liga pros outros testes).

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("escala de UI")
    local UiScale = require("src.ui.UiScale")
    local I18n = require("src.i18n.I18n")
    local SaveManager = require("engine.SaveManager")

    local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local realMouse = love.mouse.getPosition
    local fw, fh = 1024, 768
    love.graphics.getWidth = function() return fw end
    love.graphics.getHeight = function() return fh end
    love.graphics.getDimensions = function() return fw, fh end
    local mx, my = -100, -100
    love.mouse.getPosition = function() return mx, my end
    local settingsPath = SaveManager.PATHS.settings
    local savedFile = love.filesystem.getInfo(settingsPath) and love.filesystem.read(settingsPath) or nil
    local savedGS = _G.gameSettings
    _G.gameSettings = SaveManager.loadSettings()
    local savedLocale = I18n.getLocale()
    local savedMul = UiScale.userMultiplier()
    local realResize = love.resize
    love.resize = nil
    UiScale.force(nil)
    UiScale.adoptDefaults()
    I18n.setLocale("pt_BR")

    local ok, err = pcall(function()
        -- ===== 1. fator =====
        UiScale.setUserMultiplier(1)
        local cases = { { 1024, 768, 1 }, { 1366, 768, 1 }, { 1920, 1080, 1.5 },
                        { 2560, 1440, 2 }, { 3840, 2160, 2.5 }, { 800, 600, 1 } }
        for _, c in ipairs(cases) do
            t:eq(("k %dx%d"):format(c[1], c[2]), UiScale.k(c[1], c[2]), c[3])
        end
        UiScale.setUserMultiplier(0.8)
        t:eq("80% em 1440p (2 x 0.8 = 1.6 -> degrau 1.5)", UiScale.k(2560, 1440), 1.5)
        UiScale.setUserMultiplier(1.5)
        t:eq("150% em 1440p", UiScale.k(2560, 1440), 3)
        UiScale.setUserMultiplier(0.8)
        t:eq("80% em 1024 nunca abaixo de 0.75", UiScale.k(1024, 768), 0.75)
        UiScale.setUserMultiplier(1)

        -- ===== 2. contexto =====
        fw, fh = 2560, 1440
        mx, my = 1000, 500
        UiScale.begin()
        t:eq("dentro: largura virtual", love.graphics.getWidth(), 1280)
        t:eq("dentro: altura virtual", love.graphics.getHeight(), 720)
        local vx, vy = love.mouse.getPosition()
        t:eq("dentro: mouse virtual x", vx, 500)
        t:eq("dentro: mouse virtual y", vy, 250)
        t:eq("dentro: fonte com dpiscale = k", UiScale.fontDpi(), 2)
        love.graphics.setScissor(10, 10, 100, 50)
        UiScale.finish()
        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor()
        t:eq("scissor convertido pra pixels reais (x)", sx, 20)
        t:eq("scissor convertido pra pixels reais (w)", sw, 200)
        t:eq("fora: largura real de volta", love.graphics.getWidth(), 2560)
        t:eq("fora: mouse real de volta", (love.mouse.getPosition()), 1000)
        t:eq("fora: fonte 1:1", UiScale.fontDpi(), 1)

        -- vazamento: begin sem finish é consertado pelo reset do frame
        UiScale.begin(); UiScale.begin()
        UiScale.reset()
        t:eq("reset restaura dimensoes apos vazamento", love.graphics.getWidth(), 2560)
        t:falsy("reset zera o contexto", UiScale.isActive())

        -- ===== 3. tela adotada: layout + clique no mesmo espaço =====
        local game = TK.newRunGame("warrior")
        UiScale.force(nil)   -- newRunGame passa pelo bootstrap, que congela em 1
        local PauseMenu = require("components.PauseMenu")
        local closedBy
        local pause = PauseMenu:new()
        FontManager.clearCache()
        pause:show(game, { onOpenSettings = function() closedBy = "settings" end })
        local p = pause._panel
        t:truthy("painel da pausa cabe no espaco virtual 1280x720",
            p.x >= 0 and p.y >= 0 and p.x + p.w <= 1280 and p.y + p.h <= 720)
        t:eq("validate da pausa em 1440p", #pause:validate(), 0)
        -- clique em pixels REAIS no centro da linha "Configurações"
        local row = pause.rows[2]
        mx, my = (row.x + row.w / 2) * 2, (row.y + row.h / 2) * 2
        pause:mousepressed(mx, my, 1)
        pause:mousereleased(mx, my, 1)
        t:eq("clique real cai na linha virtual certa", closedBy, "settings")
        -- hover por polling dentro do update
        pause:show(game, {})
        local r1 = pause.rows[1]
        mx, my = (r1.x + 4) * 2, (r1.y + 4) * 2
        pause:update(1 / 60)   -- primeiro update só registra o mouse
        mx = mx + 2
        pause:update(1 / 60)
        t:eq("hover por polling acha a linha (mouse virtual)", pause:focusedKey(), "resume")
        pause:hide()

        -- ===== 4. opção nas Configurações =====
        local SettingsMenu = require("components.SettingsMenu")
        _G.gameSettings.uiScale = 1
        UiScale.setUserMultiplier(1)
        local sm = SettingsMenu:new()
        sm:show({ onClose = function() end })
        sm:setTab(2)
        local idx
        for i, r in ipairs(sm.rows) do if r.def.key == "ui_scale" then idx = i end end
        t:truthy("aba Video tem a linha Escala da interface", idx ~= nil)
        if idx then
            t:eq("rotulo Auto no padrao", sm.rows[idx].def.get(), I18n.t("settings.ui_scale_auto"))
            sm:stepRow(idx, 1)
            t:near("direita sobe pra 125%", UiScale.userMultiplier(), 1.25, 0.001)
            t:near("persistido", SaveManager.loadSettings().uiScale, 1.25, 0.001)
            t:eq("rotulo em %", sm.rows[idx].def.get(), "125%")
            sm:stepRow(idx, 1); sm:stepRow(idx, 1)
            t:near("trava no maior (sem dar a volta)", UiScale.userMultiplier(), 1.5, 0.001)
            for _ = 1, 6 do sm:stepRow(idx, -1) end
            t:near("trava no menor", UiScale.userMultiplier(), 0.8, 0.001)
            sm:stepRow(idx, 1); sm:stepRow(idx, 1)
            t:near("volta ao Auto", UiScale.userMultiplier(), 1, 0.001)
            t:eq("validate das configuracoes em 1440p", #sm:validate(), 0)
        end
        sm:hide(true)

        -- chaves nos 5 idiomas
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            local chunk = love.filesystem.load("src/i18n/locales/" .. loc .. ".lua")
            local data = chunk and chunk() or {}
            local s = data.settings or {}
            t:truthy(loc .. ": settings.ui_scale/ui_scale_auto",
                type(s.ui_scale) == "string" and type(s.ui_scale_auto) == "string")
        end
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)

    UiScale.reset()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
    love.mouse.getPosition = realMouse
    love.resize = realResize
    UiScale.setUserMultiplier(savedMul)
    UiScale.force(1)
    FontManager.clearCache()
    if savedFile then love.filesystem.write(settingsPath, savedFile)
    else love.filesystem.remove(settingsPath) end
    _G.gameSettings = savedGS
    I18n.setLocale(savedLocale)
    return t:done()
end

return M
