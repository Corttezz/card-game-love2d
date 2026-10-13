local M = {}
function M.run()
    local I18n = require("src.i18n.I18n"); I18n.init()
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        I18n.setLocale(loc)
        print(("[k] %s continue=%q skip=%q buy=%q"):format(loc, I18n.t("reward.continue"), I18n.t("reward.skip_no_card"), I18n.t("reward.detail_buy")))
    end
    I18n.setLocale("pt_BR")
    return true
end
return M
