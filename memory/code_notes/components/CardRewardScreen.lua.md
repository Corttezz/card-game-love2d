---
name: code_notes/components/CardRewardScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/CardRewardScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/CardRewardScreen.lua`

Origem: `components/CardRewardScreen.lua` em `7dbdb60d` (182 de 256 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local CardRewardScreen = {}`)

> components/CardRewardScreen.lua
> Tela de recompensas de cartas após vitória em batalha.

## L7-13 (em `CardRewardScreen`, junto a `local FXQ = "reward_fx"`)

> FILA DEDICADA das animações desta tela (fix DEFINITIVO Jul/2026 do bug
> "cartas invisíveis até o hover"): os helpers parallel/parallelEase são
> blocking=false mas BLOCKABLE=true — na fila "base" eles ficavam PRESOS
> atrás do rabo bloqueante da sequência de combate que acabou de terminar
> (EM.after do Game/CombatSequence é blocking). A entrada das cartas só
> rodava quando a base destravava, segundos depois. Fila própria = o combate
> nunca trava as animações da loja/recompensa. Limpa a cada show().

## L16-19 (em `CardRewardScreen`, junto a `local REWARD_DBG = require("src.core.Release").isDev()  -- release: sem reward_debug.log`)

> ============ DEBUG (caça ao bug "cartas não renderizam") ============
> Loga em print E em arquivo (save dir: reward_debug.log) — o arquivo é
> sobrescrito a cada show(), então contém sempre a ÚLTIMA abertura.
> Desligar depois: REWARD_DBG = false.

## L33-36 (em `dbg`, junto a `local function dbgQueue(name)`)

> Radiografia da fila do EventManager (trigger/blocking/timer de cada evento).
> ⚠️ require PRÓPRIO: este bloco vive ANTES dos requires do arquivo — o local
> `EventManager` de baixo não está em escopo aqui (upvalue só existe abaixo
> da declaração; o global não existe nos tools).

## L88-89 (em `dbgCards`, junto a `local ShopScene = require("src.ui.shop.ShopScene")`)

> Loja v3 (Balcão do Mercador): o modo "shop" DELEGA cena/animação a
> src/ui/shop/ShopScene; a geometria pura mora em ShopLayout.

## L93-94 (em `dbgCards`, junto a `local function reducedMotion()`)

> Acessibilidade: com reducedMotion ligado, transições da tela resolvem
> instantaneamente (o conteúdo continua idêntico, só não desliza/piscando).

## L99-103 (em `reducedMotion`, junto a `local _sfxWarned = {}`)

> Toca o PRIMEIRO código registrado da lista. Contrato do projeto pra som que
> ainda não existe no disco (mesmo padrão de RestScreen:585 e dos sons-
> assinatura de joker): o call site nasce pronto, o arquivo chega depois e
> passa a tocar sozinho. Avisa uma única vez se NENHUM resolver — fallback
> silencioso é proibido (memory/ui_layout_invariants §3).

## L112-115 (em `playFirstSfx`, junto a `if _G.audioSystem then`)

> Só avisa se HÁ sistema de áudio: sem ele (headless, tools, WSL2 mudo)
> nenhum código resolve e o aviso seria ruído garantido a cada run — o
> que treina a ignorar exatamente o aviso que deveria pegar um código
> escrito errado.

## L126-127 (em `playFirstSfx`, junto a `local SHOP_HOVER_LIFT = 12`)

> Puladinha da carta em hover na grade da loja (px). Cresce do RODAPÉ do slot
> pra cima e sobe mais um tanto — nunca invade o rótulo de raridade abaixo.

## L137-138 (em `offerKind`, junto a `function CardRewardScreen:new(shopSystem)`)

> shopSystem: instância singleton injetada (ver Game:new). Param opcional pra
> compatibilidade com chamadas antigas — fallback gera warning.

## L151-153 (em `instance.cardButtons`, junto a `instance.selectedOffer = nil`)

> Confirmação de compra
> Selection (CLICK): mini-buttons Balatro-style (Buy + Cancel) attached
> compactos sob a carta clicada.

## L158-159 (em `instance._selectionButtons`, junto a `instance.hoveredOffer = nil`)

> Hover (mouse-over sem clicar): alimenta o painel de DETALHE FIXO do
> split-view (terceira coluna da loja). Vale pra carta, voucher e pack.

## L164-165 (em `instance._selectionButtons`, junto a `instance.detailPayload = nil`)

> Painel de detalhe: conteúdo atual + memória do último olhado (o painel
> nunca fica vazio depois do primeiro hover) + fade da troca de conteúdo.

## L190-205 (em `instance.cardAnimations`, junto a `function CardRewardScreen:updateLayout()`)

> Layout fiel ao Balatro source (UI_definitions.lua:637-740):
> ROOT
> └─ COLUMN (BOSS_MAIN bg)
> ├─ ROW1 — Buttons | Cards
> │   ├─ COL: [Next Round] + [Reroll]
> │   └─ COL: shop_jokers (4 slots)
> ├─ spacer
> └─ ROW2 — Voucher | Boosters
> ├─ COL: voucher (label vertical "Ato X")
> └─ COL: 2 boosters (cardW × 1.27)
>
> ⚠️ O diagrama Balatro acima descreve o layout ANTIGO do modo "shop"
> (row1 = botões | cartas, row2 = voucher | packs). Desde o redesign
> split-view de Jul/2026 a loja é 3 COLUNAS (ações | grade | detalhe fixo) —
> ver o bloco comentado dentro do branch `self.mode == "shop"` abaixo.
> Modo "rewards": 3 cartas grandes flutuando, sem painel (StS-style).

## L209-212 (em `CardRewardScreen:updateLayout`, junto a `ShopEngraving.clearCache()`)

> Estado CACHEADO novo tem que morrer no resize, no mesmo commit
> (ui_layout_invariants, secao 2): as placas gravadas sao bitmaps
> rasterizados na largura da banda. A chave ja inclui as dimensoes, mas
> sem isto os canvases do tamanho antigo ficariam vivos pra sempre.

## L220-227 (em `self.cardPositions`, junto a `self.scene = self.scene or ShopScene.new(self)`)

> ================= BALCÃO DO MERCADOR (Loja v3, Out/2026) =================
> A geometria inteira sai de ShopLayout.layout() (puro, validado em
> test_shop_layout): estante de cima (cartas em suportes), prateleira
> de baixo (relíquias + pacote no gancho), balcão (sino / dados /
> livro-razão), pergaminho de inspeção e lanterna. Aqui só se espelha
> o resultado nos campos históricos da tela (panel, cardPositions,
> slotCount, gridArea, detailPanel, actionBar) que tools, testes e o
> tutorial ainda leem.

## L260-261 (em `self.cardPositions`, junto a `self.gridArea = { x = L.wall.x, y = L.wall.y, w = L.limitX - L.wall.x, h = L.wall.h }`)

> zonas no vocabulário antigo: vitrine = a mesa (até o pergaminho);
> detalhe = miolo do pergaminho; rodapé de ações = o CONTINUAR

## L276-281 (em `self.gridArea`, junto a `self.panel = nil`)

> ========== Modo rewards v3 "StS FLUTUANTE" (Jul/2026) ==========
> Feedback do dono: o painel parecia descentralizado, pills eram "só
> um quadrado com texto", tudo apertado. Como no Slay the Spire: SEM
> painel — o mundo (limpo) escurece atrás, um BANNER ornamental no
> topo, 3 cartas GRANDES flutuando centralizadas, marcadores sem
> caixa e o botão Seguir embaixo. Centralização é na TELA inteira.

## L318-323 (em `self.gridArea`, junto a `self:_layoutActionButtons()`)

> Rodapé de ações reposicionado AQUI, não só no detector de resize do
> update(): main.lua:love.resize chama updateLayout() direto (sem passar
> pelo detector), e sem isto os botões ficavam um frame nas coordenadas
> do tamanho ANTIGO. Regra de memory/ui_layout_invariants.md — "resize
> tem que cobrir o estado NOVO": o rodapé é estado novo desta sessão.
> No-op quando os botões ainda não existem (chamada vinda do show()).

## L325-326 (em `self.gridArea`, junto a `if self.selectedOffer then`)

> Botões de compra: largura depende do painel de detalhe, que acabou de
> mudar. Reconstrói (rótulo + largura) em vez de só reposicionar.

## L335-342 (em `self.gridArea`, junto a `function CardRewardScreen:validateLayout()`)

> ============================================================================
> VALIDAÇÃO GEOMÉTRICA — o teste que layout por acumulação nunca tem
> ============================================================================
> Devolve uma lista de violações (vazia = layout íntegro). Roda em qualquer
> tamanho de janela, então os tools conseguem exercitar o caminho que os
> screenshots não pegam: NASCER grande ≠ CRESCER (ver
> memory/ui_layout_invariants.md). Barato o bastante pra rodar por frame se
> precisar, mas o uso previsto é em ferramenta.

