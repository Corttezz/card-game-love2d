-- src/core/Debug.lua
-- Logger condicional. Use em vez de print() direto para poder silenciar em release.
--
-- Niveis:
--   log   — info de desenvolvimento (boot, "tela aberta", compras). So em DEV.
--   trace — rastreamento denso (hover, posicoes). So em DEV com Debug.verbose.
--   warn  — FALLBACK: algo faltou e o jogo seguiu de outro jeito. Vai pro log
--           tambem em RELEASE (CLAUDE.md §9: fallback silencioso e proibido —
--           o log do jogador e o unico rastro que sobra num bug report).
--   err   — erro recuperado. Sempre.

local Debug = {}

-- master switch de log/trace: desligado em RELEASE (warn/err continuam).
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
    print("[WARN]", ...)
end

function Debug.err(...)
    print("[ERR]", ...)
end

return Debug
