# Loja v4: estudo do cenário, do ângulo e do hover (13/Out/2026)

Prancha: [`shop_v4_estudo.png`](shop_v4_estudo.png): (a) a pintura atual,
(b) três cenários candidatos, (c) cada um com a vitrine por cima (captura do
jogo, 1920x1080 pt_BR).

## O pedido do dono (depois do 67912fa1)

> "Ficou melhor, mas o hover da carta está meio estranho. Dá pra deixar com
> mais detalhes, igual a gente sabe fazer: quando mexer nas pontas, a carta ir
> mexendo junto. [...] O cenário: a bancada foi bem feita, mas eu queria algo
> MAIS SIMPLES, mais relacionado com a arte do jogo. Só duas bancadas, sem
> tantas coisas em cima da mesa que não sejam itens nossos. [...] O suporte da
> carta tem poucos pixels e está fazendo escadinha nos pixels. [...] O elixir
> não ficou bom na diagonal; os pacotes também não."

Sintomas e causas (o sintoma quase nunca é o defeito):

| sintoma | causa medida |
|---|---|
| "escadinha" no suporte | a borda da v3c tinha 6,83 graus (ponto de fuga): na grade da arte isso dá degraus de 8 e 9 px misturados; o trilho era desenhado por `floor(fy + k*x)` com fase própria, e plaquinha/etiqueta eram cisalhadas na grade da UI (1,5 px virtuais por px de arte): três escadas diferentes na mesma carta |
| "muito complexo, fora da arte do jogo" | pintura 688x384 com vela, caveira, livros, moedas, pano, lanterna, pilha de papéis: seis objetos decorativos SOBRE as superfícies competindo com os oito à venda |
| elixir e pacotes "não ficaram bons na diagonal" | arte frontal cisalhada: frasco redondo cisalhado vira frasco torto; pacote 128x192 reduzido a 1/3 perde a moldura |
| hover "estranho" | a carta só saía na perpendicular e crescia: nenhuma resposta ao mouse, ao contrário da mão e das recompensas |

## Decisão 1: o ÂNGULO é 1:8

Linha diagonal em pixel art só fica limpa com inclinação inteira (1:1, 1:2,
1:3, 1:4, 1:6, 1:8...): todos os degraus do mesmo tamanho. Candidatos perto
do que o dono aprovou (6,83 graus):

| razão | graus | leitura |
|---|---|---|
| 1:6 | 9,46 | mais dramático, mas sobe 60 px de arte numa fileira de 360: a 4ª carta bate na TopBar |
| **1:8** | **7,13** | **0,3 grau do que o dono já aprovou; sobe 45 px na fileira** |
| 1:12 | 4,76 | quase reto; perde a "diagonal" pedida na v3b |

Escolhido **1:8** para as DUAS superfícies (projeção oblíqua: paralelas, sem
ponto de fuga, escala constante ao longo da reta). Tudo segue a mesma razão:
arestas pintadas, carta, trilho, batentes, plaquinha, etiqueta, sombras e o
cisalhamento das relíquias antigas (1:8 ou 1:16, nunca fração qualquer).

Regra de execução: a geometria inclinada é desenhada **na grade da arte**
(`ShopLayout.lineY(y0, x) = y0 - floor(x/8)`: a MESMA fase em todo lugar) e
sobe pra tela com nearest. Nunca shear em resolução de tela sobre sprite de
baixa resolução. Só o texto sai na grade da UI, cisalhado por cima.

## Decisão 2: a resolução da arte é 640x360

| opção | px em 1080p | prós | contras |
|---|---|---|---|
| 400x225 (densidade dos salões, 4,8 px) | 4,8 | igual aos salões | relíquias de 64 px teriam que encolher pra ~36 px (perdem o desenho) ou ficariam com pixel menor que o da mesa |
| **640x360** | **3 (2 no espaço virtual 1280x720)** | **relíquias e pacotes entram em escala 1: pixel do objeto = pixel da mesa; cover-fit inteiro em 720p/1080p/1440p/4K** | pixel menor que o dos salões |
| 688x384 (v3c) | 2,8 | nenhum | cover-fit fracionário: pixels de 2 e 3 px misturados |

A coerência que importa nesta tela é objeto x superfície onde ele está (o
dono reclamou de escada, não de densidade). 640x360 dá isso em escala 1 e o
cover-fit fica inteiro em toda janela 16:9 (`ShopLayout.coverTransform`:
múltiplo inteiro se o recorte extra for <= 20%; 4:3 cai no fracionário em
vez de cortar meia mesa).

## Decisão 3: o cenário (prancha, linha b/c)

