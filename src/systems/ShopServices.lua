-- src/systems/ShopServices.lua
-- Catálogo dos SERVIÇOS da loja: as relíquias que mexem na RUN em vez de
-- mexer numa batalha.
--
-- POR QUE ESTE MÓDULO EXISTE
-- A loja tinha duas famílias de oferta de upgrade e nenhuma delas conversava:
-- a FORJA (custo crescente, abre um picker de carta, mora no RunManager) e o
-- "pool clássico" (custo fixo, aplica direto no Player, mora no ShopSystem).
-- Toda mecânica nova caía numa escolha ruim — copiar o mecanismo da forja
-- inteiro ou virar mais um `if` de custo fixo. Aqui as duas viram UMA regra:
--
--   • o CUSTO cresce por compra na run (igual à forja),
--   • a DISPONIBILIDADE é uma pergunta ao estado da run (teto por run,
--     tamanho mínimo de deck),
--   • o LEDGER de quantas vezes foi comprado vive no save (RunManager).
--
-- Os números moram em `Config.Offers.SERVICES` (é lá que se mexe em balanço);
-- aqui mora o COMPORTAMENTO. O ShopSystem usa isto pra montar a oferta e a
-- CardRewardScreen pra aplicá-la — uma fonte só, como o CardRegistry é pras
-- ofertas de carta.
--
-- A forja NÃO foi migrada pra cá de propósito: ela tem ledger próprio
-- (`currentRun.paidForges`), testes que o travam e um caminho de UI que já
-- funciona. Reescrevê-la seria risco sem ganho. O que este módulo faz é
-- oferecer o MESMO contrato pras mecânicas novas.

local Config = require("src.core.Config")

local ShopServices = {}

-- Ordem do catálogo é a ordem de desempate; o sorteio usa `weight`.
--   id       chave do i18n (`shop_items.<id>.*`) e do ledger no save
--   effect   string que a CardRewardScreen:applyUpgrade despacha
--   picker   modo do _G.openCardPicker quando o serviço escolhe uma carta
--   fixture  true = SEMPRE na vitrine da loja (não entra no sorteio)
ShopServices.CATALOG = {
    -- A TESOURA é fixa na prateleira, como no Slay the Spire: remoção é a
    -- alavanca que transforma um deck inchado e precisa estar disponível
    -- QUANDO o deck incha, não quando o dado deixa. Sorteada, ela apareceria
    -- em ~1 de cada 6 lojas e a mecânica viraria decoração.
    { id = "remove_card",    effect = "remove_card",    picker = "remove",    weight = 0,   fixture = true },
    { id = "duplicate_card", effect = "duplicate_card", picker = "duplicate", weight = 0.8 },
    -- A BANCADA DE CORINGA também é FIXA (Out/2026). Na vaga rotativa ela
    -- aparecia em ~23% das lojas mesmo com peso 1.3 (medido no balance_sim) —
    -- e a queixa do dono era justamente não conseguir ALCANÇÁ-LA. Fixa, ela
    -- está em toda loja até o teto de compras (`maxPerRun`); batido o teto,
    -- isAvailable a recusa e a vaga volta pro sorteio das outras relíquias.
    { id = "joker_slot",     effect = "add_joker_slot", weight = 0,   fixture = true },
    { id = "card_draw_upgrade", effect = "increase_draw", weight = 0.8 },
    -- COFRE: levanta o teto dos juros. Peso menor que o resto de propósito —
    -- é a relíquia mais cara e a que o jogador precisa ver CEDO pra ela valer
    -- a pena (ver a análise dos três freios em Config.Offers). Aparecer demais
    -- no ato 5 só serviria pra vender prejuízo.
    { id = "interest_cap",   effect = "raise_interest_cap", weight = 0.7,
      -- Único serviço cujo `value` não é 1: o número que a placa do tile
      -- mostra ("+2 JUROS MAX") e que a descrição interpola é o mesmo que o
      -- Game aplica. Lido do Config em ShopServices.value() — duas fontes pro
      -- MESMO número é como uma placa passa a mentir depois de um rebalance.
      valueKey = "INTEREST_CAP_PER_BUY" },
}

local BY_ID = {}
for _, s in ipairs(ShopServices.CATALOG) do BY_ID[s.id] = s end

function ShopServices.get(id)
    return BY_ID[id]
end

-- Config do serviço (números de balanço). Sem fallback silencioso: um id que
-- não está no Config é erro de digitação e precisa aparecer no console.
function ShopServices.tuning(id)
    local cfg = (Config.Offers and Config.Offers.SERVICES or {})[id]
    if not cfg then
        print("[ShopServices] servico sem tuning em Config.Offers.SERVICES: "
            .. tostring(id))
    end
    return cfg
end

