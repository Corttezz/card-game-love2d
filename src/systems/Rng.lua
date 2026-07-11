-- src/systems/Rng.lua
-- RNG seedável da run com streams separados por categoria (padrão Slay the
-- Spire: 1 seed → N geradores independentes; sortear uma carta nunca muda o
-- resultado do próximo mapa). Ver memory/sts_progression_config.md.
--
-- Diferença pro StS: lá o save guarda `counter` e reconstrói com fast-forward;
-- aqui o RandomGenerator do LÖVE expõe getState()/setState() (string), então o
-- save restaura o ESTADO EXATO. O contador fica só como telemetria/debug.
--
-- Uso:
--   local Rng = require("src.systems.Rng")
--   Rng.setActive(Rng.new())            -- nova run (RunManager faz isso)
--   local r = Rng.get()                 -- qualquer sistema de run
--   r:random("card")                    -- float [0,1)
--   r:random("card", 6)                 -- int [1,6]
--   r:random("card", 2, 5)              -- int [2,5]
--   r:pick("shop", lista)               -- elemento aleatório
--   r:getState() / Rng.fromState(state) -- serialização pro save
--
-- `meta` é uma tabela livre serializada junto (pity de raridade etc.) — o
-- estado "psicológico" do RNG viaja com ele.
--
-- IMPORTANTE: streams são só pra DECISÕES de run (ofertas, mapa, eventos).
-- Efeito visual (partícula, jiggle, smoke) continua em love.math.random —
-- poluir os streams com rolls cosméticos quebraria a reprodutibilidade.

local Rng = {}
Rng.__index = Rng

-- Streams canônicos. Novos streams: adicionar AQUI (ordem importa pro offset
-- de seed por stream — mudar a ordem muda todas as runs futuras, não as salvas).
Rng.STREAMS = { "card", "shop", "map", "event", "enemy", "misc" }

-- Instância ativa da run (padrão do projeto pra sistemas globais, cf.
-- _G.EventManager). nil fora de run — Rng.get() cria efêmera sob demanda
-- (classic mode/testes funcionam sem seed persistida).
local active = nil

-- Primo grande pra derivar seeds de stream a partir da seed da run.
local STREAM_SEED_STEP = 7919

function Rng.generateSeed()
    -- Entropia do RNG global do LÖVE (auto-seedado no boot) + relógio.
    -- Só usado pra CRIAR seeds — nunca em decisões de run.
    local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
    local base = (love and love.math and love.math.random(1, 2147483646)) or math.random(1, 2147483646)
    local seed = (base + math.floor(t * 1000)) % 2147483647
    if seed < 1 then seed = 1 end
    return seed
end

function Rng.new(seed)
    local self = setmetatable({}, Rng)
    self.seed = seed or Rng.generateSeed()
    self.streams = {}
    self.counters = {}
    self.meta = {}   -- estado livre serializado junto (ex: pity de raridade)
    for i, name in ipairs(Rng.STREAMS) do
        self.streams[name] = love.math.newRandomGenerator(self.seed + i * STREAM_SEED_STEP)
        self.counters[name] = 0
    end
    return self
end

-- Reconstrói de um estado salvo. Tolerante a estado parcial (stream novo que
-- não existia no save nasce da seed; contador ausente vira 0).
function Rng.fromState(state)
    if type(state) ~= "table" or not state.seed then
        return Rng.new()
    end
    local self = Rng.new(state.seed)
    for name, gen in pairs(self.streams) do
        local s = state.states and state.states[name]
        if s then
            local ok = pcall(function() gen:setState(s) end)
            if not ok then
                print("[Rng] setState falhou pro stream '" .. name .. "' — stream re-seedado")
            end
        end
        self.counters[name] = (state.counters and state.counters[name]) or 0
    end
    if type(state.meta) == "table" then
        self.meta = state.meta
    end
    return self
end

function Rng:getState()
    local states = {}
    for name, gen in pairs(self.streams) do
        states[name] = gen:getState()
    end
    -- Cópia rasa dos counters (o save serializa a referência; evitar aliasing).
    local counters = {}
    for name, c in pairs(self.counters) do counters[name] = c end
    return {
        seed = self.seed,
        states = states,
        counters = counters,
        meta = self.meta,
    }
end

function Rng:_gen(stream)
    local gen = self.streams[stream]
    if not gen then
        -- Stream desconhecido é bug de chamada — avisa e cai no misc pra não
        -- crashar gameplay (mas o log denuncia).
        print("[Rng] stream desconhecido: " .. tostring(stream) .. " (usando 'misc')")
        gen = self.streams.misc
        stream = "misc"
    end
    self.counters[stream] = (self.counters[stream] or 0) + 1
    return gen
end

-- Mesma assinatura de love.math.random:
--   random(stream)        → float [0,1)
--   random(stream, m)     → int [1,m]
--   random(stream, m, n)  → int [m,n]
function Rng:random(stream, m, n)
    local gen = self:_gen(stream)
    if m == nil then
        return gen:random()
    elseif n == nil then
        return gen:random(m)
    end
    return gen:random(m, n)
end

-- Elemento aleatório de uma lista (nil se vazia).
function Rng:pick(stream, list)
    if not list or #list == 0 then return nil end
    return list[self:random(stream, #list)]
end

-- Roll ponderado: recebe { {item=..., weight=N}, ... } e retorna o item.
-- Ordem da lista é respeitada (determinístico por seed — nunca usar pairs).
function Rng:weighted(stream, entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + (e.weight or 1) end
    if total <= 0 then return entries[1] and entries[1].item end
    local r = self:random(stream) * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e.item end
    end
    return entries[#entries].item
end

-- ===== Instância ativa (escopo de run) =====

function Rng.setActive(rng)
    active = rng
    return active
end

function Rng.get()
    if not active then
        active = Rng.new()
    end
    return active
end

function Rng.clearActive()
    active = nil
end

function Rng.hasActive()
    return active ~= nil
end

return Rng