Montagem: parede do PixelLab (`create_image_pro`, 640x360, o salão do ato 1
como referência de ESTILO: paleta, contorno, detalhe e sombreamento) + as
duas superfícies desenhadas por `tools/shop_v4_compose.py` na grade, com
textura de tábua do PixelLab (reta) deslocada 1 linha a cada 8 colunas
(cisalhamento inteiro, nenhum pixel reamostrado) e cor por uma rampa de 8
tons de madeira sépia (a do `ShelfItem.WOOD`), luz da esquerda, aresta da
frente de cada superfície com realce de 1 px. Nada SOBRE as superfícies.

Notas de 1 a 5 (captura 1920x1080 com a vitrine da semente 4242):

| critério | A: estante com potes | **B: pedra do salão 1** | C: madeira, ervas, frascos |
|---|---|---|---|
| leitura em 1 s do que está à venda | 4 (potes grandes ao lado da carta 1 chamam o olho) | **5** | 4 (ervas penduradas entre as cartas) |
| coerência de pixel/paleta com os salões | 4 | **5** (mesma pedra e faixa vermelha do `castle_hall_1`) | 4 |
| zero decoração confundível com oferta | 3 (potes de vidro x elixir) | **4** (prateleira de potes alta, escura, atrás das cartas) | 3 (frascos pequenos na altura das cartas) |
| espaço limpo pra 4 cartas + 4 objetos + sino + copo | 5 | **5** | 5 |
| **total** | 16 | **19** | 16 |

(a) a pintura atual tiraria 2/3/2/4: lê bem, mas seis objetos decorativos
sobre a mesa, pixel fracionário e a borda fora de razão inteira.

**Escolhido: B.** Lanterna pintada não existe mais (a parede é calma e a luz
vem de fora do quadro): `L.lantern = nil`, a mariposa e o pulso de luz da v3
saem junto (ShopProps já aceitava nil).

## Decisão 4: o cavalete

Pixel art na grade, 1:8, mesma fase da aresta pintada: trilho ESCURO de 4
linhas (aresta clara de 1 px em cima, face em dois tons, pé de tinta) que
destaca do tampo claro do degrau, contorno de tinta nas pontas, dois batentes
de 3 px fora da carta, sombra de contato em dither à direita. Plaquinha de
raridade (latão em 4 tons, 2 pregos) pregada na FACE do degrau logo abaixo; a
etiqueta pendura do trilho por um cordão de 1 px (Bresenham), cartão de 15x8
na grade, balanço em px inteiros (sem rotação: rotação na grade quebraria a
pixel art). A perna diagonal de trás da v3 saiu (era a escadinha mais feia).

## Decisão 5: posicionamento

Retas (arte, `ShopLayout.LINES`): aresta do degrau `196 - x/8`, pés dos
objetos `290 - x/8`, aresta da mesa `306 - x/8`. Cartas em x = 110, 208, 306,
404 (passo 98); objetos em 168, 246, 324, 402 (passo 78); copo (60, um pouco
atrás) e sino (100) agrupados na ponta esquerda. Passo constante travado em
`test_shop_layout`. Quando a 4ª carta levantada (com o selo NOVA) passaria
da TopBar (4:3 desliza a fileira pra direita, onde a reta é mais alta), a
altura das cartas cede, nunca a ordem.

## Decisão 6: o hover (commit 2)

Em repouso a carta fica na pose diagonal. No hover ela sai do cavalete (como
antes) e ganha o tilt 3D da mão (`Card.hoverTilt`, a MESMA conta do
`Card:updateMouse`: posição do mouse normalizada, profundidade pelo centro,
sombra deslocada), COMPOSTO sobre a homografia da pose: o `card_perspective.glsl`
já aplica o "press" no espaço da carta antes da homografia, então a diagonal é
a base e o tilt soma por cima. O mouse é levado pro espaço da carta pela
inversa da homografia de repouso; tilt e força com amortecimento exponencial
(entra e sai suave).

## Decisão 7: elixir e pacotes (commit 2)

Gerados no PixelLab (`create_image_pro`, 16 candidatas por item) com a arte
antiga como referência de IDENTIDADE e uma guia de POSE desenhada por
`tools/shop_v4_items.py` (a antiga reduzida, cisalhada 1:8 em degraus
inteiros, lombada à esquerda). Elixir: frasco com rolha, líquido vermelho e
rótulo com a cruz, girado de forma que o rótulo acompanha a diagonal (frasco
redondo não se cisalha). Pacotes: cada um com a sua cor e selo (pergaminho com
lacre, olho dourado, máscara de bufão, lua, caveira verde), face subindo pra
direita e a espessura à esquerda. Instalados em `assets/sprites/shop/v4/`;
os PNGs antigos continuam onde são usados frontalmente (abertura do pacote,
coleção). As outras relíquias leem bem no cenário novo e ficam (cisalhamento
inteiro 1:8 ou 1:16).
