local M = {}

M.ENGINES = {
    { arch = "metal", class = "warrior",
      deck = { "defense_001", "defense_001", "defense_001", "warrior_plate_mail", "warrior_kite_guard",
          "attack_001", "attack_001", "warrior_iron_wave", "warrior_heavy_blade", "warrior_iron_discipline" },
      jokers = { "joker_001", "joker_005" }, counters = { "winter_monarch", "rune_golem" } },
    { arch = "lightning", class = "mage",
      deck = { "mage_zap", "mage_zap", "mage_lightning", "mage_ball_lightning", "mage_boot_sequence",
          "mage_dualcast", "mage_overcharge", "mage_twin_bolts", "mage_magic_barrier", "mage_magic_barrier" },
      jokers = { "mage_creative_ai", "mage_electrodynamics" }, counters = { "storm_griffin" } },
    { arch = "loop", class = "rogue",
      deck = { "rogue_doppelganger", "rogue_doppelganger", "rogue_calculated_gamble", "rogue_acrobatics",
          "rogue_neutralize", "rogue_poison_dart", "rogue_backstab", "rogue_stiletto", "rogue_strike", "rogue_defend" },
      jokers = { "rogue_a_thousand_cuts", "rogue_after_image" }, counters = { "tower_lich" } },
    { arch = "copies", class = "warrior",
      deck = { "effect_mystery_card", "effect_mystery_card", "warrior_heavy_blade", "warrior_heavy_blade",
          "warrior_heavy_blade", "warrior_colossus_blow", "warrior_colossus_blow", "warrior_war_cry",
          "warrior_defend", "warrior_defend" },
      jokers = { "joker_005", "warrior_berserk" }, counters = { "fallen_angel" } },
    { arch = "strength", class = "warrior",
      deck = { "warrior_rage", "warrior_seeing_red", "warrior_inflame", "warrior_war_cry", "warrior_heavy_blade",
          "warrior_colossus_blow", "warrior_twin_strike", "warrior_strike", "warrior_defend", "warrior_defend" },
      jokers = { "warrior_demon_form", "warrior_standard_bearer" }, counters = { "abyss_tyrant" } },
    { arch = "poison", class = "rogue",
      deck = { "rogue_poison_dart", "rogue_dirty_blade", "rogue_venom_fang", "rogue_bouncing_flask",
          "rogue_twin_fangs", "rogue_catalyst", "rogue_venom_coating", "rogue_neutralize", "rogue_defend", "rogue_defend" },
      jokers = { "rogue_toxin_master", "rogue_death_mark" }, counters = { "rot_colossus" } },
    { arch = "thorns", class = "warrior",
      deck = { "warrior_flame_barrier", "warrior_flame_barrier", "warrior_shield_slam", "warrior_shield_slam",
          "defense_bulwark", "warrior_taunt", "warrior_defend", "warrior_defend", "warrior_strike", "warrior_strike" },
      jokers = { "warrior_eternal_bulwark", "joker_002" }, counters = { "carrion_king" } },
    { arch = "block", class = "warrior",
      deck = { "warrior_defend", "warrior_defend", "warrior_defend", "defense_bulwark", "warrior_plate_mail",
          "warrior_plate_mail", "warrior_inflame", "warrior_kite_guard", "warrior_power_through", "warrior_shield_slam",
          "warrior_strike", "warrior_strike" },
      jokers = { "warrior_juggernaut", "warrior_bastion" }, counters = { "spectral_knight" } },
    { arch = "exhaust", class = "warrior",
      deck = { "warrior_ghostly_armor", "warrior_ghostly_armor", "warrior_feed", "warrior_immolate",
          "effect_mystery_card", "warrior_second_wind", "warrior_strike", "warrior_strike", "warrior_defend", "warrior_defend" },
      jokers = { "warrior_dark_embrace", "joker_005" }, counters = { "spore_mother" } },
    { arch = "blood", class = "warrior",
      deck = { "warrior_bloodletting", "warrior_bloodletting", "warrior_adrenaline_rush", "warrior_feed",
          "attack_002", "attack_002", "warrior_heavy_blade", "warrior_strike", "warrior_defend", "warrior_defend" },
      jokers = { "joker_003", "warrior_second_heart" }, counters = { "blood_duke" } },
    { arch = "echo", class = "mage",
      deck = { "mage_fireball", "mage_meteor_strike", "mage_arcane_torrent", "mage_overcharge", "mage_mind_spike",
          "mage_zap", "mage_zap", "mage_force_field", "mage_magic_barrier", "mage_magic_barrier" },
      jokers = { "mage_echo_form", "joker_boss_eclipse" }, counters = { "eclipse_queen" } },
}

local function tierOf(Kits, kitId)
    for act, r in pairs(Kits.ROSTER) do
        for tier, list in pairs(r) do
            for _, id in ipairs(list) do
                if id == kitId then return act, tier end
            end
        end
    end
    return 3, "boss"
end

local function mean(t)
    if #t == 0 then return 0 end
    local s = 0
    for _, v in ipairs(t) do s = s + v end
    return s / #t
end

