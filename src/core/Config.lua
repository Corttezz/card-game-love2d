-- src/Config.lua
-- Sistema de configuração centralizado para o jogo

local Config = {}

-- Versão do jogo (menu/splash mostram no rodapé).
-- Sobe a cada leva de correcoes que o dono vai TESTAR. O menu imprime este
-- numero no rodape (Menu:_drawVersionFooter), e e assim que se responde
-- "estou rodando a build certa?" sem adivinhar — ver a memoria
-- user-runs-stale-copy: `love .` com CWD errado ja custou semanas de "bug que
-- nao reproduz" neste projeto. O lancador oficial e o jogar.bat.
-- 0.9.2 (Set/2026): forja por copia, hover bloqueado por modal, trava de fim
--   de run (tela preta), faxina de musica orfa, pacotes renomeados.
-- 0.9.3 (Set/2026): CAMPANHA DE 6 ATOS (era 3 — os biomas, chefes e poses dos
--   atos 4-6 ja existiam e so apareciam no endless), 3 faixas novas, portao
--   de fogo do ato 3 regerado, Baluarte Eterno deixa de ser mudo no reflexo.
Config.VERSION = "0.9.3"

-- Configurações da Interface
Config.UI = {
    BUTTON_WIDTH_RATIO = 0.25,
    BUTTON_HEIGHT_RATIO = 0.08,
    BUTTON_SPACING_RATIO = 0.1,
    CARD_SPACING_RATIO = 0.15,
    CARD_START_X_RATIO = 0.1,
    CARD_Y_RATIO = 0.65, -- Cartas mais abaixo
    CARD_HOVER_OFFSET_RATIO = 0.12,
    CARD_SELECTED_OFFSET_RATIO = 0.1,
    PLAY_BUTTON_WIDTH_RATIO = 0.2,
    PLAY_BUTTON_HEIGHT_RATIO = 0.08,
    PLAY_BUTTON_X_RATIO = 0.5, -- Centralizado
    PLAY_BUTTON_Y_RATIO = 0.8, -- Abaixo das cartas
    BAR_WIDTH_RATIO = 0.25,
    BAR_HEIGHT_RATIO = 0.03,
    JOKER_SLOT_SIZE_RATIO = 0.13,
    JOKER_SLOT_SPACING_RATIO = 0.01,
    TITLE_FONT_RATIO = 0.08,
    SUBTITLE_FONT_RATIO = 0.03,
    INSTRUCTION_FONT_RATIO = 0.025,
    SCORE_FONT_RATIO = 0.04,
    TURN_FONT_RATIO = 0.03,
    JOKER_NAME_FONT_RATIO = 0.015,
}

-- Configurações do Jogo
Config.Game = {
    -- Cartas iniciais (Fase 5: hand maior pra compensar deck pequeno de 2 cartas)
    INITIAL_HAND_SIZE = 5,   -- F1: mão inicial = draw por turno (StS-style)
    CARDS_PER_TURN = 5,      -- F1: draw fixo por turno (mão descarta no fim)
    MAX_JOKER_SLOTS = 3,

    -- Fases: Fase 5 trocou o cap de 10 por estrutura de atos (ver Config.Acts).
    -- VICTORY_PHASES mantido por retrocompatibilidade (usado no modo classic sem run).
    VICTORY_PHASES = 24, -- 3 atos x 8 andares
    HEALTH_RESTORE_INTERVAL = 3,

    -- Fallback de inimigos (modo classic sem run). Run mode usa Config.Acts.
    ENEMY_BASE_HEALTH = 18,
    ENEMY_BASE_DAMAGE = 5,
    ENEMY_HEALTH_SCALING = 15,
    ENEMY_DAMAGE_SCALING = 3,

    -- Jogador: Fase 5 reduziu HP inicial (60 vs 100). Deck pequeno + curva mais
    -- apertada cria pressao pra tomar decisoes boas nas escolhas de nos.
    PLAYER_MAX_HEALTH = 60,
    -- Cap de Bloqueio POR ATO (auditoria Jul/2026): fixo em 30, a bateria de
    -- autoplay mostrou 20-24 turnos NO CAP no ato 3 — todo o scaling de
    -- defesa (Destreza/coringas/Muralha) evaporava, e hits de A3 (>30)
    -- furavam qualquer defesa. 30 no A1 mantem o anti-imunidade original
    -- (F1: 50 > maior hit do A1); +10 por ato devolve teto pras builds
    -- defensivas sem nunca virar imunidade na curva de dano do ato.
    PLAYER_MAX_ARMOR = 30,          -- base (ato 1)
    PLAYER_MAX_ARMOR_PER_ACT = 10,  -- +10 por ato: A2=40, A3+=50
    PLAYER_MAX_MANA = 3,
    PLAYER_HEALTH_RESTORE = 20,

    -- Forja de cartas: 0 = SEM CAP (upgrade infinito — pedido Jul/2026; o
    -- custo crescente da forja paga + 1 forja grátis por fogueira seguram o
    -- balance). Valor > 0 restaura um teto de níveis por carta.
    UPGRADE_LEVEL_CAP = 0,

    -- Pontuação
    BASE_SCORE_PER_PHASE = 100,

    -- Sistema de mensagens
    MAX_MESSAGES = 5,
    MESSAGE_DURATION = 3.0,
}

