-- src/data/cards/mage.lua
-- Cartas da classe Mago (common / uncommon / rare) + cartas de efeito (potions).

return {
                -- ===== CARTAS DO MAGO (usando imagens existentes) =====
                mage_zap = {
                    id = "mage_zap",
                    name = "Descarga",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 4,
                    defense = 0,
                    description = "Causa 4 de dano. Canaliza 1 Raio.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "mage",
                    effects = {
                        {
                            type = "channel_orb",
                            value = "lightning",
                            description = "Canaliza orbe de raio"
                        }
                    }
                },
                mage_dualcast = {
                    id = "mage_dualcast",
                    name = "Conjuração Dupla",
                    type = "defense",
                    subtype = "common",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Evoca o orbe mais à direita 2x.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "mage",
                    effects = {
                        {
                            type = "evoke_orb",
                            value = 2,
                            description = "Evoca orbe 2 vezes"
                        }
                    }
                },
                mage_ball_lightning = {
                    id = "mage_ball_lightning",
                    name = "Raio Esférico",
                    type = "attack",
                    subtype = "skill",
                    cost = 1,
                    attack = 7,
                    defense = 0,
                    description = "Causa 7 de dano. Canaliza 1 Raio.",
                    image = "assets/cards/attack/theRock.png", -- Reutiliza imagem existente
                    rarity = "common",
                    class = "mage",
                    effects = {
                        {
                            type = "channel_orb",
                            value = "lightning",
                            description = "Canaliza orbe de raio"
                        }
                    }
                },

                -- ===== CARTAS UNCOMMON DO MAGO =====
                mage_aggregate = {
                    id = "mage_aggregate",
                    name = "Agregar",
                    type = "defense",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Canaliza 1 orbe por carta em sua mão.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_auto_shields = {
                    id = "mage_auto_shields",
                    name = "Escudos Automáticos",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "No início de cada turno, se você não tem Bloqueio, ganha 11 de Bloqueio.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_blizzard = {
                    id = "mage_blizzard",
                    name = "Nevasca",
                    type = "attack",
                    subtype = "skill",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Causa 2 de dano a TODOS os inimigos por orbe canalizado.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_boot_sequence = {
                    id = "mage_boot_sequence",
                    name = "Sequência de Boot",
                    type = "defense",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Inato. Canaliza 1 orbe de Raio.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_chill = {
                    id = "mage_chill",
                    name = "Congelar",
                    type = "defense",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Inato. Canaliza 1 orbe de Gelo.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_consume = {
                    id = "mage_consume",
                    name = "Consumir",
                    type = "defense",
                    subtype = "skill",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Ganha 2 de Foco. Perde 1 slot de orbe.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_doom_and_gloom = {
                    id = "mage_doom_and_gloom",
                    name = "Perdição e Melancolia",
                    type = "attack",
                    subtype = "skill",
                    cost = 2,
                    attack = 10,
                    defense = 0,
                    description = "Causa 10 de dano a TODOS os inimigos. Canaliza 1 orbe de Escuridão.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },
                mage_force_field = {
                    id = "mage_force_field",
                    name = "Campo de Força",
                    type = "defense",
                    subtype = "skill",
                    cost = 4,
                    attack = 0,
                    defense = 0,
                    description = "Ganha Bloqueio igual à quantidade de orbes canalizados.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "uncommon",
                    class = "mage",
                    effects = {}
                },

                -- ===== CARTAS RARE DO MAGO =====
                mage_buffer = {
                    id = "mage_buffer",
                    name = "Buffer",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Ganhe 1 de Artefato.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_creative_ai = {
                    id = "mage_creative_ai",
                    name = "IA Criativa",
                    type = "defense",
                    subtype = "power",
                    cost = 3,
                    attack = 0,
                    defense = 0,
                    description = "No início de cada turno, adicione 1 carta de Poder aleatória à sua mão.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_echo_form = {
                    id = "mage_echo_form",
                    name = "Forma de Eco",
                    type = "defense",
                    subtype = "power",
                    cost = 3,
                    attack = 0,
                    defense = 0,
                    description = "Etéreo. A primeira carta que você jogar a cada turno será jogada duas vezes.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_electrodynamics = {
                    id = "mage_electrodynamics",
                    name = "Eletrodinâmica",
                    type = "defense",
                    subtype = "power",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Orbes de Raio atingem 2 inimigos aleatórios.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_fission = {
                    id = "mage_fission",
                    name = "Fissão",
                    type = "defense",
                    subtype = "skill",
                    cost = 0,
                    attack = 0,
                    defense = 0,
                    description = "Evoca TODOS os orbes. Ganha 1 de Energia por orbe evocado.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_machine_learning = {
                    id = "mage_machine_learning",
                    name = "Aprendizado de Máquina",
                    type = "defense",
                    subtype = "power",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Inato. No início de cada turno, compre 1 carta adicional.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_meteor_strike = {
                    id = "mage_meteor_strike",
                    name = "Chuva de Meteoros",
                    type = "attack",
                    subtype = "skill",
                    cost = 5,
                    attack = 24,
                    defense = 0,
                    description = "Causa 24 de dano a um inimigo aleatório 3 vezes. Canaliza 3 orbes de Plasma.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },
                mage_rainbow = {
                    id = "mage_rainbow",
                    name = "Arco-íris",
                    type = "defense",
                    subtype = "skill",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Canaliza 1 orbe de Raio, 1 orbe de Gelo e 1 orbe de Escuridão.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "rare",
                    class = "mage",
                    effects = {}
                },

    -- ===== CARTAS DE EFEITO (Mage) =====
                -- ===== CARTAS DE EFEITO =====
                effect_healing_potion = {
                    id = "effect_healing_potion",
                    name = "Potion of Healing",
                    type = "effect",
                    subtype = "potion",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Cura 15 HP instantaneamente.",
                    image = "assets/cards/effect/potionOfHealing.png",
                    rarity = "common",
                    class = "mage",
                    effects = {
                        {
                            type = "instant_heal",
                            value = 15,
                            description = "Cura 15 HP"
                        }
                    }
                },
                effect_mana_crystal = {
                    id = "effect_mana_crystal",
                    name = "Mana Crystal",
                    type = "effect",
                    subtype = "crystal",
                    cost = 1,
                    attack = 0,
                    defense = 0,
                    description = "Aumenta a mana máxima em 3 para esta fase.",
                    image = "assets/cards/effect/manaCrystal.png",
                    rarity = "common",
                    class = "mage",
                    effects = {
                        {
                            type = "increase_max_mana",
                            value = 3,
                            description = "Mana máxima +3"
                        }
                    }
                },

                -- ===== NOVAS: icones orfaos (2026-04-20) =====
                mage_lightning = {
                    id = "mage_lightning",
                    name = "Relampago",
                    type = "attack", subtype = "common",
                    cost = 1, attack = 8, defense = 0,
                    description = "Causa 8 de dano. Canaliza 1 Raio.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "common", class = "mage",
                    effects = { { type = "channel_orb", value = "lightning",
                                  description = "Canaliza orbe de raio" } },
                },
                mage_fireball = {
                    id = "mage_fireball",
                    name = "Bola de Fogo",
                    type = "attack", subtype = "common",
                    cost = 2, attack = 10, defense = 0,
                    description = "Causa 10 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "common", class = "mage", effects = {},
                },
                mage_flame_tongue = {
                    id = "mage_flame_tongue",
                    name = "Lingua de Chamas",
                    type = "attack", subtype = "common",
                    cost = 1, attack = 6, defense = 0,
                    description = "Causa 6 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "common", class = "mage", effects = {},
                },
                mage_crystal_shard = {
                    id = "mage_crystal_shard",
                    name = "Cristal de Sangue",
                    type = "attack", subtype = "skill",
                    cost = 1, attack = 7, defense = 0,
                    description = "Causa 7 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon", class = "mage", effects = {},
                },
                mage_frost_nova = {
                    id = "mage_frost_nova",
                    name = "Nova de Gelo",
                    type = "attack", subtype = "skill",
                    cost = 2, attack = 5, defense = 0,
                    description = "Causa 5 de dano. Canaliza 1 orbe de Gelo.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon", class = "mage",
                    effects = { { type = "channel_orb", value = "frost",
                                  description = "Canaliza orbe de gelo" } },
                },
                mage_healing_drop = {
                    id = "mage_healing_drop",
                    name = "Gota Curativa",
                    type = "effect", subtype = "potion",
                    cost = 1, attack = 0, defense = 0,
                    description = "Cura 10 HP.",
                    image = "assets/cards/effect/potionOfHealing.png",
                    rarity = "common", class = "mage",
                    effects = { { type = "instant_heal", value = 10,
                                  description = "Cura 10 HP" } },
                },
                mage_arcane_orb = {
                    id = "mage_arcane_orb",
                    name = "Orbe Arcano",
                    type = "effect", subtype = "orb",
                    cost = 1, attack = 0, defense = 0,
                    description = "Canaliza 1 Orbe arcano.",
                    image = "assets/cards/effect/manaCrystal.png",
                    rarity = "common", class = "mage",
                    effects = { { type = "channel_orb", value = "arcane",
                                  description = "Canaliza orbe arcano" } },
                },
                mage_rune_of_power = {
                    id = "mage_rune_of_power",
                    name = "Runa do Poder",
                    type = "joker", subtype = "power",
                    cost = 2, attack = 0, defense = 0,
                    description = "+3 de dano em cartas de ataque.",
                    image = "assets/jokers/joker1.png",
                    rarity = "rare", class = "mage",
                    effects = { { type = "damage_bonus", target = "attack", value = 3,
                                  description = "+3 dano" } },
                },
                mage_sages_gem = {
                    id = "mage_sages_gem",
                    name = "Gema do Sabio",
                    type = "joker", subtype = "power",
                    cost = 1, attack = 0, defense = 0,
                    description = "+1 carta no inicio do turno.",
                    image = "assets/jokers/joker1.png",
                    rarity = "rare", class = "mage",
                    effects = { { type = "draw_extra", value = 1,
                                  description = "+1 carta por turno" } },
                },
                mage_arcane_sight = {
                    id = "mage_arcane_sight",
                    name = "Visao Arcana",
                    type = "effect", subtype = "skill",
                    cost = 1, attack = 0, defense = 0,
                    description = "Compre 2 cartas.",
                    image = "assets/cards/effect/manaCrystal.png",
                    rarity = "uncommon", class = "mage",
                    effects = { { type = "draw_cards", value = 2,
                                  description = "Compra 2 cartas" } },
                },
                mage_magic_barrier = {
                    id = "mage_magic_barrier",
                    name = "Amuleto Arcano",
                    type = "defense", subtype = "skill",
                    cost = 1, attack = 0, defense = 8,
                    description = "Ganha 8 de Bloqueio magico.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "common", class = "mage", effects = {},
                },
}
