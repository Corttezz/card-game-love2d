local H = require("tools.test_nav_flow")
local M = {}

function M.script()
    local frames, sleep, pad = H.frames, H.sleep, H.pad
    local waitFor, navigateTo, check, snap = H.waitFor, H.navigateTo, H.check, H.snap
    local isButtonText, isKey, state = H.isButtonText, H.isKey, H.state
    local NavCursor = require("src.ui.NavCursor")
    local I18n = require("src.i18n.I18n")
    local IF = require("src.ui.InputFocus")
    print("---- fluxo 2 só por pad: coleção, conquistas, coringas, deck, roteiro, pacote, vitória ----")
    frames(10)
    waitFor(function()
        if state() == "boot" then love.keypressed("return") end
        return state() == "menu"
    end, 600, "menu")
    sleep(2.5)

    require("src.systems.UnlockSystem").setRevealAll(true)
    check("menu: D-pad chega na Coleção",
        navigateTo(isButtonText(I18n.t("menu.collection")), "Coleção", false))
    pad("a")
    waitFor(function() return state() == "collection" end, 300, "coleção")
    check("coleção aberta pelo pad", state() == "collection")
    sleep(0.8)
    check("coleção: D-pad foca uma carta", navigateTo(isKey("col:"), "carta da coleção", false))
    pad("dpdown"); pad("dpdown"); pad("dpdown"); pad("dpdown")
    sleep(0.3)
    snap("collection")
    check("coleção: D-pad volta à 1ª carta",
        navigateTo(function(t) return t.key == "col:1" end, "1ª carta", false))
    pad("a"); sleep(0.4)
    pad("dpright"); sleep(0.2)
    pad("b"); sleep(0.3)
    check("coleção: B fecha o zoom e fica na coleção", state() == "collection")
    pad("b"); sleep(0.5)
    check("coleção: B volta ao menu", state() == "menu")
    require("src.systems.UnlockSystem").setRevealAll(false)

    sleep(0.5)
    check("menu: D-pad chega em Conquistas",
        navigateTo(isButtonText(I18n.t("menu.achievements")), "Conquistas", false))
    pad("a")
    waitFor(function() return state() == "achievements" end, 300, "conquistas")
    check("conquistas abertas pelo pad", state() == "achievements")
    pad("dpright"); pad("dpdown")
    snap("achievements")
    pad("b"); sleep(0.5)
    check("conquistas: B volta ao menu", state() == "menu")

    sleep(0.5)
    navigateTo(isButtonText(I18n.t("menu.play")), "Jogar", false)
    pad("a"); sleep(0.5)
    if require("src.ui.ConfirmDialog").isVisible() then pad("dpleft"); pad("a"); sleep(0.3) end
    waitFor(function() return state() == "classSelection" end, 300, "classe")
    sleep(1)
    pad("rightshoulder"); pad("rightshoulder"); pad("leftshoulder")
    snap("class_seal")
    navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text == "" and b.width > 150
    end, "painel de classe", false)
    pad("a")
    waitFor(function() return state() == "playing" end, 600, "batalha")
    local game = require("src.scenes.GameplayScene").getGame()
    local run = game.runManager.currentRun
    check("classe: RB/RB/LB pelo pad deixou o Selo 1 (" .. tostring(run.seal) .. ")", run.seal == 1)
    sleep(4)
    waitFor(function() return game.turn == "player" and #game.hand > 0
        and not game.combatAnimationSystem:isBlocking() end, 900, "turno do jogador")

    local jokerId
    for id, cd in pairs(require("src.systems.CardDatabase"):new():getAllCards()) do
        if cd.type == "joker" then jokerId = cd.id or id break end
    end
    game:addJokerToRun(jokerId)
    sleep(0.3)
    check("batalha: D-pad chega no quadro de coringas",
        navigateTo(function(t) return t.key == "jokerFrame" end, "quadro de coringas", false))
    pad("a"); sleep(0.4)
    check("A abre o gerenciador de coringas", IF.activeName() == "jokerManager")
    check("gerenciador: D-pad foca o coringa", navigateTo(isKey("joker:"), "coringa", false))
    local before = run.jokerActive and run.jokerActive[1]
    snap("joker_manager")
    pad("a"); sleep(0.3)
    local after = run.jokerActive and run.jokerActive[1]
    check("gerenciador: A alterna ativo/bancada (" .. tostring(before) .. " → " .. tostring(after) .. ")",
        after ~= before)
    pad("b"); sleep(0.3)
    check("B fecha o gerenciador", IF.activeName() ~= "jokerManager")

    check("batalha: D-pad sobe até o deck na TopBar",
        navigateTo(function(t) return t.key == "topbar:topbar_deck" end, "deck na TopBar", false))
    pad("a"); sleep(0.4)
    check("A no deck abre o Deck Viewer", IF.activeName() == "deckViewer")
    check("deck: D-pad foca uma carta", navigateTo(isKey("deck:"), "carta do deck", false))
    snap("deck_viewer")
    pad("b"); sleep(0.3)
    check("B fecha o deck", IF.activeName() ~= "deckViewer")

    check("D-pad chega no bloco do ato",
        navigateTo(function(t) return t.key == "topbar:topbar_progress" end, "ato na TopBar", false))
    pad("a"); sleep(0.4)
    check("A no ato abre o Roteiro", IF.activeName() == "runJournal")
    snap("journal")
    pad("b"); sleep(0.3)
    check("B fecha o Roteiro", IF.activeName() ~= "runJournal")

    local MapManager = require("src.systems.MapManager")
    local realGen = MapManager.generate
    local forced = { "shop", "battle" }
    local idx = 0
    MapManager.generate = function(...)
        local nodes = realGen(...)
        idx = idx + 1
        if forced[idx] and nodes then for _, n in ipairs(nodes) do n.type = forced[idx] end end
        return nodes
    end
    local function winTurn()
        game.enemy.health, game.enemy.armor = 1, 0
        pad("rightshoulder")
        for _ = 1, 8 do
            local c = NavCursor.focused()
            if c and type(c.key) == "table" and c.key.type == "attack" then break end
            pad("rightshoulder")
        end
        pad("a"); sleep(0.2); pad("y")
    end
    winTurn()
    waitFor(function() return state() ~= "playing" end, 3000, "fim da luta")
    for _ = 1, 30 do
        if state() ~= "roundEval" then break end
        pad("a"); sleep(0.3)
    end
    waitFor(function() return state() == "cardReward" end, 600, "espólio")
    sleep(1.5)
    if navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text == I18n.t("reward.skip_no_card")
    end, "seguir sem carta", false) then pad("a") end
    waitFor(function() return state() == "mapSelection" end, 600, "encruzilhada")
    sleep(2)
    navigateTo(isKey("fork:"), "marco", false)
    pad("a")
    waitFor(function() return state() == "cardReward" end, 900, "loja")
    check("loja aberta", state() == "cardReward")
    sleep(2)

    game.economySystem.currentGold = 999
    local packKey
    for _, t in ipairs(NavCursor._targets()) do
        if type(t.key) == "string" and t.key:sub(1, 6) == "offer:" then
            if not packKey or tonumber(t.key:sub(7)) > tonumber(packKey:sub(7)) then packKey = t.key end
        end
    end
    check("loja: D-pad chega no pacote",
        packKey and navigateTo(function(t) return t.key == packKey end, "pacote", false))
    pad("a"); sleep(0.4)
    if navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text and b.text:find("%$") and b.width and b.width < 400 and b.text:upper() == b.text
    end, "comprar pacote", false) then pad("a") end
    waitFor(function() return IF.activeName() == "packOpen" end, 600, "pacote aberto")
    check("pacote aberto pelo pad", IF.activeName() == "packOpen")
    sleep(3)
    local deckBefore = #run.currentDeck
    snap("pack_open")
    for _ = 1, 4 do
        if IF.activeName() ~= "packOpen" then break end
        if navigateTo(function(t) return type(t.key) == "table" and t.key.type ~= nil end,
            "carta do pacote", false) then
            pad("a"); sleep(0.6)
            pad("a"); sleep(1.5)
        else
            sleep(1)
        end
    end
    waitFor(function() return IF.activeName() ~= "packOpen" end, 900, "pacote fechado")
    check("pacote: escolha pelo pad fecha e a carta entra (" .. deckBefore .. " → " .. #run.currentDeck .. ")",
        IF.activeName() ~= "packOpen" and #run.currentDeck > deckBefore)

    sleep(2.5)
    local contLabel = I18n.t("reward.continue")
    local okCont = navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text and b.text:sub(1, #contLabel) == contLabel
    end, "continuar", false)
    if not okCont then
        for _, t in ipairs(NavCursor._targets()) do
            print("      alvo", tostring(t.key), type(t.key) == "table" and t.key.text or "", t.layer)
        end
    end
    check("loja: D-pad chega no Continuar depois do pacote", okCont)
    if okCont then pad("a") end
    waitFor(function() return state() == "mapSelection" end, 600, "encruzilhada 2")
    sleep(2)
    navigateTo(isKey("fork:"), "marco 2", false)
    pad("a")
    waitFor(function() return state() == "playing" end, 900, "batalha final")
    sleep(4)
    waitFor(function() return game.turn == "player" and #game.hand > 0
        and not game.combatAnimationSystem:isBlocking() end, 900, "turno")
    run.actNumber = require("src.core.Config").TotalActs
    run.floorInAct = 8
    run.currentNode = run.currentNode or {}
    run.currentNode.type = "boss"
    winTurn()
    waitFor(function() return state() == "victory" end, 4000, "vitória")
    check("vitória alcançada", state() == "victory")
    sleep(1.5)
    snap("victory")
    for _ = 1, 8 do
        if state() ~= "victory" then break end
        pad("a"); sleep(0.6)
    end
    waitFor(function() return state() ~= "victory" end, 600, "endless")
    check("vitória: A entra no endless (" .. tostring(state()) .. ")",
        state() ~= "victory" and run.endlessMode == true)

    for _ = 1, 30 do
        if state() ~= "roundEval" then break end
        pad("a"); sleep(0.3)
    end
    waitFor(function() return state() == "cardReward" end, 600, "espólio do endless")
    sleep(1.5)
    if navigateTo(function(t)
        local b = type(t.key) == "table" and t.key
        return b and b.text == I18n.t("reward.skip_no_card")
    end, "seguir sem carta", false) then pad("a") end
    waitFor(function() return IF.activeName() == "endlessCurse" end, 900, "maldição")
    check("endless: a escolha de maldição abre", IF.activeName() == "endlessCurse")
    sleep(0.6)
    local RunModifiers = require("src.systems.RunModifiers")
    local pend = RunModifiers.pending(run)
    local want = pend and pend[2]
    check("maldição: D-pad chega na 2ª opção",
        navigateTo(function(t) return t.key == "curse:2" end, "2ª maldição", false))
    snap("endless_curse")
    pad("a"); sleep(0.4)
    check("maldição: A escolhe pelo pad (" .. tostring(want) .. ")",
        RunModifiers.pending(run) == nil and RunModifiers.curseStacks(run, want) == 1
        and IF.activeName() ~= "endlessCurse")
    MapManager.generate = realGen
    H.finish()
end

return M