-- ===== Fase 5: Atos, curvas de dificuldade e endless =====
--
-- Cada ato tem floors (qtd de andares), fórmulas de HP/dano por andar, boss
-- com stats especificos, pesos de raridade na geracao de ofertas, e cura inter-ato.
--
-- As fórmulas recebem `f` = floorInAct (1..floors). Boss e evaluado com f=floors.
-- Scaling e rate de cura documentados em memory/balance_curves.md.

-- Curvas calibradas para deck pequeno (starter=2, cresce ~1 por andar).
-- Meta: floor normal ato 1 cai em 2-3 turnos; boss ato 1 em 6-10 turnos;
-- floor normal ato 3 em 4-5 turnos; boss ato 3 em 8-12 turnos.
Config.Acts = {
    {
        number = 1, name = "Catacumbas", floors = 8,
        enemyHP    = function(f) return 8 + f * 6 end,    -- f=1: 14, f=8: 56
        enemyDmg   = function(f) return 3 + f * 1.2 end,  -- f=1: 4, f=8: 12
        bossHP = 110, bossDmg = 12,
        eliteHPMul = 1.4, eliteDmgMul = 1.25,
        rarityWeights = { common = 70, uncommon = 25, rare = 5,  legendary = 0 },
        interActHeal = 0.30,
    },
    {
        number = 2, name = "Torre de Pedra", floors = 8,
        enemyHP    = function(f) return 60 + f * 10 end,  -- f=1: 70, f=8: 140
        enemyDmg   = function(f) return 9 + f * 1.5 end,  -- f=1: 10, f=8: 21
        bossHP = 220, bossDmg = 18,
        eliteHPMul = 1.6, eliteDmgMul = 1.3,
        rarityWeights = { common = 40, uncommon = 45, rare = 14, legendary = 1 },
        interActHeal = 0.40,
    },
    {
        number = 3, name = "Abismo", floors = 8,
        enemyHP    = function(f) return 150 + f * 15 end, -- f=1: 165, f=8: 270
        enemyDmg   = function(f) return 18 + f * 2.5 end, -- f=1: 20, f=8: 38
        bossHP = 420, bossDmg = 26,
        eliteHPMul = 1.7, eliteDmgMul = 1.4,
        rarityWeights = { common = 15, uncommon = 45, rare = 32, legendary = 8 },
        interActHeal = 0.40,
    },

    -- ========================================================================
    -- ATOS 4-6 (Set/2026) — a campanha ia até o 3 enquanto os biomas, os
    -- chefes, as poses e as emissivas dos outros três já estavam prontos e só
    -- apareciam no endless. Queixa do dono: "pq sao so 3 atos? nos temos
    -- varios boses e varios mapas ja feitos pq parou ai?".
    --
    -- COMO A CURVA FOI ESCOLHIDA (e por que não é só "multiplica por 2"):
    --
    --   DANO acompanha o TETO DE ARMADURA, não uma progressão geométrica.
    --   O teto é `PLAYER_MAX_ARMOR + PLAYER_MAX_ARMOR_PER_ACT*(ato-1)` =
    --   30/40/50/60/70/80. A vida do jogador NÃO escala junto (base 60, só
    --   sobe por upgrade), então dano geométrico mata em um golpe: seguindo o
    --   fator ~1.7 que existe entre os atos 1→3, o ato 6 bateria a ~200 por
    --   turno. O que se preserva é a RELAÇÃO: um turno cheio de defesa
    --   absorve aproximadamente um golpe. Fim de ato = ~77% do teto de
    --   armadura daquele ato, igual ao ato 3 (38 de 50).
    --
    --   VIDA cresce ~1.5x por ato, essa sim geométrica, porque o dano do
    --   jogador é MULTIPLICATIVO (Força + combos + multiplicadores de
    --   coringa compõem). No log do dono um deck maduro de ato 3 já dava 109
    --   num golpe só.
    --
    --   CHEFE mantém a proporção do ato 3: dano do chefe ≈ 0,68x o dano do
    --   inimigo comum do fim do ato (o chefe é parede, não canhão), e vida
    --   ≈ 1,55x a do comum do fim do ato.
    --
    -- Estes números são um PONTO DE PARTIDA defensável, não um veredito de
    -- balanço — o balanço é decisão do dono. `love . autoplay` mede winrate
    -- por classe se for preciso apertar.
    -- ========================================================================
    {
        number = 4, name = "Cidadela Gelada", floors = 8,
        enemyHP    = function(f) return 250 + f * 22 end, -- f=1: 272, f=8: 426
        enemyDmg   = function(f) return 22 + f * 3.0 end, -- f=1: 25, f=8: 46  (teto 60)
        bossHP = 600, bossDmg = 33,   -- Out/2026 kits: chefe mais curto; o perigo vem do kit
        eliteHPMul = 1.75, eliteDmgMul = 1.45,
        rarityWeights = { common = 10, uncommon = 40, rare = 38, legendary = 12 },
        interActHeal = 0.40,
    },
    {
        number = 5, name = "Coracao Putrido", floors = 8,
        enemyHP    = function(f) return 380 + f * 32 end, -- f=1: 412, f=8: 636
        enemyDmg   = function(f) return 27 + f * 3.5 end, -- f=1: 30, f=8: 55  (teto 70)
        bossHP = 880, bossDmg = 38,   -- (regenera: luta longa é dele)
        eliteHPMul = 1.80, eliteDmgMul = 1.50,
        rarityWeights = { common = 5,  uncommon = 35, rare = 44, legendary = 16 },
        interActHeal = 0.40,
    },
    {
        number = 6, name = "Corte do Eclipse", floors = 8,
        enemyHP    = function(f) return 560 + f * 45 end, -- f=1: 605, f=8: 920
        enemyDmg   = function(f) return 32 + f * 4.0 end, -- f=1: 36, f=8: 64  (teto 80)
        bossHP = 1200, bossDmg = 46,  -- era 1430/45: esponja de 16 turnos (auditoria)
        eliteHPMul = 1.85, eliteDmgMul = 1.50,
        rarityWeights = { common = 0,  uncommon = 28, rare = 50, legendary = 22 },
        interActHeal = 0.40,
    },
}

