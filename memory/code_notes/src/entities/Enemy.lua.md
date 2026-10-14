---
name: code_notes/src/entities/Enemy.lua
description: Comentários com decisão/regra/histórico colhidos de src/entities/Enemy.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/entities/Enemy.lua`

Origem: `src/entities/Enemy.lua` em `7dbdb60d` (31 de 45 blocos de comentário tinham marcador de decisão/regra/histórico).

## L19-21 (em `Enemy:new`, junto a `instance.statusEffects = {}`)

> statusEffects: lista de debuffs { name, duration, stacks? }
> Semantica: duration e em TURNOS (nao segundos). O decremento acontece
> em onTurnEnd (apos turno do inimigo), nao em update(dt).

## L25-27 (em `instance.disp`, junto a `instance:setKit(kitId or "generic")`)

> F1 gameplay-overhaul: o inimigo TELEGRAFA a ação do próximo turno.
> O kit (src/data/enemies.lua) decide QUAIS golpes ele tem; sem kit, o
> "generic" reproduz os quatro intents de antes (testes, modo clássico).

## L32-40 (em `instance.disp`, junto a `function Enemy:setKit(kitId)`)

> ===== Kit de golpes (Out/2026, src/data/enemies.lua) =====
> Antes havia UMA tabela de intents dividida pelas 21 criaturas. Agora cada
> criatura tem o seu kit: golpes nomeados, multi-golpe, debuffs no jogador,
> carga telegrafada, invocação, fases. Trocar o kit zera o histórico de
> golpes e rola o intent de novo (é o "nascimento" da criatura).
>
> O hpMul/dmgMul do kit NÃO mora aqui: quem escala vida/dano é o
> EnemyRoster.spawn, que sabe que está criando um inimigo novo (setKit pode
> ser chamado em inimigo de teste já montado).

## L44 (em `Enemy:setKit`, junto a `print("[Enemy] kit desconhecido '" .. tostring(kitId) .. "' — usando 'generic'")`)

> Fallback silencioso é proibido (CLAUDE.md): avisa e usa o legado.

## L58-59 (em `self._moveHistory`, junto a `self.maxArmor = math.max(20, math.floor(self.damage * 2.5))`)

> Armadura do inimigo escala com o dano dele: o teto fixo de 20 virava
> "nada" no ato 6 (golpe do jogador passa de 100).

## L106-112 (em `Enemy:_streak`, junto a `function Enemy:_chooseMove()`)

> Escolhe o PRÓXIMO golpe. Ordem de precedência:
> 1. golpe forçado (carga -> golpe carregado)
> 2. abertura da fase recém-aberta / abertura do kit (1º turno)
> 3. golpe de cadência fixa (`every`)
> 4. sorteio ponderado (stream "enemy"), respeitando minTurn, maxRow e a
> PRESSÃO GARANTIDA: nunca dois turnos seguidos sem dano (senão o
> inimigo "stalla" e devolve o problema que o F1 matou).

## L179-188 (em `out`, junto a `function Enemy:rollIntent(player)`)

> CONGELA o golpe no momento do anúncio (auditoria Jul/2026, anomalia
> "escudo furado"): Fúria/buff mutavam self.damage ENTRE o telegraph e a
> execução — o golpe batia mais forte que o número que o jogador viu. Todo
> número do intent (dano por golpe, golpes, bloqueio, cura, força) é fixado
> AQUI; buffs rolados depois só valem no PRÓXIMO intent. Weak do inimigo
> continua por cima (só reduz).
>
> `player` (opcional) congela a Vulnerabilidade do jogador junto: o golpe só
> é ampliado se o jogador JÁ estava vulnerável no anúncio (e ainda estiver
> na execução) — o número no HUD nunca é menor que o golpe.

## L223-226 (em `intent`, junto a `self:refreshIntentVisibility()`)

> NÉVOA (Out/2026): quanto deste anúncio o HUD pode mostrar. Decidido
> AQUI, uma vez por intent, e nunca mais mexido até o próximo anúncio —
> o número congelado continua sendo o que acontece (intentHitDamage não
> olha isto). Ver src/systems/IntentVisibility.lua.

## L231-232 (em `intent`, junto a `function Enemy:veilSpec()`)

> ===== Visibilidade do intent (névoa do bioma / véu / revelação) =====
> Véu declarado no kit (ou na fase corrente): { level, chance }.

## L240-242 (em `Enemy:veilSpec`, junto a `function Enemy:refreshIntentVisibility()`)

> (Re)resolve a visibilidade do intent CORRENTE. Chamado no anúncio e por
> RunModifiers.decorateEnemy (o 1º golpe rola dentro do setKit, antes de o
> inimigo saber em que bioma nasceu).

## L255-256 (em `Enemy:getIntentVisibility`, junto a `function Enemy:revealIntent(turns)`)

> Revela o intent de agora e os `turns - 1` anúncios seguintes (carta de
> Revelar). `turns` nil/1 = só o corrente.

## L264-265 (em `Enemy:revealIntent`, junto a `function Enemy:revealNextIntent(turns)`)

> Revela só os PRÓXIMOS `turns` anúncios (pulso do orbe de Raio: acontece no
> fim do turno do jogador, quando o intent corrente já vai ser executado).

## L270-275 (em `Enemy:revealNextIntent`, junto a `function Enemy:getKnownIntent(player)`)

> O intent como o JOGADOR tem direito de ver — a única leitura que piloto e
> UI podem fazer quando a névoa está fechada. Nunca inclui número escondido:
> full       → o próprio intent congelado (mesma tabela de getIntent)
> type_only  → kind, pierce, debuffs (nomes) e flags; números = nil
> hidden     → { kind = "unknown" }
> `visibility` vem sempre preenchido.

## L297-299 (em `known.debuffs`, junto a `function Enemy:getKnownIncomingDamage(player)`)

> Dano total que o jogador PODE saber que vem: número só com visibilidade
> cheia; nil quando a névoa esconde (o piloto estima por
> expectedDamagePerTurn, como um jogador faria).

## L305-306 (em `Enemy:getKnownIncomingDamage`, junto a `function Enemy:forceIntent(moveId, player)`)

> Anuncia um golpe ESPECÍFICO do kit (testes e ferramentas de captura).
> Passa pelo mesmo congelamento do rollIntent.

## L312-315 (em `Enemy:forceIntent`, junto a `function Enemy:getIntent()`)

> Intent corrente. Se alguém sobrescreveu nextIntent/nextIntentDamage por
> fora (testes antigos montam o cenário assim), sintetiza o golpe legado
> correspondente — o contrato antigo (attack/strong ×1.6/defend/buff +2)
> continua valendo pra quem escreve só esses dois campos.

## L336-337 (em `synth`, junto a `function Enemy:intentHitDamage(player)`)

> Dano de UM golpe do intent, como vai acontecer (e como o HUD mostra):
> weak do inimigo reduz; vulnerável do jogador amplia só se congelado.

## L349-350 (em `Enemy:intentHitDamage`, junto a `function Enemy:getIncomingDamage(player)`)

> Dano TOTAL previsto do intent (todos os golpes) — o que o piloto e
> qualquer preview devem ler. Não desconta Bloqueio.

## L356-358 (em `Enemy:getIncomingDamage`, junto a `function Enemy:expectedDamagePerTurn()`)

> Dano MÉDIO por turno do kit ativo (média ponderada dos golpes sorteáveis,
> golpes × multiplicador × dano atual). Só pra estimar o FUTURO (piloto de
> balanceamento); o turno corrente usa o intent congelado.

## L372-377 (em `Enemy:expectedDamagePerTurn`, junto a `function Enemy:getIntentPreview(player)`)

> Valor de preview do intent pro HUD: (kind, número, intent).
> golpe com dano       → dano POR GOLPE (weak/vulnerável aplicados)
> defend               → armor que vai ganhar
> buff                 → +dano permanente
> heal                 → cura
> debuff/charge/summon → 0 (o HUD desenha ícone, sem número)

## L418-420 (em `Enemy:tickRegen`, junto a `function Enemy:_checkPhase()`)

> FASES (Rainha do Eclipse): cruzar a fração de vida troca o kit e sobe o
> dano. Mesmo contrato do ENFURECIDO: a entidade MARCA (`_pendingPhase`), o
> Game ENCENA (Game:_announcePhaseIfPending). O intent já anunciado NÃO muda.

## L438-451 (em `self._moveHistory`, junto a `function Enemy:_markDeathIfCrossed(wasAlive)`)

> MORRER E UM ACONTECIMENTO, NAO UM ESTADO QUE ALGUEM PERCEBE DEPOIS
> (Set/2026, queixa do dono: "em alguns cenarios o mob nao esta tendo a
> animacao de morrer, cair no chao").
>
> A causa era a mesma do ENFURECIDO: so UM caminho de dano (o da carta de
> ataque, em Game:processCardInCombat) sabia detectar a morte e disparar a
> animacao. Magia, pulso/evocacao de orbe, veneno e reflexo de espinhos
> levavam a vida a zero na aritmetica e ninguem avisava ninguem — a tela de
> espolios abria por cima de um inimigo em pe.
>
> Agora a VIRADA vivo->morto e marcada AQUI, no unico lugar por onde a vida
> do inimigo pode cair, seja qual for a fonte. O Game consome `_pendingDeath`
> (Game:announceDeathIfPending) e transforma em beat. Mesmo contrato do
> `_pendingEnrage`: a entidade MARCA, o Game ENCENA.

## L456-457 (em `Enemy:_markDeathIfCrossed`, junto a `self:_checkPhase()`)

> Mesmo ponto único de queda de vida: a troca de FASE também é marcada
> aqui (dano direto e DoT passam por este funil).

## L463 (em `Enemy:takeDamage`, junto a `if self:hasStatus("vulnerable") then`)

> "vulnerable": dano recebido +50%. Aplica antes de armor.

## L472-487 (em `Enemy:takeDamage`, junto a `if self.health < self.maxHealth * 0.3 then`)

> ENFURECIDO (Set/2026): abaixo de 30% de vida o inimigo passa a causar
> +50% de dano, PERMANENTE. Isso sempre existiu e era MUDO — acontecia em
> toda batalha, mudava a conta de dano que o jogador estava fazendo, e
> nada aparecia na tela. Agora o CRUZAMENTO do limiar e um acontecimento:
> * vira status REAL `enraged` (pill + tooltip no EnemyHud);
> * levanta `_pendingEnrage`, que o Game consome pra dar o INSTANTE
> proprio (beat bloqueante com rugido e numero).
> O nome e `enraged`, NAO `fury`: `fury` ja e o anti-stall do turno 8+
> (Game:enemyTurn), outra mecanica, com pill e tooltip proprios.
> O recalculo de `damage` continua acontecendo a CADA dano (e nao so na
> virada) de proposito: `baseDamage` cresce com a Furia, e recalcular
> mantem o x1.5 sobre a base atual — mexer nisso seria rebalancear.
> INVARIANTE PRESERVADA (CLAUDE.md 6): `nextIntentDamage` fica congelado
> no anuncio, entao o golpe JA telegrafado nao muda — a furia so vale do
> proximo intent em diante. Isso separa naturalmente "ele enfureceu" de
> "ele bate mais forte", que e exatamente o que ajuda a leitura.

## L491 (em `Enemy:takeDamage`, junto a `self.damage = math.floor(self.baseDamage * 1.5)`)

> floor: sem ele o HUD (e o dano real) mostrava "30.5" (autoplay A2)

## L526-527 (em `Enemy:update`, junto a `end`)

> NOTA: decremento de duracao de statusEffects nao e mais feito aqui (era em dt,
> o que fazia poison sumir em segundos). Agora e por turno via onTurnEnd.

## L537-538 (em `Enemy:performAttack`, junto a `local dmg = self.nextIntentDamage or self.damage`)

> Executa o valor CONGELADO no anuncio do intent (nunca mais forte
> que o numero que o jogador viu no HUD).

## L579-588 (em `Enemy:getStatusStacks`, junto a `function Enemy:_applyDot(dmg)`)

> Aplica um DoT (dano por turno) com a aritmetica dos venenos: bypass do
> takeDamage de proposito, porque DoT e dano FIXO e nao passa pelo
> multiplicador de Vulneravel. A armadura absorve e e consumida.
> `_markDeathIfCrossed` e obrigatorio: esta aritmetica crua nao passa pelo
> takeDamage, e sem ele morrer de DoT volta a nao ter animacao de morte.
>
> DoT IGNORA o Bloqueio (Out/2026, padrão StS): o tick cai no fim do turno do
> inimigo, logo depois de ele DEFENDER — com a armadura absorvendo, todo turno
> de defesa engolia o veneno inteiro e era o que mais travava o ladino no fim
> do jogo (mesma regra do DoT no jogador, Player:tickDebuffDots).

## L597-602 (em `Enemy:_applyDot`, junto a `function Enemy:onTurnEnd()`)

> Chamado pelo Game no final do turno do inimigo.
> Processa os DoTs (VENENO e QUEIMADURA), decrementa duration, limpa expirados.
> Retorna (danoVeneno, danoQueimadura) — DOIS numeros porque sao DOIS status
> diferentes: o veneno e do ladino, a queimadura e do fogo do mago, e somar os
> dois num numero so seria a mesma confusao que criou o `burn` (Set/2026).
> O 1o retorno continua sendo o veneno: chamadas antigas nao mudam.

## L614-615 (em `Enemy:onTurnEnd`, junto a `self:_applyDot(poisonDmg)`)

> Em sequencia, nao somados: cada DoT tem sua propria travessia do limiar
> de morte.

