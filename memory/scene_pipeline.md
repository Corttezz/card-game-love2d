---
name: Scene Pipeline (cenários ricos + overlays animados)
description: Como gerar novos cenários full-res via pixellab + integrar com SceneLayer (scene PNG + tochas/props animados). Lição aprendida: tileset repetido fica POBRE — scene única detalhada é o caminho.
type: project
---

# Pipeline de Cenários

## Filosofia

**O cenário bonito vem de uma IMAGEM ÚNICA RICA**, não de tileset procedural repetido. Os 7 PNGs originais em `assets/sprites/scenes/` (menu, gameplay, victory, etc.) são 400×256 cheios de detalhe — profundidade, composição, mood. **Esse é o padrão.**

**Animação do cenário** acontece por cima via **overlays de código**:
- Tochas piscando (flicker de alpha + glow radial)
- Cristais pulsando (pulse de alpha + tint)
- Smoke atmosférico ambient (já existe)
- Parallax vertical sutil (±2px sin wave) no próprio scene PNG
- Tint multiplicativo por ato (muda humor sem regerar)

Tiles Wang procedural são bom pra mapas grandes de jogos exploração, **não pra arena estática de combate** que o jogador olha fixo. Lição aprendida.

## Arquivos do pipeline

| Arquivo | Papel |
|---|---|
| `src/ui/SceneLayer.lua` | Renderiza scene PNG com tint + parallax + props animados |
| `src/ui/SceneBackground.lua` | Loader de PNG full-screen com cache |
| `assets/sprites/scenes/<name>.png` | Cenários ricos (400×256, gerados via pixellab) |
| `assets/sprites/map_objects/<name>.png` | Props animados (tochas, coluna, etc.) |
| `tools/install_scene.sh` | Baixa e instala scene gerada |
| `tools/install_map_object.sh` | Baixa e instala prop (backlog — por ora curl inline) |

## Dimensões e estilo

- **Scenes full-screen:** 400×256 (limite do `create_map_object` que temos usado). Proporção ~1.56:1 bate com tela 1024×768 via cover-fit.
- **Props:** 48×48 a 96×96. View=side (perspectiva lateral).
- **Estilo:** dark fantasy grimoire, paleta sépia limitada (ver sufixo-padrão abaixo).

**Sufixo de prompt obrigatório** (cole ao final de toda description):

> `dark fantasy grimoire illustration pixel art, inked engraving style, earthy desaturated palette (bone white, rust orange, deep blood crimson, tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, detailed shading with clear darks and mid-tones, dramatic silhouette, moody upper-left lighting, limited 8-color palette, Slay the Spire and Magic the Gathering card art aesthetic`

## Passo-a-passo: criar um novo cenário

### 1. Pensar a COMPOSIÇÃO antes de gerar

Um bom scene 400×256 tem:
- **Foreground**: 1-2 elementos grandes no primeiro plano (pilar quebrado, altar, esqueleto)
- **Midground**: arena onde o combate acontece (piso, parede de fundo)
- **Background**: detalhes distantes (arco de caverna, vitral, céu sangrento)
- **Light source**: vindo do canto superior esquerdo (consistência com props)

Ex: cena "catacumbas" tem escadaria de pedra descendo ao fundo + arco de tijolos + piso rachado + ossos jogados + lanterna pendurada.

### 2. Gerar via pixellab MCP

```lua
mcp__pixellab__create_map_object({
  description = "<DESCRIÇÃO RICA DE COMPOSIÇÃO> + <sufixo-padrão>",
  width = 400,
  height = 256,
  view = "side",
  outline = "single color outline",
  shading = "detailed shading",
  detail = "high detail",
})
```

**Exemplos de descrição rica:**

- Catacumbs (ato 1):
  > stone catacomb chamber with cracked archway at back, skull piles on both sides, rusted iron brazier in corner, sepia stone walls with visible mortar, dim light from upper left, eerie atmosphere, wide horizontal composition with empty center floor for combat arena
