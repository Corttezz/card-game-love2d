local M = {}

function M.active()
    return os.getenv("CARDGAME_HEADLESS") == "1"
end

function M.hide()
    if not M.active() then return false end
    if M._hidden then return true end
    if not (love and love.window and love.window.setTitle) then return false end
    local okffi, ffi = pcall(require, "ffi")
    if not okffi or ffi.os ~= "Windows" then
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
        user32.ShowWindow(hwnd, 0)
    end)
    if not ok then
        return false
    end
    M._hidden = true
    return true
end

return M
