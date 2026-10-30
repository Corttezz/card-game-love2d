# Trailer kinetic: preparação (fase 1)

_30/10/2026. Frente `trailer-kinetic`, fase 1 = só preparação: nada renderizado com Kinetic Film, nenhum mp4 final, nenhum `lovec` rodado, jogo não aberto, 0 crédito. Base: `docs/handoff/trailer-kinetic.md` e `docs/handoff/trailer-kinetic-referencias.md`. Worktree dos insumos: `E:\dev\projects\card-game-trailer` (= R), branch `steam-store-v2` em `f68db8e5`._

Convenção das tabelas: **p** = segundo da faixa, **t** = segundo do trailer. Todo corte e toda entrada de texto marcados com "grave" caem EXATAMENTE num grave do `_beats.json` (Δ = 0,00 s, conferido por script); "drop" = drop do mesmo JSON. Onde a faixa não tem grave (pads), a tabela diz "sem grave" e o ponto é ancorado num acontecimento da imagem.

---

## 1. Beats medidos

Comando (o script grava ao lado do mp3; os JSON foram movidos para a pasta pedida):

```
cd E:\dev\projects\card-game-trailer
python tools/trailer_beats.py audio/music/boss-carrion_king.mp3
python tools/trailer_beats.py audio/music/boss-abyss_tyrant.mp3
→ build/trailer/music/boss-carrion_king_beats.json, build/trailer/music/boss-abyss_tyrant_beats.json
```

Detector = o mesmo do v8 (`music_cues.py`, banda 20 a 150 Hz, 100 quadros/s). BPM não vem do script: medido à parte por autocorrelação do envelope (resolução ±1,5 BPM) e conferido pelo intervalo entre graves. `build/` é ignorado pelo git: os JSON ficam só no disco.

### Rei-Carniça (`boss-carrion_king.mp3`)

| Medida | Valor |
|---|---|
| Duração | 95,09 s |
| BPM | **≈ 95,6** (autocorrelação 98 ± 1,6; grave a cada 2 tempos = 1,255 s, medido em 16,35→35,19 e 55,26→69,06) |
| Graves | 64 |
| Drops (JSON) | 4,73 · 55,07 · 70,01 · 89,73 |
| Pico | trecho 71 a 80 s (−12 a −14 dB, o mais alto sustentado); entrada do pico no drop **70,01** |

Graves: 0,03 · 1,30 · 2,53 · 4,72 · 5,05 · 6,29 · 7,55 · 10,05 · 11,33 · 12,56 · 14,83 · 15,10 · 15,64 (0,53) · 16,35 · 17,60 · 18,86 · 19,80 · 20,17 (0,71) · 21,35 · 22,62 · 23,88 · 24,82 · 26,38 · 27,64 · 28,91 · 30,15 · 31,41 · 32,67 · 32,98 · 33,93 · 35,19 · 55,26 (0,86) · 56,52 · 57,77 · 59,01 · 60,29 (0,85) · 61,54 · 62,78 · 64,04 · 64,99 · 66,55 · 67,79 · 69,06 · 70,01 · 71,58 (0,32) · 72,85 (0,61) · 74,23 (0,40) · 75,04 · 75,35 · 76,64 (0,42) · 77,87 · 79,12 (0,49) · 80,07 · 81,62 · 82,52 · 82,89 · 84,13 · 85,01 · 86,30 · 87,53 · 89,72 · 90,05 · 91,29 · 92,55 (força 1,00 quando não indicada).

Seções:

| p | Seção | Energia |
|---|---|---|
| 0 a 4,7 | intro (3 graves) | −20 dB |
| 4,73 a 35,19 | groove com grave a cada 1,255 s (falhas em 8,8 e 13,8) | −16 a −22, picos −13 em 20 e 25 |
| **35,19 a 55,07** | **queda: pad contínuo, ZERO grave e zero ataque em qualquer banda (20 s)** | −22 dB estável |
| 55,07 a 70,01 | volta do grave (drop), 1,255 s | −18 a −23 |
| **70,01 a 80** | **pico**: o mais alto, graves fracos (0,3 a 0,6) com 75,04/75,35/77,87/80,07 fortes | −12 a −14 |
| 80 a 89,7 | graves fortes de novo | −18 a −24 |
| 89,73 a 95,09 | drop final e fim | cai a −39 |

Consequência para o corte: a faixa é contínua (regra do Daniel), então qualquer trailer com ela atravessa os 20 s de pad. Isso vira o "a música para e volta" que o Daniel pediu no v4/v8: o pad é a porta e a espera, o drop 55,07 é o chefe.

