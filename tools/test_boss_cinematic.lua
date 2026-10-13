-- tools/test_boss_cinematic.lua
-- TRAVA da cinemática do chefe (src/ui/BossCinematic + src/data/boss_cinematics).
--
-- O que ela fixa:
--   * roteiro válido (kinds conhecidos, dur numérico) em todo chefe com dado;
--   * ENTRADA: chefe escondido até POUSAR, HUD escondido até o FIM, duração =
--     soma nominal dos passos, escuro zerado e relógio do inimigo normal no fim;
--   * PULAR: ignorado antes de SKIP_AFTER, salta pro estado final depois;
--   * reducedMotion usa o roteiro curto;
--   * MORTE: detectada pelo update (chefe no SALÃO com _deathHandled), segura
--     espólios (holdsEnd), câmera lenta no EnemyRenderer e volta a 1; não
--     reencena a mesma morte; mini-boss NA ESTRADA (isBoss sem salão) não
--     vira cinemática; chefe sem roteiro não inicia nada;
--   * CENA: a porta (GameplayScene._onBossEntered) inicia a entrada e a cena
--     deixa de estar quieta (tutorial espera); o CONTINUAR (ResumeFlow.apply)
--     abre o salão SEM entrada; setGame zera tudo;
--   * i18n: nome + epíteto + dica de pular nos 5 locales.
--
--   love . test_one test_boss_cinematic

local TK = require("tools.testkit")

local M = {}

local function fakeBoss(id)
    return {
        enemy = { spriteId = id, isBoss = true, isAlive = function() return true end },
        _deathHandled = false,
    }
end

