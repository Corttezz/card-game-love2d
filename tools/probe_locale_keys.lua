local M = {}
local function flatten(t, prefix, out)
    for k, v in pairs(t) do
        local key = prefix and (prefix .. "." .. tostring(k)) or tostring(k)
        if type(v) == "table" then flatten(v, key, out) else out[key] = true end
    end
    return out
end
local function loadTable(path)
    local chunk = love.filesystem.load(path)
    if not chunk then return nil end
    local ok, t = pcall(chunk)
    return ok and type(t) == "table" and t or nil
end
function M.run()
    local dirs = { "", "tutorial/", "scribe_dice/", "enemy_kit/", "run_modifiers/", "boss_cinematics/" }
    local total = 0
    for _, d in ipairs(dirs) do
        local base = loadTable("src/i18n/locales/" .. d .. "pt_BR.lua")
        if base then
            local bk = flatten(base, nil, {})
            for _, loc in ipairs({ "en", "es", "fr", "de" }) do
                local t = loadTable("src/i18n/locales/" .. d .. loc .. ".lua")
                if t then
                    local lk = flatten(t, nil, {})
                    local miss = {}
                    for k in pairs(bk) do if not lk[k] then miss[#miss + 1] = k end end
                    table.sort(miss)
                    if #miss > 0 then
                        total = total + #miss
                        print(("[keys] %s%s: %d faltando: %s"):format(d, loc, #miss, table.concat(miss, ", ")))
                    end
                end
            end
        end
    end
    print("[keys] total faltando: " .. total)
    return true
end
return M
