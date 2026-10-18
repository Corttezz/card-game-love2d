---
name: music_reactive
description: Cenário que reage à música do chefe (17/Out/2026). Cues medidos OFFLINE (tools/music_cues.py → src/data/music_cues/<id>.lua: hit/swell/drop), engine/MusicCues lê a posição real da fonte e dispara, MusicReact traduz em tremor leve, detritos do teto (engine/CeilingDebris), pulso das chamas pintadas e respiro do chefe. Opção "Cenário reage à música" na aba Jogo. Trava test_music_react.
type: project
---

# Música reativa no salão do chefe

Pedido do dono (17/Out/2026): "sempre que tinha uma bateria forte, um batuque
forte, um grave forte ou uma parte impactante, a câmera podia tremer um pouco.
Talvez caíssem algumas pedrinhas do céu... ou o boss interagir." A palavra que
manda é **de leve**: a leitura da luta vem primeiro.

## Pipeline

1. **Análise offline** — `python tools/music_cues.py [ids] [--no-png] [--dry]`
   lê `audio/music/boss-<id>.mp3` (e as genéricas `music-boss.mp3` e
   `music-boss-eclipse.mp3`, chave `music_boss` / `music_boss_eclipse`) via
   ffmpeg (mono 12 kHz, quadros de 10 ms) e escreve
   `src/data/music_cues/<chave>.lua`:
   `{ track, duration, cues = { { t, kind, power[, dur] }, ... } }` em segundos
   do ARQUIVO.
   - **hit**: onset na banda 20-150 Hz (Butterworth 4ª ordem): subida de dB em
     30 ms, pico local em ±100 ms, acima de 2,2× a média móvel de 3 s + 1,5 dB e
     com nível grave acima do percentil 45 da faixa. `power` = raiz(onset
     normalizado × nível normalizado). Densidade: intervalo mínimo 0,35 s, no
     máximo 2 em qualquer janela de 2 s, `power` ≥ 0,30, ganham os mais fortes;
     nada nos primeiros 0,25 s (borda do arquivo).
   - **swell**: energia total suavizada em 1 s subindo ≥ 6 dB em 2,5 s, ≥ 60%
     dos quadros subindo, ≥ 1,5 s até o topo. Leva `dur`.
   - **drop**: média dos 0,8 s seguintes ≥ percentil 60 e ≥ 7 dB acima do
     1,5 s anterior; nota = salto + metade do salto GRAVE contra os 4 s
     anteriores (sem isso a volta do "breakdown" do Rei aos 57,8 s perdia para
     um respiro curto aos 62,9 s). Um drop a cada 12 s no máximo; encaixa no
     onset mais forte em ±0,2 s. Hit a menos de 0,35 s de um drop sai.
   - **Validação por medição** (não dá pra ouvir): o tool imprime % dos hits
     no pico de energia grave e o percentil do nível grave no hit, e desenha
     `tools/preview_out/musica_reativa/cues_<chave>.png` (forma de onda, curva
     grave em verde, hits vermelhos, swells azuis, drops amarelos) +
     `_drop.png` com zoom de ±6 s no primeiro drop. OLHE o PNG.
2. **Tempo de jogo** — `engine/MusicCues.lua` (genérico, sem dado do jogo):
   `MusicCues.new(data)`, `tracker:update(pos, fire)`. A primeira leitura só
   posiciona (nunca dispara). Cue com atraso > `LATE_MAX` (0,15 s) é pulado
   em silêncio: pausa, modal, foco perdido ou quadro travado NUNCA geram
   rajada. Posição que volta mais de 0,5 s = volta do loop: dispara a cauda só
   se ainda couber no atraso e recomeça do cue certo. Não depende de como o
   loop é feito (loop nativo da fonte ou seek para um `loopStart`): só lê a
   posição.
