---
name: code_notes/components/PackOpenScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/PackOpenScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/PackOpenScreen.lua`

Origem: `components/PackOpenScreen.lua` em `7dbdb60d` (84 de 141 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local PackOpenScreen = {}`)

> components/PackOpenScreen.lua
> Cinemática de pack opening fiel ao source do Balatro
> (functions/UI_definitions.lua:1629-1857). Estrutura:
>
> ┌────────────────── PACK OPEN OVERLAY ──────────────────┐
> │                                                        │
> │              [ CardArea linear horizontal ]            │
> │                                                        │
> │      ╔══════════════╗              ┌──────┐            │
> │      ║  PACOTE X    ║              │ SKIP │            │
> │      ║  Choose 1    ║              └──────┘            │
> │      ╚══════════════╝                                  │
> └────────────────────────────────────────────────────────┘
>
> Sequência:
> T=0.0   Loja desliza pra baixo (handled by main.lua via callback).
> Sleeve do pack aparece materializando no centro.
> T=0.4   Sleeve.explode() — partículas + screen jiggle.
> T=1.3   Cards spawnam na posição do explode e voam pra CardArea linear,
> materializando em cascata 80ms.
> T=1.5   DynaText "Pacote X" + "Choose N" aparecem com pop_in cascade.
> Skip button fica clicável.
> <click> Card: dissolve + adiciona ao deck. Skip: cards restantes dissolvem.
> Close   Loja desliza de volta. onComplete chamado.
>
> NÃO TEM backdrop preto — segue Balatro (shop sai de cena, pack toma o lugar).

## L48-51 (em `PackOpenScreen`, junto a `local function reducedMotion()`)

> Acessibilidade: com reducedMotion o estouro continua ENTREGANDO a informação
> (qual pacote era, quais cartas vieram) — o que some é o exagero: wobble,
> jiggle de tela, rotação do burst e os destroços. Flash e onda de choque
> permanecem, mais curtos e fracos, porque são eles que marcam o "abriu".

## L66-71 (em `TIMING`, junto a `local function sleeveCenter(zones)`)

> Pose do sleeve = mesma Y da linha de cards. Quando o pack explode, cards
> materializam ali mesmo e se espalham horizontalmente. Padrão Balatro
> (UI_definitions.lua:1631-1635 — CardArea fica na posição da hand).
> Centro do sleeve = centro da ZONA das cartas. O envelope estoura exatamente
> de onde as cartas vão nascer; se as duas coisas divergem, as cartas "pulam"
> do nada no primeiro frame.

## L80-86 (em `sleeveCenter`, junto a `function PackOpenScreen:_computeZones()`)

> A carta revelada é a RECOMPENSA — o clímax da cinemática. Ela usava a mesma
> escala da mão (Config.Cards.BASE_SCALE), o que a 1024x768 dava ~128x192: as
> três juntas ocupavam menos área que o banner do rodapé. Aqui ela ganha
> escala própria, maior, e o respiro entre elas triplica (0.12 → 0.34 da
> largura) pra lerem como TRÊS ESCOLHAS e não como uma fileira colada.
> Zonas da tela de escolha. Recalculadas em show() e resize(); todo o desenho
> lê daqui. Ver src/ui/PackChoiceLayout.lua pro plano e pro porquê.

## L122 (em `instance._selectedCards`, junto a `instance._footerAlpha = 0`)

> banner do título entra só em TIMING.titleAppear

## L123 (em `instance._selectedCards`, junto a `instance.selectedCardIdx = nil`)

> F3: card selection 3-zone (Balatro pattern, replica CardRewardScreen).

## L134-135 (em `instance._selectedCards`, junto a `function PackOpenScreen:show(pack, onComplete)`)

> pack: { kind, size, choose, instances }
> onComplete(selectedList) — selectedList = lista de cartas escolhidas (pode ser vazia).

## L151-153 (em `self._selectedCards`, junto a `self._theme = PackThemes.get(pack.kind)`)

> Tema do tipo de pacote: manda na cor do flash, no burst, na onda de
> choque, nos destroços, no título e no pitch dos sons. Abrir um Arcano
> tem que PARECER diferente de abrir um Espectral.

## L168-170 (em `self._selectedCards`, junto a `self.titleText = nil`)

> _buildTitleTexts NÃO roda aqui: o banner entra em TIMING.titleAppear
> (ver _scheduleTimeline). Criar as DynaTexts só naquele instante é o que
> faz a cascata de pop_in tocar NA ENTRADA em vez de já ter terminado.

