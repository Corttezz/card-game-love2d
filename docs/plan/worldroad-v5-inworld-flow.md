# Plano v5 — Fluxo de progressão DENTRO do mundo (a Encruzilhada)

> Objetivo (pedido do usuário, Jul/2026): tirar o máximo possível das telas
> estáticas e trazer a progressão pro mundo-esfera. Ao derrotar um monstro,
> os caminhos aparecem NO MUNDO (cabana de vendedor, baú, tenda misteriosa,
> fogueira...), com a estrada central se modificando conforme a escolha.

## 1. O fluxo atual (mapeado do código)

```
inimigo morre (Game:_onEnemyDeath, pausa 1.1s)
  → roundEval        (RoundEvalScreen — cash-out Balatro)     [TELA]
  → cardReward       (CardRewardScreen — 3 cartas)            [TELA]
  → mapSelection     (MapScreen — 2-3 painéis de node)        [TELA] ← ALVO PRINCIPAL
  → onNodeChosen:
      battle/elite/boss → nextPhase() → gameplay (estrada/interior)
      rest  → RestScreen  (curar/forjar)                      [TELA]
      event → EventScreen (narrativo)                         [TELA]
      shop  → CardRewardScreen modo shop                      [TELA]
```

Nodes: BATTLE / ELITE / MINI_BOSS / BOSS / REST / SHOP / EVENT
(MapManager.generate — pesos por floorInAct; piso 7 = mini-boss, 8 = boss).
Fonte de verdade da run: RunManager.currentRun (deck, jokers, gold, floor,
pendingNodes, currentNode). GameplayScene decide interior (boss/elite) vs
estrada e dispara WorldRoad.travel na mudança de floorKey.

## 2. A ideia — "A Encruzilhada" (fork da estrada)

Depois do cash-out e da recompensa, **em vez do MapScreen**: a câmera avança
um pouco e a estrada **se bifurca em 2-3 braços** subindo pra crista. Na boca
de cada braço, um **marco** (landmark PixelLab) diz o que aquele caminho é:

| Node | Marco no mundo | Vida |
|---|---|---|
| BATTLE | estandarte de guerra fincado + inimigo distante | bandeira balança |
| ELITE | obelisco negro com caveira | brasas roxas |
| MINI_BOSS/BOSS | portão/castelo (já existe na crista) | — |
| REST | fogueira acesa | fumaça + fagulhas (SmokeSystem) |
| SHOP | cabana/tenda de vendedor com lampião | luz quente piscando |
| EVENT | tenda misteriosa / carroça cigana | brilho arcano |

- **Hover** num braço: o caminho ganha glow, o marco dá juice_up, pill com
  nome/desc aparece flutuando sobre o marco (estilo EnemyHud).
- **Clique**: viagem — o braço escolhido **converge pro centro** (a estrada
  "se modifica": lateral do braço easa até 0 enquanto a câmera avança), os
  outros braços saem pelo cone das laterais, o marco cresce chegando.
- **Chegada por tipo** (minimizando telas):
  - battle/elite: inimigo emerge da crista (fluxo atual); elite/boss ainda
    transiciona pro interior com fade (mantém).
  - rest: chega na fogueira; 2 botões diegéticos flutuando ("Descansar
    +30%" / "Forjar") — cura acontece ali com partículas + ease de número;
    forja abre painel compacto ancorado (grid de cartas precisa de UI).
  - shop: chega na cabana; a loja abre como OVERLAY translúcido com a
    cabana/mundo visíveis atrás (restyle do CardRewardScreen modo shop).
  - event: chega na tenda; pergaminho do EventScreen vira painel ancorado
    acima da tenda, mundo visível atrás.

RoundEvalScreen (cash-out) fica como está por ora (rápido, Balatro-charm).
CardRewardScreen pós-batalha idem — fase 5 (cartas materializando sobre a
estrada) é polish futuro.

## 3. Arquitetura técnica

### WorldRoad — novo estado `fork`
- `WorldRoad.showFork(nodes, opts)` — monta 2-3 braços. Geometria: estrada
  principal até o ponto de fork (rel≈13); dali braços divergem com offset
  lateral crescendo com rel (mesma matemática de latitude/persp da estrada,
  centro deslocado: `cxRow = cx + branchDir × spread(rel)`), cada braço com
  seu marco em rel≈19 (desenhado como prop, escala persp).
- Hover/click: `WorldRoad.forkHitTest(mx, my)` → índice do braço;
  GameplayScene (novo sub-estado "fork") roteia mouse. Glow no braço +
  juice no marco.
- `WorldRoad.travelFork(i, {onComplete})` — anima: camZ avança, offset
  lateral do braço escolhido → 0 (easeInOut), braços não escolhidos somem
  pelo cone. onComplete → main.onNodeChosen(node, i) (mesmo callback!).
- Marcos: sprites em assets/sprites/world/landmark_<tipo>.png (globais,
  banho de cor do bioma via fog mix já existente).

### Integração (main.lua / GameplayScene)
- `showMapSelection()`: se SCENE_MODE=="worldroad" e não-interior →
  `currentState = "playing"` + `WorldRoad.showFork(pendingNodes, onNodeChosen)`.
  Senão (interior/fallback) → MapScreen como hoje (rede de segurança).
- Saída de interior (pós-boss/elite): fade preto já existente → volta pra
  estrada → fork aparece.
- REST/EVENT/SHOP na chegada: estados atuais continuam existindo, mas os
  componentes são REDESENHADOS como overlay ancorado com o mundo atrás
  (WorldRoad.draw continua por baixo — como cardReward já faz hoje).

### Fases de entrega
1. **F1 Fork geometry** — estado fork + braços + marcos placeholder +
   hover/click + travelFork com convergência. Validação: modo "fork" no
   screenshot_worldroad + demo tecla F.
2. **F2 Integração** — substituir MapScreen no fluxo worldroad (fallback
   mantido), chegadas battle/elite funcionando fim-a-fim.
3. **F3 Assets** — landmarks PixelLab (fogueira, cabana, tenda, estandarte,
   obelisco, baú) + pills + glow + sfx de escolha.
4. **F4 Chegadas diegéticas** — rest/shop/event como overlays ancorados
   com mundo atrás; cura in-place com partículas.
5. **F5 (futuro)** — recompensa de cartas in-world (materialize sobre a
   estrada), vendedor com personagem, baú TREASURE como node novo.

### Invariantes a respeitar (do mapeamento)
- onNodeChosen(node, index) continua sendo O contrato — fork só substitui
  a UI de escolha, nunca a lógica (RunManager.chooseNode etc.).
- Jokers nunca passam pelo deck; deck sync via synchronizeRunDeck.
- Stats transientes zeram entre batalhas (resetTransientStats).
- advanceFloorInAct/generateNextNodes ANTES de mostrar o fork.
- Interior (boss/elite/mini_boss) mantém castle_hall + InteriorFX.
- NUNCA stencil; nada luminoso desenha depois das árvores.
