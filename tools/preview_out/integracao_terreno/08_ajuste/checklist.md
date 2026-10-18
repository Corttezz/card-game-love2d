# Rodada de ajuste do ato 1: checklist por recorte

O ANTES é sempre `00_antes`. Em `recortes/` (ampliados 2x a 3x), o antes fica à esquerda e o depois à direita; dia em cima, pôr do sol embaixo. As folhas inteiras são `folha_*.png`, e `medidas.txt` é só complemento.

## 1. Performance

**O que mudou.** A sombra não é mais descarregada antes de cada objeto que ela cruza. Agora:
- Todos os objetos (props, árvores, companheiras, cercas, marcos, fogueira, loja) gravam o próprio contorno com a sua profundidade numa máscara em 1/3 da resolução.
- As sombras projetadas e as de contato vão num passe único, com a profundidade de quem projeta.
- Uma composição no fim do quadro só escurece o pixel quando o objeto naquele pixel não está mais perto que quem projetou a sombra. A máscara é dilatada em 1 célula para a borda do objeto não vazar.
- As entradas são agrupadas por imagem, então o LÖVE junta as chamadas.
- Na batalha, o passe roda uma vez antes do inimigo e outra no fim.

| medida | antes desta rodada (d085e279) | agora | pedido |
|---|---|---|---|
| draw calls (`test_perf_budget`) | 561 | 390 | < 500 (OK) |
| KB por quadro | 31,5 | 31,4 | (OK) |
| 1080p, `perf_probe` | 7,7 ms | 4,4 a 5,2 ms (ruído da máquina) | 4,5 a 5 (OK) |
| trocas de canvas | 86 | 6 | (OK) |

**A trava de profundidade continua verde.** Árvore atrás e poste na frente: 0 pixels do poste escurecidos. Com a máscara desligada, a mesma trava acusa 1449.

## 2. Árvores no horizonte de dia

`contrastFarDay = 1.0`: de dia a distância não escurece mais, só recebe a névoa azulada. No pôr do sol continua `contrastFar 0.6`. O escurecimento extra das árvores só vale perto (de t = 0 a 0,6).

| recorte | resultado |
|---|---|
| castelo_longe (dia) | copas em volta do castelo verdes e com detalhe, como no antes (OK) |
| castelo_longe (pôr) | mais escuras, puxando o lilás do horizonte (OK) |

## 3. Sombra dos postes

**O que mudou.**
- Projetadas com `alphaK 1.8` e esmaecimento menor (`FADE 0.45`).
- Como a composição agora é a última coisa do quadro, a sombra aparece por cima da grama alta. Antes ela ficava escondida sob as lâminas mais próximas.

| recorte | começa na base? | visível? | natural? |
|---|---|---|---|
| poste_viagem_base_sombra | sim | sim, na grama ao lado do pé; no antes não aparecia nada | OK |
| castelo_postes | sim | sim, mais escura no pé e esmaecendo, na grama da direita e na estrada | OK |
| poste_esquerdo (landmark) | o pé está na borda inferior da tela | a sombra aponta para a câmera (sol à frente) e sai do quadro | OK, é o comportamento correto |

## 4. Árvore grande da frente à esquerda

**O que mudou.** As árvores perto ganham um tom verde (`treeNear 0.86 / 1.0 / 0.80`) e um ganho de 0,7.

| medida | antes | agora | meta |
|---|---|---|---|
| saturação média | 137 | 159 | cor mais viva (OK) |
| brilho médio | 41 | 47 | quase igual (OK) |
| desvio padrão do verde | 34 | 30 | contraste (PARCIAL) |

A cor ficou viva e não lavada. O contraste é um pouco menor que no antes, porque no antes a copa era escurecida pela sombra das árvores de trás, que era o próprio defeito corrigido.

## 5. Volume nas árvores

**NÃO FEITO, por motivo visto nas capturas.** Implementei a oclusão sugerida: uma cópia do contorno da árvore, deslocada para baixo e para o lado oposto ao sol, desenhada no lote das sombras e aplicada só nos pixels da própria árvore. Ela funciona (com intensidade 1, a copa escurece toda).

Em intensidade baixa (0,3 a 0,45), porém, ela pinta o roxo do shadowTint sobre o verde. A saturação da copa caiu de 137 para 126 de dia e de 131 para 104 no pôr do sol: a copa fica acinzentada, ou seja, suja. Deixei desligada (`selfShade.k = 0`). O mecanismo continua no motor (`ShadowEngine.occlude`) para quando houver uma cor de oclusão própria para a folhagem.

## Árvores da direita (pedido anterior)

`arvores_direita`: verde mais vivo que no antes e sem as manchas claras (OK).
