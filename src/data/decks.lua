-- src/data/decks.lua
-- Decks predefinidos (modo classico). Formato: {cards = {{id, quantity}, ...}}.

return {
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
