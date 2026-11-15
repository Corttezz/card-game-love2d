local TK = require("tools.testkit")
local Enemy = require("src.entities.Enemy")
local EnemyRoster = require("src.systems.EnemyRoster")
local ActSystem = require("src.systems.ActSystem")
local BM = require("src.systems.BossMechanics")
local Config = require("src.core.Config")

local M = {}

local ID = "eclipse_queen"
local LOCALES = { "pt_BR", "en", "es", "fr", "de" }
local PEAK_MAX = 59

local function spawnReal(g)
    local stats = ActSystem.getEnemyStats(Config.TotalActs, 8, "boss")
    local e = EnemyRoster.spawn(Enemy, ID, stats, Config.TotalActs)
    e.isBoss = true
    e.spriteId = ID
    if g then
        g.enemy = e
        g._deathHandled, g._deathStaged = false, false
        g.player.health = g.player.maxHealth
        g.player.armor = 0
        g.battleTurn = 1
    end
    return e
end

local function maxOfMove(e, g, moveId)
    e._phaseOpener = nil
    e._forcedNext = moveId
    e:rollIntent(g.player)
    local it = e:getIntent()
    return (it.perHit or 0) * math.max(1, it.hits or 1), it
end

local function numbers(t)
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    local e = spawnReal(g)
    t:eq("donzela: chefe do último ato", require("src.data.enemies").ROSTER[Config.TotalActs].boss[1], ID)
    t:eq("donzela: HP 1020", e.maxHealth, 1020)
    t:eq("donzela: golpe base 29 no Crepúsculo", e.damage, 29)
    local kit = e.kit
    t:eq("donzela: 3 viradas (4 fases)", #kit.phases, 3)
    local ids = {}
    for i, ph in ipairs(kit.phases) do ids[i] = ph.id end
    t:eq("donzela: fases na ordem", table.concat(ids, ","), "totality,corona,diamond_ring")
    t:eq("donzela: limiares 75/50/25", string.format("%.2f,%.2f,%.2f", kit.phases[1].at, kit.phases[2].at,
        kit.phases[3].at), "0.75,0.50,0.25")

    local p1 = maxOfMove(e, g, "sunset_ray")
    t:eq("Crepúsculo: Raio do Poente = 40 (1,4 x 29)", p1, 40)
    e:takeDamage(e.health - 765)
    t:eq("virada 1 exatamente em 765", e._phaseIdx, 1)
    t:eq("Totalidade: golpe base 30", e.damage, 30)
    t:truthy("Totalidade: regra nova = véu nos anúncios", e:veilSpec() ~= nil)
    for _ = 1, 3 do
        for _, step in ipairs(BM.turnEndSteps(e)) do BM.applyStep(e, step) end
    end
    local BossTokens = require("src.ui.BossTokens")
    BossTokens.reset()
    local okReact, errReact = pcall(BossTokens.react, g, { kind = "rune_gain", total = 1 })
    t:truthy("reação de estrela sem sync visual (simulador) não quebra: " .. tostring(errReact), okReact)
    local starPeak, starIt = maxOfMove(e, g, "star_fall")
    t:truthy("Totalidade: Queda Estelar cheia <= 59 (" .. starPeak .. ")", starPeak <= PEAK_MAX)
    t:truthy("Totalidade: Queda Estelar avisada mesmo sob véu", starIt.reveal)
    e:takeDamage(e.health - 510)
    t:eq("virada 2 exatamente em 510", e._phaseIdx, 2)
    t:eq("Coroa: golpe base 31", e.damage, 31)
    t:eq("Coroa: regra nova = ciclo de labaredas", BM.spec(e).kind, "moon")
    local okStep, errStep = pcall(BM.applyStep, e, { kind = "rune_gain", n = 1 })
    t:truthy("passo de estrela atrasado na virada para a Coroa é ignorado: " .. tostring(errStep), okStep)
    t:eq("passo atrasado não cria estrela", BM.stacks(e, "stars"), 0)
    e:rollIntent(g.player)
    BossTokens.reset()
    okReact, errReact = pcall(BossTokens.react, g, { kind = "moon", full = true, msg = "flare" })
    t:truthy("reação de labareda sem sync visual não quebra: " .. tostring(errReact), okReact)
    local flarePeak, flareIt = maxOfMove(e, g, "solar_embrace")
    t:truthy("Coroa: labareda cheia anunciada", flareIt.fullMoon)
    t:truthy("Coroa: pico da labareda <= 59 (" .. flarePeak .. ")", flarePeak <= PEAK_MAX)
    e:takeDamage(e.health - 255)
    t:eq("virada 3 exatamente em 255", e._phaseIdx, 3)
    t:eq("Anel de Diamante: golpe base 33", e.damage, 33)
    t:falsy("sem fúria genérica (a fase 4 é a fúria dela)", e:hasStatus("enraged"))
    e:rollIntent(g.player)
    t:eq("Anel de Diamante: abre com a carga", e:getIntent().id, "diamond_form")
    t:truthy("carga avisada", e:getIntent().reveal)
    e:onTurnEnd()
    e:rollIntent(g.player)
    local it = e:getIntent()
    local ring = (it.perHit or 0) * math.max(1, it.hits or 1)
    t:eq("Anel de Diamante vem logo depois da carga", it.id, "diamond_ring")
    t:eq("Anel de Diamante = 59", ring, PEAK_MAX)
    t:truthy("Anel de Diamante avisado (número visível)", it.reveal)
    local IV = require("src.systems.IntentVisibility")
    t:eq("pico sempre em visibilidade cheia", (IV.resolve(e, function() return 0.01 end)), "full")

    local worst = 0
    for _, ph in ipairs({ { moves = kit.moves, mul = 29 }, { moves = kit.phases[1].moves, mul = 30 },
        { moves = kit.phases[2].moves, mul = 31 }, { moves = kit.phases[3].moves, mul = 33 } }) do
        for _, m in ipairs(ph.moves) do
            local per = math.floor(ph.mul * (m.mult or m.damageMul or 0))
            local hits = m.hits or 1
            if m.runes then hits = 3 end
            local full = (ph.moves == kit.phases[2].moves) and kit.phases[2].mechanic.fullMul or 1
            worst = math.max(worst, math.floor(per * full) * hits)
        end
    end
    t:truthy("nenhum golpe da luta passa de ~59 (" .. worst .. ")", worst <= PEAK_MAX)
end

local function music(t)
    local MD = require("src.systems.MusicDirector")
    local LOOPS = require("src.data.music_loops")
    local run = { actNumber = Config.TotalActs, currentNode = { type = "boss", enemyId = ID } }
    local prev = MD.phaseProbe
    local codes = {}
    for ph = 0, 3 do
        MD.phaseProbe = function() return ph end
        codes[ph] = MD.bossTrack(run)
        local lp = LOOPS[codes[ph]]
        t:truthy("música: fase " .. (ph + 1) .. " tem loop próprio (" .. tostring(codes[ph]) .. ")", lp ~= nil)
    end
    MD.phaseProbe = prev
    t:eq("música: 4 códigos distintos", (codes[0] ~= codes[1] and codes[1] ~= codes[2] and codes[2] ~= codes[3]
        and codes[0] ~= codes[3]) and 4 or 0, 4)
    for ph = 1, 3 do
        local a, b = LOOPS[codes[ph - 1]], LOOPS[codes[ph]]
        t:truthy("música: região da fase " .. (ph + 1) .. " vem depois da anterior", b.loopStart >= a.loopStart)
        t:truthy("música: mesma faixa na fase " .. (ph + 1), MD.sameFamily(codes[ph - 1], codes[ph]))
        local pos = a.loopStart + 2.5 * a.bar + 0.7
        local start = MD.barSyncStart(codes[ph - 1], codes[ph], pos)
        local within = (start - b.loopStart) % b.bar
        local was = (pos - a.loopStart) % a.bar
        t:near("música: virada mantém o tempo no compasso (fase " .. (ph + 1) .. ")", within, was, 1e-6)
    end
    t:truthy("música: arquivo único instalado", love.filesystem.getInfo("audio/music/" .. MD.bossFile(ID)) ~= nil)
    local MR = require("src.systems.MusicReact")
    for ph = 0, 3 do
        t:eq("música: cues da fase " .. (ph + 1) .. " vêm do arquivo da donzela", MR.cueKeyFor(codes[ph]), ID)
    end

    local FA = require("tools.fake_audio")
    local prevAudio = _G.audioSystem
    FA.install()
    local ok, err = pcall(function()
        local audio = require("engine.AudioManager"):new()
        _G.audioSystem = audio
        MD.registerTracks(audio)
        local prevHall, prevIntro = MD.hallProbe, MD.introProbe
        MD.hallProbe = function() return true end
        MD.introProbe = function() return false end
        MD._current, MD._lastWanted = nil, nil
        local ph = 0
        MD.phaseProbe = function() return ph end
        MD.apply("playing", run, "boss")
        t:eq("música (luta): Crepúsculo toca", audio.currentMusic, codes[0])
        for p = 1, 3 do
            ph = p
            MD.apply("playing", run, "boss")
            t:eq("música (luta): virada " .. p .. " troca a região", audio.currentMusic, codes[p])
            local pos = audio.sources[codes[p]].template:tell("seconds")
            local lp = LOOPS[codes[p]]
            t:truthy(string.format("música (luta): fase %d começa dentro da própria região (%.2f)", p + 1, pos),
                pos >= lp.loopStart - 0.01 and pos < lp.loopStart + lp.bar + 0.01)
        end
        audio:stopMusic()
        MD.phaseProbe = prev
        MD.hallProbe, MD.introProbe = prevHall, prevIntro
        MD._current, MD._lastWanted = nil, nil
    end)
    FA.uninstall()
    _G.audioSystem = prevAudio
    t:truthy("música (luta) sem erro: " .. tostring(err), ok)
end

local function visuals(t)
    local base = "assets/sprites/characters/enemies/" .. ID .. "/"
    for k = 1, 4 do
        local dir = base .. (k == 1 and "" or ("fase" .. k .. "/"))
        t:truthy("pele da fase " .. k .. ": south.png", love.filesystem.getInfo(dir .. "south.png"))
        for _, clip in ipairs({ "idle", "attack", "attack_strong", "hurt", "death" }) do
            t:truthy("pele da fase " .. k .. ": clipe " .. clip,
                love.filesystem.getInfo(dir .. "animations/" .. clip .. "/south/0.png"))
        end
        if k > 1 then
            local clip = "t" .. (k - 1) .. k
            t:truthy("pele da fase " .. k .. ": transição " .. clip,
                love.filesystem.getInfo(dir .. "animations/" .. clip .. "/south/0.png"))
        end
    end
    local IFX = require("src.ui.InteriorFX")
    local cfg = IFX.HALLS[6]
    t:eq("arena: 3 estados de fase além da base", #cfg.phaseArt, 3)
    for _, p in ipairs(cfg.phaseArt) do t:truthy("arena: " .. p, love.filesystem.getInfo(p)) end
    t:truthy("arena: alvorada", love.filesystem.getInfo(cfg.dawnArt))
    local w = IFX.phaseWeights(1 / 3)
    t:near("arena: Totalidade cheia na fase 2", w[1], 1, 1e-6)
    t:near("arena: Coroa ainda apagada na fase 2", w[2], 0, 1e-6)
    local BC = require("src.ui.BossCinematic")
    t:eq("pele: Crepúsculo usa a base", BC.queenSkinFor(0), nil)
    t:eq("pele: Anel de Diamante usa fase4", BC.queenSkinFor(3), "fase4")
end

local function deathToVictory(t)
    local BC = require("src.ui.BossCinematic")
    local Data = require("src.data.boss_cinematics")
    local savedGS = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    BC.reset()
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.3)
    local run = g.runManager.currentRun
    local MapManager = require("src.systems.MapManager")
    run.actNumber = Config.TotalActs
    run.floorInAct = MapManager.FLOORS_PER_ACT
    run.currentNode = { type = "boss", enemyId = ID }
    local e = spawnReal(g)
    e._phaseIdx = 3
    e.health = 0
    g._deathHandled = true
    local DT = 1 / 60
    BC.update(DT, g, { inHall = true })
    t:truthy("morte: cinemática da donzela começou", BC.isActive() and BC.phase() == "death")
    t:truthy("morte: segura a tela final enquanto toca", BC.holdsEnd())
    local limit = BC.duration(require("src.ui.BossTrophy").withTrophy(Data[ID].death, g, false)) + 3
    local el = 0
    while BC.isActive() and el < limit do
        BC.update(DT, g, { inHall = true })
        el = el + DT
    end
    t:falsy("morte: cinemática terminou", BC.isActive())
    t:near("morte: alvorada completa", BC.eclipseDawn(), 1, 1e-3)
    t:falsy("morte: libera a tela final", BC.holdsEnd())
    t:truthy("fim: vitória da campanha", g:isPhaseCleared() and g:checkVictory())
    t:eq("fim: estado victory", g.gameState, "victory")
    BC.reset()
    _G.gameSettings = savedGS
end

local function locales(t)
    local I18n = require("src.i18n.I18n")
    local prev = I18n.getLocale and I18n.getLocale() or nil
    local names = {}
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc)
        local nm = I18n.t("end_screen.enemy." .. ID, nil, "")
        names[#names + 1] = nm
        t:truthy(loc .. ": nome da donzela", nm ~= "" and nm ~= "end_screen.enemy." .. ID)
        t:falsy(loc .. ": sem nome antigo de rainha", nm:lower():find("eclipse queen", 1, true)
            or nm:lower():find("rainha do eclipse", 1, true))
        for _, k in ipairs({ "enemy_kit.phases.totality.name", "enemy_kit.phases.corona.name",
            "enemy_kit.phases.diamond_ring.name", "enemy_kit.moves.diamond_ring.name", "enemy_kit.moves.star_fall.name" }) do
            local v = I18n.t(k, nil, "")
            t:truthy(loc .. ": " .. k, v ~= "" and v ~= k)
        end
    end
    t:eq("nome em pt_BR", names[1], "Donzela do Astrolábio")
    t:eq("nome em en", names[2], "Astrolabe Maiden")
    if prev then I18n.setLocale(prev) end
end

function M.run()
    local t = TK.new("astrolabe_maiden")
    TK.bootstrap()
    numbers(t)
    music(t)
    visuals(t)
    deathToVictory(t)
    locales(t)
    return TK.verdict(t.fail == 0)
end

return M
