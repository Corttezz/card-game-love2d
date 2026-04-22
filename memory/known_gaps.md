---
name: Known Gaps and Tech Debt
description: Lacunas conhecidas após redesign completo (fases 1-8); o que é intencional vs pendente
type: project
---

# Known Gaps

**Why:** evita a LLM "corrigir" coisas intencionalmente deixadas pela metade.

**How to apply:** antes de tocar nesses itens, cheque se há pedido explícito. Ao encontrar comentário TODO, respeite a intenção.

---

## Ainda abertos (pós-redesign)

**1. Cartas ainda com `effects = {}`** — 12 cartas (starter/básicas): `warrior_strike`, `warrior_defend`, `rogue_strike`, `rogue_defend`, `attack_001`, `defense_001`, etc. Isso é **intencional**: são âncoras de tag (`#strike` / `#defend`) sem efeito adicional, balanceadas por combos. Rodar `love . validate_cards` para ver lista atualizada.

**2. Fallback de imagem `theRock.png`** usado em muitas cartas — não é estilo, é falta de arte. Pipeline de sprite via pixel-mcp está em `memory/sprite_design_queue.md`. Ao gerar PNGs, substituir campo `image` no `src/data/cards/*.lua`.

**3. Save/load persistente existe mas não há UI** — `RunManager:saveRun/loadRun/hasSavedRun/deleteSave` gravam `run.save.lua`. Ainda não há botão "Continuar" no menu principal.

**4. `Game:isRunMode` setado por `startNewRun` mas pode vazar entre runs** — `returnToMenu()` reseta via `Game:new()` então OK no fluxo normal, mas atenção ao adicionar transições novas.

**5. `conf.lua` com `t.modules.touch = false`** — iOS deployment não está configurado.

**6. `Menu:onAboutClick`** continua placeholder.

**7. `CardRewardScreen` ainda tem muitos `print` de debug.**

**8. HUD legacy FULL CLEANUP** — ✅ `HudPlayerPanel.lua` reescrito flat/sepia; ✅ `HudEnemyPanel.lua` removido; ✅ `ManaOrb.lua` adicionado; ✅ `StatusPill.lua` extraído (fonte única); ✅ `HudPanel.lua` + `VisualEffects.lua` removidos no refactor Abril/2026. **Pendente:** `CardInfoDisplay.lua`, `MessageSystem.lua` ainda com estilo visual legacy (gradients/glow).

**9. ClassSelection "class cards" são só Buttons** — visual rico ainda não extraído em `components/ClassCard.lua`.

**10. Forge (Rest) usa IDs crus no label** — mostra `warrior_strike +1` em vez de `Golpe +1`. I18n/lookup por cardData.name fica pendente.

**11. Events não processa "perder HP"** — `apply.function` pode causar dano direto, mas alguns eventos complexos (Slay-style "troca carta pelo vizinho") não estão mapeados.

**12. `damage_per_turn` no player não é disparado pelo Game** — existe em `processTriggerEffect` mas `applyTriggerEffects("turn_start")` só roda no fim do enemy turn, então DoT do player vem só a cada 2 turnos lógicos. Provavelmente está ok, mas revisar se virar bug.

**13. Efeitos de combo que dependem de orbs** — `channel_burst` pop o mais antigo. Se player não tem orbs, é no-op silencioso. Aceitável.

**14. Joker draw_extra (joker_004) virou damage_bonus** — mecânica de "compra extra por turno" não tem hook próprio ainda (`on_turn_start_draw`). Por ora jokers que tinham `draw_extra` foram convertidos para `draw_cards` ou `damage_bonus`.

**15. `rogue_envenom` aproximado** — no design, deveria aplicar 1 poison por ataque via trigger `on_attack_debuff`. Trigger ainda não existe; efeito mapeado como `damage_bonus +1` temporariamente.

**16. Ícones de mini_boss e boss** — `NODE_META` usa `skull_crowned` pra ambos. Visualmente idênticos; diferenciar via cor/label.

---

## Resolvidos pelo redesign (fases 1-7)

- ✅ **Tags** (Fase 1): toda carta tem tags normalizadas via `TagSystem`.
- ✅ **channel_orb / evoke_orb** (Fase 2): implementados em `EffectSystem` + `Player.orbs` (slots, addOrb/popOldestOrb) + `_evokeOrbEffect` (lightning/ice/dark/fire/holy).
- ✅ **strength_scaling / dexterity_scaling** (Fase 2): Player tem `strength`/`dexterity`; `applyCardEffects` soma no damage path.
- ✅ **exhaust** (Fase 2): remove carta permanentemente da run ao final da batalha via `_exhaustedThisBattle`.
- ✅ **innate** (Fase 2): cartas com `innate=true` são promovidas ao topo do deck em `Game:promoteInnateCardsToTop`.
- ✅ **mystery** (Fase 2): sorteia de pool fixo.
- ✅ **poison DoT** (Fase 2): processado em `Enemy:onTurnEnd` (duration em turnos, stacks).
- ✅ **weak / vulnerable** (Fase 2): reduzem/amplificam em `Enemy:performAttack`/`takeDamage`.
- ✅ **ComboSystem** (Fase 3): 11 regras ativas, tag-aware, compõe com jokers.
- ✅ **Mapa/Nodes** (Fase 4): `MapManager` gera escolhas tipadas; `MapScreen` UI; state `mapSelection`.
- ✅ **Atos + Endless** (Fase 5): 3 atos × 8 andares, bosses fixos, endless exponencial.
- ✅ **Rest / Event** (Fase 6): telas dedicadas; pool de 10 eventos.
- ✅ **Starter deck de 2 cartas** (Fase 5): warrior/mage/rogue começam com 1 attack + 1 defense.
- ✅ **Rebalance massivo** (Fase 7): 96 cartas com tags, effects coerentes, números contra curva.
- ✅ **Discard pile + reshuffle** (fix pós-Fase 7): cartas jogadas vão pra `game.discard`; quando o deck esvazia, reembaralha. Fix crítico pra starter de 2 cartas funcionar.

---

## Resolvidos em refactors anteriores (fases iniciais)

- ✅ `ClassSystem.lua` removido — `RunManager` usa `CardRegistry` direto.
- ✅ `src/MessageSystem.lua` duplicata removida.
- ✅ `EffectSystem:getCardData` mocks removidos.
- ✅ Saves persistem em `run.save.lua` via `love.filesystem`.
- ✅ `SettingsMenu` overlay acessível pela TopBar.
