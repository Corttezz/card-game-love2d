---
name: WorldRoad (mundo rolante)
description: V4 "Circle Land" — o mundo é um DOMO (disco-terra que gira, fiel ao Path of Kings). Inimigos emergem de trás da curva, castelo cresce ao aproximar, arte PixelLab. Substitui SceneLayer no gameplay (flag SCENE_MODE).
type: project
---

# WorldRoad — Circle Land (V4, Julho/2026)

## ⭐ V4 — A GEOMETRIA ATUAL (domo-esfera)

Plano: `docs/plan/worldroad-sphere-v4.md`. Feedback do usuário com 3 prints
de referência exigiu fidelidade à mecânica REAL do PoK (confirmada no APK:
**`CircleLandController`** + GameObjects Circle/Sphere): o mundo é um
**disco-terra gigante**, não um plano em perspectiva.

**Geometria** (`domeGeom` em WorldRoad.lua):
- Domo = círculo raio `R = 2.2w`, centro abaixo da tela; crista curva
  `crestY(px) = cy − sqrt(R² − (px−cx)²)`; ápice em `0.40h` da área.
- Mundo em distância: `t = (1 − rel/REL_CREST)^1.35` (0=crista, 1=base);
  `REL_CREST=26`. Escala: `KIND_SIZE[kind] × h×0.115 × (0.18+0.82t)`.
- **Painter's order = oclusão de graça**: céu → nuvens → montanhas →
  CASTELO → INIMIGO emergindo → PREENCHIMENTO DO DOMO → estrada → props.
  O inimigo desenhado antes do domo aparece meio-corpo atrás da curva
  (EMERGE_BAND=9 rel além da crista) — idêntico ao print 2 da referência.
- Castelo: centro da crista, base sempre oculta, escala `0.17w × (1+1.5×progress)`
  com `progress = (camZ % (28×8)) / (28×8)` — cresce conforme chega.
- Estrada: faixa central afunilando (`half = 0.15w×(0.06+0.94t^1.25)`),
  fileiras de tijolo 2 tons rolando com camZ (BRICK_LEN=0.72), juntas 1px
  na TROCA de fileira, bordas 2px.
- SEM herói/boneco (primeira pessoa implícita — decisão do usuário).
- KIND_LANE mínimo 0.34 → nada invade a estrada (half base = 0.15w < 0.30×0.5w).
- Céu: se há `<biome>_mountains.png`, o céu é a COR DO TOPO desse PNG
  (amostrada e cacheada — `mountainsSkyColor`) → emenda invisível. Isso
  matou o bug do "retângulo escuro" (céu procedural sépia vs céu baked azul).
- Montanhas: tiles ESPELHADOS alternados (esconde costura do parallax wrap);
  base estendida 70px abaixo do ápice (o domo desce ~0.058w nas laterais).

**Arte PixelLab** (assets/sprites/world/): `cloud_0/1.png` (com alpha nativo
— NÃO passar removedor de fundo!), `<biome>_mountains.png` (400×112),
`<biome>_castle.png` (224×288 — o de fields precisou de remoção de fundo
cinza via PIL, tol=18), `fields_tuft_0.png`, `road_bricks.png` (não usado —
estrada é procedural). Castelo/montanhas de highlands/abyss: leva 2.

**Lições v4**: (1) PNG do PixelLab pode vir com fundo baked — checar alpha
do canto ANTES de rodar removedor (nuvens tinham alpha nativo e o removedor
comeu os contornos; re-download resolveu). (2) Painter's order resolve
emergência sem stencil. (3) Céu = cor amostrada do asset elimina emendas.

**V4.1 (polish guiado pelos painéis do PoK — biome_back/hell_biome):**
- Lições de composição deles: MOLDURAS laterais (props grandes nas bordas
  formando corredor até o foco), chão NUNCA chapado (manchas), caminho
  sempre levando ao marco.
- `DOME_R_FACTOR 2.2→1.6` (sag ~0.08w — mundo visivelmente redondo).
- **Treeline da crista**: fileira de silhuetas (pine/tree ×0.62, tint 0.72)
  NA curva do horizonte, pulando zona da estrada e do castelo. Estáticas.
- **Molduras**: 45% dos props grandes vão pra lane 0.72-0.98 com big 1.2-1.45.
- Manchas de grama: 14 elipses world-anchored girando com o domo.
- Tijolos: variação de tom por fileira (hash) + seams desencontrados
  (terços na fileira par, centro+bordas na ímpar) — alvenaria real.
- **Crossfade no blend**: montanhas, castelo E cor do céu (prev alpha 1 +
  atual alpha t; céu lerp das cores amostradas) — sem salto na troca de ato.
- `mountainsSkyColor` desce a coluna até pixel OPACO e CLARO (strips têm
  outline escuro no topo — amostrar y=1 dava CÉU PRETO no blend).
- 6 biomas com castle+mountains PixelLab (fields/highlands/abyss/frost/
  marsh/dusk). Flood de borda pra castelos (céu baked degradê); montanhas
  NUNCA passam por flood (o céu baked delas é usado como cor do céu!).
- ⚠️ Bug conhecido do meu flood script: seeds da borda são removidos
  incondicionalmente — não usar em strips full-bleed.

---

# Histórico — v1-v3 (projeção plana por scanline, SUBSTITUÍDA)

## Origem da técnica

Estudo do jogo Unity **Path of Kings** (`com.TornadoBear.WayofKings`, APK analisado
via UnityPy em Jul/2026 — só TÉCNICA/composição; nenhum asset ou código copiado).
Descobertas-chave do sistema deles:

- **Câmera perspectiva (FOV 45°) + sprites 2D billboards em profundidade Z** — não
  há shader de curvatura; o "mundo redondo vindo pra frente" é projeção 1/z pura.
- Estrutura por bioma (14 + heaven/hell): 4 painéis de vista, props tree/bush/rock,
  **castelo no fim do bioma** (cresce ao se aproximar = objetivo visível), céu
  tilável, 3 nuvens, chão `grass_texture` rolando via TextureOffset.
- Dados em CSV: `BIOMES` (bioma → colorCode + pool de monstros), `ARENA`
  (dificuldade/loot por bioma), `SAGAS` (evil/good). Mapeia direto pros nossos atos.
- Scripts relevantes deles: `SagaController`, `CloudSpawner`, `ScrollMaterial`,
  `TextureOffset`, `ThirdPersonHeroController`, `CameraController`.

## Nossa implementação (LÖVE, fake-2.5D)

| Arquivo | Papel |
|---|---|
| `src/ui/WorldRoad.lua` | Renderer + sistema (projeção, props, viagem, sprites procedurais) |
| `src/data/biomes.lua` | DADOS: paletas sépia por bioma (3: fields/highlands/abyss), pesos de props |
| `tools/screenshot_worldroad.lua` | Validação visual: `love . screenshot_worldroad [full]` |

**Projeção**: chão por scanline — pra cada linha de tela `z = DEPTH_K / rowNorm`
(rowNorm 0=horizonte, 1=base). Props: inverso (`rowNorm = DEPTH_K / rel`), escala
∝ rowNorm. Estrada serpenteia via `roadCurve(z)` (2 senos compostos em distância
ABSOLUTA — rola junto com a viagem). Faixas de grama/estrada alternadas só no
campo próximo (rowNorm > 0.45 com smoothstep — no fundo viram moiré de 2px).
Manchas de grama determinísticas (hash por célula de mundo) dão movimento no
meio-campo. Névoa no horizonte esconde spawn ("dobra do mundo"). Castelo marco
a cada `LANDMARK_EVERY=88` unidades (≈ 8 andares × 11).

