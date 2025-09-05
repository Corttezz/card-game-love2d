local Card = require("src.cards.base.Card")

AttackCard = {}
setmetatable(AttackCard, {__index = Card})

function AttackCard:new(name, cost, attack, subtype, imagePath)
    return Card.new(self, name, cost, attack, 0, nil, "attack", subtype, imagePath)
end

return AttackCard
