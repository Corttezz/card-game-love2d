---
name: Estudo da abertura de pacote (Balatro x Grimoire)
description: Out/2026 — a abertura de pacote do Balatro batida a batida (tempos, sons, fundo, partículas, escolha, pular), a nossa antes da v2, a lista de lacunas por impacto e o que a v2 adotou. Leitura obrigatória antes de mexer em components/PackOpenScreen.lua.
type: project
---

# Abertura de pacote: Balatro x Grimoire (Out/2026)

Fonte do Balatro: `E:\dev\projects\balatro-source` (descompilado, SÓ estudo:
nenhum código, asset ou shader copiado). Linhas citadas são desse espelho.
GAMESPEED = 1 nos números abaixo.

## 1. Balatro, batida a batida

| t (s) | Batida | O que acontece | Som |
|---|---|---|---|
| 0,0 | Compra | `G.FUNCS.use_card` (button_callbacks.lua:2155): a loja DESCE pra fora da tela (`offset.y = ROOM.T.y + 29`), o pacote vai pro centro (`draw_card(G.hand, G.play)`), `Card:open()` (card.lua:1681) troca o `G.STATE` pro estado do tipo (TAROT/PLANET/SPECTRAL/STANDARD/BUFFOON_PACK) e grava `pack_choices`. | `card1` do arrasto |
| 0,2 | Pagou | `juice_up()` no pacote enquanto o dinheiro desconta. | moedas |
| 0,0 a 0,3 | Painel sobe | `update_*_pack` (game.lua ~3355): cria `G.booster_pack` (UIBox) com `offset.y` de `ROOM+9` (fora, embaixo) e manda pra `-2,2`: o painel SOBE do rodapé com a mola do Moveable. `ROOM.jiggle += 3`. | |
| 0,0 | Fundo e clima | `ease_background_colour_blind(STATE)` (common_events.lua:311): o fundo animado (shader de redemoinho) muda de COR e CONTRASTE por tipo (Arcana roxo/contraste 1,5; Spectral azul/2; Standard preto com vermelho/3; Buffoon laranja/2; Celestial preto/3). Partículas de AMBIENTE na sala inteira: `booster_pack_sparkles` (Arcana: branco/roxo/dourado, vida 1, vel 1,1; Spectral: branco/dourado, vida 3, vel 0,2), Celestial tem `booster_pack_stars` + `booster_pack_meteors`. | **música troca**: `modulate_sound` (misc_functions.lua:727) escolhe `music2` (pacote) ou `music3` (celeste) em vez da `music4` da loja |
| 0,6 a 1,8 | Carga | `Card:explode()` (card.lua:1973), `explode_time = 1,3`: o pacote TREME com rotação de ruído `r = 0,05·(sin 5t + cos(0,33+41t) + cos 67t)·p` e cresce `+15%·p` (p = 0→1 no tempo todo). Faíscas pequenas saindo dele (`Particles`, escala 0,2, vel 2). De 0 a 0,9·T o `dissolve` sobe até 0,3 (já começa a desfazer). | `explosion_buildup1` (sobe junto) |
| ~1,8 | Estouro | Em 0,9·T: rajada (`pulse_max = 30`, vel 15, vida 0,5) com as cores do pacote, `dissolve` vai a 1 em 0,1·T, `juice_up`, vibração do controle. O pacote some em 1,5·T. | `explosion_release1` |
| 1,9 | Cartas | Em `1,3·√GAMESPEED` depois do início do explode: TODAS as cartas nascem JUNTAS na posição do pacote (`card.T.x = self.T.x`) e `start_materialize` (card.lua:2183) com 1,5×0,6 = 0,9 s, partículas da cor do tipo. Depois `G.pack_cards:emplace` e a mola da CardArea ESPALHA as cartas do centro pras vagas. | `whoosh1` (0,6–0,7) + `crumple1..5` (1,2–1,4), com trava de 10 ms pra não empilhar |
| +0,5 | Foco | `recall_cardarea_focus('pack_cards')`: o cursor do controle cai na primeira carta. | |
| — | Painel | `create_UIBox_arcana_pack` (UI_definitions.lua:1629): CardArea LINEAR (largura = n·CARD_W), embaixo um bloco com o NOME (DynaText rotate+bump, `pop_in = 0,5`) e "Escolha N" (DynaText ligado ao `pack_choices`, `pop_in = 0,7`); PULAR numa coluna à DIREITA, cinza, `minw 1,8 / minh 1,2`, botão `y` do controle. | |
| hover | Passar o mouse | `Card:hover` (card.lua:4306): `juice_up(0,05; 0,03)` + tooltip da carta. | `paper1` (pitch 0,9–1,1; vol 0,35) |
| clique | Destacar | `Card:highlight` (card.lua:4582): a carta SOBE na área e ganha o botão SELECIONAR/USAR PRESO embaixo dela (`align bmi, offset y 0,65`). Outro clique troca o destaque. | `cardSlide1` |
| usar | Escolher | `use_card`: o painel do pacote DESCE; carta de baralho vai pro deck (`G.deck:emplace`), coringa pra fileira de coringas; `pack_choices - 1`; se acabou, `end_consumeable`. | `card1` + `generic1` |
| fim | Fechar / Pular | `skip_booster` → `end_consumeable` (button_callbacks.lua:2565): partículas de ambiente somem em 1 s, painel desce (`ROOM+9`) e é removido em 0,2 s, a loja SOBE de volta, o fundo volta pra cor da loja, salva. Pular só fica ativo quando as cartas já existem (`can_skip_booster`). | volta a `music4` |