**API** (assinatura igual SceneLayer pra drop-in):
- `WorldRoad.draw(x, y, w, h, actNumber)` / `WorldRoad.update(dt)`
- `WorldRoad.travel({distance, duration, onComplete})` — ease in-out + bob de passo
- `WorldRoad.isTraveling()` / `setBiome(n)` / `clearCache()`

**Integração** (`src/scenes/GameplayScene.lua`):
- `GameplayScene.SCENE_MODE = "worldroad" | "scene"` (scene = SceneLayer antigo)
- update detecta troca de `actNumber:floorInAct` → `WorldRoad.travel({distance=11, duration=2.6})`
- Bioma = actNumber (cicla se > 3)

## Arte: contrato PNG override (PixelLab futuro)

`getSprite(kind, variant)` procura `assets/sprites/world/<biomeId>_<kind>_<variant>.png`
ANTES de gerar procedural. Pra trocar placeholder por arte PixelLab, só dropar PNGs:
- Por bioma: `<id>_tree_0..2.png`, `<id>_bush_0..2.png`, `<id>_rock_0..2.png`,
  `<id>_landmark_0.png` — ids: `fields`, `highlands`, `abyss`, `frost`, `marsh`, `dusk`
- Neutros (sem bioma — tintados/reusados em runtime): `cloud_0..2.png`,
  `hero_walk_0.png` / `hero_walk_1.png` (2 frames de caminhada, VISTA DE COSTAS)
- Tamanhos de referência do procedural: tree 26×40, bush 18×12, rock 16×11,
  landmark 46×64, cloud 42×14, hero 18×26. PNG pode ser maior (escala compensa).
- Estilo: sufixo-padrão grimório sépia de `memory/backgrounds_catalog.md`.
- NUVENS são geradas em cinza-neutro e tintadas com `biome.cloud` no draw
  (a mesma nuvem cruza a transição de bioma mudando de cor).

## Tuning (constantes no topo de WorldRoad.lua)

`HORIZON_RATIO=0.42`, `DEPTH_K=14`, `Z_NEAR=0.9`, `Z_FAR=42`,
`ROAD_HALF_NEAR=0.16`, `CURVE_A/B=0.085/0.035`, `PROP_SPACING=2.6`,
`PIXEL_STEP=2` (scanlines chunky), `LANDMARK_EVERY=88`.

## Lições aprendidas

1. **Moiré**: faixas de mundo em projeção 1/z viram listras de 2-3px no fundo.
   Solução: contraste da banda × smoothstep(rowNorm) — banda só onde é grossa.
2. **Movimento no meio-campo**: sem bandas lá, usar PONTOS (manchas hash) que
   rolam — pontos não geram moiré, linhas sim.
3. Céu em 28 bandas (14 ficava visivelmente listrado em tela cheia).

## V2 (mesma sessão, auto mode)

- [x] **Herói andando**: sprite procedural de costas (2 frames, paleta neutra
  couro+aço), desenhado em `HERO_ROWNORM=0.80` da estrada só durante travel,
  fade in/out nos primeiros/últimos 15%, sombra oval, bob de passo contrafase.
- [x] **Poeira dos passos**: puffs spawnam a cada 0.16s na posição real do herói
  (`_heroScreenPos` setado no draw), física simples com fricção.
- [x] **Inimigo escondido na viagem**: GameplayScene pula EnemyRenderer/EnemyHud
  enquanto `WorldRoad.isTraveling()` — o monstro "aparece" ao chegar.
- [x] **Transição de bioma**: `setBiome` tira snapshot das cores ambientais e
  lerpa (smoothstep, `BLEND_DURATION=2.2s`) via `envColor(field)`. Props guardam
  `p.bid` (bioma do SPAWN) → paisagem velha passa com arte antiga, reciclados
  nascem com a nova. NÃO limpa cache na troca.
- [x] **Biomas 4-6 (endless)**: frost/marsh/dusk em `src/data/biomes.lua`.
  GameplayScene: endless usa `4 + floor((currentFloor-25)/8)` (actNumber trava
  em 4 no endless; currentFloor segue crescendo — ver RunManager:260-267).

## V3 (mesma sessão — feedback: "não tão bonito quanto a referência")

- [x] **Projeção de CRISTA** (o "mundo redondo" de verdade): rowNorm =
  (1/rel − 1/Z_FAR)/(1/Z_BOTTOM − 1/Z_FAR). Props brotam NO horizonte
  (rel=Z_FAR → topo do chão) e aceleram descendo — antes brotavam a 1/3 do
  chão (projeção plana), matava a sensação de dobra.
- [x] **Vista ascendente**: painel 256×88 por bioma (baked em canvas —
  montanhas em camadas + castelo multi-torre com janelas âmbar + linha de
  floresta), desenhado atrás da crista. SOBE conforme
  `(camZ % LANDMARK_EVERY)/LANDMARK_EVERY` → "dá pra ver que estou chegando".
  Crossfade entre vistas na troca de bioma. Bake é LAZY em draw (cache).
- [x] **Estrada modo-7**: pattern 64×64 das cartas (`roadPattern` no bioma,
  via BackgroundLoader) tile esticado na largura da estrada; texels encolhem
  com a distância e o V rola com o mundo. ⚠️ GRAMA testada com pattern e
  REVERTIDA — motivo de carta vira risco borrado como terreno; grama é cor
  chapada + bandas próximas + manchas hash (lição: textura modo-7 só funciona
  em superfície estreita/focal como a estrada).
- [x] **Encounter billboard**: `travel({encounter = EnemyRenderer.getEncounterBillboard(enemy)})`
  → sprite real do inimigo desce a estrada crescendo (scaleK = targetScale ×
  BATTLE_REL calibra handoff 1:1 com o EnemyRenderer na chegada).
- [x] **Inimigo PLANTADO na estrada**: GameplayScene usa
  `WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL, ...)` pro cy/cx da batalha
  (antes era height*0.68 fixo = flutuava). Sombra elíptica do EnemyRenderer
  REMOVIDA; idle bounce ±2→±1px.
- [x] **Props novos**: pine, deadtree, stump, fence, sign, flowers (cor
  `accent` do bioma), ruin. `propWeights` (tabela) substitui os 3 pesos fixos;
  fence/sign colam na beira da estrada (KIND_LANE).
- [x] TRAVEL_DISTANCE 11→28 / duration 2.6→3.6 (encounter precisa emergir da
  crista); LANDMARK_EVERY = 28×8.

## ⚠️ Incidente driver NVIDIA (Jul/04 2026) — pra próxima sessão

Após dezenas de launches rápidos do LOVE (screenshots), o driver NVIDIA
(nvoglv64.dll, RTX 2060 SUPER) entrou em estado corrompido: **stack overflow
0xC00000FD na criação de QUALQUER contexto GL do love.exe/lovec.exe** (até
projeto trivial; `--version` sem janela funciona). Diagnóstico: Event Log
Application, APPCRASH em nvoglv64.dll. Sem admin não deu pra reiniciar o
serviço NVDisplay; GLCache protegido. **Fix: usuário aperta Win+Ctrl+Shift+B
(reset do driver gráfico) ou reboot.** Código v3 teve sintaxe validada com
luac 5.4 standalone (winget DEVCOM.Lua → %LOCALAPPDATA%\Programs\Lua\bin).
Validação visual v3.2 PENDENTE: rodar `love . screenshot_worldroad travel`
+ `full` + smokes quando o driver voltar.

## V3.3 (pós-reboot — arte PixelLab + fix do driver)

- [x] **Suspeita do driver corromper**: quads com viewport FRACIONÁRIO
  minúsculo (dv até 0.15 texel) ~200×/frame no modo-7 da estrada. Fixes:
  viewport inteiro (`floor`) + bake de vista movido do draw pro update +
  **`WorldRoad.ROAD_TEXTURE = false` por padrão** (sem textura, o v3 usa as
  MESMAS operações GL do v2, que nunca envenenou). Teoria NÃO 100% provada
  (Mesa não serviu de bancada — ver abaixo); religar textura só como
  experimento controlado: 1 run → driver ok? → 2ª run → ok? → manter.
  ⚠️ Win+Ctrl+Shift+B NÃO desfaz o envenenamento — só REBOOT completo.
