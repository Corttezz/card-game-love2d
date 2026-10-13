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

**0. ASSETS DE ORIGEM DESCONHECIDA (Out/2026) — resolver ANTES de vender.** Os créditos agora dizem só o que é verdade de forma genérica (música/SFX gerados com ElevenLabs; arte gerada com PixelLab e editada pelo desenvolvedor; fonte Grimoire Pixel = Press Start 2P modificada, OFL; LÖVE zlib). Os arquivos abaixo NÃO se encaixam nessa frase com certeza — ninguém sabe de onde vieram. Não apagar (alguns estão em uso); documentar a origem ou substituir:
- `audio/music.mp3` (trilha do menu)
- `audio/hoverCard.wav`
- `audio/deckStart.mp3`
- `audio/clickselect2-92097.mp3`, `audio/sword-sound-260274.mp3`, `audio/punching-light-armour-87442.mp3` — o sufixo numérico tem cara de download da Pixabay (licença própria, permite uso comercial, mas precisa confirmar o arquivo exato)
- PNGs antigos: `assets/cards/**` (theRock, bloodSword, rage, secondWind, seeingRed, ironShield, manaCrystal, potionOfHealing, back), `assets/icons/*.png` (armor/attack/coin/deck/mana), `assets/jokers/*`, `assets/backgrounds/step1.png`
Ver também a seção de licenças em `memory/release_pipeline.md`.

**0b. SFX gerados no ElevenLabs FREE (sem uso comercial) — regerar com plano pago antes de vender.** Lista dos que entraram depois do levantamento geral (o lote antigo está em `memory/release_pipeline.md`): `audio/sfx/joker-sig/joker_combo_volley.mp3`, `joker_combo_wall.mp3`, `joker_combo_pair.mp3` (Out/2026, coringas de combo; prompts em `tools/generate_sfx.py`, regerar com `python tools/generate_sfx.py <id>`).

**1. Cartas ainda com `effects = {}`** — 12 cartas (starter/básicas): `warrior_strike`, `warrior_defend`, `rogue_strike`, `rogue_defend`, `attack_001`, `defense_001`, etc. Isso é **intencional**: são âncoras de tag (`#strike` / `#defend`) sem efeito adicional, balanceadas por combos. Rodar `love . validate_cards` para ver lista atualizada.

**2. Fallback de imagem `theRock.png`** usado em muitas cartas — não é estilo, é falta de arte. Pipeline de sprite via pixel-mcp está em `memory/sprite_design_queue.md`. Ao gerar PNGs, substituir campo `image` no `src/data/cards/*.lua`.

**3. ~~Save/load persistente existe mas não há UI~~** — ✅ Continuar existe (F1) e, desde Out/2026, retoma o ESTÁGIO certo (ver [[save_system]]). Texto antigo: — `RunManager:saveRun/loadRun/hasSavedRun/deleteSave` gravam `run.save.lua`. Ainda não há botão "Continuar" no menu principal. (Jul/2026: o save agora carrega `rngState` — seed + estado exato dos streams; migration 1.2.)

**4. `Game:isRunMode` setado por `startNewRun` mas pode vazar entre runs** — `returnToMenu()` reseta via `Game:new()` então OK no fluxo normal, mas atenção ao adicionar transições novas.

**5. `conf.lua` com `t.modules.touch = false`** — iOS deployment não está configurado.

**6. ~~`Menu:onAboutClick` placeholder~~** — ✅ Out/2026: link "Créditos" no rodapé do menu → `components/CreditsScreen.lua` (atribuição LÖVE/zlib e Press Start 2P/OFL).

**7. ~~`CardRewardScreen` ainda tem muitos `print` de debug~~** — ✅ resolvido na Fase 0 do refactor Balatro (Abril/2026). Prints viraram `Debug.log/trace/err`.

**8. HUD legacy FULL CLEANUP** — ✅ `HudPlayerPanel.lua` reescrito flat/sepia; ✅ `HudEnemyPanel.lua` removido; ✅ `ManaOrb.lua` adicionado; ✅ `StatusPill.lua` extraído (fonte única); ✅ `HudPanel.lua` + `VisualEffects.lua` removidos no refactor Abril/2026. **Pendente:** `CardInfoDisplay.lua`, `MessageSystem.lua` ainda com estilo visual legacy (gradients/glow).

**9. ClassSelection "class cards" são só Buttons** — visual rico ainda não extraído em `components/ClassCard.lua`.

