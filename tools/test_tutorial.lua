-- tools/test_tutorial.lua
-- TRAVA do onboarding (Out/2026): dicas ancoradas (src/systems/Tutorial +
-- src/ui/TipPlate), Guia de combos/glossário (components/GuideScreen) e o
-- tooltip da mana.
--   1. toda dica tem título e corpo nos 5 idiomas;
--   2. a dica dispara UMA vez, na ordem, só com o combate parado, e espera a
--      condição se manter (não pisca);
--   3. "vista" persiste no perfil, "Rever as dicas" zera, desligar cala;
--   4. clique, Enter/A e Esc/B fecham (a placa é dona do input);
--   5. a placa nunca sai da tela, nunca cobre o objeto que explica nem a
--      TopBar — em 4 tamanhos de janela, pt_BR e de (o idioma mais longo);
--   6. o Guia lista TODO combo do ComboSystem (nome, requisito, efeito) e
--      todo verbete do glossário, nos 5 idiomas.
--
--   love . test_one test_tutorial

local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

function M.run()
    local t = TK.new("tutorial: dicas ancoradas, guia, persistência")
    TK.bootstrap()
    local I18n = require("src.i18n.I18n")
    local Tutorial = require("src.systems.Tutorial")
    local TipPlate = require("src.ui.TipPlate")
    local ProfileStats = require("engine.ProfileStats")
    local UiScale = require("src.ui.UiScale")

    -- ===== 1. textos =====
    local missing = {}
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales.tutorial." .. loc)
        for _, def in ipairs(Tutorial.TIPS) do
            local tip = data.tips and data.tips[def.id]
            if not (tip and tip.title and tip.body and tip.body ~= "") then
                missing[#missing + 1] = loc .. ":" .. def.id
            end
        end
        if not (data.status and data.status.mana and data.status.mana.desc) then
            missing[#missing + 1] = loc .. ":status.mana"
        end
    end
    t:eq("toda dica (e o verbete da mana) existe nos 5 idiomas", table.concat(missing, ","), "")

    -- ===== 2. disparo: ordem, uma vez, combate parado =====
    local prevProfile = ProfileStats._swapForTests({})
    Tutorial._reset()
    Tutorial._forceForTests(true)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    g.turn = "player"
    g._enemyActing = false
    local function anchorsNow()
        -- âncoras reportadas como o draw faria (identidade = pixels reais)
        love.graphics.origin()
        Tutorial.anchor("hand", 300, 560, 400, 180)
        Tutorial.anchor("mana", 940, 680, 60, 60)
        Tutorial.anchor("intent", 470, 160, 90, 48)
        Tutorial.anchor("play", 820, 600, 150, 46)
        Tutorial.anchor("end_turn", 820, 654, 150, 33)
        Tutorial.anchor("player_panel", 14, 660, 220, 90)
        Tutorial.anchor("jokers", 14, 88, 260, 140)
    end
    local function step(state, secs)
        local n = math.floor((secs or 0.5) / (1 / 30))
        for _ = 1, n do anchorsNow(); Tutorial.update(1 / 30, state, g) end
    end

    step("playing", 0.1)
    t:eq("dica não aparece antes da condição se manter (sem piscar)", Tutorial.activeId(), nil)
    step("playing", 0.5)
    t:eq("1ª dica da 1ª batalha: a mão", Tutorial.activeId(), "battle_hand")
    t:truthy("a placa é dona do input (InputFocus)", Tutorial.overlay:isVisible())
    Tutorial.overlay:mousepressed(10, 10, 1)
    t:eq("clique fecha a dica", Tutorial.activeId(), nil)
    t:truthy("dica fechada fica VISTA no perfil", ProfileStats.isTipSeen("battle_hand"))
    step("playing", 1.0)
    t:eq("depois vem a mana", Tutorial.activeId(), "battle_mana")
    Tutorial.overlay:keypressed("return")   -- Enter / A do gamepad
    t:eq("Enter/A fecha", Tutorial.activeId(), nil)
    step("playing", 1.0)
    t:eq("depois o intent do inimigo", Tutorial.activeId(), "battle_intent")
    Tutorial.overlay:keypressed("escape")   -- Esc / B
    t:eq("Esc/B fecha", Tutorial.activeId(), nil)

    -- Vez do inimigo: nada aparece (o combate não é interrompido).
    g.turn = "enemy"
    g.selectedCards = { g.hand[1] }
    step("playing", 1.0)
    t:eq("na vez do inimigo nenhuma dica aparece", Tutorial.activeId(), nil)
    g.turn = "player"
    step("playing", 1.0)
    t:eq("com carta selecionada: o JOGAR", Tutorial.activeId(), "battle_play")
    Tutorial.dismiss()
    g.selectedCards = {}

    -- Sem âncora (objeto não desenhado), a dica espera: nunca aponta pro nada.
    Tutorial._reset()
    g.player.armor = 5
    for _ = 1, 40 do Tutorial.update(1 / 30, "playing", g) end
    t:eq("sem âncora visível, a dica não aparece", Tutorial.activeId(), nil)
    step("playing", 1.0)
    t:truthy("com Bloqueio na mesa, a dica do Bloqueio aparece (ancorada no painel)",
        Tutorial.activeId() == "block" or Tutorial.activeId() == "battle_end_turn")

    -- Visto não volta.
    Tutorial.dismiss()
    local seenNow = Tutorial.activeId()
    for _, id in ipairs({ "battle_hand", "battle_mana", "battle_intent", "battle_play" }) do
        t:truthy("'" .. id .. "' segue vista", ProfileStats.isTipSeen(id))
    end
    t:eq("(nenhuma dica presa aberta)", seenNow, nil)

    -- ===== 3. desligar, rever =====
    Tutorial._forceForTests(false)
    Tutorial._allowHeadless = true
    _G.gameSettings = _G.gameSettings or {}
    local prevTips = _G.gameSettings.tipsEnabled
    _G.gameSettings.tipsEnabled = false
    ProfileStats.resetTips()
    Tutorial._reset()
    step("playing", 1.0)
    t:eq("dicas desligadas: nada aparece", Tutorial.activeId(), nil)
    _G.gameSettings.tipsEnabled = true
    step("playing", 1.0)
    t:eq("religadas + 'Rever': a primeira volta", Tutorial.activeId(), "battle_hand")
    Tutorial.dismiss()
    t:eq("Rever as dicas devolve quantas esquecia", Tutorial.resetAll(), 1)
    t:eq("perfil zerado", ProfileStats.tipsSeenCount(), 0)
    _G.gameSettings.tipsEnabled = prevTips
    Tutorial._allowHeadless = nil
    Tutorial._reset()
    ProfileStats._swapForTests(prevProfile)

    -- Persistência em DISCO (caminho de teste: o perfil real não é tocado).
    do
        local path = "profile_tutorial_test.tool.lua"
        love.filesystem.remove(path)
        ProfileStats._setPathForTests(path)
        ProfileStats.markTipSeen("combo")
        ProfileStats._setPathForTests(path)     -- força reler do disco
        t:truthy("dica vista sobrevive a reabrir o jogo (disco)", ProfileStats.isTipSeen("combo"))
        ProfileStats.resetTips()
        ProfileStats._setPathForTests(path)
        t:falsy("reset também vai pro disco", ProfileStats.isTipSeen("combo"))
        ProfileStats._setPathForTests(nil)
        love.filesystem.remove(path)
    end

    -- ===== 5. zonas: a placa em 4 tamanhos × pt_BR/de =====
    local origW, origH, origD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local origReal = UiScale.realDimensions
    local bad = {}
    for _, sz in ipairs({ { 1024, 768 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }) do
        local W, H = sz[1], sz[2]
        love.graphics.getWidth = function() return W end
        love.graphics.getHeight = function() return H end
        love.graphics.getDimensions = function() return W, H end
        UiScale.realDimensions = function() return W, H end
        local k = UiScale.k(W, H)
        -- âncoras nas posições REAIS dos objetos (proporções do HUD)
        local A = {
            hand = { x = W * 0.28, y = H - 200 * k, w = W * 0.40, h = 190 * k },
            mana = { x = W - 90 * k, y = H - 90 * k, w = 60 * k, h = 60 * k },
            intent = { x = W / 2 - 45 * k, y = H * 0.22, w = 90 * k, h = 48 * k },
            play = { x = W * 0.80, y = H * 0.78, w = 150 * k, h = 46 * k },
            end_turn = { x = W * 0.80, y = H * 0.78 + 54 * k, w = 150 * k, h = 33 * k },
            player_panel = { x = 14 * k, y = H - 110 * k, w = 220 * k, h = 90 * k },
            jokers = { x = 14 * k, y = 88 * k, w = 260 * k, h = 140 * k },
            orbs = { x = 14 * k, y = H - 240 * k, w = 174 * k, h = 78 * k },
        }
        for _, loc in ipairs({ "pt_BR", "de" }) do
            I18n.setLocale(loc, true)
            for _, def in ipairs(Tutorial.TIPS) do
                local key = def.id:match("^battle_(.+)$") or def.id
                local anchor = A[key] or A[({ block = "player_panel", combo = "hand" })[key] or ""]
                    or { x = W / 2 - 200 * k, y = 70 * k, w = 400 * k, h = 36 * k }
                local L = Tutorial.layoutFor(def.id, anchor)
                local ok, errs = TipPlate.validate(L)
                if not ok then
                    bad[#bad + 1] = ("%dx%d %s %s: %s"):format(W, H, loc, def.id, table.concat(errs, "; "))
                end
            end
        end
    end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = origW, origH, origD
    UiScale.realDimensions = origReal
    I18n.setLocale("pt_BR", true)
    for i = 1, math.min(4, #bad) do print("     " .. bad[i]) end
    t:eq("placa nunca sai da tela, cobre o objeto ou a TopBar (4 tamanhos × pt/de)", #bad, 0)

    -- ===== 6. Guia =====
    local GuideScreen = require("components.GuideScreen")
    local ComboSystem = require("src.systems.ComboSystem")
    local gbad = {}
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc, true)
        local combos = GuideScreen.comboEntries("warrior")
        if #combos ~= #ComboSystem.RULES then gbad[#gbad + 1] = loc .. ": nº de combos" end
        for _, e in ipairs(combos) do
            if e.title == e.id or e.effect == "" then
                gbad[#gbad + 1] = loc .. ":" .. e.id
            end
        end
        local gl = GuideScreen.glossaryEntries()
        if #gl ~= #require("src.data.keywords") then gbad[#gbad + 1] = loc .. ": glossário" end
        for _, e in ipairs(gl) do
            if e.title == e.id or e.effect == "" then gbad[#gbad + 1] = loc .. ":kw:" .. e.id end
        end
    end
    I18n.setLocale("pt_BR", true)
    t:eq("Guia: todo combo (nome + regra/efeito) e todo verbete nos 5 idiomas",
        table.concat(gbad, ","), "")
    local withEx = 0
    for _, e in ipairs(GuideScreen.comboEntries("warrior")) do
        if e.examples ~= "" then withEx = withEx + 1 end
    end
    t:check("Guia: combos trazem cartas de exemplo", withEx >= #ComboSystem.RULES - 2)

    -- Guia: abre, troca aba, fecha pelo teclado/pad
    local gs = GuideScreen:new()
    gs:show(g)
    gs:keypressed("right")
    t:eq("→ / RB troca para o glossário", gs.tab, 2)
    gs:keypressed("escape")
    t:falsy("Esc / B fecha o Guia", gs:isVisible())

    Tutorial._forceForTests(false)
    Tutorial._reset()
    return t:done()
end

return M
