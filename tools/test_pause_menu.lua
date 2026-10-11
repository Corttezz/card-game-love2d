-- tools/test_pause_menu.lua
-- Trava do MENU DE PAUSA v3 + CONFIGURAÇÕES v3 (Out/2026).
--
-- O que garante:
--   1. pausa abre/fecha (ESC, Enter em Continuar, clique) e o foco nasce em
--      Continuar; clique só dispara se o PRESS nasceu no mesmo item;
--   2. abandono exige 2 etapas, foco cai no "Não" (default seguro), ESC
--      desarma sem fechar, e só "Sim" chama onAbandon (uma vez);
--   3. atalhos D/J/M fecham a pausa e abrem a tela certa;
--   4. Configurações: abas, ←/→ ajusta, Enter alterna, tudo PERSISTE em disco
--      (SaveManager) e no runtime (_G.gameSettings, CombatBeats.speed);
--      VOLTAR chama onClose (a pausa se reabre) e ESC também;
--   5. RESIZE com janela falsificada (memory/ui_layout_invariants.md §2 —
--      "nascer grande ≠ crescer"): validate() sem violação em 7 tamanhos,
--      nos estados normal / confirmando / cada aba, em pt_BR e DE;
--   6. as chaves novas existem nos 5 locales.
--
-- Efeitos colaterais isolados: settings.tool.lua é restaurado byte a byte,
-- locale/CombatBeats.speed/gameSettings voltam ao que eram, e a janela/vsync
-- reais nunca são tocados (stubs).
--
--   love . test_one test_pause_menu
--   love . test_all

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