3. **Reação** — `src/systems/MusicReact.lua`, chamado pelo
   `GameplayScene.update` todo quadro com `{ fighting, bossId, hall }`.
   `fighting` = salão do chefe aberto neste andar (`inBossRoom`), sem
   `BossCinematic.phase()` (entrada e morte ficam de fora) e chefe vivo. Além
   disso só age se a faixa tocando (`audioSystem.currentMusic`, sem crossfade
   para outra) é código de chefe (`MusicDirector.isBossCode`) com arquivo de
   cues, e com a opção ligada. Posição = `template:tell("seconds")`. Combate
   congelado por modal não chama o update; ao voltar o salto é pulado.
   Dados por chefe em `src/data/music_reactions.lua` (`BY_BOSS`, `DEFAULT`,
   `STYLES`, `AREA` por salão em coordenadas da ARTE 400×256, `COOLDOWN`):
   - **hit**: `ScreenShake.trigger` de 0,8 a 1,6 px por 0,12 s (cooldown 0,45 s,
     respeita o slider de tremor); pulso curto das chamas pintadas
     (`InteriorFX.musicPulse`, canal próprio, multiplica chamas e pulsos do
     salão); poucos detritos (cooldown 0,3 s).
   - **drop**: tremor até 3,2 px por 0,3 s (cooldown de drop 4 s), luz mais
     forte, chuva de detritos, e o chefe **respira**: sobe 1-2 px de arte por
     0,55 s (`EnemyRenderer.musicBreath`, recusado se `isBusy()`: atacando,
     tomando dano, empurrão ou clip diferente de idle) + a aura brilha
     (`BossAura.musicPulse`, só os `glows`).
   - **swell**: a luz sobe devagar e cai um fio de detritos pela duração.
   - Detritos (`engine/CeilingDebris.lua`): pool fixo de 120, zero alocação
     por quadro, nascem logo abaixo da barra superior (y 16-40 da arte: o teto
     de verdade fica atrás da TopBar), caem até uma linha de chão sorteada e
     somem em 0,45 s. Desenhados logo depois de `InteriorFX.draw`: ATRÁS do
     chefe, do HUD e das cartas. Temas: Rei-Carniça poeira clara + penas roxas,
     Lich poeira + lascas de runa, Tirano pedrinhas + brasas, Monarca neve +
     lascas de gelo, Colosso esporos, Rainha partículas de luz.
4. **Opção** — `settings.musicReact` (padrão LIGADO, `SaveManager`), linha
   "Cenário reage à música" na aba **Jogo** (`settings.music_react` nos 5
   locales). As abas de Configurações passaram a ter `MAX_ROWS = 6` (estavam
   todas cheias com 5). Desligada: nada. `reducedMotion`: zero tremor, zero
   detrito, chefe parado; fica só o pulso de luz × 0,35.

## Números (17/Out/2026)

| faixa | duração | hit | swell | drop |
|---|---|---|---|---|
| carrion_king | 85 s | 43 | 4 | 3 (7,5 / 57,8 / 72,8 s) |
| music_boss (genérica) | 20 s | 15 | 1 | 1 |
| music_boss_eclipse | 28 s | 14 | 1 | 0 |

Rei-Carniça: 91% dos hits no pico grave, nível grave médio no percentil 95.
Na faixa inteira o tremor ocupa 7% do tempo; menor intervalo entre tremores
0,88 s.

## Travas e ferramentas

- `love . test_one test_music_react` (na suíte): disparo na ordem e no quadro
  certo com posição falsa, volta do loop sem duplicar, salto sem rajada, fora
  da luta/faixa não-chefe/opção desligada = nada, reducedMotion zera tremor e
  detrito e deixa luz ≤ 0,3, cooldown (menor intervalo ≥ 0,34 s, tremor < 1/3
  da faixa), todo `boss-<id>.mp3` instalado tem cues em ordem.
- Capturas: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_musica_reativa
  carrion_king:drop` (ou `:hit`, `:swell`) → quadros antes / impacto / +0,3 s /
  +0,9 s + folha em `tools/preview_out/musica_reativa/`.
- Faixa nova de chefe: rode `python tools/music_cues.py <id>`, olhe o PNG,
  confira `test_music_react`.

## Limites conhecidos

- O tremor é o `ScreenShake` global: mexe a tela inteira (cartas inclusas), por
  isso o teto é baixo. Um tremor só do mundo exigiria um offset na passada do
  salão do `GameplayScene`.
- Com `loopStart` > 0, a cauda do loop é tratada com atraso calculado a partir
  de 0 (conservador: pode pular um cue nos últimos 0,15 s da volta).
- O decoder de mp3 da LÖVE e o ffmpeg podem divergir no atraso do encoder
  (~25 ms): imperceptível para tremor.