### Tirano (`boss-abyss_tyrant.mp3`)

| Medida | Valor |
|---|---|
| Duração | 81,09 s |
| BPM | **≈ 105** (autocorrelação 105,3; graves em colcheias, mediana 0,28 s; rajadas a cada 4 compassos ≈ 9,1 s) |
| Graves | 154 |
| Drops (JSON) | 2,28 · **29,93** (1º drop depois da intro) · 57,36 · 79,96 |
| Pico | 58 a 72 s (rajadas a −8/−10 dB em 58, 63, 67, 72) |

Estrutura: rajadas de grave em 2,5–4,7 · 11,6–13,4 · 20,5–23,3 · 29,7–32,2 · 39,1–41,7 · 48,3–51,1 · 58,6–60,0 · 61–69,4 · 70,8–74,0; buracos quase sem grave em 4,7–6,5, 13,4–19,1 (só 15,41/16,21/16,80, fracos) e **23,4–29,7** (só 25,48). A lista completa dos 154 graves está no JSON.

---

## 2. Roteiros com tempos reais

### Frases: quem entra onde

| Frase | A (30 s, Tirano) | B (65 s, Rei-Carniça) | C (v9) | Por quê |
|---|---|---|---|---|
| PLAY. | sim | não | não | gancho de 1,5 s para redes: a jogada sem explicação; em B e C a jogada aparece inteira e dispensa |
| BREAK. | sim | não | não | par do PLAY. no 1º golpe com número; só faz sentido no corte curto |
| SIX ACTS. ONE ROAD TO THE CASTLE. | sim (2 linhas) | sim | sim | a promessa de estrutura; é o que diferencia de um deckbuilder genérico |
| BUILD A LIVING DECK. | não | sim | sim | em A o par PLAY./BREAK. ocupa o lugar dela; em 30 s não cabem as duas |
| EVERY CARD IS ALIVE. | não | sim | não | só B tem o plano de recompensa com carta rara viva; C mantém o desenho do v8 |
| YOUR CARDS DECIDE WHAT SURVIVES. | sim | sim | sim | liga cartas e criaturas; vai sobre as entradas nos três |
| BEND EVERY HAND. | não | sim | não | só B tem a loja/coringas; é a 3ª aparição do gancho "cartas" (regra de 3) |
| EVERY BOSS IS A PUZZLE. | sim | sim | sim | o gancho do chefe; nos três antes/durante os salões |
| WISHLIST ON STEAM. | sim | sim | sim | CTA único, no fim |

As duas frases entre aspas do v8 ("Two cards, one road…" / "The castle never moves…") não estão na lista aprovada desta fase: em C o trecho delas vira estrada/castelo sem texto (ver C).

Leitura conferida pela regra de 1 s a cada 13 caracteres, contado da entrada da última palavra até a saída.

### Conceito A: "Gancho 30 s" (Tirano, trecho do 1º drop)

Faixa de p = 13,38 até 42,7 (fade de 0,4 s). **t = p − 11,93**. Duração **30,7 s**. Pico (número enorme) em t = 24,61 → **80,2 %**.

