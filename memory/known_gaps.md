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

**3. Save/load persistente existe mas não há UI** — `RunManager:saveRun/loadRun/hasSavedRun/deleteSave` gravam `run.save.lua`. Ainda não há botão "Continuar" no menu principal. (Jul/2026: o save agora carrega `rngState` — seed + estado exato dos streams; migration 1.2.)

**4. `Game:isRunMode` setado por `startNewRun` mas pode vazar entre runs** — `returnToMenu()` reseta via `Game:new()` então OK no fluxo normal, mas atenção ao adicionar transições novas.

**5. `conf.lua` com `t.modules.touch = false`** — iOS deployment não está configurado.

**6. `Menu:onAboutClick`** continua placeholder.

**7. ~~`CardRewardScreen` ainda tem muitos `print` de debug~~** — ✅ resolvido na Fase 0 do refactor Balatro (Abril/2026). Prints viraram `Debug.log/trace/err`.

**8. HUD legacy FULL CLEANUP** — ✅ `HudPlayerPanel.lua` reescrito flat/sepia; ✅ `HudEnemyPanel.lua` removido; ✅ `ManaOrb.lua` adicionado; ✅ `StatusPill.lua` extraído (fonte única); ✅ `HudPanel.lua` + `VisualEffects.lua` removidos no refactor Abril/2026. **Pendente:** `CardInfoDisplay.lua`, `MessageSystem.lua` ainda com estilo visual legacy (gradients/glow).

**9. ClassSelection "class cards" são só Buttons** — visual rico ainda não extraído em `components/ClassCard.lua`.

**10. ~~Forge (Rest) usa IDs crus no label~~** — ✅ resolvido (F4 UI Overhaul): `RestScreen.enterForgeMode` mostra `cardData.name` + nível.

**11. Events não processa "perder HP"** — `apply.function` pode causar dano direto, mas alguns eventos complexos (Slay-style "troca carta pelo vizinho") não estão mapeados.

**12. `damage_per_turn` no player não é disparado pelo Game** — existe em `processTriggerEffect` mas `applyTriggerEffects("turn_start")` só roda no fim do enemy turn, então DoT do player vem só a cada 2 turnos lógicos. Provavelmente está ok, mas revisar se virar bug.

**13. Efeitos de combo que dependem de orbs** — `channel_burst` pop o mais antigo. Se player não tem orbs, é no-op silencioso. Aceitável.

**14. ~~Joker draw_extra (joker_004) virou damage_bonus~~** — ✅ resolvido na auditoria de gameplay (Abril/2026). Trigger `on_turn_start_draw` implementado em `EffectSystem:processTriggerEffect`; `joker_004` "Bobo da Corte" e `mage_creative_ai` "IA Criativa" agora compram +1 carta por turno conforme descrição.

**15. ~~`rogue_envenom` aproximado~~** — ✅ resolvido na auditoria de gameplay (Abril/2026). Trigger `on_attack_debuff` implementado; `rogue_envenom` agora aplica 1 stack de poison (duration 2) a cada ataque conforme descrição.

**16. Ícones de mini_boss e boss** — `NODE_META` usa `skull_crowned` pra ambos. Visualmente idênticos; diferenciar via cor/label.

**17. Editions/Seals existem mas não há fonte de spawn ainda** — Fase 3 implementou pipeline completo (`card.edition`/`card.seal` + shaders + gameplay + render). Falta: tarots/spectrals que aplicam editions, e booster packs Standard que sorteiam edition+seal aleatoriamente. Será fechado na Fase 5 (Booster Pack opening).

**18. ~~Forge mostra IDs crus~~** — ✅ resolvido junto com o item 10. Jul/2026 adicionou ainda o preview de forja no hover ("ATQ 8 → 10 · DEF 4 → 6").

**19. Forge não tem cinemática (dissolve+materialize)** — funcionalmente upgrada via `RunManager:upgradeCard`, mas a animação Balatro-style (carta entra → +N flutua → juice + sfx) ainda não está implementada. Reutilizar `CardRevealSequence`.

**20. Tarots/Spectrals/Planets ainda não existem** — Fase 5 adicionou `BoosterPackSystem` que gera Standard (cards normais + edition/seal) e Buffoon (jokers). Arcana/Celestial/Spectral packs caem em fallback genérico hoje. Fica pendente: (a) `src/data/cards/tarots.lua` com 6+ tarots que aplicam edition/seal em carta selecionada, (b) inventory em `run.tarots` (max 2), (c) UI de "usar tarot" que pede pra escolher carta do deck. Quando feito, atualizar `BoosterPackSystem.poolForKind` pra Arcana → tarots, Celestial → planets, Spectral → spectrals.

**21. Shop polish remanescente após F8 reformulation** — Layout principal está fiel ao Balatro source (2 rows: cards | vouchers+packs, reroll em column à esquerda). Polish ainda faltando:
- Voucher mostra `$G` em vez de `$6` quando localize cifrão pega errado. Verificar `I18n.t("$")` ou trocar pra hardcoded "$".
- Nomes dos packs ("Pacote Espectral" etc) ficam flutuando entre rows sem fundo de slot — desenhar background sutil no slot do pack.
- Sleeves PixelLab estão um pouco pequenos comparados ao voucher card. Aumentar scale ou diminuir voucher.
- Skip button "Pular" está embaixo no centro mas seria mais Balatro ele junto do reroll na column esquerda (button stack vertical: Next Round vermelho + Reroll verde). "Next Round" do Balatro é o equivalente ao "Continuar/Pular" nosso.

