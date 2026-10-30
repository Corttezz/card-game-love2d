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

### 1b. A cena é nó + cutscene — e o CONTINUAR só tinha o nó

> "quando estou em um boss, salvo e tento abrir pelo Continuar, ele abre com
> o boss no meio do cenário normal" (dono, Set/2026, com captura)

O segundo argumento de `isInteriorNode` não vem do save: `bossEntered` é
**local de módulo** do `GameplayScene`, nasce `false` a cada `setGame` e só
vira `true` quando `WorldRoad.enterCastle` completa. No Continuar nenhuma
viagem dispara (`resumeWorld` já ancora `lastFloorKey` no andar salvo), logo
a cerimônia da porta nunca roda e a flag fica `false` **para sempre** —
`isInteriorNode("boss", false)` = estrada, com o chefe certo plantado nela.

**Lição geral:** o que a cena mostra é **dado do save + estado encenado**.
Retomar restaura o primeiro; o segundo tem que ser **reconstruído
explicitamente**. Vale para qualquer flag de cutscene que futuramente decida
cenário.

**Onde mora a reconstrução:** `src/systems/ResumeFlow.lua`
(`plan`/`apply`), chamado pelo `setContinueCallback` do `main.lua`. `plan`
é pura e guarda duas regras: só `boss` entra no salão (elite/mini-boss
continuam na estrada — seção 1 acima), e **não** se o save foi na
encruzilhada (`pendingNodes` não vazio): `showMapSelection` NÃO limpa
`currentNode`, então o nó do chefe recém-morto fica de resíduo e abriria o
salão em cima da bifurcação. Regressão em `tools/test_resume.lua`; prova
visual em `love . screenshot_resume_boss [antes]`.

---

## 2. `height * 0.68` nunca foi "a altura do chão"

> "o boss do segundo ato FLUTUA e tem uma sombra embaixo dele redonda como
> se tivesse no chão."

Na época o chefe do ato 2 (`tower_lich`) **tinha botas de sola chata** — ele
não flutuava na arte (isso mudou; ver a seção 4). O
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

**Flutuantes (5):**

| id | onde aparece | por que |
|---|---|---|
| `abyss_wraith` | legado | manto afina até virar nada; sem pé |
| `dusk_shade` | bioma 6, batalha | farrapos que se desfazem em fumaça |
| `carrion_king` | **boss do ato 1** | asas abertas, talões PENDURADOS (dedos curvados, sem sola) |
| `eclipse_queen` | boss do bioma 6 | capa em leque, nenhum pé |
| `tower_lich` | **boss do ato 2** | botas PENDENDO com o bico pra baixo (ver seção 4) |

**Apoiados (16):** `abyss_tyrant`, `blood_duke`, `bog_ghoul`,
`cursed_scarecrow`, `ember_imp`, `frost_wight`, `glacier_knight`,
`grave_slime`, `harvest_reaper`, `mire_hag`, `moon_gargoyle`,
`obsidian_sentinel`, `rot_colossus`, `rune_golem`, `stone_golem`,
`winter_monarch`.

### A regra que faz a coisa LER

Levantar o corpo não basta: o que comunica altura é o **vão entre corpo e
sombra**. Então a sombra do flutuante:

- **não sobe com o corpo** — continua no chão (`cy`);
- fica **menor** (`shadowK`), **mais fraca** (`shadowA`) e **mais borrada**
  (`smear × 2.4`);
- **escorrega pro lado oposto à luz**, proporcional à altura. Na estrada a
  direção vem do sol do bioma (`ShadowEngine.tipShiftAt`); no interior vem
  do `lightXr` da cena.

Colar a elipse de contato embaixo de quem paira é precisamente o defeito
original — a sombra afirma "estou apoiado" e a pose afirma "estou no ar".

### Sombra de voo: REJEITADA pelo dono (24/Out/2026)

O dono pediu "aquela coisa no pé" para saber que o chefe do ato 1 e os outros
voam. A frente entregou `src/ui/FloatShadow.lua` (23/Out, f7d7f925..4ac056e5):
a silhueta do quadro achatada no chão, curvada com o domo, respirando com o
bob. Resposta do dono: "essa sombra que você colocou nos bosses voadores está
ridícula e feia e não combina com o que a gente já tem. Eu imaginei que você
iria GERAR alguma ANIMAÇÃO para dar a sensação de voar."

