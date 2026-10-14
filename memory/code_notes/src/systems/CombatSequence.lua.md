---
name: code_notes/src/systems/CombatSequence.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CombatSequence.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CombatSequence.lua`

Origem: `src/systems/CombatSequence.lua` em `7dbdb60d` (37 de 58 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local Sfx = require("src.systems.Sfx")`)

> src/systems/CombatSequence.lua
> Coreografa o combate via EventManager. Substitui CombatAnimationSystem.lua
> (530 LOC → ~180 LOC).
>
> PRINCÍPIO-CHAVE: cartas voam pelo PRÓPRIO renderer (Card:draw via setTargetPos).
> Herdam sombras dinâmicas, warp do mesh, juice, ambient tilt, dissolve.
> Nada de `love.graphics.draw(card.image)` flat que o sistema antigo fazia.
>
> PIPELINE (Set/2026): o VOO é agendado em tempo absoluto na fila "base"
> (animação pura); a RESOLUÇÃO é uma cadeia de BEATS (src/systems/CombatBeats)
> em que cada acontecimento ocupa um instante e segura o próximo:
> cartas pousam → carta 1 impacta → jokers dela ticam → efeitos secundários
> dela (veneno/cura/orbe/espinhos) → dissolve → carta 2 → ... → fim
>
> API pública compatível com CombatAnimationSystem:
> :startCombat(cards, onComplete, onCardProcessed)
> :update(dt)  :draw()  :isBlocking()  :isAnimating()

## L25-29 (junto a `local CombatBeats = require("src.systems.CombatBeats")`)

> O RITMO mora todo em CombatBeats.HOLD (tabela unica, comentada). O antigo
> PROC_TICK local virou CombatBeats.HOLD.JOKER_PROC; o stagger/procHold que
> ESTICAVA o agendamento morreu com a fila de beats: agora a proxima carta
> literalmente espera a anterior terminar, em vez de reservar tempo por
> estimativa (EffectSystem:predictJokerProcs nao pauta mais nada).

## L35-37 (em `CombatSequence`, junto a `local Moveable = require("engine.Moveable")`)

> DEBUG FEEL (temporário, caça "carta parada no impacto" — mesmo método do
> RDBG que achou a RAIZ dos espólios): loga em feel_debug.log no save dir o
> que o DRAW recebe de hop/juice/swell na sessão REAL do jogador.

## L52 (em `self.flyingCards`, junto a `self.damageNumbers = {}`)

> Damage numbers flutuantes (apenas sobem+fade; não é MessageSystem porque é spatial).

## L58-60 (em `self.timings`, junto a `impactHold      = 0.35,`)

> v3.1: 0.15→0.35 — a carta SEGURA no centro tempo suficiente pra
> reação física dela ser LIDA (0.15s junto de shake+partículas era
> invisível — "tão totalmente estáticas", feedback do dono).

## L68-78 (em `self.timings`, junto a `function CombatSequence:startCombat(cards, onComplete, onCardProcessed)`)

> Compatibilidade: startCombat(cards, onComplete, onCardProcessed)
>
> DUAS LINHAS DO TEMPO (Set/2026):
> 1. VOO — animacao pura, agendada na fila "base" em tempo ABSOLUTO. Todas
> as cartas caem na mesa quase juntas ("mao na mesa", modelo Balatro).
> 2. RESOLUCAO — a espinha CAUSAL, na fila de beats (CombatBeats). Um
> acontecimento por instante, cada um segurando o proximo:
> carta 1 impacta > jokers dela ticam um a um > efeitos secundarios
> dela (veneno, cura, orbe, espinhos) um a um > dissolve > carta 2...
> A cadeia e empurrada DE DENTRO do beat anterior (regra do CombatBeats):
> so assim os passos dinamicos de uma carta entram antes da proxima.

## L85-86 (em `CombatSequence:startCombat`, junto a `self._onComplete = onComplete`)

> Guardado pra REDE do watchdog (ver :update): se a cadeia quebrar no meio,
> alguem precisa poder chamar _finish com o callback certo.

## L89-96 (em `CombatSequence:startCombat`, junto a `local pending = {}`)

> CÓPIA, nunca a lista viva do chamador. `Game:startCombat` passa
> `self.selectedCards` direto, e a resolução dura SEGUNDOS agora que cada
> acontecimento tem seu beat. Nessa janela o jogador clicar numa carta da
> mão fazia `table.insert` na MESMA tabela que esta função percorre: a
> carta nova existia em `cards[idx]` mas não em `geom[idx]` (montado uma
> vez, lá em cima) e o combate morria com "attempt to index local 'g'".
> Desselecionar era pior e silencioso: `table.remove` desalinhava os
> índices e a geometria passava a pertencer a outra carta.

