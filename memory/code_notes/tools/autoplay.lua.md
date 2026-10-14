---
name: code_notes/tools/autoplay.lua
description: Comentários com decisão/regra/histórico colhidos de tools/autoplay.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/autoplay.lua`

Origem: `tools/autoplay.lua` em `7dbdb60d` (162 de 237 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-33 (junto a `local M = {}`)

> tools/autoplay.lua
> PILOTO DE IA v5: joga o jogo de verdade, sozinho, pelos MESMOS sistemas do
> jogador (Game:selectCard/playSelectedCards/enemyTurn, RunManager:chooseNode,
> ShopSystem, Events.apply, forja) — e escreve um DIARIO de tudo que decidiu
> e por que, mais metricas de experiencia por run.
>
> love . autoplay [runs] [classe|all]
> ex: love . autoplay 2 all      → 2 runs por classe (6 runs)
> love . autoplay 3 warrior  → 3 runs de guerreiro
>
> Saida: autoplay_report.md no save dir (~/Library/Application Support/LOVE/
> card-game/). O relatorio e o insumo pra analise de game feel: decisoes
> reais vs automaticas, causa das mortes, curva de HP/ouro, uso de cura,
> combos, duracao de batalhas.
>
> v5 (rebalance Jul/2026, plano pilot_changes V5.1-V5.16):
> V5.1  loja com whitelist de upgrades reais + mana_upgrade prioridade maxima
> V5.2  cerebro de orbes (channel juntos, dark segurado, evoke com proposito)
> V5.3  simulador de lethal FIEL ao pipeline do Game (inclui P0.9 max-mult)
> V5.4  dano gratis (poison liq. da armor do DEFEND + pulso) desconta antes
> V5.5  turno em 2 fases: MOTOR (draw/mana sozinhas) → BATCH unico (combos)
> V5.6  gate de cura anti-desperdicio (missing >= 0.6*cura efetiva)
> V5.7  weak como defesa virtual (25% do golpe anunciado)
> V5.8  passo SCALING quando a batalha vai ser longa (>= 4 turnos)
> V5.9  forja por score (copias x ciclos / custo x ganho real x arquetipo)
> V5.10 reroll de loja (ate 2x) quando a vitrine nao vale
> V5.11 bancada de coringas: pontua e ativa o top via Game:setJokerActive
> V5.12 defesa como alocacao de sobra + modo emergencia
> V5.13 politica de caixa (reserva p/ juros; libera perto do boss)
> V5.14 canElite com dano/turno MEDIDO (byAct) em vez de face value
> V5.16 tripwires no diario (foco A3, jokers mult, thorn/turno)
>
> IMPORTANTE: roda com _G.HEADLESS_TOOL (main.lua) — perfil real intocado.

## L37-38 (em `M`, junto a `M.policy = "v6"`)

> Politica de batalha: "v6" (busca, tools/balance_ai.lua) ou "v5" (passos
> heuristicos, mantida pra A/B de qualidade do piloto).

## L40-41 (em `M`, junto a `M.quiet = false`)

> Diario detalhado (uma linha por turno). Desligado pelas baterias grandes
> (tools/balance_sim.lua) — o relatorio delas e agregado.

## L44-69 (em `M`, junto a `M.PILOTS = {`)

> ============================================================
> PILOTOS (Out/2026, pipeline de balanceamento): o mesmo harness joga com
> tres niveis de jogador, e cada nivel e um PERFIL de decisoes (dado, nao
> codigo espalhado). O relatorio compara os tres com as bandas-alvo de
> memory/sts_difficulty_targets.md.
> combat : "naive" (soca o que der, ignora o intent) | "steps" (passos
> heuristicos v5: lethal > cura > emergencia > dano > defesa) |
> "search" (v6: busca sobre os subconjuntos da mao, balance_ai)
> build  : "greedy" (pega sempre uma carta, a mais rara/cara) | "v5"
> (raridade + afinidade + arquetipo; so pula com deck > 18 e
> carta comum — o jogador que "pega sempre algo") | "normal"
> (mesmo score, mas pula quando o score fica abaixo de uma barra
> que sobe `pickBar` por carta acima de 6 — pega ~60-70% das
> ofertas; tira carta na loja a partir de `trimAt`) | "heuristic"
> (AI.wantsCard: entra quem melhora a media do deck, margem
> cresce com o tamanho) | "sim" (v6: joga as proximas lutas com
> e sem a carta — o jogador que SENTE o deck inchar)
> path   : "random" | "heuristic" (vida/ouro/elite compensa)
> shop   : "impulsive" (compra o primeiro que cabe) | "policy" (reserva de
> caixa, servicos, reroll, forja por score)
> rest   : "always_rest" | "policy" (cura abaixo do limiar, senao forja)
> event  : "first" (primeira opcao) | "policy" (valor esperado por chave)
> bench  : coringas na bancada otimizados (true) ou ativados na ordem
> em que chegaram (false)
> Os nomes legados (v5, v6, v6b, v6c) continuam valendo pros A/B antigos.
> ============================================================

## L73-76 (em `naive`, junto a `average = { combat = "steps", build = "normal", path = "heuristic", shop = "policy",`)

> AVERAGE = o jogador NORMAL (Out/2026, pedido do lead): pega ~60-70% das
> cartas (a barra sobe com o deck: `pickBar` por carta acima de 6), usa a
> raridade/afinidade da oferta, tira uma carta na loja a partir de
> `trimAt` cartas, forja na fogueira quando esta de vida (rest=policy).

## L80-81 (em `average`, junto a `average_v5 = { combat = "steps", build = "v5", path = "heuristic", shop = "policy",`)

> O average antigo ("pega sempre algo"; so pula com deck > 18 e carta
> comum) fica como referencia do que o jogo faz com um deck de 18-19.

## L86-87 (em `expert`, junto a `expert_fast = { combat = "search", build = "heuristic", path = "heuristic", shop = "policy",`)

> EXPERT sem a simulacao de deck (deck por heuristica): ~20x mais barato,
> pra baterias grandes e pro sweep de knobs.

## L102-104 (em `M.PILOTS.v6b`, junto a `local function prof()`)

> Perfil ativo: M.policy e um nome de M.PILOTS (ou um perfil inline em
> M.profile). Nome desconhecido AVISA e cai no expert (fallback silencioso e
> proibido).

## L121-122 (em `M.pilotName`, junto a `local function v6Combat() return prof().combat == "search" end`)

> A/B por METADE do cerebro: "v6c" = combate v6 + deck v5; "v6b" = deck v6 +
> combate v5. Sem separar, uma melhora numa metade escondia a piora da outra.

## L134-136 (em `naiveCombat`, junto a `local report = {}`)

> ============================================================
> Diario
> ============================================================

## L139 (em `anomalies`, junto a `local anomalies = {}`)

> invariantes violadas (o "grito" que faltou no bug do escudo)

## L152-154 (em `log`)

> ============================================================
> Helpers de simulacao
> ============================================================

## L156-161 (em `log`, junto a `local function drainPresentation()`)

> FX de APRESENTACAO (texto flutuante, particulas, faixa de combo, cometas de
> orbe, moedas) so esvaziam no update deles, que o love.update/HUD chama todo
> frame. O piloto nao desenha nem chama esses updates: sem esvaziar aqui, cada
> batalha simulada empilhava ~100 mil particulas presas a cartas (e, por elas,
> Games inteiros) e a bateria longa chegava a 9 GB. Nenhuma regra do jogo le
> esses singletons — limpar e invisivel pro resultado.

## L172-175 (em `pump`, junto a `if M.pumpImpl then return M.pumpImpl(game, secs) end`)

> RELOGIO PLUGAVEL (Out/2026): tools/instant_engine.lua troca o avanco por
> quadros por um dreno em saltos (mesma regra, fila ate esvaziar). Quem
> instala e balance_sim/testes; sem pumpImpl o relogio de quadros abaixo
> continua sendo o padrao (e o caminho que o teste de paridade compara).

## L178-180 (em `pump`, junto a `local dt = M.pumpDt or (1 / 30)`)

> TURBO (Out/2026): a bateria pode avancar o relogio em passos maiores
> (M.pumpDt, ver balance_sim BALANCE_TURBO) — a regra nao depende do
> tempo, so a animacao; menos iteracoes = bateria mais rapida.

## L187-189 (em `pump`, junto a `if game.enemy and game.enemy.update then`)

> Enemy.attackCooldown decrementa em update(dt) — sem bombear isso o
> inimigo trava em cooldown eterno e a batalha congela (1a rodada de
> autoplay pegou exatamente esse sintoma).

## L193-194 (em `pump`, junto a `do`)

> Investida do inimigo: o dano e aplicado no APEX via
> EnemyRenderer.update — sem bombear, o hit nunca acontece.

## L202-206 (em `pump`, junto a `function M.stateSignature(game, label, turn, kind, value)`)

> Assinatura do estado de REGRA (nada visual): vida/escudo/mana dos dois
> lados, intent anunciado, status do inimigo, buffs do jogador, mao em ordem,
> ouro e o estado EXATO dos 6 streams do Rng. E o que o teste de paridade
> compara entre relogios — se algo cosmetico contaminasse a regra, aparece
> aqui como divergencia.

## L282-290 (em `getFocus`, junto a `local function jokerMods(game, ctype)`)

> ============================================================
> V5.3: SIMULADOR DE VALOR FIEL — replica computeCardValue do Game na ordem
> EXATA: applyCardEffects (bonus_self/multi_hit, na ordem do card.effects)
> → statBonus (scaling conta o stat em DOBRO) → ComboSystem.applyToCardValue
> (modulo REAL, com o ctx do conjunto) → jokers com a regra P0.9
> largest-multiplier-wins (flats somam TODOS) → edition (foil +5 / holo x1.2
> / poly x1.5) → Red seal x2 → floor. O MESMO simulador serve o lethal e o
> sort de valor/mana — o bot nunca mais superestima com produto em cadeia.
> ============================================================

## L292-293 (em `getFocus`, junto a `local function jokerMods(game, ctype)`)

> Melhor multiplicador + soma dos flats dos jokers ATIVOS (espelho fiel de
> EffectSystem:applyJokerEffects pos-P0.9).

## L348 (em `simulateCardValue`, junto a `for _, e in ipairs(card.effects or {}) do`)

> 1. applyCardEffects (ordem do proprio card.effects, como no EffectSystem)

## L364 (em `simulateCardValue`, junto a `local mult, flat = jokerMods(game, card.type)`)

> 4. jokers: P0.9 largest-multiplier-wins + flats somam

## L376-377 (em `simulateCardValue`, junto a `local function playRank(c)`)

> Ordem de jogada dentro da leva (V5.2: debuff → scaling → channel → resto →
> ataques → evoke; channel SEMPRE antes de evoke).

## L403 (em `evokeDmgOfOrb`, junto a `return 0`)

> ice/holy nao causam dano

## L406-409 (em `evokeDmgOfOrb`, junto a `local function simulateSetDamage(game, set)`)

> Dano TOTAL simulado de um conjunto: ataques (simulador fiel) + magic_damage
> + evokes (fila FIFO simulada, incluindo channels do proprio set e overflow)
> + x1.5 de vulnerable quando o PROPRIO set inclui o applier (debuffs jogam
> primeiro na ordenacao, entao TODO o dano posterior amplifica).

## L461-466 (em `addDmg`, junto a `local function freeDamageThisTurn(game)`)

> V5.4: dano GRATIS que chega neste turno sem jogar carta nenhuma:
> poison liquido = stacks - armor prevista do intent DEFEND congelado
> (veneno e ABSORVIDO pela armor do inimigo em Enemy:onTurnEnd — a armor
> do defend e ganha ANTES do tick; sem o desconto o bot superestimava
> sempre que o inimigo telegrafava DEFEND)
> + pulso passivo dos orbes (orbPassiveTick no fim do turno do jogador).

## L470-471 (em `freeDamageThisTurn`, junto a `local freePoison = poison`)

> DoT ignora a armadura do inimigo (Out/2026, Enemy:_applyDot): o
> bloqueio do intent nao desconta mais o veneno.

## L484-485 (em `freeDamageThisTurn`, junto a `local function healValue(game, card)`)

> Cura efetiva de uma carta (instant_heal x heal_multiplier de jokers, com
> floor — mesma conta do EffectSystem pos-P2.4).

## L501-502 (em `healValue`, junto a `local function healPassesGate(game, card)`)

> V5.6: gate de cura — so joga se missingHP >= 60% da cura efetiva.
> Vale em QUALQUER passo, inclusive sobra.

## L510-511 (em `healPassesGate`, junto a `local function multJokerStats(game)`)

> V5.16(b): quantos jokers multiplicadores ativos + multiplicador efetivo
> (deve ser sempre o MAX — nunca o produto; deteta regressao do P0.9).

## L525-533 (em `multJokerStats`, junto a `local battleStats -- metricas agregadas (setado em M.run)`)

> ============================================================
> POLITICA DE BATALHA v5 (o "cerebro")
> ============================================================
> V5.5: o turno tem DUAS fases —
> FASE MOTOR: cartas de draw/restore_mana jogadas SOZINHAS em loop enquanto
> renderem (a mao cresce / a mana rende), respeitando exhaust natural.
> FASE BATCH: UM conjunto unico com ataques/defesas/debuffs/channels na
> MESMA leva (batch maximiza tagCounts → strike_combo/triple_strike/
> magic_focus/poison_stack/channel_burst).

## L537-539 (em `multJokerStats`, junto a `local runRec = nil`)

> REGISTRO ESTRUTURADO da run (Out/2026): o diario e texto pra gente ler; a
> bateria grande (tools/balance_sim.lua) precisa de DADOS — o que foi
> oferecido, o que entrou no deck e em que andar, onde e contra o que morreu.

## L545-555 (em `recOffer`, junto a `local dotMeter = { declared = 0, effective = 0, absorbedTicks = 0, ticks = 0 }`)

> ============================================================
> MEDIDOR: quanto do VENENO a armadura do inimigo come (Set/2026)
> ============================================================
> `Enemy:_applyDot` faz `eff = max(0, dano - armor)` e CONSOME a armadura: o
> veneno nao ignora Bloqueio como no Slay the Spire, ele e absorvido. Isso e
> citado como suspeito da fraqueza do ladino — entao vira NUMERO, nao palpite.
>
> O gancho e do INSTRUMENTO, nao do jogo: embrulha o metodo em memoria durante
> a bateria e soma declarado x efetivo. `_applyDot` DEVOLVE o valor declarado
> (nao o efetivo), entao a unica forma honesta de medir e olhar a vida antes e
> depois — que e exatamente o que o jogador ve.

## L578-585 (em `Enemy._applyDot`, junto a `local ledger = nil          -- da batalha corrente: { card=, orb=, magic=, dot=, thorn=, other= }`)

> ============================================================
> LIVRO DE DANO POR FONTE (Out/2026, pipeline): quanto do dano no inimigo
> veio da carta (base / Forca / combo / coringa), de orbe, de magia, de
> veneno+queimadura e de espinhos. Nenhuma regra muda: o ledger observa
> Enemy:takeDamage/_applyDot e le o ROTULO do beat em execucao
> (CombatBeats.push) pra saber de onde o golpe veio. Fora de beat (caminho
> sincrono) a fonte e "card".
> ============================================================

## L633-647 (em `CB.push`, junto a `local function chooseMotorCard(game)`)

> Carta de motor pagavel: effect com draw_cards, ou restore_mana que rende
> mais mana do que custa.
>
> Out/2026 — O MOTOR AINDA PODIA COMER A MANA INTEIRA. O teto de 3 levas
> (conserto Set/2026) vale 3 mana — a mana base. Flagrado pelo banco do
> test_balance_pipeline com o deck normal de 5 cartas no elite A1-F4
> (harvest_reaper): a mao JA tinha o deck inteiro, Grito de Comando
> (compra 2, +1 Forca, custo 1) voltava do reembaralho a cada leva, o
> steps gastava 3x1 mana nele por turno, Forca chegou a +24 e o inimigo
> ficou em 35/35 por 9 turnos ate o jogador morrer — o naive mata em 2.
> Duas regras de jogador: (a) nao se compra de um baralho VAZIO (deck +
> descarte sem nada alem da propria carta e um reembaralho em vao);
> (b) a ULTIMA mana nunca vai numa compra pura — compra e meio, e o que
> se compra ainda precisa de mana pra ser jogado. Quem rende mana
> (restore_mana > custo) continua passando.

## L668-669 (em `chooseMotorCard`, junto a `local function bestDamageSet(game, budget, isPicked, perMana)`)

> Conjunto de dano guloso com o simulador fiel (V5.3). perMana=true ordena o
> greedy por ganho/mana (passo VALOR); false por ganho bruto (LETHAL).

## L712-713 (em `inSet`, junto a `local function chooseBatch(game, turnState)`)

> FASE BATCH: monta o conjunto unico do turno. turnState carrega estado
> por-turno (healsUsed). Retorna (picks, why).

## L719-722 (em `chooseBatch`, junto a `local threat = AI.knownThreat(enemy, p)`)

> Dano TOTAL do intent (multi-golpe soma; Vulneravel congelado entra) —
> como o JOGADOR o conhece: com a névoa de intenção (Out/2026) o número
> escondido vira a média do kit (AI.knownThreat). A medição (diag)
> continua lendo o real.

## L747 (em `why`, junto a `local free = freeDamageThisTurn(game)`)

> V5.4: dano gratis DESCONTA do necessario ANTES de escolher cartas.

## L752-756 (em `why`, junto a `local function planDefense(requireEff, why)`)

> plano de defesa (usado por emergencia / sobra / dano-gratis) -----
> V5.12: cobre min(incoming, cap do ato); requireEff = eficiencia minima
> armor/mana (nil = emergencia, cobre a qualquer custo).
> V5.7: weak-applier vale floor(incoming*0.25) de defesa virtual e entra
> no MESMO sort de eficiencia (rank 0 na leva = joga antes dos blocos).

## L803-804 (em `cands`, junto a `if need <= 0 then`)

> V5.4: dano gratis ja mata? NAO gastar mana em ataque — rotear
> tudo pra defesa (ate min(incoming, cap)) + scaling/channel. -----

## L818-819 (em `cands`, junto a `do`)

> 1. LETHAL (V5.2/V5.3): conjunto guloso com simulador fiel,
> incluindo evoke/channel/magic + vulnerable do proprio set. -----

## L830-831 (em `cands`, junto a `do`)

> 2. SCALING (V5.8): batalha longa (>=4 turnos no ritmo atual)?
> Investir ANTES do passo VALOR. Nunca em turno de lethal (ja retornou). -----

## L846-847 (em `cands`, junto a `local nearBossFloor = floorInAct >= 7`)

> 3. CURAR (V5.6): threshold 35% (50% com boss a vista, F7+, e ai
> ate 2 curas no turno). Gate anti-desperdicio em qualquer caso. -----

## L862-863 (em `cands`, junto a `local emergency = incoming >= p.health * 0.25`)

> 4. EMERGENCIA (V5.12): defesa ANTES do dano quando o golpe
> anunciado machuca de verdade. -----

## L868-870 (em `cands`, junto a `local wallBlocked = false`)

> 5. VALOR: resto da mana em dano pelo MESMO simulador (V5.3),
> greedy por ganho/mana. Anti-muro: a armor do inimigo EXPIRA no turno
> dele — socar um muro maior que o output e jogada fora. -----

## L885-886 (em `cands`, junto a `if not emergency then planDefense(5) end`)

> 6. defesa como alocacao de sobra (V5.12, modo normal):
> eficiencia minima 5 armor/mana. -----

## L889-890 (em `cands`, junto a `for _, c in ipairs(hand) do`)

> 7. ORBES (V5.2): channels tem prioridade sobre a sobra e vao
> JUNTOS na mesma leva (3+ channel = combo channel_burst). -----

## L897-899 (em `cands`, junto a `do`)

> Evoke fora de lethal: (a) orbes cheios + channel na mao (overflow ia
> descartar); (b) orbe dark "maduro" ((v+foco)*2 >= alvo). evoke_all so
> com 2+ orbes de dano acumulados (Consumir/Fissao nao se desperdicam).

## L929-931 (em `cands`, junto a `for pass = 1, 2 do`)

> 8. SOBRA: dois passes (nao-ataque primeiro; anti-muro segura os
> ataques). Gates: defesa no cap e morta; cura respeita o gate V5.6 e o
> limite de curas; evoke ja foi decidido acima. -----

## L944 (em `cands`, junto a `skip = true`)

> decisao de evoke e do passo 7 (V5.2)

## L949 (em `cands`, junto a `skip = true`)

> V5.6: gate vale em QUALQUER passo

## L965-966 (em `cands`, junto a `for _, c in ipairs(hand) do`)

> 9. joker na mao (leak arquitetural — o Game roteia pra colecao):
> jogar cedo, valor passivo pro resto da run. -----

## L977-979 (em `cands`, junto a `local function playLeva(game, picks, why, levaNum)`)

> ============================================================
> BATALHA
> ============================================================

## L981-982 (em `cands`, junto a `local function playLeva(game, picks, why, levaNum)`)

> Executa uma leva: loga, ordena pra jogada (debuff→scaling→channel→resto→
> ataque→evoke), seleciona, joga e bombeia ate a animacao liberar.

## L993-995 (em `pickNames`, junto a `if battleStats and battleStats.plays then`)

> JOGADAS (Out/2026, combo-clareza): quantas cartas por leva e quanto do
> valor das cartas (dano/bloqueio) veio de COMBO — a pergunta do dono
> "jogar um milhao de cartas e o melhor?" precisa de numero.

## L1015-1018 (em `pickNames`, junto a `if battleStats.dmgParts then`)

> COMPOSICAO do valor da carta (pipeline): quanto do ataque veio da
> base, dos efeitos proprios, da Forca, do combo, dos coringas, da
> edicao/selo e quanto Fraco/Fragil tiraram. Mesma funcao que a previa
> do jogador usa (DamagePreview.cardValue) — fonte unica da conta.

## L1058-1060 (em `o`, junto a `local function snapshotBattle(game)`)

> Retrato do comeco de UMA batalha (banco do tools/balance_bench.lua): tudo
> que a batalha herda da run — deck com forja/edicao, coringas e quais estao
> ativos, servicos (compra extra), ato/andar/no, vida e mana base.

## L1081-1084 (em `playBattle`, junto a `local jokersPlayed = 0`)

> v3: DETECTOR DE INTEGRIDADE DO DECK — o grito que faltou no bug do
> Sobrevivente (discard_cards deletava a carta em vez de descartar).
> Invariante: mao + deck + descarte + exauridas + jokers jogados = pool
> inicial da batalha. Qualquer vazamento vira ANOMALIA no relatorio.

## L1093 (em `playBattle`, junto a `do`)

> V5.16(b): jokers multiplicadores ativos no inicio da batalha

## L1103-1107 (em `ledger`, junto a `local diag = { atkTurns = 0, inc = 0, armorOnAtk = 0, unblocked = 0, blockedTurns = 0,`)

> DIAGNOSTICO DE COMBATE (Out/2026, pedido do lead): por turno, o que o
> piloto fez contra o intent anunciado — escudo x golpe quando o intent e
> ataque (cobriu? furou quanto?), mana sobrando, carta pagavel nao jogada,
> escudo gasto em turno sem golpe. Vai no battleLog (`diag`) e o
> balance_report/diag.py compara pilotos por ato.

## L1121-1122 (em `diag`, junto a `local shownValue = value`)

> névoa de intenção: o diário mostra o que o jogador viu ("?"); a
> assinatura de paridade abaixo segue com o valor real (é de regra)

## L1128-1130 (em `diag`, junto a `if M.traceSink then`)

> TRACO DE PARIDADE (tools/test_instant_parity.lua): assinatura do
> estado de REGRA no inicio de cada turno. Dois relogios diferentes
> (quadros x instantaneo) tem que produzir a mesma sequencia.

## L1140-1142 (em `diag`, junto a `do`)

> wip/sustain: POÇÃO (Config.Game.POTIONS). Regra de jogador: bebe
> quando a vida está baixa ou quando o golpe anunciado a deixaria
> baixa — naive só abaixo de 30% (quem abriu o jogo esquece a poção).

## L1167-1185 (em `turnState`, junto a `local MOTOR_MAX_LEVAS = 3`)

> ===== FASE MOTOR (V5.5): draw/restore_mana SOZINHAS em loop
> enquanto renderem — a leva seguinte enxerga mao e mana novas.
>
> CONSERTO Set/2026 — O BOT PODIA PASSAR A BATALHA INTEIRA CICLANDO.
> O orcamento de levas era UM SO, compartilhado com a fase BATCH:
> `while levas < 6` no motor e `while levas < 6` no batch. Uma carta
> que se auto-sustenta em mana (Sosia: custa 1, compra 2, devolve 1)
> num deck pequeno volta pra mao a cada reembaralhamento e o guard de
> nao-progresso NAO dispara — porque ela PROGRIDE mesmo: a mao cresce.
> O motor gastava as 6 levas, o batch nunca rodava, e o bot ficava
> parado sem atacar ate morrer. Medido no diario: run de ladino que
> morreu em A1-F5 com 8 turnos seguidos de "leva 1..6: [Sosia] (motor)"
> e "dano causado 0" — score 64 contra ~12.000 das runs vizinhas.
> Como o ladino e a classe com MAIS cartas de ciclo (Sosia, Adrenalina,
> Aposta Calculada, Acrobacias, Elixir Azul, Tempo-bala), o defeito
> penalizava justamente a classe que se estava tentando medir.
>
> A correcao e dar ao motor um orcamento PROPRIO: ciclar e meio, nunca
> fim. O batch fica com o resto garantido.

## L1189-1192 (em `turnState`, junto a `while levas < 4 and game.enemy:isAlive() and game.player:isAlive() do`)

> NAIVE: joga o que cabe na mana, ATAQUE primeiro, na ordem da
> mao; nao olha o intent, nao raciocina orbe, nao guarda mana.
> Replaneja so porque uma compra pode ter aumentado a mao (um
> jogador assim tambem joga a carta que acabou de comprar).

## L1211-1213 (em `turnState`, junto a `while levas < 8 and game.enemy:isAlive() and game.player:isAlive() do`)

> v6 (tools/balance_ai.lua): BUSCA sobre os subconjuntos da mao.
> Motor tem orcamento proprio (mesma licao do conserto Set/2026):
> depois de 3 levas de compra, o plano vai inteiro.

## L1218-1219 (em `turnState`, junto a `local afford = {}`)

> Passar com mana e carta na mao e DECISAO — o diario
> mostra por que (score do vazio x do "joga tudo").

## L1247-1250 (em `afford`, junto a `local function sig()`)

> Guard de nao-progresso por ASSINATURA do estado inteiro: a 1a
> versao comparava so vida/escudo/mao/mana e encerrava o turno
> depois de uma Sangria (custo 0, compra 1: mao e mana iguais)
> — o guerreiro passava turnos inteiros sem atacar.

## L1261-1262 (em `hand`, junto a `if why ~= "motor" and sig() == before then break end`)

> leva de MOTOR pode devolver a mesma mao (reembaralha e recompra as
> mesmas cartas): o orcamento de motor ja a limita, o guard nao.

## L1281-1282 (em `hand`, junto a `while not v6Combat() and not naiveCombat() and levas < 6 and game.enemy:isAlive()`)

> ===== FASE BATCH (V5.5): conjunto unico maximizando combos.
> Cap total de levas 4 → 6 com guard de nao-progresso.

## L1291-1292 (em `hand`, junto a `if c.type == "defense" then`)

> V5.16(c): reflexo de thorn — carta de defesa com o trigger
> reflete POR JOGADA; joker reflete 1x/turno (P2.3).

## L1314 (em `hand`, junto a `if defensePlayedThisTurn or thornCardReflect > 0 then`)

> V5.16(c): estimativa de thorn refletido no turno

## L1332 (em `hand`, junto a `do`)

> V5.16(a): foco maximo visto por ato (tripwire do mago no A3)

## L1341 (em `hand`, junto a `local leftoverPlayable = 0`)

> "Decisao real": sobrou carta pagavel NAO jogada (houve trade-off)

## L1357 (em `hand`, junto a `battlePool = nowPool`)

> re-ancora pra nao spammar todo turno

## L1365 (em `hand`, junto a `local armorBeforeEnemy = game.player.armor or 0`)

> INVARIANTES pre-turno-inimigo (detectores de anomalia):

## L1368-1370 (em `hand`, junto a `local nextIt = game.enemy:getIntent()`)

> Total do intent (multi-golpe soma) e se ele fura o Bloqueio de
> proposito (perfurante) — o detector abaixo nao pode acusar o golpe
> que ATRAVESSA o escudo por design.

## L1378-1379 (em `hand`, junto a `local dmgTakenBeforeEnemy =`)

> usa o contador do ScoreSystem (so dano DO INIMIGO) — HP bruto
> pega custo de sangue de Berserk/Sangria (ignora armor por design)

## L1396-1402 (em `hand`, junto a `local guardP = 0`)

> O PULSO DOS ORBES vira beats na fila (endTurn so ENFILEIRA).
> A cena real so chama enemyTurn com a fila VAZIA e o inimigo
> vivo (GameplayScene: `not isBlocking() and enemy:isAlive()`).
> O piloto chamava na hora: quando o pulso matava o inimigo, o
> golpe ja estava enfileirado e o mago levava dano de um cadaver
> (Out/2026, medido: "inimigo 0 HP, dano sofrido 11"). Drena
> antes, como a cena.

## L1411-1414 (em `hand`, junto a `local guardET = 0`)

> Set/2026: o turno do inimigo virou uma CADEIA de beats
> (telegrafia > golpe > espinhos > veneno > upkeep > compra >
> gatilhos > a vez volta) e nao tem mais duracao fixa. Pumpar um
> numero magico mediria meio turno: esperamos a fila DRENAR.

## L1423-1425 (em `hand`, junto a `local dmgTakenAfterEnemy =`)

> DETECTOR "escudo furado" (o bug que o dono pegou jogando e o
> piloto engoliu): escudo cobria o golpe anunciado (+4 de margem
> pra Furia) mas o HP caiu mesmo assim.

## L1463 (em `hand`, junto a `local cn = game.runManager.currentRun and game.runManager.currentRun.currentNode`)

> chefe separado (kit Out/2026: meta de 7-10 turnos no fim de jogo)

## L1520-1522 (em `parts`, junto a `local function deckIdList(game)`)

> ============================================================
> POS-BATALHA: recompensas + scoring de deck-building
> ============================================================

## L1553-1560 (em `RARITY_SCORE`, junto a `local CLASS_ARCHETYPE = {`)

> Arquetipo por classe (prior de deck-building): o bot compra pra FOCAR,
> nao pra colecionar — combos exigem densidade da mesma tag.
> V5.17 (re-baseline Jul/2026): mago/ladino ganharam afinidade de DEFESA.
> A bateria 15x3 mostrou mago 0/15 morrendo de chip (sofrido 2-16/turno,
> decks sem NENHUMA defesa alem do starter) enquanto o guerreiro (unico
> prior com defend/armor) zerava o dano inimigo — vies de compra do bot,
> nao (so) desbalanceio do jogo. Humano de mago compra Amuleto/Campo de
> Forca; o bot agora tambem.

## L1579-1596 (em `archetypeScore`, junto a `local function normalBar(game, dctx)`)

> Piloto NORMAL (build = "normal"): a carta so entra (recompensa OU loja) se o
> score NORMALIZADO passa de uma barra que sobe com o deck. A afinidade crua
> cresce com o deck (cada copia da tag soma), o que faria a barra nunca
> morder — aqui vale no maximo 3. Escala medida no diario: comum do arquetipo
> 12-14, incomum 16-18, rara 20+, comum fora do arquetipo 2-5. Barra =
> pickBase + pickBar por carta acima de 6 (perfil `average`: 12 + 0,5/carta
> > com 6 cartas entra a comum boa do arquetipo, com 10 so incomum+, com 16
> incomum com afinidade ou rara, com 22 so rara).
>
> v2 (mesma sessao): o score por TAG era o defeito — Conjuracao Dupla (4 tags
> do arquetipo do mago) pontuava 20 e entrou 83x em 90 runs; o expert_full,
> que decide por simulacao, pega cura, basicas baratas e forja 3x mais. O
> normal agora le a carta como um jogador le: VALOR (AI.cardWorth = pontos
> de auditoria da carta + necessidades do deck: defesa abaixo de 30%,
> ataque abaixo de 35%, escalada no A2+) + um empurrao de raridade (humano
> gosta de rara). Barra = media do deck + margem que sobe com o tamanho
> (pickBar por carta acima de 8; pickBase e a folga inicial, negativa =
> aceita carta mediana enquanto o deck e pequeno).

## L1614-1617 (em `normalCardScore`, junto a `if hasHeal(cd) then`)

> SUSTENTO: o diagnostico (s2-diag) mostrou o expert_full perdendo 6,9 de
> vida por luta no A3 contra 18,8 do average com a MESMA cobertura de
> escudo — a diferenca e cura no deck (Gota Curativa 49x, Pocao 33x em 36
> runs). Um jogador normal tambem pega cura quando nao tem nenhuma.

## L1625-1629 (em `normalCardScore`, junto a `local n = math.max(1, dctx.n)`)

> PROPORCAO: o jogador normal mantem ~1/3 de defesa (o deck vencedor do
> expert_full fecha em 50% ataque / 29% defesa / 20% efeito). So pelo
> valor, o deck virava 68% ataque e cobria 23% dos golpes no A3 — e o
> test_balance_pipeline flagrou o steps perdendo mais que o naive com
> esse deck (sem escudo na mao nao ha intent que salve).

## L1637-1642 (em `normalCardScore`, junto a `local function forgeScore(game, cardId, counts)`)

> ============================================================
> V5.9: FORJA POR SCORE — score = (copias x ciclosPorBatalha / max(1,custo))
> x ganhoReal (getForgeGains, fonte unica com a UI) x (1 + arquetipo*0.3),
> com priors por classe e sinal de morte-por-chip (taken/turno alto sem
> nunca bater no cap de armor → dobra o peso de defesa).
> ============================================================

## L1661 (em `forgeScore`, junto a `local classId = game.selectedClass or "warrior"`)

> priors por classe (V5.9)

## L1691-1695 (em `forgeScore`, junto a `local function forgeIndexFor(game, cardId)`)

> Melhor alvo de forja do deck atual (usado por fogueira, loja e picker).
> Indice da copia que a forja VAI pegar: a de MENOR nivel entre as
> forjaveis daquele id. Espelha a escolha de `RunManager:upgradeCard`, e
> existe pra que o detector de "ouro queimado" meca a MESMA copia antes e
> depois (a forja e por copia, nao por id — CLAUDE.md).

## L1724-1730 (em `counts`, junto a `local JOKER_EFFECT_SCORE = {`)

> ============================================================
> V5.11: BANCADA DE CORINGAS — pontua todos os owned e ativa o top via
> Game:setJokerActive. REGRA P0.9: multiplicadores de MESMO tipo nao
> compoem — o SEGUNDO damage_multiplier pontua ~0 (so o maior conta);
> thorn de joker pontua como valor flat/turno (1x/turno via P2.3), nao
> multiplicado por defesas jogadas.
> ============================================================

## L1734 (em `JOKER_EFFECT_SCORE`, junto a `on_defend_damage = 4,`)

> P2.3: 1x/turno — flat, NAO x defesas

## L1776 (em `entries`, junto a `local function grantBest(field)`)

> so o MAIOR multiplicador de cada tipo recebe valor (P0.9)

## L1816-1821 (em `names`, junto a `local function primeShopContext(game, mode)`)

> Injeta o contexto real da run na loja (classe + deck → afinidade/pity e
> oferta de Forja, que exige context.runManager — sem isso o bot via uma
> vitrine diferente da do jogador).
> wip/sustain (Out/2026): a conta e a de ShopSystem.runContext — a MESMA da
> CardRewardScreen. Antes o piloto nao passava o piso de raridade de
> elite/chefe nem os pesos por ato: media uma vitrine diferente da do jogador.

## L1829-1834 (em `primeShopContext`, junto a `local function cardValueScore(game, cardId)`)

> ============================================================
> v4: PICKER HEADLESS — eventos de deck (remover/duplicar/forjar) usam
> _G.openCardPicker (UI). Sem shim, o piloto ganhava a opcao e recebia
> um NO-OP ("o escriba se distrai") — as melhores ferramentas de
> consistencia de deck eram inacessiveis ao bot.
> ============================================================

## L1855-1856 (em `_G.openCardPicker`, junto a `local defCount = 0`)

> guard: defesa pontua baixo em arquetipo ofensivo, mas remover
> a ultima Esquiva do rogue e suicidio — piso de 3 defesas.

## L1864-1866 (em `_G.openCardPicker`, junto a `local dctx = AI.deckContext(game)`)

> v6: as 3 piores pela heuristica viram CANDIDATAS; a
> simulacao escolhe qual tirar (tirar a "pior" no papel as
> vezes tira a unica defesa que segura o chefe).

## L1923 (em `seen`, junto a `local bestId, bestS = bestForgeTarget(game)`)

> V5.9: mesmo score de forja da fogueira/loja

## L1944-1945 (em `doRewards`, junto a `for _, o in ipairs(offers) do`)

> NAIVE: nunca pula; leva a mais rara (desempate: a mais cara). O
> deck incha — e exatamente o erro que se quer medir.

## L1953-1954 (em `doRewards`, junto a `local ids, byId = {}, {}`)

> v6: entra quem MELHORA a media do deck (AI.wantsCard); coringa
> sempre (bancada nao dilui). Pular e uma jogada, nao um fracasso.

## L1964-1966 (em `doRewards`, junto a `local dctx = AI.deckContext(game)`)

> EXPERT_FAST: a heuristica do v6 sem a simulacao — entra quem
> melhora a MEDIA do deck (AI.wantsCard, margem cresce com o tamanho
> do deck). Pular e decisao normal. Coringa sempre entra.

## L1976-1979 (em `doRewards`, junto a `for _, o in ipairs(offers) do`)

> v5 e NORMAL: raridade + afinidade + arquetipo. O NORMAL ainda compara o
> score com uma barra que sobe com o deck (pickBar por carta acima de 6):
> ate 6 cartas entra tudo; com 10, uma comum sem afinidade ja fica;
> com 14 so incomum com afinidade ou rara. Coringa sempre entra.

## L1990-1991 (em `doRewards`, junto a `local dctx = AI.deckContext(game)`)

> NORMAL escolhe pelo VALOR (nao pelo score por tag acima): a melhor
> carta pagavel pelo cardWorth + raridade, e so entra se passa a barra.

## L2030 (em `doRewards`, junto a `local cd = game.deckManager.cardDatabase:getCard(best.id)`)

> V5.11: aquisicao de joker → re-otimiza a bancada

## L2042-2044 (em `doRewards`, junto a `local function chooseNode(game, pending)`)

> ============================================================
> NODES: escolha de caminho + rest/event/shop
> ============================================================

## L2058-2061 (em `chooseNode`, junto a `local dptEstimate`)

> V5.14: elite compensa? usa o dano/turno MEDIDO nas batalhas do ato
> (battleStats.byAct) — face value do deck so como fallback na primeira
> batalha do ato (estimativa cega superestimava decks de motor e
> subestimava scaling/orbes).

## L2084-2087 (em `chooseNode`, junto a `local nearBoss = (run.floorInAct or 1) >= 6`)

> prioridade situacional
> v4 boss-aware: F7=mini_boss e F8=boss — chegar neles meio-morto era a
> causa nº1 de morte medida (10/33 no boss A2-F8). Perto do muro, o
> descanso vale mais que qualquer loja/evento.

## L2103-2104 (em `want`, junto a `if nearBoss and gold >= 30 then`)

> V5.13: chegando no F7 com caixa (>= $30), SHOP passa na frente de
> EVENT — e a ultima chance de converter ouro em poder pro boss.

## L2127-2128 (em `doRest`, junto a `local floorInAct = game.runManager.currentRun.floorInAct or 1`)

> v4 boss-aware: com mini_boss/boss a 1-2 andares, curar vale mais que
> forjar mesmo acima do threshold normal de 60%.

## L2131 (em `doRest`, junto a `if prof().rest == "always_rest" or p.health <= p.maxHealth * (nearBoss and 0.75 or 0.6) then`)

> NAIVE: sempre descansa (nunca forja), mesmo com a vida cheia.

## L2140-2141 (em `doRest`, junto a `local bestId, bestS = bestForgeTarget(game)`)

> V5.9: forja por SCORE (copias x ciclos / custo x ganho real x
> arquetipo) — substitui a heuristica "ataque com mais copias".

## L2154-2166 (em `doRest`, junto a `local function scoreEventEntry(game, entry, isCost)`)

> Pontua UMA entrada de gain/cost declarada pelo evento.
>
> CONSERTO Set/2026 — O PILOTO CRASHAVA EM TODO EVENTO COM CUSTO/GANHO.
> A v4 recebia STRING e fazia `s:lower()`; os eventos passaram a declarar
> TABELAS estruturadas (`{ k = "gold", n = 30, fb = "$30" }`) e a chamada
> morria com "attempt to call method 'lower' (a nil value)". O pcall de
> playRun engolia a run inteira: 3 de 8 corridas da bateria de ladino
> terminaram em CRASH em vez de em morte medida — e o diario nao media
> ganho nenhum de evento nas outras.
>
> A correcao nao e so "aceitar tabela": e parar de LER TEXTO. O `fb` e o
> fallback de exibicao em PT; ler ele faria o bot decidir diferente em
> outro idioma. A chave `k` e o contrato estavel — o bot pontua por ela.

## L2177 (em `scoreEventEntry`, junto a `if isCost and k == "hp" then`)

> ===== custos que nao podemos pagar = veto =====

## L2219-2220 (em `scoreEventEntry`, junto a `anomaly("evento com chave de %s desconhecida: '%s' — o piloto pontuou 0",`)

> Chave DESCONHECIDA grita (fallback silencioso e proibido no projeto):
> evento novo com chave nova passaria a valer 0 e o bot nunca a escolheria.

## L2233-2234 (em `doEvent`, junto a `local bestIdx, bestScore = #ev.options, 0.5  -- neutro levemente > 0: so`)

> v4: pontua CADA opcao pelos gains/costs declarados; "ir embora" = 0.
> Escolhe a de maior valor esperado pro estado atual (HP/ouro/deck).

## L2237-2238 (em `doEvent`, junto a `bestIdx = #ev.options`)

> NAIVE: a primeira opcao que da pra pagar (custo em ouro/vida que
> nao mata); senao vai embora.

## L2267-2269 (em `doEvent`, junto a `local REAL_UPGRADES = {`)

> ============================================================
> LOJA v5 (V5.1 whitelist / V5.9 forja / V5.10 reroll / V5.13 caixa)
> ============================================================

## L2271-2272 (em `doEvent`, junto a `local REAL_UPGRADES = {`)

> V5.1: upgrades que aplicam efeito REAL. damage/defense/card_draw sao
> toast-only (P3.2) — comprar e queimar ouro; o bot nao compra.

## L2279-2281 (em `REAL_UPGRADES`, junto a `local SERVICE_EFFECTS = {`)

> Servicos SEM picker (mexem no ledger da run, nao no deck). A tesoura e a
> prensa ficam de fora de proposito: elas tem politica propria mais abaixo,
> porque so fazem sentido em funcao do TAMANHO do deck.

## L2288-2302 (em `SERVICE_EFFECTS`, junto a `local function applyUpgradeOffer(game, o)`)

> V5.1: o harness APLICA o efeito do upgrade (a UI real faz isso na
> CardRewardScreen) + detector "ouro queimado": upgrade comprado que nao
> altera estado observavel = anomalia.
> Aplica um upgrade/servico comprado, ESPELHANDO CardRewardScreen:applyUpgrade
> (a tela real). Set/2026: antes daqui so saiam mana e vida maxima — os cinco
> SERVICOS da loja (tesoura, prensa, bancada de coringa, grimorio, cofre) nao
> tinham caminho nenhum no piloto, e por isso a metade cara da loja NUNCA era
> comprada numa bateria inteira. Qualquer conclusao de economia tirada dali
> media o bot, nao a economia.
>
> O detector de "ouro queimado" tambem estava errado para servicos: ele
> perguntava se mana OU vida maxima mudou, e nenhum servico mexe nesses dois.
> Ligar os servicos sem consertar o detector encheria o relatorio de alarme
> falso — que e pior do que nao ter detector. Agora cada efeito declara QUAL
> e o seu observavel.

## L2345-2354 (em `increase_draw`, junto a `if efeito == "forge_card" then`)

> Servicos de PICKER: quem muda o deck e o _G.openCardPicker headless
> (installHeadlessPicker), igual a tela real.
>
> O LEDGER VEM ANTES DO PICKER, e isso nao e detalhe: e ele que faz o
> preco da PROXIMA compra subir (8, 12, 17, 25, 36, 45 na tesoura).
> Sem registrar, o servico fica eternamente no preco base — a primeira
> bateria com servicos ligados comprou a tesoura 40 vezes e TODAS as
> 40 sairam por $8, o que faria a economia parecer barata por um
> defeito do medidor. CardRewardScreen:_openDeckService registra na
> mesma ordem.

## L2383-2384 (em `doShop`, junto a `if runRec and runRec.eco then`)

> Livro-caixa: ouro na entrada + se a bancada de coringa estava na
> vitrine e cabia no bolso (a pergunta do dono: "da pra alcancar?").

## L2395-2397 (em `visit`, junto a `local reserve = (floorInAct >= 6) and 0 or math.min(50, 15 * act)`)

> V5.13: politica de caixa — reserva alvo min(50, 15*ato) rendendo
> juros; a partir do F6 a reserva e liberada (boss a vista: ouro parado
> e poder desperdicado).

## L2416-2417 (em `scoreCardOffer`, junto a `if prof().build == "normal" then`)

> NORMAL: a mesma conta da recompensa vale na loja (coringa passa);
> >= 6 = compra (limiar do laco de compra abaixo), ordenado pelo valor.

## L2433-2434 (em `scoreCardOffer`, junto a `local function tryManaUpgrade()`)

> V5.1: mana_upgrade tem prioridade MAXIMA (acima de qualquer carta)
> quando gold >= 25 — e o unico ganho de teto permanente da loja.

## L2454-2455 (em `tryManaUpgrade`, junto a `for _, o in ipairs(game.shopSystem:getCurrentOffers()) do`)

> NAIVE: compra na ORDEM DA VITRINE enquanto o ouro der (ate 3 itens),
> sem reserva, sem reroll, sem perguntar se o servico tem uso agora.

## L2481 (em `tryManaUpgrade`, junto a `local rerolls = 0`)

> V5.10: reroll ate 2x se nenhuma CARTA com score >= 6 e sobra caixa.

## L2506-2518 (em `tryManaUpgrade`, junto a `local rm = game.runManager`)

> ===== SERVICOS DA LOJA (Set/2026) =====
> Tesoura, prensa, bancada de coringa, grimorio e cofre: as compras CARAS
> e permanentes. O piloto nao tinha caminho nenhum pra elas, entao a
> metade cara da vitrine ficava intocada a corrida inteira e a economia
> media do relatorio era a de um jogador que so compra carta de $3.
>
> A politica abaixo nao tenta ser otima — tenta ser um jogador RAZOAVEL,
> que e o que um instrumento de balanco precisa representar:
> • so compra o que tem uso AGORA (bancada de coringa so com coringa
> parado; tesoura so com deck inchado);
> • o cofre e decisao de ABERTURA — ele rende por batalha RESTANTE, e
> comprado tarde e prejuizo (o proprio Config.Offers explica isso);
> • nunca fura a reserva de caixa nem o teto de 3 compras por loja.

## L2527 (em `serviceWorth`, junto a `local possuidos = #((run.jokers) or {})`)

> So vale com coringa PARADO na bancada — senao e slot vazio.

## L2533-2535 (em `serviceWorth`, junto a `local eco = game.economySystem`)

> Rende +N por batalha restante, e so se realiza mantendo
> 5x(teto) parado no bolso. Decisao de abertura: A1-A2 apenas, e
> so com caixa que aguente a imobilizacao.

## L2563-2564 (em `serviceWorth`, junto a `for _, o in ipairs(offers) do`)

> TESOURA (remove_card): deck inchado e o gatilho, igual ao guard do
> picker headless (que se recusa a remover abaixo de 8 cartas).

## L2580 (em `serviceWorth`, junto a `for _, o in ipairs(offers) do`)

> Forja paga (score V5.9 decide o alvo; so compra se ha alvo que rende)

## L2590-2605 (em `serviceWorth`, junto a `local idx = forgeIndexFor(game, target)`)

> O DETECTOR PRECISA OLHAR A MESMA COPIA ANTES E DEPOIS.
>
> A versao anterior comparava `getUpgrades(id)` com o retorno
> de `upgradeCard(id)` — e essas duas funcoes respondem a
> perguntas DIFERENTES: a primeira devolve o MAIOR nivel entre
> as copias daquela carta, a segunda forja a de MENOR nivel e
> devolve o nivel DELA. Com duas copias (uma ja forjada), o
> "antes" era 1 e o "depois" era 1, e o detector gritava "ouro
> queimado" numa forja que tinha funcionado. Era ALARME FALSO,
> e ele apareceu 3x na bateria de 6 corridas.
>
> Isso importa alem do ruido: este harness e o que mede
> BALANCO. Tripwire que mente faz anomalia de verdade se
> perder no meio do barulho — e a forja e POR COPIA desde
> Set/2026 (CLAUDE.md), entao perguntar por ID e o erro de
> origem. Resolve-se o INDICE e usam-se as APIs `...At`.

## L2633-2635 (em `cardOffers`, junto a `for _ = 1, 2 do`)

> v6: a SIMULACAO decide (mesma pergunta da recompensa: o deck sofre
> menos com a carta?). Ate 2 cartas por visita, a melhor primeiro;
> so compra o que melhora >= 1 HP-equivalente nas lutas a frente.

## L2663-2666 (em `cardOffers`, junto a `local cardsThisVisit, cardCap = 0, prof().shopCards or 99`)

> NORMAL: no maximo `shopCards` cartas (nao coringa) por visita — o
> jogador normal nao leva a vitrine inteira (ate 5 cartas numa loja do
> A1 na bateria s2-avg-n3: era a loja, mais que a recompensa, que
> inchava o deck).

## L2685 (em `cardOffers`, junto a `for _, o in ipairs(offers) do`)

> V5.1: increase_max_health como filler barato (sobrou caixa e vitrine)

## L2700 (em `cardOffers`, junto a `if boughtJoker then`)

> V5.11: aquisicao de joker → re-otimiza a bancada

## L2711-2713 (em `cardOffers`, junto a `local function playRun(classId, runIdx, maxEndlessFloors, seed, opts)`)

> ============================================================
> UMA RUN COMPLETA
> ============================================================

## L2718-2719 (em `playRun`, junto a `EventManager.clear()`)

> Run nova num processo que ja jogou outras (bateria): nada da run
> anterior — eventos pendentes, FX — pode atravessar pra esta.

## L2726-2732 (em `playRun`, junto a `if seed then`)

> SEED FIXA (Set/2026) — sem isto, medir "antes x depois" de uma mudanca
> de balanco compara duas amostras DIFERENTES e o ruido engole o efeito.
> Duas fontes precisam ser fixadas, nao uma:
> • Rng (streams card/shop/map/event/enemy) → ofertas, mapa, eventos;
> • love.math → o EMBARALHAMENTO do deck (Game:shuffleDeck), que decide
> a mao de cada turno e pesa tanto quanto a oferta.
> Fixar so o Rng deixaria metade da run solta.

## L2738-2740 (em `playRun`, junto a `math.randomseed(seed)`)

> TERCEIRA fonte (Out/2026): o intent do inimigo (Enemy:rollIntent)
> sorteia com math.random do Lua. Sem fixar, duas baterias com a
> mesma seed lutavam contra inimigos que golpeavam diferente.

## L2750-2752 (em `deckByBattle`, junto a `M._pilotRng = love.math.newRandomGenerator(seed or 1)`)

> RNG PROPRIO do piloto (escolhas "aleatorias" do NAIVE): nunca o
> love.math global — cosmeticos consomem dele por quadro e o relogio
> instantaneo e o de quadros divergiriam. Seedado pela seed da run.

## L2785-2787 (em `game.addJokerToRun`, junto a `runRec.eco = { earned = {}, spent = {}, byType = {}, shops = {}, slot = {} }`)

> LIVRO-CAIXA (Out/2026, auditoria da economia): ouro ganho/gasto POR ATO
> e por categoria, mais as visitas a loja. Sem isto o relatorio so tinha
> o ouro FINAL — e "a loja e cara?" e pergunta sobre o meio da corrida.

## L2817-2818 (em `eco.spendGold`, junto a `installHeadlessPicker(game)`)

> v4: picker headless — sem isso os eventos de deck (remover/duplicar/
> forjar a escolha) eram NO-OP no piloto (dependem de UI).

## L2826 (em `byAct`, junto a `focusMaxByAct = {},   -- [act] = foco maximo visto (mago)`)

> V5.16: tripwires

## L2833-2834 (em `plays`, junto a `dmg = {}, dmgParts = {}, battleLog = {},`)

> pipeline (Out/2026): dano por fonte, composicao do valor da carta,
> uma linha por batalha

## L2856 (em `dmg`, junto a `if (run.actNumber or 1) ~= lastAct then`)

> V5.11: inicio de ato → re-otimiza a bancada de coringas

## L2875-2876 (em `runRec.death`, junto a `if (maxEndlessFloors or 0) > 0 and game.enterEndless and game:enterEndless() then`)

> Endless medido (BALANCE_ENDLESS > 0): segue pelo mesmo botão da
> tela de vitória. Vitória já contada; a run continua.

## L2890-2891 (em `runRec.death`, junto a `if opts.maxBattles and floors >= opts.maxBattles then`)

> Corte por batalhas (testes de paridade/determinismo: run curta e
> reproduzivel sem jogar a campanha inteira).

## L2898-2899 (em `runRec.death`, junto a `if game._buildRoundEvalSources then`)

> Cash-out do RoundEval (headless): o pagamento da batalha vive na
> tela de RoundEval — sem simular o resgate o bot morre de fome.

## L2925-2926 (em `names`, junto a `do`)

> Endless: ciclo novo abre escolha de maldição (a tela do jogo
> obriga). Piloto pega a de MENOR bônus de pontos = a mais branda.

## L3034 (em `runRec.death`, junto a `log("- Tripwires v5:")`)

> V5.16: TRIPWIRES do rebalance v2 (alimentam a secao Validacao do plano)

## L3062-3064 (em `names`)

> ============================================================
> ENTRY
> ============================================================

## L3066-3069 (em `names`, junto a `function M.run(runsArg, classArg, seedArg)`)

> love . autoplay [runs] [classe|all] [seedBase]
> Com seedBase, a run i da classe C usa seed = seedBase + i (mesma seed por
> indice em qualquer execucao) — e o unico jeito de um A/B de balanco medir a
> MUDANCA em vez do sorteio.

## L3081-3082 (em `classes`, junto a `if os.getenv("AUTOPLAY_PILOT") and os.getenv("AUTOPLAY_PILOT") ~= "" then`)

> AUTOPLAY_PILOT=<perfil>: diario de UM piloto especifico (o padrao e o
> expert). E o jeito de ler o que o average/naive decidiu em cada no.

## L3143-3145 (em `outcomes`, junto a `function M.playRunRecord(classId, runIdx, seed, opts)`)

> ===== Superficie da bateria (tools/balance_sim.lua) =====
> Roda UMA run e devolve o registro estruturado. pcall por fora fica com quem
> chama (a bateria conta CRASH como resultado proprio).

## L3158-3160 (em `M.getReport`, junto a `function M.replayBattle(snap, seed)`)

> Rejoga UMA batalha a partir do retrato, com a politica atual, vida CHEIA
> (mede so o combate: HP perdido e turnos). Mesma seed = mesmo embaralhamento
> e mesmos intents pra qualquer politica.

## L3195-3211 (em `M.replayBattle`, junto a `M.SIM_PER_FIGHT = 1`)

> ============================================================
> v6: DECK BUILDING POR SIMULACAO
> ============================================================
> Heuristica de "quanto vale uma carta" erra justamente onde o balanceamento
> precisa acertar (sinergia, escala, o que falta no deck). A pergunta certa e
> empirica: COM esta carta, o deck sofre menos nas proximas lutas? Cada opcao
> (incluindo PULAR) e jogada contra o CHEFE do ato e uma luta comum logo a
> frente, com as mesmas seeds pra todas as opcoes (numeros aleatorios comuns:
> a diferenca medida e a carta, nao o sorteio).
>
> `mutate(snap)` altera o retrato (adiciona/remove carta). Devolve a perda
> media em HP-equivalente: HP perdido + derrota pesada pelo quanto faltou.
> Replays por luta de referencia. O v6 original jogava 2 (x2 lutas = 4
> replays por candidata); o perfil `expert` joga 1 e so leva a simulacao as
> `SIM_CANDIDATES` melhores candidatas da heuristica (+ pular). Medido
> (Out/2026, warrior seed 720001): 892 → ~300 replays por run, mesma
> vitoria. `expert_full` restaura o v6 inteiro pra conferir.

## L3215-3216 (em `simPerFight`, junto a `function M.simCandidates(game, ids)`)

> Pre-filtro das candidatas que vao a simulacao: coringas sempre entram
> (bancada nao dilui), e as demais na ordem do valor heuristico (AI.cardWorth).

## L3251-3255 (em `fights`, junto a `local savedQueues = EventManager.queues`)

> FILAS ISOLADAS: cada replay monta um Game descartavel que deixa eventos
> pendentes (materializar carta, fim de dissolve — "after" BLOQUEANTES) na
> fila GLOBAL. Sem isolar, milhares deles se acumulavam, serializados, e
> ainda rodavam por cima da run real. Cada replay ganha filas novas; as da
> run voltam intactas no fim.

## L3310-3314 (em `M.pickBySim`, junto a `M._playBattle = playBattle`)

> ===== Superficie de teste =====
> `tools/test_autoplay_pilot.lua` conduz UMA batalha pelo cerebro real do
> piloto. Sem isto a unica forma de testar a politica de turno seria rodar uma
> corrida inteira — caro demais pra suite e vago demais pra apontar defeito.
> `battleStats` normalmente e montado por playRun; o teste precisa monta-lo.

