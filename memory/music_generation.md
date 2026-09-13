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

**1. Travessão quebra a requisição.** Prompt com `—` interpolado no `curl -d`
volta como `{"detail":{"type":"invalid_unicode",...}}` — 95 bytes de JSON
gravados por cima do `.mp3`, que passa a existir e a estar corrompido. Escreva
o corpo num arquivo e mande com `--data-binary @corpo.json`, em ASCII.

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
- `love . check_music` — percorre os 15 contextos do jogo com o AudioManager
  DE VERDADE e o master em zero, e confere que o diretor e o `audioSystem`
  concordam sobre o que está tocando. Existe porque a suíte nunca executa
  `love.update`: foi assim que um `local` a mais no topo do `main.lua` passou
  verde em 35 suítes e derrubou o jogo no boot com *"function at line 367 has
  more than 60 upvalues"*. **`love.load` do main.lua está no teto de upvalues
  do Lua** — ali se usa `require(...)` inline, nunca um `local` no topo.

## Ligações

[[sfx_generation]] · [[audio_system]] · [[ui_layout_invariants]] · [[project_overview]]
