-- tools/audit_feedback.lua
-- AUDITORIA DE FEEDBACK DE COMBATE (Set/2026).
--
-- Pergunta que esta ferramenta responde SEM depender de ninguem lembrar:
--   "para cada TIPO DE EFEITO que existe no catalogo, o codigo que o processa
--    chama alguma coisa que o jogador OUVE ou VE no instante em que acontece?"
--
-- Como MEDE (nao supoe):
--   1. VARRE o codigo-fonte que processa efeitos (EffectSystem, Game,
--      ComboSystem), segmentando por branch `<algo>.type == "<tipo>"`.
--   2. Dentro de cada branch procura CHAMADAS DE FEEDBACK conhecidas
--      (Sfx.play, FloatingText, CardFeel.burst, pushJokerProc, notifyOrbUI,
--      addMessage, juice_up/hop_up/swell_up, triggerShake, ER.trigger*).
--   3. Segue UM nivel de DELEGACAO declarada (ex: `draw_cards` chama
--      game:drawCard, e o feedback mora la dentro) — ver DELEGATION.
--   4. INSTANCIA o catalogo inteiro e cruza: quais cartas/jokers usam cada
--      tipo — a lista NOMINAL de quem e afetado por cada lacuna.
--
-- Limitacoes declaradas (o relatorio e um mapa, nao um oraculo):
--   - escaneamento estatico por proximidade textual dentro do branch;
--   - funcao cujo corpo NAO e um if-chain por tipo entra em
--     FUNCTION_ATTRIBUTION (hoje so applyJokerEffects);
--   - feedback que mora fora de qualquer branch por tipo (ex: `exhaust`, cujo
--     som esta em `if card.exhaust` no Game) aparece como mudo aqui e esta
--     anotado na linha de base.
--
-- CRITERIO DE FALHA (proposital): a ferramenta NAO falha por lacuna ja
-- existente — elas estao documentadas em docs/auditoria-feedback-combate.md e
-- em correcao por outros agentes. Ela e uma CATRACA: falha se aparecer um tipo
-- de efeito MUDO que nao esta na linha de base BASELINE_SILENT (tipo novo sem
-- feedback, ou tipo que PERDEU o feedback que tinha).
--
-- Rodar:
--   love . test_one audit_feedback     (relatorio completo)
--   love . test_all                    (entra na suite, grupo `valid`)

local CardDatabase = require("src.systems.CardDatabase")
local TK = require("tools.testkit")

local M = {}

-- ===========================================================================
-- 1. Sinais de feedback procurados no codigo
-- ===========================================================================

-- classe -> padroes Lua. A classe e o que o JOGADOR percebe.
local SIGNALS = {
    som       = { "Sfx%.play", "Sfx%.playWithVariation" },
    particula = { "CardFeel%.burst", "ParticleSystem%.Presets" },
    numero    = { "FloatingText" },
    proc      = { "pushJokerProc", "notifyJokerProc", "JokerProcFx" },
    orbe      = { "notifyOrbUI" },
    fisica    = { "juice_up", "hop_up", "swell_up", "shove_x",
                  "start_materialize", "start_dissolve" },
    tela      = { "triggerShake", "jiggleScreen" },
    inimigo   = { "ER%.trigger", "EnemyRenderer%.trigger" },
    toast     = { "addMessage" },
}

-- Classes que contam como "o jogador PERCEBE no instante em que acontece".
-- `toast` fica de fora DE PROPOSITO: o feed lateral e historico, nao evento —
-- foi exatamente a queixa do dono ("sai acontecendo e fica dificil acompanhar").
local PERCEIVED = { "som", "particula", "numero", "proc", "orbe", "fisica",
                    "tela", "inimigo" }

local SOURCES = {
    "src/systems/EffectSystem.lua",
    "src/core/Game.lua",
    "src/systems/ComboSystem.lua",
}

-- Funcoes cujo corpo NAO e um if-chain por tipo, mas cujo feedback pertence a
-- tipos especificos. Atribuicao explicita e declarada.
local FUNCTION_ATTRIBUTION = {
    ["EffectSystem:applyJokerEffects"] = {
        "damage_multiplier", "defense_multiplier",
        "damage_bonus", "defense_bonus",
    },
}

