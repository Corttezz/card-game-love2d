-- tools/balance_sim.lua
-- BATERIA DE BALANCEAMENTO (Out/2026): muitas runs seedadas por classe pelo
-- piloto v6 (tools/autoplay.lua + tools/balance_ai.lua) e um relatorio
-- AGREGADO — winrate por classe, onde se morre e contra o que, impacto de
-- cada carta e coringa.
--
--   love . balance_sim [runsPorClasse] [classes] [seedBase] [politica]
--     classes   = all | warrior | mage | rogue | warrior,rogue
--     politica  = v6 (padrao) | v5   (A/B da qualidade do proprio piloto)
--   ex: love . balance_sim 40 all 500000
--
-- Saida: console + arquivo (BALANCE_OUT, padrao balance_sim_report.md no save
-- dir). Com BALANCE_OUT apontando pra um caminho do projeto, grava la.
--
-- O CATALOGO INTEIRO e medido: se o UnlockSystem (frente de progressao)
-- existir, a bateria liga o override "tudo desbloqueado" — senao a amostra
-- mediria so as cartas iniciais e o veredito de forca seria de outro jogo.
--
-- Metodo do IMPACTO de carta (o vies obvio e "quem vai mais longe compra mais
-- cartas"): compara so runs VIVAS num mesmo andar de corte. Para cada carta,
-- entre as runs que chegaram ao andar F, separa quem a tinha adquirido ATE F
-- de quem nao tinha e compara vitoria e profundidade final. F = 9 (fim do A1)
-- e F = 17 (fim do A2).

local M = {}

local function fmtPct(a, b) return b > 0 and string.format("%.0f%%", 100 * a / b) or "-" end

local function enableFullCatalog()
    local ok, US = pcall(require, "src.systems.UnlockSystem")
    if ok and type(US) == "table" and type(US.setOverrideAll) == "function" then
        US.setOverrideAll(true)
        print("[balance_sim] UnlockSystem: override 'tudo desbloqueado' LIGADO (catalogo inteiro)")
        return true
    end
    print("[balance_sim] UnlockSystem ausente — catalogo inteiro ja e o padrao")
    return false
end

local function writeOut(text)
    local path = os.getenv("BALANCE_OUT")
    if path and path ~= "" then
        local f = io.open(path, "w")
        if f then f:write(text); f:close(); print("[balance_sim] relatorio: " .. path); return end
        print("[balance_sim] AVISO: nao consegui gravar " .. path .. " — indo pro save dir")
    end
    love.filesystem.write("balance_sim_report.md", text)
    print("[balance_sim] relatorio: <save dir>/balance_sim_report.md")
end

-- ============================================================
-- Agregacao
-- ============================================================

local CUTS = { 9, 17 }

function M.aggregate(records)
    local CardDatabase = require("src.systems.CardDatabase")
    local byClass = {}
    for _, r in ipairs(records) do
        local c = byClass[r.class] or { runs = 0, wins = 0, crashes = 0, deathAct = {},
            deathNode = {}, floors = 0, list = {} }
        byClass[r.class] = c
        c.runs = c.runs + 1
        c.list[#c.list + 1] = r
        if r.crash then c.crashes = c.crashes + 1
        else
            c.floors = c.floors + (r.floors or 0)
            if r.won then c.wins = c.wins + 1
            elseif r.death then
                local a = r.death.act or 0
                c.deathAct[a] = (c.deathAct[a] or 0) + 1
                local key = string.format("A%d %s", a, r.death.node or "?")
                c.deathNode[key] = (c.deathNode[key] or 0) + 1
            end
        end
    end

    -- impacto por carta (condicionado a estar vivo no corte)
    local impact = {}
    for _, cut in ipairs(CUTS) do
        local alive = {}
        for _, r in ipairs(records) do
            if not r.crash and (r.floors or 0) > cut then alive[#alive + 1] = r end
        end
        local stats = {}
        for _, r in ipairs(alive) do
            local has = {}
            for _, a in ipairs(r.acquired or {}) do
                if (a.floor or 0) <= cut then has[a.id] = true end
            end
            r._has = has
        end
        -- universo de cartas vistas nesta faixa
        local ids = {}
        for _, r in ipairs(alive) do for id in pairs(r._has) do ids[id] = true end end
        for id in pairs(ids) do
            local w, n, fw, wo, no, fwo = 0, 0, 0, 0, 0, 0
            for _, r in ipairs(alive) do
                -- so compara dentro da MESMA classe que poderia pegar a carta
                local cd = CardDatabase:getCard(id)
                local cls = cd and cd.class
                if cls == r.class or cls == "basic" or cls == nil then
                    if r._has[id] then
                        n = n + 1; fw = fw + r.floors; if r.won then w = w + 1 end
                    else
                        no = no + 1; fwo = fwo + r.floors; if r.won then wo = wo + 1 end
                    end
                end
            end
            if n >= 3 and no >= 3 then
                stats[#stats + 1] = { id = id, n = n, no = no,
                    wr = w / n, wro = wo / no,
                    depth = fw / n, deptho = fwo / no,
                    dWin = w / n - wo / no, dDepth = fw / n - fwo / no }
            end
        end
        table.sort(stats, function(a, b) return a.dDepth > b.dDepth end)
        impact[cut] = { alive = #alive, list = stats }
    end

    -- pick rate: ofertado x adquirido
    local offered, picked = {}, {}
    for _, r in ipairs(records) do
        for id, n in pairs(r.offered or {}) do offered[id] = (offered[id] or 0) + n end
        for _, a in ipairs(r.acquired or {}) do picked[a.id] = (picked[a.id] or 0) + 1 end
    end
    return { byClass = byClass, impact = impact, offered = offered, picked = picked }
end

function M.report(records, agg, meta)
    local out = {}
    local function p(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    local CardDatabase = require("src.systems.CardDatabase")
    local function nameOf(id)
        local cd = CardDatabase:getCard(id)
        return string.format("%s (%s)", id, cd and (cd.rarity or "?") or "?")
    end
    p("# Bateria de balanceamento — %s", meta.label or "")
    p("")
    p("Piloto %s | %d runs/classe | seed base %d | %d atos", meta.policy, meta.runs, meta.seed,
        require("src.core.Config").TotalActs)
    p("")
    p("## Winrate por classe")
    p("")
    p("| classe | runs | vitorias | winrate | batalhas vencidas (media) | deck final (media) | crashes |")
    p("|---|---|---|---|---|---|---|")
    local classes = {}
    for c in pairs(agg.byClass) do classes[#classes + 1] = c end
    table.sort(classes)
    for _, c in ipairs(classes) do
        local s = agg.byClass[c]
        local deckSum, deckN = 0, 0
        for _, r in ipairs(s.list) do
            if r.deck then deckSum = deckSum + #r.deck; deckN = deckN + 1 end
        end
        p("| %s | %d | %d | %s | %.1f | %.1f | %d |", c, s.runs, s.wins, fmtPct(s.wins, s.runs),
            s.floors / math.max(1, s.runs - s.crashes), deckSum / math.max(1, deckN), s.crashes)
    end
    p("")
    -- Ritmo do combate (kit dos inimigos, Out/2026): turnos por luta, dano
    -- SOFRIDO por turno (tensao) e duracao das lutas de chefe, por ato.
    p("## Combate por ato (todas as classes)")
    p("")
    p("| ato | batalhas | turnos/luta | dano sofrido/turno | chefes | turnos/chefe |")
    p("|---|---|---|---|---|---|")
    local acts = {}
    for _, r in ipairs(records) do
        for a, ba in pairs(r.byAct or {}) do
            local x = acts[a] or { battles = 0, turns = 0, taken = 0, bosses = 0, bossTurns = 0 }
            x.battles = x.battles + (ba.battles or 0)
            x.turns = x.turns + (ba.turns or 0)
            x.taken = x.taken + (ba.taken or 0)
            x.bosses = x.bosses + (ba.bosses or 0)
            x.bossTurns = x.bossTurns + (ba.bossTurns or 0)
            acts[a] = x
        end
    end
    for a = 1, 8 do
        local x = acts[a]
        if x and x.battles > 0 then
            p("| %d | %d | %.1f | %.1f | %d | %s |", a, x.battles, x.turns / x.battles,
                x.taken / math.max(1, x.turns), x.bosses,
                x.bosses > 0 and string.format("%.1f", x.bossTurns / x.bosses) or "-")
        end
    end
    p("")
    p("## Ato de morte")
    p("")
    for _, c in ipairs(classes) do
        local s = agg.byClass[c]
        local parts = {}
        for a = 1, 7 do
            if s.deathAct[a] then parts[#parts + 1] = ("A%d: %d"):format(a, s.deathAct[a]) end
        end
        p("- **%s**: %s", c, #parts > 0 and table.concat(parts, " · ") or "nenhuma")
    end
    p("")
    p("## Onde se morre (ato + tipo de no)")
    p("")
    local all = {}
    for _, c in ipairs(classes) do
        for k, n in pairs(agg.byClass[c].deathNode) do
            all[k] = all[k] or {}
            all[k][c] = n
            all[k]._t = (all[k]._t or 0) + n
        end
    end
    local keys = {}
    for k in pairs(all) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return all[a]._t > all[b]._t end)
    p("| no | total | %s |", table.concat(classes, " | "))
    p("|---|---|%s", string.rep("---|", #classes))
    for _, k in ipairs(keys) do
        local cols = {}
        for _, c in ipairs(classes) do cols[#cols + 1] = tostring(all[k][c] or 0) end
        p("| %s | %d | %s |", k, all[k]._t, table.concat(cols, " | "))
    end
    for _, cut in ipairs(CUTS) do
        local im = agg.impact[cut]
        p("")
        p("## Impacto de carta (runs vivas no andar %d: %d)", cut, im.alive)
        p("")
        p("Diferenca de profundidade final (andares) e de vitoria entre quem TINHA a carta ate o andar %d e quem nao tinha (mesma classe).", cut)
        p("")
        p("| carta | com | sem | andares com | andares sem | delta andares | win com | win sem |")
        p("|---|---|---|---|---|---|---|---|")
        local list = im.list
        local shown = {}
        for i = 1, math.min(12, #list) do shown[#shown + 1] = list[i] end
        if #list > 24 then shown[#shown + 1] = false end
        for i = math.max(13, #list - 11), #list do shown[#shown + 1] = list[i] end
        for _, s in ipairs(shown) do
            if s == false then p("| ... | | | | | | | |")
            else
                p("| %s | %d | %d | %.1f | %.1f | %+.1f | %.0f%% | %.0f%% |", nameOf(s.id), s.n, s.no,
                    s.depth, s.deptho, s.dDepth, 100 * s.wr, 100 * s.wro)
            end
        end
    end
    p("")
    p("## Taxa de escolha (adquirida / ofertada)")
    p("")
    local pr = {}
    for id, n in pairs(agg.offered) do
        if n >= 5 then pr[#pr + 1] = { id = id, off = n, pick = agg.picked[id] or 0 } end
    end
    table.sort(pr, function(a, b) return a.pick / a.off > b.pick / b.off end)
    p("| carta | ofertada | adquirida | taxa |")
    p("|---|---|---|---|")
    for _, s in ipairs(pr) do
        p("| %s | %d | %d | %s |", nameOf(s.id), s.off, s.pick, fmtPct(s.pick, s.off))
    end
    p("")
    p("## Coringas ativos no fim da run")
    p("")
    local jk = {}
    for _, r in ipairs(records) do
        for _, j in ipairs(r.jokers or {}) do
            local k = j.id
            jk[k] = jk[k] or { n = 0, active = 0, wins = 0 }
            jk[k].n = jk[k].n + 1
            if j.active then jk[k].active = jk[k].active + 1 end
            if r.won then jk[k].wins = jk[k].wins + 1 end
        end
    end
    local jl = {}
    for id, s in pairs(jk) do jl[#jl + 1] = { id = id, s = s } end
    table.sort(jl, function(a, b) return a.s.n > b.s.n end)
    p("| coringa | runs que possuiam | ativo | vitorias |")
    p("|---|---|---|---|")
    for _, e in ipairs(jl) do
        p("| %s | %d | %d | %d |", nameOf(e.id), e.s.n, e.s.active, e.s.wins)
    end
    local anomalies = meta.anomalies or {}
    p("")
    p("## Anomalias do piloto: %d", #anomalies)
    for i = 1, math.min(30, #anomalies) do p("- %s", anomalies[i]) end
    return table.concat(out, "\n")
end

-- ============================================================
-- Entrada
-- ============================================================

-- Prepara o processo pra bateria (tambem usado por tools/leak_probe.lua).
-- Devolve o modulo do piloto pronto.
function M.setup(policy)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    enableFullCatalog()

    -- A bateria nao desenha nada: a moldura procedural de cada carta (um
    -- canvas por instancia, refeito a cada replay da simulacao de deck)
    -- era o maior custo de CPU e de memoria. Uma moldura unica compartilhada
    -- mantem largura/altura validas pra geometria do CombatSequence.
    do
        local CardFrame = require("src.ui.CardFrame")
        local shared = love.graphics.newCanvas(96, 144)
        CardFrame.render = function() return shared end
        print("[balance_sim] moldura de carta compartilhada (bateria sem render)")
    end
    -- A faixa de combo pre-renderiza um canvas por combo anunciado. Sem
    -- love.graphics.present (a bateria nunca apresenta frame), o driver
    -- acumulava esses comandos de desenho e o processo crescia em degraus de
    -- dezenas de MB por run ate passar de 1 GB — com o heap Lua em ~10 MB.
    -- Medido: com a faixa desligada o working set fica plano entre runs.
    require("src.ui.ComboBanner").show = function() end

    local Autoplay = require("tools.autoplay")
    Autoplay.policy = policy
    Autoplay.quiet = true
    Autoplay.installHooks()
    return Autoplay
end

function M.run(runsArg, classArg, seedArg, policyArg)
    local runs = tonumber(runsArg or os.getenv("BALANCE_RUNS") or "20") or 20
    local classes = { "warrior", "mage", "rogue" }
    local carg = classArg or os.getenv("BALANCE_CLASSES") or "all"
    if carg ~= "all" then
        classes = {}
        for c in carg:gmatch("[^,]+") do classes[#classes + 1] = c end
    end
    local seed = tonumber(seedArg or os.getenv("BALANCE_SEED") or "500000") or 500000
    local policy = policyArg or os.getenv("BALANCE_POLICY") or "v6"
    local Autoplay = M.setup(policy)

    -- silencia o print do jogo durante a bateria (milhares de toasts por run
    -- deixavam a bateria lenta e o log ilegivel); o resumo por run sai aqui.
    -- progresso visivel em bateria longa (stdout em arquivo e bufferizado)
    pcall(function() io.stdout:setvbuf("line") end)
    local realPrint = print
    local records = {}
    local t0 = os.clock()
    for _, cls in ipairs(classes) do
        for i = 1, runs do
            local s = seed + i
            print = function() end
            local ok, rec = pcall(Autoplay.playRunRecord, cls, i, s)
            print = realPrint
            if not ok then
                rec = { class = cls, seed = s, crash = true, outcome = "CRASH " .. tostring(rec),
                    floors = 0, offered = {}, acquired = {} }
            end
            records[#records + 1] = rec
            realPrint(string.format("[balance_sim] %s #%d seed %d: %s (andares %d) t=%.0fs",
                cls, i, s, tostring(rec.outcome), rec.floors or 0, os.clock() - t0))
        end
    end
    local agg = M.aggregate(records)
    local text = M.report(records, agg, { policy = policy, runs = runs, seed = seed,
        label = os.getenv("BALANCE_LABEL") or "", anomalies = Autoplay.getAnomalies() })
    print(text)
    writeOut(text)
    M.lastRecords, M.lastAgg = records, agg
    love.event.quit()
end

return M