function M.run()
    local t = TK.new("boss_cinematic")
    TK.bootstrap()

    local BC = require("src.ui.BossCinematic")
    local Data = require("src.data.boss_cinematics")
    local ER = require("src.ui.EnemyRenderer")
    local GS = require("src.scenes.GameplayScene")
    local ResumeFlow = require("src.systems.ResumeFlow")

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    local DT = 1 / 60
    local function pump(secs, game, ctx)
        for _ = 1, math.floor(secs / DT + 0.5) do
            BC.update(DT, game, ctx or { inHall = true })
        end
    end
    local function runUntilDone(game, limit)
        local el = 0
        while BC.isActive() and el < limit do
            BC.update(DT, game, { inHall = true })
            el = el + DT
        end
        return el
    end
    -- palco falso (o GameplayScene passa um por frame; aqui a geometria do
    -- rasante só precisa de números coerentes)
    local stage = {
        cx = 960, cy = 840,
        bbox = { cx = 960, topY = 500, bottomY = 840, width = 300, height = 340 },
        foot = { drawX = 800, drawY = 480, scale = 2.6 },
        hall = 1, w = 1920, h = 1080, tr = { scale = 4.8, ox = 0, oy = -74 },
    }

    -- ===== 1. dados =====
    local nData = 0
    for id in pairs(Data) do
        nData = nData + 1
        local errs = BC.validate(id)
        t:eq("roteiro valido: " .. id .. " " .. table.concat(errs, "; "), #errs, 0)
    end
    t:truthy("ha pelo menos um chefe com roteiro", nData >= 1)
    t:truthy("carrion_king tem entrada", BC.hasIntro("carrion_king"))
    t:truthy("carrion_king tem morte", BC.hasDeath("carrion_king"))
    t:eq("kind desconhecido e apontado",
        #BC.validate("__nope__") > 0 and true or false, true)

    -- ===== 2. entrada =====
    BC.reset()
    local g = fakeBoss("carrion_king")
    t:truthy("startIntro aceita chefe com roteiro", BC.startIntro(g))
    t:truthy("entrada ativa", BC.isActive())
    t:eq("fase = intro", BC.phase(), "intro")
    t:truthy("chefe escondido no comeco", BC.hidesBoss())
    t:truthy("HUD escondido no comeco", BC.hidesHud())
    t:truthy("mao escondida no comeco", BC.hidesHand())
    t:truthy("salao escuro no comeco", BC.darkness() > 0.5)
    t:truthy("entrada trava a entrada do jogador", BC.lockInput())
    t:falsy("entrada nao segura espolios", BC.holdsEnd())
    BC.setStage(stage)
    local nominal = BC.duration(Data.carrion_king.intro)
    local tLand, tHud, el = nil, nil, 0
    local sawMist, sawZoom, sawHit = false, false, false
    while BC.isActive() and el < nominal + 2 do
        BC.update(DT, g, { inHall = true })
        el = el + DT
        if not tLand and not BC.hidesBoss() then tLand = el end
        if not tHud and not BC.hidesHud() then tHud = el end
        local d = BC._debug()
        if d.mist and d.mist.a > 0.5 then sawMist = true end
        if d.hit then sawHit = true end
        if BC.worldZoom() then sawZoom = true end
    end
    t:truthy("nevoa colorida sobe durante os olhos/rasantes", sawMist)
    t:truthy("pouso dispara o efeito de tela", sawHit)
    t:truthy("pouso dispara o soco de zoom do mundo", sawZoom)
    t:falsy("efeito de tela acabou no fim", BC._debug().hit ~= nil)
    t:falsy("zoom acabou no fim", BC.worldZoom() ~= nil)
    t:falsy("nevoa foi embora no fim", BC._debug().mist ~= nil)
    t:falsy("entrada termina sozinha", BC.isActive())
    t:truthy("chefe pousa ANTES do fim", tLand ~= nil and tLand < nominal)
    t:truthy("chefe fica escondido por um bom tempo (olhos + rasantes)", tLand ~= nil and tLand > 2.0)
    t:truthy("HUD so DEPOIS do pouso", tHud ~= nil and tLand ~= nil and tHud > tLand)
    t:near("duracao = soma nominal dos passos", el, nominal, 0.1)
    t:near("escuro zerado no fim", BC.darkness(), 0, 1e-3)
    t:eq("relogio do inimigo normal", ER.getTimeScale(), 1)
    t:falsy("entrada nao segura espolios (fim)", BC.holdsEnd())

    -- ===== 3. pular =====
    BC.reset()
    BC.startIntro(g)
    BC.setStage(stage)
    pump(BC.SKIP_AFTER * 0.5, g)
    t:falsy("skip antes de SKIP_AFTER e ignorado", BC.skip())
    t:truthy("continua ativa", BC.isActive())
    pump(BC.SKIP_AFTER * 0.6, g)
    t:truthy("skip depois de SKIP_AFTER", BC.skip())
    t:falsy("skip encerra", BC.isActive())
    t:falsy("skip mostra o chefe", BC.hidesBoss())
    t:falsy("skip mostra o HUD", BC.hidesHud())
    t:near("skip zera o escuro", BC.darkness(), 0, 1e-3)

    -- ===== 4. reducedMotion =====
    _G.gameSettings.reducedMotion = true
    BC.reset()
    BC.startIntro(g)
    BC.setStage(stage)
    local sawZoomR = false
    local elR = 0
    while BC.isActive() and elR < 20 do
        BC.update(DT, g, { inHall = true })
        elR = elR + DT
        if BC.worldZoom() then sawZoomR = true end
    end
    t:falsy("reducedMotion: sem soco de zoom", sawZoomR)
    t:truthy("reducedMotion: entrada curta (" .. string.format("%.2f", elR) .. "s)",
        elR < nominal * 0.7)
    t:near("reducedMotion: duracao = roteiro curto", elR,
        BC.duration(Data.carrion_king.introReduced), 0.1)
    _G.gameSettings.reducedMotion = false

    -- ===== 5. morte =====
    BC.reset()
    BC.setStage(stage)
    local gd = fakeBoss("carrion_king")
    gd._deathHandled = true
    BC.update(DT, gd, { inHall = true })
    t:truthy("morte detectada pelo update", BC.isActive())
    t:eq("fase = death", BC.phase(), "death")
    t:truthy("morte SEGURA espolios/vitoria", BC.holdsEnd())
    t:falsy("morte nao esconde o chefe (o corpo e o que se ve)", BC.hidesBoss())
    t:falsy("morte mantem o HUD de vida", BC.hidesHud())
    t:truthy("morte esconde mao/botoes/coringas", BC.hidesHand())
    pump(0.3, gd)
    t:truthy("camera lenta no EnemyRenderer", ER.getTimeScale() < 0.5)
    t:truthy("dessaturacao ativa", BC.desatAmount() > 0.1)
    local nominalD = BC.duration(Data.carrion_king.death)
    local eld = 0.3 + DT + runUntilDone(gd, nominalD + 2)
    t:falsy("morte terminou", BC.isActive())
    t:falsy("espolios liberados", BC.holdsEnd())
    t:near("duracao da morte = soma nominal", eld, nominalD, 0.1)
    t:eq("relogio do inimigo restaurado", ER.getTimeScale(), 1)
    t:near("dessaturacao zerada", BC.desatAmount(), 0, 1e-3)
    BC.update(DT, gd, { inHall = true })
    t:falsy("nao reencena a MESMA morte", BC.isActive())
    -- Continuar no cash out/espólios: o inimigo já nasce morto e a morte
    -- NÃO se reencena (markDeathSeen, chamado pelo __resumeRunStage)
    BC.reset()
    local gr = fakeBoss("carrion_king")
    gr._deathHandled = true
    BC.markDeathSeen(gr)
    BC.update(DT, gr, { inHall = true })
    t:falsy("Continuar com o chefe morto: morte nao reencena", BC.isActive())
    t:falsy("Continuar com o chefe morto: espolios livres", BC.holdsEnd())
    -- mini-boss na estrada: isBoss sem salao
    BC.reset()
    local gm = fakeBoss("carrion_king")
    gm._deathHandled = true
    BC.update(DT, gm, { inHall = false })
    t:falsy("fora do salao nao ha cinematica", BC.isActive())
    -- chefe sem roteiro próprio: entrada GENÉRICA (salão vazio → impacto →
    -- nome); quem não é chefe não tem entrada
    BC.reset()
    t:truthy("chefe sem roteiro ganha a entrada generica", BC.startIntro(fakeBoss("__nobody__")))
    t:truthy("generica: ativa", BC.isActive())
    t:truthy("generica: salao vazio no comeco", BC.hidesBoss())
    BC.setStage(stage)
    local elG = runUntilDone(fakeBoss("__nobody__"), 10)
    t:near("generica: duracao = soma nominal", elG, BC.duration(BC.GENERIC.intro), 0.1)
    BC.reset()
    local common = fakeBoss("carrion_king")
    common.enemy.isBoss = false
    t:falsy("inimigo comum nao inicia entrada", BC.startIntro(common))
    t:falsy("inimigo comum: inativo", BC.isActive())
    -- vivo: nao e morte
    BC.reset()
    BC.update(DT, fakeBoss("carrion_king"), { inHall = true })
    t:falsy("chefe vivo nao dispara morte", BC.isActive())

    -- ===== 6. cena: porta inicia, Continuar nao =====
    local game = TK.newRunGame("warrior")
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 1, 8
    run.currentNode = { type = "boss" }
    game.enemy.spriteId = "carrion_king"
    game.enemy.isBoss = true
    GS.setGame(game)
    t:falsy("setGame zera a cinematica", BC.isActive())
    t:falsy("antes da porta: estrada", GS.inBossRoom("boss"))
    GS._onBossEntered()
    t:truthy("porta aberta: salao", GS.inBossRoom("boss"))
    t:truthy("porta aberta: entrada toca", BC.isActive())
    t:falsy("cena NAO esta quieta durante a entrada (tutorial espera)", GS.isQuiet())
    BC.setStage(stage)
    runUntilDone(game, 20)
    ER.update(1.0)   -- assenta a quicada do pouso (triggerArrival)
    t:truthy("depois da entrada a cena volta a ficar quieta", GS.isQuiet())
    -- Continuar
    GS.setGame(game)
    local plan = ResumeFlow.apply(game, GS)
    t:truthy("Continuar: plano pede o salao", plan.bossInterior)
    t:truthy("Continuar: salao direto", GS.inBossRoom("boss"))
    t:falsy("Continuar: SEM entrada (retomar e retomar NA luta)", BC.isActive())
    GS.setGame(game)

    -- ===== 6b. sons da cinemática: todo arquivo declarado existe =====
    for code, spec in pairs(BC.SOUNDS) do
        t:truthy("som " .. code .. " existe em " .. spec[1],
            love.filesystem.getInfo(spec[1]) ~= nil)
    end

    -- ===== 6c. TODO chefe com roteiro: entrada e morte tocam inteiras =====
    -- (chefe escondido no começo e visível antes do fim, HUD só depois do
    -- chefe, duração = soma nominal, escuro zerado, relógio normal; morte
    -- segura espólios e solta; reducedMotion usa o roteiro curto)
    local ids = {}
    for id in pairs(Data) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        for _, reduced in ipairs({ false, true }) do
            local tag = id .. (reduced and " (reduced)" or "")
            _G.gameSettings.reducedMotion = reduced
            BC.reset()
            local gb = fakeBoss(id)
            t:truthy(tag .. ": entrada aceita", BC.startIntro(gb))
            t:truthy(tag .. ": chefe escondido no comeco", BC.hidesBoss())
            BC.setStage(stage)
            local steps = reduced and (Data[id].introReduced or Data[id].intro) or Data[id].intro
            local nom = BC.duration(steps)
            local elB, tL, tH = 0, nil, nil
            while BC.isActive() and elB < nom + 2 do
                BC.update(DT, gb, { inHall = true })
                elB = elB + DT
                if not tL and not BC.hidesBoss() then tL = elB end
                if not tH and not BC.hidesHud() then tH = elB end
            end
            t:falsy(tag .. ": entrada termina sozinha", BC.isActive())
            t:truthy(tag .. ": chefe aparece antes do fim", tL ~= nil and tL < nom)
            t:truthy(tag .. ": HUD so depois do chefe", tH ~= nil and tL ~= nil and tH > tL)
            t:near(tag .. ": duracao = soma nominal", elB, nom, 0.1)
            t:near(tag .. ": escuro zerado", BC.darkness(), 0, 1e-3)
            t:eq(tag .. ": relogio normal", ER.getTimeScale(), 1)
            -- morte
            BC.reset()
            BC.setStage(stage)
            local gdb = fakeBoss(id)
            gdb._deathHandled = true
            BC.update(DT, gdb, { inHall = true })
            t:truthy(tag .. ": morte detectada", BC.isActive() and BC.phase() == "death")
            t:truthy(tag .. ": morte segura espolios", BC.holdsEnd())
            local dsteps = reduced and (Data[id].deathReduced or Data[id].death) or Data[id].death
            local nomD = BC.duration(dsteps)
            local elD = DT + runUntilDone(gdb, nomD + 2)
            t:falsy(tag .. ": morte termina", BC.isActive())
            t:near(tag .. ": duracao da morte = soma nominal", elD, nomD, 0.1)
            t:eq(tag .. ": relogio restaurado apos a morte", ER.getTimeScale(), 1)
            t:falsy(tag .. ": espolios liberados", BC.holdsEnd())
        end
    end
    _G.gameSettings.reducedMotion = false
    BC.reset()

    -- ===== 6d. RAINHA DO ECLIPSE v2 (chefe final, frente rainha-eclipse) =====
    -- Escala: entrada de 12 a 18 s com os três atos (omen → unveil →
    -- coronation); reducedMotion curta mas com os três; letras do cartão
    -- chegam uma a uma e TODAS aparecem; a luta observa a fase do kit e
    -- fecha o eclipse do salão (InteriorFX.setEclipse) sem virar cinemática;
    -- a morte deixa a alvorada ligada (persiste no cash out) e o Continuar
    -- com a rainha morta nasce em alvorada.
    do
        local IFX = require("src.ui.InteriorFX")
        local function hasKind(steps, kind)
            for _, st in ipairs(steps or {}) do if st.kind == kind then return true end end
            return false
        end
        local qd = Data.eclipse_queen
        local nomQ = BC.duration(qd.intro)
        t:truthy("rainha: entrada entre 12 e 18 s (" .. string.format("%.1f", nomQ) .. ")",
            nomQ >= 12 and nomQ <= 18)
        t:truthy("rainha: entrada mais longa que a dos outros chefes",
            nomQ > BC.duration(Data.carrion_king.intro) + 3)
        for _, k in ipairs({ "omen", "unveil", "descend", "coronation" }) do
            t:truthy("rainha: intro tem " .. k, hasKind(qd.intro, k))
            t:truthy("rainha (reduced): intro tem " .. k .. " (toda a informacao)", hasKind(qd.introReduced, k))
        end
        t:truthy("rainha: cartao proprio (coronation), nao o title comum", not hasKind(qd.intro, "title"))
        t:truthy("rainha (reduced): roteiro curto", BC.duration(qd.introReduced) < nomQ * 0.6)
        t:truthy("rainha: morte vira cinzas (particle=ash)", qd.death[1].particle == "ash")
        t:truthy("rainha: morte abre o eclipse (dawn)", hasKind(qd.death, "dawn") and hasKind(qd.deathReduced, "dawn"))

        -- entrada inteira: fases observadas e letras todas
        _G.gameSettings.reducedMotion = false
        BC.reset()
        local gq = fakeBoss("eclipse_queen")
        gq.enemy.health, gq.enemy.maxHealth, gq.enemy._phaseIdx = 300, 300, 0
        t:truthy("rainha: entrada aceita", BC.startIntro(gq))
        BC.setStage(stage)
        local sawOmen, sawUnveil, sawCrown, maxShown, nChars = false, false, false, 0, nil
        local tReveal, elq = nil, 0
        local nEyes, sawTurnInOmen, sawEyesClose = nil, false, false
        while BC.isActive() and elq < nomQ + 2 do
            BC.update(DT, gq, { inHall = true })
            elq = elq + DT
            local d = BC._debug()
            if d.fx.omen then sawOmen = true end
            if d.fx.unveil then sawUnveil = true end
            if d.crown then
                sawCrown = true
                nChars = #d.crown.chars
                if d.crown.shown > maxShown then maxShown = d.crown.shown end
            end
            if not tReveal and not BC.hidesBoss() then tReveal = elq end
            -- olhos demais em volta do salão (lead): contagem, viram no omen, fecham na revelação
            if d.hallEyes then
                nEyes = #d.hallEyes.list
                if d.fx.omen and d.hallEyes.turned then sawTurnInOmen = true end
                if d.fx.unveil and d.hallEyes.close then sawEyesClose = true end
            end
        end
        t:truthy("rainha: olhos demais em volta do salao (20-40 pares, " .. tostring(nEyes) .. ")",
            nEyes and nEyes >= 20 and nEyes <= 40)
        t:truthy("rainha: todos os olhos viram pro jogador ainda no pressentimento", sawTurnInOmen)
        t:truthy("rainha: os olhos fecham quando ela se revela", sawEyesClose)
        t:truthy("rainha: pressentimento (omen) tocou", sawOmen)
        t:truthy("rainha: manifestacao (unveil) tocou", sawUnveil)
        t:truthy("rainha: coroacao (cartao proprio) tocou", sawCrown)
        t:truthy("rainha: TODAS as letras do nome chegaram (" .. tostring(maxShown) .. "/" .. tostring(nChars) .. ")",
            nChars and maxShown == nChars)
        t:truthy("rainha: ela so aparece depois do pressentimento + manifestacao (>6s)",
            tReveal ~= nil and tReveal > 6)
        t:falsy("rainha: cartao sumiu no fim", BC._debug().crown ~= nil)
        t:near("rainha: eclipse da luta comeca aberto", BC.eclipseLevel(), 0, 1e-3)

    end

    -- ===== 6d-b. RAINHA: luta por fases + alvorada no SALAO (InteriorFX) =====
    do
        local IFX = require("src.ui.InteriorFX")
        local qd = Data.eclipse_queen
        _G.gameSettings.reducedMotion = false
        BC.reset()
        local gq = fakeBoss("eclipse_queen")
        gq.enemy.health, gq.enemy.maxHealth, gq.enemy._phaseIdx = 300, 300, 0
        BC.startIntro(gq)
        BC.setStage(stage)
        pump(BC.SKIP_AFTER + 0.2, gq)
        t:truthy("rainha (luta): entrada pulada", BC.skip())

        -- LUTA: a fase do kit fecha o eclipse do salao SEM cinematica
        for _ = 1, 30 do BC.update(DT, gq, { inHall = true }) end
        t:falsy("rainha: luta nao e cinematica", BC.isActive())
        gq.enemy._phaseIdx = 1      -- Enemy:_checkPhase marcou a 2a fase (kit intocado)
        BC.update(DT, gq, { inHall = true })
        t:truthy("rainha: virada de fase tem instante proprio (phaseShift)", BC._debug().fx.phaseShift ~= nil)
        t:falsy("rainha: a virada nao trava a entrada do jogador", BC.lockInput())
        for _ = 1, 180 do BC.update(DT, gq, { inHall = true }) end
        t:truthy("rainha: eclipse fechado na 2a fase (" .. string.format("%.2f", BC.eclipseLevel()) .. ")",
            BC.eclipseLevel() > 0.9)
        local lvl, dawn0 = IFX.eclipseState()
        t:truthy("rainha: o salao 6 recebeu o fechamento (InteriorFX.setEclipse)", lvl > 0.9)
        t:near("rainha: sem alvorada enquanto viva", dawn0, 0, 1e-3)
        t:falsy("rainha: instante da virada acabou sozinho", BC._debug().fx.phaseShift ~= nil)

        -- MORTE: cinzas + alvorada, e a alvorada FICA (cash out no salao)
        gq.enemy.health = 0
        gq._deathHandled = true
        BC.update(DT, gq, { inHall = true })
        t:truthy("rainha: morte detectada", BC.isActive() and BC.phase() == "death")
        runUntilDone(gq, BC.duration(qd.death) + 2)
        t:falsy("rainha: morte terminou", BC.isActive())
        t:near("rainha: alvorada completa depois da morte", BC.eclipseDawn(), 1, 1e-3)
        BC.update(DT, gq, { inHall = true })
        local _, dawn1 = IFX.eclipseState()
        t:truthy("rainha: alvorada persiste no salao depois da cinematica", dawn1 > 0.99)

        -- CONTINUAR com a rainha morta: nasce em alvorada, sem reencenar
        BC.reset()
        local gc = fakeBoss("eclipse_queen")
        gc.enemy.health, gc.enemy.maxHealth, gc.enemy._phaseIdx = 0, 300, 1
        gc._deathHandled = true
        BC.markDeathSeen(gc)
        BC.setStage(stage)
        for _ = 1, 5 do BC.update(DT, gc, { inHall = true }) end
        t:falsy("rainha: Continuar morta nao reencena", BC.isActive())
        t:near("rainha: Continuar morta = alvorada pronta", BC.eclipseDawn(), 1, 1e-3)

        -- reset zera o estado do salao (outro chefe/outra run nao herda)
        BC.reset()
        local lvl2, dawn2 = IFX.eclipseState()
        t:near("rainha: reset zera o eclipse do salao (nivel)", lvl2, 0, 1e-3)
        t:near("rainha: reset zera o eclipse do salao (alvorada)", dawn2, 0, 1e-3)
        IFX.clear()
    end

    -- ===== 7. i18n: todo chefe com roteiro tem nome + epiteto nos 5 locales =====
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        local ok, tbl = pcall(require, "src.i18n.locales.boss_cinematics." .. loc)
        t:truthy("locale " .. loc .. " carrega", ok and type(tbl) == "table")
        if ok and type(tbl) == "table" then
            t:truthy(loc .. ": dica de pular com {key}",
                type(tbl.skip) == "string" and tbl.skip:find("{key}", 1, true) ~= nil)
            for _, id in ipairs(ids) do
                local ck = tbl[id]
                t:truthy(loc .. ": nome do " .. id, ck and type(ck.name) == "string" and ck.name ~= "")
                t:truthy(loc .. ": epiteto do " .. id, ck and type(ck.epithet) == "string" and ck.epithet ~= "")
            end
        end
    end

    BC.reset()
    _G.gameSettings = savedSettings
    return t:done()
end

return M
