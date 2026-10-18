# Rodada de realismo do ato 1: checklist por recorte

O ANTES é sempre `00_antes` (o jogo antes de qualquer integração). Cada recorte em `recortes/` mostra o antes à esquerda e o depois à direita; a linha de cima é o dia e a de baixo é o pôr do sol. Ampliação de 2x a 3x. As folhas inteiras são `folha_*.png`, e as medidas por região estão em `medidas.txt` (só complemento).

Legenda: **OK** = pronto; **PARCIAL** = melhorou, mas falta algo; **NÃO FEITO** = ficou de fora, com a razão.

## 1. Ordem de profundidade das sombras (o defeito)

**Causa.** Todas as sombras projetadas e de contato saíam numa fila única no fim do quadro e pintavam tudo que já estava desenhado. Por isso a sombra de uma árvore lá atrás escurecia o poste da frente.

**O que mudou.** As sombras agora entram junto com cada fatia de grama, recortadas pela faixa de profundidade da fatia (shader com a curva do domo). Antes de desenhar qualquer objeto, a fila pendente é descarregada se a caixa de alguma sombra cruza esse objeto. O objeto mais perto é desenhado depois e fica limpo.

**Trava** em `test_world_shadows`: uma árvore atrás e um poste na frente, com a sombra cruzando o poste. Resultado: 0 pixels do poste escurecidos. Com a correção desligada, o mesmo teste acusa 1449.

| recorte | algo do fundo pinta algo da frente? |
|---|---|
| poste_esquerdo | não (OK) |
| poste_direito | não (OK) |
| poste_viagem_esq / meio / dir | não (OK) |
| castelo_postes | não (OK) |
| arvores_esquerda / direita | as copas da frente ficam limpas (OK) |

**Efeito colateral.** As árvores da frente ficaram mais claras que no antes. No antes elas eram escurecidas pelas sombras das árvores de trás, e era justamente o defeito. Compensei com `treeGain 0.74` nas árvores (ver o item 5).

## 2. Intensidade e forma das sombras

**Valores.**
- Projetadas: `alphaK 1.6` (antes da calibração rejeitada era 1.0; a rejeitada usava 2.0).
- Contato: `0.65` (a rejeitada usava 0.72).
- Teto de opacidade: 0,75.

**Forma.**
- A sombra nasce na pegada e escurece mais junto da base.
- Ela esmaece ao longo do comprimento (`FADE 0.6`): na trava, a base fica em 0,30 e a ponta em 0,10.
- A cor puxa o `shadowTint` do bioma (roxo escuro), não preto chapado.
- O comprimento continua sendo o do horário (ShadowEngine).

| recorte | nasce na base? | antes + um passo? | natural? |
|---|---|---|---|
| poste_esquerdo / direito | sim | sim; sem faixa dura atravessando a estrada | OK |
| castelo_postes | sim | mais escura no pé, cauda suave | OK |
| poste_viagem_* | sim | parecida com o antes | OK |
| bandeira | sim | um pouco mais forte que o antes | OK |
| fogueira_base / fogueira_fork | contato e terra queimada colados nas pedras | discreto | OK |
| loja | sim | contato na varanda, sem bloco | OK |
| inimigo | sim | igual ao antes | OK |

## 3. Chão em degradê

**O que mudou.** O véu por fatia virou um shader contínuo por pixel, que escurece o chão com a distância (`groundFar 0.8`, alcance `0.7`) e soma a névoa só bem no fundo. Não há degrau entre fatias, porque o valor é calculado por pixel e não por fatia.

| recorte | escurece longe e clareia perto? | faixas? | detalhe perto igual ao antes? |
|---|---|---|---|
| chao_perto | igual ao antes | não | sim (OK) |
| chao_meio | levemente mais escuro | não | sim (OK) |
| chao_fundo | mais escuro e um pouco enevoado | não | OK |
| chao_fork | o degradê aparece do fundo para frente | não | OK |

## 4. Volume nas árvores

**NÃO FEITO.** Tentei um shader de sombreamento do lado oposto ao sol e da parte de baixo da copa. Nas árvores grandes da frente ele não mudava nada visível em valores sutis; só em valores extremos (0,9) aparecia escurecimento, e aí parecia sujeira. Preferi tirar do que deixar um efeito que não convence. Fazer bem exige arte, ou uma máscara de luz por sprite.

## 5. Árvores verde-claras

**O que mudou.** A variação de tom por árvore caiu de 0,05 para 0,02, e `treeGain 0.74` escurece só a família das árvores.

| recorte | resultado |
|---|---|
| arvores_direita | média de cor 26/46/24, contra 28/48/24 no antes: igual (OK) |
| arvores_esquerda | 30/50/25 contra 26/40/21: ainda um pouco mais clara (PARCIAL) |

A árvore grande da esquerda ficou mais clara porque deixou de receber, por cima, a sombra das árvores de trás (o defeito do item 1).

## Castelo

| recorte | resultado |
|---|---|
| castelo_longe | tom igual ao antes; base assentada no topo da colina, sem barra reta (OK) |
| castelo_base | sem faixa dura; os tufos e o disco de contato ficam sob a crista (OK) |

## Custo (honesto)

| medida | valor |
|---|---|
| test_perf_budget | 561 draw calls, 31,5 KB (teto de 600 e 40 KB respeitado) |
| meta do plano (< 520) | **não cumprida** |
| 1920×1080, `perf_probe` | 7,7 ms por quadro, contra 4,3 ms antes desta rodada |

O que custa é descarregar a sombra antes de cada objeto que ela cruza: uma troca de canvas e de shader por descarga. O caminho para baratear é recortar a sombra pela máscara dos objetos num passe só. Ainda não foi feito.
