local TK = require("tools.testkit")

local M = {}

M.GAME_ROOTS = { "main.lua", "conf.lua", "src", "components", "engine", "shaders" }
M.TOOL_ROOTS = { "tools" }

M.PRINT_INFRA = {
    ["src/core/Debug.lua"] = true,
    ["src/core/Release.lua"] = true,
    ["tools/run_all_tests.lua"] = true,
    ["tools/testkit.lua"] = true,
}

M.TOOL_RESULT_PRINTERS = {
    "tools/anim_drift.lua", "tools/screenshot_coringas_contra.lua", "tools/screenshot_menu_logo.lua", "tools/screenshot_estrada_final.lua", "tools/perf_estrada_final.lua", "tools/estrada_seq.lua", "tools/estrada_fluxo.lua", "tools/mem_guard.lua", "tools/bancada_sombras.lua", "tools/audit_cards.lua", "tools/audit_feedback.lua", "tools/autoplay.lua",
    "tools/bake_orb_anim.lua", "tools/balance_bench.lua", "tools/balance_sim.lua", "tools/balance_sync_desc.lua",
    "tools/boss_rooms.lua", "tools/screenshot_bestiario.lua", "tools/screenshot_castelo_base.lua", "tools/screenshot_castelo_luz.lua", "tools/screenshot_luz_suave.lua", "tools/screenshot_loja_base.lua", "tools/screenshot_tufos_viagem.lua", "tools/check_event_i18n.lua", "tools/check_font_metrics.lua", "tools/check_loop.lua",
    "tools/check_music.lua", "tools/check_seal_sfx.lua", "tools/check_sfx.lua", "tools/demo_worldroad.lua",
    "tools/dim.lua", "tools/grade_locais.lua", "tools/instant_engine.lua", "tools/intent_fog_report.lua",
    "tools/measure_lightpool.lua", "tools/orb_anim_compare.lua", "tools/orb_compare.lua", "tools/orb_zoom.lua",
    "tools/perf_card_anim_units.lua", "tools/perf_collection.lua", "tools/perf_probe.lua", "tools/perf_visual_diff.lua",
    "tools/preview_anim.lua", "tools/preview_battle_hud.lua", "tools/preview_button_border.lua",
    "tools/preview_card_anim.lua", "tools/preview_card_art_fix.lua", "tools/preview_card_live.lua",
    "tools/preview_cards.lua", "tools/preview_coinburst.lua", "tools/preview_editions.lua", "tools/preview_fx.lua",
    "tools/preview_rareglow.lua", "tools/preview_shop_props.lua", "tools/probe_continue.lua",
    "tools/realismo_measure.lua", "tools/escala_humana.lua", "tools/revisao_cenas.lua", "tools/revisao_catalogo.lua",
    "tools/screenshot_rare_joker.lua", "tools/screenshot_cheat.lua", "tools/screenshot_musica_reativa.lua",
    "tools/screenshot_icones_pausa.lua", "tools/screenshot_postes_por_ato.lua", "tools/screenshot_castelo_curva.lua", "tools/screenshot_revisao_monstros.lua", "tools/screenshot_voo.lua",
    "tools/probe_i18n_key.lua", "tools/probe_locale_keys.lua", "tools/probe_shop_i18n.lua",
    "tools/probe_shop_shadow.lua", "tools/probe_skip_label.lua", "tools/scan_clones.lua",
    "tools/screenshot_achievements.lua", "tools/screenshot_attack.lua", "tools/screenshot_boot_entry.lua",
    "tools/screenshot_bootfx.lua", "tools/screenshot_cartas_vivas.lua", "tools/screenshot_cashout.lua",
    "tools/screenshot_class_select.lua", "tools/screenshot_collection.lua", "tools/screenshot_combobanner.lua",
    "tools/screenshot_crt.lua", "tools/screenshot_crt_final.lua", "tools/screenshot_crt_levels.lua", "tools/screenshot_crt_variantes.lua", "tools/screenshot_cursor.lua",
    "tools/screenshot_damage_preview.lua", "tools/screenshot_death.lua", "tools/screenshot_discovery.lua",
    "tools/screenshot_end_screens.lua", "tools/screenshot_endless.lua", "tools/screenshot_endscreens.lua",
    "tools/screenshot_enemy_scene.lua", "tools/screenshot_vida.lua", "tools/screenshot_estados.lua", "tools/screenshot_event.lua", "tools/screenshot_event_anim.lua",
    "tools/screenshot_forge.lua", "tools/screenshot_gameplay.lua", "tools/screenshot_guide.lua",
    "tools/screenshot_holo.lua", "tools/screenshot_bordas_cartas.lua", "tools/screenshot_brilho_coringa.lua", "tools/screenshot_descobertas.lua", "tools/screenshot_intro.lua", "tools/screenshot_joker_manager.lua",
    "tools/screenshot_journal.lua", "tools/screenshot_mapscreen.lua", "tools/screenshot_menu_life.lua",
    "tools/screenshot_menu_v2.lua", "tools/screenshot_menuanim.lua", "tools/screenshot_packopen.lua", "tools/shot_pacotes_v2.lua",
    "tools/screenshot_pause.lua", "tools/screenshot_relic_art.lua", "tools/screenshot_resume_boss.lua",
    "tools/screenshot_rewards.lua", "tools/screenshot_round_eval.lua", "tools/screenshot_shop.lua",
    "tools/screenshot_shop_diag.lua", "tools/screenshot_sombras_mundo.lua", "tools/screenshot_topbar_gear.lua",
    "tools/screenshot_entradas.lua", "tools/entradas.lua", "tools/probe_enemy_halo.lua", "tools/probe_mask_offset.lua", "tools/shot_halo_crop.lua",
    "tools/screenshot_turnbanner.lua", "tools/screenshot_tutorial.lua", "tools/screenshot_ui.lua",
    "tools/screenshot_uiscale.lua", "tools/screenshot_uiscale_battle.lua", "tools/screenshot_unlock_showcase.lua",
    "tools/screenshot_unlocks.lua", "tools/screenshot_upgrades.lua", "tools/screenshot_weather.lua",
    "tools/screenshot_worldroad.lua", "tools/screenshot_integracao_terreno.lua", "tools/screenshot_borda_estrada.lua", "tools/screenshot_sol_coerente.lua", "tools/screenshot_rodada4.lua", "tools/sfx_envelope.lua", "tools/sheet.lua", "tools/sheet_card_art.lua",
    "tools/shot_boss_aura.lua", "tools/shot_boss_cinematic.lua", "tools/shot_enemy_sheet.lua",
    "tools/study_enemy_stage.lua", "tools/validate_cards.lua",
}

