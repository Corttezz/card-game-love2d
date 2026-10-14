---
name: code_notes/src/cards/base/Card.lua
description: Comentários com decisão/regra/histórico colhidos de src/cards/base/Card.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/cards/base/Card.lua`

Origem: `src/cards/base/Card.lua` em `7dbdb60d` (75 de 154 blocos de comentário tinham marcador de decisão/regra/histórico).

## L60 (em `Card:new`, junto a `instance.dragPending = false  -- mouse-down aconteceu mas não passou threshold`)

> Drag state (Balatro-style reorder em hand + collection)

## L74-75 (em `Card:new`, junto a `Moveable.initJuice(instance)`)

> Juice (Moveable engine): kick multiplicativo de scale/rot quando a
> carta é selecionada, jogada, ou vira joker. Decai em ~0.4s.

## L78-79 (em `Card:new`, junto a `instance._ambientSeed = love.math.random() * math.pi * 2`)

> Ambient tilt: cartas ociosas ondulam levemente (senóide defasada por id).
> ambientSeed garante que cartas da mão não oscilam em sync.

## L83-84 (em `Card:new`, junto a `instance.dissolve = 0`)

> Estado de dissolve (0 = visível, 1 = sumiu). Animado por
> start_dissolve/start_materialize/explode via EventManager.ease.

## L89-91 (em `Card:new`, junto a `instance.upgrades = 0`)

> Sistema de upgrade (Fase 3.1): N+ aplicado pelo RunManager:applyUpgradesToInstance.
> 0 = não forjada. >=1 = forjada N vezes (+2 atk/def por level + boost de effect).
> Render: badge "+N" desenhado em Card:_drawUpgradeBadge.

## L98-99 (em `Card:new`, junto a `instance._flip = 0 -- 0..1..0 durante a anim; 0 estático`)

> Flip state (0 = face pra cima, 1 = face pra baixo). Scale X colapsa
> no meio → ilusão de virada 3D sem shader.

## L105-107 (em `Card:new`, junto a `function Card:juice_up(scale_mod, rot_mod)`)

> Dispara juice kick. Proxy pro Moveable; usar nos momentos de "algo aconteceu":
> card:juice_up(0.3, 0.1)  -- selecionada
> card:juice_up(0.5, 0.15) -- jogada (mais forte)

## L112-113 (em `Card:juice_up`, junto a `function Card:hop_up(px, duration)`)

> Game feel v2: pulinho vertical (ataque investe, joker proca) e crescida
> sem oscilação (defesa incha). Proxies pro Moveable, compõem com juice_up.

## L122 (em `Card:swell_up`, junto a `function Card:shove_x(px, duration)`)

> Game feel v3.3: aparada horizontal (defesa checa pro lado e volta de mola).

## L127-131 (em `Card:shove_x`, junto a `local function EM()`)

> ============================================================================
> CARD STATE ANIMATIONS (inspirado em card.lua do Balatro, linhas 1973-2240)
> ============================================================================
> Todas coreografadas via _G.EventManager. Chame em resposta a eventos de jogo
> ("carta exhausted", "joker comprado materializa", "pack abriu → explode").

## L141-142 (em `Ev`, junto a `function Card:markRemoved()`)

> Marca carta como removida (pra CardParticles fazer cleanup). Callers que
> removem a carta do mundo (discard, exhaust) devem chamar após a anim.

## L147-150 (em `Card:markRemoved`, junto a `function Card:cancelDissolveAnim()`)

> Cancela qualquer animação de dissolve pendente (ease + markRemoved + fades).
> Usado em Game:drawCard quando a carta é reciclada de volta pra mão: sem isso,
> o ease continua rodando e sobrescreve `self.dissolve` após o reset, fazendo
> a carta "desaparecer" na mão do jogador.

## L162-170 (em `Card:cancelDissolveAnim`, junto a `function Card:start_dissolve(colours, silent, timeFac, noJuice, onComplete)`)

> start_dissolve ------
> Animação de destruição: carta queima progressivamente e some. Usar em
> exhaust, vendida, destruída por efeito.
>
> @param colours {c1, c2} — burn colors (default: laranja/vermelho)
> @param silent bool      — não toca som
> @param timeFac number    — multiplicador de duração (default 1 → 0.7s total)
> @param noJuice bool      — skip juice_up inicial
> @param onComplete fn     — chamado ao final (útil pra remover do deck/hand)

## L172-173 (em `Card:start_dissolve`, junto a `self:cancelDissolveAnim()`)

> Se outra dissolve anim já roda (caso raro — replay rápido), cancela
> antes de começar pra não ter 2 eases competindo.

## L205-206 (em `self._dissolveEvents`, junto a `local easeEv = em.add(ev:new({`)

> Ease do dissolve 0 → 1 ao longo da duração. Evento é trackeado em
> self._dissolveEvents pra poder ser cancelado via cancelDissolveAnim.

## L236-241 (em `ease`, junto a `function Card:start_materialize(colours, silent, timeFac, onComplete)`)

> start_materialize ------
> Reverso do dissolve: carta aparece "montando" a partir do nada. Usar em
> comprar carta, receber recompensa, joker novo.
>
> @param colours, silent, timeFac mesmos de start_dissolve
> @param onComplete fn

## L294-299 (em `ease`, junto a `function Card:explode(colours, timeFac, onComplete)`)

> explode ------
> Dissolução dramática com juice intenso, 2 pulsos de partículas, shake.
> Usar em booster pack opening (carta source estoura → spawn de resultados).
>
> @param colours, timeFac
> @param onComplete fn

## L353-356 (em `ease`, junto a `pcall(function()`)

> Som PROPRIO da carta estourando. Antes usava "enemyDeath"
> ("som de boom disponivel") -- emprestado, nao escolhido: carta
> explodindo soava como monstro morrendo. Fallback mantem o
> comportamento antigo enquanto card-explode.mp3 nao existir.

## L389-390 (em `ease`, junto a `function Card:flip(onHalfway, onComplete)`)

> flip ------
> Vira a carta (ilusão 3D colapsando scaleX). 0.3s total. Aplica no draw.

## L431-438 (em `Card:use`, junto a `function Card.hoverTilt(relX, relY)`)

> TILT 3D Balatro-style a partir do mouse RELATIVO à carta (relX, relY em
> 0..1, cortados). Conta PURA e única: a mão/recompensas (updateMouse) e a
> loja (ShelfItem, carta no cavalete em diagonal) usam a mesma.
> nx, ny      posição normalizada em [-1, 1]
> depth       1 no centro, cai pras bordas (sensação de profundidade)
> tiltX/Y     inclinação (rad); uvX/uvY = tilt normalizado em [-1, 1]
> (é o `mouse` do card_perspective.glsl)
> offsetX/Y   parallax (px), shadowX/Y + shadowScale (sombra), rot (z)

## L462-475 (em `Card:updateMouse`, junto a `local layoutX = self.layoutX or self.x`)

> Bbox de detecção: UNIÃO da posição home (layoutX/Y) com a renderizada
> (self.x/y animado). Cobrindo as duas, o usuário consegue:
> 1) entrar em hover na posição home da carta na mão;
> 2) seguir a carta com o mouse enquanto ela sobe (ex: cardY-130 em
> GameplayScene) sem perder o hover;
> 3) sair do hover só quando o mouse de fato deixa o caminho inteiro do lift.
>
> Sem isso voltavam os dois bugs:
> se o bbox seguisse só self.y, o lift saía do mouse → flicker.
> se o bbox ficasse só em layoutY, o usuário não conseguia hoverar a
> versão lifted da carta.
>
> targetScale (vs currentScale): evita encolhimento bistável quando offsetY
> pula -DEPTH_OFFSET imediato e a altura ainda está em ease.

## L484-485 (em `Card:updateMouse`, junto a `local extraMarginTop = 0`)

> Margem extra na direção do lift visual interno (liftOffset dentro do
> Card:draw). Sem isso, mouse na borda visível da carta lifted sai do bbox.

## L498 (em `Card:updateMouse`, junto a `local minX = math.min(layoutX, self.x)`)

> União home + render: cobre todo o caminho do lift externo (cardY → cardY-130)

## L513 (em `Card:updateMouse`, junto a `require("src.ui.CursorManager").request("hand")`)

> cursor "mão" sobre carta (mesmo contrato do Button)

## L515-518 (em `Card:updateMouse`, junto a `self.targetScale = self.baseScale * (Config.Cards.HOVER_SCALE_MULT or 1.06)`)

> Hover proporcional ao baseScale (não hardcode global). Antes
> usávamos Config.Cards.HOVER_SCALE fixo em 1.466 — quebrava cards
> com baseScale custom (ex: shop com slot maior, baseScale ~2.4).
> Hover bump 1.06× é suficiente pra feedback visual sem dominar a tela.

## L521-527 (em `Card:updateMouse`, junto a `Sfx.playWithVariation("hoverCard", 0.95, 0.18)`)

> Pitch random + juice kick: hover-enter Balatro-style
> (engine/text.lua:201 + card.lua:4307). Cada hover soa diferente
> e a carta "salta" sutilmente, dando feedback tátil sem precisar
> de animação extra.
> F12.5: SEM baseVolume aqui — AudioManager usa Config.Audio.HOVER_VOLUME
> (=0.03) carregado em main.lua. Antes 0.5 sobrescrevia, tocando 17x
> mais alto que pretendido (queixa "barulho da carta sai muito alto").

## L532-535 (em `Card:updateMouse`, junto a `local ht = Card.hoverTilt((mx - self.x) / cardWidth, (my - (self.y + offsetY)) / cardHeight)`)

> *** Efeito de movimento 3D Balatro-style ***
> Tilt relativo à posição renderizada (animada): cursor "puxa" a carta
> visualmente, mesmo se o mouse estiver fora do bbox visível (clamp).
> (a conta mora em Card.hoverTilt: a loja usa a mesma)

## L543 (em `Card:updateMouse`, junto a `self.tiltX = ht.tiltX`)

> *** Efeito de rotação 3D Balatro-style ***

## L547-550 (em `Card:updateMouse`, junto a `local liftAmount = Config.Cards.LIFT_AMOUNT`)

> *** Efeito de elevação (carta "levanta" do fundo) ***
> noHoverLift: usado em shop/relic onde cartas devem ficar paradas
> na posição (Balatro shop pattern — cartas só escalam +6% sem se
> mover). Mantém tilt 3D + scale + halo, mas zero translation Y.

## L567-568 (em `Card:updateMouse`, junto a `self.perspectiveRotation = ht.rot`)

> *** Efeito de perspectiva adicional ***
> A carta parece "girar" ligeiramente em 3D

## L586-590 (em `Card:updateMouse`, junto a `if _G.gameSettings and _G.gameSettings.reducedMotion then`)

> Ambient tilt (Balatro-style): cartas ociosas respiram. Onda senoidal
> defasada por seed (evita sincronia). Amplitude ~0.02 rad (~1°).
> Só roda quando NÃO hovered — hover assume tilt.
> Reduced motion (G.SETTINGS.reduced_motion no Balatro): zera o tilt
> pra acessibilidade.

## L606-608 (em `Card:updateMouse`, junto a `local ease = 1 - math.exp(-Config.Cards.SCALE_EASE_K * dt)`)

> *** Smoother hover (Balatro-style) ***
> 1) Ease-out exponencial no scale (vs lerp linear antigo). Feel parecido
> mas com desaceleração natural no fim.

## L612-613 (em `Card:updateMouse`, junto a `if self.isHovered then`)

> 2) Micro-bob quando hovered: ±HOVER_BOB_AMOUNT px vertical, freq SPEED rad/s.
> Somado ao totalOffsetY do draw via self.hoverBob.

## L622-623 (em `Card:updateMouse`, junto a `local vx = (self.x - (self._lastX or self.x)) / math.max(dt, 0.001)`)

> 3) Velocity tilt: carta movendo rápido (drag/reorder) ganha tilt na direção
> do movimento. Damped com exp decay pra settle natural.

## L630-631 (em `Card:updateMouse`, junto a `local targetHover = self.isHovered and 1 or 0`)

> 4) Hover strength (0..1) — intensidade do perspective warp. Suaviza entrada/saída
> via ease-out exp pra evitar pop in do warp.

## L652-653 (em `Card:setTargetPos`, junto a `function Card:updateRender(dt)`)

> Interpola renderX/Y em direção a targetX/Y com ease-out exp. Chamado por frame.
> Drag force-snapa pro mouse (callers usam setRenderPos pra bypass durante drag).

## L655 (em `Card:updateRender`, junto a `local k = 16`)

> decel rápida, sensação tátil Balatro

## L669-670 (em `Card:setRenderPos`, junto a `function Card:_getOffscreenCanvas()`)

> Canvas offscreen reusável pra cards com holo/glow (warp + holo composition).
> Criado lazy com dimensões do canvas da carta; reusa entre frames.

## L682 (em `Card:_getOffscreenCanvas`, junto a `function Card:getWidth()`)

> Métodos para compatibilidade com o sistema de jokers

## L692 (em `Card:draw`, junto a `showPlayableBorder = false`)

> Borda azul "playable" desativada (feedback visual substituído por hover/brightness).

## L698-701 (em `Card:draw`, junto a `local _prevImage = self.image`)

> Ícone animado (icons_anim/): carta VISÍVEL = carta VIVA (regra do
> dono, 13/Out/2026 — revoga o "só na interação" de Jul/2026). A decisão
> (inclusive reducedMotion → estático) mora em CardFrame.displayImage.
> Swap temporário de self.image durante este draw; restaurado no fim.

## L708-710 (em `Card:draw`, junto a `local baseOffsetY = 0`)

> Calcula deslocamentos para hover com efeito 3D
> noHoverLift (shop/relic): zera o baseOffsetY pra carta não saltar pra
> cima/baixo no hover. Mantém scale + tilt + offsetHoverX (parallax suave).

## L721-722 (em `Card:draw`, junto a `local baseFloat = Config.Cards.BASE_LIFT or 0`)

> BASE_LIFT: mesmo idle, carta flutua constante acima da mesa (Balatro).
> Usado pra render da carta: -BASE_LIFT (sobe). Sombra usa valor positivo.

## L724-726 (em `Card:draw`, junto a `local ambientY = 0`)

> Ondulação harmônica idle (Fase 6.3 do refactor Balatro): cartas ociosas
> oscilam Y em ~3px com frequência baixa, defasadas pelo seed pra não
> sincronizar. Some quando hovered (lift assume).

## L735 (em `Card:draw`, junto a `local offsetX = (self.offsetHoverX or 0) + Moveable.shoveOffset(self)`)

> shoveOffset: aparada lateral da defesa (game feel v3.3; decai sozinho)

## L742-745 (em `Card:draw`, junto a `local s = self.currentScale * Moveable.scaleFactor(self) * Moveable.swellFactor(self)`)

> Scale uniforme (sem o hack legado de scale não-uniforme por tilt).
> Perspectiva "press" agora vem do shear abaixo.
> Juice: bump multiplicativo de scale quando `juice_up` foi chamado.
> swellFactor: crescida da defesa (game feel v2) — compõe com o juice.

## L750-751 (em `Card:draw`, junto a `if self._flip and self._flip > 0 then`)

> Flip effect: colapsa scaleX pro meio (0.5 → invisível) e volta.
> Usado em Card:flip() pra simular virada 3D sem shader.

## L758-762 (em `Card:draw`, junto a `local imgW = self.image:getWidth() * s`)

> Sombra direcional (luz acima do centro da tela) — calcula offset screen-space
> mas aplica DENTRO do push/pop pra herdar o warp do shader (acompanha deformação).
> Componentes:
> dirX  — posição horizontal da carta na tela (bordas → sombra oposta)
> press — lado da carta que o usuário pressionou (direita afunda → sombra esquerda)

## L781-784 (em `Card:draw`, junto a `if self.dissolve and self.dissolve > 0.001 then`)

> CRÍTICO: sombra DEVE fade junto com dissolve. Sem isso, durante materialize
> (dissolve 1→0) a sombra chega antes da carta; durante start_dissolve (0→1)
> a sombra fica pairando depois da carta queimar. Visualmente, sombra e carta
> têm que ser uma coisa só.

## L796-797 (em `Card:draw`, junto a `self.lastDrawRect = { x = x + offsetX, y = y + totalOffsetY,`)

> Retângulo desenhado (sem tilt): régua do palco da batalha
> (tools/test_enemy_stage mede o inimigo contra a carta em hover).

## L800-802 (em `self.lastDrawRect`, junto a `require("src.ui.NavCursor").target(self, self.lastDrawRect.x, self.lastDrawRect.y,`)

> alvo de navegação (src/ui/NavCursor). O cursor mira o TERÇO DE BAIXO
> da carta: em hover ela sobe, e o ponto continua dentro da caixa de
> repouso — sem isso o foco "soltava" a carta a cada quadro.

## L809 (em `self.lastDrawRect`, junto a `love.graphics.rotate(perspectiveRotation + Moveable.rotOffset(self))`)

> Rotação Z sutil (tombamento lateral quando move rápido) + juice rot

## L812 (em `self.lastDrawRect`, junto a `love.graphics.scale(scaleX, scaleY)`)

> Escala uniforme (sem hack legado de scale não-uniforme por tilt)

## L819-822 (em `self.lastDrawRect`, junto a `local mouseUV = {`)

> Perspective warp via mesh+shader (Balatro-style). Uniforms:
> mouse:  [tiltX, tiltY] já normalizados em [-1, 1] via TILT_RANGE
> hover:  intensidade suave 0..1
> time:   pro wobble idle

## L836-839 (em `mouseUV`, junto a `if shader then`)

> ===== SOMBRA warpada (antes do card principal) =====
> Mesmo mesh+shader do card, mas com tint preto + offset lateral de luz.
> Como estamos dentro do push (scale aplicado), o offset é em coords da
> carta (pré-scale), então dividimos pelo scale pra compensar.

## L855-858 (em `mouseUV`, junto a `if self.dissolve and self.dissolve > 0.001 then`)

> Dissolve/materialize path: bypass mesh warp + holo (eles não compõem
> com dissolve shader sem double-shader pipeline). Usa DissolveShader
> diretamente na textura. Feio? Não — a dissolução esconde a perda de
> warp porque a carta está sumindo/aparecendo de qualquer jeito.

## L872-874 (em `mouseUV`, junto a `local editionShader, editionStrength = self:_getEditionShader()`)

> Edition path (Fase 3.2): renderiza mesh warpado num canvas, depois
> aplica o shader da edition (foil/holo/polychrome). Tem prioridade
> sobre o rarity glow legacy (fx=="holo"/"glow").

## L876-878 (em `mouseUV`, junto a `local holoGate = self:_holoGate(hoverAmt)`)

> Edition holo segue a MESMA régua da lendária (HoloShader v2): tênue e
> estática em repouso, varredura só na interação. As outras editions
> (foil/polychrome) não mudam.

## L918-928 (em `mouseUV`, junto a `local holoGate = self:_holoGate(hoverAmt)`)

> Composição warp + holo via canvas intermediário.
>
> IMPORTANTE: LÖVE NÃO salva transformações em setCanvas. Se a gente só
> mudar canvas, o translate+scale do card center continua ativo, e o
> mesh seria desenhado FORA do offCanvas (que tem só w×h pixels),
> resultando em canvas vazio → HoloShader.draw em nada → carta invisível.
> Fix: push("all") + origin() pra zerar transform dentro do offCanvas.
>
> Força GATEADA pela interação (HoloShader v2, Out/2026): rara 0 em
> repouso (carta CRUA) → 0.25 no hover; lendária 0.08 (aro tênue,
> estático) → 0.5. A varredura só corre com anim > 0 — idle = estático.

## L949-950 (em `mouseUV`, junto a `HoloShader.draw(offCanvas, drawX, drawY, strength, 0, 1, 1, 0, 0,`)

> Agora aplica HoloShader sobre o canvas já warpado (transform externa
> já restaurada — drawX/drawY são coords locais pré-scale).

## L960-961 (em `mouseUV`, junto a `if CardAnimationLayer.isEnabled() then`)

> Animation layer (halo, embers, drip, flash, ring...) — pós-canvas.
> Scale já foi aplicado no stack via love.graphics.scale, então passa (1,1).

## L970-972 (em `mouseUV`, junto a `if self.seal then`)

> Forja (v2 Jul/2026): o badge "+N" foi REMOVIDO daqui — ele cobria o
> valor real do footer (que já mostra o stat upgradado). A evolução agora
> vive NA moldura: valor em verde-forja + gemas por nível (CardFrame).

## L991-992 (em `mouseUV`, junto a `if self.isHovered and not isRewardCard then`)

> Texto só aparece no hover e agora está na parte de cima
> Mas não desenha se for uma carta de reward (a descrição será desenhada pela CardRewardScreen)

## L994-998 (em `mouseUV`, junto a `local anchorY = y + totalOffsetY`)

> Âncora = TOPO REAL da carta (com lift do hover). O offset legado
> 70+20 vinha da era do texto inline e empurrava o tooltip 50px
> acima do necessário ("muito acima da carta", playtest Jul/2026).
> tooltipBelow (coringas ativos no TOPO do combate): painel ABAIXO
> da carta — acima, o clamp cobria o topo dela.

## L1004 (em `mouseUV`, junto a `local opts = self._tooltipOpts or {}`)

> Opções reaproveitadas (o draw roda todo quadro; sem tabela nova).

## L1011-1012 (em `mouseUV`, junto a `opts.side = self.tooltipSide`)

> tooltipSide (mão do combate): painel AO LADO da carta, não
> acima — acima ele cobria o inimigo (GameplayScene, palco).

## L1016-1017 (em `mouseUV`, junto a `opts.minY = self.tooltipMinY`)

> tooltipMinY (opcional): teto do painel — a barra superior é camada
> chrome e desenha POR CIMA dele.

## L1019-1022 (em `mouseUV`, junto a `if self.deferTooltip then`)

> deferTooltip (mão do combate): o tooltip é desenhado DEPOIS de
> tudo da mão — selos "+COMBO" das vizinhas, prévia de dano, toasts
> (dono, Out/2026: o selo da carta ao lado cobria o tooltip). A
> cena chama drawDeferredTooltip() no passe final.

## L1042-1044 (em `Card:drawDeferredTooltip`, junto a `function Card:_holoGate(hoverAmt)`)

> Interação que liga o reflexo rara/lendária (HoloShader v2): o hoverStrength
> (0..1, eased) OU a carta selecionada pra jogar — a mesma regra do ícone
> animado ("só na interação", dono Jul/2026). Em repouso devolve 0.

## L1054-1056 (em `Card:_holoGate`, junto a `local EDITION_SHADERS = {`)

> Mapping edition → (shader, strength_default).
> holo: a força vem de HoloShader.strengthFor("holo", gate) no draw (0.08 em
> repouso → 0.5 na interação); o valor aqui só marca a edition como válida.

## L1061-1062 (em `polychrome`, junto a `}`)

> "negative" (cor invertida) saiu em Out/2026 a pedido do dono: sem
> entrada aqui, uma cópia antiga desenha como carta comum.

## L1065-1066 (em `polychrome`, junto a `function Card:_getEditionShader()`)

> Retorna (shader, strength) pra edition atual. Nil se sem edition ou shader
> não disponível (load failed).

## L1077-1079 (em `Card:_getEditionShader`, junto a `function Card:setEdition(editionName, options)`)

> Aplica edition na carta. Dispara feedback visual (juice + sfx).
> editionName: "foil" | "holo" | "polychrome" | nil (remove)
> options: { silent = bool } pra suprimir feedback (ex: durante setup de save load)

## L1086 (em `Card:setEdition`, junto a `if editionName then`)

> Juice + sfx por tipo (mesma ideia do Balatro card.lua:set_edition).

## L1111-1113 (em `Card:setSeal`, junto a `local SEAL_COLORS = {`)

> _drawUpgradeBadge removido (v2 Jul/2026): o badge no canto inferior-direito
> COBRIA o valor real do footer. A evolução agora é mostrada NA moldura pelo
> CardFrame (valor verde-forja + gemas por nível) — a carta é o template vivo.

