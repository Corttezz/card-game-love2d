-- src/systems/ScoreSystem.lua
-- Pontuação "TINTA × SELO" (F3 do gameplay-overhaul-v1) — o chips×mult do
-- grimório, na gramática do Balatro:
--
--   ScoreBatalha = floor(TINTA × SELO)
--   TINTA (base)  = maxHP do inimigo + 10·andar + 50·(ato−1)
--                   ×2 boss · ×1.25 elite · ×1.18^n no endless
--   SELO (mult)   = 1.0
--     + 0.30 por turno ABAIXO do par (par = 3 + ato)      [eficiência]
--     − 0.10 por turno acima (piso 0.5)
--     + 0.25 por combo de tag DISTINTO na batalha          [estilo]
--     + 0.50 se 3+ combos dispararam no MESMO turno
--     + 0.50 se terminou com HP ≤ 25%                      [risco]
--     + 1.00 flawless (nenhum dano tomado)
--
-- O score da RUN é a soma das batalhas (+ bônus de ato via caller).
-- Recorde histórico vive no ProfileStats (bestScore).
--
-- Integração (Game.lua):
--   startBattle()            — startGame / nextPhase / resumeRun
--   recordTurnCombos(ctx)    — playSelectedCards (turnContext.activeCombos)
--   recordDamageTaken(n)     — enemyTurn (dano que chegou no player)
--   finishBattle(game)       — _onEnemyDeath → retorna breakdown pro RoundEval

local ScoreSystem = {}
ScoreSystem.__index = ScoreSystem

function ScoreSystem:new()
    local instance = setmetatable({}, ScoreSystem)
    instance.runScore = 0
    instance.lastBattle = nil
    instance._battle = nil
    instance.recordBroken = false  -- true quando a run cruza o bestScore
    return instance
end

function ScoreSystem:reset()
    self.runScore = 0
    self.lastBattle = nil
    self._battle = nil
    self.recordBroken = false
end

function ScoreSystem:startBattle()
    self._battle = {
        combosDistinct = {},
        maxCombosInTurn = 0,
        damageTaken = 0,
    }
end

-- turnContext.activeCombos = lista de combos detectados neste turno.
function ScoreSystem:recordTurnCombos(activeCombos)
    local b = self._battle
    if not b then return end
    local n = 0
    for _, combo in ipairs(activeCombos or {}) do
        local key = combo.id or combo.name or tostring(combo)
        b.combosDistinct[key] = true
        n = n + 1
    end
    if n > b.maxCombosInTurn then b.maxCombosInTurn = n end
end

function ScoreSystem:recordDamageTaken(dmg)
    local b = self._battle
    if b and dmg and dmg > 0 then
        b.damageTaken = b.damageTaken + dmg
    end
end

-- Fecha a batalha vencida e soma no score da run.
-- Retorna { tinta, selo, total, turns, combos, flawless, lowHp }.
function ScoreSystem:finishBattle(game)
    local b = self._battle or {}
    self._battle = nil

    local run = game.isRunMode and game.runManager
        and game.runManager.currentRun or nil
    local act = (run and run.actNumber) or 1
    local floorN = (run and run.floorInAct) or math.min(8, game.currentPhase or 1)

    -- ===== TINTA =====
    local tinta = (game.enemy and game.enemy.maxHealth or 0)
        + 10 * floorN + 50 * (act - 1)
    local nodeType = run and run.currentNode and run.currentNode.type
    if nodeType == "boss" then
        tinta = tinta * 2
    elseif nodeType == "elite" or nodeType == "mini_boss" then
        tinta = math.floor(tinta * 1.25)
    end
    if run and run.endlessMode then
        tinta = math.floor(tinta * (1.18 ^ (run.floorsInEndless or 0)))
    end

    -- ===== SELO =====
    local selo = 1.0
    -- battleTurn conta turnos do INIMIGO; o do jogador que matou soma +1.
    local turnsUsed = (game.battleTurn or 0) + 1
    local par = 3 + act
    if turnsUsed < par then
        selo = selo + 0.30 * (par - turnsUsed)
    elseif turnsUsed > par then
        selo = math.max(0.5, selo - 0.10 * (turnsUsed - par))
    end

    local distinct = 0
    for _ in pairs(b.combosDistinct or {}) do distinct = distinct + 1 end
    selo = selo + 0.25 * distinct
    if (b.maxCombosInTurn or 0) >= 3 then selo = selo + 0.50 end

    local lowHp = false
    if game.player and game.player.maxHealth > 0 then
        lowHp = (game.player.health / game.player.maxHealth) <= 0.25
    end
    if lowHp then selo = selo + 0.50 end

    local flawless = (b.damageTaken or 0) == 0
    if flawless then selo = selo + 1.00 end

    selo = math.floor(selo * 100 + 0.5) / 100
    local total = math.floor(tinta * selo)

    -- Recibo LEGÍVEL (feedback do dono: "TINTA×SELO não ficou claro").
    -- Cada linha nomeia O QUE o jogador fez; a matemática fica implícita.
    local breakdown = {}
    table.insert(breakdown, {
        label = "Inimigo derrotado", value = tostring(tinta) .. " pts" })
    if turnsUsed < par then
        table.insert(breakdown, {
            label = ("Vitoria rapida (%d turnos)"):format(turnsUsed),
            value = ("+%d%%"):format(math.floor(30 * (par - turnsUsed) + 0.5)) })
    elseif turnsUsed > par then
        table.insert(breakdown, {
            label = ("Batalha longa (%d turnos)"):format(turnsUsed),
            value = ("-%d%%"):format(math.floor(10 * (turnsUsed - par) + 0.5)),
            bad = true })
    end
    if distinct > 0 then
        table.insert(breakdown, {
            label = ("Combos de cartas (%d)"):format(distinct),
            value = ("+%d%%"):format(25 * distinct) })
    end
    if (b.maxCombosInTurn or 0) >= 3 then
        table.insert(breakdown, {
            label = "3+ combos no mesmo turno", value = "+50%" })
    end
    if lowHp then
        table.insert(breakdown, {
            label = "Viveu no limite (HP baixo)", value = "+50%" })
    end
    if flawless then
        table.insert(breakdown, {
            label = "Nao tomou NENHUM dano", value = "+100%" })
    end

    self.lastBattle = {
        tinta = tinta, selo = selo, total = total,
        turns = turnsUsed, combos = distinct,
        flawless = flawless, lowHp = lowHp,
        breakdown = breakdown,
    }
    self.runScore = self.runScore + total
    return self.lastBattle
end

-- Bônus fixo por completar um ato (chamado pelo Game na virada de ato).
function ScoreSystem:addActBonus(actNumber)
    self.runScore = self.runScore + 500 * (actNumber or 1)
end

return ScoreSystem
