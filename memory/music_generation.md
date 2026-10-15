---
name: Music Generation — trilha por contexto, como foi gerada e como se valida
description: As 6 faixas ambientes do jogo (3 atos, boss, loja, descanso) e o pipeline real que as produziu — sound-generation com loop:true, não a API de música. Inclui o MusicDirector, tools/check_loop.lua e as três armadilhas que custaram rodadas.
type: project
---

# Music Generation — trilha por contexto

Seis faixas em `audio/music/`, 20s cada, em loop: `music-act1`, `music-act2`,
`music-act3`, `music-boss`, `music-shop`, `music-rest`. Geradas em Set/2026 a
pedido do dono ("uma por ato, por situação, na loja coisas que fazem sentido
com a estética do jogo").

## O caminho que funcionou NÃO foi o planejado

A skill `elevenlabs-music-generation` foi instalada em
`.agents/skills/elevenlabs-music-generation/`, mas **não foi usada**. Ela não
fala com o ElevenLabs direto: chama o **RunComfy CLI**, que é outra conta e
outro faturamento. `npm i -g @runcomfy/cli` falha (`npm error notsup`) e não há
`RUNCOMFY_TOKEN` no ambiente. O endpoint `/v1/music` do próprio ElevenLabs
responde **HTTP 402** na conta free.

O que produziu a trilha foi o **mesmo endpoint dos SFX**, com um parâmetro que
não está documentado no fluxo de efeitos:

```
POST https://api.elevenlabs.io/v1/sound-generation
{"text":"...","duration_seconds":22,"prompt_influence":0.5,"loop":true}
```

`"loop": true` faz o modelo compor pensando na volta — o resultado sai sem
fade nas pontas e serve como faixa ambiente. `duration_seconds` aceita 22s
nessa conta. **Prefira isto antes de pedir orçamento novo pro dono.**

## As três armadilhas

**-1. O prompt tem teto de 450 caracteres.** Passar disso devolve
`{"detail":{"type":"validation_error","code":"text_too_long", ...}}` — e, como
sempre, os 336 bytes do erro são gravados por cima do `.mp3`. Descrever
arranjo direito custa espaço, então conte os caracteres antes de mandar:
`python -c "import json;print(len(json.load(open('x.json'))['text']))"`.

**1. Travessão quebra a requisição.** Prompt com `—` interpolado no `curl -d`
volta como `{"detail":{"type":"invalid_unicode",...}}` — 95 bytes de JSON
gravados por cima do `.mp3`, que passa a existir e a estar corrompido. Escreva
o corpo num arquivo e mande com `--data-binary @corpo.json`, em ASCII.

**0. CLIMA produz retumbo; ARRANJO produz música.** Esta é a lição mais cara
da leva, e veio de uma queixa do dono: *"não pode ser a mesma música do menu
dentro de cada ato, cada ato tem que ser uma música diferente"*. Os prompts da
primeira versão descreviam atmosfera — "melancholic, distant drum, cold, vast,
oppressive". O modelo entregou quatro **retumbos graves quase idênticos**:
centroide espectral de 107, 173, 139 e 154 Hz para ato 1, ato 2, ato 3 e boss,
com ~85% da energia abaixo de 200 Hz. Cada arquivo passava sozinho em tudo.

O que consertou foi nomear o **arranjo**: instrumento que carrega a melodia,
andamento em BPM, modo, e quem fica em primeiro plano. Exemplo do ato 1 —
*"Medieval folk instrumental, 70 BPM, dorian mode. A plucked lute plays a clear
repeating melancholy melody in the foreground, a viola holds long notes
underneath, a soft frame drum keeps a slow steady pulse. Melody loud and
close."* Os mesmos quatro contextos foram para 1005, 2393, 541 e 1137 Hz.

**Adjetivo de humor não tem tradução sonora única; instrumento tem.**

**2. "Quieto" o modelo entrega como silêncio.** Pedir descanso "quiet, sparse,
almost silence" devolveu pico **0,043** — cem vezes abaixo das outras faixas.
Duas tentativas de reforçar o adjetivo ("quiet but PRESENT") não mudaram nada.
O que resolveu foi trocar o eixo da descrição: em vez de falar do volume, falar
do **primeiro plano** — *"Slow solo cello melody in the foreground, warm and
clearly audible... Instruments loud and close, room quiet."* Pico foi a 0,971.
**Descreva o arranjo, não o nível.** Nível se conserta depois com loudnorm;
arranjo não.

**3. O modelo cola fade-out mesmo com `loop:true`.** Metade das faixas veio com
a cauda a 0,35–0,45× da energia do começo. Não se ouve na primeira passada —
se ouve na virada, 22s depois, como se alguém religasse o som.

## Pós-processamento (ffmpeg, obrigatório)

```bash
# 1) nivelar por loudness, alvo diferente por contexto
ffmpeg -i in.mp3 -af "loudnorm=I=-18:TP=-1.5:LRA=11" -ar 44100 -b:a 128k out.mp3
#    atos -18 · boss -15 · loja -19 · descanso -21

# 2) fechar o loop: crossfade da faixa COM ELA MESMA (22s -> 20s)
ffmpeg -i in.mp3 -filter_complex \
 "[0:a]atrim=0:2.0,asetpts=N/SR/TB[h];[0:a]atrim=2.0,asetpts=N/SR/TB[b];\
  [b][h]acrossfade=d=2.0:c1=tri:c2=tri[o]" -map "[o]" -ar 44100 -b:a 128k out.mp3
```


**⚠️ O 2.0s do passo 2 é CHUTE, e chute errado dá DESNIVEL.** O corte vira as
DUAS pontas da faixa final: o trecho depois dele passa a ser o começo, e o
trecho antes dele, o fim. Se cair logo depois de um ataque, o fim fica muito
mais alto que o começo e o `check_loop` acusa. Aconteceu na refação do ato 1:
com 2.0s a razão prevista era **3,81x**; varrendo candidatos e escolhendo o
ponto em que o RMS dos 400ms ANTES e DEPOIS do corte é igual, caiu pra
**1,00x**. É uma varredura de dez linhas (decodificar mono 8kHz, comparar duas
janelas) e vale sempre — o melhor corte saiu em 7,3s, 4,3s, 6,0s e 1,6s nas
quatro tentativas, nunca em 2,0s.

O passo 2 é o que apaga fade-out e clique de uma vez: a emenda deixa de ser um
ponto e vira uma mistura. Custa 2s de duração e resolveu as 6 faixas.

**Nivele por LOUDNESS (LUFS), não por pico nem por RMS.** A faixa da loja é
esparsa (harpa, pico 0,85, RMS 0,03): por RMS pareceria quieta demais e o
ganho "corretivo" estouraria os picos. O gate do R128 mede o que se ouve.

## VALIDAÇÃO — `tools/check_loop.lua`

Criado nesta leva, porque `check_sfx` mede o arquivo inteiro e **não diz nada
sobre o ponto em que o fim encosta no começo** — que é exatamente onde mora o
defeito de música em loop.

```
love . check_loop          # todas
love . check_loop act      # filtra por substring
```

Mede, em ordem de importância: **salto** (amplitude da última amostra vs. a
primeira — o clique; acima de 0,05 se ouve), **razão** entre o RMS dos 400ms
finais e dos iniciais (fade colado pelo modelo; saudável entre 0,5× e 2,0×) e
**DC offset**. Pegou 4 das 6 faixas na primeira passada. Ele avisa sozinho:
`SALTO!`, `DESNIVEL!`, `DC!`.

## Estado atual das faixas (Set/2026)

| faixa | brilho | direção |
|---|---|---|
| `music-act3` | 0,19k | cellos/contrabaixo, ostinato dissonante, 50 BPM, frígio |
| `music-boss` | 0,39k | tambores de guerra + metais graves + tremolo agudo, 100 BPM |
| `music-rest` | 0,42k | violoncelo solo, melodia de ninar, fogueira ao fundo |
| `music-act1` | 0,78k | alaúde dedilhado (melodia AGUDA) + viola + tambor de moldura, 76 BPM, dórico — refeito em Set/2026 pra sair de cima do menu (0,51k); ver [[known_gaps]] |
| `music-act2` | 1,49k | cordas em arco + saltério + sino distante, 60 BPM, eólio |
| `music-shop` | 0,24k | alaúde + viola da gamba + tambor de mão, 85 BPM, mixolídio |
| `music-boss-eclipse` | 0,78k | **chefe final** (Out/2026): coral de catedral + órgão + sinos tubulares + taiko lento, 58 BPM, ré menor, virada dissonante com respiração; 30 s pedidos (o endpoint aceitou) → highpass 25 Hz (o cru tinha DC -0,015) + loudnorm -15 + emenda no corte de 8,3 s (razão 1,00) → 28 s; salto 0,0013 |

**A loja foi refeita uma segunda vez** (o dono: *"a música dentro da loja está
totalmente quebrada, toda bizarra"*). A versão anterior tinha brilho 6,01k —
cinco vezes mais aguda que qualquer outra faixa, com rolloff em 10,9 kHz, ou
seja, energia espalhada até o topo do espectro: chiado, não música. A causa
foi pedir **saltério/dulcimer e harpa**, que são metálicos e agudos por
natureza. Trocar a instrumentação para alaúde + viola da gamba + tambor de mão,
e proibir explicitamente a família aguda (*"no bells, no chimes, no harp, no
cymbals, no hiss"*), levou de 5417 Hz para 432 Hz de centroide.

**Instrumento errado não se conserta com adjetivo.** Pedir "warm" e "nothing
shrill" ao dulcimer não mudou nada; trocar o instrumento mudou tudo.

Os três atos ficam separados por fatores de 3× e 2,5× — que era o pedido.
Restam duas colisões de brilho que o tool aponta (`boss`↔`rest`, `rest`↔`act1`);
são contextos que raramente se seguem, e o brilho não captura timbre nem
dinâmica (o `rest` tem 1/3 do RMS do `act1`). **Tentar abrir o `act1` para
resolver isso saiu pela culatra**: a versão mais brilhante foi a 1,24k e passou
a colidir com o `act2` — trocar uma colisão entre contextos distantes por uma
colisão entre dois ATOS é regressão. Ficou a versão de 0,49k.

## Integração

**O `AudioManager` JÁ tinha crossfade** — `playMusic(code, {fadeDuration})`
cruza a faixa atual com a nova e é no-op se o código já está tocando. (Uma
versão anterior desta memória afirmava o contrário e mandava implementar.)

Registro em `main.lua` **por SCAN**, mesmo contrato dos SFX
([[sfx_generation]]): faixa ausente nunca quebra. Volume 0.6 no registro — já
vêm niveladas, **não calibrar por palpite no call site**.

`src/systems/MusicDirector.lua` decide qual toca. Desenho deliberado: ele
**observa** `currentState` todo frame no `love.update`, em vez de ser
notificado. Notificar exigiria instrumentar ~14 transições de estado espalhadas
pelo `main.lua`, e a que alguém esquecesse daria "música errada" — defeito que
não trava, não loga e só é notado por quem estiver ouvindo. Observar é
idempotente.

| Contexto | Faixa |
|---|---|
| menu, seleção, coleção, fim de jogo | `menuMusic` (audio/music.mp3) |
| combate/mapa por ato (endless fica no 3) | `musicAct1/2/3` |
| node `boss` (elite **não**) | `musicBoss`, fade rápido (1,2s) |
| loja | `musicShop` |
| descanso | `musicRest` |
| recompensa pós-batalha | **`nil` = mantém o que está tocando** |
| salão da **Rainha do Eclipse** (porta aberta: `GameplayScene.inBossRoom`, 4º arg `inHall` do `pick`) | `musicBossEclipse`, fade rápido; cash out/espólios mantêm |

A última linha é uma decisão, não um esquecimento: `cardReward` serve loja E
recompensa pós-luta com o mesmo state. Trocar de música na recompensa daria
quatro segundos de outro tema e volta. `tools/test_music.lua` (na suíte) existe
para impedir que alguém "simplifique" isso.

Fallback em cadeia (`musicBoss → musicAct3 → musicAct2 → musicAct1 →
menuMusic`): soltar só uma faixa nova em `audio/music/` já funciona.

Duas ferramentas, porque medem coisas diferentes:

- `love . check_loop` — as faixas fecham a volta? (salto, fade nas pontas, DC)
  **e são distinguíveis entre si?** A coluna `brilho` (cruzamentos por zero em
  kHz, proxy barato do centroide) acusa `RETUMBO!` abaixo de 0,15k, e o rodapé
  lista pares a menos de 20% de distância — porque **o defeito dos quatro
  retumbos não existia em nenhum arquivo isolado, só entre dois**, e nenhuma
  métrica de arquivo único jamais o pegaria.
- `love . check_music` — percorre os 15 contextos do jogo com o AudioManager
  DE VERDADE e o master em zero, e confere que o diretor e o `audioSystem`
  concordam sobre o que está tocando. Existe porque a suíte nunca executa
  `love.update`: foi assim que um `local` a mais no topo do `main.lua` passou
  verde em 35 suítes e derrubou o jogo no boot com *"function at line 367 has
  more than 60 upvalues"*. **`love.load` do main.lua está no teto de upvalues
  do Lua** — ali se usa `require(...)` inline, nunca um `local` no topo.

## Ligações

[[sfx_generation]] · [[audio_system]] · [[ui_layout_invariants]] · [[project_overview]]

## Silêncio antes do chefe e faixa POR CHEFE (14/Out/2026, pedido do dono)

Pedido: "imersão". Quando a bandeira do chefe aparece, a música do ato morre
devagar; nada toca na viagem, na porta e na entrada ("cerimônia") do chefe;
a trilha DELE só começa quando a entrada termina, e cada chefe tem a sua.

Linha do tempo no andar do chefe (decisão inteira em `MusicDirector.pick`,
pura; `apply` só executa):

| momento | estado / sinal | música |
|---|---|---|
| luta do mini-chefe, cash out, espólios | `playing` / `roundEval` / `cardReward` | ato (nil = mantém) |
| encruzilhada com nó `boss` em `run.pendingNodes` | `mapSelection` + `forkOffersBoss` | `SILENCE`: fade-out de `FADE_SILENCE` = 5 s |
| clique na bandeira, viagem, castelo, porta | `playing`, nó boss, `inHall == false` | silêncio |
| salão vazio + cinemática de entrada | `BossCinematic.phase() == "intro"` | silêncio (SFX da cinemática tocam) |
| fim da entrada ou pular | `inHall` e sem intro | `bossTrack(run)`, fade-in 1,2 s |
| luta, morte (fase `death`), cash out, espólios | mantém | faixa do chefe |
| encruzilhada do ato novo | `mapSelection` | faixa do ato novo |

- O silêncio é ESTADO EXPLÍCITO (`MusicDirector.SILENCE`), não nil: nil
  continua significando "mantém o que toca". `apply` chama
  `Sfx.silenceMusic` → `AudioManager:fadeOutMusic(d)`, que zera
  `currentMusic` na hora e deixa a faixa morrer pelo `musicCrossfade` com
  `to = nil`. `playMusic` por cima de um fade-out cruza a partir do ganho
  atual (`fromGain`); voltar à MESMA faixa no meio do fade a retoma do
  volume em que estava; `stopMusic` corta o fade-out. Ambiente
  (`PlaceAudio`/`WeatherAudio`) é grupo à parte e não é tocado.
- O tutorial (o corvo) já espera `GameplayScene.isQuiet`, que é falso
  enquanto a cinemática roda e a mão é dada, então ele fala depois da
  música começar sem nenhuma mudança.
- Continuar no meio da luta: `ResumeFlow` força `bossEntered` sem
  cinemática → `inHall` e sem intro → faixa do chefe direto.
- `inHall == nil` (quem chama `pick` sem cena) conta como salão; sem
  WorldRoad (`SCENE_MODE ~= "worldroad"`) também.
- Tabela única `MusicDirector.BOSS_TRACKS` (id → código). Arquivo por scan:
  `audio/music/boss-<id>.mp3` (`MusicDirector.bossFile`), registrado por
  `registerTracks` se existir; ausente → `FALLBACK` para `musicBoss` com
  `Debug.warn` uma vez. Chefe sem `enemyId` (save antigo) é deduzido do
  roster do ato; no endless sem `enemyId` cai na genérica. Mini-chefe e
  elite seguem com a faixa do ato.
- `eclipse_queen` usa o código `musicBossEclipse`: hoje toca o placeholder
  `music-boss-eclipse.mp3`; um `boss-eclipse_queen.mp3` carregado depois o
  substitui sem mudar código.
- Travas: `test_music` (pick puro de cada momento, 6 chefes, Continuar,
  morte, mini-chefe, endless; e no AudioManager real com master 0: fade de
  5 s ainda soa em 1 s e some no fim, faixa nova por cima do fade, retomar,
  stopMusic) + `test_resume`. `love . boss_rooms N` segue a mesma regra
  (chama `apply` por quadro; I = silêncio até o fim da entrada).

### Resolvido em 15/Out/2026: trilha do chefe EM SEÇÕES (ver seção no fim)

### As 6 faixas longas: BLOQUEADAS (14/Out/2026, histórico)

Pedido: 2 a 3 min por chefe, com seções e camadas (nada de loop de 28 s).
Nenhum caminho desta máquina gera isso:
- `POST /v1/music` → **402 `paid_plan_required`** ("Music API is not
  available for free users"), conta free com 747/10000 créditos usados.
- `runcomfy` não instalado e sem `RUNCOMFY_TOKEN`.
- `sound-generation` (o que fez as faixas atuais) vai a ~22-30 s; costurar
  seções independentes não garante tom/andamento.

Destrava com plano pago ElevenLabs (libera `/v1/music`, até 5 min, e uso
comercial) ou um token RunComfy. Quando gerar: salvar em
`audio/music/boss-<id>.mp3` (já registra sozinho), loudnorm -15 como o
`music-boss`, emenda pelo ponto de RMS igual e `love . check_loop boss-`.
Direção por chefe pedida pelo dono: rei-carniça (osso seco, coro grave de
monges, cordas sujas), lich (órgão, cravo dissonante, coro etéreo), tirano
(tambores de guerra, metais pesados, correntes como percussão), monarca
(sinos de gelo, cordas em tremolo, coro feminino frio), colosso (percussão
orgânica, drone grave/didgeridoo, metais abafados), rainha (coro grande,
órgão, cordas épicas, referência Radagon/Elden Beast).

## Trilha do chefe EM SEÇÕES (15/Out/2026, frente trilha-chefes)

Pedido do dono: *"sons muito bem trabalhados para cada seção de boss... não
quero esses sons repetitivos e lúdicos... pode utilizar o Eleven Labs... com
a maior qualidade, aproveitando ainda assim esse plano gratuito."*

Um loop de 20 s repetido É o monótono. Saída: cada chefe vira uma trilha de
**5 seções** no MESMO tom, BPM e banda, cada uma com papel diferente:

| seção | papel |
|---|---|
| `a` | tema (sempre abre a luta) |
| `b` | desenvolvimento: OUTRO instrumento carrega a melodia |
| `c` | ponte tensa (percussão cai, cromatismo, suspense) |
| `f1`, `f2` | fase final (toda a banda / dobra de andamento), só com o chefe a <= 50% |

Arquivos: `audio/music/boss/<id>/<seção>.mp3`, 20 s, 160 kbps.

### Tocador: `src/systems/MusicSections.lua`

- `scan(BOSS_TRACKS)` no `MusicDirector.registerTracks` só olha o disco;
  as fontes (stream) carregam na 1ª vez que o chefe toca.
- Cada seção é uma faixa comum do AudioManager com código
  `<códigoDoChefe>:<seção>` (ex. `musicBossTowerLich:b`). A troca é um
  `playMusic` com crossfade de `XFADE = 1,5 s`, então o "nunca duas músicas"
  é o do AudioManager (`stopOrphans` + crossfade), sem código novo nele.
- Troca quando a fonte passa de `duração - XFADE - LEAD` (o `tell()`), ou se
  ela já deu a volta (quadro travado). Próxima seção: sorteio (RNG próprio,
  cosmético) SEM repetir a anterior; fase 1 = `a,b,c`, fase final = `f1,f2`.
- `hpFraction()` lê `_G.game.enemy` (só `isBoss`; probe `hpProbe` nos
  testes). Ao cruzar 50% a troca vai para a final na PRÓXIMA BARRA
  (`240 / BPM`), não no meio do compasso. A final é TRAVADA por luta:
  regeneração (colosso) não volta ao tema. Continuar já abaixo da metade
  abre direto na final.
- Gancho único no `MusicDirector.apply`: `MusicSections.has(wanted)` antes
  do `resolve`; `_current` passa a ser o código da SEÇÃO que toca (o
  `check_music` e o espelho continuam concordando com o AudioManager).
  `MusicSections.trackOf(code)` devolve o código do chefe a partir da seção.
- Sem a pasta do chefe: tudo como antes (faixa única `boss-<id>.mp3` ou a
  genérica `musicBoss`). Seções têm PRECEDÊNCIA sobre a faixa única (a
  rainha deixou de tocar o placeholder `music-boss-eclipse.mp3`).
- Trava: `test_music` (`M.sections`): 6 chefes com >= 3 seções, final e
  BPM; 200 trocas sem repetir em cada fase; AudioManager real com master 0:
  abre em `a`, 7 seções encadeadas sem repetir, pico de 2 faixas no
  crossfade e 1 assentado, espera a barra, sobe para a final, não volta ao
  regenerar, ato novo assume sem seção por baixo, Continuar < 50% abre na
  final. O teste empurra o `tell()` com `seek` (no headless o laço do teste
  corre mais rápido que o áudio real).

### Geração: custo medido e orçamento

- `sound-generation`, `duration_seconds: 22`, `prompt_influence: 0.5`,
  `loop: true`. **Custo: 220 créditos por geração de 22 s (10 por
  segundo)**, medido pelo `character_count` do `/v1/user/subscription`. O
  contador ATRASA: mostra +0 em várias chamadas e salta depois (+1540 de
  uma vez); conte pela soma, não chamada a chamada.
- 34 gerações: 30 seções + 4 refeitas (`carrion_king/a`, `tower_lich/a`,
  `winter_monarch/a` e `c`, que saíram com timbre fora da família).
  Créditos: 747 -> **8227 de 10000** usados; restam **1773** no mês
  (reserva de 10% respeitada).
- Erro vem como JSON gravado por cima do mp3: o script aceita só arquivo
  com cabeçalho MP3 (`ID3` ou sync `FF Ex`) e > 20 kB.

### Prompts (ASCII, <= 450 caracteres)

Texto = `<cabeça> <banda> <corpo> Full mix, loud and close, no fade.`
Exceções: o `a` do tirano, do colosso e da rainha foi `<cabeça> <corpo>
<rodapé>` (sem a linha de banda, o corpo já a descreve); `b` e `f1` do
monarca usaram a banda antiga (sem "double basses, timpani").

- **carrion_king** (ato 1, corvos): `Dark medieval boss battle music,
  instrumental loop, 96 BPM, C minor.` Banda: `detuned church organ, low
  male monk choir humming, scraping low strings, bone clacks, deep frame
  drum`. a: órgão na melodia sobre ostinato de cordas; b: rabeca áspera na
  melodia, coro responde; c: tambor vira batida de coração, tremolo
  cromático, cluster dissonante no órgão, estalos secos "de bico"; f1:
  tudo fortíssimo; f2: tambores em dobro, rabeca e órgão em pergunta e
  resposta, coro em staccato.
- **tower_lich** (ato 2, runas): `Gothic dark fantasy boss battle music,
  instrumental loop, 84 BPM, E harmonic minor.` Banda: `harpsichord, cold
  violins, tubular bells, ethereal wordless choir, pizzicato basses,
  timpani`. a: violinos na melodia sobre arpejo de cravo; b: sinos na
  melodia, contracanto de violoncelo; c: ritual, coro em encantação sobre
  drone de órgão, pizzicato de relógio; f1: violinos em oitavas
  fortíssimo; f2: spiccato e cravo em uníssono, metais em colcheias.
- **abyss_tyrant** (ato 3, correntes e fogo): `Epic infernal boss battle
  music, instrumental loop, 120 BPM, D minor.` Banda: `taiko war drums, low
  brass horns and trombones, tuba, anvil hits, rattling iron chains as
  percussion, low strings`. a: metais graves na melodia; b: cordas graves
  na melodia, trombones respondem; c: forja, tuba e cordas em linha
  cromática, correntes e bigorna; f1: naipe de metais fortíssimo; f2:
  tambores em dobro, metais sincopados.
- **winter_monarch** (ato 4, geada): `Icy dark fantasy boss battle music,
  instrumental loop, 108 BPM, B minor.` Banda: `celesta, tremolo strings,
  glass bells, cold wordless female choir, low cellos and double basses,
  timpani, light snare`. a: celesta na melodia; b: coro feminino na
  melodia; c: violoncelo solo sobre contrabaixos, celesta "pingando gelo";
  f1: cordas e coro fortíssimo, caixa rufando; f2: spiccato e celesta em
  uníssono.
- **rot_colossus** (ato 5, raízes): `Primal swamp boss battle music,
  instrumental loop, 78 BPM, F minor.` Banda: `wooden log drums,
  didgeridoo drone, muted low horns, bass clarinet, bowed double bass,
  shaker rattles`. a: clarone na melodia sobre didgeridoo; b: trompas na
  melodia, clarone em contracanto; c: batida manca, contrabaixo cromático,
  chocalhos molhados e madeira rangendo; f1: trompas fortíssimo e tons
  tribais; f2: tambores em dobro, pergunta e resposta.
- **eclipse_queen** (ato 6, lua): `Majestic dark fantasy final boss battle
  music, instrumental loop, 66 BPM, G minor.` Banda: `harpsichord,
  wordless female choir, concert harp, cathedral organ, full strings,
  timpani`. a: coro na melodia; b: violinos na melodia, coro responde; c:
  o eclipse, voz feminina solo em lamento sobre drone de órgão, harpa em
  notas caindo; f1: coro e cordas fortíssimo, órgão rugindo; f2: cordas e
  cravo em uníssono, acordes enormes do coro.

Cada corpo diz: quem carrega a melodia em primeiro plano, quem acompanha,
o que a percussão faz e o papel da seção. O modelo responde ao ARRANJO
(lição 0); os corpos em inglês seguem esse molde, 300 a 446 caracteres.

### Pós-processamento (por seção)

1. `highpass=f=25` + `loudnorm` em DUAS passadas (`linear=true`), alvo por
   papel: `a`/`b` -16, `c` -17, `f1`/`f2` -15 LUFS (a final soa mais cheia
   de propósito; as faixas de chefe antigas medem -16,0/-16,3). Medido no
   arquivo final: a/b -16,4 a -16,9; c -17,4 a -17,9; f -15,3 a -15,9.
   Pico real (astats) <= -1,9 dBFS. Volume 0.6 no registro, igual às outras.
2. `alimiter=limit=0.84:latency=1` ANTES da emenda. **Armadilha nova:**
   limitador DEPOIS do `acrossfade` (ou sem `latency=1`) atrasa o sinal e
   o `check_loop` acusa SALTO de 0,1 a 0,27 em 17 de 30 arquivos.
3. Emenda pelo corte de RMS igual (janelas de 400 ms) entre 2,2 s e 9,0 s,
   desempatando pela amostra mais perto de zero no corte (só com RMS, a
   `eclipse_queen/f1` ficou com salto 0,0503). Cortes de 2,6 a 9,0 s.
4. `love . check_loop boss/`: 30 seções, **0 avisos** (salto, desnível, DC).

### Medições (ouvir não dá: medido)

Script numpy (scratchpad, não versionado): pulso por autocorrelação do
fluxo espectral, cromagrama 60 Hz a 2 kHz (tonalidade) e perfil de 24
bandas log de 40 Hz a 10 kHz (timbre, piso -3).

- **Andamento:** nas 30 seções o BPM pedido (ou o dobro/metade) é o pulso
  mais forte do arquivo (escore 0,94 a 1,38; 1,00 = o mais forte). As
  seções de um chefe andam juntas.
- **Mesma música dentro do chefe, outra entre chefes** (cromagrama: cos
  médio entre irmãs × contra os outros chefes; timbre: distância média):

| chefe | tonal dentro | tonal fora | timbre dentro | timbre fora |
|---|---|---|---|---|
| abyss_tyrant | 0,986 | 0,887 | 0,97 | 3,09 |
| carrion_king | 0,919 | 0,841 | 2,63 | 3,19 |
| eclipse_queen | 0,883 | 0,822 | 2,19 | 3,85 |
| rot_colossus | 0,922 | 0,812 | 2,27 | 4,36 |
| tower_lich | 0,863 | 0,835 | 2,22 | 3,13 |
| winter_monarch | 0,852 | 0,848 | 2,60 | 3,12 |

  O monarca é o mais solto na tonalidade (celesta e sinos de vidro dão
  cromagrama ruidoso), mas o timbre o separa. As 4 refeitas existem por
  causa desta tabela: na 1ª leva o `a` do rei, do lich e do monarca
  ficaram até 4,5 de timbre das irmãs (mais brilhantes; prompt sem a
  linha de banda).
- **Contra as faixas de ato:** distância de timbre de cada chefe à faixa
  do PRÓPRIO ato: rei/act1 4,70, lich/act2 4,19, tirano/act3 4,66,
  monarca/act4 6,35, colosso/act5 5,12, rainha/act6 3,34; sempre maior que
  a distância entre seções do mesmo chefe. O mais perto de algo é o tirano
  da genérica `music-boss` (1,23: as duas são tambores de guerra e metais),
  que agora só toca como fallback.
- O `check_loop` (1 dimensão, brilho por cruzamento de zero) agrupa as
  seções por chefe (média) e ainda junta 4 pares de chefes vizinhos em
  brilho; o perfil de 24 bandas acima os separa. Brilho médio: tirano
  0,45k, rei 0,49k, colosso 0,52k, lich 1,00k, rainha 1,03k, monarca 1,06k.

### Licença

Plano FREE do ElevenLabs: **sem uso comercial**. As 30 seções precisam ser
regeradas com plano pago antes da venda (mesmos prompts, mesmo
pós-processamento). Listado em [[known_gaps]] 0c.
