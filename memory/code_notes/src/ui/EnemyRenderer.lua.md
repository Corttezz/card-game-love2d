---
name: code_notes/src/ui/EnemyRenderer.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/EnemyRenderer.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/EnemyRenderer.lua`

Origem: `src/ui/EnemyRenderer.lua` em `7dbdb60d` (98 de 164 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local SpriteAnimation = require("src.ui.SpriteAnimation")`)

> src/ui/EnemyRenderer.lua
> Renderiza o inimigo como sprite animado no canvas de gameplay.
> Combina MÚLTIPLAS camadas visuais pra maximizar polish:
>
> 1. Sombra no chão — de CONTATO (apoiado) ou de ALTURA (flutuante),
> conforme src/data/enemy_poses.lua
> 2. Partículas ambientais por ato (poeira/faíscas/névoa)
> 3. Animação pixellab real (frames) OU sprite estático
> 4. Idle bounce sutil (sin wave ±1px) — apoiados; flutuantes usam o bob
> da pose no lugar dele
> 5. Micro tremor (±1px horizontal, nervosismo constante)
> 6. Pulse de cor (tint varia ±8% em sin lento)
> 7. Flash branco em hurt (overlay)
> 8. Outline glow em hurt (aura vermelha)
>
> Todas as camadas são baratas (trig + draw) e combinadas criam sensação de "vida".

## L24-26 (junto a `local function reducedMotion()`)

> Acessibilidade: com reducedMotion o BOB do flutuante some, mas o HOVER
> (a altura em si) permanece — altura diz o que a criatura É; balanço é
> enfeite. Ver memory/ui_layout_invariants.md, corolário da regra 3.

## L31-34 (em `reducedMotion`, junto a `local function submitEmissives(spriteId, sx, sy, iw, ih, scale, z, boost)`)

> LightEngine v1.2: micro-luzes dos pixels EMISSIVOS do monstro (olhos,
> chamas, cristais — src/data/enemy_emissives.lua). Pulso lento por âncora
> (fases dessincronizadas), some na morte. sx/sy = topo-esq do sprite na
> TELA (já transformado); z = profundidade na estrada (rel).

## L39-42 (em `submitEmissives`, junto a `local seed = 0`)

> fase POR MONSTRO (hash do id): a criatura "respira" como um todo.
> Fase por âncora deixava um olho a 72% e o outro a 100% no mesmo
> frame — lia como "só um olho aceso" (feedback Jul/2026). O offset
> por âncora é mínimo (0.3 rad), só pra não ficar mecânico.

## L61-62 (em `staticCache`, junto a `local axisCache = {}`)

> eixo do corpo por id (EnemyRenderer.bodyAxis) — declarado aqui porque
> o clearCache, mais acima no arquivo, também o zera

## L71-72 (em `staticMiss`, junto a `local auraId = nil`)

> Chefe na tela (spriteId) quando enemy.isBoss — o update da aura precisa
> saber de quem emitir sem conhecer o game. Setado no draw.

## L74-79 (em `staticMiss`, junto a `local poseSink = 0`)

> QUEDA do flutuante na MORTE (0 = no ar, 1 = no chão). Ver poseOffsetY.
> Pedido do dono (Out/2026): quem voa, quando morre, CAI — o corpo termina
> deitado no chão, não evaporando no ar. Era descida LINEAR de 0.7s (lia
> como elevador); agora é GRAVIDADE: k = (t/dur)², impacto com quique
> curto + poeira, e a margem de pé passa a ser a do QUADRO da death, com o
> mesmo FOOT_SINK de quem pisa — o cadáver afunda 2-3px no piso e fica.

## L88-92 (em `dust`, junto a `EnemyRenderer.FOOT_SINK = 2`)

> Quanto o pé de quem PISA afunda no chão, em px de tela. O dono pediu o pé
> "um pouquinho mais pra baixo do chão" (Out/2026): base do sprite cravada
> exatamente na linha lia como pairar — o contorno escuro do pé fica por
> cima da textura do chão em vez de dentro dela. 2px + o respiro {0,+1}
> deixa o pé sempre 2-3px dentro do chão, nunca acima.

## L96-97 (em `EnemyRenderer.getLastFoot`, junto a `function EnemyRenderer._debugSetFrame(i)`)

> Testes: fixa o quadro da animação corrente (varrer TODOS os quadros da
> idle é o que prova que o pé não descola em nenhum deles).

## L118-121 (em `ambientParticles`, junto a `local DIRECTIONS = { "south" }`)

> Pipeline atual usa só direção `south` (combate frontal estático). Outras
> direções foram removidas em 2026-04-21 — economiza ~75% disco e créditos
> de geração. Se um dia precisar de rotação, regerar via animate_character
> com directions=["east","west","north"] específicas.

## L155-158 (em `sprites`, junto a `local function idleSpec(enemyId)`)

