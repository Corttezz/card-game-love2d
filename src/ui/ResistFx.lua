local Enemy = require("src.entities.Enemy")
local Resistances = require("src.systems.Resistances")

local ResistFx = {}

ResistFx.KIND = { immune = "immune", resist = "resist", weak = "weakhit" }
ResistFx.SOUND = {
    immune = { name = "armorSound", pitch = 1.45, volume = 0.75 },
    resist = { name = "armorSound", pitch = 1.15, volume = 0.45 },
}
ResistFx.GAP = 0.22

local last = { t = -1, level = nil, n = 0 }
ResistFx._last = last
ResistFx.log = {}

function ResistFx.reset()
    last.t, last.level, last.n = -1, nil, 0
    ResistFx.log = {}
end

local function now()
    return (love.timer and love.timer.getTime()) or 0
end

local function word(level)
    local I18n = require("src.i18n.I18n")
    return I18n.t("resist.float." .. level, nil, level)
end

function ResistFx.wordFor(level)
    return word(level)
end

local function enemyPos()
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if not okER or not ER.getLastPos then return nil end
    return ER.getLastPos()
end

function ResistFx.show(level, dtype, value, opts)
    if not level then return end
    opts = opts or {}
    local t = now()
    if level == last.level and t - last.t < ResistFx.GAP and not opts.force then
        return
    end
    last.t, last.level = t, level
    last.n = last.n + 1
    local entry = { level = level, type = dtype, value = value, dot = opts.dot }
    ResistFx.log[#ResistFx.log + 1] = entry
    if #ResistFx.log > 32 then table.remove(ResistFx.log, 1) end

    local ex, ey = enemyPos()
    if ex and ey then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT then
            FloatingText.spawn(word(level), ex, ey - 64 + (opts.dy or 0),
                { kind = ResistFx.KIND[level] })
        end
    end
    local snd = ResistFx.SOUND[level]
    if snd then
        local okS, Sfx = pcall(require, "src.systems.Sfx")
        if okS then Sfx.play(snd.name, { pitch = snd.pitch, volume = snd.volume }) end
    end
    if level == "immune" then
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then CardFeel.burstAtEnemy("armor", 0.55) end
        local okES, EnemyStates = pcall(require, "src.ui.EnemyStates")
        if okES and EnemyStates.shrug then EnemyStates.shrug() end
    end
end

function ResistFx.onHit(enemy, level, dtype, raw, final)
    ResistFx.show(level, dtype, final)
end

function ResistFx.dotTick(enemy, name, info)
    if not info or not info.level or (info.raw or 0) <= 0 then return false end
    ResistFx.show(info.level, Resistances.DOT_TYPE[name], info.dealt,
        { dot = name, force = true, dy = name == "burn" and 18 or 0 })
    return info.level == "immune"
end

Enemy.onResist = ResistFx.onHit

return ResistFx