Config.Endless = {
    -- HP e dano crescem exponencial DEPOIS do ultimo ato (Config.TotalActs).
    -- O contador de endless comeca em floorInAct=1 com actNumber=TotalActs+1
    -- (ver RunManager:advanceFloorInAct).
    --
    -- CURVA (Out/2026, memory/endless_and_seals.md): fator = exp(LIN*n + QUAD*n²),
    -- n = andar absoluto do endless. Era 1.18^n pra vida E dano — x3,2 já no
    -- 1º ciclo e x14 no 2º, com o dano acompanhando a vida: o endless acabava
    -- num golpe, não numa escalada. Agora é Balatro: generoso por 2-3 ciclos
    -- e EXPLODE depois (o termo quadrático garante que toda corrida termina).
    -- Vida no fim do ciclo 1..6: x1,5 x3,0 x7 x20 x69 x290.
    -- Dano (cresce mais devagar que a vida — derrota por escalada, não por
    -- golpe único): x1,3 x1,8 x2,7 x4,5 x8 x15.
    -- 1a versao (LIN 0.08/0.045) matou TODO vencedor do piloto ainda no
    -- ciclo 1 (balance_sim BALANCE_ENDLESS=48, guerreiro): o deck que mal
    -- passa o chefe do ato 6 nao aguenta x1,9 no andar 8. Ciclo 1 tem que
    -- ser a volta da vitoria, nao o muro.
    HP_LIN = 0.05, HP_QUAD = 0.0015,
    DMG_LIN = 0.03, DMG_QUAD = 0.0006,
    scalingMultiplier = 1.18, -- LEGADO: so a PONTUACAO ainda usa 1.18^n (ScoreSystem)
    -- Raridades favorecem o alto-nivel mas comum ainda aparece (sem tirar o "floor" de oferta).
    rarityWeights = { common = 10, uncommon = 35, rare = 45, legendary = 10 },
    -- Cura ao abrir cada ciclo de 8 andares (Game:nextPhase), antes de selo/maldição.
    healPercent = 0.30,
}

-- Total de atos (excluindo endless). Usado por RunManager:advanceFloorInAct
-- e por Game:checkVictory — a tela de vitória nasce daqui, então mexer neste
-- número move o fim da campanha inteiro (foi 3 até Set/2026).
Config.TotalActs = 6

