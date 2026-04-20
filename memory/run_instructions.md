---
name: Run Instructions
description: Como executar o jogo, atalhos de teclado, localização de docs e scripts auxiliares
type: reference
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
**Executar:** `love .` a partir de `/home/cortez/projects/card-game-love2d/`. O `conf.lua` está na raiz e define a janela (1024×768, resizable).

**Ambiente atual:** Linux 6.6 / WSL2. Som no WSL2 pode estar indisponível — cheque o banner `=== STATUS DO ÁUDIO ===` no console logo no load.

**Atalhos de teclado (durante gameplay):**
- `space` — compra uma carta do deck (toca hoverCard sfx).
- `r` — reinicia o jogo chamando `game:startGame()`.
- `f` — toggle fullscreen + `FontManager.clearCache()`.
- `esc` — volta ao menu (`returnToMenu()`).
- `1` / `2` / `3` / `4` — presets de smoke (subtle / default / atmospheric / intense).
- `0` — limpa smoke (`smokeSystem:clear()`).

**Gameover:** `r` tenta `startGame()` (sem classId, pode falhar se não estiver em run), `esc` volta ao menu.  
**Victory:** `space` reinicia, `esc` volta ao menu.

**Docs no repo (raiz):**
- `README.md` — overview em PT-BR.
- `AUDIO_README.md` — sistema de áudio + troubleshooting WSL2.
- `GUIA_NOVO_SISTEMA.md` — como adicionar cartas e decks.
- `SISTEMA_SLAY_THE_SPIRE.md` — doc do modo corrida / classes.
- `CLAUDE.md` — guia de contexto consolidado pra LLM (criado por este setup).

**Docs dentro de src/:**
- `src/systems/README_CombatAnimation.md`
- `src/systems/README_SmokeSystem.md`
- `src/ui/README_HudSystem.md`
- `src/ui/README_CardInfoDisplay.md`

**Scripts/helpers:**
- `setup-audio-wsl2.sh` — mencionado em AUDIO_README mas **não existe no repo atual**. Se o usuário pedir pra rodar, avisar que precisa ser criado.
- `skills-lock.json` — lock dos skills instalados (Claude Code), não é asset do jogo.
- `test.lua`, `test-audio/main.lua`, `test-game/main.lua` — scratchpads isolados, não fazem parte do jogo principal.

**Layout do memory dir (este diretório):**
`~/.claude/projects/-home-cortez-projects-card-game-love2d/memory/` contém `MEMORY.md` (índice) + arquivos temáticos. Atualize-os quando comportamentos mudarem.
