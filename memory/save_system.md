---
name: Save System
description: SaveManager + Migrations com atomic write e versionamento; RunManager e SettingsMenu delegam toda persistência aqui
type: project
---
`engine/SaveManager.lua` + `engine/SaveMigrations.lua`. Inspirado em `balatro-source/engine/save_manager.lua` mas síncrono e com formato Lua serializado (não `string_packer`).

**Arquivos persistidos** (relativos ao save dir do LÖVE):
- `settings.lua` — volumes (master/music/sfx), fullscreen, crtShader, locale
- `run.save.lua` — corrida ativa (RunManager.currentRun) + `version` + `savedAt`

**API pública (`SaveManager`):**
- `loadSettings()` → table com defaults backfilled (`DEFAULT_SETTINGS`).
- `saveSettings(settings)` → atomic write.
- `loadRun()` → roda `Migrations.run` antes de retornar; nil se ausente/corrompido.
- `saveRun(runData)` → embrulha em `{version, savedAt, runData}` e escreve.
- `hasRun()` / `deleteRun()`.
- `serialize(value)` — exposto pra debug (recursivo, suporta string/number/bool/table).

**Atomic write:** escreve `<path>.tmp`, valida via `love.filesystem.load` (parse ok), só então grava `<path>`. Se crash no meio, save real fica intacto. Limpa `.tmp` órfão na operação seguinte.

**Migrations:**
- `Migrations.CURRENT_VERSION = "1.1"` (atualizar quando schema mudar).
- `handlers["1.0"](payload)` muta `payload.runData` e seta `payload.version="1.1"`. Adicionar handlers conforme necessário.
- Loop com guard de 32 iterações (anti-infinito).

**Wired-up:**
- `RunManager:saveRun/loadRun/deleteSave/hasSavedRun` (linhas ~305-330) delegam direto ao SaveManager.
- `components/SettingsMenu:_persist()` é chamado em cada mudança (volume slider, fullscreen toggle, CRT toggle, language). Constrói o snapshot lendo `_G.audioSystem`, `love.window.getFullscreen()`, `CRTShader.isEnabled()`, `I18n.getLocale()`.
- `main.lua:love.load` carrega settings ANTES de inicializar AudioManager/CRT, aplica fullscreen pré-init.

**How to apply:**
- Schema mudou? Bump `Migrations.CURRENT_VERSION`, adicione handler pra versão antiga.
- Save novo (perfil, metrics)? Adicione path em `SaveManager.PATHS` + funções `saveX`/`loadX` análogas.
- Settings novo campo? Adicione em `DEFAULT_SETTINGS` (backfill automático no load) e persista no `_persist()` do SettingsMenu.
