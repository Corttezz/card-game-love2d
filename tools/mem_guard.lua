local ffi = require("ffi")

local M = {}

M.CAP_MB = tonumber(os.getenv("TEST_MEM_CAP") or "4000")
M.PRESENT_EVERY = tonumber(os.getenv("TEST_MEM_PRESENT") or "4")
M.CHECK_EVERY = 32
M.current = "?"
M.peakSeen = 0

pcall(ffi.cdef, [[
typedef struct { unsigned long cb; unsigned long PageFaultCount; size_t PeakWorkingSetSize; size_t WorkingSetSize;
  size_t QuotaPeakPagedPoolUsage; size_t QuotaPagedPoolUsage; size_t QuotaPeakNonPagedPoolUsage;
  size_t QuotaNonPagedPoolUsage; size_t PagefileUsage; size_t PeakPagefileUsage; } ESTRADA_PMC;
void* GetCurrentProcess(void);
int K32GetProcessMemoryInfo(void* h, ESTRADA_PMC* c, unsigned long cb);
]])

function M.mem()
    local luaMB = collectgarbage("count") / 1024
    local ok, priv, peak = pcall(function()
        local c = ffi.new("ESTRADA_PMC")
        c.cb = ffi.sizeof(c)
        ffi.C.K32GetProcessMemoryInfo(ffi.C.GetCurrentProcess(), c, c.cb)
        return tonumber(c.PagefileUsage) / 1048576, tonumber(c.PeakPagefileUsage) / 1048576
    end)
    if not ok then priv, peak = -1, -1 end
    return luaMB, priv, peak
end

function M.check(where)
    local _, priv = M.mem()
    if priv > M.peakSeen then M.peakSeen = priv end
    if priv > M.CAP_MB then
        print(string.format("[FAIL] memoria do processo %.0f MB passou do teto %d MB em %s (%s)", priv, M.CAP_MB,
            tostring(M.current), tostring(where or "")))
        io.stdout:flush()
        os.exit(3)
    end
    return priv
end

function M.install()
    if M.installed then return end
    M.installed = true
    local g = love.graphics
    local setCanvas, present = g.setCanvas, g.present
    local n, k = 0, 0
    g.setCanvas = function(...)
        setCanvas(...)
        if select("#", ...) == 0 or (...) == nil then
            n = n + 1
            if M.PRESENT_EVERY > 0 and n >= M.PRESENT_EVERY then
                n = 0
                pcall(present)
            end
            k = k + 1
            if k >= M.CHECK_EVERY then
                k = 0
                M.check("setCanvas")
            end
        end
    end
end

return M
