-- tools/test_enemy_death.lua
-- TRAVA DO FIM DA LUTA (Set/2026).
--
-- POR QUE ESTE TESTE EXISTE
-- Duas queixas do dono jogando, que sao o mesmo assunto:
--   1. "em alguns cenarios, o mob nao esta tendo a animacao de morrer, cair no
--      chao etc. Acho que e quando se buffa"
--   2. "a tela de vitoria ta aparecendo rapido demais, so aparece quando a
--      gente tem a confirmacao que ele morreu"
--
-- A causa de (1) nao era o buff: era a FONTE do golpe final. A morte so era
-- encenada no caminho da carta de ATAQUE. Magia, pulso e evocacao de orbe,
-- veneno e reflexo de espinhos zeravam a vida e a tela de espolios abria por
-- cima de um inimigo em pe. A causa de (2) era o gate: a vitoria so esperava
-- `isBlocking()`, nunca o relogio da morte.
--
-- "Nao crashou" nao prova nada aqui. Cada bloco afere o TRACE de beats
-- (CombatBeats grava a ordem executada) e o clip corrente do EnemyRenderer.
-- Revertendo as correcoes, cai:
--   * marcacao no Enemy (`_pendingDeath`)        -> 5 fontes sem morte
--   * gate da vitoria (`isReadyForEndScreen`)    -> "vitoria espera a morte" cai
--   * morte no beat do veneno                    -> a morte sai fora de ordem
--
--   love . test_one test_enemy_death
--   love . test_all

local TK = require("tools.testkit")
local CombatBeats = require("src.systems.CombatBeats")
local EnemyRenderer = require("src.ui.EnemyRenderer")

local M = {}

local function at(label) return CombatBeats.indexOf(label) end

local function countExact(label)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l == label then n = n + 1 end
    end
    return n
end

-- Estado limpo de renderizacao: sem isto o clip "death" de um caso anterior
-- ficaria de pe e o proximo bloco passaria sem ter animado nada (falso verde).
local function freshRenderer()
    EnemyRenderer.resetRun()
end

local function animName()
    local st = EnemyRenderer.debugState()
    return st and st.animName
end

-- Um caso de "matou por X": roda `kill(game)` com o trace ligado e cobra os
-- tres sinais da morte encenada.
local function assertDied(t, who, game)
    t:truthy(who .. ": a morte virou acontecimento na fila ("
        .. CombatBeats.traceString() .. ")", at("enemy.death") ~= nil)
    t:truthy(who .. ": o clip de MORTE esta tocando (o monstro cai na tela)",
        animName() == "death")
    t:truthy(who .. ": o combate segura a troca de tela (relogio da morte)",
        game._deathPauseTimer and game._deathPauseTimer > 0)
    t:eq(who .. ": a morte foi encenada UMA vez", countExact("enemy.death"), 1)
end

