# Postes por ato: revisão individual (19/Out/2026, frente postes-por-ato)

Quadros 1920x1080, semente 0xC0FFEE, caminho: chegada na batalha, encruzilhada (Battle / Rest / Shop), clique em Battle, viagem, chegada.
Capturas: `tools/screenshot_postes_por_ato.lua` (`lovec . test_one screenshot_postes_por_ato <ato>:<tod>:<rotulo>`).
Por ato, em `atoN_*/`: `encruzilhada_antes_depois.jpg`, `batalha_tod65|85|100_antes_depois.jpg`, `sequencia_antes.jpg` e `sequencia_depois.jpg` (um quadro a cada 10, do clique até a chegada), `recorte_batalha_1x1.png` e `recorte_encruzilhada_1x1.png`.
Escala medida com `lovec . test_one escala_humana postes:bN` (inimigo de referência: 279 px; poste na faixa rel 13, base na mesma altura do pé do inimigo).

| Ato | Poste | Escala x inimigo | Base x borda | Braço / lanterna | Sombra | Luz (0,65 / 0,85 / 1,0) | Cobre marco/rótulo? | Ordem com inimigo |
|---|---|---|---|---|---|---|---|---|
| 1 campos | lanterna de madeira (mantida, aprovada pelo dono) | 250/279 = 0,90 | na grama; a borda interna da LANTERNA encosta na borda visível da estrada | aponta para a estrada, não invade | pegada medida (0fb43025), sem mudança | acende a meio no 0,65, cheia no 0,85 e 1,0; poça âmbar no chão | não (layout dos marcos + janela perto) | poste mais perto cobre o inimigo (trava) |
| 2 colinas | ARTE NOVA: base de pedra + haste de ferro + lanterna de chama azul (`highlands_brazier_0`), tamanho 5,2 | 243/279 = 0,87 | na grama, base estreita (era o pilar largo com metade na estrada) | lanterna à direita da haste, `face = 1` (antes o pilar não espelhava) | pegada medida | azul fria; poça calibrada (`emit 2,2`), sutil: é luz de lua, não fogo | não | idem |
| 3 abismo | poste-gaiola com tocha (mantido) | 228/279 = 0,82 | na grama | gaiola em cima, sem braço | pegada medida | fogo laranja, brasas; ok nos três horários | não | idem |
| 4 gelo | poste de ferro com gelo (mantido) | 232/279 = 0,83 | na grama, neve na base | braço de ferro com lanterna, ponta na borda | pegada medida | âmbar quente sobre neve azul, poça visível | não | idem |
| 5 pântano | ARTE NOVA: madeira podre com musgo e lanterna de vidro verde (`marsh_lantern_0`) | 258/279 = 0,92 | na grama (o cipó antigo espalhava raízes para dentro da estrada) | braço com musgo pendurado, lanterna verde na borda | pegada medida | verde; poça calibrada (`radiusK 1,15`, `emit 2,0`) | não | idem |
| 6 crepúsculo | lanterna de madeira (mantida) | 245/279 = 0,88 | na grama | aponta para a estrada, não invade | pegada medida | âmbar; ok | não | idem |

## O que mudou no motor (vale para os seis atos)

1. Encruzilhada: nenhum poste nasce com rel -3 a 3,5 da parada planejada e da parada + 10 (o gigante colado na câmera) e, quando a encruzilhada abre, cada marco se desloca o mínimo para que arte + rótulo não encostem em poste nenhum (`LMG.layoutMarks`). Marcos não deslizam mais do centro na abertura: nascem no lugar e crescem. Trava: `test_scene_continuity` falha com `cobre` (matriz 6 atos x 3 sementes x 4 cenários: 72 de 72 limpas; sem as regras novas o cenário path1 já dava cobertura nos seis atos).
2. Inimigo da chegada no painter por profundidade; na batalha, a lista longe também é cortada atrás/frente. Trava `test_poste_profundidade` (chegada no main antigo: 82 a 93 % dos pixels do poste mostravam o inimigo; agora 0 %).
3. Posição pela arte: borda interna da caixa opaca na borda da estrada (`edgeGap` por bioma, hoje 0 em todos).
4. Cadência 18 (era 13): no máximo um poste por lado na faixa perto/meio nos quadros medidos.

## Leitura honesta (o que ainda não está bom)

- Com a cadência maior, as regras de nascimento (marcos, ramos, inimigo) e a janela perto da câmera, há encruzilhadas e batalhas SEM poste perto (na semente medida: ato 1 e 3 sem poste na primeira batalha, só um ao longe na crista). Escolhi não mostrar poste a mostrar poste em cima da opção ou do inimigo.
- A garantia vale para a encruzilhada parada e clicável. Na abertura os marcos já nascem no lugar; durante o converge (depois do clique) o marco escolhido vira o destino e pode passar atrás de um poste mais perto, que é profundidade correta, não opção coberta.
- O layout dos marcos pode não achar lugar se dois postes flanquearem a estrada muito perto do centro (aconteceu antes da janela perto da câmera); nesse caso o marco fica no padrão e a trava acusa. Na matriz atual não aconteceu.
- A luz da lanterna azul do ato 2 e da verde do ato 5 é discreta no chão (poça fria e pequena); está natural, mas quem espera "fogo" vai achar fraca.
- A arte nova do ato 2 perde a chama azul grande do pilar, que era a assinatura do bioma; ganha proporção de poste. Se o dono sentir falta, o pilar antigo está no histórico (be8fe749).
