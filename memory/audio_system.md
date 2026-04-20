---
name: Audio System
description: AudioSystem WSL2-aware, exposto como _G.audioSystem, com fallback gracioso quando áudio não disponível
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
`src/systems/AudioSystem.lua`. Exposto como **`_G.audioSystem`** em `main.lua` (linha ~85) — é a única variável global do projeto.

**Problema que resolve:** WSL2 não tem áudio nativo. Sem essa camada, `love.audio.newSource` lança erros intermitentes e o jogo quebra ao carregar qualquer som.

**Funcionamento:**
- `detectWSL2()` lê `/proc/version` procurando "microsoft" ou "WSL2".
- `initializeAudio()` tenta múltiplos backends (pulse/alsa/directsound) via `pcall(love.audio.setVolume, 1.0)`.
- `testAudio()` tenta carregar e tocar `audio/clickselect2-92097.mp3` com pcall. Se sucesso, `audioAvailable = true`.
- Se não, imprime aviso mas não aborta — `loadSound`/`playSound` viram no-ops seguros.

**API pública:**
- `audioSystem:loadSound(name, path, volume)` — cacheia em `self.audioCache[name]`.
- `audioSystem:playSound(name)` — faz `sound:stop()` + `sound:play()` com pcall.
- `audioSystem:loadBackgroundMusic(path)` / `playBackgroundMusic()` — stream com loop.
- `audioSystem:setMusicVolume(v)`, `setSFXVolume(v)`, `setVolume(v)` (geral).
- `audioSystem:isAudioAvailable()` — sempre cheque antes de operações críticas.
- `audioSystem:printStatus()` — imprime banner `=== STATUS DO ÁUDIO ===` no console.

**Sons carregados em main.lua:**
- `hoverCard` (0.03 volume, Config.Audio.HOVER_VOLUME)
- `cardSelect` (0.2, CLICK_SELECT_VOLUME)
- `deckStart` (0.1, DECK_START_VOLUME)
- `swordSound` (0.7)
- `armorSound` (0.7)
- Música: `audio/music.mp3` com loop

**Regra de ouro:** `if _G.audioSystem and _G.audioSystem:isAudioAvailable() then _G.audioSystem:playSound("nome") end`. Nunca chame `love.audio.newSource` direto em código novo. Código antigo em `Game.lua`, `Card.lua`, `JokerCard.lua`, `CombatAnimationSystem.lua` ainda tem fallbacks locais — preservar mas não replicar.

**How to apply:** Adicionar novo som = (1) colocar arquivo em `audio/`, (2) registrar via `audioSystem:loadSound` no `love.load` em `main.lua`, (3) chamar `_G.audioSystem:playSound("nome")` onde precisar. Volumes default em `Config.Audio`.
