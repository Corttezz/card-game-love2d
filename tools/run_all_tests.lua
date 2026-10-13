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
    { group = "unit",  name = "test_forge_resize" },
    { group = "unit",  name = "test_cards" },
    { group = "unit",  name = "test_effects_full" },
    { group = "unit",  name = "test_combat" },
    { group = "unit",  name = "test_damage_preview" },
    { group = "unit",  name = "test_beats" },
    { group = "unit",  name = "test_enemy_death" },
    { group = "unit",  name = "test_enemies" },
    -- névoa de intenção: bioma/véu/revelação, intent segue congelado, HUD "?",
    -- contadores, clima acompanha, piloto não espia (memory/intent_visibility.md)
    { group = "unit",  name = "test_intent_visibility" },
    { group = "unit",  name = "test_tutorial" },
    { group = "unit",  name = "test_events" },
    { group = "unit",  name = "test_journal" },
    { group = "unit",  name = "test_journal_resize" },
    { group = "unit",  name = "test_saved_run_locale" },
    { group = "unit",  name = "test_card_top_frame" },
    { group = "unit",  name = "test_tooltip_order" },
    { group = "unit",  name = "test_enemy_pose" },
    { group = "unit",  name = "test_enemy_stage" },
    { group = "unit",  name = "test_interior_fx" },
    { group = "unit",  name = "test_weather" },
    { group = "unit",  name = "test_boss_visuals" },
    { group = "unit",  name = "test_boss_cinematic" },
    { group = "unit",  name = "test_hand_deal" },
    { group = "unit",  name = "test_enemy_fall" },
    { group = "unit",  name = "test_enemy_axis" },
    { group = "unit",  name = "test_castle_gate" },
    { group = "unit",  name = "test_card_live_hover" },
    { group = "unit",  name = "test_holo_shader" },
    { group = "unit",  name = "test_preview_plate" },
    { group = "unit",  name = "test_boot_entry" },
    { group = "unit",  name = "test_crt_levels" },
    { group = "unit",  name = "test_pixelcanvas_state" },
    { group = "unit",  name = "test_screen_exits" },
    { group = "unit",  name = "test_music" },
    { group = "unit",  name = "test_window" },
    { group = "unit",  name = "test_release" },
    { group = "unit",  name = "test_app_loop" },
    { group = "unit",  name = "test_coinburst" },
    { group = "unit",  name = "test_end_transition" },
    { group = "unit",  name = "test_replay" },
    { group = "unit",  name = "test_combat_reentry" },
    { group = "unit",  name = "test_upgrade_tile" },
    { group = "unit",  name = "test_status_pills" },
    { group = "unit",  name = "test_orb_anim" },
    { group = "unit",  name = "test_input_focus" },
    { group = "unit",  name = "test_autoplay_pilot" },
    { group = "unit",  name = "test_sim_memory" },
    -- pipeline de balanceamento: relogio instantaneo == relogio de quadros
    -- (traco turno a turno), pilotos naive/average/expert, determinismo,
    -- throughput e o registro que o relatorio Python le
    { group = "unit",  name = "test_instant_parity" },
    { group = "unit",  name = "test_balance_pipeline" },
    { group = "unit",  name = "test_economy_acts" },
    { group = "unit",  name = "test_scribe_dice" },
    { group = "unit",  name = "test_endless_seals" },
    { group = "unit",  name = "test_pause_menu" },
    { group = "unit",  name = "test_toasts" },
    { group = "unit",  name = "test_ui_scale" },
    { group = "unit",  name = "test_class_select" },
    { group = "unit",  name = "test_navcursor" },
    { group = "unit",  name = "test_unlocks" },
    { group = "unit",  name = "test_discovery_mark" },
    { group = "unit",  name = "test_toast_audit" },
    { group = "unit",  name = "test_confirm_dialog" },
    { group = "unit",  name = "test_credits" },
    { group = "unit",  name = "test_lifecycle" },
    { group = "unit",  name = "test_saveflow" },
    { group = "unit",  name = "test_save_integrity" },
    { group = "unit",  name = "test_resume_state" },
    { group = "unit",  name = "test_endless" },
    { group = "unit",  name = "test_end_screens" },
    { group = "unit",  name = "test_unlock_showcase" },
    { group = "valid", name = "check_event_i18n" },
    { group = "valid", name = "audit_feedback" },
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
    { group = "unit",  name = "test_shop_services" },
    { group = "smoke", name = "smoke_packs" },
    { group = "smoke", name = "smoke_turn_order" },
    { group = "smoke", name = "smoke_ui_turn" },
    { group = "smoke", name = "test_worldroad_resume" },
    -- trava de performance do WorldRoad (draw calls, cache estático, GC,
    -- troca de bioma sem decodificar PNG) — não mede ms (varia por máquina)
    { group = "smoke", name = "test_perf_budget" },
    { group = "smoke", name = "test_resume" },
    { group = "smoke", name = "smoke_crt_mouse" },
    -- Validação / conteúdo
    { group = "valid", name = "validate_cards" },
    { group = "valid", name = "test_card_audit" },
    { group = "unit",  name = "test_balance_ai" },
    { group = "valid", name = "test_i18n" },
    { group = "valid", name = "test_i18n_used_keys" },
    { group = "valid", name = "test_no_hardcoded_pt" },
    { group = "valid", name = "test_dynatext_bump" },
    { group = "valid", name = "test_achievements_i18n" },
    { group = "unit",  name = "test_achievements" },
    { group = "valid", name = "test_locale_glyphs" },
    -- acento de verdade: glifos das maiusculas, ASCII-ismos por locale, glossario traduzido
    { group = "valid", name = "test_locale_accents" },
    { group = "valid", name = "test_locale_dashes" },
}

