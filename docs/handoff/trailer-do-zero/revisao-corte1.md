# Revisão: etapa 4, corte 1 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte1.md` (15:41) e os vídeos `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte1_1080p.mp4` (1920×1080, 60 fps, 68,50 s, 15 Mb/s) e `..._720p.mp4` (1280×720, 60 fps, 6,1 Mb/s). O que fiz: folha de quadros a 2 quadros/s do filme inteiro; quadros em resolução cheia em 20 instantes; folhas a 3-4 quadros/s da cascata, da Revoada, das correntes e do final; movimento quadro a quadro dos planos de estrada; luma por plano; distância de cada clipe e texto ao grave (`corte/edl.py` × `boss-abyss_tyrant_beats.json`, deslocamento 1,60 s); EBU R128 por segundo (curto prazo e momentâneo) nos dois arquivos; leitura do `mix_sources.json` (399 eventos). Script: `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\medir.py`; medidas e imagens em `...\scratchpad\rev\c1_1080\` e `...\rev\fr\`. Não ouvi o áudio: o som foi avaliado por medida e pela lista de eventos. A escuta humana continua obrigatória, como a diretora disse._

## Rodada 1, NÃO APROVADO

É de longe o melhor trailer que o projeto já teve, e o salto em relação a A/B/C é real. A carta a ×2 é linda e se lê de verdade (4,5 s: Backstab, Storm of Steel, Dirty Blade e Poison Dart com nome, arte e ATTACK 8/10/4/2). A sincronia está perfeita: **26 dos 27 clipes e os 7 textos começam a 0,0 quadro de um grave medido**; os únicos fora são o quadro 0, o salão IA e o escuro do silêncio, todos declarados. A entrada do Rei (28,0 s: pouso com a órbita de corvos e o anel de revelação) é um plano de pôster. O logo está bonito e legível (GRIMOIRE grande, A ROGUELIKE DECKBUILDER e WISHLIST ON STEAM a cerca de 30 px de glifo, sobre o salão escurecido). Loudness −14,1 LUFS, −1,2 dBTP e LRA 9,2 (era 4 a 8) nos dois arquivos. Zero rajadas. O 720p é a mesma coisa reduzida, com a mesma medida de som.

O que impede o ≥ 9 é que **as três coisas que o filme existe para provar ficam escondidas**: a cascata cobre o inimigo, a Revoada não se vê e as correntes ficam sob a legenda. E o golpe LETAL acontece atrás das cartas. Há também três defeitos de som que o Daniel já reclamou antes (sons duplicados e clima de fora dentro do salão).

### Problemas, com timestamp

