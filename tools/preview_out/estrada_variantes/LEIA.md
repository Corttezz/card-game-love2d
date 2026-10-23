# Estrada central: 18 variantes para escolher (23/Out/2026)

O jogo continua com a estrada atual. As variantes só aparecem se você pedir:

- **No jogo (modo cheat, DEV):** `love . cheat` ou `jogar_cheat.bat`, depois **Home** (próxima) e **End** (anterior). A ordem é atual, A, B, C, e um aviso mostra o nome da variante do ato.
- **Por variável de ambiente (DEV):** `CARDGAME_ROAD=A` (ou `B`, `C`) antes de `love .`.
- A variante vale para os seis atos ao mesmo tempo. Cada ato tem a sua própria versão de A, B e C.

## Onde olhar

- `visao_geral_18_tod65.png` e `visao_geral_18_tod85.png`: as 18 variantes lado a lado, recorte da encruzilhada.
- `atoN/folha_fork_tod65.png`, `atoN/folha_battle_tod65.png` (e `_tod85`): atual | A | B | C em 1920x1080, encruzilhada aberta e batalha (cenário sem HUD).
- `atoN/recortes_*`: recortes 2x perto da câmera (em cima) e na crista (embaixo; na encruzilhada a crista fica atrás dos marcos).

## O que parece falso na estrada atual (estudo a 1:1)

- **Cor chapada com manchas lisas.** O tile atual é ruído suave em 4 tons, e perto da câmera vira blocos de 4 px sem forma (lê como pintura vetorial borrada).
- **Sem lógica de desgaste.** O centro, os sulcos de roda e o acostamento têm o mesmo tom. Os sulcos são uma linha de 1 a 2 px quase invisível.
- **Decalques planos.** As manchas escuras elípticas (`patch`) e as pedrinhas quadradas não têm luz nem sombra. Parecem buracos ou adesivos.
- **Tile preso ao pixel da tela.** A largura do tile não segue a largura da estrada: em 1024x768 os sulcos caem fora da estrada e em 3440x1440 o tile se repete na horizontal.
- **Atos 2 e 3 sem volume.** As lajes do ato 2 e as rachaduras do ato 3 são só linhas escuras, sem chanfro, sem sombra projetada e com células do mesmo tamanho.
- **Ato 4 parece asfalto.** É uma faixa azul-escura com bolhas brancas enfileiradas no meio da neve. Neve pisada não fica preta.
- **Ato 5 com poças de mentira.** As poças são elipses verdes iguais em fila. A lama não tem água nem relevo.
- **Sem poça, folha, pegada ou pedra com sombra** em nenhum ato. A crista não perde detalhe, só fica com o tile comprimido.

## O que as variantes fazem (todas)

- **Tile novo por variante e por bioma** (`engine/RoadSurfaceVariants.lua`), gerado no código. Cada texel tem material, altura e tom. A altura gera **sombra projetada na direção da luz do bioma** (sol ou lua à direita; à esquerda no ato 6) e **borda iluminada** do lado da luz. As cores vêm da paleta do bioma em degraus, com pontilhado leve, sem gradiente liso.
- **Perspectiva certa.** O tile ocupa sempre 56 texels por meia-largura de estrada, então o detalhe encolhe junto com a estrada até a crista e fica igual em qualquer resolução. A densidade ao longo da estrada subiu 1,75x, então pedras e lajes ficam achatadas pela perspectiva em vez de esticadas.
- **Queda de detalhe no horizonte.** O tile tem uma metade borrada. Entre t 0,42 e 0,10 (perto da crista) ela entra aos poucos, por segmento, sem linha de corte e sem cintilar.
- **Decalques vivos** (`engine/RoadDecals.lua`, um atlas só e um lote de desenho): poças com o reflexo do céu do bioma e anel de ondulação, pegadas, folhas e cinza ou neve que o vento leva de lado, cintilado no gelo, juncos que balançam, brasas pulsando na luz. Tudo preso à posição do mundo (parado fica idêntico, andando escorrega com o chão).
- **Fora:** os sulcos e as pedrinhas por fileira do código antigo e os decalques `RoadWear` antigos.
- **Não usei PixelLab.** Textura vista em perspectiva num tile que se repete saiu mais controlável no código: o sulco precisa ficar alinhado com a poça do decalque e a borda com a sombra. Gerações gastas: 0. Se você escolher uma variante, dá para refinar as pedras e tábuas com PixelLab depois.