## L175-177 (em `self._selectedCards`, junto a `pcall(PackThemes.registerSealSounds)`)

> Registra os sons de lacre na 1a abertura (idempotente). Fica aqui, e nao
> no boot, porque main.lua nao e territorio deste trabalho -- se um dia a
> chamada entrar la, esta vira no-op e nada muda.

## L180-181 (em `self._selectedCards`, junto a `Sfx.play("shopOpen")`)

> F11.5: shopOpen (cozy chime) na entrada — não duplica com pack-seal-break
> que vem em sleeve.explode (T=0.7s).

## L197-206 (em `PackOpenScreen:isVisible`, junto a `function PackOpenScreen:_rebuildCardArt()`)

> Recomputa todo o layout em resposta a resize. Mantém estado de seleção
> (selectedCardIdx) intacto — só recalcula posições de cartas + skip button.
> Reconstroi a ARTE das cartas. Trocar o modo de video (fullscreen, drag de
> borda) invalida o CONTEUDO de todo Canvas: o objeto sobrevive, os pixels
> nao. As cartas do pacote guardam esse canvas em , entao depois
> de um resize elas desenham VAZIAS -- moldura e selo aparecem, a arte nao.
> Era este o "toda desconfigurada" que o dono viu ao dar fullscreen.
>
> Limpar o cache do CardFrame NAO basta: a instancia guarda a referencia
> morta. Tem que limpar E re-renderizar, reatribuindo card.image.

## L217-218 (em `PackOpenScreen:_rebuildCardArt`, junto a `love.graphics.setCanvas()`)

> render usa beginDraw/endDraw; crash no meio deixa o canvas
> preso ativo e trava o present() do frame seguinte.

## L227-229 (em `PackOpenScreen:resize`, junto a `ShopEngraving.clearCache()`)

> Bitmaps gravados (cartuchos de custo/dano) sao rasterizados por tamanho:
> estado cacheado novo morre no resize, no mesmo commit
> (ui_layout_invariants, secao 2).

## L231 (em `PackOpenScreen:resize`, junto a `self:_rebuildCardArt()`)

> ORDEM: arte primeiro (o layout mede image:getWidth()), zonas depois.

## L236-237 (em `PackOpenScreen:resize`, junto a `end`)

> Os botoes de acao sao reposicionados a cada frame pela zona D, entao
> resize nao precisa toca-los -- so garantir que a selecao sobrevive.

## L240-242 (em `PackOpenScreen:resize`, junto a `function PackOpenScreen:_dissolvePalette()`)

> Paleta de dissolve/materialize das CARTAS do pacote. Antes era sempre o
> roxo/magenta de DissolveShader.palette("booster") — o que fazia as cartas
> do Celestial nascerem roxas. Agora nascem e somem na cor do pacote.

## L270-278 (em `self._finalCardPositions`, junto a `local spawnX, spawnY`)

> Cards começam SNAP na posição do sleeve. setRenderPos zera a
> interpolação interna — primeira chamada não fica "voando do nada".
>
> MAS: se a carta JÁ voou pro lugar dela (`_packDispatched`), snapar de
> volta pro sleeve seria um teleporte. Isso acontecia de verdade em
> `resize()`, que chama esta função: redimensionar a janela no meio da
> revelação jogava as três cartas de volta pro centro e elas FICAVAM lá
> (nada re-emitia o setTargetPos). Carta já despachada recalcula direto
> pra posição final nova.

## L306-315 (em `self._finalCardPositions`, junto a `if not card._packDispatched then`)

> ESTADO DE NASCIMENTO, so pra carta que ainda nao apareceu.
> `dissolve = 1` significa "invisivel, esperando materializar". Isto
> aqui ficava incondicional porque _layoutCards so era chamado UMA vez,
> na abertura -- mas resize() tambem o chama, e entao ele apagava as
> cartas JA REVELADAS: dissolve voltava a 1, elas sumiam, as etiquetas
> de raridade sumiam junto (exigem dissolve < 0.2) e nada as trazia de
> volta, porque a timeline de materializacao ja tinha rodado.
> Era este o "toda desconfigurada" ao dar fullscreen.
> Licao geral: funcao usada por resize() nao pode reaplicar estado
> INICIAL -- ela recalcula geometria, nao renasce a tela.

## L327-331 (em `PackOpenScreen:_buildSkipButton`, junto a `local label = I18n.t("common.skip")`)

