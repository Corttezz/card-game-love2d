---
name: Auditoria de áudio por momento do jogo (25/Out/2026)
description: Tudo o que toca (música, ambiente, SFX) em cada momento da run, o que faltava ou estava errado, o que a frente AUDIO-FLOW mudou (MusicMoments, duck, passa-baixa, stingers) e o que ainda pede o ouvido do dono. Inclui os prompts dos stingers gerados e a trava test_music_flow.
type: project
---

# Auditoria de áudio (25/Out/2026, frente AUDIO-FLOW)

Pedido do dono: "a entrada do mini-chefe não tem diferença nenhuma no som... quando
matamos o chefe final a música da luta continua tocando... quando ele morre a música
deveria parar devagar e ter uma passagem". Ver [[music_map]], [[audio_system]],
[[music_generation]], [[sfx_generation]].

## Como o fluxo funciona agora

- `MusicDirector.apply(estado, run, tipoDoNo, dt)` (main.lua, 1x por quadro) chama
  primeiro `src/systems/MusicMoments.lua`, que OBSERVA o jogo e dispara os momentos
  por BORDA (vivo → morto, estado novo, entrada começou). Borda vista nunca repete
  (`fired` por andar) e a primeira leitura depois de um Continuar só registra: retomar
  nunca toca sting de entrada nem de morte.
- Dados (volumes, ducks, tempos) em `src/data/music_stingers.lua`. Arquivos em
  `audio/sfx/stingers/<nome>.mp3`, registrados por SCAN em
  `MusicMoments.register` (chamado por `MusicDirector.registerTracks`), código
  `sting_<nome>`, grupo `sfx`. Arquivo ausente = `Debug.warn` + fallback no SFX antigo.
- `AudioManager` ganhou **duck** reutilizável, só no grupo `music`, multiplicado em
  `computeFinalVolume` (vale para crossfade, seções e loop):
  `duck(chave, ganho, ataque, segura, solta)` (envelope que se desfaz sozinho),
  `holdDuck(chave, ganho, ataque)` / `releaseDuck(chave, solta)` (estado contínuo),
  `clearDucks()`. Vários ducks: vale o MENOR. E **passa-baixa** na música:
  `setMusicFilter(highgain|nil)` (pcall no `Source:setFilter`, aviso uma vez se a saída
  não suportar).
- Silêncio continua sendo `MusicDirector.SILENCE`. `MusicMoments.override` força o
  silêncio (chefe morto no salão, jogador morto) e `MusicMoments.silenceFade` escolhe o
  fade (3,2 s na morte do chefe, 1,0 s na do jogador, 5 s no resto).
  `MusicMoments.holding(estado)` segura a faixa SEGUINTE enquanto um sting de fim
  ainda soa (game over 3,2 s, vitória 5,6 s): nada de música do menu por cima.
- Tela nenhuma mexe em música; o menu (`returnToMenu`) zera tudo (`MusicMoments.reset`).

## Tabela por momento

Legenda: OK = já estava bom; NOVO = mudado nesta frente; GAP = falta, não feito.

| momento | antes | agora |
|---|---|---|
| boot (IntroTube) | sem música, SFX do boot | OK |
| menu / seleção / coleção / conquistas | `menuMusic` contínua, `collectionFlip`, `menuHover` | OK |
| início da run, viagem | `musicAct1` 1,2 s, clima | OK |
| encruzilhada, hover e escolha | ato + `forkHover*` por tipo + `nodeSelect` | OK |
| início da batalha / turno do jogador | `TurnBanner` sem som | GAP: banner de turno mudo (barato: um "tic" grave no turno do inimigo) |
| jogar carta / impacto | `cardPlay*`, `CardFeel` por tema, `jokerTick` | OK |
| telegraph e golpe do inimigo | `enemyAttack`; voz por criatura é da frente ENEMY-VOICES | fora do escopo |
| bloqueio | `armorSound` / `cardPlayDefense` | OK |
| enfurecido | `enemyBuffRoar` no beat do Game | OK |
| morte de inimigo comum | `enemyDeath` + `battleVictory` no cash out (o chime REPETIA no Continuar) | NOVO: `victory_small` (1,2 s, duck 0,6) na morte; chime do cash out só se a morte foi vista nesta sessão |
| elite: entrada | nada diferente | NOVO: duck do ato a 0,75 durante a chegada + `elite_entrance` no fim (duck 0,55), volta ao volume cheio |
| elite: morte | igual comum | NOVO: `victory_elite` (1,9 s, duck 0,45) |
| mini-chefe: entrada (marquise) | nada diferente, faixa do ato inteira | NOVO: duck do ato a 0,45 ao longo da chegada, `miniboss_entrance` (subida reversa de 1,35 s + golpe grave) com o golpe batendo na parada/marquise, duck 0,30 no golpe e volta ao volume cheio ~3 s depois |
| mini-chefe: morte | igual comum | NOVO: `victory_elite` |
| bandeira do chefe, viagem, porta, salão, entrada | silêncio 5 s, SFX da `BossCinematic` | OK |
| luta, fases, mecânica-assinatura | faixa do chefe, `MusicReact`, `BossTokens` | OK |
| morte do chefe | a faixa do chefe SEGUIA tocando na morte, no troféu, no cash out e nos espólios | NOVO: fade de 3,2 s junto do câmera-lenta, `boss_pass` (2,2 s) em +2,4 s, silêncio com o ambiente do salão |
| troféu (coringa do chefe) | `bossRevealSting` | OK (o sting próprio dele) |
| fim do ato (cash out do chefe) | nada no fim do ato; `actComplete` só toca no 1º nó do ato SEGUINTE (`Game:nextPhase`, junto da cura entre atos; mantido, é o som da cura) | NOVO: `act_complete` 0,35 s depois de abrir o cash out do chefe, sem o chime comum; espólios em silêncio; o ato novo entra na encruzilhada |
| loja, descanso, evento, forja, pacote | faixas próprias, `PlaceAudio`, SFX dos objetos | OK |
| vida baixa | nada | NOVO: abaixo de 25% (sai acima de 30%): música a 0,80 + passa-baixa 0,45 + batimento (`boss_heartbeat`, 0,95 a 1,25 s, mais rápido quanto menor a vida). Sempre ligado, sutil (sem opção: a aba Jogo está cheia) |
| morte do jogador | `runDefeat` era chamado A CADA QUADRO durante o desligamento do CRT (0,9 s) e o menu entrava por cima | NOVO: corte da faixa em 1,0 s, `player_death` (2,5 s) uma vez, menu segurado 3,2 s e entra em 2,5 s |
| game over | `menuMusic` | OK depois da espera |
| vitória (chefe do ato 6) | `runVictory` A CADA QUADRO, `menuMusic` logo | NOVO: `boss_pass` na morte e `run_victory` (4,6 s, duas camadas solenes) na tela, menu segurado 5,6 s |
| maldição do endless | ato | OK |
| pausa, configurações, coleção, roteiro | mantém a faixa, `menuOpen/Close` | OK |

