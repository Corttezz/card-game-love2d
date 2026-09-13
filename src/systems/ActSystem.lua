-- src/systems/ActSystem.lua
-- Utilitarios para calcular stats de inimigos/bosses baseado no ato e no floor.
-- Consume Config.Acts (Fase 5) + Config.Endless.
--
-- Funcao principal:
--   ActSystem.getEnemyStats(actNumber, floorInAct, nodeType) -> {health, damage, kind}
--   - Retorna HP e dano apropriados para o tipo de no.
--   - nodeType: "battle" | "elite" | "mini_boss" | "boss"
--   - Em endless (actNumber > TotalActs), aplica scaling exponencial.

local Config = require("src.core.Config")

local ActSystem = {}

-- Retorna a configuracao do ato N. Em endless (N > total), retorna config do ultimo
-- ato mas sinalizando via `endless = true` e expoente calculado.
function ActSystem.getActConfig(actNumber)
    actNumber = actNumber or 1
    local totalActs = Config.TotalActs or 3
    if actNumber <= totalActs then
        return Config.Acts[actNumber], false
    end
    -- Endless: base no ato 3 + expoente
    return Config.Acts[totalActs], true
end

-- Calcula (health, damage) para um inimigo segundo (act, floor, nodeType).
-- floorInAct: 1..act.floors. Em endless, floorInAct funciona como contador de
-- andares dentro do endless (1, 2, 3, ...).
function ActSystem.getEnemyStats(actNumber, floorInAct, nodeType)
    nodeType = nodeType or "battle"
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if not act then return { health = 20, damage = 5, kind = "battle" } end

    local hp, dmg

    -- Boss/mini_boss usam stats fixos do ato
    if nodeType == "boss" then
        hp, dmg = act.bossHP or 200, act.bossDmg or 20
    elseif nodeType == "mini_boss" then
        hp  = math.floor((act.bossHP or 200) * 0.7)
        dmg = math.floor((act.bossDmg or 20) * 0.8)
    else
        -- Normal/elite: curva do ato
        hp  = math.floor(act.enemyHP(floorInAct))
        dmg = math.floor(act.enemyDmg(floorInAct))
        if nodeType == "elite" then
            hp  = math.floor(hp * (act.eliteHPMul or 1.5))
            dmg = math.floor(dmg * (act.eliteDmgMul or 1.25))
        end
    end

    -- Endless multiplier (exponencial sobre base do ato 3)
    if isEndless then
        local mul = Config.Endless.scalingMultiplier or 1.18
        local expFloors = math.max(0, floorInAct - 1)
        local factor = mul ^ expFloors
        hp  = math.floor(hp * factor)
        dmg = math.floor(dmg * factor)
    end

    return { health = hp, damage = dmg, kind = nodeType }
end

-- Retorna os pesos de raridade ativos (shop e recompensa usam esses).
function ActSystem.getRarityWeights(actNumber)
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if isEndless then return Config.Endless.rarityWeights or { common = 10, uncommon = 35, rare = 45, legendary = 10 } end
    return (act and act.rarityWeights) or { common = 70, uncommon = 25, rare = 5, legendary = 0 }
end

-- % de cura para aplicar entre atos (0 a 1).
function ActSystem.getInterActHealPercent(actNumber)
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if isEndless then return 0 end
    return (act and act.interActHeal) or 0
end

-- Retorna o nome amigavel do ato atual (ex: "Catacumbas", ou "Endless #3").
--
-- O nome vem do i18n (`acts.act<N>`); `Config.Acts[n].name` fica como fallback
-- de dev. Antes o nome saia cravado em PT do Config e a tela aparecia bilingue
-- ("AKT 1 - Catacumbas") em qualquer locale estrangeiro.
function ActSystem.getActName(actNumber, endlessFloor)
    local I18n = require("src.i18n.I18n")
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if isEndless then
        if endlessFloor then
            return I18n.t("acts.endless_n", { n = endlessFloor },
                "Endless #" .. endlessFloor)
        end
        return I18n.t("acts.endless", nil, "Endless")
    end
    local n = actNumber or 1
    return I18n.t("acts.act" .. n, nil,
        (act and act.name) or I18n.t("acts.fallback", { n = n }, "Ato " .. n))
end

return ActSystem