-- GUARDA DE VAZAMENTO ENTRE SUITES (Out/2026). Suites e tools monkeypatcham
-- funções compartilhadas (relógio, janela falsa, mouse, print, render de
-- carta). O que ainda estiver trocado ao FIM da suite é restaurado aqui e
-- vira uma linha `[leak]` no relatório — porque o sintoma aparece em OUTRA
-- suite, longe da causa: tools/balance_sim.setup (test_instant_parity e
-- test_balance_pipeline) trocava CardFrame.render por um stub e
-- test_class_select, oito suites depois, caía em CardFrame.lua:423 uma vez a
-- cada nove rodadas, conforme o horário (memory/card_icon_animation.md).
-- Restaurar aqui é a rede; a suite que vaza continua sendo a dona do defeito.
local GUARDED = {
    { "CardFrame.render",            "src.ui.CardFrame",   "render" },
    { "CardFrame.liveImage",         "src.ui.CardFrame",   "liveImage" },
    { "CardFrame.getAnimation",      "src.ui.CardFrame",   "getAnimation" },
    { "ComboBanner.show",            "src.ui.ComboBanner", "show" },
    { "love.timer.getTime",          love.timer,           "getTime" },
    { "love.graphics.getWidth",      love.graphics,        "getWidth" },
    { "love.graphics.getHeight",     love.graphics,        "getHeight" },
    { "love.graphics.getDimensions", love.graphics,        "getDimensions" },
    { "love.mouse.getPosition",      love.mouse,           "getPosition" },
    { "print",                       _G,                   "print" },
}

local function guardedTable(spec)
    if type(spec[2]) == "string" then
        local ok, mod = pcall(require, spec[2])
        return ok and type(mod) == "table" and mod or nil
    end
    return spec[2]
end

local function snapshotGuarded()
    local snap = {}
    for i, g in ipairs(GUARDED) do
        local tbl = guardedTable(g)
        snap[i] = tbl and tbl[g[3]] or nil
    end
    return snap
end

-- Restaura o que mudou; devolve a lista de nomes vazados (vazia = limpo).
local function restoreGuarded(snap)
    local leaked = {}
    for i, g in ipairs(GUARDED) do
        local tbl = guardedTable(g)
        if tbl and snap[i] ~= nil and tbl[g[3]] ~= snap[i] then
            tbl[g[3]] = snap[i]
            leaked[#leaked + 1] = g[1]
        end
    end
    return leaked
end
M._snapshotGuarded, M._restoreGuarded = snapshotGuarded, restoreGuarded

function M.run()
    local results = {}
    local passed, failed, crashed = 0, 0, 0
    local leaks = {}

    for _, suite in ipairs(SUITES) do
        print("\n========================================")
        print("  SUITE: " .. suite.name .. "  [" .. suite.group .. "]")
        print("========================================")
        local mod = require("tools." .. suite.name)
        local snap = snapshotGuarded()
        local ok, res = pcall(mod.run)
        local leaked = restoreGuarded(snap)
        if #leaked > 0 then
            print("  [leak] " .. suite.name .. " deixou trocado: "
                .. table.concat(leaked, ", ") .. " — restaurado pelo runner")
            leaks[#leaks + 1] = { name = suite.name, what = leaked }
        end
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
    if #leaks > 0 then
        print("\n  Vazamentos de monkeypatch restaurados pelo runner (a suite é a dona do defeito):")
        for _, l in ipairs(leaks) do
            print("    [leak] " .. l.name .. ": " .. table.concat(l.what, ", "))
        end
    end
    print(string.format("\n  %d suites: %d PASS / %d FAIL / %d CRASH",
        #results, passed, failed, crashed))

    local allGreen = (failed == 0 and crashed == 0)
    print(allGreen and "\n===== TUDO VERDE =====" or "\n===== HÁ FALHAS =====")
    return allGreen
end

return M
