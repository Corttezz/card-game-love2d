-- src/data/cards/warrior.lua
-- Cartas da classe Guerreiro. Fase 7: tags + effects consistentes.
-- Arquetipos principais: armor stack / strength scaling / thorns / exhaust engine.
-- Rebalance v2 (Jul/2026): 16 mudancas + 4 cartas novas — WC Berserker completa
-- (strength_scaling em twin_strike/colossus), WC Muralha/Thorn (shield_slam common
-- de thorn, juggernaut 6, Baluarte Eterno 8 — thorn de JOKER dispara 1x/turno via
-- P2.3), draw engine (brutality redesign + Grito de Comando), weak defensivo
-- (Provocar) e bateria de mana com Exaurir (Adrenalina, critica A4).

return {
    -- ========== STARTER + COMMON BATTLES ==========
    warrior_strike = {
        id = "warrior_strike", name = "Golpe",
        type = "attack", subtype = "common",
        cost = 1, attack = 8, defense = 0,
        description = "Causa 8 de dano.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "warrior",
        tags = { "strike" },
        effects = {},
    },
    warrior_defend = {
        id = "warrior_defend", name = "Defender",
        type = "defense", subtype = "common",
        cost = 1, attack = 0, defense = 7,
        description = "Ganha 7 de Bloqueio.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "warrior",
        tags = { "defend", "armor" },
        effects = {},
    },
    warrior_quick_strike = {
        id = "warrior_quick_strike", name = "Golpe Rapido",
        type = "attack", subtype = "common",
        cost = 0, attack = 3, defense = 0,
        description = "Custo 0. 3 de dano. Conta em DOBRO para combos.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "warrior",
        tags = { "strike", "zero_cost", "combo" },
        effects = {},
    },
    -- Rebalance v2 (Jul/2026): REDESIGN — era duplicata exata de warrior_defend;
    -- virou a common de thorn que o thorn_reflex nao tinha. Thorn de CARTA reflete
    -- por carta jogada (a regra 1x/turno do P2.3 e SO para jokers).
    warrior_shield_slam = {
        id = "warrior_shield_slam", name = "Escudo de Espinhos",
        type = "defense", subtype = "common",
        cost = 1, attack = 0, defense = 5,
        description = "Ganha 5 de Bloqueio. Reflete 3 de dano ao defender.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "warrior",
        tags = { "defend", "armor", "thorn" },
        effects = {
            { type = "on_defend_damage", value = 3, description = "Reflete 3 ao defender" },
        },
    },
    warrior_helm_of_valor = {
        id = "warrior_helm_of_valor", name = "Elmo do Valor",
        type = "defense", subtype = "common",
        cost = 1, attack = 0, defense = 6,
        -- Rebalance v2 (Jul/2026): instant_heal 1 -> 3 (com floor no heal_multiplier, 3x1.5=4).
        description = "Ganha 6 de Bloqueio e cura 3 de HP.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "common", class = "warrior",
        tags = { "defend", "armor", "heal" },
        effects = {
            { type = "instant_heal", value = 3, description = "Cura 3 HP" },
        },
    },
    warrior_bash = {
        id = "warrior_bash", name = "Pancada",
        type = "attack", subtype = "skill",
        cost = 2, attack = 10, defense = 0,
        description = "10 de dano. Aplica Vulneravel (2 turnos).",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "warrior",
        tags = { "strike", "vulnerable", "debuff" },
        effects = {
            { type = "apply_debuff", value = "vulnerable", stacks = 1, duration = 2,
              description = "Aplica Vulneravel por 2 turnos" },
        },
    },
    warrior_iron_wave = {
        id = "warrior_iron_wave", name = "Onda de Ferro",
        type = "attack", subtype = "skill",
        cost = 1, attack = 5, defense = 0,
        description = "5 de dano. +5 armor tambem.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "warrior",
        tags = { "strike", "armor", "defend" },
        effects = {
            { type = "add_armor", value = 5, description = "+5 armor" },
        },
    },
    warrior_heavy_blade = {
        id = "warrior_heavy_blade", name = "Lamina Pesada",
        type = "attack", subtype = "skill",
        cost = 2, attack = 12, defense = 0,
        description = "12 de dano. Forca conta em DOBRO.",
        image = "assets/cards/attack/theRock.png",
        rarity = "common", class = "warrior",
        tags = { "strike", "strength", "scaling", "finisher" },
        effects = {
            { type = "strength_scaling", description = "+dano por Forca" },
        },
    },

    -- ========== UNCOMMON ==========
    warrior_flame_barrier = {
        id = "warrior_flame_barrier", name = "Barreira de Fogo",
        type = "defense", subtype = "power",
        cost = 2, attack = 0, defense = 12,
        -- Rebalance v2 (Jul/2026): on_defend_damage 4 -> 7; tag 'fire' removida (morta, poluia afinidade).
        description = "Ganha 12 de Bloqueio. Reflete 7 de dano ao defender.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "thorn" },
        effects = {
            { type = "on_defend_damage", value = 7, description = "Reflete 7 ao defender" },
        },
    },
    warrior_ghostly_armor = {
        id = "warrior_ghostly_armor", name = "Armadura Fantasma",
        type = "defense", subtype = "power",
        cost = 1, attack = 0, defense = 10,
        description = "10 de Bloqueio. Exaurir.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "exhaust" },
        effects = { { type = "exhaust" } },
    },
    warrior_inflame = {
        id = "warrior_inflame", name = "Inflamar",
        type = "effect", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        -- Rebalance v2 (Jul/2026): gain_dexterity 1 -> 2 (degrau real sobre seeing_red, common +2 Forca).
        description = "+2 de Forca e +2 de Destreza.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "strength", "dexterity", "utility" },
        effects = {
            { type = "gain_strength", value = 2 },
            { type = "gain_dexterity", value = 2 },
        },
    },
    warrior_power_through = {
        id = "warrior_power_through", name = "Forca Interior",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 9,
        -- Rebalance v2 (Jul/2026): discard_cards 2 -> 1 (preserva a tag discard p/ cycle_motion).
        description = "Ganha 9 de Bloqueio. Descarta 1 carta aleatoria.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "discard" },
        effects = {
            { type = "discard_cards", value = 1 },
        },
    },
    warrior_plate_mail = {
        id = "warrior_plate_mail", name = "Cota de Malha",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 8,
        description = "Ganha 8 de Bloqueio. +1 Destreza nesta batalha.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "dexterity" },
        effects = {
            { type = "gain_dexterity", value = 1 },
        },
    },
    -- Rebalance v2 (Jul/2026): FIX TRAP — ganhou retain (era dominada por 2x Defender);
    -- vira setup contra intents grandes (intent congelado permite planejar).
    warrior_kite_guard = {
        id = "warrior_kite_guard", name = "Escudo Templario",
        type = "defense", subtype = "skill",
        cost = 2, attack = 0, defense = 14,
        retain = true,
        description = "Ganha 14 de Bloqueio. Retencao: nao e descartada no fim do turno.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "retain" },
        effects = {},
    },

    warrior_war_cry = {
        id = "warrior_war_cry", name = "Grito de Guerra",
        type = "effect", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        -- Rebalance v2 (Jul/2026): gain_strength 3 -> 4 (corrige inversao vs seeing_red common +2).
        description = "+4 de Forca.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "strength", "scaling" },
        effects = {
            { type = "gain_strength", value = 4 },
        },
    },
    warrior_twin_strike = {
        id = "warrior_twin_strike", name = "Golpe Duplo",
        type = "attack", subtype = "skill",
        cost = 2, attack = 7, defense = 0,
        -- Rebalance v2 (Jul/2026): attack 6 -> 7 + strength_scaling (era dominada pela common heavy_blade).
        description = "Causa 7 de dano, 2 vezes. Forca conta em DOBRO.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "strike" },
        effects = {
            { type = "multi_hit", value = 2 },
            { type = "strength_scaling", description = "+dano por Forca" },
        },
    },
    warrior_iron_discipline = {
        id = "warrior_iron_discipline", name = "Disciplina de Ferro",
        type = "defense", subtype = "skill",
        cost = 2, attack = 0, defense = 12,
        -- Rebalance v2 (Jul/2026): defense 10 -> 12 (ponte Muralha->Berserker na banda uncommon C2).
        description = "Ganha 12 de Bloqueio. +1 de Forca.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "strength" },
        effects = {
            { type = "gain_strength", value = 1 },
        },
    },

    -- Rebalance v2 (Jul/2026): NOVA — weak defensivo (era rogue-only); tech contra o boss A2.
    -- Weak so REDUZ o intent congelado (invariante preservado).
    warrior_taunt = {
        id = "warrior_taunt", name = "Provocar",
        type = "defense", subtype = "skill",
        cost = 1, attack = 0, defense = 6,
        description = "Ganha 6 de Bloqueio. Aplica Fraco por 2 turnos.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "uncommon", class = "warrior",
        tags = { "defend", "armor", "debuff", "weak" },
        effects = {
            { type = "apply_debuff", value = "weak", stacks = 1, duration = 2,
              description = "Aplica Fraco por 2 turnos" },
        },
    },
    -- Rebalance v2 (Jul/2026): NOVA — warrior tinha ZERO draw fora de Sangria (rare);
    -- destrava cycle_motion pra classe.
    warrior_battle_orders = {
        id = "warrior_battle_orders", name = "Grito de Comando",
        type = "effect", subtype = "skill",
        cost = 1, attack = 0, defense = 0,
        description = "Compre 2 cartas. +1 de Forca.",
        image = "assets/cards/attack/theRock.png",
        rarity = "uncommon", class = "warrior",
        tags = { "draw", "cycle", "scaling" },
        effects = {
            { type = "draw_cards", value = 2 },
            { type = "gain_strength", value = 1 },
        },
    },

    -- ========== RARE ==========
    warrior_colossus_blow = {
        id = "warrior_colossus_blow", name = "Golpe Colossal",
        type = "attack", subtype = "skill",
        cost = 3, attack = 24, defense = 0,
        -- Rebalance v2 (Jul/2026): + strength_scaling (rare vanilla dominada por 3x Golpe);
        -- remate do Berserker no A3 (~87 com 12 Forca + combos).
        description = "Causa 24 de dano. Forca conta em DOBRO.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strike", "finisher" },
        effects = {
            { type = "strength_scaling", description = "+dano por Forca" },
        },
    },
    warrior_bastion = {
        id = "warrior_bastion", name = "Bastiao",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "Seu Bloqueio NAO expira: acumula entre turnos.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "warrior",
        tags = { "defend", "armor", "scaling" },
        effects = {
            { type = "retain_armor" },
        },
    },
    warrior_standard_bearer = {
        id = "warrior_standard_bearer", name = "Porta-Estandarte",
        type = "joker", subtype = "power",
        cost = 1, attack = 0, defense = 0,
        description = "+3 de dano em todos os ataques.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "warrior",
        tags = { "strike", "scaling" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 3 },
        },
    },
    warrior_berserk = {
        id = "warrior_berserk", name = "Berserk",
        type = "joker", subtype = "power",
        cost = 0, attack = 0, defense = 0,
        -- Rebalance v2 (Jul/2026): damage_bonus 2 -> 5 (versao high-risk do estandarte:
        -- +5 sujo vs +3 limpo; bonus FLAT soma normalmente, largest-wins e so p/ multiplicadores).
        description = "+5 de dano em todos os ataques. Perde 2 HP por turno.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strike", "scaling" },
        effects = {
            { type = "damage_bonus", target = "attack", value = 5 },
            { type = "damage_per_turn", value = 2 },
        },
    },
    warrior_bloodletting = {
        id = "warrior_bloodletting", name = "Sangria",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        description = "Perde 3 HP. +2 Forca. Compre 1 carta.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strength", "draw", "cycle" },
        effects = {
            { type = "self_damage", value = 3 },
            { type = "gain_strength", value = 2 },
            { type = "draw_cards", value = 1 },
        },
    },
    -- Rebalance v2 (Jul/2026): REDESIGN — era dominada por second_heart+standard_bearer;
    -- vira o motor de draw do warrior (identidade StS Brutality). on_turn_start_draw
    -- so itera jokerSlots — correto, e joker.
    warrior_brutality = {
        id = "warrior_brutality", name = "Brutalidade",
        type = "joker", subtype = "power",
        cost = 0, attack = 0, defense = 0,
        description = "Compra 1 carta extra no inicio de cada turno. Perde 1 HP por turno.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "draw", "cycle", "scaling" },
        effects = {
            { type = "on_turn_start_draw", value = 1 },
            { type = "damage_per_turn", value = 1 },
        },
    },
    -- Rebalance v2 (Jul/2026): REDESIGN — era dominada por juggernaut; primeiro uso do
    -- heal_multiplier (sinergia com helm_of_valor/feed/second_heart/rest; floor via P2.4).
    warrior_dark_embrace = {
        id = "warrior_dark_embrace", name = "Abraco Sombrio",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+3 de Bloqueio em cartas de defesa. Todas as curas recebidas sao aumentadas em 50%.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "defend", "heal", "dark", "passive" },
        effects = {
            { type = "defense_bonus", target = "defense", value = 3 },
            { type = "heal_multiplier", value = 1.5 },
        },
    },
    warrior_demon_form = {
        id = "warrior_demon_form", name = "Forma Demoniaca",
        type = "joker", subtype = "power",
        cost = 3, attack = 0, defense = 0,
        description = "+2 de Forca no inicio de cada turno.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strength", "strike", "finisher" },
        effects = {
            { type = "strength_per_turn", value = 2 },
        },
    },
    warrior_feed = {
        id = "warrior_feed", name = "Alimentar",
        type = "attack", subtype = "skill",
        cost = 1, attack = 12, defense = 0,
        -- Rebalance v2 (Jul/2026): attack 10 -> 12, instant_heal 5 -> 8 (burst de sustain
        -- digno de rare; ancora do Vampiro). Exhaust = 1x por batalha.
        description = "Causa 12 de dano. Cura 8 de HP. Exaurir.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strike", "lifesteal", "exhaust", "finisher" },
        effects = {
            { type = "instant_heal", value = 8 },
            { type = "exhaust" },
        },
    },
    warrior_immolate = {
        id = "warrior_immolate", name = "Imolar",
        type = "attack", subtype = "skill",
        cost = 2, attack = 18, defense = 0,
        -- Rebalance v2 (Jul/2026): tags 'aoe' (mentira mecanica, jogo single-enemy) e
        -- 'fire' (morta) removidas; numeros mantidos.
        description = "18 de dano. Aplica Vulneravel. Exaurir.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "strike", "exhaust", "finisher" },
        effects = {
            { type = "apply_debuff", value = "vulnerable", stacks = 1, duration = 2 },
            { type = "exhaust" },
        },
    },
    -- Rebalance v2 (Jul/2026): on_defend_damage 3 -> 6; como JOKER, o reflexo dispara
    -- 1x/turno (regra P2.3) — com Baluarte (8) + joker_002 (4) = 18/turno de jokers.
    warrior_juggernaut = {
        id = "warrior_juggernaut", name = "Juggernaut",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+3 de Bloqueio em defesas. Reflete 6 de dano no primeiro Bloqueio de cada turno.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "defend", "armor", "thorn" },
        effects = {
            { type = "defense_bonus", target = "defense", value = 3 },
            { type = "on_defend_damage", value = 6 },
        },
    },
    warrior_second_heart = {
        id = "warrior_second_heart", name = "Coracao Dilacerado",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "Regenera 2 HP por turno.",
        image = "assets/jokers/joker1.png",
        rarity = "rare", class = "warrior",
        tags = { "heal" },
        effects = {
            { type = "regen_per_turn", value = 2 },
        },
    },
    -- Rebalance v2 (Jul/2026): NOVA (critica A4) — bateria de mana COM Exaurir:
    -- 1x/batalha, sem loop de mana no reshuffle; sem dominancia vs rogue_adrenaline (C0 sem custo de HP).
    warrior_adrenaline_rush = {
        id = "warrior_adrenaline_rush", name = "Adrenalina",
        type = "effect", subtype = "skill",
        cost = 0, attack = 0, defense = 0,
        exhaust = true,
        description = "Perde 4 de HP. Restaura 2 de mana e compre 1 carta. Exaurir.",
        image = "assets/cards/attack/theRock.png",
        rarity = "rare", class = "warrior",
        tags = { "mana", "zero_cost", "cycle", "draw" },
        effects = {
            { type = "self_damage", value = 4 },
            { type = "restore_mana", value = 2 },
            { type = "draw_cards", value = 1 },
        },
    },

    -- ========== LEGENDARY ==========
    -- Rebalance v2 (Jul/2026): NOVA — capstone da Muralha/Thorn; como joker o reflexo
    -- dispara 1x/turno (regra P2.3). Tripwire: winrate Muralha >65% -> 8 vira 6.
    warrior_eternal_bulwark = {
        id = "warrior_eternal_bulwark", name = "Baluarte Eterno",
        type = "joker", subtype = "power",
        cost = 2, attack = 0, defense = 0,
        description = "+2 de Bloqueio em defesas. Reflete 8 de dano no primeiro Bloqueio de cada turno.",
        image = "assets/cards/defense/ironShield.png",
        rarity = "legendary", class = "warrior",
        tags = { "defend", "thorn", "passive" },
        effects = {
            { type = "defense_bonus", target = "defense", value = 2 },
            { type = "on_defend_damage", value = 8, description = "Reflete 8 no primeiro Bloqueio do turno" },
        },
    },
}
