---
name: code_notes/tools/test_beats.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_beats.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_beats.lua`

Origem: `tools/test_beats.lua` em `7dbdb60d` (47 de 64 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local TK = require("tools.testkit")`)

> tools/test_beats.lua
> TRAVA DO RITMO DO COMBATE (Set/2026).
>
> POR QUE ESTE TESTE EXISTE
> O dono jogou e disse: "muitas coisas so saem acontecendo e fica dificil de
> entender e acompanhar". O defeito nao era visual — era TEMPO e ORDEM: dano,
> debuff no inimigo, proc de coringa, pulso de orbe e compra de carta caiam no
> mesmo instante. A correcao foi transformar o combate numa fila de BEATS
> (src/systems/CombatBeats.lua), um acontecimento por instante, cada um
> segurando o proximo.
>
> "Nao crashou" nao prova nada aqui. Os asserts abaixo checam a ORDEM CAUSAL
> executada (CombatBeats grava o trace) e o BLOQUEIO (nada anda na frente do
> que ainda nao aconteceu). Se alguem reverter o mecanismo, cada bloco falha:
> 1. beat sem bloqueio  -> "um beat por vez" cai (tudo roda no 1o frame)
> 2. espinhos na jogada -> "espinhos NAO ferem ao jogar" cai
> 3. reflexo removido   -> "o golpe do inimigo cobra os espinhos" cai
> 4. ordem do turno     -> os indices do trace saem fora de ordem
> 5. orbes agregados    -> "um pulso por orbe" cai (1 beat em vez de 3)
> 6. heal_multiplier mudo -> "coringa de cura tica" cai
>
> love . test_one test_beats
> love . test_all

## L31 (em `M`, junto a `local function at(label)`)

> Indice do beat `label` no trace (nil se nunca rodou).

## L72-74 (em `M.run`, junto a `CombatBeats.clear()`)

> ========================================================================
> 1. A FILA SEGURA: um beat por vez
> ========================================================================

## L90-95 (em `ran`, junto a `ran = {}`)

> SEMANTICA MEDIDA: push joga no FIM da fila mesmo chamado de dentro de um
> beat. E por isso que resolucao de carta e turno do inimigo sao escritos
> como CADEIA (o beat corrente empurra os passos dele e, por ultimo, o elo
> seguinte) — pre-agendar carta 1 e carta 2 juntas jogaria os efeitos da
> carta 1 pra depois da carta 2. Este assert existe pra que a regra nao
> seja "descoberta" de novo na marra.

## L107-111 (em `ran`, junto a `local g = TK.newRunGame("warrior")`)

