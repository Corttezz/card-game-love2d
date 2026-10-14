---
name: code_notes/src/systems/EffectSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/EffectSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/EffectSystem.lua`

Origem: `src/systems/EffectSystem.lua` em `7dbdb60d` (72 de 98 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local EffectSystem = {}`)

> src/systems/EffectSystem.lua
> Sistema modular de efeitos de cartas.
> Dois domínios:
> 1. Efeitos *contínuos* de jokers — modificam o dano/defesa/heal de cartas jogadas.
> 2. Efeitos de *trigger* — disparam em eventos ("attack", "defend", "turn_start").
> Todos os efeitos são data-driven: leem `card.effects` (já injetado por CardDatabase:createCardInstance).

## L18-21 (em `msg`, junto a `local function notifyOrbUI(fn, ...)`)

> Ponte pra UI (OrbRow) — pcall pra rodar headless sem UI (mesmo idioma dos
> pcall(require EnemyRenderer/FloatingText) no Game.lua). fn inexistente =
> no-op. DECLARADA AQUI NO TOPO: locals de Lua so existem abaixo da definicao
> (regressao pega pelo test_all: channel_orb usava antes da declaracao).

## L33-36 (em `EffectSystem:new`, junto a `local function sinkOf(game)`)

> Coletor de PASSOS do combate (ver src/systems/CombatBeats.lua). O Game seta
> `game._beatSink` enquanto resolve uma carta; com ele presente, cada efeito
> vira um acontecimento com instante proprio em vez de todos no mesmo frame.
> Ausente (API chamada direto por teste/autoplay) = sincrono, como sempre foi.

## L41-44 (em `sinkOf`, junto a `local function checkEnrage(game)`)

> Todo dano ao inimigo pode cruzar os 30% de vida e ENFURECE-LO (+50% de dano
> permanente). Era mudo; agora o Game da um instante proprio ao cruzamento.
> Chamado depois de CADA takeDamage daqui. `game` leve (mockGame dos testes)
> nao tem o metodo — vira no-op, como o resto das pontes de UI deste arquivo.

## L51-55 (em `checkEnrage`, junto a `local function enemyHurt()`)

> DANO TEM CARA DE DANO. Magia e evoke acertam o inimigo pelo EffectSystem, que
> (ao contrario da carta de ataque, servida pelo CombatSequence) nao tinha
> numero nem reacao — so um burst. Sem isso o jogador do mago via a mesma
> explosao generica pra "levou dano" e pra "ganhou um orbe". `v` negativo nunca
> chega aqui; headless/UI ausente = no-op.

## L65-67 (em `showEnemyDamage`, junto a `if ER.triggerHurt then pcall(ER.triggerHurt) end`)

> Inline de proposito (nao chama enemyHurt): a varredura estatica de
> tools/audit_feedback.lua segue UM nivel de delegacao, entao a reacao do
> inimigo precisa ser visivel aqui pra o tipo de efeito nao parecer mudo.

## L78-80 (em `showEnemyDamage`)

> ==============================================================================
> Efeitos contínuos de jokers (chamados ao jogar uma carta de ataque/defesa).
> ==============================================================================

## L82-84 (em `showEnemyDamage`, junto a `local function pushJokerProc(game, sink, joker, label, kind)`)

> Game feel v1 (Jul/2026): helper de PROC — registra que um joker contribuiu
> (rótulo tipo "×2"/"+3"/"+4 PV") num sink, com o índice do slot pra UI ticar
> o joker certo (JokerProcFx). Sink ausente = no-op (headless/chamadas antigas).

## L98-102 (em `proc`, junto a `local now = (love.timer and love.timer.getTime()) or 0`)

> SEM sink = proc FORA do pipeline de carta (ex: turn_start — compra
> extra, regen, Forma Demoniaca...). Antes era no-op e o joker ficava
> MUDO ("Aprendizado de Máquina não triga visualmente" — feedback
> Jul/2026). Dispara DIRETO no JokerProcFx, escalonado: vários procs
> no mesmo instante ticam em sequência (0.18s), não em uníssono.

## L121-123 (em `fire`, junto a `function EffectSystem:notifyJokerProc(game, joker, label, kind, sink)`)

> API pública do proc direto (Game usa pro retain_armor do Bastião, que
> dispara fora do EffectSystem — em Player:onTurnStart). Com `sink`, o proc
> entra no array da carta (Game:_resolveCardInCombat, conta via DamagePreview).

