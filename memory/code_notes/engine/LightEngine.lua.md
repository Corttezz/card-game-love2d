---
name: code_notes/engine/LightEngine.lua
description: Comentários com decisão/regra/histórico colhidos de engine/LightEngine.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/LightEngine.lua`

Origem: `engine/LightEngine.lua` em `7dbdb60d` (26 de 44 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local LightEngine = {}`)

> engine/LightEngine.lua
> Motor de iluminação 2D da cena (WorldRoad; futuro: interiores).
> Plano completo: docs/plan/lighting-engine-v1.md · memória: memory/lighting_engine.md
>
> PIPELINE (padrão Luven/Stardew, temperado pelas regras de pixel art do projeto):
> canvas 1/4 res nearest (rgba8) limpo com a cor ambiente do bioma (ALPHA=1 —
> multiply também multiplica o alpha do destino) → luzes acumuladas com blend
> "add" (falloff (1-d²)² posterizado em degraus + dither Bayer só nas poças de
> chão; micro-luzes como sprite radial de 2 degraus, sem shader) → composto
> sobre a cena com "multiply"/"premultiplied" + setScissor na área do mundo.
>
> MULTIPLY-ONLY: o lightmap tem teto 1.0 (rgba8) — o motor só escurece em
> direção ao ambiente e "devolve" a arte original perto das luzes; nunca cria
> cor acima do que o artista pintou (lição v6/v7: aditivo sobre sprite = franja).
> ZERO stencil (driver NVIDIA).
>
> Coordenadas: submits recebem coords de TELA — quem chama de dentro de um
> transform (room sway / screen shake) converte com love.graphics.transformPoint.
> O composite desenha com origin(), então lightmap e cena casam por construção.

## L25-28 (em `LightEngine`, junto a `LightEngine.debugNoLights = false`)

