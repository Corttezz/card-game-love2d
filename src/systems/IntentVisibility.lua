-- src/systems/IntentVisibility.lua
-- ============================================================================
-- VISIBILIDADE DO INTENT — névoa do bioma + véu do inimigo + revelações
-- ============================================================================
-- Ideia do dono (Out/2026): nos biomas do fim da jornada a nevasca esconde
-- parte do que o inimigo anuncia. Isto é a camada GERAL que decide, a cada
-- anúncio de intent, quanto o HUD pode mostrar:
--
--   "full"       tudo (como sempre foi)
--   "type_only"  o ÍCONE do golpe aparece, o NÚMERO vira "?"
--   "hidden"     nem o tipo: ícone de desconhecido + "A névoa esconde a intenção"
--
-- Três fontes, combinadas pelo PIOR nível (menor), e uma que vence tudo:
--   1. NÉVOA DO BIOMA  (src/data/intent_fog.lua, por bioma; rolada por turno)
--   2. VÉU DO INIMIGO  (campo `veil` do kit ou da fase, src/data/enemies.lua)
--   3. REVELAÇÃO       (carta/efeito `reveal_intent`, pulso do orbe de Raio):
--                      força "full" neste turno e nos N seguintes.
--
-- INVARIANTES
--   * O intent continua CONGELADO no anúncio (CLAUDE.md §6). Esta camada só
--     muda o que se MOSTRA; `Enemy:intentHitDamage` não sabe que ela existe.
--   * Decidido UMA vez por anúncio (`Enemy:rollIntent`) e guardado em
--     `enemy.intentVisibility`: nunca pisca durante a decisão do jogador.
--   * A rolagem usa o stream "misc" do Rng (a seed reproduz; "enemy" ficou
--     intocado pra não deslocar os golpes já medidos pelo piloto).
--   * O mundo ACOMPANHA o estado, não o contrário: o WeatherEngine lê
--     `worldFog()` e engrossa a nevasca quando o número some. O relógio do
--     clima é visual, por isso não pode ser a regra.
--
-- Quem usa: Enemy (resolve), EnemyHud/IntentVeil (desenho), EffectSystem
-- (reveal), RunModifiers.decorateEnemy (contexto do bioma), pilotos
-- (`Enemy:getKnownIntent` — não podem espiar). Ver memory/intent_visibility.md.
-- ============================================================================

local IntentVisibility = {}

local FogData = require("src.data.intent_fog")

IntentVisibility.LEVELS = { "full", "type_only", "hidden" }
IntentVisibility.RANK = { full = 3, type_only = 2, hidden = 1 }

local function isLevel(v) return IntentVisibility.RANK[v] ~= nil end

-- O pior dos dois níveis (nil = sem opinião).
function IntentVisibility.worst(a, b)
    if not a then return b end
    if not b then return a end
    return (IntentVisibility.RANK[a] <= IntentVisibility.RANK[b]) and a or b
end

