-- tools/run_all_tests.lua
-- Runner mestre da suite COMPLETA: testes unit/integração novos + smoke tests
-- de sistema + validação de catálogo + i18n. Cada suite roda em pcall (um crash
-- não derruba as outras) e o resumo final lista o status de cada uma.
--   love . test_all
--
-- Rodar UM teste isolado: love . test_one <nome>

local M = {}

-- Ordem: unit/integração primeiro (rápidos, determinísticos), depois smoke
-- (sistema), depois validação. Cada entrada é um módulo com .run() -> bool.
local SUITES = {
    -- Novos (esta entrega)
    { group = "unit",  name = "test_entities" },
    { group = "unit",  name = "test_economy" },
    { group = "unit",  name = "test_progression" },
    { group = "unit",  name = "test_forge" },
    { group = "unit",  name = "test_cards" },
    { group = "unit",  name = "test_effects_full" },
    { group = "unit",  name = "test_combat" },
    { group = "unit",  name = "test_events" },
    { group = "unit",  name = "test_pixelcanvas_state" },
    -- Smoke de sistema (pré-existentes)
    { group = "smoke", name = "smoke_tags" },
    { group = "smoke", name = "smoke_effects" },
    { group = "smoke", name = "smoke_combos" },
    { group = "smoke", name = "smoke_map" },
    { group = "smoke", name = "smoke_acts" },
    { group = "smoke", name = "smoke_discard" },
    { group = "smoke", name = "smoke_exhaust_pool" },
    { group = "unit", name = "test_systems" },
    { group = "smoke", name = "smoke_upgrades" },
    { group = "smoke", name = "smoke_shop" },
    { group = "smoke", name = "smoke_packs" },
    { group = "smoke", name = "smoke_turn_order" },
    { group = "smoke", name = "smoke_ui_turn" },
    { group = "smoke", name = "smoke_crt_mouse" },
    -- Validação / conteúdo
    { group = "valid", name = "validate_cards" },
    { group = "valid", name = "test_i18n" },
}

function M.run()
    local results = {}
    local passed, failed, crashed = 0, 0, 0

    for _, suite in ipairs(SUITES) do
        print("\n========================================")
        print("  SUITE: " .. suite.name .. "  [" .. suite.group .. "]")
        print("========================================")
        local mod = require("tools." .. suite.name)
        local ok, res = pcall(mod.run)
        local status
        if not ok then
            status = "CRASH"
            crashed = crashed + 1
            print("  !! CRASH: " .. tostring(res))
        elseif res then
            status = "PASS"
            passed = passed + 1
        else
            status = "FAIL"
            failed = failed + 1
        end
        results[#results + 1] = { name = suite.name, group = suite.group, status = status }
    end

    -- ===== Resumo =====
    print("\n========================================")
    print("  RESUMO DA SUITE COMPLETA")
    print("========================================")
    for _, r in ipairs(results) do
        local mark = (r.status == "PASS") and "  OK  " or ("[" .. r.status .. "]")
        print(string.format("  %s  %-18s %s", mark, r.name, r.group))
    end
    print(string.format("\n  %d suites: %d PASS / %d FAIL / %d CRASH",
        #results, passed, failed, crashed))

    local allGreen = (failed == 0 and crashed == 0)
    print(allGreen and "\n===== TUDO VERDE =====" or "\n===== HÁ FALHAS =====")
    return allGreen
end

return M