**Imagem e leitura**
1. **0,00 s, quadro 0 = pôster da Steam: reprovado.** A faixa da TV está a cerca de 35% e coberta de ruído do liga-TV; cerca de 65% do vidro é preto (folha `fr/f_0.0.png`). Esse quadro vira o pôster do vídeo na loja. A própria diretora apontou isso: começar com a faixa ≥ 60% e o ruído já baixo (`TV_SKIP` maior). Critério: quadro 0 com < 30% do vidro em preto e as cartas legíveis.
2. **3,07–6,62 s, cascata: o inimigo e os números estão atrás da mão.** O recorte ×2 [480,120] enquadra as 4 cartas em repouso e o Espantalho fica escondido atrás delas (`fr/cascata.png`). O "3" de dano e a barra aparecem pequenos entre as cartas, e as cartas não voam. O que se vê são cartas tremendo e, depois, o banner COMBO! Volley +18. A escalada que o roteiro prometeu ("cada número sobe, a barra cai em degraus") não aparece. **Exijo** um enquadramento ×2 do Espantalho + barra + números por cima das cartas (o recorte sobe uns 300 px de captura; a mão pode sair por baixo), ou ×1 enquanto as cartas voam e ×2 no inimigo no 2º e 3º impacto.
3. **6,62–8,95 s, "145 LIVING CARDS.":** fica sobre um plano ×1 em que as cartas são minúsculas (só duas na mão, cortadas embaixo) e **colide com a carta Poison Dart em voo** (o "11" e a borda da carta encostam no "S." final; `fr/f_7.5.png`). O texto fala de cartas sobre o único plano em que elas não se veem. Pelo roteiro, era sobre a mão sendo dada a ×2. Mover para um plano ×2 da mão ou da carta parada, e nunca encostar em carta.
4. **7,5 s, "40/40 LETHAL" já aparece contra o Espantalho.** Isso gasta o LETHAL do clímax (55 s) no 7º segundo. Não é erro de jogo, mas tira a novidade do pico. Esconda o painel nesse plano ou use uma jogada que não seja letal.
5. **33,24–37,49 s, prova 1 (Revoada): ilegível.** Os 4,25 s a ×1 (`fr/revoada.png`) mostram o Rei parado no trono, "ENEMY TURN", o nome do golpe pequeno e um "Weak" minúsculo embaixo à esquerda. Os corvos que mergulham no painel do herói têm poucos pixels e não se distinguem. Sem som, ninguém entende que o chefe quebrou uma regra. É o 1º terço do gancho e o trecho de 48 a 55% do filme, onde a atenção cai. **Exijo** um ×2 entre o Rei e o painel do herói (ou dois planos: ×2 na órbita com o contador de corvos, ×2 no painel recebendo os mergulhos e a vida caindo), e duração ≤ 3 s.
6. **41,78–44,64 s, prova 2 (correntes): a legenda cobre a prova.** "BREAK HIS CHAINS." está em y=870, **sobre as cartas e sobre o texto do próprio jogo** ("Half strike / Chain snapped… damage"), que é justamente a explicação da regra (`fr/correntes.png`). O Tirano também sai cortado no alto do recorte (só os chifres e o topo do rosto) e as cartas sobem na frente dele. O intent 20 → 10 se lê, e isso é bom. **Exijo** a legenda no terço superior (ou nenhuma: o "Chain snapped" do jogo já é o texto), o recorte deslocado para pegar o rosto do Tirano + a barra com as marcas + o intent, e o mesmo enquadramento antes e depois do rompimento.
7. **55,84–56,6 s, golpe LETAL: o impacto acontece atrás das cartas.** No quadro do golpe (`fr/f_56.2.png`) as cartas Twin Strike e Iron Wave cobrem o Rei, o banner COMBO! cobre a barra dele e o número é um "27" vermelho sobre a carta. O "número enorme, a barra zera" do roteiro não aparece. Depois, a morte é um plano ×1 dessaturado com o Rei pequeno no centro (57–59,5 s). O pico de som existe (+2,3 dB), mas a imagem não dá o pico. **Exijo** o quadro do hit-stop com o Rei visível e a barra indo a zero (fim do voo das cartas, ou ×2 no Rei + barra com as cartas já dissolvidas) e a morte com o Rei maior (×2 no corpo caindo, ou ×1 só nos 1,5 s finais).
8. **52,08–55,84 s:** no ×2 do LETAL [900,480] o Rei fica cortado ao meio na borda esquerda. Ou ele entra inteiro, ou sai do quadro: corte pela metade lê como erro de enquadramento.

**Continuidade**
9. **Clima de fora dentro do salão.** Grilos e vento da estrada continuam no salão escuro (23,6 s, −34 dB) e **sobem a −26 dB no cartão do nome (28,33 s)**. É o mesmo defeito que a revisão de som de 01/11 corrigiu no B ("grilos dentro do salão escuro"). O clima externo tem de morrer no corte para o salão IA (22,6 s).
10. **O portão abre duas vezes.** `castleGateOpen` a 20,35 s (−4,2 dB, certo, no plano da porta) e **de novo a 23,6 s** (−14,2 dB), no início do `k_escuro`, porque o clipe reaproveita o evento da tomada. No silêncio, um segundo rangido de portão já com o salão fechado.
11. **O pouso bate duas vezes.** `bossLandImpact` a 27,73 s (−1,9) e **de novo a 28,33 s** (+0,1), junto com `crowFlock2`, `bossFeathersSettle` e `bossRevealSting` repetidos no início do `k_nome`. São dois pousos com 0,6 s de distância. Para o Daniel isso é o "war war duas vezes" dos corvos de 17/10, que ele chamou de irritante.
12. **Montagem "6 ACTS.":** mostra os atos 2, 3, 4 e 6; o ato 5 sumiu (E5 saiu do corte). Com o texto "6 ACTS." na tela, a contagem visível é de 5 biomas (1 a 4 + 6). Ou o E5 volta (0,9 s, a rajada já prevista), ou isso fica assumido. Recomendo voltar.
13. **0 a 0,9 s:** o liga-TV não está "sozinho" como o roteiro pediu. Junto com ele tocam grilos, vento ×4, `hoverCard` e `cardSelect`. Deixe só o liga-TV até a música entrar.