> Idle de cada inimigo: ping-pong no IDLE_FPS (roster comum, 4 quadros)
> ou LOOP fechado no fps declarado na pose (chefes, idle assado por
> tools/bake_boss_idle.py — ciclo que já volta ao quadro 0 sozinho;
> ping-pong ali faria o pano "rebobinar").

## L169 (em `idleSpec`, junto a `local clipFps = {}`)

> fps dos clips de cinemática pedidos por playClip (nome -> fps)

## L178 (em `ensureAnim`, junto a `local function backToIdle()`)

> Volta canônica pro idle (usada por todo clip one-shot).

## L190-191 (em `opts`, junto a `fps = ATTACK_FPS`)

> ONE-SHOT (bug playtest Jul/2026: caía no default loop+pingpong e o
> inimigo repetia o golpe pra sempre). Toca uma vez e volta pro idle.

## L198-199 (em `opts`, junto a `fps = clipFps[animName] or 10`)

> CLIP DE CINEMÁTICA (pouso, rugido, subida... — BossCinematic via
> playClip): one-shot no fps pedido, volta pro idle ao terminar.

## L213-219 (em `opts`, junto a `function EnemyRenderer.poseOffsetY(spriteId, spriteH, now, sinkK)`)

> Deslocamento vertical da POSE (negativo = pra cima) + a pose resolvida.
> Puro: mesma entrada, mesma saida — dá pra testar sem contexto grafico.
> Com reducedMotion o BOB some e sobra so o HOVER: a criatura continua na
> ALTURA certa (posicao e informacao; balanco e enfeite).
> sinkK 0..1: MORTE. O que segurava a criatura no ar deixa de segurar —
> ela desce ate o chao ao longo do clip de death em vez de evaporar
> pairando (e a sombra reaparece no tamanho cheio).

## L231-233 (em `EnemyRenderer.poseOffsetY`, junto a `function EnemyRenderer.poseOffsetX(spriteId, spriteH, now, sinkK)`)

> Deriva HORIZONTAL do flutuante (só quem declara `drift` — os chefes que
> pairam). Ciclo mais lento que o bob (0.53x) pra traçar um oito largo em
> vez de ir e voltar na mesma linha. reducedMotion: zero (é balanço).

## L258-259 (em `ambientParticles`, junto a `function EnemyRenderer.debugState()`)

> Estado interno pra testes de regressão (tools/test_systems.lua valida o
> ciclo attack→idle e a escala estável — bug do loop/encolhimento Jul/2026).

## L267-268 (em `EnemyRenderer.debugState`, junto a `local arrivalT = 0`)

> Juice de CHEGADA (fim da viagem na estrada): o inimigo "assenta" com
> duas quicadas rápidas em vez de aparecer num corte seco.

## L281-284 (em `EnemyRenderer.getArrivalOffset`, junto a `local attackFx = nil     -- { t, kind, onApex, apexFired }`)

> ===== FX DE COMBATE (Jul/2026 — "o inimigo é uma estátua") =====
> Camada PROCEDURAL sobre os clips existentes (idle/hurt/death): investida
> no ataque, knockback no dano, tint de veneno/defesa/fúria. Nenhum sprite
> novo — física de offsets + cor sobre a base atual.

## L290 (em `EnemyRenderer.getArrivalOffset`, junto a `local slashTime = 0          -- arco de golpe no apex da investida`)

> Telegrafia v2 (Jul/2026 — "não fica claro quando ele defende/ataca/buffa"):

## L294-295 (em `buffParticles`, junto a `local DEFEND_DUR = 0.9`)

> Durações dos FX de intent executado. defend/buff eram 0.5/0.6s de tint —
> curtos e sutis demais pra ler (playtest). Agora carregam ícone/partículas.

## L305-309 (em `buffParticles`, junto a `function EnemyRenderer.resetRun()`)

> RESET DE RUN (bug "abandonei e caí na run antiga", Jul/2026): FX e clip
> correntes são estado de módulo. O pior caso era um attackFx da run
> ABANDONADA com onApex pendente — o callback (que fecha o turno inimigo
> do game morto) dispararia DENTRO da run nova. Chamado pelo rebind da
> GameplayScene (setGame).

## L311-312 (em `EnemyRenderer.resetRun`, junto a `EnemyRenderer.setTimeScale(1)`)

> (o `local timeScale` so e declarado mais abaixo: atribuir aqui criava um
> GLOBAL homonimo e nao resetava a camera lenta de verdade)

## L331-333 (em `ambientParticles`, junto a `function EnemyRenderer.triggerAttack(kind, onApex)`)

> O inimigo TELEGRAFA + INVESTE: recua, avança na direção do jogador
> (baixo-esquerda) e o dano é aplicado NO IMPACTO via onApex.
> Se o personagem tiver clip "attack" (PixelLab), ele toca junto da investida.

## L337-342 (em `attackFx`, junto a `if currentEnemyId and currentAnimName ~= "death" then`)

