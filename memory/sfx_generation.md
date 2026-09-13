---
name: SFX Generation (ElevenLabs) — pipeline, contrato e validação
description: Como gerar efeitos sonoros novos pro jogo via ElevenLabs, o contrato de registro por scan, e como VALIDAR o som sem poder ouvi-lo (tools/check_sfx.lua). Inclui o formato canônico dos 71 sfx existentes.
type: project
---

# SFX Generation — ElevenLabs

Pipeline usado desde Jul/2026 pros SFX do jogo. A chave do ElevenLabs fica na
memória automática do Claude (`elevenlabs-api-key`) — é free tier, 10.000
créditos por ciclo, e o dono avisou que rotaciona. Se der 401, pedir a nova.

```
POST https://api.elevenlabs.io/v1/sound-generation
header: xi-api-key: <key>
body:   {"text": "...", "duration_seconds": N, "prompt_influence": 0..1}
→ audio/mpeg binário
```

## ⚠️ REGRA DO DONO — ÁUDIO É GENÉRICO, NUNCA POR IDIOMA

Set/2026, palavras dele:

> *"não é para termos áudios em certos idiomas, isso não pode acontecer. Áudios
> precisam ser genéricos. Apenas podemos ter textos em outros idiomas."*

**Só TEXTO é traduzido. Som é o mesmo para todos os jogadores.** Nada de
narração, nada de voz, nada de `codigo_<locale>.mp3`, nada de caminho de áudio
que varie com `I18n.current`.

Estado verificado (Set/2026, conforme):
- `src/i18n/I18n.lua` tem hook de **fonte** (`getFont`) e nenhum de áudio.
- Nenhum locale declara arquivo de som. As ocorrências de "sfx" nos locales são
  o RÓTULO do controle de volume ("Efeitos" / "Effekte"), não um asset.
- Nenhum caminho em `audio/` depende de locale.
- Os SFX são todos não-verbais: martelo, pano, vento, lacre, moedas, impactos.

Ao gerar som novo, o prompt deve sempre conter **"no voice"** — além de "no
music" e "no repeats". Som com fala embutida quebraria a regra sem ninguém
perceber até alguém jogar noutro idioma.

## Formato canônico (bate com os 71 sfx existentes)

**128 kbps CBR, 44100 Hz.** A API já devolve nisso — não precisa converter.

Consequência útil: **tamanho de arquivo ≈ duração**. Por isso 5 sfx diferentes
do projeto têm exatamente 20106 bytes e outros 8 têm 23031. Tamanho repetido
**não** indica arquivo duplicado; confira por checksum antes de suspeitar.

## Registro: por SCAN, com fallback

O contrato do projeto (mesmo dos sons-assinatura de joker) é declarar o som
ANTES de o arquivo existir. Em `main.lua`:

```lua
for code, path in pairs({
    forgeStrike = "audio/sfx/forge-strike.mp3",
    forgeReveal = "audio/sfx/forge-reveal.mp3",
}) do
    if love.filesystem.getInfo(path) then
        audioSystem:loadSound(code, path, 0.65)
    end
end
```

E no consumidor, `Sfx.has` escolhe e cai num genérico:

```lua
playFirst({ "forgeStrike", "restComplete" }, { pitch = 1.05 })
```

Assim soltar o arquivo em `audio/sfx/` faz ele tocar sozinho, sem tocar em
código, e a ausência nunca quebra nada. Nome do arquivo em `kebab-case`, código
em `camelCase`.

## VALIDAÇÃO — você não vai poder ouvir

Este é o ponto que custa caro se for ignorado. Header de MP3 válido **não diz
nada** sobre o que importa no design. Use `tools/check_sfx.lua`:

```
love . check_sfx           # todos (lento — ~71 arquivos amostra a amostra)
love . check_sfx forge     # filtra por substring (use isto)
```

Ele decodifica pelo LÖVE e mede: duração real, pico, RMS, instante do ataque e
os tempos de decaimento (t50/t10/t01 = tempo até cair a 50%/10%/1% do pico).

**Por que isso importa, com o caso real.** `forgeStrike` é disparado TRÊS vezes
com ~0,28s de espaçamento (as três marteladas da cerimônia da bigorna). Se a
cauda fosse longa, as três se somariam e virariam lama. Medido:

| arquivo | dur | pico | ataque | t50 | t10 |
|---|---|---|---|---|---|
| `forge-strike.mp3` | 0,88s | 0,963 | **0,00s** | 0,07s | **0,20s** |
| `forge-reveal.mp3` | 1,76s | 0,628 | 0,62s | 0,12s | 0,34s |

Ataque em 0,00s = percussivo de verdade. t10 = 0,20s < 0,28s de espaçamento =
quando a 2ª martelada bate, a 1ª já está abaixo de 10%. **Isso é verificável
sem ouvir, e é o que separa "gerei um arquivo" de "o som serve ao design".**