## L362-365 (em `screen`, junto a `local L = self.scene and self.scene.L`)

> A prova geométrica do balcão mora em ShopLayout.validate (zonas
> disjuntas, pé de todo objeto na tábua, pacote pendurado sem tocar
> a prateleira, nada fora da tela). Aqui só o que é da tela: os
> botões invisíveis do balcão têm que estar sobre os objetos.

## L396-398 (em `screen`, junto a `for i = 1, (self.mode ~= "shop") and ((self.slotCount or 0) - 1) or 0 do`)

> Slots da mesma fileira nunca se sobrepõem (espólios: a fileira é
> reta; na loja v3b os objetos ficam numa DIAGONAL em perspectiva e a
> prova de sobreposição mora em ShopLayout.validate).

## L413-423 (em `screen`, junto a `local function offerNodeKey(run, mode)`)

> mode: "rewards" | "shop"   (default "rewards" pra back-compat com chamadas antigas).
> "rewards" = pós-batalha, 3 cartas, sem reroll. Skip = continuar sem bônus.
> "shop"    = SHOP node, 4 cartas + 1 voucher + 2 packs, reroll exponencial,
> Skip dá +3 ouro de bônus.
> ============================================================================
> VITRINE NO SAVE (anti-save-scum, Out/2026)
> ============================================================================
> A loja/recompensa gerada para um nó mora em `currentRun.shopState`, com a
> chave do nó. Continuar no mesmo nó RESTAURA (nunca regera); sair do nó
> limpa. Chave = modo + ato + andar + nº de nós já escolhidos (mapHistory
> cresce a cada nó, então dois nós nunca colidem).

## L447-448 (em `CardRewardScreen:_restoreOffers`, junto a `function CardRewardScreen:_persistOffers(writeNow)`)

> Espelha a vitrine viva no currentRun. `writeNow` grava o checkpoint na
> hora; sem ele, o próximo checkpoint (Salvar e sair) leva o estado.

## L471-475 (em `CardRewardScreen:show`, junto a `local run = game.runManager and game.runManager.currentRun`)

> Contexto da run pro cérebro de ofertas (classe filtra pool; deck liga
> afinidade e anti-duplicata — "as escolhas anteriores importam"). P0.7:
> elite/chefe pisam a raridade só em modo rewards; P0.3/P0.4: pesos de
> raridade por ato; P0.5: cap de afinidade por ato. A conta mora em
> ShopSystem.runContext — a MESMA que o piloto usa (wip/sustain).

## L481-482 (em `CardRewardScreen:show`, junto a `local restored = self:_restoreOffers(run)`)

> Vitrine JÁ gerada para este nó (Continuar após "Salvar e sair") volta
> idêntica — ofertas, VENDIDO, preços e reroll. Só gera se não houver.

## L488-491 (em `CardRewardScreen:show`, junto a `for i, o in ipairs(self.shopOffers) do o._slot = i end`)

> Slot FIXO por oferta (F2): comprada uma carta, as demais NÃO trocam de
> lugar. Antes, draw/hover/selection indexavam shopOffers[i] contra
> cardInstances compactado — hover mostrava info da carta errada e os
> botões de compra apareciam no slot errado após a 1ª compra.

## L497-498 (em `self._goldPopups`, junto a `self._rewardTaken = false`)

> Regra "escolha 1" (rewards): flag zera a cada abertura — sem isto a
> SEGUNDA recompensa da run nasceria travada.

## L505-506 (em `self._goldPopups`, junto a `if not restored then self:_persistOffers(true) end`)

> Vitrine nova: entra no save JÁ (checkpoint com o RNG pós-geração), pra
> que nem um fechamento abrupto da janela permita re-sortear.

## L532-536 (em `self._goldPopups`, junto a `EventManager.clear(FXQ)`)

> Zera as filas dedicadas: eventos zumbis de uma abertura anterior morrem
> aqui (o close atrasado do "escolha 1" já é guardado por self.visible).
> A de SAÍDA entra junto: um fechamento pendente de uma abertura passada
> fecharia esta tela recém-aberta. Nenhum callback legítimo se perde —
> a saída sempre termina ANTES de qualquer caminho que reabra a loja.

## L541-542 (em `self._goldPopups`, junto a `self.slideOffsetY = -love.graphics.getHeight()`)

> Slide-in animation (Fase 4.4): painel desce do topo da tela em 0.43s.
> Padrão Balatro: easing 'smooth' (cubic in-out) chega "encaixando".

## L546-549 (em `self._goldPopups`, junto a `if self.mode == "shop" then`)

> A LOJA abria em silêncio absoluto. `shopOpen` (chime quente) já existia
> registrado e só era usado pelo pack e pelo cash out — é o som da porta
> da loja, e é aqui que ele pertence. Rewards NÃO ganha som próprio de
> abertura: o battleVictory ainda está soando quando esta tela entra.

## L554-556 (em `self._goldPopups`, junto a `if self.mode == "rewards" then`)

> ENTRADA v3 (rewards): cada carta CAI de cima com back_out (stagger) +
> tick sonoro em pitch crescente + juice ao pousar — fluidez pedida no
> feedback ("animações, coisas legais, jogo satisfatório").

## L575-581 (em `self._goldPopups`, junto a `if self.mode ~= "rewards" and self.mode ~= "shop" then`)

> Materialize cascade nas cartas: cada cardInstance arranca em dissolve=1
> e tweena pra 0 com stagger de 80ms — Balatro pack-opening style.
> ⚠️ SÓ NA LOJA (fix Jul/2026): em rewards, deixar dissolve=1 esperando o
> start_materialize agendado deixou as cartas INVISÍVEIS no jogo real
> (print do dono: só banner+marcadores). A entrada do rewards é a QUEDA
> (_entryOy) — dissolve fica 0 desde o início, visibilidade garantida
> sem corrida com o EventManager.

## L593-601 (em `self._goldPopups`, junto a `playFirstSfx({ "cardShelfPlace", "cardDraw" },`)