**Som (por medida)**
14. **Empilhamento:** `comboTrigger` ×4 no mesmo instante a 56,37 s (−3 dB cada) e duplicados a 7,57, 32,26, 42,31 e 55,23 s; `hoverCard` duplicado a 0, 2,07, 41,78, 52,08 e 53,23 s. Som idêntico sobreposto no mesmo quadro soma volume e dá fase/flange. Um evento por código por instante.
15. **Silêncio:** o leito está certo (só o ambiente, de −32 a −45, e zero música). Mas no mix o curto prazo só fica em −24/−25 de 25 a 26 s; em 23 a 24 s o 2º portão (item 10) e os olhos seguram −17/−19, e a 27 s os rasantes já levam a −20. O silêncio percebido dura uns 2 s. Com os itens 9 e 10 resolvidos ele dobra, sem mexer em nada mais.

### O que está excelente (não mexer)
- Carta a ×2 em escala inteira (4,5 s), o HUD a 2,07 s, a revelação do coringa raro no espólio (10–11,8 s).
- Sincronia (0 quadro em 26 cortes) e textos dentro dos planos.
- O silêncio no escuro com os olhos, os rasantes e o pouso do Rei (24–28 s, imagem), o cartão CARRION KING.
- A Geada (47,45–50,95 s): as cartas congeladas se leem na mão e o "FROST LOCKS YOUR HAND." fica sobre o Monarca, sem cobrir a mão. É o modelo para as outras duas provas.
- 42 CREATURES. sobre a serpente; os salões IA integrados (o de lava a 40,1 s é o mais saturado, mas fica dentro da regra).
- Coringa Carrion Crown subindo e virando o selo no mesmo giro; logo, fade e último som de carta.

## Notas por critério (rodada 1)

| critério | nota | por quê |
|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 7 | gameplay contínuo a 0,4 s e HUD a 2,07 s, mas o quadro 0 (pôster) é faixa de ruído com 65% de preto |
| C2 Sem preto | 8 | 0,54% de quadros pretos; o problema é o quadro 0 |
| C3 Sincronia | 10 | 26/27 clipes e 7/7 textos a 0,0 quadro do grave |
| C4 Legibilidade | 6 | cartas ótimas; cascata, Revoada, correntes e LETAL escondidos (itens 2, 5, 6, 7); texto colidindo com carta (3) |
| C5 Ritmo | 8 | 0 rajadas e planos de 1 a 4 s; 15,2–22,6 s (estrada até a porta) é longo para o pouco que acontece |
| C6 Pico | 7 | som certo (+2,3 dB no lugar certo); imagem do pico escondida atrás das cartas, morte pequena |
| C7 Regra de 3 | 7 | só a Geada prova a regra; a Revoada não se lê e as correntes ficam meio cobertas |
| C8 Fecho | 9 | coringa → selo → GRIMOIRE / gênero / WISHLIST, 6,4 s |
| C9 Conformidade | 9 | sem 4K, CRT do jogo em 100% após a TV, cenários válidos, −14,1 / −1,2, marca "não publicável" |
| C10 Checklist do Daniel | 8 | TV antes da música, porta audível, chefe inteiro, salões IA nos acentos, música contínua: ok; sons duplicados (itens 10, 11) repetem um defeito que ele já rejeitou |
| C11 Continuidade | 7 | ordem e estado corretos; grilos dentro do salão, portão e pouso duplicados, ato 5 faltando no "6 ACTS." |
| C12 Está bom / legal de assistir | 8 | o melhor trailer do projeto; perde nas três provas e no golpe final, que são a razão do filme |
| C13 Prende do início ao fim | 8 | abertura e entrada do Rei prendem; 15–22 s e a Revoada parada (33–37 s) são os dois pontos de abandono |
| C14 Som | 7 | contraste e pico medidos certos; duplicações, empilhamento e clima externo no salão |

**Status: NÃO APROVADO.** Para a rodada 2 exijo os itens 1, 2, 5, 6, 7, 9, 10, 11 e 14. Os itens 3, 4, 8, 12, 13 e 15 também devem ser resolvidos ou respondidos com motivo. Quase tudo é de montagem/mixagem (recorte, posição de legenda, filtro de eventos por clipe). Só os itens 5 e 7 podem pedir uma regravação curta da tomada `zero_carrion`, se o recorte da tomada atual não der. `===CORTE1_PRONTO===` não pode ser marcado.