- Torre (ato 2):
  > ancient stone tower interior, spiral staircase climbing along back wall, arcane runes glowing faintly on pillars, broken stained-glass window letting in violet light, scattered scrolls and bones on tiled floor, wide horizontal composition
- Abismo (ato 3):
  > abyssal void chamber carved into black rock, cracks in floor leaking violet mist, twisted obsidian spires rising at sides, distant red eye glowing from shadow at back, corpse fragments floating, cosmic dread atmosphere, wide horizontal composition

**Anti-pattern nas descrições:**
- ❌ "background pattern" → gera tileset, não cena
- ❌ "simple", "minimalist" → pixellab faz bem com complexidade
- ❌ evitar pedir texto/símbolos → pixellab não escreve bem
- ❌ evitar "characters" no scene → enemy sprite entra depois

### 3. Aguardar e baixar

O `create_map_object` é async (30-90s). Polling via `get_map_object(uuid)`. Quando `Status: ready`:

```bash
./tools/install_scene.sh <UUID> catacumbs
```

O script baixa e instala em `assets/sprites/scenes/catacumbs.png`.

### 4. Registrar no SceneLayer

Em `src/ui/SceneLayer.lua`, procure `ACT_CONFIGS` e aponte:

```lua
[1] = {
    name = "catacumbs",
    scenePng = "catacumbs",        -- nome sem extensão
    fallbackScene = "gameplay",    -- usa se catacumbs.png ainda não existe
    tint = { 1.00, 0.95, 0.85 },
    parallaxY = 1.5,
    props = { ... },
},
```

### 5. Adicionar props opcionais

Props são sprites animados SOBRE o scene (tochas, cristal). Gerar via `create_map_object` size 32-96, instalar em `assets/sprites/map_objects/<name>.png`, adicionar em `ACT_CONFIGS[N].props`.

Tipos de anim suportados pelos props:
- `"torch"`: flicker alpha + glow laranja radial
- `"crystal"`: pulse alpha + tint vermelho
- `nil`: estático

## Cenários planejados (backlog)

### Ato 1 (Catacumbas) — parcial
- [x] Props: torch, column, skull_pile, crystal
- [ ] Scene dedicada `catacumbs.png` (atualmente usa `gameplay.png` como fallback)
- [ ] Variante noturna `catacumbs_night.png` pra bossfight

### Ato 2 (Torre de Pedra)
- [ ] Scene `stone_tower.png`
- [ ] Props: pillar_arcane (pilar com runas), floating_book, rune_crystal

### Ato 3 (Abismo)
- [ ] Scene `abyss.png`
- [ ] Props: shadow_statue, void_rift, tentacle, dark_altar

### Bosses (opcional)
- [ ] `boss_catacumbs.png` — scene dramática pra boss do ato 1
- [ ] `boss_stone_tower.png`, `boss_abyss.png`

### Telas (não-combate)
- [x] menu.png, gameplay.png, victory.png, gameOver.png, collection.png, classSelection.png, cardReward.png (todas já existem; regerar qualquer uma via mesmo pipeline)

## Pipeline de props

Mesmo esquema das scenes, com tamanhos menores:

```lua
mcp__pixellab__create_map_object({
  description = "<prop description> + <sufixo-padrão>",
  width = 64,   -- ou 48, 96 conforme escala desejada
  height = 64,
  view = "side",
  outline = "single color outline",
  shading = "detailed shading",
  detail = "high detail",
})
```

Install (curl direto ou via script):
```bash
curl -sS --fail -o assets/sprites/map_objects/<name>.png \
  "https://api.pixellab.ai/mcp/map-objects/<UUID>/download"
```

Registrar em `SceneLayer.ACT_CONFIGS[N].props`:
```lua
{ id = "<name>", xr = 0.45, yr = 0.75, scale = 3, anim = "torch" }
```
- `xr`/`yr`: posição relativa (0..1) — **relativa ao canvas da tela** (não à PNG)
- `scale`: multiplicador (2-4 típico)
- `anim`: `"torch"` | `"crystal"` | `nil`
- `flipH = true`: inverte horizontalmente

