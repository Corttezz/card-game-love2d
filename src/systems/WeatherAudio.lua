-- src/systems/WeatherAudio.lua
-- ============================================================================
-- WEATHERAUDIO — o SOM do clima do WorldRoad (Out/2026, dono: "cada tipo de
-- partícula precisa de som, e o som não pode ser um loop fixo e idêntico")
-- ============================================================================
-- Três camadas, todas lidas do estado do WeatherEngine (intensidade da
-- chegada ao castelo, tempestade, rajada do capim, noite):
--
--   CAMAS  (chuva leve/forte, vento, nevasca, grilos, brejo, brasas): cada
--          cama é uma fila de VOZES que nunca dá loop — a voz toca uma vez,
--          a partir de um ponto aleatório, com pitch próprio, e perto do fim
--          entra a próxima variante (≠ da anterior) em crossfade. A emenda
--          do arquivo nunca é ouvida e a cama nunca se repete igual (técnica
--          do "ambi-patch" do Dead Space; camadas por superfície da chuva do
--          Hunt: Showdown — pesquisa Out/2026).
--   AVULSOS (gota, coruja, grilo, sapo, estalo de brasa, cristal de gelo,
--          brilho de vagalume): intervalo, pitch e volume sorteados; nunca a
--          mesma variante duas vezes seguidas.
--   TROVÃO: 5 variantes escolhidas pela DISTÂNCIA do raio (perto = estalo
--          seco e alto, longe = rumor baixo), atraso e volume pela distância,
--          pitch ±8%, nunca o mesmo duas vezes seguidas.
--
-- Arquivos em audio/sfx/weather/ (ElevenLabs, plano FREE — regenerar após
-- assinar; lista em memory/weather_engine.md). Registro por SCAN: arquivo
-- novo `rain-light-4.mp3` entra sozinho na cama `rain-light`.
-- Grupo "sfx" (respeita master/sfx) e volume base Config.Audio.WEATHER_VOLUME.
--
-- WATCHDOG: as camas só vivem enquanto o mundo é atualizado. Se o
-- WorldRoad parar de chamar update (interior do chefe, loja, menu), o
-- watchdog (main.lua, todo frame) esvazia as camas em fade curto.
-- ============================================================================

local WeatherAudio = {}

local DIR = "audio/sfx/weather"
local FADE = 1.6            -- s de crossfade entre vozes de uma cama
local GAIN_RATE = 0.7       -- quanto a cama anda por segundo rumo ao alvo

-- volume relativo por categoria (×Config.Audio.WEATHER_VOLUME)
local CAT_VOL = { bed = 0.55, one = 0.40, thunder = 0.85 }

-- camas e avulsos por bioma. gain(s) recebe o estado do clima.
--   s.intensity 0..1 (sobe com a chegada ao castelo), s.storm 0..1,
--   s.gust 0..~1.5 (|rajada| no centro), s.night 0..1, s.rain 0..1
local function clamp01(x) return math.max(0, math.min(1, x)) end

WeatherAudio.BIOMES = {
    fields = {
        beds = {
            { family = "wind", vars = { "wind-1", "wind-3" },
              gain = function(s) return 0.25 + 0.35 * clamp01(s.gust) end },
            { family = "crickets", vars = { "night-crickets-1", "night-crickets-2" },
              gain = function(s) return 0.75 * s.night end },
        },
        ones = {
            { vars = { "cricket-chirp-1" }, every = { 5, 12 }, vol = 0.5, pitch = 0.12,
              when = function(s) return s.night > 0.3 end },
            { vars = { "owl-1" }, every = { 25, 55 }, vol = 0.45, pitch = 0.06,
              when = function(s) return s.night > 0.5 end },
        },
    },
    highlands = {
        beds = {
            { family = "rain-light", vars = { "rain-light-1", "rain-light-2", "rain-light-3" },
              gain = function(s) return 0.85 * s.rain * (1 - 0.6 * s.storm) end },
            { family = "rain-heavy", vars = { "rain-heavy-1", "rain-heavy-2" },
              gain = function(s) return 0.80 * s.rain * s.storm end },
            { family = "wind", vars = { "wind-2", "wind-1" },
              gain = function(s) return 0.20 + 0.40 * clamp01(s.gust) * (0.5 + 0.5 * s.storm) end },
        },
        ones = {
            { vars = { "drip-1", "drip-2" }, every = { 3, 8 }, vol = 0.45, pitch = 0.18,
              when = function(s) return s.rain > 0.2 end },
            { vars = { "owl-1" }, every = { 35, 70 }, vol = 0.35, pitch = 0.06,
              when = function(s) return s.storm < 0.3 end },
        },
    },
    abyss = {
        beds = {
            { family = "embers", vars = { "ember-crackle-1" },
              gain = function(s) return 0.55 + 0.35 * s.intensity end },
            { family = "wind", vars = { "wind-2" },
              gain = function(s) return 0.15 + 0.25 * clamp01(s.gust) end },
        },
        ones = {
            { vars = { "ember-pop-1" }, every = { 2, 6 }, vol = 0.5, pitch = 0.22 },
        },
    },
    frost = {
        beds = {
            { family = "blizzard", vars = { "blizzard-1", "blizzard-2" },
              gain = function(s) return 0.15 + 0.70 * s.intensity * (0.6 + 0.4 * clamp01(s.gust)) end },
            { family = "wind", vars = { "wind-2" },
              gain = function(s) return 0.25 * (1 - s.intensity) end },
        },
        ones = {
            { vars = { "ice-tinkle-1" }, every = { 6, 14 }, vol = 0.35, pitch = 0.20 },
        },
    },
    marsh = {
        beds = {
            { family = "rain-light", vars = { "rain-light-2", "rain-light-3", "rain-light-1" },
              gain = function(s) return 0.70 * s.rain end },
            { family = "swamp", vars = { "marsh-night-1" },
              gain = function(s) return 0.35 + 0.45 * s.night end },
        },
        ones = {
            { vars = { "frog-1" }, every = { 4, 11 }, vol = 0.45, pitch = 0.15 },
            { vars = { "drip-1", "drip-2" }, every = { 4, 10 }, vol = 0.40, pitch = 0.18,
              when = function(s) return s.rain > 0.2 end },
        },
    },
    dusk = {
        beds = {
            { family = "wind", vars = { "wind-3", "wind-1" },
              gain = function(s) return 0.30 + 0.40 * clamp01(s.gust) end },
            { family = "crickets", vars = { "night-crickets-2", "night-crickets-1" },
              gain = function(s) return 0.45 * s.night end },
        },
        ones = {
            { vars = { "owl-1" }, every = { 30, 60 }, vol = 0.40, pitch = 0.06,
              when = function(s) return s.night > 0.4 end },
        },
    },
}

-- trovão por distância (0 = em cima, 1 = no horizonte)
WeatherAudio.THUNDER = {
    near = { "thunder-near", "thunder-crack-2" },
    mid  = { "thunder-mid", "thunder-roll" },
    far  = { "thunder-far", "thunder-roll" },
}
WeatherAudio.FIREFLY = { "firefly-1", "firefly-2" }

-- ----------------------------------------------------------------------------
-- estado
-- ----------------------------------------------------------------------------
local beds = {}             -- [family] = { cur, voices = {}, last }
local ones = {}             -- [index] = { t }
local lastPick = {}         -- [grupo] = última variante (não repetir)
local curBiome = nil
local lastUpdate = 0
local lastFirefly = -100
local now = 0
local rng = love.math.newRandomGenerator(4417)

local function audio() return _G.audioSystem end
local function code(name) return "wx:" .. name end

-- sorteio que NUNCA repete a anterior do mesmo grupo (se houver opção)
function WeatherAudio.pick(group, vars)
    local n = #vars
    if n == 0 then return nil end
    if n == 1 then lastPick[group] = vars[1]; return vars[1] end
    local prev = lastPick[group]
    local v
    repeat v = vars[rng:random(1, n)] until v ~= prev
    lastPick[group] = v
    return v
end

-- ----------------------------------------------------------------------------
-- REGISTRO por scan (chamado no love.load)
-- ----------------------------------------------------------------------------
function WeatherAudio.registerSounds(a)
    a = a or audio()
    if not a then return 0 end
    local Config = require("src.core.Config")
    local base = (Config.Audio and Config.Audio.WEATHER_VOLUME) or 0.8
    local n = 0
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        local name = item:match("^(.+)%.mp3$")
        if name then
            local cat = name:find("^thunder") and "thunder"
                or ((name:find("^rain") or name:find("^wind") or name:find("^blizzard")
                     or name:find("^night") or name:find("^marsh") or name:find("crackle"))
                    and "bed" or "one")
            a:loadSound(code(name), DIR .. "/" .. item,
                { volume = base * CAT_VOL[cat], group = "sfx", stream = false })
            n = n + 1
        end
    end
    return n
end

-- ----------------------------------------------------------------------------
-- VOZES de uma cama
-- ----------------------------------------------------------------------------
local function startVoice(bed, def)
    local a = audio()
    if not a then return end
    local name = WeatherAudio.pick("bed:" .. def.family, def.vars)
    local c = (def.prefix or "wx:") .. name
    local src = a:play(c, { loop = false, gain = 0,
        pitch = 1 + (rng:random() * 2 - 1) * 0.06 })
    if not src then return end
    local dur = src:getDuration() or 0
    -- começa num ponto aleatório (até 35% do arquivo): a mesma variante
    -- nunca soa igual duas vezes
    if dur > FADE * 3 then pcall(src.seek, src, rng:random() * dur * 0.35) end
    bed.voices[#bed.voices + 1] = { code = c, src = src, age = 0, out = false }
end

local function stopVoice(v)
    local a = audio()
    if a then a:setInstanceGain(v.code, v.src, nil) end
    if v.src:isPlaying() then v.src:stop() end
end

local function tickBed(bed, def, target, dt, rate)
    local a = audio()
    -- ganho da cama anda devagar rumo ao alvo (sem degrau ao mudar clima);
    -- rate opcional: sair da estrada pra um LUGAR corta em ~1 s
    local d = target - bed.cur
    local step = (rate or GAIN_RATE) * dt
    bed.cur = bed.cur + math.max(-step, math.min(step, d))
    local live = 0
    local i = 1
    while i <= #bed.voices do
        local v = bed.voices[i]
        v.age = v.age + dt
        local playing = v.src:isPlaying()
        local remaining = 0
        if playing then
            local pitch = v.src:getPitch()
            remaining = (v.src:getDuration() - v.src:tell()) / math.max(0.5, pitch)
        end
        if playing and not v.out and remaining < FADE then
            v.out = true      -- perto do fim: a próxima variante assume
        end
        local env = math.min(1, v.age / FADE)
        if v.out then env = math.min(env, math.max(0, remaining / FADE)) end
        if (not playing) or (v.out and env <= 0.001) then
            stopVoice(v)
            table.remove(bed.voices, i)
        else
            if a then a:setInstanceGain(v.code, v.src, env * bed.cur) end
            if not v.out then live = live + 1 end
            i = i + 1
        end
    end
    if live == 0 and bed.cur > 0.01 and target > 0.01 then
        startVoice(bed, def)
    end
    if bed.cur <= 0.004 and target <= 0.004 then
        for k = #bed.voices, 1, -1 do stopVoice(bed.voices[k]); bed.voices[k] = nil end
    end
end

local function fadeAll(dt)
    for _, bed in pairs(beds) do
        bed.cur = math.max(0, bed.cur - dt * 2.5)
        for k = #bed.voices, 1, -1 do
            local v = bed.voices[k]
            if bed.cur <= 0.004 then stopVoice(v); table.remove(bed.voices, k)
            else
                local a = audio()
                if a then a:setInstanceGain(v.code, v.src, bed.cur * math.min(1, v.age / FADE)) end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- UPDATE — chamado pelo WorldRoad.update com o estado do WeatherEngine
-- ----------------------------------------------------------------------------
-- PORTÃO DE LUGAR (PlaceAudio): o clima da estrada só soa NA estrada. Fora
-- dela (loja, forja, descanso, evento, recompensa, salão do chefe) as camas
-- descem em ~1 s e avulsos/trovão calam — mesmo com o mundo ainda
-- atualizando por baixo da tela.
WeatherAudio.roadActive = true
local GATE_RATE = 1.0

function WeatherAudio.update(dt, s)
    now = now + dt
    lastUpdate = love.timer.getTime()
    local gate = WeatherAudio.roadActive
    local cfg = WeatherAudio.BIOMES[s.biomeId]
    if s.biomeId ~= curBiome then
        curBiome = s.biomeId
        ones = {}
    end
    local reduced = (_G.gameSettings and _G.gameSettings.reducedMotion) or false
    -- camas: as do bioma atual sobem, as de outros biomas descem
    local wanted = {}
    if cfg then
        for _, def in ipairs(cfg.beds) do
            local fam = def.family
            beds[fam] = beds[fam] or { cur = 0, voices = {} }
            local tgt = gate and math.max(0, math.min(1, def.gain(s))) or 0
            -- a mesma família pode aparecer em 2 biomas com variantes
            -- diferentes: a definição corrente manda
            wanted[fam] = true
            tickBed(beds[fam], def, tgt, dt, (not gate) and GATE_RATE or nil)
        end
    end
    for fam, bed in pairs(beds) do
        if not wanted[fam] then
            tickBed(bed, { family = fam, vars = {} }, 0, dt, (not gate) and GATE_RATE or nil)
        end
    end
    -- avulsos
    if gate and cfg and audio() then
        for idx, def in ipairs(cfg.ones) do
            local st = ones[idx]
            if not st then
                st = { t = def.every[1] + rng:random() * (def.every[2] - def.every[1]) }
                ones[idx] = st
            end
            st.t = st.t - dt
            if st.t <= 0 then
                st.t = def.every[1] + rng:random() * (def.every[2] - def.every[1])
                if not def.when or def.when(s) then
                    local name = WeatherAudio.pick("one:" .. s.biomeId .. idx, def.vars)
                    audio():play(code(name), {
                        pitch = 1 + (rng:random() * 2 - 1) * (def.pitch or 0.1),
                        gain = def.vol * (0.75 + rng:random() * 0.25),
                    })
                end
            end
        end
    end
    -- trovão pendente (o WeatherEngine já esperou o atraso da distância)
    if gate and s.thunder and not reduced then WeatherAudio.thunder(s.thunder) end
end

-- trovão pela distância do raio (0 = em cima, 1 = horizonte)
function WeatherAudio.thunder(dist)
    local a = audio()
    if not a then return nil end
    local band = dist < 0.33 and "near" or (dist < 0.7 and "mid" or "far")
    -- nunca a mesma variante do trovão ANTERIOR (de qualquer faixa)
    local name = WeatherAudio.pick("thunder", WeatherAudio.THUNDER[band])
    a:play(code(name), {
        pitch = 1 + (rng:random() * 2 - 1) * 0.08,
        gain = 1.0 - 0.55 * dist,
    })
    return name
end

-- vagalume perto acendeu: brilho baixinho, no máximo 1 a cada 2.5 s
function WeatherAudio.fireflyBlink(nearK)
    local a = audio()
    if not a or not WeatherAudio.roadActive or now - lastFirefly < 2.5 then return end
    lastFirefly = now
    local name = WeatherAudio.pick("firefly", WeatherAudio.FIREFLY)
    a:play(code(name), { pitch = 0.95 + rng:random() * 0.35,
        gain = 0.18 + 0.20 * (nearK or 0.5) })
end

-- motor de camas compartilhado (PlaceAudio usa o mesmo: vozes em crossfade,
-- variante nunca repetida). def = { family, vars, prefix }
WeatherAudio.tickBed = tickBed
WeatherAudio.stopVoice = stopVoice

-- main.lua chama todo frame: mundo parado de atualizar = camas somem
function WeatherAudio.watchdog(dt)
    if love.timer.getTime() - lastUpdate > 0.3 then
        local any = false
        for _, bed in pairs(beds) do if #bed.voices > 0 then any = true break end end
        if any then fadeAll(dt or 1 / 60) end
    end
end

-- teste: estado interno (leitura)
function WeatherAudio._state() return beds, lastPick end
function WeatherAudio._reset()
    for _, bed in pairs(beds) do
        for k = #bed.voices, 1, -1 do stopVoice(bed.voices[k]) end
    end
    beds, ones, lastPick, curBiome, lastFirefly, now = {}, {}, {}, nil, -100, 0
end

return WeatherAudio