## L128-131 (em `EffectSystem:notifyJokerProc`, junto a `local DEBUFF_THEME = { burn = "fire" }`)

> TEMA VISUAL DE CADA DEBUFF. `CardFeel.THEMES` e indexado por TAG de carta
> (fire/ice/poison/...), e nem todo status tem tag de mesmo nome -- queimadura
> e o caso: sem este mapa ela estouraria com as BOLHAS VERDES do veneno, que e
> exatamente a confusao que este status veio desfazer.

## L137 (em `debuffTheme`, junto a `if not warnedTheme[name] then`)

> Fallback silencioso e proibido (CLAUDE.md 9): status novo sem tema AVISA.

## L151-158 (em `multLabel`, junto a `function EffectSystem:jokerSteps(game, card, baseValue, turnContext, echoFired)`)

> NUCLEO PURO (Out/2026, previa de dano): a mesma conta de sempre, sem tocar
> em nada — devolve (valor, entradas, ecoUsado). Cada entrada e
> { joker, op = "mult"|"add", value, label, kind, text, after }. A previa
> (src/systems/DamagePreview.lua) le as entradas pra explicar o numero; o
> combate (applyJokerEffects, abaixo) as transforma em toast + proc. Uma
> conta so: previa == resultado por construcao.
> `echoFired` = o Eco ja disparou neste turno (estado do turno, passado pela
> previa que simula a leva; o combate passa o flag real do game).

## L164-171 (em `entries`, junto a `local bestMult, bestMultJoker = nil, nil`)

> P0.9 (Jul/2026, rebalance v2 — LARGEST-MULTIPLIER-WINS): entre os jokers
> ativos, APENAS o MAIOR damage_multiplier e o MAIOR defense_multiplier
> contam. Sem isso, echo_form 1.5 x joker_001 1.5 = x2.25 em cadeia
> (produto x5.06 com combo+vulnerable — boss A2 em ~1.5 turnos), e duas
> copias do mesmo joker multiplicador dobravam de graca. Bonus FLAT
> (damage_bonus/defense_bonus) continuam somando TODOS; multiplicadores
> de COMBO e vulnerable sao camadas distintas do pipeline e ficam fora
> da regra. NAO reintroduzir produto em cadeia aqui.

## L199-207 (em `entries`, junto a `if card.type == "attack" and not echoFired then`)

> ECO (Set/2026): dobra a PRIMEIRA carta de ataque do turno, uma vez por
> turno. Fica FORA do largest-wins de proposito — nao e um multiplicador
> plano concorrendo com os outros, e um pico condicional: premia botar o
> golpe grande na frente em vez de somar em tudo.
>
> Existe porque "Forma de Eco" era um CLONE do "Deus do Abismo" (os dois
> damage_multiplier attack 1.5) — queixa do dono: "qual a diferenca entre
> deus do abismo e forma de eco? nenhuma, e uma e lendaria a outra rara".
> E com o largest-wins ter os dois nao somava nada: max(1.5,1.5) = 1.5.

## L246-252 (em `entries`, junto a `function EffectSystem:applyJokerEffects(game, card, baseValue, turnContext)`)

> turnContext (opcional, Fase 3+): tabela com { allSelectedCards, tagCounts,
> activeCombos, cardsProcessed, turnNumber }. Se presente, combos amplificam o
> valor ANTES dos jokers (multiplicador-sobre-multiplicador nao vira produtorio).
>
> RETORNO (game feel v1): (finalValue, procs) — procs é o array de contribuições
> de joker pro tick sequencial estilo Balatro. Chamadas antigas que só leem o
> primeiro retorno continuam funcionando.

## L264-268 (em `procs`, junto a `function EffectSystem:predictJokerProcs(game, card)`)

> Game feel v1: PREVISÃO de quantos procs de joker uma carta vai disparar —
> usada pelo Game ANTES do startCombat pra esticar o stagger (a próxima carta
> espera os ticks da anterior). Aproximação barata da mesma lógica de
> applyJokerEffects + triggers on_attack/on_defend; contar 1 a mais/menos só
> muda pacing, nunca valores.

## L282-283 (em `EffectSystem:predictJokerProcs`, junto a `if not game._echoFiredThisTurn then n = n + 1 end`)

> So proca se ainda nao ecoou neste turno; prever a mais
> deixaria a carta esperando um tick que nao vem.

