-- src/systems/CardDatabase.lua
-- Sistema de banco de dados de cartas baseado em JSON

local CardDatabase = {}
CardDatabase.__index = CardDatabase

-- Cache para dados carregados
local cardData = nil
local deckData = nil

function CardDatabase:new()
    local instance = setmetatable({}, CardDatabase)
    self:loadData()
    return instance
end

-- Carrega dados (versão simplificada sem JSON por enquanto)
function CardDatabase:loadData()
    if not cardData then
        -- Dados hard-coded por enquanto (funciona sem dependências externas)
        cardData = {
            cards = {
                attack_001 = {
                    id = "attack_001",
                    name = "The Rock",
                    type = "attack",
                    subtype = "iron",
                    cost = 1,
                    attack = 10,
                    defense = 0,
                    description = "Uma pedra pesada que causa dano físico.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "common",
                    effects = {}
                },
                attack_002 = {
                    id = "attack_002",
                    name = "Blood Sword",
                    type = "attack",
                    subtype = "blood",
                    cost = 1,
                    attack = 8,
                    defense = 0,
                    description = "Espada amaldiçoada que drena energia.",
                    image = "assets/cards/attack/bloodSword.png",
                    rarity = "common",
                    effects = {}
                },
                defense_001 = {
                    id = "defense_001",
                    name = "Iron Shield",
                    type = "defense",
                    subtype = "iron",
                    cost = 1,
                    attack = 0,
                    defense = 12,
                    description = "Escudo resistente de ferro puro.",
                    image = "assets/cards/defense/ironShield.png",
                    rarity = "common",
                    effects = {}
                },
                warrior_seeing_red = {
                    id = "warrior_seeing_red",
                    name = "Seeing Red",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 10,
                    defense = 0,
                    description = "Causa 10 de dano.",
                    image = "assets/cards/attack/seeingRed.png",
                    rarity = "common",
                    effects = {}
                },
                warrior_rage = {
                    id = "warrior_rage",
                    name = "Rage",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 10,
                    defense = 0,
                    description = "Causa 10 de dano.",
                    image = "assets/cards/attack/rage.png",
                    rarity = "common",
                    effects = {}
                },
                warrior_second_wind = {
                    id = "warrior_second_wind",
                    name = "Second Wind",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 10,
                    defense = 0,
                    description = "Causa 10 de dano.",
                    image = "assets/cards/attack/secondWind.png",
                    rarity = "uncommon",
                    effects = {}
                },
                warrior_spot_weakness = {
                    id = "warrior_spot_weakness",
                    name = "Spot Weakness",
                    type = "attack",
                    subtype = "common",
                    cost = 1,
                    attack = 10,
                    defense = 0,
                    description = "Causa 10 de dano.",
                    image = "assets/cards/attack/theRock.png",
                    rarity = "uncommon",
                    effects = {}
                },
                joker_001 = {
                    id = "joker_001",
                    name = "God of the Abyss",
                    type = "joker",
                    subtype = "triangle",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Dobra o dano de todas as cartas de ataque.",
                    image = "assets/jokers/joker1.png",
                    rarity = "legendary",
                    effects = {
                        {
                            type = "damage_multiplier",
                            target = "attack",
                            value = 2.0,
                            description = "Dobra dano de cartas de ataque"
                        }
                    }
                },
                -- dobrea defesa
                joker_002 = {
                    id = "joker_002",
                    name = "God of the Abyss",
                    type = "joker",
                    subtype = "triangle",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Dobra o dano de todas as cartas de ataque.",
                    image = "assets/jokers/joker1.png",
                    rarity = "legendary",
                    effects = {
                        {
                            type = "defense_multiplier",
                            target = "defense",
                            value = 2.0,
                            description = "Dobra defesa de cartas de defesa"
                        }
                    }
                },
                -- outro joker com outro efeito -- aumenta cura
                joker_003 = {
                    id = "joker_003",
                    name = "God of the Abyss",
                    type = "joker",
                    subtype = "triangle",
                    cost = 2,
                    attack = 0,
                    defense = 0,
                    description = "Aumenta a cura em 3.",
                    image = "assets/jokers/joker1.png",
                    rarity = "legendary",
                    effects = {
                        {
                            type = "heal_multiplier",
                            target = "heal",
                            value = 2.0,
                            description = "Aumenta a cura em 3"
                        }
                    }
                },

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
                }
            }
        }
        
        deckData = {
            decks = {
                starter = {
                    name = "Deck Iniciante",
                    description = "Deck básico para novos jogadores",
                    cards = {
                        {id = "attack_001", quantity = 2},
                        {id = "attack_002", quantity = 1},
                        {id = "defense_001", quantity = 2},
                        {id = "joker_001", quantity = 1}
                    }
                },
                warrior = {
                    name = "Deck Guerreiro",
                    description = "Focado em ataques físicos e resistência",
                    cards = {
                        {id = "attack_001", quantity = 3},
                        {id = "defense_001", quantity = 3},
                        {id = "joker_001", quantity = 1}
                    }
                },
                mage = {
                    name = "Deck Mago",
                    description = "Deck focado em magia e efeitos especiais",
                    cards = {
                        {id = "mage_zap", quantity = 2},
                        {id = "mage_dualcast", quantity = 1},
                        {id = "mage_ball_lightning", quantity = 2},
                        {id = "effect_healing_potion", quantity = 1},
                        {id = "effect_mana_crystal", quantity = 1},
                        {id = "joker_001", quantity = 1}
                    }
                }
            }
        }
    end
