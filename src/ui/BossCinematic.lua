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
                              title = true, hud = true }
BossCinematic.DEATH_KINDS = { slowmo = true, burst = true, desat = true, hold = true }

-- Sons (audio/sfx/boss/, registrados sob demanda; fallback por Sfx.has).
local SOUNDS = {
    bossEyesIgnite  = { "audio/sfx/boss/boss_eyes_ignite.mp3",  0.70 },
    bossWingPass    = { "audio/sfx/boss/boss_wing_pass.mp3",    0.80 },
    bossRevealSting = { "audio/sfx/boss/boss_reveal_sting.mp3", 0.85 },
}
local soundsLoaded = false

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
local spawnMist        -- definida na seção NÉVOA (startIntro fica acima dela)
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
            a:loadSound(code, spec[1], spec[2])
        end
    end
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

local function begin(phase, steps, bossId, reduced)
    loadSounds()
    seq = { phase = phase, steps = copySteps(steps), idx = 1, stepT = 0, t = 0,
            bossId = bossId, reduced = reduced }
end

-- ENTRADA GENÉRICA — chefe SEM roteiro próprio (chefe novo que ainda não
-- ganhou o dele). O salão abre VAZIO, um compasso de escuro, o chefe aparece
-- no palco com impacto, cartão com o nome. Nunca mais "luta como antes" com
-- a mão já na tela (bug do dono, Out/2026).
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
    begin("intro", steps, id, reduced)
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
             mist = mist, hit = hit,
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

local function spawnFeather(x, y, vx, vy)
    feathers[#feathers + 1] = {
        x = x, y = y, vx = vx, vy = vy,
        rot = love.math.random() * math.pi, rotV = (love.math.random() - 0.5) * 6,
        sway = love.math.random() * math.pi * 2,
        life = 1.4 + love.math.random() * 1.2, max = 0,
        light = love.math.random() < 0.35,
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

local function spawnWind(x, y, dirX, len)
    wind[#wind + 1] = { x = x, y = y, len = len, vx = dirX * (520 + love.math.random() * 260),
                        life = 0.28 + love.math.random() * 0.18, max = 0 }
    wind[#wind].max = wind[#wind].life
end

local function updateFx(dt)
    for i = #feathers, 1, -1 do
        local f = feathers[i]
        f.life = f.life - dt
        f.sway = f.sway + dt * 4.5
        f.vy = math.min(f.vy + 55 * dt, 48)
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

local MIST_BODY  = { 0.22, 0.13, 0.38 }
local MIST_GLOW  = { 0.58, 0.36, 0.98 }
local MIST_EMBER = { 1.00, 0.50, 0.16 }

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
        pf.x = pf.x + (pf.vx + g * 60) * par * dt
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
            love.graphics.setColor(MIST_BODY[1], MIST_BODY[2], MIST_BODY[3], a)
            love.graphics.draw(img, x, y, 0, sx, sy)
            love.graphics.setBlendMode("add")
            local gc = pf.ember and MIST_EMBER or MIST_GLOW
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
local HIT_COLOR = { 0.72, 0.52, 1.00 }
local function startHit(cx, cy)
    hit = { t = 0, dur = 0.60, cx = cx, cy = cy }
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
            love.graphics.setColor(HIT_COLOR[1], HIT_COLOR[2], HIT_COLOR[3], fa)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
        -- ONDA DE CHOQUE: dois anéis de blocos, o de dentro atrasado
        for ring = 0, 1 do
            local rt = t - ring * 0.08
            if rt > 0 then
                local k = clamp01(rt / hit.dur)
                local r = easeOut(k) * w * 0.55
                local a = 1 - k
                local col = (ring == 0) and MIST_EMBER or HIT_COLOR
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
-- GEOMETRIA DO RASANTE
-- ---------------------------------------------------------------------------
-- Canto superior esquerdo do sprite do rasante no parâmetro k (0..1).
-- `land=true`: termina EXATAMENTE onde o EnemyRenderer vai desenhar o chefe
-- (medido pelo passe no canvas descartado: stage.foot.drawX/drawY).
local function flyPos(f, k, w, h)
    local tr = stage and stage.tr
    local iw, ih = 0, 0
    if flyAnim then iw, ih = flyAnim:getSize() end
    local s = (stage and stage.foot and stage.foot.scale) or 2
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
    local spec = EnemyPoses.get and EnemyPoses.get(id) or nil
    local fps = (spec and spec.idle and spec.idle.fps) or 8
    -- asas batem mais rápido no rasante
    flyAnim = SpriteAnimation.new(id, "idle", "south", fps * 2.2)
end

local function enterStep(st)
    local kind = st.kind
    if kind == "dark" then
        darkEase = { from = dark, to = st.to or 0, t = 0, dur = math.max(0.01, st.dur or 0.3) }
    elseif kind == "eyes" then
        eyes = { u = st.u or 0.5, v = st.v or 0.4, size = st.size or 0.04,
                 blinks = st.blinks or {}, t = 0, dur = st.dur or 2 }
        mistTarget(1, 1.2)
        play("bossEyesIgnite", nil)
    elseif kind == "flyby" then
        eyes = nil
        ensureFlyAnim(seq.bossId)
        fly = { from = st.from or "left", v = st.v or 0.4, ghosts = st.ghosts or 2,
                arc = st.arc or 0, land = st.land, lights = st.lights,
                t = 0, dur = math.max(0.05, st.dur or 0.5), startDark = dark, trail = {} }
        if st.lights then
            darkEase = { from = dark, to = st.lights, t = 0, dur = fly.dur }
        end
        mistGustDir = (fly.from == "left") and 1 or -1
        InteriorFX.gust(1.0, fly.dur + 0.35)
        play("bossWingPass", "sceneRustle", 0.92 + love.math.random() * 0.16, 0)
    elseif kind == "land" then
        fly = nil
        bossHidden = false
        landed = true
        darkEase = { from = dark, to = 0, t = 0, dur = math.max(0.15, (st.dur or 0.5) * 0.6) }
        mistTarget(0.35, 0.45)
        EnemyRenderer.triggerArrival()
        if _G.triggerShake and (st.shake or 0) > 0 then _G.triggerShake(st.shake, 0.38) end
        if _G.jiggleScreen and not seq.reduced then _G.jiggleScreen(1.0) end
        play("bootImpact", "sceneStoneThud")
        play("bossRevealSting", "enemyBuffRoar")
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local gy = stage.cy or stage.bbox.bottomY
            spawnDust(gx, gy, st.dust or 12, stage.bbox.width or 120)
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.45
            spawnCrows(gx, body, st.crows or 5, 260)
            startHit(gx, body)
            for _ = 1, 12 do
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120),
                    body + (love.math.random() - 0.5) * 40,
                    (love.math.random() - 0.5) * 60, -20 + love.math.random() * 10)
            end
        end
        InteriorFX.gust(0.6, 0.5)
    elseif kind == "title" then
        mistTarget(0, 1.6)
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
    elseif kind == "burst" then
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.42
            for _ = 1, (st.feathers or 16) do
                local a = love.math.random() * math.pi * 2
                local sp = 60 + love.math.random() * 160
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120) * 0.6,
                    body + (love.math.random() - 0.5) * (stage.bbox.height or 200) * 0.5,
                    math.cos(a) * sp, math.sin(a) * sp * 0.6 - 40)
            end
            spawnCrows(gx, body, st.crows or 4, 200)
        end
    elseif kind == "desat" then
        desat = { peak = st.peak or 0.7, rise = st.rise or 0.4, fall = st.fall or 1.2,
                  total = remainingDuration(seq.idx), t = 0 }
    elseif kind == "hold" then
        -- nada a disparar: o corpo fica, espólios esperam (holdsEnd)
    else
        if not warnedKind[kind or "nil"] then
            warnedKind[kind or "nil"] = true
            print("[BossCinematic] passo desconhecido '" .. tostring(kind) .. "' — pulado")
        end
    end
