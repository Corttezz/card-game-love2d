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

local function freshRenderer()
    EnemyRenderer.resetRun()
end

local function animName()
    local st = EnemyRenderer.debugState()
    return st and st.animName
end

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
        t:eq("cadaver nao telegrafa o proximo golpe", g.enemy.nextIntent, "defend")
    end

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

    do
        freshRenderer()
        local MapManager = require("src.systems.MapManager")
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        local run = g.runManager.currentRun
        run.actNumber = require("src.core.Config").TotalActs
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

        local dt = 1 / 30
        local frames, deathAtFrame, readyAtFrame = 0, nil, nil
        local victoryTrueAtFrame = nil
        for i = 1, 300 do
            TK.pump(g, dt)
            frames = i
            if g:checkVictory() and not victoryTrueAtFrame then victoryTrueAtFrame = i end
            if g._deathHandled and not deathAtFrame then deathAtFrame = i end
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

    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        g.enemy.health = 0
        CombatBeats.clear()
        TK.pump(g, 0.5)
        g._deathPauseTimer = 0.5
        t:falsy("morte ainda rolando: nenhuma tela de desfecho entra",
            g:isReadyForEndScreen())
        g._deathPauseTimer = 0
        t:truthy("relogio zerado e fila vazia: ai sim libera",
            g:isReadyForEndScreen())
    end

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

    do
        freshRenderer()
        local g = TK.newRunGame("mage")
        TK.pump(g, 0.5)
        g.enemy.maxHealth = 120
        g.enemy.health = 6

        local db = g.deckManager.cardDatabase
        local c1 = db:createCardInstance(db:getCard("mage_meteor_strike"))
        local c2 = db:createCardInstance(db:getCard("mage_meteor_strike"))
        c1.cost, c2.cost = 0, 0
        table.insert(g.hand, c1)
        table.insert(g.hand, c2)
        g.player.mana = 9
        g:selectCard(c1)
        g:selectCard(c2)

        CombatBeats.clear(); CombatBeats.startTrace()
        g:playSelectedCards()

        local dt, peak, frames = 1 / 30, 0, 0
        for i = 1, 600 do
            g:announceDeathIfPending(nil)
            if g._deathPauseTimer and g._deathPauseTimer > 0 then
                g._deathPauseTimer = math.max(0, g._deathPauseTimer - dt)
            end
            TK.pump(g, dt)
            peak = math.max(peak, CombatBeats.pending())
            frames = i
            if g:isReadyForEndScreen() then break end
        end
        CombatBeats.stopTrace()

        t:eq("a morte foi encenada UMA vez, nao uma por frame",
            countExact("enemy.death"), 1)
        t:truthy("a fila de beats nao inchou (pico " .. peak .. ", limite 14)",
            peak <= 14)
        t:falsy("o combate terminou (nao ficou bloqueando pra sempre)",
            g.combatAnimationSystem:isBlocking())
        t:falsy("a sequencia de combate saiu do ar", g.combatAnimationSystem.active)
        t:truthy("a tela de desfecho liberou (" .. frames .. " frames)",
            g:isReadyForEndScreen())
        t:truthy("e liberou RAPIDO, nao depois de dezenas de segundos ("
            .. string.format("%.1f", frames * dt) .. "s, limite 6s)",
            frames * dt <= 6.0)
    end

    do
        freshRenderer()
        local g = TK.newRunGame("warrior")
        TK.pump(g, 0.5)
        local card = { id = "tk_net", name = "Teste Rede", type = "attack",
                       cost = 0, attack = 3, defense = 0, effects = {} }
        table.insert(g.hand, card)
        g.player.mana = 3
        g:selectCard(card)
        local finished = false
        g.combatAnimationSystem:startCombat({ card },
            function() finished = true end,
            function() return {} end)
        TK.pump(g, 0.1)
        t:truthy("combate ativo depois de comecar", g.combatAnimationSystem.active)

        CombatBeats.clear()
        TK.pump(g, 0.3)
        t:truthy("logo depois da fila sumir, a rede ainda nao agiu (da tempo)",
            g.combatAnimationSystem.active)
        TK.pump(g, 1.2)
        t:falsy("a rede encerrou o combate travado",
            g.combatAnimationSystem.active)
        t:truthy("e chamou o callback de fim (o turno segue)", finished)
        t:falsy("o jogo voltou a andar", g.combatAnimationSystem:isBlocking())
    end

    CombatBeats.clear()
    freshRenderer()
    return t:done()
end

return M