| t | p | âncora | imagem | texto | SFX sintetizado |
|---|---|---|---|---|---|
| 0,00–1,45 | — | sem música | TV liga já com a mão do ladino no vidro (`deck8`) | — | `tv_on` em 0,00 |
| 1,45 | 13,38 | grave 1,00 | música entra seca; JOGAR | **PLAY.** | — |
| 3,48 | 15,41 | grave 0,60 | 1º golpe + número | **BREAK.** | `impact_1` |
| 4,28 / 4,87 | 16,21 / 16,80 | graves 0,68 / 0,54 | golpes 2 e 3 (onde o jogo os puser; ver nota) | — | `impact_2` |
| 7,18 | 19,11 | grave 0,95 | corte: encruzilhada, castelo ao centro (`fork_a2`) | **SIX ACTS.** | `whoosh_2` |
| 8,82 | 20,75 | grave 1,00 | corte: 2ª encruzilhada (`fork_a4`) | 2ª linha **ONE ROAD TO THE CASTLE.** (cartão inteiro 3,3 s) | `whoosh_2` |
| 10,51 | 22,44 | grave 1,00 | grifo (entrada desde o quadro 0) | **YOUR CARDS DECIDE** | `impact_2` no relâmpago |
| 11,19 | 23,12 | grave 1,00 | grifo continua | 2ª linha **WHAT SURVIVES.** (até 13,4) | — |
| 13,55 | 25,48 | grave 1,00 | serpente de gelo erguendo (buraco da faixa começa) | — | `whoosh_1` |
| 15,01 | (pad) | sem grave: 2,75 s antes do baque | porta do castelo abre (`boss8`) | — | `castle_door` em 15,01 |
| 17,76 | 29,69 | grave 1,00 | baque da porta, olhos no escuro, rasante (entrada a ~1,6x) | — | baque do `castle_door` (offset 2,75) |
| 18,00 | 29,93 | **drop** | Rei-Carniça pousa inteiro, cartão nome+epíteto do jogo | — | `impact_heavy` |
| 18,82 | 30,75 | grave 1,00 | salão 4K `hall1_carrion` | **EVERY BOSS** | `whoosh_2` |
| 19,73 | 31,66 | grave 1,00 | `hall2_lich` | 2ª linha **IS A PUZZLE.** (até 22,2) | `whoosh_2` |
| 20,31 | 32,24 | grave 1,00 | `hall3_tyrant` (2 s) | — | `whoosh_2` |
| 22,31 | 34,24 | grave 1,00 | luta (guerreiro): 1º golpe NO corte | — | `impact_1` |
| 23,22 | (34,62/34,84 perto) | espaçamento do jogo | 2º golpe | — | `impact_2` |
| 24,48 → **24,61** | 36,54 | grave 1,00 (Δ 0,13 se o espaçamento do v8 for mantido) | 3º golpe, **número de dano enorme** | (o número é o texto) | `impact_heavy` |
| 26,89 | 38,82 | grave 0,64 | glitch | — | `glitch` |
| 27,16 | 39,09 | grave 1,00 | logo: anel | — | — |
| 28,34 / 28,61 | 40,27 / 40,54 | graves 0,92 / 1,00 | selo preenche (2 pulsos) | **GRIMOIRE** | `impact_1` baixo |
| 29,17 | 41,10 | grave 1,00 | selo fecha | **WISHLIST ON STEAM.** | `logo_seal` |
| 29,76 → 30,7 | 41,69 → 42,6 | grave 1,00 | cartão final parado (3,5 s desde o logo) | — | fade da faixa 0,4 s |

Notas A: 7 cartões em 30 s (denso de propósito, modelo Vampire Survivors); 3 salões em vez de 4 porque o Tirano não tem grave entre 32,24 e 34,24; gameplay no quadro 0 (a mão já está no vidro enquanto a TV acende). Os golpes 2 e 3 da luta usam o espaçamento do v8 (0,91 / 1,26 s): ancorando o 1º em 22,31, o 3º cai em 24,48, a 0,13 s do grave 36,54.

### Conceito B: "Principal 65 s" (Rei-Carniça, candidato a 1º vídeo)

Faixa de p = 18,86 até 83,1. **t = p − 17,86**. Duração **65,3 s**. Pico (número enorme no drop 70,01) em t = 52,15 → **79,9 %**.