> MEDIÇÃO (P6'): suprime TODA luz mantendo o ambiente — o A/B do protocolo
> de diferença por pixel (tools/measure_lightpool.lua). Com o mesmo frame
> renderizado com e sem luz, tudo que é ASSADO no PNG é idêntico nos dois e
> subtrai a zero: a diferença isola só a contribuição da luz. Só ferramenta.

## L31 (em `LightEngine`, junto a `local MAX_LIGHTS = 28`)

> fila com shader (poças/fontes médias; 16→28 em Out/2026: as

## L32-33 (em `LightEngine`, junto a `local MAX_MICRO  = 64          -- fila de micro-pontos (vagalumes/chamas/janelas)`)

> janelas do castelo perto lotavam a fila e as poças dos vagalumes
> do WeatherEngine — as mais fracas — nunca entravam)

## L51-53 (em `ambient`, junto a `local function isEnabled()`)

> ============================================================================
> Estado / settings
> ============================================================================

## L55-56 (em `ambient`, junto a `local function isEnabled()`)

> Habilitado se: override setado → override; senão settings persistidos
> (_G.gameSettings.lighting, backfill default true); senão true (tools).

## L69-70 (em `lumaOf`, junto a `function LightEngine.ambientLuma()`)

> Luminância do ambiente do frame corrente (0..1) — usado pra gatear
> vagalumes/efeitos "de escuro" no WorldRoad.

## L76-77 (em `LightEngine.ambientLuma`, junto a `function LightEngine.ambientColor()`)

> Cor ambiente RGB do frame corrente — o EnemyRenderer usa pra compor o
> flat "cor padrão + leve tom do ambiente" do oclusor focal (monstro).

## L86-88 (em `LightEngine.update`, junto a `local function ensureResources()`)

> ============================================================================
> Recursos (criados 1x; canvas recriado lazily no resize — padrão CRTShader)
> ============================================================================

## L105-106 (em `ensureResources`, junto a `local d = love.image.newImageData(16, 16)`)

> radial 16x16 com 2 degraus assados NO ALPHA (rgb branco): com blend
> add+alphamultiply o que soma é rgb*alpha → núcleo cheio + anel 45%

## L130-131 (em `ensureResources`, junto a `local ok2, sh2 = pcall(function()`)

> shader de oclusor: silhueta CHAPADA (só alpha) — corrige o
> esmagamento (sprite × sprite) que escurecia monstro/árvores

## L139-141 (em `ensureResources`, junto a `function LightEngine.beginFrame(amb)`)

> ============================================================================
> Frame de luz
> ============================================================================

## L159-162 (em `LightEngine.beginFrame`, junto a `function LightEngine.submit(spec)`)

> Luz com shader (poça de chão / fonte média).
> spec = { x, y, radius, color={r,g,b}, intensity=0..1, dither=bool,
> levels=n (default 4; 2 pra luz pequena/horizonte),
> flicker=nil|"fire"|"pulse", seed=n }

## L168 (em `LightEngine.submit`, junto a `local seed = (spec.seed or 0) % 1000`)

> noise 2 oitavas (contínuo, orgânico) — nunca random puro

## L184-186 (em `entry`, junto a `z = spec.z or -1,`)

> profundidade (rel de mundo): luzes mais FUNDAS são desenhadas
> primeiro e podem ser ocluídas por silhuetas mais próximas.
> Default -1 = coladas na câmera (nunca ocluídas).

## L192-193 (em `entry`, junto a `local wi, ww = nil, entry.r * entry.i`)

> overflow: substitui a luz mais fraca (raio×intensidade), nunca
> descarta por ordem de submit (política do plano §5.3)

## L203-204 (em `entry`, junto a `function LightEngine.submitMicro(x, y, radius, color, intensity, z)`)

> Micro-luz: ponto raio 4-12px sem shader (vagalume/chama/janela).
> O "glow" É o de-escurecimento local — halo pequeno sobre fundo escuro.

## L215-224 (em `LightEngine.submitMicro`, junto a `function LightEngine.submitOccluder(o)`)

> OCLUSOR por silhueta (pedido do usuário: luz atrás de um corpo não vaza
> por cima dele — monstro na frente do portão, árvore na frente da poça).
> A silhueta do sprite é desenhada NO LIGHTMAP com a cor ambiente, na ordem
> de profundidade: luzes mais fundas (z maior) → silhueta → luzes mais
> próximas. Bloqueio pixel-perfeito, zero stencil; uma lanterna na FRENTE
> do corpo continua iluminando ele.
> o = { z,                       -- profundidade (rel); oclui luzes com z maior
> bx, by, w, h,            -- bounds na tela (culling)
> img, x, y, rot, sx, sy, ox, oy   -- sprite (coords de TELA)
> OU fn = function() ... end }     -- draw custom (anim do inimigo)

## L231-233 (em `LightEngine.submitOccluder`, junto a `function LightEngine.tintCompensate(r, g, b)`)

> Tint compensado p/ superfícies difusas desenhadas antes do composite
> (SÓ acentos pontuais — nunca sprites inteiros). Fator ÚNICO por luma
> (nunca por canal — preserva matiz), teto 1/0.55.

## L240-241 (em `LightEngine.tintCompensate`, junto a `function LightEngine.composite(x, y, w, h)`)

> Composite: desenha o lightmap e multiplica sobre a região (x,y,w,h).
> GUARD: sem beginFrame neste frame (interiores, caminho esquecido) = no-op.

## L260-263 (em `LightEngine.composite`, junto a `love.graphics.setCanvas(canvas)`)

> 1) lightmap: ambiente + PAINTER de luzes/oclusores por profundidade.
> Ordem: z DESC (fundo primeiro). Luz funda → silhueta oclusora →
> luz próxima: a silhueta apaga (volta ao ambiente) a luz que vinha
> de trás dela; luzes na frente ainda a iluminam.

## L267-268 (em `LightEngine.composite`, junto a `local lights = {}`)

> culling de oclusores: só entra quem tem alguma luz MAIS FUNDA
> encostando no seu retângulo (senão pintar ambiente sobre ambiente)

## L285-286 (em `entries`, junto a `if hit or o.lift or o.flatColor then o.occ = true; entries[#entries + 1] = o end`)

> oclusor com lift/flatColor SEMPRE pinta (levanta o dono mesmo sem
> luz atrás — é como o monstro/árvore fica legível no contraluz)

## L300-305 (em `entries`, junto a `love.graphics.setBlendMode("alpha", "alphamultiply")`)

> silhueta CHAPADA: o shader usa SÓ o alpha da textura e pinta
> cor flat (ambiente, ou ambiente×lift). ANTES desenhava o
> sprite com setColor → multiplicava ambiente × cor-do-sprite,
> e o multiply final virava sprite² (partes escuras do monstro/
> árvore esmagavam pra quase preto). setColor branco: com o
> shader a cor vem do uniform `flat`.

## L309-312 (em `entries`, junto a `cr, cg, cb = e.flatColor[1], e.flatColor[2], e.flatColor[3]`)

> flat CRAVADO pelo dono (monstro focal): "cor padrão + leve
> tom do ambiente", perto do branco. Ignora o teto do lift —
> ambient×lift satura no canal mais forte e nunca chega na
> cor cheia, deixando o corpo escuro do sprite quase preto.

## L325 (em `entries`, junto a `love.graphics.setColor(cr, cg, cb, 1)`)

> fallback (bug antigo)