Repare também na hierarquia de pico: a martelada (0,96) é mais alta que o
reveal (0,63). O impacto manda; a resolução responde.

## ARMADILHA — a API devolve AR MORTO antes do evento

`duration_seconds` é a duração do ARQUIVO, não do som. O modelo frequentemente
põe o evento no meio e preenche o resto com silêncio/ruído de fundo. Caso real
(Set/2026): `card-shelf-place.mp3` pedido com 0,6s veio assim —

```
0.00s→0.34s   ruido de fundo (1-5% do pico)
0.40s         |####...####| 0.246   <- o toque, 60ms
0.46s         silencio
```

**0,34s de ar morto antes do evento.** O som toca N vezes em cascata com
stagger de 0,08s: o toque da carta 1 cairia em cima do VISUAL da carta 5. O
jogador não descreve isso como "o arquivo tem silêncio" — descreve como **"o
som não bate com a imagem"**.

**Sempre confira o ONSET**, não só a duração. No `check_sfx`, um `ataque` alto
num arquivo curto é o sintoma. O número sozinho é ambíguo (pode ser um envelope
que sobe de propósito) — por isso existe `tools/sfx_envelope.lua`, que desenha a
CURVA janela a janela em ASCII. **`check_sfx` dá os números; `sfx_envelope` dá a
forma, e foi a forma que pegou o defeito.**

Aparar sem perder qualidade (stream copy, zero reencode):
```bash
ffmpeg -ss 0.34 -i entrada.mp3 -c copy saida.mp3
```

## VOLUME — `opts.volume` SUBSTITUI, não multiplica

`AudioManager.lua:182`: o volume passado no call site **substitui** o
`baseVolume` do registro. E dois arquivos registrados no mesmo volume soam
muito diferente conforme o pico da amostra — então **calibre pelo pico medido,
não por palpite**.

Referência do projeto: `cardDraw` = 0.35 sobre pico 0,124 ≈ **0,043 efetivo**.

| som | pico | registrado | efetivo |
|---|---|---|---|
| `cardShelfPlace` | 0,246 | 0.22 | 0,054 |
| `shopLeaveWhoosh` | 0,764 | 0.50 | 0,38 |
| `cardDeselect` | **1,000** | 0.16 | 0,16 |

Repare no `cardDeselect`: a amostra veio **no talo** (pico 1,000). Registrar
0.30 nele estouraria sobre toda a UI. Palpite de volume sem olhar o pico é
chute.

**Calibração mora num lugar só** — no registro do `main.lua`, não nos call
sites. Com fallback de vários códigos (`playFirst({"a","b"})`), um volume no
call site valeria para todos eles.

## Tool que roda sozinho PRECISA de `love.event.quit()`

O `check_sfx` nasceu sem, e o dispatcher fazia `return` seco. Rodar por pipe
(`| grep`, `| tail`) travava para sempre e a saída nunca aparecia — duas
tentativas de medição foram atribuídas erradamente a "disputa pelo LÖVE com
outros agentes" quando a causa era o tool não fechar. Era o único da lista sem
`quit()`. Confira ao criar tool novo.

## Aviso que dispara sempre é aviso ignorado

A regra de [[ui_layout_invariants]] §3 (fallback silencioso é proibido) tem um
contrapeso: `playFirstSfx` só avisa quando `_G.audioSystem` EXISTE. Sem essa
condição ele gritaria em toda execução headless — tools, suíte, WSL2 sem áudio
— onde a ausência é esperada. Aviso que toca sempre vira ruído, e o dia em que
um código estiver escrito errado ele passa batido. **Avise na condição em que a
falha é anômala, não em toda condição em que o recurso falta.**

## Prompt — o que funcionou

O modelo tende a devolver sequências e ambiência. Force o oposto quando quiser
percussivo:

- **Diga que é UM evento**: *"One single heavy blacksmith hammer blow..."*
- **Descreva o envelope explicitamente**: *"hard immediate attack and a short
  tight ring that decays quickly"*.
- **Proíba o que não quer**, o modelo respeita: *"Dry and close, no reverb, no
  room echo, no repeats, no music."*
- `prompt_influence` 0,7–0,8 pra seguir de perto. `duration_seconds` perto do
  alvo: pedir 2s pra um impacto devolve 1,5s de silêncio no fim.

## Lacunas conhecidas (candidatas pra próxima leva)

- **Estouro de pacote é o mesmo som pros 5 tipos** (`packSealBreak` com pitch
  diferente). É o mesmo problema que o burst tingido tinha no visual e que já
  foi resolvido lá com arte por tipo — ver [[ui_layout_invariants]] §4.
- **SFX da viagem** do WorldRoad (backlog antigo).
- Fogueira/descanso, remoção e duplicação de carta ainda dividem
  `restComplete`.

## Ligações

[[card_feel]] · [[audio_system]] · [[joker_proc_fx]] · [[ui_layout_invariants]]
