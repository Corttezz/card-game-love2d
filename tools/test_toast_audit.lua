local TK = require("tools.testkit")

local M = {}

M.ALLOWED = {
    ["messages.not_in_run"]          = "erro de fluxo (só fora de run)",
    ["messages.card_discovered"]     = "carta inédita entregue sem vitrine (evento)",
    ["messages.card_add_failed"]     = "erro",
    ["messages.joker_benched"]       = "coringa foi pra bancada, não pro campo",
    ["messages.no_mana"]             = "ação recusada",
    ["messages.select_cards"]        = "ação recusada",
    ["messages.passive_toxins_grow"] = "passiva da classe subiu de nível",
    ["messages.blue_seal"]           = "selo explica a compra extra",
    ["messages.gold_seal"]           = "selo explica o ouro no meio da luta",
    ["messages.purple_seal"]         = "selo explica o orbe novo",
    ["messages.armor_capped"]        = "bloqueio desperdiçado no teto",
    ["messages.enemy_fury"]          = "regra anti-arrasto (turno 8+)",
    ["messages.intent_revealed"]     = "a névoa sobre o intent se abriu (carta de Revelar)",
    ["enemy_kit.msg.pierce"]         = "golpe ignorou o bloqueio",
    ["enemy_kit.msg.summoned"]       = "revoada cresceu",
    ["enemy_kit.phases.*"]           = "chefe mudou de fase",
    ["messages.new_record"]          = "recorde da run",
    ["messages.act_transition_heal"] = "cura entre atos",
    ["messages.health_restored"]     = "cura do modo clássico",
    ["messages.settings_unavailable"] = "erro",
    ["messages.no_orbs"]             = "evocar sem orbe",
    ["messages.orb_overflow"]        = "orbe empurrado pra fora",
    ["effect_desc_fallback"]         = "efeito sem motor: descreve a carta",
    ["unlocks.toast_class"]          = "desbloqueio no meio da run",
    ["unlocks.toast_card"]           = "desbloqueio no meio da run",
    ["reward.refresh_fail"]          = "ação recusada",
    ["reward.insufficient_gold"]     = "ação recusada",
    ["reward.joker_run_only"]        = "ação recusada",
    ["reward.service_refunded"]      = "estorno de ouro",
    ["reward.joker_slot_gained"]     = "novo teto de coringas",
    ["reward.interest_cap_raised"]   = "novo teto de juros",
    ["reward.extra_draw"]            = "compras por turno",
    ["joker_manager.cap_reached"]    = "ação recusada",
    ["messages.endless_unlocked"]    = "modo novo liberado",
}

local FILES_DIRS = { "src", "components" }

local function listLua(dir, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = dir .. "/" .. name
        local info = love.filesystem.getInfo(p)
        if info and info.type == "directory" then listLua(p, out)
        elseif name:match("%.lua$") then out[#out + 1] = p end
    end
    return out
end

local function scan(path)
    local src = love.filesystem.read(path) or ""
    local lines = {}
    for l in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
    local found = {}
    for i, l in ipairs(lines) do
        if l:find("addMessage%(") and not l:find("function [%w%.:]*addMessage")
            and not l:find("self%.messageSystem:addMessage") and not l:match("^%s*%-%-") then
            local call = l .. " " .. (lines[i + 1] or "") .. " " .. (lines[i + 2] or "")
            local body = call:match("addMessage%((.*)")
            local key = body:match('^%s*msg%("([%w_]+)"') and ("messages." .. body:match('^%s*msg%("([%w_]+)"'))
                or body:match('^%s*I18n%.t%("([%w_%.]+)"')
                or (body:match("^%s*I18n%.t%(key %.%. \"%.msg\"") and "enemy_kit.phases.*")
                or (body:match("^%s*msg%(discovered and") and "messages.card_discovered")
                or (body:match("^%s*text,") and "effect_desc_fallback")
            found[#found + 1] = { line = i, key = key, src = l }
        end
    end
    return found
end

function M.run()
    TK.bootstrap()
    local t = TK.new("avisos: lista fechada + batalha silenciosa")
    local I18n = require("src.i18n.I18n")

    local ok, err = pcall(function()
        local files = { "main.lua" }
        for _, d in ipairs(FILES_DIRS) do listLua(d, files) end
        local total, bad = 0, {}
        for _, f in ipairs(files) do
            for _, c in ipairs(scan(f)) do
                total = total + 1
                if not c.key or not M.ALLOWED[c.key] then
                    bad[#bad + 1] = ("%s:%d %s"):format(f, c.line, c.key or c.src:gsub("^%s+", ""))
                end
            end
        end
        t:truthy(("%d chamadas de aviso no jogo"):format(total), total > 20)
        t:truthy("toda chamada usa chave da lista" .. (#bad == 0 and "" or (": " .. table.concat(bad, " | "))),
            #bad == 0)
        for key in pairs(M.ALLOWED) do
            if not key:find("%*") and key ~= "effect_desc_fallback" then
                for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
                    I18n.setLocale(loc)
                    local v = I18n.t(key, {}, "\0")
                    if v == "\0" or v == key then t:check(("%s em %s"):format(key, loc), false) end
                end
            end
        end
        I18n.setLocale("pt_BR")

        TK.seedRng(4242)
        local Game = require("src.core.Game")
        local g = Game:new()
        local got = {}
        g.addMessage = function(_, text, kind) got[#got + 1] = tostring(kind) .. ": " .. tostring(text) end
        g:startNewRun("warrior")
        g:startGame()
        TK.pump(g, 1.0)
        t:eq("início da run + batalha: nenhum aviso" .. (#got > 0 and (" (" .. table.concat(got, " | ") .. ")") or ""),
            #got, 0)
        local function play(kind)
            for _, c in ipairs(g.hand) do
                if c.type == kind and (c.cost or 0) <= g.player.mana then
                    g:selectCard(c)
                    g:playSelectedCards()
                    TK.pump(g, 3.0)
                    return true
                end
            end
        end
        play("attack")
        play("defense")
        g:endTurn()
        g.enemy.nextIntent = "attack"
        g.enemy.nextIntentDamage = 6
        g.battleTurn = 1
        local hp0, ar0 = g.player.health, g.player.armor
        g:enemyTurn()
        TK.pump(g, 6.0)
        t:truthy("o inimigo bateu", g.player.health < hp0 or ar0 > 0)
        t:eq("a vez voltou pro jogador", g.turn, "player")
        t:eq("turno inteiro (ataque, defesa, golpe do inimigo): nenhum aviso"
            .. (#got > 0 and (" (" .. table.concat(got, " | ") .. ")") or ""), #got, 0)

        local MessageSystem = require("src.systems.MessageSystem")
        local ms = MessageSystem:new()
        ms:addMessage("", "info")
        ms:addMessage(nil, "info")
        t:eq("vazio não vira aviso", #ms.messages, 0)
        ms:addMessage("A", "info"); ms:addMessage("B", "gold"); ms:addMessage("A", "info")
        t:eq("repetido não empilha", #ms.messages, 2)
        t:eq("repetido vira o mais novo", ms.messages[#ms.messages].text, "A")
        for i = 1, 6 do ms:addMessage("m" .. i, "success") end
        t:eq("no máximo 3 de uma vez", #ms.messages, 3)
        local seen = {}
        for _, k in ipairs({ "error", "warning", "success", "info", "gold", "arcane" }) do
            local c = MessageSystem.accentFor(k)
            local id = ("%.3f %.3f %.3f"):format(c[1], c[2], c[3])
            t:falsy("cor própria: " .. k, seen[id])
            seen[id] = true
        end
    end)
    t:truthy("suite rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
