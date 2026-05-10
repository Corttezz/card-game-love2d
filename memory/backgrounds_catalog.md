---
name: Backgrounds Catalog
description: Inventário completo de TODOS os backgrounds/scenes/tilesets do jogo. Padrões obrigatórios pra gerar novos via pixellab MCP mantendo coerência visual.
type: project
---

# Catálogo de Backgrounds

Fonte de verdade pra **manter coerência visual** quando gerar novos assets. Sempre antes de chamar `mcp__pixellab__create_map_object` ou `create_topdown_tileset`, consulte:

1. **Categoria** — scene full-screen, path vertical, pattern tileável, map node, etc.
2. **Dimensões** — fixas por categoria (não improvise)
3. **View / outline / shading** — fixos por categoria
4. **Prompt template** — copiar/adaptar
5. **Sufixo de estilo obrigatório** (final do prompt) — sempre o mesmo

## Sufixo de estilo obrigatório (cole no FINAL de TODA description)

> `dark fantasy grimoire illustration pixel art, inked engraving style, earthy desaturated palette (bone white, rust orange, deep blood crimson, tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, detailed shading with clear darks and mid-tones, dramatic silhouette, moody upper-left lighting, limited 8-color palette, Slay the Spire and Magic the Gathering card art aesthetic`

Sem esse sufixo, o pixellab gera com cores aleatórias e quebra a coerência sépia/grimoire.

---

## Categoria 1: Scenes 400×256 (telas inteiras + cenários de ato)

**Onde aparecem:** background full-screen via `SceneBackground.draw(<name>, w, h, alpha)` (cover-fit com `math.max(sx,sy)` e overlay escuro).

**Geração via pixellab:**
- Tool: `mcp__pixellab__create_map_object`
- Width: **400**, Height: **256** (proporção ~1.56:1, bate tela 1024×688)
- View: `side`
- Outline: `single color outline`
- Shading: `detailed shading`
- Detail: `high detail`

**Como integrar:**
- Salvar em `assets/sprites/scenes/<name>.png`
- Tela usa via `SceneBackground.draw("<name>", w, h)` ou `SceneLayer.ACT_CONFIGS[N].scenePng = "<name>"`

### Inventário atual (17 scenes 400×256)

| Nome | Quem usa | Composição |
|---|---|---|
| **menu.png** | `Menu:draw` | Grimoire em altar com velas, parede de pedra rachada |
| **splash.png** | `BootScene.drawBackground` | Câmara ritual com runas douradas + feixe de luz central (Balatro splash) |
| **gameplay.png** | Fallback do `SceneLayer` | Arena genérica de combate |
| **classSelection.png** | `ClassSelectionScreen` | Tela de escolha de classe |
| **cardReward.png** | `CardRewardScreen` | Recompensa de carta / shop |
| **collection.png** | `CollectionScreen` | Tela de coleção de cartas |
| **gameOver.png** | `drawGameOver` em main.lua | Tela de derrota |
| **victory.png** | `drawVictory` em main.lua | Tela de vitória |
| **catacumbs.png** | `SceneLayer` ato 1 | Arena ato 1 — arco escuro, tochas, crânios, cristais |
| **stone_tower.png** | `SceneLayer` ato 2 | Arena ato 2 — vitral violeta, escadaria, pilares com runas |
| **abyss.png** | `SceneLayer` ato 3 | Arena ato 3 — olho vermelho, fenda violeta, espinhos obsidian |

**Backlog (ainda não geradas):**
- `boss_catacumbs.png` / `boss_stone_tower.png` / `boss_abyss.png` — variantes dramáticas pra boss fight de cada ato

### Prompt template — Scene full-arena de combate

> `<descrição da CENA composta — composição rica em foreground/midground/background> + <sufixo obrigatório>`

**Exemplo (catacumbs):**
> stone catacomb combat chamber interior, wide horizontal composition with large empty flat floor in center for battle arena, cracked stone archway at back wall with deep darkness beyond, two iron wall-mounted torches with bright orange flames on left and right walls casting warm glow, piles of human bones and skulls in both lower corners, toppled broken stone column with moss on lower-left foreground, single jagged crimson crystal shard embedded in floor at bottom center, ancient sepia stone walls with visible mortar seams and cracks, dim ambient light with strong warm torch glow from both sides, dramatic moody atmosphere, foreground mid background depth, **+ sufixo obrigatório**

**Anti-patterns:**
- ❌ Compose com personagens humanóides ("warrior in center") — eles são desenhados via EnemyRenderer
- ❌ "battlefield" sem detalhar composição — IA gera coisa genérica
- ❌ Usar texto/runas legíveis — pixellab não escreve bem; pedir "faint symbols" genérico