Saiu tudo (módulo, `test_floating_shadow`, `screenshot_sombra_voo`,
`WorldRoad.groundRadius`, `ShadowEngine.getTint`, `opts.shadowMaxY/groundR`),
e a sombra do flutuante voltou a ser a de antes (silhueta projetada do
`ShadowEngine` com `shadowK/shadowA`). Lição: "a
coisa no pé" era MOVIMENTO, não uma forma nova; forma desenhada por código
(mancha, disco, elipse, silhueta achatada) num jogo de pixel art pintado lê
como enxerto. Não reintroduzir sombra de voo.

### Sem sombrinha sob o pé: SÓ a silhueta projetada (dono, 24/Out/2026)

O dono jogou e reclamou: "vocês colocaram uma sombra adicional em cada
monstro. A gente já tem a sombra deles projetada pra frente e agora tem uma
sombrinha redonda embaixo do pé. Qual o sentido? Tira, usa só a que já
existia." Eram três camadas por baixo da silhueta do `ShadowEngine`:

- `EnemyRenderer.drawFootContact` (três barras em degrau 0,62/1,0/0,80 da
  largura do pé, que lia como uma elipse) na batalha e no billboard da
  estrada (`WorldRoad`), com `EnemyRenderer.contactK` decidindo flutuante e
  cadáver;
- `src/ui/InteriorDepth.lua` (poça elíptica em degraus sob o chefe no salão);
- a elipse de fallback (dupla para quem flutua) quando o `ShadowEngine` não
  tinha frame.

Saiu tudo: as funções, o módulo e a elipse. Sem frame de sombra o inimigo
fica sem sombra (o salão e a estrada sempre ligam o frame; o salão por
`GameplayScene.hallShadowFrame`). Trava em `test_enemy_shadow_motion`
(nenhuma elipse, nada desenhado no chão 4 a 16 px abaixo do pé com a
silhueta desligada, em seis criaturas) e `test_interior_fx`. Não
reintroduzir sombra de contato, poça, disco ou elipse sob o monstro.

### Voo pela ANIMAÇÃO (24/Out/2026)

O que diz "estou voando" agora é o próprio corpo:

- **Idle de voo gerado** (`tools/pixellab_voo.py run|fetch|install|restore`,
  `animate_image` v3 com o primeiro e o último quadro pinados no idle 0, 12
  quadros, melhor de 3; o idle antigo fica em
  `tools/preview_out/voo_tries/_antes_<id>/`): asas BATEM com subida e
  descida claras (carrion_king, dusk_bat, eclipse_queen), capa e barra
  ESVOAÇAM como se o ar segurasse (tower_lich, dusk_shade), e o corpo sobe
  dentro do quadro na batida. Quadro 0 byte a byte igual ao idle 0 de antes
  (fidgets, estados, entradas, dano e morte continuam emendando).
  `abyss_watcher` MANTEVE o idle antigo de 16 quadros: os tentáculos já
  ondulam como água-viva e a única tentativa de pulsar o sino apagou os olhos
  e saturou o vermelho (outra criatura). `abyss_wraith` não está no roster:
  nada gerado.
- **Bob na fase da batida** (`flapPeak` em `src/data/enemy_poses.lua`, fração
  do loop onde o corpo está mais alto): com o idle tocando, o `bob` deixa de
  ser senoide de relógio e segue o quadro do idle
  (`EnemyRenderer.poseOffsetY(..., flapPh)`), então o corpo sobe na batida da
  arte em vez de flutuar fora de ritmo. Fora do idle (ataque, fidget,
  estado) volta ao relógio. `reducedMotion`: sem bob, como antes.
  **Troca sem degrau (30/Out/2026):** a entrada na estrada (`WorldRoad`) usa o
  relógio; quando a fase da batida começa (handoff, troca de inimigo) o bob
  cruza do relógio para a batida em `EnemyRenderer.FLAP_BLEND` = 0,6 s
  (`_flap.k`, 6º arg de `poseOffsetY`). Antes a troca era instantânea e a
  sombra do `dusk_shade` saltava 6 a 12 px no fim da chegada
  (`test_scene_continuity` a6).
