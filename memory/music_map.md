---
name: Mapa da música e do ambiente por estado
description: Tabela de TODA transição do jogo (abertura, menu, run, atos, chefe, Continuar por estágio, cheat) com a faixa esperada, o fade e o que o ambiente faz; os 7 defeitos achados na auditoria de 15/Out/2026 com a causa e a trava test_music_flow (fluxo real pelo main.lua com fontes falsas).
type: project
---

# Mapa da música (auditoria de 15/Out/2026)

Pedido do dono: "revisar o áudio de todas as etapas... 100% nas trilhas". Quem
decide a faixa é o `MusicDirector`, que OBSERVA o estado a cada quadro
(`main.lua` `love.update` → `MusicDirector.apply(estadoMusical, run, tipoDoNo)`).
`pick` é puro e devolve: um código de faixa, `SILENCE` (fade-out explícito) ou
`nil` (mantém o que toca). Ver [[music_generation]] e [[audio_system]].

## Regras gerais

- **Uma faixa só.** `AudioManager:playMusic` para qualquer faixa órfã antes de
  montar o crossfade; durante um crossfade soam no máximo duas, e só as duas do
  crossfade.
- **A verdade é o `audioSystem.currentMusic`.** O espelho `MusicDirector._current`
  só vale sem áudio (WSL2, teste puro). Antes o diretor lia
  `currentMusic or _current`: quando alguém parava a faixa por fora, o espelho
  dizia "já toca" e o diretor nunca mais religava (defeito 1).
- **Fades:** faixa de chefe e saída do menu = 1,2 s; resto = 2,5 s; silêncio do
  chefe = 5 s; menu ao voltar (`Menu:enterWithIntro`) = 1,5 s.
- **Estados que mantêm (`KEEP_STATES` = cash out e espólios):** mantêm o que
  toca, MAS se o que toca é a faixa do menu ou nada (sem silêncio de chefe
  pedido), entra `MusicDirector.actTrack(run)`. Cobre o Continuar no cash out e
  a entrada no endless pela tela de vitória (defeito 4).
- **Seletor de cartas (`_G.openCardPicker`) não é o descanso.** Ele troca
  `currentState` para `rest` por baixo; o `main.lua` passa ao diretor o estado de
  ORIGEM (`restScreen.pickerFrom`), então a forja aberta da loja segue com a
  faixa da loja e a de um evento segue com a do ato (defeito 3).
- **Ponto de plugar a trilha do chefe:** `MusicDirector.bossTrack(run)` devolve o
  código; a tabela é `MusicDirector.BOSS_TRACKS` (id → código), arquivo
  `audio/music/boss-<id>.mp3`. Ausente → `musicBoss` com aviso.
  Instalada (17/Out/2026): só `boss-carrion_king.mp3` (ACE-Step, candidata B
  aprovada pelo dono); os outros cinco chefes ainda caem em `musicBoss`.
- **Chefe em seções** (`MusicSections`, 15/Out/2026): com `audio/music/boss/<id>/`
  o chefe toca seções `a/b/c/f1/f2`, cada uma uma faixa comum do AudioManager com
  código `<faixa do chefe>:<seção>`. Enquanto toca, `currentMusic` e
  `MusicDirector._current` guardam o código da SEÇÃO; `MusicSections.trackOf`
  devolve o do chefe. Troca de seção é um `playMusic` com crossfade de 1,5 s,
  então conta como crossfade normal (duas faixas só durante ele). As seções só
  avançam enquanto o diretor pede a faixa do chefe (`playing` no salão); na morte,
  no cash out e nos espólios (`nil` = mantém) a seção que tocava segue em loop
  até a encruzilhada do ato seguinte cruzar para o ato.
- **Ambiente** é grupo à parte (`ambient`): `PlaceAudio.placeFor(estado)` escolhe
  o lugar e `WeatherAudio` só soa com o lugar `road`. Clima sem atualização do
  mundo por 0,3 s de JOGO some em 0,4 s (watchdog; antes contava relógio de
  parede, defeito 6).
- **Loops de SFX de chefe** só existem dentro de uma sequência da
  `BossCinematic`; `finish`/`reset`/`InputFocus.hideAll` param todos.

## Tabela