> A cascata materializava MUDA (queixa do dono: "falta um som
> suave de cada carta entrando"). Uma carta pousando na
> prateleira, pitch subindo pela fileira — mesmo padrão do
> modo rewards acima. `cardShelfPlace` é o som dedicado; até
> ele existir, cai no cardDraw baixinho (contrato Sfx.has).
> Sem `volume` de propósito: cada código já é registrado no
> seu volume calibrado (main.lua) e um número aqui valeria
> pros DOIS, que têm picos de amostra bem diferentes. A
> calibração mora num lugar só.

## L608-611 (em `self._goldPopups`, junto a `local skipBonus = (self.modeConfig and self.modeConfig.skipBonus) or 0`)

> Skip/Continue. Em modo shop dá +N ouro de bônus (configurado em MODE_CONFIG).
> F2: em modo shop vira o botão PRINCIPAL da coluna esquerda (Balatro:
> "Next Round" vermelho grande no topo da column), não um botãozinho no
> rodapé. Em rewards continua compacto no rodapé.

## L621-623 (em `self._goldPopups`, junto a `local skipFont = 12`)

> Reforma Jul/2026 (feedback "Seguir ..."): 130px NÃO cabia "Seguir sem
> carta" (~190px em Press Start 2P 12) e o TextFit truncava com "...".
> Largura agora é MEDIDA pelo texto (+ícone/padding) e o botão recentra.

## L629-630 (em `self._goldPopups`, junto a `self.skipButton = Button:new(`)

> Em shop a geometria definitiva vem de _layoutActionButtons() (medida);
> estes valores são só provisórios até lá.

## L635-636 (em `self._goldPopups`, junto a `if self._closing then return end`)

> Saída JÁ em curso: cada clique extra na janela da cerimônia
> pagava o bônus de novo (e o _closing só era checado depois).

## L641-642 (em `self._goldPopups`, junto a `self:_exitWithFlourish()`)

> Saída pela porta da frente: cartas queimam, painel desliza,
> som anuncia. _exitWithFlourish chama hide + onSkipped no fim.

## L652-653 (em `self._goldPopups`, junto a `local rerollX = self.skipButtonX + 145`)

> Em modo shop a posição/largura vem de _layoutActionButtons() (rodapé,
> largura medida pelo rótulo). Em rewards fica ao lado do Skip (legacy).

## L674-676 (em `self._goldPopups`, junto a `self.scene:reroll(self.shopOffers)`)

> Loja v3: as prateleiras deslizam pra fora e voltam
> repostas (os DADOS já trocaram acima: quem lê
> shopOffers depois do clique vê a vitrine nova).

## L698-699 (em `self.cardAnimations`, junto a `self:_layoutActionButtons()`)

> Custo novo = rótulo novo = largura nova (o "($12)" é mais
> largo que "($5)"). Re-mede antes que o fitText trunque.

## L713-714 (em `self.cardAnimations`, junto a `self.buyButton = nil`)

> COMPRAR (Loja v3b): clicar no objeto SELECIONA; a compra é confirmada
> aqui, no rodapé do pergaminho (ou Enter/A com o foco nele).

## L725-727 (em `self.cardAnimations`, junto a `self.diceButton = nil`)

> DADOS DO ESCRIBA (Out/2026): a aposta opcional mora no rodapé de ações,
> ao lado do reroll — é uma AÇÃO da loja, não uma oferta da vitrine.
> Abre o modal (components/ScribeDiceScreen); regra em ScribeDice.lua.

## L736-737 (em `self.cardAnimations`, junto a `self:_layoutActionButtons()`)

> Geometria definitiva do rodapé de ações (larguras medidas pelos rótulos
> já finais, incluindo o custo do reroll e o bônus do skip).

## L750-752 (em `self.cardAnimations`, junto a `function CardRewardScreen:_makeCardInstance(offer)`)

> Uma instância de Card pra oferta (loja e espólios usam a MESMA fábrica).
> Posição/escala são de quem chama: na loja o ShelfItem apoia a carta no
> suporte; nos espólios createCardInstances centraliza no slot.

## L778-780 (em `CardRewardScreen:_makeCardInstance`, junto a `function CardRewardScreen:_mirrorScene()`)

> Espelha a cena nos campos históricos (cardInstances / offer.cardInstance):
> a cerimônia de saída dissolve as instâncias, o selo de descoberta e os
> testes leem daqui.

## L788-790 (em `CardRewardScreen:createCardInstances`, junto a `self.scene = self.scene or ShopScene.new(self)`)

> Loja v3: os objetos da prateleira (ShelfItem) são donos das cartas.
> updateLayout() já criou a cena; sem ela (chamada fora de ordem)
> cria aqui — layout vem no primeiro draw/update.

## L798-800 (em `self.cardInstances`, junto a `local maxSlots = self.slotCount or 3`)

> F2: itera pelas ofertas usando o _slot FIXO de cada uma — depois de uma
> compra as cartas restantes ficam onde estavam (slot comprado vira vazio
> com stamp VENDIDO, desenhado em draw()).

## L818-821 (em `self.cardInstances`, junto a `local imgW = cardInstance.image and cardInstance.image:getWidth() or 96`)

> Fill do slot: em "rewards" a carta é a estrela e sobra folga
> pros marcadores (86%). No split-view da loja o slot já é
> pequeno e os rótulos moram na faixa DE FORA (slotLabelH) — aqui
> a carta usa quase tudo, senão vira uma miniatura ilegível.

## L830-831 (em `self.cardInstances`, junto a `cardInstance.x = math.floor(pos.x + (slotW - renderW) / 2)`)

> Centraliza a carta DENTRO do slot. Slot continua sendo a área
> clicável (cardButton); o sprite visualmente ocupa apenas o centro.

## L834-838 (em `self.cardInstances`, junto a `cardInstance.homeX = cardInstance.x`)

> ÂNCORA IMUTÁVEL do layout (fix Jul/2026 do feedback loop):
> Card:draw grava self.y = y a cada frame; desenhar a partir de
> self.y + entryOy fazia y ACUMULAR o offset (70px/frame — as
> cartas estabilizavam em y≈-1900, fora da tela; era o bug
> "não renderizam até o hover"). O draw parte SEMPRE daqui.

## L844-845 (em `self.cardInstances`, junto a `cardInstance.targetScale = fitScale`)

> targetScale começa = baseScale; Card:updateMouse aplica hover bump
> proporcional (HOVER_SCALE_MULT) automaticamente.

## L847-854 (em `self.cardInstances`, junto a `cardInstance.noHoverLift = true`)

> SEM deslocamento vertical no hover — nos dois modos.
> Tentei ligar o lift na grade (o feedback fica mais vivo), mas na
> captura ficou evidente o porquê de ele estar desligado: tudo que
> decora o slot é ancorado no RETÂNGULO DO SLOT, não na carta —
> medalhão de preço, marcador de raridade, halo de seleção. Com a
> carta deslocada, o preço descola e o marcador some atrás dela.
> O hover continua legível por SCALE (+6%) e, principalmente, pelo
> painel de detalhe inteiro trocando de conteúdo.

## L857-858 (em `self.cardInstances`, junto a `if not cardInstance.description and offer.description then`)

> Rarity border pulsante removida em F10.1 (poluía visualmente).
> offer.rarity ainda existe pra ordenar/filtrar; só não desenhamos halo.

## L875-876 (em `self.cardInstances`, junto a `offer.cardInstance = cardInstance`)

> Link bidirecional: purchaseOffer usa offer.cardInstance pro FX
> de compra (antes NUNCA era atribuído — o feedback não disparava).

## L917-918 (em `CardRewardScreen:purchaseOffer`, junto a `if self.mode == "rewards" and self._rewardTaken then return end`)

> REGRA "ESCOLHA 1" (fix Jul/2026 — dava pra pegar as 3): depois da
> primeira carta, cliques atrasados durante o fade/close são ignorados.

## L923-924 (em `CardRewardScreen:purchaseOffer`, junto a `self.scene:onDenied(offer)`)

> Loja v3: a etiqueta treme vermelha e o ouro da TopBar pisca.
> Sem toast (decisão do plano §4.4).

## L933 (em `CardRewardScreen:purchaseOffer`, junto a `if offer.type == "card" then`)

> Pre-check: joker com slots cheios não pode ser comprado (evita gold drain).

## L937-942 (em `CardRewardScreen:purchaseOffer`, junto a `self.game:addMessage(`)

> O texto falava em "slots cheios", mas quem barra aqui é
> `canAcceptJoker`, que hoje só testa `isRunMode` (Game.lua:383)
> — a rejeição por slots morreu no refactor coleção+bancada de
> Jul/2026 e é anti-pattern documentado no CLAUDE.md. A mensagem
> tinha ficado pra trás e mentia sobre a causa; agora diz o que a
> condição de fato verifica.

## L953-954 (em `CardRewardScreen:purchaseOffer`, junto a `offer.purchased = true`)

> Marca purchased ANTES de qualquer side-effect (pack open, addCardToRun)
> pra evitar duplo-buy caso input leak durante overlay/animação.

## L956-958 (em `CardRewardScreen:purchaseOffer`, junto a `self:_persistOffers()`)

> VENDIDO entra no currentRun na hora: qualquer save daqui em diante
> (Salvar e sair, toggle de coringa) já leva o slot vendido junto
> com o ouro gasto e a carta no deck.

## L967 (em `CardRewardScreen:purchaseOffer`, junto a `if _G.jiggleScreen then _G.jiggleScreen(0.25) end`)

> Screen jiggle no momento da compra (Fase 6.4) — feedback tátil leve.

## L970 (em `CardRewardScreen:purchaseOffer`, junto a `do`)

> Popup de ouro "-$N" flutuando do slot comprado (todo tipo de oferta).

## L979-981 (em `CardRewardScreen:purchaseOffer`, junto a `if self.mode == "shop" and self.scene then`)

> Loja v3: etiqueta arrancada + objeto voando pro destino + poeira e
> VENDIDO no lugar — tudo na cena, ANTES do rebuild dos itens (que
> lê offer.purchased e troca o objeto pela marca de poeira).

## L987-988 (em `CardRewardScreen:purchaseOffer`, junto a `if not (self.mode == "shop" and self.scene) then self:_startFlyToDeck(offer) end`)

> Feedback visual F2 (Balatro): a carta VOA até o ícone de deck na
> TopBar, encolhendo — comunica "foi pro seu deck" sem texto.

## L992-993 (em `CardRewardScreen:purchaseOffer`, junto a `self:_startRelicFlourish(offer)`)

> Floreio ANTES do applyUpgrade: a forja abre o picker por cima
> da loja, e o gesto tem que já estar no ar quando ele entrar.

## L997-998 (em `CardRewardScreen:purchaseOffer`, junto a `local BoosterPackSystem = require("src.systems.BoosterPackSystem")`)

> Fase 5: abre o pack imediatamente via PackOpenScreen overlay.
> main.lua expõe _G.openBoosterPack(packData, onComplete) que orquestra.

## L1002-1003 (em `CardRewardScreen:purchaseOffer`, junto a `local pack = BoosterPackSystem.expandPackRecord({`)

> P0.6/P0.10: runManager liga o dedup de joker possuído (Buffoon)
> e actNumber os pesos de raridade por ato (Arcana/Celestial/Spectral).

## L1014-1015 (em `CardRewardScreen:purchaseOffer`, junto a `for _, card in ipairs(selected or {}) do`)

> Cards escolhidas vão pro deck — passa edition/seal via meta
> pra que essa cópia específica preserve o modifier (Fase 5.4).

## L1047-1050 (em `CardRewardScreen:purchaseOffer`, junto a `if self.mode == "rewards" and offer.type == "card" then`)

> REGRA "ESCOLHA 1" (rewards, StS): pegar UMA carta ENCERRA os
> espólios — os botões morrem na hora, as cartas restantes DISSOLVEM
> (queima Balatro) e a tela fecha sozinha seguindo o fluxo (mesmo
> caminho do Seguir). Antes dava pra pegar as 3.

## L1056-1059 (em `self.cardButtons`, junto a `self:_exitWithFlourish(offer.cardInstance)`)

> A queima das não-escolhidas + o fechamento agora moram no
> mesmo gesto de saída da loja (_exitWithFlourish): as cartas
> queimam, o painel desliza e o som anuncia. A carta PEGA não
> queima — ela já voou pro deck.

## L1065-1069 (em `self.cardButtons`, junto a `function CardRewardScreen:setSelectedOffer(offer, idx)`)

> Marca uma oferta como "selecionada" — dispara o overlay 3-zone (info-left,
> carta-com-buttons-attached, preview-right). Substitui o modal centralizado
> antigo (showPurchaseConfirmation + drawPurchaseConfirmation, removidos).
> Pattern Balatro: create_shop_card_ui (UI_definitions.lua:802-880) cria
> buy_button como CHILD da carta, popup info side-anchored via align_h_popup.

## L1073-1074 (em `CardRewardScreen:setSelectedOffer`, junto a `if self.selectedOffer == offer then return end`)

> Loja v3b: selecionar foca o pergaminho e arma o COMPRAR; clicar de
> novo não desfaz (a leitura fica estável até outra escolha).

## L1084 (em `CardRewardScreen:setSelectedOffer`, junto a `if self.selectedOffer == offer then`)

> Re-clicar na mesma → toggle off (Balatro card.lua:4610-4623).

## L1101-1106 (em `CardRewardScreen:setSelectedOffer`, junto a `Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })`)

> Selecao tem som PROPRIO: cardSelect, no volume do registro
> (Config.Audio.CLICK_SELECT_VOLUME = 0.2). Antes era o hoverCard com
> `volume = 0.5` cravado aqui -- 16x o hover da carta, com a MESMA
> amostra. Corrigido o hover (ver _playSlotHoverSfx), manter o select em
> 0.5 deixaria um degrau de 17:1 entre passar o mouse e clicar; e emprestar
> o som de hover pra confirmar selecao ja era o gesto errado.

## L1110-1114 (em `CardRewardScreen:setSelectedOffer`, junto a `function CardRewardScreen:_buildSelectionButtons(offer, idx)`)

> Mini-buttons Balatro-style (UI_definitions.lua:382 card_focus_button) attached
> compactos sob a carta. Sem texto verbal — apenas cor semântica:
> Buy: verde-grimório com "$N" (custo é a única info necessária)
> Cancel: vermelho-crimson com ícone X
> Largura ~50% da carta dividida em 2; altura 32px.

## L1117-1118 (em `self._selectionButtons`, junto a `if self.mode == "shop" then return end`)

> Loja v3: não há botão de confirmação; a oferta selecionada só fica
> travada no pergaminho (tools/testes antigos ainda chamam).

## L1122-1124 (em `self._selectionButtons`, junto a `local bx0, by0, buyW, cancelW, btnH, gap = self:_selectionButtonsRect(idx)`)

> Reforma Jul/2026 (feedback "aquele P e aquele X"): 90px + fonte 12 NÃO
> cabia "PEGAR" e o TextFit degradava até virar UMA LETRA. Largura agora
> é MEDIDA pelo texto (rewards) ou ocupa o rodapé do painel (loja).

## L1158-1179 (em `self._selectionButtons`, junto a `function CardRewardScreen:_cardDrawRect(inst)`)

> ============================================================================
> RETÂNGULO REAL DA CARTA — a âncora de TUDO que decora o slot
> ============================================================================
> O problema que fez o hover ficar feio não era o lift: era a ÂNCORA.
> Card:draw(x, y) desenha o topo-esquerda em (x, y) e escala a partir DALI —
> então a carta em hover crescia pra BAIXO e pra DIREITA, invadindo o rótulo
> de raridade (que fica em Y fixo sob o slot) enquanto o medalhão de preço,
> preso ao retângulo estático do slot, ficava pra trás.
>
> Aqui a carta é ancorada no CENTRO-X e no RODAPÉ do seu retângulo de repouso:
> crescer só empurra o topo pra cima. Somado ao lift, vira a "puladinha pra
> cima" pedida. Este método devolve o retângulo EFETIVAMENTE desenhado no
> frame — medalhão de preço e halo de seleção leem daqui, então acompanham a
> carta em vez de descolar.
>
> Os offsets internos do Card:draw (BASE_LIFT constante, ondulação idle,
> parallax horizontal) são recompostos aqui pra o retângulo bater pixel a
> pixel. Na carta em HOVER a ondulação é zero por definição, que é justamente
> o caso em que o alinhamento tem que ser exato.
> Devolve { drawX, drawY, x, y, w, h }:
> drawX/drawY — o que passar pro Card:draw (ele soma os offsets internos)
> x/y/w/h     — o retângulo VISÍVEL resultante (âncora das decorações)

## L1198-1200 (em `CardRewardScreen:_cardDrawRect`, junto a `local x, y = homeX, homeY`)

> Âncora nova (centro-X + rodapé) é EXCLUSIVA da loja. Em "rewards" o
> marcador de raridade fica ACIMA da carta (pos.y - 15): crescer pra cima
> bateria nele. Lá a âncora segue sendo o topo-esquerda de sempre.

## L1213-1214 (em `CardRewardScreen:_cardDrawRect`, junto a `local baseFloat = Config.Cards.BASE_LIFT or 0`)

> Offsets que o Card:draw soma por dentro — entram só no retângulo
> visível, NUNCA na posição passada pro draw (senão contam duas vezes).

## L1228-1234 (em `CardRewardScreen:_cardDrawRect`, junto a `local function measuredButtonWidth(btn, minW)`)

> ============================================================================
> RODAPÉ DE AÇÕES (loja) — larguras MEDIDAS, nunca chutadas
> ============================================================================
> Largura que um Button precisa pro rótulo inteiro caber sem o fitText
> degradar pra "...": texto + ícone + padding interno (12 de cada lado no
> variante clean) + folga. Medida no locale ATUAL, então "Novas ofertas ($5)"
> e "Erneuern ($5)" recebem cada um o que precisam.

## L1243-1245 (em `measuredButtonWidth`, junto a `function CardRewardScreen:_layoutActionButtons()`)

> Reroll à esquerda, ouro no meio, Continuar à direita. Se a soma não couber
> (janela minúscula / locale gigante), as larguras encolhem proporcionalmente
> e o fitText do Button reduz a fonte — degradação suave, sem estourar a faixa.

## L1250-1254 (em `CardRewardScreen:_layoutActionButtons`, junto a `if self.mode == "shop" and self.scene and self.scene.L then`)

> Loja v3: sino / copo de dados / livro-razão são OBJETOS no balcão
> (ShopScene desenha). Os Buttons continuam existindo como hitbox
> invisível sobre cada objeto: mantêm o clique, o onClick que tools e
> testes chamam, e o alvo do NavCursor (Button:draw registra mesmo
> invisível). O texto deles vira o rótulo a giz sob o objeto.

## L1266-1267 (em `place`, junto a `place(self.buyButton, L.scroll.buy, true)`)

> COMPRAR: fita com selo de cera no rodapé do pergaminho (o
> ShopScene desenha; o Button vira hitbox + alvo do NavCursor)

## L1318-1319 (em `CardRewardScreen:_diceHelpRect`, junto a `if self.mode == "shop" and self.scene and self.scene.L and self.scene.L.diceHelp then`)

> Loja v3: o "?" dos dados mora no canto da placa do cabeçalho, ao lado
> do título (nunca solto no balcão).

## L1329-1330 (em `CardRewardScreen:_diceHelpRect`, junto a `function CardRewardScreen:openDiceHelp()`)

> Explicação dos Dados do Escriba (conversa "dice_help" do corvo), a
> qualquer momento — o dono achou a mesa confusa sem isso.

## L1347-1358 (em `CardRewardScreen:_refreshDiceButton`, junto a `function CardRewardScreen:_prefocusDetail()`)

> Pré-foca a primeira oferta de carta ao abrir a loja.
>
> Defeito reportado: sem hover, ~29% da tela ficava preta com 3 linhas de
> texto no meio — a loja parecia inacabada em repouso. Das três saídas
> possíveis (brasão decorativo / resumo do estoque / pré-focar), pré-focar é
> a única que não inventa conteúdo novo: o painel já nasce mostrando uma
> oferta REAL e, ao fazer isso, ensina sozinho pra que ele serve. Brasão
> seria enfeite ocupando o lugar da informação; resumo do estoque duplicaria
> o que a grade ao lado já mostra.
>
> É PRÉ-FOCO, não pré-seleção: nada de halo nem de botão de compra armado —
> o jogador continua tendo que clicar pra comprar.

## L1368-1369 (em `self._lastDetailPayload`, junto a `self.selectedOffer = offer`)

> Loja v3b: o pergaminho nasce com uma oferta SELECIONADA (COMPRAR
> armado), como na referência; o jogador troca clicando noutra.

## L1379-1380 (em `self._lastDetailPayload`, junto a `function CardRewardScreen:_refreshBuyButton()`)

> Rótulo e estado do COMPRAR: "COMPRAR · $N" da oferta selecionada; apagado
> sem seleção ou sem ouro (o preço fica vermelho na placa, sem toast).

## L1396-1398 (em `CardRewardScreen:_refreshBuyButton`, junto a `function CardRewardScreen:_resetDetail()`)

> Zera a memória do painel de detalhe. Obrigatório sempre que o CONJUNTO de
> ofertas muda (abertura, reroll): segurar a "última olhada" apontando pra uma
> oferta que não existe mais mostraria uma carta fantasma.

## L1422-1423 (em `self._selectionButtons`, junto a `function CardRewardScreen:showPurchaseConfirmation(offer)`)

> Aliases legacy mantidos pra eventual call site externo. Internamente apenas
> delegam pra setSelectedOffer/clearSelection.

## L1445-1447 (em `CardRewardScreen:cancelPurchase`)

> ============================================================================
> FX DE COMPRA (F2) — carta voa pro deck + popups de ouro + stamp VENDIDO
> ============================================================================

## L1449-1451 (em `CardRewardScreen:cancelPurchase`, junto a `function CardRewardScreen:_startFlyToDeck(offer)`)

> Carta comprada voa até o ícone de deck da TopBar (x≈200), encolhendo com
> ease_in (sucção). Entry vive em self._flyCards; desenhada em screen-space
> (fora do slide do painel) no fim do draw().

## L1484-1486 (em `fly`, junto a `function CardRewardScreen:_spawnGoldPopup(x, y, text, color, centered)`)

> Popup "-$N" que flutua pra cima e some (age controlada em update()).
> `color`/`centered` são opcionais: a compra de relíquia reusa este mesmo
> popup pra subir o EFEITO ganho ("+10 VIDA MAX") na cor do efeito.

## L1493-1497 (em `CardRewardScreen:_spawnGoldPopup`, junto a `function CardRewardScreen:_startRelicFlourish(offer)`)

> Compra de RELÍQUIA: a peça sobe do pedestal crescendo e se apaga, e o
> EFEITO sobe escrito atrás dela. Antes o feedback era idêntico ao de
> qualquer oferta (popup "-$N" + carimbo VENDIDO): a tela cobrava e não
> dizia o que você tinha acabado de ganhar — que é justamente o que um
> upgrade vende. Com reducedMotion sobra o texto, que é a INFORMAÇÃO.

## L1514-1515 (em `CardRewardScreen:_startRelicFlourish`, junto a `if self.scene then return end`)

> Loja v3: o objeto voa pelo ShopScene (onPurchased); aqui fica só o
> EFEITO escrito subindo — a informação que a compra vende.

## L1559-1562 (em `CardRewardScreen:_drawPurchaseFx`, junto a `local img = fly.inst and require("src.ui.CardFrame").displayImage(fly.inst) or fly.img`)

> ox/oy: a carta voa pelo canto (origem 0,0 — é como ela é desenhada
> na grade); a relíquia sobe pelo CENTRO, senão crescer a escala a
> empurra pro canto inferior-direito em vez de inflar no lugar.
> Carta comprada continua animando no voo (dono, 13/Out/2026).

## L1583-1584 (em `CardRewardScreen:_drawPurchaseFx`, junto a `function CardRewardScreen:_drawSoldSlot(pos)`)

> Slot de carta comprada: moldura vazia esmaecida + stamp "VENDIDO" diagonal
> (Balatro deixa o buraco no shelf — comunicar "você JÁ comprou isto aqui").

## L1609-1624 (em `CardRewardScreen:_drawSoldSlot`, junto a `local DECK_SERVICE_PICKER = {`)

> ============================================================================
> SERVIÇOS DE DECK (forja / tesoura / prensa)
> ============================================================================
> Os três compram a MESMA coisa: o direito de apontar uma carta do deck. A
> diferença é só o modo do picker, então o caminho é um só.
>
> ⚠️ PAGO ANTES, APLICADO DEPOIS. `purchaseOffer` já debitou o ouro quando
> esta função roda, e o picker é uma tela SEPARADA que o jogador pode fechar
> no "Voltar" sem escolher carta nenhuma. Sem o estorno abaixo o jogador paga
> e não leva — e o slot na vitrine já está carimbado VENDIDO. A forja tinha
> esse buraco desde sempre; ele só não incomodava porque a forja aparecia em
> metade das lojas. Com a tesoura FIXA na prateleira viraria rotina.
>
> Como se sabe se o serviço foi usado: a ASSINATURA DO DECK
> (ShopServices.deckFingerprint) muda quando uma carta entra, sai ou sobe de
> nível. Se ela não mudou entre abrir e fechar o picker, nada aconteceu.

## L1634-1635 (em `CardRewardScreen:_openDeckService`, junto a `if offer.effect == "forge_card" then`)

> Ledger: o custo da PRÓXIMA compra deste serviço cresce a partir de
> agora. Desfeito no estorno se o jogador não escolher carta.

## L1657-1659 (em `CardRewardScreen:_openDeckService`, junto a `function CardRewardScreen:_refundDeckService(offer)`)

> Desfaz a compra de um serviço de deck: devolve o ouro, desfaz o ledger e
> RECOLOCA a oferta na vitrine (o slot deixa de ser VENDIDO). O jogador sai
> exatamente como entrou — é isso que faz "Voltar" significar cancelar.

## L1681-1682 (em `CardRewardScreen:_refundDeckService`, junto a `if not self.visible then return end`)

> A tela pode ter fechado enquanto o picker estava aberto (não acontece
> no fluxo atual, mas o estorno não pode ressuscitar layout morto).

## L1697-1700 (em `CardRewardScreen:applyUpgrade`, junto a `if upgrade.effect == "increase_max_health" then`)

> P3.2 (rebalance Jul/2026): os branches toast-only (increase_card_draw /
> increase_attack_damage / increase_defense) foram REMOVIDOS junto com as
> ofertas correspondentes (ShopSystem:initializeShopPools) — upgrade
> comprado tem que aplicar efeito real, nunca só mensagem.

## L1710-1714 (em `CardRewardScreen:applyUpgrade`, junto a `if rm and rm.registerService then rm:registerService(upgrade.id) end`)

> BANCADA EXTRA: sobe o teto de coringas ATIVOS pelo resto da run.
> O ledger é a fonte; recomputeMaxJokerSlots (base + comprados)
> reescreve o espelho em currentRun.maxJokerSlots e
> reconstrói jokerSlots — sem isso o coringa que estava na bancada
> não subiria pro tabuleiro até a próxima batalha.

## L1726-1729 (em `CardRewardScreen:applyUpgrade`, junto a `if rm and rm.registerService then rm:registerService(upgrade.id) end`)

> COFRE: levanta o teto dos juros pelo resto da run. O ledger é a
> fonte; syncInterestCap reescreve o espelho no EconomySystem — e a
> TopBar, que lê calculateInterest todo frame, mostra o número novo
> no frame seguinte sem precisar saber que algo foi comprado.

## L1739-1740 (em `CardRewardScreen:applyUpgrade`, junto a `if rm and rm.registerService then rm:registerService(upgrade.id) end`)

> GRIMÓRIO: +1 carta comprada por turno, pelo resto da run. O ledger
> é lido por Game:drawForTurn e pela mão inicial da batalha.

## L1751-1780 (em `CardRewardScreen:applyUpgrade`, junto a `local EXITQ = "reward_exit"`)

> ============================================================================
> SAÍDA COM CERIMÔNIA (queixa do dono: "sair da loja e voltar pro mapa não tem
> transição nenhuma ... queria as cartas voltando, com som que indique isso")
> ============================================================================
>
> Antes, TODO caminho de saída era `self:hide()` seco — a tela simplesmente
> deixava de existir no frame seguinte. Agora a saída é um gesto em 3 tempos,
> todo ele com peças que já existiam na tela:
>
> 1. as cartas QUEIMAM em cascata (`start_dissolve`, o mesmo efeito que o
> modo rewards já usava ao pegar uma carta) — "as cartas voltando";
> 2. o painel desliza pra fora (`slideOut`, escrito na Fase 7.4 e até hoje
> só chamado pelo pack opening);
> 3. som de saída + o callback do fluxo, DEPOIS da animação.
>
> `keepInst` é a carta comprada: ela não queima junto (já voou pro deck).
> Com reducedMotion resolve na hora — mas o SOM toca igual: a flag remove
> movimento, nunca informação (CLAUDE.md / ui_layout_invariants §3).
>
> ⚠️ FILA PRÓPRIA, e não a `base` (memory/eventmanager_queues.md, regra de
> ouro): na base os eventos de tela ficam presos atrás do rabo BLOQUEANTE do
> combate — e `parallel` não salva, porque é blockable também. Foi assim que
> nasceu o bug das "cartas invisíveis até o hover". Primeira versão deste
> código caiu exatamente nessa armadilha e o test_shop_exit pegou: com a base
> suja, o callback de continuar a run simplesmente não vinha.
>
> Fila SEPARADA da FXQ de propósito: a FXQ é limpa a cada `show()` (é a fila
> da ENTRADA) e a saída tem ciclo de vida próprio. Limpamos a nossa no início
> da saída (mata zumbi de uma saída anterior) e o callback ainda guarda em
> `self.visible`, como a regra manda pra evento com efeito de fluxo.

## L1808-1810 (em `CardRewardScreen:_exitWithFlourish`, junto a `self:slideOut()`)

> O whoosh e o slide são UM gesto: o som sobe durante os 0,45s do
> deslize e o riffle assenta em 0,48s — medido, é quando o painel acabou
> de sair. Disparar junto é o que faz os dois lerem como a mesma coisa.

## L1817-1818 (em `CardRewardScreen:_exitWithFlourish`, junto a `self:_clearPersistedOffers()`)

> Saiu do nó: a vitrine deixa de existir (o próximo save, na
> encruzilhada, já não a carrega).

## L1858-1859 (em `CardRewardScreen:update`, junto a `if self.mode ~= "shop" then`)

> Na loja, updateLayout() já remediu o rodapé e reconstruiu os
> botões de compra; só as recompensas têm botão pra recentrar.

## L1862 (em `CardRewardScreen:update`, junto a `self.skipButton.x = math.floor(love.graphics.getWidth() / 2`)

> rewards: recentra pela LARGURA MEDIDA (não o -90 fixo)

## L1877-1878 (em `CardRewardScreen:update`, junto a `if REWARD_DBG and self.animationTime < 6 then`)

> DEBUG: snapshot a cada 0.5s nos primeiros 6s da tela (o suficiente
> pra pegar a entrada travada sem inundar o log).

## L1905-1906 (em `CardRewardScreen:update`, junto a `if self.mode == "shop" and self.scene then`)

> Hover/click nas cartas e seus invisible-buttons sempre rodam
> (sem modal bloqueando entrada). Selection overlay coexiste com hover.

## L1911-1913 (em `CardRewardScreen:update`, junto a `local mx, my = love.mouse.getPosition()`)

> Cartas são desenhadas DENTRO do translate do slide — o mouse vai
> pro espaço local antes do hit-test (em repouso o offset é 0, então
> isso só muda o comportamento durante o slide-in/slideOut).

## L1942 (em `CardRewardScreen:update`, junto a `if self._selectionButtons then`)

> Buttons attached da carta selecionada (Balatro pattern: filhos da carta).

## L1956-1959 (em `CardRewardScreen:easeOutBack`, junto a `function CardRewardScreen:_drawShop()`)

> ============================================================================
> DRAW DA LOJA (Balcão do Mercador) — a cena desenha; a tela só junta os
> botões invisíveis do balcão, as ações do pad, o FX de compra e o tutorial.
> ============================================================================

## L1967-1968 (em `CardRewardScreen:_drawShop`, junto a `if self.refreshButton then`)

> hitboxes invisíveis (registram o alvo do NavCursor) + ações do pad:
> X = sino (novas ofertas), Y = livro-razão (seguir viagem)

## L2015-2017 (em `CardRewardScreen:_drawShop`, junto a `local L = self.scene and self.scene.L`)

> v5: o recorte das ofertas inclui o CAVALETE/etiqueta de cada peça, e
> as placas de preço (plaquinha da carta, etiqueta pendurada do
> objeto e do sino) têm recorte próprio pra fala do preço

## L2037-2038 (em `CardRewardScreen:_drawShop`, junto a `self:_drawPurchaseFx()`)

> FX por cima de tudo: popups "-$N" / efeito ganho + objeto voando pro
> destino (TopBar é o destino da carta, então fora do slide).

## L2053-2054 (em `CardRewardScreen:draw`, junto a `if self.mode == "rewards" then`)

> Backdrop FIXO (não desliza com o conteúdo) — fica sempre cobrindo o
> gameplay atrás. Só o conteúdo (título + slots + botões) entra pelo topo.

## L2056-2059 (em `CardRewardScreen:draw`, junto a `love.graphics.setColor(0.02, 0.015, 0.01, 0.60)`)

> IMERSÃO (feedback Jul/2026): espólios de batalha acontecem NO LUGAR
> da batalha — main.lua já desenha o mundo vivo atrás (GameplayScene
> antes deste draw; WorldRoad continua tickando). Só um véu escuro
> pra dar foco ao painel — nada de interior de loja aqui.

## L2069 (em `CardRewardScreen:draw`, junto a `if self.mode == "rewards" then`)

> Modo rewards v3 não tem painel (banner flutuante estilo StS).

## L2074-2076 (em `CardRewardScreen:draw`, junto a `local dbgDrawTick = false`)

> Vitrine e rodapé de ações NÃO têm caixa: eram duas das cinco molduras
> aninhadas. Os retângulos gridArea/actionBar seguem existindo como
> ZONAS do layout (validateLayout), só não são desenhados.

## L2089-2090 (em `CardRewardScreen:draw`, junto a `local offer = cardInstance.shopOffer`)

> F2: anim e affordability vêm da OFERTA da própria instância
> (indexar shopOffers[i] quebrava após a 1ª compra).

## L2109-2110 (em `CardRewardScreen:draw`, junto a `cardInstance.saleDim = (self.mode == "shop") and offer`)

> Impagável = carta escurecida (2º canal além do preço
> vermelho; pesquisa: nunca comunicar só por cor do número)

## L2115-2118 (em `CardRewardScreen:draw`, junto a `local r = self:_cardDrawRect(cardInstance)`)

> _cardDrawRect parte de homeX/homeY (âncora IMUTÁVEL) — nunca
> de self.x/y, que o Card:draw sobrescreve a cada frame (o
> feedback loop y+=entryOy mandava as cartas pra y≈-1900; era
> o bug "não renderizam") — e já aplica a puladinha do hover.

## L2137-2142 (em `CardRewardScreen:draw`, junto a `local fx = self:_slotFx(slot)`)

> ENTRADA: `anim.scale` já era calculado pra TODOS os slots no
> update, mas só as cartas o usavam (elas materializam em
> cascata). Voucher e pacote simplesmente APARECIAM no meio da
> cascata, quebrando a leitura de "a prateleira está sendo
> montada". Agora a mesma curva easeOutBack os traz, crescendo
> a partir do CENTRO do slot. O hop/juice do hover compõe aqui.

## L2144-2145 (em `CardRewardScreen:draw`, junto a `require("src.ui.NavCursor").target("offer:" .. slot, pos.x, pos.y,`)

> relíquia/pacote: alvo do foco de teclado/pad (NavCursor); a
> carta se registra sozinha no Card:draw

## L2170-2173 (em `CardRewardScreen:draw`, junto a `for _, cardInstance in ipairs(self.cardInstances) do`)

> Marcadores (raridade + afinidade) em PASSE PRÓPRIO, depois de todas as
> cartas: assim a carta vizinha em hover nunca passa por cima deles. Eles
> ficam na faixa FIXA sob o slot — a carta é que pula pra cima, liberando
> o rótulo (pedido do dono).

## L2183-2185 (em `CardRewardScreen:draw`)

> Relíquia e pacote NÃO levam etiqueta de categoria ("◆ RELÍQUIA ◆",
> "◆ PACOTE ◆"): o objeto já diz o que é — a placa com efeito gravado e o
> envelope. A etiqueta repetida sob cada slot era ruído (Out/2026).

## L2187-2189 (em `CardRewardScreen:draw`, junto a `if self.detailPanel then`)

> ===== Painel de DETALHE FIXO (3ª coluna, só na loja) =====
> Desenhado DENTRO do slide, junto com o resto do painel: ele é parte da
> janela da loja, não um popup por cima dela.

## L2223-2226 (em `CardRewardScreen:draw`)

> ========== SEGUNDA PASS: overlays acima de tudo ==========
> LOJA: nenhum tooltip/popup flutuante. Toda a informação da oferta vive
> no painel de detalhe FIXO da terceira coluna, desenhado junto com o
> resto do painel (dentro do slide) — leitura em posição estável.

## L2228-2236 (em `CardRewardScreen:draw`, junto a `if self.mode == "rewards" and self.hoveredInst and not self.selectedOffer then`)

> REWARDS: tooltip canônico do jogo (o mesmo da mão/deck viewer) para a
> carta em hover — some quando há seleção ativa (os botões mandam).
> Card:draw NÃO desenha tooltip aqui (recebe isRewardCard=true); este
> passe é a única fonte. Dono, 13/Out/2026 ("não pode ficar o tooltip
> assim"): a carta de espólio é GRANDE e começa a 28% da tela — ACIMA
> dela o painel não cabia, o clamp o prendia no topo e a TopBar
> (camada chrome, desenhada depois) cobria o nome. Agora abre AO LADO,
> topo alinhado ao topo da carta (o mesmo da mão do combate), sobre o
> retângulo REAL desenhado (_drawRect) e nunca acima da barra superior.

## L2253-2254 (em `CardRewardScreen:draw`, junto a `self:_drawSelectionOverlay()`)

> Selection overlay (CLICK): halo pulsante + mini-buttons Balatro-style
> (UI_definitions.lua:382 card_focus_button) attached compactos sob a carta.

## L2281-2282 (em `occupied`, junto a `if self.inspectModal then`)

> Inspeção completa (clique DIREITO numa oferta): mesma visão da Coleção
> — carta grande + painel de detalhes. Por cima de tudo.

## L2289-2291 (em `occupied`)

> (_drawShopAmbience / _drawShopShelves / _drawShopHeader saíram na Loja v3:
> a parede, a luz, as tábuas e a placa com o "?" das regras moram no
> ShopScene.)

## L2293-2295 (em `occupied`, junto a `function CardRewardScreen:_drawRewardsBanner()`)

> Banner flutuante do modo rewards (v3 StS): título grande com outline ink,
> filetes ornamentais com losango dos dois lados, subtítulo com respiro e o
> "?" das regras (pity/afinidade/raridade) à direita do título.

## L2340 (em `CardRewardScreen:_drawRewardsBanner`, junto a `local sub = I18n.t("reward.rewards_subtitle")`)

> subtítulo com RESPIRO (feedback: "texto meio apertado")

## L2349 (em `CardRewardScreen:_drawRewardsBanner`, junto a `local hx = cx + gap + lineW + 22`)

> "?" das regras à direita do filete (tooltip de pity/afinidade)

## L2374-2384 (em `CardRewardScreen:_drawRewardsBanner`, junto a `local function drawMarker(cx, cy, text, color, fontSize, dia)`)

> Reforma v3 (feedback: "só um quadrado com texto, feio"): marcador SEM
> caixa — texto colorido com outline ink e LOSANGOS dos dois lados
> (◆ RARA ◆), mesma linguagem ornamental do banner.
>
> Era um closure dentro de drawOfferBadges; virou função de arquivo quando a
> faixa de rótulos passou a servir TAMBÉM os slots que não são carta (o
> voucher e os pacotes tinham uma faixa reservada e VAZIA embaixo deles —
> "zona vazia é pior que zona ausente", ui_layout_invariants §1).
> Marcador "losango . TEXTO . losango". A implementacao vive em
> src/ui/ShopEngraving.marker, compartilhada com a tela de abertura de pacote
> (que antes desenhava a MESMA etiqueta como caixinha com contorno).

## L2389-2396 (em `drawMarker`, junto a `function CardRewardScreen:drawOfferBadges(cardInstance, slot)`)

> Marcadores de clareza da oferta: raridade NOMEADA + "AFINIDADE" quando a
> carta foi puxada pelas tags fortes do deck. Clareza: raridade não é só uma
> borda colorida; afinidade não é mágica.
>
> Posicionamento por modo:
> rewards → folgas do slot (a carta ocupa 86%, sobra espaço real)
> shop    → faixa de rótulos SOB o slot (slotLabelH), em escala menor:
> linha 1 = raridade, linha 2 = afinidade.

## L2422-2425 (em `CardRewardScreen:drawOfferBadges`, junto a `marker(cx, pos.y - (offer.isNew and 27 or 15), label, Palette.forRarity(offer.rarity), 9, 4)`)

> ZONAS acima da carta: raridade / fita NOVA / carta. Com a fita
> (que agora sai inteira pra fora da moldura, DiscoveryMark), a
> raridade sobe mais 12 px pra não encostar nela (dono, 13/Out:
> "tudo tampando ali em cima").

## L2436-2440 (em `CardRewardScreen:drawOfferBadges`, junto a `function CardRewardScreen:_drawDetailPanel(rect, parchment, artMaxH, objectArt)`)

> ============================================================================
> PAINEL DE DETALHE FIXO — a coluna que explica a oferta em foco
> ============================================================================
> `rect`/`parchment` (Loja v3): o ShopScene chama com o miolo do pergaminho
> e a paleta tinta-sobre-papel; sem argumentos é a coluna escura de sempre.

## L2452 (em `CardRewardScreen:_drawDetailPanel`, junto a `local footerH = self.selectedOffer and (self.detailFooterH or 58) or 0`)

> Rodapé reservado só quando há seleção ativa (os botões moram lá).

## L2455-2457 (em `CardRewardScreen:_drawDetailPanel`, junto a `local hint = nil`)

> Rodapé de contexto: no pré-foco ENSINA (o painel nasce cheio, mas o
> jogador ainda não sabe que ele responde ao mouse); depois só avisa que
> está segurando a última oferta observada.

## L2460-2461 (em `CardRewardScreen:_drawDetailPanel`, junto a `hint = I18n.t("reward.detail_prefocus", nil, "Passe o mouse pra comparar")`)

> Curto DE PROPÓSITO: cabe numa linha só na coluna mais estreita
> (230px), então não há wrap nem risco de entrelinha apertada.

## L2467 (em `CardRewardScreen:_drawDetailPanel`, junto a `self._detailFit = CardDetailPanel.draw(dp, payload, {`)

> v5: guarda a medida (test_shop_scene: nada sai do pergaminho)

## L2484-2485 (em `CardRewardScreen:_drawDetailPanel`, junto a `function CardRewardScreen:_drawCardTooltipOverlay(cardInstance)`)

> Tooltip de carta em pass separado pra ficar acima de tudo (F10.2). Calcula
> posição relativa à carta, idêntico ao que Card:draw fazia inline.

## L2489-2491 (em `CardRewardScreen:_drawCardTooltipOverlay`, junto a `local px = cardInstance.renderX or cardInstance.x or 0`)

> Posição: ABAIXO da carta (smart positioning fará fallback acima se
> ultrapassar bottom da tela). Usa renderX/Y se Card tem interpolação,
> senão x/y direto.

## L2506-2507 (em `CardRewardScreen:drawOffer`, junto a `local compact = h < 250`)

> Slot pequeno = tile do split-view: o texto longo sai (o painel de
> detalhe carrega a descrição) e as faixas encolhem pra sobrar arte.

## L2510-2511 (em `CardRewardScreen:drawOffer`, junto a `if offer.type == "booster_pack" then`)

> Booster pack: usa o sleeve PixelLab via PackSleeve em vez de retângulo plano.
> Sleeve preenche o slot inteiro, preço fica overlaid embaixo.

## L2516-2523 (em `CardRewardScreen:drawOffer`, junto a `local headerH = compact and 13 or 16`)

> Header (nome) ocupa o topo; o resto e do SLEEVE.
>
> O preço deixou de ser uma barra no rodapé (Set/2026, "cara de IA"):
> era um retângulo de 1px flutuando sob a arte, a 40px de cartas que
> mostravam o preço como MOEDA cunhada no canto. Duas gramáticas pra
> mesma informação na mesma fileira — e a barra ainda roubava ~22px de
> altura do envelope. Agora o pacote usa a moeda de ShopEngraving,
> carimbada no canto do SLEEVE (o objeto), não do slot.

## L2534-2537 (em `CardRewardScreen:drawOffer`, junto a `Palette.set(Palette.AGED_GOLD_LIGHT)`)

> Nome do pack no topo do slot (dentro). Quebra em 2 linhas quando
> cada PALAVRA cabe; uma palavra maior que o slot (alemão:
> "Totengräbertuch") era cortada no meio pelo printf — aí o nome vai
> numa linha só, reduzido/truncado pelo TextFit.

## L2564-2566 (em `sleeveRect`, junto a `if offer.type == "upgrade" then`)

> Upgrade (voucher) = RELÍQUIA na prateleira: placa iluminada com pedestal,
> halo na cor do efeito, chip com o número e placa de preço. Tudo em
> src/ui/UpgradeTile.lua, que fatia o slot em bandas validáveis.

## L2605-2615 (em `sleeveRect`, junto a `function CardRewardScreen:drawPriceOverlay(cardInstance, rect)`)

> Moeda de preço no canto superior-direito da carta. Inspirado em Balatro
> create_shop_card_ui (UI_definitions.lua:802-880), que flutua um UIBox com
> DynaText `$<cost>` sobre a carta.
>
> O desenho mora em src/ui/ShopEngraving.priceSeal, compartilhado com pacote e
> relíquia. Antes vivia aqui, com dez `setColor` de RGB literal e discos do
> `love.graphics.circle` — anti-aliasados, num jogo de borda dura. Centralizar
> resolveu as duas coisas: paleta e degraus.
>
> rect: retângulo REAL da carta neste frame (_cardDrawRect). A moeda é parte
> da carta — sobe junto com ela no hover, não fica presa ao slot estático.

## L2629-2631 (em `CardRewardScreen:drawPriceOverlay`, junto a `function CardRewardScreen:drawPurchaseConfirmation() end`)

> LEGACY: drawPurchaseConfirmation (modal centralizado) removido. Substituído
> pelo _drawSelectionOverlay (3-zone Balatro pattern). Mantido como stub no-op
> caso algum call site externo ainda chame.

## L2634-2641 (em `CardRewardScreen:drawPurchaseConfirmation`, junto a `function CardRewardScreen:_drawSelectionOverlay()`)

> ============================================================================
> SELECTION (CLICK) — mini-buttons Balatro-style sob a carta
> ============================================================================
> Quando uma carta é clicada (setSelectedOffer), desenha:
> 1) Halo dourado pulsante na carta (feedback visual de selecionada).
> 2) Mini-buttons compactos (COMPRAR $N + X). Na LOJA eles ancoram no
> rodapé do painel de detalhe; em "rewards", sob a carta.
> A descrição da oferta NÃO é parte deste overlay — mora no painel fixo.

## L2653-2654 (em `CardRewardScreen:_drawSelectionOverlay`, junto a `local selInst = self.selectedOffer and self.selectedOffer.cardInstance`)

> Se a oferta selecionada é uma CARTA, o halo abraça o retângulo REAL
> dela (com a puladinha do hover) em vez do retângulo estático do slot.

## L2671-2674 (em `CardRewardScreen:_drawSelectionOverlay`, junto a `if self._selectionButtons and #self._selectionButtons > 0 then`)

> Buttons attached (criados em _buildSelectionButtons). Reposiciona a cada
> frame pra acompanhar mudanças de layout. Na LOJA eles moram no rodapé do
> painel de detalhe (é lá que a oferta está sendo lida — confirmar do lado
> do que se lê); em "rewards" continuam colados sob a carta.

## L2691-2696 (em `CardRewardScreen:_drawSelectionOverlay`)

> LEGACY: _drawHoverInfoPanels (2 painéis FLUTUANTES fora da janela da loja)
> foi REMOVIDO no split-view de Jul/2026. Era a causa raiz da reclamação do
> dono: a informação da oferta vivia num popup que saltava de posição e
> cobria as cartas vizinhas. Substituído pelo painel de detalhe FIXO
> (src/ui/CardDetailPanel.lua) na terceira coluna. Em "rewards" esses painéis
> já estavam desligados — lá o hover usa o tooltip canônico (CardInfoDisplay).

## L2698-2701 (em `CardRewardScreen:_drawSelectionOverlay`, junto a `function CardRewardScreen:_updateHoverState()`)

> Atualiza estado de hover lendo cardInstance.isHovered. Chamado em :update.
> Split-view: voucher e booster pack TAMBÉM entram no hover (antes só cartas
> tinham instância com isHovered) — o painel de detalhe explica qualquer
> oferta, não só as cartas.

## L2719-2720 (em `CardRewardScreen:_updateHoverState`, junto a `local offer = inst.shopOffer`)

> F2: a oferta vem da própria instância (shopOffers[i] mostrava
> a info da carta ERRADA depois de uma compra).

## L2730-2731 (em `CardRewardScreen:_updateHoverState`, junto a `local mx, my = love.mouse.getPosition()`)

> Hit-test por retângulo do slot. O layout vive dentro do translate do
> slide, então o mouse precisa ir pro espaço local antes de comparar.

## L2756-2766 (em `CardRewardScreen:_updateHoverState`, junto a `function CardRewardScreen:_slotFx(slot)`)

> ============================================================================
> FX DOS SLOTS NAO-CARTA (voucher / booster pack)
> ============================================================================
> A carta tem hover próprio (Card:updateMouse faz lift, tilt e escala). O
> voucher e o pacote eram DESENHOS PARADOS: passar o mouse por cima não mexia
> um pixel — só o painel da direita trocava de conteúdo. Aqui eles ganham o
> mesmo vocabulário da carta: destaque contínuo (hover interpolado) + estalo
> ao entrar (hop + juice do Moveable) + kick na compra.
>
> Nenhum estado GEOMÉTRICO mora aqui (só hover 0..1 e o juice), então o resize
> não tem o que invalidar: a geometria sai de cardPositions a cada frame.

## L2778-2780 (em `fx`)

> (_playSlotHoverSfx / _updateSlotFx saíram na Loja v3: o hover da relíquia
> e do pacote — som na borda de entrada, nunca durante o deslize — mora no
> ShopScene:update / ShelfItem:update.)

## L2782-2793 (em `fx`, junto a `function CardRewardScreen:_resolveDetailPayload()`)

> ============================================================================
> PAINEL DE DETALHE FIXO (split-view da loja)
> ============================================================================
> Decide O QUE o painel da direita mostra, por prioridade:
> 1) a oferta SELECIONADA — trava enquanto o jogador confirma a compra
> (o que ele vai pagar não pode sumir porque o mouse escorregou);
> 2) a oferta sob o mouse;
> 3) a ÚLTIMA que ele olhou, marcada como "stale".
> Escolha de design pro estado "sem hover" (pedido explícito): o painel NÃO
> pisca vazio. Ele segura a última carta olhada com um rodapé discreto; o
> estado neutro com instrução só aparece na ABERTURA, antes do 1º hover —
> ali ele ensina em vez de mostrar um buraco.

