-- src/i18n/TextCase.lua
-- Caixa alta/baixa que entende ACENTO.
--
-- `string.upper` do Lua trabalha byte a byte em ASCII: "légendaire":upper()
-- vira "LéGENDAIRE", "não":upper() vira "NãO". Com os locales voltando a ter
-- acento (Out/2026), todo rótulo que a UI força em maiúsculas (raridade, tipo
-- de carta, botão PEGAR) passou a sair com a letra acentuada em minúscula no
-- meio da palavra. Este módulo cobre o Latin-1 — exatamente o conjunto que a
-- fonte desenha (tools/test_locale_glyphs.lua).

local utf8 = require("utf8")

local TextCase = {}

local UP, LOW = {}, {}
-- Latin-1 suplementar: minúsculas U+00E0..U+00FE (exceto ÷ U+00F7) ↔
-- maiúsculas U+00C0..U+00DE (exceto × U+00D7). ÿ/ß ficam como estão.
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
    -- UTF-8 inválido: devolve o ASCII convertido e AVISA (nunca calado).
    print("[TextCase] texto com UTF-8 invalido: " .. s)
    return asciiFn(s)
end

function TextCase.upper(s) return map(s, UP, string.upper) end
function TextCase.lower(s) return map(s, LOW, string.lower) end

return TextCase