- [x] **Assinatura PixelLab ativa** (Tier 1, 2000 gerações/mês). Batch 1
  (bioma fields) gerado e instalado em `assets/sprites/world/`:
  tree_0 (carvalho), tree_1 (salgueiro), bush_0, rock_0, stump_0, fence_0,
  sign_0, flowers_0, landmark_0 (torre arruinada c/ janela acesa) e
  **fields_vista.png** (panorama 400×112 — montanhas + castelo + floresta).
- [x] **Vista PNG override**: `getVista` tenta `<id>_vista.png` antes do bake
  procedural. Panorama PixelLab é MUITO superior — gerar pros outros biomas.
- [x] **KIND_TARGET_H**: escala por tipo = target/ih (arte 64-96px e
  procedural 12-40px ocupam o mesmo espaço). Fallback de variante: sem PNG da
  variante N, usa PNG da variante 0 (não mistura procedural com arte real).
- [x] **Crop obrigatório**: PNGs do PixelLab vêm com sobra transparente no
  canvas → prop "flutua" (draw ancora no rodapé). SEMPRE cropar pro bbox
  (PIL `img.crop(img.getbbox())`) após download.
- [x] Estrada: base sólida + textura em alpha 0.85 (mata o look "remendado");
  TEX_V_DENSITY 3.5; densidade de props +30%, spread lateral 320.
- ⚠️ **Texturas seamless de chão NÃO saem via create_map_object** (gera
  objeto/blob com fundo transparente, ignora paleta). Usar create_topdown_tileset
  ou manter patterns existentes.
- ⚠️ **Mesa/llvmpipe (love-soft no scratchpad)**: roda projetos triviais mas
  crasha (E_INVALIDARG) no boot do jogo completo — causa não investigada.
  Serve só de fallback de emergência pra projetos simples.

## V4.2 (feedback do trailer + prints)

- [x] Domo TEXTURIZADO: `<biome>_ground.png` (256×256 PixelLab, tileável)
  rolando pra baixo com camZ, mascarado pelo círculo via **FATIAS VERTICAIS**
  (cada coluna desenha de crestYAt(x) até a base — segue o arco exato).
- [x] ⚠️ **ANTI-PATTERN: `love.graphics.stencil` PROIBIDO** — crashava o
  driver NVIDIA (0xC00000FD em nvoglv64) e envenenava o OpenGL da máquina
  inteira até reset do driver. Sintoma: love crasha em QUALQUER projeto.
  Máscaras circulares = fatias verticais, sempre.
- [x] Trilha de TERRA natural (não calçada): borda com wobble por fileira
  (hash), largura irregular, tom variando, marcas horizontais esparsas.
- [x] Props saem em CONE pelas laterais (lateral cresce com t^0.8 — 
  espalham pros cantos, não descem em linha reta).
- [x] Inimigo de batalha menor (targetHeight 320→255, boss 420→330).
- [x] Castelos REGENERADOS isolados: prompt precisa de "single isolated
  building only, nothing else, no trees no landscape, transparent
  background" — sem isso o PixelLab embute árvores/cenário cortado que
  conflita com o fundo. Pós-processo: flood-fill de borda (PIL) remove céu
  chapado + crop; **strips de montanha**: cortar linhas escuras do TOPO
  (outline do PixelLab virava "faixa preta" no céu — highlands tinha 11
  linhas, abyss 7).
- [x] Céu: cor amostrada do strip descendo até pixel claro/opaco + crossfade
  do céu no blend de bioma.

## V4.3 (feedback: "sem impressão de profundidade")

- [x] **`g.persp(t) = 0.10 + 0.90·t^1.65`** — função de perspectiva ÚNICA que
  governa TODOS os tamanhos (props, encounter, largura da estrada, bordas,
  pedrinhas). Antes cada sistema tinha curva própria (0.18+0.82t linear) e a
  profundidade parecia falsa. Contraste longe:perto agora é 1:10.
- [x] **Domo em MODO-7 real**: linhas horizontais com largura = corda do
  círculo naquele y (máscara exata sem stencil), texels crescendo 2.2→7.5px
  com a proximidade, V mapeado pela MESMA curva de profundidade dos props
  (GROUND_V_DENSITY=4.8). Antes a textura era escala única = "adesivo plano".
- [x] **Caminho RETO**: serpenteio removido (parecia torto); naturalidade vem
  das bordas com senos contínuos de baixa frequência (edgeAmp × persp) — nada
  de jitter por fileira.
- [x] **BATTLE_REL 16→9**: inimigo de batalha perto de nós (t≈0.56, ~74% da
  altura), SEPARADO do castelo na crista (antes ficava colado/engolido).
  Handoff do encounter normalizado: persp(t)/persp(tBattle) = 1.0 exato.
- [x] Treeline da crista com t=0.14 explícito (persp(0)=0.10 deixava 11px).

## V4.4 (feedback: "árvores fixas irreais" + "caminho não respeita a esfera")

- [x] **Treeline estática REMOVIDA** — anel fixo de árvores na crista
  denunciava o truque ("nunca mudam"). Substituída por densidade maior de
  props REAIS fluindo (PROP_SPACING 2.3→1.7, lane default até 1.05 = árvores
  alcançam as bordas; persp floor 0.10→0.14 pra presença no longe).
- [x] **Caminho envolve a esfera**: largura no topo = 30% da base
  (0.30+0.70·t^1.15), somindo POR CIMA da curva — antes convergia pra um
  ponto de fuga (cone), o que só existiria em plano infinito, não em esfera.

## V4.5 (feedback: castelos de lado, assets pequenos, mundo solto, interiores)

- [x] **fields_castle regenerado FRONTAL** — estava em vista isométrica 3/4.
  Prompt precisa de: "PERFECTLY FRONT-FACING straight-on view, symmetrical
  facade centered, NO isometric angle, NO three-quarter view". Os outros 5
  castelos já eram frontais (inspecionados 1 a 1).
- [x] **REGRA DE OURO de escala**: árvore perto > inimigo (~255px). KIND_SIZE
  ~1.5×: tree 3.8 (~375px na base), pine 4.2, bush 1.0, ruin 2.4 etc.
- [x] **Clusters naturais**: ~45% da vegetação spawna em grupo de 2-3
  (companheiras 68-80% do tamanho, offset lateral, tint 0.88) — mata o
  "muito solto".
- [x] **Perspectiva atmosférica** (pesquisa externa): props distantes (t<0.25)
  desenhados ANTES de uma banda de névoa que segue a curva da crista; props
  do meio/perto por cima, nítidos. Alpha/tint fade no longe
  (aFade = 0.72 + t*1.1). Fontes: Wulverblade faking-3D, pixel-art layering
  guides (fg escuro / mid claro / bg mais claro; longe = menos contraste).
- [x] **INTERIORES DE CASTELO por progressão**: nodes boss/mini_boss/elite
  lutam DENTRO do castelo — `assets/sprites/scenes/castle_hall_1/2/3.png`
  (400×256 PixelLab, um por ato: salão quente / gótico violeta / obsidiana
  infernal). GameplayScene decide por `run.currentNode.type`; inimigo em
  âncora fixa (0.5w, 0.68h); SEM WorldRoad.travel nesses nodes (entra direto).
  Fallback: SceneLayer do ato se o PNG faltar.

## ⚠️ FLUXO DE CENÁRIO — mapa pra mexer depois (o que acontece se...)