- **Sopro no chão** (`downdraft`, tipo de fx do `EnemyLife`, ver
  `memory/enemy_life.md`): em cada quadro de batida declarado em `strokes`
  sai uma rajada de motas de pixel ao longo do chão sob a criatura (poeira no
  salão, folha vermelha no crepúsculo, folha/terra nos campos, neve no gelo),
  e na estrada a grama sob ela inclina para fora (`GrassField.pokeAt` com
  amplitude 0,45). Sem disco, sem elipse, sem brilho, sem forma achatada.

Pranchas antes/depois (cena real 1920x1080, chefes no salão, 1:1 e chão 3x)
e GIFs: `tools/preview_out/voo/<id>_antes_depois.{gif,png}`; tira do idle
novo: `tools/preview_out/voo/<id>_idle_novo.png`. Captura:
`CARDGAME_HEADLESS=1 VOO_IDS=a,b lovec . test_one screenshot_voo` (modo
`antes` sobrepõe o idle antigo no save dir e tira o downdraft) e
`python tools/voo_compose.py <savedir>/voo <id>`. Trava: `test_enemy_life`
(todo flutuante do roster declara downdraft; apoiado nunca).

Asas que PISAM continuam `grounded` (olhado o idle a 3x, 23/Out/2026):
`storm_harpy` (talões no chão, agachada), `storm_griffin` (quatro patas
plantadas), `fallen_angel` (botas no chão, espada), `moon_gargoyle`
(agachada). Asa aberta não é voo; o pé é que decide.

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

## 4. O dado dizia "flutua", a ARTE dizia "pisa"

> "no ato 2, o boss que agora está voando e flutuando ficou um pouco melhor,
> mas as animações dele ainda parecem que ele está meio que só em cima de
> algo. O pezinho dele precisa parecer que ele está realmente flutuando,
> então ele precisa ficar inclinado para baixo. A capa também precisa ficar
> mexendo um pouquinho, coisas sutis, bem pequenas." (dono, Set/2026)

A seção 3 tinha subido o `tower_lich` e tirado a sombra de contato dele por
DADO. O sprite, porém, continuava com **bota de sola chata plantada** e uma
idle cuja silhueta não se mexia: as bordas da capa andavam 0-1px entre os
quatro frames, e o que sobrava era chuvisco de regeração, não balanço.
Pose flutuante + postura de quem pisa = leitura de "apoiado em algo
invisível". **Altura é dado; POSTURA é arte — corrigir só um dos dois não
resolve.**

Correções, nos três clips (`idle`/`hurt`/`death`):

- **Bico pra baixo.** As botas foram regeradas por `inpaint_image` com
  máscara própria (só os pés, o orbe do cajado fora dela) e depois
  escurecidas/dessaturadas em 0.68/0.35 — cru elas saíam o objeto mais
  claro da metade de baixo e lavavam a paleta fria. A ponta da bota
  direita saiu **cortada na última linha do canvas**: a máscara ia até
  `y=130` e o modelo preencheu até o fim. Máscara de inpaint precisa
  deixar folga pro conteúdo respirar.
- **Capa ondulando.** `animate_image` foi tentado e REPROVADO: ele redesenha
  o sprite inteiro e o chefe DERIVA (medido: ~90% dos pixels mudam entre
  frames, a capa vira outra forma, as botas perdem a ponta). O que entrou
  foi **deslocamento assado a partir de UM frame base** — 6 frames, cada
  pixel vindo do frame base, deriva zero por construção e amplitude que é
  um número escolhido (`AH=3.0` horizontal, `AV=1.3` vertical, ~1.4s de
  ciclo com o ping-pong do `IDLE_FPS`). A componente vertical não é
  enfeite: só a horizontal faz o pano DESLIZAR; é a barra subindo e
  descendo que lê como tecido pairando. **O cajado fica fora das zonas de
  deslocamento — madeira não é pano.**

### O pé de CADA CLIP tem que cair na mesma linha

