local Card = require("src.cards.base.Card")

JokerCard = {}
setmetatable(JokerCard, {__index = Card})

function JokerCard:new(name, cost, passive, subtype, imagePath)
    return Card.new(self, name, cost, 0, 0, passive, "joker", subtype, imagePath)
end

return JokerCard
