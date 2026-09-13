---
name: enemy_pose_and_scene_anchor
description: Onde a criatura pisa (linha de chão POR CENA) e se ela pisa (pose apoiado × flutuante, com a sombra que cada uma pede). Nasceu de três defeitos de Set/2026 — elite no salão do chefe, chefe do ato 2 pairando com sombra de contato.
type: project
---

# Pose do inimigo e âncora de chão da cena

Três defeitos reportados pelo dono em Set/2026, uma causa comum: **posição
era número mágico, não dado da cena nem da criatura.**

---

## 1. O elite não briga no salão do chefe

> "ao selecionar inimigo elite, não faz sentido ele ir para um cenário
> diferente, ele tá indo para o mesmo cenário do castelo do endgame do mapa,
> isso não faz sentido."

**Decisão:** o elite luta na **ESTRADA**, exatamente como o mini-boss.
Interior = **só o boss**.

Por quê a estrada e não uma sala própria:

- O hall é o **clímax do ato** — é o pagamento da cerimônia da porta
  (`enterCastle`: porta abrindo, som, fade). O elite acontece 2-3× por ato,
  sem viagem e sem porta. Gastar o salão nele esvaziava a chegada do boss.
- **Lógica de mundo**: a run é uma estrada. Entrar num interior no meio dela,
  sem aproximação e sem porta, contradiz a cutscene que o jogo constrói.
- O **mini-boss usa o MESMO sprite do elite** no `ENEMY_ROSTER`. Tê-los em
  cenas diferentes era incoerente com o próprio roster.
- A estrada **já sabe** dizer "isto é um elite": o marco `landmark_elite`
  com luz roxa (`{0.72, 0.38, 1.00}`) e `forkHoverElite` no fork.
- Zero arte nova.

Alternativa avaliada e descartada: dar ao elite um interior próprio
(`stone_tower` / `catacumbs` / `abyss`, que existem como fallback legado do
`SceneLayer`). Resolveria "não é o salão do boss", mas manteria o teleporte
para dentro sem porta — o problema de mundo, não só o de repetição.

**Onde mora:** `GameplayScene.isInteriorNode(nodeType, bossEntered)` —
**fonte única**. A condição vivia duplicada em `draw` e em `update` e já
tinha divergido antes (o comentário "v10.4: alinhado com o draw" era o
sintoma). Regressão em `tools/test_enemy_pose.lua`.

---

## 2. `height * 0.68` nunca foi "a altura do chão"

> "o boss do segundo ato FLUTUA e tem uma sombra embaixo dele redonda como
> se tivesse no chão."

O chefe do ato 2 (`tower_lich`) **tem botas** — ele não flutua na arte. O
que flutuava era a ÂNCORA: nos interiores o inimigo era desenhado em
`height * 0.68`, número herdado do `castle_hall_1`. No `castle_hall_2` a
laje começa muito mais baixa e essa linha cai **na parede, acima da porta**.
A elipse de contato então desenhava no ar junto com ele.

**Correção:** `src/data/scene_anchors.lua` — linha de chão **por cena**, em
coordenadas normalizadas da PNG:

| cena | `yr` | nota |
|---|---|---|
| `castle_hall_1` | 0.78 | laje pálida depois dos degraus |
| `castle_hall_2` | 0.83 | **laje mais baixa que a dos irmãos** — é o caso do defeito |
| `castle_hall_3` | 0.78 | chão alto; luz vem da lava (`shadowA` 0.45) |

Dois detalhes que não são opcionais:

- **`yr` é da ARTE, não da tela.** `SceneBackground` desenha em cover-fit e
  em 16:9 **corta a imagem na vertical**. `SceneAnchors.groundAnchor` passa
  pelo mesmo `getCoverTransform`, então o pé fica no mesmo ponto do piso em
  qualquer resolução. Regressão comparando 1024×768 com 1920×1080.
- **Uniformizar os três valores reintroduz o bug.** O teste tem um assert
  explícito de que o hall 2 ancora MAIS BAIXO que o hall 1.

Referência de enquadramento: na estrada o inimigo pisa em
`WorldRoad.getRoadAnchor(BATTLE_REL)` ≈ **76% da altura da tela**. Os
interiores ficam perto disso *quando a arte permite*.

**Resize:** nada foi cacheado — a âncora é recalculada por frame a partir de
`love.graphics.getWidth/Height`, como todo o resto do `GameplayScene` (que
não tem `resize()` justamente por isso). A regra 2 de
[[ui_layout_invariants]] está satisfeita **por construção**, não por
disciplina.