-- DELEGACAO: se o branch de um tipo chama uma destas funcoes, o feedback dela
-- conta pro tipo. Um nivel so, e declarado aqui (nada implicito).
local DELEGATION = {
    ["drawCard"]          = "Game:drawCard",
    ["_evokeOrbEffect"]   = "EffectSystem:_evokeOrbEffect",
    ["processEffectCard"] = "EffectSystem:processEffectCard",
    -- Set/2026: canalizar e evocar viraram BEATS proprios e o corpo saiu do
    -- if-chain pra estes dois helpers (a mutacao do estado precisa morar
    -- DENTRO do beat, nao na coleta). Sem declarar a delegacao a ferramenta le
    -- os tres tipos de orbe como MUDOS e acusa regressao onde houve correcao.
    ["_stepChannelOrb"]   = "EffectSystem:_stepChannelOrb",
    ["_stepEvokeOrb"]     = "EffectSystem:_stepEvokeOrb",
    -- Numero de dano + reacao do inimigo pra magia/evoke, que antes so tinham
    -- burst (o jogador via a MESMA explosao pra "levou dano" e "ganhou orbe").
    ["showEnemyDamage"]   = "showEnemyDamage",
}

-- ===========================================================================
-- 2. Linha de base (catraca). Tipos HOJE sem nenhum sinal percebido.
--    Corrigiu um? Tire da lista NO MESMO COMMIT (o tool avisa se esquecer).
--    Precisa ADICIONAR um? Entao esta introduzindo mudez nova — justifique.
-- ===========================================================================
local BASELINE_SILENT = {
    -- CURADO EM VOO (ritmo-combate, Set/2026): applyHealMultiplier agora empurra
    -- proc. Mantido na lista de proposito enquanto a correcao assenta, pra que
    -- esta ferramenta NUNCA seja o motivo de o test_all ficar vermelho no meio
    -- de uma edicao de terceiro. O [INFO] "tipos CURADOS" cobra a remocao.
    heal_multiplier   = "multiplica a cura em silencio: sem proc, sem som, sem toast",
    apply_buff        = "so toast (Foco do mago nao soa nem brilha)",
    restore_mana      = "so toast (o ManaOrb nao reage ao ganho)",
    increase_max_mana = "so toast",
    self_damage       = "so toast (HP cai sem numero no painel do jogador)",
    discard_cards     = "so toast (a carta some da mao sem animacao de descarte)",
    strength_scaling  = "invisivel: dobra o stat dentro do numero final da carta",
    dexterity_scaling = "invisivel: dobra o stat dentro do numero final da carta",
    multi_hit         = "invisivel: vira 1 numero, a descricao promete 2 golpes",
    add_armor         = "so toast (nao usa o caminho visual da carta de defesa)",
    exhaust           = "branch e no-op; o som real (cardExhaust) mora no Game, "
                        .. "fora de qualquer branch por tipo",
    innate            = "flag de montagem de mao, sem feedback proprio",
}

-- ===========================================================================
-- 3. Varredura estatica
-- ===========================================================================