-- O NÚMERO do serviço: o que a placa do tile exibe e o que o efeito aplica.
-- 1 por padrão (remover 1 carta, 1 cópia, 1 slot, 1 compra); quem tem
-- `valueKey` lê a grandeza direto do Config, pra que rebalancear o número não
-- deixe a vitrine prometendo o valor antigo.
function ShopServices.value(id)
    local svc = BY_ID[id]
    if not svc then return 1 end
    if svc.valueKey then
        local v = Config.Offers and Config.Offers[svc.valueKey]
        if v then return v end
        print("[ShopServices] valueKey ausente em Config.Offers: "
            .. tostring(svc.valueKey) .. " (servico " .. tostring(id) .. ")")
    end
    return 1
end

-- Quantas vezes o serviço já foi comprado nesta run.
function ShopServices.count(id, runManager)
    if not runManager or not runManager.getServiceCount then return 0 end
    return runManager:getServiceCount(id)
end

-- Custo da PRÓXIMA compra: base * mult^comprasJaFeitas, com teto.
-- Mesma aritmética de RunManager:getPaidForgeCost — de propósito, pra que os
-- dois tipos de relíquia encareçam do mesmo jeito aos olhos do jogador.
function ShopServices.cost(id, runManager)
    local cfg = ShopServices.tuning(id)
    if not cfg then return nil end
    local n = ShopServices.count(id, runManager)
    local raw = cfg.base * (cfg.mult ^ n)
    return math.min(cfg.max, math.floor(raw + 0.5))
end

-- O serviço pode ser OFERTADO agora? Responde pelo estado da run:
--   • teto de compras por run (`maxPerRun`);
--   • tamanho mínimo de deck (`minDeck`) — a tesoura some quando o deck já
--     está no osso, senão a loja vende algo que a tela de remoção vai recusar
--     (RestScreen:doRemove nunca deixa o deck abaixo de 2 cartas).
function ShopServices.isAvailable(id, runManager)
    local cfg = ShopServices.tuning(id)
    if not cfg then return false end
    if not runManager or not runManager.currentRun then return false end

    local maxPerRun = cfg.maxPerRun or 0
    if maxPerRun > 0 and ShopServices.count(id, runManager) >= maxPerRun then
        return false
    end

    if cfg.minDeck then
        local deck = runManager.currentRun.currentDeck or {}
        if #deck < cfg.minDeck then return false end
    end

    return true
end

-- Peso do serviço no sorteio da vaga rotativa — e ele OLHA A RUN.
--
-- Com seis relíquias disputando uma vaga, um peso fixo faz a bancada de
-- coringa aparecer em ~1 de cada 6 lojas: o jogador que acumulou coringas na
-- bancada pode terminar a corrida sem nunca ver a coisa que resolveria o
-- problema dele. Isso não é dificuldade, é a loja não estar prestando
-- atenção.
--
-- Então o peso TRIPLICA quando o jogador tem coringa parado na bancada (mais
-- coringas possuídos do que slots ativos). É a mesma ideia da AFINIDADE das
-- ofertas de carta (Config.Offers.AFFINITY_*): a vitrine responde ao que já
-- está no deck. Fora dessa situação o peso base segue valendo — a bancada
-- continua comprável por antecipação, só não domina a prateleira.
local BENCH_PRESSURE_MULT = 3.0

function ShopServices.weight(id, runManager)
    local svc = BY_ID[id]
    if not svc then return 0 end
    local w = svc.weight or 0

    if id == "joker_slot" and runManager and runManager.currentRun
        and runManager.getActiveJokerCount then
        local possuidos = #(runManager.currentRun.jokers or {})
        if possuidos > runManager:getActiveJokerCount() then
            w = w * BENCH_PRESSURE_MULT
        end
    end

    return w
end

-- Assinatura do DECK: muda quando uma carta entra, sai ou é forjada.
--
-- Serve a UMA pergunta: o jogador pagou pelo serviço e o picker de carta fez
-- alguma coisa? O picker pode ser fechado no "Voltar" sem escolher nada, e
-- sem esta checagem o ouro sairia do bolso pra nada (defeito que a forja já
-- tinha e que a tesoura, sendo fixa na loja, tornaria rotina).
--
-- Um número só: tamanho do deck × 4096 + soma dos níveis de forja. Remover
-- baixa o primeiro termo, duplicar sobe, forjar sobe o segundo.
function ShopServices.deckFingerprint(runManager)
    if not runManager or not runManager.currentRun then return 0 end
    local deck = runManager.currentRun.currentDeck or {}
    local levels = 0
    for i = 1, #deck do
        levels = levels + (runManager:getEntryLevel(deck[i]) or 0)
    end
    return #deck * 4096 + levels
end

return ShopServices