> F11.2: reduzido de 110×48 → 90×34 pra ficar discreto, não disputar atenção com cards.
> F12: 90px é largura de "Pular", não de "Ueberspringen" — em alemão o
> Button caía na truncagem e o rótulo virava "Ue...", que não informa nada.
> Mede o texto JÁ LOCALIZADO e cresce só o necessário (o discreto continua
> discreto em pt_BR; quem tem palavra longa ganha espaço em vez de reticências).

## L346-347 (em `PackOpenScreen:_buildTitleTexts`, junto a `local th = self._theme`)

> Title: nome do pack ("Pacote Padrão", etc). As DUAS cores do ciclo saem
> do tema — o nome do pacote é escrito na cor do próprio pacote.

## L354-359 (em `PackOpenScreen:_buildTitleTexts`, junto a `bump_phase = 0.42,`)

> F12: o bump default (bump_phase=200) defasa letras vizinhas em
> ~-1.06 rad, o que ESPALHA as letras — num frame parado o título lia
> como texto quebrado (o "P" de Pacote 14px acima do resto). Com fase
> pequena o salto VIAJA pela palavra: vira ondulação, que é o efeito
> que sempre se quis. Amplitude cai pra ~6px (era 14) porque agora
> várias letras estão levantadas ao mesmo tempo.

## L375-379 (em `colours`, junto a `self.chooseText = DynaText.new({`)

> Choose N (atualiza dinamicamente). SEM bump e SEM rotate: é texto
> INFORMATIVO ("quantas você ainda escolhe") e precisa ficar na linha de
> base. Era ele o pior caso do espalhamento — "Escolha 1" saía com o E
> abaixo e o "a" acima, ilegível em frame parado. A vida dele vem do
> pop_in na entrada e do pulse quando o número muda.

## L406-408 (em `PackOpenScreen:_scheduleTimeline`, junto a `if not still then`)

> T=0.45-0.7: PRÉ-EXPLODE (Balatro card.lua:explode pattern). O sleeve
> ENCOLHE um tico e treme (o tremor vem do _elapsed no update) — é a
> inspiração antes do grito. Com reducedMotion, nada disso acontece.

## L420-425 (em `PackOpenScreen:_scheduleTimeline`, junto a `if FlashShader and FlashShader.trigger then`)

> Flash: o branco do FlashShader dá o "estalo"; por cima dele entra
> uma lavagem ADITIVA na cor do pacote (self._washAlpha, decaída no
> update). É o que separa o roxo do Arcano do verde do Espectral já
> no primeiro frame do estouro.
> O branco cedeu espaço pra lavagem colorida (era 0.7): somados, o
> estouro tem o mesmo PUNCH de antes, só que agora tem COR.

## L429-437 (em `PackOpenScreen:_scheduleTimeline`, junto a `self._washAlpha = still and 0.09 or 0.16`)

> 0.50 → 0.35: somada ao branco do FlashShader, a lavagem a 0.50
> estourava a tela inteira e o cenário sumia atrás da cor por ~0.2s.
> Quem carrega a identidade é o BURST (agora grande e rápido), não um
> filtro por cima de tudo.
> 0.35 → 0.16. A lavagem existia pra dar COR a um estouro que era um
> sprite laranja genérico pros 5 tipos. Agora cada tipo tem arte
> própria e a cor vem de lá; a lavagem voltou a ser só o que devia
> ser: o clarão de um instante. Mais que isso tinge a cena inteira —
> a mesma doença do tint, só que em tela cheia.

## L445-452 (em `PackOpenScreen:_scheduleTimeline`, junto a `if th.sealCode and Sfx.has and Sfx.has(th.sealCode) then`)

> F11.5: packSealBreak (chunky paper tear) no explode. F12: o pitch é
> do tema (Espectral grave/arrastado, Celestial agudo/cristalino) e
> uma camada de acento temática entra por cima, se existir registrada.
> Som do lacre POR TIPO. Fallback por scan, igual ao burstFile: sem o
> arquivo do tipo, volta pro packSealBreak generico -- e so nesse
> caminho o pitch por tema continua valendo, porque ali ele ainda e a
> unica coisa que diferencia os cinco. Com gravacao propria o pitch
> volta a 1.0: mexer nele de novo seria tingir o som por cima da arte.

## L462-471 (em `PackOpenScreen:_scheduleTimeline`)

