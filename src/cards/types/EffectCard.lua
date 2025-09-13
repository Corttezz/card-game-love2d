local Card = require("src.cards.base.Card")

EffectCard = {}
setmetatable(EffectCard, {__index = Card})

function EffectCard:new(name, cost, effectFunction, subtype, imagePath)
    return Card.new(self, name, cost, 0, 0, effectFunction, "effect", subtype, imagePath)
end

return EffectCard