## L2817-2818 (em `self.detailPayload`, junto a `if self.detailPayload and self.detailPayload.offer then`)

> Re-amarra a instância: createCardInstances() reconstrói tudo a cada
> compra, e a referência guardada viraria um objeto órfão.

## L2825-2827 (em `self.detailPayload`, junto a `if self.detailPayload and self.detailPayload.offer`)

> Oferta comprada não fica presa no painel (o slot dela virou VENDIDO) —
> mas o painel TAMBÉM não pode virar buraco preto depois de uma compra:
> re-foca a próxima oferta disponível. Só fica neutro se acabou o estoque.

## L2837-2840 (em `self.detailPayload`, junto a `local shown = self.detailPayload and self.detailPayload.offer or nil`)

> Cross-fade curto quando o conteúdo troca (evita "corte seco" ao varrer
> o mouse pela grade). Instantâneo com reducedMotion. Deliberadamente NÃO
> usa EventManager: se a fila estiver pausada o painel ficaria parado em
> meio-fade — a legibilidade da loja não pode depender disso.

## L2848-2850 (em `self.detailPayload`, junto a `function CardRewardScreen:_selectionButtonsRect(idx)`)

> Retângulo onde os botões Comprar/Cancelar moram na LOJA: o rodapé do painel
> de detalhe. Em "rewards" eles continuam colados embaixo da carta (aquele
> modo não foi alvo da reclamação e não tem painel).