| t | p | âncora | imagem | texto | SFX |
|---|---|---|---|---|---|
| 0,00–1,00 | — | sem música | TV liga com o combate do ladino já visível (`deck8`) | — | `tv_on` |
| 1,00 | 18,86 | grave | música entra; mão sendo dada | — | — |
| 1,94 | 19,80 | grave | seleção de cartas | — | — |
| 3,49 | 21,35 | grave | **JOGAR** | **BUILD A LIVING DECK.** (até 8,3) | — |
| 4,76 / 6,02 / 6,96 | 22,62 / 23,88 / 24,82 | graves | golpes 1 a 3 (velocidade de combate da gravação ajustada para ~1,25 s entre golpes) | — | `impact_1/2/1` |
| 8,52 | 26,38 | grave | corte: recompensa com carta rara viva (`reward`) | **EVERY CARD IS ALIVE.** (até 10,9) | `whoosh_2` |
| 11,05 | 28,91 | grave | ato I (estrada à noite, `night_a1`) | **SIX ACTS.** + numeral **I** em runa | `whoosh_2` |
| 12,29 / 13,55 / 14,81 / 16,07 | 30,15 / 31,41 / 32,67 / 33,93 | graves | atos II, III, IV, V (1,26 s cada) | numerais II a V | `whoosh_2` baixo |
| 17,33 | 35,19 | último grave antes do pad | ato VI, castelo ao centro; a música cai | **ONE ROAD TO THE CASTLE.** (até 20,4) | — |
| 20,5–28,0 | pad | **sem grave**: dissolves ancorados no pouso de cada criatura | grifo, anjo caído, serpente (~2,5 s cada) | **YOUR CARDS DECIDE** no pouso do grifo; **WHAT SURVIVES.** no pouso do anjo | `whoosh_1` + `impact_2` em cada pouso |
| 28,0–31,0 | pad | sem grave | loja e coringas (`shop`) | **BEND EVERY HAND.** | `whoosh_1` |
| 31,0 | pad | sem grave | porta do castelo (`boss8`) | — | `castle_door` (baque em 33,75 = quadro da porta) |
| 33,75–37,21 | pad | quadro da imagem | olhos, rasantes, entrada inteira | — | — |
| 37,21 | 55,07 | **drop** | pouso do Rei-Carniça + cartão do jogo | — | `impact_heavy` |
| 38,66 | 56,52 | grave | salão 4K `hall2_lich` | **EVERY BOSS** | `whoosh_2` |
| 39,91 | 57,77 | grave | `hall3_tyrant` | 2ª linha **IS A PUZZLE.** (até 42,3) | `whoosh_2` |
| 41,15 / 42,43 | 59,01 / 60,29 | graves 1,00 / 0,85 | `hall4_ice`, `hall5_heart` | — | `whoosh_2` |
| 43,68 | 61,54 | grave | luta sem corte (guerreiro) até 54,99 | — | — |
| 44,92 | 62,78 | grave | JOGAR | — | — |
| 49,93 / 51,20 | 67,79 / 69,06 | graves | golpes 1 e 2 | — | `impact_1/2` |
| **52,15** | **70,01** | **drop (pico)** | 3º golpe, **número enorme** | (o número) | `impact_heavy` |
| 54,99 | 72,85 | grave 0,61 | glitch (0,3 s) | — | `glitch` |
| 55,29 | — | fim do glitch | logo: anel | — | — |
| 57,18 | 75,04 | grave | selo, 1º pulso | **GRIMOIRE** | `impact_1` baixo |
| 60,01 | 77,87 | grave 0,97 | selo fecha | **WISHLIST ON STEAM.** | `logo_seal` |
| 62,21 | 80,07 | grave 0,93 | brilho final | — | `impact_1` baixo |
| 64,66 → 65,3 | 82,52 → 83,1 | grave | corte seco do cartão, fade da faixa 0,6 s | — | — |

Notas B: gameplay no quadro 0; loop completo (jogar → recompensa → mapa → chefe) até 43 s; cortes médios de 2 a 4 s, com uma rajada de 1,26 s nos 6 atos. Os 20 s de pad (t 17,3 a 37,2) não têm grave nenhum: ali não se promete sincronia de grave; os pontos são o pouso de cada criatura e o quadro da porta, cada um com SFX sintetizado. Cartão final: 5,3 s desde o WISHLIST.

### Conceito C: "v9" (v8 recortado nos graves do Rei-Carniça)

Mesma ordem e mesmas imagens do v8. Faixa de p = 10,05 até 73,5. **t = p − 8,55**. Duração **65,0 s** (v8: 62,0). Pico em t = 52,99 → **81,5 %**. O drop 55,07 cai em t = 46,52, a 0,42 s do nome do chefe no v8 (46,94): o desenho do v8 cabe quase sem mexer, e o pad do Rei-Carniça ocupa o lugar do silêncio do v8 (frases + porta).

