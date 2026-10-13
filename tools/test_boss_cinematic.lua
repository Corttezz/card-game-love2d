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
    t:truthy("salao escuro no comeco", BC.darkness() > 0.5)
    t:truthy("entrada trava a entrada do jogador", BC.lockInput())
    t:falsy("entrada nao segura espolios", BC.holdsEnd())
    BC.setStage(stage)
    local nominal = BC.duration(Data.carrion_king.intro)
    local tLand, tHud, el = nil, nil, 0
    while BC.isActive() and el < nominal + 2 do
        BC.update(DT, g, { inHall = true })
        el = el + DT
        if not tLand and not BC.hidesBoss() then tLand = el end
        if not tHud and not BC.hidesHud() then tHud = el end
    end
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
    local elR = runUntilDone(g, 20)
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
    -- mini-boss na estrada: isBoss sem salao
    BC.reset()
    local gm = fakeBoss("carrion_king")
    gm._deathHandled = true
    BC.update(DT, gm, { inHall = false })
    t:falsy("fora do salao nao ha cinematica", BC.isActive())
    -- chefe sem roteiro
    BC.reset()
    t:falsy("chefe sem roteiro nao inicia entrada", BC.startIntro(fakeBoss("tower_lich")))
    t:falsy("chefe sem roteiro: inativo", BC.isActive())
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

    -- ===== 7. i18n =====
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        local ok, tbl = pcall(require, "src.i18n.locales.boss_cinematics." .. loc)
        t:truthy("locale " .. loc .. " carrega", ok and type(tbl) == "table")
        if ok and type(tbl) == "table" then
            t:truthy(loc .. ": dica de pular com {key}",
                type(tbl.skip) == "string" and tbl.skip:find("{key}", 1, true) ~= nil)
            local ck = tbl.carrion_king
            t:truthy(loc .. ": nome do carrion_king", ck and type(ck.name) == "string" and ck.name ~= "")
            t:truthy(loc .. ": epiteto do carrion_king", ck and type(ck.epithet) == "string" and ck.epithet ~= "")
        end
    end

    BC.reset()
    _G.gameSettings = savedSettings
    return t:done()
end

return M
