local M = {}

-- Mapa com a escala de interface do jogo de verdade (SHOT_K). O testkit fixa a escala em 1,
-- então aqui a escala pedida vence esse force(1).
function M.run(tag)
    local UiScale = require("src.ui.UiScale")
    local k = tonumber(os.getenv("SHOT_K") or "") or 1.25
    local force = UiScale.force
    UiScale.force = function() return force(k) end
    force(k)
    return require("tools.shot_act_map_v4").run(tag)
end

return M
