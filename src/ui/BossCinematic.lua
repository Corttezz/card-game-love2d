-- src/ui/BossCinematic.lua
-- CINEMÁTICA DE CHEFE: entrada no salão e morte — runner dos roteiros de
-- src/data/boss_cinematics.lua.
--
-- Pedido do dono (Out/2026): a porta do castelo abre (cerimônia já existente,
-- WorldRoad.enterCastle) → o salão abre VAZIO (sem chefe, sem HUD) → a entrada
-- toca dentro do salão com o cenário do próprio salão → nome do chefe → HUD →
-- luta. Na morte: colapso em câmera lenta, luz saindo dos olhos, rajada de
-- penas e corvos, dessaturação breve, o corpo fica no salão e SÓ DEPOIS os
-- espólios entram.
--
-- COMO SE ENCAIXA (ver GameplayScene):
--   * `startIntro(game)` é chamado pelo onComplete da porta (bossEntered=true).
--     O Continuar (ResumeFlow → _debugForceBossEntered) NÃO passa por aqui:
--     retomar dentro da luta é retomar na luta, sem repetir a entrada.
--   * A cena pergunta `hidesBoss()` (chefe ainda não pousou → o EnemyRenderer
--     desenha num canvas descartado só pra MEDIR onde ele vai ficar) e
--     `hidesHud()` (HUD do inimigo, painel do herói, mão e botões esperam).
--   * `drawBack()` roda no espaço do MUNDO logo depois do salão + InteriorFX
--     (escuridão, olhos, rasantes, vento, penas); `drawFront()` depois do chefe
--     (poeira do pouso, corvos espantados, penas da morte); `drawUI()` no
--     espaço da UI (cartão de nome, dica de pular).
--   * `beginWorldPass()/endWorldPass()` embrulham o mundo num canvas quando a
--     dessaturação da morte está ativa (shaders/desat.glsl).
--   * `holdsEnd()` segura espólios/vitória enquanto a morte toca.
--   * `overlay` é registrado no InputFocus (main.lua, PRIMEIRO da lista = menor
--     prioridade: pausa e companhia continuam ganhando). Com ele visível o
--     clique/tecla/A vêm pra cá (pular depois de SKIP_AFTER), o NavCursor não
--     reclama o Enter (ownsNavigation) e o combate NÃO congela (exceção em
--     main.lua: a cinemática é a única captora que deixa o relógio correr).
--
-- Tempo: a sequência é uma LINHA DO TEMPO própria (dt acumulado), não uma fila
-- do EventManager — pular é saltar pro estado final, e o teste roda sem
-- EventManager. Efeitos com envelope (gust das luminárias, slowmo, desat)
-- continuam vivos depois que o passo que os disparou passou.
--
-- reducedMotion: usa `introReduced`/`deathReduced` do dado (mesma linguagem,
-- sem varrer a tela); informação (nome do chefe) fica.

local Data            = require("src.data.boss_cinematics")
local I18n            = require("src.i18n.I18n")
local FontManager     = require("src.ui.FontManager")
local Sfx             = require("src.systems.Sfx")
local SceneBackground = require("src.ui.SceneBackground")
local SpriteAnimation = require("src.ui.SpriteAnimation")
local EnemyRenderer   = require("src.ui.EnemyRenderer")
local EnemyPoses      = require("src.data.enemy_poses")
local InteriorFX      = require("src.ui.InteriorFX")
local DynaText        = require("src.ui.DynaText")

local BossCinematic = {}

-- Depois de quanto tempo clique/A/Enter PULA (segundos).
BossCinematic.SKIP_AFTER = 1.0

-- Passos conhecidos por fase. Kind desconhecido AVISA e é pulado (fallback
-- silencioso é proibido — CLAUDE.md §9).
BossCinematic.INTRO_KINDS = { dark = true, eyes = true, flyby = true, land = true,
                              title = true, hud = true,
                              -- outros chefes (elemento de cada um)
                              runes = true, rise = true, whiteout = true, silhouette = true,
                              settle = true, door_burst = true, firewall = true, chains = true,
                              walk_in = true, heartbeat = true, roots = true, eclipse = true,
                              descend = true }
BossCinematic.DEATH_KINDS = { slowmo = true, burst = true, desat = true, hold = true,
                              -- elemento engolindo o corpo (tirano: poça de lava)
                              lava = true }

-- Sons (audio/sfx/boss/, registrados sob demanda; fallback por Sfx.has).
local SOUNDS = {
    bossEyesIgnite     = { "audio/sfx/boss/boss_eyes_ignite.mp3",     0.70 },
    bossEyesRumble     = { "audio/sfx/boss/boss_eyes_rumble.mp3",     0.55, loop = true },
    bossBlinkClick     = { "audio/sfx/boss/boss_blink_click.mp3",     0.60 },
    bossWingPass       = { "audio/sfx/boss/boss_wing_pass.mp3",       0.80 },
    bossCrowsCaw       = { "audio/sfx/boss/boss_crows_caw.mp3",       0.60 },
    bossLandImpact     = { "audio/sfx/boss/boss_land_impact.mp3",     0.90 },
    bossFeathersSettle = { "audio/sfx/boss/boss_feathers_settle.mp3", 0.55 },
    bossRevealSting    = { "audio/sfx/boss/boss_reveal_sting.mp3",    0.85 },
    bossDeathThud      = { "audio/sfx/boss/boss_death_thud.mp3",      0.85 },
    bossFeatherBurst   = { "audio/sfx/boss/boss_feather_burst.mp3",   0.70 },
    bossCrowsFlee      = { "audio/sfx/boss/boss_crows_flee.mp3",      0.60 },
    bossHoldAmbience   = { "audio/sfx/boss/boss_hold_ambience.mp3",   0.45, loop = true },
    -- outros chefes (elemento)
    bossRuneIgnite     = { "audio/sfx/boss/boss_rune_ignite.mp3",      0.65 },
    bossFrostStorm     = { "audio/sfx/boss/boss_frost_storm.mp3",      0.60, loop = true },
    bossFrostShatter   = { "audio/sfx/boss/boss_frost_shatter.mp3",    0.80 },
    bossDoorBurst      = { "audio/sfx/boss/boss_door_burst.mp3",       0.90 },
    bossHellfireWall   = { "audio/sfx/boss/boss_hellfire_wall.mp3",    0.55, loop = true },
    bossChainsRattle   = { "audio/sfx/boss/boss_chains_rattle.mp3",    0.65 },
    bossLavaImplosion  = { "audio/sfx/boss/boss_lava_implosion.mp3",   0.85 },
    bossBlizzard       = { "audio/sfx/boss/boss_blizzard_whiteout.mp3", 0.60, loop = true },
    bossIceCrackle     = { "audio/sfx/boss/boss_ice_crackle.mp3",      0.70 },
    bossHeartbeat      = { "audio/sfx/boss/boss_heartbeat.mp3",        0.80 },
    bossRootsCrawl     = { "audio/sfx/boss/boss_roots_crawl.mp3",      0.55, loop = true },
    bossEmergeTear     = { "audio/sfx/boss/boss_emerge_tear.mp3",      0.85 },
    bossSporeCollapse  = { "audio/sfx/boss/boss_spore_collapse.mp3",   0.80 },
    bossEclipseHum     = { "audio/sfx/boss/boss_eclipse_hum.mp3",      0.55, loop = true },
    bossDescendWings   = { "audio/sfx/boss/boss_descend_wings.mp3",    0.75 },
    bossEclipseBreak   = { "audio/sfx/boss/boss_eclipse_break.mp3",    0.80 },
}
local soundsLoaded = false
BossCinematic.SOUNDS = SOUNDS   -- teste confere que todo arquivo existe

-- ---------------------------------------------------------------------------
-- ESTADO (módulo: uma cinemática por vez, como a cena)
-- ---------------------------------------------------------------------------
local seq = nil        -- { phase, steps, idx, stepT, t, bossId, reduced }
local stage = nil      -- { cx, cy, bbox, foot, hall, w, h, tr } (GameplayScene, por frame)
local dark = 0         -- escuridão corrente do salão (0..1)
local darkEase = nil   -- { from, to, t, dur }
local eyes = nil       -- { u, v, size, blinks, t, dur }
local fly = nil        -- { from, v, ghosts, arc, land, lights, t, dur, startDark, trail }
local title = nil      -- { t, dur, name, epithet, dyna }
local slowmo = nil     -- { scale, dur, release, t }
local desat = nil      -- { peak, rise, fall, total, t }
local bossHidden = false
local hudHidden = false
local landed = false
local mist = nil       -- névoa colorida do salão { puffs, a, target, speed }
local mistGustDir = 1  -- pra onde a rajada do rasante empurra a névoa
local hit = nil        -- efeito de tela do pouso { t, dur, cx, cy }
local edge = nil       -- whoosh na borda da tela { side, t, dur }
local loops = {}       -- sons em loop tocando (code -> source)
local sfxQueue = {}    -- sons agendados { t, code, pitch }
local spawnMist        -- definida na seção NÉVOA (startIntro fica acima dela)
-- PALETA do chefe (cor da névoa, do brilho, do flash, das partículas) — vem
-- de `palette` no dado; sem ela, a do rei-carniça (violeta/brasa).
local DEFAULT_PALETTE = {
    body = { 0.22, 0.13, 0.38 }, glow = { 0.58, 0.36, 0.98 }, ember = { 1.00, 0.50, 0.16 },
    flash = { 0.72, 0.52, 1.00 }, ghost = { 0.56, 0.46, 0.86 }, rim = { 0.62, 0.50, 0.95 },
    particle = { 0.20, 0.16, 0.32 }, particle2 = { 0.58, 0.50, 0.90 },
}
local PAL = DEFAULT_PALETTE
-- estados dos kinds dos outros chefes (runas, subida, nevasca, portão...)
local fx = {}
local flakes = {}
local ownAnims = {}
local deathFor = nil   -- inimigo cuja morte já foi encenada (não repete)
local flyAnim = nil    -- SpriteAnimation idle do chefe pros rasantes
local flyAnimId = nil
-- partículas (px de tela)
local feathers, dust, crows, wind = {}, {}, {}, {}
-- canvases: dummy (medição) e passe de dessaturação
local dummy = nil
local worldCanvas = nil
local desatShader = nil
local desatTried = false
local warnedKind = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function smooth(k) return k * k * (3 - 2 * k) end

local function loadSounds()
    if soundsLoaded then return end
    soundsLoaded = true
    local a = _G.audioSystem
    if not a or not a.loadSound then return end
    for code, spec in pairs(SOUNDS) do
        if not Sfx.has(code) and love.filesystem.getInfo(spec[1]) then
            a:loadSound(code, spec[1], { volume = spec[2], loop = spec.loop or false })
        end
    end
end

-- som em LOOP (rumor dos olhos, ambiente do corpo): guarda a fonte pra parar
local function playLoop(code)
    if loops[code] then return end
    local a = _G.audioSystem
    if not a or not Sfx.has(code) then return end
    local src = a:play(code, { loop = true })
    if src then loops[code] = src end
end
local function stopLoop(code)
    local src = loops[code]
    if src then pcall(src.stop, src) end
    loops[code] = nil
end
local function stopAllLoops()
    for code in pairs(loops) do stopLoop(code) end