| momento | estado | música | fade | ambiente |
|---|---|---|---|---|
| abertura (IntroTube, mergulho no CRT) | `boot` | nenhuma | n/a | nenhum (SFX do boot; `stopGroup("sfx")` no fim) |
| menu | `menu` | `menuMusic` | entra 1,5 s | nenhum |
| configurações (menu ou pausa), troca de idioma/volume | overlay | mantém, sem reiniciar | n/a | mantém |
| coleção, conquistas | `collection`/`achievements` | `menuMusic` contínua | n/a | nenhum |
| UnlockShowcase (revelações) | overlay no menu | `menuMusic` | n/a | nenhum |
| seleção de classe | `classSelection` | `menuMusic` contínua (defeito 2) | n/a | nenhum |
| início da run (viagem de chegada) | `playing` | `musicAct1` | 1,2 s | clima do bioma (estrada) |
| batalha comum, elite, mini-chefe | `playing` | `musicAct<n>` | 2,5 s | clima |
| encruzilhada | `mapSelection` | `musicAct<n>` | 2,5 s | clima |
| evento | `event` | `musicAct<n>` | 2,5 s | drone do evento |
| seletor aberto pelo evento | `rest` (origem `event`) | `musicAct<n>` contínua | n/a | forja/descanso |
| loja | `cardReward` + nó `shop` | `musicShop` | 2,5 s | sala da loja + sino |
| forja aberta da loja | `rest` (origem `cardReward`) | `musicShop` contínua | n/a | forja |
| descanso / forja do descanso | `rest` | `musicRest` | 2,5 s | fogueira / forja |
| pacote | overlay | mantém | n/a | mantém |
| cash out, espólios | `roundEval`/`cardReward` | mantém (ou ato, ver regra) | n/a | "reward" |
| bandeira do chefe na encruzilhada | `mapSelection` + `forkOffersBoss` | silêncio | sai em 5 s | clima |
| viagem, porta, salão vazio, entrada do chefe | `playing` boss, fora do salão ou fase `intro` | silêncio | n/a | clima / sala do chefe |
| luta do chefe | `playing` boss, no salão, sem cinemática | `bossTrack(run)`: seções `a` → `b`/`c` sem repetir; ≤ 50% de vida sobe para `f1`/`f2` na próxima barra | entra 1,2 s; seção a seção 1,5 s | sala do chefe |
| morte do chefe (fase `death`, troféu) | `playing` | mantém (nunca começa a faixa na morte) | n/a | sala do chefe |
| cash out e espólios do chefe | `roundEval`/`cardReward` | faixa do chefe | n/a | "reward" |
| encruzilhada do ato seguinte | `mapSelection` | `musicAct<n+1>` | 2,5 s | clima do bioma novo |
| último chefe morto | `victory` | `menuMusic` | 2,5 s | nenhum |
| pausa (Esc), Deck/Coringas/Roteiro/Guia (D/J/M/G) | overlay | mantém, sem reiniciar; crossfade em curso termina | n/a | clima some na batalha (mundo congelado) e volta ao fechar |
| game over | `gameOver` | `menuMusic` | 2,5 s | some |
| entrar no endless (vitória → cash out) | `roundEval` | `musicAct6` (defeito 4) | 2,5 s | "reward" |
| endless (atos, chefes, maldição) | igual aos atos; chefe do endless com `enemyId` → faixa dele, sem → `musicBoss` | | | |
| voltar ao menu pela pausa / abandonar | `menu` | `menuMusic` | 1,5 s | clima e lugar somem; loops de chefe param |
| Continuar: batalha | `playing` | `musicAct<n>` | 1,2 s | clima |
| Continuar: cash out / espólios | `roundEval`/`cardReward` | `musicAct<n>` (defeito 4) | 1,2 s | "reward" |
| Continuar: loja / descanso / evento | idem | `musicShop` / `musicRest` / ato | 1,2 s | do lugar |
| Continuar: encruzilhada | `mapSelection` | ato | 1,2 s | clima |
| Continuar: encruzilhada com a bandeira | `mapSelection` | silêncio (menu sai em 5 s) | 5 s | clima |
| Continuar: luta do chefe | `playing` boss | faixa do chefe (sem repetir a entrada) | 1,2 s | sala do chefe |
| janela perde o foco / minimiza | qualquer | segue tocando (decisão: sem mudo automático); o laço cai para 15/8 FPS com `dt` real, os fades seguem no tempo de relógio | | |
| cheat: Ctrl+B/E/M/C/L/D/V, F9/F10/F11, Ctrl+1..6, Ctrl+Shift+1..6, F2/F3, rush F12 | os mesmos estados acima | a regra do estado de destino; pulos no meio de um fade assentam na faixa certa | | |

## Defeitos achados (15/Out/2026)

