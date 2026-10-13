-- tools/probe_shop_i18n.lua: chaves I18n usadas pela loja que caem no fallback
-- em algum dos 5 idiomas. love . test_one probe_shop_i18n
local M = {}
function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    local files = { "src/ui/shop/ShopScene.lua", "src/ui/shop/ShelfItem.lua", "components/CardRewardScreen.lua",
        "components/PackOpenScreen.lua", "src/ui/CardDetailPanel.lua", "src/ui/UpgradeTile.lua", "src/ui/PackSleeve.lua",
        "src/ui/PackThemes.lua", "src/ui/PackChoiceLayout.lua", "src/ui/StatusTooltip.lua", "src/ui/HelpBadge.lua" }
    local keys = {}
    for _, f in ipairs(files) do
        local src = love.filesystem.read(f) or ""
        for k in src:gmatch('I18n%.t%(%s*"([%w_%.]+)"') do keys[k] = f end
    end
    for _, k in ipairs({ "status.scribe_dice_help.name", "status.scribe_dice_help.desc", "unlocks.new_badge",
        "reward.buy_sold", "reward.buy_no_gold", "shop.bell_plate", "shop.dice_plate" }) do keys[k] = "manual" end
    local bad = 0
    for _, loc in ipairs(I18n.getAvailable()) do
        I18n.setLocale(loc)
        for k, f in pairs(keys) do
            local v = I18n.t(k, nil, "__MISSING__")
            if v == "__MISSING__" or v == k then
                print(("[i18n] %s FALTA %s (%s)"):format(loc, k, f)); bad = bad + 1
            end
        end
    end
    I18n.setLocale("pt_BR")
    print("[i18n] faltando: " .. bad)
    return true
end
return M
