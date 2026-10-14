---
name: code_notes/components/RestScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/RestScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/RestScreen.lua`

Origem: `components/RestScreen.lua` em `7dbdb60d` (100 de 132 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-38 (junto a `local RestScreen = {}`)

> components/RestScreen.lua
> Descanso: escolhe entre curar 30% maxHP ou forjar (upgrade) uma carta do deck.
> Forge: sobe o nivel DA COPIA escolhida (currentDeck[i].up++ via
> RunManager:upgradeCardAt) — nunca das outras copias do mesmo id.
>
> F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena REAL de fogueira
> (assets/sprites/scenes/path_rest.png) + painel grimório (Panel9) + duas
> ESCOLHAS-CARTÃO grandes com preview do resultado (HP atual → resultante),
> no lugar dos 2 botões soltos no vazio (tela nota D no levantamento).
>
> BIGORNA v2 (Set/2026 — pedido do dono: "a tela de forjar mostrar as cartas
> visualmente, ao confirmar ter uma animação, na hora de visualizar conseguir
> ver as cartas ter o hover"). O picker deixou de ser uma grade de BOTÕES DE
> TEXTO e passou a ser uma grade de CARTAS REAIS:
> (a) instâncias de verdade (CardDatabase:createCardInstance + os upgrades
> já aplicados) — a carta na bigorna é a carta que você joga;
> (b) hover 3D do padrão reward (Card:updateMouse + draw(..., isRewardCard
> = true): a carta SOBE, tilta e ganha sombra) + painel de bigorna
> ancorado nela com o preview "ATQ 8 -> 10". O preview antigo (única
> forma de saber o que a forja faz) NÃO sumiu: virou parte do hover;
> (c) confirmar dispara a CERIMÔNIA DA BIGORNA — ver a seção grande mais
> abaixo. Resumo: a carta sobe pra pose herói, leva TRÊS marteladas e o
> upgrade acontece VISÍVEL numa placa de delta ("ATQ 8 -> 10", com o
> valor antigo cedendo lugar ao novo em pop dourado). Referência de
> intenção: a forja do Slay the Spire;
> (d) overflow resolvido por PAGINAÇÃO (uma grade com scissor cortaria
> sombra, lift e painel das cartas — paginar preserva o 3D inteiro).
>
> UMA ENTRADA POR CÓPIA (Set/2026): a grade percorre currentDeck por ÍNDICE.
> Duas "Golpe" no deck = duas cartas na bigorna, cada uma com o próprio nível,
> e forjar/remover/duplicar uma NÃO toca na outra (RunManager, seção "Forja
> POR CÓPIA"). Mesma regra do DeckViewerScreen, que sempre mostrou cópia a
> cópia — a bigorna é que destoava.
>
> Acessibilidade: com _G.gameSettings.reducedMotion a MUDANÇA DE VALOR continua
> acontecendo e legível (a placa mostra o antes/depois, o "+2 ATQ" aparece) —
> só o exagero some (marteladas, faíscas, flash, jiggle, pop de escala).
> Informação de jogo nunca depende de juice.

## L64-67 (em `RestScreen`, junto a `local FORGE_Q = "forge"`)

> Fila dedicada pros beats da bigorna. Os primitivos do Card (start_dissolve)
> empilham eventos BLOQUEANTES na fila default; agendar os nossos beats lá
> dentro os deixaria reféns desse bloqueio. Mesmo motivo pelo qual a
> CardRewardScreen tem a fila própria dela.

## L77-79 (em `instance.buttons`, junto a `instance.cardList = {}`)

> ÍNDICES em currentRun.currentDeck das cópias elegíveis. ÍNDICE, e não
> id: duas "Golpe" no deck são DUAS cópias distintas e o jogador escolhe
> QUAL delas vai pra bigorna (ver RunManager, seção "Forja POR CÓPIA").

## L84 (em `instance.cardEntries`, junto a `instance.busy = false`)

> cerimônia da bigorna rodando: trava o input

## L92-95 (em `instance.choiceCards`, junto a `local PICKER_KEYS = {`)

> Textos por modo de picker (forge = fogueira/loja; remove/duplicate = eventos).
> Só os PREFIXOS de chave moram aqui — o texto vem do i18n a cada draw, senão
> uma troca de idioma com a tela aberta não pegaria. Ver src/i18n/locales/*.lua
> na seção `rest`.

## L102-103 (em `PICKER_KEYS`, junto a `local function pickerText(mode, part)`)

> Resolve title/sub/hint/empty do modo atual. Retorna nil no modo "choose"
> (a fogueira tem os textos dela).

## L110-113 (em `pickerText`, junto a `local STAT_KEY = {`)

> Rotulo do stat na placa de delta e nos textos de resultado. Reusa
> card_type.* de proposito: assim a placa diz a MESMA palavra que o rodape da
> propria carta (em alemao, ANGRIFF nos dois lugares). A placa MEDE o rotulo,
> entao rotulo longo nao quebra o layout.

## L123-125 (em `statLabel`, junto a `function RestScreen:show(game, onClose, mode)`)

> mode opcional: "choose" (default — fogueira: descansar OU forjar) |
> "forge" | "remove" | "duplicate" (vai DIRETO ao picker de cartas — usado
> pela oferta Forja da loja e pelos eventos, via _G.openCardPicker).

## L131-132 (em `RestScreen:show`, junto a `self._directPicker = (self.mode ~= "choose")`)

> Picker direto (loja/evento): o "Voltar" FECHA a tela em vez de cair no
> menu da fogueira (que não é o contexto de origem).

## L140-142 (em `RestScreen:show`, junto a `self.lastPickDone = false`)

> O picker FEZ algo (forjou/removeu/duplicou)? Quem abriu o picker pago
> (Forja da loja) lê isto no fechamento pra devolver o ouro se o jogador
> só apertou Voltar.

## L153-155 (em `RestScreen:hide`, junto a `EventManager.clear(FORGE_Q)`)

> Beats da bigorna que ainda não venceram morrem com a tela (a fila é só
> nossa). Os eventos dos primitivos do Card vivem na fila default e se
> resolvem sozinhos — não é nosso papel limpá-los.

## L168-181 (em `RestScreen:isVisible`, junto a `function RestScreen:resize()`)

> Resize handler: rebuilda os botões usando sw/sh atuais (cada modo tem o seu).
> (Antes checava self.buildForgeButtons, que nunca existiu — resize em pleno
> modo forge caía nos botões de "choose". Com os modos novos de picker o
> rebuild correto é re-entrar na grade de cartas.)
> Resize handler. Cobre TODO o estado derivado da janela que esta tela cacheia
> (memory/ui_layout_invariants.md §2): métricas da grade, posições+escala das
> cartas, paginação, botões de rodapé E a geometria da cerimônia da bigorna
> (pose herói, placa de delta, decalques das marteladas).
>
> Armadilha que isto evita (a mesma do PackOpenScreen): resize NÃO pode
> "reposicionar do zero" enquanto há animação em curso. Aqui ele RECALCULA O
> DESTINO — `_layoutPage(false)` reposiciona as instâncias EXISTENTES em vez
> de recriá-las, então o dissolve do "remover" e a cerimônia da forja
> continuam de onde estavam, só que na geometria nova.

## L197-198 (em `RestScreen:panelRect`, junto a `pw = math.min(1000, math.floor(sw * 0.92))`)

> Picker de CARTAS: precisa de muito mais área que o menu da fogueira
> (10 cartas de ~140×210 não cabem nos 680×560 antigos).

## L230-232 (em `self.choiceCards`, junto a `local full = p and p.health >= p.maxHealth`)

> Vida cheia: descansar continua possível (StS também deixa), mas a
> carta AVISA no próprio objeto e apaga — antes oferecia "+30% HP" sem
> dizer que não curaria nada (auditoria de UI, Out/2026).

## L260-263 (em `self.choiceCards`, junto a `function RestScreen:_markCampUsed()`)

> A fogueira foi USADA: "Salvar e sair" durante a cerimônia não pode
> reabrir o acampamento no Continuar (curaria/forjaria duas vezes). O resume
> lê "rest_done" → encruzilhada. Picker direto (loja/evento) não é nó de
> descanso e não mexe no estágio.

## L271-272 (em `RestScreen:_markCampUsed`, junto a `function RestScreen:_healPct()`)

> Fração curada pela fogueira: 30% base, reduzida pelo Selo "Cura Escassa" /
> maldição "Fome" (RunModifiers). Prévia e cura leem a MESMA conta.

## L290-294 (em `self.choiceCards`, junto a `Sfx.play("healShimmer", { pitch = 0.95, volume = 0.55 })`)

> A cura era a ÚNICA das três ações da fogueira sem celebração: a forja
> tem cerimônia de bigorna inteira e a remoção queima a carta, mas
> descansar só trocava um texto. Reusa exatamente o vocabulário que o
> combate já usa pra cura — número verde subindo e faíscas no jogador —
> em dose menor, porque aqui não há impacto pra justificar mais.

## L308-310 (em `self.choiceCards`)

> ===========================================================================
> PICKER DE CARTAS (forge / remove / duplicate)
> ===========================================================================

## L312-315 (em `self.choiceCards`, junto a `local function cloneEffects(inst)`)

> createCardInstance aponta instance.effects pra MESMA tabela do CardDatabase
> (src/systems/CardDatabase.lua) e applyUpgradesToInstance soma em eff.value —
> sem esta cópia, abrir a bigorna com uma carta de EFEITO forjada envenenaria
> o catálogo (o valor cresceria a cada abertura de tela).

## L327-329 (em `c`, junto a `function RestScreen:_makeInstance(cardId, level)`)

> Instância de exibição da carta, com o nível de forja JÁ aplicado (mesmo
> caminho do DeckViewerScreen: createCardInstance + applyUpgradesToInstance,
> que também re-renderiza a moldura com os números novos e o selo +N).

## L343-344 (em `RestScreen:_makeInstance`, junto a `function RestScreen:_gridRect()`)

> Área útil da grade dentro do painel (header em cima; rodapé com paginação
> + Voltar embaixo).

## L354-355 (em `RestScreen:_gridRect`, junto a `function RestScreen:_gridMetrics()`)

> Geometria da grade: colunas/linhas e a escala de carta que cabe nelas.
> Tudo derivado das dimensões ATUAIS da janela (nada hard-coded).

## L363 (em `RestScreen:_gridMetrics`, junto a `local maxCols = math.max(2, math.floor((gw + gapX) / (74 + gapX)))`)

> Janela estreita: nunca espreme a carta abaixo de ~74px de largura.

## L374-375 (em `RestScreen:_gridMetrics`, junto a `local scale = math.min(cellW / CARD_W, cellH / CARD_H, 1.6)`)

> 1.6 = teto de escala (carta ~154×230). Sem teto, uma tela larga com
> poucas cartas geraria cartas gigantes e sem respiro pro hover.

## L389-392 (em `RestScreen:enterForgeMode`, junto a `if self.mode == "choose" then self.mode = "forge" end`)

> Só a FOGUEIRA (modo "choose") promove pra "forge". Sobrescrever o modo
> aqui era um bug: _G.openCardPicker("remove"/"duplicate") dos eventos
> caía em enterForgeMode e virava FORJA — o evento prometia remover uma
> carta e forjava outra.

## L409-413 (em `self.cardEntries`, junto a `local rm = self.game.runManager`)

> UMA ENTRADA POR CÓPIA. Aqui havia um `seen[id]` que colapsava cópias
> repetidas numa só ("tenho duas Golpe e a bigorna só mostra uma" — a
> queixa do dono). A dedupe era coerente com a forja antiga, que era POR
> ID (forjar uma subia as duas, então mostrar duas seria mentira); com o
> nível POR CÓPIA cada cópia é uma escolha de verdade e todas aparecem.

## L416-417 (em `self.cardEntries`, junto a `local id = type(entry) == "table" and entry.id or entry`)

> currentDeck guarda id string OU {id, edition, seal, up} (cartas de
> booster com edition/seal — RunManager:addCardToDeck).

## L419-420 (em `self.cardEntries`, junto a `if id and (self.mode ~= "forge" or rm:canUpgradeAt(i)) then`)

> No modo FORJA, só lista cópia que a forja consegue melhorar
> (canUpgradeAt também barra cartas sem stat/effect upgradável).

## L430-432 (em `self.cardEntries`, junto a `local function gridPositions(m, count)`)

> Posições da grade pra `count` cartas: cada linha centrada, bloco todo
> centrado na área da grade. Puro (só depende das métricas) — é o que permite
> reposicionar sem recriar nada.

## L454-455 (em `pos`, junto a `local function placeEntry(e, p, m)`)

> Aplica posição + escala da grade numa entry JÁ EXISTENTE. Não recria a
> instância: é isto que faz um resize preservar dissolve/juice/cerimônia.

## L461-463 (em `placeEntry`, junto a `inst.homeX, inst.homeY = p.x, p.y`)

> Âncoras IMUTÁVEIS: Card:draw grava self.x/y a cada frame; o layout parte
> SEMPRE daqui (lição do feedback loop y+=entryOy da CardRewardScreen, que
> mandava as cartas pra fora da tela).

## L469-470 (em `placeEntry`, junto a `inst.isRewardCard = true`)

> Padrão REWARD (e não shop): a carta SOBE no hover. É a linguagem certa
> pra uma tela de ESCOLHA.

## L481-482 (em `entries`, junto a `local deckIdx = self.cardList[first + i - 1]`)

> deckIdx é a IDENTIDADE da cópia (índice em currentDeck). O id serve
> só pra montar a instância e escrever o nome.

## L499-502 (em `entries`, junto a `function RestScreen:_layoutPage(rebuild)`)

> Calcula métricas e posiciona a página atual.
> rebuild = true  → cria instâncias novas (entrar na tela, trocar de página)
> rebuild = false → RESIZE: reposiciona as instâncias existentes; só cai em
> rebuild se a composição da página mudou de verdade.

## L507-510 (em `RestScreen:_layoutPage`, junto a `if self.busy or self.forge then`)

> Animação em curso (cerimônia da bigorna, dissolve do "remover"): a
> composição da página fica CONGELADA. Trocar as instâncias no meio
> mataria a animação — reposicionar é o suficiente e é o que o
> "recalcular destino ≠ reposicionar do zero" pede.

## L525-527 (em `RestScreen:_layoutPage`, junto a `local anchor = self._anchorIdx or 1`)

> Resize: mantém visível a MESMA carta que abria a página. Sem esta
> âncora, mudar o nº de colunas jogaria o jogador pra outra página
> (ou pro clamp da última) sem ele ter pedido nada.

## L563-564 (em `self.buttons`, junto a `if self.pageCount > 1 then`)

> Paginação: overflow resolvido por página, não por scroll (um scissor
> cortaria sombra/lift/painel de hover das cartas).

## L577-578 (em `self.buttons`, junto a `local back = Button:new(`)

> Botao voltar (dentro do painel, rodapé). No picker direto (loja/evento)
> fecha e devolve o controle; na fogueira volta pro menu descansar/forjar.

## L605-608 (em `RestScreen:_changePage`, junto a `function RestScreen:_onPickCard(entry)`)

> Despacho do picker: a MESMA grade de cartas serve pra forjar (fogueira/
> loja), remover (eventos) e duplicar (eventos) — o modo decide a ação.
> Recebe a ENTRY da grade (a cópia escolhida), não um id: com cópias
> repetidas o id não distingue qual delas o jogador apontou.

## L633-634 (em `reducedMotion`, junto a `local function jiggle(amount)`)

> Jiggle da tela (mesmo vocabulário do PackOpenScreen — a cinemática de pack
> que roda de verdade no jogo). Silencioso com reducedMotion.

## L647-650 (em `flash`, junto a `local function playFirst(codes, opts)`)

> Toca o primeiro som REGISTRADO da lista (mesmo contrato dos sons-assinatura
> de joker: registro por SCAN + fallback via Sfx.has). Enquanto
> audio/sfx/forge-strike.mp3 não existir, cai no genérico e nada quebra.
> playFirst({ "forgeStrike", "restComplete" }, { pitch = 1.05 })

## L665 (em `RestScreen:doRemove`, junto a `if not run or #run.currentDeck <= 2 then`)

> Guarda: nunca deixar o deck abaixo de 2 cartas (o jogo precisa de mão).

## L671-672 (em `RestScreen:doRemove`, junto a `local displayName = I18n.cardName(cd or cardId)`)

> I18n.cardName e nao cd.name: o nome da carta no texto de resultado
> tem que sair no idioma do jogador, igual ao da moldura e do tooltip.

## L674-676 (em `RestScreen:doRemove`, junto a `self.game.runManager:removeCardAt(entry.idx)`)

> removeCardAt e não removeCardFromDeck(id): com três "Golpe" no deck, a
> remoção por id levaria SEMPRE a primeira — inclusive quando o jogador
> apontou a terceira (que podia ser a forjada).

## L684-685 (em `RestScreen:doRemove`, junto a `self.busy = true`)

> A página arde: mesma linguagem da forja, sem o retorno. Paleta
> "exhaust" (preto/cinza) — isto não volta.

## L703-704 (em `RestScreen:doDuplicate`, junto a `local displayName = I18n.cardName(cd or cardId)`)

> I18n.cardName e nao cd.name: o nome da carta no texto de resultado
> tem que sair no idioma do jogador, igual ao da moldura e do tooltip.

## L706-707 (em `RestScreen:doDuplicate`, junto a `self.game.runManager:duplicateCardAt(entry.idx)`)

> duplicateCardAt e não addCardToDeck(id): a cópia nova sai igual à
> ESCOLHIDA (mesmo nível de forja, mesma edition/seal).

## L722-765 (em `RestScreen:doDuplicate`, junto a `local FORGE_T = {`)

> CERIMÔNIA DA BIGORNA
>
> Pedido do dono: "uma animação da carta sendo upgradada, para que o upgrade
> tenha algo VISÍVEL". O que ele quer ver não é uma transição — é a MUDANÇA DE
> VALOR. Dissolve→materialize provava que "algo aconteceu"; não dizia O QUÊ.
>
> REFERÊNCIA (Slay the Spire, estudo de intenção — zero cópia de código/asset;
> fonte descompilada em E:\dev\projects\slay-the-spire-source):
> · UpgradeShineEffect      → TRÊS marteladas em posições distintas ao redor
> da carta, cada uma com shake curto e forte;
> o som toca na primeira.
> · UpgradeHammerImprintEffect → cada martelada deixa um decalque em rotação
> aleatória, additive, que expande e some.
> · UpgradeShineParticleEffect → ~30 faíscas por martelada, com GRAVIDADE e
> quique no chão, cor laranja/ouro sorteada.
> · ShowCardBrieflyEffect   → depois de forjar, a carta RESULTANTE é exibida
> grande no centro (drawScale 0.01 → 1.0). É
> assim que o StS torna o upgrade legível.
>
> REIMPLEMENTAÇÃO AQUI (com as ferramentas deste projeto, e resolvendo o que o
> StS não resolve — lá você compara de memória; aqui o delta é escrito):
> Fase A · ANTECIPAÇÃO (0 → 0.34s): a carta escolhida sobe pra POSE HERÓI no
> centro da grade, crescendo (o "mostrar grande" do ShowCardBriefly, só que
> antes do golpe), `swell_up` armando, véu escurecendo o resto da grade.
> A PLACA DE DELTA entra já mostrando os valores ATUAIS — o jogador lê o
> "antes" antes de o martelo cair.
> Fase B · IMPACTO ×3 (0.46 / 0.74 / 1.00): decalque + faíscas com gravidade
> + jiggle + `forgeStrike` em pitch crescente, em três pontos distintos.
> martelada 1 → aquece (só faísca)
> martelada 2 → A VIRADA: a instância da carta troca pela forjada (a
> moldura re-renderiza com os números novos) E na placa o
> valor antigo cede (esmaece + encolhe) enquanto o novo
> entra em pop dourado branco-quente
> martelada 3 → o SELO "+N" carimba
> Fase C · ASSENTAMENTO (1.22 → 2.57s): brilho decai, a carta e a placa
> ficam paradas e legíveis. Só então a tela fecha.
>
> Só entram na placa os campos que getForgeGains (RunManager, fonte única)
> diz que mudam — o que não mudou não compete por atenção.
>
> reducedMotion: sem véu animado, sem marteladas, sem faíscas/flash/jiggle. A
> pose herói e a placa aparecem prontas e A VIRADA ACONTECE IGUAL (só sem o
> pop de escala). A informação do delta nunca depende do juice.

## L777-778 (em `FORGE_T`, junto a `local CLANG_AT = {`)

> Posições das marteladas, em fração do bbox da carta herói (o StS usa três
> offsets distintos justamente pra não parecer o mesmo golpe repetido).

## L793-796 (em `SPARK_COLOURS`, junto a `local function clearHoverPose(inst)`)

> Zera o estado de HOVER da carta. Necessário porque a cerimônia deixa de
> chamar Card:updateMouse (que brigaria com a escala da pose herói) — e é o
> updateMouse quem normalmente desfaz lift/tilt/warp. Sem isto a carta subiria
> pro palco congelada na pose de hover: torta, deslocada e com o warp ligado.

## L811-812 (em `clearHoverPose`, junto a `function RestScreen:_buildForgeLines(cd, gains, lvl)`)

> Monta as linhas da placa a partir de getForgeGains. label/old/new prontos
> pra desenhar + os campos animáveis (eased pelo EventManager).

## L835-836 (em `add`, junto a `if #lines == 0 then`)

> Defensivo: canUpgrade barra carta sem ganho, então isto não deve
> acontecer — mas a placa nunca sai vazia.

## L843-849 (em `add`, junto a `local function applyPose(f)`)

> Geometria da cerimônia: pose herói + placa, centradas como UM bloco na área
> da grade. Responsivo (tudo derivado de _gridRect e da escala da grade).
> Pose da carta = LERP adimensional entre o berço (posição/escala dela na
> grade) e o palco (pose herói). Quem o EventManager anima é `f.pose` (0→1),
> um número SEM unidade — por isso um resize no meio da subida só precisa
> reescrever os dois extremos e a animação continua, sem pulo e sem reinício.
> (Animar cx/cy/scale direto prenderia a ease a coordenadas da janela antiga.)

## L857-859 (em `applyPose`, junto a `function RestScreen:_layoutForge(f)`)

> GEOMETRIA da cerimônia — e SÓ geometria. Recalculável a qualquer momento
> (é o que o resize chama), nunca toca no conteúdo nem no estado animado das
> linhas (oldA/newA/newS/hot) nem em pose/veil/glow/stamp.

## L863-864 (em `RestScreen:_layoutForge`, junto a `local labelFont = FontManager.getFont(11)`)

> Fontes re-medidas: love.resize roda FontManager.clearCache() ANTES de
> chamar a gente, então largura/altura precisam ser lidas de novo.

## L882-883 (em `RestScreen:_layoutForge`, junto a `local gridScale = (f.entry.w > 0) and (f.entry.w / CARD_W)`)

> Escala herói: a carta cresce, mas o bloco (carta + placa) tem que caber
> na área da grade com folga.

## L896-897 (em `RestScreen:_layoutForge`, junto a `if topY < gy then topY = gy end`)

> Janela muito baixa: encosta o bloco no topo da grade em vez de deixar a
> carta subir por cima do título.

## L905-906 (em `RestScreen:_layoutForge`, junto a `f.startX, f.startY = f.entry.x, f.entry.y`)

> Berço: de onde a carta sai (a posição dela NA GRADE, já reposicionada
> pelo _layoutPage quando isto vem de um resize).

## L924-925 (em `f.plate`, junto a `function RestScreen:_buildForge(entry, cardId, cd, gains, newLvl, resultText)`)

> CONTEÚDO + estado animado da cerimônia. A geometria sai toda do
> _layoutForge, pra que o resize possa refazê-la sem tocar nisto aqui.

## L940-941 (em `clangs`, junto a `function RestScreen:_clang(n)`)

> Uma martelada: decalque em rotação aleatória + faíscas com gravidade + som
> em pitch crescente + jiggle. (RNG global: é cosmético, não decisão de run.)

## L953-956 (em `RestScreen:_clang`, junto a `local decal = {`)

> O decalque guarda a FRAÇÃO do bbox da carta, não a coordenada absoluta:
> assim um resize no meio da martelada o leva junto (coordenada absoluta
> ficaria órfã na geometria antiga). O x/y acima serve só pras faíscas,
> que são físicas e transitórias.

## L964-966 (em `decal`, junto a `EventManager.parallelEase(decal, "s", 1.45, 0.55, "easeout", FORGE_Q)`)

> "easeout" em minúsculas de propósito: o lookup de engine/Easing.lua é
> case-sensitive (byName só tem easeout/ease_out) e qualquer nome não
> resolvido cai calado em `smooth`.

## L969-970 (em `decal`, junto a `ParticlesManager.spawn(x - 5, y - 5, 10, 10, {`)

> Faíscas: one-shot (pulse_max) com gravidade positiva — caem e somem,
> como respingo de forja.

## L986-987 (em `decal`, junto a `function RestScreen:_forgeTurn()`)

> A VIRADA: a carta vira a forjada e, na placa, o valor antigo cede lugar ao
> novo. É O beat do pedido — tudo o mais é moldura pra isto ser lido.

## L993-995 (em `RestScreen:_forgeTurn`, junto a `local upgraded = self:_makeInstance(f.cardId, f.newLvl)`)

> Carta: instância no nível novo. applyUpgradesToInstance re-renderiza a
> moldura, então o rodapé de stats da própria carta vira no MESMO frame
> que a placa — dois canais, um beat.

## L1020-1025 (em `RestScreen:_forgeTurn`, junto a `local POP_FONT = 15`)

> Popup do delta AO LADO da placa. FloatingText desenha CENTRADO em x
> (FloatingText.lua:127, `-w * 0.5`), então somar só uma margem à borda
> direita da placa joga METADE do texto de volta por cima dela — e o que
> ficava coberto era justamente o número novo, o payload da cerimônia.
> Por isso medimos a linha mais larga e deslocamos por metade dela, com
> fontSize explícito pra medir com a MESMA fonte que o draw vai usar.

## L1037 (em `RestScreen:_forgeTurn`, junto a `popX = math.max(math.floor(popHalf + 12), popX)`)

> nunca sai da tela

## L1043-1044 (em `RestScreen:_forgeTurn`, junto a `ln.oldA, ln.oldS, ln.newA, ln.newS, ln.hot = 0.30, 0.82, 1, 1, 0`)

> Mesmo estado FINAL, sem o trajeto: o novo valor já está lá,
> dourado, e o antigo já cedeu.

## L1064-1065 (em `RestScreen:_forgeTurn`, junto a `function RestScreen:_forgeStamp()`)

> O selo "+N" carimba (o mesmo "+N" que o resto do jogo usa no label da carta;
> entra como parte da coreografia, não do nada no fim).

## L1074-1075 (em `RestScreen:_forgeStamp`, junto a `f.stampS = 2.4`)

> "backout": a escala passa de 1 e volta — o selo BATE e assenta, em vez
> de só encolher. (Minúsculas: ver nota do lookup de Easing no _clang.)

## L1084-1085 (em `RestScreen:doForge`, junto a `local displayName = I18n.cardName(cd or cardId)`)

> I18n.cardName e nao cd.name: o nome da carta no texto de resultado
> tem que sair no idioma do jogador, igual ao da moldura e do tooltip.

## L1091-1093 (em `RestScreen:doForge`, junto a `local newLvl = self.game.runManager:upgradeCardAt(entry.idx)`)

> upgradeCardAt e não upgradeCard(id): forja A CÓPIA apontada. Pelo id,
> as outras cópias da mesma carta subiriam junto (era exatamente o motivo
> de a grade ter sido deduplicada).

## L1100-1101 (em `RestScreen:doForge`, junto a `self:_finishWith(I18n.t("rest.forge_capped", { name = displayName }), 1.0)`)

> Cap atingido (só acontece se Config.Game.UPGRADE_LEVEL_CAP > 0) —
> feedback ao jogador, sem consumir o nó (caller decide).

## L1106-1108 (em `RestScreen:doForge`, junto a `local parts = {}`)

> Texto de resultado com os ganhos REAIS (fonte única getForgeGains —
> carta de ataque puro não anuncia DEF fantasma). Fica de reserva: quando
> a cerimônia roda, quem comunica é a placa.

## L1129-1130 (em `parts`, junto a `if not entry.inst or not cd then`)

> Sem carta visível na página (não deveria acontecer): caminho curto. A
> forja NUNCA depende da animação — o upgrade já está aplicado acima.

## L1162-1164 (em `self.buttons`, junto a `EventManager.parallelEase(f, "pose", 1, FORGE_T.lift, "smooth", FORGE_Q)`)

> Fase A — ANTECIPAÇÃO: a carta sobe pra pose herói e se arma. Quem é
> animado é a POSE (0→1, adimensional) — ver applyPose: é o que deixa a
> subida sobreviver a um resize no meio dela.

## L1192-1194 (em `self.buttons`, junto a `function RestScreen:_drawForge(px, py, pw, ph)`)

> Desenho da cerimônia. Ordem: véu → halo → carta herói → decalques das
> marteladas → placa de delta → selo. (As faíscas são partículas globais,
> desenhadas pelo main.lua por cima de tudo.)

## L1199-1200 (em `RestScreen:_drawForge`, junto a `if (f.veil or 0) > 0 then`)

> Véu: isola a carta do resto da grade (o StS escurece a tela inteira
> durante a forja; aqui basta o painel, que é o palco).

## L1210 (em `RestScreen:_drawForge`, junto a `if (f.glow or 0) > 0.01 then`)

> Halo de brasa atrás da carta, aceso na virada e decaindo.

## L1222-1223 (em `RestScreen:_drawForge`, junto a `if inst then`)

> Carta herói. A escala vem da pose (não do hover) — por isso o update
> pula o updateMouse enquanto a cerimônia roda.

## L1239-1240 (em `RestScreen:_drawForge`, junto a `local dx = f.heroX + f.heroW * d.fx`)

> Resolve a fração AGORA, na geometria corrente (sobrevive a
> resize no meio da martelada).

## L1262-1264 (em `printCentered`, junto a `function RestScreen:_drawForgePlate()`)

> A PLACA DE DELTA: o payload do pedido. Uma linha por campo que a forja
> muda (e só por esses). O valor antigo esmaece e encolhe; o novo entra
> grande, branco-quente, e assenta em ouro.

## L1294-1295 (em `fill`, junto a `if (ln.newA or 0) > 0.01 then`)

> Valor NOVO: só existe depois da virada. Branco-quente (`hot`) por
> um instante, depois ouro.

## L1326-1332 (em `fill`, junto a `local PANEL_MAX_INNER = 230`)

> PAINEL DE BIGORNA (hover)
>
> O preview "ATQ 8 -> 10" era a ÚNICA forma de saber o que a forja faz — não
> podia sumir na troca de botões por cartas. Virou este painel ancorado na
> carta em hover: nome + nível, os ganhos REAIS (getForgeGains, fonte única)
> e a descrição. Nos modos remove/duplicate o painel explica a consequência.

## L1393-1401 (em `RestScreen:_drawHoverPanel`, junto a `local _, nameLines = nameFont:getWrap(name, PANEL_MAX_INNER)`)

> MEDE tudo antes: a maior linha define a largura (nada vaza do painel —
> mesma disciplina do CardInfoDisplay v2).
>
> PANEL_MAX_INNER e largura de QUEBRA, e vale so pro que quebra (nome e
> descricao). As linhas de GANHO ("VERTEID.  7  ->  9") sao atomicas: nao
> ha onde quebrar sem mentir. Aplicar o cap sobre elas nao encurtava a
> linha, so estreitava o painel — e o fim dela era CORTADO. Aparecia em
> alemao/espanhol, onde o rotulo do stat e longo (ANGRIFF, DEFENSA);
> em pt_BR "ATQ" cabia e o defeito ficava invisivel.

## L1410 (em `descLines`, junto a `for _, l in ipairs(gainLines) do innerW = math.max(innerW, gainFont:getWidth(l)) end`)

> Ganhos EMPURRAM o painel, com teto relativo a tela (nunca vira tarja).

## L1422-1423 (em `descLines`, junto a `local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()`)

> Posição: ao LADO da carta (direita por padrão; esquerda se não couber),
> clampada na tela.

## L1483-1484 (em `RestScreen:update`, junto a `applyPose(self.forge)`)

> A pose é recomposta TODO frame a partir dos extremos correntes: o
> EventManager mexe só em `pose`, e um resize reescreve berço/palco.

## L1486-1489 (em `RestScreen:update`, junto a `if self.forge.entry.inst then`)

> Sem updateMouse na cerimônia, ninguém tickaria os timers de
> juice/swell da carta herói (Card:updateMouse é quem chama
> updateJuice) — a antecipação ficaria inchada pra sempre e o kick da
> virada, travado.

## L1495-1501 (em `RestScreen:update`, junto a `if self.mode ~= "choose" and not self.forge then`)

> Hover das cartas: UM alvo por frame. Os bboxes de cartas vizinhas se
> tocam (Card:updateMouse infla o bbox com a margem do lift) — deixar cada
> Card decidir sozinho acenderia duas ao mesmo tempo.
>
> Durante a cerimônia o updateMouse é PULADO de propósito: ele faz o ease
> de currentScale rumo a targetScale e brigaria com a escala da pose herói
> (que é o próprio `forge.scale`, controlado pelo EventManager).

## L1533-1534 (em `RestScreen:update`, junto a `local function drawChoiceCard(c)`)

> Escolha-cartão: painel interno com ícone grande + título + detalhe.
> Hover (via botão invisível) = levanta 4px + moldura dourada.

## L1558-1559 (em `drawChoiceCard`, junto a `local TextFit = require("src.ui.TextFit")`)

> sub e detail com FIT na largura da carta (design system Jul/2026 —
> o detail da forja "+2 ATQ / +2 DEF por nivel..." vazava dos 250px).

## L1565-1567 (em `drawChoiceCard`, junto a `local size, lines, df = 10`)

> detail QUEBRA em até 2 linhas (o da forja — "Melhora o que a carta
> TEM (sem limite)" — era cortado com reticências numa linha só); só
> se nem assim couber a fonte desce.

## L1590-1591 (em `RestScreen:draw`, junto a `local drawn = SceneBackground.draw("path_rest", sw, sh, 0.35)`)

> CENA REAL de fogueira (cover-fit + véu leve) — a tela antiga era um
> fundo pontilhado chapado com o gameplay vazando atrás.

## L1619-1620 (em `RestScreen:draw`, junto a `if self.mode ~= "choose" then`)

> Grade de CARTAS REAIS. A carta em hover desenha por ÚLTIMO pra que o
> lift/sombra/tilt dela fiquem por cima das vizinhas.

## L1622-1623 (em `RestScreen:draw`, junto a `local forgeInst = self.forge and self.forge.entry.inst`)

> A carta em cerimônia sai da grade: quem desenha ela é _drawForge,
> por cima do véu e na pose herói.

## L1635 (em `RestScreen:draw`, junto a `if #self.cardList == 0 then`)

> Grimório sem cartas elegíveis: diz isso em vez de deixar o vazio.

## L1658-1659 (em `RestScreen:draw`, junto a `if self.forge then self:_drawForge(px, py, pw, ph) end`)

> CERIMÔNIA DA BIGORNA: véu + pose herói + marteladas + placa de delta.
> Desenha DEPOIS da grade (cobre as vizinhas) e ANTES dos botões/hint.

## L1677-1678 (em `RestScreen:draw`, junto a `if self.resultText and not self.forge then`)

> Texto de resultado no rodapé: é a voz de curar/remover/duplicar. Na
> forja quem comunica é a PLACA — repetir embaixo só divide a atenção.

## L1699-1700 (em `RestScreen:mousereleased`, junto a `local e = self._hoverIdx and self.cardEntries[self._hoverIdx]`)

> Carta em hover tem prioridade sobre os botões de rodapé (não se
> sobrepõem, mas a ordem deixa a intenção explícita).

