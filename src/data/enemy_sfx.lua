local EnemySfxData = {}

EnemySfxData.DIR = "audio/sfx/enemies"

EnemySfxData.EVENTS = {
    hurt   = { volume = 0.42, pitchVar = 0.04, cooldown = 0.18, warn = true },
    death  = { volume = 0.62, pitchVar = 0.03, cooldown = 0.5, warn = true, fallback = "enemyDeath" },
    attack = { volume = 0.40, pitchVar = 0.04, cooldown = 0.6 },
    roar   = { volume = 0.50, pitchVar = 0.04, cooldown = 0.8 },
}

EnemySfxData.ALIAS = {}

return EnemySfxData
