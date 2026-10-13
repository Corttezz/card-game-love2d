local M = {}
function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    local I18n = require("src.i18n.I18n"); I18n.init(); I18n.setLocale("fr")
    print("[p] antes do Game: " .. I18n.t("reward.continue") .. " locale=" .. tostring(I18n.getLocale and I18n.getLocale()))
    local Game = require("src.core.Game")
    local game = Game:new(); game:startNewRun("warrior"); game:startGame()
    print("[p] depois do Game: " .. I18n.t("reward.continue") .. " locale=" .. tostring(I18n.getLocale and I18n.getLocale()))
    local s = require("components.CardRewardScreen"):new(game.shopSystem)
    s:show(game, function() end, function() end, "shop")
    print("[p] skipButton.text=" .. tostring(s.skipButton and s.skipButton.text) .. " locale=" .. tostring(I18n.getLocale and I18n.getLocale()))
    return true
end
return M