**Decisão de backdrop (GameplayScene.draw, ordem):**
1. `SCENE_MODE == "worldroad"` E node ∈ {boss, mini_boss, elite} → INTERIOR
   (castle_hall_<min(act,3)>). Enemy âncora fixa. Travel nunca dispara.
2. `SCENE_MODE == "worldroad"` (nodes battle/normais) → WorldRoad (esfera).
   Enemy âncora = getRoadAnchor(BATTLE_REL). Travel dispara na troca de
   floorKey (act:floor) EXCETO pra nodes de interior.
3. `SCENE_MODE == "scene"` → SceneLayer legado (PNG estático por ato).

**Se mexer em X, cuidado com Y:**
- Mudar `BATTLE_REL` → recalibra: posição Y do inimigo em batalha, escala do
  encounter no handoff (persp-normalizada), e o quanto ele fica separado do
  castelo. Testar k1 e k4 do tour.
- Mudar `T_POW`/`REL_CREST` → muda TODAS as curvas (props, estrada, chão
  modo-7 usa o inverso t^(1/T_POW)). Devem mudar JUNTOS ou a estrada "desgruda"
  do chão.
- Mudar `persp()` → afeta props + encounter + bordas da estrada; a LARGURA da
  estrada tem curva própria (0.30+0.70·t^1.15) — esfera exige topo largo.
- Adicionar node type novo que luta em interior → incluir na lista do
  GameplayScene (2 lugares: draw + skip do travel).
- Adicionar bioma → biomes.lua + gerar <id>_castle/_mountains/_ground (senão
  fallback procedural) + rawBiome cicla por módulo automaticamente.
- Trocar sprite de inimigo → getEncounterBillboard usa o static south.png;
  targetScale = EnemyRenderer (255/330px) — o tamanho de batalha manda.
- **NUNCA** reintroduzir `love.graphics.stencil` (crasha driver NVIDIA) nem
  `Stop-Process -Name love` (mata o jogo do usuário).

**Prováveis próximos problemas (previstos):**
- Interior 400×256 cover-fit em 1024×768 corta as laterais (aspect 1.56 vs
  1.33) — se compor algo importante nas bordas do hall, some. Gerar 340×256
  se incomodar.
- Elite em interior pode cansar (elite é frequente) — talvez só boss/mini_boss.
- Endless (bioma 4-6) usa castle_hall_<min(act,3)> = sempre o do ato 3.
- CRTShader por cima de tudo suaviza o pixel do interior — conferir com CRT on.

## Loop infinito de melhoria (ciclos autônomos — Jul/04 noite)

### 📋 RESUMO EXECUTIVO (13 ciclos, ~4h autônomas)

| # | Entrega |
|---|---|
| 1-2 | Sombras sob props + vento na vegetação + partículas ambientais/bioma |
| 3 | InteriorFX: tochas/brasas animadas nos 3 halls de castelo |
| 4 | Fumaça na chaminé do castelo (perto) + sulcos de desgaste na estrada |
| 5 | Luz ambiente do bioma nos props + fix ordem do crossfade (faixa no céu) |
| 6 | Fade de entrada no castelo (estrada→interior) |
| 7 | Sol/lua por bioma + pássaros cruzando o céu |
| 8 | Juice de chegada do inimigo (quicadas) + vinheta lateral |
| 9 | Pedrinhas na borda + auditoria completa + fix anel-fantasma da lua |
| 10 | Tile dedicado de terra (PIPELINE: tileset→subtile sólido→recolor lum.) |
| 11 | Sombras de nuvem no domo + tiles abyss/frost |
| 12 | Anti-repeat do tile + aves pousadas que decolam + tile marsh |
| 13 | Tiles highlands/dusk (6/6) + regressão completa (113 smokes) |

| 14 (v4.6) | LATITUDES REAIS da esfera (g.latY — mata curvatura invertida do campo próximo; props/estrada/sombras/manchas todos no arco) + fallback variante-0 de PNG (procedural tosco morto onde há arte) + props PixelLab highlands/abyss + anti-empilhamento (resolveOverlap) + cerca = linha de 3 + chão v2 (4 tons + oitavas + acentos) + critters (borboletas/vagalumes) |

| 15 (v4.7) | CURVATURA 100%: textura do domo TAMBÉM em fatias de latitude (as fileiras do padrão arqueiam — era o resto da contradição plano-vs-arco) + escala CONTÍNUA do encounter na emergência (era 0.5 fixo → encolhia ao cruzar a crista e ficava maior que árvore) + densidade 1.45 + camada de nuvens distantes |

| 16 (endless art) | frost_pine/rock instalados; modo `endless` no screenshot tool (painéis biomas 4-6); **céu neon-menta do marsh_mountains dessaturado** via HSV uniforme (lição: strip PixelLab pode vir com céu fora da paleta — passar QA de saturação; threshold parcial deixa mosqueado, transform uniforme alisa). ⚠️ PixelLab degradado (jobs travando em ~95%): marsh_deadtree/bush + dusk_tree/bush + marsh_flowers PENDENTES — jobs re-disparados, monitor de colheita em background, script process_world_assets.py pronto no scratchpad |

⚠️ **Incidente PixelLab (Jul/05 tarde)**: pipeline deles degradou — TODOS os
jobs de map_object travando em "95%, eta 0s" indefinidamente (30+ min), até
re-gerados. Não é rate limit nem crédito (assinatura ok). Padrão: create
retorna id normal, processing avança até 95% e congela. NÃO adianta re-gerar
durante o incidente (cria mais zumbis — deletar com delete_object). Pendentes
pra próxima janela: marsh_deadtree_0, marsh_bush_0 (nem gerado), 
marsh_flowers_0, dusk_tree_0, dusk_bush_0. Prompts prontos no histórico;
script de pós-processo: scratchpad/process_world_assets.py. Impacto: BAIXO
(props endless têm fallback procedural + frost completo + tiles/castelos/
montanhas de todos os 6 biomas já instalados).

| 17 (fix cercas) | Feedback "tanto de cerca junta": cercas NÃO entravam no anti-empilhamento e cada prop de cerca desenha linha de 3 → 2 props juntos = 6 cercas amontoadas. Fix: zona de exclusividade global de cerca (8+ unidades entre cercas, qualquer lado — excedente REBAIXA pra arbusto, mantém densidade) + peso fence 1.1→0.45 |

**Estado: AGUARDANDO FEEDBACK EM MOVIMENTO do usuário** — os ciclos 3-12 são
temporais (viagem, blends, tochas, aves, fumaça); stills validados, motion
precisa do olho dele. Loop retoma no primeiro feedback.
**Bloqueado:** sfx da viagem (ELEVENLABS_API_KEY inexistente na máquina).

**Ciclo 1-2 (entregues):** sombras elípticas sob props (ancoram no chão) +
balanço de vento na vegetação (rot ±0.018 rad, fase por p.z, pivô na base) +
partículas ambientais por bioma (`biome.ambient = {style, rate, color}`:
leaf/mote/ember(sobe!)/snow/spore — cap 36, sway senoidal, empurrão no travel).
⚠️ Bug pego no ciclo: cluster usava `p.jitter` que rollProp não setava →
runtime error → LOVE preso na tela de erro = parecia "hang" do tour. Lição:
**tour travado sem stdout = provável erro Lua na tela de erro do LOVE**, matar
e caçar nil.
⚠️ Assinatura alucinada do PixelLab no castle_hall_2 (canto inf-esq) removida
com patch espelhado do piso via PIL — SEMPRE inspecionar cantos de cena gerada.

**Ciclo 3 (entregue):** `src/ui/InteriorFX.lua` — tochas/brasas animadas nos
interiores: emissores relativos por ato (hall_1 tochas L/R, hall_2 candelabros,
hall_3 lava L/R + trono), glow pulsante 2 anéis com flicker de tocha, brasas
subindo com desaceleração. GameplayScene ticka no update (nodes de interior) e
desenha após o backdrop. Validado: composição de boss no tablado ficou
cinematográfica.