> Clip do golpe (Out/2026: todos os 45 têm; tools/bake_attack.py): 9
> quadros a 12 fps, golpe no quadro 4 = apex da investida (0,34s). Forte
> usa `attack_strong` (amplitude 1,6x) quando existe. REINICIA a cada
> golpe: no multi-golpe o 2º hit chega com o clip anterior ainda na
> volta, e o ensureAnim reaproveitaria o clip em andamento (golpe
> dessincronizado do apex).

## L357-358 (em `attackFx`, junto a `function EnemyRenderer.hasClip(id, name)`)

> CLIP ONE-SHOT da cinemática (BossCinematic): toca `name` no fps dado e
> volta pro idle. Nunca por cima da morte. hasClip diz se está instalado.

## L379-381 (em `EnemyRenderer.triggerBuff`, junto a `buffParticles = {}`)

> Fagulhas de fúria: 14 partículas nascem no corpo e SOBEM (a linguagem
> universal de "ele ficou mais forte"). Offsets relativos ao sprite —
> o draw posiciona no corpo real do frame.

## L401-402 (em `EnemyRenderer.isAttacking`, junto a `local lastCenterX, lastCenterY = nil, nil`)

> Última posição desenhada (centro do peito) — pro Game ancorar floating
> text de veneno sem conhecer o layout.

## L404-405 (em `EnemyRenderer.isAttacking`, junto a `function EnemyRenderer.getLastPos()`)

> Volta no espaço da UI (src/ui/UiScale): quem pergunta é texto flutuante/
> partícula, que desenham com a UI; o inimigo é desenhado na janela real.

## L413-416 (em `EnemyRenderer.triggerHurt`, junto a `if currentAnimName == "death" then return end`)

> Guard: nao sobrescrever death anim com hurt. A death e "terminal" —
> uma vez acionada, nao volta pra hurt/idle. Sem esse guard, o hurt
> disparado pelo CombatSequence apos o dano fatal reiniciava
> a animacao e a morte nunca aparecia em tela.

## L448-450 (em `spawnAmbientParticle`, junto a `local timeScale = 1`)

> CÂMERA LENTA (BossCinematic, morte do chefe): o relógio DESTE módulo —
> clip, queda, quique, aura — corre a `timeScale`. O resto da cena (beats,
> partículas da UI) segue normal: é o CORPO que cai devagar, não o jogo.

## L533-536 (em `dust`, junto a `end`)

> posição central só pra spawn; o draw usa a posição real do inimigo
> Nota: spawn com placeholder cx=0 cy=0; reajustado em draw via offset
> (hack leve pq update nao sabe a pos; deixa particula nascer em 0,0
> e draw translada pro cx,cy). Mais simples: spawn direto em draw.

## L551-565 (em `dust`, junto a `local clipMetricsCache = {}`)

> v8.1: CENTRALIZAÇÃO POR CONTEÚDO — o crop de instalação usa a UNIÃO
> dos bboxes de TODAS as animações (a death caindo pro lado estica o
> canvas), então o idle de alguns monstros fica descentrado no canvas
> (medido: obsidian_sentinel −19px, glacier_knight −20px, frost_wight
> −10px — feedback "muito à esquerda"). Offset do centro do conteúdo
> do 1º frame idle, cacheado por id, aplicado no cx do draw.
> v8.3 (fix playtest Jul/2026): métricas POR CLIP. Os clips antigos foram
> CROPADOS na instalação (idle do scarecrow = 96×97), mas clips novos podem
> vir com canvas cru do PixelLab (attack = 176-256px com margens
> transparentes). Medimos o CONTEÚDO do 1º frame de cada clip:
> off = descentramento horizontal do conteúdo no canvas
> pad = margem transparente abaixo do pé (crava o pé no chão)
> h/w = tamanho do canvas do clip
> A ESCALA do personagem deriva SEMPRE do idle (âncora estável) — clip com
> canvas maior desenha com o MESMO scale e o corpo nunca muda de tamanho.

## L567-568 (em `clipMetricsCache`, junto a `local FOOT_ALPHA = 0.1`)

> Limiar de "pixel de conteúdo" (pé/silhueta). Mesmo valor nas duas
> varreduras — 1º quadro e por quadro — senão as margens discordam.

## L571-579 (em `EnemyRenderer._clearClipMetrics`, junto a `local GROUND_T = 5`)

> LINHA DE CHÃO do quadro (Out/2026, dono: "os ratos parecem flutuar").
> O pé era o pixel opaco MAIS BAIXO — e no monte de ratos esse pixel é a
> ponta de um rabo enrolado abaixo dos corpos: cravado o rabo no chão, os
> corpos pairavam. Agora o chão é a linha mais baixa com pelo menos M
> pixels "sólidos", onde sólido = coluna opaca contínua de >= GROUND_T px
> terminando ali (bota, casco, pata e base de corpo são verticais e grossos;
> ponta de rabo, de lâmina e farrapo de capa são finos). Devolve a linha
> (nil se vazio) e o trecho horizontal do apoio (footL, footR) nas 4 linhas
> de cima dela — a largura da pegada pra sombra de contato.

