-- src/core/Debug.lua
-- Logger condicional. Use em vez de print() direto para poder silenciar em release.

local Debug = {}

-- master switch: desligado em RELEASE (Debug.err continua indo pro log).
Debug.enabled = require("src.core.Release").isDev()
Debug.verbose = false     -- logs de hover/mouse/draw (muito ruidoso)

-- Log normal (info).
function Debug.log(...)
    if Debug.enabled then
        print(...)
    end
end

-- Log opcional para rastreamento denso (hover, posições).
function Debug.trace(...)
    if Debug.enabled and Debug.verbose then
        print(...)
    end
end

function Debug.warn(...)
    if Debug.enabled then
        print("[WARN]", ...)
    end
end

function Debug.err(...)
    print("[ERR]", ...)
end

return Debug