## L301-302 (em `EffectSystem:predictJokerProcs`, junto a `function EffectSystem:processEffect(effect, card, currentValue, turnContext)`)

> Retorna (novoValor, mensagem?) para um efeito aplicado a uma carta específica.
> turnContext e passado para permitir efeitos tag-aware futuros (Fase 3).

## L324-336 (em `EffectSystem:processEffect`, junto a `function EffectSystem.hitCount(card)`)

> Bonus aditivo a ataques baseado em player.strength. Usado como efeito NA
> PROPRIA CARTA (card.effects, nao joker). Chamado pelo Game ao resolver ataque.
> Retorna (novoValor, mensagem?) para consumo pelo Game:processCardInCombat.
>
> IMPORTANTE: strength_scaling/dexterity_scaling são FLAG-ONLY aqui — Strength
> e Dexterity do player já são adicionados em Game:processCardInCombat via o
> parâmetro statBonus de computeCardValue. Antes da Fase 2 do refactor de
> balance, este branch também somava → strength entrava 2x para cartas que
> declaravam o effect. Mantemos o effect declarado nas cartas (semântica útil
> para tooltip/UI/validate_cards) mas não dobramos a aplicação.
> Quantos GOLPES a carta da (multi_hit). Fonte unica: o Game multiplica o
> bonus de Forca por isto (Forca vale por golpe) e o piloto
> (tools/autoplay.lua) espelha a mesma conta.

## L360-361 (em `EffectSystem:applyCardEffects`, junto a `finalValue = finalValue * math.max(1, v)`)

> Ataque multiplo (N hits): aqui so o VALOR (multiplicacao simples);
> os golpes separados sao coreografados pelo CombatSequence/CombatBeats.

## L369-371 (em `EffectSystem:applyCardEffects`, junto a `local SELF_STEPPED = {`)

> ==============================================================================
> Efeitos de cartas de efeito (potions/utilitárias) — jogadas, consumidas.
> ==============================================================================

## L373-374 (em `EffectSystem:applyCardEffects`, junto a `local SELF_STEPPED = {`)

> Efeitos que JA emitem os proprios passos (orbes evocam/canalizam um a um).
> Envolve-los num passo externo os colapsaria de volta num instante so.

## L385-388 (em `EFFECT_HOLD`, junto a `function EffectSystem:processEffectCardStepped(game, effect, showFallback)`)

> Entrada SEQUENCIADA de um efeito de carta: com `game._beatSink` ativo cada
> efeito ocupa um instante proprio (ver CombatBeats); sem sink roda na hora.
> `showFallback` reproduz o comportamento do `card.passive` compilado pelo
> CardDatabase (descrever no feed o efeito que o engine nao reconhece).

## L418-419 (em `EffectSystem:processEffectCard`, junto a `game.player:loseHealth(v)`)

> Custo em sangue: HP direto, ignora armor (F0 gameplay-overhaul —
> cartas tipo Sangria prometem "Perde N HP" e precisam cumprir).

## L440-441 (em `EffectSystem:processEffectCard`, junto a `CardFeel.burstAtEnemy("magic", 0.9)`)

> Game feel v1: dano mágico de effect card também estoura no inimigo
> (cartas de ATAQUE já ganham burst via CombatSequence; efeito não).

## L451-453 (em `EffectSystem:processEffectCard`, junto a `local debuff = {`)

> value = nome do debuff ("poison"/"weak"/"vulnerable"),
> stacks = intensidade (ex: 3 de poison = 3 dano por turno),
> duration = turnos que dura (default 2).

## L465-466 (em `debuff`, junto a `CardFeel.burstAtEnemy(debuffTheme(debuff.name), 0.8)`)

> Game feel v1: o debuff APARECE no corpo do inimigo com a cor dele
> (veneno verde, weak lavanda, vulnerable rosado, queimadura laranja).

## L471-475 (em `debuff`, junto a `if game.enemy and game.enemy.revealIntent then`)

> NÉVOA DE INTENÇÃO (Out/2026): dissipa o véu sobre o anúncio do
> inimigo neste turno e nos `value - 1` seguintes. O golpe não muda
> (continua congelado) — só a LEITURA volta. Fora da névoa a carta
> não faz nada visível, de propósito: é um contador barato, não um
> efeito de dano.

## L487-494 (em `debuff`, junto a `local discarded = 0`)