## L622-623 (em `solidRows`, junto a `return g, fl, fr, low, top`)

> top = linha do conteúdo mais alto: g - top + 1 é a ALTURA do corpo
> neste quadro (cadáver deitado mede menos que o bicho em pé)

## L668-670 (em `m`, junto a `m.cw = maxX - minX + 1`)

> largura do CONTEÚDO (canvas cru do PixelLab tem margem
> lateral gorda): a elipse de contato mede o corpo, não a
> folha de papel em que ele foi desenhado.

## L672-675 (em `m`, junto a `m.pad = (hpx - 1) - maxY`)

> v8.2: MARGEM DE PÉ — canvas transparente abaixo do conteúdo
> fazia o monstro "flutuar". pad crava o pé do CONTEÚDO no
> chão. Quem flutua por DESIGN (espectros/alados) sobe
> por dado, não por margem de canvas: src/data/enemy_poses.

## L677 (em `m`, junto a `local g, fl, fr = groundOf(data)`)

> chão pela regra do apoio (ignora rabo/lâmina/farrapo)

## L686-694 (em `m`, junto a `m.framePads = {}`)

> PÉ POR QUADRO (Out/2026, dono: "quando ele fica o corpo inteiro pra
> fora, ainda fica meio que flutuando alguns milímetros do chão"). O
> `pad` acima mede SÓ o 1º quadro, mas a regeração do PixelLab desloca
> a figura INTEIRA (pés junto) 1-2px entre quadros da idle: abyss_tyrant,
> ember_imp e rot_colossus sobem 2px de arte (~5px na tela) em metade
> do ciclo — o pé descolava do chão e voltava, a cada respiração.
> framePads[i] = margem abaixo do conteúdo do quadro i (mesmo limiar).
> Quem pisa usa o pad DO QUADRO na idle: o pé fica cravado e o que
> sobra de movimento é o do corpo em relação ao pé.

## L696-699 (em `m.framePads`, junto a `m.frameHeights = {}`)

> ALTURA DO CONTEÚDO por quadro (v9 das sombras, Out/2026): topo→chão.
> É o que diz se o corpo está em pé ou DEITADO na death — a sombra de
> um cadáver é a de um objeto baixo (pegada = o corpo), não a
> silhueta inteira virada de novo no chão.

## L725-728 (em `m.frameHeights`, junto a `local gr = (EnemyPoses.BY_ID[id] or {}).groundRow`)

> OVERRIDE `groundRow` (enemy_poses, linha do canvas do idle) quando a
> regra erra: desloca o chão de TODOS os quadros pelo mesmo tanto (a
> diferença medida no quadro 0 do idle). Vale também na death: o quadro
> 0 dela é o do idle, e o cadáver assenta na mesma régua.

## L744-752 (em `m.frameHeights`, junto a `function EnemyRenderer.bodyAxis(id)`)

> EIXO DO CORPO (Out/2026, dono: "o 29 e a barra de vida estão à esquerda
> do corpo"). Centrar pelo BBOX do conteúdo põe arma/cajado/cauda/capa no
> cálculo: o corpo sai do centro e o HUD (que ancora no cx) fica torto. O
> eixo é a MEDIANA, nas linhas do meio do corpo (20%-80% da altura do
> conteúdo), do centro do MAIOR trecho opaco contínuo de cada linha — o
> tronco é o trecho mais largo na maioria das linhas; cajado e cauda são
> trechos finos e separados. Erra com escudo largo, quadrúpede de frente e
> orbe grande: aí vale o override `axisX` de src/data/enemy_poses.lua.
> Coluna em px do canvas do idle (coordenada de CENTRO de pixel).

## L813-814 (em `centers`, junto a `local function axisOffset(id)`)

> deslocamento horizontal (px do canvas) que leva o EIXO do corpo ao centro
> do canvas do idle — o que o draw e o billboard subtraem do cx

## L821-823 (em `axisOffset`, junto a `local function contentOffsets(id)`)

> Compat: call sites antigos (billboard da viagem etc.) pedem só o idle.
> O offset agora é o do EIXO DO CORPO (mesma conta do draw: o handoff
> viagem→batalha não pode pular de lado).

## L829-830 (em `contentOffsets`, junto a `function EnemyRenderer.debugClipMetrics(id, animName)`)

> Exposto pra testes de regressão (escala estável entre clips — depois da
> declaração de clipMetrics, senão a closure capturaria um global nil).

## L845-858 (em `tickAmbientSpawn`, junto a `function EnemyRenderer.shadowProfile(pose, animName, frameH, idleH)`)

> Retorna bbox { x, y, w, h } do sprite desenhado (em pixels de tela), ou false.
> EnemyHud usa esse bbox pra ancorar HP bar / intent icon.
> cx/cy = ponto de CHAO onde a criatura pisa (na estrada vem do
> WorldRoad.getRoadAnchor; nos interiores, de src/data/scene_anchors.lua).
> opts (interiores): { shadowA, lightXr } — a cena diz o quanto e pra onde
> a sombra cai; ver SceneAnchors.get(scene).
> PERFIL DE PEGADA da sombra (ShadowEngine v9, puro — tools/test_world_shadows).
> Em pé: o que a pose declara (`shadowBaseK`/`shadowRiseK` em enemy_poses;
> bicho largo e baixo como o monte de ratos ou o touro). Na MORTE o corpo
> vai deitando: a altura do quadro cai em relação à do idle e a pegada
> cresce junto — cadáver é objeto baixo (a sombra dele é uma orla, não um
> segundo cadáver no chão). lying = 0 em pé .. 1 deitado (altura caiu 35%
> ou mais: o touro deitado ainda mede 70% do touro em pé — quadrúpede
> deita pouco). Devolve baseK, riseK, lenK.

## L877-879 (em `EnemyRenderer.draw`, junto a `if opts and opts.deathCy and currentAnimName == "death"`)

> CHÃO DO CADÁVER (opts.deathCy, salão com deathYr): quem voa cai pra
> FRENTE e pra baixo até o piso andável — a linha de chão escorrega de
> cy pra deathCy junto da queda (poseSink). Apoiado não se mexe.

## L885-890 (em `EnemyRenderer.draw`, junto a `local enemyAlive = game.enemy and game.enemy.health > 0`)

> Detecta necessidade de re-iniciar a idle:
> 1) Inimigo trocou de spriteId (novo ato/node).
> 2) Nao ha anim carregada ainda.
> 3) Anim de death terminou mas o inimigo atual esta vivo (proxima batalha
> com mesmo spriteId): sem esse reset, a tela continua mostrando o
> ultimo frame de death ("inimigo deitado morto").