## L2879-2880 (em `CardRewardScreen:drawInstructions`, junto a `local text = I18n.t("reward.instructions")`)

> F1 do UI Overhaul: HintBar padronizada — SEMPRE cabe na tela (o texto
> antigo estourava dos dois lados e atropelava o botão Pular)

## L2883-2884 (em `CardRewardScreen:drawInstructions`, junto a `text = I18n.t("reward.instructions_shop", nil,`)

> Split-view: o hint ensina a gramática nova (passar o mouse LÊ, o
> clique SELECIONA e a compra é confirmada no painel).

## L2893-2895 (em `CardRewardScreen:mousepressed`, junto a `if self._closing then return true end`)

> Durante a cerimônia de saída nada mais é clicável: comprar uma Forja
> nessa janela abria o picker e o callback da saída o atropelava (ouro
> gasto, forja perdida). Engole o clique.

## L2925-2926 (em `CardRewardScreen:mousepressed`, junto a `if self._selectionButtons then`)

> Selection buttons attached na carta selecionada têm prioridade —
> consomem o click antes dos cardButtons (que ficariam re-selecionando).

## L2950-2951 (em `CardRewardScreen:mousepressed`, junto a `if self.mode == "shop" and self.scene and button == 1 then`)

> Loja v3b: pressionar sobre um objeto da mesa arma a seleção (o
> release confirma, como os botões).

## L2961-2962 (em `CardRewardScreen:mousepressed`, junto a `if self.selectedOffer then`)

> Click fora de qualquer card/button enquanto há seleção → desselleciona
> (Balatro: re-clicar na mesma carta também alterna; aqui aceitamos ambos).

## L3024-3026 (em `CardRewardScreen:mousereleased`, junto a `function CardRewardScreen:isVisible()`)

> drawRarityBorder removida em F10.1 (poluição visual). Cards agora não têm
> halo pulsante de raridade. Se voltar a precisar, recriar dentro do CardFrame
> como acabamento sutil de borda (não animação fullscreen).

## L3032-3034 (em `CardRewardScreen:isVisible`, junto a `function CardRewardScreen:slideOut()`)

> Desliza loja pra fora da tela (Fase 7.4 do refactor Balatro). Chamado quando
> pack opening assume o foco. Padrão Balatro: shop fica off-screen embaixo
> (não usa backdrop preto sobre ela).

