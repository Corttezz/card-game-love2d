---
name: code_notes/src/ui/OrbRow.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/OrbRow.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/OrbRow.lua`

Origem: `src/ui/OrbRow.lua` em `7dbdb60d` (51 de 81 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/OrbRow.lua
> Fileira de orbes do jogador (identidade Defect/StS trazida pra tela).
> Resolve a "mecânica fantasma" (Jul/2026): canalizar não tinha NENHUM
> feedback visual — orbes viviam só em player.orbs e toasts passageiros.
>
> O que mostra (espelho de orbs/AbstractOrb.java do StS descompilado):
> TODOS os slots (vazio = aro apagado) — ensina o cap de 3 antes de doer;
> cada orbe com o VALOR DO PULSO escrito nele (base+Foco, ao vivo — a
> fórmula vem de EffectSystem.orbPulseValue, fonte única);
> fila FIFO: o mais à esquerda é o mais antigo (= próximo a evocar,
> marcado com um triângulo);
> hover → StatusTooltip com pulso e evoke exatos;
> preview de evoke: mão sobre carta de Evocar → orbe(s) afetado(s)
> acendem em ciano e o número vira o VALOR DE EVOKE (showEvokeValue
> do StS);
> animações: pop-in ao canalizar, flash+número flutuante no pulso do
> fim de turno, flash branco ao evocar.
>
> Módulo singleton (padrão EnemyHud): EffectSystem notifica via
> OrbRow.notifyChannel/notifyPulse/notifyEvoke (pcall — headless = no-op).

## L28-31 (em `OrbRow`, junto a `local SIZE = 48          -- lado da gema (1:1 com o PNG)`)

> SIZE = 48 porque a arte é 48x48 NATIVA (assets/sprites/orbs/): desenhar 1:1
> é o ponto inteiro de ter gerado no tamanho de uso. Reduzir pra 46 borraria a
> pedra -- foi arte reduzida virando mancha que derrubou o ícone dentro do
> orbe na rodada passada.

## L33 (em `OrbRow`, junto a `local SPACING = 12`)

> medido: com 8 as placas vizinhas encostavam

## L36-37 (em `OrbRow`, junto a `local GAP_ABOVE_PILLS = 16`)

> 16 (era 8): o trilho da fila mora ABAIXO das silhuetas e com 8 ele encostava
> na banda de pills (visto na captura de validacao).

## L47-49 (em `holy`, junto a `local EVOKE_CYAN = { 0.25, 0.95, 0.95 }`)

> (A tabela OrbRow.ICONS saiu: o PNG de 64x64 reduzido pra ~14px dentro do
> orbe virava mancha -- foi o que a captura de validacao mostrou. Quem
> identifica o elemento agora e a SILHUETA, e o nome continua no tooltip.)

## L52-76 (em `EVOKE_CYAN`)

> ============================================================================
> FORMA = ELEMENTO, GLIFO = UNIDADE (Set/2026)
> ============================================================================
> Pedido do dono, jogando: "está meio difícil de entender esses círculos ali".
> A captura `lovec . preview_battle_hud orbs` (cinco tipos lado a lado, no
> tamanho de uso, sobre o fundo real) mostrou por que: eram cinco DISCOS
> iguais, QUATRO deles exibindo o mesmo "3", e o ícone do elemento renderizado
> a ~14px virava uma mancha ilegível. Nada dizia que elemento era, nada dizia
> o que o número significava, e a fileira era indistinguível da row de pills
> logo abaixo (também redonda, também do mesmo tamanho).
>
> Três problemas empilhados, três respostas separadas:
>
> 1. QUE elemento é  -> a SILHUETA. Cor sozinha não ensina, e ícone pequeno
> não sobrevive ao tamanho de uso; a forma do contorno sobrevive.
> losango / hexágono / chama / pentágono invertido / sol.
> 2. O QUE ele faz   -> um GLIFO DE UNIDADE ao lado do número, desenhado em
> vetor (nada de PNG reduzido): X = dano, escudo = bloqueio, cruz = cura,
> seta = cresce. Duplo-codificado com a cor do glifo.
> 3. QUAL sai primeiro -> trilho com seta apontando pra ESQUERDA sob a
> fileira + aro duplo claro no próximo a evocar.
>
> O ícone PNG do elemento saiu de dentro do orbe (era a mancha). Ele continua
> valendo no fantasma de saída, onde tem espaço, e o nome do elemento continua
> no tooltip de hover.

## L78-89 (em `EVOKE_CYAN`, junto a `OrbRow.ART = {`)

> ARTE POR ELEMENTO: gema lapidada, 48x48 nativa, uma por elemento.
> Set/2026: as silhuetas VETORIAIS que vieram antes resolveram a leitura
> (distinguir os cinco de relance, e o glifo de unidade dizendo o que o número
> era) mas o dono reprovou o visual -- "achei meio feio". O diagnóstico é
> concreto: contorno colorido com INTERIOR VAZIO é wireframe, não objeto. Num
> jogo de pixel art com bevel, sombra e desgaste, geometria chapada lê como
> ícone de aplicativo -- e as pills logo abaixo (arte pixel dentro de aro)
> pareciam melhores que os orbes.
>
> O que MUDOU é o material; o que FICOU é a leitura: cada gema tem um corte
> próprio (marquise / hexágono / gota / brilhante / estrela), o glifo de
> unidade continua, o trilho FIFO continua e `readout` segue como fonte única.

## L98-116 (em `OrbRow.ART`, junto a `local ANIM_ROOT = "assets/sprites/orbs_anim"`)

> GEMA VIVA (Set/2026, pedido do dono jogando): "se a gente conseguir colocar
> animações bem sutis ali na arte delas, bem sutíssimas, só para não ser tipo
> um PNG estático igual está hoje".
>
> Mesmo CONTRATO de pasta dos ícones de carta e dos vouchers da loja
> (memory/card_icon_animation.md): assets/sprites/orbs_anim/<tipo>/frame_NNN.png
> (+ meta.lua com fps). Pasta ausente = PNG estático, e isso é um estado
> normal, não um defeito — o que é defeito é pasta existir sem frame legível,
> e isso AVISA (fallback silencioso é proibido, CLAUDE.md §9).
>
> DUAS decisões que divergem da doutrina dos ícones de carta, de propósito:
> 1. Aqui a animação roda SEMPRE, não só no hover. A regra "idle = estático"
> existe porque a mão/coleção tem DEZENAS de cartas e todas vivas viram
> carnaval; a fileira tem no máximo 3 gemas, e o pedido do dono é
> justamente que elas não pareçam PNG parado. Mesmo caso das relíquias da
> loja (UpgradeTile), que também animam sempre.
> 2. Cada slot corre com uma FASE própria (PHASE_STEP). Três gemas pulsando
> em uníssono leriam como um pisca-pisca da HUD inteira — que é o oposto
> de sutil; defasadas, cada pedra respira sozinha.

## L149 (em `gemOf`, junto a `warnedGem[orbType] = true`)

> Fallback silencioso é proibido (CLAUDE.md §9): elemento sem gema AVISA.

## L158-161 (em `gemOf`, junto a `function OrbRow.gemImageAt(orbType, t)`)

> A imagem da gema NESTE instante. `t` nil = quadro de repouso (frame 0 do
> loop, que é byte a byte o PNG estático — v3 guarda o frame de entrada como
> frame 0, é o que garante zero "pop" entre parado e vivo).
> Ordem: frame do loop -> PNG estático -> nil (e o nil já avisou em gemOf).

## L171-174 (em `OrbRow.gemImageAt`, junto a `local UNIT_OF = {`)

> UNIDADE do número. `mode` = "pulse" (fim de turno) ou "evoke" (ao evocar).
> Fonte: EffectSystem.orbPulseValue / _evokeOrbEffect -- sombra NÃO pulsa (só
> engorda) mas EVOCA como dano, e é justamente essa diferença que o glifo
> ensina quando o jogador passa o mouse numa carta de Evocar.

## L188-190 (em `grow`, junto a `OrbRow.UNIT_OF = UNIT_OF`)

> Expostos pra trava de teste (tools/test_beats.lua bloco 4g): a unidade que o
> orbe ANUNCIA tem que bater com o que o EffectSystem de fato faz, e duas
> silhuetas nunca podem coincidir.

## L193-199 (em `grow`, junto a `function OrbRow.readout(orb, focus, mode)`)

> O QUE O ORBE DIZ: (valor, unidade). Fonte única do par número+glifo — o
> desenho e o teste leem daqui.
> mode "pulse" = fim de turno; "evoke" = ao ser evocado (preview de carta).
> Sombra é o caso que justifica a função existir: ela NÃO pulsa, então o
> "valor do pulso" dela é 0 e mostrar 0 seria mentira; o que cresce é o valor
> acumulado, e é ELE que dobra no evoke.
> Exposto pro tool de comparacao visual (tools/orb_compare.lua).

## L217-219 (em `drawUnitGlyph`, junto a `local w = a * 0.22   -- pontas finas: "faisca", nao "losango"`)

> Faisca de 4 pontas. NAO e um "X": na captura de validacao o X lia
> como MULTIPLICADOR ("x3"), que neste jogo e a linguagem dos coringas
> o glifo de dano estava dizendo a coisa errada.

## L244-251 (em `pulseFlash`, junto a `local inbound = {}        -- [i] = { t, dur, color }`)

> DIREÇÃO É A PALAVRA (Set/2026, pedido do dono jogando de mago: "canaliza
> muitas ao mesmo tempo, fica confuso se está dando dano ou se canalizando").
> Dano vai PARA o inimigo; canalizar vem PARA a fileira; evocar SAI da fileira.
> Duas listas de FX resolvem os dois sentidos que faltavam:
> inbound[i] — o orbe está VIAJANDO até o slot i (o slot fica vazio e um
> cometa da cor do elemento entra na tela até pousar);
> outbound   — fantasma do orbe que DEIXOU o slot, subindo rumo ao combate.
> Sem isso o orbe simplesmente aparecia/sumia: mesma leitura de "explodiu algo".

## L255 (em `outbound`, junto a `local FLIGHT_IN  = 0.26`)

> s: o cometa tem que pousar DENTRO do beat ORB (0.40)

## L262-265 (em `reducedMotion`, junto a `local function tutNote(ev, info)`)

> O corvo do tutorial (src/systems/Tutorial) aprende os FATOS da fileira por
> aqui: canalizou, pulsou, evocou, expulsou. Sem isto a conversa do pulso
> teria que ADIVINHAR pelo estado ("há orbe e o turno virou"); com isto ela
> nasce do acontecimento. pcall: a fileira nunca pode cair por causa do corvo.

## L270-272 (em `tutNote`, junto a `local function gemClock(i)`)

> Relógio do loop idle da gema do slot i (fase própria por slot — ver a nota
> de GEMA VIVA lá em cima). reducedMotion devolve nil: a pedra congela no
> quadro de repouso, com a mesma cor, o mesmo tamanho e o mesmo número.

## L285-287 (em `decay`, junto a `local function spellOrigin()`)

> Origem do cometa de canalização: o centro do palco, onde a carta resolve.
> Não é o ponto exato da carta (o EffectSystem não o conhece), e não precisa
> ser: o que a animação afirma é "isto veio do feitiço e foi PARA a fileira".

## L292 (em `spellOrigin`, junto a `function OrbRow.notifyChannel(i, orb)`)

> ===== Notificações vindas do EffectSystem (pcall — nunca podem quebrar) ====

## L294-295 (em `spellOrigin`, junto a `function OrbRow.notifyChannel(i, orb)`)

> Orbe entrou no slot i: ele VIAJA do feitiço até o slot e só então nasce
> (pop-in). `orb` opcional dá a cor do elemento ao cometa.

## L299-300 (em `OrbRow.notifyChannel`, junto a `slotAnim[i] = 1.0`)

> Tira o MOVIMENTO, nunca a INFORMAÇÃO: sem viagem, mas o orbe ainda
> nasce no instante do beat dele (a ordem continua legível).

## L311-312 (em `OrbRow.notifyChannel`, junto a `function OrbRow.notifyPulse(i, text, kind)`)

> Orbe do slot i pulsou: flash + número flutuante saindo DO orbe.
> kind: "damage" | "armor" | "heal" | "grow"

## L327-330 (em `OrbRow.notifyPulse`, junto a `function OrbRow.burstAtSlot(i, theme, k)`)

> Burst tematico ANCORADO no orbe. Existe pro pulso de SOMBRA, que e o unico
> cujo efeito nao sai da fileira (o orbe engorda a si mesmo) -- a marca dele
> tem que cair no proprio orbe, nao no inimigo nem no painel. Sem posicao
> calculada (headless, fileira invisivel) vira no-op.

## L339-343 (em `OrbRow.burstAtSlot`, junto a `function OrbRow.notifyEvoke(i, orb, reason)`)

> Orbe do slot i SAIU da fileira. `reason`:
> "evoke"    — o jogador evocou (a carta pediu);
> "overflow" — a fileira estava cheia e o mais antigo foi EXPULSO pra abrir
> vaga. É um acontecimento diferente e precisa dizer isso, senão
> o jogador vê um orbe sumir e não entende por quê.

## L361-363 (em `OrbRow.notifyEvoke`, junto a `local half = FontManager.getFont(14):getWidth(label) * 0.5`)

> O FloatingText e CENTRADO no x, e o slot 1 fica colado na borda
> esquerda: sem esta margem o rotulo sai da tela pela metade
> ("XPULSO" na captura de validacao).

## L372-374 (em `OrbRow.notifyEvoke`, junto a `local function cellHeight()`)

> Altura total de uma célula: gema + placa. O slot VAZIO não tem placa (a
> fileira encolhe sozinha nos turnos sem orbe), mas a ALTURA da banda é a
> mesma sempre -- senão a row inteira pularia de lugar quando o 1º orbe nasce.

## L379-382 (em `cellHeight`, junto a `local function drawPlate(x, y, w, color, unit, value, font)`)

> A PLACA do número. Fica EMBAIXO da gema, não por cima (decisão do dono no
> comparativo): número branco sobre pedra facetada apaga a pedra -- ganha-se a
> gema e perde-se a gema. A placa leva o glifo de unidade junto e a borda na
> cor do elemento, então ela também é identidade, não só suporte.

## L416-418 (em `drawPlate`, junto a `local function drawGem(orbType, x, y, alpha, flash, t)`)

> Desenha a gema 1:1 em (x, y). `flash` (0..1) acende a pedra SEM lavá-la:
> blend aditivo por cima do desenho normal, em vez de multiplicar a cor (que
> só escureceria a arte). `t` = relógio do loop idle (nil = quadro parado).

## L434-435 (em `drawGem`, junto a `function OrbRow.clear()`)

> Zera os FX em voo (troca de batalha/run, ou quem simula sem desenhar: as
> listas so esvaziam em update(), que so roda no HUD da batalha).

## L450-451 (em `OrbRow.update`, junto a `for i, fx in pairs(inbound) do`)

> Cometa de canalização: quando POUSA, o orbe nasce (pop-in). Enquanto
> voa, o slot continua desenhado vazio — o orbe está em trânsito, não lá.

## L466-468 (em `OrbRow.update`, junto a `previewMode = nil`)

> Preview de evoke/canalização: carta da mão sob o mouse anuncia o que
> fará com os orbes ANTES do clique (contrato do intent congelado vale
> pros dois lados: o jogador também vê o próprio futuro).

## L488-489 (em `OrbRow.update`, junto a `local function isVisible(game)`)

> É visível? Mago sempre (slots vazios ensinam o cap); outras classes só
> quando algum orbe existir (evita ruído de HUD pra warrior/rogue).

## L497-498 (em `isVisible`, junto a `function OrbRow.draw(game, panelX, panelY)`)

> Desenha a fileira. panelX/panelY = top-left do HudPlayerPanel; a fileira
> fica ACIMA da row de buff pills (que fica acima do painel).

## L508-511 (em `OrbRow.draw`, junto a `local PlayerBuffPills = require("src.ui.PlayerBuffPills")`)

> Zona: a fileira de orbes empilha a partir do TOPO da banda de pills.
> A altura da banda é do PlayerBuffPills (fonte única) — antes isso era o
> número mágico "36 + 6" repetido aqui, que silenciosamente quebraria se a
> banda mudasse de tamanho (ui_layout_invariants §1).

## L519-520 (em `slotPos`, junto a `local font = FontManager.getResponsiveFont(0.021, 13)`)

> Fonte 13: a placa tem 18px de altura, e 15 (a de antes, quando o número
> morava DENTRO da silhueta) transbordava a borda.

## L534-536 (em `slotPos`, junto a `love.graphics.setColor(0.10, 0.07, 0.05, 0.55)`)

> Slot VAZIO: aro apagado e MENOR, sem placa. A fileira encolhe
> sozinha nos turnos sem orbe, e "sem elemento" continua sendo a
> única coisa redonda e oca da fileira.

## L544-545 (em `slotPos`, junto a `local blink = reducedMotion() and 0.9`)

> Sem movimento a piscada vira realce fixo: o slot que vai
> receber continua APONTADO, so nao pisca.

## L557-559 (em `slotPos`, junto a `local kick = slotAnim[i] or 0`)

> bob sutil + pulinho do pop-in. Sem ESCALA: a gema é pixel art
> 1:1, e escalar em fração faria a pedra tremer (shimmer). O
> "nasceu agora" vem de subir e acender, não de inchar.

## L561-563 (em `slotPos`, junto a `local bob = 0`)

> reducedMotion tira o MOVIMENTO e nada mais: some o flutuar e o
> pulinho de chegada, FICA o clarao do pop-in (que e o que diz
> "este nasceu agora") e ficam todos os numeros.

## L570-571 (em `slotPos`, junto a `local haloC = inEvokePreview and EVOKE_CYAN or color`)

> Halo: brilho difuso ATRÁS da pedra (a gema tem corpo, então o
> halo não precisa mais desenhar a forma).

## L595-596 (em `slotPos`, junto a `local txt = tostring(shown)`)

> No preview de evoke o número também é outro: pinta o valor de
> ciano por cima pra ninguém ler o de pulso.

## L608-611 (em `slotPos`, junto a `if i == 1 and #p.orbs > 0 then`)

> PRÓXIMO A SAIR (FIFO): moldura clara em volta da CÉLULA inteira
> (pedra + placa). Antes era um aro na silhueta; com a gema não há
> polígono, e a moldura da célula lê melhor — marca "este bloco",
> não "esta borda".

## L622-623 (em `slotPos`, junto a `require("src.ui.NavCursor").target("orb:" .. tostring(x), x, y, SIZE, cellHeight())   -- foco = hover (pad)`)

> Hover → tooltip com números exatos (stacks=pulso, duration=evoke —
> reuso do StatusTooltip; as descs de status.orb_* nomeiam os campos).

## L639-641 (em `slotPos`, junto a `do`)

> Âncoras do corvo (src/systems/Tutorial): a fileira inteira com o trilho
> e a célula do mais antigo, na MESMA geometria que acabou de ser desenhada
> (antes era um retângulo fixo no HudManager que não batia com as células).

## L654-656 (em `slotPos`, junto a `if #(p.orbs or {}) > 0 then`)

> TRILHO DA FILA: uma linha sob a fileira com a ponta de seta à ESQUERDA.
> Ensina a regra inteira de uma vez -- "entram pela direita, saem pela
> esquerda" -- sem texto e sem depender de marcador por orbe.

## L666-667 (em `slotPos`, junto a `local fx = startX + SIZE / 2`)

> Losango no trilho sob o PRIMEIRO orbe: liga "este aqui" a "a saida e
> por ali". Nao depende da cor do orbe, ao contrario do aro.

## L678-680 (em `slotPos`, junto a `function OrbRow._drawFx()`)

> Os dois SENTIDOS desenhados. Cometa ENTRANDO (canalizar) e fantasma SAINDO
> (evocar/expulsar) — a mesma fileira, gestos opostos, para o jogador nunca
> confundir "ganhei um orbe" com "um orbe agiu".

## L684-685 (em `OrbRow._drawFx`, junto a `local ox, oy = spellOrigin()`)

> ENTRANDO: do centro do palco até o slot, acelerando (ease-in quad) —
> chega e "pousa", em vez de deslizar e parar.

## L703-706 (em `OrbRow._drawFx`, junto a `love.graphics.setColor(c[1], c[2], c[3], 0.30 + 0.35 * e)`)

> A cabeça do cometa JÁ É a gema que vai nascer -- a MESMA arte,
> não um substituto. Ela viaja em escala INTEIRA (1:1) com um brilho
> por trás que cresce: escalar a pedra em fração faria ela tremer,
> e meio pixel de tremor num voo de 0,26s lê como sujeira.

## L727-730 (em `OrbRow._drawFx`, junto a `love.graphics.setColor(c[1], c[2], c[3], 0.65 * a)`)

> O fantasma é a PRÓPRIA gema saindo, apagando -- também 1:1, pelo
> mesmo motivo do cometa. Quem diz "isto está indo embora" é o
> alpha + o halo da cor (âmbar quando é expulsão), não uma forma
> diferente: forma diferente leria como outro orbe.

