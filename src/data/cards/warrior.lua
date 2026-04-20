-- src/data/cards/warrior.lua
-- Cartas da classe Guerreiro (common / uncommon / rare).

return {
                -- ===== CARTAS UNCOMMON DO GUERREIRO =====
                warrior_flame_barrier = {
                    id = "warrior_flame_barrier",
                    name = "Barreira de Fogo",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 12,
                    description = "Ganha 12 de Bloqueio. Sempre que você receber dano, cause 4 de dano ao atacante.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "warrior",
                    effects = {}
                },
                warrior_ghostly_armor = {
                    id = "warrior_ghostly_armor",
                    name = "Armadura Fantasma",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 10,
                    description = "Etéreo. Ganha 10 de Bloqueio.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "warrior",
                    effects = {}
                },
                warrior_inflame = {
                    id = "warrior_inflame",
                    name = "Inflamar",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Ganha 2 de Força. Ganha 1 de Destreza.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "warrior",
                    effects = {}
                },
                warrior_power_through = {
                    id = "warrior_power_through",
                    name = "Força Interior",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 15,
                    description = "Adiciona 2 Ferimentos ao deck. Ganha 15 de Bloqueio.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "warrior",
                    effects = {}
                },

                -- ===== CARTAS DO GUERREIRO (usando imagens existentes) =====
                warrior_strike = {
                    id = "warrior_strike",
                    name = "Golpe",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 6,
                    defense = 0,
                    description = "Causa 6 de dano.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "warrior",
                    effects = {}
                },
                warrior_defend = {
                    id = "warrior_defend",
                    name = "Defender",
                    type = "defense",
                    subtype = "common",
                    cost = 1,
                    attack = 0,
                    defense = 5,
                    description = "Ganha 5 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "warrior",
                    effects = {}
                },
                warrior_bash = {
                    id = "warrior_bash",
                    name = "Pancada",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 8,
                    defense = 0,
                    description = "Causa 8 de dano. Aplica 2 de Vulnerável.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "warrior",
                    effects = {
                        {
                            type = "apply_debuff",
                            value = "vulnerable",
                            stacks = 2,
                            description = "Aplica Vulnerável"
                        }
                    }
                },
                warrior_iron_wave = {
                    id = "warrior_iron_wave",
                    name = "Onda de Ferro",
                    type = "attack",
                    subtype = "skill",
                    cost = 1,
                    attack = 5,
                    defense = 5,
                    description = "Causa 5 de dano. Ganha 5 de Bloqueio.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "warrior",
                    effects = {}
                },
                warrior_heavy_blade = {
                    id = "warrior_heavy_blade",
                    name = "Lâmina Pesada",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 14,
                    defense = 0,
                    description = "Causa 14 de dano. +3 de dano por Força.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "warrior",
                    effects = {
                        {
                            type = "strength_scaling",
                            value = 3,
                            description = "Dano aumenta com Força"
                        }
                    }
                },

                -- ===== CARTAS RARE DO GUERREIRO =====
                warrior_berserk = {
                    id = "warrior_berserk",
                    name = "Berserk",
                    type = "defense",
                    subtype = "power",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Ganha 1 de Energia no início de cada turno. No início de cada turno, receba 1 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_bloodletting = {
                    id = "warrior_bloodletting",
                    name = "Sangria",
                    type = "attack",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Perde 3 de HP. Ganha 2 de Energia.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_brutality = {
                    id = "warrior_brutality",
                    name = "Brutalidade",
                    type = "defense",
                    subtype = "power",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "No início de cada turno, perde 1 HP e compra 1 carta.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_dark_embrace = {
                    id = "warrior_dark_embrace",
                    name = "Abraço Sombrio",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que uma carta for Exaurida, compre 1 carta.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_demon_form = {
                    id = "warrior_demon_form",
                    name = "Forma Demoníaca",
                    type = "defense",
                    subtype = "power",
                    cost = 3,
                    attack = 0,
                    defense = 0,
                    description = "No início de cada turno, ganha 2 de Força.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_feed = {
                    id = "warrior_feed",
                    name = "Alimentar",
                    type = "attack",
                    subtype = "skill",
                    cost = 1,
                    attack = 5,
                    defense = 0,
                    description = "Causa 5 de dano. Se mata um inimigo não-Chefe, ganhe 3 de HP Max. Exaurir.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_immolate = {
                    id = "warrior_immolate",
                    name = "Imolar",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 21,
                    defense = 0,
                    description = "Causa 21 de dano a TODOS os inimigos. Adiciona 1 Queimadura ao deck.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },
                warrior_juggernaut = {
                    id = "warrior_juggernaut",
                    name = "Juggernaut",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que ganhar Bloqueio, cause 5 de dano a um inimigo aleatório.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "warrior",
                    effects = {}
                },

                -- ===== NOVAS: icones orfaos (2026-04-20) =====
                warrior_plate_mail = {
                    id = "warrior_plate_mail",
                    name = "Cota de Malha",
                    type = "defense",
                    subtype = "skill",
                    cost = 1, attack = 0, defense = 8,
                    description = "Ganha 8 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon", class = "warrior", effects = {},
                },
                warrior_helm_of_valor = {
                    id = "warrior_helm_of_valor",
                    name = "Elmo do Valor",
                    type = "defense",
                    subtype = "common",
                    cost = 1, attack = 0, defense = 6,
                    description = "Ganha 6 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "common", class = "warrior", effects = {},
                },
                warrior_second_heart = {
                    id = "warrior_second_heart",
                    name = "Coracao Dilacerado",
                    type = "joker",
                    subtype = "power",
                    cost = 2, attack = 0, defense = 0,
                    description = "Regenera 2 HP por turno.",
                    image = "assets/jokers/joker1.png",
                    rarity = "rare", class = "warrior",
                    effects = {
                        { type = "regen_per_turn", value = 2,
                          description = "Regen 2 HP por turno" },
                    },
                },
                warrior_shield_slam = {
                    id = "warrior_shield_slam",
                    name = "Escudo Redondo",
                    type = "defense",
                    subtype = "common",
                    cost = 1, attack = 0, defense = 7,
                    description = "Ganha 7 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "common", class = "warrior", effects = {},
                },
                warrior_kite_guard = {
                    id = "warrior_kite_guard",
                    name = "Escudo Templario",
                    type = "defense",
                    subtype = "skill",
                    cost = 2, attack = 0, defense = 10,
                    description = "Ganha 10 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon", class = "warrior", effects = {},
                },
                warrior_quick_strike = {
                    id = "warrior_quick_strike",
                    name = "Golpe Rapido",
                    type = "attack",
                    subtype = "common",
                    cost = 0, attack = 4, defense = 0,
                    description = "Causa 4 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "common", class = "warrior", effects = {},
                },
}
