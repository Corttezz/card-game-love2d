---
name: Endless em ciclos + Selos do Grimório (pós-jogo)
description: Out/2026 — pesquisa (Balatro/StS/Monster Train/Hades), desenho e implementação do pós-jogo: Selos do Grimório 1-10 (Ascensão por classe, cumulativos) e endless em ciclos de 8 andares com maldição 1-de-2 empilhável, curva exp-quadrática que sempre termina a run; onde mora cada regra, save, UI, conquistas, testes.
type: project
---

# Pós-jogo: Endless em ciclos + Selos do Grimório (Out/2026)

Pedido do dono: "depois de vencer o chefe final o jogador tem que poder seguir
no endless — um endless que faça sentido jogar pra sempre, tipo Balatro, pra
não acabar de forma abrupta. É um roguelike em que o jogador passa boas horas
pra terminar todo o conteúdo; precisa de um elemento de modo."

## Pesquisa — como os quatro seguram o pós-jogo

| Jogo | Mecânica | O que copiamos (a IDEIA, nunca o código) |
|---|---|---|
| **Balatro** | Endless depois da Ante 8: a meta de fichas cresce super-exponencial até o número "estourar" (naneinf ~1e308). Stakes (8 cores) = dificuldade por baralho, cumulativa. | Curva que **sempre termina** a run; dificuldade **cumulativa** desbloqueada degrau a degrau. |
| **Slay the Spire** | Ascensão 1-20: uma regra nova por nível, cumulativa, desbloqueada vencendo o nível anterior **com o mesmo personagem**. Endless (Neow): a cada 3 atos impõe "blights" (Spear/Shield = +dano/+vida inimiga, Mimic Infestation = baú vira elite, Muzzle = sem +HP max); com o mod de baús, escolha 1-de-2 blights. | Selos 1-10 por classe; maldições do endless que **mexem em sistemas diferentes** (vida, dano, elite, loja, cura) e **escolha 1-de-2**. |
| **Monster Train** | Covenant 1-25: cada nível muda inimigos, chefes e o próprio deck. | Mesmo eixo do StS; confirmou: **cada degrau precisa ser sentido** (não "+2% de vida" x25). |
| **Hades** | Pacto da Punição (Heat): o jogador ESCOLHE quais condições ligar; recompensa = só na 1ª vitória em heat maior. | O jogador escolhe a maldição; **recompensa = pontuação** (e conquista), não poder. |

Fontes: wikis do StS (Blights, Custom Mode), páginas da loja do Monster Train,
artigos sobre "naneinf" do Balatro. Ver memory/sts_progression_config.md.

## Selos do Grimório (dificuldade antes da run)

- 10 selos CUMULATIVOS, cada um um sistema diferente (`src/data/run_modifiers.lua`):
  1 Cerco (elite x1,5 no mapa) · 2 Cura Escassa (fogueira x0,75) · 3 Mercado
  Caro (loja x1,15) · 4 Hordas (vida comum/elite +10%) · 5 Chefes Encouraçados
  (vida chefe/mini +15%) · 6 Feridas Abertas (cura entre atos x0,5) · 7 Bolsa
  Leve ($0 inicial, vitória −$1) · 8 Elites Ferozes (dano elite +15%) · 9
  Escolha Curta (recompensa com 2 cartas) · 10 O Último Selo (dano +10% geral).
- **Desbloqueio POR CLASSE** (StS): vencer no selo k abre o k+1
  (`UnlockSystem.getMaxSeal/getSealWon`, `profile.unlocks.sealsWon`). Perfil
  antigo com vitória da classe = selo 0 vencido (não punir quem já jogou).
- Escolha na seleção de classe: banda S própria no `ClassSelectLayout` (setas
  + selo + regra; hover numa classe mostra o teto dela ou os RECORDES dela);
  teclas ←/→ (A/D, Q/E). Um seletor só; ao escolher a classe o selo é
  limitado ao teto dela (`sealFor`). Replay mantém o selo.
- Pontos: +10% por selo (`RunModifiers.scoreMul`).

## Endless em ciclos