> ========================================================================
> 2. ESPINHOS: a carta ARMA, o GOLPE DO INIMIGO cobra
> (pedido do dono: "esse dano nao deveria ser so quando o inimigo
> atacar?" — antes o reflexo saia no instante em que a carta era jogada)
> ========================================================================

## L144-153 (em `ran`, junto a `local gj = TK.newRunGame("warrior")`)

> ========================================================================
> 2b. O CORINGA QUE ARMOU ESPINHOS FALA QUANDO ELES SAEM
> (dono: "JOKER BALUARTE ETERNO TAMBEM TEM Q FAZER BARULHO QUANDO
> RECEBER DANO")
>
> Espinhos sao ESTADO: o coringa arma quando a defesa e jogada e o
> reflexo so sai no golpe do inimigo. O proc visual/sonoro existia so no
> ARMAR, entao o lendario ficava MUDO no instante em que faz o que
> promete — o inimigo levava dano "do nada".
> ========================================================================

## L164-168 (em `gj.jokerSlots`, junto a `local procs = {}`)

> Espia os procs SEM depender da UI (o tick de verdade mora no
> JokerProcFx, que precisa de geometria de cena).
> Nota: isto ve so o proc DIRETO. O proc do ARMAR sai por outro caminho
> (`procSink` da carta, consumido pelo CombatSequence) e nao passa por
> aqui — o que interessa neste bloco e justamente o do REFLEXO.

## L180 (em `gj.effectSystem.notifyJokerProc`, junto a `gj:processCardInCombat(`)

> P2.3: o MESMO coringa nao arma duas vezes no mesmo turno.

## L187-189 (em `gj.effectSystem.notifyJokerProc`, junto a `gj.jokerSlots = { {`)

> E o teto tem que sobreviver a `rebuildJokerSlots` (abrir o Gerenciador
> de Coringas no meio da luta recria as instancias). Antes a chave era a
> INSTANCIA: com a referencia orfa o teto reabria sozinho.

## L201 (em `effects`, junto a `local procsAntes = #procs`)

> Agora o inimigo ataca: o reflexo sai E o coringa tem que falar.

## L244-256 (em `gk.effectSystem.notifyJokerProc`, junto a `do`)

> ========================================================================
> 2c. O ANDAR NOVO SEMPRE COMECA NA VEZ DO JOGADOR
> (dono: "teve um turno de batalha que o inimigo ja chegou me dando
> dano enquanto andava, antes mesmo de chegar na tela pra eu jogar
> minha carta, ou seja atacou antes de mim")
>
> `endTurn` poe turn="enemy" e SO ENTAO enfileira o pulso dos orbes. Se o
> pulso mata o inimigo, o portao da GameplayScene — que exige
> `enemy:isAlive()` — nunca chama `enemyTurn()`, e quem devolvia a vez era
> o beat final DELE. A vez ficava com o inimigo pela recompensa, pelo
> descanso e pelo mapa; no andar seguinte o portao via inimigo novo VIVO
> + vez do inimigo e mandava ele golpear antes da primeira carta.
> ========================================================================

## L261-262 (em `gk.effectSystem.notifyJokerProc`, junto a `gp.turn = "enemy"`)

> Reproduz a morte que vem DO FIM DO TURNO (e nao das cartas): a vez
> ja passou pro inimigo quando ele cai.

## L276-277 (em `gk.effectSystem.notifyJokerProc`, junto a `local portaoAbriria = (gp.turn == "enemy") and gp.enemy:isAlive()`)

> A condicao exata do portao da cena (GameplayScene): com ela
> verdadeira, o inimigo age antes do jogador.

## L283-285 (em `gk.effectSystem.notifyJokerProc`, junto a `local g3 = TK.newRunGame("warrior")`)

> ========================================================================
> 3. ORDEM CAUSAL DO TURNO DO INIMIGO
> ========================================================================

## L299 (em `gk.effectSystem.notifyJokerProc`, junto a `TK.pump(g3, 0.2)`)

> BLOQUEIO: o turno inteiro NAO pode caber num piscar de olhos.

## L331-333 (em `order`, junto a `local gm = TK.newRunGame("mage")`)

> ========================================================================
> 4. ORBES DO MAGO: um pulso por orbe, cada um no instante dele
> ========================================================================

## L351-353 (em `gm.player.orbs`, junto a `local focusM = gm.player:getBuffStacks("focus") or 0`)

> Valor esperado pela formula CANONICA (a mesma que a UI exibe) — o mago
> comeca com Foco 2 (passiva Conduite), entao cravar "2 de dano" no teste
> seria testar um numero desatualizado em vez da mecanica.

## L381-394 (em `steps`, junto a `local gmc = TK.newRunGame("mage")`)

> ========================================================================
> 4b. CANALIZACAO MULTIPLA: N orbes = N acontecimentos CONTAVEIS, e
> nenhum deles no instante do DANO.
> (pedido do dono, Set/2026, jogando de mago: "Chuva de Meteoros
> canaliza muitas ao mesmo tempo, fica confuso se esta dando dano ou
> se canalizando uma nova")
>
> O BUG QUE ESTE BLOCO PEGA: os beats de orbe ja existiam, mas a
> MUTACAO nao. `player:addOrb` rodava na COLETA -- dentro do beat de
> impacto da carta -- entao a fileira ia de 0 a 3 orbes no MESMO frame
> do numero de dano, e os beats seguintes so tocavam som em cima de
> orbes que ja estavam la. Reverter isso derruba as asserções de
> "a fileira passou por 1 e por 2": com o bug ela pula de 0 pra 3.
> ========================================================================

## L416-417 (em `effects`, junto a `local sawCount, orbsAtImpact, dmgLanded = {}, nil, false`)

> Amostra a cada 1/20s: quantos orbes a FILEIRA mostrava e se o dano ja
> tinha saido. E a leitura do JOGADOR quadro a quadro, nao o estado final.

## L447-451 (em `effects`, junto a `local gof = TK.newRunGame("mage")`)

> ========================================================================
> 4c. OVERFLOW e um TERCEIRO acontecimento, com instante proprio.
> Canalizar com a fileira cheia EXPULSA o mais antigo (evocando-o).
> Sem instante proprio o jogador ve um orbe sumir e nao entende por que.
> ========================================================================

## L465-466 (em `steps`, junto a `t:eq("a fileira NAO muda na coleta, so quando o beat toca",`)

> ANTES de tocar os beats nada pode ter mudado: o estado mora DENTRO do
> acontecimento. Com o bug antigo a fileira ja estaria com o orbe de gelo.

## L487-488 (em `steps`, junto a `local gro = TK.newRunGame("mage")`)

> Controle: com vaga na fileira NAO existe expulsao (o beat condicional
> orb.make_room custa MICRO e nao vira acontecimento).

## L504-507 (em `steps2`, junto a `local gev = TK.newRunGame("mage")`)

> ========================================================================
> 4d. EVOCAR tambem muda o estado DENTRO do beat -- senao o orbe some no
> impacto e o flash cai depois, num slot que ja e de outro orbe.
> ========================================================================

## L523-538 (em `steps3`, junto a `do`)

> ========================================================================
> 4f. CADA PULSO ATERRISSA ONDE O EFEITO DELE ACONTECE -- e com a
> assinatura do ELEMENTO, nao um efeito generico.
> (pedido do dono, Set/2026: "os orbes, quando dao dano ao final do
> turno, eles poderiam refletir algo no inimigo visualmente tambem,
> cada um de uma forma sabe, visual e som")
>
> A METADE PERIGOSA e a que o pedido NAO cobre: gelo da Bloqueio e
> sagrado CURA -- se eles estourarem no inimigo, o jogo ensina que
> defender fere, que e exatamente o defeito dos espinhos (doutrina de
> defeitos, §3: feedback certo no lugar errado deixa o jogador convicto
> do errado). Sombra nem sai da fileira: engorda o proprio orbe.
>
> Como se observa isso num teste headless: interceptando as chamadas de
> som e de burst. E o contrato real -- quem toca o que, e ONDE.
> ========================================================================

## L550 (em `resetLog`, junto a `resetLog()`)

> criar o Game ja toca sons: o coletor precisa existir antes

## L595 (em `sounds`, junto a `g, b = pulseOf("ice", 4)`)

> GELO: da Bloqueio -> marca no JOGADOR, NUNCA no inimigo

## L604 (em `sounds`, junto a `g, b = pulseOf("holy", 6)`)

> SAGRADO: cura -> marca no JOGADOR, NUNCA no inimigo

## L624-625 (em `sounds`, junto a `local uniq, names = {}, {}`)

> CADA UM DE UMA FORMA: os 5 sons tem que ser DIFERENTES entre si.
> (Reverter pra um som generico unico derruba esta asserção.)

## L643-657 (em `sounds`, junto a `do`)

> ========================================================================
> 4g. A FILEIRA TEM QUE SE LER: silhueta = elemento, glifo = unidade.
> (pedido do dono, Set/2026: "esta meio dificil de entender esses
> circulos ali, podemos pensar em algo diferente")
>
> A captura `lovec . preview_battle_hud orbs` mostrou o defeito: cinco
> DISCOS iguais, quatro deles exibindo o mesmo "3", e o icone do
> elemento a ~14px virava mancha. O redesenho deu SILHUETA propria a
> cada elemento e um GLIFO DE UNIDADE ao lado do numero.
>
> O que este bloco trava nao e "esta bonito" -- e que o orbe nao MINTA:
> a unidade que ele anuncia tem que ser a que o EffectSystem de fato
> aplica. Se alguem mudar o pulso do gelo pra dano e esquecer o glifo,
> a fileira passa a ensinar causalidade errada em silencio.
> ========================================================================

## L662-667 (em `TYPES`, junto a `local byPath, byPixels = {}, {}`)

> (a) cada elemento tem a SUA gema, e nenhuma se repete.
> Set/2026: a arte era silhueta vetorial e virou gema pixel
> (assets/sprites/orbs/) -- o dono reprovou o contorno vazio, "meio
> feio", e tinha razao: wireframe nao e objeto. O que o teste trava nao
> e o material, e a REGRA que sobreviveu aos dois: cinco elementos,
> cinco leituras distintas.

## L681-683 (em `TYPES`, junto a `if info then`)

> Arte NATIVA no tamanho de uso: 48x48. Se alguem trocar por um
> PNG maior, ele seria reduzido em tempo de desenho -- que e
> exatamente o defeito que matou o icone DENTRO do orbe.

## L691-692 (em `TYPES`, junto a `local sig = 0`)

> Assinatura esparsa: pega dois arquivos IGUAIS com nomes
> diferentes, que o teste de caminho sozinho deixaria passar.

## L750-752 (em `b`, junto a `local EffectSystem2 = require("src.systems.EffectSystem")`)

> (c) o numero nao pode ser mentira: SOMBRA nao pulsa, entao o que ela
> mostra e o valor ACUMULADO (o que dobra ao evocar), nunca o zero
> do pulso.

## L764-765 (em `darkOrb`, junto a `local vFocus = OrbRow.readout({ type = "lightning", value = 4 }, 2, "pulse")`)

> (d) Foco entra na conta que a fileira exibe (senao o numero na tela
> diverge do dano que sai).

## L771-780 (em `darkOrb`, junto a `do`)

> ========================================================================
> 4h. O MAGO NAO ENVENENA NINGUEM (ponta a ponta, numa run de verdade)
> Queixa do dono, jogando: "por que o inimigo esta ficando com veneno
> na minha run de mago? nao faz muito sentido". Estava certo — o ramo
> `fire` de _evokeOrbEffect aplicava `poison` como atalho.
>
> Os blocos de tools/test_effects_full cobrem a unidade; ESTE cobre a
> CADEIA inteira, que e onde o jogador vive: evocar fogo -> queimadura
> entra -> turno do inimigo -> o beat do DoT tica -> a vida cai.
> ========================================================================

## L794 (em `gf.player.orbs`, junto a `local hpBefore = gf.enemy.health`)

> O turno do inimigo tica o DoT: a queimadura tem que DOER.

## L797-799 (em `gf.player.orbs`, junto a `gf.enemy.nextIntent = "buff"`)

> `buff`, nao `defend`: defender da armadura ANTES do beat do DoT e a
> armadura absorveria a queimadura inteira -- o teste passaria a medir
> a armadura em vez do DoT.

## L815-827 (em `gf.player.orbs`, junto a `do`)

> MORRER QUEIMADO tem que encenar a morte igual a morrer envenenado: no
> beat do tick que matou, e nao tres passos adiante com a barra zerada e o
> monstro em pe. (`_applyDot` -> `_markDeathIfCrossed` -> o `enemy.dot`
> chama `announceDeathIfPending`, que reivindica o instante corrente.)
>
> MEDIDO, pra ninguem se enganar: este bloco continua VERDE se alguem
> tirar o `_markDeathIfCrossed` do `_applyDot` -- a REDE de
> announceDeathIfPending ("morto e nao encenado conta como pendente")
> recolhe a morte assim mesmo. Quem guarda a marcacao e a asserção unitaria
> `morrer QUEIMADO marca a morte` em tools/test_effects_full.lua. Os dois
> testes cobrem coisas diferentes: aqui, que a morte por queimadura E
> encenada e cai no beat certo; la, que a marcacao existe -- que e o que
> mantem a morte correta quando a checagem nao acontece no mesmo beat.

## L851-854 (em `gf.player.orbs`, junto a `do`)

> ========================================================================
> 4e. O CASO REAL: quantas cartas do catalogo canalizam em rajada?
> Asserção de CONTAGEM pra nao passar verde por nao ter exercitado nada.
> ========================================================================

## L881-884 (em `gf.player.orbs`, junto a `local gj = TK.newRunGame("warrior")`)

> ========================================================================
> 5. CORINGA QUE MUDA UM NUMERO TEM QUE TICAR
> (Abraco Sombrio: defense_bonus ticava, heal_multiplier era MUDO)
> ========================================================================

## L897 (em `procs`, junto a `do`)

> Cobertura: TODO tipo continuo de coringa do catalogo empurra proc.

## L915-917 (em `gAll.jokerSlots`, junto a `local gc = TK.newRunGame("rogue")`)

> ========================================================================
> 6. RESOLUCAO DE CARTA: impacto > coringas > efeitos > dissolve > proxima
> ========================================================================

## L920-921 (em `gAll.jokerSlots`, junto a `local atk = {`)

> Carta de ataque com efeito secundario (veneno): o debuff no inimigo tem
> que acontecer DEPOIS do dano, num instante proprio.

## L945-949 (em `effects`, junto a `local ge = TK.newRunGame("warrior")`)

> ========================================================================
> 7. ENFURECIDO: o inimigo cruzar os 30% de vida e um ACONTECIMENTO
> (era mudo: +50% de dano permanente sem toast, som, pill ou instante —
> acontecia em TODA batalha e mudava a conta de dano do jogador)
> ========================================================================

## L980 (em `bigHit`, junto a `t:eq("o intent ja telegrafado NAO fica mais forte",`)

> INVARIANTE (CLAUDE.md 6): o golpe JA anunciado no HUD nao muda.

## L994 (em `bigHit`, junto a `local ge2 = TK.newRunGame("warrior")`)

> checkpoint no turno do inimigo: fonte fora da carta nunca fica muda

## L1015-1018 (em `bigHit`, junto a `do`)

> ========================================================================
> 8. CONTRATO: todo trigger de processTriggerEffect esta em TRIGGER_OF
> (esquecer de registrar = o trigger nunca mais dispara, em silencio)
> ========================================================================

