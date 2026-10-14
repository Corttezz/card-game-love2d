local Config = require("src.core.Config")

local ActSystem = {}

function ActSystem.getActConfig(actNumber)
    actNumber = actNumber or 1
    local totalActs = Config.TotalActs or 3
    if actNumber <= totalActs then
        return Config.Acts[actNumber], false
    end
    return Config.Acts[totalActs], true
end

function ActSystem.getEnemyStats(actNumber, floorInAct, nodeType, endlessFloor)
    nodeType = nodeType or "battle"
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if not act then return { health = 20, damage = 5, kind = "battle" } end

    local hp, dmg

    if nodeType == "boss" then
        hp, dmg = act.bossHP or 200, act.bossDmg or 20
    elseif nodeType == "mini_boss" then
        hp  = math.floor((act.bossHP or 200) * 0.7)
        dmg = math.floor((act.bossDmg or 20) * 0.8)
    else
        hp  = math.floor(act.enemyHP(floorInAct))
        dmg = math.floor(act.enemyDmg(floorInAct))
        if nodeType == "elite" then
            local hpMul = act.eliteHPMul or 1.5
            if Config.Game and Config.Game.ELITE_RAMP and hpMul > (Config.Game.ELITE_RAMP_START or hpMul) then
                local t = math.max(0, math.min(1, ((floorInAct or 1) - 1) / 7))
                local start = Config.Game.ELITE_RAMP_START
                hpMul = start + (hpMul - start) * t
            end
            hp  = math.floor(hp * hpMul)
            dmg = math.floor(dmg * (act.eliteDmgMul or 1.25))
        end
    end

    if isEndless then
        local n = endlessFloor or floorInAct
        if (nodeType == "boss" or nodeType == "mini_boss") and endlessFloor and floorInAct then
            n = math.max(1, endlessFloor - floorInAct + 1)
        end
        local fh, fd = ActSystem.endlessFactors(n)
        hp  = math.floor(hp * fh)
        dmg = math.floor(dmg * fd)
    end

    local pw = Config.Game and Config.Game.ENEMY_POWER
    local byAct = Config.Game and Config.Game.ENEMY_POWER_BY_ACT
    local pa = byAct and byAct[math.min(actNumber or 1, Config.TotalActs or #byAct)]
    if pw or pa then
        local hm = ((pw and pw.health) or 1) * ((pa and pa.health) or 1)
        local dm = ((pw and pw.damage) or 1) * ((pa and pa.damage) or 1)
        hp  = math.floor(hp * hm)
        dmg = math.floor(dmg * dm)
    end
    return { health = hp, damage = dmg, kind = nodeType }
end

function ActSystem.endlessFactors(n)
    local E = Config.Endless
    n = math.max(0, (n or 1) - 1)
    local fh = math.exp((E.HP_LIN or 0) * n + (E.HP_QUAD or 0) * n * n)
    local fd = math.exp((E.DMG_LIN or 0) * n + (E.DMG_QUAD or 0) * n * n)
    return fh, fd
end

function ActSystem.getRarityWeights(actNumber)
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if isEndless then return Config.Endless.rarityWeights or { common = 10, uncommon = 35, rare = 45, legendary = 10 } end
    return (act and act.rarityWeights) or { common = 70, uncommon = 25, rare = 5, legendary = 0 }
end

function ActSystem.getInterActHealPercent(actNumber)
    local act, isEndless = ActSystem.getActConfig(actNumber)
    if isEndless then return 0 end
    return (act and act.interActHeal) or 0
end

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