-- ----------------------------------------------------------------------------
-- Curva da névoa: a MESMA do clima na tela (WeatherEngine.intensityFor).
-- Copiada aqui de propósito — este módulo roda sem o motor gráfico (pilotos,
-- testes); test_intent_visibility exige que as duas batam.
-- ----------------------------------------------------------------------------
local function smooth(a, b, x)
    local t = math.min(1, math.max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
end
function IntentVisibility.fogCurve(prog)
    return 0.12 + 0.88 * (smooth(0, 1, prog) ^ 1.3)
end

-- Bioma (id de src/data/biomes.lua) do ato da run — mesmo wrap do endless que
-- EnemyRoster.biomeAct / WorldRoad.rawBiome usam (4,5,6,1,2,3,...).
function IntentVisibility.biomeIdFor(run)
    if not run then return nil end
    local a = run.actNumber or 1
    if run.endlessMode then
        a = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    a = ((a - 1) % 6) + 1
    local biomes = require("src.data.biomes")
    local list = biomes.list or biomes
    local b = list[a]
    return b and b.id or nil
end

-- Regra do bioma (nil = céu limpo).
function IntentVisibility.ruleFor(biomeId)
    return biomeId and FogData.biomes[biomeId] or nil
end

-- Contexto de névoa de UMA batalha. nil quando o bioma não tem névoa — o
-- inimigo então nem rola (atos 1-3 ficam idênticos ao que eram).
--   progress  0..1 pela chegada ao castelo (andar 1 → 8), igual ao clima
--   hall      chefe luta no salão: bruma do interior, densidade fixa
function IntentVisibility.contextFor(run, nodeType)
    if not run then return nil end
    local bid = IntentVisibility.biomeIdFor(run)
    local rule = IntentVisibility.ruleFor(bid)
    if not rule then return nil end
    nodeType = nodeType or (run.currentNode and run.currentNode.type) or "battle"
    local floor = run.floorInAct or 1
    local progress = math.min(1, math.max(0, (floor - 1) / 7))
    local ctx = { biomeId = bid, progress = progress, hall = (nodeType == "boss") }
    ctx.density = IntentVisibility.density(ctx)
    return ctx
end

-- Densidade da névoa do contexto (0..1): fração dos anúncios encobertos.
function IntentVisibility.density(ctx)
    if not ctx then return 0 end
    local rule = IntentVisibility.ruleFor(ctx.biomeId)
    if not rule then return 0 end
    if ctx.hall then return rule.hall or 0 end
    local k = IntentVisibility.fogCurve(ctx.progress or 0)
    -- a curva começa em 0.12 (céu quase limpo) e chega a 1: normaliza pra que
    -- `base` seja exatamente o 1º andar e `peak` a porta do castelo
    local n = (k - 0.12) / 0.88
    return rule.base + (rule.peak - rule.base) * n
end

-- ----------------------------------------------------------------------------
-- Resolução por anúncio
-- ----------------------------------------------------------------------------
-- `roll` = função que devolve [0,1) (padrão: Rng stream "misc"). Só é chamada
-- quando há o que sortear — sem névoa e sem véu probabilístico o Rng não anda.
-- Devolve (nível, causa) com causa ∈ "fog" | "veil" | "reveal" | nil.
function IntentVisibility.resolve(enemy, roll)
    if not enemy then return "full", nil end
    -- Revelação vence tudo (e consome um turno da contagem).
    if (enemy._revealTurns or 0) > 0 then
        enemy._revealTurns = enemy._revealTurns - 1
        return "full", "reveal"
    end
    roll = roll or function()
        return require("src.systems.Rng").get():random("misc")
    end
    local level, cause = "full", nil

    -- 1. névoa do bioma
    local ctx = enemy.fogContext
    local density = ctx and (ctx.density or IntentVisibility.density(ctx)) or 0
    if density > 0 then
        local rule = IntentVisibility.ruleFor(ctx.biomeId) or {}
        local r = roll()
        if r < density then
            level = (r < density * (rule.heavy or 0)) and "hidden" or "type_only"
            cause = "fog"
        end
    end

    -- 2. véu do inimigo (kit ou fase corrente)
    local veil = enemy.veilSpec and enemy:veilSpec() or nil
    if veil and isLevel(veil.level) then
        local chance = veil.chance or 1
        if chance >= 1 or roll() < chance then
            local before = level
            level = IntentVisibility.worst(level, veil.level)
            if level ~= before or cause == nil then cause = "veil" end
        end
    end

    return level, cause
end

-- ----------------------------------------------------------------------------
-- O mundo acompanha: quanto a névoa oculta engrossa o clima da tela
-- ----------------------------------------------------------------------------
local active = nil   -- último inimigo que resolveu visibilidade (a luta corrente)

function IntentVisibility.noteActive(enemy) active = enemy end
function IntentVisibility.activeEnemy() return active end
function IntentVisibility.reset() active = nil end

-- 0..1 de intensidade EXTRA pro WeatherEngine (hook instalado abaixo). Zero
-- fora de luta, com o inimigo morto, no salão (interior não tem clima do
-- domo) ou com o número à mostra.
function IntentVisibility.worldFog()
    local e = active
    if not e or not e.fogContext or e.fogContext.hall then return 0 end
    if e.isAlive and not e:isAlive() then return 0 end
    local lvl = e.intentVisibility or "full"
    return (FogData.worldBoost or {})[lvl] or 0
end

-- Cor do véu desenhado sobre o intent (tinta do bioma; véu do inimigo sem
-- bioma de névoa usa violeta neutro).
local VEIL_DEFAULT = { 0.62, 0.52, 0.72 }
function IntentVisibility.veilColor(enemy)
    local ctx = enemy and enemy.fogContext
    local rule = ctx and IntentVisibility.ruleFor(ctx.biomeId)
    return (rule and rule.color) or VEIL_DEFAULT
end

-- Instala o hook no motor de clima (sem ciclo: o WeatherEngine não conhece
-- src/). Fora do LÖVE gráfico (pilotos) o require pode falhar — tudo bem.
do
    local ok, WeatherEngine = pcall(require, "engine.WeatherEngine")
    if ok and type(WeatherEngine) == "table" then
        WeatherEngine.fogHook = IntentVisibility.worldFog
    end
end

return IntentVisibility
