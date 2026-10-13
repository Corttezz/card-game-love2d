-- tools/balance_sim.lua
-- BATERIA DE BALANCEAMENTO (Out/2026): muitas runs seedadas por classe pelo
-- piloto (tools/autoplay.lua + tools/balance_ai.lua) e um relatorio
-- AGREGADO — winrate por classe, onde se morre e contra o que, impacto de
-- cada carta e coringa.
--
--   love . balance_sim [runsPorClasse] [classes] [seedBase] [piloto]
--     classes   = all | warrior | mage | rogue | warrior,rogue
--     piloto    = expert (padrao) | expert_fast | average | naive | expert_full
--                 (v5/v6/v6b/v6c legados continuam valendo)
--   ex: love . balance_sim 40 all 500000 average
--
-- Saida: console + arquivo (BALANCE_OUT, padrao balance_sim_report.md no save
-- dir). Com BALANCE_OUT apontando pra um caminho do projeto, grava la.
-- BALANCE_JSON=<arquivo>: grava TODOS os registros de run em JSON (uma
-- lista) — e o que tools/balance.py junta de varios processos.
--
-- RELOGIO: por padrao a bateria roda no relogio INSTANTANEO
-- (tools/instant_engine.lua — fila drenada por saltos, mesma regra, paridade
-- travada em test_instant_parity). BALANCE_CLOCK=frames volta ao avanco por
-- quadros (1/30 s) do piloto original.
--
-- KNOBS de A/B sem editar o jogo (lidos no setup; o sweep de
-- tools/balance_tune.py usa todos):
--   BALANCE_ENEMY_POWER="dano,vida"    Config.Game.ENEMY_POWER (ex: "0.8,0.85")
--   BALANCE_BOSS_HP=<mult>             vida de chefe e mini-chefe (ex: 1.15)
--   BALANCE_COMBO="volley=3,wall=5"    `step` das regras de combo por id
--   BALANCE_PLAYER_HP=<n>              vida inicial do jogador
--   BALANCE_SEAL=<n> / BALANCE_ENDLESS=<n>   selo da run / andares de endless
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
    -- JOGADAS (Out/2026, combo-clareza): o tamanho da leva e quanto do valor
    -- das cartas veio de COMBO. "Spam" = muitas cartas por leva + combo
    -- carregando o dano.
    p("")
    p("## Jogadas por classe")
    p("")
    p("| classe | levas | cartas/leva | max | levas com combo | dano de combo | bloqueio de combo | 1 | 2 | 3 | 4 | 5+ |")
    p("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for _, c in ipairs(classes) do
        local t = { n = 0, cards = 0, max = 0, withCombo = 0, atk = 0, atkCombo = 0,
            def = 0, defCombo = 0, hist = {} }
        for _, r in ipairs(agg.byClass[c].list) do
            local ps = r.plays
            if ps then
                for _, k in ipairs({ "n", "cards", "withCombo", "atk", "atkCombo", "def", "defCombo" }) do
                    t[k] = t[k] + (ps[k] or 0)
                end
                if (ps.max or 0) > t.max then t.max = ps.max end
                for k, v in pairs(ps.hist or {}) do
                    local b = math.min(5, k)
                    t.hist[b] = (t.hist[b] or 0) + v
                end
            end
        end
        p("| %s | %d | %.2f | %d | %s | %s | %s | %s | %s | %s | %s | %s |", c, t.n,
            t.cards / math.max(1, t.n), t.max, fmtPct(t.withCombo, t.n),
            fmtPct(t.atkCombo, t.atk), fmtPct(t.defCombo, t.def),
            fmtPct(t.hist[1] or 0, t.n), fmtPct(t.hist[2] or 0, t.n), fmtPct(t.hist[3] or 0, t.n),
            fmtPct(t.hist[4] or 0, t.n), fmtPct(t.hist[5] or 0, t.n))
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
    -- ECONOMIA (Out/2026): renda e gasto por ato, ouro na porta da loja e o
    -- alcance da bancada extra de coringa. Medias sobre as runs que CHEGARAM
    -- ao ato (quem morreu no A2 nao puxa a media do A4 pra zero).
    p("")
    p("## Economia por ato (media por run que chegou ao ato)")
    p("")
    p("| ato | runs | batalhas | ganho | gasto | ganho/batalha | lojas | ouro na porta da loja |")
    p("|---|---|---|---|---|---|---|---|")
    local ea = {}
    for _, r in ipairs(records) do
        local e = r.eco
        if e then
            local seen = {}
            for a, ba in pairs(r.byAct or {}) do seen[a] = true end
            for a in pairs(e.earned) do seen[a] = true end
            for a in pairs(seen) do
                local x = ea[a] or { runs = 0, battles = 0, earned = 0, spent = 0,
                    shops = 0, shopGold = 0 }
                ea[a] = x
                x.runs = x.runs + 1
                x.battles = x.battles + (((r.byAct or {})[a] or {}).battles or 0)
                x.earned = x.earned + (e.earned[a] or 0)
                x.spent = x.spent + (e.spent[a] or 0)
            end
            for _, v in ipairs(e.shops) do
                local x = ea[v.act]
                if x then x.shops = x.shops + 1; x.shopGold = x.shopGold + v.gold end
            end
        end
    end
    local actList = {}
    for a in pairs(ea) do actList[#actList + 1] = a end
    table.sort(actList)
    for _, a in ipairs(actList) do
        local x = ea[a]
        p("| %d | %d | %.1f | $%.0f | $%.0f | $%.1f | %.2f | $%.0f |", a, x.runs,
            x.battles / x.runs, x.earned / x.runs, x.spent / x.runs,
            x.earned / math.max(1, x.battles), x.shops / x.runs,
            x.shopGold / math.max(1, x.shops))
    end
    local slotSeen, slotAff, visits = 0, 0, 0
    local byType = {}
    for _, r in ipairs(records) do
        for _, v in ipairs((r.eco or {}).shops or {}) do
            visits = visits + 1
            if v.slotCost then
                slotSeen = slotSeen + 1
                if v.slotAffordable then slotAff = slotAff + 1 end
            end
        end
        for k, n in pairs((r.eco or {}).byType or {}) do byType[k] = (byType[k] or 0) + n end
    end
    p("")
    p("- Visitas a loja: %d | bancada de coringa na vitrine: %d (%s) | cabia no bolso: %d (%s das vezes que apareceu)",
        visits, slotSeen, fmtPct(slotSeen, visits), slotAff, fmtPct(slotAff, slotSeen))
    local bt = {}
    for k, n in pairs(byType) do bt[#bt + 1] = { k = k, n = n } end
    table.sort(bt, function(a, b) return a.n > b.n end)
    local parts = {}
    for _, e in ipairs(bt) do parts[#parts + 1] = string.format("%s $%.0f", e.k, e.n / math.max(1, #records)) end
    p("- Gasto medio por run, por item: %s", table.concat(parts, " · "))
    -- ENDLESS (BALANCE_ENDLESS=N): ate onde os vencedores chegam depois da
    -- vitoria — o ciclo em que a curva exponencial encerra a corrida.
    local endl = {}
    for _, r in ipairs(records) do
        if r.endless then endl[#endl + 1] = r end
    end
    if #endl > 0 then
        p("")
        p("## Endless (vencedores que seguiram)")
        p("")
        local sum, best = 0, 0
        local byCycle = {}
        for _, r in ipairs(endl) do
            local f = r.endlessFloors or 0
            sum, best = sum + f, math.max(best, f)
            local c = math.floor(math.max(0, f - 1) / 8) + 1
            byCycle[c] = (byCycle[c] or 0) + 1
        end
        p("- Runs: %d | andar medio %.1f | melhor %d", #endl, sum / #endl, best)
        local cs = {}
        for c, n in pairs(byCycle) do cs[#cs + 1] = c end
        table.sort(cs)
        for _, c in ipairs(cs) do p("- terminou no ciclo %d: %d run(s)", c, byCycle[c]) end
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
    -- TURBO (BALANCE_TURBO=1): relogio em passos de 0,1s e beats do combate
    -- 4x mais curtos. So muda QUANTAS vezes a fila e bombeada, nao a regra.
    -- A/B rapido da forca do inimigo sem editar o Config:
    -- BALANCE_ENEMY_POWER="dano,vida" (ex: "0.72,0.8")
    local ep = os.getenv("BALANCE_ENEMY_POWER")
    if ep and ep ~= "" then
        local d, h = ep:match("([%d%.]+),([%d%.]+)")
        if d then
            require("src.core.Config").Game.ENEMY_POWER = { damage = tonumber(d), health = tonumber(h) }
            print("[balance_sim] ENEMY_POWER dano " .. d .. " vida " .. h)
        end
    end
    if os.getenv("BALANCE_TURBO") == "1" then
        Autoplay.pumpDt = 0.1
        require("src.systems.CombatBeats").speed = 0.25
        print("[balance_sim] TURBO ligado (pumpDt 0.1, beats x0.25)")
    end
    -- Knobs do sweep (tools/balance_tune.py). Cada um AVISA o valor aplicado.
    do
        local bh = tonumber(os.getenv("BALANCE_BOSS_HP") or "")
        if bh and bh ~= 1 then
            local AS = require("src.systems.ActSystem")
            local orig = AS.getEnemyStats
            AS.getEnemyStats = function(actNumber, floorInAct, nodeType, endlessFloor)
                local st = orig(actNumber, floorInAct, nodeType, endlessFloor)
                if nodeType == "boss" or nodeType == "mini_boss" then
                    st.health = math.floor(st.health * bh)
                end
                return st
            end
            print("[balance_sim] BOSS_HP x" .. bh)
        end
        local combo = os.getenv("BALANCE_COMBO")
        if combo and combo ~= "" then
            local CS = require("src.systems.ComboSystem")
            for id, v in combo:gmatch("(%w+)=([%d%.]+)") do
                local rule = CS.RULE_BY_ID and CS.RULE_BY_ID[id]
                if rule then
                    rule.step = tonumber(v)
                    print("[balance_sim] COMBO " .. id .. ".step = " .. v)
                else
                    print("[balance_sim] AVISO: combo desconhecido '" .. id .. "'")
                end
            end
        end
        local php = tonumber(os.getenv("BALANCE_PLAYER_HP") or "")
        if php then
            require("src.core.Config").Game.PLAYER_MAX_HEALTH = php
            print("[balance_sim] PLAYER_MAX_HEALTH = " .. php)
        end
    end
    Autoplay.setPilot(policy or os.getenv("BALANCE_PILOT") or "expert")
    Autoplay.quiet = true
    Autoplay.installHooks()
    -- Relogio instantaneo por padrao (ver cabecalho).
    if (os.getenv("BALANCE_CLOCK") or "instant") == "frames" then
        require("tools.instant_engine").uninstall(Autoplay)
        print("[balance_sim] relogio de QUADROS")
    else
        require("tools.instant_engine").install(Autoplay)
    end
    return Autoplay
end

-- Grava os registros em JSON (BALANCE_JSON). Cada registro e o `runRec` do
-- piloto: resultado, morte, batalhas (battleLog), dano por fonte, deck,
-- coringas, ofertas/aquisicoes, forjas, compras, economia por ato.
local function writeJson(records, meta)
    local path = os.getenv("BALANCE_JSON")
    if not path or path == "" then return end
    local J = require("tools.jsonlite")
    local f = io.open(path, "w")
    if not f then
        print("[balance_sim] AVISO: nao consegui gravar JSON em " .. path)
        return
    end
    f:write(J.encode({ meta = meta, records = records }))
    f:close()
    print("[balance_sim] json: " .. path)
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
    local policy = policyArg or os.getenv("BALANCE_PILOT") or os.getenv("BALANCE_POLICY") or "expert"
    local Autoplay = M.setup(policy)
    local Instant = require("tools.instant_engine")
    local wall0 = os.time()

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
            local tRun0 = os.clock()
            print = function() end
            local ok, rec = pcall(Autoplay.playRunRecord, cls, i, s)
            print = realPrint
            if not ok then
                rec = { class = cls, seed = s, crash = true, outcome = "CRASH " .. tostring(rec),
                    floors = 0, offered = {}, acquired = {} }
            end
            rec.pilot = rec.pilot or policy
            rec.seal = rec.seal or tonumber(os.getenv("BALANCE_SEAL") or "0") or 0
            rec.cpuSeconds = os.clock() - tRun0
            records[#records + 1] = rec
            realPrint(string.format("[balance_sim] %s #%d seed %d: %s (andares %d) t=%.0fs",
                cls, i, s, tostring(rec.outcome), rec.floors or 0, os.clock() - t0))
        end
    end
    local cpu = os.clock() - t0
    local meta = { policy = policy, pilot = policy, runs = runs, seed = seed,
        classes = classes, seal = tonumber(os.getenv("BALANCE_SEAL") or "0") or 0,
        label = os.getenv("BALANCE_LABEL") or "", anomalies = Autoplay.getAnomalies(),
        clock = Autoplay.clockMode or "frames", cpuSeconds = cpu,
        wallSeconds = os.time() - wall0, runsPerSecond = #records / math.max(1e-6, cpu),
        instantStalls = Instant.stats.stalls, instantIters = Instant.stats.iters,
        knobs = { enemyPower = os.getenv("BALANCE_ENEMY_POWER"), bossHp = os.getenv("BALANCE_BOSS_HP"),
            combo = os.getenv("BALANCE_COMBO"), playerHp = os.getenv("BALANCE_PLAYER_HP") },
        totalActs = require("src.core.Config").TotalActs }
    local agg = M.aggregate(records)
    local text = M.report(records, agg, meta)
    print(text)
    print(string.format("[balance_sim] %d runs em %.1fs de CPU (%.2f runs/s, relogio %s)",
        #records, cpu, meta.runsPerSecond, meta.clock))
    writeOut(text)
    writeJson(records, meta)
    M.lastRecords, M.lastAgg = records, agg
    love.event.quit()
end

return M
