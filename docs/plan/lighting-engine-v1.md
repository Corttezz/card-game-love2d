# LightEngine v1 — Motor de Iluminação do WorldRoad

> **Status:** IMPLEMENTADO até F2 + F3 parcial + **F6.1 (entardecer por andar)**
> (Jul/2026) — ver `memory/lighting_engine.md` para o estado real e armadilhas
> descobertas (POOL_MIN_T, lightWindowColor, oclusão). NOTA: a limitação de
> bleeding screen-space (§3/F-2) foi RESOLVIDA além do planejado — oclusão por
> silhueta no lightmap (painter por z: luzes fundas → silhueta ambiente →
> luzes próximas), pixel-perfeito e sem stencil. Pendentes: F4 (bruma por
> fatia), F5 (gated: LUT/variação tonal/god rays), F6.2/6.3 (interiores/bloom).
> Plano revisado por passe adversarial (§11). Pesquisa em 9 frentes
> (4 leitores de código + 5 dossiês web).
> **Prova de conceito:** [`lighting-engine-v1-mockup.png`](lighting-engine-v1-mockup.png)
> — simulação offline do pipeline (lightmap ¼ res, posterização, multiply) sobre captura
> real. O mood da referência é atingível; a v2 do mockup incorpora as emendas da revisão
> (luz por janela, micro-luzes de vagalume, falloff mais duro).

---

## 1. Objetivo

Elevar a cena WorldRoad ao nível da imagem de referência (mockup do usuário sobre o
`demo_worldroad`): lanterna acesa na beira da estrada, braseiro de pedra, janelas do
castelo vivas, vagalumes com brilho, entardecer dramático com contraste quente×frio,
névoa de profundidade e moldura escura — **mantendo 60fps, zero stencil e a estética
pixel-art sépia do projeto**.

### 1.1 Decomposição da referência (o que exatamente falta)

| # | Elemento na referência | Estado atual | Camada do motor |
|---|---|---|---|
| 1 | Ambiente entardecer (céu quente, sombras frias roxas) | paleta boa, luz chapada uniforme | **Ambiente por bioma** (F1) |
| 2 | Lanterna em poste com poça de luz quente | prop não existe | **Fontes pontuais** (F2) |
| 3 | Braseiro/tocha de pedra com fogo | prop não existe | **Fontes pontuais** (F2) |
| 4 | Janelas do castelo iluminando de verdade | assadas no PNG, sem efeito no entorno | **Fontes pontuais** (F2) |
| 5 | Vagalumes com glow espalhados | 6 critters tímidos, só em biomas escuros | **Vida emissiva** (F3) |
| 6 | Névoa entre camadas de floresta | véu atmosférico existe, sem relação com luz | **Profundidade** (F3) |
| 7 | Contraste centro-claro/bordas-escuras | vinhetas fixas alpha 0.32/0.16 (mantidas) | **Ambiente** (F1) |
| 8 | Poça d'água refletindo o céu | não existe | fora de escopo v1 (§10) |
| 9 | Grading rico (darks coloridos, não cinza) | cores diretas da paleta | **LUT opcional** (F5) |

---

## 2. Diagnóstico do estado atual (capturas Jul/2026)

- `love . screenshot_worldroad all` → 6 biomas: paletas fortes (dusk/abyss já são
  "entardecer" de arte), mas **nenhuma fonte de luz local, nenhuma interação luz×cena**.
- A composição da referência é 1:1 com `screenshot_worldroad enemy1_cursed_scarecrow` —
  o que falta é literalmente um passe de luz.
- Render: WorldRoad desenha **direto no framebuffer** (sem canvas próprio), dentro do
  canvas full-screen do CRTShader (`main.lua:801/878`). Sprites nearest com escala
  contínua por perspectiva (`g.persp(t)` / `g.scaleAt`, dentro de `domeGeom`,
  `WorldRoad.lua:130-181`). Não há grid fixo de pixel-art — o "pixel lógico" varia
  com a profundidade (~4px perto, ~1px no horizonte).

## 3. Lições do projeto que o motor DEVE respeitar (não-negociáveis)

Histórico verificado em `memory/worldroad_scene.md` + comentários no código:

1. **"Luz em pixel art se DESENHA na paleta, não se sobrepõe com alpha."**
   (comentário-lápide em `WorldRoad.lua` ~1155-1157). Já foram implementados e
   **removidos por feedback**: god rays aditivos (v6.6), rim light aditivo (v6.3),
   glow de janelas `CASTLE_GLOW_K` (v6.4), **sombras de nuvem** (ciclo 26 — "NÃO
   reintroduzir": nuvem distante não projeta sombra no primeiro plano; objeção
   CONCEITUAL, não técnica), faixa de luz da crista.
2. **Zero `love.graphics.stencil`** — crash de driver NVIDIA (memory
   `research_libs_pixellab.md`). Nada no plano usa stencil nem depth attachment.
   (Scissor é permitido — não toca stencil/depth.)
3. **Painter's order é sagrado** — nenhum efeito luminoso desenha DEPOIS dos props;
   só vinhetas escuras e UI ficam na frente.
4. Halos de alpha baixo só são tolerados **sobre fundos escuros/uniformes e pequenos**.
5. Véus grandes de baixa frequência (véu atmosférico, vinhetas) são aceitos —
   o banido é gradiente *colado em silhueta de sprite*, liso OU posterizado
   (dither-xadrez em cunha ao redor de uma torre é franja de nova geração — §11 F-1).

### Por que o LightEngine não repete o erro do v6

O v6 **somava** luz por cima da arte (add/alpha → franja). O LightEngine **multiplica**
a cena por um mapa cujo teto é 1.0 (canvas `rgba8` normalizado + clamp do blend add):
ele só *escurece em direção ao ambiente* e *devolve* a arte original onde há luz —
**por construção nunca cria cor acima do que o artista pintou**. Brilho "acima da arte"
(chama, vagalume, janela) continua **pintado na paleta** (regra 1) — sprites emissivos
com glow assado + micro-luzes que "furam" o escurecimento local (§6.5).

**Limitação assumida (screen-space):** o lightmap não conhece profundidade — uma luz
grande no horizonte vazaria sobre céu/montanha atrás do emissor, e uma copa na frente
de uma lanterna receberia luz que deveria ser bloqueada. Política (§6.4): raios
proporcionais à escala do emissor na tela (`persp(t)`), luzes de horizonte pequenas e
fracas, bleeding aceito apenas em poças de chão próximas (padrão Stardew). Isso está
na tabela de riscos (§9).

---

## 4. Pesquisa — síntese e vereditos

### 4.1 Libs LÖVE2D

| Lib | Stencil? | Vivo? | Veredito |
|---|---|---|---|
| light_world.lua (tanema) | **sim (núcleo)** | nov/2025 | ignorar |
| lighter (speakk) | **sim (núcleo)** | parado | ignorar |
| Shädows (matiasah) | não | morto (2020) | referência de blend apenas |
| **Luven** (halsten-dev) | não | 2024 | **copiar arquitetura (~40 LOC)** |
| bitumbra (a13X-B) | não (depth16) | ativo 2026 | observar; sem occluders não precisamos |
| **moonshine** (vrld) | não | congelado-estável | adotar só se F5 precisar (bloom/godsray); miolo gaussian caro — preferir Kawase |