> NOME DA EASE: "easeout", minúsculo. O lookup de engine/Easing.lua é
> case-sensitive, então o "easeOut" camelCase que estava aqui era nil
> e caía em `smooth` — as seis animações do estouro NUNCA rodaram com
> a curva que o código dizia. Corrigido de verdade (e não maquiado
> pra "smooth") porque easeout é a curva FÍSICA de uma detonação:
> velocidade máxima no instante do impacto, desacelerando. Com smooth
> o burst tinha ramp-up — lia como algo sendo INFLADO, não estourado.
> Os tempos abaixo foram re-afinados pra curva certa: easeout percorre
> 44% do trajeto em 1/4 do tempo (smooth faz 16%), então o que era
> curto pra compensar o ramp-up de smooth agora sobra.

## L473-475 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallelEase(self, "_sleeveDissolve", 1, 0.22, "easeout")`)

> Sleeve "explode" — some decidido, sem fantasma.
> 0.25 → 0.22: com easeout ele já está 44% dissolvido em 60ms; encurtar
> garante que suma antes das cartas entrarem.

## L477-478 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallelEase(self, "_sleeveScale", 1.55, 0.28, "easeout")`)

> 1.4 → 1.55 em 0.28: a expansão agora é toda no começo, então dá pra
> ir mais longe sem ficar lento — lê como "arrancado", não "inchado".

## L481-487 (em `PackOpenScreen:_scheduleTimeline`, junto a `local bScale = th.burstScale or 1.8`)

> Burst overlay (sprite PixelLab 'burst.png'): expande, gira e some.
> Escala/tempo/sentido de giro saem do tema — Celestial abre grande e
> lento como um céu; Bufão roda feito roda de circo; Espectral é
> pequeno, anti-horário e demora pra dissipar.
> bTime fica como está: com easeout a onda abre quase toda no primeiro
> terço e a borda externa SETTLE devagar no resto — que é exatamente
> a personalidade por tipo que bTime codifica.

## L490-494 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallelEase(self, "_burstScale", bScale, bTime * 0.5, "easeout")`)

> A ESCALA abre em METADE do bTime; rotação e fade continuam no bTime
> cheio. Antes as três duravam o mesmo, então o burst só alcançava o
> tamanho máximo quando o alpha já tinha caído — nunca estava grande
> E brilhante ao mesmo tempo, e a onda de choque (que abre rápido)
> ficava 3x maior que ele. Agora ele ESTOURA aberto e depois assenta.

## L498-499 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallelEase(self, "_burstRotation",`)

> Giro que nasce rápido e assenta = momento. Com smooth ele
> acelerava no meio e parecia motor ligando.

## L503-506 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallel(0.20, function()`)

> Fade-out do burst começa após o pico. 0.16 → 0.20: o fade-in agora
> termina mais cedo, então sem esse respiro o brilho máximo quase não
> existiria. Sai com easeout também — despenca e deixa um rastro
> fraco, que é como fumaça dissipa (o Espectral vive disso).

## L511-512 (em `PackOpenScreen:_scheduleTimeline`, junto a `self:_spawnDebris()`)

> Destroços: confete, pó arcano, estrelas ou ectoplasma — a FÍSICA é
> que carrega a identidade (ver PackThemes.debris).

## L516-519 (em `PackOpenScreen:_scheduleTimeline`, junto a `for i, card in ipairs(self.pack.instances) do`)

> T=1.3+: cards materializam na posição do sleeve. Quase em paralelo
> (delay 0.15s após materialize start) cada card SETA target pra posição
> final na linha — updateRender (lerp 16/s) lerpa naturalmente. Resultado:
> cards "voam" do sleeve pra linha enquanto materializam.

## L528-530 (em `PackOpenScreen:_scheduleTimeline`, junto a `local basePitch = (self._theme and self._theme.revealPitch) or 0.9`)

> F11.5: packCardReveal por card que materializa, pitch crescente.
> F12: o pitch BASE é do tema — a escala de revelação do Espectral
> soa mais grave que a do Celestial.

## L535-536 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallel(at + 0.18, function()`)

> Alvo da linha disparado um tiquinho depois do materialize start, pra
> card já estar visível enquanto voa.

## L544-547 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallel(at + 0.52, function()`)

> POUSO: a carta chegava no lugar e simplesmente parava. Um kick de
> escala no instante em que assenta dá o peso que faltava — e é POR
> CARTA, casando com o packCardReveal de pitch crescente que já
> tocava sozinho, sem contrapartida visual.

## L559-563 (em `PackOpenScreen:_scheduleTimeline`, junto a `end)`)

