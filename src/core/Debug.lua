local Release = require("src.core.Release")

local Debug = {}

local level = tonumber(os.getenv("CARDGAME_DEBUG") or "") or 0
Debug.enabled = level >= 1
Debug.verbose = level >= 2

function Debug.setEnabled(on)
    Debug.enabled = on and true or false
end

function Debug.log(...)
    if Debug.enabled then print(...) end
end

function Debug.trace(...)
    if Debug.enabled and Debug.verbose then print(...) end
end

function Debug.warn(...)
    if Debug.enabled or Release.isRelease() then print("[WARN]", ...) end
end

function Debug.err(...)
    if Debug.enabled or Release.isRelease() then print("[ERR]", ...) end
end

return Debug