- Ciclo = 8 andares, girando pelos 6 biomas (EnemyRoster.biomeAct). Ao abrir
  cada ciclo (`RunManager:advanceFloorInAct` → `RunModifiers.beginEndlessCycle`)
  duas maldições DIFERENTES ficam abertas em `run.endless.pending` (stream
  "event"). A tela `components/EndlessCurseScreen.lua` é obrigatória (sem
  pular) e abre sozinha observando o estado (`watch` no love.draw), então
  Continuar no meio reabre a escolha.
- 6 maldições empilháveis com teto (`max`) e bônus de pontos por acúmulo:
  Vigor Profano (vida +15%), Lâminas Afiadas (dano +10%), Couraça Abissal
  (Bloqueio inicial 8% da vida), Caçada (elite x2), Dízimo (loja +25%), Fome
  (cura x0,7). Ícones PixelLab (`tools/pixellab_endless_icons.py`).
- **Curva** (`Config.Endless`, `ActSystem.endlessFactors`): fator =
  exp(LIN·n + QUAD·n²). Vida no fim dos ciclos 1..6: x1,9 x4,7 x14 x50 x220
  x1180; dano x1,4 x2,4 x4,3 x8,7 x19 x48. Era 1.18^n pra vida E dano (x3,2 já
  no 1º ciclo, x14 no 2º, dano junto = morte num golpe). Agora: generoso por
  2-3 ciclos, e o termo quadrático garante que toda run termina.
- Cura de ciclo: `Config.Endless.healPercent` (20%) x selo/maldição. Antes caía
  sem querer na cura do ato 6 (40% a cada 8 andares); `healEveryNFloors` era
  config morta e saiu.
- Recompensa: pontuação (`ScoreSystem` x `RunModifiers.scoreMul`), recorde por
  classe (`UnlockSystem.getClassRecord` — melhor pontuação e andar do endless,
  na banda de selo ao passar o mouse na classe) e conquistas.

## Onde cada regra entra (uma porta por sistema — RunModifiers)

ActSystem/Game.nextPhase+resumeRun (`enemyStats`, `decorateEnemy`) · MapManager
(`opts.eliteMul` via RunManager.generateNextNodes) · ShopSystem.generateOffers
(preço da vitrine) + getRefreshCost · RestScreen:_healPct · Game (ouro inicial,
vitória, cura entre atos) · ShopSystem rewards (cartas a menos) · ScoreSystem.
**Só multiplica por cima** — selo 0 sem maldição = jogo base (teste trava).

## UI

TopBar (linha 2: "andar x/8 · Selo 3 · Ciclo 2"; tooltip lista selo +
maldições + multiplicador) · pausa (linha da jornada) · roteiro (subtítulo) ·
tela final (célula "chegou até" + aviso "Selo N liberado"). Texto num lugar só:
`src/ui/RunModsText.lua`. i18n: `src/i18n/locales/run_modifiers/<loc>.lua`
(seals, seal_ui, endless_curses, endless).

## Conquistas novas (API names congelados no test_achievements)

ciclo_3 / ciclo_5 / ciclo_10 (andar 24/40/80 do endless) · primeiro_selo ·
selo_max_guerreiro / _mago / _ladino. Texto em `tools/achievement_text.py`,
ícones PixelLab → `tools/achievement_icons.py all`.

## Medição e travas

- `BALANCE_SEAL=N` e `BALANCE_ENDLESS=N` no `balance_sim` (o piloto escolhe a
  maldição de menor bônus; relatório ganha a seção "Endless").
- `love . test_one test_endless_seals` (no test_all): neutro, cumulativo,
  integração no Game, desbloqueio por classe, ciclo/escolha/teto/save, curva,
  layouts, tela por teclado. Capturas: `love . test_one screenshot_endless`
  (END_W/H/LOCALE/TAG) e `love . screenshot_class_select` (CS_LOCALE, CS_SIZES).

**Why:** pós-jogo sem regra nova vira grind; regra nova sem escolha vira
punição. **How to apply:** selo/maldição nova = uma linha em
`src/data/run_modifiers.lua` (+ i18n + ícone); se a regra precisa de um
sistema que ainda não consulta RunModifiers, adicione UMA porta lá. Nunca
mexer nos números base daqui. Ver [[rng_and_offers]], [[balance_curves]], [[unlocks]].