Padrão Luven = pipeline canônico da comunidade
([thread Night effect t=78200](https://love2d.org/forums/viewtopic.php?t=78200),
[Luven](https://github.com/halsten-dev/Luven)): canvas de luz com clear na cor
ambiente + luzes com blend `add` + composição `multiply, premultiplied`.

### 4.2 Semântica de blend e API (LÖVE 11.x — verificado)

- `setBlendMode("multiply", "premultiplied")` é **obrigatório** — `multiply` com
  `alphamultiply` é **erro de runtime** em 11.x (changelog 11.0).
- **O multiply também multiplica o alpha do destino.** Como compomos DENTRO do canvas
  do CRTShader: lightmap limpo com **alpha = 1** (`clear(r,g,b,1)`); luzes acumuladas
  com `add`+`alphamultiply` (fórmula `res.a = dst.a` — alpha do lightmap fica 1).
- `screen_coords` no `effect()` de shader = pixel do **render target ativo**
  (o lightmap ¼) — o Bayer sai no grid certo de graça.
- **GLSL do LÖVE (compat ES/1.20): sem inicializador de array const** — a tabela
  Bayer vai como if-chain (inclusa em §6.2), padrão do glsl-dither.
- **Quads de luz precisam de UV [0,1]**: `love.graphics.rectangle` não fornece UV
  úteis — desenhar uma **Image branca 2×2 escalada** (ou Mesh) com o shader.
- `love.graphics.transformPoint(x, y)` existe em 11.x e converte coords locais→tela
  com o transform stack ativo (necessário para submits dentro do room-sway).
- Recorte do composite à área da cena: `love.graphics.setScissor(x, y, w, h)`
  (sem stencil; barato).

### 4.3 Números de produção (referências de calibração)

- **Terraria** (decompilado): pôr-do-sol fase 1 tint ≈ `(235,120,170)`/255; noite
  quase acromática `(35,35,35)` → quem faz o contraste são as tochas.
- **Stardew** (decompilado): escuridão anima um **escalar** 0.3→0.93 com cor fixa;
  lightmap em **baixa resolução** com upscale; luzes de rua = **2 sprites sobrepostos**
  (halo largo fraco + núcleo pequeno forte).
- **Graveyard Keeper**: ambiente por gradiente temporal + **10 LUTs** interpoladas +
  fog em camadas + sombras cisalhadas (nosso `sunShadowDir` já é isso).
- **Songs of Conquest**: "o color grading É o dia/noite".
- **Mark Ferrari / saint11 / consenso pixel-art**: luz dinâmica quantizada em 2-4
  degraus; dentro do sprite a luz é assada; runtime age em superfícies de baixa
  frequência (chão, névoa, céu).

### 4.4 Técnicas avançadas — vereditos

| Técnica | Veredito |
|---|---|
| Normal maps (Laigter/auto) | **não** — arte IA já tem luz pintada; auto-gen vira "emboss" |
| Emissive mask + bloom Kawase | futuro (F6.3) — é a resposta certa para "glow além da silhueta" (janelas do castelo contra o céu); começar SEM bloom |
| God rays radial blur (70 taps) | **não** contínuo; já removido 2× no projeto |
| God rays quads dithered | experimento F5, gated por aprovação visual |
| Sombra de nuvem / variação tonal | experimento F5, gated (já removida no ciclo 26 — §8) |
| Heat haze quad sobre fogo | ok F3 (quantizar offset por texel) |
| LUT grading (strip 256×16) | ok F5 opcional — 1 Texel extra/px, antes do CRT |
| Reflexo em poça | fora do v1 (§10) |

---

## 5. Decisões de arquitetura

1. **Lightmap multiplicativo, multiply-only, sem stencil** (§3).
2. **Resolução ¼, filter nearest, formato `rgba8`** (clamp ≤ 1 garantido — parte do
   argumento de segurança).
3. **Duas filas de luz:**
   - **Luzes com shader** (cap 16): poças de chão e fontes médias — falloff `(1-d²)²`
     (opção `(1-d²)³` se o degrau intermediário "ferver" em movimento), posterizado
     em `LEVELS` degraus; **dither Bayer 4×4 SÓ em poças de chão próximas** (texel ≈
     pixel lógico). Luzes pequenas/de horizonte: **2 degraus SEM dither**.
   - **Micro-luzes** (cap 64): pontos raio 4-12px desenhados direto no lightmap
     (retângulo/imagem radial minúscula, sem shader, custo ~zero) — vagalumes, brasas,
     chamas, janelas. O "glow" do vagalume É o de-escurecimento local (regra 4:
     halo pequeno sobre fundo escuro).
   - Overflow: descartar por menor `raio × intensity`, nunca por ordem de submit.
4. **Raio sempre escala com a perspectiva**: `radius_tela = radius_base × persp(t)`
   (mesma curva dos sprites) — lanterna no horizonte tem poça minúscula.
5. **Fontes nascem no draw** — quem desenha o prop conhece a posição final na tela;
   registra a luz no mesmo frame; composite no fim.
6. **Emissivos pintados na arte** (glow assado no PNG) + micro-luz por cima. O
   antigo conceito de `boost()` (dividir cor pelo ambiente) foi **rejeitado na
   revisão** (§11 F-3): não restaura canal saturado e pode clarear acima da arte
   perto de luz pontual. Sobrevive só como `tintCompensate()` para superfícies
   difusas (acentos do GrassField), com teto `min(1, c / max(ambient, 0.55))`
   **aplicado em conjunto, nunca por canal isolado** (preserva matiz).
7. **Dados por bioma em `src/data/biomes.lua`** com crossfade grátis via
   `ENV_FIELDS`/`envColor`.
8. **Motor em `engine/LightEngine.lua`**; **toggle persistido** (`lighting`) no
   padrão do CRT. OFF = frame idêntico ao atual (fail-safe).

---

## 6. Design detalhado

### 6.1 Módulo `engine/LightEngine.lua` (~180 LOC)

```lua
local LightEngine = {}
LightEngine.enabled = true       -- bind em _G.gameSettings.lighting no boot

-- Início do frame de luz (1x, no começo de WorldRoad.draw, após domeGeom).
-- ambient = {r,g,b} JÁ LERPADO pelo crossfade (envColor("lightAmbient")).
-- Canvas lazily recriado se a janela mudou (padrão CRTShader.beginScene).
function LightEngine.beginFrame(ambient) end

-- Luz com shader (fila 1, cap 16). Coordenadas de TELA — quem chama de dentro
-- do room-sway converte antes com love.graphics.transformPoint(x, y).
-- spec = { x, y, radius, color = {r,g,b}, intensity = 0..1,
--          dither = false,              -- true SÓ para poças de chão próximas
--          levels = nil,                -- default Config.Lighting.LEVELS; 2 p/ horizonte
--          flicker = nil|"fire"|"pulse", seed = n }
function LightEngine.submit(spec) end

-- Micro-luz (fila 2, cap 64): ponto raio 4-12px, sem shader.
function LightEngine.submitMicro(x, y, radius, color, intensity) end

-- Desenha o lightmap (clear ambient alpha=1 → luzes add) e compõe
-- multiply/premultiplied sobre a região, com setScissor(x,y,w,h) durante o
-- draw (o canvas ¼ arredonda pra cima; o scissor recorta o excedente e
-- protege TopBar/HUD). GUARD: se beginFrame não rodou neste frame (ex.:
-- interiores), é no-op — caminho sem luz nunca escurece a cena.
function LightEngine.composite(x, y, w, h) end

-- Tint compensado p/ superfícies difusas desenhadas antes do composite
-- (SÓ acentos — ver §5.6): k = min(1, 1 / max(luma(ambient), 0.55))
function LightEngine.tintCompensate(r, g, b) end

function LightEngine.update(dt) end     -- relógio dos flickers
```

Detalhes internos:
- Canvas único `lightCanvas` (`ceil(W/4) × ceil(H/4)`, nearest, rgba8), criado lazy,
  **nunca por frame** (fórum LÖVE t=88324).
- Clear com `ambient` e **alpha 1** (gotcha do multiply, §4.2).
- Luz com shader: desenhar `whiteImg` (Image branca 2×2, criada 1×) escalada a
  `2r/4` com o shader `light_dither` (UV [0,1] garantido — rectangle não serve).
- Micro-luz: 1 draw de imagem radial 8×8 pré-gerada (2 degraus assados), escalada.
- Flicker "fire": `love.math.noise(t*1.8, seed)*0.7 + love.math.noise(t*8, seed+37)*0.3`
  → raio ±12%, intensidade 0.85-1.0, G/B esfriam quando enfraquece. "pulse": seno lento.
- Composite: `setBlendMode("multiply", "premultiplied")` + `setScissor` + draw ×4;
  restaurar blend/scissor/color SEMPRE (`push("all")`/`pop()` defensivo).
- `enabled = false` ou ambient ≈ branco e 0 luzes: no-op (nenhum canvas tocado).

### 6.2 Shader `shaders/light_dither.glsl`

Compat GLSL do LÖVE (ES/1.20): **sem array initializer** — if-chain do
[glsl-dither/4x4](https://github.com/hughsk/glsl-dither) (valores completos abaixo):

```glsl
extern number levels;      // 4 (poça) ou 2 (horizonte)
extern number useDither;   // 0.0 | 1.0

float bayer4(vec2 sc) {
    int x = int(mod(sc.x, 4.0));
    int y = int(mod(sc.y, 4.0));
    int i = x + y * 4;
    if (i ==  0) return 0.0625; if (i ==  1) return 0.5625;
    if (i ==  2) return 0.1875; if (i ==  3) return 0.6875;
    if (i ==  4) return 0.8125; if (i ==  5) return 0.3125;
    if (i ==  6) return 0.9375; if (i ==  7) return 0.4375;
    if (i ==  8) return 0.25;   if (i ==  9) return 0.75;
    if (i == 10) return 0.125;  if (i == 11) return 0.625;
    if (i == 12) return 1.0;    if (i == 13) return 0.5;
    if (i == 14) return 0.875;  return 0.375;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    float i = clamp(1.0 - dot(p, p), 0.0, 1.0);
    i = i * i;                                   // (1-d²)²; usar i*i*i se "ferver"
    float thr = mix(0.5, bayer4(sc), useDither); // sc = pixel do LIGHTMAP (¼)
    i = floor(i * levels + thr) / levels;
    return vec4(color.rgb * i, 1.0);
}
```

### 6.3 Dados por bioma (`src/data/biomes.lua`)

Novo campo nos **6 biomas** + entrada em `ENV_FIELDS` (`WorldRoad.lua:77-80`) para
crossfade automático no blend (o `setBiome` captura o `from` de todos os ENV_FIELDS):

```lua
-- fields (dia dourado — sutil):        lightAmbient = { 0.94, 0.90, 0.86 },
-- highlands (noite azulada):           lightAmbient = { 0.62, 0.64, 0.80 },
-- abyss (brasa no escuro):             lightAmbient = { 0.58, 0.46, 0.46 },
-- frost (dia gelado — quase neutro):   lightAmbient = { 0.88, 0.92, 1.00 },
-- marsh (podridão verde-escura):       lightAmbient = { 0.60, 0.70, 0.58 },
-- dusk (o entardecer da referência):   lightAmbient = { 0.52, 0.44, 0.58 },
```

Valores iniciais — **calibrar por captura** (harness §8). Regra de legibilidade:
luminância do ambiente ≥ 0.35 (medível: luma média da faixa central da estrada na
captura, script de aceite F1).

### 6.4 Integração exata (âncoras por função; linhas de Jul/2026 como referência)

1. `WorldRoad.draw`, logo após `domeGeom` (~2521):
   `LightEngine.beginFrame(envColor("lightAmbient"))`.
2. Submits (dentro do room-sway → `transformPoint`):
   - **Castelo**: dentro de `drawCastleOf` (def ~1314-1369), após o draw principal —
     **2-3 micro-luzes POR coluna de janela** (âncoras `{xr, yr}` relativas ao sprite),
     `radius ≈ 0.18 × largura_do_castelo_na_tela`, `intensity ≤ 0.6`, kind "pulse"
     sutil. **NUNCA uma luz única cobrindo o sprite** — a pedra deve escurecer com o
     ambiente, só o entorno imediato das janelas volta (§11 F-1/F-7). Bleeding sobre
     céu/montanha fica imperceptível nesse raio; halo real além da silhueta é papel
     do bloom seletivo (F6.3), não do lightmap.
   - **Props emissores**: no loop de `drawProps` (tint block, ~2417-2452), quando
     `p.kind == "lantern"|"brazier"` → `submit` na âncora da chama
     (`FLAME_ANCHOR[kind] = {xr, yr}`, tabela nova junto de `KIND_SIZE`,
     WorldRoad.lua ~67), `radius = Config × persp(t)`, `dither = (t > 0.45)`,
     flicker "fire".
   - **Olhos do inimigo** (opcional): `drawEncounterFront` (~2513) e/ou
     EnemyRenderer — `radius ≤ 0.25 × altura do sprite`, `intensity ≤ 0.5`,
     ancorada nos olhos, **nunca alcança o chão** (anti-spotlight, §11 F-9).
   - **Vagalumes/brasas/fumaça**: nos loops existentes (critters ~2620, `_ambient`
     ~2639, chaminé ~1385) → `submitMicro` raio 6-10px na cor do emissor. O sprite
     de 2px continua desenhado como hoje (pintado na paleta).
3. **Composite**: `WorldRoad.draw` NÃO compõe. Nova `WorldRoad.drawLightComposite()`
   (wrapper de `LightEngine.composite` na área da cena).
4. **Fork marks saem do composite**: mover `drawForkMarks` (chamada ~2659) para
   função pública `WorldRoad.drawForkOverlay()`, desenhada APÓS o composite
   (marks+pills são UI in-world — legibilidade protegida; §11 F-10).
   `drawLandmarkFront` e `drawEncounterFront` FICAM antes (objetos de mundo, devem
   receber luz).
5. `GameplayScene.draw` — nova ordem: `WorldRoad.draw` → `topBar` →
   `EnemyRenderer.draw` (pulado se traveling — composite roda mesmo assim) →
   **`WorldRoad.drawLightComposite()`** → **`WorldRoad.drawForkOverlay()`** →
   `EnemyHud.draw` → `gameUI` → mão/smoke/etc.
   `drawWorldOnly` (~129-141, caminho do fork no mapSelection): mesma sequência
   sem inimigo/HUD. **Interiores (boss/elite) não chamam WorldRoad.draw** → guard
   do composite cobre (no-op).
6. `main.lua`: `LightEngine.update(dt)` no bloco de updates do playing; boot aplica
   `persistedSettings.lighting`.
7. Tools (checklist F0 — caminho esquecido = cena sem luz, fail-safe):
   `screenshot_worldroad.lua` (modos full/all/gate/fork/blend6/travel/enemy/endless)
   e `demo_worldroad.lua` (drawBattleFrame) chamam composite + forkOverlay.

### 6.5 Config + settings

```lua
-- src/core/Config.lua
Config.Lighting = {
  SCALE = 4, LEVELS = 4,
  MAX_LIGHTS = 16, MAX_MICRO = 64,      -- overflow: menor raio×intensity sai
  MIN_AMBIENT_LUMA = 0.35,
  COMPENSATE_FLOOR = 0.55,              -- teto do tintCompensate (§5.6)
  LANTERN = { radius = 150, color = {1.00, 0.62, 0.25}, intensity = 1.0 },
  BRAZIER = { radius = 130, color = {1.00, 0.55, 0.20}, intensity = 1.0 },
  WINDOW  = { radiusK = 0.18, color = {1.00, 0.72, 0.35}, intensity = 0.6 },
  EYES    = { radiusK = 0.25, intensity = 0.5 },
  FIREFLY = { radius = 8, intensity = 0.8 },
  FLICKER_FIRE = { slow = 1.8, fast = 8.0, radiusK = 0.12 },
}
```

- `engine/SaveManager.lua` `DEFAULT_SETTINGS`: `lighting = true` (backfill automático).
- `components/SettingsMenu.lua`: row "Iluminação" no padrão do CRT toggle (~73-85).
- Resize: lazy no `beginFrame` — nada no `love.resize`.

### 6.6 Assets novos (fila PixelLab)

Contrato: `memory/scene_pipeline.md` (sufixo canônico grimoire + "sprite isolated on
transparent background, no halo no disc no moon"). **O glow do emissor é PINTADO na
arte** (ramp quente 2-3 degraus concêntricos), como as janelas do castelo:

| Asset | Tamanho | Prompt-núcleo | Biomas |
|---|---|---|---|
| `fields_lantern_0.png` | ~48×96 | wooden roadside post with hanging LIT lantern, warm amber flame, glow painted as 2-3 concentric pixel-art steps around the glass | fields, dusk (tint), marsh |
| `brazier_0.png` (neutro) | ~48×80 | weathered stone pillar brazier with burning orange fire on top, flame painted with 2-3 step warm ramp, embers | abyss, highlands, frost |
| variações `<bid>_lantern_0` | idem | idem com material do bioma | conforme calibração |

Motor: `KIND_SIZE.lantern = 1.7`, `KIND_SIZE.brazier = 1.2` + `FLAME_ANCHOR` por kind
(WorldRoad.lua ~67-71); `KIND_LANE` perto da estrada; `propWeights` baixo (0.30-0.45 —
~1 por tela, cadência da referência); fallback procedural no `MAKERS` (poste +
retângulo âmbar) para nunca depender do PNG. **Regra F2: nenhuma poça de luz sem
emissor visível no frame** — a poça só existe se o prop desenhou.

---

## 7. Performance (orçamento)

| Item | Custo estimado |
|---|---|
| lightmap ~256×192: clear + ≤16 quads shader + ≤64 micro-draws | « 0.2 ms |
| composite multiply full-screen (1 draw + scissor) | ~0.2-0.4 ms iGPU |
| flicker noise (CPU) | desprezível |
| **Total** | **< 0.6 ms** (budget 16.6ms; A/B via `screenshot_worldroad bench`) |

Regras: canvas criado 1× (lazy resize); zero `newShader`/`newCanvas` em runtime;
1 canvas-switch + 1 shader-switch por frame; `love.graphics.getStats`
(`drawcalls`, `canvasswitches`, `shaderswitches`) no bench.

---

## 8. Fases de implementação (com critérios de aceitação)

Validação padrão de TODAS as fases:
- `love . screenshot_worldroad light<N>` (novo modo: bioma N com motor ON, mesmo
  enquadramento do `full<N>`) + comparação com `full<N>` (OFF).
- `demo_worldroad` interativo: tecla **L** = toggle do motor, **O/P** = ambient -/+
  (override de debug para calibração ao vivo).
- **Zoom 3× nos sprites**: nenhum xadrez/cunha de dither na silhueta de NENHUM sprite.
- **Teste em movimento** (modo `travel`): dither não "ferve" contra a textura rolando.
- **Aceite automatizado**: script compara ON vs OFF pixel a pixel — ON nunca excede
  OFF em nenhum canal (multiply garante; pega regressão de add/compensate).

### F0 — Fundação (motor vazio, risco zero)
`engine/LightEngine.lua` + `shaders/light_dither.glsl` + `Config.Lighting` +
setting `lighting` + teclas no demo + modos de screenshot + composite/forkOverlay
ligados em TODOS os caminhos (checklist §6.4.7).
**Aceite:** ON com ambient branco e 0 luzes = diff < 1% vs atual; OFF = idêntico;
bench delta < 0.6 ms; resize/fullscreen ok; **testar na máquina NVIDIA antes de F1**.

### F1 — Ambiente por bioma (o "clima" — 70% do mood)
`lightAmbient` nos 6 biomas + `ENV_FIELDS` + reorder do GameplayScene +
`tintCompensate` nos acentos do GrassField.
**Aceite:** dusk/abyss/marsh com mood forte; luma média da faixa da estrada ≥ 0.35
(script); fields/frost sutis; crossfade suave no `blend6`; HUD/cartas/TopBar/pills
sem escurecimento; zoom 3× limpo; vagalumes/brasas legíveis (micro-luzes de F0 já
ativas para eles).

### F2 — Fontes pontuais (o "wow" da referência)
Assets lantern/brazier + kinds novos + submits (props, janelas por-coluna do castelo,
olhos opcionais) + flicker noise.
**Aceite:** captura `light6` (dusk) ≈ **referência do usuário** (não o mockup);
poça posterizada alinhada ao grid ¼, dither só no chão; **nenhuma poça sem emissor
visível**; luz nunca clareia sprite acima da arte (script ON≤OFF); pedra do castelo
escurece, só entorno das janelas volta; chama tremula orgânico; teste travel sem
fervura. *(Nota: fields de dia é sutil por design — o mood da referência em fields
depende da decisão F6.1.)*

### F3 — Vida emissiva (promovida — era F4)
Vagalumes upgrade: cap por bioma (dusk/marsh 18-26 via micro-fila; frost 0), spawn
perto de vegetação, blink dessincronizado, fade por profundidade; brasas do abyss
mais densas perto de braseiros; heat haze opcional (quad pequeno, offset quantizado).
**Aceite:** cena parada nunca 100% estática; partículas respeitam oclusão (antes dos
props); vagalume distante não vira pixel solto; **vagalume próximo tem halo ≥ 2
células do lightmap**.

### F4 — Profundidade (névoa entre camadas — mecanismo já existe)
Bruma fria por fatia de profundidade: quads posterizados desenhados **entre os passes
de props/grama** (o v7.5 já intercala fatias por `relFrom/relTo` — a bruma entra como
mais uma fatia), cor = `fog` do bioma modulada pelo ambiente. Reforça a banda da
crista existente.
**Aceite:** 3+ planos de profundidade separados por bruma nas capturas; bruma oclui
atrás de árvore do primeiro plano (painter's order); sem banding; biomas de dia sutil.

### F5 — Polimento global (opcional, tudo gated por aprovação visual)
- LUT sépia por bioma (strip 256×16, lerp no blend, antes do CRT).
- **Variação tonal do terreno** (ex-"sombra de nuvem" — REMOVIDA no ciclo 26, gate
  obrigatório): FBM de frequência baixíssima, POSTERIZADO nos mesmos degraus,
  **dessincronizado das nuvens visíveis** (o 1:1 nuvem→sombra foi o que leu como
  "bolas sem sentido"), desenhado no lightmap antes das luzes (luzes furam).
- God rays dithered = experimento nas mesmas condições.
- Vinhetas atuais: **manter como estão** (véus aceitos; §11 F-12).
**Aceite:** cada item só entra com captura A/B aprovada explicitamente pelo usuário.

### F6 — Decisões de design em aberto (perguntar antes)
1. **Entardecer progressivo por andar**: keyframes de `lightAmbient` por
   `floorInAct` (andar 1 = dia → andar 8/boss = anoitecer; a referência é fields no
   fim do ato). Mecânica pronta (lerp sobre os keyframes); decisão é de game design.
   **É o que torna o aceite "fields = referência" shipável.**
2. **Interiores**: substituir os anéis de glow do InteriorFX pelo LightEngine
   (âncoras via `SceneBackground.getCoverTransform` — fix de aspect ratio de brinde).
3. **Bloom Kawase seletivo** (emissive canvas ½→⅛): o caminho honesto para halo
   ALÉM da silhueta (janelas do castelo contra o céu, chamas) — pirâmide quase
   grátis; decidir após ver F2 sem bloom.

---

## 9. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Franja/mancha (lição v7) — inclusive dither-halo em silhueta | multiply-only ≤ 1 (rgba8); dither só em poça de chão; horizonte 2 degraus sem dither; aceite com zoom 3× + teste em movimento em TODAS as fases |
| **Bleeding screen-space** (luz vaza sobre occluder/céu) | raio ∝ persp(t); luzes de horizonte pequenas/fracas (janela = radiusK 0.18, int ≤ 0.6); bleeding aceito só em poça de chão; halo real além da silhueta = F6.3 (bloom), não lightmap |
| Driver NVIDIA | zero stencil/depth; canvas simples (CRTShader é precedente); F0 testa na máquina NVIDIA antes de F1+ |
| Legibilidade (cena escura demais) | MIN_AMBIENT_LUMA 0.35 medido por script; HUD/pills fora do composite (forkOverlay) |
| Alpha do canvas CRT zerado | clear alpha=1 + add alphamultiply preserva (verificado na wiki) |
| Caminho de draw sem composite (tools/interior) | guard no composite (no-op sem beginFrame) + checklist §6.4.7 |
| Emissivo apagado pelo multiply | micro-luz por emissor (não boost) — cor original atravessa intacta com oclusão preservada |
| Cap de luzes estourado (26 vagalumes) | fila micro cap 64 + política de overflow documentada |
| Blend de bioma "pula" a luz | lightAmbient em ENV_FIELDS = crossfade grátis |
| Custo em iGPU | lightmap ¼; bench A/B em F0 e F2 |

## 10. Fora de escopo do v1 (registrado)

Poças com reflexo (shader de água em quad — técnica validada na pesquisa), normal maps
(rejeitado), godsray radial blur 70-taps, palette-swap indexado completo (endgame
Ferrari — só se a LUT do F5 não bastar), luz no modo clássico de cartas, bitumbra /
sombras many-lights, **HUD da imagem de referência** (painel HERÓI, badge de nível,
orbe ⅓ — é redesign de UI, não motor de luz).

## 11. Revisão adversarial (Jul/2026) — achados incorporados

Passe de crítico de arte/tech-art sobre plano + mockup v1 (zooms pixel-a-pixel):

| # | Achado | Resolução no plano |
|---|---|---|
| F-1 grave | halo de dither na silhueta do castelo (franja de nova geração) | luzes por janela, radiusK ∝ escala, 2 degraus sem dither no horizonte (§6.4.2) |
| F-2 grave | luz screen-space vaza sobre céu/montanha/occluders | limitação assumida + política de raios (§3, §9) |
| F-3 grave | boost() não preserva emissivo saturado e pode clarear acima da arte | rejeitado → micro-luzes (§5.3/5.6) |
| F-4 grave | 18-26 vagalumes vs MAX_LIGHTS 16 | fila micro cap 64 + overflow (§5.3) |
| F-5 grave | sombra de nuvem re-entrava sem gate (removida no ciclo 26) | movida pra F5, gated, dessincronizada, posterizada (§8 F5) |
| F-6 médio | vagalume "adesivo" sem glow | micro-luz raio 6-10px = halo; aceite F3 |
| F-7 médio | castelo 100% devolvido = adesivo diurno | coberto por F-1 |
| F-8 médio | aceite F2 usava mockup (fields+dusk inexistente in-game) | aceite sobre bioma dusk + nota F6.1 (§8 F2) |
| F-9 médio | poça órfã + spotlight no inimigo | regra "nenhuma poça sem emissor" + spec EYES (§6.4/6.5) |
| F-10 médio | fork pills escureciam sob o composite | drawForkOverlay pós-composite (§6.4.4) |
| F-11 leve | degrau intermediário do dither pode "ferver" em movimento | falloff (1-d²)³ opcional + teste travel no aceite |
| F-12 leve | integrar vinheta ao lightmap seria downgrade | vinhetas mantidas como estão |

Checagens de API feitas em separado (§4.2): transformPoint, scissor, UV de rectangle
(→ Image branca), array GLSL (→ if-chain), screen_coords = pixel do render target,
alpha do multiply, formato rgba8.
