-- src/data/cards/rogue.lua
-- Cartas da classe Ladino (common / uncommon / rare).

return {
                
                -- ===== CARTAS DO LADINO (usando imagens existentes) =====
                rogue_strike = {
                    id = "rogue_strike",
                    name = "Golpe Furtivo",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 6,
                    defense = 0,
                    description = "Causa 6 de dano.",
                    image = "assets/cards/attack/bloodSword.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "rogue",
                    effects = {}
                },
                rogue_defend = {
                    id = "rogue_defend",
                    name = "Esquiva",
                    type = "defense",
                    subtype = "common",
                    cost = 1,
                    attack = 0,
                    defense = 5,
                    description = "Ganha 5 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "rogue",
                    effects = {}
                },
                rogue_survivor = {
                    id = "rogue_survivor",
                    name = "Sobrevivente",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 8,
                    description = "Ganha 8 de Bloqueio. Descarta 1 carta.",
                    image = "assets/cards/defense/ironShield.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "rogue",
                    effects = {
                        {
                            type = "discard_cards",
                            value = 1,
                            description = "Descarta 1 carta"
                        }
                    }
                },
                rogue_neutralize = {
                    id = "rogue_neutralize",
                    name = "Neutralizar",
                    type = "attack",
                    subtype = "skill",
                    cost = 0,
                    attack = 3,
                    defense = 0,
                    description = "Causa 3 de dano. Aplica 1 de Fraco.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "rogue",
                    effects = {
                        {
                            type = "apply_debuff",
                            value = "weak",
                            stacks = 1,
                            description = "Aplica Fraco"
                        }
                    }
                },
                rogue_backstab = {
                    id = "rogue_backstab",
                    name = "Punhalada pelas Costas",
                    type = "attack",
                    subtype = "skill",
                    cost = 0,
                    attack = 11,
                    defense = 0,
                    description = "Causa 11 de dano. Só pode ser jogada se não foi modificada neste turno. Exaurir.",
                    image = "assets/cards/attack/bloodSword.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "rogue",
                    effects = {
                        {
                            type = "exhaust",
                            description = "Carta é removida após uso"
                        },
                        {
                            type = "innate",
                            description = "Começa na mão"
                        }
                    }
                },

                -- ===== CARTAS UNCOMMON DO LADINO =====
                rogue_accuracy = {
                    id = "rogue_accuracy",
                    name = "Precisão",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Shivs causam 4 de dano adicional.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_acrobatics = {
                    id = "rogue_acrobatics",
                    name = "Acrobacias",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Compre 3 cartas. Descarte 1 carta.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_adrenaline = {
                    id = "rogue_adrenaline",
                    name = "Adrenalina",
                    type = "defense",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Ganha 1 de Energia. Coloque 1 Cansaço em seu deck. Exaurir.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_blur = {
                    id = "rogue_blur",
                    name = "Borrão",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 5,
                    description = "Ganha 5 de Bloqueio. O próximo turno você compra 1 carta a menos.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_bouncing_flask = {
                    id = "rogue_bouncing_flask",
                    name = "Frasco Ricochete",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 3,
                    defense = 0,
                    description = "Aplique 3 de Veneno a um inimigo aleatório 3 vezes.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_calculated_gamble = {
                    id = "rogue_calculated_gamble",
                    name = "Aposta Calculada",
                    type = "defense",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Descarte sua mão. Compre o mesmo número de cartas.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_caltrops = {
                    id = "rogue_caltrops",
                    name = "Estrepes",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que você receber dano não-bloqueado, cause 3 de dano ao atacante.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },
                rogue_catalyst = {
                    id = "rogue_catalyst",
                    name = "Catalisador",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Dobre todo o Veneno de um inimigo. Exaurir.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "rogue",
                    effects = {}
                },

                -- ===== CARTAS RARE DO LADINO =====
                rogue_a_thousand_cuts = {
                    id = "rogue_a_thousand_cuts",
                    name = "Mil Cortes",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que jogar uma carta, cause 1 de dano a TODOS os inimigos.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_after_image = {
                    id = "rogue_after_image",
                    name = "Pós-imagem",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que jogar uma carta, ganhe 1 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_bullet_time = {
                    id = "rogue_bullet_time",
                    name = "Tempo-bala",
                    type = "defense",
                    subtype = "skill",
                    cost = 3,
                    attack = 0,
                    defense = 0,
                    description = "Todas as cartas custam 0 neste turno. Não pode ser jogada se não for a única carta na mão.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_corpse_explosion = {
                    id = "rogue_corpse_explosion",
                    name = "Explosão de Cadáver",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Aplique Veneno a um inimigo igual à sua HP atual. Exaurir.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_doppelganger = {
                    id = "rogue_doppelganger",
                    name = "Sósia",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Ganhe uma cópia da próxima carta de Ataque ou Poder que jogar neste turno.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_envenom = {
                    id = "rogue_envenom",
                    name = "Envenenar",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Sempre que uma carta de Ataque não-bloqueada causar dano, aplique 1 de Veneno.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },
                rogue_storm_of_steel = {
                    id = "rogue_storm_of_steel",
                    name = "Tempestade de Aço",
                    type = "attack",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Adicione 1 Shiv à sua mão por carta descartada neste turno.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "rare",
                    class = "rogue",
                    effects = {}
                },

                -- ===== NOVAS: icones orfaos (2026-04-20) =====
                rogue_stiletto = {
                    id = "rogue_stiletto",
                    name = "Estilete",
                    type = "attack", subtype = "common",
                    cost = 1, attack = 5, defense = 0,
                    description = "Causa 5 de dano.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "common", class = "rogue", effects = {},
                },
                rogue_rake = {
                    id = "rogue_rake",
                    name = "Garra Rapida",
                    type = "attack", subtype = "skill",
                    cost = 1, attack = 4, defense = 0,
                    description = "Causa 4 de dano. Aplica 1 de Fraco.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "common", class = "rogue",
                    effects = { { type = "apply_debuff", value = "weak", stacks = 1,
                                  description = "Aplica Fraco" } },
                },
                rogue_venom_fang = {
                    id = "rogue_venom_fang",
                    name = "Presa Venenosa",
                    type = "attack", subtype = "skill",
                    cost = 1, attack = 3, defense = 0,
                    description = "Causa 3 de dano. Aplica 3 de Veneno.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "uncommon", class = "rogue",
                    effects = { { type = "apply_debuff", value = "poison", stacks = 3,
                                  description = "Aplica Veneno" } },
                },
                rogue_blue_elixir = {
                    id = "rogue_blue_elixir",
                    name = "Elixir Azul",
                    type = "effect", subtype = "potion",
                    cost = 1, attack = 0, defense = 0,
                    description = "Restaura 3 de mana.",
                    image = "assets/cards/effect/manaCrystal.png",
                    rarity = "common", class = "rogue",
                    effects = { { type = "restore_mana", value = 3,
                                  description = "Restaura 3 mana" } },
                },
                rogue_death_mark = {
                    id = "rogue_death_mark",
                    name = "Marca da Morte",
                    type = "joker", subtype = "power",
                    cost = 2, attack = 0, defense = 0,
                    description = "+2 dano em todas as cartas de ataque.",
                    image = "assets/jokers/joker1.png",
                    rarity = "rare", class = "rogue",
                    effects = { { type = "damage_bonus", target = "attack", value = 2,
                                  description = "+2 dano" } },
                },
                rogue_moonshadow = {
                    id = "rogue_moonshadow",
                    name = "Sombra da Lua",
                    type = "defense", subtype = "skill",
                    cost = 1, attack = 0, defense = 6,
                    description = "Ganha 6 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon", class = "rogue", effects = {},
                },
                rogue_shooting_star = {
                    id = "rogue_shooting_star",
                    name = "Medalhao Estelar",
                    type = "attack", subtype = "skill",
                    cost = 2, attack = 12, defense = 0,
                    description = "Causa 12 de dano.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "rare", class = "rogue", effects = {},
                },
}