> (O recuo do banner saiu aqui: ele existia porque o titulo ficava no
> RODAPE, competindo com as cartas. Agora o contexto e uma barra fina
> no topo, que nao disputa atencao -- e o recuo tinha um efeito
> colateral feio: derrubava _footerAlpha abaixo do limiar que desenha
> o botao Pular, entao ele sumia da tela pra sempre.)

## L566-570 (em `PackOpenScreen:_scheduleTimeline`, junto a `EventManager.parallel(TIMING.titleAppear, function()`)

> T=1.5: o banner do pacote ENTRA. Antes ele era desenhado desde o frame
> 0 — TIMING.titleAppear existia na tabela mas nunca era usado, então o
> nome do pacote já estava na tela enquanto o envelope ainda estava
> lacrado, e a revelação não tinha momento. Agora chega junto com as
> cartas assentando.

## L583-586 (em `PackOpenScreen:_scheduleTimeline`, junto a `function PackOpenScreen:_burstImage()`)

> Sprite do estouro do tipo atual. Fallback por SCAN (mesmo padrão dos sons
> assinatura de joker): se o arquivo do tema não existir no disco, cai no
> burst.png genérico — nenhum tipo fica sem explosão se um asset sumir, e
> adicionar um tipo novo é só dropar o PNG e apontar o burstFile.

## L599-603 (em `PackOpenScreen:_burstImage`, junto a `function PackOpenScreen:_spawnDebris()`)

> ============================================================================
> DESTROÇOS DO ESTOURO (física por tipo — PackThemes.KINDS[kind].debris)
> ============================================================================
> RNG: cosmético, logo RNG global (love.math/math.random). Os streams do Rng
> são pra decisão de RUN — destroço de partícula não pode consumir seed.

## L626-627 (em `list`, junto a `col = (i % 3 == 0) and self._theme.accent or self._theme.glow,`)

> Dois terços na cor de brilho, um terço no acento: o contraste
> entre as duas é o que faz o estouro ler como "do tipo X".

## L682-684 (em `PackOpenScreen:_drawDebris`, junto a `function PackOpenScreen:_drawShockwave()`)

> Onda de choque: anel que abre do centro na cor do pacote. É o elemento
> mais barato e mais legível do estouro — mesmo com reducedMotion ele fica
> (não é tremor, é gráfico), só menor e mais rápido.

## L693-694 (em `PackOpenScreen:_drawShockwave`, junto a `local maxR = 210 * (th.ringScale or 1)`)

> 320 → 210: o anel chegava a 350px de raio e dominava a tela, ficando 3x
> maior que o próprio estouro. A onda é o ECO da explosão, não o evento.

## L697-698 (em `PackOpenScreen:_drawShockwave`, junto a `local a = (1 - p) * (1 - p) * (1 - p) * 0.80`)

> (1-p)^3: some mais rápido. Com quadrático ele ficava visível metade da
> animação e, sendo um círculo perfeito e nítido, lia como wireframe.

## L704-706 (em `PackOpenScreen:_drawShockwave`, junto a `local band = { {-7, 0.22}, {-3, 0.60}, {0, 1.00}, {3, 0.45}, {7, 0.18} }`)

> Falloff barato: 4 circunferências concêntricas com alpha decrescente
> pros dois lados. Uma linha só, por mais grossa que fosse, tinha borda
> dura — energia não tem contorno.

## L731-732 (em `band`, junto a `function PackOpenScreen:_drawColourWash()`)

> Lavagem colorida em cima do flash branco. Aditiva e fullscreen: o estouro
> TINGE a tela com a cor do pacote por ~0.35s.

## L748-749 (em `PackOpenScreen:_updateChooseText`, junto a `local label = self.choicesRemaining > 0`)

> "Escolha N" / "Fechando..." eram PT cravado SEM ACENTO -- invisivel pra
> trava de literais acentuados, e visivel pro jogador em qualquer idioma.

## L770 (em `PackOpenScreen:close`, junto a `local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()`)

> Cards escolhidos voam pro canto inferior (deck) antes de dissolver.

## L802-806 (em `PackOpenScreen:selectCard`, junto a `self._washAlpha = math.max(self._washAlpha or 0, 0.09)`)

> Pisca na cor do pacote junto com o flash branco (mesma lavagem do
> estouro, bem mais fraca) — escolher fecha o ciclo cromatico do evento.
> 0.22 -> 0.09. O estouro do pacote usa 0.16; escolher uma carta estava
> lavando a tela MAIS que a explosao que abre o pacote -- hierarquia
> invertida. O clarao da escolha e uma confirmacao, nao um evento maior.