## L125-128 (em `self.flyingCards`, junto a `local function scheduleAt(delay, fn)`)

> Helper: agenda ANIMACAO em delay absoluto (nao-blocking, paralelo) na
> fila base. EM.after cria eventos BLOCKING que serializam a fila; pra
> keyframes visuais precisamos de tempo ABSOLUTO. blockable=false porque
> Card:start_dissolve enfileira um ease BLOQUEANTE na base.

## L153-154 (em `geom`, junto a `local pitch = math.min(1.4, 0.95 + (launchPitchIdx - 1) * 0.06)`)

> SFX dedicado de "jogar carta" no lancamento (whoosh), antes do
> impacto (sword/armor). Pitch crescente por carta no combo.

## L167 (em `geom`, junto a `local function removeFlying(card)`)

> ===== Linha 2: RESOLUCAO (cadeia causal) =====

## L178-179 (em `resolveCard`, junto a `CombatBeats.push("combat.settle", nil, self.timings.dissolveTime * 0.6)`)

> Ultima carta dissolvendo: o combate so "termina" quando ela some,
> senao _finish arranca as cartas da tela no meio do dissolve.

## L188-191 (em `resolveCard`, junto a `print("[CombatSequence] sem geometria para a carta " .. tostring(idx)`)

> Não deveria acontecer (a lista é copiada e `geom` cobre todos os
> índices). Se acontecer, encerra a cadeia em vez de derrubar o
> jogo no meio do turno — mas AVISA, porque é sintoma de alguém ter
> mexido na lista depois do layout.

## L206-207 (em `resolveCard`, junto a `local sink = {}`)

> `sink` coleta os efeitos SECUNDARIOS da carta (Game os empurra
> ali em vez de executar tudo no mesmo instante do dano).

## L212-215 (em `sink`, junto a `if card.type == "attack" then`)

> Game feel v2/v3.1: reacao FISICA por tipo no impacto — AMPLA e
> LONGA o bastante pra sobreviver ao ruido do momento (shake de
> tela + particulas + numero acontecem juntos e mascaravam a
> reacao curta). Cada tipo ganha um SEGUNDO pulso de assentamento.

## L217-218 (em `sink`, junto a `if card.hop_up then card:hop_up(44, 0.50) end`)

> v3.2: pulo CHUNKY (estala-segura-cai-quica) + pop de escala
> (swell curto le melhor que vibracao de 50rad/s) + tilt.

## L223-224 (em `sink`, junto a `if card.shove_x then card:shove_x(nil, 0.55) end`)

> v3.3: a defesa APARA o golpe — checa pro lado torta (shove
> horizontal + tilt), segura, e volta com um TIQUE de mola.

## L234-235 (em `sink`, junto a `scheduleAt(0.16, function()`)

> 3a camada sonora do efeito (cast no voo -> chime no impacto
> > resolve fechando). Ver _playLaunchSfx/_playImpactSfx.

## L243-245 (em `sink`, junto a `for k, proc in ipairs(result and result.jokerProcs or {}) do`)

> Procs de joker (Balatro): cada joker que contribuiu tica em
> SEQUENCIA — juice no slot + popup do valor + som com pitch
> crescente. UM BEAT CADA: o jogador conta os jokers.

## L253-254 (em `sink`, junto a `CombatBeats.pushAll(sink)`)

> Efeitos secundarios coletados no sink (veneno, cura, orbe,
> espinhos armados, gatilhos de joker): um acontecimento por vez.

## L257-259 (em `sink`, junto a `CombatBeats.push("card.dissolve", function()`)

> A carta so queima DEPOIS de tudo que ela causou ter acontecido
> (causalidade Balatro: o jogador ve o joker reagir com a carta
> ainda na tela).

## L285-286 (em `self.damageNumbers`, junto a `for _, card in ipairs(self.flyingCards) do`)

> flyingCards pode ainda ter resíduo se dissolve não completou — limpa.
> Se houver cartas sobrando, marca como removidas pra CardParticles fazer cleanup.

## L294-296 (em `self.flyingCards`, junto a `function CombatSequence:_playLaunchSfx(card, pitch)`)

> ============================================================================
> IMPACT HANDLERS
> ============================================================================

## L298-299 (em `self.flyingCards`, junto a `function CombatSequence:_playLaunchSfx(card, pitch)`)