---

## Categoria 2: Path scenes 256×400 (MapScreen vertical)

**Onde aparecem:** painéis verticais full-height do `MapScreen` quando jogador escolhe próximo nó.

**Geração via pixellab:**
- Tool: `mcp__pixellab__create_map_object`
- Width: **256**, Height: **400** (proporção 1:1.56, vertical)
- View: `side`
- Outline: `single color outline`
- Shading: `detailed shading`
- Detail: `high detail`

**Nota:** o pixellab às vezes força quadrado (256×256) mesmo pedindo 256×400. Aceitar — cover-fit no MapScreen lida com proporções diferentes.

**Como integrar:**
- Salvar em `assets/sprites/scenes/path_<nodeType>.png`
- `nodeType` deve bater com `MapManager.NODE_TYPES`: `battle`, `elite`, `mini_boss`, `boss`, `shop`, `rest`, `event`
- MapScreen carrega automaticamente via `loadPathScene(node.type)` (não precisa registrar)

### Inventário atual (7 path scenes)

| Nome | Tipo | Composição |
|---|---|---|
| **path_battle.png** | BATTLE | Arco escuro de catacumba, tochas laterais, esqueletos no chão, silhueta inimiga |
| **path_elite.png** | ELITE | Trono medieval, banners crimson, sangue no chão, tochas em pedestais |
| **path_rest.png** | REST | Caverna com fogueira central, cama com cobertor vermelho, panela, bolsa |
| **path_shop.png** | SHOP | Mercador encapuzado em barraca, prateleira de poções, ouro, baú |
| **path_event.png** | EVENT | Câmara mística, altar de cristais violeta, runas flutuantes, mist arcano |
| **path_boss.png** | BOSS | Portões épicos com crânio dourado, gárgulas, tochas vermelhas, eye atrás |
| **path_mini_boss.png** | MINI_BOSS | (cópia do path_boss — backlog: gerar variante distinta) |

### Prompt template — Path scene vertical

Sempre comece com `VERTICAL portrait composition` e termine com `cinematic vertical framing for game menu` antes do sufixo:

> `VERTICAL portrait composition, <descrição rica do cenário do caminho>, perspective looking into the chamber, cinematic vertical framing for game menu, + sufixo obrigatório`

**Exemplo (rest):**
> VERTICAL portrait composition, cozy rest camp inside small stone cavern, bright crackling campfire at center with logs and stones around, bedroll with leather blanket, hanging cooking pot, traveler backpack with potions and scroll, warm orange firelight illuminating cavern walls, peaceful safe atmosphere, perspective looking into the cave, vertical framing for game menu, **+ sufixo obrigatório**

---

## Categoria 3: Patterns 64×64 tileáveis (fundo de carta)

**Onde aparecem:** dentro do `CardArtSlot` em cada carta procedural — patterns repetidos com tint do tipo de efeito.

**Geração via pixellab:**
- Tool: `mcp__pixellab__create_topdown_tileset` ou imagens individuais
- Dimensões: **64×64**
- View: `high top-down`
- Outline: `lineless` (importante! não tem outline preto, é texture-like)
- Shading: `basic shading`
- Detail: `medium detail`
- **Tileável** (sem bordas duras de cor; ele tile perfeito)

### Inventário atual (17 patterns)

`stone, fire, ice, blood, metal, void, poison, arcane, ghost, impact, rage, shadow, soft, storm, wave, wind, abyss`

Cada pattern é tilizado em runtime pelo `BackgroundLoader.get(name)` que aplica `setWrap("repeat")` automático.

### Prompt template — Pattern tileável

> `seamless tiling texture of <materia/elemento>, top-down view, lineless pixel art, basic shading, earthy desaturated palette (sepia tones), no harsh edges, repeats perfectly when tiled`

**Exemplo (metal):**
> seamless tiling texture of tarnished dark steel armor plates with rivets, top-down view, lineless pixel art, basic shading, earthy desaturated palette (sepia tones), no harsh edges, repeats perfectly when tiled

**Importante:** patterns NÃO levam o sufixo padrão (eles são lineless e mais sutis que scenes). Use o template específico acima.

---

## Categoria 4: Map node sprites 96×96 (props no MapScreen / map)

**Onde aparecem:** sprites pequenos representando o tipo de nó (modo MapScreen antigo OU como overlays no MapScreen futuro).

**Geração via pixellab:**
- Tool: `mcp__pixellab__create_map_object`
- Width/Height: **96×96**
- View: `high top-down`
- Outline: `single color outline`
- Shading: `detailed shading`
- Detail: `high detail`