**10. ~~Forge (Rest) usa IDs crus no label~~** — ✅ resolvido (F4 UI Overhaul): `RestScreen.enterForgeMode` mostra `cardData.name` + nível.

**11. Events: custos de sangue** — ✅ Out/2026: `loseHealth` (armadura não paga) e nunca matam; opção impagável desabilitada (`Events.canAfford`). Pendente o resto: **Events não processa "perder HP"** — `apply.function` pode causar dano direto, mas alguns eventos complexos (Slay-style "troca carta pelo vizinho") não estão mapeados.

**12. `damage_per_turn` no player não é disparado pelo Game** — existe em `processTriggerEffect` mas `applyTriggerEffects("turn_start")` só roda no fim do enemy turn, então DoT do player vem só a cada 2 turnos lógicos. Provavelmente está ok, mas revisar se virar bug.

**13. Efeitos de combo que dependem de orbs** — `channel_burst` pop o mais antigo. Se player não tem orbs, é no-op silencioso. Aceitável.

**14. ~~Joker draw_extra (joker_004) virou damage_bonus~~** — ✅ resolvido na auditoria de gameplay (Abril/2026). Trigger `on_turn_start_draw` implementado em `EffectSystem:processTriggerEffect`; `joker_004` "Bobo da Corte" e `mage_creative_ai` "IA Criativa" agora compram +1 carta por turno conforme descrição.

**15. ~~`rogue_envenom` aproximado~~** — ✅ resolvido na auditoria de gameplay (Abril/2026). Trigger `on_attack_debuff` implementado; `rogue_envenom` agora aplica 1 stack de poison (duration 2) a cada ataque conforme descrição.

**16. ~~Ícones de mini_boss e boss~~ RESOLVIDO (Out/2026)** — mini-chefe ganhou ícone próprio `skull_horned` (NODE_META + Roteiro) e marco próprio no fork da estrada (`landmark_miniboss`, estandarte de crânio chifrudo com tochas).

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

**25. ~~Save é slot ÚNICO sem diálogo~~** — ✅ Out/2026: "Jogar" com save abre `ConfirmDialog` ("Começar nova corrida?"). Texto antigo: Save é slot ÚNICO sem diálogo — "Jogar" com um save existente NÃO pergunta nada: a run nova sobrescreve o save antigo no primeiro checkpoint (padrão StS de slot único, mas o StS confirma antes). Se algum dia houver reclamação de "perdi meu save clicando em Jogar", adicionar confirmação no menu quando `SaveManager.hasRun()`.

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

## Pacotes gêmeos: Arcano e Celestial são o MESMO pacote (Set/2026)

`src/systems/ShopSystem.lua` define `pack_arcana` e `pack_celestial` com
parâmetros **idênticos** — `cost = 4`, `weight = 1.0`, `size = 3`,
`choose = 1` — e em `BoosterPackSystem.generateContents` os dois caem no mesmo
ramo, com o mesmo pool e os mesmos pesos de raridade do ato. São dois nomes,
duas artes e duas trilhas de som para **um conteúdo**.

Descoberto ao renomear os pacotes (os nomes antigos eram os cinco do Balatro
traduzidos, e as descrições prometiam "tarôs", "planetas" e "espectrais" —
categorias que **não existem neste jogo**). Os nomes e descrições foram
corrigidos para dizer a verdade; o conteúdo duplicado **não**.

**Decisão do dono, Set/2026: renomear agora, diferenciar depois.** Nome
honesto não conserta pacote duplicado, mas parar de mentir já é ganho, e
diferenciar mexe em balanceamento e pede playtest.

O que JÁ foi feito nessa linha: o Espectral (Mortalha do Coveiro) ganhou
contrapartida — ele dá 2 cartas onde os irmãos dão 3, pelo mesmo preço, e
ainda é o mais raro de aparecer (`weight = 0.3`); agora nenhuma delas é comum
(piso de raridade em `generateContents`, travado em `tools/smoke_packs.lua`).
A contrapartida é raridade e não edição **de propósito**: edição e selo são o
que torna o Fardo do Mercador único, e duplicar isso repetiria o erro dos
gêmeos um nível acima.

Quando for diferenciar, o gancho existe: `pack.kind` já chega no gerador, e
basta ramificar nele. Ideias descartadas por agora, registradas para não se
perderem: pool por tag/elemento, garantia de upgrade, escolha entre 2 com
edição garantida.

## A musica do ATO 1 soa como a do MENU (Set/2026, medido e NAO corrigido)