## L824-825 (em `PackOpenScreen:update`, junto a `if not self._sleeveExploded and not reducedMotion() then`)

> Wobble pré-estouro: o sleeve treme em rotação senoidal entre T=0.45 e o
> estouro, com amplitude subindo. É o telegrafo do "vai estourar".

## L835-838 (em `PackOpenScreen:update`, junto a `if (self._washAlpha or 0) > 0 then`)

> Decaimento da lavagem colorida do estouro. 1.8 → 2.6/s (0.50 zera em
> ~0.19s): a 1.8 ela ainda valia 0.14 dois décimos depois do estalo e
> TINGIA a cena inteira — num frame parado o cenário sumia atrás da cor.
> Flash é para durar um instante; a identidade quem carrega é o burst.

## L858-859 (em `PackOpenScreen:update`, junto a `for _, card in ipairs(self.pack.instances) do`)

> Interpola posição (renderX/renderY → targetX/targetY) por frame.
> Sem isso, cards ficam parados onde foram inicializados.

## L881-887 (em `PackOpenScreen:draw`, junto a `do`)

> Vinheta sutil pra focar no centro (NÃO é backdrop preto, é gradient leve).
> Mantém a loja por trás visível mas levemente escurecida nos cantos.
> FUNDO PRÓPRIO (dono, Out/2026: a loja escurecida atrás do pacote
> "fica muito poluída; um background diferente, mais centralizado"):
> pano sépia escuro OPACO com uma POÇA DE LUZ em degraus (dither Bayer
> nas bordas, sem gradiente contínuo) centrada no pacote. Nada da loja
> nem da estrada aparece atrás; o pacote e as cartas são o único assunto.

## L913 (em `steps`, junto a `if d < r - band or SP.dithered(xx / cell, yy / cell, 1 - (d - (r - band)) / band) then`)

> dither só na faixa de transição do degrau

## L924-925 (em `steps`, junto a `if self._sleeveDissolve < 0.99 and self.pack then`)

> 1) Sleeve no centro. Materializa subindo de dissolve=1 (invisível) pra
> 0 (visível). No explode (T=0.7), volta pra 1 com scale up — efeito "estouro".

## L930-936 (em `steps`, junto a `local okSP, SP = pcall(require, "src.ui.shop.ShopPerspective")`)

> interactive=false: aqui o sleeve não é um item de prateleira, é
> cenário — o hover do PackSleeve não deve reagir ao mouse parado no
> centro da tela. O tilt do wobble entra por `rotation`.
> Loja v5 (dono: "animação do PixelLab de abertura do pacote"): a
> capa v5 (a mesma da mesa) ABRE quadro a quadro até o estouro
> (assets/sprites/shop/v5_anim/<pack>/), em escala inteira; sem os
> quadros, a capa antiga de sempre.

## L960-963 (em `steps`, junto a `if (self._burstAlpha or 0) > 0.001 then`)

> 1b) Burst overlay (PixelLab burst.png): sobreposto ao sleeve durante
> explode. Scale + rotation + alpha animam via _scheduleTimeline.
> Desenhado APÓS o sleeve mas ANTES dos cards: explosão "engole" o sleeve,
> cards saem pela frente.

## L970-974 (em `steps`, junto a `love.graphics.setColor(1, 1, 1, self._burstAlpha)`)

> BRANCO, uma passada só. Cada tipo tem sprite próprio agora — a
> cor mora na ARTE. Tingir por cima (o que se fazia quando os 5
> dividiam um único sprite laranja) sujava o resultado: verde
> pintado sobre laranja dava o estouro sujo do Espectral. Aqui o
> alpha é a ÚNICA coisa que o código controla.

## L982-983 (em `steps`, junto a `self:_drawDebris()`)

> 1c) Destroços (confete / pó / estrelas / ectoplasma). Depois do burst,
> antes das cartas: voam POR TRÁS do que o jogador precisa ler.

## L986-987 (em `steps`, junto a `if self.pack and self.pack.instances then`)

> 2) Cards (durante e após explode). Usa renderX/renderY (posição
> interpolada via updateRender) pra ficar coerente com o "voo" do sleeve.

## L998-1000 (em `steps`, junto a `self:_drawRarityTags()        -- A2: metadado colado na carta`)

> ZONAS. Cada elemento abaixo mora numa banda reservada (ver
> src/ui/PackChoiceLayout.lua). Nenhuma delas encosta na outra em nenhum
> estado -- isso e garantido pela alocacao das alturas, nao por inspecao.

