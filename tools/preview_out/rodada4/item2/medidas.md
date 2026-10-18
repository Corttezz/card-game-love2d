# Item 2: luz pintada invertendo no ladrilho espelhado

## Defeito
`drawStripTiles` (e `drawStripMirrorBelow`) desenhava cópias alternadas da faixa ESPELHADAS na horizontal. A luz
pintada nas encostas trocava de lado de uma cópia para a outra; com a câmera andando, a cópia espelhada passava
pela tela inteira (antes_b1: o pico da direita aceso do lado oposto; antes_b3 e antes_b5: o mesmo morro e a mesma
árvore refletidos lado a lado). Valia para os seis biomas (no abyss a cópia espelhada ficava parada nos 12 % da
esquerda).

## Medida da costura (ladrilho reto, sem espelho)
`python tools/mountain_strip_seam.py measure`: salto de cor na emenda (coluna final contra coluna inicial) contra o
salto médio entre colunas vizinhas da própria arte, base e `_front` juntas.

| bioma | vizinho | emenda reta | decisão |
|---|---|---|---|
| fields | 24,6 | 25,7 (nuvem cortada a prumo, visível) | costura cruzada 24 px |
| highlands | 29,4 | 8,7 | contínua, só tira o espelho |
| abyss | 34,1 | 46,9 | costura cruzada 24 px |
| frost | 35,0 | 50,4 | costura cruzada 24 px |
| marsh | 33,9 | 18,1 (mas a massa escura termina num corte vertical, visto em 2x) | costura cruzada 40 px |
| dusk | 20,1 | 42,0 | costura cruzada 48 px |

A métrica média não pega o corte de nuvem do fields nem o do marsh: a decisão final foi pelo recorte a 3x
(`costura/antes/` e `costura/depois/`, duas cópias lado a lado na emenda) e pela captura 2x em cena.

## Costura cruzada sem pixel novo
Primeira tentativa: dissolve com Bayer em 12 px. Rejeitada no recorte: virou uma coluna pontilhada e silhueta
fantasma no pico do frost e nas montanhas do fields. Adotado: costura de erro mínimo (quilting): na janela de
sobreposição, cada linha escolhe a coluna onde troca do fim da faixa para o começo, caminho contínuo de menor
diferença. Nenhuma cor nova, nenhum alfa parcial; base e `_front` usam o MESMO caminho (continuam alinhadas). A faixa
perde a largura da janela (fields 375, abyss 365, frost 359, marsh 343, dusk 343 de 400). A escala NÃO muda:
`stripTransform` mede a escala contra `PropCut.STRIP_W` (400), então o ladrilho fica um pouco mais estreito que a
tela e o motivo se repete mais cedo, sem crescer as montanhas.

Sol pintado reposicionado na PNG nova: abyss `painted` 0,505 -> 0,5534, dusk 0,505 -> 0,5714 (coluna 202 menos o
corte, sobre a largura nova). Conferido nas folhas b3/b6: o disco fica no mesmo pixel de antes.

Folhas: `b<N>_ceu_antes_depois.png` (andares 1, 4 e 8, faixa do céu, tod 0,65). Reproduzir:
`python tools/mountain_strip_seam.py apply <pasta> fields,abyss,frost` (24 px), `SEAM_OVERLAP=40 ... marsh`,
`SEAM_OVERLAP=48 ... dusk` sobre as PNGs originais.