**Ciclo 4 (entregue):** fumaça da chaminé do castelo quando progress>0.55
(spawn no update via _castleTop setado no drawCastleOf; puffs expandem
subindo, desenhados junto do castelo atrás do domo) + sulcos de desgaste na
estrada (2 linhas a ±0.42·half, só t>0.45, alpha crescendo com proximidade).

**Ciclo 5 (entregue):** luz ambiente do bioma nos props (mix 16% da cor de
fog no tint — quente no abismo, frio na geleira; integra os sprites na
atmosfera) + FIX crítico no crossfade de montanhas/castelo: ordem invertida
(NOVO 100% por baixo, VELHO (1-t) por cima) — na ordem antiga o céu baked do
strip velho (mais alto pós-trim) ficava como faixa fixa no céu durante o
blend; agora a sobra esvai junto.

**Ciclo 6 (entregue):** fade de entrada no castelo — GameplayScene detecta
transição estrada↔interior (lastInterior), overlay preto ease-out 0.9s por
cima de tudo + InteriorFX.clear() ao entrar. Itens 4 (sulcos) e 6 (tint)
entregues nos ciclos 4-5. LOD (5) DESCARTADO: nearest-filter já degrada bem
à distância; custo > ganho. Validado: 55 smokes verdes.

**Ciclo 7 (entregue):** sol/lua por bioma (`biome.celestial = {kind, xr, yr,
r, color}` — disco + halo 2 anéis; lua = crescente via disco de cor-do-céu
deslocado; crossfade no blend; nuvens passam NA FRENTE) + pássaros (bando de
3-5 silhuetas "^" com batida de asa a cada 9-23s, cruzando o céu). Lição:
celestial precisa ficar na ZONA AZUL do céu (yr≈0.14) — na zona clara perto
do horizonte o disco pálido some (fields ficou invisível na 1ª tentativa).

**Ciclo 8 (entregue):** juice de chegada do inimigo (EnemyRenderer.
triggerArrival → 2 quicadas decrescentes em 0.55s via getArrivalOffset,
disparado pelo onComplete do travel) + vinheta lateral sutil (5.5% da largura,
alpha máx 0.16 — enquadramento cinematográfico). Sol reposicionado pra zona
azul validado no k4 (melhor frame até aqui).

**Ciclo 9 (entregue):** pedrinhas na borda estrada↔grama (esparsas, hash>0.72,
persp-scaled) + AUDITORIA COMPLETA dos 6 keyframes + interior. Achado e
corrigido: anel fantasma da lua (crescente por disco-de-céu tinha mismatch de
cor com o gradiente → trocado por disco cheio + 3 crateras). Estado geral:
k1-k6 + interior em nível profissional consistente; k4 é o frame-vitrine.

**Ciclo 10 (entregue):** tile dedicado de terra na estrada (modo-7 com
rolagem, quad generalizado pra qualquer tile size). **PIPELINE DESCOBERTO**
pra tiles de terreno no PixelLab:
1. `create_map_object` NÃO serve pra textura (recorta fundo → blob, ~33%
   cobertura — 2 tentativas falharam mesmo pedindo full-bleed).
2. `create_topdown_tileset` (mesmo terreno em lower E upper) → baixar o PNG
   do tileset → extrair o subtile SÓLIDO (score: zero pixels escuros de
   borda + 100% opaco, via PIL).
3. O tile vem saturado/vibrante → **recolorir por luminância** pra paleta
   alvo (lum → base_color × lum, contraste ×0.75) — vira terra sépia calma.
Salvo em assets/sprites/world/road_dirt.png (32×32; getRoadTile aceita
road_dirt_<bid>.png por bioma).

**Ciclo 11 (entregue):** sombras de nuvem no domo (elipse alpha 0.07 sob cada
nuvem, deslizando junto — céu "conectado" ao chão) + tiles por bioma via
pipeline do ciclo 10: road_dirt_abyss.png (terra vulcânica escura) e
road_dirt_frost.png (neve compacta). Seleção do subtile agora por MENOR
DESVIO-PADRÃO de luminância (mais robusto que contagem de pixels escuros).
Nota: o screenshot 3-painéis captura biomas em MEIO-blend (setBiome
sequencial + 30 ticks < 2.2s) — montanhas misturadas ali é artefato do tool.

**Ciclo 12 (entregue):** offset-u aleatório por faixa de mundo no tile da
estrada (repeat morto) + AVES pousadas em cercas (55% das cercas, 1-2 aves de
3px no trilho de cima) que DECOLAM em arco quando rel<6.5 (viram _birds com
vyr negativo decaindo — arco de voo) + road_dirt_marsh.png (lama, pipeline
ciclo 10). g agora expõe y/h (conversão tela→coords de céu pro takeoff).

**Ciclo 18 (entregue — colheita endless completa, 05/Jul):** infra PixelLab
voltou após incidente de 04/Jul (jobs travados em 95%). Dos 4 jobs zumbis,
3 expiraram (TTL 8h), mas marsh_deadtree COMPLETOU antes de expirar e foi
resgatado via curl. Re-gerados os 4 restantes (completaram em ~2min):
marsh_bush (juncos/taboas), marsh_flowers (cogumelos pálidos), dusk_tree
(árvore roxo-crepúsculo), dusk_bush (tufo de trigo dourado). Pipeline:
download curl Bearer → process_world_assets.py (flood+crop) → validado no
screenshot endless (3 painéis OK). **Todos os 6 biomas agora têm props 100%
PixelLab.** Lição: jobs completados TAMBÉM expiram em 8h — baixar
imediatamente ao ver status completed, nunca "deixar pra depois".

**Ciclo 19 (entregue — escala + distribuição, 05/Jul):** feedback "tamanhos
pequenos, esquerda vazia, direita amontoada". 4 causas raiz em WorldRoad.lua:
(1) KIND_SIZE calibrado pra base mas props vivem em t≈0.3-0.5 → +25% geral
(tree 3.8→4.6 etc.); (2) clusters com offset ±0.55×iw e escala ~igual
empilhavam 3 árvores no mesmo pixel → companheiras agora afastam ~1 largura
pro próprio lado, escala 0.5-0.63, apoiadas em latY da própria posição x e
com sombra; (3) p.side moeda 50/50 sem memória dava streak → _sideBal
(saldo ponderado: árvores 1.0, cerca/placa 0.7, resto 0.35) puxa a
probabilidade pro lado mais leve (clamp 0.15-0.85); (4) espaçamento médio
~1.9 → PROP_SPACING 1.45→1.05 + jitter 1.2→0.9. Validado em full/travel/
endless — árvore perto > inimigo, lados equilibrados, clusters orgânicos.

**Ciclo 20 (entregue — massa visual + cerca-linha, 05/Jul):** feedback "tanto
de coisa na esquerda quase nada na direita + cercas todas juntas". 3 fixes:
(1) cluster agora SOMA no _sideBal (+0.55/companheira) — grupo de 3 pesava
como 1 árvore e desequilibrava a tela mesmo com sorteio balanceado;
(2) flip do resolveOverlap ia pra lado aleatório (desfazia o saldo) → agora
vai pro lado mais leve e atualiza _sideBal; (3) segmentos da cerca-linha:
espaçamento 0.85→1.7 (em t médio comprimiam num bolo) e sem extras quando
t<0.35. BÔNUS: companheiras de cluster só espalham pra FORA (p.side) —
offset ± deixava a interna invadir a estrada. REGRA: qualquer coisa que
multiplique massa visual de um lado (cluster, linha de cerca) precisa
entrar no saldo de lados, senão o balanceamento é ilusório.

