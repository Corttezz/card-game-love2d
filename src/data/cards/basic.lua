-- src/data/cards/basic.lua
-- Cartas basicas (sem classe especifica) e jokers lendarios compartilhados.
-- Fase 7 rebalance: toda carta tem tags explicitas e effects significativos.

return {
    -- ========== BASIC ATTACKS / DEFENSES ==========
    attack_001 = {
        id = "attack_001", name = "The Rock",
        type = "attack", subtype = "iron",
        cost = 1, attack = 7, defense = 0,
        description = "Uma pedra pesada que causa dano fisico.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common",
        tags = { "strike" },
        effects = {},
    },
    attack_002 = {
        id = "attack_002", name = "Blood Sword",
        type = "attack", subtype = "blood",
        cost = 1, attack = 6, defense = 0,
        description = "Espada amaldicoada. Cura 2 HP ao atacar.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common",
        tags = { "strike", "lifesteal" },
        effects = {
            { type = "instant_heal", value = 2, description = "Cura 2 HP ao atacar" },
        },
    },
    defense_001 = {
        id = "defense_001", name = "Iron Shield",
        type = "defense", subtype = "iron",
        cost = 1, attack = 0, defense = 8,
        description = "Escudo resistente de ferro puro.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common",
        tags = { "defend", "armor" },
        effects = {},
    },

    -- ========== WARRIOR-COLORED BASICS (no basic.lua por legado) ==========
    warrior_seeing_red = {
        id = "warrior_seeing_red", name = "Ver Vermelho",
        type = "effect", subtype = "common",
        cost = 1, attack = 0, defense = 0,
        description = "Ganhe +2 de Forca.",
        image = "assets/cards/attack/seeingRed.png",
        rarity = "common", class = "warrior",
        tags = { "strength", "utility" },
        effects = {
            { type = "gain_strength", value = 2, description = "+2 Forca" },
        },
    },
    warrior_rage = {
        id = "warrior_rage", name = "Furia",
        type = "attack", subtype = "common",
        cost = 0, attack = 3, defense = 0,
        description = "3 de dano. Ganhe +1 Forca.",
        image = "assets/cards/attack/rage.png",
        rarity = "common", class = "warrior",
        tags = { "strike", "strength" },
        effects = {
            { type = "gain_strength", value = 1, description = "+1 Forca" },
        },
    },
    attack_cleave = {
        id = "attack_cleave", name = "Cutilada",
        type = "attack", subtype = "common",
        cost = 2, attack = 13, defense = 0,
        description = "Causa 13 de dano.",
        image = "assets/cards/attack/bloodSword.png",
        rarity = "common", class = "basic",
        tags = { "strike" },
        effects = {},
    },
    defense_bulwark = {
        id = "defense_bulwark", name = "Baluarte",
        type = "defense", subtype = "common",
        cost = 2, attack = 0, defense = 13,
        description = "Ganha 13 de Bloqueio.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "basic",
        tags = { "defend", "armor" },
        effects = {},
    },

    warrior_second_wind = {
        id = "warrior_second_wind", name = "Segundo Folego",
        type = "effect", subtype = "common",
        cost = 1, attack = 0, defense = 0,
        description = "Ganha 8 de Bloqueio. Descarta 1 carta aleatoria.",
        image = "assets/cards/attack/secondWind.png",
        rarity = "uncommon", class = "warrior",
        tags = { "discard", "armor", "cycle" },
        effects = {
            -- Rebalance Jul/2026: descarte 2 -> 1 (tira o tempo negativo e diferencia de power_through)
            { type = "discard_cards", value = 1 },
            { type = "add_armor", value = 8, description = "+8 armor" },
        },
    },
    warrior_spot_weakness = {
        id = "warrior_spot_weakness", name = "Achar a Brecha",
        type = "effect", subtype = "common",
        cost = 1, attack = 0, defense = 0,
        description = "Aplique Vulneravel por 2 turnos e ganhe +2 Forca.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "vulnerable", "strength", "debuff" },
        effects = {
            { type = "apply_debuff", value = "vulnerable", stacks = 1, duration = 2 },
            { type = "gain_strength", value = 2, description = "+2 Forca" },
        },
    },

    -- ========== JOKERS LENDARIOS (sempre disponiveis) ==========
    joker_001 = {
        id = "joker_001", name = "Deus do Abismo",
        type = "joker", subtype = "legendary",
        cost = 2, attack = 0, defense = 0,
        description = "+50% de dano em todas as cartas de ataque.",
        image = "assets/jokers/joker1.png",
        rarity = "legendary", class = "basic",
        tags = { "strike", "scaling" },
        effects = {
            { type = "damage_multiplier", target = "attack", value = 1.5,
              description = "+50% de dano em ataques" },
        },
    },
    joker_002 = {
        id = "joker_002", name = "Guardiao do Escudo",
        type = "joker", subtype = "legendary",
        cost = 2, attack = 0, defense = 0,
        description = "+50% de Bloqueio em defesas. Reflete 4 de dano no primeiro Bloqueio de cada turno.",
        image = "assets/jokers/joker1.png",
        rarity = "legendary", class = "basic",
        tags = { "defend", "armor", "scaling" },
        effects = {
            { type = "defense_multiplier", target = "defense", value = 1.5,
              description = "+50% de Bloqueio em defesas" },
            -- Rebalance Jul/2026: reflexo agregado ao x1.5 (que colide com o cap de bloqueio 30/40/50);
            -- como e JOKER, on_defend_damage dispara 1x/turno (regra P2.3, engine em EffectSystem/Game)
            { type = "on_defend_damage", value = 4, description = "Reflete 4 no primeiro Bloqueio do turno" },
        },
    },
    joker_003 = {
        id = "joker_003", name = "Senhor Vampiro",
        type = "joker", subtype = "legendary",
        cost = 2, attack = 0, defense = 0,
        description = "Cura 3 HP a cada ataque.",
        image = "assets/jokers/joker1.png",
        rarity = "legendary", class = "basic",
        tags = { "lifesteal", "heal" },
        effects = {
            { type = "on_attack_heal", value = 3, description = "Cura 3 HP por ataque" },
        },
    },
    joker_004 = {
        id = "joker_004", name = "Bobo da Corte",
        type = "joker", subtype = "rare",
        cost = 1, attack = 0, defense = 0,
        description = "Compra 1 carta extra no inicio do turno.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "basic",
        tags = { "draw", "cycle" },
        effects = {
            { type = "on_turn_start_draw", value = 1, description = "+1 carta por turno" },
        },
    },
    joker_005 = {
        id = "joker_005", name = "Chapeu do Bufao",
        type = "joker", subtype = "rare",
        cost = 1, attack = 0, defense = 0,
        description = "+2 de dano em todas as cartas de ataque.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "basic",
        tags = { "strike", "combo" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 2,
              description = "+2 dano por ataque" },
        },
    },

    -- ========== EFFECTS BASICOS ==========
    effect_mystery_card = {
        id = "effect_mystery_card", name = "Carta Misterio",
        type = "effect", subtype = "mystery",
        cost = 0, attack = 0, defense = 0,
        description = "Efeito aleatorio surpreendente.",
        image = "assets/cards/effect/potionOfHealing.png",
        rarity = "uncommon", class = "basic",
        tags = { "utility" },
        effects = {
            { type = "mystery", description = "Efeito misterioso" },
        },
    },
    effect_scroll_wisdom = {
        id = "effect_scroll_wisdom", name = "Pergaminho da Sabedoria",
        type = "effect", subtype = "scroll",
        cost = 1, attack = 0, defense = 0,
        description = "Compre 3 cartas do deck.",
        image = "assets/cards/effect/manaCrystal.png",
        -- Rebalance Jul/2026: common -> uncommon (nerf preventivo — pos-fix do pool volta a ser
        -- ofertavel; draw 3 por 1 mana em common dominaria mage_arcane_sight e viraria auto-include)
        rarity = "uncommon", class = "basic",
        tags = { "draw", "cycle" },
        effects = {
            { type = "draw_cards", value = 3, description = "Compra 3 cartas" },
        },
    },
}
