local U = {}

U.LEVEL_COSTS = { 100, 150, 200, 250, 300 }

U.XP = {
    PER_FLOOR    = 5,
    PER_ACT      = 25,
    VICTORY      = 100,
    PER_ENDLESS  = 15,
    MINIMUM      = 20,
}

U.CLASS_BUNDLES = {
    warrior = {
        { theme = "warrior_1", cards = { "warrior_flame_barrier", "warrior_taunt", "warrior_juggernaut" } },
        { theme = "warrior_2", cards = { "warrior_feed", "warrior_bloodletting", "warrior_helm_of_valor" } },
        { theme = "warrior_3", cards = { "warrior_rage", "warrior_war_cry", "warrior_berserk" } },
        { theme = "warrior_4", cards = { "warrior_immolate", "warrior_ghostly_armor", "warrior_power_through" } },
        { theme = "warrior_5", cards = { "warrior_demon_form", "warrior_spot_weakness", "warrior_eternal_bulwark" } },
    },
    mage = {
        { theme = "mage_1", cards = { "mage_blizzard", "mage_frost_nova", "mage_rainbow" } },
        { theme = "mage_2", cards = { "mage_ball_lightning", "mage_overcharge", "mage_electrodynamics" } },
        { theme = "mage_3", cards = { "mage_doom_and_gloom", "mage_dark_harvest", "mage_echo_form" } },
        { theme = "mage_4", cards = { "mage_fission", "mage_arcane_torrent", "mage_flame_tongue" } },
        { theme = "mage_5", cards = { "mage_meteor_strike", "mage_healing_drop", "mage_primordial_storm" } },
    },
    rogue = {
        { theme = "rogue_1", cards = { "rogue_bouncing_flask", "rogue_catalyst", "rogue_envenom" } },
        { theme = "rogue_2", cards = { "rogue_stiletto", "rogue_accuracy", "rogue_a_thousand_cuts" } },
        { theme = "rogue_3", cards = { "rogue_shadow_dance", "rogue_moonshadow", "rogue_after_image" } },
        { theme = "rogue_4", cards = { "rogue_corpse_explosion", "rogue_executioner", "rogue_expose_weakness" } },
        { theme = "rogue_5", cards = { "rogue_rake", "rogue_calculated_gamble", "rogue_toxin_master" } },
    },
}

U.MILESTONES = {
    { card = "joker_001", kind = "act_cleared", n = 1 },
    { card = "joker_002", kind = "reach_act",   n = 4 },
    { card = "joker_003", kind = "victory" },
}

U.CLASSES = {
    warrior = { always = true, reqKey = "unlock.class.default" },
    mage    = { actCleared = 2, reqKey = "unlock.class.mage_req",  vars = { act = 2 } },
    rogue   = { actCleared = 4, orVictory = true,
                reqKey = "unlock.class.rogue_req", vars = { act = 4 } },
}

U.CLASS_ORDER = { "warrior", "mage", "rogue" }

return U
