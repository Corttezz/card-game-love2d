local S = {}

S.DIR = "audio/sfx/stingers/"
S.PREFIX = "sting_"

S.STINGERS = {
    miniboss_entrance = { volume = 0.80, hit = 1.35, duck = { gain = 0.30, attack = 0.25, hold = 2.2, release = 1.6 } },
    elite_entrance    = { volume = 0.70, hit = 0.05, duck = { gain = 0.55, attack = 0.15, hold = 0.9, release = 1.0 } },
    victory_small     = { volume = 0.55, duck = { gain = 0.60, attack = 0.08, hold = 0.7, release = 0.8 } },
    victory_elite     = { volume = 0.70, duck = { gain = 0.45, attack = 0.10, hold = 1.3, release = 1.2 } },
    boss_pass         = { volume = 0.85 },
    act_complete      = { volume = 0.70 },
    player_death      = { volume = 0.90 },
    run_victory       = { volume = 0.85 },
    heartbeat         = { volume = 0.55, file = "audio/sfx/boss/boss_heartbeat.mp3" },
}

S.ENTRANCE = {
    mini_boss = { sting = "miniboss_entrance", preDuck = { gain = 0.45, attack = 2.0 }, release = 1.6 },
    elite     = { sting = "elite_entrance", preDuck = { gain = 0.75, attack = 1.2 }, release = 1.0 },
}

S.ENEMY_DEATH = {
    battle = "victory_small",
    elite = "victory_elite",
    mini_boss = "victory_elite",
}

S.BOSS_DEATH = { fade = 3.2, passAt = 2.4 }
S.ACT_COMPLETE_DELAY = 0.35
S.PLAYER_DEATH = { fade = 1.0, hold = 3.2 }
S.VICTORY = { hold = 5.6 }

S.LOW_HP = {
    enter = 0.25, leave = 0.30,
    duck = 0.80, attack = 1.5, release = 1.2,
    filter = 0.45,
    beatEvery = 1.25, beatEveryMin = 0.95,
}

return S