## L912-916 (em `EnemyRenderer.draw`, junto a `local targetHeight = 250`)

> Escala alvo. 250 normal / 330 boss. v5: escala ADAPTATIVA (float).
> v8.3: a escala deriva SEMPRE do canvas do IDLE (âncora estável do
> personagem) — o attack do PixelLab vem com canvas cru maior (176-256px
> vs idle cropado ~100px) e, escalando pelo clip atual, o corpo ENCOLHIA
> durante o golpe (playtest Jul/2026).

## L919-920 (em `EnemyRenderer.draw`, junto a `targetHeight = targetHeight * ((opts and opts.sizeK) or 1)`)

> sizeK: o PALCO decide o tamanho (na estrada, a perspectiva da
> distância de parada — WorldRoad.battleSizeK; nos salões, 1).

## L927-929 (em `EnemyRenderer.draw`, junto a `local curM = hasAnim and clipMetrics(id, currentAnimName or "idle") or idleM`)

> v8.1/8.2/8.3: descentramento e margem de pé do CLIP ATUAL — centro
> visual no cx pedido e pé do CONTEÚDO cravado em cy (sombra, HUD e
> emissivos seguem juntos), mesmo quando o canvas do clip difere do idle.

## L933-935 (em `EnemyRenderer.draw`, junto a `if idleM.w > 0 then`)

> EIXO DO CORPO (automático ou override axisX): troca o centro do bbox
> do idle pelo eixo, preservando o desvio relativo de cada clip. O HUD
> ancora no cx devolvido no bbox — eixo no cx = HUD sobre o corpo.

## L939-945 (em `EnemyRenderer.draw`, junto a `local bodyCx = cx`)

> bodyCx: o ponto pedido É onde o EIXO DO CORPO fica. `cx` daqui em
> diante é o centro do CANVAS (o sprite e a silhueta da sombra desenham
> a partir dele). HUD, sombra elíptica, aura e o texto flutuante ancoram
> no CORPO (bodyCx) — devolver o centro do canvas no bbox era o "29 e a
> barra à esquerda do corpo" (Out/2026): o canvas tem margem/arma/capa
> de um lado só, e o centro dele não é o do bicho (medido a 1080p: até
> 36px de diferença no glacier_knight).

## L949-952 (em `EnemyRenderer.draw`, junto a `local hoverY, pose = EnemyRenderer.poseOffsetY(id, ih * scale,`)

> POSE (src/data/enemy_poses.lua): apoiado x flutuante. Quem tem pe
> fica com o pe no chao; quem e espectro/alado SOBE de proposito e
> deriva. A sombra (mais abaixo) fica no chao nos dois casos — e o
> vao entre corpo e sombra que comunica altura.

## L960-964 (em `EnemyRenderer.draw`, junto a `local footPad = curM.pad`)

> Pé: margem do QUADRO atual na idle de quem pisa (ver framePads) e
> AFUNDADO FOOT_SINK px no chão. footY = deslocamento que leva a base
> do canvas até o pé, SEM truncar: o SpriteAnimation já faz floor do y
> e um segundo floor aqui somava até 2px pra CIMA — justamente o lado
> que lê como flutuar.

## L971-974 (em `EnemyRenderer.draw`, junto a `if not floating and currentAnimName == "death"`)

