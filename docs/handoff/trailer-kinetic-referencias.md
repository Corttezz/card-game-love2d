# Referências para o trailer Kinetic Film do Grimoire

_Montado em 29/10/2026 para a frente `trailer-kinetic` (briefing: `docs/handoff/trailer-kinetic.md`). Nada renderizado. Fontes reais com link; o que é medição nossa está marcado como tal._

**Método dos trailers:** baixei cada trailer em 360p (só para análise, `/tmp/tr` na box, não vai para o repo), medi a duração, contei cortes com `ffmpeg select='gt(scene,0.3)'` (contagem aproximada: não pega cortes em fade e conta flashes) e olhei quadros de 1 em 1 s nos primeiros 6 s e de 2 em 2 s nos últimos 10 s. Não deu para ouvir a música; por isso o "ritmo de cortes x música" é inferido da densidade de cortes, não medido no grave.

## 1. Trailers de referência

| Jogo / trailer | Duração | Primeiros 3–5 s | Gameplay entra | Texto / tipografia | Cortes (aprox.) | Fecho |
|---|---|---|---|---|---|---|
| [Slay the Spire – Official Launch Trailer](https://www.youtube.com/watch?v=9SZUtyYSOjQ) (Mega Crit, 2019) | 96 s | Arte animada do Defeito invocando orbes (desfoque → foco), sem logo | ~4 s (1º corte 3,6 s) para combate com mão de cartas e carta "Channel Lightning" em destaque | Pouco texto; a carta em close faz o papel do cartão de texto | 27 (~1 a cada 3,5 s): planos longos, legíveis | Logo sobre a arte da Spire + "AVAILABLE NOW" (~8 s parado) |
| [Balatro – Official Launch Trailer](https://www.youtube.com/watch?v=VUyP21iQ_-g) (Playstack, 2024) | 68 s | Fundo escuro, o Jimbo (carta do coringa) surge e "fala" em balão: "Hello!" / "Takes one to know one!" | ~8 s; depois rajada de cortes (8,2 / 8,6 / 9,5 s…) | Narração + balões de texto na fonte pixel do jogo; o texto É personagem | 32 (~1 a cada 2 s, com rajadas) | Coringa em close, flash branco, logo + botão "OUT NOW" + plataformas (~8 s) |
| [Inscryption – Official Launch Trailer](https://www.youtube.com/watch?v=BRlnP67TAf4) (Devolver, 2021) | 60 s | Preto, só os olhos do Leshy; texto "FROM THE CREATOR OF THE HEX AND PONY ISLAND" | ~15 s (1º corte 15,0 s) | Texto curto em caixa alta, 2 cores, sobre preto; aposta em clima, não em loop | 16 (~1 a cada 3,7 s) | Mesa com velas (gameplay) → logo + "NOW AVAILABLE" → volta aos olhos no escuro |
| [Monster Train – Release Trailer](https://www.youtube.com/watch?v=ZJ6ayvNJDjs) (Good Shepherd, 2020) | 59 s | Preto → gameplay no trem (3 andares) com feitiço explodindo já em ~1,6 s | ~1,6 s | Cartão de citação de imprensa real ("PERFECT FOR THE 'ONE MORE RUN' MENTALITY" – The Sixth Axis) | 28 (~1 a cada 2,1 s) | Arte do anjo → logo → "BUY NOW" + logos (~6 s) |
| [Luck be a Landlord – v1.0 Release Date Trailer](https://www.youtube.com/watch?v=JcbKTeJ6uXU) (TrampolineTales, 2022) | 100 s | UI do próprio jogo: e-mail do senhorio "your rent is due…" com botão Pay | Interface do jogo desde 0 s; caça-níquel após ~19 s | Todo texto é UI do jogo em fonte pixel; humor | 7 (planos muito longos) | Logo pixel gigante sobre os símbolos + "Leaving Early Access on… January 6th, 2023" + site |
| [Cobalt Core – Launch Trailer (Switch)](https://www.youtube.com/watch?v=6dRbEJn2Ew8) (Nintendo of America, 2023) | 98 s | Cartão ESRB + logo Switch (exigência de plataforma: o que NÃO fazer na Steam) | ~4 s, combate de naves com mão de cartas | Pouco texto; arte-chave com "Sci-Fi Roguelike Deckbuilder" | 39 (~1 a cada 2,5 s) | Arte-chave + "Available Now" + gênero (~10 s) |
| [Dicey Dungeons – Launch Trailer (PS)](https://www.youtube.com/watch?v=qnNpuf3chqk) (PlayStation, 2021) | 52 s | Logo PS (plataforma) → dado gigante rolando em fundo escuro | ~4–5 s, combate com dados e cartas-equipamento | Texto é a UI do jogo (cartas "FIREBALL", "SWORD") | 13 (~1 a cada 4 s) | Arte-chave + "NOW AVAILABLE!" (~10 s) + logo PS |
| [Vampire Survivors – Launch Trailer](https://www.youtube.com/watch?v=aS7JqyHdQQA) (poncle, 2022) | 63 s | Gameplay puro desde o quadro 0 (horda + projéteis) | 0 s | **Tipografia cinética de verdade:** "120,000 POSITIVE REVIEWS", "0 VAMPIRES", palavras grandes amarelas com contorno, entrando com tremor sobre um plano borrado do jogo | 23 (~1 a cada 2,7 s) | Arte do vampiro + logo + "Available now" + Steam/Game Pass (~8 s) |

**O que se repete nos que deram certo:**
- Nenhum abre com logo de estúdio; na Steam, só os cortes de console têm ESRB/logo de plataforma (obrigação de console, não modelo).
- Os deckbuilders mostram **a mão de cartas na tela** cedo (StS ~4 s, Cobalt ~4 s, Dicey ~5 s). Inscryption atrasa (15 s) porque vende mistério; não é o nosso caso para o 1º vídeo.
- O texto que funciona tem **cara do jogo**: balão pixel do Balatro, UI do LBaL, números enormes do Vampire Survivors. Nada de vetor genérico.
- Cortes a cada **2 a 4 s** em média, com rajadas curtas nos picos. Ninguém corta em toda batida o tempo todo.
- Fecho: logo + **um** CTA ("AVAILABLE NOW" / "OUT NOW" / data) parado de **6 a 10 s**.
- Duração: 52 a 100 s (mediana ≈ 66 s).

## 2. Padrões da Steam (lista curta)

1. **O 1º trailer deve ser gameplay**, da perspectiva do jogador e com HUD visível; os 2 primeiros vídeos aparecem antes dos screenshots. — [Steamworks: Trailers](https://partner.steamgames.com/doc/store/trailer)
2. **Menos de 10 s para causar impressão, e muitas vezes sem áudio** (Fila de Descoberta). Texto tem de ser legível mudo. — [Steamworks: Trailers](https://partner.steamgames.com/doc/store/trailer); autoplay da loja começa mudo — [discussão Steam](https://steamcommunity.com/discussions/forum/1/627456359724914238/)
3. **Gameplay nos primeiros 2–5 s**, sem logo de estúdio nem texto de lore ("In a world…") nem pan lento de cenário. — Chris Zukowski, [quando postar a página](https://howtomarketagame.com/2025/03/10/when-should-i-post-my-steam-coming-soon-page/) e [60 Mistakes, #7](https://howtomarketagame.com/wp-content/uploads/2023/05/Zukowski_60MistakesEbookV1.pdf) ("cut to actual gameplay within the first two seconds")
4. **Gancho (o que é único) em 10–15 s**, logo depois de situar o gênero em 1–2 planos. — Derek Lieu, [How to Hook the Audience](https://www.derek-lieu.com/blog/2022/10/24/how-to-hook-the-audience-and-how-quickly-to-do-it)
5. **Mostrar o gancho 2 a 3 vezes, nunca 4.** — Derek Lieu, [Rule of Threes](https://www.derek-lieu.com/blog/2022/11/14/the-rule-of-threes-in-game-trailers)
6. **Duração:** 60–90 s para o trailer principal ([WishlistReady](https://wishlistready.com/steam-page-components/trailer), [SteamPageAnalyzer](https://www.steampageanalyzer.com/blog/steam-trailer-best-practices)); Derek Lieu vai até 90–180 s para o "MVP trailer", porque o comprador pula pela barra ([Simplest Trailer](https://www.derek-lieu.com/blog/2021/4/18/the-simplest-trailer-to-make-for-your-steam-page)). 30 s já serve para começar (Zukowski).
7. **Planos de 2–4 s** (3–5 s se a pessoa vai pular pela barra), variar ritmo; clímax de gameplay e então título + "Wishlist" claro; logo de estúdio no máximo 2–3 s. — [SteamPageAnalyzer](https://www.steampageanalyzer.com/blog/steam-trailer-best-practices), [Derek Lieu](https://www.derek-lieu.com/blog/2021/4/18/the-simplest-trailer-to-make-for-your-steam-page)
8. **Microtrailer:** a Steam gera sozinha um clipe de 6 s **a partir do 1º vídeo**, usado nos hovers de festivais (Next Fest etc.); dá para conferir trocando `movie480_vp9.webm` por `microtrailer.webm` na URL. — [Myopic Design](https://myopic.design/blog/preview-steam-micro-trailer/). Relato de dev: são seis trechos de 1 s de pontos espalhados (num trailer de 30 s: 10/13/16/20/23/26 s) — [r/gamedev](https://www.reddit.com/r/gamedev/comments/1mlngcp/how_we_were_able_to_control_our_steam_microtrailer/). ⚠️ Isto **corrige** a premissa da nossa pesquisa de 20/10 ("os 6 s iniciais viram microtrailer"): o certo é evitar preto/cartão de texto puro em qualquer trecho, não só no começo. Conferir no microtrailer real depois que o vídeo subir.
9. **Thumbnail/poster:** gerados automaticamente (600x380 e 232x130). — [Steamworks: Trailers](https://partner.steamgames.com/doc/store/trailer). O loop da página mostra o 1º quadro antes de tocar ([WishlistReady](https://wishlistready.com/steam-page-components/trailer)): primeiro quadro não pode ser preto.
10. **Upload:** até 1920x1080, 30 ou 60 fps, ≥ 5.000 kbps, H.264 + AAC, áudio vira estéreo. — [Steamworks: Trailers](https://partner.steamgames.com/doc/store/trailer)

## 3. Guia de tipografia cinética

**Exemplos:**
- Vampire Survivors, [Launch Trailer](https://www.youtube.com/watch?v=aS7JqyHdQQA): números grandes com contorno sobre o jogo borrado; o texto bate junto com o corte. É o modelo mais próximo do que queremos (texto curto, enorme, com humor/peso, sobre o próprio jogo).
- Balatro, [Launch Trailer](https://www.youtube.com/watch?v=VUyP21iQ_-g): o texto entra em balões na fonte pixel do jogo, com "pop" de escala. Prova que tipografia pixel não precisa de vetor liso.
- Luck be a Landlord, [v1.0 trailer](https://www.youtube.com/watch?v=JcbKTeJ6uXU): logo e textos em fonte pixel grossa com contorno, legíveis em 360p.
- BPM: Bullets Per Minute ([case da Futureproof](https://futureproof.film/creations/bpm-video-game-trailer/)): cartões e efeitos de texto sincronizados com tiros/batida.
- Persona 3 "Mass Destruction" ([projeto de Draxyle](https://draxyle.com/graphicdesign13.html)) e HADES66 ([J. Pérez](https://jperez091.myportfolio.com/kinetic-typography-hades66)): tipografia cinética na letra da música (referência de motion, não de trailer Steam).
- Afterparty (citado por [Derek Lieu](https://www.derek-lieu.com/blog/2020/4/19/how-to-write-trailer-title-cards-with-strong-messaging)): "FLIRT / CHEAT / DANCE / PARTY YOUR WAY OUT OF HELL" — mesma frase com 1 palavra trocando = estrutura perfeita para kinetic no grave.

**Regras práticas (com fonte):**
- **Tempo de leitura:** texto parado no mínimo 1 s a cada 13 caracteres, contado depois que a animação assenta ([legibility.info](https://legibility.info/rules-for-text-in-videos)). Ex.: "BUILD A LIVING DECK." (20 car.) ≥ 1,6 s parado; "YOUR CARDS DECIDE WHAT SURVIVES." (32 car.) ≥ 2,5 s parado ou entrar em 2 telas.
- **Ritmo:** 2–3 palavras/s (120–180 ppm) para texto que se lê junto com a música ([showtime pacing](https://faviovazquez.github.io/showtime/docs/pacing.html)); estudo de 2024 achou 90 ppm o mais agradável sem diferença de retenção entre 40 e 120 ppm ([GRID 2024](https://doi.org/10.24867/grid-2024-p89)).
- **Volume:** ≤ 30 caracteres por linha, ≤ 3 linhas; em 1080p, corpo ≥ 40–60 px, título ≥ 1,5x ([legibility.info](https://legibility.info/rules-for-text-in-videos)). Para o Grimoire Pixel: altura de glifo **≥ 64 px** (múltiplo inteiro do pixel da fonte, nearest-neighbor, sem anti-alias).
- **Um texto por vez**, contraste alto, contorno/sombra, fora das bordas (title-safe), sem texto competindo ([Derek Lieu – legendas](https://www.derek-lieu.com/blog/2019/10/27/guide-for-captions-and-subtitles), [QC checklist](https://www.derek-lieu.com/blog/2022/7/11/quality-control-check-list-for-game-trailers)).
- **Mensagem:** cartão que só descreve o Grimoire, não o gênero genérico; 3 palavras é o exercício ([Derek Lieu – title cards](https://www.derek-lieu.com/blog/2020/4/19/how-to-write-trailer-title-cards-with-strong-messaging)).
- **Sincronia (decisão nossa a partir do histórico):** a **entrada** de cada palavra cai num grave medido; a **saída** pode cair em contratempo. Palavra a palavra só em frases ≤ 4 palavras; acima disso, a frase entra inteira e só a palavra-chave pulsa no grave.
- **Pixel/CRT:** renderizar o texto na resolução lógica do jogo e escalar por inteiro; aplicar o mesmo CRT/scanline do jogo **por cima** do texto (senão o texto "flutua" e fica com cara de IA); nada de blur, gradiente, glow liso. Animação por passos (quadros inteiros: 12–15 fps de animação dentro dos 60 fps), dissolução em runa já aprovada. Flashes ≤ 3/s.

## 4. O que o Daniel já pediu / rejeitou

**Pediu (sobre o v7, aplicado no v8 — `docs/steam/trailer-v8-design.md`):**
1. Música não começa no 0: primeiro a TV ligando.
2. Mesmas cenas regravadas no jogo atual.
3. Inimigo aparece pela entrada desde o quadro 0.
4. Menos gameplay, mais animação.
5. Sem o mago: chefe com o guerreiro, cartas com o ladino.
6. Som da porta do castelo audível (o do jogo).
7. Chefe entrando inteiro.
8. Música que para e volta **sincronizada** (como no v4): cada corte num grave.
9. Salões do Higgsfield nos acentos da música.
10. Sons e sincronia no logo/WISHLIST enquanto o selo preenche.
11. Mais sincronia com o áudio, revisão quadro a quadro.

**Rejeitou / regras dele:**
- "Cara de IA" (vetor suave sobre pixel art); vídeo IA só como ponte curta re-pixelizada.
- Música de chefe emendada de clipes diferentes e faixa "alegre": a música é **uma peça contínua, séria, ligada ao bioma**.
- Cenários que não existem mais no jogo (só WorldRoad atos 1–6, `castle_hall_1..6`, `menu.png`; nada de `abyss/splash/catacumbs/stone_tower`).
- Citação inventada (as telas pretas do v8 usam frases do próprio jogo, sem autor).
- Não mexer no aprovado: castelo no centro, arte-assinatura, moldura do CRT sempre no quadro.
- "Bem sutil" = muito sutil.

**Conflitos a resolver (decisão minha, com critério):**
- **Pedido 6 (porta audível) x licença:** o `castleGateOpen` é ElevenLabs free → não entra. Solução: porta sintetizada localmente (rangido grave + baque) colocada no mesmo quadro; registrar como troca na Entrega.
- **Pedido 4 (mais animação) x Steam (gameplay cedo):** o 1º vídeo da página mantém captura real antes de 4 s; "animação" = entradas de criaturas e chefes (que são do jogo), não b-roll.
- **TV ligando (pedido 1) x "gameplay nos 2–5 s":** a TV liga em ≤ 1,5 s **já com a imagem do jogo aparecendo no vidro**, não 3 s de preto.
- **Microtrailer:** as duas telas pretas de frase do v8 (35–40 s) podem cair no microtrailer; nas versões novas a frase vai sobre imagem do jogo.

## 5. Aplicação ao Grimoire

**Áudio (restrição dura):** só `audio/music/boss-carrion_king.mp3` (Rei-Carniça, 95,1 s) e `boss-abyss_tyrant.mp3` (Tirano, 81,1 s), ACE-Step local, uso comercial ok. **Uma faixa por trailer, contínua, sem emenda** (regra do Daniel). SFX só sintetizados localmente (`tools/synth_narrator_blips.py` e síntese por código no Kinetic Film: impacto, whoosh, rangido de porta, selo). Nenhum SFX do jogo (ElevenLabs free), nenhum Pixabay/origem incerta, nem `trailer_T4/T1.wav`.
**Antes do corte:** rodar `tools/trailer_beats.py` nas duas faixas e gerar `boss-carrion_king_beats.json` e `boss-abyss_tyrant_beats.json`; os segundos abaixo são **lugares nominais** e cada evento é ajustado ao grave medido mais próximo (≤ 0,15 s), como no v8.
**Imagens:** só captura real (takes do AppData: `cards`, `hand_hover`, `fork`, `act1..6`, `boss_carrion/lich/tyrant/monarch/eclipse`, `reward`, `shop`, `victory`, `intro`, `menu`), trechos extraídos do próprio `grimoire_trailer_v8.mp4` (entradas, `deck8`, `boss8`, que não existem mais no disco), salões 4K `ai_4k/hall1..5` (b-roll IA, declarar) e a marca (`logo_final.png`, moldura `bezel_mask/ring`). O `logo_sting.mp4` só entra se o áudio dele for trocado pelo selo sintetizado.

### Conceito A — "Gancho 30 s" (redes, Next Fest, 2º vídeo)
Faixa: Tirano (mais agressiva; usar o trecho do 1º drop). Tipografia protagonista, estilo Vampire Survivors/Afterparty.

| t (s) | batida | imagem | texto na tela |
|---|---|---|---|
| 0,0–1,2 | TV liga (blip sintetizado), já com a mão de cartas no vidro | `hand_hover` | — |
| 1,2–3,6 | entra a faixa; JOGAR no 1º grave, 3 golpes nos 3 seguintes | `cards` (ladino) | **PLAY.** (no grave do JOGAR) |
| 3,6–6,0 | número de dano grande | `cards`/`deck8` | **BREAK.** |
| 6,0–9,0 | 3 encruzilhadas, 1 por grave | `fork_a1/a3/a5` | **SIX ACTS.** → **ONE ROAD.** |
| 9,0–15,0 | 3 entradas de criatura, 1 por grave (grifo, serpente, anjo) | do v8 | **YOUR CARDS / DECIDE / WHAT SURVIVES.** (1 linha por entrada) |
| 15,0–18,0 | queda de energia da faixa; porta sintetizada | `boss_carrion` (porta + olhos) | — (silêncio de texto) |
| 18,0–24,0 | drop: chefe entra inteiro; 4 salões 4K, 1 por grave | `boss_carrion` + `hall1..4` | **EVERY BOSS / IS A PUZZLE.** |
| 24,0–26,0 | golpe final com número enorme (pico ≈ 80 %) | `boss8` | (o número é o texto) |
| 26,0–30,0 | selo preenche no último grave | logo | **GRIMOIRE** + **WISHLIST ON STEAM** |

Insumos: `hand_hover`, `cards`, `fork`, entradas e `boss8` extraídos do v8, `boss_carrion`, `hall1..4`, logo. 8 cartões, ≤ 3 palavras por tela.

### Conceito B — "Principal 60–65 s" (candidato a 1º vídeo da página)
Faixa: Rei-Carniça (é o chefe mostrado; faixa ligada ao bioma do ato 1). Gameplay < 2 s, loop completo até 20 s, kinetic como camada leve sobre captura.

| t (s) | batida | imagem | texto |
|---|---|---|---|
| 0,0–1,0 | TV liga com o combate já visível | `cards` | — |
| 1,0–5,0 | faixa entra; seleção de cartas, JOGAR e 3 golpes nos graves (oner curto, à la Derek Lieu) | `cards` (ladino) | **BUILD A LIVING DECK.** (entra no JOGAR) |
| 5,0–9,0 | recompensa com carta rara | `reward` | **EVERY CARD IS ALIVE.** ⚠️ texto novo, precisa de OK |
| 9,0–13,0 | encruzilhada + estrada com castelo ao centro | `fork_a1`, `intro` | **SIX ACTS. / ONE ROAD TO THE CASTLE.** |
| 13,0–21,0 | 6 atos, ~1,3 s cada, um por grave | `act1..act6` (só guerreiro/ladino) | contador **I II III IV V VI** em runa |
| 21,0–28,0 | 3 entradas de criatura | do v8 | **YOUR CARDS DECIDE WHAT SURVIVES.** (2 telas) |
| 28,0–33,0 | loja e coringas | `shop` | **BEND EVERY HAND.** ⚠️ novo |
| 33,0–38,0 | queda da faixa: porta sintetizada, olhos, chefe inteiro | `boss_carrion` | — |
| 38,0–44,0 | drop: nome do chefe; 4 salões 4K por grave | `boss_carrion`, `hall2..5` | **EVERY BOSS / IS A PUZZLE.** |
| 44,0–52,0 | luta sem corte (guerreiro), 3 golpes nos graves, pico ≈ 80 % (≈ 50 s) com número grande | `boss8` (do v8) | — |
| 52,0–54,0 | glitch | — | — |
| 54,0–62,0 | selo preenche em 3 graves, blips sintetizados | logo | **WISHLIST ON STEAM** |

Insumos: `cards`, `reward`, `fork`, `intro`, `act1..6`, `shop`, entradas e `boss8` do v8, `boss_carrion`, `hall2..5`, logo.

### Conceito C — "v9: v8 melhorado" (`grimoire_trailer_v9_kinetic.mp4`)
Mesma ordem e mesmas imagens do v8 (base aceita), com 4 trocas:
1. **Trilha:** T4 sai; entra Rei-Carniça inteira e contínua. Recortar o v8 nos graves da faixa nova (os blocos mudam de duração, a ordem não).
2. **Áudio:** porta e logo com SFX sintetizados no mesmo quadro (v8: `castleGateOpen` +6 dB → porta sintetizada, mesmo volume relativo).
3. **TV:** de 3,0 s de TV sem música para ~1,5 s, com o castelo aparecendo no vidro (gameplay antes de 2 s).
4. **Texto kinetic:** os 5 cartões aprovados passam de dissolução a entrada palavra a palavra no grave; as **2 telas pretas** de frase (v8 35–40 s) viram texto sobre a estrada/castelo (nada de preto no microtrailer).

| t (s) | v8 | v9 |
|---|---|---|
| 0–1,5 | TV liga 3 s sem música | TV liga 1,5 s, castelo no vidro |
| 1,5–4 | estrada + castelo | idem, **SIX ACTS.** palavra por grave |
| 4–14 | cartas, JOGAR | idem, **BUILD / A LIVING / DECK.** |
| 14–19 | encruzilhadas 2 e 4 | idem |
| 19–25 | drop 1: 5 salões | idem, nome do chefe em runa pixel |
| 25–33 | entradas | idem, **YOUR CARDS DECIDE WHAT SURVIVES.** |
| 33–38 | 2 telas pretas | frases sobre estrada/castelo (a confirmar se ficam) |
| 38–46 | porta + Rei entra | porta sintetizada, **EVERY BOSS IS A PUZZLE.** |
| 46–54 | drop 2 + luta | idem, número de dano enorme no pico |
| 54–60 | logo | selo sintetizado nos graves, **WISHLIST ON STEAM** |

### Critérios objetivos para comparar as versões
Medir em cada mp4 (script + folha de contato) e montar uma tabela:
1. **Gameplay até:** segundo do 1º quadro de captura real (meta ≤ 2 s; obrigatório < 4 s no 1º vídeo).
2. **Sem preto:** % de quadros com luminância média < 5 % (meta < 3 % fora da TV ligando e do glitch) → protege microtrailer e thumbnail.
3. **Sincronia:** distância de cada corte e de cada entrada de texto ao grave mais próximo do `_beats.json` (meta: mediana ≤ 1 quadro a 60 fps, máximo ≤ 3 quadros).
4. **Legibilidade:** cada cartão parado ≥ 1 s/13 caracteres; glifo ≥ 64 px; ≤ 30 caracteres/linha; 1 texto por vez. Teste mudo: 3 pessoas (ou o Daniel) dizem o gênero e o que se faz depois de ver mudo.
5. **Ritmo:** duração média do plano 2–4 s, com no máximo 2 rajadas < 1 s.
6. **Pico:** número de dano maior em 75–82 % da duração.
7. **Regra de 3:** gancho (carta viva / chefe-quebra-cabeça) aparece 2–3 vezes.
8. **Fecho:** cartão final 3–8 s, sem nada depois do CTA.
9. **Conformidade:** 0 asset de ElevenLabs/T4/sem licença (lista de origem por faixa e efeito); flashes ≤ 3/s; moldura do CRT presente em 100 % dos quadros após a TV ligar; só cenários válidos; −14 LUFS.
10. **Checklist Daniel:** os 11 itens do v7 + "sem cara de IA" + música contínua → marcar ok/não em cada versão.

**Recomendação inicial:** B como 1º vídeo da página; A como 2º vídeo/redes; C como substituto direto do v8 caso o Daniel prefira manter o desenho aprovado.

## Pendências
- Medir graves das duas faixas ACE-Step antes de qualquer corte (os segundos acima são nominais).
- Textos novos marcados ⚠️ ("EVERY CARD IS ALIVE.", "BEND EVERY HAND.", "PLAY./BREAK.") precisam passar pelo Daniel via chefe; se não, usar só os 5 aprovados.
- Confirmar se as 2 frases do v8 continuam no v9.
- Conferir o microtrailer real depois do upload (é com o Daniel).