Resumo do sentimento: (1) **a sala muda** (cor, partículas, música) — você
entrou num momento; (2) **carga longa e legível** (1,3 s de tremor que
cresce, com som que sobe) antes do estouro; (3) estouro curto e seco; (4)
as cartas saem DO pacote e se espalham com mola; (5) escolher é destacar +
botão preso na carta; (6) sair desce tudo e devolve a loja.

## 2. Grimoire antes da v2 (`components/PackOpenScreen.lua`, até 42f99d50)

| t (s) | Batida | O que acontecia | Som |
|---|---|---|---|
| 0,0 | Abre | Fundo OPACO na hora (sem transição da loja) com um DISCO radial quente pontilhado atrás do pacote — o mesmo para os 5 tipos. Pacote parado no centro. | `shopOpen` |
| 0,45–0,7 | Tremor | 0,25 s de tremor senoidal (`sin 55t`) + escala 0,93. | — |
| 0,7 | Estouro | Flash, lavagem de cor na tela, ANÉIS concêntricos (shockwave) + `burst_*.png` (um disco de raios) girando, 14–26 quadradinhos. | selo do tipo + acento |
| 1,3 | Cartas | Do centro, 0,1 s entre elas, materialize 0,7 s, voam pra vaga. | `packCardReveal` com pitch subindo |
| 1,5–1,7 | Cabeçalho | Painel do topo com o nome (DynaText) e Pular; etiquetas de raridade todas de uma vez quando a última pousa. | — |
| clique | Escolher | 1º clique destaca (moldura dourada FORA da carta, pulsando) + botões Selecionar/Cancelar; 2º confirma. | `cardSelect` / `packCardPick` |
| fim | Fecha | Não escolhidas dissolvem no lugar, a escolhida cai pra baixo. Medido: o fechamento levava **2,4 s** depois do clique porque `EventManager.after` (bloqueante) ficava atrás dos eventos de materialize na fila base. | — |

## 3. Lacunas, por impacto

1. **Estouro com "bola de luz"** (disco `burst_*.png`, anéis, disco radial no fundo): exatamente o que o dono proíbe (CLAUDE.md §14). E não lê como "rasgar um pacote".
2. **Carga curta demais** (0,25 s): o Balatro gasta 1,3 s construindo; o nosso estoura antes de o jogador entender que algo vai acontecer.
3. **A sala não muda**: fundo igual pros 5 tipos, sem transição da loja (corte seco), sem clima. No Balatro cada tipo tem cor e partícula próprias.
4. **Seleção desenha FORA da carta** (moldura pulsante) — viola a regra de borda.
5. **Fechar demora e trava** (2,4 s, fila bloqueante) e as cartas recusadas só dissolvem paradas.
6. **Raridade sem momento**: todas as etiquetas aparecem juntas; uma rara pousa igual a uma comum.
7. **Sem pular a animação** e sem ação de pad pro Pular (só Esc / clique).
8. Música não muda no pacote (Balatro troca de faixa). Fica pendente: pede faixa nova aprovada pelo dono.

## 4. O que a v2 fez (24/Out/2026)

Linha do tempo própria (`PackOpenScreen.TIMING` / `TIMING_REDUCED`, relógio
da tela `self._t` + lista de batidas `_at` + tweens próprios): nada espera a
fila bloqueante do EventManager, e `fastForward()` dispara as batidas que
faltam em modo instantâneo.