> MORTE de quem pisa: margem DO QUADRO (regra do apoio) — o corpo que
> tomba/desaba tem a base mudando a cada quadro; com a margem só do 1º,
> o cadáver deitado terminava acima do chão ou atravessando a estrada
> ("os ratos morrem e ficam errado no chão", Out/2026).

## L983-985 (em `EnemyRenderer.draw`, junto a `local fp = curM.framePads and curM.framePads[frameIdx]`)

> caindo: a margem de pé vai da do 1º quadro (no ar) pra do QUADRO
> corrente da death (o cadáver deitado tem outro ponto mais baixo),
> e o afundamento chega no FOOT_SINK de quem pisa ao tocar o chão.

## L989-991 (em `EnemyRenderer.draw`, junto a `if landT >= 0 and landT < BOUNCE_DUR and not reducedMotion() then`)

> quique curto no impacto (meia senoide amortecida); sem quique em
> reducedMotion. Nunca termina acima do chão: em landT >= BOUNCE_DUR
> o deslocamento é zero.

## L999-1001 (em `EnemyRenderer.draw`, junto a `local t = love.timer.getTime()`)

> =========================================================
> CAMADAS VISUAIS (aplicadas em ordem)
> =========================================================

## L1012-1016 (em `EnemyRenderer.draw`, junto a `local bounce = floating and 0 or (math.sin(t * 1.6) > 0 and 1 or 0)`)

> (4) Idle bounce (±1px vertical — respiração; ±2 parecia flutuar)
> Flutuante nao respira em 1px: o bob da pose ja e o movimento dele
> (somar os dois dava tremelique de duas frequencias).
> Out/2026: o floor do seno dava {-1, 0} — meio ciclo 1px ACIMA do
> chão. Agora {0, +1}: respira pra DENTRO do chão, nunca descola.

## L1018-1019 (em `EnemyRenderer.draw`, junto a `local jitter = 0`)

> (5) Tremor SÓ no impacto (o tremor constante de 13-17Hz era o
> "fricando" apontado pelo dono — monstro parado não treme).

## L1025-1026 (em `EnemyRenderer.draw`, junto a `local atkDX, atkDY = 0, 0`)

> FX de combate: investida de ataque (recua → avança pro jogador →
> volta) + knockback ao tomar dano.

## L1056 (em `EnemyRenderer.draw`, junto a `+ footY + atkDY + hoverY`)

> v8.2: pé do conteúdo NO chão (margem do canvas fora)

## L1057-1058 (em `EnemyRenderer.draw`, junto a `lastFoot = {`)

> Régua do palco (tools/test_enemy_stage): onde o pé DESTE quadro caiu,
> pela mesma conta que o SpriteAnimation usa (floor do y).

## L1063-1064 (em `lastFoot`, junto a `drawX = drawX,`)

> canto do canvas do sprite na tela (BossCinematic pousa o rasante
> EXATAMENTE onde o próximo draw vai desenhar o chefe)

## L1076-1087 (em `lastFoot`, junto a `do`)

> (1) v8: SOMBRA PROJETADA da silhueta (ShadowEngine) — a própria
> forma do monstro (frame ATUAL da animação: a sombra respira e ataca
> junto) deitada pro primeiro plano, cisalhada pra longe do sol do
> bioma, comprimento pelo horário. Nos INTERIORES (sem frame de
> sombra do WorldRoad) cai na elipse rasteira legada — luz de tocha
> não tem direção única.
> SOMBRA: de CONTATO pra quem pisa, de ALTURA pra quem flutua.
> Regra que a pose impoe: a sombra NAO sobe com o corpo. Ela fica no
> chao (cy), fica MENOR, mais fraca e mais borrada, e escorrega pro
> lado oposto a luz — a distancia entre corpo e sombra e o que diz
> "isto esta no ar". Colar a elipse de contato embaixo de quem paira
> foi exatamente o defeito reportado (Set/2026).

## L1091-1092 (em `lastFoot`, junto a `local sink = math.max(0, math.min(1, poseSink))`)

> Enquanto o flutuante DESCE na morte, a sombra volta ao tamanho e
> a forca de contato — quem pousou projeta sombra de quem pousou.

## L1101-1102 (em `lastFoot`, junto a `local dirX = ShadowEngine.tipShiftAt(cx)`)

> direcao "pra longe da luz": na estrada o proprio ShadowEngine
> sabe onde esta o astro do bioma; no interior vem da cena.

## L1117-1118 (em `lastFoot`, junto a `local sy0 = -(ih * scale) + footY - sink`)

> +footY: a sombra ancora no PE DO CONTEUDO (a margem
> transparente do canvas criava um vao entre pe e sombra)

## L1148-1150 (em `lastFoot`, junto a `local footW, footCx = nil, nil`)

> PEGADA (footL..footR do quadro 0 do clip, regra do apoio): onde o
> bicho de fato toca o chão. Bota, casco, monte de ratos — a sombra
> de contato mede ISSO, não o canvas nem o corpo inteiro.

