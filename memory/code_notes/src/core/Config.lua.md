---
name: code_notes/src/core/Config.lua
description: Comentários com decisão/regra/histórico colhidos de src/core/Config.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/core/Config.lua`

Origem: `src/core/Config.lua` em `7dbdb60d` (59 de 167 blocos de comentário tinham marcador de decisão/regra/histórico).

## L6-16 (em `Config`, junto a `Config.VERSION = "0.9.3"`)

> Versão do jogo (menu/splash mostram no rodapé).
> Sobe a cada leva de correcoes que o dono vai TESTAR. O menu imprime este
> numero no rodape (Menu:_drawVersionFooter), e e assim que se responde
> "estou rodando a build certa?" sem adivinhar — ver a memoria
> user-runs-stale-copy: `love .` com CWD errado ja custou semanas de "bug que
> nao reproduz" neste projeto. O lancador oficial e o jogar.bat.
> 0.9.2 (Set/2026): forja por copia, hover bloqueado por modal, trava de fim
> de run (tela preta), faxina de musica orfa, pacotes renomeados.
> 0.9.3 (Set/2026): CAMPANHA DE 6 ATOS (era 3 — os biomas, chefes e poses dos
> atos 4-6 ja existiam e so apareciam no endless), 3 faixas novas, portao
> de fogo do ato 3 regerado, Baluarte Eterno deixa de ser mudo no reflexo.

## L48 (em `Config.Game`, junto a `INITIAL_HAND_SIZE = 5,`)

> F1: mão inicial = draw por turno (StS-style)

## L52-53 (em `Config.Game`, junto a `VICTORY_PHASES = 24, -- so o modo classico (sem run); a campanha usa Config.TotalActs x 8 andares`)

> Fases: Fase 5 trocou o cap de 10 por estrutura de atos (ver Config.Acts).
> VICTORY_PHASES mantido por retrocompatibilidade (usado no modo classic sem run).

## L63-76 (em `Config.Game`, junto a `ENEMY_POWER = { damage = 0.75, health = 0.8 },`)

> FORÇA DO INIMIGO na run (Out/2026, combos simples): as 13 regras de
> combo por tag davam ~40% do dano e ~50% do Bloqueio das cartas, e a
> curva de inimigos foi calibrada COM elas. Trocadas por Saraivada/
> Muralha/Par (pequenas e legíveis), o piloto caiu de 55% para 0-5% com o
> guerreiro; compensar do lado do jogador (+60% de Bloqueio, +20% de
> ataque, combos 2x) não voltou. Escalar o inimigo voltou: dano x0,8 e
> vida x0,85 em TODA a run (endless incluso, a curva continua contínua).
> Ponto único: ActSystem.getEnemyStats.
> Out/2026 (Stage 2, sweep contra as bandas do StS — memory/
> balance_curves.md): 0,8/0,85 -> 0,75/0,8. Com 0,8/0,85 o melhor piloto
> (expert_full) estava na banda (53/57/43) mas o A3 era um muro pra todo
> mundo abaixo dele (elites do A3: 47 das 270 mortes dos pilotos
> rapidos). Com 0,75/0,8 + ato 3 x0,9: expert_full 57/53/53, mortes
> concentradas no A5 (Colosso), lutas tardias 7-9 turnos.

## L78-82 (em `ENEMY_POWER`, junto a `ENEMY_POWER_BY_ACT = { [3] = { damage = 0.9, health = 0.9 } },`)

> Curva POR ATO em cima da global (compõe e arredonda UMA vez; endless
> herda o último ato). Lida por ActSystem.getEnemyStats; knob
> BALANCE_ENEMY_POWER_ACT do sweep. Ato 3 ("Abismo") era o degrau mais
> duro da run: vida base 150+15f (x2 sobre o fim do A2) com elite x1,7 —
> 280 de vida no 1º andar do ato, mais que o chefe do A2.

## L85-86 (em `ENEMY_POWER_BY_ACT`, junto a `PLAYER_MAX_HEALTH = 60,`)

> Jogador: Fase 5 reduziu HP inicial (60 vs 100). Deck pequeno + curva mais
> apertada cria pressao pra tomar decisoes boas nas escolhas de nos.

## L88-93 (em `ENEMY_POWER_BY_ACT`, junto a `PLAYER_MAX_ARMOR = 30,          -- base (ato 1)`)

> Cap de Bloqueio POR ATO (auditoria Jul/2026): fixo em 30, a bateria de
> autoplay mostrou 20-24 turnos NO CAP no ato 3 — todo o scaling de
> defesa (Destreza/coringas/Muralha) evaporava, e hits de A3 (>30)
> furavam qualquer defesa. 30 no A1 mantem o anti-imunidade original
> (F1: 50 > maior hit do A1); +10 por ato devolve teto pras builds
> defensivas sem nunca virar imunidade na curva de dano do ato.

## L99-104 (em `ENEMY_POWER_BY_ACT`, junto a `REST_HEAL_PCT = 0.30,    -- cura da fogueira (fracao da vida maxima; StS = 30%)`)

> ===== Propostas de SUSTENTO medidas pela bateria (Out/2026). Estas tres
> NAO foram adotadas (descanso 40% e elite em rampa nao moveram nada; a
> pocao so ajudou o expert) e ficam atras de flags cujo default e o jogo
> atual. A bateria liga por env (BALANCE_REST_HEAL / BALANCE_POTIONS /
> BALANCE_ELITE_RAMP / BALANCE_SUSTAIN em tools/balance_sim.lua). A que
> FOI adotada e Config.Offers.SUSTAIN_*. Numeros em memory/balance_curves.md.

## L105 (em `ENEMY_POWER_BY_ACT`, junto a `REST_HEAL_PCT = 0.30,`)

> cura da fogueira (fracao da vida maxima; StS = 30%)

## L112-114 (em `ENEMY_POWER_BY_ACT`, junto a `UPGRADE_LEVEL_CAP = 0,`)

> Forja de cartas: 0 = SEM CAP (upgrade infinito — pedido Jul/2026; o
> custo crescente da forja paga + 1 forja grátis por fogueira seguram o
> balance). Valor > 0 restaura um teto de níveis por carta.

## L125-131 (em `ENEMY_POWER_BY_ACT`)

> ===== Fase 5: Atos, curvas de dificuldade e endless =====
>
> Cada ato tem floors (qtd de andares), fórmulas de HP/dano por andar, boss
> com stats especificos, pesos de raridade na geracao de ofertas, e cura inter-ato.
>
> As fórmulas recebem `f` = floorInAct (1..floors). Boss e evaluado com f=floors.
> Scaling e rate de cura documentados em memory/balance_curves.md.

## L133-135 (em `ENEMY_POWER_BY_ACT`, junto a `Config.Acts = {`)

> Curvas calibradas para deck pequeno (starter=2, cresce ~1 por andar).
> Meta: floor normal ato 1 cai em 2-3 turnos; boss ato 1 em 6-10 turnos;
> floor normal ato 3 em 4-5 turnos; boss ato 3 em 8-12 turnos.

## L165-194 (em `rarityWeights`, junto a `{`)

> ========================================================================
> ATOS 4-6 (Set/2026) — a campanha ia até o 3 enquanto os biomas, os
> chefes, as poses e as emissivas dos outros três já estavam prontos e só
> apareciam no endless. Queixa do dono: "pq sao so 3 atos? nos temos
> varios boses e varios mapas ja feitos pq parou ai?".
>
> COMO A CURVA FOI ESCOLHIDA (e por que não é só "multiplica por 2"):
>
> DANO acompanha o TETO DE ARMADURA, não uma progressão geométrica.
> O teto é `PLAYER_MAX_ARMOR + PLAYER_MAX_ARMOR_PER_ACT*(ato-1)` =
> 30/40/50/60/70/80. A vida do jogador NÃO escala junto (base 60, só
> sobe por upgrade), então dano geométrico mata em um golpe: seguindo o
> fator ~1.7 que existe entre os atos 1→3, o ato 6 bateria a ~200 por
> turno. O que se preserva é a RELAÇÃO: um turno cheio de defesa
> absorve aproximadamente um golpe. Fim de ato = ~77% do teto de
> armadura daquele ato, igual ao ato 3 (38 de 50).
>
> VIDA cresce ~1.5x por ato, essa sim geométrica, porque o dano do
> jogador é MULTIPLICATIVO (Força + combos + multiplicadores de
> coringa compõem). No log do dono um deck maduro de ato 3 já dava 109
> num golpe só.
>
> CHEFE mantém a proporção do ato 3: dano do chefe ≈ 0,68x o dano do
> inimigo comum do fim do ato (o chefe é parede, não canhão), e vida
> ≈ 1,55x a do comum do fim do ato.
>
> Estes números são um PONTO DE PARTIDA defensável, não um veredito de
> balanço — o balanço é decisão do dono. `love . autoplay` mede winrate
> por classe se for preciso apertar.
> ========================================================================

## L198 (em `enemyDmg`, junto a `enemyDmg   = function(f) return 22 + f * 3.0 end,`)

> f=1: 25, f=8: 46  (teto 60)

## L199 (em `enemyDmg`, junto a `bossHP = 600, bossDmg = 33,`)

> Out/2026 kits: chefe mais curto; o perigo vem do kit

## L207 (em `enemyDmg`, junto a `enemyDmg   = function(f) return 27 + f * 3.5 end,`)

> f=1: 30, f=8: 55  (teto 70)

## L216 (em `enemyDmg`, junto a `enemyDmg   = function(f) return 32 + f * 4.0 end,`)

> f=1: 36, f=8: 64  (teto 80)

## L217 (em `enemyDmg`, junto a `bossHP = 1200, bossDmg = 46,`)

> era 1430/45: esponja de 16 turnos (auditoria)

## L225-240 (em `Config.Endless`, junto a `HP_LIN = 0.05, HP_QUAD = 0.0015,`)

> HP e dano crescem exponencial DEPOIS do ultimo ato (Config.TotalActs).
> O contador de endless comeca em floorInAct=1 com actNumber=TotalActs+1
> (ver RunManager:advanceFloorInAct).
>
> CURVA (Out/2026, memory/endless_and_seals.md): fator = exp(LIN*n + QUAD*n²),
> n = andar absoluto do endless. Era 1.18^n pra vida E dano — x3,2 já no
> 1º ciclo e x14 no 2º, com o dano acompanhando a vida: o endless acabava
> num golpe, não numa escalada. Agora é Balatro: generoso por 2-3 ciclos
> e EXPLODE depois (o termo quadrático garante que toda corrida termina).
> Vida no fim do ciclo 1..6: x1,5 x3,0 x7 x20 x69 x290.
> Dano (cresce mais devagar que a vida — derrota por escalada, não por
> golpe único): x1,3 x1,8 x2,7 x4,5 x8 x15.
> 1a versao (LIN 0.08/0.045) matou TODO vencedor do piloto ainda no
> ciclo 1 (balance_sim BALANCE_ENDLESS=48, guerreiro): o deck que mal
> passa o chefe do ato 6 nao aguenta x1,9 no andar 8. Ciclo 1 tem que
> ser a volta da vitoria, nao o muro.

## L246 (em `rarityWeights`, junto a `healPercent = 0.30,`)

> Cura ao abrir cada ciclo de 8 andares (Game:nextPhase), antes de selo/maldição.

## L250-252 (em `rarityWeights`, junto a `Config.TotalActs = 6`)

> Total de atos (excluindo endless). Usado por RunManager:advanceFloorInAct
> e por Game:checkVictory — a tela de vitória nasce daqui, então mexer neste
> número move o fim da campanha inteiro (foi 3 até Set/2026).

## L255-298 (em `rarityWeights`, junto a `Config.Economy = {`)

> ===== ECONOMIA: o pagamento por batalha (Set/2026) =====
>
> POR QUE A VITORIA PASSOU A ESCALAR POR ATO
>
> A campanha dobrou (3 -> 6 atos, Config.TotalActs) e o pagamento nao foi
> revisto. Medido com `love . autoplay 16 warrior 901000` (261 batalhas, loja
> exercitada de verdade — inclusive os servicos):
>
> • renda de $9,88 por batalha, CONSTANTE do ato 1 ao ato 6;
> $5 vitoria (50%) + $3 HP cheio (11%) + juros (39%)
> • os juros batem no teto de $5 em 55% das batalhas — ou seja, sao um
> salario fixo, nao um premio por poupar: acima de $25 no bolso guardar
> mais nao rende nada, e o jogador passa dos $25 ainda no ato 1;
> • ouro medio no bolso: A1 $29 · A2 $42 · A3 $56 · A4 $57 · A5 $39 · A6 $38;
> • compras por ato: 74 · 62 · 28 · 43 · 10 · 1.
>
> A renda e LINEAR e os precos sao GEOMETRICOS (forja x1,35; servicos x1,45 a
> x2,2 por compra na run). Com 3 atos a corrida acabava antes de a conta
> apertar. Com 6, o poder de compra por batalha no ato 6 e EXATAMENTE o do
> ato 1 ($10) enquanto a coisa mais barata que ainda nao se comprou custa
> $25-60: a loja fecha sozinha na metade final da campanha, e os numeros
> acima mostram isso acontecendo (10 compras no A5, 1 no A6).
>
> A CORRECAO E NO TERMO LINEAR, que foi o que a campanha mais longa quebrou.
> A vitoria passa a pagar `BASE + POR_ATO*(ato-1)`: $5 · $7 · $9 · $11 · $13 ·
> $15. Com ~4,3 batalhas por ato (26 batalhas numa corrida completa, medidas),
> isso soma ~$129 numa corrida inteira, TODOS na metade de tras — a renda
> total sai de ~$260 pra ~$390 e passa a acompanhar a escalada dos precos.
>
> O ato 1 fica BYTE-IDENTICO de proposito: e a parte mais testada do jogo e
> nao ha evidencia de que esteja errada.
>
> O QUE DELIBERADAMENTE NAO MUDOU, e por que:
>
> • O TETO DOS JUROS continua 5. Subi-lo premiaria GUARDAR justamente na
> metade em que o problema e nao conseguir GASTAR, e realimentaria o ciclo
> que Config.Offers descreve nos tres freios do Cofre. O numero (55% de
> saturacao) diz que a mecanica esta morta acima de $25 — mas a cura disso
> e a relIquia Cofre existir, nao a base subir.
>
> • O BONUS DE HP CHEIO continua $3 fixo. Ele e colhido em 11% das batalhas
> pelo guerreiro e em 7-8% pelo mago e pelo ladino — premia quem ja esta
> ganhando. Escalar por ato ALARGARIA a diferenca entre as classes, entao
> fica como esta; se virar alavanca um dia, e pra baixo, nao pra cima.

## L304-313 (em `Config.Economy`, junto a `ELITE_BONUS_MULT    = 1,`)

> BONUS DE RISCO (Out/2026, auditoria da economia): elite, mini-chefe e
> chefe pagavam EXATAMENTE o mesmo que uma luta comum — o mapa prometia
> risco e a bolsa nao pagava. Agora pagam uma linha a mais na folha do
> cash out, proporcional a vitoria do ato.
> elite: +1x a vitoria do ato · chefe do ato: +1x · mini-chefe: nada
> O mini-chefe fica de fora DE PROPOSITO: ele e obrigatorio em todo ato,
> entao bonus nele e so renda fixa disfarcada. A 1a versao (mini +1x,
> chefe +2x) subiu a renda do A1 de $9,8 para $13,6/batalha e o winrate
> do guerreiro do piloto de 42% para 83% na mesma bateria — risco tem que
> ser ESCOLHA (elite) ou marco (chefe), nao imposto sobre a rota.

## L318-322 (em `Config.Economy`, junto a `DICE = {`)

> DADOS DO ESCRIBA (Out/2026): aposta opcional da loja, uma por visita.
> Logica e o PORQUE de cada numero em src/systems/ScribeDice.lua.
> PAYOUT = retorno total na vitoria; EV = chance x PAYOUT ~ 1,0 (justo):
> Baixo/Alto 15/36 x 2,5 = 1,04 · Sete 6/36 x 6 = 1,00.
> test_scribe_dice trava o EV entre 0,9 e 1,1 — aposta nao e mina.

## L330-332 (em `STAKES`, junto a `function Config.Economy.victoryGold(act)`)

> Ouro da vitoria no ato `act` (FONTE UNICA — Game:_buildRoundEvalSources
> paga por aqui e qualquer preview deve ler daqui tambem; duas formulas pro
> mesmo numero e como a TopBar passou a mentir sobre os juros uma vez).

## L352-356 (em `Config.Economy.nodeBonus`, junto a `Config.Offers = {`)

> ===== Ofertas de carta (recompensas + loja): pity e afinidade =====
> Adaptação do "card blizzard" do Slay the Spire pro nosso modelo de pesos
> (ver memory/sts_run_economy.md). Estado do pity vive em Rng.meta (serializado
> com o save; compartilhado entre recompensas e loja). Regras explicadas ao
> jogador no "?" da tela de recompensas.

## L362 (em `Config.Offers`, junto a `AFFINITY_CAP       = 0.60,`)

> teto do bônus de afinidade

## L368-374 (em `Config.Offers`, junto a `SUSTAIN_GUARANTEE   = true,`)

> SUSTENTO garantido cedo (Out/2026, ADOTADO — unico lever que moveu o
> piloto mediano: +10 a +17pp, memory/balance_curves.md). Com menos de
> SUSTAIN_MIN_SOURCES cartas de sustento no deck (cura/roubo de vida/
> regeneração — CardRegistry.isSustainCard): GUARANTEE reserva a 1ª vaga
> da recompensa de elite/chefe pra uma carta de sustento; WEIGHT_BONUS
> multiplica o peso delas em QUALQUER oferta (1.0 = peso dobrado; 0 =
> desligado). Mexe só na OFERTA: nenhuma carta mudou de valor.

## L379-388 (em `Config.Offers`, junto a `DAILY_SALE     = true,`)

> OFERTA DO DIA (Loja v3 F4, Out/2026): UMA oferta da vitrine da loja
> (carta, reliquia ou pacote), sorteada no stream "shop" do Rng, sai
> DAILY_SALE_PCT mais barata (preco = floor(preco x (1 - pct))) e ganha
> a etiqueta vermelha torta. O reroll sorteia de novo; viaja no save com
> a vitrine. Mexe SO em preco. LIGADA por padrao desde 13/Out/2026 como
> decisao de UX do dono: a bateria (reports/balance/shop-sale,
> memory/balance_curves.md "Oferta do dia") mediu ruido puro em
> average e expert_full (-3 / +1 pp, dentro do IC) — nao e lever de
> dificuldade. Knob BALANCE_SHOP_SALE=0 (tools/balance_sim.lua) desliga
> pra medir a variante sem.

## L392-394 (em `Config.Offers`, junto a `FORGE_COST_BASE = 5,`)

> Forja (upgrade de carta) COMPRADA na loja: custo cresce a cada forja
> paga na run. A forja da fogueira continua grátis (o custo é a ESCOLHA:
> forjar OU descansar).

## L404-431 (em `Config.Offers`, junto a `SERVICES = {`)

> ===== SERVIÇOS da loja (Set/2026) =====
> Relíquias que mexem na RUN e não numa batalha: tesoura (remover carta),
> prensa (duplicar carta), bancada extra de coringa e o grimório de compra
> extra. Cada uma encarece a cada compra NA MESMA RUN, igual à forja —
> a loja vende o serviço, não uma assinatura barata pro resto do jogo.
>
> COMO OS NÚMEROS FORAM ESCOLHIDOS (e por que não são chute):
> Uma run de 6 atos paga ~$10 por batalha ($5 vitória + $3 HP cheio +
> juros até $5) e uma carta comum custa $3.
> NÚMERO DE BATALHAS, medido (Set/2026, `love . autoplay 16 warrior`):
> 17,3 por corrida até a morte (andar ~31); uma corrida COMPLETA até o
> andar 48 dá ~26 batalhas. O "~35 batalhas" que estava escrito aqui era
> estimativa, nunca medição, e inflava em ~35% o retorno de tudo que
> rende POR BATALHA RESTANTE — o Cofre logo abaixo em primeiro lugar.
> Com a vitória escalando por ato (Config.Economy), a renda da corrida
> inteira sai de ~$260 para ~$390.
> • remover/duplicar entram na faixa da forja (base 5) porque competem
> com ela pelo mesmo slot e pelo mesmo bolso;
> • slot de coringa e compra extra são upgrades PERMANENTES de motor —
> ficam na faixa do Cristal de Éter ($25) pra cima e têm TETO DE
> COMPRAS por run (`maxPerRun`), senão viram a única coisa que se
> compra na run inteira.
> Balanço é decisão do dono: mexer aqui move a economia toda.
> base      = custo da 1ª compra na run
> mult      = multiplicador por compra JÁ FEITA (custo = base*mult^n)
> max       = teto do custo
> maxPerRun = 0 (sem limite) ou N compras por run
> minDeck   = só é ofertada com pelo menos N cartas no deck

## L433 (em `SERVICES`, junto a `remove_card    = { base = 8,  mult = 1.45, max = 45, maxPerRun = 0, minDeck = 3 },`)

> 8, 12, 17, 25, 36, 45(teto) — barata na primeira, dolorosa na quinta.

## L435-436 (em `remove_card`, junto a `duplicate_card = { base = 12, mult = 1.55, max = 60, maxPerRun = 0 },`)

> 12, 19, 29, 45, 60(teto) — duplicar carta forjada é forte demais
> pra custar o mesmo que remover uma ruim.

## L438-442 (em `duplicate_card`, junto a `joker_slot     = { base = 20, mult = 1.75, max = 60, maxPerRun = 2 },`)

> 20, 35 (era 30, 60 — Out/2026, queixa do dono: "a bancada de
> coringa é cara demais"). Medido na bateria: o ouro na porta da loja
> no ato 1 é ~$26, então $30 empurrava a PRIMEIRA bancada pro ato 2+
> e a segunda ($60) pro ato 4. Com 20/35 a primeira cabe no ato 1 e
> a segunda no ato 2-3. O teto de 2 leva a bancada de 3 pra 5 ATIVOS.

## L444 (em `joker_slot`, junto a `card_draw_upgrade   = { base = 22, mult = 2.0,  max = 60, maxPerRun = 2 },`)

> 22, 44 (era 25, 55) — +1 carta por turno é motor puro; 2 é o teto.

## L446-450 (em `card_draw_upgrade`, junto a `interest_cap        = { base = 25, mult = 1.65, max = 150, maxPerRun = 0 },`)

> 25, 41, 68, 113, 150(teto) — ver INTEREST_CAP_* logo abaixo.
> SEM teto de compras (`maxPerRun = 0`): o pedido foi "aumentar
> sempre". Quem segura é o PREÇO, e ele segura de verdade — as cinco
> primeiras compras somam $397, que é aproximadamente a renda inteira
> de uma corrida.

## L454-485 (em `interest_cap`, junto a `INTEREST_CAP_PER_BUY = 2,   -- quanto o teto sobe por compra`)

> ===== TETO DE JUROS comprável (Set/2026) =====
> Pedido do dono: "hoje o juros tem limite, ter uma forma também de
> destravar o limite do juros e aumentar sempre ele".
>
> POR QUE ISTO PRECISA DE MAIS CUIDADO QUE AS OUTRAS RELÍQUIAS
> Slot de coringa e compra extra são DEGRAUS: sobem o patamar e param.
> Teto de juros realimenta a própria fonte — mais teto, mais ouro
> guardado, mais juros, mais teto. Sem freio vira motor infinito.
>
> SÃO TRÊS FREIOS, e nenhum deles é uma trava dura:
>
> 1. PREÇO CRESCENTE (×1,65 por compra). O freio principal.
>
> 2. OURO PARADO. Juros são `floor(ouro/5)` LIMITADOS pelo teto: pra
> realizar teto C é preciso manter 5×C no cofre. Teto 15 exige $75
> dormindo no bolso — sete cartas comuns que você NÃO comprou. O
> custo real da relíquia não é só o preço: é a liquidez.
>
> 3. PISTA QUE ENCURTA. O ganho é +2 por batalha RESTANTE. Comprado no
> ato 1 (~23 batalhas pela frente, medido) rende ~$46 por $25;
> comprado no ato 5 (~4 batalhas) rende $8 por $68 e é prejuízo grosso.
> (Os números antigos aqui — 30 e 10 batalhas — vinham do mesmo
> "~35 batalhas" estimado acima.) O item se
> desvaloriza sozinho conforme a corrida anda — é decisão de ABERTURA,
> não de fechamento, e isso não precisou de regra nenhuma.
>
> De propósito NÃO existe um quarto freio (rendimento decrescente por
> compra): os três acima já se compõem, e somar um quarto faria a compra
> parecer quebrada em vez de cara.
>
> Com 6 atos (o dobro da campanha antiga) o item vale literalmente o dobro
> do que valeria antes — é por isso que a base é $25 e não $10.

## L486 (em `interest_cap`, junto a `INTEREST_CAP_PER_BUY = 2,`)

> quanto o teto sobe por compra

## L487-490 (em `interest_cap`, junto a `INTEREST_CAP_MAX = 25,`)

> Guarda-corpo, não design: nas contas acima chegar aqui custaria mais de
> $1.000 numa corrida que rende ~$400. Existe pra que o número não possa
> disparar num modo futuro (endless longo, joker que dá ouro), nunca pra
> ser encostado numa corrida normal.

## L496-497 (em `Config.Cards`, junto a `BASE_SCALE = 1.333,`)

> Escalas (alvo: cartas procedurais são 96×144 → base 1.33 ≈ 128×192 na tela,
> preservando o mesmo espaço ocupado pelo layout legado de 64×96×2.0).

## L506 (em `Config.Cards`, junto a `PERSPECTIVE_STRENGTH = 0.25,    -- Força do efeito de perspectiva`)

> Efeitos 3D Balatro-style

## L525 (em `Config.Cards`, junto a `PLAYABLE_BORDER_COLOR = {0.3, 0.6, 0.9, 0.8}, -- Azul semi-transparente`)

> Borda azul para cartas jogáveis (Slay the Spire style)

## L551 (em `basic`, junto a `CORNER_CUT = 3,              -- stepped cut dos cantos no canvas lógico (96×144)`)

> ===== Polish (Balatro-like) =====

## L555 (em `basic`, junto a `SCALE_EASE_K = 12,`)

> exp decay pro scale (antes era lerp linear 10*dt)

## L562-564 (em `basic`, junto a `AMBIENT_TILT_SPEED = 1.4,    -- freq em rad/s (devagar, orgânico)`)

> ===== Ambient tilt (cartas ociosas respiram — Balatro) =====
> Só aplica quando NÃO hovered. Senóide defasada por seed aleatório
> pra cartas da mão não oscilarem em sync.

## L566 (em `basic`, junto a `AMBIENT_TILT_AMOUNT = 0.02,`)

> amplitude em radianos (~1.1°, sutil)

## L568 (em `basic`, junto a `BASE_LIFT = 3,               -- carta flutua sempre ~3px acima da mesa (idle)`)

> ===== Floating / Shadow (Balatro-accurate) =====

## L569 (em `basic`, junto a `BASE_LIFT = 3,`)

> carta flutua sempre ~3px acima da mesa (idle)

## L578 (em `basic`, junto a `MESH_COLS = 8,               -- tessellation horizontal`)

> ===== Perspective warp (Balatro-accurate via vertex shader) =====

## L596-599 (em `Config.Audio`, junto a `COMBO_TRIGGER_VOLUME = 0.5,`)

> 13/Out/2026 (dono: "muito alto, muito estridente, horroroso"): o
> arquivo combo-trigger.mp3 foi suavizado na fonte (passa-baixa 3,8 kHz,
> 9 dB; média -18 -> -29 dB) e o ganho caiu. Ele toca nos combos, na
> conquista e no recorde; a escolha de classe deixou de usá-lo.

## L608-610 (em `Config.Audio`, junto a `ENEMY_DEATH_VOLUME = 0.48,`)

> 0.65 -> 0.48 (Set/2026, dono: "barulho quando monstro morre muito alto").
> 0.65 era o TOPO da faixa do projeto (combate vive em 0.5-0.55) e ainda
> soma com o jiggleScreen(1.5) que dispara no mesmo frame (Game.lua:1295).

## L612-615 (em `Config.Audio`, junto a `CARD_EXPLODE_VOLUME = 0.45,`)

> Carta explodindo tem som PROPRIO. Antes tomava emprestado o enemyDeath
> ("som de boom disponivel", comentario no Card.lua) -- carta estourando
> nao deveria soar como monstro morrendo. Registro por scan: enquanto
> audio/sfx/card-explode.mp3 nao existir, cai no enemyDeath e nada quebra.

## L624 (em `Config.Audio`, junto a `AMBIENT_VOLUME = 0.09,`)

> KNOB ÚNICO do ambiente (clima + lugares): camas ~-32 dB sob o pico da música (dono: "muito alto"; era 1.0 e no grupo sfx)

## L628 (em `Config.Audio`, junto a `BATTLE_VICTORY_VOLUME = 0.45,`)

> arquivo também suavizado (passa-baixa 5 kHz, -7 dB), 13/Out/2026

## L637-639 (em `Config.Audio`, junto a `Config.Lighting = {`)

> LightEngine v1 (docs/plan/lighting-engine-v1.md) — tuning das fontes de luz
> do WorldRoad. O motor em si vive em engine/LightEngine.lua; a cor ambiente
> por bioma vive em src/data/biomes.lua (campo lightAmbient).

## L641-646 (em `Config.Lighting`, junto a `WINDOW  = { radiusK = 0.16, color = { 1.00, 0.72, 0.35 }, intensity = 0.55,`)

> v9: LANTERN/BRAZIER/POOL_MIN_T migraram pro LuminaireEngine
> (engine/LuminaireEngine.lua) — luz de prop decorativo agora é
> catálogo POR BIOMA com 2-3 tipos cada.
> janelas do castelo: micro-luzes POR janela (raio ∝ largura do castelo);
> âncoras default {xr, yr} relativas ao sprite — biomes.lua pode
> sobrescrever com lightWindows

## L649 (em `anchors`, junto a `FIREFLY = { radius = 6, intensity = 0.45 },`)

> tímido: vagalume é detalhe, não farol (feedback Jul/2026)

## L679-690 (em `getRelativePosition`, junto a `tamanhoJanelaInicial = function(desktopW, desktopH, larguraAtual, fracao)`)

> Tamanho com que a janela deve NASCER, dado o monitor e a largura atual.
> Devolve (w, h) ou nil quando não há motivo pra mexer.
>
> Mora aqui, separada de `love.window`, para poder ser testada: abrir
> janela de verdade num teste não é reproduzível (cada máquina tem um
> monitor) e `love.window.setMode` repetido dentro de um tool não retorna
> (ver memory/ui_layout_invariants.md). A decisão é aritmética; só a
> aplicação precisa do módulo window.
>
> 85% e não 100%: a área que o SO dá não desconta barra de tarefas
> (Windows) nem menu bar e dock (macOS), então pedir tudo enfia a barra de
> título atrás delas.

## L697-698 (em `tamanhoJanelaInicial`, junto a `if w < 800 or h < 600 then return nil end`)

> Nunca abaixo do mínimo declarado no conf.lua, senão o setMode
> devolve uma janela maior que a pedida e o layout nasce errado.

