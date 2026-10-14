local TK = require("tools.testkit")

local M = {}

local function victoryGoldPagoPeloGame(game, act)
    game.runManager.currentRun.actNumber = act
    local sources = game:_buildRoundEvalSources()
    for _, s in ipairs(sources or {}) do
        return s.dollars or 0
    end
    return 0
end

function M.run()
    local t = TK.new("economia: pagamento por batalha escala por ato")

    local Config = require("src.core.Config")
    t:truthy("Config.Economy existe", type(Config.Economy) == "table")
    if type(Config.Economy) ~= "table" then return t:done() end

    t:eq("ato 1 paga a base (sem regressao no ato mais tunado)",
        Config.Economy.victoryGold(1), Config.Economy.VICTORY_GOLD_BASE)

    local totalAtos = Config.TotalActs or 6
    local anterior = Config.Economy.victoryGold(1)
    local cresceuSempre = true
    for a = 2, totalAtos do
        local v = Config.Economy.victoryGold(a)
        if v <= anterior then cresceuSempre = false end
        anterior = v
    end
    t:check("o pagamento cresce a cada ato ate o ato " .. totalAtos,
        cresceuSempre)

    t:check("o ultimo ato paga mais que o primeiro (A1 $"
        .. Config.Economy.victoryGold(1) .. " -> A" .. totalAtos .. " $"
        .. Config.Economy.victoryGold(totalAtos) .. ")",
        Config.Economy.victoryGold(totalAtos) > Config.Economy.victoryGold(1))

    t:eq("ato nil cai na base", Config.Economy.victoryGold(nil),
        Config.Economy.VICTORY_GOLD_BASE)
    t:eq("ato 0 cai na base", Config.Economy.victoryGold(0),
        Config.Economy.VICTORY_GOLD_BASE)

    local game = TK.newRunGame("warrior")
    local a1 = victoryGoldPagoPeloGame(game, 1)
    local aN = victoryGoldPagoPeloGame(game, totalAtos)

    t:eq("o Game paga no ato 1 o mesmo que a formula",
        a1, Config.Economy.victoryGold(1))
    t:check("o Game paga MAIS no ato " .. totalAtos .. " que no ato 1"
        .. " (pago: $" .. a1 .. " -> $" .. aN .. ")", aN > a1)
    t:eq("o Game paga no ato " .. totalAtos .. " o mesmo que a formula",
        aN, Config.Economy.victoryGold(totalAtos))

    local I18n = require("src.i18n.I18n")
    local function bonusPago(nodeType, act)
        game.runManager.currentRun.actNumber = act
        game.runManager.currentRun.currentNode = { type = nodeType }
        local want = I18n.t(nodeType == "boss" and "round_eval.src_boss" or "round_eval.src_elite")
        for _, s in ipairs(game:_buildRoundEvalSources() or {}) do
            if s.label == want then return s.dollars end
        end
        return 0
    end
    t:eq("luta comum: sem bonus", bonusPago("battle", 2), 0)
    t:eq("elite no ato 2 paga +1x a vitoria", bonusPago("elite", 2), Config.Economy.victoryGold(2))
    t:eq("mini-chefe sem bonus (obrigatorio = nao e risco)", bonusPago("mini_boss", 3), 0)
    t:eq("chefe paga +1x a vitoria", bonusPago("boss", 4), Config.Economy.victoryGold(4))

    return t:done()
end

return M