`EnemyRenderer.clipMetrics` mede o `pad` (margem transparente abaixo do
conteúdo) do **1º frame de cada clip** e é ele que posiciona o sprite. Bota
pendendo é mais comprida que sola chata, então corrigir só a `idle` deixava
`idle=1` e `hurt=4`: **o chefe pularia ~7px na tela a cada golpe recebido.**
Por isso o pé corrigido foi transplantado também pra `hurt` (7 frames) e pro
começo da `death` (4 frames — do 5º em diante ele já está desabando e não
há pé visível). Os 21 inimigos do roster têm `span=0` entre idle/hurt/death;
`attack` fica fora de propósito (canvas cru do PixelLab, margem gorda, e o
`EnemyRenderer` já conta com isso).

Travas em `tools/test_enemy_pose.lua` (seção 5), as duas verificadas
falhando com o defeito presente: pé na mesma linha nos três clips de
**todos** os inimigos, e a silhueta da capa do lich se mexendo — com **teto**,
porque a outra metade do pedido foi "coisas sutis, bem pequenas".

Pendente: `south.png` (sprite estático usado só pelos ícones de nó do
`MapScreen`) segue com a bota antiga. É arte diferente da idle, renderiza a
poucos pixels e não foi tocada.

---

## 5. O palco da batalha: pé DENTRO do chão e parada mais ao fundo (Out/2026)

> "quando ele aparece lá de trás e fica o corpo inteiro para fora, ele ainda
> fica meio que flutuando alguns milímetros do chão [...] só deixar elas um
> pouquinho mais para baixo do chão."
> "Os inimigos param muito na frente da tela. Muitas das vezes, a descrição
> da carta ou a carta em si, quando faz o hover, fica à frente do inimigo."

### 5a. Pé: três causas, nenhuma era número mágico por inimigo

1. **Margem só do 1º quadro.** `clipMetrics.pad` media o quadro 0; a regeração
   do PixelLab desloca a figura INTEIRA (pés junto) entre quadros da idle.
   Agora `framePads[i]` e quem PISA usa o pad do quadro atual na idle (o
   billboard da viagem também — `getEncounterBillboard.framePads`).
2. **Respiro pra cima.** `floor(sin)` dava {-1,0}: meio ciclo 1px ACIMA. Virou {0,+1}.
3. **Dois floors.** `floor(footPad·scale)` + o floor do `SpriteAnimation` somavam até 2px pra cima.

Mais `EnemyRenderer.FOOT_SINK = 2`: o pé afunda 2px (+respiro = 2-3px). A
sombra nasce no pé afundado. Flutuantes não afundam (pose manda).

| inimigo | pads idle (arte) | pior gap ANTES | gap AGORA |
|---|---|---|---|
| abyss_tyrant | 3,3,5,5 | +5.2px (no ar) | -2.7..-2.1 |
| ember_imp | 3,5,5,5 | +6.5px | -2.8..-2.3 |
| rot_colossus | 10,9,12,12 | +5.0px | -2.9..-2.3 |
| moon_gargoyle | 4,4,4,5 | +4.0px | -2.8..-2.0 |
| bog_ghoul | 9,9,10,10 | +3.7px | -3.0..-2.3 |
| obsidian_sentinel | 6,6,7,7 | +3.4px | -2.6..-2.1 |
| winter_monarch | 5,5,6,5 | +3.0px | -2.8..-2.2 |
| demais apoiados (9) | constantes | +1..+2px (respiro+floor) | -3.0..-2.1 |
| flutuantes (5) | — | no ar por design | no ar (+14..+36) |

(gap = linha do chão − base do pé; negativo = dentro do chão. Tabela completa
impressa por `love . test_one test_enemy_stage`.)

### 5b. Distância de parada: o estudo e a escolha

`love . test_one study_enemy_stage 9,11,12,13,14,15,auto[,shots]` desenha o
GameplayScene REAL em 1024x768 / 1280x720 / 1920x1080 (janela falsificada,
mouse falso na carta do meio) e mede inimigo+HUD (`EnemyHud.layout().rect`)
contra `Card.lastDrawRect` e `CardInfoDisplay.lastRect`.

