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
| `music-act1` | 0,49k | alaúde dedilhado + viola + tambor de moldura, 70 BPM, dórico |
| `music-act2` | 1,49k | cordas em arco + saltério + sino distante, 60 BPM, eólio |
| `music-shop` | 0,24k | alaúde + viola da gamba + tambor de mão, 85 BPM, mixolídio |

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