## L1007-1008 (em `steps`, junto a `self:_drawColourWash()`)

> 6) Lavagem colorida do estouro POR CIMA de tudo do overlay (o flash
> branco do FlashShader ainda vem depois, no love.draw do main).

## L1021-1023 (em `PackOpenScreen:mousepressed`, junto a `if self.selectButton and self.selectButton:mousepressed(x, y, button) then`)

> Selection mini-buttons (Balatro card.lua:4582-4607: highlight cria use_button child).
> Consomem o click ANTES da detecção de clique na carta pra evitar
> "click no botão re-seleciona a carta atrás dele".

## L1031 (em `PackOpenScreen:mousepressed`, junto a `if not self._cardsReady then return true end`)

> consome durante intro pra evitar click acidental

## L1040-1041 (em `PackOpenScreen:mousepressed`, junto a `if self.selectedCardIdx == i then`)

> Click numa carta = SELECIONA pra preview (3-zone overlay).
> Re-click na mesma OU click no Select button = confirma.

## L1068-1070 (em `PackOpenScreen:mousereleased`, junto a `function PackOpenScreen:_setCardSelection(idx, card)`)

> ============================================================================
> CARD SELECTION (3-zone overlay com info-left + preview-right + button attached)
> ============================================================================

## L1076-1080 (em `PackOpenScreen:_setCardSelection`, junto a `local btnH = 36`)

> Os botoes NAO sao mais ancorados na carta. Antes nasciam em
> `ry + imgH + 8`, exatamente onde a etiqueta de raridade tambem nascia, e
> tapavam a raridade da carta selecionada. Agora sao dimensionados aqui e
> POSICIONADOS pela zona D (_drawActionBand), que e territorio exclusivo
> deles.

## L1092-1094 (em `PackOpenScreen:_setCardSelection`, junto a `local cancelLabel = I18n.t("reward.cancel", nil, "Cancelar")`)

> reward.cancel, nao common.cancel: a chave vive no mesmo bloco do
> reward.select_card usado acima. Com a chave errada o fallback entrava e o
> botao saia em portugues ao lado de um jogo em alemao.

## L1107-1112 (em `PackOpenScreen:_setCardSelection`, junto a `Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })`)

> Selecao tem som PROPRIO: cardSelect no volume do registro
> (Config.Audio.CLICK_SELECT_VOLUME = 0.2). Era hoverCard com
> `volume = 0.5` cravado no call site -- e opts.volume SUBSTITUI o
> baseVolume (engine/AudioManager.lua), entao a MESMA amostra que a carta
> toca a 0.03 no hover saia aqui 16x mais alta. Mesmo defeito, mesma
> correcao da loja (CardRewardScreen:_playSlotHoverSfx).

## L1128-1137 (em `PackOpenScreen:_clearCardSelection`, junto a `function PackOpenScreen:_drawHeaderBand()`)

> Desenha overlay de carta selecionada — apenas halo dourado + mini-buttons
> compactos sob a carta (Balatro use_and_sell_buttons pattern). Os painéis
> info/preview aparecem via hover separadamente em PackOpenScreen:draw().
> ============================================================================
> ZONA C — CONTEXTO DO PACOTE
> ============================================================================
> Nome do pacote, quantas escolhas restam e o Pular. Subiu do rodape pro topo:
> embaixo ele disputava atencao com as cartas justo no momento em que elas sao
> o assunto, e ainda empurrava a acao (Escolher/Cancelar) pra fora da tela em
> janela baixa. Contexto no topo, decisao embaixo, carta no meio.

## L1166-1167 (em `PackOpenScreen:_drawHeaderBand`, junto a `function PackOpenScreen:_drawSelectionHalo()`)

> Moldura da carta selecionada. Fica NA carta (zona A) -- e o unico feedback de
> selecao que pode morar ali, porque acompanha o objeto sem ocupar area nova.

## L1185-1191 (em `PackOpenScreen:_drawSelectionHalo`, junto a `function PackOpenScreen:_drawRarityTags()`)

> ============================================================================
> ZONA A2 — ETIQUETAS DE RARIDADE (metadado colado na carta)
> ============================================================================
> Mora na banda `tags`, reservada so pra isso. Antes dividia o Y com os botoes
> de confirmar/cancelar (ambos nasciam em `ry + imgH + 8`) e o botao tapava a
> raridade -- o defeito que o dono viu. Agora os botoes moram na zona D e a
> colisao e impossivel por construcao, nao por ajuste de pixel.

