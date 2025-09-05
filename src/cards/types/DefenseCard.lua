local Card = require("src.cards.base.Card")

DefenseCard = {}
setmetatable(DefenseCard, {__index = Card})

function DefenseCard:new(name, cost, defense, subtype, imagePath)
    return Card.new(self, name, cost, 0, defense, nil, "defense", subtype, imagePath)
end

return DefenseCard