## fireEmitters (partículas de fogo) — IMPORTANTE

Se a scene PNG tem **tochas/fogueiras/luzes pintadas na arte**, adicione emitters pra partículas de fogo saírem dessas posições exatas:

```lua
fireEmitters = {
    { xr = 0.12, yr = 0.145 },  -- posição relativa à PNG
    ...
}
```

**Diferença crítica vs props:**
- `props[].xr/yr` é **relativo ao canvas da tela** — muda de posição visual conforme a tela corta a scene (cover-fit)
- `fireEmitters[].xr/yr` é **relativo à PNG original** — sempre nasce onde a tocha está pintada, independente da resolução

**Como encontrar as coordenadas das tochas:**
1. Abra a PNG gerada (`assets/sprites/scenes/<scene>.png`) num editor
2. Localize o pixel onde a CHAMA começa (topo da tocha)
3. `xr = pixel_x / imgW`, `yr = pixel_y / imgH`
4. Adicione ao ACT_CONFIGS

**Por que relativo à PNG, não ao canvas?** Scene usa cover-fit (`math.max(sx, sy)`), então partes da imagem são cortadas dependendo da proporção da janela. Coords relativas ao canvas fazem a partícula aterrissar onde a tocha NÃO está visível. Coords relativas à PNG + transform (calculado por `SceneBackground.getCoverTransform`) garantem mapeamento correto em qualquer resolução.

## Workflow típico (gerar ato 2 completo)

```bash
# 1. Dispara scene + 3 props em paralelo via MCP tools
# (ver doc dos MCP tools em create_map_object)

# 2. Aguarda ~2min. Pollar get_map_object.

# 3. Instalar
./tools/install_scene.sh <uuid_scene>  stone_tower
curl -sS --fail -o assets/sprites/map_objects/pillar_arcane.png  \
  "https://api.pixellab.ai/mcp/map-objects/<uuid_pillar>/download"
curl -sS --fail -o assets/sprites/map_objects/floating_book.png  \
  "https://api.pixellab.ai/mcp/map-objects/<uuid_book>/download"

# 4. Editar SceneLayer.lua ACT_CONFIGS[2].props pra incluir os novos props

# 5. Testar
love .
```

Custo típico: 4 créditos (scene + 3 props) por ato.

## Troubleshooting

**Scene ficou mole/borrada**
→ Descrição genérica demais. Reforçar elementos concretos ("skull piles on both sides", "dim torchlight from upper left"). Evitar adjetivos abstratos ("mysterious", "dark") sem elementos visuais.

**Cores neon/roxas apareceram**
→ Esqueceu o sufixo de estilo. Sempre cole "NO neon colors, NO bright magenta or cyan".

**Scene tem texto/símbolos bizarros**
→ Pixellab não escreve bem. Evitar pedir "runes with text", "inscriptions". Pedir "faint symbols" genérico.

**Props com proporção errada na tela**
→ Ajustar `scale` em `ACT_CONFIGS[N].props`. Scale=3 é default; 2 pra props delicados, 4 pra elementos grandes.

**Scene não carrega**
→ Verificar nome do arquivo em `scenes/` bate com `scenePng` em `ACT_CONFIGS`. Verificar que é PNG válido (`file <scene>.png`). SceneLayer cai pro `fallbackScene` automaticamente se principal não existir.

## Anti-pattern conhecido (não repetir)

❌ **Usar tileset procedural (Wang 4×4) como base do cenário** — tentei isso na Tier 1-D e ficou visualmente pobre. 16 tiles de 32×32 repetidos em grid dão sensação de "chão de jogo de Super Nintendo sem arte direction". Serve pra MAPAS grandes de exploração, não pra arena fixa.

✅ **Usar scene PNG 400×256 como base + overlays animados (props, smoke, parallax)** — este é o approach atual.