end
-- som agendado (relógio da cinemática, não o EventManager)
local function queueSfx(delay, code, fallback, pitch)
    sfxQueue[#sfxQueue + 1] = { t = delay, code = code, fallback = fallback, pitch = pitch }
end

local function play(code, fallback, pitch, pitchVar)
    local name = Sfx.has(code) and code or fallback
    if not name then return end
    if pitch then
        Sfx.playWithVariation(name, pitch, pitchVar or 0)
    else
        Sfx.play(name)
    end
end

-- ---------------------------------------------------------------------------
-- DADOS
-- ---------------------------------------------------------------------------
function BossCinematic.data(id)
    return id and Data[id] or nil
end

function BossCinematic.hasIntro(id)
    local d = Data[id]
    return d ~= nil and d.intro ~= nil and #d.intro > 0
end

function BossCinematic.hasDeath(id)
    local d = Data[id]
    return d ~= nil and d.death ~= nil and #d.death > 0
end

-- Soma dos `dur` de uma lista de passos (limite nominal da sequência).
function BossCinematic.duration(steps)
    local s = 0
    for _, st in ipairs(steps or {}) do s = s + (st.dur or 0) end
    return s
end

-- Valida um roteiro: kinds conhecidos pra fase, dur numérico >= 0.
-- Devolve lista de problemas (vazia = ok). Usada pelo teste e no start.
function BossCinematic.validate(id)
    local d = Data[id]
    local errs = {}
    if not d then return { "sem dados pra " .. tostring(id) } end
    local function check(list, kinds, label)
        for i, st in ipairs(list or {}) do
            if not kinds[st.kind] then
                errs[#errs + 1] = ("%s.%s[%d]: kind desconhecido '%s'"):format(id, label, i, tostring(st.kind))
            end
            if st.dur ~= nil and (type(st.dur) ~= "number" or st.dur < 0) then
                errs[#errs + 1] = ("%s.%s[%d]: dur invalido"):format(id, label, i)
            end
        end
    end
    check(d.intro, BossCinematic.INTRO_KINDS, "intro")
    check(d.introReduced, BossCinematic.INTRO_KINDS, "introReduced")
    check(d.death, BossCinematic.DEATH_KINDS, "death")
    check(d.deathReduced, BossCinematic.DEATH_KINDS, "deathReduced")
    return errs
end

-- ---------------------------------------------------------------------------
-- CICLO DE VIDA
-- ---------------------------------------------------------------------------
local function clearFx()
    feathers, dust, crows, wind = {}, {}, {}, {}
end

-- Estado final (tudo visível, nada pendente). Partículas em voo podem
-- terminar sozinhas.
local function finish()
    seq = nil
    dark = 0
    darkEase = nil
    eyes = nil
    fly = nil
    title = nil
    slowmo = nil
    desat = nil
    bossHidden = false
    hudHidden = false
    mist = nil
    hit = nil
    edge = nil
    fx = {}
    flakes = {}
    sfxQueue = {}
    stopAllLoops()
    EnemyRenderer.setTimeScale(1)
end

function BossCinematic.reset()
    finish()
    clearFx()
    landed = false
    deathFor = nil
    stage = nil
end

local function copySteps(list)
    local out = {}
    for i, st in ipairs(list) do
        local c = {}
        for k, v in pairs(st) do c[k] = v end
        out[i] = c
    end
    return out
end

local function begin(phase, steps, bossId, reduced, data)
    loadSounds()
    seq = { phase = phase, steps = copySteps(steps), idx = 1, stepT = 0, t = 0,
            bossId = bossId, reduced = reduced }
    local pal = data and data.palette or (Data[bossId] and Data[bossId].palette)
    PAL = setmetatable(pal or {}, { __index = DEFAULT_PALETTE })
    fx = {}
    flakes = {}
end

-- ENTRADA GENÉRICA — chefe SEM roteiro próprio (chefe novo que ainda não
-- ganhou o dele). O salão abre VAZIO, um compasso de escuro, o chefe aparece
-- no palco com impacto, cartão com o nome. Nunca mais "luta como antes" com
-- a mão já na tela (bug do dono, Out/2026). Paleta neutra (pedra/âmbar).
BossCinematic.GENERIC = {
    intro = {
        { kind = "dark",  dur = 0.70, to = 0.60 },
        { kind = "land",  dur = 0.55, shake = 8, dust = 10, crows = 0 },
        { kind = "title", dur = 1.80 },
        { kind = "hud",   dur = 0 },
    },
    introReduced = {
        { kind = "dark",  dur = 0.35, to = 0.45 },
        { kind = "land",  dur = 0.40, shake = 3, dust = 4, crows = 0 },
        { kind = "title", dur = 1.30 },
        { kind = "hud",   dur = 0 },
    },
    palette = {
        body = { 0.12, 0.10, 0.14 }, glow = { 0.70, 0.64, 0.52 }, ember = { 0.90, 0.68, 0.36 },
        flash = { 0.82, 0.76, 0.64 }, ghost = { 0.60, 0.56, 0.50 }, rim = { 0.72, 0.66, 0.54 },
        particle = { 0.30, 0.26, 0.22 }, particle2 = { 0.62, 0.56, 0.46 },
    },
}

-- ENTRADA. Chefe com roteiro usa o dele; chefe sem roteiro usa o GENÉRICO.
-- Quem não é chefe não tem entrada (devolve false).
function BossCinematic.startIntro(game)
    local e = game and game.enemy
    local id = e and e.spriteId
    if not (e and e.isBoss and id) then return false end
    local d = Data[id]
    if d and not BossCinematic.hasIntro(id) then d = nil end
    if d then
        for _, err in ipairs(BossCinematic.validate(id)) do
            print("[BossCinematic] " .. err)
        end
    else
        print("[BossCinematic] chefe sem roteiro próprio: " .. tostring(id) .. " — entrada genérica")
        d = BossCinematic.GENERIC
    end
    local reduced = reducedMotion()
    local steps = (reduced and d.introReduced) or d.intro
    finish()
    clearFx()
    landed = false
    deathFor = nil
    begin("intro", steps, id, reduced, d)
    -- o salão nasce ESCURO: a cena ainda está no fade do preto
    dark = 0.86
    bossHidden = true
    hudHidden = true
    spawnMist()
    return true
end

-- MORTE. Chamada pelo update ao detectar `_deathHandled` do chefe no salão
-- (ou direto por teste/ferramenta).
function BossCinematic.startDeath(game)
    local e = game and game.enemy
    local id = e and e.spriteId
    if not (e and e.isBoss and BossCinematic.hasDeath(id)) then return false end
    if deathFor == e then return false end
    deathFor = e
    local d = Data[id]
    local reduced = reducedMotion()
    local steps = (reduced and d.deathReduced) or d.death
    -- a entrada ainda tocando (morte instantânea por ferramenta): encerra
    if seq then finish() end
    begin("death", steps, id, reduced)
    return true
end

function BossCinematic.isActive() return seq ~= nil end
function BossCinematic.phase() return seq and seq.phase or nil end
function BossCinematic.hidesBoss() return seq ~= nil and bossHidden end
function BossCinematic.hidesHud() return seq ~= nil and hudHidden end
-- mão, botões, coringas e prévia somem em QUALQUER fase (na morte o HUD de
-- vida/TopBar fica, mas não há o que jogar)
function BossCinematic.hidesHand() return seq ~= nil end
function BossCinematic.holdsEnd() return seq ~= nil and seq.phase == "death" end
function BossCinematic.lockInput() return seq ~= nil end
function BossCinematic.elapsed() return seq and seq.t or 0 end
function BossCinematic.canSkip()
    return seq ~= nil and seq.t >= BossCinematic.SKIP_AFTER
end
function BossCinematic.darkness() return dark end

-- Introspecção pra testes.
function BossCinematic._debug()
    return { seq = seq, dark = dark, eyes = eyes, fly = fly, title = title,
             slowmo = slowmo, desat = desat, landed = landed,
             mist = mist, hit = hit, edge = edge, loops = loops, fx = fx,
             feathers = #feathers, dust = #dust, crows = #crows, wind = #wind }
end

-- PULAR: salta pro estado final. Antes de SKIP_AFTER é ignorado (evita o
-- clique de aproximação da porta engolir a entrada).
function BossCinematic.skip()
    if not BossCinematic.canSkip() then return false end
    if seq.phase == "intro" then
        landed = true
        EnemyRenderer.triggerArrival()
    end
    finish()
    return true
end

-- Posição/medidas do palco, vindas da cena a cada frame (espaço do mundo).
function BossCinematic.setStage(st) stage = st end

-- ---------------------------------------------------------------------------
-- PARTÍCULAS
-- ---------------------------------------------------------------------------
local FEATHER_DARK  = { 0.20, 0.16, 0.32 }
local FEATHER_LIGHT = { 0.58, 0.50, 0.90 }
local CROW_BODY     = { 0.09, 0.07, 0.13 }
local CROW_SHEEN    = { 0.36, 0.31, 0.56 }
local WIND_COLOR    = { 0.78, 0.74, 0.90 }
local EYE_CORE      = { 1.00, 0.78, 0.32 }
local EYE_HALO      = { 1.00, 0.46, 0.10 }

-- bloco = pixel da ARTE (escala do sprite ou do salão), nunca 1px de tela
local function px()
    local s = (stage and stage.foot and stage.foot.scale) or (stage and stage.tr and stage.tr.scale) or 2
    return math.max(2, math.floor(s + 0.5))
end

local function spawnFeather(x, y, vx, vy, kind)
    kind = kind or "feather"
    feathers[#feathers + 1] = {
        x = x, y = y, vx = vx, vy = vy, kind = kind,
        rot = love.math.random() * math.pi, rotV = (love.math.random() - 0.5) * 6,
        sway = love.math.random() * math.pi * 2,
        life = 1.4 + love.math.random() * 1.2, max = 0,
        light = love.math.random() < 0.35,
        -- brasa/esporo FLUTUAM (sobem devagar); pena/lasca/pétala caem
        float = (kind == "ember" or kind == "spore"),
    }
    local f = feathers[#feathers]
    f.max = f.life
end

local function spawnDust(x, groundY, n, spread)
    for i = 1, n do
        local side = (i % 2 == 0) and 1 or -1
        dust[#dust + 1] = {
            x = x + side * (6 + love.math.random() * spread * 0.4),
            y = groundY,
            vx = side * (60 + love.math.random() * 120),
            vy = -(30 + love.math.random() * 70),
            life = 0.45 + love.math.random() * 0.35, max = 0,
        }
        dust[#dust].max = dust[#dust].life
    end
end

local function spawnCrows(x, y, n, speed)
    for i = 1, n do
        local a = -math.pi * (0.15 + 0.7 * ((i - 0.5) / n)) + (love.math.random() - 0.5) * 0.3
        local sp = speed * (0.75 + love.math.random() * 0.5)
        crows[#crows + 1] = {
            x = x + (love.math.random() - 0.5) * 40, y = y + (love.math.random() - 0.5) * 30,
            vx = math.cos(a) * sp, vy = math.sin(a) * sp,
            flap = love.math.random() * 3, life = 2.4, max = 2.4,
            dir = (math.cos(a) >= 0) and 1 or -1,
        }
    end
end

local function spawnWind(x, y, dirX, len, thick)
    wind[#wind + 1] = { x = x, y = y, len = len, vx = dirX * (720 + love.math.random() * 420),
                        life = 0.22 + love.math.random() * 0.16, max = 0, thick = thick }
    wind[#wind].max = wind[#wind].life
end

local function updateFx(dt)
    for i = #feathers, 1, -1 do
        local f = feathers[i]
        f.life = f.life - dt
        f.sway = f.sway + dt * 4.5
        if f.float then
            f.vy = f.vy - 18 * dt
        else
            f.vy = math.min(f.vy + 55 * dt, 48)
        end
        f.vx = f.vx * (1 - 1.6 * dt) + math.sin(f.sway) * 22 * dt
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
        f.rot = f.rot + f.rotV * dt
        if f.life <= 0 or (stage and f.y > (stage.h or 1e9) + 20) then table.remove(feathers, i) end
    end
    for i = #dust, 1, -1 do
        local d = dust[i]
        d.life = d.life - dt
        d.x = d.x + d.vx * dt
        d.vx = d.vx * (1 - 3 * dt)
        d.y = d.y + d.vy * dt
        d.vy = d.vy + 220 * dt
        if d.life <= 0 then table.remove(dust, i) end
    end
    for i = #crows, 1, -1 do
        local c = crows[i]
        c.life = c.life - dt
        c.flap = c.flap + dt * 14
        c.vy = c.vy - 60 * dt            -- ganham altura
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt
        if c.life <= 0 or c.y < -60 then table.remove(crows, i) end
    end
    for i = #wind, 1, -1 do
        local w = wind[i]
        w.life = w.life - dt
        w.x = w.x + w.vx * dt
        if w.life <= 0 then table.remove(wind, i) end
    end
end

-- ---------------------------------------------------------------------------
-- NÉVOA COLORIDA (revisão do dono: "algo nebuloso, com cor, mais drama").
-- Puffs = texturas de névoa GERADAS (value noise + 3 degraus de alpha com
-- dither Bayer 4×4, borda esfarelada — nada de retângulo, nada de gradiente
-- liso), desenhadas na GRADE DA ARTE do salão (posição truncada em px da
-- PNG, escala = cover-fit × tamanho do puff), em 3 camadas com paralaxe:
-- duas atrás do chefe (fundas/rentes) e uma na frente, fina. Cada puff
-- desenha o CORPO (alpha, violeta escuro) e um BRILHO aditivo (violeta ou
-- brasa) — é esse brilho que "sangra" cor na pedra. A rajada do rasante
-- empurra a névoa (InteriorFX.gustLevel × direção do voo). reducedMotion:
-- névoa parada.
-- ---------------------------------------------------------------------------
local BAYER4 = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local function bayer(x, y)
    return (BAYER4[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16
end
local function hash2(x, y)
    local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)
end
local function vnoise(x, y)
    local xi, yi = math.floor(x), math.floor(y)
    local xf, yf = x - xi, y - yi
    local u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    local a, b = hash2(xi, yi), hash2(xi + 1, yi)
    local c, d = hash2(xi, yi + 1), hash2(xi + 1, yi + 1)
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v
end
local function fbm(x, y)
    return 0.55 * vnoise(x, y) + 0.30 * vnoise(x * 2.1 + 5.2, y * 2.1 + 1.3)
        + 0.15 * vnoise(x * 4.3 + 9.1, y * 4.3 + 3.7)
end

local fogImgs = nil
local FOG_W, FOG_H = 72, 36
local function ensureFog()
    if fogImgs then return fogImgs end
    fogImgs = {}
    for i = 1, 3 do
        local data = love.image.newImageData(FOG_W, FOG_H)
        for y = 0, FOG_H - 1 do
            for x = 0, FOG_W - 1 do
                local n = fbm(x / FOG_W * 3 + i * 7.3, y / FOG_H * 2 + i * 3.1)
                local dx, dy = (x + 0.5) / FOG_W * 2 - 1, (y + 0.5) / FOG_H * 2 - 1
                local r = math.sqrt(dx * dx + dy * dy * 1.3)
                local v = n * math.max(0, math.min(1, 1.35 - r * 1.1))
                local th = bayer(x, y) * 0.18
                local a = 0
                if v > 0.50 + th then a = 1
                elseif v > 0.35 + th then a = 0.66
                elseif v > 0.22 + th then a = 0.33 end
                data:setPixel(x, y, 1, 1, 1, a)
            end
        end
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        fogImgs[i] = img
    end
    return fogImgs
end


-- layer 1 = fundo (lento, pequeno), 2 = rente ao chefe, 3 = frente (fino)
spawnMist = function()
    ensureFog()
    mist = { puffs = {}, a = 0, target = 0, speed = 1 }
    local function puff(layer, n)
        for _ = 1, n do
            local far = (layer == 1)
            mist.puffs[#mist.puffs + 1] = {
                layer = layer,
                x = -60 + love.math.random() * 480,
                y = (far and 70 or 110) + love.math.random() * (far and 110 or 120),
                vx = (far and 2 or 4) * (love.math.random() < 0.5 and -1 or 1) * (0.6 + love.math.random() * 0.8),
                s = (far and 0.9 or 1.3) + love.math.random() * 0.6,
                a = (layer == 3) and 0.22 or (far and 0.42 or 0.56),
                img = 1 + love.math.random(0, 2),
                flip = love.math.random() < 0.5,
                ember = love.math.random() < 0.22,
                bob = love.math.random() * 6.28,
            }
        end
    end
    puff(1, 9)
    puff(2, 10)
    puff(3, 5)
end

local function mistTarget(target, secs)
    if not mist then return end
    mist.target = target
    mist.speed = 1 / math.max(0.05, secs or 1)
end

local function updateMist(dt)
    if not mist then return end
    if mist.a < mist.target then mist.a = math.min(mist.target, mist.a + dt * mist.speed)
    elseif mist.a > mist.target then mist.a = math.max(mist.target, mist.a - dt * mist.speed) end
    if reducedMotion() then return end
    local g = InteriorFX.gustLevel() * mistGustDir
    for _, pf in ipairs(mist.puffs) do
        local par = (pf.layer == 1) and 0.5 or ((pf.layer == 2) and 1 or 1.7)
        pf.x = pf.x + (pf.vx + g * 230) * par * dt
        pf.bob = pf.bob + dt * 0.7
        if pf.x > 430 then pf.x = -90 elseif pf.x < -100 then pf.x = 420 end
    end
end

-- Desenha as camadas `layers` (tabela de booleanos por layer) em coords da arte.
local function drawMist(layers)
    if not mist or mist.a <= 0.01 or not stage or not stage.tr then return end
    local tr = stage.tr
    local S = tr.scale
    local imgs = ensureFog()
    for _, pf in ipairs(mist.puffs) do
        if layers[pf.layer] then
            local img = imgs[pf.img]
            local sx = pf.s * S * (pf.flip and -1 or 1)
            local sy = pf.s * S
            local x = tr.ox + math.floor(pf.x + (pf.flip and FOG_W * pf.s or 0)) * S
            local y = tr.oy + math.floor(pf.y + math.sin(pf.bob) * 3) * S
            local a = pf.a * mist.a
            love.graphics.setColor(PAL.body[1], PAL.body[2], PAL.body[3], a)
            love.graphics.draw(img, x, y, 0, sx, sy)
            love.graphics.setBlendMode("add")
            local gc = pf.ember and PAL.ember or PAL.glow
            love.graphics.setColor(gc[1], gc[2], gc[3], a * (pf.ember and 0.22 or 0.30))
            love.graphics.draw(img, x, y, 0, sx, sy)
            love.graphics.setBlendMode("alpha")
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Blob de brilho (névoa aditiva) centrado em (cx, cy), largura w, altura h —
-- substitui qualquer "retângulo de luz": a borda é a da textura esfarelada.
local function glowBlob(cx, cy, w, h, color, a, idx)
    local img = ensureFog()[idx or 1]
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], a)
    love.graphics.draw(img, math.floor(cx - w / 2), math.floor(cy - h / 2), 0, w / FOG_W, h / FOG_H)
    love.graphics.setBlendMode("alpha")
end

-- ---------------------------------------------------------------------------
-- EFEITO DE TELA DO POUSO: flash na cor do chefe (3 degraus no tempo, sem
-- gradiente), onda de choque em anel pontilhado (blocos na grade, dither
-- Bayer no esvaecer), pulso de vinheta em bandas, solavanco no CRT e soco
-- de zoom no MUNDO (1.0 → 1.06 → 1.0, translação inteira). reducedMotion:
-- só o pulso de vinheta, suave.
-- ---------------------------------------------------------------------------
-- Cores dos dois anéis da onda de choque por ESTILO (`land.ring` no dado):
-- sem estilo, a paleta do chefe (brasa + flash).
local RING_STYLES = {
    ice    = { { 0.78, 0.94, 1.00 }, { 0.42, 0.78, 1.00 } },
    frost  = { { 0.90, 0.97, 1.00 }, { 0.62, 0.86, 1.00 } },
    lava   = { { 1.00, 0.52, 0.12 }, { 1.00, 0.86, 0.38 } },
    spores = { { 0.55, 0.86, 0.32 }, { 0.86, 0.96, 0.52 } },
    petal  = { { 0.96, 0.46, 0.76 }, { 0.74, 0.32, 0.92 } },
}
local function startHit(cx, cy, ring)
    if ring and not RING_STYLES[ring] then
        print("[BossCinematic] land.ring desconhecido: " .. tostring(ring) .. " — paleta do chefe")
    end
    hit = { t = 0, dur = 0.60, cx = cx, cy = cy, ring = ring and RING_STYLES[ring] or nil }
    if not reducedMotion() then
        local okC, CRT = pcall(require, "src.ui.CRTShader")
        if okC and CRT.jolt then CRT.jolt(0.16) end
    end
end

-- (k, cx, cy) do soco de zoom em px do MUNDO, ou nil.
function BossCinematic.worldZoom()
    if not hit or reducedMotion() then return nil end
    local k = clamp01(hit.t / 0.32)
    if k >= 1 then return nil end
    return 1 + 0.06 * math.sin(math.pi * k), hit.cx, hit.cy
end

local function drawScreenFx()
    local hf = BossCinematic.heartFlash and BossCinematic.heartFlash() or 0
    if hf > 0.01 then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local uk = require("src.ui.UiScale").activeK()
        for i, bw in ipairs({ 60, 30 }) do
            local b = math.floor(bw * uk)
            love.graphics.setColor(PAL.flash[1], PAL.flash[2], PAL.flash[3], hf * (0.5 * i))
            love.graphics.rectangle("fill", 0, 0, w, b)
            love.graphics.rectangle("fill", 0, h - b, w, b)
            love.graphics.rectangle("fill", 0, 0, b, h)
            love.graphics.rectangle("fill", w - b, 0, b, h)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    if not hit then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local t = hit.t
    local reduced = reducedMotion()
    local uk = require("src.ui.UiScale").activeK()
    local cx, cy = hit.cx / uk, hit.cy / uk
    local P = math.max(2, math.floor(2 * uk + 0.5))
    if not reduced then
        -- FLASH na cor do chefe, 3 degraus
        local fa = (t < 0.06) and 0.55 or ((t < 0.13) and 0.30 or ((t < 0.22) and 0.12 or 0))
        if fa > 0 then
            love.graphics.setColor(PAL.flash[1], PAL.flash[2], PAL.flash[3], fa)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
        -- ONDA DE CHOQUE: dois anéis de blocos, o de dentro atrasado
        for ring = 0, 1 do
            local rt = t - ring * 0.08
            if rt > 0 then
                local k = clamp01(rt / hit.dur)
                local r = easeOut(k) * w * 0.55
                local a = 1 - k
                local col = hit.ring and hit.ring[ring + 1]
                    or ((ring == 0) and PAL.ember or PAL.flash)
                local n = math.max(24, math.floor(2 * math.pi * r / P))
                for i = 0, n - 1 do
                    -- dither: cada bloco cai fora conforme o anel esvaece
                    if bayer(i, ring + math.floor(i / 4)) < a then
                        local ang = i / n * math.pi * 2
                        local bx = math.floor((cx + math.cos(ang) * r) / P) * P
                        local by = math.floor((cy + math.sin(ang) * r * 0.78) / P) * P
                        love.graphics.setColor(col[1], col[2], col[3], 0.85)
                        love.graphics.rectangle("fill", bx, by, P, P)
                    end
                end
            end
        end
    end
    -- VINHETA em bandas (3 molduras), esvaece com o tempo
    local va = (1 - clamp01(t / hit.dur)) * (reduced and 0.35 or 0.6)
    if va > 0.02 then
        for i, bw in ipairs({ 48, 28, 12 }) do
            love.graphics.setColor(0.05, 0.02, 0.08, va * (0.18 * i))
            local b = math.floor(bw * uk)
            love.graphics.rectangle("fill", 0, 0, w, b)
            love.graphics.rectangle("fill", 0, h - b, w, b)
            love.graphics.rectangle("fill", 0, 0, b, h)
            love.graphics.rectangle("fill", w - b, 0, b, h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- OS OUTROS CHEFES — kinds por ELEMENTO. Todos desenham o chefe "fora do
-- lugar" com um clip PRÓPRIO (ownAnim: clip PixelLab do chefe se instalado,
-- senão o idle) e terminam exatamente onde o EnemyRenderer vai desenhá-lo
-- (stage.foot, medido pelo passe no canvas descartado). Tudo na grade:
-- blobs pontilhados, blocos, níveis em degraus.
-- ---------------------------------------------------------------------------
local function ownAnim(clip, dur)
    local id = seq and seq.bossId
    if not id then return nil end
    local key = id .. "/" .. tostring(clip)
    if ownAnims[key] then return ownAnims[key] end
    local a
    if clip and SpriteAnimation.exists(id, clip, "south") then
        a = SpriteAnimation.new(id, clip, "south", 10, { loop = false })
        if dur and a then
            -- o clip ocupa o passo inteiro
            a.fps = math.max(2, a:getFrameCount() / dur)
            a.frameTime = 1 / a.fps
        end
    else
        local spec = EnemyPoses.get and EnemyPoses.get(id) or nil
        a = SpriteAnimation.new(id, "idle", "south", (spec and spec.idle and spec.idle.fps) or 8)
    end
    ownAnims[key] = a
    return a
end

-- posição/escala reais do chefe no palco (do passe de medição)
local function footInfo()
    if not (stage and stage.foot and stage.foot.drawX) then return nil end
    return stage.foot.drawX, stage.foot.drawY, stage.foot.scale
end

local function drawOwn(anim, x, y, s, tint, rimA)
    if not anim then return end
    anim:draw(x, y, s, tint or { 1, 1, 1, 1 })
    if rimA and rimA > 0 then
        love.graphics.setBlendMode("add")
        anim:draw(x, y, s, { PAL.rim[1], PAL.rim[2], PAL.rim[3], rimA })
        love.graphics.setBlendMode("alpha")
    end
end

-- anel pontilhado (corona do eclipse, runas): blocos na grade, dither no esvaecer
local function dotRing(cx, cy, r, ry, P, col, a)
    local n = math.max(16, math.floor(2 * math.pi * r / P))
    for i = 0, n - 1 do
        if bayer(i, math.floor(i / 4)) < a then
            local ang = i / n * math.pi * 2
            love.graphics.setColor(col[1], col[2], col[3], 0.9)
            love.graphics.rectangle("fill", math.floor((cx + math.cos(ang) * r) / P) * P,
                math.floor((cy + math.sin(ang) * ry) / P) * P, P, P)
        end
    end
end

local RUNE_GLYPHS = {
    { ".#.", "###", ".#.", "#.#", "#.#" }, { "#.#", ".#.", "###", ".#.", "#.#" },
    { "###", "#..", "##.", "#..", "###" }, { ".#.", "#.#", ".#.", "#.#", ".#." },
    { "#.#", "###", "#.#", ".#.", ".#." },
}

-- Runas no chão em volta do palco: bloco = ~1.6 px da ARTE do salão (3×5
-- blocos por glifo, legível a 1080p), halo em blob, e o círculo pontilhado
-- que as liga fecha quando todas acenderam — e FICA aceso durante a subida
-- (o passo seguinte é que o apaga, ver `land`).
local function drawRunes()
    local r = fx.runes
    if not r or not stage or not stage.bbox then return end
    local P = px()
    local B = math.max(P, math.floor(((stage.tr and stage.tr.scale) or 4) * 1.6 + 0.5))
    local cx, cy = stage.bbox.cx, (stage.cy or stage.bbox.bottomY)
    local rx = math.max(80, (stage.bbox.width or 120) * 1.1)
    local ry = rx * 0.22
    for i = 1, r.n do
        local lit = clamp01((r.t - (i - 1) * r.dur / r.n) / 0.25)
        if lit > 0 then
            local ang = -math.pi / 2 + (i - 1) / r.n * math.pi * 2
            local gx = math.floor((cx + math.cos(ang) * rx) / B) * B
            local gy = math.floor((cy + math.sin(ang) * ry) / B) * B
            local glyph = RUNE_GLYPHS[1 + (i - 1) % #RUNE_GLYPHS]
            local pulse = 0.75 + 0.25 * math.sin(r.t * 6 + i)
            glowBlob(gx, gy, 14 * B, 9 * B, PAL.glow, 0.60 * lit * pulse, 1 + i % 3)
            glowBlob(gx, gy, 7 * B, 5 * B, PAL.ember, 0.35 * lit * pulse, 3)
            for row = 1, 5 do
                for col = 1, 3 do
                    if glyph[row]:sub(col, col) == "#" then
                        love.graphics.setColor(PAL.ember[1], PAL.ember[2], PAL.ember[3], lit)
                        love.graphics.rectangle("fill", gx + (col - 2) * B, gy + (row - 3) * B, B, B)
                    end
                end
            end
        end
    end
    -- o círculo que liga as runas fecha quando todas acenderam
    local all = clamp01((r.t - r.dur) / 0.4 + 1)
    if r.t > r.dur * 0.9 then
        local breathe = 0.8 + 0.2 * math.sin(r.t * 4)
        dotRing(cx, cy, rx, ry, P, PAL.glow, 0.75 * all * breathe)
        dotRing(cx, cy, rx + 3 * P, ry + 2 * P, P, PAL.ember, 0.35 * all * breathe)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawRise(w, h)
    local r = fx.riser
    local dx, dy, s = footInfo()
    if not r or not dx or not r.anim then return end
    local k = clamp01(r.t / r.dur)
    local e = easeOut(k)
    local iw, ih = r.anim:getSize()
    local sw, sh = iw * s, ih * s
    local x = dx
    local y = dy + sh * (1 - e)
    local floorY = math.floor((stage.cy or (dy + sh)) + 2)
    -- brilho do elemento atrás do corpo e vapor na linha do chão
    glowBlob(x + sw / 2, y + sh * 0.5, sw * 1.7, sh * 1.1, PAL.glow, 0.35 * e, 2)
    for i = -2, 2 do
        glowBlob(x + sw / 2 + i * sw * 0.22, floorY - 6, sw * 0.5, sh * 0.16, PAL.glow,
            0.28 * (0.7 + 0.3 * math.sin(r.t * 13 + i)), 1 + (i + 2) % 3)
    end
    -- RECORTE NA LINHA DO CHÃO: o que está abaixo do piso ainda não existe
    local sx, sy, sww, shh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, 0, w, floorY)
    drawOwn(r.anim, x, y, s, { 1, 1, 1, 1 }, 0.25 * (1 - e) + 0.08)
    if sx then love.graphics.setScissor(sx, sy, sww, shh) else love.graphics.setScissor() end
end

local function drawWalk(w, h)
    local wk = fx.walker
    local dx, dy, s = footInfo()
    if not wk or not dx or not wk.anim then return end
    local k = clamp01(wk.t / wk.dur)
    local e = smooth(k)
    local iw, ih = wk.anim:getSize()
    local sk = s * (0.58 + 0.42 * e)
    local bodyCx = stage.bbox and stage.bbox.cx or (dx + iw * s / 2)
    local backY = stage.backY or ((stage.cy or dy + ih * s) - ih * s * 0.25)
    local groundY = lerp(backY, stage.cy or (dy + ih * s), e)
    local padBelow = (dy + ih * s) - (stage.cy or (dy + ih * s))
    local x = bodyCx - (bodyCx - dx) * (sk / s)
    local y = groundY + padBelow * (sk / s) - ih * sk
    -- sombra de contato cresce com ele
    love.graphics.setColor(0, 0, 0, 0.35 * e)
    love.graphics.ellipse("fill", bodyCx, groundY, iw * sk * 0.3, math.max(3, iw * sk * 0.05))
    glowBlob(bodyCx, y + ih * sk * 0.6, iw * sk * 1.5, ih * sk * 0.9, PAL.glow, 0.22, 2)
    drawOwn(wk.anim, x, y, sk, { 0.7 + 0.3 * e, 0.7 + 0.3 * e, 0.7 + 0.3 * e, 1 }, 0.12)
end

local function drawDescend(w, h)
    local d = fx.desc
    local dx, dy, s = footInfo()
    if not d or not dx or not d.anim then return end
    local k = clamp01(d.t / d.dur)
    local e = smooth(k)
    local tr = stage.tr
    local iw, ih = d.anim:getSize()
    local sw, sh = iw * s, ih * s
    local x0 = (tr and (tr.ox + d.u * 400 * tr.scale) or (w * d.u)) - sw / 2
    local y0 = (tr and (tr.oy + d.v * 256 * tr.scale) or (h * d.v)) - sh * 0.5
    local x, y = lerp(x0, dx, e), lerp(y0, dy, e) + math.sin(d.t * 2.2) * 3
    -- contraluz: preto na abertura, cor cheia ao pousar; asas com brilho de borda
    local lit = d.backlit and (0.08 + 0.92 * e) or 1
    glowBlob(x + sw / 2, y + sh * 0.5, sw * 1.9, sh * 1.3, PAL.glow, 0.30 * (1 - e * 0.5), 1)
    drawOwn(d.anim, x, y, s, { lit, lit, lit, 1 }, 0.3 * (1 - e) + 0.05)
end

local function drawSilhouette(w, h)
    local si = fx.sil
    local dx, dy, s = footInfo()
    if not si or not dx or not si.anim then return end
    local k = smooth(clamp01(si.t / si.dur))
    local sway = math.sin(si.t * 3) * 2
    drawOwn(si.anim, dx + sway, dy, s, { 0.02, 0.03, 0.06, k }, 0)
end

local function drawFirewall(w, h)
    local f = fx.fire
    if not f or not stage or not stage.tr then return end
    local tr = stage.tr
    local env = math.min(clamp01(f.t / 0.4), clamp01((f.total - f.t) / 0.5))
    if env <= 0 then return end
    local S = tr.scale
    local n = 14
    for i = 0, n do
        local xa = (i / n) * 400
        local fl = 0.6 + 0.4 * math.sin(f.t * 9 + i * 1.7) * math.sin(f.t * 5.3 + i)
        local hh = f.h * 256 * (0.6 + 0.4 * fl)
        local x = tr.ox + xa * S
        local y = tr.oy + (f.v * 256 - hh * 0.5) * S
        glowBlob(x, y, 48 * S, hh * S, PAL.ember, 0.55 * env * fl, 1 + i % 3)
        glowBlob(x, y + hh * 0.3 * S, 30 * S, hh * 0.5 * S, { 1, 0.85, 0.4 }, 0.35 * env * fl, 3)
    end
    -- brilho de lava no chão
    glowBlob(w / 2, tr.oy + (f.v * 256 + 30) * S, w * 1.1, 40 * S, PAL.ember, 0.25 * env, 2)
end

local function drawChains(w, h)
    local c = fx.chains
    if not c then return end
    local P = px()
    for _, ch in ipairs(c.list) do
        local drop = easeOut(clamp01((c.t - ch.delay) / 0.4))
        if drop > 0 then
            -- elo = 2 blocos de largura × 3 de altura, claro/escuro alternando
            -- (1 bloco de largura lia como fio, não corrente)
            local len = math.floor(ch.len * drop / P) * P
            local sway = math.sin(c.t * 2.6 + ch.phase) * 10 * P * (1 - drop * 0.5)
            local link = 0
            for yy = 0, len, 3 * P do
                local k = yy / math.max(1, len)
                local x = math.floor((ch.x + sway * k) / P) * P
                local lit = (link % 2 == 0)
                love.graphics.setColor(0.30, 0.28, 0.32, 0.95)
                love.graphics.rectangle("fill", x - P, yy, 2 * P, 3 * P)
                love.graphics.setColor(lit and 0.66 or 0.48, lit and 0.62 or 0.46, lit and 0.66 or 0.50, 0.95)
                love.graphics.rectangle("fill", x - P, yy, 2 * P, P)
                love.graphics.rectangle("fill", x - P, yy + P, P, P)
                link = link + 1
            end
            -- gancho na ponta
            local hx = math.floor((ch.x + sway) / P) * P
            love.graphics.setColor(0.70, 0.66, 0.70, 0.95)
            love.graphics.rectangle("fill", hx - 2 * P, len, 4 * P, P)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawRoots()
    local r = fx.roots
    if not r or not stage or not stage.tr then return end
    local P = px()
    local tr = stage.tr
    local k = clamp01(r.t / r.dur)
    for _, root in ipairs(r.list) do
        local nseg = #root.pts - 1
        local grown = k * nseg
        for i = 1, nseg do
            local segK = clamp01(grown - (i - 1))
            if segK > 0 then
                local a, b = root.pts[i], root.pts[i + 1]
                local ex = lerp(a[1], b[1], segK)
                local ey = lerp(a[2], b[2], segK)
                local steps = math.max(2, math.floor(math.abs(ex - a[1]) / 2 + 1))
                for st2 = 0, steps do
                    local q = st2 / steps
                    local x = tr.ox + math.floor(lerp(a[1], ex, q)) * tr.scale
                    local y = tr.oy + math.floor(lerp(a[2], ey, q)) * tr.scale
                    love.graphics.setColor(PAL.particle[1], PAL.particle[2], PAL.particle[3], 1)
                    love.graphics.rectangle("fill", math.floor(x / P) * P, math.floor(y / P) * P, 2 * P, 2 * P)
                    if st2 % 2 == 0 then
                        love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], 0.6)
                        love.graphics.rectangle("fill", math.floor(x / P) * P, math.floor(y / P) * P, P, P)
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawEclipse(w, h)
    local e = fx.ecl
    if not e or not stage or not stage.tr then return end
    local tr = stage.tr
    local P = px()
    local k = clamp01(e.t / e.dur)
    local cx = tr.ox + e.u * 400 * tr.scale
    local cy = tr.oy + e.v * 256 * tr.scale
    local r = 14 * tr.scale * (1 + 0.15 * math.sin(e.t * 3))
    -- disco negro cobrindo + coroa pontilhada que respira
    love.graphics.setColor(0.02, 0.0, 0.04, 0.9 * smooth(k))
    love.graphics.circle("fill", cx, cy, r * 0.95, 24)
    dotRing(cx, cy, r + 2 * P, r + 2 * P, P, PAL.glow, 0.85 * smooth(k))
    dotRing(cx, cy, r + 6 * P, r + 5 * P, P, PAL.flash, 0.4 * smooth(k) * (0.6 + 0.4 * math.sin(e.t * 7)))
    glowBlob(cx, cy, r * 6, r * 4, PAL.glow, 0.35 * smooth(k), 2)
end

local function drawWhiteout()
    local wo = fx.white
    if not wo then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local level = wo.peak * smooth(clamp01(wo.t / (wo.dur * 0.5)))
    if wo.fade then level = level * (1 - smooth(clamp01(wo.fade.t / wo.fade.dur))) end
    wo.level = level
    if level <= 0.01 then return end
    -- 5 degraus (sem gradiente), teto 0.8: o salão nunca some de todo — a
    -- nevasca é TEXTURA (rajadas de névoa correndo), não uma chapa branca
    local q = math.min(0.82, math.floor(level * 5) / 5)
    love.graphics.setColor(0.90, 0.95, 1.0, q)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- RAJADAS: as texturas de névoa (3 degraus de alpha com dither) correndo
    -- da direita pra esquerda em duas camadas, azul-gelo sobre o branco e
    -- branco aditivo por cima — é o vento que se vê
    local imgs = ensureFog()
    local t = wo.t
    local gw = w * 0.42
    local gh = gw * (FOG_H / FOG_W)
    for layer = 1, 2 do
        local speed = (layer == 1) and 520 or 760
        local rows = (layer == 1) and 4 or 3
        for row = 0, rows - 1 do
            local y = h * (row + 0.5) / rows - gh / 2 + math.sin(t * 2.1 + row + layer) * gh * 0.15
            local off = (t * speed + row * gw * 0.47 + layer * 131) % (gw * 1.1)
            for i = -1, math.ceil(w / (gw * 1.1)) + 1 do
                local x = i * gw * 1.1 - off
                local img = imgs[1 + (i + row + layer) % 3]
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(0.62, 0.78, 0.96, 0.22 * level)
                love.graphics.draw(img, math.floor(x), math.floor(y), 0, gw / FOG_W, gh / FOG_H)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, 0.16 * level)
                love.graphics.draw(img, math.floor(x + gw * 0.3), math.floor(y + gh * 0.2), 0,
                    gw / FOG_W * 0.8, gh / FOG_H * 0.8)
            end
        end
    end
    love.graphics.setBlendMode("alpha")
    -- flocos: blocos azul-gelo esticados na direção do vento (riscos curtos)
    local P = px()
    for _, fl in ipairs(flakes) do
        local bx, by = math.floor(fl.x / P) * P, math.floor(fl.y / P) * P
        love.graphics.setColor(0.55, 0.72, 0.92, 0.85)
        love.graphics.rectangle("fill", bx, by, 3 * P, P)
        love.graphics.setColor(0.92, 0.97, 1.0, 0.95)
        love.graphics.rectangle("fill", bx, by, P, P)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- pulso do coração (vinheta da cor do chefe por batida) — na UI
function BossCinematic.heartFlash()
    local hb = fx.heart
    if not hb then return 0 end
    local ph = (hb.t * hb.rate) % 1
    return math.max(0, 1 - ph * 4) * 0.28
end

-- ---------------------------------------------------------------------------
-- GEOMETRIA DO RASANTE
-- ---------------------------------------------------------------------------
-- Canto superior esquerdo do sprite do rasante no parâmetro k (0..1).
-- `land=true`: termina EXATAMENTE onde o EnemyRenderer vai desenhar o chefe
-- (medido pelo passe no canvas descartado: stage.foot.drawX/drawY).
local function flyPos(f, k, w, h)
    local tr = stage and stage.tr
    local iw, ih = 0, 0
    if flyAnim then iw, ih = flyAnim:getSize() end
    -- passagens cada vez mais PERTO da câmera: `scale` multiplica o sprite
    local s = ((stage and stage.foot and stage.foot.scale) or 2) * (f.land and 1 or (f.scale or 1))
    local sw, sh = iw * s, ih * s
    local yArt = tr and (tr.oy + f.v * 256 * tr.scale) or (h * f.v)
    local x0 = (f.from == "left") and (-sw - w * 0.05) or (w + w * 0.05)
    local x1 = (f.from == "left") and (w + w * 0.05) or (-sw - w * 0.05)
    local y0 = yArt - sh * 0.5
    local y1 = y0
    if f.land and stage and stage.foot and stage.foot.drawX then
        x1 = stage.foot.drawX
        y1 = stage.foot.drawY
    end
    local e = f.land and (1 - (1 - k) ^ 2.4) or k
    local x = lerp(x0, x1, e)
    local y = lerp(y0, y1, e) + math.sin(math.pi * e) * (f.arc or 0) * h
    return x, y, sw, sh, s
end

-- ---------------------------------------------------------------------------
-- PASSOS
-- ---------------------------------------------------------------------------
local function remainingDuration(fromIdx)
    local s = 0
    for i = fromIdx, #seq.steps do s = s + (seq.steps[i].dur or 0) end
    return s
end

local function ensureFlyAnim(id)
    if flyAnim and flyAnimId == id then return end
    flyAnimId = id
    -- clip de MERGULHO (PixelLab, tools/pixellab_boss_cine.py) quando existe;
    -- senão o idle com as asas batendo bem mais rápido
    if SpriteAnimation.exists(id, "dive", "south") then
        flyAnim = SpriteAnimation.new(id, "dive", "south", 14)
        return
    end
    local spec = EnemyPoses.get and EnemyPoses.get(id) or nil
    local fps = (spec and spec.idle and spec.idle.fps) or 8
    flyAnim = SpriteAnimation.new(id, "idle", "south", fps * 2.6)
end

-- clip one-shot do chefe JÁ no palco (pouso, rugido) — só se instalado
local function bossClip(name, fps)
    local id = seq and seq.bossId
    if not id or not name then return false end
    if EnemyRenderer.hasClip and EnemyRenderer.hasClip(id, name) then
        EnemyRenderer.playClip(name, fps)
        return true
    end
    return false
end

local function enterStep(st)
    local kind = st.kind
    if kind == "dark" then
        darkEase = { from = dark, to = st.to or 0, t = 0, dur = math.max(0.01, st.dur or 0.3) }
    elseif kind == "eyes" then
        eyes = { u = st.u or 0.5, v = st.v or 0.4, size = st.size or 0.05,
                 blinks = st.blinks or {}, blinked = {}, t = 0, dur = st.dur or 2,
                 track = st.track ~= false }
        mistTarget(1, 1.2)
        play("bossEyesIgnite", nil)
        playLoop("bossEyesRumble")
    elseif kind == "flyby" then
        eyes = nil
        ensureFlyAnim(seq.bossId)
        fly = { from = st.from or "left", v = st.v or 0.4, ghosts = st.ghosts or 2,
                arc = st.arc or 0, land = st.land, lights = st.lights,
                scale = st.scale or 1, near = (st.scale or 1) > 1.2,
                t = 0, dur = math.max(0.05, st.dur or 0.5), startDark = dark, trail = {} }
        if st.lights then
            darkEase = { from = dark, to = st.lights, t = 0, dur = fly.dur }
        end
        mistGustDir = (fly.from == "left") and 1 or -1
        InteriorFX.gust(1.0, fly.dur + 0.35)
        -- whoosh na borda por onde ele ENTRA e, no fim, por onde sai
        edge = { side = fly.from, t = 0, dur = fly.dur + 0.25, out = (fly.from == "left") and "right" or "left" }
        stopLoop("bossEyesRumble")
        -- passagem perto da câmera soa mais grave e mais alta
        play("bossWingPass", "sceneRustle", (fly.near and 0.78 or 0.95) + love.math.random() * 0.12, 0)
        if st.caw then play("bossCrowsCaw", nil, 0.95, 0.08) end
    elseif kind == "land" then
        fly = nil
        fx.runes = nil
        bossHidden = false
        landed = true
        darkEase = { from = dark, to = 0, t = 0, dur = math.max(0.15, (st.dur or 0.5) * 0.6) }
        mistTarget(0.35, 0.45)
        edge = nil
        EnemyRenderer.triggerArrival()
        bossClip(st.clip or "land", 12)
        if _G.triggerShake and (st.shake or 0) > 0 then _G.triggerShake(st.shake, 0.38) end
        if _G.jiggleScreen and not seq.reduced then _G.jiggleScreen(1.0) end
        -- som do impacto por chefe (`sound`); corvos/penas só pra quem os tem
        play(st.sound or "bossLandImpact", "bootImpact")
        local crowsN = st.crows or 5
        if crowsN > 0 then
            queueSfx(0.45, "bossFeathersSettle", nil)
            queueSfx(0.15, "bossCrowsCaw", nil, 1.05)
        end
        if st.after then queueSfx(st.afterDelay or 0.4, st.after, nil) end
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local gy = stage.cy or stage.bbox.bottomY
            spawnDust(gx, gy, st.dust or 12, stage.bbox.width or 120)
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.45
            if crowsN > 0 then spawnCrows(gx, body, crowsN, 260) end
            startHit(gx, body, st.ring)
            -- lascas do impacto: pena (rei-carniça), lasca de gelo, brasa,
            -- esporo, pétala — `particle` do passo
            for _ = 1, (st.burst or 12) do
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120),
                    body + (love.math.random() - 0.5) * 40,
                    (love.math.random() - 0.5) * 60, -20 + love.math.random() * 10, st.particle)
            end
        end
        InteriorFX.gust(0.6, 0.5)
    elseif kind == "title" then
        mistTarget(0, 1.6)
        bossClip(st.clip or "roar", 10)
        play("bossRevealSting", "enemyBuffRoar")
        local id = seq.bossId
        local name = I18n.t("boss_cinematics." .. id .. ".name", nil,
            I18n.t("end_screen.enemy." .. id, nil, id))
        local epithet = I18n.t("boss_cinematics." .. id .. ".epithet", nil, "")
        local h = love.graphics.getHeight()
        local size = math.max(26, math.min(64, math.floor(h * 0.058)))
        title = { t = 0, dur = st.dur or 2, name = name, epithet = epithet, size = size,
                  dyna = DynaText.new({
                      text = require("src.i18n.TextCase").upper(name),
                      fontSize = size, pop_in = 0.32, pop_in_rate = 3.2,
                      bump = not seq.reduced, bump_phase = 0.42, bump_amount = 0.28,
                      bump_rate = 2.2,
                      colours = { { 0.95, 0.82, 0.52, 1 } }, shadow = true,
                  }) }
    elseif kind == "hud" then
        hudHidden = false
    elseif kind == "slowmo" then
        slowmo = { scale = st.scale or 0.35, dur = st.dur or 1.2, release = st.release or 0.3, t = 0 }
        play("bossDeathThud", nil, 0.9, 0.05)
    elseif kind == "burst" then
        local pk = st.particle or "feather"
        play(st.sound or "bossFeatherBurst", nil)
        if (st.crows or 0) > 0 then queueSfx(0.12, "bossCrowsFlee", nil) end
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.42
            for _ = 1, (st.feathers or st.n or 16) do
                local a = love.math.random() * math.pi * 2
                local sp = 60 + love.math.random() * 160
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120) * 0.6,
                    body + (love.math.random() - 0.5) * (stage.bbox.height or 200) * 0.5,
                    math.cos(a) * sp, math.sin(a) * sp * 0.6 - 40, pk)
            end
            if (st.crows or 0) > 0 then spawnCrows(gx, body, st.crows, 200) end
        end
    elseif kind == "desat" then
        desat = { peak = st.peak or 0.7, rise = st.rise or 0.4, fall = st.fall or 1.2,
                  total = remainingDuration(seq.idx), t = 0 }
    elseif kind == "hold" then
        -- o corpo fica, espólios esperam (holdsEnd); ambiente quieto por cima
        playLoop("bossHoldAmbience")
    elseif kind == "lava" then
        -- poça de lava cresce sob o corpo até o fim da morte (bolhas no update)
        fx.lava = { t = 0, dur = math.max(0.5, remainingDuration(seq.idx)), bubble = 0 }
    -- ===== outros chefes =====
    elseif kind == "runes" then
        fx.runes = { n = st.n or 5, t = 0, dur = math.max(0.3, st.dur or 1.5) }
        mistTarget(1, 1.0)
        for i = 1, fx.runes.n do
            queueSfx((i - 1) * fx.runes.dur / fx.runes.n, "bossRuneIgnite", "orbChannel", 0.9 + i * 0.05)
        end
    elseif kind == "rise" then
        fx.riser = { t = 0, dur = math.max(0.3, st.dur or 1.4), anim = ownAnim(st.clip, st.dur) }
        if st.storm then playLoop(st.storm) end
        InteriorFX.gust(0.8, fx.riser.dur)
        if _G.triggerShake then _G.triggerShake(4, fx.riser.dur) end
    elseif kind == "whiteout" then
        fx.white = { t = 0, dur = math.max(0.3, st.dur or 1.8), peak = st.peak or 0.9 }
        playLoop("bossBlizzard")
        InteriorFX.gust(1.0, st.dur or 1.8)
        mistTarget(0.8, 0.8)
    elseif kind == "silhouette" then
        fx.sil = { t = 0, dur = math.max(0.3, st.dur or 1.2), anim = ownAnim(st.clip, st.dur) }
    elseif kind == "settle" then
        if fx.white then fx.white.fade = { t = 0, dur = math.max(0.2, st.dur or 0.8) } end
        fx.sil = nil
        bossHidden = false
        landed = true
        stopLoop("bossBlizzard")
        mistTarget(0.3, st.dur or 0.8)
        play("bossIceCrackle", nil)
    elseif kind == "door_burst" then
        local tr = stage and stage.tr
        local gx = tr and (tr.ox + (st.u or 0.5) * 400 * tr.scale) or (stage and stage.w or 960) / 2
        local gy = tr and (tr.oy + (st.v or 0.5) * 256 * tr.scale) or (stage and stage.h or 540) / 2
        startHit(gx, gy)
        if _G.triggerShake then _G.triggerShake(st.shake or 18, 0.45) end
        play("bossDoorBurst", "castleGateMagic")
        darkEase = { from = dark, to = st.lights or 0.35, t = 0, dur = 0.4 }
        mistTarget(0.9, 0.5)
        for _ = 1, (st.debris or 16) do
            local a = -math.pi * (0.1 + 0.8 * love.math.random())
            local sp = 120 + love.math.random() * 260
            spawnFeather(gx + (love.math.random() - 0.5) * 60, gy + (love.math.random() - 0.5) * 40,
                math.cos(a) * sp, math.sin(a) * sp, "shard")
        end
        for _ = 1, 14 do
            spawnFeather(gx + (love.math.random() - 0.5) * 80, gy + (love.math.random() - 0.5) * 60,
                (love.math.random() - 0.5) * 80, -40 - love.math.random() * 60, "ember")
        end
    elseif kind == "firewall" then
        fx.fire = { t = 0, total = (st.dur or 1.4) + (st.hold or 0), v = st.v or 0.6, h = st.h or 0.3 }
        playLoop("bossHellfireWall")
        InteriorFX.gust(0.7, fx.fire.total)
    elseif kind == "chains" then
        local w = (stage and stage.w) or 1920
        fx.chains = { t = 0, list = {} }
        for i = 1, (st.n or 4) do
            fx.chains.list[i] = { x = w * (0.12 + 0.76 * (i - 0.5) / (st.n or 4)) + (love.math.random() - 0.5) * 40,
                                  len = (stage and stage.h or 1080) * (0.35 + love.math.random() * 0.3),
                                  delay = (i - 1) * 0.12, phase = love.math.random() * 6.28 }
        end
        play("bossChainsRattle", nil)
    elseif kind == "walk_in" then
        fx.walker = { t = 0, dur = math.max(0.4, st.dur or 1.8), anim = ownAnim(st.clip, st.dur),
                      stomp = st.stomp, nextStomp = st.stomp or 1e9 }
        if st.sound then play(st.sound, nil) end
    elseif kind == "heartbeat" then
        fx.heart = { t = 0, dur = (st.dur or 1.6) + (st.hold or 0), rate = st.rate or 2.0, nextBeat = 0 }
        if InteriorFX.pulseBoost then InteriorFX.pulseBoost(st.boost or 2.0, fx.heart.dur) end
        mistTarget(1, 1.0)
    elseif kind == "roots" then
        fx.roots = { t = 0, dur = math.max(0.4, st.dur or 1.2), list = {} }
        local ox, oy = (st.u or 0.5) * 400, (st.v or 0.62) * 256
        for i = 1, (st.n or 6) do
            local tx = 20 + (i - 0.5) / (st.n or 6) * 360 + (love.math.random() - 0.5) * 30
            local ty = 236 + love.math.random() * 16
            local pts = { { ox, oy } }
            for k = 1, 7 do
                local q = k / 7
                pts[#pts + 1] = { lerp(ox, tx, q) + (love.math.random() - 0.5) * 14 * q,
                                  lerp(oy, ty, q) + (love.math.random() - 0.5) * 5 }
            end
            fx.roots.list[i] = { pts = pts }
        end
        playLoop("bossRootsCrawl")
    elseif kind == "eclipse" then
        fx.ecl = { t = 0, dur = math.max(0.3, st.dur or 1.6), u = st.u or 0.5, v = st.v or 0.23 }
        darkEase = { from = dark, to = st.to or 0.9, t = 0, dur = fx.ecl.dur }
        playLoop("bossEclipseHum")
        mistTarget(1, 1.2)
    elseif kind == "descend" then
        fx.desc = { t = 0, dur = math.max(0.4, st.dur or 1.8), u = st.u or 0.5, v = st.v or 0.2,
                    backlit = st.backlit ~= false, anim = ownAnim(st.clip, st.dur) }
        play("bossDescendWings", nil)
        if st.lights then darkEase = { from = dark, to = st.lights, t = 0, dur = fx.desc.dur } end
    else
        if not warnedKind[kind or "nil"] then
            warnedKind[kind or "nil"] = true
            print("[BossCinematic] passo desconhecido '" .. tostring(kind) .. "' — pulado")
        end
    end