| t (s) | Batida v2 | Som |
|---|---|---|
| 0,00–0,35 | Clima do tipo entra em fade POR CIMA da loja (`src/ui/PackMood.lua`: gradiente vertical em 9 degraus com dither Bayer, bordas laterais escurecidas em degraus, nunca disco; partículas de ambiente por tipo: pó que sobe / confete que cai virando / centelhas em cruz / estrelas que piscam + meteoro / fiapos que sobem). O pacote SOBE do rodapé (outBack). Arte ESTÁTICA da v5 (as `v5_anim` têm brilho ciano fora da paleta). | `shopPackLift` |
| 0,20 | Cabeçalho desce do topo com o nome (DynaText) e Pular (inativo). | — |
| 0,35–1,25 | Carga: tremor de ruído em 3 frequências crescendo com p², escala +12%, faíscas de pixel saindo das bordas (10→90/s), e a SILHUETA do pacote acende em degraus (desenho aditivo do próprio sprite, nada fora dele). | `sceneRustle` 3× com pitch 0,85 → 1,1 |
| 1,05 | Rasgo: a TIRA DE CIMA do sprite (20% da altura útil, medida no PNG) solta e voa girando pra cima; o pacote segue sem ela. | `shopPackOpenTear` + tremor leve |
| 1,25 | Estouro: o resto do sprite parte em 4×5 pedaços (quads da arte) com gravidade e giro (rotação em degraus de 22,5°) + rajada de quadradinhos nas cores do tipo (`src/ui/PackBurst.lua`); flash curto e tremor. Sem anel, sem disco (os `burst_*.png` e o shockwave saíram). | selo do tipo + acento |
| 1,38 + 0,14·i | Cartas DADAS uma a uma do ponto do rasgo, de 55% até a vaga (outBack), dissolve inverso; pousou → etiqueta de raridade CARIMBA (pop de escala). Rara/lendária segura +0,22 s, juice maior, carimbo maior. | `packCardReveal` (pitch sobe), `cardShelfPlace` no pouso, `cardDiscovered` na lendária / `packCardPick` agudo na rara |
| pronta | ~2,1–2,3 s (3 cartas). Pular ativo + ação Y do pad. | — |
| durante a abertura | Clique, Enter, Espaço, Esc ou A ADIANTAM tudo pro estado pronto (pedaços somem, cartas na vaga). | `cardShelfPlace` |
| clique carta | Destaque: a carta SOBE até 14 px (limitado pela folga real entre cabeçalho e cartas, contando o selo NOVA e o hover: `_overhang`) + juice; Selecionar/Cancelar na banda de ação. A moldura dourada pulsante que desenhava FORA da carta saiu. | `cardSelect` / `cardDeselect` |
| confirmar | Escolhida: juice + sobe, depois voa e encolhe pro canto do baralho e dissolve; as outras AFUNDAM acelerando e dissolvem; cabeçalho sobe; clima sai em fade (a loja volta). Fecha em 0,95 s (era 2,4 s). | `packCardPick`, `shopLeaveWhoosh` |
| Pular / Esc / Y | Mesmo fim, todas afundam. | `cardDeselect` + `shopLeaveWhoosh` |

Layout: `PackChoiceLayout.LIFT_RESERVE = 30` reserva folga entre cabeçalho e
cartas (o selo NOVA + hover já encostavam no cabeçalho antes da v2).

`reducedMotion`: sem subida, tremor, rasgo, pedaços, faíscas nem deriva
(partículas paradas, estrela sem piscar); o pacote some em fade, as cartas
aparecem direto na vaga com dissolve; nome, Pular, etiquetas, detalhe e sons
idênticos; pronto em 0,8 s. Remove movimento, nunca informação.

PixelLab: tentado `animate_image` (2 gerações, `tools/pixellab_pack_tear.py`,
quadros em `tools/preview_out/pacotes_v2/raw/`) pedindo o pacote rasgando a
partir da arte v5. Resultado igual ao da loja v5: o modelo só faz cintilar e
deixa o pacote translúcido, não rasga. Rejeitado; o rasgo é feito em código
com a própria arte (tira + pedaços), que fica sempre fiel ao sprite.

Pendente: música própria do pacote (Balatro troca de faixa) pede faixa nova
aprovada pelo dono.

Travas: `love . test_one test_pack_open_beats` (adiantar, Pular, confirmar,
pad: cartas viram alvo e Y pula, reducedMotion sem movimento e com tudo
visível, zonas, destaque sem pixel fora da carta e das zonas, resize no meio
da abertura em 3 tamanhos), `test_pack_choice_layout`. Prova visual:
`lovec . test_one shot_pacotes_v2 1920x1080:depois` (e `1280x720:depois`,
`resize`) + `python tools/pacotes_v2_sheet.py <save_dir>` →
`tools/preview_out/pacotes_v2/` (folhas, GIFs, comparar antes x depois).