> BUG FIX (Jul/2026): a carta descartada tem que IR PRO DISCARD, não
> sumir. table.remove(game.hand) só a arrancava da mão — nunca entrava
> em game.discard, então nunca voltava no reshuffle. Efeito: Sobrevivente
> (discard_cards=1) deletava 1 carta não-jogada por turno; em poucas
> rodadas o deck de batalha degenerava pras 3 cartas que o jogador
> jogava (as únicas que iam pro discard direito), infinitamente. O deck
> DA RUN (currentDeck) nunca foi tocado — o bug era só na instância da
> batalha. Ver smoke_discard test 13.

## L521-522 (em `debuff`, junto a `local name = effect.value or "buff"`)

> Aplica buff nomeado no jogador (ex: "focus"). value=nome, stacks=intensidade,
> duration em turnos.

## L544-545 (em `debuff`, junto a `local count = #game.player.orbs`)

> UM ORBE POR VEZ (Set/2026): antes os 3 evocavam no mesmo instante e
> o jogador via um borrão de números sem saber qual orbe fez o quê.

## L551 (em `debuff`, junto a `CombatBeats.step(sinkOf(game), "orb.evoke_all_done", function() end, "MICRO")`)

> respiro depois da rajada de evocações (o feedback é o do orbe)

## L581-582 (em `debuff`, junto a `return true`)

> Efeitos processados em applyCardEffects (no damage path), nao aqui.
> Retorna true para suprimir o fallback de descricao.

## L593-596 (em `debuff`)

> ==============================================================================
> Orbes: formulas CANONICAS de pulso/evoke (fonte unica — a UI OrbRow exibe
> estes mesmos numeros; mudou a formula aqui, a tela acompanha de graca).
> ==============================================================================

## L598-602 (em `debuff`, junto a `function EffectSystem.orbPulseValue(orb, focus)`)

> Valor do PULSO por turno de um orbe (0 = nao pulsa; dark cresce em vez disso).
> Combos simples (Out/2026): com o inimigo mais fraco (Config.Game.ENEMY_POWER)
> o mago foi a 73-90% com o pacote de crescimento (Conduite +1 Foco por turno,
> orbe pelo multiplicador de coringa, Foco inteiro no pulso). Sem os tres:
> 47% (bateria 30 runs). O Foco volta a entrar na base, dividido junto.

## L620-625 (em `EffectSystem.orbEvokeValue`, junto a `function EffectSystem:_evokeOrbEffect(game, orb)`)

> Aplica o efeito mecanico de um orb evocado. Mapa central de tipos:
> lightning: dano direto
> ice      : armor
> dark     : dano dobrado (simbolo: orb cresce enquanto canalizado; MVP = 2x valor)
> fire     : dano + QUEIMADURA (status proprio `burn`, DoT de fogo)
> holy     : cura

## L629-632 (em `EffectSystem:_evokeOrbEffect`, junto a `local focus = 0`)

> FOCO (auditoria Jul/2026): o buff "focus" existia no HUD (pill) mas
> NADA concedia nem consumia — mecanica fantasma. Agora e o eixo de
> scaling do mago (identidade StS Defect): +1 de potencia por stack em
> CADA orbe evocado. Concedido por Foco Arcano / Consumir.

## L639-640 (em `EffectSystem:_evokeOrbEffect`, junto a `if orb.type == "lightning" then`)

> Game feel v1: o evoke ATERRISSA visivelmente — burst do elemento no
> alvo (dano → inimigo; armor/cura → painel do jogador).

## L657-663 (em `EffectSystem:_evokeOrbEffect`, junto a `game.enemy:addStatusEffect({ name = "burn", duration = 2,`)