-- ===== Janela falsa =====
local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    fakeW, fakeH = nil, nil
end
-- Espelha o love.resize real: limpa fontes ANTES de avisar a tela.
local function resizeTo(screens, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    for _, s in ipairs(screens) do s:resize() end
end

local function report(t, label, problems)
    t:eq(label, #problems, 0)
    for _, p in ipairs(problems) do print("      -> " .. p) end
end

-- Mouse falso (o PauseMenu/Button leem love.mouse.getPosition).
local realMouse = love.mouse.getPosition
local mouse = { x = -100, y = -100 }
local function installFakeMouse()
    love.mouse.getPosition = function() return mouse.x, mouse.y end
end
local function restoreMouse() love.mouse.getPosition = realMouse end

local function center(r) return r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2) end

function M.run()
    TK.bootstrap()
    TK.seedRng(7)
    local t = TK.new("pausa + configuracoes v3")
    local I18n = require("src.i18n.I18n")
    local SaveManager = require("engine.SaveManager")
    local CombatBeats = require("src.systems.CombatBeats")
    local PauseMenu = require("components.PauseMenu")
    local SettingsMenu = require("components.SettingsMenu")

    -- ===== snapshot do que o teste pode tocar =====
    local settingsPath = SaveManager.PATHS.settings
    local savedFile = love.filesystem.getInfo(settingsPath)
        and love.filesystem.read(settingsPath) or nil
    local savedLocale = I18n.getLocale()
    local savedSpeed = CombatBeats.speed
    local savedGS = _G.gameSettings
    _G.gameSettings = SaveManager.loadSettings()
    local savedAudio = _G.audioSystem
    _G.audioSystem = nil   -- volumes vão pro gameSettings (caminho sem áudio)
    local win = love.window
    local realFS, realGetFS = win.setFullscreen, win.getFullscreen
    local realSetV, realGetV = win.setVSync, win.getVSync
    local realResize = love.resize
    local fs, vs = false, 1
    win.setFullscreen = function(v) fs = v; return true end
    win.getFullscreen = function() return fs end
    win.setVSync = function(v) vs = v end
    win.getVSync = function() return vs end
    love.resize = nil

    installFakeWindow()
    installFakeMouse()
    fakeW, fakeH = 1024, 768
    I18n.setLocale("pt_BR")

    local ok, err = pcall(function()
        local game = TK.newRunGame("warrior")
        local calls = {}
        local function cb(name) return function() calls[name] = (calls[name] or 0) + 1 end end
        local callbacks = {
            onOpenSettings = cb("settings"), onSaveQuit = cb("save_quit"),
            onAbandon = cb("abandon"), onOpenDeck = cb("deck"),
            onOpenJokers = cb("jokers"), onOpenJournal = cb("journal"),
        }

        -- ===== 1. abrir / fechar / foco =====
        local pause = PauseMenu:new()
        pause:show(game, callbacks)
        t:truthy("pausa abre", pause:isVisible())
        t:eq("foco nasce em Continuar", pause:focusedKey(), "resume")
        t:eq("4 acoes com run ativa", #pause.rows, 4)
        t:eq("3 atalhos com run ativa", #pause.shortcuts, 3)
        t:truthy("resumo da run tem 6 celulas", #(pause:runSummary() or {}) == 6)
        pause:keypressed("escape")
        t:falsy("ESC fecha a pausa", pause:isVisible())

        pause:show(game, callbacks)
        pause:keypressed("down")
        t:eq("seta pra baixo vai pra Configuracoes", pause:focusedKey(), "settings")
        pause:keypressed("up"); pause:keypressed("up")
        t:eq("acima de Continuar ficam os atalhos", pause:focusedKey(), "deck")
        pause:keypressed("right")
        t:eq("direita anda entre atalhos", pause:focusedKey(), "jokers")
        pause:keypressed("down")
        pause:keypressed("return")
        t:falsy("Enter em Continuar fecha", pause:isVisible())

        -- tecla qualquer nao vaza (modal engole)
        pause:show(game, callbacks)
        t:truthy("modal engole tecla estranha", pause:keypressed("x"))
        t:truthy("x nao fechou", pause:isVisible())

        -- clique: so com press+release no mesmo item
        local resumeRow = pause.rows[1]
        mouse.x, mouse.y = center(resumeRow)
        pause:mousereleased(mouse.x, mouse.y, 1)
        t:truthy("release sem press (clique que abriu) nao dispara", pause:isVisible())
        pause:mousepressed(mouse.x, mouse.y, 1)
        pause:mousereleased(mouse.x, mouse.y, 1)
        t:falsy("press+release em Continuar fecha", pause:isVisible())

        -- Configuracoes
        pause:show(game, callbacks)
        pause:keypressed("down"); pause:keypressed("return")
        t:eq("Configuracoes chama onOpenSettings", calls.settings, 1)
        t:falsy("e fecha a pausa", pause:isVisible())

        -- ===== 2. abandono em 2 etapas =====
        pause:show(game, callbacks)
        for _ = 1, 3 do pause:keypressed("down") end
        t:eq("chega no Abandonar", pause:focusedKey(), "abandon")
        pause:keypressed("return")
        t:truthy("primeiro Enter ARMA a confirmacao", pause.confirmingAbandon)
        t:eq("foco cai no Nao (default seguro)", pause:focusedKey(), "abandon_no")
        t:eq("nada abandonado ainda", calls.abandon, nil)
        pause:keypressed("escape")
        t:falsy("ESC desarma", pause.confirmingAbandon)
        t:truthy("ESC na confirmacao NAO fecha a pausa", pause:isVisible())
        t:eq("foco volta pro Abandonar", pause:focusedKey(), "abandon")
        pause:keypressed("return"); pause:keypressed("return")
        t:falsy("Enter no Nao desarma", pause.confirmingAbandon)
        t:eq("Nao nao abandona", calls.abandon, nil)
        pause:keypressed("return"); pause:keypressed("left")
        t:eq("esquerda vai pro Sim", pause:focusedKey(), "abandon_yes")
        pause:keypressed("return")
        t:eq("Sim abandona UMA vez", calls.abandon, 1)
        t:falsy("e fecha a pausa", pause:isVisible())

        -- ===== 3. atalhos =====
        for _, k in ipairs({ { "d", "deck" }, { "j", "jokers" }, { "m", "journal" } }) do
            pause:show(game, callbacks)
            pause:keypressed(k[1])
            t:eq("tecla " .. k[1] .. " abre " .. k[2], calls[k[2]], 1)
            t:falsy("tecla " .. k[1] .. " fecha a pausa", pause:isVisible())
        end

        -- sem run: sem atalhos, sem abandono, resumo vazio
        local noRun = PauseMenu:new()
        noRun:show(nil, {})
        t:eq("sem run: 3 acoes", #noRun.rows, 3)
        t:eq("sem run: sem atalhos", #noRun.shortcuts, 0)
        t:eq("sem run: sem resumo", noRun:runSummary(), nil)
        noRun:hide()

        -- ===== 4. configuracoes: persistencia =====
        local sm = SettingsMenu:new()
        local closed = 0
        sm:show({ onClose = function() closed = closed + 1 end })
        t:eq("3 abas", sm:tabCount(), 3)
        t:eq("aba Audio tem 3 linhas", #sm.rows, 3)

        _G.gameSettings.masterVolume = 0.5
        sm:keypressed("right")
        t:near("direita sobe o volume geral 10%", _G.gameSettings.masterVolume, 0.6, 0.001)
        t:near("volume geral persistido em disco",
            SaveManager.loadSettings().masterVolume, 0.6, 0.001)
        sm:keypressed("left"); sm:keypressed("left")
        t:near("esquerda desce", SaveManager.loadSettings().masterVolume, 0.4, 0.001)
        -- clique no corpo do slider pula pro ponto
        local r2 = sm.rows[2]
        mouse.x = r2.value.x + math.floor(r2.value.w * 0.75)
        mouse.y = r2.value.y + 2
        sm:mousepressed(mouse.x, mouse.y, 1); sm:mousereleased(mouse.x, mouse.y, 1)
        t:near("clique no slider da musica pula pra 80%",
            SaveManager.loadSettings().musicVolume, 0.8, 0.001)

        sm:keypressed("tab")
        t:eq("Tab vai pra aba Video", sm.tab, 2)
        sm:keypressed("return")
        t:truthy("Enter alterna tela cheia (stub)", fs == true)
        t:eq("tela cheia persistida", SaveManager.loadSettings().fullscreen, true)
        sm:keypressed("down"); sm:keypressed("return")
        t:eq("vsync desligado via setVSync(0)", vs, 0)
        t:eq("vsync persistido", SaveManager.loadSettings().vsync, false)
        sm:keypressed("down")
        local crtBefore = require("src.ui.CRTShader").isEnabled()
        sm:keypressed("return")
        t:eq("CRT alterna", require("src.ui.CRTShader").isEnabled(), not crtBefore)
        sm:keypressed("return")   -- devolve o CRT

        sm:keypressed("q")
        t:eq("Q volta uma aba", sm.tab, 1)
        sm:keypressed("3")
        t:eq("tecla 3 vai direto pra aba Jogo", sm.tab, 3)
        t:eq("aba Jogo tem 4 linhas", #sm.rows, 4)
        sm:keypressed("right")
        t:near("ritmo 1.5x -> CombatBeats.speed 1/1.5", CombatBeats.speed, 1 / 1.5, 0.001)
        t:eq("ritmo persistido", SaveManager.loadSettings().combatSpeed, 1.5)
        sm:keypressed("left")
        t:near("ritmo de volta a 1x", CombatBeats.speed, 1.0, 0.001)
        local rmBefore = _G.gameSettings.reducedMotion and true or false
        sm:keypressed("down"); sm:keypressed("down"); sm:keypressed("return")
        t:eq("movimento reduzido alterna", _G.gameSettings.reducedMotion, not rmBefore)
        t:eq("movimento reduzido persistido", SaveManager.loadSettings().reducedMotion, not rmBefore)
        sm:keypressed("return")
        sm:keypressed("down"); sm:keypressed("right")
        t:truthy("idioma ciclou", I18n.getLocale() ~= "pt_BR")
        t:eq("idioma persistido", SaveManager.loadSettings().locale, I18n.getLocale())
        sm:keypressed("left")
        t:eq("idioma voltou", I18n.getLocale(), "pt_BR")

        -- applyRuntime (boot)
        SettingsMenu.applyRuntime({ combatSpeed = 2 })
        t:near("applyRuntime: 2x -> speed 0.5", CombatBeats.speed, 0.5, 0.001)
        SettingsMenu.applyRuntime({ combatSpeed = 1 })

        -- VOLTAR / ESC
        sm:keypressed("escape")
        t:falsy("ESC fecha as configuracoes", sm:isVisible())
        t:eq("ESC chama onClose (volta pra pausa)", closed, 1)
        sm:show({ onClose = function() closed = closed + 1 end })
        sm:keypressed("up")   -- wrap: sobe da 1a linha pro VOLTAR
        t:truthy("foco no VOLTAR", sm.focus == #sm.rows + 1)
        sm:keypressed("return")
        t:eq("Enter no VOLTAR chama onClose", closed, 2)
        sm:show()
        sm:hide()
        t:eq("aberta do menu (sem onClose) so fecha", closed, 2)

        -- ===== 5. resize com janela falsificada =====
        local sizes = {
            { 800, 600 }, { 1920, 1080 }, { 800, 600 }, { 1024, 768 },
            { 640, 480 }, { 1280, 400 }, { 420, 900 },
        }
        for _, loc in ipairs({ "pt_BR", "de" }) do
            I18n.setLocale(loc)
            fakeW, fakeH = 800, 600   -- NASCE pequeno
            FontManager.clearCache()
            local p = PauseMenu:new(); p:show(game, callbacks)
            local s = SettingsMenu:new(); s:show({ onClose = function() end })
            for _, sz in ipairs(sizes) do
                local w, h = sz[1], sz[2]
                local tag = ("%s %dx%d"):format(loc, w, h)
                resizeTo({ p, s }, w, h)
                report(t, tag .. " pausa sem violacao (" .. p._mode .. ")", p:validate())
                p:armAbandon()
                report(t, tag .. " pausa confirmando sem violacao", p:validate())
                p:disarmAbandon()
                for i = 1, s:tabCount() do
                    s:setTab(i)
                    report(t, tag .. " config aba " .. i .. " sem violacao", s:validate())
                end
                s:setTab(1)
            end
            p:hide(); s:hide(true)
        end
        I18n.setLocale("pt_BR")

        -- o validate() ENXERGA sobreposição (teste do teste: um validador
        -- que nunca acusa nada passaria em qualquer layout quebrado)
        do
            fakeW, fakeH = 1024, 768
            local pm = PauseMenu:new(); pm:show(game, callbacks)
            pm.rows[2].y = pm.rows[1].y + 4
            t:truthy("validate da pausa acusa row sobreposta", #pm:validate() > 0)
            pm:hide()
            local sv = SettingsMenu:new(); sv:show()
            sv.rows[2].y = sv.rows[1].y + 4
            t:truthy("validate das configuracoes acusa linha sobreposta", #sv:validate() > 0)
            sv:hide(true)
        end

        -- foco sobrevive ao resize
        fakeW, fakeH = 1024, 768
        local pf = PauseMenu:new(); pf:show(game, callbacks)
        pf:keypressed("down"); pf:keypressed("down")
        resizeTo({ pf }, 1600, 900)
        t:eq("foco preservado no resize", pf:focusedKey(), "save_quit")
        pf:hide()

        -- ===== 6. chaves novas nos 5 locales =====
        local keys = {
            "pause.info_class", "pause.info_journey", "pause.info_journey_value",
            "pause.info_seed", "pause.info_hp", "pause.info_gold", "pause.info_deck",
            "pause.shortcut_deck", "pause.shortcut_jokers", "pause.shortcut_journal",
            "pause.hint", "pause.hint_confirm",
            "settings.tab_audio", "settings.tab_video", "settings.tab_game",
            "settings.vsync", "settings.combat_speed", "settings.back", "settings.hint",
        }
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            local chunk = love.filesystem.load("src/i18n/locales/" .. loc .. ".lua")
            local data = chunk and chunk() or {}
            local missing = {}
            for _, k in ipairs(keys) do
                local cur = data
                for seg in k:gmatch("[^%.]+") do cur = type(cur) == "table" and cur[seg] or nil end
                if type(cur) ~= "string" then missing[#missing + 1] = k end
            end
            t:eq(loc .. ": chaves novas presentes", #missing, 0)
            for _, k in ipairs(missing) do print("      -> falta " .. k) end
        end
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)

    -- ===== restaura tudo =====
    restoreMouse()
    restoreWindow()
    win.setFullscreen, win.getFullscreen = realFS, realGetFS
    win.setVSync, win.getVSync = realSetV, realGetV
    love.resize = realResize
    I18n.setLocale(savedLocale)
    CombatBeats.speed = savedSpeed
    _G.gameSettings = savedGS
    _G.audioSystem = savedAudio
    if savedFile then
        love.filesystem.write(settingsPath, savedFile)
    else
        love.filesystem.remove(settingsPath)
    end
    FontManager.clearCache()
    return t:done()
end

return M