**Como integrar:**
- Salvar em `assets/sprites/map_nodes/<name>.png`
- Registrar em `MapManager.NODE_META[<TYPE>].sprite = "<name>"`

### Inventário atual (4 sprites)

| Nome | Tipo | Visual |
|---|---|---|
| **chest.png** | (reserva) | Baú de tesouro fechado com bandas de ferro |
| **campfire.png** | REST | Fogueira top-down com chama amarela |
| **shop_tent.png** | SHOP | Tenda listrada vermelha + cream |
| **altar.png** | EVENT | Altar de pedra com vela dourada e dagger |

**Backlog:** `arena_pit` (battle), `crown_skull` (boss/mini_boss), `forge_anvil` (rest variant), etc.

### Prompt template — Map node sprite

> `<objeto isolado descrito>, top-down view, dark fantasy game map prop, + sufixo obrigatório`

**Exemplo (campfire):**
> burning campfire with crackling yellow orange flames, logs arranged in teepee, small circle of stones around, warm glow on ground, **+ sufixo obrigatório**

---

## Categoria 5: Tilesets Wang 4×4 (futuro / não-ativo)

**Onde aparecem:** atualmente NENHUM lugar do código consome esses tilesets. Foram gerados em Tier 1-D mas removidos do uso (decisão: scene única > tile repetido pra arena estática).

**Status:** infraestrutura pronta (`SceneBackground.getCoverTransform`, `BackgroundLoader`), mas tilesets reservados pra futuras telas de exploração tipo overworld map (se um dia tivermos).

**Geração:**
- Tool: `mcp__pixellab__create_topdown_tileset`
- 4×4 grid de 16 Wang tiles
- Tile size: 32×32 (default)
- Salvar em `assets/sprites/tilesets/<id>/tileset.png` + `metadata.json`

### Inventário atual (1 tileset)

| Pasta | Status |
|---|---|
| `tilesets/act1_catacumbs/` | Gerado mas inativo (substituído por scene PNG) |

---

## Categoria 6: Legados (raramente usados)

| Arquivo | Uso |
|---|---|
| `assets/backgrounds/step1.png` | Background antigo de gameplay; ainda referenciado em `BackgroundConfig.GAMEPLAY` como fallback distante. Não regerar. |
| `assets/backgrounds/202509071408.mp4` | Video legado, não consumido pelo código. Pode deletar. |

---

## Workflow recomendado pra adicionar background novo

1. **Identifique a CATEGORIA** (1-5 acima). Use as dimensões e parâmetros corretos.
2. **Escreva descrição rica** seguindo o template da categoria. Sempre cole o sufixo.
3. **Dispare `mcp__pixellab__create_map_object` (ou create_topdown_tileset)**.
4. **Aguarde + poll** via `get_map_object`/`get_topdown_tileset`.
5. **Baixe** via:
   - Scenes: `./tools/install_scene.sh <UUID> <name>`
   - Map nodes: `curl -sS --fail -o assets/sprites/map_nodes/<name>.png "https://api.pixellab.ai/mcp/map-objects/<UUID>/download"`
   - Tilesets: `curl -sS --fail -o assets/sprites/tilesets/<id>/tileset.png "<backblaze URL do metadata>"`
6. **Registre** no código (SceneLayer ACT_CONFIGS, MapManager NODE_META, etc.) se necessário.
7. **Smoke test:** `love . smoke_all` deve continuar verde.
8. **Visual check:** `love . screenshot_gameplay` ou `love . screenshot_mapscreen` pra confirmar.

## Coerência visual — checklist obrigatório

Antes de aceitar uma scene gerada, valide:

- [ ] Paleta sépia (NÃO tem magenta/cyan/neon)
- [ ] Outline preto 1px (exceto patterns que são lineless)
- [ ] Composição rica (foreground/mid/back com profundidade)
- [ ] Iluminação superior-esquerda dramática
- [ ] Texto/símbolos sem letras legíveis (pixellab erra texto)
- [ ] Personagens humanóides ausentes (eles entram via sprite separado)
- [ ] Encaixa visualmente com as 17+ scenes existentes (compare lado a lado)

Se falhou: ajuste prompt e regere. Pixellab é determinístico-ish — pequenas mudanças no prompt mudam composição.

## Custos típicos

| Asset | Créditos | Tempo |
|---|---|---|
| Scene full 400×256 | 1 | 60-90s |
| Path scene 256×400 | 1 | 60-90s |
| Map node 96×96 | 1 | 30-60s |
| Tileset Wang 4×4 (16 tiles) | 1 | ~100s |
| Pattern 64×64 | 1 | 30s |

Rate limit: 8 jobs concorrentes. Pra batch grande, dispare em waves de 6-8.
