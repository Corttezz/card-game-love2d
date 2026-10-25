local M = {}

local SUITES = {
    { group = "unit",  name = "test_entities" },
    { group = "unit",  name = "test_economy" },
    { group = "unit",  name = "test_progression" },
    { group = "unit",  name = "test_sustain_knobs" },
    { group = "unit",  name = "test_boss_jokers" },
    { group = "unit",  name = "test_counter_jokers" },
    { group = "unit",  name = "test_forge" },
    { group = "unit",  name = "test_forge_resize" },
    { group = "unit",  name = "test_cards" },
    { group = "unit",  name = "test_effects_full" },
    { group = "unit",  name = "test_combat" },
    { group = "unit",  name = "test_damage_preview" },
    { group = "unit",  name = "test_immunities" },
    { group = "unit",  name = "test_beats" },
    { group = "unit",  name = "test_enemy_death" },
    { group = "unit",  name = "test_enemies" },
    { group = "unit",  name = "test_intent_visibility" },
    { group = "unit",  name = "test_tutorial" },
    { group = "unit",  name = "test_tutorial_mage" },
    { group = "unit",  name = "test_events" },
    { group = "unit",  name = "test_journal" },
    { group = "unit",  name = "test_journal_resize" },
    { group = "unit",  name = "test_journal_map" },
    { group = "unit",  name = "test_saved_run_locale" },
    { group = "unit",  name = "test_card_top_frame" },
    { group = "unit",  name = "test_tooltip_order" },
    { group = "unit",  name = "test_pack_choice_layout" },
    { group = "unit",  name = "test_pack_open_beats" },
    { group = "unit",  name = "test_collection_hover" },
    { group = "unit",  name = "test_reward_tooltip" },
    { group = "unit",  name = "test_reward_jokers" },
    { group = "unit",  name = "test_enemy_pose" },
    { group = "unit",  name = "test_enemy_stage" },
    { group = "unit",  name = "test_interior_fx" },
    { group = "unit",  name = "test_world_shadows" },
    { group = "unit",  name = "test_sky_strip" },
    { group = "unit",  name = "test_light_emit" },
    { group = "unit",  name = "test_light_falloff" },
    { group = "unit",  name = "test_enemy_light_fringe" },
    { group = "unit",  name = "test_tree_anim" },
    { group = "unit",  name = "test_weather" },
    { group = "unit",  name = "test_world_props" },
    { group = "unit",  name = "test_scene_continuity" },
    { group = "unit",  name = "test_enemy_entrances" },
    { group = "unit",  name = "test_enemy_props" },
    { group = "unit",  name = "test_enemy_life" },
    { group = "unit",  name = "test_props_opaque" },
    { group = "unit",  name = "test_scene_grade" },
    { group = "unit",  name = "test_contact_shadow" },
    { group = "unit",  name = "test_sombra_base" },
    { group = "unit",  name = "test_sombras_item" },
    { group = "unit",  name = "test_poste_profundidade" },
    { group = "unit",  name = "test_landmark_fx" },
    { group = "unit",  name = "test_loja_base" },
    { group = "unit",  name = "test_tufos_base" },
    { group = "unit",  name = "test_prop_variation" },
    { group = "unit",  name = "test_boss_visuals" },
    { group = "unit",  name = "test_boss_mechanics" },
    { group = "unit",  name = "test_crow_sfx" },
    { group = "unit",  name = "test_entrance_sfx" },
    { group = "unit",  name = "test_boss_cinematic" },
    { group = "unit",  name = "test_hand_deal" },
    { group = "unit",  name = "test_enemy_fall" },
    { group = "unit",  name = "test_enemy_shadow_motion" },
    { group = "unit",  name = "test_enemy_clip_identity" },
    { group = "unit",  name = "test_enemy_axis" },
    { group = "unit",  name = "test_castle_gate" },
    { group = "unit",  name = "test_castle_foot" },
    { group = "unit",  name = "test_castle_light" },
    { group = "unit",  name = "test_card_live_hover" },
    { group = "unit",  name = "test_cards_always_live" },
    { group = "unit",  name = "test_holo_shader" },
    { group = "unit",  name = "test_card_hover_edges" },
    { group = "unit",  name = "test_reveal_glow" },
    { group = "unit",  name = "test_preview_plate" },
    { group = "unit",  name = "test_boot_entry" },
    { group = "unit",  name = "test_intro_tube" },
    { group = "unit",  name = "test_menu_brand" },
    { group = "unit",  name = "test_crt_levels" },
    { group = "unit",  name = "test_pixelcanvas_state" },
    { group = "unit",  name = "test_screen_exits" },
    { group = "unit",  name = "test_music" },
    { group = "unit",  name = "test_music_react" },
    { group = "unit",  name = "test_window" },
    { group = "unit",  name = "test_release" },
    { group = "unit",  name = "test_app_loop" },
    { group = "unit",  name = "test_coinburst" },
    { group = "unit",  name = "test_end_transition" },
    { group = "unit",  name = "test_replay" },
    { group = "unit",  name = "test_combat_reentry" },
    { group = "unit",  name = "test_upgrade_tile" },
    { group = "unit",  name = "test_shop_layout" },
    { group = "unit",  name = "test_shop_scene" },
    { group = "unit",  name = "test_shop_shadows" },
    { group = "unit",  name = "test_status_pills" },
    { group = "unit",  name = "test_orb_anim" },
    { group = "unit",  name = "test_input_focus" },
    { group = "unit",  name = "test_autoplay_pilot" },
    { group = "unit",  name = "test_sim_memory" },
    { group = "unit",  name = "test_instant_parity" },
    { group = "unit",  name = "test_balance_pipeline" },
    { group = "unit",  name = "test_difficulty_floor" },
    { group = "unit",  name = "test_economy_acts" },
    { group = "unit",  name = "test_scribe_dice" },
    { group = "unit",  name = "test_shop_props" },
    { group = "unit",  name = "test_endless_seals" },
    { group = "unit",  name = "test_pause_menu" },
    { group = "unit",  name = "test_toasts" },
    { group = "unit",  name = "test_ui_scale" },
    { group = "unit",  name = "test_class_select" },
    { group = "unit",  name = "test_navcursor" },
    { group = "unit",  name = "test_unlocks" },
    { group = "unit",  name = "test_discovery_mark" },
    { group = "unit",  name = "test_descobertas" },
    { group = "unit",  name = "test_bestiary" },
    { group = "unit",  name = "test_bestiary_ui" },
    { group = "unit",  name = "test_toast_audit" },
    { group = "unit",  name = "test_confirm_dialog" },
    { group = "unit",  name = "test_lifecycle" },
    { group = "unit",  name = "test_saveflow" },
    { group = "unit",  name = "test_save_integrity" },
    { group = "unit",  name = "test_resume_state" },
    { group = "unit",  name = "test_endless" },
    { group = "unit",  name = "test_end_screens" },
    { group = "unit",  name = "test_unlock_showcase" },
    { group = "valid", name = "check_event_i18n" },
    { group = "valid", name = "audit_feedback" },
    { group = "smoke", name = "smoke_tags" },
    { group = "smoke", name = "smoke_effects" },
    { group = "smoke", name = "smoke_combos" },
    { group = "smoke", name = "smoke_map" },
    { group = "smoke", name = "smoke_acts" },
    { group = "smoke", name = "smoke_discard" },
    { group = "smoke", name = "smoke_exhaust_pool" },
    { group = "unit", name = "test_systems" },
    { group = "unit",  name = "test_fork_types" },
    { group = "smoke", name = "smoke_upgrades" },
    { group = "smoke", name = "smoke_shop" },
    { group = "unit",  name = "test_shop_services" },
    { group = "unit",  name = "test_shop_sale" },
    { group = "smoke", name = "smoke_packs" },
    { group = "smoke", name = "smoke_turn_order" },
    { group = "smoke", name = "smoke_ui_turn" },
    { group = "smoke", name = "test_worldroad_resume" },
    { group = "smoke", name = "test_perf_budget" },
    { group = "smoke", name = "test_road_edge_rhythm" },
    { group = "smoke", name = "test_fork_branch_width" },
    { group = "smoke", name = "test_road_fork_surface" },
    { group = "smoke", name = "test_fork_sequence" },
    { group = "smoke", name = "test_fork_flow" },
    { group = "smoke", name = "test_resume" },
    { group = "smoke", name = "smoke_crt_mouse" },
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
    { group = "valid", name = "test_locale_accents" },
    { group = "valid", name = "test_locale_dashes" },
    { group = "valid", name = "test_bestiary_lore" },
    { group = "valid", name = "test_no_comments_no_prints" },
    { group = "unit",  name = "test_cheat_mode" },
    { group = "unit",  name = "test_music_flow" },
}

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

    local MemGuard = require("tools.mem_guard")
    MemGuard.install()
    local shardI, shardN = (os.getenv("TEST_SHARD") or ""):match("^(%d+)/(%d+)$")
    shardI, shardN = tonumber(shardI), tonumber(shardN)
    for si, suite in ipairs(SUITES) do
        if shardN and (si - 1) % shardN + 1 ~= shardI then goto continue end
        print("\n========================================")
        print("  SUITE: " .. suite.name .. "  [" .. suite.group .. "]")
        print("========================================")
        MemGuard.current = suite.name
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
        collectgarbage("collect")
        collectgarbage("collect")
        pcall(love.graphics.setCanvas)
        pcall(love.graphics.present)
        local luaMB, privMB, peakMB = MemGuard.mem()
        print(string.format("  [mem] %s lua=%.0fMB privado=%.0fMB pico=%.0fMB", suite.name, luaMB, privMB, peakMB))
        MemGuard.check("fim da suite")
        ::continue::
    end

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
    local _, _, peakAll = require("tools.mem_guard").mem()
    print(string.format("  memoria: pico do processo %.0f MB", peakAll))
    print(string.format("\n  %d suites: %d PASS / %d FAIL / %d CRASH",
        #results, passed, failed, crashed))

    local allGreen = (failed == 0 and crashed == 0)
    print(allGreen and "\n===== TUDO VERDE =====" or "\n===== HÁ FALHAS =====")
    return allGreen
end

return M
