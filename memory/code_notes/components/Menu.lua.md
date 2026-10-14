---
name: code_notes/components/Menu.lua
description: Comentários com decisão/regra/histórico colhidos de components/Menu.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/Menu.lua`

Origem: `components/Menu.lua` em `7dbdb60d` (57 de 128 blocos de comentário tinham marcador de decisão/regra/histórico).

## L18-19 (em `Menu`, junto a `local function reducedMotion()`)

> Movimento reduzido (Configurações → Jogo): a cena fica ESTÁTICA — nada
> deriva, pisca, respira ou varre. Informação nenhuma some (só movimento).

## L34-36 (em `instance.buttons`, junto a `instance.intro = {`)

> Estado de intro animation. Modificado por enterWithIntro().
> alphaTitle / alphaButtons[name] são interpolados via
> EventManager.ease pra fade-in stagger Balatro-style.

## L46-50 (em `buttonOffsetY`, junto a `instance.floatingCards = {`)

> 3 versos de carta flutuantes (Balatro-style demo cards). Cada uma tem
> um state de hover compartilhado com CardBackHover (replica Card:updateMouse).
> v2: CLICÁVEIS — clique dá spin 360° com juice (spinT anima em update).
> SÓ duas cartas: esquerda e direita (a 3ª de baixo poluía a coluna
> de botões — cortada a pedido do dono, Jul/2026).

## L56-58 (em `instance.floatingCards`, junto a `instance.osdTimer = 0`)

> v2 "o televisor é o palco" (docs/plan/menu-crt-v2.md):
> OSD do aparelho (tag de canal + relógio) que aparece ao entrar e
> some em ~3.5s como TV de verdade.

## L60-63 (em `instance.floatingCards`, junto a `instance.motes = {}`)

> Motes de poeira dourada derivando (vida ambiente barata).
> v3 (Out/2026): 60% vivem no FEIXE de luz da lanterna (cone do teto ao
> livro — `shaft = true` mantém o mote dentro do cone no update), o resto
> vaga pela sala. Poeira que só se vê onde há luz, como numa sala real.

## L75-76 (em `instance.motes`, junto a `instance._candleFlare = 0`)

> Flare das velas (0..1, decai): a sala reage — entrada no menu e clique
> nas cartas fazem as chamas crescerem por um instante.

## L100-101 (em `Menu:createButtons`, junto a `local SaveManager = require("engine.SaveManager")`)

> Botão Continuar (F1): só aparece com run salva em disco. Retomar é a
> ação mais provável de quem tem save — fica ACIMA de Jogar.

## L185-187 (em `Menu:createButtons`, junto a `for _, btn in pairs(self.buttons) do`)

> v2.2: SEM ícones nos itens do menu (pedido do dono — eram fracos e
> repetidos; lista de TV é texto puro, a seta âmbar do hover já guia).
> v2.1: look "lista de TV" (variant tv) — barra de seleção âmbar.

## L241-242 (em `Menu:update`, junto a `self:_ensureTitleDyna()`)

> DynaText do título (lazy-init em ensure). update progredindo timer interno
> pra que pop_in cascade + rotate wobble animem por frame.

## L244-246 (em `Menu:update`, junto a `if self._titleDyna then`)

> Movimento reduzido: o update SEGUE (a cascata de pop_in precisa dele
> pra revelar as letras — congelar o update deixava só o "G"), mas o
> wobble de rotação desliga.

## L256-257 (em `Menu:update`, junto a `self.osdTimer = (self.osdTimer or 0) + dt`)

> OSD do aparelho conta o tempo pra sumir (TV real: ~3.5s após trocar
> de canal). enterWithIntro reseta pra 0.

## L277-278 (em `self.embers`, junto a `local tf = self._sceneTf`)

> Poeira dourada deriva pra cima (wrap vertical). Motes do FEIXE ficam
> dentro do cone da lanterna (meia-largura cresce com a descida).

## L294 (em `self.embers`, junto a `do`)

> v2.1: PARALLAX suavizado (mouse → alvo; lerp evita tranco).

## L305-306 (em `self.embers`, junto a `self.embers = self.embers or {}`)

> v2.1: BRASAS subindo das velas (faísca ocasional, vida curta).
> Com flare (entrada/clique) as velas cospem mais.

## L327-329 (em `self.embers`, junto a `function Menu:_ensureTitleDyna()`)

> Cria/recria a instância DynaText do título. Recria se a fonte responsiva
> mudou (resize) ou se o texto mudou (locale switch). Cache local em
> self._titleDyna; o objeto guarda timer interno (pop_in + bump/rotate).

## L341 (em `Menu:_ensureTitleDyna`, junto a `rotate = true,`)

> wobble idle Balatro-style

## L369 (em `Menu:draw`, junto a `self:_drawFloatingCards()`)

> Cartas decorativas flutuantes (Balatro-style demo).

## L375-377 (em `Menu:draw`, junto a `for name, button in pairs(self.buttons) do`)

> (o subtítulo "Cartas arcanas. Decisões fatais." que ficava aqui foi
> REMOVIDO em 13/Out a pedido do dono: "tira essas coisas embaixo de
> Grimoire"; a frase vive só na tela do computador da abertura)

## L379-380 (em `Menu:draw`, junto a `for name, button in pairs(self.buttons) do`)

> Desenha botões. Durante intro: cada botão fica invisível até seu alpha
> passar de 0.1, depois faz slide-up de 12px com back_out (efeito "pop in").

## L394-395 (em `Menu:draw`, junto a `self:_drawProfilePlaque()`)

> Perfil persistente (vitórias/melhor progresso) + versão no rodapé —
> o menu "lembra de você" (repaginada Jul/2026).

## L406-408 (em `Menu:draw`, junto a `function Menu:_drawOsdChrome()`)

> ===== v2: OSD do televisor =====
> "AV-1 GRIMOIRE" + relógio real no canto sup-dir. Visível ~3.5s após
> entrar no menu, depois some com fade — comportamento de TV de verdade.

## L423-426 (em `Menu:_drawOsdChrome`, junto a `function Menu:_drawButtonCrtFx(btn)`)

> ===== v2: estética CRT nos botões (hover) =====
> (a) varredura de scanline clara descendo em loop (scissor no rect);
> (b) glow de fósforo pulsante na borda; (c) seta OSD piscando à esquerda.
> Desenhado POR CIMA do Button — o widget global fica intocado.

## L433-434 (em `Menu:_drawButtonCrtFx`, junto a `if require("src.ui.CRTShader").isEnabled() then`)

> (a) varredura: banda clara de 10px descendo pelo botão (loop 0.9s).
> Artefato de TUBO: só com o CRT ligado em Configurações (níveis, Out/2026).

## L446-448 (em `Menu:_drawButtonCrtFx`, junto a `do`)

> (a2) GLINT pixel: um brilho de 2 px corre a borda de cima do botão em
> passos de 4 px (grade), com um rastro de 1 px — reflexo de metal, não
> gradiente. Estático em movimento reduzido (fica parado no canto).

## L480-482 (em `Menu:_drawButtonCrtFx`, junto a `function Menu:_drawEmbers()`)

> ===== v2.1: brasas das velas =====
> Faíscas ocasionais subindo da chama com sway senoidal, esfriando de
> amarelo-quente pra laranja antes de apagar.

## L504-508 (em `ANCH`, junto a `local SHAFT = { xr = 0.50, topY = 0.04, botY = 0.72, hwTop = 0.012, hwBot = 0.17 }`)

> ===== v3: FEIXE da lanterna =====
> A lanterna pendurada no teto da arte (x 0.50, y 0.04 do PNG) ilumina o
> livro (y ~0.70). O cone é desenhado em 3 DEGRAUS aditivos (nada de
> gradiente suave) e balança devagar com noise. Devolve, pra uma altura
> normalizada `ay`, o centro x e a meia-largura do cone (normalizados).

## L523-525 (em `Menu:_drawLightShaft`, junto a `local px = tf.dh / 256`)

> NA GRADE DA ARTE: o cone é uma pilha de linhas de 1 px da arte, cada
> uma com largura em múltiplos de 1 px da arte — bordas em escada, como
> o resto do cenário (um polígono antialiased lia como forma vetorial).

## L539-540 (em `Menu:_drawLightShaft`, junto a `local y0 = math.floor(tf.oy + iy * px)`)

> linhas que se ENCOSTAM exatamente (sem fresta nem sobreposição —
> em blend aditivo qualquer uma das duas vira risca horizontal)

## L550-552 (em `Menu:_drawLightShaft`, junto a `function Menu:_drawVignette(bgAlpha)`)

> ===== v3: VINHETA que respira =====
> Bordas escurecem em 3 molduras DEGRAU (sem gradiente), com período lento
> (~7 s) — a sala "respira" com a luz das velas. Estática em movimento reduzido.

## L573-576 (em `Menu:_drawVignette`, junto a `local PAGE_QUAD = { x = 250, y = 168, w = 42, h = 20 }   -- px da arte 400×256`)

> ===== v3: a PÁGINA se mexe =====
> O canto da página direita do livro (recorte do PNG) levanta 1-2 px da arte
> em passos secos, de vez em quando — correnteza de ar na sala. Nada de
> deformação suave: é o pixel subindo um degrau.

## L619-622 (em `Menu:_drawMotes`, junto a `function Menu:_drawProfilePlaque()`)

> Perfil no RODAPÉ direito, espelhando a versão no rodapé esquerdo —
> uma linha discreta, sem caixa, que não briga com a arte do menu
> (a plaque em caixa no canto superior destoava do cenário — feedback
> do dono, Jul/2026). Texto com sombra ink pra legibilidade sobre a arte.

## L634-635 (em `Menu:_drawProfilePlaque`, junto a `local parts = {}`)

> Linha única: "★ 2 vitorias · Melhor: Ato 2-6" (ou só corridas se
> nunca venceu). Curta, sem rótulo "PERFIL" — o conteúdo se explica.

## L685-687 (em `Menu:_drawVersionFooter`, junto a `local label = I18n.t("credits.link")`)

> Link "Créditos" logo depois da versão (substitui o antigo "Sobre"
> placeholder). Link de rodapé, não item da coluna: a coluna já tem 6
> botões e um 7º empurraria o "Sair" pra fora da tela em 768px.

## L703-711 (em `self._creditsRect`, junto a `local BG_SEQ = {`)

> ===== v2.1: BACKGROUND EM CAMADAS VIVAS =====
> O cenário deixou de ser um PNG parado: parallax de mouse (a sala inteira
> responde), luz de vela PULSANDO nas duas velas (âncoras na imagem),
> flicker quente global, fumaça de incenso derivando na frente.
> v2.3: ANIMAÇÃO DE VELA — o background cicla por frames de flicker
> desenhados à mão (crossfade suave, "vida de fogo" igual às luminárias dos
> postes). Ordem pedida pelo usuário; "menu" = a que já tínhamos (chama
> discreta, funciona como respiro). O laço volta pro começo ("menu" no fim
> emenda com "menu" no início → dwell mais longo no estado de descanso).

## L721-724 (em `BG_SEQ`, junto a `local BG_FPS = 10`)

> MESMA cadência do fogo dos postes do jogo: WorldRoad troca o frame da
> chama a 10 fps com corte seco (fr[floor(_time*10)%#fr]). O menu segue igual
> — flicker rápido, sem crossfade (só a chama muda entre os frames, então o
> corte seco lê como fogo vivo, não como troca de imagem).

## L727-728 (em `BG_SEQ`, junto a `local function bgFrame(t)`)

> Deterministic a partir do relógio: retorna (from, to, mix 0..1).
> Corte seco → to = from e mix = 0 (drawParallaxCrossfade desenha só `from`).

## L743-744 (em `Menu:drawBackground`, junto a `local fromScene, toScene, mix = bgFrame(t)`)

> CAMADA 1: cenário com parallax (mouse desloca a sala) + crossfade de
> vela entre os frames do ciclo (BG_SEQ). Movimento reduzido: frame fixo.

## L758 (em `Menu:drawBackground`, junto a `self:_drawLightShaft(tf, bgAlpha)`)

> CAMADA 2b: feixe da lanterna do teto sobre o livro (degraus)

## L790-792 (em `Menu:drawBackground`, junto a `local CANDLE_ANCHORS = {`)

> Âncoras das velas na IMAGEM do menu (coords relativas ao PNG 400×256,
> medidas na captura). O transform do parallax converte pra tela — a luz
> acompanha a vela mesmo com a sala deslocando.

## L822-823 (em `Menu:_drawCandleGlow`, junto a `local flick = (0.70 + 0.30 * love.math.noise(t * 5.5, a.phase)) * (1 + 0.6 * flare)`)

> flicker orgânico (noise, não seno — vela real não é metrônomo);
> flare (entrada/clique): a chama cresce e clareia por um instante

## L838-839 (em `Menu:_drawCandleGlow`, junto a `local SMOKE_WISPS = {`)

> Fumaça de incenso: 3 novelos derivando devagar na frente do cenário
> (parallax mais forte que o fundo = profundidade de verdade).

## L902-904 (em `colA`, junto a `if self._titleDyna then`)

> Título via DynaText (Balatro engine/text.lua port): pop_in cascade na
> entrada + rotate wobble idle + shadow integrada. Substitui love.graphics.print
> direto pra dar movimento "vivo" característico do polish do Balatro.

## L918-919 (em `colA`, junto a `function Menu:_drawFloatingCards()`)

> Cartas decorativas que flutuam atrás do título (Balatro-style demo cards).
> Cada uma tem fase própria pra dessincronizar drift+rotação.

## L944-945 (em `Menu:_drawFloatingCards`, junto a `CardBackHover.update(fc.hover, mx, my, cx, cy, cardW, cardH, dt, "up")`)

> Atualiza hover state (tilts/lift/perspective via CardBackHover.update,
> mesmo math que Card:updateMouse). liftDir="up" = sobe quando hovered.

## L969-970 (em `Menu:_drawFloatingCards`, junto a `function Menu:onPlayClick()`)

> (F1 do UI Overhaul: drawInstructions REMOVIDO — instruções de gameplay
> vazavam por cima da arte do livro; dicas de jogo pertencem ao gameplay.)

## L973-975 (em `Menu:onPlayClick`, junto a `if self._hasSave and not self._newRunConfirmed then`)

> Slot ÚNICO de save (padrão StS): começar outra corrida apaga a salva no
> primeiro checkpoint. Antes era SEM PERGUNTAR — um clique distraído em
> "Jogar" em vez de "Continuar" jogava fora a run (known_gaps 25).

## L993 (em `onConfirm`, junto a `if Sfx.fadeMusicOut then Sfx.fadeMusicOut(0.5) end`)

> Fade-out da música menu antes de entrar no gameplay.

## L995-997 (em `onConfirm`, junto a `if _G.jiggleScreen then _G.jiggleScreen(0.8) end`)

> Jiggle + flash ao entrar no jogo: feedback cinematográfico Balatro-style
> (game.lua dispara o mesmo combo no `start_run`). Sinaliza ao jogador
> "transição importante acontecendo".

## L1028-1029 (em `Menu:setCreditsCallback`, junto a `function Menu:requestQuit()`)

> ESC no menu principal: antes fechava o jogo NA HORA (sem animação nem
> pergunta) — quem aperta ESC "pra voltar" perdia a janela. Agora pergunta.

## L1047 (em `Menu:onQuitClick`, junto a `CRTShader.powerOff(1.2, function() love.event.quit() end)`)

> v3.6: colapso → linha → ponto de fósforo esfriando até apagar

## L1059-1060 (em `Menu:show`, junto a `self:createButtons()`)

> recria botões: o save pode ter surgido/sumido desde a última visita
> (Continuar aparece/some — F1 do UI Overhaul)

## L1065-1067 (em `Menu:show`, junto a `function Menu:enterWithIntro()`)

> Reanima o menu como se fosse a primeira vez: alpha 0→1 staggered nos botões,
> title scale com back-out, music fade-in. Chamado por main.lua após o splash
> e ao voltar do gameplay/collection/settings.

## L1096-1097 (em `Menu:enterWithIntro`, junto a `EM.clear("menu_intro")`)

> Limpa queue de intro anterior caso ainda tenha resíduo
> (ex: jogador entra/sai do menu rapidamente).

## L1100-1101 (em `Menu:enterWithIntro`, junto a `EM.parallelEase(self.intro, "alphaBg",       1, 0.35, "smooth",   "menu_intro")`)

> IMPORTANTE: usar parallelEase pra todas eases iniciarem AGORA em
> paralelo. ease bloqueante faria fade-in sequencial absurdamente longo.

## L1106-1108 (em `Menu:enterWithIntro`, junto a `local order = { "continueRun", "play", "collection", "achievements", "settings", "quit" }`)

> Stagger botões: 0.08s offset entre cada (delays absolutos).
> continueRun entra no stagger (antes surgia seco, a 100%, enquanto o
> resto da coluna fazia fade-in — o único botão "fora do ritmo").

## L1122-1123 (em `order`, junto a `local okDir, MD = pcall(require, "src.systems.MusicDirector")`)

> Avisa o diretor de trilha que o menu já está tocando, senão ele
> reinicia a mesma faixa no primeiro update depois do splash.

## L1149-1150 (em `Menu:mousepressed`, junto a `if not consumed and button == 1 then`)

> v2: cartas flutuantes clicáveis (easter egg) — só se o clique não
> caiu em botão (botões têm prioridade no z-order de hit).