> QUEIMADURA, nao veneno (Set/2026 — o dono jogando: "por que o inimigo
> esta ficando com veneno na minha run de mago?"). O atalho antigo
> ("aplica burn via poison por ora; refinar") sobreviveu ao "por ora" e
> custava tres coisas: roubava a identidade do LADINO (veneno e o eixo
> dele, 6 cartas), fazia a TELA MENTIR (icone/nome/desc diziam Veneno) e
> CONTAMINAVA sinergias (conquista de 15+ veneno, combo poison_stack).
> Mecanica igual -- dano por turno pelos stacks -- com status proprio.

## L675-693 (em `EffectSystem:_evokeOrbEffect`, junto a `local CHANNEL_PITCH_BASE, CHANNEL_PITCH_STEP = 0.92, 0.15`)

> ==============================================================================
> CANALIZAR x EVOCAR: dois acontecimentos que o jogador precisa DISTINGUIR
> ==============================================================================
> Pedido do dono (Set/2026), jogando com o mago: "Chuva de Meteoros canaliza
> muitas ao mesmo tempo, fica confuso se esta dando dano ou se canalizando uma
> nova". O defeito NAO era falta de beat — os beats ja existiam. Era que o
> ESTADO mudava fora deles: `player:addOrb` rodava na COLETA (dentro do beat de
> impacto da carta), entao os 3 orbes APARECIAM na fileira no mesmo instante do
> numero de dano e os beats seguintes so tocavam som e pop-in em cima de orbes
> que ja estavam la. O mesmo valia pro evoke: o orbe sumia no impacto e o flash
> caia depois, no slot 1, em cima de um orbe que nem era aquele.
>
> Agora a MUTACAO mora dentro do beat. E a linguagem separa os dois sentidos:
> canalizar -> vai PARA a fileira: streak entrando, pop-in, pitch SUBINDO
> com o slot (a fileira vira teclado: 1 grave, 3 agudo);
> evocar    -> SAI da fileira pro combate: fantasma do orbe deixando o slot,
> pitch GRAVE e descendo;
> overflow  -> um TERCEIRO acontecimento (o orbe mais antigo e expulso pra
> abrir vaga), com instante proprio e o som mais grave de todos.

## L698-703 (em `EffectSystem:_evokeOrbEffect`, junto a `function EffectSystem:_stepChannelOrb(game, orb, sink)`)

> Canaliza UM orbe como acontecimento(s) proprio(s).
> Beat 1 "orb.make_room" (MICRO): barato quando ha vaga. Quando a fileira esta
> CHEIA ele expulsa o mais antigo e reivindica o instante via extendCurrent
> (padrao do passo CONDICIONAL, o mesmo do enemy.enrage_check) — o jogador
> ve o orbe SAIR antes do novo entrar, em vez de um sumir do nada.
> Beat 2 "orb.channel" (ORB): o orbe entra. `addOrb` so roda AQUI.

## L733-735 (em `EffectSystem:_stepChannelOrb`, junto a `function EffectSystem:_stepEvokeOrb(game, sink, ord)`)

> Evoca o orbe mais antigo como acontecimento proprio. `ord`/`total` so afinam
> o pitch quando o evoke vem em lote (evoke_all_orbs): desce a cada orbe, o
> gesto sonoro contrario ao da canalizacao.

## L747-772 (em `EffectSystem:_stepEvokeOrb`, junto a `local PULSE_LAND_STEP = 0.06`)

> ==============================================================================
> ONDE O PULSO ATERRISSA (Set/2026, pedido do dono: "os orbes, quando dao dano
> ao final do turno, eles poderiam refletir algo no inimigo visualmente
> tambem, cada um de uma forma")
> ==============================================================================
> O pulso ja SAIA do orbe (flash + numero no slot). Faltava a outra ponta: ele
> CHEGAR em algum lugar e deixar marca. Mas "no inimigo" so vale pros pulsos
> que de fato ferem — a doutrina de defeitos (§3) diz que feedback certo na
> HORA/LUGAR errado e pior que feedback nenhum, porque ensina causalidade
> errada. Conferido em EffectSystem.orbPulseValue + orbPassiveTick:
>
> raio, fogo -> DANO no inimigo   -> marca no INIMIGO
> gelo       -> Bloqueio no heroi -> marca no PAINEL DO JOGADOR
> sagrado    -> cura o heroi      -> marca no PAINEL DO JOGADOR
> sombra     -> cresce no proprio orbe (nao sai dali) -> marca NO ORBE
>
> A identidade de cada elemento nao e inventada aqui: vem do CardFeel (som de
> impacto + paleta + FISICA das particulas — fogo sobe, gelo cai, raio e rapido
> e sem gravidade, sombra sobe devagar). Ver memory/card_feel.md.
>
> `pitch` e a assinatura do elemento; `+ (idx-1)*STEP` mantem a contagem da
> esquerda pra direita (a fileira toca como teclado, igual a canalizacao).
> `k` (intensidade do burst) foi MEDIDO na captura de validacao
> (`lovec . preview_battle_hud pulse`): abaixo de ~0,9 as particulas de gelo e
> sombra sumiam contra o HUD sepia. Todos seguem ABAIXO do impacto de carta
> (1,1-1,2), que e o que mantem "pulso < golpe" na leitura.

## L779 (em `fire`, junto a `ice       = { theme = "ice",       where = "player", pitch = 1.18, k = 0.95 },`)

> gelo: cristalino, e DEFENSIVO — cai no painel do heroi, nunca no inimigo

## L787-789 (em `dark`, junto a `local function landPulse(orbType, idx, landed)`)

> Toca a assinatura do elemento e estoura o burst NO LUGAR CERTO.
> `landed` = o efeito realmente aconteceu (pulso > 0, alvo vivo). Pulso que nao
> fez nada nao pode soar como se tivesse feito.

## L807-809 (em `landPulse`, junto a `function EffectSystem.previewPulseLanding(orbType, idx)`)

> Porta de validacao VISUAL (tools/preview_battle_hud.lua `pulse`): dispara so
> a aterrissagem, sem mexer em estado nenhum. Existe porque o efeito desta
> rodada e particula na tela — sem caminho visual, "validei" seria mentira.

## L814-819 (em `EffectSystem.previewPulseLanding`, junto a `function EffectSystem:orbPassiveTick(game, sink)`)

> Pulso passivo dos orbes (fim do turno do jogador, identidade Defect/StS):
> cada orbe canalizado dispara uma versao fraca do seu evoke — o motor do
> mago gera pressao POR TURNO, nao so no evoke (auditoria Jul/2026: orbe
> inerte era a raiz do mago 0/6 no autoplay — dano anemico e DEFEND do
> inimigo anulava turnos inteiros). Foco soma no valor base antes da
> divisao, entao escala pulso E evoke.

## L825-830 (em `EffectSystem:orbPassiveTick`, junto a `for i, orb in ipairs(p.orbs) do`)

> UM ORBE POR VEZ (Set/2026, pedido do dono: "um exemplo e o mago com as
> orbes"). ANTES: o laco somava dmg/armor/heal dos 3 orbes e aplicava um
> numero agregado no mesmo instante — o jogador via "-7" e nao tinha como
> saber de onde veio. AGORA cada orbe pulsa no beat dele: flash no slot,
> numero saindo DAQUELE orbe, efeito aplicado, respiro, proximo.
> Formula canonica em orbPulseValue (fonte unica com a UI).

## L835-837 (em `EffectSystem:orbPassiveTick`, junto a `local landed = false`)

> O NUMERO sai do orbe (causa) e o IMPACTO cai no alvo (efeito).
> De proposito nao ha segundo numero no alvo: o valor ja foi dito
> uma vez, e repeti-lo a 0,0s de distancia vira ruido.

## L845-847 (em `EffectSystem:orbPassiveTick`, junto a `if o.type == "lightning" and game.enemy.revealNextIntent then`)

> O clarão do RAIO rasga a névoa de intenção: o PRÓXIMO
> anúncio do inimigo vem inteiro (IntentVisibility). É o
> contador do mago sem carta nova.

## L875-881 (em `EffectSystem:orbPassiveTick`, junto a `function EffectSystem.announceBurnTick(game, dmg)`)

> ==============================================================================
> QUEIMADURA: a APRESENTACAO do DoT de fogo
> ==============================================================================
> O dano mora em Enemy:onTurnEnd, junto do veneno — mesmo instante, mesma
> aritmetica, mesma travessia do limiar de morte. Aqui fica so a linguagem: o
> veneno CHIA verde e borbulha; a queimadura ESTALA laranja. Dois DoTs, duas
> assinaturas — a mesma regra dos pulsos de orbe.

## L900-902 (em `EffectSystem.announceBurnTick`, junto a `function EffectSystem:applyHealMultiplier(game, amount, procSink)`)

> Aplica multiplicadores de heal vindos de jokers (heal_multiplier).
> P2.4 (Jul/2026, rebalance v2): retorno com math.floor — sem ele, 5 x 1.5
> rendia 7.5 HP fracionario no HUD (Prece Radiante sob Calice do Sabio).

## L911-914 (em `EffectSystem:applyHealMultiplier`, junto a `if math.floor(final) ~= math.floor(before) then`)

> EFEITO QUE MUDA UM NUMERO TEM QUE TICAR (Set/2026, pedido
> do dono sobre o Abraco Sombrio): o joker tinha defense_bonus
> ticando e heal_multiplier MUDO — metade dele era invisivel.
> Sem sink o proc dispara direto (escalonado no JokerProcFx).

## L926-929 (em `EffectSystem:applyHealMultiplier`, junto a `function EffectSystem.thornStacks(game)`)

> ==============================================================================
> ESPINHOS (thorn) — estado armado por cartas/jokers de on_defend_damage e
> DISPARADO pelo golpe do inimigo. Fonte unica do valor pra logica e pra UI.
> ==============================================================================

## L938-939 (em `EffectSystem.thornStacks`, junto a `function EffectSystem:fireThornReflect(game)`)

> Dispara o reflexo. Chamado pelo Game DEPOIS do golpe do inimigo aterrissar,
> no beat proprio dele. Retorna o dano refletido (0 se nao havia espinhos).

## L946-947 (em `EffectSystem:fireThornReflect`, junto a `Sfx.play("thornReflect")`)

> Game feel v1: espinhos têm som metálico próprio + burst no inimigo
> (o dano refletido é VISÍVEL chegando nele).

## L960-973 (em `EffectSystem:fireThornReflect`, junto a `local armados = game._jokerThornFiredThisTurn`)

> O JOKER QUE ARMOU FALA AQUI (Set/2026, pedido do dono sobre o Baluarte
> Eterno: "tambem tem q fazer barulho quando receber dano").
>
> Espinhos sao ESTADO: o joker arma quando a defesa e jogada e o reflexo
> so sai agora, quando o inimigo ataca. O proc visual/sonoro estava so no
> ARMAR — ou seja, o lendario ficava MUDO exatamente no instante em que
> faz o que promete. Quem olha a tela ve o inimigo levar dano do nada e
> nao liga a um coringa.
>
> Vale pros QUATRO que armam espinhos (Baluarte Eterno, Juggernaut,
> Estrepes, joker_005) — todos tem som assinatura em audio/sfx/joker-sig/.
> A varredura e pela ORDEM DOS SLOTS, nao pelo `pairs` do mapa: com dois
> coringas de espinho a cadeia de ticks tem que sair sempre na mesma
> ordem, senao o som do turno muda de run pra run sem motivo.

## L986-990 (em `EffectSystem:fireThornReflect`)

> ==============================================================================
> Efeitos de trigger — disparados pelo Game em eventos específicos.
> triggerType: "attack" | "defend" | "turn_start"
> context: tabela opcional com dados do evento (ex: {target = enemy}).
> ==============================================================================

## L992-998 (em `EffectSystem:fireThornReflect`, junto a `EffectSystem.TRIGGER_OF = {`)

> Mapa tipo-de-efeito -> gatilho que o dispara. Serve a DOIS propositos:
> 1) saber, SEM executar, se um efeito tem algo a fazer neste gatilho — sem
> isso cada joker inerte viraria um BEAT vazio e o turno ganhava ar morto;
> 2) documentar o contrato num lugar só.
> AO ADICIONAR UM TRIGGER NOVO em processTriggerEffect, REGISTRE AQUI — senão
> ele nunca dispara. A trava `test_beats` compara este mapa com o código-fonte
> de processTriggerEffect e falha se divergirem.

## L1010-1013 (em `EffectSystem.TRIGGER_OF`, junto a `function EffectSystem:applyTriggerEffects(game, triggerType, context)`)

> context.beatSink (Set/2026): quando presente, cada trigger que TEM o que
> fazer vira um PASSO na fila em vez de rodar junto com todos os outros — um
> acontecimento por instante (ver src/systems/CombatBeats.lua). Sem sink o
> comportamento e o antigo, sincrono (API direta: testes, autoplay).

## L1017-1019 (em `EffectSystem:applyTriggerEffects`, junto a `for _, joker in ipairs(game.jokerSlots or {}) do`)

> 1) Triggers de jokers ativos (ex: lifesteal, regen).
> P2.3 (Jul/2026): marca a FONTE joker no context — processTriggerEffect
> usa isso pra limitar on_defend_damage de joker a 1x/turno por joker.

