---
name: STS Gap Analysis
description: Confronto direto Slay the Spire × nosso card game, sistema a sistema, com sugestões priorizadas (impacto × esforço). Insumo do documento de melhorias do Daniel. Estado do nosso jogo auditado em Jul/2026.
type: project
---

# STS × Nosso jogo — confronto e sugestões (Jul/2026)

Base: memórias [[STS Powers Catalog]], [[STS Cards & Synergies]], [[STS TopBar & HUD]], [[STS Metagame]], [[STS Run Economy]], [[STS Progression & Config]] + auditoria do nosso código (TopBar.lua, ComboSystem, EffectSystem, Enemy/Player, RunManager, MapManager, ScoreSystem, AchievementSystem, EnemyHud).
Legenda: impacto ★1-3 · esforço E1 (horas) / E2 (1-2 dias) / E3 (semana+).

## Onde JÁ estamos no nível (ou com identidade própria melhor — não mexer)

- **ComboSystem com anúncio** — o StS nem tem; é nossa identidade Balatro. Manter como pilar.
- **ScoreSystem TINTA×SELO com recibo por batalha** (RoundEvalScreen) — mais transparente que o score só-no-fim do StS.
- **Achievements com triggers inline** (20) — mesma arquitetura do StS (48). Só ampliar catálogo com o tempo.
- **Juros/economia TFT-Balatro** com fonte única calculateInterest — coerente.
- **SaveManager atômico com migrations** — base melhor que a do StS (que só ofusca com XOR).
- **Settings** já cobre volumes/CRT/lighting/screenshake/reduced-motion/idioma — acima da média.
- **StatusTooltip + keywords i18n** — bom alicerce (o gap é cobertura, não arquitetura).

## Tabela de confronto