**Ciclo 21 (entregue — CUNHAS ref APK, 05/Jul):** feedback com anotação
vermelha: "elementos SÓ podem aparecer nas cunhas laterais (lateral do
castelo → canto de baixo da tela) e quase todas preenchidas, igual ao APK".
Redesign do posicionamento lateral:
- `lateral = side × w × (inner + lane×0.30)` com `inner = 0.13 + 0.44×t` —
  a zona permitida é o triângulo castelo→canto; na base só os cantos
  extremos têm props, o corredor central fica SEMPRE limpo.
- KIND_LANE virou fração [0,1] DENTRO da cunha (0=diagonal interna, 1=borda).
- populate spawna nos DOIS lados por passo de z (90% cada) — simetria por
  construção, _sideBal só pros spawns avulsos de travel.
- TREELINE dedicada: passada extra a cada ~1.4-1.9 z-units com árvore
  GARANTIDA (tree/pine/deadtree por bioma, lane 0.2-0.8, 50% cluster) —
  o sorteio misto gasta ~40% em tufo/flor e deixava buracos na parede.
- resolveOverlap mantém o lado (re-rola lane + nudge z) — flip de lado
  brigava com a simetria forçada.
Validado travel + endless: parede de floresta contínua dos 2 lados, igual
referência. Fórmula antiga do cone (0.14+1.15t^1.8) NÃO existe mais.

**Ciclo 22 (entregue — parede persistente + árvores dominantes, 05/Jul):**
feedback "todos os lados COMPLETAMENTE preenchidos + árvores muitas vezes,
resto poucas". Causa raiz do esvaziamento: a RECICLAGEM (prop passa da
base → renasce atrás da crista) re-rolava kind no sorteio misto — as
árvores da treeline viravam tufos conforme o jogador viajava e a parede
dissolvia. Fixes: (1) p.wall=true nos props de treeline + makeWall()
helper; reciclagem preserva LADO (simetria eterna) e identidade de parede;
(2) pickKind com multiplicadores: árvores ×3.5, resto ×0.5, bônus de tufo
2.5→0.7 (árvores ~70% do sorteio misto); (3) treeline mais densa (step
1.15-1.6). REGRA: densidade que só existe no populate() é ilusória — o que
define o mundo em regime é o que a reciclagem preserva.

**Ciclo 23 (entregue — props emergem da curvatura + cunha larga, 05/Jul):**
feedback: "árvores/itens longe precisam ter o MESMO comportamento do
monstro (corpo tampado pela curvatura) + aumentar o range de spawn".
- drawPropsBehind(): novo passe entre drawEncounterBehind e drawDome —
  props com rel em (REL_CREST..+EMERGE_BAND] desenham ANTES do fill do
  domo com a base afundada (sink = (1-em)×ih×s), mesma matemática do
  inimigo (escala em t=0 → continuidade perfeita ao cruzar a crista).
  Companheiras de cluster emergem junto. Tint 0.66 (distante).
  Antes: tOf retornava nil além da crista → prop PIPOCAVA ao cruzar.
- Cunha mais larga: lane×0.30→0.38 (na crista os props chegam à borda da
  tela; embaixo aprofundam os cantos) — 2 lugares (props + cerca).
- Treeline mais densa: step 1.15→0.95.
Painter's order atualizado: ...castle → encounter-behind → PROPS-BEHIND →
dome fill → road → props(front) → encounter-front.

**Ciclo 24 (entregue — funil + ritmo + opacidade, 05/Jul):** feedback:
"afunilar mais / viagem rápida demais, inimigo chega rápido / árvores às
vezes transparentes". (1) Funil: inner 0.13+0.44t → 0.11+0.38t (3 lugares:
props front, cerca, props-behind usa 0.11). (2) Ritmo: TRAVEL_DISTANCE
28→20, TRAVEL_DURATION 3.6→5.0 (SEGMENT_LEN acompanha = 160). (3) CAUSA da
transparência: o fade atmosférico usava aFade também no canal ALPHA
(0.72 em t=0) — o domo vazava através das árvores distantes. Agora aFade
só escurece (brilho), alpha sempre 1. Lição: fade atmosférico em pixel art
opaca = brilho/cor, NUNCA alpha (alpha lê como "fantasma", não como longe).

**Ciclo 25 (entregue — saída real dos props, 05/Jul):** feedback: "árvore
perto da tela só some, não desaparece aos poucos". Causa: reciclagem em
rel<-0.5 cortava o prop com meia copa visível. Fix: `over = max(0,-rel)`
no drawList — depois de rel<0 o prop DESLIZA pra fora (inner += over×0.16,
sy += over×0.20×g.h → acelera pro canto e pra baixo, como algo passando do
seu lado); reciclagem só em rel<-3.5 (~0.9s de slide, já fora da tela).
Continuidade perfeita em rel=0 (over=0). latY tem fallback bottomY+40 pra
dx grande, então o slide nunca produz NaN.

**Ciclo 26 (entregue — viagem 6.5s + sombras saneadas, 05/Jul):**
(1) TRAVEL_DURATION 5.0→6.5 ("deixe mais lenta a animação").
(2) SOMBRAS DE NUVEM REMOVIDAS (eram do ciclo 11): as elipses deslizando
no gramado liam como "bolas sem sentido dentro do terreno" e, passando
sob árvores, como sombra flutuante descolada — nuvem de background
distante não projeta sombra no chão do primeiro plano. NÃO reintroduzir.
(3) Sombra dos props 0.34→0.22×iw (main e companheiras): elipse na
largura da copa sobrava pros lados (embaixo de ar) e lia como flutuação —
sombra abraça o TRONCO. Diagnóstico importante: PNGs estavam justos
(scan de margem transparente), o problema era só de render.

**Ciclo 27 (entregue — raiz cortada + base enterrada, 05/Jul):** feedback:
fields_tree_1 "estranha, parte da raiz fica de fora". Causa: a geração
PixelLab original tinha a raiz CORTADA reta na borda do canvas — exposto
quando a árvore fica grande no primeiro plano. Fixes: (1) fields_tree_1
re-gerada (prompt com "roots fully visible... nothing cut off at edges",
job 62bbc200) — carvalho com raízes completas; (2) base ENTERRADA: árvores/
pinheiros/mortas/arbustos desenham com sink2 = 4% da altura pra dentro do
gramado (main + companheiras de cluster) — esconde corte de canvas de
QUALQUER sprite e assenta a raiz na grama. Sombra fica em sy (contato
visual com o chão). Checklist de novo sprite de árvore: pedir margem em
todos os lados no prompt + conferir corte de raiz antes de instalar.

**Ciclo 28 (entregue — névoa só no horizonte, 05/Jul):** feedback dusk:
"dá pra ver a borda do mundo em cima das árvores". Causa: drawCrestFog
seguia crestYAt(x) na LARGURA INTEIRA — a curva da crista desce até os
cantos, e a névoa pintava a borda do domo POR CIMA das árvores laterais
(farPass, t<0.25). Em fields a névoa sépia disfarçava; em dusk a laranja
denunciou. Fix: clamp fogLimitY = crestApexY + 22% da altura do domo —
névoa só na faixa central do horizonte. Cores custom de chão (pedidos do
usuário): fields #1E3E1F, highlands #335559, marsh #5E7F27, dusk #5D404B
(grassA = hex, grassB ≈ -18%).

**Ciclo 29 (entregue — riscos diagonais na estrada, 05/Jul):** feedback:
"caminho com pixels estranhos em todos os mapas" (riscos diagonais
oliva). Causa: pedrinhas/torrões do drawRoad eram re-desenhados a CADA
fileira de 2px enquanto rowId (faixa de mundo, floor(worldZ*2.3)) fica
constante por muitas fileiras perto da câmera; como xL/xR mudam por
fileira, px2 = xL + hpos×(xR-xL) deslizava a cada linha → a "pedrinha"
virava risco diagonal. Fix: lastDecoRow — decoração PONTUAL (pedrinhas
internas + torrão de transição) desenha 1x por rowId, altura sz (não
step). Bordas quebradas continuam por fileira (são textura contínua de
borda, o smear é o efeito desejado ali). Tiles estavam limpos (scan) e
setWrap repeat já ok — era 100% lógica de render.