## L1036-1038 (em `EffectSystem:applyTriggerEffects`, junto a `if context and context.sourceCard and context.sourceCard.effects then`)

> 2) Triggers da carta sendo jogada (passada pelo Game via context.sourceCard).
> Ex: defense card "Barreira de Fogo" tem on_defend_damage → arma espinhos.
> Sem isso, triggers em cartas non-joker seriam silenciosamente no-op.

## L1053-1054 (em `EffectSystem:applyTriggerEffects`, junto a `local TRIGGER_HOLD = {`)

> Quanto tempo cada trigger ocupa. Mudanca de ESTADO (buff/debuff/espinhos)
> ganha o beat longo; numero que so sobe e desce ganha o curto.

## L1072-1073 (em `EffectSystem:processTriggerEffect`, junto a `Sfx.play("healShimmerSoft")`)

> Game feel v1: lifesteal SOA (shimmer discreto) e o joker fonte tica.
> healShimmerSoft: alias registrado mais baixo (opts.volume mutaria o base).

## L1079-1098 (em `EffectSystem:processTriggerEffect`, junto a `local fired = true`)

> ESPINHOS VIRARAM ESTADO (Set/2026, pedido do dono: "esse dano nao
> deveria ser so quando o inimigo atacar?"). ANTES: jogar a carta ja
> causava o dano na hora — o reflexo acontecia mesmo que o inimigo
> nunca atacasse, e a palavra "refletir" era mentira. AGORA (padrao
> StS / Flame Barrier): a carta ARMA o buff "thorn" no jogador, que
> dura o turno; quem dispara o dano e o GOLPE do inimigo
> (Game:_enemyStrikeChain -> EffectSystem:fireThornReflect), no
> instante proprio dele. O buff expira no Player:onTurnStart seguinte.
>
> P2.3 preservado: thorn cuja FONTE e JOKER ARMA no maximo 1x por
> turno POR JOKER (flag resetada em Game:drawForTurn) — o teto de
> stacks por turno continua o mesmo de antes do rebalance. Thorn de
> CARTA (context.sourceCard) continua acumulando POR CARTA jogada.
> A chave e o ID, nao a INSTANCIA (Set/2026). Duas razoes: (1) quem
> armou precisa ser reencontrado la no `fireThornReflect`, turno do
> inimigo adiante, pra PROCAR — e `rebuildJokerSlots` recria as
> instancias (abrir o Gerenciador de Coringas no meio da luta basta),
> deixando a referencia velha orfa; (2) pela mesma orfandade, o teto
> P2.3 se reabria sozinho e o joker armava espinhos duas vezes no
> mesmo turno. Id e estavel; instancia nao.

## L1120-1123 (em `EffectSystem:processTriggerEffect`, junto a `if game.player and game.player.addOrb then`)

> P2.1 (Jul/2026, rebalance v2 — engine flagada #1): motor de orbes
> (mage_electrodynamics). Canaliza 1 orbe do tipo declarado no inicio
> de cada turno. Espelho de strength_per_turn; overflow FIFO evoca o
> orbe mais antigo, igual ao channel_orb de carta.

## L1125-1130 (em `EffectSystem:processTriggerEffect`, junto a `self:_stepChannelOrb(game,`)

> Mesma rotina da carta (_stepChannelOrb): abrir vaga e canalizar
> sao passos distintos. Aqui o sink e nil DE PROPOSITO — este
> trigger JA roda dentro do beat "trigger.turn_start.channel_per_turn"
> (hold ORB); empurrar pra fila agora jogaria o orbe pro fim do
> turno. Quando ha overflow, o extendCurrent de _stepChannelOrb
> estica ESTE beat, que e o instante certo.

## L1138 (em `EffectSystem:processTriggerEffect`, junto a `game.player:gainStrength(v)`)

> Demon Form: Força cumulativa por turno (identidade StS clássica).

## L1150-1151 (em `EffectSystem:processTriggerEffect`, junto a `game.player:loseHealth(v)`)

> Custo auto-infligido: HP direto, SEM passar pela armadura (senão
> o downside de cartas tipo Berserk é fictício — auditoria F0).

## L1157-1158 (em `EffectSystem:processTriggerEffect`, junto a `local n = math.max(1, v)`)

> Joker que compra cartas extra no início do turno (ex: joker_004
> "Bobo da Corte", mage_creative_ai). value = quantas cartas.

## L1167-1168 (em `EffectSystem:processTriggerEffect`, junto a `if context and context.target and context.target.addStatusEffect then`)

> Joker que aplica debuff a cada ataque (ex: rogue_envenom poison-on-hit).
> effect.debuffName = "poison"/"weak"/"vulnerable"