Achados:
- **Recuar sozinho não resolve o tooltip.** Acima da carta levantada ele
  ocupa ~0,45-0,62 da altura no centro — exatamente o tronco do inimigo em
  QUALQUER distância que ainda seja estrada (12/12 cenas colidindo de rel 9
  a 15). Por isso a descrição da mão do combate foi pro LADO da carta
  (`Card.tooltipSide` → `CardInfoDisplay` opção `side`, topo alinhado ao topo
  da carta, lado ESQUERDO preferido: à direita Jogar/Encerrar desenham por
  cima e engoliam o painel em 1024x768).
- **A carta em hover tem tamanho FIXO em px; o mundo escala com a tela.**
  Rel fixo não serve: rel 12 limpa 1080p e colide 12/12 em 768/720; rel 15
  limpa 768 mas deixa o inimigo minúsculo em 1080p. Escolha: **palco pela
  zona da mão** — `GameplayScene.stageFootLimit()` = topo da carta levantada
  − 18px, e `WorldRoad.battleRelFor` inverte a geometria da estrada pra achar
  o rel (clamp 9..16.5). Resultado: ~12.6 em 1080p, ~15.4 em 1024x768,
  ~16.1 em 1280x720. Recalculado todo frame (resize coerente por construção;
  `syncBattleStage` roda também antes da viagem, que nasce em camZ+dist+palco).
- **Tamanho:** encolhe pela perspectiva do mundo elevada a
  `WorldRoad.ENEMY_SIZE_PERSP = 0.6` (`battleSizeK`, 1.0 no rel 9 histórico).
  Perspectiva pura dava 120-140px em 768/720 — menor que a carta, sem
  ameaça; 0.6 dá 148-183px (182-212 em 1080p).

| palco | 1024x768 | 1280x720 | 1920x1080 |
|---|---|---|---|
| rel 9 (antes) | carta 12/12, tooltip 12/12 | 12/12, 12/12 | 12/12, 12/12 |
| rel 12 fixo | 12/12, 12/12 | 12/12, 12/12 | 1/12, 1/12 |
| **auto (escolha)** | **0/12, 0/12** | **0/12, 0/12** | **0/12, 0/12** |

### 5c. Chefe no salão: recua o que a laje deixa

`scene_anchors.backYr` = borda de trás do piso de cada PNG (lida de olho:
hall1 0.70, hall2 0.83, hall3 0.73, hall4 0.75, hall5 0.79, hall6 0.75). O
chefe recua de `yr` até `max(backYr, zona da carta)` e encolhe pela
perspectiva do chão (`SceneAnchors.depthSizeK`, horizonte 0.42, mesmo
expoente 0.6). Halls 2 e 5 não recuam (laje baixa + teto da mão — a
limitação da seção 2 continua). **O chefe ainda colide com a carta em hover
nos salões**: o piso das artes acaba antes da zona da carta. Resolver de
verdade pede re-enquadrar as PNGs (horizonte mais alto), não mexer em âncora.

Travas: `tools/test_enemy_stage.lua` (pé de todo apoiado em todo quadro com
margem medida independente; inimigo+HUD fora da carta e do tooltip nos 3
tamanhos; chefe não avança, não sai da laje, segue maior que o comum).
Verificada falhando com framePads desligado (6 inimigos) e com o palco preso
em rel 9 (todas as cenas da estrada).

Prancha do estudo: `prancha_palco.png` no save dir do sandbox
(`%APPDATA%/LOVE/card-game-inimigo/`).

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
- `tools/test_enemy_pose.lua` — 162 asserts (registrado em `run_all_tests`)
- `tools/test_enemy_stage.lua` + `tools/study_enemy_stage.lua` — palco (seção 5)
- `tools/screenshot_enemy_scene.lua` — `love . screenshot_enemy_scene 2_boss`
- `love . sheet <dir> <escala>` — frames lado a lado sobre fundo escuro,
  que é como se valida arte aqui (o Python da máquina quebrou em Set/2026)

## Ligações

[[shadow_engine]] · [[worldroad_scene]] · [[ui_layout_invariants]] ·
[[lighting_engine]]
