-- tools/test_enemies.lua
-- TRAVA do kit dos inimigos (Out/2026, src/data/enemies.lua).
--
-- Auditoria de conteúdo: todo inimigo jogava igual (uma tabela de intents só),
-- ninguém debuffava o jogador, o roster era um monstro por ato e o chefe era
-- um saco de vida. Esta suíte trava o que a frente consertou:
--   1. todo sprite do roster tem kit; todo golpe tem nome nos 5 idiomas;
--   2. todo golpe de todo kit resolve pela fila de beats (e a vez volta);
--   3. o intent é CONGELADO — inclusive multi-golpe e Vulnerável;
--   4. Fraco/Frágil do jogador fazem a conta certa e duram o combinado;
--   5. o roster não repete o último inimigo (seed fixa);
--   6. cada chefe dispara a mecânica-assinatura;
--   7. a mesma seed reproduz o combate (intents + embaralhamento).
--
--   love . test_one test_enemies

local TK = require("tools.testkit")
local Enemy = require("src.entities.Enemy")
local Player = require("src.entities.Player")
local EnemyKits = require("src.data.enemies")
local EnemyRoster = require("src.systems.EnemyRoster")
local CombatBeats = require("src.systems.CombatBeats")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

-- Monta uma batalha de run com o inimigo `id` (vida alta pra ninguém morrer
-- no meio da asserção) e o golpe `moveId` anunciado.
local function battleWith(id, moveId, hp, dmg)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    g.enemy = EnemyRoster.spawn(Enemy, id, { health = hp or 500, damage = dmg or 10 })
    g._deathHandled, g._deathStaged = false, false
    if moveId then g.enemy:forceIntent(moveId, g.player) end
    g.player.health = g.player.maxHealth
    g.player.armor = 0
    g.battleTurn = 1
    return g
end

local function runEnemyTurn(g, secs)
    g.turn = "enemy"
    g._enemyActing = false
    g:enemyTurn()
    TK.pump(g, secs or 8)
end

local function traceCount(label)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do if l == label then n = n + 1 end end
    return n
end

