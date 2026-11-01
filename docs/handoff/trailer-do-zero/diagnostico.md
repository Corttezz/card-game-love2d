# Etapa 1: diagnóstico (trailer-do-zero)

_Diretora, 01/11/2026. **Revisado após `revisao-diagnostico.md` (ver `resposta-diagnostico.md` e a seção 6).** Todas as versões vistas por folha de quadros (1 quadro/s; v3 a v5 a cada 2 s; A a cada 0,5 s), forma de onda, loudness EBU R128 (integrado, LRA e curva de curto prazo por segundo) e contagem de cortes (`select='gt(scene,0.3)'`, aproximada: não pega chicote com desfoque). Script e imagens: `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\7f9e50b0-2a53-4549-9447-d15442060f00\scratchpad\diag\` (`analyze.py`, `sheet_*.jpg`, `wave_*.png`, `metrics.json`)._

## 1. Medições

| versão | arquivo analisado | duração | LUFS I | LRA | cortes detectados | quadro 0 |
|---|---|---|---|---|---|---|
| v3 | `grimoire_trailer_v3_review.mp4` | 109,2 s | −12,6 | 5,8 | 32 | computador bege (intro do jogo), sem jogo |
| v4 | `..._v4_review.mp4` | 114,5 s | −11,6 | 6,2 | 23 | preto + linha da TV |
| v5 | `..._v5_review.mp4` | 114,5 s | −12,7 | 11,6 | 27 | preto |
| v6 | `..._v6_review.mp4` | 79,7 s | −12,3 | 5,0 | 14 | preto |
| v7 | `..._v7_review.mp4` | 58,0 s | −12,3 | 7,6 | 13 | preto |
| v8 | `..._v8_review.mp4` | 62,1 s | −12,5 | 6,5 | 21 | preto |
| A | `grimoire_kinetic_hook30_1080p.mp4` | 32,3 s | −13,9 | 4,0 | 10 | preto |
| B | `grimoire_kinetic_new_1080p.mp4` | 65,3 s | −14,3 | 6,8 | 9 | combate (plano aberto) |
| C | `grimoire_trailer_v9_kinetic_1080p.mp4` | 64,5 s | −14,4 | 6,6 | 9 | preto + linha da TV |
| A_som | `..._hook30_som_720p.mp4` | 32,3 s | −14,1 | 6,1 | (= A) | (= A) |
| B_som | `..._new_som_720p.mp4` | 65,3 s | −14,1 | 7,9 | (= B) | (= B) |
| C_som | `..._v9_kinetic_som_720p.mp4` | 64,5 s | −14,1 | 7,1 | (= C) | (= C) |

**O número que explica o "muito ruim" no som:** no B_som, o trecho "sem música" da entrada do chefe (32,6 a 37,4 s) mede −16 a −18 LUFS de curto prazo; o resto do filme fica entre −12 e −15. A "pausa" (30 a 37 s: −15 a −19 LUFS) fica só **5 a 9 dB** abaixo do trecho anterior (28 a 29 s: −11 a −12), porque o ronco, os corvos e o salão a preenchem quase no nível da música. O "drop" que vem depois (37,4 s) chega a −12, igual ao começo do filme. Não existe pico: o ponto mais alto de B_som (−10 LUFS a 42 s) fica só 2 dB acima da média. LRA de 4 a 8 LU em todas as versões = parede de som do começo ao fim. No C_som o padrão é igual (pausa a −19/−20 em 29 a 30 s; resto −9 a −16).

## 2. O que não funciona (por critério)

### Leitura das cartas: o defeito principal
- Em **A, B, C, v7 e v8** todo o gameplay é o **plano aberto da tela do jogo, dentro da moldura do CRT**. A carta na mão ocupa cerca de 4% da largura do quadro (~70 px num 1080p) e a ilustração dela ~35 px: não se lê o nome, o custo, o número nem a arte. Num celular ou no autoplay da Steam (vídeo pequeno), a carta vira um retângulo bege.
- A tipografia cinética cai **em cima** da mão ("BUILD A LIVING DECK", "PLAY.", "BREAK.") e cobre a única coisa que o texto pretende mostrar.
- O jogo vende "cartas vivas" (toda carta animada, regra do dono) e **nenhum quadro de A, B ou C mostra uma carta grande o bastante para se ver que ela se mexe**. As únicas versões em que a carta se lê são **v3** (escolha do pacote, cartas a ~1/3 da altura), **v4** e **v6** (Coleção em close: Meteor Strike, Demon Fang, Bloodletting, Poção de Cura). Essas são as cenas que vendem o gênero e foram cortadas a partir do v7.

### Clareza do gameplay
- Nenhuma versão mostra a cadeia **causa → efeito** de forma legível: escolher carta → JOGAR → carta voa → número grande → barra do inimigo cai → inimigo morre. Os números de dano (42, 33, 27) e o "COMBO! Volley +15" aparecem, mas pequenos (cerca de 20 px de altura no 1080p).
- Recursos únicos do Grimoire nunca explicados nem mostrados de perto: **prévia de dano / LETAL**, **coringas** que ticam, **mecânica-assinatura de cada chefe** (runas do Lich, correntes do Tirano, geada, raízes, ciclo da lua, corvos), **forja**, **loja do mercador**, **mundo-domo** em que o inimigo surge pela curva.
- "EVERY BOSS IS A PUZZLE." aparece sobre **salões vazios** (B 38 a 46 s; C 26 a 39 s: 13 s de salão sem chefe, sem carta, sem regra). A promessa do texto não tem prova na imagem.

### Gancho
- **Quadro 0 preto** em A, C, v4 a v8 (C: linha da TV no preto). A Steam usa o 1º quadro como pôster do loop e corta 6 trechos de 1 s para o microtrailer: preto é desperdício nos dois.
- Os 2 primeiros segundos de B e A são o **plano aberto do combate**, sem nada se mexer de importante: não diz "isto é um deckbuilder diferente". Não há um momento "uau" antes de 5 s.
- Os textos são genéricos do gênero (SIX ACTS / ONE ROAD / EVERY BOSS IS A PUZZLE / YOUR CARDS DECIDE WHAT SURVIVES): servem a qualquer roguelike. Nada diz por que este jogo é este jogo.

### Ritmo
- A, B e C trocam de **ideia** a cada ~2 s, mas a **imagem** fica parada: os atos são cartões-postais estáticos da estrada (B 11 a 20 s, C 1 a 6 s e 22 a 26 s) com chicote entre eles. Sensação de proteção de tela com legenda, não de jogo.
- A câmera nunca entra no jogo (sem zoom na mão, sem close no inimigo, sem acompanhar a carta voando). Todo o movimento vem de transição, não do conteúdo.
- v3 a v5 (110 s) são longos demais e têm 3 a 5 telas pretas de citação (incluindo "PLACEHOLDER QUOTE" visível no v3 e "PLACEHOLDER: PRESS/PLAYTESTER" no v6).

### Emoção
- O único trecho com tensão de verdade, em **todas** as versões, é a **entrada do Rei-Carniça**: escuro, olhos, rasantes de corvo, pouso, cartão do nome. Mas dura ~5 s, acontece no plano aberto e o chefe ocupa pouco do quadro.
- Não há jogador em perigo nem vitória contada: ninguém quase morre, nenhuma jogada vira a luta. Sem risco, não há alívio.
- Os 6 chefes (v3/v4 mostravam cinco com nome e epíteto, como "WINTER MONARCH / Crown of the Endless Blizzard") viraram salões vazios em A/B/C. Os chefes são a arte mais forte do jogo e sumiram.

### Som
- Parede de música do começo ao fim (LRA 4 a 8). Os remixes `_som` colocaram o som do jogo, mas a música abaixa só 6 a 8 dB, e as "pausas" seguem cheias de ambiente quase no mesmo nível (seção 1). O ouvido não percebe a música sair.
- Nenhum som do jogo é **solo**: o clique do JOGAR, a carta batendo e a voz do monstro sempre dividem o espaço com a trilha. O som que mais vende um deckbuilder (carta sendo jogada → impacto) nunca fica sozinho.
- O drop da faixa e o pico visual não coincidem com um **evento** de jogo (golpe letal, chefe morrendo). O pico da imagem em B (42 de dano a 52 s = 80%) tem o mesmo nível de som que a introdução.
- Final: 8 s de logo sobre o roxo escuro com a música continuando; nenhum ponto final sonoro.

### Texto
- Caixa alta pixel com contorno: legível, cara do jogo (bom). Mas: (1) cobre a imagem que deveria comprovar o texto; (2) frases de 3 linhas que ficam menos tempo que a regra de 1 s/13 caracteres em "YOUR CARDS / DECIDE / WHAT SURVIVES." (B: ~3 s entre entrar e sair, com a dissolução no meio); (3) repetido demais: "EVERY BOSS IS A PUZZLE" em 5 a 8 s seguidos.
- Falta a linha de gênero que v3 tinha ("A ROGUELIKE DECKBUILDER").

### Final
- Bússola + GRIMOIRE + WISHLIST ON STEAM, ~8 a 10 s sobre fundo vazio (B 56 a 65 s; C 56 a 64 s). Bom: o selo e a letra pixel são da marca. Ruim: nenhuma imagem do jogo, nenhum ponto alto antes, nenhuma linha de gênero, e a bússola girando em cima do preto por 3 s antes do nome (mais preto para o microtrailer).

## 3. O que funciona e deve ser aproveitado

| o quê | de onde | por quê |
|---|---|---|
| Entrada do Rei-Carniça (olhos no escuro → corvos → pouso → cartão do nome) | todas; melhor tomada em `boss_carrion`/`boss8` | é a única sequência com suspense; som do jogo forte (corvos, pouso, revelação) |
| Cartões de nome de chefe com epíteto | v3, v4 | mostram elenco e escala do jogo em 1 s cada |
| Coleção em close (carta grande, animada, com texto) | v4, v6 ("137 LIVING CARDS", número **desatualizado**) | é onde a carta viva se lê; o número concreto hoje é 145 (seção 6.1) |
| Escolha do pacote / espólio com cartas grandes | v3, v4, B (9 a 10 s) | carta grande + raridade + brilho de achado raro |
| Bestiário: criatura surgindo no ato dela, com nome | v3 (A BESTIARY OF THE CURSED), v4 | variedade de inimigos e biomas com propósito, em vez de estrada vazia |
| Fileira de coringas / COMBO! | v3, v8, B | aparece o "número sobe" do gênero |
| TV ligando com o jogo no vidro (pedido 1 do Daniel) | C, v8 | identidade CRT; tem de durar < 1 s e já com imagem |
| Tipografia pixel com contorno e dissolução em runa | A/B/C | aprovada, cara do jogo; o problema é onde e quanto |
| Final com selo + letras | B, C | marca correta; precisa de linha de gênero e de ser mais curto |
| Motor de remix por `audio.jsonl` | `trailer-revisao-som/remix_engine.py` | coloca o som real do jogo no quadro certo: reaproveitar inteiro |
| Faixas ACE-Step do Rei-Carniça e do Tirano | `audio/music/boss-*.mp3` | séria, ligada ao bioma, aprovada; o problema era a mixagem |

## 4. Referências do gênero: o que prende

Medições de 29/10 em `docs/handoff/trailer-kinetic-referencias.md` (8 trailers, link e duração). Novo nesta etapa: o que, especificamente, cada um faz que nós não fazemos.

| trailer | o que prende | o que nos falta |
|---|---|---|
| **Slay the Spire** (launch, 96 s) | a carta em **close** faz o papel do cartão de texto ("Channel Lightning" grande); 1º corte a 3,6 s já é combate com a mão | carta grande e legível; plano de 3 a 4 s para ler |
| **Balatro** (launch, 68 s) | personagem com voz (Jimbo fala em balões); o **número sobe** em cascata (fichas × mult, cada passo visível, ref. [UX de Balatro](https://blakecrosley.com/es/guides/design/balatro)); rajadas de corte só nos picos | escalada visível; uma "voz" (temos o corvo Pena, narrador do tutorial) |
| **Inscryption** (launch, 60 s) | clima: escuro, olhos, um texto curto; mistério antes do jogo | já temos o escuro + olhos do Rei-Carniça: é a nossa cena mais próxima; usar como tal |
| **Monster Train** (release, 59 s) | gameplay com explosão em 1,6 s; citação real de imprensa | algo grande acontecendo antes de 2 s |
| **Vampire Survivors** (launch, 63 s) | **números enormes** (120.000 / 0 VAMPIRES) sobre o jogo borrado, com humor | um número enorme verdadeiro, recontado no código (seção 6.1): 145 cartas, 42 criaturas, 6 chefes |
| **Cobalt Core / Dicey Dungeons** | o texto **é** a UI do jogo (carta FIREBALL); arte-chave + gênero no fim | o nosso texto deveria sair das próprias cartas/UI |
| **Luck be a Landlord** | humor na UI; logo pixel gigante | — |

Padrões que se repetem (somados às regras da Steam já levantadas: gameplay em 2 a 5 s, impressão em < 10 s, mudo no autoplay, microtrailer de 6 × 1 s, quadro 0 vira pôster):
1. **A ação principal do jogo legível nos primeiros segundos**, com a câmera perto o bastante para ler. Num deckbuilder isso é a carta ([SteamPageAnalyzer, deckbuilders](https://www.steampageanalyzer.com/optimize/deckbuilder): "cards are small objects on screen... text and art can become illegible").
2. **Escalada**: o jogo fica maior (inimigo maior, número maior, chefe) até o pico, que é um evento de jogo, não só a música.
3. **O gancho mostrado 2 a 3 vezes** (Derek Lieu, regra dos três), não 8 ideias genéricas.
4. **Contraste de som**: a música para de verdade ("dropping everything out for a beat makes the next impact feel enormous", [IRPR, trailer sound design](https://sounddesign.irpr.agency/guides/guide-to-trailer-sound-design/); "music that never stops becomes wallpaper", [Bugnet](https://bugnet.io/blog/the-case-for-silence-in-game-audio)). Na prática: meio segundo de quase nada (≥ 15 dB abaixo) antes do impacto. Derek Lieu: "do audio first" ([PC Gamer](https://www.pcgamer.com/the-art-of-making-effective-game-trailers)).
5. **Personalidade**: cada um tem uma voz (Jimbo, Leshy, humor do senhorio). O nosso tem texto genérico em inglês.
6. **Fecho curto** (6 a 10 s) com gênero + CTA, de preferência com imagem do jogo.

## 5. Conclusão: por que os trailers estão ruins

1. **Ninguém consegue ver as cartas.** Num jogo de cartas vivas, o trailer nunca mostra uma carta de perto. É o defeito nº 1, e as primeiras versões (v3, v4, v6) já tinham resolvido isso com a Coleção e o pacote.
2. **Paisagem com legenda no lugar de jogo.** Metade do tempo de A/B/C é estrada vazia ou salão vazio com texto genérico.
3. **O som é uma parede.** Pausas a 3 a 5 dB da música não são pausas; não há pico nem ponto final; nenhum som do jogo soa sozinho.
4. **Não há história de uma luta**: sem perigo, sem virada, sem golpe final que importe.
5. **Os chefes, o melhor do jogo, viraram cenário.**

**Direção para o roteiro (a validar na etapa 3):** câmera **dentro** do jogo (closes por recorte de captura 4K ou captura headless com zoom), carta em primeiro plano, uma luta contada do começo ao golpe letal, chefes com corpo e nome, a música saindo de verdade (−20 dB ou silêncio) nos 2 momentos certos, texto saindo da UI do jogo ou de números verdadeiros, e quadro 0 já com uma carta viva.

## 6. Decisões tomadas depois da revisão (entram no roteiro como regra)

### 6.1 Número na tela = número contado no código
Nenhum número vai para a tela sem a contagem registrada aqui e refeita antes do corte final.

| número | valor | comando (raiz do repo) |
|---|---|---|
| cartas | **145** (139 sem os 6 coringas de chefe) | `for f in src/data/cards/*.lua; do grep -cE '^\s*id\s*=' $f; done` → basic 27, boss 6, mage 42, rogue 37, warrior 33 |
| criaturas | **42** (roster único; 43 kits contam um kit genérico) | `lua -e 'local E=dofile("src/data/enemies.lua") ...'` (contagem de ids únicos em `E.ROSTER`); bate com as 42 pastas de `audio/sfx/enemies/` |
| atos / chefes | **6 / 6** | `Config.TotalActs = 6` (`src/core/Config.lua:141`) |

### 6.2 Meta de silêncio
Pausa de música = **≥ 15 dB abaixo do trecho anterior**, medida em loudness de curto prazo (janela de 3 s, EBU R128), e o impacto seguinte volta ao nível do trecho anterior ou acima. No B_som a pausa ficou 5 a 9 dB abaixo: reprovada por essa régua.

### 6.3 TV antes da música (pedido 1 do Daniel) e carta viva no quadro 0
O filme começa **no meio** do liga-TV do CRT: o quadro 0 já mostra o vidro aberto ~60% com a carta viva dentro (nunca preto, nunca só a linha). A TV termina de abrir em ≤ 0,8 s com o som de ligar do jogo (`boot-tv-power-on`) sozinho; a música entra depois, no 1º grave após a TV abrir. Os dois pedidos ficam atendidos: a TV liga antes da música e o pôster/microtrailer nunca pega preto.

### 6.4 Salões de IA (Higgsfield): fora do corte 1, decisão do Daniel
O corte 1 usa só os `castle_hall_*` **reais do jogo, com o chefe dentro** (captura headless). Os salões de IA (`ai_4k/hall1..5`) não entram; se o Daniel quiser manter o pedido 9 do v7 ("salões nos acentos"), eles voltam só como ponte de ≤ 1 s, re-pixelizada e declarada. **Pendência registrada para o Daniel** na Entrega.

### 6.5 Gancho, em uma frase
**"Cada chefe quebra as regras da luta, e o seu baralho vivo é o que quebra de volta."**
Mostrado 3 vezes, sempre com a regra visível na imagem: (1) corvos do Rei-Carniça; (2) Geada do Monarca congelando as cartas na mão (a mecânica aparece **na própria carta**, que liga chefe e carta viva); (3) correntes do Tirano rompendo, ou runas do Lich. Carta viva é a textura do filme inteiro, não um segundo gancho.

### 6.6 Alvo do corte 1
**1º vídeo da página da Steam, 60 a 70 s**, gameplay com HUD antes de 2 s, legível mudo. O de 30 s sai depois como recorte deste.

### 6.7 Como sai uma carta legível em escala inteira (dependência para `ferramentas.md`)
Medido: as tomadas atuais são **1920×1080** (`boss8/00001.tga`), com o CRT **embutido**; a carta na mão tem ~128×192 px (96×144 lógicos × 1,333), e a mão e o HUD ainda não escalam com a resolução (`UiScale` só cobre telas de UI), então **capturar em 4K não aumenta a carta**. O gravador (`tools/trailer_record.lua` do worktree) já aceita `TRAILER_SIZE=WxH`, `TRAILER_CRT=0` e `TRAILER_NOBEZEL=1`. Caminho escolhido, a validar na etapa 2:
- capturar **sem CRT** (`TRAILER_CRT=0`) a 1920×1080, recortar uma janela de **960×540** (×2) ou **640×360** (×3) em volta da mão / do inimigo / do chefe e ampliar por **vizinho mais próximo** em fator inteiro → carta com 384 px (×2, 36% da altura) ou 576 px (×3, 53%); o recorte pode andar entre quadros (câmera virtual) em passos de pixel inteiro da captura;
- aplicar o CRT **depois**, por cima do quadro final (scanline na escala do filme, não ampliado);
- Coleção / inspeção de carta para o close máximo da carta parada.
Dono: diretora, etapa 2 (`ferramentas.md`), com teste de recorte em 1 tomada antes do roteiro.

### 6.8 Luta encenada (dependência para `ferramentas.md`)
"A história de uma luta" (perigo, virada, golpe LETAL) exige captura roteirizada no modo cheat (vida baixa, mão escolhida, LETAL na prévia, chefe com a mecânica ativa). Entra como item da etapa 2, com o que o `trailer_record.lua` já oferece e o que falta.

### 6.9 Microtrailer simulado (6 fatias de 1 s, frações 0,33/0,43/0,53/0,67/0,77/0,87 do relato do r/gamedev)
Imagem: `scratchpad\diag\micro_ABC.png`.

| | fatia 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| A (11/14/18/22/25/28 s) | grifo + texto | serpente na neve | estrada vazia | salão IA + texto dissolvendo | combate plano aberto | bússola no escuro |
| B (22/29/35/44/51/57 s) | grifo + texto | BEND EVERY HAND (estrada) | salão escuro | salão IA vazio | combate plano aberto | bússola no escuro |
| C (22/28/35/44/50/56 s) | serpente + texto | salão IA com runas | salão IA de gelo | salão escuro (olhos) | combate plano aberto | bússola no escuro |

18 fatias: **0** com carta legível; 3 de combate (carta ilegível); 4 com criatura (3 delas cobertas por texto); 6 de salão ou estrada sem ação; 2 de salão escuro; 3 de bússola no escuro. Reforça as conclusões 1 e 2. Regra para o corte novo: entre 30% e 90% da duração, **todo segundo** tem carta grande ou criatura em ação; nada de logo antes de 90%.