## L1208-1211 (em `PackOpenScreen:_drawRarityTags`, junto a `local rc = Palette.forRarity(card.rarity)`)

> Cor CLAREADA: as cores de raridade do Palette foram feitas pra
> moldura sobre pergaminho claro; cruas sobre o fundo escuro do
> pacote, o vermelho de `rare` some. Levanta em direcao ao branco
> so o bastante pra ler, preservando a matiz.

## L1216-1220 (em `lit`, junto a `ShopEngraving.marker(math.floor(tx + tw * 0.5),`)

> Marcador de losango, o MESMO da loja -- nao mais uma caixinha
> preta com contorno de 1px. A loja etiqueta raridade assim duas
> telas antes; ter duas gramaticas pra mesma etiqueta era parte do
> "cara de IA" que o dono reportou (Set/2026). A caixa saiu: menos
> cromo, mesma informacao.

## L1229-1234 (em `lit`, junto a `function PackOpenScreen:_focusedCard()`)

> ============================================================================
> ZONA B — DETALHE DA CARTA EM FOCO
> ============================================================================
> Qual carta esta "em foco": a que esta sob o mouse; se nenhuma, a selecionada.
> Hover manda sobre selecao porque quem passa o mouse esta COMPARANDO -- quer
> ver a carta que esta olhando, nao a que ja escolheu.

## L1248-1257 (em `PackOpenScreen:_focusedCard`, junto a `local function drawChip(x, y, w, h, label, value, colour, seed)`)

> "chip" de metadado: rotulo pequeno + valor, com moldura. E como a loja
> (src/ui/CardDetailPanel.lua) apresenta custo/dano, e aqui o jogador precisa
> DA MESMA informacao: este e o momento de decisao dele.
> Cartucho de metadado: rotulo pequeno + valor. E como a loja
> (src/ui/CardDetailPanel.lua) apresenta custo/dano, e aqui o jogador precisa
> DA MESMA informacao: este e o momento de decisao dele.
>
> Antes era retangulo preto a 45% com contorno de 1px na cor do tipo -- o
> mesmo dialeto de campo de formulario que o dono reprovou na loja. Agora usa
> a chapa gravada compartilhada (bevel, cunhas de canto, grao e desgaste).

## L1269-1276 (em `PackOpenScreen:_drawDetailBand`, junto a `local card = self:_focusedCard()`)

> O ESPACO da banda e sempre reservado pelo PackChoiceLayout (por isso a
> tela nao pula quando o mouse entra e sai de uma carta), mas a CAIXA so e
> desenhada quando ha conteudo. Reservar espaco != desenhar container
> vazio -- essa confusao produziu o defeito que o dono reportou:
> "ficou com um espaco meio que empty, que sai preenchido quando eu passo
> o mouse. Isso ficou bem estranho" (Set/2026).
> O texto-instrucao que morava aqui tambem era REDUNDANTE: a zona D (acao)
> ja mostra a instrucao enquanto nao ha selecao. Sem foco, nada a dizer.

## L1329-1330 (em `chips`, junto a `if card.effects and #card.effects > 0 then`)

> Efeitos: a loja mostra, e sao eles que dizem o que a carta REALMENTE faz
> alem do numero. Ate 3, numa linha so, pra nao estourar a banda.

## L1334-1336 (em `parts`, junto a `local okE, txt = pcall(I18n.effectDesc, card.effects[i])`)

> I18n.effectDesc humaniza ("damage_bonus 3" -> texto legivel). E
> o mesmo helper que src/ui/CardDetailPanel.lua usa na loja;
> mostrar o  cru era texto de programador na cara do jogador.

## L1338-1341 (em `parts`, junto a `if okE and txt and txt ~= "" and not (txt:find("_") and not txt:find(" ")) then`)

> Sem chave de traducao, effectDesc devolve o TIPO CRU
> ("retain_armor"). Texto de programador na cara do jogador e pior
> que ausencia: omite em vez de vazar. Heuristica: chave crua nao
> tem espaco e tem underscore.

## L1364-1369 (em `parts`, junto a `function PackOpenScreen:_drawActionBand()`)

> ============================================================================
> ZONA D — ACAO
> ============================================================================
> Sem selecao: a instrucao. Com selecao: Escolher + Cancelar. Sempre na MESMA
> banda, entao nada se move quando o jogador clica -- e nada encosta na carta
> nem na etiqueta de raridade.