**Ciclo 30 (entregue — emersão só no horizonte central, 05/Jul):**
feedback: "ainda dá pra ver a borda em cima das árvores" (dusk, laterais).
Causa: drawPropsBehind desenhava emergentes em QUALQUER lateral — nas
bordas a curva da crista desce íngreme e o fill do domo cortava as copas
em diagonal. Fix: emersão clampeada à faixa central do horizonte
(crestYAt(pxX) < crestApexY + 22% da altura do domo — mesmo clamp da
névoa do ciclo 28). Nas laterais o prop entra direto no passe frontal,
pequeno sobre a superfície (pop imperceptível). REGRA: tudo que segue a
curva da crista (névoa, emersão, luz) deve existir SÓ na faixa central —
a curva nas laterais é "borda do mundo", não "horizonte".

**Ciclo 31 (entregue — frestas da estrada, 05/Jul):** feedback: "ainda
cheio de pixels estranhos no caminho" (pós ciclo 29 — as pedrinhas eram
outro bug). Causa REAL dos riscos diagonais: as fatias de latitude da
estrada (segmentos 16px × 2px) caem em floor(latY) — quando duas fileiras
consecutivas arredondam com 3px de distância vertical, sobra FRESTA de
1px onde a grama de baixo vaza (verde sobre lama = gritante no marsh).
Fix: overdraw vertical de +1.5px em cada fatia (tile e fallback) — a
fileira seguinte cobre a emenda. Validado em fields e marsh (novo modo
full<N> no screenshot_worldroad: "full5" = bioma 5 em tela cheia).

**Ciclo 32 (entregue — luz da crista vira arco, 05/Jul):** feedback: "a
corzinha da borda aplicada nas árvores à frente, não respeita
profundidade". Era a LUZ DA CRISTA: circle("line") COMPLETO do planeta —
o arco descia pelas laterais por cima das silhuetas da treeline da
crista. Fix: arc("open") limitado a ±phiMax onde
phiMax = acos(1 - bandH/R), bandH = 22% do domo — terceiro elemento
clampeado pela regra do ciclo 30 (névoa, emersão, agora luz). Validado
full6: laterais limpas.

**Ciclo 33 (entregue — clamp da crista por LARGURA, 06/Jul):** feedback:
"ainda sobressai nas árvores no cenário 6". O clamp por altura (c28/c30/
c32, crestYAt < apex+22%) era GEOMETRICAMENTE RASO: perto do topo a curva
dip é pequena (dip=110px só a 0.59w com R=1.6w) — árvores a 0.4w ainda
emergiam e o domo pintava faixa de grama por cima (zoom mostrou o
"sanduíche": copa emergente atrás + banda de domo + árvore da frente).
Fix definitivo: critério HORIZONTAL |dx| < 0.26w-0.30w nos três (emersão,
névoa, arco de luz). REGRA ATUALIZADA: a faixa central da crista se
define por LARGURA (|dx| do centro), nunca por altura da curva — a curva
é rasa demais no topo pra separar centro de lateral.

**Ciclo 34 (entregue — CAUSA RAIZ da "borda sobre as árvores", 06/Jul):**
após 3 fixes parciais (c28/c30/c32/c33 — todos reais mas insuficientes),
o diagnóstico definitivo: os sprites PixelLab têm FUROS TRANSPARENTES
INTERNOS entre os tufos de folha (dusk_tree_0: 167px! fields_tree_1:
112px) — a linha clara da borda do mundo passa POR TRÁS da árvore e vaza
pelos furos, desenhando a "cor da borda" na forma da copa. Nada estava
na frente: era o fundo vazando POR DENTRO. Fix: flood-fill de borda
identifica bolsões internos (não alcançáveis) e preenche com média dos
vizinhos ×0.85 (vira sombra de copa) — 20 sprites corrigidos, cerca
PULADA (vãos entre ripas são design). Backup em scratchpad/
world_backup_c34. LIÇÃO DE PIPELINE: todo sprite novo do PixelLab deve
passar pelo scan de furos internos ANTES de instalar (adicionar ao
process_world_assets.py). Sprites com furo parecem OK isolados — só
denunciam com fundo de alto contraste atrás.

**Ciclo 35 (entregue — ARO DE BRILHO da esfera, 06/Jul):** o usuário
esclareceu: "vejo esse brilho em TODOS os biomas, o final da esfera".
Era o CÍRCULO-BASE do domo (grassA chapado, mais claro que a textura):
as fatias da textura assentam na latitude do CENTRO do segmento de 32px;
perto da borda lateral a curva cai vários px dentro do próprio segmento
e o degrau expõe o círculo-base em escadinha → ARO CLARO contornando a
silhueta inteira da esfera, atrás das árvores (lido como "brilho
sobressaindo das árvores"). Fix: círculo-base grassB×0.78 (mais escuro
que qualquer texel) — o que vaza vira SOMBRA de borda, natural em esfera.
Sagas relacionadas: c28-c33 (efeitos da crista) e c34 (furos de sprite)
eram bugs reais mas NÃO este. Diagnóstico fechou quando o usuário disse
"em todos os biomas" — brilho biome-independente ⇒ código comum ⇒ domo.

**Ciclo 36 (entregue — NADA brilhante desenha sobre árvores, 06/Jul):**
o print do usuário fechou o caso: a franja laranja seguindo a borda POR
CIMA das copas era a NÉVOA DA CRISTA — o design antigo era far props →
névoa → near props (atmosfera "sobre o longe" de propósito), e as árvores
perto da crista estão DENTRO da faixa central clampeada, então todos os
clamps de posição (c28/c33) nunca poderiam resolver — era a ORDEM.
Fixes: (1) drawCrestFog ANTES de qualquer árvore (atmosfera nas árvores
longe já existe via aFade); (2) critters + partículas ambientais movidos
pra ANTES de drawProps (folha dourada/vagalume sobre copa escura lia como
brilho). REGRA FINAL DA SAGA (c28→c36): NENHUM efeito luminoso desenha
depois dos props — árvore oclui tudo que é do campo (névoa, partícula,
critter, luz). Só vinhetas (escuras) e UI ficam na frente.

**Ciclo 37 (entregue — v5 A ENCRUZILHADA, 06/Jul):** escolha de caminho
IN-WORLD substitui o MapScreen na estrada. WorldRoad ganhou:
- showFork(nodes, onChosen) / isForkActive / forkHitTest / forkMousePressed;
  constantes FORK_REL=10, MARK_REL=17.5, ARRIVE_REL=7.5, FORK_SPREAD=0.15.
- drawRoad refatorado: paintRow(cxRow, halfMul, aMul, decorate, bright) —
  fileiras com rel>FORK_REL pintam 1x POR BRAÇO (offset smoothstep, largura
  0.78, hover 1.14 de brilho). Braços não escolhidos: alpha→0 no converge.
- Marcos: landmark_<battle|elite|rest|shop|event|chest>.png (PixelLab,
  LANDMARK_FOR_TYPE/LANDMARK_SIZE), pill com label sempre + desc no hover,
  glow no chão, bob. Desenhados DEPOIS dos props (UI interativa — exceção
  consciente à regra "nada sobre árvores"). markBoxes = hitboxes frame-fresh.
- Convergência: clique → braço escolhido easa pro centro enquanto camZ
  avança MARK_REL→ARRIVE_REL (2.4s) → _landmark plantado no centro (desliza
  na próxima viagem, some em rel<-3) → onChosen(node, idx).