local SKIP_DIRS = { ["tools/preview_out"] = true, ["tools/__pycache__"] = true, ["tools/vendor"] = true }

local function walk(path, out)
    local info = love.filesystem.getInfo(path)
    if not info then return end
    if info.type == "directory" then
        if SKIP_DIRS[path] then return end
        for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
            walk(path .. "/" .. item, out)
        end
    elseif path:match("%.lua$") or path:match("%.glsl$") then
        out[#out + 1] = path
    end
end

local function longBracket(s, i)
    if s:sub(i, i) ~= "[" then return nil end
    local j = i + 1
    while s:sub(j, j) == "=" do j = j + 1 end
    if s:sub(j, j) == "[" then return j - i - 1, j + 1 end
    return nil
end

function M.luaScan(src)
    local comments, codeParts = {}, {}
    local n, i, line = #src, 1, 1
    local buf = {}
    local function flush()
        if #buf > 0 then
            codeParts[#codeParts + 1] = { line = line, text = table.concat(buf) }
            buf = {}
        end
    end
    while i <= n do
        local c = src:sub(i, i)
        if c == "\n" then
            flush()
            line = line + 1
            i = i + 1
        elseif c == "-" and src:sub(i, i + 1) == "--" then
            flush()
            local level, start = longBracket(src, i + 2)
            if level then
                local close = "]" .. string.rep("=", level) .. "]"
                local k = src:find(close, start, true)
                if not k then return nil, "comentario longo sem fim na linha " .. line end
                local body = src:sub(i, k + #close - 1)
                comments[#comments + 1] = { line = line, text = body }
                for _ in body:gmatch("\n") do line = line + 1 end
                i = k + #close
            else
                local k = src:find("\n", i, true) or (n + 1)
                comments[#comments + 1] = { line = line, text = src:sub(i, k - 1) }
                i = k
            end
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do
                local ch = src:sub(j, j)
                if ch == "\\" then
                    j = j + 2
                elseif ch == c then
                    break
                elseif ch == "\n" then
                    return nil, "string sem fim na linha " .. line
                else
                    j = j + 1
                end
            end
            flush()
            i = j + 1
        elseif c == "[" and longBracket(src, i) then
            local level, start = longBracket(src, i)
            local close = "]" .. string.rep("=", level) .. "]"
            local k = src:find(close, start, true)
            if not k then return nil, "string longa sem fim na linha " .. line end
            flush()
            local body = src:sub(i, k + #close - 1)
            for _ in body:gmatch("\n") do line = line + 1 end
            i = k + #close
        else
            buf[#buf + 1] = c
            i = i + 1
        end
    end
    flush()
    return comments, codeParts
end

function M.glslComments(src)
    local out = {}
    local line = 1
    local i, n = 1, #src
    while i <= n do
        local c = src:sub(i, i)
        if c == "\n" then
            line = line + 1
            i = i + 1
        elseif c == "/" and src:sub(i, i + 1) == "//" then
            local k = src:find("\n", i, true) or (n + 1)
            out[#out + 1] = { line = line, text = src:sub(i, k - 1) }
            i = k
        elseif c == "/" and src:sub(i, i + 1) == "/*" then
            local k = src:find("*/", i + 2, true)
            if not k then return nil, "comentario /* sem fim na linha " .. line end
            local body = src:sub(i, k + 1)
            out[#out + 1] = { line = line, text = body }
            for _ in body:gmatch("\n") do line = line + 1 end
            i = k + 2
        else
            i = i + 1
        end
    end
    return out
end

function M.bareprints(codeParts)
    local hits = {}
    for _, part in ipairs(codeParts) do
        local s = " " .. part.text
        local pos = 1
        while true do
            local a, b = s:find("[^%w_%.:]print%s*%(", pos)
            if not a then break end
            hits[#hits + 1] = part.line
            pos = b
        end
    end
    return hits
end

local function isTool(path) return path:sub(1, 6) == "tools/" end

function M.run()
    local t = TK.new("zero comentarios no codigo, zero print fora do Debug")
    local allowedTool = {}
    for _, p in ipairs(M.TOOL_RESULT_PRINTERS) do allowedTool[p] = true end

    local files = {}
    for _, root in ipairs(M.GAME_ROOTS) do walk(root, files) end
    for _, root in ipairs(M.TOOL_ROOTS) do walk(root, files) end
    table.sort(files)

    local commentFiles, printFiles, lexErrors = {}, {}, {}
    local nComments, nPrints, nLua, nGlsl = 0, 0, 0, 0
    for _, path in ipairs(files) do
        local src = love.filesystem.read(path) or ""
        if path:match("%.glsl$") then
            nGlsl = nGlsl + 1
            local cs, err = M.glslComments(src)
            if not cs then
                lexErrors[#lexErrors + 1] = path .. ": " .. err
            elseif #cs > 0 then
                nComments = nComments + #cs
                commentFiles[#commentFiles + 1] = ("%s:%d %s"):format(path, cs[1].line, cs[1].text:sub(1, 60))
            end
        else
            nLua = nLua + 1
            local cs, codeParts = M.luaScan(src)
            if not cs then
                lexErrors[#lexErrors + 1] = path .. ": " .. tostring(codeParts)
            else
                if #cs > 0 then
                    nComments = nComments + #cs
                    commentFiles[#commentFiles + 1] = ("%s:%d %s"):format(path, cs[1].line, cs[1].text:sub(1, 60))
                end
                local hits = M.bareprints(codeParts)
                if #hits > 0 then
                    local ok = M.PRINT_INFRA[path]
                        or (isTool(path) and (allowedTool[path]
                            or path:match("^tools/test_[%w_]+%.lua$")
                            or path:match("^tools/smoke_[%w_]+%.lua$")))
                    if not ok then
                        nPrints = nPrints + #hits
                        printFiles[#printFiles + 1] = ("%s:%d (%d print)"):format(path, hits[1], #hits)
                    end
                end
            end
        end
    end

    t:truthy(("varreu %d .lua e %d .glsl"):format(nLua, nGlsl), nLua > 200 and nGlsl > 10)
    t:truthy("todo arquivo lexa (strings e colchetes longos fechados)", #lexErrors == 0)
    for i = 1, math.min(#lexErrors, 5) do print("    " .. lexErrors[i]) end
    t:truthy(("zero comentarios (-- / --[[ / // / /*) no jogo e nas tools: %d encontrados"):format(nComments),
        nComments == 0)
    for i = 1, math.min(#commentFiles, 15) do print("    " .. commentFiles[i]) end
    if #commentFiles > 15 then print(("    ... e mais %d arquivos"):format(#commentFiles - 15)) end
    t:truthy(("zero print() fora de Debug/Release/runner e da lista de tools de resultado: %d encontrados"):format(nPrints),
        nPrints == 0)
    for i = 1, math.min(#printFiles, 15) do print("    " .. printFiles[i]) end

    local stale = {}
    for _, p in ipairs(M.TOOL_RESULT_PRINTERS) do
        if not love.filesystem.getInfo(p) then stale[#stale + 1] = p end
    end
    t:truthy("lista de tools de resultado so aponta arquivos que existem", #stale == 0)
    for _, p in ipairs(stale) do print("    sem arquivo: " .. p) end

    local Debug = require("src.core.Debug")
    local okShape = type(Debug.log) == "function" and type(Debug.warn) == "function"
        and type(Debug.err) == "function" and type(Debug.trace) == "function"
    t:truthy("Debug expoe log/trace/warn/err", okShape)
    local realPrint = print
    local said = 0
    print = function() said = said + 1 end
    local prev = Debug.enabled
    Debug.enabled = false
    Debug.log("x"); Debug.trace("x")
    local Release = require("src.core.Release")
    if Release.isDev() then Debug.warn("x"); Debug.err("x") end
    local mute = said
    Debug.enabled = true
    Debug.log("x"); Debug.warn("x"); Debug.err("x")
    local loud = said - mute
    Debug.enabled = prev
    print = realPrint
    t:eq("Debug mudo por padrao em DEV (nada impresso sem CARDGAME_DEBUG)", mute, 0)
    t:eq("Debug.enabled=true imprime log/warn/err", loud, 3)

    local shaders = {}
    walk("shaders", shaders)
    local badShader = {}
    if love.graphics and love.graphics.isCreated and love.graphics.isCreated() then
        for _, p in ipairs(shaders) do
            local ok, err = pcall(love.graphics.newShader, p)
            if not ok then badShader[#badShader + 1] = p .. ": " .. tostring(err):sub(1, 120) end
        end
        t:truthy(("todos os %d shaders compilam sem comentarios"):format(#shaders), #badShader == 0)
        for _, e in ipairs(badShader) do print("    " .. e) end
    end

    return t:done()
end

return M