> SFX de lançamento da carta (whoosh de "jogar"), tocado na Fase 1 antes do
> impacto. Só attack/defense têm som dedicado; joker/effect já soam no impacto.

## L314-315 (em `CombatSequence:_playImpactSfx`, junto a `if CardFeel.playImpact(card, pitch) then return end`)

> Game feel v1: tema da carta (fire/ice/poison/...) tem SOM PRÓPRIO —
> a Bola de Fogo soa fogo, não espada. Sem tema → identidade física.

## L326-328 (em `CombatSequence:_playImpactSfx`, junto a `Sfx.play("effectChime", opts)`)

> 2ª camada do efeito: chime de ativação (a 3ª, effectResolve, é
> agendada no impacto). Cartas de efeito TEMÁTICAS já retornaram
> no CardFeel.playImpact acima — aqui é o fallback sem tema.

## L336-337 (em `CombatSequence:_spawnImpactParticles`, junto a `local theme = CardFeel.themeOf(card)`)

> Game feel v1: burst com a paleta/física do TEMA (fogo sobe laranja,
> gelo cai azul, veneno borbulha verde). Sem tema → presets por tipo.

## L347-348 (em `CombatSequence:_spawnImpactParticles`, junto a `local t = card.type`)

> Presets já registram a instância no ParticlesManager (spawn). Caller só
> precisa invocar — o retorno é a instância pra opcional :fade/:remove.

## L372-373 (em `CombatSequence:_handleResult`, junto a `CardFeel.burstAtEnemy(CardFeel.themeOf(card) or "physical",`)

> O golpe estoura NO INIMIGO (StS): burst temático no sprite dele —
> o jogador vê o fogo/raio/veneno CHEGANDO, não só saindo da carta.

## L397-399 (em `CombatSequence:_addDamageNumber`)

> ============================================================================
> UPDATE / DRAW
> ============================================================================

## L401-405 (em `CombatSequence:_addDamageNumber`, junto a `local STARVE_TIMEOUT = 0.75`)

> Quanto tempo a cadeia pode ficar SEM NENHUM beat pendente antes de a rede
> declarar que ela quebrou. Mid-cadeia isso e impossivel por construcao: cada
> beat empurra o proximo elo no INICIO da propria execucao (trigger "before"),
> entao sempre ha um beat na fila. Fila vazia com o combate ativo = alguem
> limpou a fila ou um elo nao foi empurrado.

## L409-416 (em `CombatSequence:update`, junto a `if self.active then`)

> ===== REDE: o combate NAO PODE ficar ativo pra sempre =====
> `isBlocking()` e `self.active or CombatBeats.isBusy()`, e o jogo inteiro
> espera por ele: turno do inimigo, espolios, vitoria, botoes da mao. Se a
> cadeia quebrar, o jogador fica com a tela travada e os botoes cinzas —
> foi o que aconteceu ao matar o boss (Set/2026). Morte do inimigo no meio
> da resolucao e caminho COMUM: nao pode depender de tudo dar certo.
> Travar o jogo e muito pior que encerrar cedo — mas encerrar em silencio
> tambem e proibido (CLAUDE.md), entao a rede AVISA.

## L439-440 (em `CombatSequence:update`, junto a `card.isHovered = false`)

> Hover é falso durante voo (clique não deve selecionar carta no ar).
> updateMouse ainda roda no main pra ambient tilt, então setamos isHovered = false.

## L471-472 (em `CombatSequence:draw`, junto a `for _, card in ipairs(self.flyingCards) do`)

> Desenha cartas voando COM O PRÓPRIO RENDERER: herda sombras, warp,
> juice, ambient tilt, dissolve. Isso é o grande ganho vs sistema antigo.

## L488-489 (em `CombatSequence:draw`, junto a `if #self.damageNumbers > 0 then`)

> (o overlay FDBG magenta saiu — cumpriu o papel na caça ao bug de
> feel; o diagnóstico continua no feel_debug.log, invisível em jogo)

## L508-510 (em `CombatSequence:draw`)

> ============================================================================
> STATUS QUERIES (compat com CombatAnimationSystem)
> ============================================================================

## L512-516 (em `CombatSequence:draw`, junto a `function CombatSequence:isBlocking()`)

> Contrato critico: enquanto isto for true, main/GameplayScene NAO dispara
> turno do inimigo, game over, victory nem nextPhase. Agora inclui a FILA DE
> BEATS — o jogo nao avanca enquanto houver acontecimento de combate pendente
> (o dano do veneno, o orbe pulsando, o coringa ticando). Sem isso a tela de
> espolios abriria por cima da resolucao.