| t | p | âncora | bloco do v8 (t no v8) | texto | SFX |
|---|---|---|---|---|---|
| 0,00–1,50 | — | sem música | TV liga: v8 0,40–1,90 (ponto → linha → imagem) | — | `tv_on` |
| 1,50 | 10,05 | grave | estrada + castelo (v8 1,90 em diante) | **SIX** | — |
| 2,78 | 11,33 | grave | idem | **ACTS.** | — |
| 4,01 | 12,56 | grave | idem | **ONE ROAD TO THE CASTLE.** (até 6,2) | — |
| 6,28 | 14,83 | grave | cartas: v8 6,96–16,01 (deslocamento −0,68 s) | — | `whoosh_2` |
| 7,80 / 9,05 | 16,35 / 17,60 | graves | mão dada, seleção | **BUILD** / **A LIVING** | — |
| 10,31 | 18,86 | grave | **JOGAR** (v8 10,99) | **DECK.** (até 12,6) | — |
| ≈12,42 / ≈12,82 | 21,35 = 12,80 | grave | golpes do v8 (≈13,1/13,5 no v8; o 2º fica a 0,02 s do grave, o 1º a 0,38) | — | `impact_1/2` |
| 15,33 | 23,88 | grave | encruzilhada ato 2 (v8 16,17+) | — | `whoosh_2` |
| 17,83 | 26,38 | grave | encruzilhada ato 4 (v8 18,40+) | — | `whoosh_2` |
| 19,09 / 20,36 / 21,60 / 22,86 / 24,12 | 27,64 / 28,91 / 30,15 / 31,41 / 32,67 | graves | 5 salões 4K, um por grave (originais `ai_4k`, sem nome queimado) | nome do chefe em runa pixel em cada salão | `whoosh_2` com pitch subindo |
| 25,38 | 33,93 | grave | grifo | **YOUR CARDS** | `impact_2` |
| 26,64 | 35,19 | último grave antes do pad | grifo continua | **DECIDE WHAT SURVIVES.** (até 29,2) | — |
| ≈29,4 | pad | pouso (sem grave) | anjo caído (v8 30,42–32,73) | — | `whoosh_1` + `impact_2` |
| ≈31,7 | pad | sem grave | serpente de gelo (v8 32,73–35,02) | — | `whoosh_1` |
| ≈34,0–39,4 | pad | sem grave | estrada/castelo à noite (lugar das 2 telas pretas do v8): sem texto, nada de preto | — | — |
| 39,41 | pad | quadro da porta | porta + entrada do rei (bloco do v8 a 1,247x, 7,11 s) | **EVERY BOSS IS A PUZZLE.** no baque | `castle_door` (baque no quadro da porta) |
| 46,52 | 55,07 | **drop** | nome do chefe (v8 46,94) | — | `impact_heavy` |
| 47,97 | 56,52 | grave | luta sem corte (v8 48,20–55,20) | — | — |
| 49,22 | 57,77 | grave | JOGAR | — | — |
| 50,46 / 51,74 | 59,01 / 60,29 | graves | golpes 1 e 2 | — | `impact_1/2` |
| **52,99** | **61,54** | grave (pico) | 3º golpe, **número enorme** | (o número) | `impact_heavy` |
| 55,19–55,49 | — / 64,04 | termina no grave | glitch | — | `glitch` |
| 55,49 | 64,04 | grave | `logo_sting` a 1,044x (o impacto da arte, 2,62 s, cai em 58,00 = grave 66,55) | — | `impact_1` em 58,00 |
| 60,51 | 69,06 | grave | selo fecha | **WISHLIST ON STEAM.** | `logo_seal` |
| 61,46 → 65,0 | 70,01 → 73,5 | drop | cartão final parado (4,5 s desde o WISHLIST), fade da faixa | — | — |

Notas C: as 4 trocas do plano de referência estão todas aqui (trilha, áudio sintetizado, TV de 1,5 s com imagem a partir de 1,25 s, texto palavra a palavra no grave). Os golpes que vêm do v8 têm o espaçamento do jogo (0,91/1,26 s), não o do Rei-Carniça (1,255 s): só um golpe por bloco pode cair exato no grave sem regravar com outra velocidade de combate.

---

## 3. Tomadas

### O que existe em `%APPDATA%\LOVE\card-game-trailer\trailer\`

Todas de **20/10/2026** (build de 10 dias atrás), 1920x1080 TGA (8,3 MB por quadro; a pasta tem 111 GB), gravadas com a **run do mago** (`newRun("mage")` em todos esses SHOTS).

| Tomada | Quadros | Situação |
|---|---|---|
| act1_mage | 735 | mago, build antiga: **não usar** (Daniel: sem mago, jogo atual) |
| act2_griffin / act3_hellhound / act4_wyrm / act5_spore / act6_dullahan | 587 / 635 / 635 / 551 / 662 | batalhas com a mão do mago: **não usar** |
| boss_carrion / lich / tyrant / monarch / eclipse | 1558 / 924 / 1037 / 986 / 2735 | mago; a rainha nunca aparece no trailer: **não usar** |
| hand_hover | 845 | mago (`hand_hover` cria run de mago): **não usar** |
| fork | 270 | encruzilhada da run do mago, build antiga: só de reserva |
| reward / shop | 406 / 161 | mago, build antiga: **não usar** |
| intro / menu / classsel / collection / journal / victory | 242 / 120 / 337 / 369 / 176 / 180 | build antiga (menu sem a marca atual): fora dos 3 conceitos |
| ai_book | 240 | vídeo IA: fora |
| cards | 0 TGA (384 PNG) | não é gameplay: 16 cartas × 24 quadros da animação de ícone (`export_cards`) |
| `audio.jsonl` | 19 tomadas | só serve às tomadas acima |

