-- tools/test_beats.lua
-- TRAVA DO RITMO DO COMBATE (Set/2026).
--
-- POR QUE ESTE TESTE EXISTE
-- O dono jogou e disse: "muitas coisas so saem acontecendo e fica dificil de
-- entender e acompanhar". O defeito nao era visual — era TEMPO e ORDEM: dano,
-- debuff no inimigo, proc de coringa, pulso de orbe e compra de carta caiam no
-- mesmo instante. A correcao foi transformar o combate numa fila de BEATS
-- (src/systems/CombatBeats.lua), um acontecimento por instante, cada um
-- segurando o proximo.
--
-- "Nao crashou" nao prova nada aqui. Os asserts abaixo checam a ORDEM CAUSAL
-- executada (CombatBeats grava o trace) e o BLOQUEIO (nada anda na frente do
-- que ainda nao aconteceu). Se alguem reverter o mecanismo, cada bloco falha:
--   1. beat sem bloqueio  -> "um beat por vez" cai (tudo roda no 1o frame)
--   2. espinhos na jogada -> "espinhos NAO ferem ao jogar" cai
--   3. reflexo removido   -> "o golpe do inimigo cobra os espinhos" cai
--   4. ordem do turno     -> os indices do trace saem fora de ordem
--   5. orbes agregados    -> "um pulso por orbe" cai (1 beat em vez de 3)
--   6. heal_multiplier mudo -> "coringa de cura tica" cai
--
--   love . test_one test_beats
--   love . test_all

local TK = require("tools.testkit")
local CombatBeats = require("src.systems.CombatBeats")
local EffectSystem = require("src.systems.EffectSystem")

local M = {}

-- Indice do beat `label` no trace (nil se nunca rodou).
local function at(label)
    return CombatBeats.indexOf(label)
end

-- Indice do primeiro beat cujo label comeca com `prefix`.
local function atPrefix(prefix)
    for i, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then return i end
    end
    return nil
end

local function countPrefix(prefix)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end

local function countExact(label)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l == label then n = n + 1 end
    end
    return n
end

local function thornCard(value)
    return {
        id = "tk_thorn", name = "Teste Espinhos", type = "defense",
        cost = 1, attack = 0, defense = 5,
        effects = { { type = "on_defend_damage", value = value } },
    }
end

