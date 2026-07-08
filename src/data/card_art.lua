-- src/data/card_art.lua
-- Atlas visual: cada ID de carta mapeia para uma composição única.
-- Formato de entrada:
--   {
--     icon       = string,    -- nome em PixelIcons (sword_short, bolt, skull, ...)
--     bg         = string,    -- padrão de fundo (ver CardFrame: blood/storm/ice/...)
--     accent     = string,    -- cor de destaque (Palette.<NAME>)
--     effect     = string?,   -- "glow" | "holo" | nil (auto pela raridade se nil)
--     decoration = string?,   -- "sparks" | "dust" | "smoke" | "flash" | nil
--   }
--
-- Cartas sem entrada recebem fallback derivado de (type, class, rarity).
--
-- 2026-04-20: cada carta agora tem ícone único em assets/sprites/icons/<card_id>.png
-- geradas via PixelLab MCP. Cartas listadas que mantêm ícones do pool original
-- (sword_great, axe, skull_crowned, mask, coin, potion_red, joker_*) já eram únicos.

return {
    -- ===== BASIC =====
    attack_001              = { icon = "attack_001",             bg = "stone",   accent = "ATTACK",       decoration = "sparks" },
    attack_002              = { icon = "attack_002",             bg = "blood",   accent = "MAGENTA_DARK", decoration = "flash"  },
    defense_001             = { icon = "defense_001",            bg = "metal",   accent = "DEFENSE",      decoration = "sparks" },
    warrior_seeing_red      = { icon = "warrior_seeing_red",     bg = "rage",    accent = "MAGENTA",      decoration = "flash"  },
    warrior_rage            = { icon = "warrior_rage",           bg = "fire",    accent = "ORANGE",       decoration = "sparks" },
    warrior_second_wind     = { icon = "warrior_second_wind",    bg = "wind",    accent = "YELLOW",       decoration = "dust"   },
    warrior_spot_weakness   = { icon = "warrior_spot_weakness",  bg = "void",    accent = "PURPLE",       decoration = "smoke"  },

    joker_001               = { icon = "joker_abyss",    bg = "abyss",   accent = "AGED_GOLD",  effect = "holo" },
    joker_002               = { icon = "joker_shield",   bg = "abyss",   accent = "AGED_GOLD",  effect = "holo" },
    joker_003               = { icon = "joker_vampire",  bg = "abyss",   accent = "AGED_GOLD",  effect = "holo" },
    joker_004               = { icon = "joker_jester",   bg = "abyss",   accent = "AGED_GOLD",  effect = "holo" },

    -- ===== NOVAS (gameplay-overhaul Jul/2026 — scaling/payoffs) =====
    warrior_bastion         = { icon = "warrior_bastion",         bg = "metal",   accent = "AGED_GOLD", effect = "holo" },
    warrior_war_cry         = { icon = "warrior_war_cry",         bg = "rage",    accent = "MAGENTA",   decoration = "flash"  },
    warrior_twin_strike     = { icon = "warrior_twin_strike",     bg = "impact",  accent = "ATTACK",    decoration = "sparks" },
    warrior_iron_discipline = { icon = "warrior_iron_discipline", bg = "metal",   accent = "DEFENSE",   decoration = "sparks" },
    warrior_colossus_blow   = { icon = "warrior_colossus_blow",   bg = "impact",  accent = "ORANGE",    decoration = "flash"  },
    warrior_standard_bearer = { icon = "warrior_standard_bearer", bg = "rage",    accent = "AGED_GOLD", effect = "holo" },
    mage_overcharge         = { icon = "mage_overcharge",         bg = "storm",   accent = "CYAN",      decoration = "sparks" },
    mage_arcane_focus       = { icon = "mage_arcane_focus",       bg = "arcane",  accent = "PURPLE",    decoration = "smoke"  },
    mage_mind_spike         = { icon = "mage_mind_spike",         bg = "void",    accent = "PURPLE",    decoration = "flash"  },
    mage_twin_bolts         = { icon = "mage_twin_bolts",         bg = "storm",   accent = "YELLOW",    decoration = "sparks" },
    mage_arcane_torrent     = { icon = "mage_arcane_torrent",     bg = "arcane",  accent = "MAGENTA",   decoration = "flash"  },
    rogue_venom_coating     = { icon = "rogue_venom_coating",     bg = "poison",  accent = "MOSS",      decoration = "smoke"  },
    rogue_twin_fangs        = { icon = "rogue_twin_fangs",        bg = "poison",  accent = "MOSS",      decoration = "sparks" },
    rogue_expose_weakness   = { icon = "rogue_expose_weakness",   bg = "void",    accent = "PURPLE",    decoration = "flash"  },
    rogue_shadow_dance      = { icon = "rogue_shadow_dance",      bg = "shadow",  accent = "PURPLE",    decoration = "smoke"  },
    rogue_executioner       = { icon = "rogue_executioner",       bg = "blood",   accent = "ATTACK",    decoration = "flash"  },
    attack_cleave           = { icon = "attack_cleave",           bg = "impact",  accent = "ATTACK",    decoration = "sparks" },
    defense_bulwark         = { icon = "defense_bulwark",         bg = "stone",   accent = "DEFENSE",   decoration = "dust"   },

    -- ===== WARRIOR =====
    warrior_flame_barrier   = { icon = "warrior_flame_barrier",  bg = "fire",    accent = "ORANGE",       decoration = "sparks" },
    warrior_ghostly_armor   = { icon = "warrior_ghostly_armor",  bg = "ghost",   accent = "CYAN_PALE",    decoration = "smoke"  },
    warrior_inflame         = { icon = "warrior_inflame",        bg = "fire",    accent = "MAGENTA",      decoration = "sparks" },
    warrior_power_through   = { icon = "warrior_power_through",  bg = "stone",   accent = "ORANGE",       decoration = "dust"   },
    warrior_strike          = { icon = "warrior_strike",         bg = "impact",  accent = "MAGENTA",      decoration = "sparks" },
    warrior_defend          = { icon = "warrior_defend",         bg = "metal",   accent = "CYAN",         decoration = "sparks" },
    warrior_bash            = { icon = "axe",                    bg = "impact",  accent = "ORANGE",       decoration = "sparks" },
    warrior_iron_wave       = { icon = "warrior_iron_wave",      bg = "wave",    accent = "CYAN",         decoration = "sparks" },
    warrior_heavy_blade     = { icon = "sword_great",            bg = "stone",   accent = "ORANGE",       decoration = "dust"   },
    warrior_berserk         = { icon = "warrior_berserk",        bg = "rage",    accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    warrior_bloodletting    = { icon = "warrior_bloodletting",   bg = "blood",   accent = "MAGENTA_DARK", decoration = "flash", effect = "glow" },
    warrior_brutality       = { icon = "warrior_brutality",      bg = "blood",   accent = "MAGENTA",      decoration = "smoke", effect = "glow" },
    warrior_dark_embrace    = { icon = "warrior_dark_embrace",   bg = "void",    accent = "PURPLE",       decoration = "smoke", effect = "glow" },
    warrior_demon_form      = { icon = "skull_crowned",          bg = "fire",    accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    warrior_feed            = { icon = "warrior_feed",           bg = "blood",   accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    warrior_immolate        = { icon = "warrior_immolate",       bg = "fire",    accent = "ORANGE",       decoration = "sparks", effect = "glow" },
    warrior_juggernaut      = { icon = "warrior_juggernaut",     bg = "impact",  accent = "YELLOW",       decoration = "sparks", effect = "glow" },

    -- ===== MAGE =====
    mage_zap                = { icon = "mage_zap",               bg = "storm",   accent = "YELLOW",       decoration = "flash" },
    mage_dualcast           = { icon = "mage_dualcast",          bg = "arcane",  accent = "PURPLE",       decoration = "sparks" },
    mage_ball_lightning     = { icon = "mage_ball_lightning",    bg = "storm",   accent = "YELLOW",       decoration = "flash" },
    mage_aggregate          = { icon = "mage_aggregate",         bg = "arcane",  accent = "CYAN",         decoration = "sparks" },
    mage_auto_shields       = { icon = "mage_auto_shields",      bg = "arcane",  accent = "CYAN",         decoration = "sparks" },
    mage_blizzard           = { icon = "mage_blizzard",          bg = "ice",     accent = "CYAN",         decoration = "dust"   },
    mage_boot_sequence      = { icon = "mage_boot_sequence",     bg = "arcane",  accent = "YELLOW",       decoration = "sparks" },
    mage_chill              = { icon = "mage_chill",             bg = "ice",     accent = "CYAN_PALE",    decoration = "dust"   },
    mage_consume            = { icon = "mage_consume",           bg = "void",    accent = "PURPLE",       decoration = "smoke"  },
    mage_doom_and_gloom     = { icon = "mage_doom_and_gloom",    bg = "void",    accent = "PURPLE",       decoration = "smoke", effect = "glow" },
    mage_force_field        = { icon = "mage_force_field",       bg = "arcane",  accent = "CYAN",         decoration = "sparks" },
    mage_buffer             = { icon = "mage_buffer",            bg = "arcane",  accent = "PURPLE",       decoration = "sparks", effect = "glow" },
    mage_creative_ai        = { icon = "mage_creative_ai",       bg = "arcane",  accent = "CYAN",         decoration = "sparks", effect = "glow" },
    mage_echo_form          = { icon = "mage_echo_form",         bg = "arcane",  accent = "PINK",         decoration = "sparks", effect = "glow" },
    mage_electrodynamics    = { icon = "mage_electrodynamics",   bg = "storm",   accent = "YELLOW",       decoration = "flash", effect = "glow" },
    mage_fission            = { icon = "mage_fission",           bg = "arcane",  accent = "ORANGE",       decoration = "flash", effect = "glow" },
    mage_machine_learning   = { icon = "mage_machine_learning",  bg = "arcane",  accent = "GREEN_BRIGHT", decoration = "sparks", effect = "glow" },
    mage_meteor_strike      = { icon = "mage_meteor_strike",     bg = "fire",    accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    mage_rainbow            = { icon = "mage_rainbow",           bg = "arcane",  accent = "PINK",         decoration = "sparks", effect = "holo" },
    effect_healing_potion   = { icon = "potion_red",             bg = "soft",    accent = "MAGENTA",      decoration = "sparks" },
    effect_mana_crystal     = { icon = "effect_mana_crystal",    bg = "arcane",  accent = "CYAN",         decoration = "sparks" },

    -- ===== ROGUE =====
    rogue_strike            = { icon = "rogue_strike",           bg = "impact",  accent = "GREEN_BRIGHT", decoration = "sparks" },
    rogue_defend            = { icon = "rogue_defend",           bg = "wind",    accent = "CYAN",         decoration = "dust"   },
    rogue_survivor          = { icon = "rogue_survivor",         bg = "wind",    accent = "CYAN",         decoration = "dust"   },
    rogue_neutralize        = { icon = "rogue_neutralize",       bg = "poison",  accent = "GREEN_BRIGHT", decoration = "sparks" },
    rogue_backstab          = { icon = "rogue_backstab",         bg = "blood",   accent = "MAGENTA_DARK", decoration = "flash"  },
    rogue_accuracy          = { icon = "rogue_accuracy",         bg = "wind",    accent = "YELLOW",       decoration = "sparks" },
    rogue_acrobatics        = { icon = "rogue_acrobatics",       bg = "wind",    accent = "CYAN_PALE",    decoration = "dust"   },
    rogue_adrenaline        = { icon = "rogue_adrenaline",       bg = "impact",  accent = "MAGENTA",      decoration = "sparks" },
    rogue_blur              = { icon = "rogue_blur",             bg = "shadow",  accent = "PURPLE",       decoration = "smoke"  },
    rogue_bouncing_flask    = { icon = "rogue_bouncing_flask",   bg = "poison",  accent = "GREEN_BRIGHT", decoration = "sparks" },
    rogue_calculated_gamble = { icon = "coin",                   bg = "wind",    accent = "YELLOW",       decoration = "sparks" },
    rogue_caltrops          = { icon = "rogue_caltrops",         bg = "metal",   accent = "CYAN",         decoration = "sparks" },
    rogue_catalyst          = { icon = "rogue_catalyst",         bg = "poison",  accent = "GREEN_BRIGHT", decoration = "smoke"  },
    rogue_a_thousand_cuts   = { icon = "rogue_a_thousand_cuts",  bg = "blood",   accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    rogue_after_image       = { icon = "rogue_after_image",      bg = "shadow",  accent = "CYAN_PALE",    decoration = "smoke", effect = "glow" },
    rogue_bullet_time       = { icon = "rogue_bullet_time",      bg = "shadow",  accent = "PURPLE",       decoration = "smoke", effect = "glow" },
    rogue_corpse_explosion  = { icon = "rogue_corpse_explosion", bg = "blood",   accent = "MAGENTA",      decoration = "flash", effect = "glow" },
    rogue_doppelganger      = { icon = "mask",                   bg = "shadow",  accent = "PURPLE",       decoration = "smoke", effect = "glow" },
    rogue_envenom           = { icon = "rogue_envenom",          bg = "poison",  accent = "GREEN_BRIGHT", decoration = "smoke", effect = "glow" },
    rogue_storm_of_steel    = { icon = "rogue_storm_of_steel",   bg = "storm",   accent = "CYAN",         decoration = "flash", effect = "glow" },

    -- ===== NOVAS (2026-04-20): reaproveitando icones do pool original =====
    -- Warrior
    warrior_plate_mail      = { icon = "armor_plate",            bg = "metal",   accent = "CYAN",         decoration = "sparks" },
    warrior_helm_of_valor   = { icon = "helm",                   bg = "metal",   accent = "ORANGE",       decoration = "sparks" },
    warrior_second_heart    = { icon = "heart",                  bg = "blood",   accent = "MAGENTA",      decoration = "flash",  effect = "glow" },
    warrior_shield_slam     = { icon = "shield_round",           bg = "impact",  accent = "ORANGE",       decoration = "sparks" },
    warrior_kite_guard      = { icon = "shield_kite",            bg = "metal",   accent = "YELLOW",       decoration = "sparks" },
    warrior_quick_strike    = { icon = "sword_short",            bg = "impact",  accent = "CYAN",         decoration = "sparks" },
    -- Mage
    mage_lightning          = { icon = "bolt",                   bg = "storm",   accent = "YELLOW",       decoration = "flash" },
    mage_fireball           = { icon = "fireball",               bg = "fire",    accent = "ORANGE",       decoration = "sparks" },
    mage_flame_tongue       = { icon = "flame",                  bg = "fire",    accent = "ORANGE",       decoration = "sparks" },
    mage_crystal_shard      = { icon = "crystal",                bg = "arcane",  accent = "CYAN",         decoration = "sparks" },
    mage_frost_nova         = { icon = "snowflake",              bg = "ice",     accent = "CYAN_PALE",    decoration = "dust"   },
    mage_healing_drop       = { icon = "water_drop",             bg = "soft",    accent = "CYAN",         decoration = "sparks" },
    mage_arcane_orb         = { icon = "orb",                    bg = "arcane",  accent = "PURPLE",       decoration = "sparks" },
    mage_rune_of_power      = { icon = "rune",                   bg = "arcane",  accent = "AGED_GOLD",    decoration = "sparks", effect = "glow" },
    mage_sages_gem          = { icon = "gem",                    bg = "arcane",  accent = "PURPLE",       decoration = "sparks", effect = "glow" },
    mage_arcane_sight       = { icon = "eye",                    bg = "arcane",  accent = "PURPLE",       decoration = "smoke"  },
    mage_magic_barrier      = { icon = "barrier",                bg = "arcane",  accent = "CYAN",         decoration = "sparks" },
    -- Rogue
    rogue_stiletto          = { icon = "dagger",                 bg = "impact",  accent = "GREEN_BRIGHT", decoration = "sparks" },
    rogue_rake              = { icon = "claw",                   bg = "rage",    accent = "GREEN_BRIGHT", decoration = "flash"  },
    rogue_venom_fang        = { icon = "fang",                   bg = "poison",  accent = "GREEN_BRIGHT", decoration = "sparks" },
    rogue_blue_elixir       = { icon = "potion_blue",            bg = "poison",  accent = "CYAN",         decoration = "sparks" },
    rogue_death_mark        = { icon = "skull",                  bg = "shadow",  accent = "PURPLE",       decoration = "smoke",  effect = "glow" },
    rogue_moonshadow        = { icon = "moon",                   bg = "shadow",  accent = "PURPLE",       decoration = "smoke"  },
    rogue_shooting_star     = { icon = "star",                   bg = "wind",    accent = "YELLOW",       decoration = "sparks", effect = "glow" },
    -- Basic/Effect/Joker
    effect_scroll_wisdom    = { icon = "scroll",                 bg = "soft",    accent = "AGED_GOLD",    decoration = "sparks" },
    effect_mystery_card     = { icon = "question",               bg = "arcane",  accent = "PURPLE",       decoration = "sparks" },
    joker_005               = { icon = "jester_hat",             bg = "abyss",   accent = "AGED_GOLD",    effect = "holo" },
}
