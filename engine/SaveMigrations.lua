local Migrations = {}

Migrations.CURRENT_VERSION = "1.2"

local handlers = {
    ["1.0"] = function(payload)
        payload.version = "1.1"
    end,
    ["1.1"] = function(payload)
        payload.version = "1.2"
    end,
}

function Migrations.run(payload)
    if type(payload) ~= "table" then
        return false, "payload não é tabela"
    end

    payload.version = payload.version or "1.0"

    local guard = 0
    while payload.version ~= Migrations.CURRENT_VERSION do
        guard = guard + 1
        if guard > 32 then
            return false, "loop de migration (versão atual: " .. tostring(payload.version) .. ")"
        end

        local handler = handlers[payload.version]
        if not handler then
            return false, "sem handler para versão " .. tostring(payload.version)
        end

        local ok, err = pcall(handler, payload)
        if not ok then
            return false, "handler falhou: " .. tostring(err)
        end
    end

    return true
end

return Migrations