end

-- Retorna dados de uma carta específica
function CardDatabase:getCard(cardId)
    self:loadData()
    return cardData and cardData.cards and cardData.cards[cardId]
end

-- Retorna todas as cartas
function CardDatabase:getAllCards()
    self:loadData()
    return cardData and cardData.cards or {}
end

-- Retorna dados de um deck específico
function CardDatabase:getDeck(deckId)
    self:loadData()
    return deckData and deckData.decks and deckData.decks[deckId]
end

-- Retorna todos os decks disponíveis
function CardDatabase:getAllDecks()
    self:loadData()
    return deckData and deckData.decks or {}
end

-- Retorna cartas filtradas por tipo
function CardDatabase:getCardsByType(cardType)
    local allCards = self:getAllCards()
    local filtered = {}
    
    for id, card in pairs(allCards) do
        if card.type == cardType then
            filtered[id] = card
        end
    end
    
    return filtered
end

-- Retorna cartas filtradas por raridade
function CardDatabase:getCardsByRarity(rarity)
    local allCards = self:getAllCards()
    local filtered = {}
    
    for id, card in pairs(allCards) do
        if card.rarity == rarity then
            filtered[id] = card
        end
    end
    
    return filtered
end

-- Cria uma lista de cartas baseada em um deck
function CardDatabase:buildDeckCards(deckId)
    local deck = self:getDeck(deckId)
    if not deck then
        error("Deck não encontrado: " .. tostring(deckId))
    end
    
    local cards = {}
    
    for _, cardEntry in ipairs(deck.cards) do
        local cardData = self:getCard(cardEntry.id)
        if cardData then
            -- Adiciona múltiplas cópias se especificado
            for i = 1, (cardEntry.quantity or 1) do
                table.insert(cards, self:createCardInstance(cardData))
            end
        else
            print("AVISO: Carta não encontrada: " .. cardEntry.id)
        end
    end
    
    return cards
end

-- Cria uma instância de carta baseada nos dados
function CardDatabase:createCardInstance(cardData)
    local AttackCard = require("src.cards.types.AttackCard")
    local DefenseCard = require("src.cards.types.DefenseCard") 
    local JokerCard = require("src.cards.types.JokerCard")
    local EffectCard = require("src.cards.types.EffectCard")
    
    if cardData.type == "attack" then
        local cardInstance = AttackCard:new(
            cardData.name,
            cardData.cost,
            cardData.attack,
            cardData.subtype,
            cardData.image
        )
        -- Adiciona dados adicionais para o novo sistema
        cardInstance.description = cardData.description
        cardInstance.rarity = cardData.rarity
        cardInstance.effects = cardData.effects
        return cardInstance
    elseif cardData.type == "defense" then
        local cardInstance = DefenseCard:new(
            cardData.name,
            cardData.cost,
            cardData.defense,
            cardData.subtype,
            cardData.image
        )
        -- Adiciona dados adicionais para o novo sistema
        cardInstance.description = cardData.description
        cardInstance.rarity = cardData.rarity
        cardInstance.effects = cardData.effects
        return cardInstance
    elseif cardData.type == "joker" then
        -- Para jokers, criamos a função de efeito baseada nos dados
        local effectFunction = self:createEffectFunction(cardData.effects)
        local jokerInstance = JokerCard:new(
            cardData.name,
            cardData.cost,
            effectFunction,
            cardData.subtype,
            cardData.image
        )
        
        -- Adiciona dados adicionais para o novo sistema
        jokerInstance.description = cardData.description
        jokerInstance.effects = cardData.effects
        
        return jokerInstance
    elseif cardData.type == "effect" then
        -- Para cartas de efeito, criamos a função de efeito baseada nos dados
        local effectFunction = self:createEffectFunction(cardData.effects)
        local effectInstance = EffectCard:new(
            cardData.name,
            cardData.cost,
            effectFunction,
            cardData.subtype,
            cardData.image
        )
        
        -- Adiciona dados adicionais para o novo sistema
        effectInstance.description = cardData.description
        effectInstance.rarity = cardData.rarity
        effectInstance.effects = cardData.effects
        
        return effectInstance
    end
    
    error("Tipo de carta desconhecido: " .. tostring(cardData.type))
end

-- Cria função de efeito baseada nos dados JSON
function CardDatabase:createEffectFunction(effects)
    return function(game)
        for _, effect in ipairs(effects or {}) do
            -- Para cartas de efeito, usa o EffectSystem para processar
            if game.effectSystem and game.effectSystem:processEffectCard(game, effect) then
                -- Efeito processado com sucesso
            else
                -- Fallback: apenas mostra mensagem
                if effect.description then
                    game:addMessage(effect.description, "info")
                end
            end
        end
    end
end

-- Valida se um deck é válido
function CardDatabase:validateDeck(deckId)
    local deck = self:getDeck(deckId)
    if not deck then return false, "Deck não encontrado" end
    
    local totalCards = 0
    for _, cardEntry in ipairs(deck.cards) do
        if not self:getCard(cardEntry.id) then
            return false, "Carta inválida: " .. cardEntry.id
        end
        totalCards = totalCards + (cardEntry.quantity or 1)
    end
    
    if totalCards < 5 then
        return false, "Deck muito pequeno (mínimo 5 cartas)"
    end
    
    return true, "Deck válido"
end

return CardDatabase
