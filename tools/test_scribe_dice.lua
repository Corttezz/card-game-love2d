local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("Dados do Escriba")
    TK.bootstrap()
    local ScribeDice = require("src.systems.ScribeDice")

    t:near("Baixo = 15/36", ScribeDice.chance("low"), 15 / 36, 1e-9)
    t:near("Sete = 6/36", ScribeDice.chance("seven"), 6 / 36, 1e-9)
    t:near("Alto = 15/36", ScribeDice.chance("high"), 15 / 36, 1e-9)
    for _, id in ipairs(ScribeDice.BET_IDS) do
        local ev = ScribeDice.expectedValue(id)
        t:truthy(("EV de %s justo (%.3f em 0,9..1,1)"):format(id, ev), ev >= 0.9 and ev <= 1.1)
    end

    local a1, a6 = ScribeDice.stakes(1), ScribeDice.stakes(6)
    t:eq("3 fichas", #a1, 3)
    local pares, crescem = true, true
    for i = 1, 3 do
        if a1[i] % 2 ~= 0 or a6[i] % 2 ~= 0 then pares = false end
        if a6[i] <= a1[i] then crescem = false end
        if math.floor(a1[i] * ScribeDice.payoutMult("low")) ~= a1[i] * ScribeDice.payoutMult("low") then
            pares = false
        end
    end
    t:truthy("fichas pares (pagamento x2,5 inteiro)", pares)
    t:truthy("fichas crescem do ato 1 ao 6", crescem)

    local g = TK.newRunGame("warrior")
    local rm, eco = g.runManager, g.economySystem
    local run = rm.currentRun
    TK.seedRng(4242)
    eco.currentGold = 100
    local stake = a1[2]
    t:falsy("mesa livre ao chegar", ScribeDice.isUsed(run))
    local st = ScribeDice.roll(run, eco, "high", stake)
    t:truthy("lançou", st ~= nil)
    if not st then return t:done() end
    t:truthy("dados 1..6", st.dice[1] >= 1 and st.dice[1] <= 6 and st.dice[2] >= 1 and st.dice[2] <= 6)
    t:eq("soma coerente", st.sum, st.dice[1] + st.dice[2])
    t:eq("vitória segue a regra", st.won, st.sum >= 8)
    local esperado = 100 - stake + (st.won and math.floor(stake * 2.5) or 0)
    t:eq("ouro depois da jogada", eco.currentGold, esperado)
    local st2, why = ScribeDice.roll(run, eco, "low", stake)
    t:truthy("segunda jogada na MESMA loja recusada", st2 == nil and why == "used")

    TK.seedRng(4242)
    local run2 = { actNumber = 1, floorInAct = 1, mapHistory = {} }
    local eco2 = { currentGold = 100, canAfford = function(s, n) return s.currentGold >= n end,
        spendGold = function(s, n) s.currentGold = s.currentGold - n; return true end,
        earnGold = function(s, n) s.currentGold = s.currentGold + n; return n end }
    local again = ScribeDice.roll(run2, eco2, "high", stake)
    t:eq("mesma seed, mesma soma", again and again.sum, st.sum)

    local run3 = { actNumber = 1, floorInAct = 2, mapHistory = {} }
    eco2.currentGold = stake - 1
    local poor, whyPoor = ScribeDice.roll(run3, eco2, "high", stake)
    t:truthy("sem ouro: recusa", poor == nil and whyPoor == "poor")
    t:eq("sem ouro: nada cobrado", eco2.currentGold, stake - 1)
    t:truthy("ficha inválida recusada", select(2, ScribeDice.canRoll(run3, eco2, "high", 7)) == "bad_stake")

    g:checkpointRun()
    local soma, ouro = st.sum, eco.currentGold
    local RunManager = require("src.systems.RunManager")
    local rm2 = RunManager:new()
    t:truthy("carregou o save", rm2:loadRun())
    local back = ScribeDice.state(rm2.currentRun)
    t:truthy("mesa volta USADA depois de carregar", back ~= nil and back.used == true)
    t:eq("mesma soma depois de carregar", back and back.sum, soma)
    t:eq("ouro salvo já com o resultado", rm2.currentRun.playerState and rm2.currentRun.playerState.gold or ouro, ouro)
    local again2, whyAgain = ScribeDice.roll(rm2.currentRun, eco, "seven", stake)
    t:truthy("depois de carregar não há segunda jogada", again2 == nil and whyAgain == "used")

    run.mapHistory = run.mapHistory or {}
    table.insert(run.mapHistory, { type = "shop" })
    t:falsy("nó seguinte: mesa livre de novo", ScribeDice.isUsed(run))

    local Screen = require("components.ScribeDiceScreen")
    local sizes = { { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 } }
    for _, s in ipairs(sizes) do
        local probs = Screen.validate(Screen.layout(s[1], s[2]), s[1], s[2])
        t:truthy(("layout %dx%d sem problemas%s"):format(s[1], s[2],
            #probs > 0 and (": " .. table.concat(probs, "; ")) or ""), #probs == 0)
    end
    local scr = Screen:new()
    eco.currentGold = 50
    t:noerror("abre, navega, lança e fecha headless", function()
        scr:show(g, function() end)
        for _, k in ipairs({ "right", "left", "return", "return", "return" }) do scr:keypressed(k) end
        for _ = 1, 60 do scr:update(1 / 30) end
        scr:keypressed("escape")
    end)
    t:falsy("fechou", scr:isVisible())
    t:truthy("a tela gravou a jogada no nó", ScribeDice.isUsed(run))

    local Tutorial = require("src.systems.Tutorial")
    Tutorial._reset()
    local scr2 = Screen:new()
    scr2:show(g, function() end)
    scr2:keypressed("h")
    t:eq("H abre a explicacao dos dados", Tutorial.activeId(), "dice_help")
    t:falsy("explicar de novo com conversa aberta e recusado",
        Tutorial.explain("dice_help", g))
    Tutorial._reset()
    scr2:keypressed("e")
    t:eq("Y do controle (tecla e) tambem abre", Tutorial.activeId(), "dice_help")
    Tutorial._reset()
    scr2:hide()
    local I18n = require("src.i18n.I18n")
    local cur = I18n.getLocale()
    local lowPct = math.floor(ScribeDice.chance("low") * 100 + 0.5)
    local sevenPct = math.floor(ScribeDice.chance("seven") * 100 + 0.5)
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        I18n.setLocale(loc, true)
        local bets = I18n.t("tutorial.script.dice_help.bets")
        local mult = string.format("%g", ScribeDice.payoutMult("low"))
        local multC = mult:gsub("%.", ",")
        t:truthy(loc .. ": chance do Baixo/Alto escrita certa (" .. lowPct .. "%)",
            bets:find(tostring(lowPct), 1, true) ~= nil)
        t:truthy(loc .. ": chance do Sete escrita certa", bets:find(tostring(sevenPct), 1, true) ~= nil)
        t:truthy(loc .. ": pagamento x" .. mult .. " escrito certo",
            bets:find(mult .. "×", 1, true) ~= nil or bets:find(multC .. "×", 1, true) ~= nil)
        t:truthy(loc .. ": pagamento do Sete escrito certo",
            bets:find(string.format("%g", ScribeDice.payoutMult("seven")) .. "×", 1, true) ~= nil)
        for _, k in ipairs({ "what", "stakes", "once" }) do
            local txt = I18n.t("tutorial.script.dice_help." .. k)
            t:truthy(loc .. ": fala " .. k .. " traduzida", txt and not txt:find("dice_help", 1, true))
        end
    end
    I18n.setLocale(cur, true)

    rm:deleteSave()
    return t:done()
end

return M
