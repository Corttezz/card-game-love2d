local M = {}

function M.run(arg)
    local off = {}
    for k in (os.getenv("SB_OFF") or ""):gmatch("[^,]+") do off[k] = true end
    local CS = require("engine.ContactShadow")
    local SE = require("engine.ShadowEngine")
    if off.contact then CS.queue = function() return true end end
    if off.disc then CS.queueDisc = function() end end
    if off.shadow then SE.queue = function() return true end end
    local tag = os.getenv("REVISAO_TAG") or "raw"
    local suffix = os.getenv("SB_OFF") and ("_sem_" .. os.getenv("SB_OFF"):gsub(",", "_")) or ""
    local R = require("tools.revisao_cenas")
    local realGetenv = os.getenv
    os.getenv = function(k)
        if k == "REVISAO_TAG" then return tag .. suffix end
        return realGetenv(k)
    end
    local ok = R.run(arg)
    os.getenv = realGetenv
    return ok
end

return M