## Por ato: uma linha por variante

### Ato 1, campos (terra)
- **A, trilha gasta:** dois sulcos de roda que convergem com a perspectiva, centro mais claro e liso, acostamento mais escuro, pedrinhas com sombra. Prós: é a evolução natural da estrada atual e lê bem a 1080p. Contras: as pedrinhas ficam miúdas no fundo.
- **B, terra batida com meio-fio:** terra compactada com abaulamento, lajes chatas enterradas e meio-fio de pedras nas duas bordas, que segue a borda orgânica real. Prós: lê como estrada feita por gente. Contras: o meio-fio deixa a borda mais "construída" de novo, o contrário do que você pediu na borda orgânica.
- **C, poças e pegadas:** A com os sulcos úmidos, poças com o céu e ondulação, pegadas no centro, palha. Prós: a mais viva. Contras: a poça lê melhor no fim de tarde (0,85) do que de dia.
- **Recomendo C** (ou A, se as poças parecerem demais).

### Ato 2, planalto (pedra)
- **A, trilha de cascalho:** terra fria com cascalho e pedras maiores com sombra, sulcos limpos. Prós: discreta. Contras: perde a identidade de "pedra" do ato.
- **B, lajes irregulares:** lajes de dois tamanhos, juntas com musgo, chanfro e sombra pela luz, algumas lajes faltando com terra no lugar. Prós: a mais forte das 18. Lê como calçada antiga em qualquer distância. Contras: nenhum que eu tenha visto.
- **C, lajes molhadas com folhas:** B mais escuro, água nas juntas, poças roxas do céu, folhas sopradas. Prós: clima. Contras: as folhas laranja brigam um pouco com a paleta fria.
- **Recomendo B.**

### Ato 3, abismo (cinza e brasa)
- **A, trilha de cinza:** cinza com rachaduras finas, parte delas com brasa, carvões. Prós: orgânica. Contras: a rede de rachaduras laranja fica densa no fundo.
- **B, basalto com brasa:** lajes poligonais de basalto (colunas vistas de cima) com brasa em parte das juntas, chanfro e rachaduras. Prós: muito legível, identidade forte. Contras: brilha mais que a estrada atual; pode competir com o inimigo.
- **C, cinza soprada com brasas:** B com placas de cinza por cima das lajes, cinza correndo pelo vento e brasas pulsando na luz. Prós: B com o brilho mais contido. Contras: a cinza parada lê um pouco como mancha.
- **Recomendo C.**

### Ato 4, gelo (neve)
- **A, neve pisada:** neve cinza-azulada no centro, pegadas de bota, sulcos rasos, borda fofa mais clara. Prós: acaba com o "asfalto". Contras: o contraste com o campo de neve é baixo, a estrada some um pouco.
- **B, neve compactada com trilho de trenó:** dois trilhos finos de trenó, cascos no meio, pedras enterradas aparecendo com chapéu de neve. Prós: a ideia mais clara do ato. Contras: o mesmo contraste baixo de A.
- **C, neve soprada e gelo:** A com placas de gelo que cintilam e neve correndo de lado. Prós: o vento ajuda a ler o chão. Contras: as placas de gelo pontilhadas parecem ruído no fundo.
- **Recomendo B**, escurecendo um pouco a faixa pisada se você escolher.