local function typesInLine(line)
    local found = nil
    for name in line:gmatch("[%w_]*%.?type%s*==%s*\"([%w_]+)\"") do
        found = found or {}; found[#found + 1] = name
    end
    for name in line:gmatch("[^%w_]t%s*==%s*\"([%w_]+)\"") do
        found = found or {}; found[#found + 1] = name
    end
    return found
end

local function classesInLine(line)
    local hits = nil
    for class, pats in pairs(SIGNALS) do
        for _, p in ipairs(pats) do
            if line:find(p) then hits = hits or {}; hits[class] = true; break end
        end
    end
    return hits
end

local function delegatesInLine(line)
    local hits = nil
    for pat, fname in pairs(DELEGATION) do
        -- Fronteira de palavra em vez de exigir `:`/`.`: helpers LOCAIS
        -- (showEnemyDamage) sao chamados sem prefixo e ficariam invisiveis.
        if line:find("[^%w_]" .. pat .. "%s*%(") then
            hits = hits or {}; hits[fname] = true
        end
    end
    return hits
end

-- Retorna sig = { [tipo] = { seen=true, [classe]=true, _where={...},
--                           _delegates={fname=true} } }
local function scanSources()
    local sig = {}          -- por tipo de efeito
    local funcSig = {}      -- por funcao (pra resolver delegacao)

    local function ensure(ty)
        sig[ty] = sig[ty] or { seen = true, _where = {}, _delegates = {} }
        return sig[ty]
    end
    local function mark(types, classes, where)
        for _, ty in ipairs(types) do
            local e = ensure(ty)
            for c in pairs(classes) do
                if not e[c] then
                    e[c] = true
                    e._where[#e._where + 1] = c .. " @ " .. where
                end
            end
        end
    end

    for _, path in ipairs(SOURCES) do
        local src = love.filesystem.read(path)
        if not src then
            print("  [AVISO] nao consegui ler " .. path)
        else
            local current, attributed, curFunc = nil, nil, nil
            local lineNo = 0
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do
                lineNo = lineNo + 1

                if line:match("^function%s") or line:match("^local function%s") then
                    -- Indexa tambem `local function nome(...)`: helper local e
                    -- destino de delegacao valido (showEnemyDamage nasceu assim).
                    local fname = line:match("^function%s+([%w_]+[:%.][%w_]+)")
                        or line:match("^local function%s+([%w_]+)")
                    current = nil
                    curFunc = fname
                    attributed = fname and FUNCTION_ATTRIBUTION[fname] or nil
                end

                local t = typesInLine(line)
                if t then
                    current = t
                    for _, ty in ipairs(t) do ensure(ty) end
                end

                local classes = classesInLine(line)
                if classes then
                    local where = path .. ":" .. lineNo
                    if current then mark(current, classes, where) end
                    if attributed then mark(attributed, classes, where) end
                    if curFunc then
                        funcSig[curFunc] = funcSig[curFunc] or {}
                        for c in pairs(classes) do funcSig[curFunc][c] = true end
                    end
                end

                local dele = delegatesInLine(line)
                if dele and current then
                    for _, ty in ipairs(current) do
                        for fname in pairs(dele) do
                            ensure(ty)._delegates[fname] = true
                        end
                    end
                end
            end
        end
    end

    -- Resolve delegacao (um nivel).
    for _, e in pairs(sig) do
        for fname in pairs(e._delegates) do
            for c in pairs(funcSig[fname] or {}) do
                if not e[c] then
                    e[c] = true
                    e._where[#e._where + 1] = c .. " @ (delegado) " .. fname
                end
            end
        end
    end

    return sig
end

-- ===========================================================================
-- 4. Catalogo: quem usa cada tipo
-- ===========================================================================

local function scanCatalog()
    local db = CardDatabase:new()
    local all = db:getAllCards()
    local byType, total = {}, 0
    for id, card in pairs(all) do
        total = total + 1
        for _, eff in ipairs(card.effects or {}) do
            if eff.type then
                byType[eff.type] = byType[eff.type] or {}
                table.insert(byType[eff.type], {
                    id = id, name = card.name or id, cardType = card.type,
                })
            end
        end
    end
    for _, list in pairs(byType) do
        table.sort(list, function(a, b) return a.id < b.id end)
    end
    return byType, total
end

-- ===========================================================================
-- 5. Relatorio + catraca
-- ===========================================================================

local function perceivedClasses(entry)
    local out = {}
    if entry then
        for _, c in ipairs(PERCEIVED) do
            if entry[c] then out[#out + 1] = c end
        end
    end
    return out
end

function M.run()
    TK.bootstrap()
    local t = TK.new("audit_feedback (feedback por tipo de efeito)")

    local sig = scanSources()
    local byType, totalCards = scanCatalog()

    local types = {}
    for ty in pairs(byType) do types[#types + 1] = ty end
    table.sort(types)

    print("\n  Catalogo: " .. totalCards .. " cartas, "
        .. #types .. " tipos de efeito em uso.")
    print("  'FEEDBACK PERCEBIDO' = o que o jogador ve/ouve NO INSTANTE."
        .. " Toast (feed) conta separado.\n")
    print(string.format("  %-22s %-5s %-34s %s",
        "TIPO", "USOS", "FEEDBACK PERCEBIDO", "TOAST"))
    print("  " .. string.rep("-", 78))

    local silentNow, unknownNow = {}, {}

    for _, ty in ipairs(types) do
        local entry = sig[ty]
        local perc = perceivedClasses(entry)
        local toast = (entry and entry.toast) and "sim" or "-"
        print(string.format("  %-22s %-5d %-34s %s", ty, #byType[ty],
            (#perc > 0) and table.concat(perc, ",") or "NENHUM", toast))
        if not entry then
            unknownNow[#unknownNow + 1] = ty
        elseif #perc == 0 then
            silentNow[#silentNow + 1] = ty
        end
    end

    if #silentNow > 0 or #unknownNow > 0 then
        print("\n  ===== CARTAS AFETADAS POR TIPOS SEM FEEDBACK PERCEBIDO =====")
        local function dump(list, header)
            for _, ty in ipairs(list) do
                local users = byType[ty] or {}
                print(("\n  %s [%s]  (%d cartas)"):format(ty, header, #users))
                for _, u in ipairs(users) do
                    print(("     - %-26s %s (%s)"):format(u.id, u.name, u.cardType))
                end
            end
        end
        dump(unknownNow, "NENHUM BRANCH PROCESSA ESTE TIPO")
        dump(silentNow, "BRANCH EXISTE MAS SO TOAST OU NADA")
    end

    -- ----- Simultaneidade: quantos efeitos resolvem no MESMO instante -----
    -- Game:processCardInCombat roda processAdditionalEffects() em UM frame, no
    -- impacto da carta: todo efeito secundario da carta acontece junto do
    -- numero de dano/bloqueio, do burst e dos procs de joker. Quanto maior a
    -- contagem, mais coisa o jogador precisa ler no mesmo piscar de olhos.
    local FLAGS = { exhaust = true, innate = true, retain = true }
    local db2 = CardDatabase:new()
    local heavy, multi = {}, 0
    for id, card in pairs(db2:getAllCards()) do
        local n = 0
        for _, eff in ipairs(card.effects or {}) do
            if eff.type and not FLAGS[eff.type] then n = n + 1 end
        end
        -- ataque/defesa ja resolvem 1 "efeito" implicito (o dano/bloqueio).
        if card.type == "attack" or card.type == "defense" then n = n + 1 end
        if n >= 2 then
            multi = multi + 1
            heavy[#heavy + 1] = { id = id, name = card.name or id, n = n }
        end
    end
    table.sort(heavy, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.id < b.id
    end)
    print(("\n  ===== SIMULTANEIDADE (efeitos resolvidos no MESMO instante) ====="))
    print(("  %d de %d cartas resolvem 2+ coisas de uma vez."):format(multi, totalCards))
    print("  Top 15 (contagem inclui o dano/bloqueio da propria carta):")
    for i = 1, math.min(15, #heavy) do
        print(("     %dx  %-26s %s"):format(heavy[i].n, heavy[i].id, heavy[i].name))
    end

    -- ----- Catraca -----
    print("\n  ===== CATRACA =====")
    local novos = {}
    for _, ty in ipairs(silentNow) do
        if not BASELINE_SILENT[ty] then novos[#novos + 1] = ty end
    end
    for _, ty in ipairs(unknownNow) do
        if not BASELINE_SILENT[ty] then novos[#novos + 1] = ty end
    end
    table.sort(novos)
    t:eq("nenhum tipo de efeito MUDO fora da linha de base", #novos, 0)
    for _, ty in ipairs(novos) do
        print("     !! " .. ty .. " nao tem feedback percebido e nao esta"
            .. " em BASELINE_SILENT")
    end

    -- Linha de base obsoleta: tipo que ganhou feedback e continua listado.
    -- Nao falha (as correcoes estao em voo), mas avisa em alto e bom som.
    local curados = {}
    for ty in pairs(BASELINE_SILENT) do
        if sig[ty] and #perceivedClasses(sig[ty]) > 0 then
            curados[#curados + 1] = ty
        end
    end
    table.sort(curados)
    if #curados > 0 then
        print("\n  [INFO] tipos CURADOS desde a linha de base — tire de"
            .. " BASELINE_SILENT no mesmo commit:")
        for _, ty in ipairs(curados) do print("     + " .. ty) end
    end

    local orfaos = {}
    for ty in pairs(BASELINE_SILENT) do
        if not byType[ty] then orfaos[#orfaos + 1] = ty end
    end
    table.sort(orfaos)
    if #orfaos > 0 then
        print("\n  [INFO] em BASELINE_SILENT mas sem nenhuma carta usando: "
            .. table.concat(orfaos, ", "))
    end

    return t:done()
end

return M