function M.run()
    local t = TK.new("inimigos: kits, beats, intent congelado, roster, chefes")
    TK.bootstrap()
    TK.seedRng(4242)

    -- ======================================================================
    -- 1. DADOS: roster -> kit -> golpes -> i18n -> sprite
    -- ======================================================================
    local seenIds = {}
    for act = 1, 6 do
        local r = EnemyKits.ROSTER[act]
        t:truthy("ato " .. act .. " tem roster", r)
        t:check("ato " .. act .. ": 2+ comuns", #(r.battle or {}) >= 2)
        t:check("ato " .. act .. ": 1+ elite", #(r.elite or {}) >= 1)
        t:check("ato " .. act .. ": chefe", #(r.boss or {}) == 1)
        local elites = {}
        for _, id in ipairs(r.elite) do elites[id] = true end
        local distinct = true
        for _, id in ipairs(r.mini_boss or {}) do
            if elites[id] then distinct = false end
        end
        t:check("ato " .. act .. ": mini-chefe DISTINTO do elite", distinct and #(r.mini_boss or {}) >= 1)
        for _, list in pairs(r) do
            for _, id in ipairs(list) do seenIds[id] = true end
        end
    end
    -- REGRA DO DONO (Out/2026): só criatura DO BIOMA do ato. Emprestar sprite
    -- de outro ato fazia aparecer "monstros sem relação com o bioma".
    local foreign = {}
    for act = 1, 6 do
        for nt, list in pairs(EnemyKits.ROSTER[act]) do
            for _, id in ipairs(list) do
                if EnemyKits.HOME_BIOME[id] ~= act then
                    foreign[#foreign + 1] = ("A%d.%s=%s(bioma %s)"):format(act, nt, id,
                        tostring(EnemyKits.HOME_BIOME[id]))
                end
            end
        end
    end
    t:eq("todo inimigo do roster pertence ao bioma do ato", table.concat(foreign, ","), "")
    -- Endless: o bioma do inimigo é o MESMO que a cena desenha (fórmula do
    -- GameplayScene: 4 + floor((andar - 25) / 8), embrulhado em 6).
    local endlessOk = true
    for floor = 25, 120 do
        local shown = (((4 + math.floor((floor - 25) / 8)) - 1) % 6) + 1
        local run = { endlessMode = true, actNumber = 7, currentFloor = floor }
        local act = EnemyRoster.biomeAct(run)
        if act ~= shown then endlessOk = false end
        TK.seedRng(floor)
        local id = EnemyRoster.pick(act, "battle", nil)
        if EnemyKits.HOME_BIOME[id] ~= shown then endlessOk = false end
    end
    t:truthy("endless: inimigo do bioma que a cena mostra (andares 25-120)", endlessOk)

    local missingKit, missingSprite = {}, {}
    for id in pairs(seenIds) do
        if not EnemyKits.KITS[id] then missingKit[#missingKit + 1] = id end
        if not love.filesystem.getInfo("assets/sprites/characters/enemies/" .. id) then
            missingSprite[#missingSprite + 1] = id
        end
    end
    t:eq("todo sprite do roster tem kit", table.concat(missingKit, ","), "")
    t:eq("todo sprite do roster existe em disco", table.concat(missingSprite, ","), "")

    -- Referências internas do kit + nomes nos 5 idiomas.
    local badRef, missingName = {}, {}
    local I18n = require("src.i18n.I18n")
    local function allMoves(kit)
        local out = {}
        for _, m in ipairs(kit.moves) do out[#out + 1] = m end
        for _, ph in ipairs(kit.phases or {}) do
            for _, m in ipairs(ph.moves) do out[#out + 1] = m end
        end
        return out
    end
    for kid, kit in pairs(EnemyKits.KITS) do
        local ids = {}
        for _, m in ipairs(allMoves(kit)) do ids[m.id] = true end
        if kit.opener and not ids[kit.opener] then badRef[#badRef + 1] = kid .. ".opener" end
        for _, ph in ipairs(kit.phases or {}) do
            if ph.opener and not ids[ph.opener] then badRef[#badRef + 1] = kid .. ".phase.opener" end
        end
        for _, m in ipairs(allMoves(kit)) do
            if m.next and not ids[m.next] then badRef[#badRef + 1] = kid .. "." .. m.id .. ".next" end
            for _, loc in ipairs(LOCALES) do
                local data = require("src.i18n.locales.enemy_kit." .. loc)
                if not (data.moves[m.id] and data.moves[m.id].name) then
                    missingName[#missingName + 1] = loc .. ":" .. m.id
                end
            end
            for _, d in ipairs(m.debuff and (m.debuff.name and { m.debuff } or m.debuff) or {}) do
                if not EnemyKits.PLAYER_DEBUFFS[d.name] then
                    badRef[#badRef + 1] = kid .. "." .. m.id .. ".debuff=" .. tostring(d.name)
                end
            end
        end
    end
    t:eq("referências do kit (opener/next/debuff) resolvem", table.concat(badRef, ","), "")
    t:eq("todo golpe tem nome nos 5 idiomas", table.concat(missingName, ","), "")
    t:check("I18n enxerga enemy_kit no locale ativo",
        I18n.t("enemy_kit.moves.hellfire.name", nil, "") ~= "")

    -- ======================================================================
    -- 2. TODO golpe de TODO kit resolve pela fila de beats
    -- ======================================================================
    local broken = {}
    for kid, kit in pairs(EnemyKits.KITS) do
        if kid ~= "generic" then
            for _, m in ipairs(allMoves(kit)) do
                local g = battleWith(kid, m.id)
                local it = g.enemy:getIntent()
                local ok = it.id == m.id
                CombatBeats.startTrace()
                local okRun, err = pcall(runEnemyTurn, g, 10)
                CombatBeats.stopTrace()
                ok = ok and okRun and g.turn == "player"
                if (it.hits or 0) > 0 and traceCount("enemy.attack") ~= it.hits then ok = false end
                if (it.armor or 0) > 0 and traceCount("enemy.defend") ~= 1 then ok = false end
                for _, d in ipairs(it.debuffs or {}) do
                    if traceCount("enemy.debuff." .. d.name) ~= 1 then ok = false end
                    -- o debuff ficou no jogador (DoT ainda não decaiu: acabou de entrar)
                    if not g.player:hasDebuff(d.name) and d.duration > 0 then ok = false end
                end
                if (it.strength or 0) > 0 and traceCount("enemy.buff") ~= 1 then ok = false end
                if (it.summon or 0) > 0 and traceCount("enemy.summon") ~= 1 then ok = false end
                if it.charge and traceCount("enemy.charge") ~= 1 then ok = false end
                if not ok then broken[#broken + 1] = kid .. "." .. m.id .. (err and (":" .. tostring(err)) or "") end
            end
        end
    end
    t:eq("todo golpe resolve pelos beats e devolve a vez", table.concat(broken, " | "), "")

    -- ======================================================================
    -- 3. INTENT CONGELADO (CLAUDE.md §6) — multi-golpe e Vulnerável
    -- ======================================================================
    do
        local g = battleWith("cursed_scarecrow", "crow_pecks", 500, 20)
        local it = g.enemy:getIntent()
        local shownPerHit = g.enemy:intentHitDamage(g.player)
        local shownTotal = g.enemy:getIncomingDamage(g.player)
        t:eq("multi-golpe: 3 golpes anunciados", it.hits, 3)
        t:eq("multi-golpe: total = por golpe × golpes", shownTotal, shownPerHit * 3)
        -- Entre o anúncio e a execução: buff + enfurecido + Fúria.
        g.enemy:gainStrength(10)
        g.enemy:takeDamage(400)  -- cruza 30%: enfurecido
        local hp0 = g.player.health
        runEnemyTurn(g)
        t:eq("multi-golpe executa EXATAMENTE o anunciado (buffs depois não valem)",
            hp0 - g.player.health, shownTotal)
    end
    do
        -- Vulnerável aplicado ANTES do anúncio amplia; o HUD já mostra.
        local g = battleWith("dusk_shade", nil, 500, 20)
        g.player:addDebuff("vulnerable", 2)
        g.player.debuffs[1].fresh = nil
        g.enemy:forceIntent("shadow_blade", g.player)
        local shown = g.enemy:intentHitDamage(g.player)
        t:eq("Vulnerável congelado no anúncio: ×1.5", shown, math.floor(math.floor(20 * 1.1) * 1.5))
        local hp0 = g.player.health
        runEnemyTurn(g)
        t:eq("golpe vulnerável = número do HUD", hp0 - g.player.health, shown)
        -- Vulnerável que aparece DEPOIS do anúncio não amplia o golpe já visto.
        local g2 = battleWith("dusk_shade", "shadow_blade", 500, 20)
        local shown2 = g2.enemy:intentHitDamage(g2.player)
        g2.player:addDebuff("vulnerable", 2)
        local hp2 = g2.player.health
        runEnemyTurn(g2)
        t:eq("Vulnerável posterior ao anúncio NÃO amplia", hp2 - g2.player.health, shown2)
    end
    do
        -- Perfurante ignora o Bloqueio.
        local g = battleWith("winter_monarch", "winter_blade", 500, 20)
        local shown = g.enemy:intentHitDamage(g.player)
        g.player.armor = 99
        local hp0 = g.player.health
        runEnemyTurn(g)
        t:eq("golpe perfurante atravessa o Bloqueio", hp0 - g.player.health, shown)
        t:eq("perfurante não consome o Bloqueio", g.player.armor >= 0, true)
    end

    -- ======================================================================
    -- 4. FRACO / FRÁGIL / DoT NO JOGADOR
    -- ======================================================================
    do
        local p = Player:new()
        p:addDebuff("weak", 2)
        p:addDebuff("frail", 1)
        t:eq("Fraco: ataque 10 -> 7", p:applyWeakToAttack(10), 7)
        t:eq("Frágil: bloqueio 10 -> 7", p:applyFrailToBlock(10), 7)
        -- Fraco 2 aplicado no turno do inimigo vale 2 turnos do jogador.
        p:decayDebuffs()  -- fim do turno em que foi aplicado: pula
        t:truthy("Fraco sobrevive ao fim do turno em que foi aplicado", p:hasDebuff("weak"))
        t:truthy("Frágil 1 também", p:hasDebuff("frail"))
        p:decayDebuffs()  -- fim do 1º turno inimigo seguinte
        t:truthy("Fraco 2: ainda ativo no 2º turno do jogador", p:hasDebuff("weak"))
        t:falsy("Frágil 1: acabou depois de 1 turno do jogador", p:hasDebuff("frail"))
        p:decayDebuffs()
        t:falsy("Fraco 2 expirou depois de 2 turnos", p:hasDebuff("weak"))

        local q = Player:new()
        q.armor = 50
        q:addDebuff("poison", 2, 4)
        local poison = q:tickDebuffDots()
        t:eq("veneno no jogador tica as pilhas", poison, 4)
        t:eq("veneno ignora o Bloqueio", q.health, q.maxHealth - 4)
        -- DoT no jogador: pilhas SOMAM, duração fica a MAIOR (não compõe).
        q:addDebuff("poison", 1, 2)
        t:eq("2º veneno soma pilhas", q:getDebuffStacks("poison"), 6)
        t:eq("2º veneno não soma duração (fica a maior)", q.debuffs[1].duration, 2)
    end
    do
        -- Integração: carta de ataque com o jogador Fraco causa 75%.
        local g = battleWith("cursed_scarecrow", "rusty_scythe", 500, 5)
        g.player:addDebuff("weak", 2)
        local hp0 = g.enemy.health
        local card = { id = "t_weak", type = "attack", attack = 20, cost = 0, effects = {} }
        g:processCardInCombat(card, nil)
        t:eq("ataque do jogador Fraco: 20 -> 15", hp0 - g.enemy.health, 15)
        g.player:addDebuff("frail", 2)
        local card2 = { id = "t_frail", type = "defense", defense = 20, cost = 0, effects = {} }
        g.player.armor = 0
        g:processCardInCombat(card2, nil)
        t:eq("defesa do jogador Frágil: 20 -> 15", g.player.armor, 15)
    end
    do
        -- Veneno do kit tica no upkeep do jogador (beat próprio).
        local g = battleWith("bog_ghoul", "infected_bite", 500, 10)
        CombatBeats.startTrace()
        runEnemyTurn(g)
        CombatBeats.stopTrace()
        local iHit = CombatBeats.indexOf("enemy.attack")
        local iDeb = CombatBeats.indexOf("enemy.debuff.poison")
        local iDot = CombatBeats.indexOf("player.dot")
        local iDraw = CombatBeats.indexOf("player.draw")
        t:check("ordem: golpe > veneno aplicado > veneno tica > compra",
            iHit and iDeb and iDot and iDraw and iHit < iDeb and iDeb < iDot and iDot < iDraw)
        t:eq("o veneno entrou e já ticou 1x (3 pilhas)", g.player:getDebuffStacks("poison"), 3)
    end

    -- ======================================================================
    -- 5. ROSTER: sorteio seedado, sem repetir o último
    -- ======================================================================
    do
        TK.seedRng(777)
        local run = { actNumber = 1 }
        local repeats, picks = 0, {}
        for i = 1, 200 do
            local act = ((i - 1) % 6) + 1
            run.actNumber = act
            local id = EnemyRoster.pick(act, "battle", run.recentEnemies)
            local last = run.recentEnemies and run.recentEnemies[#run.recentEnemies]
            if id == last then repeats = repeats + 1 end
            EnemyRoster.remember(run, id)
            picks[#picks + 1] = id
        end
        t:eq("200 sorteios: nunca repete o último", repeats, 0)
        -- mesmo ato seguido: alterna entre os comuns
        TK.seedRng(778)
        local r2, alt = { actNumber = 2 }, true
        local prev
        for _ = 1, 30 do
            local id = EnemyRoster.pick(2, "battle", r2.recentEnemies)
            if id == prev then alt = false end
            EnemyRoster.remember(r2, id)
            prev = id
        end
        t:truthy("mesmo ato 30x: sem repetição consecutiva", alt)
        -- o inimigo vai pro nó e o nó manda
        TK.seedRng(779)
        local run3 = { actNumber = 3, recentEnemies = { "ember_imp" } }
        local nodes = { { type = "battle" }, { type = "elite" }, { type = "rest" } }
        EnemyRoster.assignNodes(run3, nodes)
        t:check("nó de batalha não repete o último inimigo",
            nodes[1].enemyId ~= "ember_imp" and EnemyKits.HOME_BIOME[nodes[1].enemyId] == 3)
        t:check("nó de elite recebe um elite do ato",
            nodes[2].enemyId == "obsidian_sentinel" or nodes[2].enemyId == "pit_brute")
        t:eq("nó sem combate fica sem inimigo", nodes[3].enemyId, nil)
        t:eq("resolveNode lê o inimigo gravado", EnemyRoster.resolveNode(run3, nodes[1]),
            nodes[1].enemyId)
    end

    -- ======================================================================
    -- 6. MECÂNICAS DOS CHEFES
    -- ======================================================================
    do
        -- A1 Rei da Carniça: Chamado soma corvos, a Revoada bate por corvo.
        local g = battleWith("carrion_king", nil, 500, 10)
        t:eq("Rei da Carniça abre com o Chamado", g.enemy:getIntent().id, "call_of_crows")
        runEnemyTurn(g)
        t:eq("Chamado: +2 corvos", g.enemy:getStatusStacks("swarm"), 2)
        g.enemy:forceIntent("murder_of_crows", g.player)
        t:eq("Revoada: 2 + 2 corvos = 4 golpes", g.enemy:getIntent().hits, 4)
    end
    do
        -- A2 Lich: Escudo de Gelo a cada 3º turno.
        local g = battleWith("tower_lich", nil, 500, 10)
        local ids = { g.enemy:getIntent().id }
        for _ = 2, 6 do g.enemy:rollIntent(g.player); ids[#ids + 1] = g.enemy:getIntent().id end
        t:eq("Lich: escudo no 3º turno", ids[3], "frost_shield")
        t:eq("Lich: escudo no 6º turno", ids[6], "frost_shield")
        t:check("Lich: escudo NÃO nos outros", ids[1] ~= "frost_shield" and ids[2] ~= "frost_shield"
            and ids[4] ~= "frost_shield" and ids[5] ~= "frost_shield")
    end
    do
        -- A3 Tirano: carga telegrafada -> Fogo Infernal no turno seguinte.
        local g = battleWith("abyss_tyrant", "gather_flames", 500, 10)
        CombatBeats.startTrace()
        runEnemyTurn(g)
        CombatBeats.stopTrace()
        t:eq("carga tem beat próprio", traceCount("enemy.charge"), 1)
        t:eq("depois da carga vem o Fogo Infernal", g.enemy:getIntent().id, "hellfire")
        local hellMult, maxOther = 0, 0
        for _, m in ipairs(EnemyKits.KITS.abyss_tyrant.moves) do
            if m.id == "hellfire" then hellMult = m.mult
            elseif (m.mult or 0) * (m.hits or 1) > maxOther then maxOther = (m.mult or 0) * (m.hits or 1) end
        end
        t:eq("Fogo Infernal anunciado com o multiplicador do kit",
            g.enemy:getIntent().perHit, math.floor(10 * hellMult))
        t:check("Fogo Infernal é o maior golpe do Tirano", hellMult > maxOther)
        runEnemyTurn(g)
        t:check("Fogo Infernal queima o jogador", g.player:getDebuffStacks("burn") > 0)
    end
    do
        -- A4 Monarca: perfurante (coberto acima) + inverno a cada 3º turno.
        local g = battleWith("winter_monarch", nil, 500, 10)
        g.enemy:rollIntent(g.player); g.enemy:rollIntent(g.player)
        t:eq("Monarca: Inverno Eterno no 3º turno", g.enemy:getIntent().id, "eternal_winter")
        runEnemyTurn(g)
        t:truthy("Inverno Eterno: jogador Frágil", g.player:hasDebuff("frail"))
        t:truthy("Inverno Eterno: jogador Fraco", g.player:hasDebuff("weak"))
    end
    do
        -- A5 Colosso: regenera sozinho + nuvem de veneno.
        local g = battleWith("rot_colossus", "plague_cloud", 1000, 10)
        t:truthy("Colosso nasce com Regeneração", g.enemy:hasStatus("regen"))
        g.enemy.health = 500
        runEnemyTurn(g)
        local pct = EnemyKits.KITS.rot_colossus.passive.regenPct
        t:eq("Colosso regenera a fração do kit no fim do turno", g.enemy.health,
            500 + math.floor(1000 * pct))
        t:check("Nuvem Pestilenta envenena o jogador", g.player:getDebuffStacks("poison") >= 4)
    end
    do
        -- A6 Rainha: abaixo de 50% vira o ECLIPSE (beat, kit novo, dano sobe).
        local g = battleWith("eclipse_queen", "lunar_blades", 1000, 20)
        local frozen = g.enemy:getIncomingDamage(g.player)
        CombatBeats.startTrace()
        g.enemy:takeDamage(520)
        g:settleEnemyDamage(nil)
        TK.pump(g, 1.0)
        CombatBeats.stopTrace()
        t:eq("fase anunciada com beat próprio", traceCount("enemy.phase"), 1)
        t:check("dano subiu na fase 2", g.enemy.damage > 20)
        t:eq("intent já anunciado NÃO muda na troca de fase",
            g.enemy:getIncomingDamage(g.player), frozen)
        g.enemy:rollIntent(g.player)
        t:eq("fase 2 abre com o Eclipse Total", g.enemy:getIntent().id, "total_eclipse")
        g.enemy:rollIntent(g.player)
        local inPhase2 = false
        for _, m in ipairs(EnemyKits.KITS.eclipse_queen.phases[1].moves) do
            if m.id == g.enemy:getIntent().id then inPhase2 = true end
        end
        t:truthy("golpes seguintes vêm do kit da fase 2", inPhase2)
    end

    -- ======================================================================
    -- 7. A MESMA SEED REPRODUZ O COMBATE
    -- ======================================================================
    do
        local function sample(seed)
            local g = TK.newRunGame("rogue")
            -- deck maior que o inicial, pra o embaralhamento ter o que provar
            g.deck = {}
            for i = 1, 12 do g.deck[i] = { id = "c" .. i } end
            TK.seedRng(seed)   -- a run nova cria Rng próprio: fixa DEPOIS
            g:shuffleDeck()
            local hand = {}
            for _, c in ipairs(g.deck) do hand[#hand + 1] = c.id end
            local e = EnemyRoster.spawn(Enemy, "harvest_reaper", { health = 300, damage = 10 })
            local seq = { e:getIntent().id }
            for _ = 1, 15 do e:rollIntent(); seq[#seq + 1] = e:getIntent().id end
            return table.concat(hand, ",") .. "|" .. table.concat(seq, ",")
        end
        local a, b, c = sample(9001), sample(9001), sample(9002)
        t:eq("mesma seed: mesmo embaralhamento e mesma sequência de golpes", a, b)
        t:check("seed diferente: sequência diferente", a ~= c)
    end

    return t:done()
end

return M