end

local function exitStep(st)
    if st.kind == "eyes" then eyes = nil; stopLoop("bossEyesRumble") end
    if st.kind == "flyby" then
        if st.land then
            -- pousou: o passo `land` assume; se não houver, mostra o chefe
            if not (seq.steps[seq.idx + 1] and seq.steps[seq.idx + 1].kind == "land") then
                bossHidden = false
                landed = true
            end
        end
        fly = nil
    end
    if st.kind == "title" then title = nil end
    if st.kind == "rise" then
        fx.riser = nil; bossHidden = false; landed = true
        if st.storm then stopLoop(st.storm) end
    end
    if st.kind == "walk_in" then fx.walker = nil; bossHidden = false; landed = true end
    if st.kind == "descend" then fx.desc = nil; bossHidden = false; landed = true
        stopLoop("bossEclipseHum") end
    -- runas ficam acesas até o chefe pousar (`land` as apaga)
    if st.kind == "roots" then stopLoop("bossRootsCrawl") end
    if st.kind == "firewall" and (st.hold or 0) == 0 then fx.fire = nil; stopLoop("bossHellfireWall") end
end

-- ---------------------------------------------------------------------------
-- UPDATE
-- ---------------------------------------------------------------------------
-- ctx.inHall: a cena de combate É o salão do chefe (só aí a morte do chefe
-- vira cinemática — o mini-boss também tem isBoss, mas luta na estrada).
function BossCinematic.update(dt, game, ctx)
    ctx = ctx or {}
    if not dummy and love.graphics and love.graphics.newCanvas then
        local ok, c = pcall(love.graphics.newCanvas, 4, 4)
        if ok then dummy = c end
    end

    -- MORTE do chefe no salão: detecta o acontecimento (Game._onEnemyDeath
    -- já encenou clip/som/shake; aqui entra a câmera lenta e o resto).
    if game and game.enemy and game.enemy.isBoss and game._deathHandled
        and ctx.inHall and not (seq and seq.phase == "death") then
        BossCinematic.startDeath(game)
    end

    if seq then
        seq.t = seq.t + dt
        local remaining = dt
        while seq and seq.idx <= #seq.steps do
            local st = seq.steps[seq.idx]
            if not st._entered then
                st._entered = true
                enterStep(st)
                if not seq then break end
            end
            local dur = st.dur or 0
            local need = dur - seq.stepT
            if remaining >= need then
                remaining = remaining - need
                seq.stepT = 0
                exitStep(st)
                seq.idx = seq.idx + 1
            else
                seq.stepT = seq.stepT + remaining
                remaining = 0
                break
            end
        end
        if seq and seq.idx > #seq.steps then finish() end
    end

    -- envelopes
    if darkEase then
        darkEase.t = darkEase.t + dt
        local k = clamp01(darkEase.t / darkEase.dur)
        dark = lerp(darkEase.from, darkEase.to, smooth(k))
        if k >= 1 then darkEase = nil end
    end
    if eyes then
        eyes.t = eyes.t + dt
        for i, bt in ipairs(eyes.blinks) do
            if not eyes.blinked[i] and eyes.t >= bt then
                eyes.blinked[i] = true
                play("bossBlinkClick", nil, 0.9 + love.math.random() * 0.2, 0)
            end
        end
    end
    for i = #sfxQueue, 1, -1 do
        local q = sfxQueue[i]
        q.t = q.t - dt
        if q.t <= 0 then
            play(q.code, q.fallback, q.pitch, 0)
            table.remove(sfxQueue, i)
        end
    end
    if edge then
        edge.t = edge.t + dt
        if edge.t >= edge.dur then edge = nil end
    end
    if fly then
        fly.t = fly.t + dt
        if flyAnim then flyAnim:update(dt) end
        -- rastro: posições recentes (cópias fantasmas = borrão de movimento)
        if stage then
            local x, y, sw, sh = flyPos(fly, clamp01(fly.t / fly.dur), stage.w, stage.h)
            local tr = fly.trail
            tr[#tr + 1] = { x = x, y = y, t = fly.t }
            if #tr > 12 then table.remove(tr, 1) end
            -- vento e penas saem da borda de trás da asa
            local dirX = (fly.from == "left") and 1 or -1
            local backX = (dirX > 0) and x or (x + sw)
            if not seq.reduced then
                -- riscos de velocidade: muitos, longos, pela faixa inteira do voo
                local nW = fly.near and 7 or 5
                for _ = 1, nW do
                    local wx = x + love.math.random() * sw
                    spawnWind(wx, y + sh * (0.1 + love.math.random() * 0.8), -dirX,
                        (60 + love.math.random() * 160) * (fly.scale or 1), fly.near)
                end
                if love.math.random() < 0.5 then
                    spawnFeather(backX + (love.math.random() - 0.5) * sw * 0.3,
                        y + sh * (0.3 + love.math.random() * 0.4),
                        -dirX * (40 + love.math.random() * 80), 10 + love.math.random() * 30)
                end
            end
        end
    end
    if title then
        title.t = title.t + dt
        title.dyna:update(dt)
    end
    if slowmo then
        slowmo.t = slowmo.t + dt
        local k
        if slowmo.t < slowmo.dur then
            k = slowmo.scale
        else
            local r = clamp01((slowmo.t - slowmo.dur) / math.max(0.01, slowmo.release))
            k = lerp(slowmo.scale, 1, smooth(r))
            if r >= 1 then slowmo = nil end
        end
        EnemyRenderer.setTimeScale(k)
    elseif not seq then
        EnemyRenderer.setTimeScale(1)
    end
    if desat then
        desat.t = desat.t + dt
        if desat.t >= desat.total then desat = nil end
    end

    -- kinds dos outros chefes
    if fx.runes then fx.runes.t = fx.runes.t + dt end
    if fx.riser then
        local r = fx.riser
        r.t = r.t + dt
        if r.anim then r.anim:update(dt) end
        -- a tempestade em volta do corpo que sobe: fagulhas do elemento
        -- (kind "ember" FLUTUA e usa PAL.ember — geada branca no lich) saindo
        -- da linha do chão, mais densas no começo da subida
        if stage and stage.bbox and not reducedMotion() then
            local n = (r.t < r.dur * 0.6) and 3 or 1
            local gy = stage.cy or stage.bbox.bottomY
            local wdt = (stage.bbox.width or 120) * 0.9
            for _ = 1, n do
                spawnFeather(stage.bbox.cx + (love.math.random() - 0.5) * wdt, gy - love.math.random() * 8,
                    (love.math.random() - 0.5) * 70, -60 - love.math.random() * 120, "ember")
            end
        end
    end
    if fx.sil then fx.sil.t = fx.sil.t + dt; if fx.sil.anim then fx.sil.anim:update(dt) end end
    if fx.white then
        fx.white.t = fx.white.t + dt
        if fx.white.fade then
            fx.white.fade.t = fx.white.fade.t + dt
            if fx.white.fade.t >= fx.white.fade.dur then fx.white = nil end
        end
        if fx.white and stage and not reducedMotion() then
            for _ = 1, 3 do
                flakes[#flakes + 1] = { x = love.math.random() * stage.w, y = -8,
                    vx = -120 - love.math.random() * 160, vy = 160 + love.math.random() * 200, life = 2 }
            end
        end
    end
    for i = #flakes, 1, -1 do
        local fl = flakes[i]
        fl.x = fl.x + fl.vx * dt; fl.y = fl.y + fl.vy * dt; fl.life = fl.life - dt
        if fl.life <= 0 or (stage and (fl.y > stage.h or fl.x < -20)) then table.remove(flakes, i) end
    end
    if fx.fire then
        fx.fire.t = fx.fire.t + dt
        if stage and not reducedMotion() and love.math.random() < 0.5 and stage.tr then
            local tr = stage.tr
            spawnFeather(tr.ox + love.math.random() * 400 * tr.scale,
                tr.oy + fx.fire.v * 256 * tr.scale, (love.math.random() - 0.5) * 30,
                -60 - love.math.random() * 80, "ember")
        end
        if fx.fire.t >= fx.fire.total then fx.fire = nil; stopLoop("bossHellfireWall") end
    end
    if fx.chains then fx.chains.t = fx.chains.t + dt end
    if fx.walker then
        local wk = fx.walker
        wk.t = wk.t + dt
        if wk.anim then wk.anim:update(dt) end
        if wk.stomp and wk.t >= wk.nextStomp then
            wk.nextStomp = wk.nextStomp + wk.stomp
            if _G.triggerShake then _G.triggerShake(7, 0.2) end
            play("sceneStoneThud", nil, 0.8, 0.1)
        end
    end
    if fx.heart then
        local hb = fx.heart
        hb.t = hb.t + dt
        if hb.t >= hb.nextBeat then
            hb.nextBeat = hb.nextBeat + 1 / hb.rate
            play("bossHeartbeat", nil, 0.95, 0.05)
            if _G.triggerShake and not reducedMotion() then _G.triggerShake(3, 0.12) end
        end
        if hb.t >= hb.dur then fx.heart = nil end
    end
    if fx.roots then fx.roots.t = fx.roots.t + dt end
    if fx.ecl then fx.ecl.t = fx.ecl.t + dt end
    if fx.lava then
        local lv = fx.lava
        lv.t = lv.t + dt
        -- bolhas de lava estourando na poça (brasas que sobem e apagam)
        lv.bubble = lv.bubble + dt
        if stage and stage.bbox and not reducedMotion() and lv.bubble > 0.09 then
            lv.bubble = 0
            local k = clamp01(lv.t / lv.dur)
            local wdt = (stage.bbox.width or 120) * (0.4 + 0.8 * k)
            spawnFeather(stage.bbox.cx + (love.math.random() - 0.5) * wdt,
                (stage.cy or stage.bbox.bottomY) - love.math.random() * 6,
                (love.math.random() - 0.5) * 30, -30 - love.math.random() * 60, "ember")
        end
    end
    if fx.desc then fx.desc.t = fx.desc.t + dt; if fx.desc.anim then fx.desc.anim:update(dt) end end
    updateMist(dt)
    if hit then
        hit.t = hit.t + dt
        if hit.t >= hit.dur then hit = nil end
    end
    updateFx(dt)
end

-- Envelope da dessaturação (0..1).
function BossCinematic.desatAmount()
    if not desat then return 0 end
    local t = desat.t
    local up = clamp01(t / math.max(0.01, desat.rise))
    local downStart = math.max(desat.rise, desat.total - desat.fall)
    local down = (t > downStart) and clamp01((t - downStart) / math.max(0.01, desat.fall)) or 0
    return desat.peak * smooth(up) * (1 - smooth(down))
end

-- ---------------------------------------------------------------------------
-- MEDIÇÃO: desenha o chefe num canvas descartado (nada chega à tela) e
-- devolve o que a função devolver (o bbox do EnemyRenderer.draw).
-- ---------------------------------------------------------------------------
function BossCinematic.measure(drawFn)
    if not dummy then return nil end
    local prev = love.graphics.getCanvas()
    love.graphics.setCanvas(dummy)
    local ok, res = pcall(drawFn)
    if prev then love.graphics.setCanvas(prev) else love.graphics.setCanvas() end
    love.graphics.setColor(1, 1, 1, 1)
    if not ok then
        print("[BossCinematic] medição falhou: " .. tostring(res))
        return nil
    end
    return res
end

-- ---------------------------------------------------------------------------
-- PASSE DE DESSATURAÇÃO (mundo → canvas → shader)
-- ---------------------------------------------------------------------------
local function ensureDesatShader()
    if desatShader or desatTried then return desatShader end
    desatTried = true
    local ok, sh = pcall(love.graphics.newShader, "shaders/desat.glsl")
    if ok then desatShader = sh else
        print("[BossCinematic] shaders/desat.glsl não carregou: " .. tostring(sh)
            .. " — morte sem dessaturação")
    end
    return desatShader
end

local worldPrev = nil
-- Chamado DENTRO do UiScale.outside (transform identidade da janela real).
-- Devolve true quando o mundo está sendo capturado.
function BossCinematic.beginWorldPass()
    local amt = BossCinematic.desatAmount()
    if amt <= 0.005 then return false end
    if not ensureDesatShader() then return false end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if not worldCanvas or worldCanvas:getWidth() ~= w or worldCanvas:getHeight() ~= h then
        local ok, c = pcall(love.graphics.newCanvas, w, h)
        if not ok then return false end
        worldCanvas = c
        worldCanvas:setFilter("nearest", "nearest")
    end
    worldPrev = love.graphics.getCanvas()
    love.graphics.setCanvas(worldCanvas)
    love.graphics.clear(0, 0, 0, 1)
    return true
end

function BossCinematic.endWorldPass()
    if worldPrev then love.graphics.setCanvas(worldPrev) else love.graphics.setCanvas() end
    worldPrev = nil
    desatShader:send("amount", BossCinematic.desatAmount())
    love.graphics.setShader(desatShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(worldCanvas, 0, 0)
    love.graphics.setShader()
end

-- ---------------------------------------------------------------------------
-- DRAW — mundo (atrás do chefe)
-- ---------------------------------------------------------------------------
-- Olho = amêndoa de 8×5 blocos (pixel da arte do salão), pupila em fenda,
-- halo aditivo. Abre do meio (fenda → cheio), pisca fechando as fileiras.
-- OLHOS v3 (dono: "mais detalhe, aterrorizante"): amêndoa 12×7 com aro de
-- brasa escura, íris laranja, núcleo claro; pupila em FENDA que ACOMPANHA
-- (deriva lenta + sacadas), halo em blob pontilhado, calor subindo em
-- blobs finos tremendo, rumor grave enquanto estão abertos (loop) e clique
-- a cada piscada. Abrem DEVAGAR do meio (fenda → cheio).
local EYE_ROWS = {
    "...######...",
    ".##iiiiii##.",
    "#iiccccccii#",
    "#icc....cci#",
    "#iiccccccii#",
    ".##iiiiii##.",
    "...######...",
}
local EYE_RIM  = { 0.72, 0.26, 0.06 }
local EYE_IRIS = { 1.00, 0.58, 0.14 }
local function drawEyes(w, h)
    if not eyes or not stage or not stage.tr then return end
    local tr = stage.tr
    local B = math.max(2, math.floor(eyes.size * 256 * tr.scale / 12 + 0.5))
    local ex = tr.ox + eyes.u * 400 * tr.scale
    local ey = tr.oy + eyes.v * 256 * tr.scale
    local t = eyes.t
    -- abertura LENTA (0.6s) do meio; piscadas = sino de 0.12s; fecha no fim
    local open = smooth(clamp01(t / 0.6))
    for _, bt in ipairs(eyes.blinks) do
        local d = math.abs(t - bt)
        if d < 0.12 then open = math.min(open, d / 0.12) end
    end
    local closing = eyes.dur - t
    if closing < 0.18 then open = math.min(open, clamp01(closing / 0.18)) end
    local rows = math.floor(open * 7 + 0.5)
    if rows <= 0 then return end
    local glow = 0.80 + 0.20 * math.sin(t * 7.3)
    -- PUPILA acompanha: deriva senoidal lenta + sacada ocasional (hash do tempo)
    local track = 0
    if eyes.track then
        local saccade = math.floor(t * 0.9) % 3 - 1
        track = math.floor(1.6 * math.sin(t * 0.8) + saccade * 0.6 + 0.5)
        track = math.max(-2, math.min(2, track))
    end
    local gap = 17 * B
    local ew, eh = 12 * B, 7 * B
    local lo = 4 - math.floor((rows - 1) / 2)
    local hi = 4 + math.floor(rows / 2)
    for side = -1, 1, 2 do
        local cx = math.floor(ex + side * gap / 2)
        local x0, y0 = cx - ew / 2, ey - eh / 2
        -- halo pontilhado + CALOR subindo (blobs finos tremendo acima do olho)
        local ha = 0.6 * glow * (rows / 7)
        glowBlob(cx, ey, ew * 3.0, eh * 3.2, EYE_HALO, ha * 0.5, 1 + (side + 1) / 2)
        glowBlob(cx, ey, ew * 1.7, eh * 1.9, EYE_CORE, ha * 0.4, 3)
        if not reducedMotion() then
            for k = 0, 2 do
                local rise = ((t * 22 + k * 11) % 34)
                local wob = math.sin(t * 9 + k * 2.1) * 2 * B
                glowBlob(cx + wob, ey - eh * 0.6 - rise, ew * (0.9 - k * 0.15), eh * 0.5,
                    EYE_HALO, ha * 0.22 * (1 - rise / 34), 1 + k)
            end
        end
        for r = lo, hi do
            local line = EYE_ROWS[r]
            for c = 1, 12 do
                local ch = line:sub(c, c)
                if ch ~= "." then
                    local col
                    if ch == "#" then col = EYE_RIM
                    elseif ch == "i" then col = EYE_IRIS
                    else col = EYE_CORE end
                    love.graphics.setColor(col[1], col[2] * (0.9 + 0.1 * glow), col[3], 1)
                    love.graphics.rectangle("fill", x0 + (c - 1) * B, y0 + (r - 1) * B, B, B)
                end
            end
        end
        -- pupila: fenda vertical de 2 blocos, deslocada pelo rastreio
        local pc = 6 + track
        love.graphics.setColor(0.22, 0.04, 0.02, 1)
        for r = math.max(lo, 2), math.min(hi, 6) do
            love.graphics.rectangle("fill", x0 + (pc - 1) * B, y0 + (r - 1) * B, 2 * B, B)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Olhos do chefe no sprite (fração do canvas), pra acendê-los no rasante.
local EYE_ANCHORS = { { 0.435, 0.24 }, { 0.545, 0.24 } }

local function drawFly(w, h)
    if not fly or not flyAnim or not stage then return end
    local k = clamp01(fly.t / fly.dur)
    local x, y, sw, sh, s = flyPos(fly, k, w, h)
    local tr = fly.trail
    local n = fly.ghosts or 0
    -- RASTRO: blobs de névoa aditiva (violeta, uma brasa de vez em quando)
    -- deixados ao longo do caminho — a trilha do voo é nebulosa, sem
    -- retângulo nem quadro visível (revisão do dono: "efeito de túnel")
    for i = 1, #tr, 2 do
        local p = tr[i]
        local a = 0.26 * (i / #tr)
        local col = (i % 6 == 1) and PAL.ember or PAL.glow
        glowBlob(p.x + sw * 0.5, p.y + sh * 0.5, sw * 1.15, sh * 0.75, col, a, 1 + i % 3)
    end
    love.graphics.setBlendMode("add")
    -- fantasmas: cópias ATRÁS no tempo, claras (violeta de corvo em aditivo).
    -- Perto da câmera o atraso é de 1 quadro: o vulto fica "borrado".
    local lag = fly.near and 1 or 2
    for g = n, 1, -1 do
        local p = tr[#tr - g * lag]
        if p then
            local a = (fly.near and 0.5 or 0.55) * (1 - (g - 1) / math.max(1, n))
            flyAnim:draw(p.x, p.y, s, { PAL.ghost[1] + 0.15, PAL.ghost[2] + 0.1, PAL.ghost[3] + 0.15, a })
        end
    end
    -- RIM LIGHT: a silhueta deslocada em 4 direções, aditiva, antes do corpo
    local P = math.max(1, math.floor(s + 0.5))
    for _, off in ipairs({ { -P, 0 }, { P, 0 }, { 0, -P }, { 0, P } }) do
        flyAnim:draw(x + off[1], y + off[2], s, { PAL.rim[1], PAL.rim[2], PAL.rim[3], 0.32 })
    end
    love.graphics.setBlendMode("alpha")
    -- o chefe em si, AUTO-ILUMINADO (não escurece com o salão) + brilho
    -- próprio aditivo (a silhueta, de novo, em violeta-branco fraco)
    flyAnim:draw(x, y, s, { 1, 0.98, 1.04, 1 })
    love.graphics.setBlendMode("add")
    flyAnim:draw(x, y, s, { 0.55, 0.45, 0.80, 0.22 })
    -- olhos acesos (blobs de brasa nas âncoras dos olhos)
    love.graphics.setBlendMode("alpha")
    local glow = 0.8 + 0.2 * math.sin(fly.t * 23)
    for _, e in ipairs(EYE_ANCHORS) do
        local ex = x + e[1] * sw
        local ey = y + e[2] * sh
        glowBlob(ex, ey, 10 * P, 6 * P, EYE_HALO, 0.6 * glow, 2)
        glowBlob(ex, ey, 5 * P, 3 * P, EYE_CORE, 0.9 * glow, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- WHOOSH DE BORDA: blobs de névoa empilhados na borda por onde o vulto
-- entra (e, no fim, por onde sai) — a tela "sente" a passagem.
local function drawEdge(w, h)
    if not edge or reducedMotion() then return end
    local k = clamp01(edge.t / edge.dur)
    local env = (k < 0.35) and (k / 0.35) or (1 - (k - 0.35) / 0.65)
    local a = 0.30 * math.max(0, env)
    local side = (k < 0.5) and edge.side or edge.out
    local cx = (side == "left") and (w * 0.04) or (w * 0.96)
    for i = 0, 3 do
        glowBlob(cx + (love.math.random() - 0.5) * 8, h * (0.15 + i * 0.23),
            w * 0.22, h * 0.34, PAL.glow, a * (0.8 + 0.2 * math.sin(edge.t * 31 + i)), 1 + i % 3)
    end
end

-- RISCOS DE VELOCIDADE: linhas na grade da arte, claras, que esmaecem em
-- 3 degraus (a ponta de trás some primeiro — lê como rastro, não régua)
local function drawWind()
    local P = px()
    for _, wv in ipairs(wind) do
        local k = wv.life / wv.max
        local th = wv.thick and 2 * P or P
        local len = math.floor(wv.len * (0.4 + 0.6 * k) / P) * P
        local x0 = (wv.vx < 0) and (wv.x - len) or wv.x
        local y = math.floor(wv.y / P) * P
        -- 3 segmentos: cabeça clara, meio, cauda fraca
        local seg = math.max(P, math.floor(len / 3 / P) * P)
        for i = 0, 2 do
            local a = (0.75 - i * 0.22) * k
            love.graphics.setColor(WIND_COLOR[1], WIND_COLOR[2], WIND_COLOR[3], a)
            local sx = (wv.vx < 0) and (x0 + len - (i + 1) * seg) or (x0 + i * seg)
            love.graphics.rectangle("fill", math.floor(sx), y, seg, th)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFeathers()
    local P = px()
    for _, f in ipairs(feathers) do
        local a = clamp01(f.life / f.max * 1.6)
        local c = f.light and PAL.particle2 or PAL.particle
        local kind = f.kind or "feather"
        if kind == "ember" or kind == "spore" then
            -- 1 bloco (brasa quente / esporo fosco) + halo aditivo pequeno
            local col = (kind == "ember") and PAL.ember or PAL.glow
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), P, P)
            if kind == "ember" then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(col[1], col[2], col[3], a * 0.35)
                love.graphics.rectangle("fill", math.floor(f.x) - P, math.floor(f.y) - P, 3 * P, 3 * P)
                love.graphics.setBlendMode("alpha")
            end
        elseif kind == "petal" then
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), 2 * P, 2 * P)
            love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], a * 0.8)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), P, P)
        else
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.push()
            love.graphics.translate(math.floor(f.x), math.floor(f.y))
            love.graphics.rotate(f.rot)
            if kind == "shard" then
                -- lasca = 2 blocos em diagonal, clara
                love.graphics.rectangle("fill", -P, -P * 0.5, P, P)
                love.graphics.rectangle("fill", 0, -P * 0.5, P, P)
            else
                -- pena = diagonal de 3 blocos que tomba (traço reto lê como glitch)
                love.graphics.rectangle("fill", -P * 1.5, -P * 0.5, P, P)
                love.graphics.rectangle("fill", -P * 0.5, -P * 0.5, P, P)
                love.graphics.rectangle("fill", P * 0.5, -P * 0.5, P, P)
            end
            love.graphics.pop()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDust()
    local P = px()
    for _, d in ipairs(dust) do
        local a = clamp01(d.life / d.max)
        love.graphics.setColor(0.62, 0.56, 0.48, 0.6 * a)
        local n = (a > 0.5) and 2 or 1
        love.graphics.rectangle("fill", math.floor(d.x), math.floor(d.y) - P * n, P * n, P * n)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Silhueta de corvo de frente ("m" de 3 quadros), em blocos da arte.