## Arquivos novos (`python tools/build_stingers.py` monta tudo; medido por ebur128)

| arquivo | duração | LUFS | pico | origem |
|---|---|---|---|---|
| `boss_pass.mp3` | 2,17 s | -14,4 | -4,2 | ElevenLabs |
| `player_death.mp3` | 2,48 s | -14,4 | -3,7 | ElevenLabs |
| `act_complete.mp3` | 1,88 s | -16,8 | -1,4 | ElevenLabs |
| `miniboss_entrance.mp3` | 3,77 s | -15,0 | -1,4 | ElevenLabs + subida reversa |
| `elite_entrance.mp3` | 1,30 s | -17,4 | -1,5 | recorte grave do mini-chefe (pitch 0,88) |
| `victory_small.mp3` | 1,21 s | -18,9 | -2,1 | `boss_death_thud` pitch 1,12 + eco |
| `victory_elite.mp3` | 1,85 s | -17,0 | -1,2 | `boss_death_thud` + `act-complete` pitch 0,84 |
| `run_victory.mp3` | 4,64 s | -15,4 | -2,3 | `boss_pass` pitch 0,78 + `act_complete` pitch 0,84, eco |

Referência: SFX existentes vão de -10 a -21 LUFS (`enemy-death` -13, `act-complete` -14,
`battle-victory` -21). Brutos em `tools/stingers_src/`.

Prompts (sound-generation, `prompt_influence` 0,5, 1 candidato cada, cota quase zerada):
- boss_pass (2,5 s): "Dark fantasy orchestral victory stinger after slaying a great monster: one heavy low brass chord swell with deep timpani hit and low strings, solemn and grim, not cheerful, decaying into a cathedral reverb tail. Single hit, no melody, no voice, no repeats."
- miniboss_entrance (2,5 s): "Dark fantasy tension stinger for a powerful monster appearing: one deep low drum boom hit, then a rising ominous swell of low strings and muted brass crescendo, cinematic. No melody, no voice, no repeats." (saiu como golpe com rufar decaindo, SEM subida: a subida é o próprio som invertido, feita no build)
- player_death (2,5 s): "Dark fantasy death sting for a fallen hero: a heavy distant low orchestral hit with deep gong and sub boom, then a dark low drone of cellos fading out, grim and final. No melody, no voice, no repeats."
- act_complete (2,0 s): "Dark fantasy chapter complete sting: a deep solemn low brass and timpani resolution hit with a soft low choir-less string swell, grim and earned, not cheerful, short reverb tail. No melody, no voice, no repeats."

## Prova

`love . test_one test_music_flow` cenários novos `miniboss_entrance` (mini-chefe e
elite: duck mínimo, sting 1x tocado DURANTE a entrada, volume cheio no fim, Continuar
sem sting; morte comum e de elite com o sting certo 1x), `boss_death_fade` (curva: 0,35
a 0,9 em 1 s, < 0,01 em 3,6 s, só desce; passagem 1x; silêncio no cash out e espólios;
`act_complete` 1x; Continuar nos espólios sem sting; ato novo na encruzilhada),
`player_death` (silêncio em ≤ 1,3 s, sting 1x, menu só depois de 3 s), `lowhp` (nível
0,7 a 0,9, filtro na fonte, 3 a 5 batimentos em 4 s, volta limpa). Os cenários de chefe
antigos (`boss`, `bossloop`, `end`) foram ajustados para a morte em silêncio e a
espera da vitória. Linhas do tempo (volume da música / ajuste, duck, filtro, estado,
eventos) em `tools/preview_out/audio_fluxo/*.png` (`tools/audio_timeline.lua`).

## Pontos fracos (pedem o ouvido do dono)

- Nenhum stinger foi OUVIDO: escolhidos por espectrograma, duração e LUFS. O
  `miniboss_entrance` e o `act_complete` têm pulsos rítmicos (rufar): conferir se não
  brigam com a faixa do ato.
- `elite_entrance`, `victory_small`, `victory_elite` e `run_victory` são montagens de
  material existente, não geração própria; regerar com cota.
- O duck da entrada do mini-chefe começa no início da viagem (o `EnemyEntrance` cobre a
  viagem toda): ~6 s de faixa a 45%. Se ficar longo, subir `ENTRANCE.mini_boss.preDuck`
  ou atrasar.
- Espólios do chefe ficam em silêncio (só ambiente) até a encruzilhada do ato novo.
