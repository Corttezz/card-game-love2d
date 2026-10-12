-- src/systems/PlaceAudio.lua
-- ============================================================================
-- PLACEAUDIO — o som AMBIENTE de cada lugar da run (Out/2026, dono: "ao
-- entrar na loja, forja, descanso, evento, o som da estrada não pode
-- continuar — no máximo o ambiente do lugar novo")
-- ============================================================================
-- Mesmo desenho do MusicDirector: OBSERVA o estado todo frame (apply) em vez
-- de ser avisado por cada tela — transição esquecida não vira "som errado".
--
-- Decide o LUGAR (road / shop / forge / rest / event / reward / boss / nil)
-- e:
--   1. abre ou fecha o portão do clima da estrada (WeatherAudio.roadActive);
--   2. toca a cama do lugar + avulsos raros, com o MESMO motor de camas do
--      WeatherAudio (vozes em crossfade de variantes, ponto de início e pitch
--      sorteados, nunca a mesma variante seguida — nada de loop fixo);
--   3. um avulso de CHEGADA (sino da porta da loja) uma vez por entrada.
--
-- Volume bem abaixo da música: PLACE_VOLUME × AMBIENT_VOLUME × categoria,
-- grupo "ambient" (slider próprio em Configurações).
-- Não duplica SFX de UI: a batida da forja (forgeStrike) continua sendo da
-- RestScreen; aqui a bigorna é DISTANTE, rara e para enquanto a cerimônia de
-- forja toca (forgeBusy).
--
-- Sons em audio/sfx/place/ (ElevenLabs FREE — lista pra regenerar em
-- memory/weather_engine.md) + reuso de audio/sfx/weather/ (grilos, brasa,
-- vento, coruja). Registro por SCAN (código "pl:<nome>").
-- ============================================================================

local PlaceAudio = {}
local WeatherAudio = require("src.systems.WeatherAudio")

local DIR = "audio/sfx/place"
local CAT_VOL = { bed = 0.42, one = 0.32 }
local IN_RATE, OUT_RATE = 0.9, 1.1     -- ganho/s: chega em ~1 s, sai em ~1 s

local P, W = "pl:", "wx:"   -- prefixos: sons do lugar × reuso do clima

-- cama(s) + avulsos por lugar. every = intervalo sorteado (s).
PlaceAudio.PLACES = {
    shop = {
        beds = { { family = "pl-shop", prefix = P, vars = { "shop-room-1", "shop-room-2" }, gain = 0.85 } },
        enter = { prefix = P, vars = { "shop-bell-1", "shop-bell-2" }, vol = 0.8 },
        ones = {
            { prefix = P, vars = { "coin-clink-1", "coin-clink-2", "coin-clink-3" },
              every = { 4, 10 }, vol = 0.55, pitch = 0.10 },
            { prefix = P, vars = { "shop-creak-1" }, every = { 9, 20 }, vol = 0.45, pitch = 0.12 },
        },
    },
    forge = {
        beds = { { family = "pl-forge", prefix = P, vars = { "forge-fire-1", "forge-fire-2" }, gain = 0.9 } },
        ones = {
            { prefix = P, vars = { "anvil-1", "anvil-2", "anvil-3" },
              every = { 5, 11 }, vol = 0.45, pitch = 0.06, quietWhenBusy = true },
            { prefix = P, vars = { "bellows-1" }, every = { 8, 16 }, vol = 0.45, pitch = 0.08 },
            { prefix = W, vars = { "ember-pop-1" }, every = { 3, 7 }, vol = 0.45, pitch = 0.2 },
        },
    },
    rest = {
        beds = {
            { family = "pl-camp", prefix = P, vars = { "rest-camp-1", "rest-camp-2" }, gain = 0.9 },
            { family = "pl-crickets", prefix = W, vars = { "night-crickets-1", "night-crickets-2" }, gain = 0.35 },
        },
        ones = {
            { prefix = W, vars = { "ember-pop-1" }, every = { 3, 8 }, vol = 0.45, pitch = 0.2 },
            { prefix = W, vars = { "owl-1" }, every = { 25, 50 }, vol = 0.30, pitch = 0.06 },
        },
    },
    event = {
        beds = { { family = "pl-event", prefix = P, vars = { "event-drone-1", "event-drone-2" }, gain = 0.75 } },
        ones = {
            { prefix = P, vars = { "event-chime-1", "event-chime-2" }, every = { 7, 15 }, vol = 0.40, pitch = 0.10 },
        },
    },
    reward = {
        beds = {},
        ones = {
            { prefix = P, vars = { "coin-clink-1", "coin-clink-2", "coin-clink-3" },
              every = { 6, 14 }, vol = 0.35, pitch = 0.12 },
            { prefix = P, vars = { "paper-1" }, every = { 8, 18 }, vol = 0.35, pitch = 0.10 },
        },
    },
    boss = {
        beds = { { family = "pl-boss", prefix = P, vars = { "boss-room-1" }, gain = 0.45 } },
        ones = {
            { prefix = P, vars = { "boss-rumble-1" }, every = { 18, 35 }, vol = 0.35, pitch = 0.08 },
        },
    },
}

local beds = {}       -- [family] = estado de cama (motor do WeatherAudio)
local onesT = {}      -- [place..idx] = s até o próximo avulso
local cur = nil
local rng = love.math.newRandomGenerator(6151)

local function audio() return _G.audioSystem end

function PlaceAudio.registerSounds(a)
    a = a or audio()
    if not a then return 0 end
    local Config = require("src.core.Config")
    local base = Config.Audio.PLACE_VOLUME * Config.Audio.AMBIENT_VOLUME
    local n = 0
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        local name = item:match("^(.+)%.mp3$")
        if name then
            local isBed = name:find("%-room%-") or name:find("%-fire%-")
                or name:find("%-camp%-") or name:find("%-drone%-")
            a:loadSound(P .. name, DIR .. "/" .. item,
                { volume = base * (isBed and CAT_VOL.bed or CAT_VOL.one),
                  group = "ambient", stream = false })
            n = n + 1
        end
    end
    return n
end

-- ----------------------------------------------------------------------------
-- QUAL LUGAR — pura, testável sem áudio.
--   state   = currentState do main.lua
--   ctx     = { nodeType, restMode, bossRoom (bool) }
-- ----------------------------------------------------------------------------
function PlaceAudio.placeFor(state, ctx)
    ctx = ctx or {}
    if state == "playing" then
        return ctx.bossRoom and "boss" or "road"
    elseif state == "mapSelection" then
        return "road"
    elseif state == "cardReward" then
        return (ctx.nodeType == "shop") and "shop" or "reward"
    elseif state == "roundEval" then
        return "reward"
    elseif state == "rest" then
        return (ctx.restMode == "forge") and "forge" or "rest"
    elseif state == "event" then
        return "event"
    end
    return nil   -- menu, coleção, game over, vitória: silêncio de ambiente
end

local function playOne(def, gainK)
    local a = audio()
    if not a then return end
    local name = WeatherAudio.pick("pl1:" .. def.vars[1], def.vars)
    a:play(def.prefix .. name, {
        pitch = 1 + (rng:random() * 2 - 1) * (def.pitch or 0.1),
        gain = (def.vol or 0.5) * (gainK or (0.75 + rng:random() * 0.25)),
    })
end

-- chamado TODO frame pelo main.lua
function PlaceAudio.apply(dt, state, ctx)
    local place = PlaceAudio.placeFor(state, ctx)
    WeatherAudio.roadActive = (place == "road")
    if place ~= cur then
        local prev = cur
        cur = place
        onesT = {}
        local cfg = place and PlaceAudio.PLACES[place]
        -- avulso de CHEGADA (sino da loja) — só na entrada, não na volta do
        -- pause/deck viewer (o estado não muda nesses casos)
        if cfg and cfg.enter and prev ~= place then playOne(cfg.enter, 1) end
    end
    local cfg = place and PlaceAudio.PLACES[place]
    -- camas: as do lugar sobem, as demais descem
    local wanted = {}
    if cfg then
        for _, def in ipairs(cfg.beds) do
            beds[def.family] = beds[def.family] or { cur = 0, voices = {} }
            wanted[def.family] = true
            WeatherAudio.tickBed(beds[def.family], def, def.gain or 1, dt, IN_RATE)
        end
    end
    for fam, bed in pairs(beds) do
        if not wanted[fam] then
            WeatherAudio.tickBed(bed, { family = fam, vars = {} }, 0, dt, OUT_RATE)
        end
    end
    -- avulsos
    if cfg and audio() then
        for idx, def in ipairs(cfg.ones) do
            local key = place .. idx
            local t = onesT[key]
            if not t then
                t = def.every[1] + rng:random() * (def.every[2] - def.every[1])
            end
            t = t - dt
            if t <= 0 then
                t = def.every[1] + rng:random() * (def.every[2] - def.every[1])
                if not (def.quietWhenBusy and ctx and ctx.forgeBusy) then playOne(def) end
            end
            onesT[key] = t
        end
    end
end

function PlaceAudio.current() return cur end
function PlaceAudio._state() return beds end
function PlaceAudio._reset()
    for _, bed in pairs(beds) do
        for k = #bed.voices, 1, -1 do WeatherAudio.stopVoice(bed.voices[k]) end
    end
    beds, onesT, cur = {}, {}, nil
    WeatherAudio.roadActive = true
end

return PlaceAudio
