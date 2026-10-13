-- Boss cinematic (src/ui/BossCinematic): name card + epithet and the skip hint.
-- Names match end_screen.enemy.*; the epithet is each boss's element.
return {
    skip = "Skip  {key}",
    carrion_king   = { name = "Carrion King",   epithet = "Sovereign of Crows" },
    tower_lich     = { name = "Tower Lich",     epithet = "Lord of the Frozen Runes" },
    abyss_tyrant   = { name = "Abyss Tyrant",   epithet = "Warden of the Burning Chains" },
    winter_monarch = { name = "Winter Monarch", epithet = "Crown of the Endless Blizzard" },
    rot_colossus   = { name = "Rot Colossus",   epithet = "Heart of the Rotten Roots" },
    eclipse_queen  = { name = "Eclipse Queen",  epithet = "Lady of the Black Sun" },
}