local CROW_FRAMES = {
    { "#.....#", ".#...#.", "..###..", "...#..." },      -- asas em cima
    { ".......", "###.###", "...#...", "...#..." },      -- planando
    { ".......", "...#...", ".##.##.", "#.....#" },      -- asas embaixo
}
local function drawCrows()
    local P = px()
    for _, c in ipairs(crows) do
        local fr = CROW_FRAMES[1 + (math.floor(c.flap) % 3)]
        local a = clamp01(c.life / c.max * 1.4)
        for row, line in ipairs(fr) do
            for col = 1, #line do
                if line:sub(col, col) == "#" then
                    local sheen = (row == 2) and (col == 2 or col == 6)
                    local col2 = sheen and CROW_SHEEN or CROW_BODY
                    love.graphics.setColor(col2[1], col2[2], col2[3], a)
                    love.graphics.rectangle("fill",
                        math.floor(c.x + (col - 4) * P), math.floor(c.y + (row - 2) * P), P, P)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Atrás do chefe: escuridão, olhos, rasante com rastro, vento, penas em voo.
function BossCinematic.drawBack()
    local w = (stage and stage.w) or love.graphics.getWidth()
    local h = (stage and stage.h) or love.graphics.getHeight()
    if dark > 0.002 then
        love.graphics.setColor(0.01, 0.005, 0.01, dark)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    if not stage then return end
    drawMist({ [1] = true })
    drawRoots()
    drawRunes()
    drawFirewall(w, h)
    drawEclipse(w, h)
    drawEyes(w, h)
    drawMist({ [2] = true })
    drawWalk(w, h)
    drawRise(w, h)
    drawDescend(w, h)
    drawWind()
    drawFly(w, h)
    drawEdge(w, h)
    if seq and seq.phase == "intro" then drawFeathers() end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Na frente do chefe: poeira do pouso, corvos espantados, penas da morte.