- Integração main.lua: showMapSelection usa fork quando SCENE_MODE=worldroad
  (MapScreen = fallback); estado mapSelection roteia update/draw
  (GameplayScene.drawWorldOnly — mundo sem inimigo/mão)/mouse/teclas 1-3.
- Validação: modos "fork" e "fork2" (meio da convergência) no
  screenshot_worldroad. validate_cards verde.
Assets: 6 landmarks em assets/sprites/world/ (cabana, fogueira, tenda
mística, estandarte, obelisco, baú — baú reservado pra node treasure futuro).

**Ciclo 38 (entregue — castelos v2 + chegada no portão + cantos, 06/Jul):**
(1) 6 castelos RE-GERADOS 220px (era ~130): centrados, simétricos, portão
frontal GRANDE, sem elementos extras. Batalha de prompts: highlands v1
veio com nuvens, abyss v1/v2 lavado+disco, dusk v1/v2 com halo — v3 com
"sprite isolated on transparent background, no halo no disc no moon"
resolveu (dusk/highlands); abyss precisou de cirurgia PIL (remoção do
disco creme por cor na metade superior). De-speckle: componentes
conectados <25px fora do corpo principal = fragmentos → removidos
(fields 1451px!, abyss 1061px). (2) APROXIMAÇÃO: escala 1.0→4.2
(progress^1.4, era 1.0→2.5 linear) + afundamento 26%→3% no fim — no
último andar o PORTÃO domina o quadro (modo "gate" no screenshot pra
validar, camZ=92% do segmento). (3) CANTOS PRETOS (telas largas): rect
full-frame na cor grassB×0.78 ANTES de tudo no WorldRoad.draw — pixel
não coberto mostra terra do bioma, nunca preto.

**Ciclo 39 (entregue — roster v5 Ato 1, 06/Jul):** monstros do zero,
identidade grimório: cursed_scarecrow (comum), harvest_reaper (elite/
mini-boss), carrion_king (boss) — create_character v3 (96/96/128px,
low top-down) + animações template (breathing-idle→idle 4f,
taking-punch→hurt 6f, falling-back-death→death 7f, south only).
PIPELINE NOVO: ZIP do PixelLab mudou (aninhado sob <name>/, pastas SEM
hash: animating/taking_a_punch/falling_backward) — install manual via
bash inline (install_enemy_animation.sh desatualizado). Pós-processo:
crop pela UNIÃO dos bboxes de todos os frames (corte idêntico = sem
jitter) + 2px respiro. EnemyRenderer: (1) ENEMY_ROSTER data-driven
ato×nodeType (atos 2-3 ainda legado); (2) escala ADAPTATIVA
targetHeight/ih float (o piso max(4,...) era pra sprites de 50px e
virava kaiju com canvas 176+; legado ih<=80 mantém piso); (3)
enemy.isBoss agora É setado em Game:nextPhase (boss/mini_boss → 330px).
UUIDs (expiram? characters persistem na conta): scarecrow 7c8af239,
reaper 5404a43d, king 4251fb01. PENDENTE: rosters atos 2-3 + biomas
endless (mesma receita).

**Ciclo 40 (entregue — ROSTER COMPLETO atos 1-3, 06/Jul):** 9 monstros
novos (identidade grimório, v3 low top-down, idle/hurt/death south):
- Ato 1: cursed_scarecrow / harvest_reaper / carrion_king
- Ato 2: moon_gargoyle / rune_golem / tower_lich (UUIDs 57d8e618/
  b4ec75e9/b02615b3)
- Ato 3: ember_imp / obsidian_sentinel / abyss_tyrant (49602e59/
  aecd31c5/6bcb0c1e)
ENEMY_ROSTER completo por ato×nodeType. Lições novas: (a) fila do
PixelLab Tier 1 = 8 jobs — enfileirar em ondas; (b) animação PODE falhar
("Generation failed") — checar failed jobs no get_character e re-disparar
(morte do tirano falhou 1x, retry ok); (c) frames de retry vêm no canvas
original — recortar separadamente. Legado (grave_slime/stone_golem/
abyss_wraith) mantido como fallback. PENDENTE: monstros específicos dos
biomas endless (frost/marsh/dusk) — roster hoje repete ato 3 no endless.

**Ciclo 41 (entregue — 5 fixes do feedback do fork, 06/Jul):**
(1) CRASH ao escolher caminho: LANDMARK_FOR_TYPE/SIZE/getLandmark eram
locais declarados DEPOIS de WorldRoad.update no arquivo → nil dentro do
update. Movidos pra antes. LIÇÃO LUA: local declarado abaixo não existe
pra função definida acima — sempre declarar tabelas compartilhadas no
topo da seção que as usa primeiro. (2) Estrada "muito certinha": meandro
orgânico no centro (2 senos worldZ*0.14/0.047, amp 0.024w×(0.3+0.7t));
fork usa wob×0.5. (3) Marcos MAIORES que árvores (são lugares): shop
5.2, event 5.0, elite 4.4, rest 3.6, battle 3.4, chest 2.6. (4) Árvores
nos caminhos do fork: supressão por corredor (|pxX-centro do braço| <
half+0.045w some enquanto fork ativo) + emersão pausada no fork.
(5) Castelos transparentes in-game: vazamentos internos CONECTADOS à
borda por canais finos (remoção de fundo da geração comeu parede) — fix:
preencher transparente cercado por opaco nos 4 sentidos (R=40) — fields
3283px!, abyss 3835px, frost 1983px. fork2 agora atravessa a convergência
completa (85 ticks) = prova onChosen sem crash.

**Ciclo 42 (entregue — v5.2, 06/Jul):** (1) marco escolhido persistia na
tela quando a PRÓXIMA encruzilhada abria → showFork limpa _landmark
("deixamos o lugar pra trás"). (2) Estrada torta DE VERDADE: roadWobble()
compartilhado (3 senos worldZ*0.11/0.30/0.71, amp 0.045w×(0.28+0.72t),
depende do worldZ ABSOLUTO) usado por drawRoad + getRoadAnchor +
drawForkMarks (×0.5) + drawLandmarkFront + encounterFront/Behind — o
inimigo DESCE A CURVA e tudo assenta na estrada torta. REGRA: qualquer
âncora "no centro da estrada" passa por roadWobble, nunca g.cx puro.
(3) Castelos: vazamento via canais finos (ameias) escapava do fill 4-dir
→ método EROSÃO (r=2) + flood da borda + dilate r=3; o que o flood não
alcança = vazamento (fields 1719px, abyss 1756px, frost 1705px). Ameias
perdem os vãos (aceitável na escala do jogo).

**Próximos ciclos (fila fina — plateau de qualidade atingido):**
14. Sfx da viagem — ⚠️ BLOQUEADO: precisa ELEVENLABS_API_KEY
21. Aguardar feedback do usuário jogando (viagem/blends/interiores em MOTION
    é onde os ciclos 3-12 aparecem; stills já validados)

## Backlog

- [ ] **Validação visual v3.3 nativa** (precisa driver resetado; testar em
  estágios: screenshot single → repetir → tour completo)
- [x] ~~Gerar batches PixelLab dos outros 5 biomas~~ — CONCLUÍDO no ciclo 18
  (todos os 6 biomas com props PixelLab)
- [ ] Herói PixelLab (create_character vista NORTE + animate walk 2-4 frames)
- [ ] Entrada do inimigo ao fim da viagem (materialize/juice em vez de pop)
- [ ] Sfx de passos durante travel (Sfx.play com pitchVariation)
- [ ] Variação de landmark por bioma (hoje é a mesma torre com paleta trocada)
- [ ] Avaliar textura modo-7 na grama com pattern DEDICADO de terreno
  (gerar via PixelLab um tile "grass_ground" sem motivos — aí sim funciona)