## L1157-1161 (em `lastFoot`, junto a `if drawn and footW and not floating then`)

> CONTATO na estrada (Out/2026, "os ratos parecem flutuar"): a
> silhueta projetada vai pra longe do sol e não escurece o chão
> DEBAIXO do pé — bicho largo e baixo ficava sem contato nenhum.
> Três faixas em degrau, na grade do pixel da arte, da largura da
> pegada. Só quem pisa (quem flutua mostra o vão, não contato).

## L1174-1176 (em `lastFoot`, junto a `local baseW = footW or (((curM.cw > 0) and curM.cw or iw) * scale)`)

> Interiores: sem sol unico, elipse rasteira. A largura sai da
> PEGADA (ou do conteúdo), nao do canvas — canvas cru do
> PixelLab tem margem lateral gorda e a elipse saia larga demais.

## L1185-1186 (em `lastFoot`, junto a `love.graphics.setColor(0, 0, 0, a * 0.5)`)

> duas passadas concentricas = penumbra barata: sombra de
> corpo no ar tem borda macia, nao recorte de tesoura.

## L1198-1200 (em `lastFoot`, junto a `if #dust > 0 then`)

> Poeira do impacto da queda: blocos do pixel da arte saindo rente ao
> chão pros dois lados (fica ATRÁS do corpo caído só no meio; nas
> pontas, aparece — é ali que a poeira lê).

## L1215-1216 (em `lastFoot`, junto a `local auraRect = nil`)

> Aura do chefe, camada de TRÁS (círculo no chão, eclipse, metade de
> trás das órbitas, fumaça rasteira) — depois da sombra, antes do corpo.

## L1225 (em `auraRect`, junto a `local pulse = 0.94 + (math.sin(t * 1.1) * 0.5 + 0.5) * 0.06`)

> (6) Pulse de tint (cor varia ±6% lentamente, respiração sutil)

## L1227-1228 (em `auraRect`, junto a `local tintR, tintG, tintB = pulse, pulse, pulse`)

> Tint de status por cima do pulse (clareza: veneno tinge VERDE,
> defesa tinge AÇO, fúria/buff tinge VERMELHO pulsante).

## L1287-1289 (em `offsets`, junto a `if auraRect then BossAura.drawFront(auraId, auraRect) end`)

> Aura do chefe, camada da FRENTE (brilhos, metade da frente das
> órbitas, penas/almas/fagulhas) — antes dos FX de intent, que são
> leitura de jogo e não podem ficar por baixo de enfeite.

## L1292-1293 (em `offsets`, junto a `if defendTime > 0 then`)

> DEFESA v2 (telegrafia Jul/2026): dois anéis aço em sequência + ESCUDO
> grande com pop sobre o peito — "ele se protegeu" impossível de perder.

## L1328-1329 (em `offsets`, junto a `if buffTime > 0 then`)

> BUFF v2: fagulhas vermelhas SOBEM do corpo + ícone de força com pop
> acima da cabeça — a linguagem universal de "ele ficou mais forte".

## L1361-1362 (em `offsets`, junto a `if slashTime > 0 then`)

> ARCO DE GOLPE no apex da investida: três traços brancos varrendo na
> direção do ataque (baixo-esquerda) — o "corte" que faltava no impacto.

## L1384-1387 (em `offsets`, junto a `if currentAnimName ~= "death" then`)

> LightEngine v1.2: emissivos do monstro (olhos/chamas/cristais) —
> mesma z do corpo: a silhueta oclui a luz de trás, e o tie-break do
> engine desenha a luz DEPOIS da silhueta no mesmo plano (visível).
> Morte apaga os emissivos (o corpo "desliga").

## L1393-1402 (em `offsets`, junto a `do`)

> LightEngine v1.1: o corpo do inimigo OCLUI luzes atrás dele (janelas
> do castelo, poças mais fundas) — silhueta pixel-perfeita no lightmap.
> No-op sem frame de luz (interiores). Lanterna mais PRÓXIMA que ele
> continua iluminando-o.
> v9.2 (bug: "monstro fica todo escuro em alguns momentos"): z tem
> VIÉS +6 — o corpo só oclui luz BEM mais funda (janelas do castelo,
> rel ~26). Poça de luminária logo atrás (rel 9-15) voltou a
> iluminá-lo: sem o viés, a silhueta apagava a poça e o monstro
> virava um buraco preto DENTRO da área iluminada, estrobando com o
> flicker do fogo (a poça cresce/encolhe sobre ele).

## L1412-1429 (em `offsets`, junto a `local ar, ag, ab = 1, 1, 1`)