-- Poça de lava engolindo o corpo (morte do tirano): blobs de brasa na
-- linha do chão, crescendo com o tempo, núcleo mais claro tremendo —
-- na FRENTE do corpo, pra cobrir a base dele.
local function drawLavaPool()
    local lv = fx.lava
    if not lv or not stage or not stage.bbox then return end
    local k = smooth(clamp01(lv.t / lv.dur))
    local cx = stage.bbox.cx
    local cy = (stage.cy or stage.bbox.bottomY)
    local wdt = (stage.bbox.width or 120) * (0.5 + 1.1 * k)
    local hgt = (stage.bbox.height or 200) * (0.08 + 0.22 * k)
    local fl = 0.85 + 0.15 * math.sin(lv.t * 9)
    glowBlob(cx, cy - hgt * 0.15, wdt * 1.3, hgt * 1.6, PAL.glow, 0.45 * k * fl, 1)
    glowBlob(cx, cy - hgt * 0.2, wdt, hgt, PAL.ember, 0.55 * k * fl, 2)
    glowBlob(cx + math.sin(lv.t * 3) * wdt * 0.1, cy - hgt * 0.25, wdt * 0.5, hgt * 0.6,
        { 1, 0.92, 0.6 }, 0.35 * k * fl, 3)
end

function BossCinematic.drawFront()
    if not stage then return end
    drawMist({ [3] = true })
    drawChains(stage.w, stage.h)
    drawLavaPool()
    drawDust()
    if not (seq and seq.phase == "intro") then drawFeathers() end
    drawCrows()
    -- nevasca por cima de tudo do mundo, e a silhueta DENTRO do branco
    drawWhiteout()
    drawSilhouette(stage.w, stage.h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- DRAW — UI (cartão de nome + dica de pular)
-- ---------------------------------------------------------------------------
local function titleAlpha()
    if not title then return 0 end
    local t, d = title.t, title.dur
    if t < 0.25 then return smooth(t / 0.25) end
    if t > d - 0.45 then return 1 - smooth(clamp01((t - (d - 0.45)) / 0.45)) end
    return 1
end

function BossCinematic.drawUI()
    drawScreenFx()
    if not seq then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if title then
        local a = titleAlpha()
        local cy = math.floor(h * 0.80)
        local lineW = math.floor(w * 0.34)
        -- faixa de tinta atrás (sépia), fina
        love.graphics.setColor(0.07, 0.05, 0.04, 0.72 * a)
        love.graphics.rectangle("fill", 0, cy - title.size * 1.05, w, title.size * 2.55)
        -- linhas de ouro envelhecido com losango-guarda
        love.graphics.setColor(0.72, 0.58, 0.32, 0.9 * a)
        local ly = cy + title.size * 0.75
        love.graphics.rectangle("fill", math.floor(w / 2 - lineW / 2), ly, lineW, 2)
        for side = -1, 1, 2 do
            local gx = math.floor(w / 2 + side * (lineW / 2 + 10))
            love.graphics.polygon("fill", gx, ly - 3, gx + 4, ly + 1, gx, ly + 5, gx - 4, ly + 1)
        end
        -- NOME (DynaText: pop_in em cascata, ondulação discreta)
        love.graphics.setColor(1, 1, 1, a)
        title.dyna.colours[1][4] = a
        title.dyna:draw(w / 2, cy)
        -- EPÍTETO, abaixo, em vermelho-pergaminho, chega um pouco depois
        if title.epithet ~= "" then
            local ea = a * smooth(clamp01((title.t - 0.35) / 0.3))
            local font = FontManager.getFont(math.max(12, math.floor(title.size * 0.42)))
            love.graphics.setFont(font)
            local tw = font:getWidth(title.epithet)
            local ty = ly + 8
            love.graphics.setColor(0, 0, 0, 0.7 * ea)
            love.graphics.print(title.epithet, math.floor(w / 2 - tw / 2) + 1, ty + 1)
            love.graphics.setColor(0.95, 0.58, 0.45, ea)
            love.graphics.print(title.epithet, math.floor(w / 2 - tw / 2), ty)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- dica de pular: pequena, canto inferior direito, só depois de SKIP_AFTER
    if BossCinematic.canSkip() then
        local k = clamp01((seq.t - BossCinematic.SKIP_AFTER) / 0.4)
        local NavCursor = require("src.ui.NavCursor")
        local dev = NavCursor.device and NavCursor.device() or "mouse"
        local glyph = (dev == "pad") and NavCursor.PAD_LABEL.confirm
            or NavCursor.KEY_LABEL.confirm
        local text = I18n.t("boss_cinematics.skip", { key = glyph }, "")
        local font = FontManager.getFont(math.max(10, math.floor(h * 0.016)))
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local x, y = w - tw - 18, h - font:getHeight() - 14
        love.graphics.setColor(0, 0, 0, 0.6 * k)
        love.graphics.print(text, x + 1, y + 1)
        love.graphics.setColor(0.85, 0.78, 0.62, 0.75 * k)
        love.graphics.print(text, x, y)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ---------------------------------------------------------------------------
-- OVERLAY do InputFocus: enquanto a cinemática toca, a entrada é dela.
-- ---------------------------------------------------------------------------
BossCinematic.overlay = {
    ownsNavigation = true,
    isVisible = function() return seq ~= nil end,
    -- voltar ao menu / abandonar: a cinemática morre junto
    hide = function() BossCinematic.reset() end,
}
function BossCinematic.overlay:keypressed(key)
    if key == "escape" then
        if _G.togglePauseMenu then _G.togglePauseMenu() end
        return true
    end
    if key == "return" or key == "kpenter" or key == "space" then
        BossCinematic.skip()
        return true
    end
    return false
end
function BossCinematic.overlay:mousepressed(_, _, button)
    if button == 1 then BossCinematic.skip() end
    return true
end
function BossCinematic.overlay:mousereleased() return true end
function BossCinematic.overlay:wheelmoved() return true end

return BossCinematic
