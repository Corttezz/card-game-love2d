-- tools/test_economy_acts.lua
-- Trava do PAGAMENTO POR BATALHA escalando por ato (Set/2026).
--
-- O defeito que isto tranca
-- --------------------------
-- A campanha foi de 3 para 6 atos e o pagamento por batalha ficou parado: $5
-- de vitoria fixos, $3 de HP cheio fixos, juros no teto de $5. Medido com
-- `love . autoplay 16 warrior 901000` (261 batalhas, com a loja exercitada de
-- verdade): renda de $9,88 por batalha CONSTANTE do ato 1 ao 6, enquanto todo
-- preco de loja escala geometricamente. Resultado medido: 74 compras no ato 1
-- e 1 compra no ato 6 — a loja fecha sozinha na metade final da campanha.
--
-- A correcao poe a vitoria em `BASE + POR_ATO*(ato-1)`. Este teste garante
-- tres coisas que e facil quebrar sem perceber:
--
--   1. o ato 1 continua pagando exatamente o que pagava (nenhuma regressao na
--      parte mais tunada do jogo);
--   2. o pagamento CRESCE de fato ato a ato — com o valor fixo de volta, os
--      atos 1 e 6 pagam igual e o teste fica vermelho;
--   3. quem paga e o Game de verdade (`_buildRoundEvalSources`), nao so a
--      formula do Config. Um teste que so chamasse `Config.Economy.victoryGold`
--      passaria com o Game ainda pagando $5 cravado — mediria a coisa errada.
--
-- Verificado revertendo a correcao (dollars = 5 fixo em Game.lua) antes de
-- commitar: os itens 2 e 3 ficam vermelhos.

local TK = require("tools.testkit")

local M = {}

-- Ouro de vitoria que o GAME realmente paga, com a run no ato `act`.
local function victoryGoldPagoPeloGame(game, act)
    game.runManager.currentRun.actNumber = act
    local sources = game:_buildRoundEvalSources()
    for _, s in ipairs(sources or {}) do
        -- a vitoria e sempre a primeira fonte da folha
        return s.dollars or 0
    end
    return 0
end

function M.run()
    local t = TK.new("economia: pagamento por batalha escala por ato")

    local Config = require("src.core.Config")
    t:truthy("Config.Economy existe", type(Config.Economy) == "table")
    if type(Config.Economy) ~= "table" then return t:done() end

    -- ===== 1) a formula =====
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

    -- Ato invalido nao pode pagar menos que a base (act 0/nil vindo de um
    -- caminho classico sem run).
    t:eq("ato nil cai na base", Config.Economy.victoryGold(nil),
        Config.Economy.VICTORY_GOLD_BASE)
    t:eq("ato 0 cai na base", Config.Economy.victoryGold(0),
        Config.Economy.VICTORY_GOLD_BASE)

    -- ===== 2) quem paga e o Game =====
    local game = TK.newRunGame("warrior")
    -- HP cheio mudaria a folha; o que se mede aqui e a linha da VITORIA, que e
    -- sempre a primeira fonte.
    local a1 = victoryGoldPagoPeloGame(game, 1)
    local aN = victoryGoldPagoPeloGame(game, totalAtos)

    t:eq("o Game paga no ato 1 o mesmo que a formula",
        a1, Config.Economy.victoryGold(1))
    t:check("o Game paga MAIS no ato " .. totalAtos .. " que no ato 1"
        .. " (pago: $" .. a1 .. " -> $" .. aN .. ")", aN > a1)
    t:eq("o Game paga no ato " .. totalAtos .. " o mesmo que a formula",
        aN, Config.Economy.victoryGold(totalAtos))

    -- ===== 3) bonus de RISCO do no (Out/2026) =====
    -- Elite e chefe pagam uma linha a mais; luta comum e mini-chefe nao. Medido
    -- na folha do Game (nao so na formula), pelo rotulo traduzido da linha.
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
    -- mini-chefe e obrigatorio em todo ato: bonus nele seria renda fixa.
    t:eq("mini-chefe sem bonus (obrigatorio = nao e risco)", bonusPago("mini_boss", 3), 0)
    t:eq("chefe paga +1x a vitoria", bonusPago("boss", 4), Config.Economy.victoryGold(4))

    return t:done()
end

return M
