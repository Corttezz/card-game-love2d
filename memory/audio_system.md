---
name: Audio System
description: AudioManager (Balatro-inspired) com polifonia, grupos master/music/sfx, crossfade, settings persistidos via SaveManager
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
`engine/AudioManager.lua` (substitui o antigo `src/systems/AudioSystem.lua`, deletado). Exposto como **`_G.audioSystem`** em `main.lua`. Inspirado em `balatro-source/engine/sound_manager.lua` mas síncrono (sem `love.thread`).

**Por que mudou (Abril/2026):** o antigo cache flat `audioCache[name]` mantinha 1 source por som — não tocava o mesmo SFX duas vezes simultâneo, e `setSFXVolume` sobrescrevia o `baseVolume` original. Sem grupos, sem crossfade, sem persistência.

**Conceitos principais:**
- **Polifonia**: `sources[code].instances` é array; `play()` pega instância ociosa ou clona o template (até `MAX_CLONES_PER_SOUND=8`). Voice-stealing simples se exceder.
- **Grupos**: `master`, `music`, `sfx`. Volume final = `baseVolume * groupVol * master`, recalculado a cada `update(dt)`. Mudança de slider reflete imediatamente em sources tocando.
- **Crossfade**: `playMusic(code)` com música tocando dispara `musicCrossfade = {from, to, t, duration}` que `update(dt)` interpola.
- **Streaming auto**: `path:find("music")` ou `find("ambient")` → `Source(_, "stream")`.

**API pública (instance):**
- `loadSound(code, path, opts)` — opts: `{volume=1, group="sfx", stream=auto, pitch=1, pitchVariation=0, loop=false}`. Aceita `volume` numérico legacy.
- `play(code, opts)` — opts override por-call: `{volume, pitch, loop}`. Retorna a Source ou nil.
- `playSound(name)` — alias compat.
- `playMusic(code, opts)` / `stopMusic()` / `fadeOutMusic(d)` (silêncio com fade: `currentMusic` vira nil na hora, a faixa morre pelo crossfade com `to = nil`; ver [[music_generation]]).
- `setGroupVolume(group, v)` / `setMusicVolume`/`setSFXVolume`/`setMasterVolume` / `setVolume` (master).
- `update(dt)` — chamado em `love.update` (logo após EventManager).
- `getStatus()` / `printStatus()` / `isAudioAvailable()`.
- Compat: `loadBackgroundMusic`, `playBackgroundMusic`, `stopBackgroundMusic`.

**Trilha em seções (chefes, 15/Out/2026): DESLIGADA.** `src/systems/MusicSections.lua` encadeia faixas de um chefe chamando `playMusic` por seção (código `<chefe>:<seção>`), mas o dono rejeitou o resultado: `ENABLED = false`, nenhum chefe em `BOSSES`, mp3 fora do repo. Ver [[music_generation]].

**Quem escolhe a música é o `MusicDirector`** (observa o estado, ver [[music_map]]). Tela nenhuma chama `playMusic`/`stopMusic` para "preparar" a próxima: o `Sfx.fadeMusicOut` antigo baixava o volume do GRUPO e parava a faixa errada meio segundo depois (auditoria 15/Out/2026). Hoje ele é só um `silenceMusic`.

**Regra de ouro:** use `Sfx.play("name")` (de `src/systems/Sfx.lua`). Sfx é facade único — também expõe `Sfx.playMusic`, `Sfx.stopMusic`, `Sfx.setMusicVolume/setSfxVolume/setMasterVolume`. AudioManager é no-op gracioso se áudio indisponível (WSL2 sem driver).

**Persistência:** volumes / fullscreen / CRT / locale são salvos via `SaveManager.saveSettings(...)` quando alteram em `SettingsMenu`. `main.lua:love.load` chama `SaveManager.loadSettings()` ANTES de `AudioManager:new()` e passa os volumes no construtor.

**How to apply:** Som novo = (1) arquivo em `audio/` ou `audio/sfx/`, (2) `audioSystem:loadSound("name", path, Config.Audio.X_VOLUME)` em `main.lua` `love.load`, (3) `Sfx.play("name")`. Para SFX repetitivo (sword, click), passar `{pitchVariation=0.1}` no `loadSound` para variação automática de pitch e evitar fadiga auditiva.

**Pool de variantes com cooldown (corvos, 17/Out/2026):** `src/systems/CrowSfx.lua` registra por SCAN `audio/sfx/boss/crow/<momento>_<n>.mp3` como `crowAppear1..`, `crowDive1..`, `crowFlock1..`, `crowCine1..` e toca por MOMENTO (`CrowSfx.play("crowDive")`): sorteia variante sem repetir a anterior, pitch leve, cooldown por momento (1,2 s) e `CrowSfx.attack(h, hits)` agrupa a revoada (nunca um som por corvo). `BossCinematic.play` e `BossTrophy` desviam para ele quando o código é um momento de corvo. Relógio injetável (`CrowSfx.now`) e relógio que volta não trava. Modelo para outro som repetitivo que irrite: pool + cooldown + grupo, não um arquivo só. Licença: ElevenLabs FREE, sem uso comercial; regerar antes de vender (lista em `memory/known_gaps.md`). Detalhes e medição antes/depois: [[boss_mechanics]], "Som dos corvos".