function M.run()
    local t = TK.new("fim da luta: a morte acontece, depois a vitoria")
    TK.bootstrap()

    -- ========================================================================
    -- 1. CARTA DE ATAQUE (o unico caminho que ja funcionava — controle)
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g.enemy.health = 4
        local card = { id = "tk_kill", name = "Teste Fatal", type = "attack",
                       cost = 0, attack = 40, defense = 0, effects = {} }
        table.insert(g.hand, card)
        g.player.mana = 3
        g:selectCard(card)
        CombatBeats.clear(); CombatBeats.startTrace()
        g:playSelectedCards()
        TK.pump(g, 6.0)
        CombatBeats.stopTrace()
        t:eq("carta de ataque: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "carta de ataque", g)
        local iImpact, iDeath = CombatBeats.indexOf("card.impact.attack"), at("enemy.death")
        t:truthy("a morte vem DEPOIS do golpe que a causou",
            iImpact and iDeath and iDeath > iImpact)
    end

    -- ========================================================================
    -- 2. MAGIA (effect card) — carta que nao e do tipo "attack"
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("mage")
        TK.pump(g, 0.5)
        g.enemy.health = 5
        local card = { id = "tk_bolt", name = "Teste Raio", type = "effect",
                       cost = 0, attack = 0, defense = 0,
                       effects = { { type = "magic_damage", value = 40 } } }
        table.insert(g.hand, card)
        g.player.mana = 3
        g:selectCard(card)
        CombatBeats.clear(); CombatBeats.startTrace()
        g:playSelectedCards()
        TK.pump(g, 6.0)
        CombatBeats.stopTrace()
        t:eq("magia: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "dano magico", g)
    end

    -- ========================================================================
    -- 3. PULSO DE ORBE (fim do turno do jogador — o "mago com as orbes")
    --    Era o caso mais descoberto: o proprio comentario do endTurn dizia
    --    "se o pulso matar, isPhaseCleared transiciona no proximo frame".
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("mage")
        TK.pump(g, 0.5)
        g.player.orbs = {}
        g.player:addOrb({ type = "lightning", value = 40 })
        g.enemy.health = 3
        CombatBeats.clear(); CombatBeats.startTrace()
        g:endTurn()
        TK.pump(g, 4.0)
        CombatBeats.stopTrace()
        t:eq("pulso de orbe: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "pulso de orbe", g)
        local iPulse = CombatBeats.indexOf("orb.pulse.lightning")
        t:truthy("a morte acontece NO pulso que matou, nao la na frente",
            iPulse and at("enemy.death") and at("enemy.death") >= iPulse)
    end

    -- ========================================================================
    -- 4. EVOCAR ORBE
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("mage")
        TK.pump(g, 0.5)
        g.player.orbs = {}
        g.player:addOrb({ type = "lightning", value = 40 })
        g.enemy.health = 3
        CombatBeats.clear(); CombatBeats.startTrace()
        local steps = {}
        g._beatSink = steps
        g.effectSystem:processEffectCard(g, { type = "evoke_orb" })
        g._beatSink = nil
        CombatBeats.pushAll(steps)
        TK.pump(g, 4.0)
        CombatBeats.stopTrace()
        t:eq("evocar orbe: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "evocar orbe", g)
    end

    -- ========================================================================
    -- 5. VENENO (DoT no fim do turno do inimigo) — aritmetica crua, fora do
    --    takeDamage: e por isso que a marcacao mora no Enemy e nao no caminho.
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("rogue")
        TK.pump(g, 0.5)
        g.enemy.health = 3
        g.enemy:addStatusEffect({ name = "poison", stacks = 9, duration = 3 })
        g.enemy.nextIntent = "defend"
        g.battleTurn = 1
        g.turn = "enemy"
        CombatBeats.clear(); CombatBeats.startTrace()
        g:enemyTurn()
        TK.pump(g, 6.0)
        CombatBeats.stopTrace()
        t:eq("veneno: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "veneno", g)
        local iDot, iDeath = at("enemy.dot"), at("enemy.death")
        t:truthy("a morte por veneno sai NO tick, nao no fim do turno",
            iDot and iDeath and iDeath >= iDot)
        t:truthy("a morte vem ANTES de a vez voltar pro jogador",
            iDeath and at("turn.player_ready") and iDeath < at("turn.player_ready"))
        -- O intent ficou como estava: `enemy.next_intent` nao rolou um golpe
        -- novo pra quem acabou de cair (o HUD chegava a piscar a intencao de
        -- um cadaver).
        t:eq("cadaver nao telegrafa o proximo golpe", g.enemy.nextIntent, "defend")
    end

    -- ========================================================================
    -- 6. ESPINHOS (reflexo no golpe do inimigo) — a leitura mais provavel do
    --    "quando se buffa": a carta de defesa ARMA um buff `thorn` no jogador
    --    e quem mata e o reflexo, nao a carta.
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g:processCardInCombat({
            id = "tk_thorn", name = "Teste Espinhos", type = "defense",
            cost = 0, attack = 0, defense = 5,
            effects = { { type = "on_defend_damage", value = 30 } },
        }, nil)
        g.enemy.health = 4
        g.enemy.nextIntent = "attack"
        g.enemy.damage = 3; g.enemy.baseDamage = 3; g.enemy.nextIntentDamage = 3
        g.battleTurn = 1
        g.turn = "enemy"
        CombatBeats.clear(); CombatBeats.startTrace()
        g:enemyTurn()
        TK.pump(g, 6.0)
        CombatBeats.stopTrace()
        t:eq("espinhos: o inimigo morreu", g.enemy.health, 0)
        assertDied(t, "reflexo de espinhos", g)
        local iRef, iDeath = at("player.thorn_reflect"), at("enemy.death")
        t:truthy("a morte sai NO reflexo que a causou",
            iRef and iDeath and iDeath >= iRef)
    end

    -- ========================================================================
    -- 7. REDE: morto sem marcacao nenhuma tambem cai na tela
    --    (fonte futura que mexa na vida por fora do Enemy)
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g.enemy.health = 0
        g.enemy._pendingDeath = nil
        CombatBeats.clear(); CombatBeats.startTrace()
        g:announceDeathIfPending(nil)
        TK.pump(g, 2.0)
        CombatBeats.stopTrace()
        assertDied(t, "rede (morto sem marcacao)", g)
    end

    -- ========================================================================
    -- 8. A VITORIA ESPERA A MORTE
    --    Queixa 2 do dono. O gate vive em Game:isReadyForEndScreen — e aqui
    --    que se prova que ele SEGURA, e nao so que existe.
    -- ========================================================================
    do
        freshRenderer()
        local MapManager = require("src.systems.MapManager")
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        local run = g.runManager.currentRun
        run.actNumber = 3
        run.floorInAct = MapManager.FLOORS_PER_ACT
        run.currentNode = { type = "boss" }
        run.endlessMode = false
        g.enemy.isBoss = true
        g.enemy.health = 4

        local card = { id = "tk_bosskill", name = "Teste Fatal", type = "attack",
                       cost = 0, attack = 40, defense = 0, effects = {} }
        table.insert(g.hand, card)
        g.player.mana = 3
        g:selectCard(card)
        CombatBeats.clear()
        g:playSelectedCards()

        -- Amostra frame a frame: em que instante cada coisa vira verdade.
        local dt = 1 / 30
        local frames, deathAtFrame, readyAtFrame = 0, nil, nil
        local victoryTrueAtFrame = nil
        for i = 1, 300 do
            TK.pump(g, dt)
            frames = i
            if g:checkVictory() and not victoryTrueAtFrame then victoryTrueAtFrame = i end
            if g._deathHandled and not deathAtFrame then deathAtFrame = i end
            -- O relogio da morte corre na cena; aqui reproduzimos o mesmo passo.
            if g._deathPauseTimer and g._deathPauseTimer > 0 then
                g._deathPauseTimer = math.max(0, g._deathPauseTimer - dt)
            end
            if g:isReadyForEndScreen() and not readyAtFrame then readyAtFrame = i end
            if readyAtFrame then break end
        end

        t:truthy("boss caido: checkVictory reconhece a vitoria", victoryTrueAtFrame ~= nil)
        t:truthy("a morte foi encenada", deathAtFrame ~= nil)
        t:truthy("a tela de vitoria NAO pode entrar no mesmo instante do golpe",
            readyAtFrame ~= nil and victoryTrueAtFrame ~= nil
            and readyAtFrame > victoryTrueAtFrame)
        t:truthy("a vitoria so libera DEPOIS de a morte ter acontecido na tela",
            readyAtFrame ~= nil and deathAtFrame ~= nil and readyAtFrame > deathAtFrame)
        -- Quanto de respiro, em segundos, entre "morreu" e "pode trocar de tela".
        local breath = readyAtFrame and deathAtFrame
            and (readyAtFrame - deathAtFrame) * dt or 0
        t:truthy(string.format(
            "o respiro entre a morte e a vitoria da pra ver (%.2fs, minimo 0.60s)",
            breath), breath >= 0.60)
        t:truthy("o clip de MORTE do boss esta tocando", animName() == "death")
        t:truthy("(frames ate liberar: " .. tostring(readyAtFrame)
            .. " de " .. tostring(frames) .. ") a amostragem exercitou o gate",
            frames > 1)
    end

    -- ========================================================================
    -- 8b. O RELOGIO DA MORTE VALE PRA VITORIA TAMBEM
    --     Este e o assert que separa o gate novo do antigo: antes, a vitoria
    --     so olhava `isBlocking()` e o `_deathPauseTimer` valia so pros
    --     espolios — a tela final entrava mais cedo que a tela de recompensa
    --     do inimigo comum, que e exatamente o "rapido demais" do dono.
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g.enemy.health = 0
        CombatBeats.clear()          -- fila vazia: sobra so o relogio da morte
        TK.pump(g, 0.5)
        g._deathPauseTimer = 0.5
        t:falsy("morte ainda rolando: nenhuma tela de desfecho entra",
            g:isReadyForEndScreen())
        g._deathPauseTimer = 0
        t:truthy("relogio zerado e fila vazia: ai sim libera",
            g:isReadyForEndScreen())
    end

    -- ========================================================================
    -- 9. INIMIGO COMUM: os espolios esperam a mesma coisa
    -- ========================================================================
    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g.enemy.health = 4
        local card = { id = "tk_kill2", name = "Teste Fatal", type = "attack",
                       cost = 0, attack = 40, defense = 0, effects = {} }
        table.insert(g.hand, card)
        g.player.mana = 3
        g:selectCard(card)
        g:playSelectedCards()

        -- Instante EXATO em que a vida zera: os espolios ja poderiam abrir
        -- (isPhaseCleared e so "health <= 0") e e justamente aqui que o gate
        -- tem que segurar — primeiro pela fila de beats, depois pelo relogio.
        local dt = 1 / 30
        local clearedAt
        for i = 1, 300 do
            TK.pump(g, dt)
            if g:isPhaseCleared() then clearedAt = i break end
        end
        t:truthy("a vida do inimigo zerou", clearedAt ~= nil)
        t:falsy("os espolios NAO abrem no instante em que a vida zera",
            g:isReadyForEndScreen())

        local opened = nil
        for i = 1, 300 do
            TK.pump(g, dt)
            if g._deathPauseTimer and g._deathPauseTimer > 0 then
                g._deathPauseTimer = math.max(0, g._deathPauseTimer - dt)
            end
            if g:isReadyForEndScreen() then opened = i break end
        end
        t:truthy("os espolios acabam abrindo (nao travou)", opened ~= nil)
        t:truthy("a morte ja tinha sido encenada quando abriram", g._deathHandled)
    end

    CombatBeats.clear()
    freshRenderer()
    return t:done()
end

return M