`love . check_loop` passou a incluir `audio/music.mp3` (a faixa do menu mora
fora de `audio/music/` e por isso nunca tinha sido medida em 9 meses). Ao
entrar na varredura ela revelou uma colisao que ninguem sabia que existia:

    music-act1.mp3       0.49k
    music.mp3 (menu)     0.51k     <- 4% de distancia

Quatro por cento. Pela regra do proprio tool (faixas a menos de 20% soam
iguais), o jogador sai do menu e entra no ato 1 ouvindo praticamente o mesmo
timbre. E exatamente a familia de queixa que o dono ja fez uma vez ("nao
pode ser a mesma musica do menu dentro de cada ato").

**Deliberadamente NAO corrigido**, por dois motivos que se somam:

1. O dono nunca reclamou DESTA. Ele reclamou dos quatro retumbos iguais, que
   foram corrigidos. Mexer no ato 1 agora e arriscar piorar uma faixa que
   passou no crivo dele.
2. Ja houve UMA tentativa de abrir o brilho do ato 1 e ela SAIU PELA CULATRA
   (registrado em [[music_generation]]): a versao mais brilhante foi a 1,24k
   e passou a colidir com o ato 2 — trocar colisao entre contextos distantes
   por colisao entre dois ATOS e regressao.

O que mudou desde aquela tentativa: o ato 2 subiu para 1,49k e entraram
act4 (0,88k) e act6 (1,29k). Sobrou uma janela livre em **~0,65-0,80k** que
nao existia antes. Se alguem for mexer, o alvo e esse, e a mudanca e de
ARRANJO (trocar o instrumento que carrega a melodia), nunca de adjetivo.

As outras 5 colisoes do rodape sao entre contextos que raramente se seguem
(boss/rest, rest/act1) ou entre atos distantes (act1/act5, act2/act6).

**Atualizacao 2 (Set/2026) — CORRIGIDO, com uma troca consciente.** A faixa do
ato 1 foi refeita: **0,49k -> 0,78k**, salto 0,0080, razao 0,91x. A colisao com
o MENU morreu (0,51k vs 0,78k = 53% de distancia).

Em troca nasceu uma colisao ato1 <-> ato4 (0,78k vs 0,88k, 11%). Isso e uma
MELHORA e nao um empate, pelo criterio que esta pagina ja usava: menu->ato 1 e
uma transicao IMEDIATA, acontece em toda run que comeca; ato 1 -> ato 4 nunca e
consecutiva (passam dois atos inteiros no meio). Nota sobre o alvo: a janela
"0,65-0,80k" estava otimista — com o ato 4 em 0,88k o teto real pra zero
colisoes e **0,73k**. 0,78k ficou dentro da janela pedida mas acima desse teto.

Quatro tentativas, e as duas primeiras erraram por LADOS OPOSTOS:
  1. flauta doce como melodia principal .................... 0,86k (colide c/ ato4)
  2. + viola baixa segurando drone grave .................... 0,10k RETUMBO
  3. alaude e flauta doce revezando a melodia ............... 0,84k
  4. alaude sozinho, melodia AGUDA nas cordas ............... 0,78k  <- instalada
A 4 e a menos invasiva musicalmente: mantem o arranjo que o dono aprovou
(alaude + viola + tambor de moldura, dorico) e so muda o registro. As opcoes
1 e 3 trocavam o instrumento que carrega a melodia, o que e mudanca maior numa
faixa de que ele nunca reclamou.

⚠️ **Limite de quem fez:** brilho e emenda sao MEDIDOS; "se a melodia ficou
boa" nao foi avaliado por ninguem que ouviu. Se soar pior que a anterior, o
original esta preservado no historico do git.


## Salao do chefe do ato 3: o TRONO fica escondido atras do chefe (Set/2026)

Queixa original do dono foi "a composicao da sala do chefe do ato 3 esta
estranha", com a leitura de que o chefe ficava no terco inferior e sobrava
espaco vazio em cima, com um trono pequeno.

**Recapturado em Set/2026** (`love . screenshot_enemy_scene 3_boss`, imagem
em `tools/preview_out/hall3_ANTES.png`) e a parte de "chefe la embaixo" NAO
se confirma mais: o chefe domina o quadro e o pe esta acima do topo da mao.
O teto de mao (`ENEMY_HAND_CLEARANCE`) que corrigiu o chefe do ato 2
provavelmente resolveu isto junto.

O que SOBRA, e que e um problema de composicao de verdade:

**O trono e o elemento mais brilhante da arte e fica exatamente atras do
sujeito.** Na tela o que se ve sao as barras alaranjadas do estrado
cortando a altura dos ombros do chefe; a cadeira em si fica 100% ocluida.
O salao le como "corredor com barras brilhantes", nao como sala do trono —
e o chefe (silhueta escura) encosta em fundo escuro dos dois lados, sem
separacao de valor.

**Nao corrigido, de proposito.** O conserto e de ARTE (regerar o
`castle_hall_3.png` com o estrado mais largo/alto, ou o trono fora da linha
de centro), e nao de parametro: framing por cena nao resolve, porque a
ancora do pe acompanha o mesmo transform — mover o fundo move o chefe junto
e a relacao entre os dois nao muda. O unico lever real e a arte.

Custo estimado: ~30 geracoes PixelLab. Ficou de fora agora porque a frente
dos locais por ato tem 25 conjuntos pela frente (750-1100 geracoes de um
saldo de ~1840) e essa era a prioridade declarada do dono.

**Atualizacao (Set/2026, frente dos saloes 4-6).** A REGRA que faltava foi
extraida e esta aplicada nos saloes novos: o chefe cobre a faixa central da
arte — medido no caminho real, x 0.375-0.625 e de (yr-0.43) ate yr — entao o
elemento de identidade nao pode morar ali, e a faixa imediatamente atras do
corpo dele precisa CONTRASTAR em valor com a silhueta (chefe palido pede
fundo escuro; chefe escuro pede fundo claro). Os saloes 4, 5 e 6 nasceram
com essa regra e o resultado esta em `tools/preview_out/salas_de_chefe_1a6.png`.

Uma regeracao do `castle_hall_3` foi TENTADA aplicando a regra (1 geracao;
candidato em `tools/preview_out/candidato_hall3_NAO_INSTALADO.png`) e **nao
foi instalada**. Ela resolve o contraste — vao de lava claro atras do tirano
escuro — mas perde o TRONO por completo, ou seja, troca um problema de
identidade por outro; e a linha de chao dela cai em ~0.86 contra os 0.78 de
hoje, o que puxaria o chefe pra perto da mao e obrigaria a remedir
EMITTERS[3]. Trocar a arte de um ato que o dono ja joga, sem ganho claro,
nao compensa. Se for regerar, o alvo e: vao claro atras do CORPO **e** trono
visivel ACIMA DA CABECA (fora da linha do corpo), com a laje comecando em
~0.72 pra manter yr 0.78.

**RESOLVIDO (Out/2026):** hall 3 regerado sem trono — portão-caveira ACIMA da
cabeça e cascata de lava clara atrás do corpo; chão ajustado pra ~0.71. Ver
[[boss_halls]]. O histórico abaixo fica pelo registro.

**Atualizacao 3 (Set/2026) — mais duas tentativas, TODAS falharam no mesmo
ponto; hall 3 fica como esta.** O alvo era juntar as tres coisas de uma vez:
vao claro atras do CORPO, trono ACIMA DA CABECA (fora de x 0.375-0.625 /
yr-0.43..yr) e laje comecando em ~0.72. Quatro artes geradas ao todo, e o
problema nunca foi o contraste nem o chao — foi sempre o TRONO:

  - "trono numa alcova elevada, bem acima do vao" -> o modelo pos o trono no
    CHAO, centralizado, na altura do corpo. Mesmo defeito de hoje, so que
    bonito. (`tools/preview_out/hall3_tentativa_trono_no_corpo.png`)
  - "trono numa sacada alta + o chao COMPLETAMENTE VAZIO" -> o trono sumiu por
    completo e a sala virou caverna: sem colunas, sem braseiros, sem salao.
    (`tools/preview_out/hall3_tentativa_sem_trono.png`)

**Padrao:** "sala do trono" puxa o modelo pra por o trono no centro do chao, e
proibir isso faz ele APAGAR o trono em vez de subi-lo. Os dois vaos claros
saem otimos; o trono e que nao sobe.

Se alguem voltar: parar de pedir "trono" na mesma imagem. Duas saidas que nao
foram tentadas — (a) gerar o salao SEM trono e compor o trono por cima, num
retangulo alto, com o mesmo composite cirurgico usado nas animacoes; (b)
aceitar outro simbolo de identidade que viva nas laterais (estandartes,
estatuas), abrindo mao do trono. Custo ate aqui: 4 geracoes, nenhuma instalada.