`card-game-trailer-v8\trailer\` (e v6, v7, 1080, 4k, 4kn) estão **vazias**: os takes do v8 (`entrances`, `deck8`, `boss8`, `poweron`, `fork_a*`) não existem mais. `card-game-trailer-nocrt` tem act1_mage, boss_carrion, hand_hover, intro, menu, reward (mago, sem CRT): não usar.

**Conclusão:** nenhuma tomada do disco serve sem violar "sem mago" ou "jogo atual". Tudo vem do v8 ou de regravação.

### O que sai do `grimoire_trailer_v8.mp4` (1920x1080, 60 fps, 62,0 s)

Tempos recalculados do próprio corte (`trailer_v8_cut.py`, mesma conta do `report()`) e conferidos em folha de contato (TV: ponto em 0,50, linha 0,75–1,00, imagem 1,25, assentada 1,75; cartas: texto em 7,0–9,6, banner COMBO em 13–14, clarão em ≈14,0). **O v8 tem os 5 textos e os nomes dos salões QUEIMADOS na imagem**, além da trilha T4 e dos SFX ElevenLabs no áudio: extrair sempre sem áudio (`-an`) e só das janelas limpas.

| Bloco | Janela no v8 (t) | Limpa? | Uso |
|---|---|---|---|
| poweron (TV liga) | 0,00–3,00 | sim | C 0–1,5 |
| estrada (poweron cont. + fork_a1) | 3,00–4,20 limpa · 4,20–6,90 **SIX ACTS. queimado** | parcial | C só 1,9–4,2 limpo |
| deck8 (ladino, salão de lava) | 6,50–10,00 **BUILD A LIVING DECK. queimado** · **10,00–16,17 limpa** (JOGAR 10,99; golpes ≈13,1 / 13,5) | parcial | A 0–5 (o trecho 9,54–10,0 fica sob a TV ligando); B e C precisam do início |
| fork_a2 | 16,17–18,40 | sim (abre com glitch 0,14 s) | A 7,18 · C 15,33 |
| fork_a4 | 18,40–20,60 | sim | A 8,82 · C 17,83 |
| 5 salões | 20,60–26,43 | nomes queimados | **usar os originais** `R\build\trailer\ai_4k\hall1..5_*.mp4` |
| grifo | 26,43–26,83 limpa · 26,83–29,43 **YOUR CARDS… queimado** · 29,43–30,42 limpa | parcial | A/B/C querem texto novo em cima: precisa regravar |
| anjo caído | 30,42–32,73 | sim | B, C |
| serpente de gelo | 32,73–35,02 | sim | A, B, C |
| frases pretas | 35,02–39,82 | — | não usar |
| porta + entrada (1,247x) | 39,82–39,92 limpa · 39,92–42,67 **EVERY BOSS… queimado** · 42,67–46,93 limpa | parcial | a porta em si está sob o texto |
| nome do chefe | 46,93–48,20 | sim | A 18,00 · B 37,21 · C 46,52 |
| luta (guerreiro) | 48,20–55,20 (golpes 53,00 / 53,91 / 55,17) | sim (pulsos de brilho nos golpes, que andam com a imagem) | A 22,31 · B · C |
| logo | 55,50–62,00 (WISHLIST queimado em 59,8) | parcial | usar `brand\logo_sting.mp4` original, mudo |

Pulsos de brilho/tremor queimados (dos graves da T4): 20,60 21,18 21,61 25,62 25,97 26,43 30,42 30,82 31,41 32,74 35,03 35,41 36,03 37,54 39,83 40,64 47,00 48,20 49,11 51,80 53,00 53,91 55,17 (+ os golpes do deck, não recalculáveis sem o log apagado) e zoom de 3 % em 20,60 21,61 22,24 23,67 25,62 26,43 30,42 32,74 46,94 48,20. Os que caem fora de golpe/corte vão aparecer fora do grave novo (anjo 30,82/31,41, porta 40,64).

Extração (exemplo; `-ss` depois do `-i` para precisão de quadro, sem áudio):

```
cd E:\dev\projects\card-game-trailer\build\trailer
mkdir v8x
ffmpeg -i grimoire_trailer_v8.mp4 -ss 0.00  -to 3.00  -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/poweron.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 10.00 -to 16.17 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/deck8_limpo.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 16.17 -to 18.40 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/fork_a2.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 18.40 -to 20.60 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/fork_a4.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 30.42 -to 32.73 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/entr_anjo.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 32.73 -to 35.02 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/entr_serpente.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 42.67 -to 48.20 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/boss_entrada_nome.mp4
ffmpeg -i grimoire_trailer_v8.mp4 -ss 48.20 -to 55.20 -an -c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p v8x/boss_luta.mp4
```

(não rodado nesta fase; o v8 já tem a moldura do CRT queimada, então o efeito de "TV ligando" sobre `deck8` em A e B é feito no editor, por dentro da moldura.)

### Faltas e regravação

Faltam limpas, para os três conceitos: **estrada/castelo (fork_a1) sem texto**, **deck8 desde a mão sendo dada**, **grifo inteiro**, **porta do castelo**, e para B: **6 atos sem mago (night_a1..6)**, **recompensa com carta rara e loja com o ladino**. A luta do v8 também não tem cauda depois do 3º golpe (o número enorme precisa de ~2 s parado). Recomendo regravar o conjunto do v8 numa sessão, em vez de remendar com o v8: com tomadas novas, o `trailer_v8_cut.py` pode ser reparametrizado nos graves novos e o kinetic entra por cima de imagem limpa.

Pré-requisitos (`memory/trailer_capture.md` do R):
1. A branch `steam-store-v2` está **2 commits atrás da `main`** (`14d5eba5` estrada sem mato, `e40c1249` Mãe dos Esporos): trazer a `main` antes (lição de 20/10: gravar o código atual).
2. Conferir que o Daniel não está jogando (processo verificado pela linha de comando, nunca matar por nome) e que não há outro `lovec` rodando: **1 lovec**.
3. Espaço: ~8,3 MB por quadro a 60 fps ≈ 0,5 GB por segundo de tomada; a sessão abaixo dá ~200 s ≈ 100 GB (C: tem 268 GB livres; a identidade antiga ocupa 111 GB, apagar só com OK do Daniel).

Comando (Git Bash, na raiz de R; `CARDGAME_HEADLESS=1` = janela escondida fora do monitor; identidade nova isolada e `HEADLESS_TOOL` mandam o save para `*.tool.lua` de `card-game-trailer-v9`, o save real não é tocado):

```
cd /e/dev/projects/card-game-trailer
CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=card-game-trailer-v9 \
TRAILER_FPS=60 TRAILER_SIZE=1920x1080 TRAILER_NIGHT=0.85 TRAILER_NOTOPBAR=1 TRAILER_LOCALE=en \
TRAILER_ACTS=1,2,3,4,5,6 \
TRAILER_ENTRANCES=storm_griffin,fallen_angel,ice_wyrm \
TRAILER_DECK_CLASS=rogue TRAILER_DECK_ENEMY=pit_brute TRAILER_DECK_TURNS=2 TRAILER_DECK_SPEED=0.72 \
TRAILER_BOSS_CLASS=warrior TRAILER_BOSS_ACT=1 TRAILER_BOSS_TURNS=2 TRAILER_BOSS_SPEED=0.54 \
lovec . test_one trailer_record poweron,night,entrances,deck8,reward,shop,boss8
```

- Ordem importa: `poweron` e `night` criam run de mago se não houver, mas são só mundo (`worldOnly`, inimigo desligado): conferir na folha de contato que nenhuma carta do mago aparece. `entrances` e `boss8` fazem `freshRun("warrior")`, `deck8` faz `freshRun("rogue")`, e `reward`/`shop` reaproveitam a run do ladino que o `deck8` deixou.
- `night` grava `fork_a1..6` + `night_a1..6` (encruzilhada + viagem sem monstro).
- Para B e C, testar `TRAILER_DECK_SPEED`/`TRAILER_BOSS_SPEED` entre 0,6 e 0,75 para os golpes ficarem ~1,25 s um do outro (o `speed` multiplica as esperas: menor = mais rápido).
- Saída: `%APPDATA%\LOVE\card-game-trailer-v9\trailer\<shot>\`. Revisar cada take com `python tools/trailer_review.py shot:<nome> t0 t1 passo` antes de ancorar.
- O `audio.jsonl` continua útil SÓ como marcador de tempo (clique, portão, golpe): nenhum som do jogo vai para o trailer.

---

## 4. SFX sintetizados

Script: `tools/synth_trailer_sfx.py` (neste repo). Síntese local com numpy/scipy, **sem amostra nenhuma** (nem do jogo, nem ElevenLabs, nem Pixabay), semente fixa (resultado idêntico a cada execução).

```
python tools/synth_trailer_sfx.py            → E:\dev\projects\card-game-trailer\build\trailer\sfx_synth\
python tools/synth_trailer_sfx.py <pasta>    → outra pasta
```

Saída: WAV 48 kHz, 16 bit, estéreo, pico −1 a −4 dBFS, e `manifest.json` com duração e o instante do ataque de cada arquivo (`hit`), para o editor alinhar o ataque ao grave.

| Arquivo | Duração | Ataque (`hit`) | Como é feito |
|---|---|---|---|
| `tv_on.wav` | 1,60 s | 0,00 | clique de relé (ruído 0,8–6 kHz), "tunc" de alta tensão (senoide 180→55 Hz), zumbido de desmagnetização 50 Hz em batimento de 7 Hz, chiado do flyback 15,6 kHz bem baixo, estalos de estática e um blip de 1,24 kHz |
| `impact_1.wav` / `impact_2.wav` | 1,10 s | 0,00 | golpe: sub 140→38 Hz (160→44 no 2), estalo de ruído 0,9–7 kHz, corpo grave, saturação tanh e sala curta |
| `impact_heavy.wav` | 1,10 s | 0,00 | golpe do número enorme/drop: 120→30 Hz, corpo longo |
| `whoosh_1.wav` / `whoosh_2.wav` | 0,90 / 0,65 s | 0,56 / 0,36 | ruído com filtro passa-banda varrendo 250 Hz → 4 kHz, envelope que cresce e corta, pan da esquerda para a direita |
| `castle_door.wav` | 5,20 s | **2,75** (baque) | rangido grave por atrito (pulsos irregulares de 26 a 60 Hz em ressonâncias de 140–320, 420–700 e 900–1300 Hz, centroide ≈ 580 Hz) + gemido de 62→48 Hz; baque em 2,75 s (sub 85→32 Hz, madeira, corrente) com sala grande |
| `logo_seal.wav` | 3,40 s | 0,00 | selo: baque 110→42 Hz + sino inarmônico FM (parciais 1 / 2,76 / 5,4 / 8,93 sobre 220 Hz) + brilho 5–11 kHz pulsando |
| `glitch.wav` | 0,55 s | 0,00 | rajadas de 12–60 ms: onda quadrada, sample-and-hold, silêncio e tom agudo com ruído, quantizado em 12 níveis |

Conferido por medição (não ouvido): taxa 48 kHz, 2 canais, sem NaN, pico/RMS em ordem, rangido com 6 dB a mais que a 1ª versão para a porta ficar audível (pedido 6 do Daniel; o `castleGateOpen` do jogo é ElevenLabs free e não entra). **Falta ouvir**: timbre e volume relativo são decisão de ouvido na fase 2.

Uso por conceito: `tv_on` no t 0; `whoosh` nos cortes de atos/salões/encruzilhadas; `impact_*` em cada golpe e pouso (os sons de golpe e de entrada das tomadas são ElevenLabs: o trailer usa só estes); `castle_door` com o ataque 2,75 s no baque; `logo_seal` no WISHLIST; `glitch` antes do logo.

---

## 5. Origem e licença do áudio previsto

| Áudio | Origem | Licença |
|---|---|---|
| `audio/music/boss-carrion_king.mp3` (B, C) | ACE-Step 1.5 local | uso comercial ok |
| `audio/music/boss-abyss_tyrant.mp3` (A) | ACE-Step 1.5 local | uso comercial ok |
| `build/trailer/sfx_synth/*.wav` | `tools/synth_trailer_sfx.py`, síntese própria | sem pendência |
| sons do jogo nas tomadas, `castleGateOpen`, áudio do v8, T4/T1 | ElevenLabs free / origem não documentada | **não usar** |

Divergência para o chefe olhar: `memory/trailer_capture.md` (no R, rodada de 21/10) diz que a `trailer_T4.wav` é ACE-Step; o handoff diz que a licença da T4 não está documentada. Não muda nada aqui (nenhum conceito usa a T4), mas decide se o v8 atual é publicável como está.

## Pendências para a fase 2

1. Decidir: regravar (recomendado) ou montar com as janelas limpas do v8.
2. Ouvir os SFX sintetizados e ajustar timbre/ganho.
3. Folha de contato de cada take novo antes de ancorar golpes e pousos.
4. Medir o resultado: rodar o detector no áudio do mp4 final e comparar com os cortes (meta ≤ 1 quadro de mediana).
