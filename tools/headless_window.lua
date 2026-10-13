-- tools/headless_window.lua
-- ZERO JANELA VISIVEL na bateria de balanceamento (requisito do dono,
-- Out/2026: "varias janelas do Grimoire" apareciam durante as baterias).
--
-- Com CARDGAME_HEADLESS=1 o conf.lua ja faz a janela nascer 1x1, sem borda,
-- em (-32000, -32000). Falta tira-la da BARRA DE TAREFAS: a LOVE nao tem API
-- pra esconder a propria janela, entao no Windows usamos user32 via FFI
-- (ShowWindow SW_HIDE) na janela deste processo — achada pelo titulo, que
-- antes trocamos por um unico (o `love.exe .` do dono tambem se chama
-- "Grimoire" e NUNCA pode ser tocado). Esconder de FORA (balance.py via
-- ctypes) nao funcionava: o SDL re-mostra a janela se o SW_HIDE chega antes
-- do fim da criacao — aqui chamamos DEPOIS, de dentro do proprio processo.
--
-- Fora do Windows / sem FFI: AVISA e segue (a janela 1x1 fora da tela ja nao
-- aparece em monitor nenhum).

local M = {}

function M.active()
    return os.getenv("CARDGAME_HEADLESS") == "1"
end

-- Devolve true se escondeu. Idempotente.
function M.hide()
    if not M.active() then return false end
    if M._hidden then return true end
    if not (love and love.window and love.window.setTitle) then return false end
    local okffi, ffi = pcall(require, "ffi")
    if not okffi or ffi.os ~= "Windows" then
        print("[headless_window] sem FFI/Windows — janela 1x1 fora da tela, nao escondida")
        return false
    end
    local ok, err = pcall(function()
        ffi.cdef [[
            void* FindWindowA(const char* cls, const char* title);
            int ShowWindow(void* hwnd, int cmd);
        ]]
        local user32 = ffi.load("user32")
        local title = ("grimoire-sim-%d-%d"):format(os.time(), math.floor(os.clock() * 1e6) % 1000000)
        love.window.setTitle(title)
        local hwnd = user32.FindWindowA(nil, title)
        if hwnd == nil then error("FindWindowA nao achou a janela '" .. title .. "'") end
        user32.ShowWindow(hwnd, 0)   -- SW_HIDE
    end)
    if not ok then
        print("[headless_window] nao consegui esconder a janela: " .. tostring(err))
        return false
    end
    M._hidden = true
    return true
end

return M