| # | Área | StS | Nosso estado | Sugestão | Prior. |
|---|---|---|---|---|---|
| 1 | **RNG/seed** | 1 seed → 13 streams com contador salvo; run reprodutível; anti save-scum; habilita daily/replay | `love.math.random` sem seed; nada é reprodutível | Criar `Rng.lua` (streams: card/enemy/map/shop/event/misc, contador serializado no save). Fundação de daily, história de run e balance | ★★★ E2 |
| 2 | **Pity systems** | Raridade +5→−40; poção 40±10; eventos com ramp | Raridade flat 70/25/5 na loja e rewards; sem correção de má sorte | Adotar blizzard na raridade de reward/loja + pity de "consumível" quando existir. 1 contador por categoria, salvo na run | ★★★ E1 |
| 3 | **Hooks de efeito** | ~50 hooks; powers/relíquias/cartas ESCUTAM eventos (onExhaust, onCardPlayed, wasHPLost...) | EffectSystem com pontos fixos (attack/defend/turn_start); triggers limitados | `EffectSystem.emit(evento, ctx)` + contadores de combate (cardsPlayedThisTurn/Combat, exhaustedThisCombat, damageReceivedThisTurn). Destrava famílias novas de joker/carta sem tocar Game.lua | ★★★ E2 |
| 4 | **Preview honesto** | base vs atual + isModified; número verde/vermelho; descrição com !D! vivo; intent JÁ com debuff aplicado | Descrições literais; valor real só ao resolver (intent preview já aplica weak ✔) | `computeCardValue` alimentar render: número da carta colorido quando strength/combo/joker altera + placeholder `{dmg}` interpolado no CardInfoDisplay | ★★★ E2 |
| 5 | **TopBar** | HP+gold rolando+poções+piso+ascension+chaves+relíquias com counter/flash+3 botões com tooltip/hotkey; TUDO hover-explicável | Ouro eased+juros ✔, deck, score, config; sem piso/ato, sem mapa, sem tooltips gerais, jokers sem counter/flash | Fase 1: piso/ato visível + tooltip em TODO elemento + botão mapa. Fase 2: counters/flash nos jokers (quem triggerou). Filosofia: visível/explicável/anima/clicável | ★★★ E2 |
| 6 | **Sinergia emergente** | Cartas leem estado (block→dano, poison×2, conta STRIKE, dano cresce por uso, payoff de deck vazio) | Efeitos data-driven ricos mas nenhum lê estado acumulado | Novos effect types: `damage_from_armor`, `multiply_debuff`, `count_tag_bonus`, `grow_per_use` (por combate) e `grow_per_kill` (na run, tipo Ritual Dagger via `misc`) | ★★★ E1-E2 |
| 7 | **Intent rico** | 17 intents; ícone+valor com multiplicador (5×2); UNKNOWN/STUN/SLEEP; move name no ataque | 4 intents (attack/strong/defend/buff) com preview ✔ | Adicionar attack_debuff, attack_defend, debuff, unknown (boss misterioso), stun; mostrar N×dano em multi-hit; nome do golpe no EnemyHud ao executar | ★★ E1 |
| 8 | **Fogueira** | Rest 30% + Smith + opções INJETADAS por relíquia (Girya/Toke/Dig/Recall) | RestScreen fixo (rest/forjar) | Opções de fogueira registráveis por joker/evento (API `addCampfireOption`) — transforma jokers utilitários em decisões de rota | ★★ E1 |
| 9 | **Bênção inicial (Neow)** | 4 opções: pequena, recurso, GRANDE+drawback, boss-relic all-in | Run começa direto na batalha | "Bênção do Escriba" na 1ª sala: 3-4 escolhas (carta/ouro/HP/trade-off com curse). Primeira decisão de build antes da primeira luta | ★★ E2 |
| 10 | **Eventos** | 56; custo explícito no botão; mexem no DECK (remover/transformar/duplicar); shrines cross-ato | EventScreen básico | Padronizar template choice com custo no label + 6-8 eventos que operam no deck. Aproveitar sistema de raridade/CardRegistry | ★★ E2 |
| 11 | **Ascension** | 20 níveis, 1 regra nomeável cada, opt-in, mostrado no CharSelect | Só endless (1.18^floor) | "Selos do Grimório" 1-10 pós-vitória (ex.: S1 elites+, S2 inimigos+dano, S3 −cura, S4 curse inicial, S5 boss duplo...). Retenção enorme, custo baixo | ★★★ E2 |
| 12 | **Boss reward** | Escolha 1-de-3 boss relics (pivô de build) + cura inter-ato | Ouro + reward comum | Boss derrotado → escolha de 1 entre 3 jokers/upgrades RAROS exclusivos | ★★ E1 |
| 13 | **Unlocks** | 5 níveis/classe; score enche barra; bundles de 3; compêndio com "?" | 96 cartas liberadas desde o início; DeckViewer existe | Card pool com locked tiers por classe + barra pós-run + reveal. Dá "cenoura" pra rejogar cada classe | ★★ E3 |
| 14 | **Run history** | Cada run = .run JSON (path, escolhas por andar, HP/gold por andar); timeline visual | ProfileStats + card history parcial | Gravar run-file no fim (já temos os dados passando pelo RunManager) + tela simples de timeline. Também vira telemetria de balance | ★★ E2 |
| 15 | **Daily** | Seed do dia + 3 mutators de 35 + leaderboard | — (depende do item 1) | Pós-seed: "Desafio do Dia" com 2-3 mutators do nosso pool (já temos smoke presets/flags pra inspirar mutators) | ★★ E2 (após #1) |
| 16 | **Gold por sala** | 10-20/25-35/95-105 por tipo; recompensa proporcional ao risco | 5 flat + juros | Ranges por tipo de node (battle/elite/boss) rolados no Rng stream de economia | ★ E1 |
| 17 | **Fast mode** | Durações de action ×0.5 global | Timings fixos no CombatSequence | Flag em Settings multiplicando os `timings` — qualidade de vida de veterano | ★ E1 |
| 18 | **Baús/chaves** | Chaves como objetivos de rota (trocam recompensa por progresso) | — | Só se criarmos "ato final trancado"; anotar pra depois | ★ E3 |
| 19 | **Status/curses** | Cartas-lixo como mecânica (Burn/Wound/curses) alimentando arquétipo exhaust | Não existem cartas-lixo | Curses em eventos/trade-offs (já há tag exhaust): "Borrão de Tinta" no deck via evento ganancioso | ★ E2 |
| 20 | **Achievements toast** | UnlockTextEffect in-game na hora | Toast via MessageSystem? (verificar visual dedicado) | Toast dedicado com ícone + som próprio no momento do unlock | ★ E1 |

## Top 5 pra começar (ordem sugerida)

1. **#1 RNG seedável com streams** — fundação de #14, #15 e de QUALQUER análise de balance. Sem isso, metade das ideias não nasce.
2. **#3 Hooks + contadores de combate** — multiplica o espaço de design de cartas/jokers imediatamente (e alimenta #6).
3. **#4+#5 Preview honesto + TopBar fase 1** — é o que o jogador VÊ; maior ganho de percepção de qualidade por hora investida.
4. **#2 Pity de raridade** — 20 linhas, melhora a sensação de TODA reward pra sempre.
5. **#11 Ascension/Selos** — retenção pós-vitória; transforma "zerei" em "subi um selo".

## Como usar

O Daniel vai redigir o documento oficial de decisões a partir daqui (fazer/não fazer/adaptar). Ao implementar qualquer item: abrir a memória STS correspondente, conferir os números no source (`E:\dev\projects\slay-the-spire-source`), e ADAPTAR pra nossa identidade (grimório sépia + combos Balatro) — nunca copiar.