-- ===== ECONOMIA: o pagamento por batalha (Set/2026) =====
--
-- POR QUE A VITORIA PASSOU A ESCALAR POR ATO
--
-- A campanha dobrou (3 -> 6 atos, Config.TotalActs) e o pagamento nao foi
-- revisto. Medido com `love . autoplay 16 warrior 901000` (261 batalhas, loja
-- exercitada de verdade — inclusive os servicos):
--
--   • renda de $9,88 por batalha, CONSTANTE do ato 1 ao ato 6;
--       $5 vitoria (50%) + $3 HP cheio (11%) + juros (39%)
--   • os juros batem no teto de $5 em 55% das batalhas — ou seja, sao um
--     salario fixo, nao um premio por poupar: acima de $25 no bolso guardar
--     mais nao rende nada, e o jogador passa dos $25 ainda no ato 1;
--   • ouro medio no bolso: A1 $29 · A2 $42 · A3 $56 · A4 $57 · A5 $39 · A6 $38;
--   • compras por ato: 74 · 62 · 28 · 43 · 10 · 1.
--
-- A renda e LINEAR e os precos sao GEOMETRICOS (forja x1,35; servicos x1,45 a
-- x2,2 por compra na run). Com 3 atos a corrida acabava antes de a conta
-- apertar. Com 6, o poder de compra por batalha no ato 6 e EXATAMENTE o do
-- ato 1 ($10) enquanto a coisa mais barata que ainda nao se comprou custa
-- $25-60: a loja fecha sozinha na metade final da campanha, e os numeros
-- acima mostram isso acontecendo (10 compras no A5, 1 no A6).
--
-- A CORRECAO E NO TERMO LINEAR, que foi o que a campanha mais longa quebrou.
-- A vitoria passa a pagar `BASE + POR_ATO*(ato-1)`: $5 · $7 · $9 · $11 · $13 ·
-- $15. Com ~4,3 batalhas por ato (26 batalhas numa corrida completa, medidas),
-- isso soma ~$129 numa corrida inteira, TODOS na metade de tras — a renda
-- total sai de ~$260 pra ~$390 e passa a acompanhar a escalada dos precos.
--
-- O ato 1 fica BYTE-IDENTICO de proposito: e a parte mais testada do jogo e
-- nao ha evidencia de que esteja errada.
--
-- O QUE DELIBERADAMENTE NAO MUDOU, e por que:
--
--  • O TETO DOS JUROS continua 5. Subi-lo premiaria GUARDAR justamente na
--    metade em que o problema e nao conseguir GASTAR, e realimentaria o ciclo
--    que Config.Offers descreve nos tres freios do Cofre. O numero (55% de
--    saturacao) diz que a mecanica esta morta acima de $25 — mas a cura disso
--    e a relIquia Cofre existir, nao a base subir.
--
--  • O BONUS DE HP CHEIO continua $3 fixo. Ele e colhido em 11% das batalhas
--    pelo guerreiro e em 7-8% pelo mago e pelo ladino — premia quem ja esta
--    ganhando. Escalar por ato ALARGARIA a diferenca entre as classes, entao
--    fica como esta; se virar alavanca um dia, e pra baixo, nao pra cima.
Config.Economy = {
    VICTORY_GOLD_BASE    = 5,  -- pago no ato 1 (inalterado)
    VICTORY_GOLD_PER_ACT = 2,  -- +$2 por ato: A1 $5 ... A6 $15
    FULL_HP_BONUS        = 3,  -- bonus por terminar a batalha sem perder HP

    -- BONUS DE RISCO (Out/2026, auditoria da economia): elite, mini-chefe e
    -- chefe pagavam EXATAMENTE o mesmo que uma luta comum — o mapa prometia
    -- risco e a bolsa nao pagava. Agora pagam uma linha a mais na folha do
    -- cash out, proporcional a vitoria do ato.
    --   elite: +1x a vitoria do ato · chefe do ato: +1x · mini-chefe: nada
    -- O mini-chefe fica de fora DE PROPOSITO: ele e obrigatorio em todo ato,
    -- entao bonus nele e so renda fixa disfarcada. A 1a versao (mini +1x,
    -- chefe +2x) subiu a renda do A1 de $9,8 para $13,6/batalha e o winrate
    -- do guerreiro do piloto de 42% para 83% na mesma bateria — risco tem que
    -- ser ESCOLHA (elite) ou marco (chefe), nao imposto sobre a rota.
    ELITE_BONUS_MULT    = 1,
    MINIBOSS_BONUS_MULT = 0,
    BOSS_BONUS_MULT     = 1,

    -- DADOS DO ESCRIBA (Out/2026): aposta opcional da loja, uma por visita.
    -- Logica e o PORQUE de cada numero em src/systems/ScribeDice.lua.
    -- PAYOUT = retorno total na vitoria; EV = chance x PAYOUT ~ 1,0 (justo):
    -- Baixo/Alto 15/36 x 2,5 = 1,04 · Sete 6/36 x 6 = 1,00.
    -- test_scribe_dice trava o EV entre 0,9 e 1,1 — aposta nao e mina.
    DICE = {
        PAYOUT = { low = 2.5, seven = 6, high = 2.5 },
        STAKES = { 4, 8, 16 },  -- fichas do ato 1
        STAKE_PER_ACT = 0.3,    -- +30% por ato: A6 = 10 / 20 / 40
    },
}

-- Ouro da vitoria no ato `act` (FONTE UNICA — Game:_buildRoundEvalSources
-- paga por aqui e qualquer preview deve ler daqui tambem; duas formulas pro
-- mesmo numero e como a TopBar passou a mentir sobre os juros uma vez).
function Config.Economy.victoryGold(act)
    act = math.max(1, math.floor(tonumber(act) or 1))
    return Config.Economy.VICTORY_GOLD_BASE
        + Config.Economy.VICTORY_GOLD_PER_ACT * (act - 1)
end

-- Bonus de risco do no (elite/mini_boss/boss) no ato `act`. 0 pra luta comum.
function Config.Economy.nodeBonus(nodeType, act)
    local mult = 0
    if nodeType == "elite" then
        mult = Config.Economy.ELITE_BONUS_MULT or 0
    elseif nodeType == "mini_boss" then
        mult = Config.Economy.MINIBOSS_BONUS_MULT or 0
    elseif nodeType == "boss" then
        mult = Config.Economy.BOSS_BONUS_MULT or 0
    end
    return math.floor(mult * Config.Economy.victoryGold(act))
end