end

local function exitStep(st)
    if st.kind == "eyes" then eyes = nil end
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
    if eyes then eyes.t = eyes.t + dt end
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
                for _ = 1, 2 do
                    spawnWind(backX, y + sh * (0.25 + love.math.random() * 0.5), -dirX,
                        24 + love.math.random() * 40)
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
local EYE_ROWS = { "..####..", ".######.", "########", ".######.", "..####.." }
local function drawEyes(w, h)
    if not eyes or not stage or not stage.tr then return end
    local tr = stage.tr
    local B = math.max(2, math.floor(eyes.size * 256 * tr.scale / 8 + 0.5))
    local ex = tr.ox + eyes.u * 400 * tr.scale
    local ey = tr.oy + eyes.v * 256 * tr.scale
    -- abertura: 0 → 1 nos primeiros 0.35s; piscadas = sino de 0.12s; fecha
    -- nos últimos 0.18s do passo
    local t = eyes.t
    local open = clamp01(t / 0.35)
    for _, bt in ipairs(eyes.blinks) do
        local d = math.abs(t - bt)
        if d < 0.12 then open = math.min(open, d / 0.12) end
    end
    local closing = eyes.dur - t
    if closing < 0.18 then open = math.min(open, clamp01(closing / 0.18)) end
    -- fileiras visíveis a partir do MEIO (1 = fenda, 5 = aberto)
    local rows = math.floor(open * 5 + 0.5)
    if rows <= 0 then return end
    local glow = 0.78 + 0.22 * math.sin(t * 7.3)
    local gap = 11 * B      -- distância entre os centros dos dois olhos
    local ew, eh = 8 * B, 5 * B
    for side = -1, 1, 2 do
        local cx = math.floor(ex + side * gap / 2)
        local x0 = cx - ew / 2
        local y0 = ey - eh / 2
        -- halo: BLOB de névoa aditiva (borda esfarelada, nunca retângulo),
        -- cresce com a abertura do olho e respira
        local ha = 0.55 * glow * (rows / 5)
        glowBlob(cx, ey, ew * 3.2, eh * 3.4, EYE_HALO, ha * 0.55, 1 + (side + 1) / 2)
        glowBlob(cx, ey, ew * 1.8, eh * 2.0, EYE_CORE, ha * 0.45, 3)
        -- fileiras do meio pra fora
        local lo = 3 - math.floor((rows - 1) / 2)
        local hi = 3 + math.floor(rows / 2)
        for r = lo, hi do
            local line = EYE_ROWS[r]
            for c = 1, 8 do
                if line:sub(c, c) == "#" then
                    local pupil = (c == 4 or c == 5) and r >= 2 and r <= 4
                    if pupil then
                        love.graphics.setColor(0.30, 0.06, 0.02, 1)
                    elseif c == 3 or c == 6 then
                        love.graphics.setColor(EYE_CORE[1], EYE_CORE[2] * 0.92, EYE_CORE[3] * 0.7, glow)
                    else
                        love.graphics.setColor(EYE_HALO[1], EYE_HALO[2] + 0.1, EYE_HALO[3], glow)
                    end
                    love.graphics.rectangle("fill", x0 + (c - 1) * B, y0 + (r - 1) * B, B, B)
                end
            end
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
        local col = (i % 6 == 1) and MIST_EMBER or MIST_GLOW
        glowBlob(p.x + sw * 0.5, p.y + sh * 0.5, sw * 1.15, sh * 0.75, col, a, 1 + i % 3)
    end
    love.graphics.setBlendMode("add")
    -- fantasmas: cópias ATRÁS no tempo, claras (violeta de corvo em aditivo)
    for g = n, 1, -1 do
        local p = tr[#tr - g * 2]
        if p then
            local a = 0.55 * (1 - (g - 1) / math.max(1, n))
            flyAnim:draw(p.x, p.y, s, { CROW_SHEEN[1] + 0.2, CROW_SHEEN[2] + 0.15, CROW_SHEEN[3] + 0.3, a })
        end
    end
    -- RIM LIGHT: a silhueta deslocada em 4 direções, aditiva, antes do corpo
    local P = math.max(1, math.floor(s + 0.5))
    for _, off in ipairs({ { -P, 0 }, { P, 0 }, { 0, -P }, { 0, P } }) do
        flyAnim:draw(x + off[1], y + off[2], s, { 0.62, 0.50, 0.95, 0.32 })
    end
    love.graphics.setBlendMode("alpha")
    -- o chefe em si, AUTO-ILUMINADO (não escurece com o salão)
    flyAnim:draw(x, y, s, { 1, 0.97, 1.02, 1 })
    -- olhos acesos (brasa aditiva nas âncoras dos olhos)
    love.graphics.setBlendMode("add")
    local glow = 0.8 + 0.2 * math.sin(fly.t * 23)
    for _, e in ipairs(EYE_ANCHORS) do
        local ex = math.floor(x + e[1] * sw)
        local ey = math.floor(y + e[2] * sh)
        love.graphics.setColor(EYE_HALO[1], EYE_HALO[2], EYE_HALO[3], 0.35 * glow)
        love.graphics.rectangle("fill", ex - 2 * P, ey - 2 * P, 4 * P, 4 * P)
        love.graphics.setColor(EYE_CORE[1], EYE_CORE[2], EYE_CORE[3], 0.95 * glow)
        love.graphics.rectangle("fill", ex - P, ey - P, 2 * P, 2 * P)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawWind()
    local P = px()
    for _, wv in ipairs(wind) do
        local a = 0.55 * (wv.life / wv.max)
        love.graphics.setColor(WIND_COLOR[1], WIND_COLOR[2], WIND_COLOR[3], a)
        local len = math.floor(wv.len / P) * P
        local x0 = (wv.vx < 0) and (wv.x - len) or wv.x
        love.graphics.rectangle("fill", math.floor(x0), math.floor(wv.y), len, P)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFeathers()
    local P = px()
    for _, f in ipairs(feathers) do
        local a = clamp01(f.life / f.max * 1.6)
        local c = f.light and FEATHER_LIGHT or FEATHER_DARK
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.push()
        love.graphics.translate(math.floor(f.x), math.floor(f.y))
        love.graphics.rotate(f.rot)
        -- pena = diagonal de 3 blocos que tomba (traço reto lê como glitch)
        love.graphics.rectangle("fill", -P * 1.5, -P * 0.5, P, P)
        love.graphics.rectangle("fill", -P * 0.5, -P * 0.5, P, P)
        love.graphics.rectangle("fill", P * 0.5, -P * 0.5, P, P)
        love.graphics.pop()
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
    drawEyes(w, h)
    drawMist({ [2] = true })
    drawWind()
    drawFly(w, h)
    if seq and seq.phase == "intro" then drawFeathers() end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Na frente do chefe: poeira do pouso, corvos espantados, penas da morte.
function BossCinematic.drawFront()
    if not stage then return end
    drawMist({ [3] = true })
    drawDust()
    if not (seq and seq.phase == "intro") then drawFeathers() end
    drawCrows()
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
