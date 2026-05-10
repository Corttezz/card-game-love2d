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
- `playMusic(code, opts)` / `stopMusic()`.
- `setGroupVolume(group, v)` / `setMusicVolume`/`setSFXVolume`/`setMasterVolume` / `setVolume` (master).
- `update(dt)` — chamado em `love.update` (logo após EventManager).
- `getStatus()` / `printStatus()` / `isAudioAvailable()`.
- Compat: `loadBackgroundMusic`, `playBackgroundMusic`, `stopBackgroundMusic`.

**Regra de ouro:** use `Sfx.play("name")` (de `src/systems/Sfx.lua`). Sfx é facade único — também expõe `Sfx.playMusic`, `Sfx.stopMusic`, `Sfx.setMusicVolume/setSfxVolume/setMasterVolume`. AudioManager é no-op gracioso se áudio indisponível (WSL2 sem driver).

**Persistência:** volumes / fullscreen / CRT / locale são salvos via `SaveManager.saveSettings(...)` quando alteram em `SettingsMenu`. `main.lua:love.load` chama `SaveManager.loadSettings()` ANTES de `AudioManager:new()` e passa os volumes no construtor.

**How to apply:** Som novo = (1) arquivo em `audio/` ou `audio/sfx/`, (2) `audioSystem:loadSound("name", path, Config.Audio.X_VOLUME)` em `main.lua` `love.load`, (3) `Sfx.play("name")`. Para SFX repetitivo (sword, click), passar `{pitchVariation=0.1}` no `loadSound` para variação automática de pitch e evitar fadiga auditiva.