function M.run(seedsArg)
    local seeds = tonumber(seedsArg or os.getenv("SIM509_SEEDS") or "6") or 6
    local BS = require("tools.balance_sim")
    local Autoplay = BS.setup("expert")
    local Kits = require("src.data.enemies")
    local AC = require("src.systems.ArchetypeCounters")
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local realSpec = AC.spec
    local realSig = Autoplay.stateSignature
    local realPrint = print

    local missing = {}
    for _, e in ipairs(M.ENGINES) do
        for _, id in ipairs(e.deck) do if not db:getCard(id) then missing[#missing + 1] = id end end
        for _, id in ipairs(e.jokers) do if not db:getCard(id) then missing[#missing + 1] = id end end
    end
    if #missing > 0 then realPrint("[sim509] ids ausentes: " .. table.concat(missing, ", ")) end

    local trace
    Autoplay.stateSignature = function(game, label, turn)
        local e = game.enemy
        if trace then
            if turn == 1 and trace.hpMul and trace.hpMul > 1 then
                e.maxHealth = math.floor(e.maxHealth * trace.hpMul)
                e.health = e.maxHealth
            end
            trace.hp[#trace.hp + 1] = e.health
        end
        return ""
    end

    local function fight(engine, kitId, opts, seed)
        local act, tier = tierOf(Kits, kitId)
        local snap = {
            class = engine.class, deck = engine.deck,
            jokers = opts.noJokers and {} or engine.jokers,
            jokerActive = opts.noJokers and {} or { true, true },
            services = {}, maxJokerSlots = 2,
            act = act, floorInAct = tier == "boss" and 8 or (tier == "mini_boss" and 7 or 5),
            node = { type = tier, enemyId = kitId },
            hp = opts.hp or 80, maxHp = opts.hp or 80, baseMana = 4,
        }
        AC.spec = opts.counterOff and function() return nil end or realSpec
        trace = { hp = {}, hpMul = opts.hpMul }
        Autoplay.traceSink = {}
        print = function() end
        local ok, r = pcall(Autoplay.replayBattle, snap, seed)
        print = realPrint
        Autoplay.traceSink = nil
        AC.spec = realSpec
        local dealt = {}
        for i = 2, #trace.hp do dealt[#dealt + 1] = math.max(0, trace.hp[i - 1] - trace.hp[i]) end
        trace = nil
        if not ok then return { err = tostring(r) } end
        r.dealt = dealt
        return r
    end

    local out = {}
    local function line(s) out[#out + 1] = s; realPrint(s) end
    local function pick(d, a, b)
        local t = {}
        for i = a, b do if d[i] then t[#t + 1] = d[i] end end
        return t
    end

    line("## Bola de neve (vida do inimigo ×8, jogador com 999 de vida, contra desligado, " .. seeds .. " sementes)")
    line("")
    line("| Motor | Coringas | Dano T1-2 | Dano T5-6 | Pico | Crescimento | Sem coringa T5-6 |")
    line("|---|---|---|---|---|---|---|")
    local snowRows = {}
    for _, e in ipairs(M.ENGINES) do
        local early, late, peak, lateNo = {}, {}, 0, {}
        for s = 1, seeds do
            local r = fight(e, e.counters[1], { counterOff = true, hpMul = 8, hp = 999 }, 509000 + s * 17)
            if r.dealt then
                local a, b = pick(r.dealt, 1, 2), pick(r.dealt, 5, 6)
                if #a > 0 then early[#early + 1] = mean(a) end
                if #b > 0 then late[#late + 1] = mean(b) end
                for _, d in ipairs(r.dealt) do peak = math.max(peak, d) end
            end
            local r0 = fight(e, e.counters[1], { counterOff = true, hpMul = 8, hp = 999, noJokers = true }, 509000 + s * 17)
            local b0 = r0.dealt and pick(r0.dealt, 5, 6) or {}
            if #b0 > 0 then lateNo[#lateNo + 1] = mean(b0) end
        end
        local a, b = mean(early), mean(late)
        snowRows[e.arch] = { early = a, late = b, peak = peak, lateNo = mean(lateNo) }
        line(("| %s | %s | %.0f | %.0f | %d | ×%.1f | %.0f |"):format(e.arch, table.concat(e.jokers, " + "),
            a, b, peak, a > 0 and b / a or 0, mean(lateNo)))
    end

    line("")
    line("## Contra (mesmo chefe, contra ligado × desligado, jogador com 300 de vida, " .. seeds .. " sementes)")
    line("")
    line("| Motor | Inimigo | Vitórias sem contra | Vitórias com contra | Turnos sem → com | Vida perdida sem → com | Dano/turno sem → com |")
    line("|---|---|---|---|---|---|---|")
    local counterRows = {}
    for _, e in ipairs(M.ENGINES) do
        for _, kitId in ipairs(e.counters) do
            local agg = { off = { w = 0, t = {}, h = {}, d = {} }, on = { w = 0, t = {}, h = {}, d = {} } }
            for s = 1, seeds do
                for key, off in pairs({ off = true, on = false }) do
                    local r = fight(e, kitId, { counterOff = off, hp = 300 }, 709000 + s * 29)
                    local a = agg[key]
                    if r.err then
                        realPrint("[sim509] erro " .. e.arch .. "/" .. kitId .. ": " .. r.err)
                    else
                        if r.won then a.w = a.w + 1 end
                        a.t[#a.t + 1] = tonumber(r.turns) or 40
                        a.h[#a.h + 1] = r.hpLost or 0
                        a.d[#a.d + 1] = mean(r.dealt or {})
                    end
                end
            end
            counterRows[#counterRows + 1] = { arch = e.arch, kit = kitId, agg = agg }
            line(("| %s | %s | %d/%d | %d/%d | %.1f → %.1f | %.0f → %.0f | %.0f → %.0f |"):format(
                e.arch, kitId, agg.off.w, seeds, agg.on.w, seeds, mean(agg.off.t), mean(agg.on.t),
                mean(agg.off.h), mean(agg.on.h), mean(agg.off.d), mean(agg.on.d)))
        end
    end

    Autoplay.stateSignature = realSig
    BS.teardown()
    love.filesystem.write("sim_combos_509.md", table.concat(out, "\n") .. "\n")
    realPrint("[sim509] relatório: " .. love.filesystem.getSaveDirectory() .. "/sim_combos_509.md")
    M.snow, M.counters = snowRows, counterRows
    return #missing == 0
end

return M