**Limitação conhecida (framing, não bug desta correção):** a laje do
`castle_hall_2` é tão baixa que o pé do chefe e a sombra dele caem logo
abaixo da linha da mão de cartas (`height*0.8`). Não há posição na arte que
seja ao mesmo tempo "no chão" e "acima da mão". Resolver de verdade pede
re-enquadrar a PNG (horizonte mais alto), não mexer no anchor.

---

## 3. Quem DEVE flutuar, flutua de propósito

> "e talvez quando identificar esses casos, analisando junto também o
> cenário, colocar um leve efeito flutuante sabe."

`src/data/enemy_poses.lua` classifica os 21 sprites. Critério **literal**,
tirado de olhar cada PNG (doutrina do projeto): dá pra ver o **pé** tocando
a linha de base? Bota, garra, casco, pata, base de lodo = `grounded`. Barra
de manto que afina, farrapo que se desfaz, talão pendurado de asa aberta =
`floating`.

**Flutuantes (4):**

| id | onde aparece | por que |
|---|---|---|
| `abyss_wraith` | legado | manto afina até virar nada; sem pé |
| `dusk_shade` | bioma 6, batalha | farrapos que se desfazem em fumaça |
| `carrion_king` | **boss do ato 1** | asas abertas, talões PENDURADOS (dedos curvados, sem sola) |
| `eclipse_queen` | boss do bioma 6 | capa em leque, nenhum pé |

**Apoiados (17):** `abyss_tyrant`, `blood_duke`, `bog_ghoul`,
`cursed_scarecrow`, `ember_imp`, `frost_wight`, `glacier_knight`,
`grave_slime`, `harvest_reaper`, `mire_hag`, `moon_gargoyle`,
`obsidian_sentinel`, `rot_colossus`, `rune_golem`, `stone_golem`,
`tower_lich`, `winter_monarch`.

### A regra que faz a coisa LER

Levantar o corpo não basta: o que comunica altura é o **vão entre corpo e
sombra**. Então a sombra do flutuante:

- **não sobe com o corpo** — continua no chão (`cy`);
- fica **menor** (`shadowK`), **mais fraca** (`shadowA`) e **mais borrada**
  (`smear × 2.4`; no fallback de elipse, duas passadas concêntricas =
  penumbra barata);
- **escorrega pro lado oposto à luz**, proporcional à altura. Na estrada a
  direção vem do sol do bioma (`ShadowEngine.tipShiftAt`); no interior vem
  do `lightXr` da cena.

Colar a elipse de contato embaixo de quem paira é precisamente o defeito
original — a sombra afirma "estou apoiado" e a pose afirma "estou no ar".

### Morte

Flutuante **desce** enquanto o clip de `death` toca (`poseSink`, 0.7s), e a
sombra volta ao tamanho/força de contato no mesmo ritmo. O que o segurava no
ar deixou de segurar.

### Acessibilidade

`reducedMotion` tira o **bob**, nunca o **hover**: a criatura continua na
altura certa. Posição é informação (diz o que ela é); balanço é enfeite.
Corolário da regra 3 de [[ui_layout_invariants]]. Testado numericamente via
`EnemyRenderer.poseOffsetY` (helper puro, sem contexto gráfico).

---

## Fallback anunciado, nunca mudo

`EnemyPoses.get` e `SceneAnchors.get` **imprimem aviso** (uma vez por chave)
quando o id/cena não está declarado, e caem em `grounded` / `yr=0.76`. O
teste vai além: falha se **qualquer diretório** em
`assets/sprites/characters/enemies/` não tiver pose declarada — arte nova
entrando sem classificação é o caminho de volta pro defeito.

---

## Arquivos

- `src/data/enemy_poses.lua` — a classificação
- `src/data/scene_anchors.lua` — linha de chão + luz por cena
- `src/ui/EnemyRenderer.lua` — `poseOffsetY` (puro) + bloco de sombra
- `engine/ShadowEngine.lua` — `widthK`/`alphaK`/`tipShiftAt`
- `src/scenes/GameplayScene.lua` — `isInteriorNode`, uso da âncora
- `tools/test_enemy_pose.lua` — 92 asserts (registrado em `run_all_tests`)
- `tools/screenshot_enemy_scene.lua` — `love . screenshot_enemy_scene 2_boss`

## Ligações

[[shadow_engine]] · [[worldroad_scene]] · [[ui_layout_invariants]] ·
[[lighting_engine]]