> v9.2 (feedback: "monstro com luz em volta no bioma 6"): o antigo
> FILL era micro-luz radial → halo no chão, gritante no escuro.
> Agora o LIFT levanta a leitura SÓ nos pixels da silhueta (recorte
> pixel-perfeito, ZERO halo). Escala pelo ambiente: escuro levanta
> mais, claro não mexe (teto 1.6). Igual em todos os biomas.
> mesmo piso do billboard da viagem (drawEncounterFront) — o
> handoff viagem→batalha NÃO pode mudar o brilho do monstro
> alvo 1.0: monstro na COR PADRÃO cheia (lightmap≈1 na silhueta),
> igual ao billboard da viagem — sem escurecer ao ficar estático.
> Lanternas ainda ADICIONAM calor por cima (clampa em 1).
> flat "cor padrão + leve tom do ambiente": o monstro é elemento
> FOCAL (leitura de gameplay) — precisa ficar na cor cheia do sprite
> mesmo sem luz na frente ou com luz vindo de trás. O ambient×lift
> antigo saturava no canal mais forte (teto 1) e travava em ~82% de
> luma no dusk/noite → o corpo escuro do espantalho esmagava pra
> quase preto. Aqui o flat parte do BRANCO e recebe só uma fração
> (tint) do matiz do ambiente → monstro na cor padrão, levemente
> tingido pela hora. Lanternas na frente ainda SOMAM calor por cima.

## L1441-1442 (em `flatColor`, junto a `z = (((package.loaded["src.ui.WorldRoad"] or {}).BATTLE_REL)`)

> BATTLE_REL + viés. Lido via package.loaded: o WorldRoad
> requer este módulo (require direto seria circular).

## L1449-1450 (em `fn`, junto a `local r, g, b = love.graphics.getColor()`)

> SpriteAnimation:draw ignora setColor sem tint —
> repassa a cor ambiente que o engine deixou setada

## L1462-1463 (em `fn`, junto a `return {`)

> Retorna bounding box do sprite pra overlays (HP bar / intent).
> cx = EIXO DO CORPO (não o centro do canvas); pés em cy; topo em drawY.

## L1466-1470 (em `fn`, junto a `topY = cy - ih * scale + footY`)

> topo em REPOUSO: sem respiro (sin do relógio real), sem bob do
> flutuante, sem quicada de chegada nem investida. O HUD não treme
> 1px junto da respiração e a altura medida não depende de em que
> milissegundo o quadro caiu (flake "chefe 5 maior que o comum" no
> test_all, Out/2026). A altura do HOVER (dado da pose) fica.

## L1479-1481 (em `fn`, junto a `function EnemyRenderer.getEncounterBillboard(enemy)`)

> Billboard leve pro WorldRoad: o inimigo que vem "lá de trás" na estrada
> durante a viagem. Retorna { img, iw, ih, targetScale } ou nil.
> targetScale = mesma escala que draw() usa na batalha (handoff sem pulo).

## L1484-1487 (em `EnemyRenderer.getEncounterBillboard`, junto a `local bfps, bopts = idleSpec(enemy.spriteId)`)

> v8.4: o billboard usa a ANIMAÇÃO idle (mesmo canvas da batalha) —
> o south.png estático tinha margens DIFERENTES dos frames (por isso
> o monstro "continuava flutuando enquanto vinha" mesmo com footPad)
> e vinha parado ("estático vindo é estranho — deixa animando").

## L1506 (em `EnemyRenderer.getEncounterBillboard`, junto a `anim = anim,`)

> v8.4: vem ANDANDO vivo (idle)

## L1511 (em `EnemyRenderer.getEncounterBillboard`, junto a `spriteId = enemy.spriteId,`)

> LightEngine v1.2: emissivos na viagem

## L1512-1513 (em `EnemyRenderer.getEncounterBillboard`, junto a `offX = offX,`)

> v8.2: o billboard da viagem também crava o pé no chão e centra
> por conteúdo (o espantalho "já surgia flutuando lá do fundo")

## L1516-1517 (em `EnemyRenderer.getEncounterBillboard`, junto a `framePads = (not EnemyPoses.isFloating(enemy.spriteId))`)

> Out/2026: pé por quadro + afundado, mesma regra do draw (quem
> flutua não crava: o pad dele é o do 1º quadro, sem afundar)

## L1522-1523 (em `EnemyRenderer.getEncounterBillboard`, junto a `shadowBaseK = EnemyPoses.get(enemy.spriteId).shadowBaseK,`)

> v9 das sombras: pegada da criatura (largo e baixo) + altura do
> conteúdo do idle, pro ShadowEngine recortar a faixa da pegada

## L1530-1534 (em `EnemyRenderer.getEncounterBillboard`, junto a `function EnemyRenderer.resolveSpriteId(actNumber, nodeType)`)

> ROSTER: a fonte única agora é src/data/enemies.lua (`ROSTER`, pools por
> ato × tipo de nó, Out/2026). A batalha usa o inimigo SORTEADO no nó
> (EnemyRoster, gravado em node.enemyId); este helper devolve o PRIMEIRO do
> pool — o "rosto" do ato, usado por ferramentas de captura e como prévia
> de nó antigo sem enemyId. Endless cicla 4,5,6,1,2,3,... (WorldRoad).