1. **Música parada que o diretor nunca religava** (`MusicDirector.apply`: `atual =
   tocandoAgora() or MusicDirector._current`). Qualquer parada por fora deixava o
   espelho mentindo. Correção: com áudio, a verdade é `currentMusic`; se a faixa
   pedida é a atual mas a fonte parou, religa.
2. **"Jogar" e "Continuar" chamavam `Sfx.fadeMusicOut(0.5)`** (`components/Menu.lua`),
   que baixava o VOLUME DO GRUPO `music` pelo EventManager e depois chamava
   `stopMusic()` 0,55 s depois. Na seleção de classe: silêncio até voltar ao menu
   (e a coleção junto). No Continuar: o `stopMusic` atrasado matava a faixa do ATO
   que o diretor tinha acabado de cruzar, e a do menu (sem crossfade) voltava a
   volume cheio DENTRO da run; no cash out/espólios, silêncio. Se o
   `EventManager.clear()` do `returnToMenu` caísse na janela de 0,5 s, o grupo
   `music` ficava preso num volume menor que o da configuração. Correção: o menu
   não mexe mais na música (o diretor cruza); `Sfx.fadeMusicOut` virou
   `silenceMusic` e nunca mais toca no volume do grupo.
3. **Forja aberta da loja trocava para `musicRest`** e, ao fechar, a da loja
   voltava do ZERO (o `crossfade` termina com `stop()`, que rebobina). O mesmo
   no seletor de cartas de eventos. Correção: `restScreen.pickerFrom`.
4. **Estados que mantêm herdavam a faixa do menu**: Continuar no cash out ou nos
   espólios e "Seguir no Endless" (vitória → cash out) tocavam `menuMusic` até a
   encruzilhada. Correção: `KEEP_STATES` + `actTrack`.
5. **Faixa do chefe vazava no clique da bandeira** (`GameplayScene.inBossRoom`):
   `bossEntered` do chefe ANTERIOR seguia verdadeiro até a cena processar o andar
   novo, e o diretor (que roda antes da cena no quadro) via "no salão, sem
   cinemática" e começava a faixa do chefe por ~3 s, cortada pelo silêncio da
   viagem. Correção: o salão vale só para o andar em que foi aberto
   (`bossEnteredKey`).
6. **Watchdog do clima por relógio de parede** (`WeatherAudio.watchdog` comparava
   `love.timer.getTime()`). No jogo normal quadro e relógio andam juntos, então
   o jogador não ouvia; mas qualquer simulação mais rápida que o relógio (as
   ferramentas, a trava abaixo) deixava o clima tocando no menu. Correção:
   ociosidade contada em `dt` de jogo (determinístico).

7. **A fase final das seções do chefe nunca entrava no jogo real**
   (`MusicSections.hpFraction` lia `_G.game`, que o `main.lua` nunca define; o
   `test_music` passava porque injeta `hpProbe`). Correção: lê
   `GameplayScene.getGame()` (o jogo que a cena desenha) e só cai em `_G.game`
   sem cena. A trava de fluxo baixa a vida do chefe para 40% e
   exige `f1`/`f2`.

## Trava

`love . test_one test_music_flow` (na suíte): dá boot no jogo inteiro pelo
`main.lua` com `love.audio.newSource` trocado por fontes falsas
(`tools/fake_audio.lua`: registram play/stop/volume/posição, duração lida do
arquivo, silêncio real, master intacto) e percorre a tabela acima, inclusive
idas e voltas rápidas, pausa no meio de crossfade, cheat no meio de fade, matar
o chefe na entrada, Continuar em cada estágio. A cada quadro: no máximo duas
faixas audíveis e só se forem as do crossfade, nenhuma instância duplicada,
nenhuma acima do volume das configurações (seções de chefe incluídas: a
comparação é pela faixa do chefe via `trackOf`). Em cada ponto: exatamente a faixa
esperada (ou silêncio) em volume cheio; nas transições que mantêm, a mesma
fonte sem reiniciar; no menu, nenhuma fonte de música órfã, nenhum ambiente e
nenhum loop de SFX. `MUSIC_FLOW_ONLY=boss,continue` roda só alguns cenários;
`MUSIC_FLOW_VERBOSE=1` imprime a linha do tempo.

Fora do escopo desta auditoria (decisões, não esquecimentos): mudo automático ao
perder o foco (o jogo segue tocando; se o dono quiser, é uma opção nova em
Configurações → Áudio, não um padrão); o trovão/coruja avulso
toca até o fim mesmo saindo da estrada (é um evento único de poucos segundos).
