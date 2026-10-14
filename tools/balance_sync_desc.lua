local M = {}

local FILES = { "basic", "warrior", "mage", "rogue" }

local function esc(s)
    return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

function M.expected()
    local I18n = require("src.i18n.I18n")
    local CardDatabase = require("src.systems.CardDatabase")
    I18n.init()
    local saved = I18n.getLocale()
    I18n.setLocale("pt_BR", true)
    local out = {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        local inst = CardDatabase:createCardInstance(cd)
        out[id] = I18n.cardDesc(inst)
    end
    I18n.setLocale(saved, true)
    return out
end

function M.run()
    local want = M.expected()
    local changed = 0
    for _, f in ipairs(FILES) do
        local path = "src/data/cards/" .. f .. ".lua"
        local fh = io.open(path, "rb")
        local src = fh:read("*a"); fh:close()
        for id, desc in pairs(want) do
            local s = src:find("\n    " .. id .. "%s*=%s*{")
            if s then
                local ds, de = src:find('description = "', s, true)
                local close = src:find('"', de + 1, true)
                while src:sub(close - 1, close - 1) == "\\" do close = src:find('"', close + 1, true) end
                local cur = src:sub(de + 1, close - 1)
                local new = esc(desc)
                if cur ~= new then
                    src = src:sub(1, de) .. new .. src:sub(close)
                    changed = changed + 1
                end
            end
        end
        local w = io.open(path, "wb"); w:write(src); w:close()
    end
    print("[balance_sync_desc] descricoes de fallback atualizadas: " .. changed)
    return true
end

return M
