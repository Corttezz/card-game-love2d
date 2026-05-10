-- engine/SaveMigrations.lua
-- Versionamento de save. Cada migration pega o payload em uma versão e
-- transforma in-place para a próxima. Roda em cadeia até CURRENT_VERSION.
--
-- Convenção: chave do dicionário é a versão de origem ("1.0"), função
-- retorna a nova versão depois de transformar (ou raise em caso de save
-- irrecuperável).

local Migrations = {}

Migrations.CURRENT_VERSION = "1.1"

-- Cada handler recebe payload (que tem .version, .runData, .savedAt) e
-- muta payload.runData / payload.version para a próxima versão.
local handlers = {
    ["1.0"] = function(payload)
        -- 1.0 → 1.1: nada a transformar nos dados (era a versão anterior
        -- antes do SaveManager existir). Só registra a bump.
        payload.version = "1.1"
    end,
}

-- Roda migrations em cadeia. Retorna true em sucesso, false+err em falha.
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