### Ato 5, pântano (lama)
- **A, lama com sulcos:** lama com montinhos secos, sulcos cheios d'água, raízes cruzando. Prós: natural. Contras: escura, a estrada quase some na grama alta.
- **B, passarela de tábuas:** tábuas atravessadas com pregos, veio, tábuas quebradas ou faltando e lama com água por baixo e dos lados. Prós: a mais diferente e a mais legível do ato. Contras: as tábuas continuam pelos ramos da encruzilhada (passarela que se divide em três).
- **C, lama com água e juncos:** A com poças maiores com o céu e ondulação, juncos na borda. Prós: clima de brejo. Contras: escura como A.
- **Recomendo B.**

### Ato 6, crepúsculo (estrada antiga)
- **A, trilha de folhas:** terra quente com sulcos e folhas caídas nas cores do outono. Prós: combina com o pôr do sol. Contras: as folhas são miúdas e viram pontilhado no fundo.
- **B, estrada antiga com musgo:** calçamento de pedra em fiadas desencontradas, juntas com musgo, pedras quebradas, faltando ou rachadas. Prós: conta história ("estrada de um reino que caiu"). Contras: perto da câmera lembra um pouco parede de tijolo.
- **C, folhas sopradas e poças:** B com poças douradas nos buracos e folhas sopradas pelo vento. Prós: a mais bonita do ato no 0,85. Contras: mais coisa mexendo na tela.
- **Recomendo C.**

## Desempenho (1920x1080, 60 quadros por medida, `lovec . test_one perf_estrada_variantes`)

Orçamento do `test_perf_budget`: 600 draw calls, 40 KB alocados por quadro. Nenhuma variante passa disso. O decalque usa um atlas só (um lote), e o tile novo é uma textura de 384x640 por bioma (~1 MB), assada na hora em que a variante é ligada (atraso de uma fração de segundo na troca, só no DEV).

| ato | atual | A | B | C |
|---|---|---|---|---|
| 1 | 515 dc, 18 KB | 513, 15 | 523, 15 | 544, 15 |
| 2 | 547, 16 | 547, 16 | 545, 15 | 525, 22 |
| 3 | 547, 15 | 548, 13 | 568, 13 | 577, 12 |
| 4 | 549, 14 | 536, 15 | 512, 13 | 521, 13 |
| 5 | 582, 48* | 545, 16 | 564, 15 | 561, 18 |
| 6 | 571, 17 | 568, 18 | 544, 16 | 521, 17 |

\* pico isolado da coleta de lixo na estrada atual; o `test_perf_budget` passa. O tempo por quadro andando ficou entre 23 e 33 ms para todas, incluindo a atual. Na janela escondida isso é ruído, não dá para comparar.

## Testes com a estrada padrão (verdes)

`test_road_edge_rhythm`, `test_fork_branch_width`, `test_castle_light`, `test_scene_continuity`, `test_perf_budget`, `test_no_comments_no_prints`, `test_toast_audit`.

## O que ainda não está bom

- No ato 4 a estrada tem pouco contraste com o campo de neve em A, B e C.
- Nos atos 5 (A e C) e 3 (A) a estrada fica escura e lê pouco contra o chão ao lado.
- O meio-fio do ato 1 B é feito de retângulos por fileira: perto da câmera lê como pedra, longe vira tracejado.
- As poças ainda usam uma cor fixa de céu por bioma, não o céu real da hora do dia.
- Escolhida a variante, o certo é virar padrão por bioma (uma tabela no lugar da chave global), apagar as outras e reconferir a borda e a continuidade com ela.

## Como refazer

```
CARDGAME_HEADLESS=1 lovec . test_one screenshot_estrada_variantes "1,2,3,4,5,6:atual,A,B,C:fork,battle"
ESTRADA_TOD=0.85 CARDGAME_HEADLESS=1 lovec . test_one screenshot_estrada_variantes
python tools/estrada_variantes_folha.py sheet tod65
python tools/estrada_variantes_folha.py sheet tod85
```