function M.run()
    local t = TK.new("ritmo do combate: beats, ordem causal e espinhos")
    TK.bootstrap()

    -- ========================================================================
    -- 1. A FILA SEGURA: um beat por vez
    -- ========================================================================
    CombatBeats.clear()
    CombatBeats.startTrace()
    local ran = {}
    CombatBeats.push("a", function() ran[#ran + 1] = "a" end, 0.5)
    CombatBeats.push("b", function() ran[#ran + 1] = "b" end, 0.5)
    CombatBeats.push("c", function() ran[#ran + 1] = "c" end, 0.5)
    TK.pump(nil, 0.2)
    t:eq("um beat por vez: so o 1o rodou em 0.2s", #ran, 1)
    TK.pump(nil, 0.5)
    t:eq("o 2o so roda depois do hold do 1o", #ran, 2)
    TK.pump(nil, 1.2)
    t:eq("a fila drena inteira", #ran, 3)
    t:eq("ordem preservada", table.concat(ran, ","), "a,b,c")
    t:eq("fila vazia no fim", CombatBeats.pending(), 0)

    -- SEMANTICA MEDIDA: push joga no FIM da fila mesmo chamado de dentro de um
    -- beat. E por isso que resolucao de carta e turno do inimigo sao escritos
    -- como CADEIA (o beat corrente empurra os passos dele e, por ultimo, o elo
    -- seguinte) — pre-agendar carta 1 e carta 2 juntas jogaria os efeitos da
    -- carta 1 pra depois da carta 2. Este assert existe pra que a regra nao
    -- seja "descoberta" de novo na marra.
    ran = {}
    CombatBeats.push("outer", function()
        ran[#ran + 1] = "outer"
        CombatBeats.push("inner", function() ran[#ran + 1] = "inner" end, 0.1)
    end, 0.1)
    CombatBeats.push("after", function() ran[#ran + 1] = "after" end, 0.1)
    TK.pump(nil, 1.0)
    t:eq("push de dentro de um beat vai pro FIM da fila (regra da cadeia)",
        table.concat(ran, ","), "outer,after,inner")
    CombatBeats.stopTrace()

    -- ========================================================================
    -- 2. ESPINHOS: a carta ARMA, o GOLPE DO INIMIGO cobra
    --    (pedido do dono: "esse dano nao deveria ser so quando o inimigo
    --     atacar?" — antes o reflexo saia no instante em que a carta era jogada)
    -- ========================================================================
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    local hpEnemy = g.enemy.health
    g:processCardInCombat(thornCard(7), nil)
    t:eq("espinhos NAO ferem ao jogar a carta", g.enemy.health, hpEnemy)
    t:eq("a carta armou 7 de espinhos", g.player:getBuffStacks("thorn"), 7)
    t:eq("bloqueio da carta entrou normalmente", g.player.armor, 5)

    -- O inimigo ATACA -> o reflexo acontece.
    g.enemy.nextIntent = "attack"
    g.enemy.damage = 6; g.enemy.baseDamage = 6; g.enemy.nextIntentDamage = 6
    g.battleTurn = 1
    g.turn = "enemy"
    g:enemyTurn()
    TK.pump(g, 3.5)
    t:eq("o golpe do inimigo cobra os espinhos (-7)", g.enemy.health, hpEnemy - 7)
    t:eq("espinhos expiram no upkeep do jogador seguinte",
        g.player:getBuffStacks("thorn"), 0)
    t:eq("a vez voltou pro jogador", g.turn, "player")

    -- CONTROLE: inimigo que NAO ataca nao leva reflexo nenhum.
    local g2 = TK.newRunGame("warrior")
    TK.pump(g2, 0.5)
    local hp2 = g2.enemy.health
    g2:processCardInCombat(thornCard(7), nil)
    g2.enemy.nextIntent = "defend"
    g2.battleTurn = 1
    g2.turn = "enemy"
    g2:enemyTurn()
    TK.pump(g2, 3.5)
    t:eq("inimigo que DEFENDE nao leva reflexo", g2.enemy.health, hp2)

    -- ========================================================================
    -- 3. ORDEM CAUSAL DO TURNO DO INIMIGO
    -- ========================================================================
    local g3 = TK.newRunGame("warrior")
    TK.pump(g3, 0.5)
    g3:processCardInCombat(thornCard(4), nil)      -- espinhos armados
    g3.enemy:addStatusEffect({ name = "poison", stacks = 3, duration = 3 })
    g3.enemy.nextIntent = "attack"
    g3.enemy.damage = 4; g3.enemy.baseDamage = 4; g3.enemy.nextIntentDamage = 4
    g3.battleTurn = 1
    g3.turn = "enemy"

    CombatBeats.clear()
    CombatBeats.startTrace()
    g3:enemyTurn()

    -- BLOQUEIO: o turno inteiro NAO pode caber num piscar de olhos.
    TK.pump(g3, 0.2)
    local early = #CombatBeats.log
    t:truthy("turno do inimigo NAO resolve tudo em 0.2s (bloqueia mesmo)",
        early > 0 and early <= 2)
    t:truthy("isBlocking() segura o jogo enquanto ha beats pendentes",
        g3.combatAnimationSystem:isBlocking())

    TK.pump(g3, 4.0)
    CombatBeats.stopTrace()
    local order = {
        "enemy.telegraph", "enemy.attack", "player.thorn_reflect",
        "enemy.dot", "enemy.next_intent", "player.upkeep",
        "player.draw", "turn.player_ready",
    }
    local prev, okOrder = 0, true
    for _, label in ipairs(order) do
        local idx = at(label)
        if not idx then
            t:truthy("beat presente no turno: " .. label, false)
            okOrder = false
        elseif idx <= prev then
            okOrder = false
        else
            prev = idx
        end
    end
    t:truthy("ordem causal do turno do inimigo (" .. CombatBeats.traceString() .. ")",
        okOrder)
    t:truthy("nenhum beat do turno se repetiu (re-entrancia bloqueada)",
        countExact("enemy.telegraph") == 1 and countExact("enemy.attack") == 1)

    -- ========================================================================
    -- 4. ORBES DO MAGO: um pulso por orbe, cada um no instante dele
    -- ========================================================================
    local gm = TK.newRunGame("mage")
    TK.pump(gm, 0.5)
    gm.player.orbs = {}
    gm.player:addOrb({ type = "lightning", value = 4 })
    gm.player:addOrb({ type = "ice", value = 4 })
    gm.player:addOrb({ type = "lightning", value = 4 })
    local enemyHpM = gm.enemy.health

    CombatBeats.clear()
    CombatBeats.startTrace()
    gm:endTurn()
    TK.pump(gm, 0.15)
    t:eq("pulso dos orbes: so o primeiro saiu em 0.15s", countPrefix("orb.pulse."), 1)
    TK.pump(gm, 2.0)
    CombatBeats.stopTrace()
    t:eq("um beat de pulso POR ORBE (3 orbes = 3 beats)",
        countPrefix("orb.pulse."), 3)
    -- Valor esperado pela formula CANONICA (a mesma que a UI exibe) — o mago
    -- comeca com Foco 2 (passiva Conduite), entao cravar "2 de dano" no teste
    -- seria testar um numero desatualizado em vez da mecanica.
    local focusM = gm.player:getBuffStacks("focus") or 0
    local expectedPulse = 0
    for _, o in ipairs({ { type = "lightning", value = 4 }, { type = "lightning", value = 4 } }) do
        expectedPulse = expectedPulse + EffectSystem.orbPulseValue(o, focusM)
    end
    t:eq("os pulsos aplicaram o dano de cada orbe",
        gm.enemy.health, enemyHpM - expectedPulse)
    t:truthy("o pulso de gelo virou bloqueio", gm.player.armor >= 2)

    -- evoke_all_orbs tambem evoca UM DE CADA VEZ
    local gm2 = TK.newRunGame("mage")
    TK.pump(gm2, 0.5)
    gm2.player.orbs = {}
    gm2.player:addOrb({ type = "lightning", value = 3 })
    gm2.player:addOrb({ type = "lightning", value = 3 })
    CombatBeats.clear()
    CombatBeats.startTrace()
    local steps = {}
    gm2._beatSink = steps
    gm2.effectSystem:processEffectCard(gm2, { type = "evoke_all_orbs" })
    gm2._beatSink = nil
    CombatBeats.pushAll(steps)
    TK.pump(gm2, 2.0)
    CombatBeats.stopTrace()
    t:eq("evoke_all_orbs: um beat de evoke por orbe", countExact("orb.evoke"), 2)
    t:eq("evoke_all_orbs esvaziou os orbes", #gm2.player.orbs, 0)

    -- ========================================================================
    -- 4b. CANALIZACAO MULTIPLA: N orbes = N acontecimentos CONTAVEIS, e
    --     nenhum deles no instante do DANO.
    --     (pedido do dono, Set/2026, jogando de mago: "Chuva de Meteoros
    --      canaliza muitas ao mesmo tempo, fica confuso se esta dando dano ou
    --      se canalizando uma nova")
    --
    --     O BUG QUE ESTE BLOCO PEGA: os beats de orbe ja existiam, mas a
    --     MUTACAO nao. `player:addOrb` rodava na COLETA -- dentro do beat de
    --     impacto da carta -- entao a fileira ia de 0 a 3 orbes no MESMO frame
    --     do numero de dano, e os beats seguintes so tocavam som em cima de
    --     orbes que ja estavam la. Reverter isso derruba as asserções de
    --     "a fileira passou por 1 e por 2": com o bug ela pula de 0 pra 3.
    -- ========================================================================
    local gmc = TK.newRunGame("mage")
    TK.pump(gmc, 0.5)
    gmc.player.orbs = {}                       -- limpa o orbe da passiva Conduite
    local meteor = {
        id = "tk_meteor", name = "Teste Chuva de Meteoros", type = "attack",
        cost = 0, attack = 6, defense = 0,
        effects = {
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
        },
    }
    table.insert(gmc.hand, meteor)
    gmc.player.mana = 3
    gmc:selectCard(meteor)

    local enemyHpC = gmc.enemy.health
    CombatBeats.clear()
    CombatBeats.startTrace()
    gmc:playSelectedCards()

    -- Amostra a cada 1/20s: quantos orbes a FILEIRA mostrava e se o dano ja
    -- tinha saido. E a leitura do JOGADOR quadro a quadro, nao o estado final.
    local sawCount, orbsAtImpact, dmgLanded = {}, nil, false
    for _ = 1, 160 do
        TK.pump(gmc, 0.05)
        local n = #gmc.player.orbs
        sawCount[n] = true
        if not dmgLanded and gmc.enemy.health < enemyHpC then
            dmgLanded = true
            orbsAtImpact = n
        end
    end
    CombatBeats.stopTrace()

    t:truthy("o dano da carta aconteceu", dmgLanded)
    t:eq("nenhum orbe nasceu no instante do DANO (dano e canalizacao sao"
        .. " acontecimentos separados)", orbsAtImpact, 0)
    t:eq("um beat de canalizacao POR ORBE (3 orbes = 3 beats)",
        countExact("orb.channel"), 3)
    t:truthy("a fileira passou por 1 orbe (os 3 nao aparecem de uma vez)",
        sawCount[1] == true)
    t:truthy("a fileira passou por 2 orbes", sawCount[2] == true)
    t:eq("os 3 orbes acabaram canalizados", #gmc.player.orbs, 3)
    t:truthy("cada canalizacao veio DEPOIS do impacto da carta ("
        .. CombatBeats.traceString() .. ")",
        atPrefix("card.impact.") and at("orb.channel")
        and at("orb.channel") > atPrefix("card.impact."))
    t:truthy("a carta so queima depois de canalizar tudo",
        at("card.dissolve") and at("orb.channel")
        and at("card.dissolve") > at("orb.channel"))

    -- ========================================================================
    -- 4c. OVERFLOW e um TERCEIRO acontecimento, com instante proprio.
    --     Canalizar com a fileira cheia EXPULSA o mais antigo (evocando-o).
    --     Sem instante proprio o jogador ve um orbe sumir e nao entende por que.
    -- ========================================================================
    local gof = TK.newRunGame("mage")
    TK.pump(gof, 0.5)
    gof.player.orbs = {}
    gof.player:addOrb({ type = "lightning", value = 3 })
    gof.player:addOrb({ type = "lightning", value = 3 })
    gof.player:addOrb({ type = "lightning", value = 3 })
    t:eq("fileira cheia (3 de 3)", #gof.player.orbs, gof.player.orbSlots)
    local hpOf = gof.enemy.health

    local steps = {}
    gof._beatSink = steps
    gof.effectSystem:processEffectCard(gof, { type = "channel_orb", orbType = "ice", value = 5 })
    gof._beatSink = nil
    -- ANTES de tocar os beats nada pode ter mudado: o estado mora DENTRO do
    -- acontecimento. Com o bug antigo a fileira ja estaria com o orbe de gelo.
    t:eq("a fileira NAO muda na coleta, so quando o beat toca",
        gof.player.orbs[3].type, "lightning")
    t:eq("o inimigo NAO leva o dano do overflow na coleta", gof.enemy.health, hpOf)

    CombatBeats.clear()
    CombatBeats.startTrace()
    CombatBeats.pushAll(steps)
    TK.pump(gof, 2.5)
    CombatBeats.stopTrace()

    t:eq("expulsar o orbe mais antigo e UM acontecimento",
        countExact("orb.overflow"), 1)
    t:truthy("o orbe SAI antes do novo entrar (" .. CombatBeats.traceString() .. ")",
        at("orb.overflow") and at("orb.channel")
        and at("orb.overflow") < at("orb.channel"))
    t:eq("o orbe novo entrou no fim da fila", gof.player.orbs[3].type, "ice")
    t:eq("a fileira continua no cap", #gof.player.orbs, 3)
    t:truthy("o orbe expulso EVOCOU de verdade (o dano dele saiu)",
        gof.enemy.health < hpOf)

    -- Controle: com vaga na fileira NAO existe expulsao (o beat condicional
    -- orb.make_room custa MICRO e nao vira acontecimento).
    local gro = TK.newRunGame("mage")
    TK.pump(gro, 0.5)
    gro.player.orbs = {}
    local steps2 = {}
    gro._beatSink = steps2
    gro.effectSystem:processEffectCard(gro, { type = "channel_orb", orbType = "ice", value = 5 })
    gro._beatSink = nil
    CombatBeats.clear()
    CombatBeats.startTrace()
    CombatBeats.pushAll(steps2)
    TK.pump(gro, 2.0)
    CombatBeats.stopTrace()
    t:eq("com vaga livre nao ha expulsao nenhuma", countExact("orb.overflow"), 0)
    t:eq("mesmo assim o orbe foi canalizado", #gro.player.orbs, 1)

    -- ========================================================================
    -- 4d. EVOCAR tambem muda o estado DENTRO do beat -- senao o orbe some no
    --     impacto e o flash cai depois, num slot que ja e de outro orbe.
    -- ========================================================================
    local gev = TK.newRunGame("mage")
    TK.pump(gev, 0.5)
    gev.player.orbs = {}
    gev.player:addOrb({ type = "lightning", value = 3 })
    gev.player:addOrb({ type = "ice", value = 3 })
    local steps3 = {}
    gev._beatSink = steps3
    gev.effectSystem:processEffectCard(gev, { type = "evoke_orb" })
    gev._beatSink = nil
    t:eq("o orbe NAO sai da fileira na coleta", #gev.player.orbs, 2)
    CombatBeats.pushAll(steps3)
    TK.pump(gev, 1.5)
    t:eq("o orbe sai quando o beat de evoke toca", #gev.player.orbs, 1)
    t:eq("saiu o MAIS ANTIGO (FIFO)", gev.player.orbs[1].type, "ice")

    -- ========================================================================
    -- 4f. CADA PULSO ATERRISSA ONDE O EFEITO DELE ACONTECE -- e com a
    --     assinatura do ELEMENTO, nao um efeito generico.
    --     (pedido do dono, Set/2026: "os orbes, quando dao dano ao final do
    --      turno, eles poderiam refletir algo no inimigo visualmente tambem,
    --      cada um de uma forma sabe, visual e som")
    --
    --     A METADE PERIGOSA e a que o pedido NAO cobre: gelo da Bloqueio e
    --     sagrado CURA -- se eles estourarem no inimigo, o jogo ensina que
    --     defender fere, que e exatamente o defeito dos espinhos (doutrina de
    --     defeitos, §3: feedback certo no lugar errado deixa o jogador convicto
    --     do errado). Sombra nem sai da fileira: engorda o proprio orbe.
    --
    --     Como se observa isso num teste headless: interceptando as chamadas de
    --     som e de burst. E o contrato real -- quem toca o que, e ONDE.
    -- ========================================================================
    do
        local Sfx = require("src.systems.Sfx")
        local CardFeel = require("src.systems.CardFeel")
        local OrbRow = require("src.ui.OrbRow")
        local realPlay      = Sfx.play
        local realAtEnemy   = CardFeel.burstAtEnemy
        local realAtPlayer  = CardFeel.burstAtPlayer
        local realAtSlot    = OrbRow.burstAtSlot

        local log
        local function resetLog() log = { sfx = {}, enemy = {}, player = {}, slot = {} } end
        resetLog()   -- criar o Game ja toca sons: o coletor precisa existir antes
        Sfx.play = function(name) log.sfx[#log.sfx + 1] = name end
        CardFeel.burstAtEnemy  = function(theme) log.enemy[#log.enemy + 1] = theme end
        CardFeel.burstAtPlayer = function(theme) log.player[#log.player + 1] = theme end
        OrbRow.burstAtSlot     = function(_, theme) log.slot[#log.slot + 1] = theme end

        -- Dispara o pulso de UM orbe isolado e devolve o que foi tocado/estourado.
        local function pulseOf(orbType, value)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = { { type = orbType, value = value or 4 } }
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local before = {
                enemyHp = g.enemy.health,
                armor   = g.player.armor,
                hp      = g.player.health,
                orbVal  = g.player.orbs[1].value,
            }
            resetLog()
            local steps = {}
            g.effectSystem:orbPassiveTick(g, steps)
            CombatBeats.pushAll(steps)
            TK.pump(g, 1.5)
            return g, before
        end

        local sounds = {}

        -- RAIO: fere -> marca no INIMIGO
        local g, b = pulseOf("lightning", 4)
        t:truthy("pulso de RAIO fere o inimigo", g.enemy.health < b.enemyHp)
        t:eq("raio estoura NO INIMIGO", #log.enemy, 1)
        t:eq("raio usa a paleta de raio", log.enemy[1], "lightning")
        t:eq("raio nao estoura no painel do jogador", #log.player, 0)
        t:eq("raio toca UM som", #log.sfx, 1)
        sounds.lightning = log.sfx[1]

        -- FOGO: fere -> marca no INIMIGO, com outro som e outra paleta
        g, b = pulseOf("fire", 6)
        t:truthy("pulso de FOGO fere o inimigo", g.enemy.health < b.enemyHp)
        t:eq("fogo estoura NO INIMIGO", #log.enemy, 1)
        t:eq("fogo usa a paleta de fogo", log.enemy[1], "fire")
        sounds.fire = log.sfx[1]

        -- GELO: da Bloqueio -> marca no JOGADOR, NUNCA no inimigo
        g, b = pulseOf("ice", 4)
        t:truthy("pulso de GELO da Bloqueio", g.player.armor > b.armor)
        t:eq("o inimigo NAO leva dano do pulso de gelo", g.enemy.health, b.enemyHp)
        t:eq("gelo NAO estoura no inimigo (defender nao fere)", #log.enemy, 0)
        t:eq("gelo estoura no painel do jogador", #log.player, 1)
        t:eq("gelo usa a paleta de gelo", log.player[1], "ice")
        sounds.ice = log.sfx[1]

        -- SAGRADO: cura -> marca no JOGADOR, NUNCA no inimigo
        g, b = pulseOf("holy", 6)
        t:truthy("pulso SAGRADO cura o heroi", g.player.health > b.hp)
        t:eq("o inimigo NAO leva dano do pulso sagrado", g.enemy.health, b.enemyHp)
        t:eq("sagrado NAO estoura no inimigo (curar nao fere)", #log.enemy, 0)
        t:eq("sagrado estoura no painel do jogador", #log.player, 1)
        t:eq("sagrado usa a paleta sagrada", log.player[1], "holy")
        sounds.holy = log.sfx[1]

        -- SOMBRA: cresce no proprio orbe -> marca NO ORBE
        g, b = pulseOf("dark", 5)
        t:eq("pulso de SOMBRA engorda o proprio orbe",
            g.player.orbs[1].value, b.orbVal + 2)
        t:eq("o inimigo NAO leva dano do pulso de sombra", g.enemy.health, b.enemyHp)
        t:eq("sombra NAO estoura no inimigo", #log.enemy, 0)
        t:eq("sombra NAO estoura no painel do jogador", #log.player, 0)
        t:eq("sombra estoura NO PROPRIO ORBE", #log.slot, 1)
        t:eq("sombra usa a paleta de sombra", log.slot[1], "dark")
        sounds.dark = log.sfx[1]

        -- CADA UM DE UMA FORMA: os 5 sons tem que ser DIFERENTES entre si.
        -- (Reverter pra um som generico unico derruba esta asserção.)
        local uniq, names = {}, {}
        for k, v in pairs(sounds) do
            names[#names + 1] = k .. "=" .. tostring(v)
            uniq[tostring(v)] = true
        end
        local nUniq = 0
        for _ in pairs(uniq) do nUniq = nUniq + 1 end
        table.sort(names)
        t:eq("os 5 elementos soam DIFERENTE (" .. table.concat(names, " ") .. ")",
            nUniq, 5)

        Sfx.play = realPlay
        CardFeel.burstAtEnemy = realAtEnemy
        CardFeel.burstAtPlayer = realAtPlayer
        OrbRow.burstAtSlot = realAtSlot
    end

    -- ========================================================================
    -- 4g. A FILEIRA TEM QUE SE LER: silhueta = elemento, glifo = unidade.
    --     (pedido do dono, Set/2026: "esta meio dificil de entender esses
    --      circulos ali, podemos pensar em algo diferente")
    --
    --     A captura `lovec . preview_battle_hud orbs` mostrou o defeito: cinco
    --     DISCOS iguais, quatro deles exibindo o mesmo "3", e o icone do
    --     elemento a ~14px virava mancha. O redesenho deu SILHUETA propria a
    --     cada elemento e um GLIFO DE UNIDADE ao lado do numero.
    --
    --     O que este bloco trava nao e "esta bonito" -- e que o orbe nao MINTA:
    --     a unidade que ele anuncia tem que ser a que o EffectSystem de fato
    --     aplica. Se alguem mudar o pulso do gelo pra dano e esquecer o glifo,
    --     a fileira passa a ensinar causalidade errada em silencio.
    -- ========================================================================
    do
        local OrbRow = require("src.ui.OrbRow")
        local TYPES = { "lightning", "ice", "fire", "dark", "holy" }

        -- (a) cada elemento tem uma silhueta, e nenhuma se repete
        local byShape = {}
        for _, ty in ipairs(TYPES) do
            local sh = OrbRow.SHAPES[ty]
            t:truthy("orbe " .. ty .. " tem silhueta propria (nao e mais disco)",
                type(sh) == "table" and #sh >= 6)
            local key = table.concat(sh or {}, ",")
            t:falsy("a silhueta de " .. ty .. " nao repete a de "
                .. tostring(byShape[key]), byShape[key] ~= nil)
            byShape[key] = ty
        end

        -- (b) o que o EffectSystem REALMENTE faz com cada pulso, observado
        local function observedPulseUnit(orbType)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = { { type = orbType, value = 6 } }
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local b = { hp = g.enemy.health, armor = g.player.armor,
                        php = g.player.health, val = 6 }
            local steps = {}
            g.effectSystem:orbPassiveTick(g, steps)
            CombatBeats.pushAll(steps)
            TK.pump(g, 1.5)
            if g.enemy.health < b.hp then return "damage" end
            if g.player.armor > b.armor then return "block" end
            if g.player.health > b.php then return "heal" end
            if ((g.player.orbs[1] or {}).value or 0) > b.val then return "grow" end
            return "nada"
        end

        local function observedEvokeUnit(orbType)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = {}
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local b = { hp = g.enemy.health, armor = g.player.armor,
                        php = g.player.health }
            g.effectSystem:_evokeOrbEffect(g, { type = orbType, value = 6 })
            if g.enemy.health < b.hp then return "damage" end
            if g.player.armor > b.armor then return "block" end
            if g.player.health > b.php then return "heal" end
            return "nada"
        end

        for _, ty in ipairs(TYPES) do
            t:eq("o glifo do PULSO de " .. ty .. " diz o que o pulso faz",
                OrbRow.UNIT_OF.pulse[ty], observedPulseUnit(ty))
            t:eq("o glifo do EVOKE de " .. ty .. " diz o que o evoke faz",
                OrbRow.UNIT_OF.evoke[ty], observedEvokeUnit(ty))
        end

        -- (c) o numero nao pode ser mentira: SOMBRA nao pulsa, entao o que ela
        --     mostra e o valor ACUMULADO (o que dobra ao evocar), nunca o zero
        --     do pulso.
        local EffectSystem2 = require("src.systems.EffectSystem")
        local darkOrb = { type = "dark", value = 7 }
        t:eq("sombra nao pulsa (valor de pulso e zero)",
            EffectSystem2.orbPulseValue(darkOrb, 0), 0)
        local vDark, uDark = OrbRow.readout(darkOrb, 0, "pulse")
        t:eq("mas a fileira mostra o valor ACUMULADO, nao o zero", vDark, 7)
        t:eq("e o glifo dela diz CRESCE, nao dano", uDark, "grow")
        local vEv, uEv = OrbRow.readout(darkOrb, 0, "evoke")
        t:eq("no preview de evoke o numero vira o dobro", vEv, 14)
        t:eq("e o glifo vira DANO (e o que evocar sombra faz)", uEv, "damage")

        -- (d) Foco entra na conta que a fileira exibe (senao o numero na tela
        --     diverge do dano que sai).
        local vFocus = OrbRow.readout({ type = "lightning", value = 4 }, 2, "pulse")
        t:eq("o numero exibido ja inclui o Foco",
            vFocus, EffectSystem2.orbPulseValue({ type = "lightning", value = 4 }, 2))
    end

    -- ========================================================================
    -- 4h. O MAGO NAO ENVENENA NINGUEM (ponta a ponta, numa run de verdade)
    --     Queixa do dono, jogando: "por que o inimigo esta ficando com veneno
    --     na minha run de mago? nao faz muito sentido". Estava certo — o ramo
    --     `fire` de _evokeOrbEffect aplicava `poison` como atalho.
    --
    --     Os blocos de tools/test_effects_full cobrem a unidade; ESTE cobre a
    --     CADEIA inteira, que e onde o jogador vive: evocar fogo -> queimadura
    --     entra -> turno do inimigo -> o beat do DoT tica -> a vida cai.
    -- ========================================================================
    do
        local gf = TK.newRunGame("mage")
        TK.pump(gf, 0.5)
        gf.player.orbs = {}
        gf.effectSystem:processEffectCard(gf,
            { type = "channel_orb", orbType = "fire", value = 6 })
        gf.effectSystem:processEffectCard(gf, { type = "evoke_orb" })

        t:truthy("evocar fogo deixa QUEIMADURA no inimigo",
            gf.enemy:hasStatus("burn"))
        t:falsy("e NAO deixa veneno (o mago nao tem carta de veneno no deck)",
            gf.enemy:hasStatus("poison"))

        -- O turno do inimigo tica o DoT: a queimadura tem que DOER.
        local hpBefore = gf.enemy.health
        gf.enemy.armor = 0
        -- `buff`, nao `defend`: defender da armadura ANTES do beat do DoT e a
        -- armadura absorveria a queimadura inteira -- o teste passaria a medir
        -- a armadura em vez do DoT.
        gf.enemy.nextIntent = "buff"
        gf.battleTurn = 1
        gf.turn = "enemy"
        CombatBeats.clear()
        CombatBeats.startTrace()
        gf:enemyTurn()
        TK.pump(gf, 4.0)
        CombatBeats.stopTrace()

        t:truthy("o beat do DoT aconteceu (" .. CombatBeats.traceString() .. ")",
            at("enemy.dot") ~= nil)
        t:truthy("a queimadura DOEU no turno do inimigo",
            gf.enemy.health < hpBefore)
    end

    -- ========================================================================
    -- 4e. O CASO REAL: quantas cartas do catalogo canalizam em rajada?
    --     Asserção de CONTAGEM pra nao passar verde por nao ter exercitado nada.
    -- ========================================================================
    do
        local CardDatabase = require("src.systems.CardDatabase")
        local all = CardDatabase.getAllCards and CardDatabase:getAllCards() or {}
        local multi, mixed, total = {}, {}, 0
        for id, cd in pairs(all) do
            total = total + 1
            local ch, dmg = 0, false
            for _, e in ipairs(cd.effects or {}) do
                if e.type == "channel_orb" then ch = ch + 1 end
                if e.type == "magic_damage" or e.type == "aoe_magic_damage" then dmg = true end
            end
            if (cd.attack or 0) > 0 then dmg = true end
            if ch >= 2 then multi[#multi + 1] = id end
            if ch >= 1 and dmg then mixed[#mixed + 1] = id end
        end
        table.sort(multi); table.sort(mixed)
        print("[beats] catalogo lido: " .. total .. " cartas")
        print("[beats] canalizam 2+ orbes: " .. table.concat(multi, ", "))
        print("[beats] misturam dano + canalizacao: " .. table.concat(mixed, ", "))
        t:truthy("o catalogo foi mesmo lido (" .. total .. " cartas)", total > 50)
        t:truthy("o catalogo TEM cartas que canalizam em rajada (" .. #multi .. ")",
            #multi >= 3)
        t:truthy("o catalogo TEM cartas que misturam dano e canalizacao ("
            .. #mixed .. ")", #mixed >= 8)
    end

    -- ========================================================================
    -- 5. CORINGA QUE MUDA UM NUMERO TEM QUE TICAR
    --    (Abraco Sombrio: defense_bonus ticava, heal_multiplier era MUDO)
    -- ========================================================================
    local gj = TK.newRunGame("warrior")
    TK.pump(gj, 0.5)
    gj:addJokerToRun("warrior_dark_embrace")
    local jk = gj.jokerSlots[#gj.jokerSlots]
    t:truthy("Abraco Sombrio ativo no slot", jk ~= nil)
    local procs = {}
    local healed = gj.effectSystem:applyHealMultiplier(gj, 10, procs)
    t:eq("heal_multiplier 1.5 aplicou o valor", healed, 15)
    t:eq("heal_multiplier EMPURRA proc (coringa deixa de ser mudo)", #procs, 1)
    t:truthy("o proc aponta o slot do coringa certo",
        procs[1] and procs[1].joker == jk)

    -- Cobertura: TODO tipo continuo de coringa do catalogo empurra proc.
    do
        local gAll = TK.newRunGame("warrior")
        TK.pump(gAll, 0.5)
        gAll.jokerSlots = {
            { effects = { { type = "damage_multiplier", target = "attack", value = 2 } } },
            { effects = { { type = "damage_bonus", value = 3 } } },
        }
        local _, p1 = gAll.effectSystem:applyJokerEffects(gAll, { type = "attack" }, 10)
        t:eq("damage_multiplier + damage_bonus ticam (2 procs)", #p1, 2)
        gAll.jokerSlots = {
            { effects = { { type = "defense_multiplier", target = "defense", value = 1.5 } } },
            { effects = { { type = "defense_bonus", value = 2 } } },
        }
        local _, p2 = gAll.effectSystem:applyJokerEffects(gAll, { type = "defense" }, 10)
        t:eq("defense_multiplier + defense_bonus ticam (2 procs)", #p2, 2)
    end

    -- ========================================================================
    -- 6. RESOLUCAO DE CARTA: impacto > coringas > efeitos > dissolve > proxima
    -- ========================================================================
    local gc = TK.newRunGame("rogue")
    TK.pump(gc, 0.5)
    -- Carta de ataque com efeito secundario (veneno): o debuff no inimigo tem
    -- que acontecer DEPOIS do dano, num instante proprio.
    local atk = {
        id = "tk_atk", name = "Teste Golpe", type = "attack",
        cost = 0, attack = 6, defense = 0,
        effects = { { type = "apply_debuff", value = "poison", stacks = 2, duration = 2 } },
    }
    table.insert(gc.hand, atk)
    gc.player.mana = 3
    gc:selectCard(atk)
    CombatBeats.clear()
    CombatBeats.startTrace()
    gc:playSelectedCards()
    TK.pump(gc, 6.0)
    CombatBeats.stopTrace()
    local iImpact = atPrefix("card.impact.")
    local iEffect = at("effect.apply_debuff")
    local iDissolve = at("card.dissolve")
    t:truthy("carta impactou (" .. CombatBeats.traceString() .. ")", iImpact ~= nil)
    t:truthy("o debuff no inimigo tem beat proprio", iEffect ~= nil)
    t:truthy("debuff DEPOIS do impacto", iImpact and iEffect and iEffect > iImpact)
    t:truthy("dissolve DEPOIS do efeito da carta",
        iDissolve and iEffect and iDissolve > iEffect)
    t:truthy("o veneno chegou no inimigo", gc.enemy:hasStatus("poison"))

    -- ========================================================================
    -- 7. ENFURECIDO: o inimigo cruzar os 30% de vida e um ACONTECIMENTO
    --    (era mudo: +50% de dano permanente sem toast, som, pill ou instante —
    --     acontecia em TODA batalha e mudava a conta de dano do jogador)
    -- ========================================================================
    local ge = TK.newRunGame("warrior")
    TK.pump(ge, 0.5)
    ge.enemy.health = 10                 -- 30% de 18 = 5.4: ainda acima
    ge.enemy.damage = 6; ge.enemy.baseDamage = 6
    ge.enemy:rollIntent()
    local intentBefore = ge.enemy.nextIntentDamage
    t:falsy("antes de ferir: nao esta enfurecido", ge.enemy:hasStatus("enraged"))

    local bigHit = {
        id = "tk_big", name = "Teste Pancada", type = "attack",
        cost = 0, attack = 8, defense = 0, effects = {},
    }
    table.insert(ge.hand, bigHit)
    ge.player.mana = 3
    ge:selectCard(bigHit)
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge:playSelectedCards()
    TK.pump(ge, 6.0)
    CombatBeats.stopTrace()

    t:truthy("inimigo ferido vira status REAL `enraged` (pill no HUD)",
        ge.enemy:hasStatus("enraged"))
    local iImpactE = atPrefix("card.impact.")
    local iRage = at("enemy.enraged")
    t:truthy("o enfurecimento tem BEAT proprio (" .. CombatBeats.traceString() .. ")",
        iRage ~= nil)
    t:truthy("o enfurecimento vem DEPOIS do golpe que o causou",
        iImpactE and iRage and iRage > iImpactE)
    t:eq("o dano dele subiu 50%", ge.enemy.damage, math.floor(6 * 1.5))
    -- INVARIANTE (CLAUDE.md 6): o golpe JA anunciado no HUD nao muda.
    t:eq("o intent ja telegrafado NAO fica mais forte",
        ge.enemy.nextIntentDamage, intentBefore)

    -- so anuncia na VIRADA: ferir de novo nao repete o acontecimento
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge.enemy:takeDamage(1)
    ge:announceEnrageIfPending(nil)
    TK.pump(ge, 1.0)
    CombatBeats.stopTrace()
    t:eq("enfurecer e evento de VIRADA, nao se repete a cada dano",
        countExact("enemy.enraged"), 0)

    -- checkpoint no turno do inimigo: fonte fora da carta nunca fica muda
    local ge2 = TK.newRunGame("warrior")
    TK.pump(ge2, 0.5)
    ge2.enemy.health = 4                 -- ja abaixo do limiar
    ge2.enemy:takeDamage(0)              -- cruza pelo caminho canonico
    t:truthy("dano de qualquer fonte marca o enfurecimento pendente",
        ge2.enemy._pendingEnrage == true)
    ge2.enemy.nextIntent = "defend"
    ge2.battleTurn = 1
    ge2.turn = "enemy"
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge2:enemyTurn()
    TK.pump(ge2, 4.0)
    CombatBeats.stopTrace()
    t:eq("checkpoint do turno anuncia o enfurecimento pendente",
        countExact("enemy.enraged"), 1)
    t:truthy("o checkpoint vem ANTES do inimigo agir",
        at("enemy.enraged") and at("enemy.defend")
        and at("enemy.enraged") < at("enemy.defend"))

    -- ========================================================================
    -- 8. CONTRATO: todo trigger de processTriggerEffect esta em TRIGGER_OF
    --    (esquecer de registrar = o trigger nunca mais dispara, em silencio)
    -- ========================================================================
    do
        local src = love.filesystem.read("src/systems/EffectSystem.lua")
        local missing = {}
        for ttype, trig in src:gmatch('t == "(%w+)" and triggerType == "(%w+)"') do
            if EffectSystem.TRIGGER_OF[ttype] ~= trig then
                missing[#missing + 1] = ttype .. "->" .. trig
            end
        end
        t:eq("TRIGGER_OF cobre todo trigger implementado ("
            .. table.concat(missing, ", ") .. ")", #missing, 0)
    end

    CombatBeats.clear()
    return t:done()
end

return M