-- ===== Ofertas de carta (recompensas + loja): pity e afinidade =====
-- Adaptação do "card blizzard" do Slay the Spire pro nosso modelo de pesos
-- (ver memory/sts_run_economy.md). Estado do pity vive em Rng.meta (serializado
-- com o save; compartilhado entre recompensas e loja). Regras explicadas ao
-- jogador no "?" da tela de recompensas.
Config.Offers = {
    PITY_STEP = 0.35,   -- +35% no peso de rare/legendary por oferta sem rare+
    HARD_PITY = 25,     -- na 25ª oferta seca, rare é GARANTIDA (se possível no pool)

    AFFINITY_PER_TAG   = 0.20, -- +20% de peso por tag da carta que é forte no deck
    AFFINITY_CAP       = 0.60, -- teto do bônus de afinidade
    AFFINITY_MIN_COUNT = 2,    -- tag "forte" = presente em 2+ cartas do deck

    DUPE_PENALTY   = 0.5, -- peso da carta cai pela metade quando você já tem cópias
    DUPE_THRESHOLD = 2,   -- ...a partir desta quantidade de cópias no deck

    -- Forja (upgrade de carta) COMPRADA na loja: custo cresce a cada forja
    -- paga na run. A forja da fogueira continua grátis (o custo é a ESCOLHA:
    -- forjar OU descansar).
    FORGE_COST_BASE = 5,
    FORGE_COST_MULT = 1.35, -- custo = base * mult^forjasPagasNaRun (arredondado)
    FORGE_COST_MAX  = 60,

    -- Ganho por nível de forja (fonte única — RunManager aplica, UI exibe).
    FORGE_ATK_PER_LVL    = 2,
    FORGE_DEF_PER_LVL    = 2,
    FORGE_EFFECT_PER_LVL = 1,

    -- ===== SERVIÇOS da loja (Set/2026) =====
    -- Relíquias que mexem na RUN e não numa batalha: tesoura (remover carta),
    -- prensa (duplicar carta), bancada extra de coringa e o grimório de compra
    -- extra. Cada uma encarece a cada compra NA MESMA RUN, igual à forja —
    -- a loja vende o serviço, não uma assinatura barata pro resto do jogo.
    --
    -- COMO OS NÚMEROS FORAM ESCOLHIDOS (e por que não são chute):
    --   Uma run de 6 atos paga ~$10 por batalha ($5 vitória + $3 HP cheio +
    --   juros até $5) e uma carta comum custa $3.
    --   NÚMERO DE BATALHAS, medido (Set/2026, `love . autoplay 16 warrior`):
    --   17,3 por corrida até a morte (andar ~31); uma corrida COMPLETA até o
    --   andar 48 dá ~26 batalhas. O "~35 batalhas" que estava escrito aqui era
    --   estimativa, nunca medição, e inflava em ~35% o retorno de tudo que
    --   rende POR BATALHA RESTANTE — o Cofre logo abaixo em primeiro lugar.
    --   Com a vitória escalando por ato (Config.Economy), a renda da corrida
    --   inteira sai de ~$260 para ~$390.
    --   • remover/duplicar entram na faixa da forja (base 5) porque competem
    --     com ela pelo mesmo slot e pelo mesmo bolso;
    --   • slot de coringa e compra extra são upgrades PERMANENTES de motor —
    --     ficam na faixa do Cristal de Éter ($25) pra cima e têm TETO DE
    --     COMPRAS por run (`maxPerRun`), senão viram a única coisa que se
    --     compra na run inteira.
    -- Balanço é decisão do dono: mexer aqui move a economia toda.
    --   base      = custo da 1ª compra na run
    --   mult      = multiplicador por compra JÁ FEITA (custo = base*mult^n)
    --   max       = teto do custo
    --   maxPerRun = 0 (sem limite) ou N compras por run
    --   minDeck   = só é ofertada com pelo menos N cartas no deck
    SERVICES = {
        -- 8, 12, 17, 25, 36, 45(teto) — barata na primeira, dolorosa na quinta.
        remove_card    = { base = 8,  mult = 1.45, max = 45, maxPerRun = 0, minDeck = 3 },
        -- 12, 19, 29, 45, 60(teto) — duplicar carta forjada é forte demais
        -- pra custar o mesmo que remover uma ruim.
        duplicate_card = { base = 12, mult = 1.55, max = 60, maxPerRun = 0 },
        -- 20, 35 (era 30, 60 — Out/2026, queixa do dono: "a bancada de
        -- coringa é cara demais"). Medido na bateria: o ouro na porta da loja
        -- no ato 1 é ~$26, então $30 empurrava a PRIMEIRA bancada pro ato 2+
        -- e a segunda ($60) pro ato 4. Com 20/35 a primeira cabe no ato 1 e
        -- a segunda no ato 2-3. O teto de 2 leva a bancada de 3 pra 5 ATIVOS.
        joker_slot     = { base = 20, mult = 1.75, max = 60, maxPerRun = 2 },
        -- 22, 44 (era 25, 55) — +1 carta por turno é motor puro; 2 é o teto.
        card_draw_upgrade   = { base = 22, mult = 2.0,  max = 60, maxPerRun = 2 },
        -- 25, 41, 68, 113, 150(teto) — ver INTEREST_CAP_* logo abaixo.
        -- SEM teto de compras (`maxPerRun = 0`): o pedido foi "aumentar
        -- sempre". Quem segura é o PREÇO, e ele segura de verdade — as cinco
        -- primeiras compras somam $397, que é aproximadamente a renda inteira
        -- de uma corrida.
        interest_cap        = { base = 25, mult = 1.65, max = 150, maxPerRun = 0 },
    },

    -- ===== TETO DE JUROS comprável (Set/2026) =====
    -- Pedido do dono: "hoje o juros tem limite, ter uma forma também de
    -- destravar o limite do juros e aumentar sempre ele".
    --
    -- POR QUE ISTO PRECISA DE MAIS CUIDADO QUE AS OUTRAS RELÍQUIAS
    -- Slot de coringa e compra extra são DEGRAUS: sobem o patamar e param.
    -- Teto de juros realimenta a própria fonte — mais teto, mais ouro
    -- guardado, mais juros, mais teto. Sem freio vira motor infinito.
    --
    -- SÃO TRÊS FREIOS, e nenhum deles é uma trava dura:
    --
    --  1. PREÇO CRESCENTE (×1,65 por compra). O freio principal.
    --
    --  2. OURO PARADO. Juros são `floor(ouro/5)` LIMITADOS pelo teto: pra
    --     realizar teto C é preciso manter 5×C no cofre. Teto 15 exige $75
    --     dormindo no bolso — sete cartas comuns que você NÃO comprou. O
    --     custo real da relíquia não é só o preço: é a liquidez.
    --
    --  3. PISTA QUE ENCURTA. O ganho é +2 por batalha RESTANTE. Comprado no
    --     ato 1 (~23 batalhas pela frente, medido) rende ~$46 por $25;
    --     comprado no ato 5 (~4 batalhas) rende $8 por $68 e é prejuízo grosso.
    --     (Os números antigos aqui — 30 e 10 batalhas — vinham do mesmo
    --     "~35 batalhas" estimado acima.) O item se
    --     desvaloriza sozinho conforme a corrida anda — é decisão de ABERTURA,
    --     não de fechamento, e isso não precisou de regra nenhuma.
    --
    -- De propósito NÃO existe um quarto freio (rendimento decrescente por
    -- compra): os três acima já se compõem, e somar um quarto faria a compra
    -- parecer quebrada em vez de cara.
    --
    -- Com 6 atos (o dobro da campanha antiga) o item vale literalmente o dobro
    -- do que valeria antes — é por isso que a base é $25 e não $10.
    INTEREST_CAP_PER_BUY = 2,   -- quanto o teto sobe por compra
    -- Guarda-corpo, não design: nas contas acima chegar aqui custaria mais de
    -- $1.000 numa corrida que rende ~$400. Existe pra que o número não possa
    -- disparar num modo futuro (endless longo, joker que dá ouro), nunca pra
    -- ser encostado numa corrida normal.
    INTEREST_CAP_MAX = 25,
}

-- Configurações das Cartas
Config.Cards = {
    -- Escalas (alvo: cartas procedurais são 96×144 → base 1.33 ≈ 128×192 na tela,
    -- preservando o mesmo espaço ocupado pelo layout legado de 64×96×2.0).
    BASE_SCALE = 1.333,
    HOVER_SCALE = 1.466,
    
    -- Animações
    SCALE_ANIMATION_SPEED = 10,
    MOVE_RANGE = 8,           -- Aumentado para mais movimento
    TILT_RANGE = 0.15,        -- Aumentado para mais inclinação
    
    -- Efeitos 3D Balatro-style
    PERSPECTIVE_STRENGTH = 0.25,    -- Força do efeito de perspectiva
    DEPTH_OFFSET = 15,              -- Deslocamento vertical para profundidade
    ROTATION_SPEED = 8,             -- Velocidade da rotação
    SHADOW_INTENSITY = 0.8,         -- Intensidade da sombra
    
    -- Sombras dinâmicas
    SHADOW_OFFSET_BASE_X = -20,     -- Sombra base mais para esquerda
    SHADOW_OFFSET_BASE_Y = 30,      -- Sombra base mais para baixo
    SHADOW_STRETCH_X = 8,           -- Estiramento horizontal da sombra
    SHADOW_STRETCH_Y = 8,           -- Estiramento vertical da sombra
    SHADOW_SCALE_BASE = 0.9,        -- Escala base da sombra
    SHADOW_SCALE_VARIATION = 0.15,  -- Variação da escala da sombra
    
    -- Efeitos de profundidade
    DEPTH_TILT_X = 0.12,            -- Inclinação X baseada na profundidade
    DEPTH_TILT_Y = 0.08,            -- Inclinação Y baseada na profundidade
    LIFT_AMOUNT = 25,                -- Quanto a carta "levanta" no hover
    
    -- Borda azul para cartas jogáveis (Slay the Spire style)
    PLAYABLE_BORDER_COLOR = {0.3, 0.6, 0.9, 0.8}, -- Azul semi-transparente
    PLAYABLE_BORDER_THICKNESS = 4,                  -- Espessura da borda
    
    -- Animação da borda
    BORDER_ANIMATION_SPEED = 2.0,                   -- Velocidade da animação
    BORDER_PULSE_RANGE = 0.3,                       -- Variação da opacidade (0.3 = 30%)
    BORDER_INNER_OFFSET = 4,                        -- Borda vem menos para dentro da carta
    
    -- Tamanho dos jokers nos slots ativos
    JOKER_SLOT_SCALE = 0.7,                          -- Jokers são 30% menores nos slots
    
    -- Cores de raridade para bordas
    RARITY_COLORS = {
        common = {0.7, 0.7, 0.7, 0.8},      -- Cinza
        uncommon = {0.2, 0.8, 0.2, 0.8},   -- Verde
        rare = {0.8, 0.2, 0.8, 0.8},       -- Roxo
        legendary = {0.8, 0.6, 0.2, 0.8},  -- Dourado
        basic = {0.5, 0.5, 0.5, 0.8}       -- Cinza escuro
    },
    
    -- Configurações de borda de raridade
    RARITY_BORDER_THICKNESS = 3,
    RARITY_BORDER_PULSE_RANGE = 0.4,
    RARITY_BORDER_ANIMATION_SPEED = 1.5,

    -- ===== Polish (Balatro-like) =====
    CORNER_CUT = 3,              -- stepped cut dos cantos no canvas lógico (96×144)
    HOVER_BOB_AMOUNT = 1.5,      -- ±px vertical da micro-oscilação ao hover
    HOVER_BOB_SPEED = 2.5,       -- freq em rad/s
    SCALE_EASE_K = 12,           -- exp decay pro scale (antes era lerp linear 10*dt)
    VEL_TILT_GAIN = 0.0003,      -- quanto a velocidade X converte em tilt (clamped)
    VEL_TILT_MAX = 0.15,
    VEL_TILT_DAMP = 8,           -- exp decay do tilt quando a carta pára
    DRAG_THRESHOLD_PX = 6,       -- distância que promove mouse-down a drag
    DRAG_SCALE_BOOST = 0.08,     -- +8% scale na carta enquanto arrastada

    -- ===== Ambient tilt (cartas ociosas respiram — Balatro) =====
    -- Só aplica quando NÃO hovered. Senóide defasada por seed aleatório
    -- pra cartas da mão não oscilarem em sync.
    AMBIENT_TILT_SPEED = 1.4,    -- freq em rad/s (devagar, orgânico)
    AMBIENT_TILT_AMOUNT = 0.02,  -- amplitude em radianos (~1.1°, sutil)

    -- ===== Floating / Shadow (Balatro-accurate) =====
    BASE_LIFT = 3,               -- carta flutua sempre ~3px acima da mesa (idle)
    SHADOW_MAX_HORIZ_OFFSET = 20,-- deslocamento máx horizontal da sombra (carta nas bordas)
    SHADOW_BASE_OFFSET_Y = 6,    -- deslocamento vertical base da sombra
    SHADOW_PRESS_SHIFT = 14,     -- deslocamento extra baseado em tilt (press): press direita → sombra esquerda
    SHADOW_ALPHA = 0.50,         -- opacidade da sombra (não preta pura)

    -- ===== Press-hover (shear 3D fake, só usado como fallback se shader falhar) =====
    PRESS_SHEAR_STRENGTH = 0.10, -- intensidade do shear baseado em tilt

    -- ===== Perspective warp (Balatro-accurate via vertex shader) =====
    MESH_COLS = 8,               -- tessellation horizontal
    MESH_ROWS = 12,              -- tessellation vertical
    PRESS_WARP_STRENGTH = 0.25,  -- amplitude do warp (tunável pelo shader)
    HOVER_STRENGTH_EASE_K = 14,  -- ease-out exp pra hoverStrength (0..1)
}

-- Configurações de Áudio
Config.Audio = {
    HOVER_VOLUME = 0.03,
    DECK_START_VOLUME = 0.1,
    CLICK_SELECT_VOLUME = 0.2,

    -- SFX gerados via ElevenLabs (audio/sfx/)
    CARD_PLAY_ATTACK_VOLUME = 0.55,
    CARD_PLAY_DEFENSE_VOLUME = 0.55,
    CARD_DRAW_VOLUME = 0.35,
    CARD_EXHAUST_VOLUME = 0.5,
    COMBO_TRIGGER_VOLUME = 0.65,
    JOKER_ACTIVATE_VOLUME = 0.55,
    ORB_CHANNEL_VOLUME = 0.5,
    ORB_EVOKE_VOLUME = 0.6,
    DEBUFF_APPLIED_VOLUME = 0.5,
    STRENGTH_GAIN_VOLUME = 0.55,
    POISON_TICK_VOLUME = 0.45,
    ENEMY_ATTACK_VOLUME = 0.6,
    -- 0.65 -> 0.48 (Set/2026, dono: "barulho quando monstro morre muito alto").
    -- 0.65 era o TOPO da faixa do projeto (combate vive em 0.5-0.55) e ainda
    -- soma com o jiggleScreen(1.5) que dispara no mesmo frame (Game.lua:1295).
    ENEMY_DEATH_VOLUME = 0.48,
    -- Carta explodindo tem som PROPRIO. Antes tomava emprestado o enemyDeath
    -- ("som de boom disponivel", comentario no Card.lua) -- carta estourando
    -- nao deveria soar como monstro morrendo. Registro por scan: enquanto
    -- audio/sfx/card-explode.mp3 nao existir, cai no enemyDeath e nada quebra.
    CARD_EXPLODE_VOLUME = 0.45,
    BUTTON_CLICK_VOLUME = 0.4,
    MENU_OPEN_VOLUME = 0.45,
    MENU_CLOSE_VOLUME = 0.4,
    MENU_HOVER_VOLUME = 0.15,
    COLLECTION_FLIP_VOLUME = 0.5,
    PURCHASE_CONFIRM_VOLUME = 0.6,
    CARD_DISCOVERED_VOLUME = 0.55,   -- carta inédita na vitrine (DiscoveryMark)
    AMBIENT_VOLUME = 0.09,        -- KNOB ÚNICO do ambiente (clima + lugares): camas ~-32 dB sob o pico da música (dono: "muito alto"; era 1.0 e no grupo sfx)
    PLACE_VOLUME = 0.75,          -- ambiente dos lugares (PlaceAudio): camas×0.42, avulsos×0.32 — abaixo da música
    WEATHER_VOLUME = 0.8,         -- clima do WorldRoad (WeatherAudio): camas×0.55, avulsos×0.40, trovão×0.85
    PURCHASE_DENY_VOLUME = 0.4,
    BATTLE_VICTORY_VOLUME = 0.6,
    GOLD_GAIN_VOLUME = 0.55,
    NODE_SELECT_VOLUME = 0.45,
    REST_COMPLETE_VOLUME = 0.55,
    ACT_COMPLETE_VOLUME = 0.7,
    RUN_VICTORY_VOLUME = 0.75,
    RUN_DEFEAT_VOLUME = 0.65,
}

-- LightEngine v1 (docs/plan/lighting-engine-v1.md) — tuning das fontes de luz
-- do WorldRoad. O motor em si vive em engine/LightEngine.lua; a cor ambiente
-- por bioma vive em src/data/biomes.lua (campo lightAmbient).
Config.Lighting = {
    -- v9: LANTERN/BRAZIER/POOL_MIN_T migraram pro LuminaireEngine
    -- (engine/LuminaireEngine.lua) — luz de prop decorativo agora é
    -- catálogo POR BIOMA com 2-3 tipos cada.
    -- janelas do castelo: micro-luzes POR janela (raio ∝ largura do castelo);
    -- âncoras default {xr, yr} relativas ao sprite — biomes.lua pode
    -- sobrescrever com lightWindows
    WINDOW  = { radiusK = 0.16, color = { 1.00, 0.72, 0.35 }, intensity = 0.55,
                anchors = { { 0.36, 0.52 }, { 0.64, 0.52 }, { 0.50, 0.82 } } },
    -- tímido: vagalume é detalhe, não farol (feedback Jul/2026)
    FIREFLY = { radius = 6, intensity = 0.45 },
    EMBER   = { radius = 6, intensity = 0.45 },
}

-- Configurações de Performance
Config.Performance = {
    -- Cache de recursos
    ENABLE_AUDIO_CACHE = true,
    ENABLE_FONT_CACHE = true,
}

-- Funções utilitárias para cálculos responsivos
Config.Utils = {
    -- Calcula tamanho responsivo com limite máximo
    getResponsiveSize = function(ratio, maxSize, dimension)
        local screenSize = dimension == "width" and love.graphics.getWidth() or love.graphics.getHeight()
        return math.min(maxSize, screenSize * ratio)
    end,
    
    -- Calcula posição centralizada
    getCenteredPosition = function(width, screenWidth)
        return (screenWidth - width) / 2
    end,
    
    -- Calcula posição relativa
    getRelativePosition = function(ratio, screenSize)
        return screenSize * ratio
    end,

    -- Tamanho com que a janela deve NASCER, dado o monitor e a largura atual.
    -- Devolve (w, h) ou nil quando não há motivo pra mexer.
    --
    -- Mora aqui, separada de `love.window`, para poder ser testada: abrir
    -- janela de verdade num teste não é reproduzível (cada máquina tem um
    -- monitor) e `love.window.setMode` repetido dentro de um tool não retorna
    -- (ver memory/ui_layout_invariants.md). A decisão é aritmética; só a
    -- aplicação precisa do módulo window.
    --
    -- 85% e não 100%: a área que o SO dá não desconta barra de tarefas
    -- (Windows) nem menu bar e dock (macOS), então pedir tudo enfia a barra de
    -- título atrás delas.
    tamanhoJanelaInicial = function(desktopW, desktopH, larguraAtual, fracao)
        if not desktopW or not desktopH then return nil end
        if desktopW <= 0 or desktopH <= 0 then return nil end
        local f = fracao or 0.85
        local w = math.floor(desktopW * f)
        local h = math.floor(desktopH * f)
        -- Nunca abaixo do mínimo declarado no conf.lua, senão o setMode
        -- devolve uma janela maior que a pedida e o layout nasce errado.
        if w < 800 or h < 600 then return nil end
        -- Só cresce. Janela que já veio grande fica como está.
        if larguraAtual and larguraAtual >= w then return nil end
        return w, h
    end
}

return Config