**22. Pity compartilhado rewards+loja é decisão de design** — `rng.meta.cardPity` é um contador só. Se um dia rewards e loja precisarem de pity separado, dividir em `meta.cardPity`/`meta.shopPity` (uma linha em `CardRegistry:rollRarity`).

**23. Locales es/fr/de não têm seção `status`** — caem no fallback `en` (padrão pré-existente do i18n). Inclui os tooltips novos da TopBar (`status.topbar_*`) e o `status.reward_rules`. Traduzir quando a seção status inteira for portada.

**24. Watcher de teste** — `love . test_systems` valida a entrega STS-improvements v1. NUNCA rodar com processo `love` do usuário aberto (guarda em tools + memória never-kill-user-processes).

**25. Save é slot ÚNICO sem diálogo** — "Jogar" com um save existente NÃO pergunta nada: a run nova sobrescreve o save antigo no primeiro checkpoint (padrão StS de slot único, mas o StS confirma antes). Se algum dia houver reclamação de "perdi meu save clicando em Jogar", adicionar confirmação no menu quando `SaveManager.hasRun()`.

**26. returnToMenu FAZ limpeza pesada (Jul/2026)** — `EventManager.clear()` + `runManager.currentRun=nil` + `Rng.clearActive()` ANTES de recriar o game. Motivo: callbacks agendados do game descartado re-salvavam a run abandonada e até puxavam `currentState` de volta pro jogo. Ao adicionar transições novas pro menu, passar SEMPRE por `returnToMenu()` (nunca setar `currentState="menu"` na mão).

---

## Resolvidos pela entrega STS-improvements v1 (Jul/2026)

Plano: `docs/plan/sts-improvements-v1.md` · detalhes: `memory/rng_and_offers.md`.

- ✅ **RNG sem seed** → `src/systems/Rng.lua`: 1 seed/run, 6 streams com getState/setState no save (migration 1.2). Decisões de run reprodutíveis; save-scum neutralizado.
- ✅ **Raridade flat** → pity acumulativo (+35%/oferta seca, garantia na 25ª) compartilhado rewards+loja, persistido no save.
- ✅ **Ofertas cegas ao deck** → afinidade por tags (+20%/tag forte, cap +60%), anti-duplicata na oferta, penalidade de cópias (×0.5 com 2+), filtro de classe na loja. Badge "AFINIDADE" + "?" com regras na tela de recompensas.
- ✅ **Upgrade cap 5 invisível** → forja INFINITA (Config.Game.UPGRADE_LEVEL_CAP=0), ganhos em Config.Offers (fonte única), preview na forja, linha "Forjada +N" no tooltip, oferta "Forja" paga na loja com custo crescente (5×1.35^n) e picker.
- ✅ **TopBar muda/opaca** → ato/andar visível, tooltip em todos os elementos, flash direcional no ouro, highlight de hover.
- ✅ **Rewards sem contexto** → título/subtítulo próprios, raridade NOMEADA por slot, skip "Seguir sem carta".
- ✅ **Eventos com custo escondido** → labels com `[+ganho / -custo]` data-driven; 4 eventos de deck novos (remover/duplicar/forjar/sangue↔ouro); no-repeat por ato via `run.eventHistory`; RestScreen virou picker genérico (`_G.openCardPicker`).

## Resolvidos pela auditoria de gameplay (Abril/2026)

- ✅ **Joker architecture**: jokers nunca mais entram em `currentDeck`/hand. Adquiridos via novo `Game:addJokerToRun` → `runManager.currentRun.jokers` (separado de `currentDeck`, padrão Balatro G.jokers). `addCardToRun` bifurca por `cardData.type`. Migration runtime em `RunManager:_migrateJokersFromDeck` cuida de saves antigos. Bug "mesmo joker jogado várias vezes" resolvido.
- ✅ **Strength/Dexterity dupla aplicação**: `applyCardEffects` antes somava `player.strength` quando o card declarava `strength_scaling`, E `Game:processCardInCombat` somava de novo via `statBonus`. Removidos os branches de `applyCardEffects`; o effect agora é flag-only (semântica para tooltips/validador).
- ✅ **Tipos de efeito órfãos**: `tag_observer_multiplier`/`tag_stack_bonus` removidos do `validate_cards.lua` (declarados em fase futura mas nunca implementados).
- ✅ **Triggers em cartas non-joker**: `applyTriggerEffects` agora também itera `context.sourceCard.effects` além de jokerSlots. Permite `warrior_flame_barrier` com `on_defend_damage` realmente refletir, sem precisar virar joker.
- ✅ **Cartas que mentiam**: `joker_004` (no-op), `warrior_flame_barrier` (effects vazio mas descrição prometia reflect), `mage_creative_ai` (instant draw em joker), `rogue_envenom` (damage_bonus em vez de poison). Todas honram a descrição agora.
- ✅ **Stat outliers**: `rogue_bouncing_flask` (atk 3→6), `rogue_venom_fang` (3→5), `mage_zap` (5→6), `mage_blizzard` (cost 1→2), `mage_meteor_strike` (atk 20→24).

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
