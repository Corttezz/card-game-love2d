---
name: Known Gaps and Tech Debt
description: Lacunas conhecidas (atualizado pós-refactor fases 1-5) — cartas com effects={} sem efeito gameplay, orbes/strength_scaling ainda não implementados
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---

Pontos que já existem no código mas **não estão completos**. Tratar como "conhecido" — não criar tickets sem confirmar com o dev.

**Why:** evita a LLM "corrigir" coisas intencionalmente deixadas pela metade.

**How to apply:** antes de tocar nesses itens, cheque se há pedido explícito. Ao encontrar comentário TODO ou função comentada, respeite a intenção.

---

**1. Cartas Slay the Spire com `effects = {}`** — muitas cartas (mage_blizzard, warrior_berserk, rogue_envenom, etc.) têm descrições prometendo mecânicas que não foram implementadas. Só dano/defesa base funciona. Não assuma que "faz o que a descrição diz".

**2. Tipos de efeito declarados mas não processados:**
- `channel_orb` / `evoke_orb` (orbes do mago) — sem sistema de orbes.
- `strength_scaling` — sem stat Força no Player.
- `exhaust` / `innate` — mecânicas de deck não implementadas.
- `EffectSystem:processEffectCard` reconhece os tipos e retorna `false` para eles (não causa erro).

**3. `Game:isRunMode` setado por `startNewRun` mas nunca resetado em `gameOver`** — se jogador morre e volta ao menu via escape, `isRunMode` continua true até novo run. `returnToMenu()` resseta o jogo via `Game:new()` então OK, mas fluxos alternativos podem vazar estado.

**4. Fallback de imagem `theRock.png`** usado em quase todas as cartas novas — não é "estilo", é falta de arte. Ao criar PNG novo, substitua o campo `image` no `src/data/cards/*.lua`.

**5. `JokerSlot:drawEmptySlot` é quase vazio** — só renderiza um rect translúcido; o "+" e texto "VAZIO" foram removidos intencionalmente.

**6. Save/load persistente existe mas não há UI** — `RunManager:saveRun/loadRun/hasSavedRun/deleteSave` gravam em `run.save.lua` no save dir do love. Ainda não há botão "Continuar" no menu principal que chame `loadRun()`.

**7. `conf.lua` com `t.modules.touch = false`** — iOS deployment não está configurado. A skill `love2d-gamedev` tem doc em `references/ios/` para quando quiser.

**8. `Menu:onAboutClick`** continua placeholder (só imprime "em desenvolvimento"). Configurações (`onSettingsClick`) ainda é placeholder pois o acesso real é pela TopBar.

**9. `CardRewardScreen` tem muitos `print` de debug** — não foram limpos junto com os outros (tamanho do arquivo grande demais, cuidado).

**10. HUD ainda com gradientes 20-step e glow borders** — `src/ui/HudPanel.lua`, `HudPlayerPanel.lua`, `HudEnemyPanel.lua`, `CardInfoDisplay.lua`, `MessageSystem.lua` ainda usam `VisualEffects.Utils.drawRadialGradient` / `drawCircleWithGlow` / `rectangle(..., rx, ry)`. **Fora** do chrome de UI pixel atual (que cobriu Button/Menu/Settings/ClassSelection/TopBar/CardReward). Próxima passada mapeia essas 5 superfícies pra `PixelCanvas.rect` + `dither25` + `Palette.BUTTON_*`/`PANEL_*`. Ver `memory/ui_pixel_system.md` seção 6.

**11. ClassSelection "class cards" são só Buttons** — hoje cada classe (warrior/mage/rogue) aparece como um botão com texto + ícone de arma. Visual mais rico (arte de fundo, descrição, ícone grande) está fora de escopo. Quando for atacar, extrair `components/ClassCard.lua` componente dedicado, não customizar Button.

---

## Resolvidos no refactor recente (fases 1-5)

- ✅ `ClassSystem.lua` removido — `RunManager` usa `CardRegistry` direto.
- ✅ `src/MessageSystem.lua` duplicata removida.
- ✅ `src/systems/SmokeSystemExample.lua` + `src/ui/CardInfoDisplayExample.lua` removidos.
- ✅ `components/JokerCard.lua` removido (órfão, nunca foi require'd).
- ✅ `EffectSystem:getCardData` mocks removidos — lê `joker.effects` direto.
- ✅ `EffectSystem:applyTriggerEffects` wired em `Game:processCardInCombat` (attack/defend) e `enemyTurn` (turn_start).
- ✅ `apply_debuff`, `discard_cards`, `heal_multiplier` agora processados.
- ✅ Performance: `ImageCache` para ícones; `FontManager` em lugar de `newFont` espalhado.
- ✅ `love.resize(w, h)` implementado — reposiciona tudo e invalida cache.
- ✅ `GameUI` sem funções comentadas (drawPlayerInfo/drawEnemyInfo etc.).
- ✅ Menu principal com título "CARD GAME" (era "jogo" literal minúsculo).
- ✅ `conf.lua` versão 11.3 → 11.5.
- ✅ Arquivos `:Zone.Identifier` removidos.
- ✅ Saves persistem em `run.save.lua` via `love.filesystem`.
- ✅ `SettingsMenu` overlay (volume música/SFX/master + fullscreen toggle) acessível pelo ícone da TopBar.
