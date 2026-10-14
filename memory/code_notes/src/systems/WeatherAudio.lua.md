---
name: code_notes/src/systems/WeatherAudio.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/WeatherAudio.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/WeatherAudio.lua`

Origem: `src/systems/WeatherAudio.lua` em `7dbdb60d` (11 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local WeatherAudio = {}`)

> src/systems/WeatherAudio.lua
> ============================================================================
> WEATHERAUDIO — o SOM do clima do WorldRoad (Out/2026, dono: "cada tipo de
> partícula precisa de som, e o som não pode ser um loop fixo e idêntico")
> ============================================================================
> Três camadas, todas lidas do estado do WeatherEngine (intensidade da
> chegada ao castelo, tempestade, rajada do capim, noite):
>
> CAMAS  (chuva leve/forte, vento, nevasca, grilos, brejo, brasas): cada
> cama é uma fila de VOZES que nunca dá loop — a voz toca uma vez,
> a partir de um ponto aleatório, com pitch próprio, e perto do fim
> entra a próxima variante (≠ da anterior) em crossfade. A emenda
> do arquivo nunca é ouvida e a cama nunca se repete igual (técnica
> do "ambi-patch" do Dead Space; camadas por superfície da chuva do
> Hunt: Showdown — pesquisa Out/2026).
> AVULSOS (gota, coruja, grilo, sapo, estalo de brasa, cristal de gelo,
> brilho de vagalume): intervalo, pitch e volume sorteados; nunca a
> mesma variante duas vezes seguidas.
> TROVÃO: 5 variantes escolhidas pela DISTÂNCIA do raio (perto = estalo
> seco e alto, longe = rumor baixo), atraso e volume pela distância,
> pitch ±8%, nunca o mesmo duas vezes seguidas.
>
> Arquivos em audio/sfx/weather/ (ElevenLabs, plano FREE — regenerar após
> assinar; lista em memory/weather_engine.md). Registro por SCAN: arquivo
> novo `rain-light-4.mp3` entra sozinho na cama `rain-light`.
> Grupo "sfx" (respeita master/sfx) e volume base Config.Audio.WEATHER_VOLUME.
>
> WATCHDOG: as camas só vivem enquanto o mundo é atualizado. Se o
> WorldRoad parar de chamar update (interior do chefe, loja, menu), o
> watchdog (main.lua, todo frame) esvazia as camas em fade curto.
> ============================================================================

## L42-44 (em `CAT_VOL`, junto a `local function clamp01(x) return math.max(0, math.min(1, x)) end`)

> camas e avulsos por bioma. gain(s) recebe o estado do clima.
> s.intensity 0..1 (sobe com a chegada ao castelo), s.storm 0..1,
> s.gust 0..~1.5 (|rajada| no centro), s.night 0..1, s.rain 0..1

## L150 (em `code`, junto a `function WeatherAudio.pick(group, vars)`)

> sorteio que NUNCA repete a anterior do mesmo grupo (se houver opção)

## L169-170 (em `WeatherAudio.registerSounds`, junto a `local base = Config.Audio.WEATHER_VOLUME * Config.Audio.AMBIENT_VOLUME`)

> AMBIENT_VOLUME: o knob ÚNICO do ambiente (dono: "muito alto — tem que
> ser ambiente de verdade"); grupo "ambient" = slider em Configurações

## L200-201 (em `startVoice`, junto a `if dur > FADE * 3 then pcall(src.seek, src, rng:random() * dur * 0.35) end`)

> começa num ponto aleatório (até 35% do arquivo): a mesma variante
> nunca soa igual duas vezes

## L214-215 (em `tickBed`, junto a `local d = target - bed.cur`)

> ganho da cama anda devagar rumo ao alvo (sem degrau ao mudar clima);
> rate opcional: sair da estrada pra um LUGAR corta em ~1 s

## L266-272 (em `fadeAll`, junto a `WeatherAudio.roadActive = true`)

> UPDATE — chamado pelo WorldRoad.update com o estado do WeatherEngine
>
> PORTÃO DE LUGAR (PlaceAudio): o clima da estrada só soa NA estrada. Fora
> dela (loja, forja, descanso, evento, recompensa, salão do chefe) as camas
> descem em ~1 s e avulsos/trovão calam — mesmo com o mundo ainda
> atualizando por baixo da tela.

## L293-294 (em `wanted`, junto a `wanted[fam] = true`)

> a mesma família pode aparecer em 2 biomas com variantes
> diferentes: a definição corrente manda

## L334 (em `WeatherAudio.thunder`, junto a `local name = WeatherAudio.pick("thunder", WeatherAudio.THUNDER[band])`)

> nunca a mesma variante do trovão ANTERIOR (de qualquer faixa)

## L353-354 (em `WeatherAudio.fireflyBlink`, junto a `WeatherAudio.tickBed = tickBed`)

> motor de camas compartilhado (PlaceAudio usa o mesmo: vozes em crossfade,
> variante nunca repetida). def = { family, vars, prefix }

## L358 (em `WeatherAudio.fireflyBlink`, junto a `function WeatherAudio.watchdog(dt)`)

> main.lua chama todo frame: mundo parado de atualizar = camas somem

