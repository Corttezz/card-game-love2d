local Debug = require("src.core.Debug")

local utf8 = require("utf8")

local TextCase = {}

local UP, LOW = {}, {}
for cp = 0xE0, 0xFE do
    if cp ~= 0xF7 then
        UP[cp] = cp - 0x20
        LOW[cp - 0x20] = cp
    end
end

local function map(s, tbl, asciiFn)
    if type(s) ~= "string" then return s end
    if not s:find("[\128-\255]") then return asciiFn(s) end
    local ok, out = pcall(function()
        local parts = {}
        for _, cp in utf8.codes(s) do
            if cp < 128 then
                parts[#parts + 1] = asciiFn(string.char(cp))
            else
                parts[#parts + 1] = utf8.char(tbl[cp] or cp)
            end
        end
        return table.concat(parts)
    end)
    if ok then return out end
    Debug.warn("[TextCase] texto com UTF-8 invalido: " .. s)
    return asciiFn(s)
end

function TextCase.upper(s) return map(s, UP, string.upper) end
function TextCase.lower(s) return map(s, LOW, string.lower) end

return TextCase
