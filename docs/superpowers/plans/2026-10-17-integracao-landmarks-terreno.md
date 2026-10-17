# Integração dos landmarks ao terreno do WorldRoad — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer os landmarks, props, castelo e inimigo do WorldRoad pertencerem ao mesmo mundo que o chão: cor única por profundidade (`SceneGrade`), sombra de contato com pegada medida (`ContactShadow`), oclusão pela base com tufos obrigatórios (`GrassField.requireTufts`), névoa em camadas (`WeatherEngine`), interação própria de cada landmark e variação por instância das árvores (`PropVariation`), com tabela por bioma desde o primeiro commit.

**Architecture:** Nenhuma regra visual nova dentro de `src/ui/WorldRoad.lua`: ele só chama. Tudo que é novo entra em `engine/` (SceneGrade, ContactShadow, PropVariation, extensões de GrassField/WeatherEngine/LuminaireEngine/LightEngine) e nos dados (`src/data/scene_integration.lua`, uma entrada por bioma). As três engines novas entram no WorldRoad por UM único `local Scene = { Grade = ..., Contact = ..., Var = ... }` para a contagem de locais do arquivo (hoje 198 de 200) cair, não subir. O pintor por profundidade (`rel`) continua a lei: o landmark escolhido vira pseudo-prop dentro de `drawList`, sombras de contato descarregam no mesmo ponto do `ShadowEngine.flush()`, tufos entram no lote da fatia de grama logo à frente da base.

**Tech Stack:** Lua 5.1 (LuaJIT 2.1) + LÖVE 11.5, FFI para varredura de PNG, QuadMesh (engine própria), testes `tools/test_*.lua` no padrão `tools/testkit.lua`, capturas headless com `CARDGAME_HEADLESS=1 lovec . test_one <tool>`.

**Spec:** `E:\dev\projects\card-game-love2d\docs\superpowers\specs\2026-10-17-integracao-landmarks-terreno-design.md`

## Global Constraints

- Zero comentário em Lua/GLSL do jogo e das tools (`main.lua`, `src/**`, `components/**`, `engine/**`, `shaders/**`, `tools/**`); zero `print()` fora de `Debug.lua`/`Release.lua`/runner/testkit/`test_*`/`smoke_*`/lista `TOOL_RESULT_PRINTERS` de `tools/test_no_comments_no_prints.lua`. Diagnóstico só por `require("src.core.Debug").warn/log`.
- Nunca declarar `local` novo no escopo de arquivo de `main.lua` (teto de 60 upvalues do `love.load`).
- `src/ui/WorldRoad.lua` está em **198 de 200** slots de `local` no escopo de arquivo. A contagem NÃO pode subir em nenhum commit (meta da spec: abaixo de 190 ao fim). Comando de contagem (Tarefa 1 cria `tools/count_locals.py`): `python tools/count_locals.py src/ui/WorldRoad.lua`.
- Regra de profundidade do WorldRoad: Todo elemento novo entra no pintor intercalado por `rel` (entre as fatias de grama via `flushGrassTo`), nunca em camada global por tipo. Vale para sombra de contato, tufos, landmark escolhido, poeira e névoa por fatia.
- `reducedMotion` remove MOVIMENTO, nunca INFORMAÇÃO: tom, escala, espelho, sombra de contato, tufos, névoa e brilho ficam; vento, deriva da névoa, pulso e poeira param.
- Asset ou scan novo por bioma entra em `prewarmJobs` do WorldRoad (`test_perf_budget`: 0 decode de PNG no 1º frame após troca de bioma).
- `test_perf_budget`: ≤ 600 draw calls e ≤ 40 KB alocados por frame (meta da spec: < 520 e < 34 KB com tudo ligado). Nada de closure nem `love.graphics.*` em laço quente; tabelas de pool por frame (padrão `shadowOpts`/`occluderSlot`).
- Luz em pixel art: nada aditivo colado em silhueta; poça de chão aditiva no lightmap é aceita (LightEngine multiply-only).
- Decisão de RUN usa `Rng` streams; aqui tudo é cosmético (hash determinístico por semente do prop / `WorldRoad._rng`), nunca `Rng`.
- Céu e montanhas NÃO acompanham a hora do dia (spec §5): a família `mountain` do SceneGrade recebe só a profundidade (névoa e contraste), sem temperatura.
- Antes de cada commit: `CARDGAME_HEADLESS=1 lovec . test_all` verde (inclui `test_no_comments_no_prints`, `test_perf_budget`, `test_world_shadows`, `test_weather`, `test_world_props`).
- Capturas antes/depois do ato 1 por passe em `tools/preview_out/integracao_terreno/<passe>/` (dia/meio/pôr × fork/landmark/viagem/castelo), geradas por `tools/screenshot_integracao_terreno.lua` (Tarefa 1) e copiadas do save-dir da LÖVE.
- Mensagens de commit em PT-BR com o trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. **Crossfade entre biomas no meio** (`WorldRoad._blend` ativo, `blendK` 0,5): `SceneGrade.begin` tem que interpolar as duas linhas da tabela sem `nil` e sem pular de cor. Teste na Tarefa 1 (`blend no meio: cor entre as duas linhas`).
2. **Janela minúscula / escala 0,35** (`g.scaleAt` tem piso 0,35): faixa de contato e tufos com altura < 1 px não podem gerar quad de altura 0, NaN ou laço infinito. Testes na Tarefa 2 (`escala mínima: faixa ≥ 1 px`) e Tarefa 3 (`tufo com escala mínima não quebra`).
3. **Sprite sem pegada** (procedural de `MAKERS` gerado antes do scan, frame de animação sem varredura): `ContactShadow.queue` tem que ser no-op com UM `Debug.warn` por imagem, nunca erro. Teste na Tarefa 2 (`imagem sem pegada: no-op avisado`).
4. **Iluminação desligada** (`gameSettings.lighting = false`): `LightEngine.beginFrame` não ativa o frame e `ambientColor()` devolve o último ambiente; `SceneGrade.flatColor` e `color` continuam válidos. Teste na Tarefa 1 (`lighting=false: cor e flatColor válidos`).
5. **Salão do chefe depois da estrada** (interior não chama `WorldRoad.draw`): o `EnemyRenderer` não pode aplicar o grade velho da estrada. `SceneGrade.isActive()` expira em 0,1 s como o `ShadowEngine`. Teste na Tarefa 1 (`sem begin há 0,1 s: color = 1`).

---

### Tarefa 1: `SceneGrade` + tabela por bioma + migração de todas as famílias de cor + ferramenta de captura

**Files:**
- Create: `src/data/scene_integration.lua`
- Create: `engine/SceneGrade.lua`
- Create: `tools/count_locals.py`
- Create: `tools/screenshot_integracao_terreno.lua`
- Create: `tools/test_scene_grade.lua`
- Modify: `src/ui/WorldRoad.lua` (pontos listados no Passo 7, linhas de 17/Out: 12-13, 1300-1307, 1463-1481, 1989, 2037, 2087-2099, 2224/2261/2267, 2393, 2402/2416/2426, 2436-2438, 2539-2577, 2816, 2918, 3042-3045, 3155, 3174, 3181-3227, 3255-3270, 3398-3414, 3442-3454, 3470-3481, 3561-3592)
- Modify: `src/ui/EnemyRenderer.lua:917-936` e `:1076-1084`
- Modify: `tools/run_all_tests.lua:37` (registrar `test_scene_grade`)
- Modify: `tools/test_no_comments_no_prints.lua:47` (registrar o tool de captura)
- Test: `tools/test_scene_grade.lua`

**Interfaces:**
- Consumes: `LightEngine.ambientColor() -> r, g, b` (engine/LightEngine.lua:44); `WeatherEngine.modulateAmbient(amb) -> amb` (engine/WeatherEngine.lua:462); `WorldRoad._blend`, `WorldRoad._prevBiomeIndex`, `WorldRoad._timeOfDay`, `rawBiome(idx)` (WorldRoad.lua:130-167).
- Produces (usadas pelas Tarefas 2 a 11):
  - `SceneGrade.FAMILIES` — array `{ "ground","road","grass","prop","tree","rock","landmark","castle","mountain","enemy","luminaire","critter" }`.
  - `SceneGrade.familyOf(kind, isLuminaire) -> string`.
  - `SceneGrade.begin(bid, tod, fromBid, blendK, amb)` — uma vez por quadro; `amb` é a MESMA tabela passada ao `LightEngine.beginFrame`.
  - `SceneGrade.isActive() -> boolean` (0,1 s desde o último `begin`).
  - `SceneGrade.color(family, t, out) -> out` (escreve `out[1..3]`, sem alocar).
  - `SceneGrade.flatColor(family, out) -> out` (ambiente puro, igual para toda família).
  - `SceneGrade.fogAlpha(t) -> number`, `SceneGrade.fogColor() -> r, g, b`, `SceneGrade.shadowTint() -> r, g, b`.
  - `SceneGrade.cfg(section) -> table` (seção `contact`/`occlusion`/`lowFog`/`trees`/`landmarks` do bioma atual, sem mistura).
  - `SceneGrade.setDepth(t)` / `SceneGrade.depth() -> number` (profundidade do inimigo em batalha, lida pelo EnemyRenderer).
  - `SceneGrade.biome() -> string`.
  - `WorldRoad` passa a ter `local Scene = { Grade = require("engine.SceneGrade") }` (Tarefas 2 e 6 só ADICIONAM campos a essa tabela) e `LMG.c = {}` / `LMG.fc = {}` (tabelas de saída reutilizadas).
  - Tool: `lovec . test_one screenshot_integracao_terreno <label>[:<bioma>]` grava 12 PNGs por bioma em `<save-dir>/integracao_terreno/<label>/b<bioma>_<dia|meio|por>_<fork|landmark|viagem|castelo>.png` e imprime os caminhos.

- [ ] **Passo 1: Contador de locais do WorldRoad**

Criar `tools/count_locals.py`:

```python
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "src/ui/WorldRoad.lua"
n = 0
for line in open(path, encoding="utf-8").read().split("\n"):
    if re.match(r"^local\s+function\s", line):
        n += 1
        continue
    m = re.match(r"^local\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)", line)
    if m:
        n += len(m.group(1).split(","))
print(path, "file-scope local slots:", n)
```

Rodar: `python tools/count_locals.py src/ui/WorldRoad.lua`
Esperado: `src/ui/WorldRoad.lua file-scope local slots: 198`

- [ ] **Passo 2: Ferramenta de captura headless (antes de qualquer mudança visual)**

Criar `tools/screenshot_integracao_terreno.lua`:

```lua
local M = {}

local TODS = { { "dia", 0 }, { "meio", 0.5 }, { "por", 1 } }
local SCENES = { "fork", "landmark", "viagem", "castelo" }

local function paintTop(width, topBarH)
    love.graphics.setColor(0.1, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, width, topBarH)
    love.graphics.setColor(1, 1, 1, 1)
end

local function setup(bio, scene)
    local WorldRoad = require("src.ui.WorldRoad")
    local width, height = love.graphics.getDimensions()
    local topBarH = 80
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
                WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
            end
        end
    end
    if scene == "castelo" then
        WorldRoad._segBase = 0
        WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.85
        tick(30, false)
    elseif scene == "viagem" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        WorldRoad._camZ = 5.5
        tick(30, false)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        tick(70, true)
    else
        WorldRoad._camZ = 5.5
        tick(30, false)
        require("src.i18n.I18n").init()
        local MM = require("src.systems.MapManager")
        local nodes = {}
        for i, ty in ipairs({ "battle", "rest", "shop" }) do
            nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
        end
        WorldRoad.showFork(nodes, function() end)
        tick(20, true)
        if scene == "fork" then
            if WorldRoad._fork then WorldRoad._fork.hover = 2 end
        else
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[2]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            tick(85, true)
        end
    end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    return function()
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        paintTop(width, topBarH)
    end
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local label, bioArg = tostring(arg or "captura"):match("^([^:]+):?(%d*)$")
    label = label or "captura"
    local bios = {}
    if bioArg and bioArg ~= "" then bios[1] = tonumber(bioArg) else bios[1] = 1 end
    local dir = "integracao_terreno/" .. label
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local saved = {}
    for _, bio in ipairs(bios) do
        for _, scene in ipairs(SCENES) do
            for _, td in ipairs(TODS) do
                local draw = setup(bio, scene)
                WorldRoad.setTimeOfDay(td[2], true)
                WorldRoad.update(1 / 30)
                draw()
                local path = string.format("%s/b%d_%s_%s.png", dir, bio, td[1], scene)
                love.graphics.captureScreenshot(function(imageData)
                    imageData:encode("png", path)
                end)
                love.graphics.present()
                saved[#saved + 1] = love.filesystem.getSaveDirectory() .. "/" .. path
            end
        end
    end
    love.timer.getTime = realTime
    for _, p in ipairs(saved) do print(p) end
    love.event.quit()
    return true
end

return M
```

Registrar em `tools/test_no_comments_no_prints.lua`, dentro de `M.TOOL_RESULT_PRINTERS`, logo após `"tools/screenshot_worldroad.lua",` (linha 47):

```lua
    "tools/screenshot_integracao_terreno.lua",
```

Rodar (no Git Bash, raiz do repo):

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 00_antes
```

Esperado: 12 linhas com caminhos absolutos `.../integracao_terreno/00_antes/b1_<tod>_<cena>.png`, sem erro. Copiar para o repo:

```bash
SAVE=$(CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 00_antes | head -1 | sed 's#/integracao_terreno/.*##')
mkdir -p tools/preview_out/integracao_terreno/00_antes
cp "$SAVE"/integracao_terreno/00_antes/*.png tools/preview_out/integracao_terreno/00_antes/
ls tools/preview_out/integracao_terreno/00_antes | wc -l
```

Esperado: `12`.

- [ ] **Passo 3: Commit da ferramenta e das capturas "antes"**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_no_comments_no_prints
git add tools/count_locals.py tools/screenshot_integracao_terreno.lua tools/test_no_comments_no_prints.lua tools/preview_out/integracao_terreno/00_antes
git commit -m "Integração do terreno: ferramenta de captura headless e contador de locais, capturas de antes do ato 1

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Passo 4: Tabela por bioma (dados puros)**

Criar `src/data/scene_integration.lua` com as 6 entradas. `fields` é o ponto de partida da spec; os outros derivam de `lightDay`/`lightNight`/`fog` de `src/data/biomes.lua` e são calibrados nas Tarefas 7 a 11.

```lua
local function landmarks(scorchR, scorchA)
    return {
        rest   = { scorch = { radius = scorchR, alpha = scorchA }, embers = true,
                   smoke = "thin", pulse = 0.18 },
        battle = { flagWave = true, dust = { rate = 0.4, alpha = 0.10 } },
        shop   = { windowGlow = { alpha = 0.22, spread = 1.4 }, smoke = "chimney" },
        event  = { lanternGlow = true },
        elite  = { runeFlicker = true },
        castle = { lowFog = true, hillShadow = true },
    }
end

return {
    fields = {
        grade = {
            day = { 1.00, 0.97, 0.90 }, dusk = { 0.80, 0.66, 0.84 },
            shadowTint = { 0.36, 0.22, 0.46 },
            satNear = 1.0, satFar = 0.55, contrastFar = 0.6,
            fog = { 0.55, 0.42, 0.28 }, fogNear = 0.0, fogFar = 0.45, fogCurve = 1.6,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.10, tuftsMin = 3, tuftsMax = 6, tuftScale = { 0.8, 1.2 } },
        lowFog = { alpha = 0.18, height = 0.09, drift = 0.02 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.030, trunkSway = 0.010, bushSway = 0.040 },
        landmarks = landmarks(1.35, 0.5),
    },
    highlands = {
        grade = {
            day = { 0.90, 0.92, 1.00 }, dusk = { 0.62, 0.66, 0.92 },
            shadowTint = { 0.30, 0.28, 0.52 },
            satNear = 0.95, satFar = 0.50, contrastFar = 0.58,
            fog = { 0.38, 0.34, 0.48 }, fogNear = 0.02, fogFar = 0.52, fogCurve = 1.5,
        },
        contact = { alpha = 0.50, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.09, tuftsMin = 2, tuftsMax = 5, tuftScale = { 0.7, 1.1 } },
        lowFog = { alpha = 0.26, height = 0.11, drift = 0.015 },
        trees = { tint = 0.04, scale = 0.07, flip = true, windPhase = true,
                  canopySway = 0.034, trunkSway = 0.012, bushSway = 0.045 },
        landmarks = landmarks(1.25, 0.45),
    },
    abyss = {
        grade = {
            day = { 1.00, 0.80, 0.68 }, dusk = { 0.86, 0.46, 0.36 },
            shadowTint = { 0.30, 0.10, 0.10 },
            satNear = 1.0, satFar = 0.62, contrastFar = 0.55,
            fog = { 0.55, 0.20, 0.10 }, fogNear = 0.0, fogFar = 0.40, fogCurve = 1.7,
        },
        contact = { alpha = 0.60, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.07, tuftsMin = 2, tuftsMax = 4, tuftScale = { 0.7, 1.0 } },
        lowFog = { alpha = 0.14, height = 0.07, drift = 0.03 },
        trees = { tint = 0.06, scale = 0.09, flip = true, windPhase = true,
                  canopySway = 0.016, trunkSway = 0.008, bushSway = 0.030 },
        landmarks = landmarks(1.5, 0.6),
    },
    frost = {
        grade = {
            day = { 0.90, 0.94, 1.00 }, dusk = { 0.64, 0.70, 0.90 },
            shadowTint = { 0.30, 0.38, 0.58 },
            satNear = 0.85, satFar = 0.45, contrastFar = 0.66,
            fog = { 0.55, 0.60, 0.68 }, fogNear = 0.04, fogFar = 0.55, fogCurve = 1.4,
        },
        contact = { alpha = 0.45, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.07, tuftsMin = 2, tuftsMax = 4, tuftScale = { 0.6, 1.0 } },
        lowFog = { alpha = 0.30, height = 0.12, drift = 0.012 },
        trees = { tint = 0.03, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.026, trunkSway = 0.008, bushSway = 0.030 },
        landmarks = landmarks(1.2, 0.5),
    },
    marsh = {
        grade = {
            day = { 0.86, 0.94, 0.80 }, dusk = { 0.60, 0.72, 0.58 },
            shadowTint = { 0.16, 0.24, 0.16 },
            satNear = 1.0, satFar = 0.55, contrastFar = 0.58,
            fog = { 0.38, 0.42, 0.24 }, fogNear = 0.03, fogFar = 0.50, fogCurve = 1.5,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.13, tuftsMin = 4, tuftsMax = 7, tuftScale = { 0.9, 1.4 } },
        lowFog = { alpha = 0.28, height = 0.10, drift = 0.018 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.028, trunkSway = 0.010, bushSway = 0.050 },
        landmarks = landmarks(1.3, 0.45),
    },
    dusk = {
        grade = {
            day = { 1.00, 0.92, 0.80 }, dusk = { 0.78, 0.56, 0.70 },
            shadowTint = { 0.34, 0.18, 0.36 },
            satNear = 1.0, satFar = 0.60, contrastFar = 0.62,
            fog = { 0.72, 0.48, 0.22 }, fogNear = 0.0, fogFar = 0.42, fogCurve = 1.6,
        },
        contact = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true },
        occlusion = { baseCover = 0.10, tuftsMin = 3, tuftsMax = 6, tuftScale = { 0.8, 1.2 } },
        lowFog = { alpha = 0.20, height = 0.09, drift = 0.02 },
        trees = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.036, trunkSway = 0.012, bushSway = 0.045 },
        landmarks = landmarks(1.35, 0.5),
    },
}
```

- [ ] **Passo 5: Teste que falha (`tools/test_scene_grade.lua`)**

```lua
local TK = require("tools.testkit")
local M = {}

local SECTIONS = { "grade", "contact", "occlusion", "lowFog", "trees", "landmarks" }
local LANDMARK_KEYS = { "rest", "battle", "shop", "event", "elite", "castle" }

local function luma(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end
local function sat(c)
    local mx, mn = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
    return mx - mn
end

local function fnBody(src, name)
    local s = src:find("local function " .. name .. "%(")
    if not s then return nil end
    local e = src:find("\nend\n", s, true)
    return e and src:sub(s, e + 4) or nil
end

function M.run()
    local t = TK.new("SceneGrade: fonte única de cor da cena")
    local biomes = require("src.data.biomes")
    local DATA = require("src.data.scene_integration")
    local SceneGrade = require("engine.SceneGrade")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    for _, b in ipairs(biomes) do
        local e = DATA[b.id]
        if t:truthy(b.id .. ": tem entrada na tabela", e ~= nil) then
            for _, sec in ipairs(SECTIONS) do
                t:truthy(b.id .. ": seção " .. sec, type(e[sec]) == "table")
            end
            for _, k in ipairs(LANDMARK_KEYS) do
                t:truthy(b.id .. ": landmarks." .. k, e.landmarks and e.landmarks[k] ~= nil)
            end
            local g = e.grade
            t:truthy(b.id .. ": satFar < satNear ≤ 1", g.satFar < g.satNear and g.satNear <= 1)
            t:truthy(b.id .. ": contrastFar em [0.4, 1]", g.contrastFar >= 0.4 and g.contrastFar <= 1)
            t:truthy(b.id .. ": fogFar ≤ 0.6 e fogNear < fogFar", g.fogFar <= 0.6 and g.fogNear < g.fogFar)
            t:truthy(b.id .. ": contact.height em (0, 0.08]", e.contact.height > 0 and e.contact.height <= 0.08)
            t:truthy(b.id .. ": tuftsMin ≤ tuftsMax", e.occlusion.tuftsMin <= e.occlusion.tuftsMax)
        end
    end

    local amb = { 0.9, 0.85, 0.8 }
    local c0, c1, cm = {}, {}, {}

    SceneGrade.begin("fields", 0, nil, 1, amb)
    t:truthy("isActive logo após begin", SceneGrade.isActive())
    t:eq("biome() = fields", SceneGrade.biome(), "fields")
    SceneGrade.color("prop", 0, c0)
    SceneGrade.color("prop", 1, c1)
    t:truthy("horizonte mais escuro que a base (contrastFar)", luma(c0) < luma(c1))
    t:truthy("horizonte menos saturado que a base", sat(c0) <= sat(c1) + 1e-6)
    t:truthy("fogAlpha(0) > fogAlpha(1)", SceneGrade.fogAlpha(0) > SceneGrade.fogAlpha(1))
    t:near("fogAlpha(1) = fogNear", SceneGrade.fogAlpha(1), DATA.fields.grade.fogNear, 1e-6)
    t:near("fogAlpha(0) = fogFar", SceneGrade.fogAlpha(0), DATA.fields.grade.fogFar, 1e-6)
    local mono = true
    for k = 1, 20 do
        if SceneGrade.fogAlpha(k / 20) > SceneGrade.fogAlpha((k - 1) / 20) + 1e-9 then mono = false end
    end
    t:truthy("fogAlpha decresce com t", mono)
    for k = 0, 10 do
        SceneGrade.color("tree", k / 10, cm)
        if cm[1] > 1 or cm[2] > 1 or cm[3] > 1 or cm[1] < 0 or cm[1] ~= cm[1] then mono = false end
    end
    t:truthy("cor sempre em [0,1], sem NaN", mono)

    local day, dusk = {}, {}
    SceneGrade.begin("fields", 0, nil, 1, amb)
    SceneGrade.color("prop", 1, day)
    SceneGrade.begin("fields", 1, nil, 1, amb)
    SceneGrade.color("prop", 1, dusk)
    t:truthy("pôr do sol dos campos puxa pro azul-roxo (b/r sobe)",
        dusk[3] / dusk[1] > day[3] / day[1])
    local m0, m1 = {}, {}
    SceneGrade.begin("fields", 0, nil, 1, amb)
    SceneGrade.color("mountain", 0, m0)
    SceneGrade.begin("fields", 1, nil, 1, amb)
    SceneGrade.color("mountain", 0, m1)
    t:truthy("montanha ignora a hora do dia (só profundidade)",
        math.abs(m0[1] - m1[1]) < 1e-6 and math.abs(m0[3] - m1[3]) < 1e-6)

    SceneGrade.begin("fields", 0.5, nil, 1, amb)
    local same = true
    local f0 = {}
    SceneGrade.flatColor(SceneGrade.FAMILIES[1], f0)
    for _, fam in ipairs(SceneGrade.FAMILIES) do
        local fc = SceneGrade.flatColor(fam, {})
        if math.abs(fc[1] - f0[1]) > 1e-9 or math.abs(fc[2] - f0[2]) > 1e-9
           or math.abs(fc[3] - f0[3]) > 1e-9 then same = false end
    end
    t:truthy("flatColor igual para TODAS as famílias", same)
    t:truthy("flatColor = ambiente puro", math.abs(f0[1] - amb[1]) < 1e-9
        and math.abs(f0[2] - amb[2]) < 1e-9 and math.abs(f0[3] - amb[3]) < 1e-9)

    local a, bb = {}, {}
    SceneGrade.begin("fields", 0.7, nil, 1, amb)
    SceneGrade.color("tree", 0.4, a)
    _G.gameSettings = { reducedMotion = true }
    SceneGrade.begin("fields", 0.7, nil, 1, amb)
    SceneGrade.color("tree", 0.4, bb)
    _G.gameSettings = { reducedMotion = false }
    t:truthy("reducedMotion não muda cor (remove movimento, não informação)",
        a[1] == bb[1] and a[2] == bb[2] and a[3] == bb[3])

    local pf, pc, pm = {}, {}, {}
    SceneGrade.begin("fields", 0.5, nil, 1, amb)
    SceneGrade.color("prop", 0.5, pf)
    SceneGrade.begin("highlands", 0.5, nil, 1, amb)
    SceneGrade.color("prop", 0.5, pc)
    SceneGrade.begin("highlands", 0.5, "fields", 0.5, amb)
    SceneGrade.color("prop", 0.5, pm)
    local between = true
    for k = 1, 3 do
        local lo, hi = math.min(pf[k], pc[k]) - 1e-6, math.max(pf[k], pc[k]) + 1e-6
        if pm[k] < lo or pm[k] > hi then between = false end
    end
    t:truthy("blend no meio: cor entre as duas linhas", between)
    t:truthy("blend no meio: fogAlpha finito", SceneGrade.fogAlpha(0.3) == SceneGrade.fogAlpha(0.3))

    t:eq("familyOf(tree)", SceneGrade.familyOf("tree"), "tree")
    t:eq("familyOf(pine)", SceneGrade.familyOf("pine"), "tree")
    t:eq("familyOf(bush)", SceneGrade.familyOf("bush"), "tree")
    t:eq("familyOf(rock)", SceneGrade.familyOf("rock"), "rock")
    t:eq("familyOf(ruin)", SceneGrade.familyOf("ruin"), "rock")
    t:eq("familyOf(fence)", SceneGrade.familyOf("fence"), "prop")
    t:eq("familyOf(lantern, luminária)", SceneGrade.familyOf("lantern", true), "luminaire")
    t:eq("familyOf(desconhecido)", SceneGrade.familyOf("zzz"), "prop")

    do
        local LightEngine = require("engine.LightEngine")
        local prev = _G.gameSettings
        _G.gameSettings = { reducedMotion = false, lighting = false }
        LightEngine.beginFrame(amb)
        SceneGrade.begin("fields", 0.5, nil, 1, amb)
        local cc, ff = {}, {}
        SceneGrade.color("prop", 0.5, cc)
        SceneGrade.flatColor("prop", ff)
        t:truthy("lighting=false: cor e flatColor válidos",
            cc[1] == cc[1] and cc[1] > 0 and ff[1] == ff[1] and ff[1] > 0)
        _G.gameSettings = prev
    end

    do
        local realGet = love.timer.getTime
        local now = 1000
        love.timer.getTime = function() return now end
        SceneGrade.begin("fields", 1, nil, 1, amb)
        now = 1000.5
        local cc = {}
        SceneGrade.color("enemy", 0.5, cc)
        t:falsy("sem begin há 0,1 s: inativo", SceneGrade.isActive())
        t:truthy("sem begin há 0,1 s: color = 1", cc[1] == 1 and cc[2] == 1 and cc[3] == 1)
        love.timer.getTime = realGet
    end

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local er = love.filesystem.read("src/ui/EnemyRenderer.lua") or ""
        local viaKind = { luminaire = true }
        for _, fam in pairs(SceneGrade.KIND_FAMILY) do viaKind[fam] = true end
        t:truthy("WorldRoad resolve família por kind (familyOf)",
            src:find("Scene.Grade.familyOf(", 1, true) ~= nil)
        for _, fam in ipairs(SceneGrade.FAMILIES) do
            local needle = 'color("' .. fam .. '"'
            t:truthy("família '" .. fam .. "' tem chamada no desenho",
                viaKind[fam] or src:find(needle, 1, true) ~= nil or er:find(needle, 1, true) ~= nil)
        end
        for _, fn in ipairs({ "drawDome", "drawRoad", "drawGrass", "drawCastleOf",
                              "drawMountainsOf", "drawMountainsFrontOf", "drawPropsBehind",
                              "drawEncounterFront", "drawTerrainDetail" }) do
            local body = fnBody(src, fn)
            t:truthy(fn .. ": chama Scene.Grade.color", body ~= nil and body:find("Scene.Grade.color(", 1, true) ~= nil)
        end
        for _, gone in ipairs({ "LMG.setTint", "local mixK", "liftT", "local tint = 0.35",
                                "local tint = 0.28", "setColor(0.88, 0.88, 0.88",
                                "setColor(0.94, 0.94, 0.94", "setColor(0.7, 0.7, 0.7",
                                "setColor(0.66, 0.66, 0.66", "setColor(0.6, 0.6, 0.6",
                                "oc.lift", ".lift = " }) do
            t:falsy("WorldRoad sem '" .. gone .. "'", src:find(gone, 1, true) ~= nil)
        end
        t:falsy("EnemyRenderer sem 'local tint = 0.28'", er:find("local tint = 0.28", 1, true) ~= nil)
        t:truthy("WorldRoad: SceneGrade.begin logo após LightEngine.beginFrame",
            src:find("LightEngine%.beginFrame%(amb%)%s*\n%s*Scene%.Grade%.begin%(") ~= nil)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local W, H = love.graphics.getDimensions()
        local function shot(tod)
            local cv = love.graphics.newCanvas(W, H)
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(1)
            WorldRoad._camZ = 5.5
            WorldRoad.setTimeOfDay(tod, true)
            for _ = 1, 10 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
            return cv:newImageData()
        end
        local okA, idA = pcall(shot, 0)
        local okB, idB = pcall(shot, 1)
        t:truthy("cena desenha com o grade (dia e pôr do sol)", okA and okB)
        if okA and okB then
            local x, y = math.floor(W * 0.5), math.floor(H * 0.85)
            local r0, g0, b0 = idA:getPixel(x, y)
            local r1, g1, b1 = idB:getPixel(x, y)
            t:truthy("chão perto da base muda de cor com a hora do dia",
                math.abs(r0 - r1) + math.abs(g0 - g1) + math.abs(b0 - b1) > 0.01)
        end
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    _G.gameSettings = savedSettings
    return t:done()
end

return M
```

Registrar em `tools/run_all_tests.lua`, depois de `{ group = "unit",  name = "test_world_props" },` (linha 37):

```lua
    { group = "unit",  name = "test_scene_grade" },
```

- [ ] **Passo 6: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade`
Esperado: crash `module 'engine.SceneGrade' not found` (ou `[FAIL]` em todos os asserts da varredura) e `== SOME FAILED ==`.

- [ ] **Passo 7: Implementar `engine/SceneGrade.lua`**

```lua
local LightEngine = require("engine.LightEngine")
local DATA = require("src.data.scene_integration")

local SceneGrade = {}

SceneGrade.FAMILIES = {
    "ground", "road", "grass", "prop", "tree", "rock", "landmark",
    "castle", "mountain", "enemy", "luminaire", "critter",
}

SceneGrade.KIND_FAMILY = {
    tree = "tree", pine = "tree", deadtree = "tree", bush = "tree",
    rock = "rock", ruin = "rock",
    stump = "prop", fence = "prop", sign = "prop", flowers = "prop", tuft = "prop",
}

local NO_TEMP = { mountain = true }

local S = {
    bid = "fields", stamp = -1,
    tr = 1, tg = 1, tb = 1,
    shr = 0, shg = 0, shb = 0,
    satNear = 1, satFar = 1, contrastFar = 1,
    fr = 1, fg = 1, fb = 1, fogNear = 0, fogFar = 0, fogCurve = 1,
    ar = 1, ag = 1, ab = 1,
    depth = 1,
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, k) return a + (b - a) * k end

local function gradeOf(bid)
    local e = DATA[bid] or DATA.fields
    return e.grade
end

local function resolve(g, tod, into)
    into.tr = lerp(g.day[1], g.dusk[1], tod)
    into.tg = lerp(g.day[2], g.dusk[2], tod)
    into.tb = lerp(g.day[3], g.dusk[3], tod)
    into.shr, into.shg, into.shb = g.shadowTint[1], g.shadowTint[2], g.shadowTint[3]
    into.satNear, into.satFar = g.satNear, g.satFar
    into.contrastFar = g.contrastFar
    into.fr = math.min(1.6, g.fog[1] * 1.9)
    into.fg = math.min(1.6, g.fog[2] * 1.9)
    into.fb = math.min(1.6, g.fog[3] * 1.9)
    into.fogNear, into.fogFar, into.fogCurve = g.fogNear, g.fogFar, g.fogCurve
    return into
end

local prevLine = {}
local FIELDS = { "tr", "tg", "tb", "shr", "shg", "shb", "satNear", "satFar",
                 "contrastFar", "fr", "fg", "fb", "fogNear", "fogFar", "fogCurve" }

function SceneGrade.begin(bid, tod, fromBid, blendK, amb)
    tod = clamp01(tod or 1)
    S.bid = DATA[bid] and bid or "fields"
    resolve(gradeOf(S.bid), tod, S)
    if fromBid and DATA[fromBid] and blendK and blendK < 1 then
        resolve(gradeOf(fromBid), tod, prevLine)
        local k = clamp01(blendK)
        for i = 1, #FIELDS do
            local f = FIELDS[i]
            S[f] = lerp(prevLine[f], S[f], k)
        end
    end
    if amb then
        S.ar, S.ag, S.ab = amb[1] or 1, amb[2] or 1, amb[3] or 1
    else
        S.ar, S.ag, S.ab = LightEngine.ambientColor()
    end
    S.stamp = love.timer.getTime()
end

function SceneGrade.isActive()
    return (love.timer.getTime() - S.stamp) < 0.1
end

function SceneGrade.biome() return S.bid end

function SceneGrade.familyOf(kind, isLuminaire)
    if isLuminaire then return "luminaire" end
    return SceneGrade.KIND_FAMILY[kind] or "prop"
end

function SceneGrade.fogAlpha(t)
    t = clamp01(t or 1)
    return S.fogNear + (S.fogFar - S.fogNear) * ((1 - t) ^ S.fogCurve)
end

function SceneGrade.fogColor() return S.fr, S.fg, S.fb end
function SceneGrade.shadowTint() return S.shr, S.shg, S.shb end

function SceneGrade.color(family, t, out)
    out = out or {}
    if not SceneGrade.isActive() then
        out[1], out[2], out[3] = 1, 1, 1
        return out
    end
    t = clamp01(t or 1)
    local r, g, b = 1, 1, 1
    if not NO_TEMP[family] then r, g, b = S.tr, S.tg, S.tb end
    local sat = lerp(S.satFar, S.satNear, t)
    local l = 0.299 * r + 0.587 * g + 0.114 * b
    r, g, b = lerp(l, r, sat), lerp(l, g, sat), lerp(l, b, sat)
    local fa = SceneGrade.fogAlpha(t)
    r, g, b = lerp(r, S.fr, fa), lerp(g, S.fg, fa), lerp(b, S.fb, fa)
    local bright = lerp(S.contrastFar, 1, t)
    out[1] = clamp01(r * bright)
    out[2] = clamp01(g * bright)
    out[3] = clamp01(b * bright)
    return out
end

function SceneGrade.flatColor(family, out)
    out = out or {}
    out[1], out[2], out[3] = S.ar, S.ag, S.ab
    return out
end

function SceneGrade.cfg(section)
    local e = DATA[S.bid] or DATA.fields
    return e[section]
end

function SceneGrade.setDepth(t) S.depth = clamp01(t or 1) end
function SceneGrade.depth() return S.depth end

return SceneGrade
```

- [ ] **Passo 8: Migrar o WorldRoad (todos os pontos de `setColor` da cena)**

Cada ponto abaixo: ANTES (linha de 17/Out) → DEPOIS. Nenhum `local` novo no escopo de arquivo além do `Scene` (o `_profT, _profKB` vira campo do módulo para a contagem CAIR).

**8a. Topo (linha 12-13).** Depois de `local GrassField = require("engine.GrassField")`:

```lua
local Scene = { Grade = require("engine.SceneGrade") }
```

**8b. `_profT, _profKB` (linhas 3442-3454).** ANTES:

```lua
local _profT, _profKB
local function _profMark(name)
    local P = WorldRoad._prof
    if not P then return end
    love.graphics.flushBatch()
    local now = love.timer.getTime()
    local kb = collectgarbage("count")
    if name ~= "start" and _profT then
        P[name] = (P[name] or 0) + (now - _profT) * 1000
        P["kb " .. name] = (P["kb " .. name] or 0) + (kb - _profKB)
    end
    _profT, _profKB = now, kb
end
```

DEPOIS:

```lua
WorldRoad._profState = {}
local function _profMark(name)
    local P = WorldRoad._prof
    if not P then return end
    love.graphics.flushBatch()
    local ps = WorldRoad._profState
    local now = love.timer.getTime()
    local kb = collectgarbage("count")
    if name ~= "start" and ps.t then
        P[name] = (P[name] or 0) + (now - ps.t) * 1000
        P["kb " .. name] = (P["kb " .. name] or 0) + (kb - ps.kb)
    end
    ps.t, ps.kb = now, kb
end
```

**8c. `LMG` (linhas 1284-1307).** Apagar `function LMG.setTint(br, a) ... end` inteiro (1300-1307). Logo depois de `function LMG.refH(key, ih) return LMG.ORIG_H[key] or ih end` (1299) acrescentar:

```lua
LMG.c = {}
LMG.fc = {}
LMG.tint4 = { 1, 1, 1, 1 }
```

**8d. `submitLandmarkOccluder` (1463-1481).** ANTES:

```lua
local function submitLandmarkOccluder(img, px, py, iw, ih, s, rel)
    local oxT, oyT = love.graphics.transformPoint(px - iw * s / 2, py - ih * s)
    local ar, ag2, ab2 = 1, 1, 1
    if LightEngine.ambientColor then
        ar, ag2, ab2 = LightEngine.ambientColor()
    end
    local mx2 = math.max(ar, ag2, ab2, 0.001)
    local tint = 0.35
    LightEngine.submitOccluder({
        z = rel,
        flatColor = {
            1 - tint * (1 - ar / mx2),
            1 - tint * (1 - ag2 / mx2),
            1 - tint * (1 - ab2 / mx2),
        },
        img = img, x = oxT, y = oyT, sx = s, sy = s,
        bx = oxT, by = oyT, w = iw * s, h = ih * s,
    })
end
```

DEPOIS:

```lua
local function submitLandmarkOccluder(img, px, py, iw, ih, s, rel)
    local oxT, oyT = love.graphics.transformPoint(px - iw * s / 2, py - ih * s)
    LightEngine.submitOccluder({
        z = rel,
        flatColor = Scene.Grade.flatColor("landmark", {}),
        img = img, x = oxT, y = oyT, sx = s, sy = s,
        bx = oxT, by = oyT, w = iw * s, h = ih * s,
    })
end
```

**8e. `drawMountainsOf` (1989).** `love.graphics.setColor(1, 1, 1, alpha)` →

```lua
        local c = Scene.Grade.color("mountain", 0, LMG.c)
        love.graphics.setColor(c[1], c[2], c[3], alpha)
```

**8f. `drawMountainsFrontOf` (2036-2037).** ANTES:

```lua
    if _G.WR_TINT then love.graphics.setColor(1, 0, 0, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
```

DEPOIS:

```lua
    local c = Scene.Grade.color("mountain", 0, LMG.c)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
```

**8g. `drawCastleOf` (2097).** `love.graphics.setColor(1, 1, 1, alpha)` →

```lua
    local cc = Scene.Grade.color("castle", 0, LMG.c)
    love.graphics.setColor(cc[1], cc[2], cc[3], alpha)
```

(As duas elipses de 2084-2095 ficam nesta tarefa; saem na Tarefa 5.)

**8h. `drawPropsBehind` (2224, 2261, 2267).** Os três `setColor` ficam multiplicados pelo grade na profundidade 0:

```lua
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind, true), 0, LMG.c)
                love.graphics.setColor(cb[1] * 0.7, cb[2] * 0.7, cb[3] * 0.7, fadeA)
```

```lua
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                            love.graphics.setColor(cc[1] * 0.6, cc[2] * 0.6, cc[3] * 0.6, fadeA)
```

```lua
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                love.graphics.setColor(cb[1] * 0.66, cb[2] * 0.66, cb[3] * 0.66, fadeA)
```

**8i. `drawDomeTexOf` (2393).** `love.graphics.setColor(1, 1, 1, alpha)` →

```lua
    local c = Scene.Grade.color("ground", 0.5, LMG.c)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
```

**8j. `drawDome` (2399-2431).** Logo após `local grassB = envColor("grassB")` inserir `local gc = Scene.Grade.color("ground", 0.5, LMG.c)` e, como `LMG.c` é reutilizado pelo `drawDomeTexOf` chamado no meio, copiar para locais: `local gr, gg, gb = gc[1], gc[2], gc[3]`. Os três `setColor`:

```lua
    love.graphics.setColor(grassB[1] * 0.78 * gr, grassB[2] * 0.78 * gg, grassB[3] * 0.78 * gb, 1)
```

```lua
        love.graphics.setColor(grassA[1] * gr, grassA[2] * gg, grassA[3] * gb, 1)
```

```lua
    love.graphics.setColor(grassA[1] * 1.16 * gr, grassA[2] * 1.16 * gg, grassA[3] * 1.10 * gb, 0.85)
```

**8k. `drawTerrainDetail` (2434-2438).** ANTES:

```lua
    local gA = envColor("grassA")
    local gB = envColor("grassB")
    local dark  = { gB[1] * 0.70, gB[2] * 0.70, gB[3] * 0.70 }
    local light = { math.min(1, gA[1] * 1.45), math.min(1, gA[2] * 1.40),
                    math.min(1, gA[3] * 1.25) }
```

DEPOIS:

```lua
    local gA = envColor("grassA")
    local gB = envColor("grassB")
    local gc = Scene.Grade.color("ground", 0.5, LMG.c)
    local dark  = { gB[1] * 0.70 * gc[1], gB[2] * 0.70 * gc[2], gB[3] * 0.70 * gc[3] }
    local light = { math.min(1, gA[1] * 1.45) * gc[1], math.min(1, gA[2] * 1.40) * gc[2],
                    math.min(1, gA[3] * 1.25) * gc[3] }
```

**8l. `drawGrass` (2571-2577).** ANTES:

```lua
            colors = {
                mid   = { gA[1] * 0.98, gA[2] * 0.98, gA[3] * 0.98 },
                light = { math.min(1, gA[1] * lk),
                          math.min(1, gA[2] * lk * 0.97),
                          math.min(1, gA[3] * lk * 0.88) },
                accent = acc,
            },
```

DEPOIS (antes do `_grassCtx = {` inserir `local gc = Scene.Grade.color("grass", 0.5, LMG.c)`):

```lua
            colors = {
                mid   = { gA[1] * 0.98 * gc[1], gA[2] * 0.98 * gc[2], gA[3] * 0.98 * gc[3] },
                light = { math.min(1, gA[1] * lk) * gc[1],
                          math.min(1, gA[2] * lk * 0.97) * gc[2],
                          math.min(1, gA[3] * lk * 0.88) * gc[3] },
                accent = { acc[1] * gc[1], acc[2] * gc[2], acc[3] * gc[3] },
            },
```

**8m. `drawRoad` (2816).** `love.graphics.setColor(1, 1, 1, 1)` antes do `qm:draw` →

```lua
        local rc = Scene.Grade.color("road", 0.5, LMG.c)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
```

**8n. `drawLandmarkFront` (2918).** `LMG.setTint(1, 1)` →

```lua
    local lc = Scene.Grade.color("landmark", t, LMG.c)
    love.graphics.setColor(lc[1], lc[2], lc[3], 1)
```

**8o. `drawForkPhysical` (3042-3043).** ANTES:

```lua
                local br = hovered and 1.10 or 1
                LMG.setTint(br, aMul)
```

DEPOIS:

```lua
                local br = hovered and 1.10 or 1
                local lc = Scene.Grade.color("landmark", tM, LMG.c)
                love.graphics.setColor(math.min(1, lc[1] * br), math.min(1, lc[2] * br),
                    math.min(1, lc[3] * br), aMul)
```

**8p. `drawList`, companheiras (3155).** `love.graphics.setColor(0.88, 0.88, 0.88, fadeA)` →

```lua
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), t, LMG.c)
                            love.graphics.setColor(cc[1] * 0.88, cc[2] * 0.88, cc[3] * 0.88, fadeA)
```

**8q. `drawList`, cerca (3174).** `love.graphics.setColor(0.94, 0.94, 0.94, fadeA)` →

```lua
                            local fc = Scene.Grade.color("prop", ft, LMG.c)
                            love.graphics.setColor(fc[1] * 0.94, fc[2] * 0.94, fc[3] * 0.94, fadeA)
```

**8r. `drawList`, o prop (3181-3191 e 3221-3229).** O `aFade` segue existindo SÓ para o alpha da sombra (3181-3191 ficam iguais). ANTES (3221-3229):

```lua
                local lt = envColor("fog")
                local mixK = 0.16
                love.graphics.setColor(
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[1] * 1.9)),
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[2] * 1.9)),
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[3] * 1.9)),
                    fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip, s, gustKx * lumFlip)
```

DEPOIS:

```lua
                local pc = Scene.Grade.color(Scene.Grade.familyOf(p.kind, lumDef ~= nil), t, LMG.c)
                love.graphics.setColor(pc[1], pc[2], pc[3], fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip, s, gustKx * lumFlip)
```

**8s. `drawList`, oclusor das árvores (3255-3270).** ANTES:

```lua
                    local oxT, oyT = love.graphics.transformPoint(
                        pxX, sy + sink2)
                    local ambT = LightEngine.ambientLuma
                        and LightEngine.ambientLuma() or 1
                    local liftT = math.min(1.8, math.max(1, 0.72 / math.max(0.2, ambT)))
                    local oc = occluderSlot()
                    oc.z, oc.lift = rel, liftT
```

DEPOIS:

```lua
                    local oxT, oyT = love.graphics.transformPoint(
                        pxX, sy + sink2)
                    local oc = occluderSlot()
                    oc.fc = oc.fc or {}
                    oc.z = rel
                    oc.flatColor = Scene.Grade.flatColor("tree", oc.fc)
```

**8t. `drawEncounterFront` (3398-3428).** ANTES do `love.graphics.setColor(1, 1, 1, 1)` (3398) até o fim do bloco de oclusor (3428):

```lua
    love.graphics.setColor(1, 1, 1, 1)
    if e.anim then
        e.anim:draw(dx0, dy0, s)
    else
        love.graphics.draw(e.img, dx0, dy0, 0, s, s)
    end

    local oxT, oyT = love.graphics.transformPoint(dx0, dy0)
    local ar, ag, ab = 1, 1, 1
    if LightEngine.ambientColor then ar, ag, ab = LightEngine.ambientColor() end
    local mx = math.max(ar, ag, ab, 0.001)
    local tint = 0.28
    local flatColor = {
        1 - tint * (1 - ar / mx),
        1 - tint * (1 - ag / mx),
        1 - tint * (1 - ab / mx),
    }
```

DEPOIS:

```lua
    local ec = Scene.Grade.color("enemy", t, LMG.c)
    local t4 = LMG.tint4
    t4[1], t4[2], t4[3], t4[4] = ec[1], ec[2], ec[3], 1
    love.graphics.setColor(ec[1], ec[2], ec[3], 1)
    if e.anim then
        e.anim:draw(dx0, dy0, s, t4)
    else
        love.graphics.draw(e.img, dx0, dy0, 0, s, s)
    end

    local oxT, oyT = love.graphics.transformPoint(dx0, dy0)
    local flatColor = Scene.Grade.flatColor("enemy", LMG.fc)
```

(as duas chamadas `LightEngine.submitOccluder({ ... flatColor = flatColor ...})` abaixo ficam como estão.)

**8u. `WorldRoad.draw` (3470-3481).** ANTES:

```lua
    LightEngine.beginFrame(WeatherEngine.modulateAmbient(currentLightAmbient()))

    do
        local cel = rawBiome().celestial
        local sunX = cel and (x + cel.xr * w) or g.cx
        ShadowEngine.setFrame(sunX, w, WorldRoad._timeOfDay,
            LightEngine.ambientLuma())
    end

    local gb0 = envColor("grassB")
    love.graphics.setColor(gb0[1] * 0.78, gb0[2] * 0.78, gb0[3] * 0.78, 1)
    love.graphics.rectangle("fill", x, y, w, h)
```

DEPOIS:

```lua
    local amb = WeatherEngine.modulateAmbient(currentLightAmbient())
    LightEngine.beginFrame(amb)
    Scene.Grade.begin(rawBiome().id, WorldRoad._timeOfDay,
        WorldRoad._blend and WorldRoad._prevBiomeIndex
            and rawBiome(WorldRoad._prevBiomeIndex).id or nil,
        WorldRoad._blend and (function()
            local k = math.min(1, WorldRoad._blend.t / WorldRoad._blend.duration)
            return k * k * (3 - 2 * k)
        end)() or 1,
        amb)
    Scene.Grade.setDepth(g.tOf(WorldRoad.BATTLE_REL) or 1)

    do
        local cel = rawBiome().celestial
        local sunX = cel and (x + cel.xr * w) or g.cx
        ShadowEngine.setFrame(sunX, w, WorldRoad._timeOfDay,
            LightEngine.ambientLuma())
    end

    local gb0 = envColor("grassB")
    local g0 = Scene.Grade.color("ground", 0.5, LMG.c)
    love.graphics.setColor(gb0[1] * 0.78 * g0[1], gb0[2] * 0.78 * g0[2], gb0[3] * 0.78 * g0[3], 1)
    love.graphics.rectangle("fill", x, y, w, h)
```

A closure do `blendK` roda uma vez por quadro fora de laço (sem custo de JIT); se preferir, troque por `local bk = 1` + `if WorldRoad._blend then ... end` antes do `begin`.

**8v. Bichos (3561-3592).** Depois de `local acc = b.accent or { 0.8, 0.7, 0.4 }` inserir `local crc = Scene.Grade.color("critter", 0.7, LMG.c)` e `local ar, ag, ab = acc[1] * crc[1], acc[2] * crc[2], acc[3] * crc[3]`; trocar nos `setColor` do bloco `acc[1], acc[2], acc[3]` por `ar, ag, ab` (as quatro ocorrências: 3574, 3576, 3584; a 3576 vira `ar * 1.2, ag * 1.2, ab * 1.1`). O `submitMicro` continua com `acc`.

- [ ] **Passo 9: Migrar o `EnemyRenderer` (batalha)**

`src/ui/EnemyRenderer.lua:933` ANTES:

```lua
    love.graphics.setColor(tintR, tintG, tintB, 1)
```

DEPOIS (o `require` fica no topo do arquivo, junto dos outros):

```lua
    local SceneGrade = require("engine.SceneGrade")
    local gradeC = SceneGrade.color("enemy", SceneGrade.depth(), EnemyRenderer._gradeC)
    tintR, tintG, tintB = tintR * gradeC[1], tintG * gradeC[2], tintB * gradeC[3]
    love.graphics.setColor(tintR, tintG, tintB, 1)
```

E no topo do módulo (junto das outras tabelas de módulo): `EnemyRenderer._gradeC = {}`.

`src/ui/EnemyRenderer.lua:1076-1084` ANTES:

```lua
        local ar, ag, ab = 1, 1, 1
        if LightEngine.ambientColor then ar, ag, ab = LightEngine.ambientColor() end
        local mx = math.max(ar, ag, ab, 0.001)
        local tint = 0.28
        local flatColor = {
            1 - tint * (1 - ar / mx),
            1 - tint * (1 - ag / mx),
            1 - tint * (1 - ab / mx),
        }
```

DEPOIS:

```lua
        local flatColor = require("engine.SceneGrade").flatColor("enemy", {})
```

Quando o SceneGrade está inativo (salão do chefe), `color` devolve 1 e `flatColor` devolve o último ambiente do `LightEngine`, que é o que o salão já usava como base.

- [ ] **Passo 10: Rodar o teste e as travas vizinhas**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_world_shadows
CARDGAME_HEADLESS=1 lovec . test_one test_weather
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: `== ALL GREEN ==` nos quatro; contagem `197` (198 + `Scene` − `_profT` − `_profKB`). Se o `test_perf_budget` reclamar de KB por frame, a causa é alocação dentro de `color`: confira que todo chamador passa `LMG.c`/`oc.fc`/`EnemyRenderer._gradeC` e nunca `{}` em laço (os `{}` de `submitLandmarkOccluder` e do `EnemyRenderer` ocorrem no máximo 4 vezes por quadro).

- [ ] **Passo 11: Capturas depois, suíte inteira, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 01_scene_grade
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/01_scene_grade
cp "$SAVE"/integracao_terreno/01_scene_grade/*.png tools/preview_out/integracao_terreno/01_scene_grade/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir (Read) `tools/preview_out/integracao_terreno/01_scene_grade/b1_por_landmark.png` e `b1_dia_fork.png` ao lado dos pares de `00_antes/`: o pôr do sol tem que puxar o chão, as árvores e o landmark para o MESMO roxo; o horizonte mais lavado que a base; nenhuma árvore clareada à noite (o `lift` saiu).

```bash
git add src/data/scene_integration.lua engine/SceneGrade.lua tools/test_scene_grade.lua tools/run_all_tests.lua src/ui/WorldRoad.lua src/ui/EnemyRenderer.lua tools/preview_out/integracao_terreno/01_scene_grade
git commit -m "SceneGrade: fonte única de cor da cena por bioma e profundidade; chão, estrada, grama, props, marcos, castelo, montanhas, inimigo e bichos pela mesma régua

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 2: `ContactShadow` (faixa de contato com pegada medida) + terra queimada da fogueira

**Files:**
- Create: `engine/ContactShadow.lua`
- Create: `tools/test_contact_shadow.lua`
- Modify: `src/ui/WorldRoad.lua` (`local Scene` da Tarefa 1; `toImage` 389-393; `tryLoadPng` 262-274; `readAnimFrames` 276-302; `drawLandmarkFront` 2894-2924; `shadowOpts`/`occluderSlot` 2880-2953; `drawForkPhysical` 3034-3045; `drawList` 3151-3158, 3172-3176, 3182-3191; `drawProps` 3360-3362; `WorldRoad.draw` 3475-3477)
- Modify: `tools/run_all_tests.lua` (registrar `test_contact_shadow` depois de `test_scene_grade`)
- Test: `tools/test_contact_shadow.lua`

**Interfaces:**
- Consumes: `SceneGrade.cfg("contact") -> { alpha, height, spread, dither }`, `SceneGrade.shadowTint() -> r, g, b`, `SceneGrade.cfg("landmarks") -> table` (Tarefa 1); `QuadMesh.new(n)`, `qm:reset()`, `qm:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)`, `qm:upload(from, to)`, `qm:draw(from, count)` (engine/QuadMesh.lua); `ShadowEngine.flush()` (ponto de descarga, WorldRoad.lua:3361).
- Produces (usadas pelas Tarefas 3 e 5):
  - `ContactShadow.scan(img, data) -> footprint|nil` — `footprint = { spans = { {a, b}, ... }, bottom = linha, w = iw, h = ih }`, colunas do PNG cujo último pixel opaco está a ≤ 1 linha do ponto mais baixo; cache fraco por imagem; `data` é o ImageData já decodificado (nunca decodifica de novo).
  - `ContactShadow.footprint(img) -> footprint|nil`.
  - `ContactShadow.setFrame(cfg, r, g, b)` — uma vez por quadro (cfg = `SceneGrade.cfg("contact")`, cor = `SceneGrade.shadowTint()`).
  - `ContactShadow.queue(img, x, y, s, t, alpha, flip) -> boolean` — `x, y` do ponto de contato na tela (pé do sprite), `s` escala, `t` profundidade, `flip` ±1; `false` quando a imagem não tem pegada (um `Debug.warn` por imagem).
  - `ContactShadow.scorch(x, y, wPx, t, radiusK, alpha)` — disco irregular IMEDIATO (desenha na hora) centrado no pé; `wPx` = largura do sprite na tela; `radiusK` relativo a `wPx/2`.
  - `ContactShadow.flush()` — desenha todas as faixas enfileiradas em UM draw call (QuadMesh próprio) e zera a fila.
  - `ContactShadow.queued() -> number`, `ContactShadow.stats = { contacts, scorch, quads }`.
  - WorldRoad: `Scene.Contact` (campo novo na tabela `Scene`), `WorldRoad._pools` (tabela que absorve `shOptPool/shOptN/occPool/occN`).

- [ ] **Passo 1: Teste que falha (`tools/test_contact_shadow.lua`)**

```lua
local TK = require("tools.testkit")
local M = {}

local function synth(w, h, fn)
    local d = love.image.newImageData(w, h)
    d:mapPixel(function(x, y)
        if fn(x, y) then return 0.5, 0.3, 0.2, 1 end
        return 0, 0, 0, 0
    end)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    return img, d
end

local function loadWorld(key)
    local path = "assets/sprites/world/" .. key .. ".png"
    local d = love.image.newImageData(path)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    return img, d
end

local function render(fn)
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.5, 0.5, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    fn()
    love.graphics.setCanvas()
    return cv:newImageData()
end

local function lumaAt(id, x, y)
    local r, g, b = id:getPixel(x, y)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

function M.run()
    local t = TK.new("ContactShadow: faixa de contato colada na pegada; terra queimada só na fogueira")
    local CS = require("engine.ContactShadow")
    local SceneGrade = require("engine.SceneGrade")
    local DATA = require("src.data.scene_integration")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    do
        local img, d = synth(8, 6, function(x, y)
            if x >= 3 and x <= 4 then return y >= 1 and y <= 2 end
            return y >= 1
        end)
        local fp = CS.scan(img, d)
        t:truthy("scan: devolve pegada", fp ~= nil)
        t:eq("scan: linha de contato = última linha", fp and fp.bottom, 5)
        t:eq("scan: dois vãos de contato", fp and #fp.spans, 2)
        t:truthy("scan: colunas 0..2 e 5..7 tocam o chão (3..4 no ar)",
            fp and fp.spans[1][1] == 0 and fp.spans[1][2] == 2
            and fp.spans[2][1] == 5 and fp.spans[2][2] == 7)
        t:truthy("scan: cache por imagem (mesma tabela)", CS.scan(img, d) == fp)
        t:truthy("footprint(img) = scan", CS.footprint(img) == fp)
    end

    do
        local keys = { "fields_rock_0", "fields_tree_0", "landmark_rest", "landmark_shop",
                       "landmark_battle", "landmark_event", "landmark_elite", "landmark_chest" }
        for _, f in ipairs(love.filesystem.getDirectoryItems("assets/sprites/world")) do
            local k = f:match("^(%a+_landmark_%a+)%.png$")
            if k then keys[#keys + 1] = k end
        end
        for _, key in ipairs(keys) do
            local img, d = loadWorld(key)
            local fp = CS.scan(img, d)
            if t:truthy(key .. ": pegada medida", fp ~= nil and #fp.spans > 0) then
                local okSpan = true
                for _, sp in ipairs(fp.spans) do
                    if sp[1] > sp[2] or sp[1] < 0 or sp[2] >= fp.w then okSpan = false end
                end
                t:truthy(key .. ": vãos dentro da imagem e ordenados", okSpan)
            end
        end
    end

    local cfg = DATA.fields.contact
    local W, H = love.graphics.getDimensions()
    local FX, FY = math.floor(W * 0.5), math.floor(H * 0.6)

    do
        local img, d = loadWorld("landmark_rest")
        local fp = CS.scan(img, d)
        local s = 3
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            t:truthy("queue aceita imagem com pegada", CS.queue(img, FX, FY, s, 0.8, 1, 1))
            t:eq("queued() conta a fila", CS.queued(), 1)
            CS.flush()
            t:eq("flush esvazia a fila", CS.queued(), 0)
        end)
        local ground = lumaAt(id, 4, 4)
        local gaps, dark = 0, 0
        for _, sp in ipairs(fp.spans) do
            for col = sp[1], sp[2] do
                local sx = math.floor(FX + (col + 0.5 - fp.w / 2) * s)
                if lumaAt(id, sx, FY) < ground - 0.02 then dark = dark + 1 else gaps = gaps + 1 end
            end
        end
        t:eq("faixa de contato: toda coluna de contato escurecida (vãos = 0)", gaps, 0)
        t:truthy("faixa de contato: escureceu alguma coisa", dark > 0)
        local farX = math.floor(FX + (fp.w / 2 + 12) * s)
        t:truthy("fora da pegada o chão fica intacto", math.abs(lumaAt(id, farX, FY) - ground) < 0.005)
        local above = lumaAt(id, math.floor(FX + (fp.spans[1][1] + 0.5 - fp.w / 2) * s), FY - 2)
        t:truthy("faixa não sobe acima do contato", math.abs(above - ground) < 0.005)
        local hpx = math.max(1, math.floor(cfg.height * fp.w * s * (0.55 + 0.45 * 0.8) + 0.5))
        local below = lumaAt(id, math.floor(FX + (fp.spans[1][1] + 0.5 - fp.w / 2) * s), FY + 2 * hpx + 2)
        t:truthy("faixa é curta (acabou a 2× a altura)", math.abs(below - ground) < 0.005)
    end

    do
        local img, d = loadWorld("fields_tree_0")
        CS.scan(img, d)
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            CS.queue(img, FX, FY, 0.35, 0.2, 1, 1)
            CS.flush()
        end)
        t:truthy("escala mínima: faixa ≥ 1 px", lumaAt(id, FX, FY) < lumaAt(id, 4, 4) - 0.01)
    end

    do
        local img = love.graphics.newImage(love.image.newImageData(4, 4))
        local Debug = require("src.core.Debug")
        local warns = 0
        local realWarn = Debug.warn
        Debug.warn = function() warns = warns + 1 end
        local okQ, res = pcall(CS.queue, img, FX, FY, 2, 0.5, 1, 1)
        local okQ2 = pcall(CS.queue, img, FX, FY, 2, 0.5, 1, 1)
        Debug.warn = realWarn
        t:truthy("imagem sem pegada: no-op avisado", okQ and okQ2 and res == false and warns == 1)
        CS.flush()
    end

    do
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            CS.scorch(FX, FY, 120, 0.8, 1.35, 0.5)
        end)
        local ground = lumaAt(id, 4, 4)
        t:truthy("scorch: centro escurecido", lumaAt(id, FX, FY) < ground - 0.02)
        t:truthy("scorch: cabe no raio (fora = chão)", math.abs(lumaAt(id, FX + 120, FY) - ground) < 0.005)
        t:truthy("scorch: achatado (acima de 0,5 raio em y = chão)",
            math.abs(lumaAt(id, FX, FY - 60) - ground) < 0.005)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local function frameWith(key)
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(1)
            WorldRoad._camZ = 5.5
            for _ = 1, 10 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad._landmark = { key = key, z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
            CS.stats.scorch, CS.stats.contacts = 0, 0
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
            return CS.stats.scorch, CS.stats.contacts
        end
        local sc1, c1 = frameWith("landmark_rest")
        local sc2, c2 = frameWith("landmark_battle")
        t:eq("cena: fogueira desenha terra queimada", sc1, 1)
        t:eq("cena: bandeira não desenha terra queimada", sc2, 0)
        t:truthy("cena: props e marco enfileiram contato (" .. c1 .. ")", c1 >= 10 and c2 >= 10)
        WorldRoad._landmark = nil
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    do
        local img, d = loadWorld("fields_rock_0")
        CS.scan(img, d)
        CS.setFrame(cfg, 0.36, 0.22, 0.46)
        for _ = 1, 3 do CS.queue(img, FX, FY, 2, 0.5, 1, 1) end
        CS.flush()
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 50 do
            for _ = 1, 40 do CS.queue(img, FX, FY, 2, 0.5, 1, 1) end
            CS.flush()
        end
        local perKB = (collectgarbage("count") - k0) / 50
        collectgarbage("restart")
        t:truthy(string.format("fila sem lixo por quadro (%.2f KB ≤ 1)", perKB), perKB <= 1)
    end

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:truthy("WorldRoad: ContactShadow.flush logo após ShadowEngine.flush",
            src:find("ShadowEngine%.flush%(%)%s*\n%s*Scene%.Contact%.flush%(%)") ~= nil)
        t:truthy("WorldRoad: scan no tryLoadPng e no toImage",
            select(2, src:gsub("Scene%.Contact%.scan%(img, data%)", "")) >= 2)
        t:truthy("WorldRoad: scan nos quadros de animação",
            src:find("Scene.Contact.scan(im, data)", 1, true) ~= nil)
        t:falsy("WorldRoad sem shOptPool solto", src:find("local shOptPool", 1, true) ~= nil)
    end

    _G.gameSettings = savedSettings
    return t:done()
end

return M
```

Registrar em `tools/run_all_tests.lua` logo após `test_scene_grade`:

```lua
    { group = "unit",  name = "test_contact_shadow" },
```

- [ ] **Passo 2: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_contact_shadow`
Esperado: crash `module 'engine.ContactShadow' not found`.

- [ ] **Passo 3: Implementar `engine/ContactShadow.lua`**

```lua
local Debug = require("src.core.Debug")
local QuadMesh = require("engine.QuadMesh")
local ffi = require("ffi")

local ContactShadow = {}

ContactShadow.stats = { contacts = 0, scorch = 0, quads = 0 }

local foot = setmetatable({}, { __mode = "k" })
local warned = setmetatable({}, { __mode = "k" })
local frame = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true,
                r = 0.2, g = 0.15, b = 0.25 }
local queue, qn = {}, 0
local qm

local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local function hash01(n)
    local v = math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)
end

function ContactShadow.scan(img, data)
    local hit = foot[img]
    if hit ~= nil then return hit or nil end
    if not data then foot[img] = false; return nil end
    local w, h = data:getWidth(), data:getHeight()
    local px = data:getFormat() == "rgba8"
        and ffi.cast("const uint8_t*", data:getFFIPointer()) or nil
    local low = {}
    local maxRow = -1
    for x = 0, w - 1 do
        local lr = -1
        for y = h - 1, 0, -1 do
            local opaque
            if px then
                opaque = px[(y * w + x) * 4 + 3] >= 153
            else
                local _, _, _, a = data:getPixel(x, y)
                opaque = a >= 0.6
            end
            if opaque then lr = y; break end
        end
        low[x] = lr
        if lr > maxRow then maxRow = lr end
    end
    if maxRow < 0 then foot[img] = false; return nil end
    local spans = {}
    local a = nil
    for x = 0, w - 1 do
        local touch = low[x] >= 0 and low[x] >= maxRow - 1
        if touch and not a then a = x end
        if not touch and a then
            spans[#spans + 1] = { a, x - 1 }
            a = nil
        end
    end
    if a then spans[#spans + 1] = { a, w - 1 } end
    local fp = { spans = spans, bottom = maxRow, w = w, h = h }
    foot[img] = fp
    return fp
end

function ContactShadow.footprint(img)
    local f = foot[img]
    return f or nil
end

function ContactShadow.setFrame(cfg, r, g, b)
    if cfg then
        frame.alpha = cfg.alpha or frame.alpha
        frame.height = cfg.height or frame.height
        frame.spread = cfg.spread or frame.spread
        frame.dither = cfg.dither ~= false
    end
    frame.r, frame.g, frame.b = r or frame.r, g or frame.g, b or frame.b
    ContactShadow.stats.contacts, ContactShadow.stats.scorch = 0, 0
end

function ContactShadow.queue(img, x, y, s, t, alpha, flip)
    local fp = foot[img]
    if not fp then
        if fp == nil and not warned[img] then
            warned[img] = true
            Debug.warn("[ContactShadow] imagem sem pegada medida (scan não rodou): sem faixa de contato")
        end
        return false
    end
    qn = qn + 1
    local q = queue[qn]
    if not q then q = {}; queue[qn] = q end
    q.img, q.x, q.y, q.s, q.t = img, x, y, s, t or 1
    q.a, q.flip = alpha or 1, flip or 1
    ContactShadow.stats.contacts = ContactShadow.stats.contacts + 1
    return true
end

function ContactShadow.queued() return qn end

local function unit()
    local _, H = love.graphics.getDimensions()
    return math.max(1, math.floor(H / 250 + 0.5))
end

local function band(q, fp)
    local s, fl = q.s, q.flip
    local hpx = math.max(1, math.floor(frame.height * fp.w * s * (0.55 + 0.45 * q.t) + 0.5))
    local a = frame.alpha * q.a * (0.6 + 0.4 * q.t)
    local r, g, b = frame.r * 0.35, frame.g * 0.35, frame.b * 0.35
    local u = unit()
    local y0 = math.floor(q.y)
    for i = 1, #fp.spans do
        local sp = fp.spans[i]
        local cxs = (sp[1] + sp[2] + 1) * 0.5 - fp.w * 0.5
        local wd = math.max(1, math.floor((sp[2] - sp[1] + 1) * frame.spread * s + 0.5))
        local x0 = math.floor(q.x + fl * cxs * s - wd * 0.5)
        qm:rect(x0, y0, wd, hpx, 0, 0, 1, 1, r, g, b, a)
        if frame.dither then
            local yd = y0 + hpx
            local xx = x0
            local k = 0
            while xx < x0 + wd do
                local bx = math.floor(xx / u) % 4
                local by = math.floor(yd / u) % 4
                if BAYER[by + 1][bx + 1] < 8 then
                    qm:rect(xx, yd, math.min(u, x0 + wd - xx), u, 0, 0, 1, 1, r, g, b, a * 0.85)
                end
                xx = xx + u
                k = k + 1
                if k > 512 then break end
            end
        end
    end
end

function ContactShadow.flush()
    if qn == 0 then return end
    qm = qm or QuadMesh.new(2048)
    qm:reset()
    for i = 1, qn do
        local q = queue[i]
        local fp = foot[q.img]
        if fp then band(q, fp) end
        q.img = nil
    end
    qn = 0
    if qm.n > 0 then
        qm:upload(0, qm.n)
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(0, qm.n)
    end
    ContactShadow.stats.quads = qm.n
end

function ContactShadow.scorch(x, y, wPx, t, radiusK, alpha)
    local rx = math.max(2, (wPx or 2) * 0.5 * (radiusK or 1))
    local ry = math.max(1, rx * 0.38 * (0.55 + 0.45 * (t or 1)))
    local u = unit()
    local r, g, b = frame.r * 0.22, frame.g * 0.18, frame.b * 0.20
    local seed = math.floor(x * 0.37 + y * 1.91)
    local rows = math.max(1, math.floor(ry / u))
    for row = -rows, rows do
        local f = row / (rows + 0.5)
        local half = rx * math.sqrt(math.max(0, 1 - f * f))
        half = half * (0.86 + 0.14 * hash01(seed + row * 7.3))
        local yy = math.floor(y + row * u)
        local edge = math.abs(f)
        local a = (alpha or 0.5) * (1 - 0.45 * edge)
        if edge > 0.62 then
            local xx = math.floor(x - half)
            local xe = math.floor(x + half)
            while xx < xe do
                if BAYER[(math.floor(yy / u) % 4) + 1][(math.floor(xx / u) % 4) + 1] < 8 then
                    love.graphics.setColor(r, g, b, a)
                    love.graphics.rectangle("fill", xx, yy, u, u)
                end
                xx = xx + u
            end
        else
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", math.floor(x - half), yy,
                math.max(1, math.floor(half * 2 + 0.5)), u)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    ContactShadow.stats.scorch = ContactShadow.stats.scorch + 1
end

return ContactShadow
```

- [ ] **Passo 4: Ligar o WorldRoad (scan no load, fila nos props/marcos, flush depois da grama, terra queimada)**

**4a. `local Scene` (topo).** Vira:

```lua
local Scene = {
    Grade = require("engine.SceneGrade"),
    Contact = require("engine.ContactShadow"),
}
```

**4b. `toImage` (389-393).** ANTES:

```lua
local function toImage(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end
```

DEPOIS:

```lua
local function toImage(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    Scene.Contact.scan(img, data)
    return img
end
```

**4c. `tryLoadPng` (270).** Depois de `scanContentRect(img, path, data)` inserir:

```lua
    Scene.Contact.scan(img, data)
```

**4d. `readAnimFrames` (296).** Depois de `scanContentRect(im, path, data)` inserir:

```lua
                Scene.Contact.scan(im, data)
```

(Os três pontos rodam dentro de `prewarmJobs`, então a pegada é medida no pré-aquecimento, nunca no quadro da troca de bioma.)

**4e. Pools (2880-2892 e 2946-2953) viram campos do módulo (−4 locais).** ANTES:

```lua
local shOptPool, shOptN = {}, 0
local function shadowOpts(alphaK, flip, footPad, prof)
    shOptN = shOptN + 1
    local o = shOptPool[shOptN]
    if not o then o = {}; shOptPool[shOptN] = o end
```

DEPOIS:

```lua
WorldRoad._pools = { sh = {}, shN = 0, occ = {}, occN = 0 }
local function shadowOpts(alphaK, flip, footPad, prof)
    local P = WorldRoad._pools
    P.shN = P.shN + 1
    local o = P.sh[P.shN]
    if not o then o = {}; P.sh[P.shN] = o end
```

ANTES:

```lua
local occPool, occN = {}, 0
local function occluderSlot()
    occN = occN + 1
    local o = occPool[occN]
    if not o then o = {}; occPool[occN] = o end
    o.fn = nil
    return o
end
```

DEPOIS:

```lua
local function occluderSlot()
    local P = WorldRoad._pools
    P.occN = P.occN + 1
    local o = P.occ[P.occN]
    if not o then o = {}; P.occ[P.occN] = o end
    o.fn = nil
    return o
end
```

E em `drawProps` (2964) `shOptN, occN = 0, 0` → `WorldRoad._pools.shN, WorldRoad._pools.occN = 0, 0`.

**4f. `WorldRoad.draw`, depois do bloco `ShadowEngine.setFrame(...)` (3472-3477):**

```lua
    Scene.Contact.setFrame(Scene.Grade.cfg("contact"), Scene.Grade.shadowTint())
```

**4g. `drawList`: fila de contato.** Depois do bloco `if not ShadowEngine.queue(img, pxX, sy - 1, s, ...) ... end` (3182-3191):

```lua
                if p.kind ~= "tuft" and p.kind ~= "flowers" then
                    Scene.Contact.queue(img, pxX, sy, s, t, fadeA, lumFlip)
                end
```

Companheiras (3151-3158), depois de `ShadowEngine.queue(cimg, cx2, cy2 - 1, cs, ...)`:

```lua
                            Scene.Contact.queue(cimg, cx2, cy2, cs, t, 0.8 * fadeA, 1)
```

Cerca (3172-3173), depois de `ShadowEngine.queue(img, fx, fy - 1, fs, shadowOpts(0.85 * fadeA))`:

```lua
                            Scene.Contact.queue(img, fx, fy, fs, ft, 0.85 * fadeA, 1)
```

**4h. `drawForkPhysical` (3034-3045).** Entre o bloco da sombra e o `local br = ...`:

```lua
                local lmk = Scene.Grade.cfg("landmarks")[key:match("landmark_(%a+)$") or ""]
                if lmk and lmk.scorch then
                    Scene.Contact.scorch(px, shY, iw * s, tM,
                        lmk.scorch.radius, lmk.scorch.alpha * aMul)
                end
                Scene.Contact.queue(img, px, shY, s, tM, aMul, 1)
```

**4i. `drawLandmarkFront` (2910-2919).** Mesmo par, depois do bloco da sombra:

```lua
    local lmk = Scene.Grade.cfg("landmarks")[lm.key:match("landmark_(%a+)$") or ""]
    if lmk and lmk.scorch then
        Scene.Contact.scorch(lx, shY, iw * s, t, lmk.scorch.radius, lmk.scorch.alpha)
    end
    Scene.Contact.queue(img, lx, shY, s, t, 1, 1)
```

**4j. `drawProps` (3361).** ANTES:

```lua
    flushGrassTo(-1)
    ShadowEngine.flush()
end
```

DEPOIS:

```lua
    flushGrassTo(-1)
    ShadowEngine.flush()
    Scene.Contact.flush()
end
```

- [ ] **Passo 5: Rodar o teste, travas vizinhas e contagem**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_contact_shadow
CARDGAME_HEADLESS=1 lovec . test_one test_world_shadows
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: todos `== ALL GREEN ==`; `test_perf_budget` imprime draw calls ≤ 600 (a fila inteira é 1 draw call; a terra queimada ≤ 2 por quadro); contagem `193`.

- [ ] **Passo 6: Capturas, suíte inteira, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 02_contact_shadow
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/02_contact_shadow
cp "$SAVE"/integracao_terreno/02_contact_shadow/*.png tools/preview_out/integracao_terreno/02_contact_shadow/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir `b1_dia_landmark.png` (fogueira escolhida): faixa escura curta colada na base das pedras, terra queimada achatada sob a fogueira com a grama da frente por cima; `b1_dia_fork.png`: as três placas assentadas, sem vão claro entre base e chão.

```bash
git add engine/ContactShadow.lua tools/test_contact_shadow.lua tools/run_all_tests.lua src/ui/WorldRoad.lua tools/preview_out/integracao_terreno/02_contact_shadow
git commit -m "ContactShadow: faixa de contato com pegada medida por sprite (dither Bayer, cor do shadowTint) e terra queimada sob a fogueira

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 3: Oclusão pela base (`GrassField.requireTufts`) + landmark escolhido de volta ao pintor

**Files:**
- Modify: `engine/GrassField.lua` (241-244 stats; 345-403 draw/replay; 696-715 fim do draw; 717-723 clearCache)
- Modify: `src/ui/WorldRoad.lua` (`drawLandmarkFront` 2894-2924 apagar; `_farPass.._front` 2944; `drawCastleOf` 2097-2109; `drawForkPhysical` 3044-3045; `drawList` 3072-3076 e 3228-3229; `drawProps` 2962-2975 e 3355-3362; `WorldRoad.draw` 3492-3493 e 3601)
- Modify: `tools/test_world_props.lua` (acrescentar o bloco do Passo 1)
- Test: `tools/test_world_props.lua`

**Interfaces:**
- Consumes: `SceneGrade.cfg("occlusion") -> { baseCover, tuftsMin, tuftsMax, tuftScale = {lo, hi} }` (Tarefa 1); `ContactShadow.queue/scorch` (Tarefa 2); `GrassField.draw(ctx)` com `ctx.relFrom/relTo` (fatias), `emit(...)`, `hash(a, b)`, `K_BLADE`, `quads`, `N_THIN/N_BROAD`, `cDark/cMid/cLight` (internos do GrassField).
- Produces (usadas pelas Tarefas 5 e 6):
  - `GrassField.CELL_H = 16`.
  - `GrassField.beginFrame()` — zera os pedidos; chamado por `WorldRoad.draw` ANTES do castelo.
  - `GrassField.requireTufts(rel, x, w, n, scale)` — tufos obrigatórios na fatia que contém `rel` (logo à frente da base: o chamador passa `rel - 0.05`), `n` lâminas espalhadas em `x ± w/2`, altura `scale × CELL_H` px.
  - `GrassField.stats.tufts` (lâminas de tufo escritas no quadro), `GrassField._tuftRequests() -> list, n`.
  - WorldRoad: `WorldRoad._lists = { far, near, behind, front }`, `WorldRoad._landmarkDrawnAt` (número de fatias de grama já desenhadas quando o landmark escolhido foi pintado), função interna `drawChosenLandmark()` dentro de `drawProps`; `drawLandmarkFront` deixa de existir.

- [ ] **Passo 1: Teste que falha (extensão de `tools/test_world_props.lua`)**

Inserir antes de `return t:done()`:

```lua
    do
        local GrassField = require("engine.GrassField")
        local savedSettings = _G.gameSettings
        _G.gameSettings = { reducedMotion = false }
        local W, H = love.graphics.getDimensions()
        local cv = love.graphics.newCanvas(W, H)
        local function frame()
            WorldRoad.update(1 / 30)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
        end
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 10 do frame() end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad._landmark = { key = "landmark_rest", z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        GrassField.resetStats()
        frame()
        local total = GrassField.stats.builds + GrassField.stats.replays
        local at = WorldRoad._landmarkDrawnAt or -1
        t:truthy(("landmark escolhido pintado ENTRE fatias de grama (fatia %d de %d)"):format(at, total),
            at > 0 and at < total)
        t:truthy("tufos escritos no quadro (" .. GrassField.stats.tufts .. ")", GrassField.stats.tufts > 0)
        local lx = WorldRoad.getRoadAnchor(9, 0, 52, W, H - 52)
        local reqs, n = GrassField._tuftRequests()
        local near = false
        for i = 1, n do
            if math.abs(reqs[i].x - lx) < 3 and reqs[i].rel < 9 and reqs[i].rel > 8.5 then near = true end
        end
        t:truthy("tufo pedido na frente da base do landmark", near)
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("drawLandmarkFront não existe mais", src:find("drawLandmarkFront", 1, true) ~= nil)
        t:truthy("landmark escolhido desenha dentro de drawProps (balanço da cena)",
            src:find("local function drawChosenLandmark()", 1, true) ~= nil)
        t:truthy("GrassField.beginFrame antes do castelo",
            src:find("GrassField%.beginFrame%(%).-drawCastle%(g, x, w, WorldRoad%._camZ%)") ~= nil)

        GrassField.resetStats()
        for _ = 1, 3 do frame() end
        GrassField.resetStats()
        for _ = 1, 5 do frame() end
        t:eq("com tufos e câmera parada a grama ainda reusa o lote (0 builds)", GrassField.stats.builds, 0)

        _G.gameSettings = { reducedMotion = true }
        GrassField.resetStats()
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        frame()
        t:truthy("reducedMotion mantém os tufos (informação, não movimento)", GrassField.stats.tufts > 0)
        _G.gameSettings = { reducedMotion = false }

        local realBegin = GrassField.beginFrame
        GrassField.beginFrame = function()
            realBegin()
            GrassField.requireTufts(5, 100, 10, 3, 0.01)
        end
        GrassField.resetStats()
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        local okMin = pcall(frame)
        GrassField.beginFrame = realBegin
        t:truthy("tufo com escala mínima não quebra", okMin)

        WorldRoad._landmark = nil
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        _G.gameSettings = savedSettings
    end
```

- [ ] **Passo 2: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_world_props`
Esperado: `[FAIL] landmark escolhido pintado ENTRE fatias`, `[FAIL] tufos escritos`, crash em `GrassField._tuftRequests` (nil) ou `== SOME FAILED ==`.

- [ ] **Passo 3: `GrassField.requireTufts`**

`engine/GrassField.lua`. Depois de `local K_CLUMP, K_CREST, K_BLADE, K_BROAD, K_FLOWER = 0, 1, 2, 3, 4` (143):

```lua
GrassField.CELL_H = CELL_H
local tufts, tuftN = {}, 0
function GrassField.beginFrame() tuftN = 0 end
function GrassField.requireTufts(rel, x, w, n, scale)
    if rel ~= rel or x ~= x then return end
    tuftN = tuftN + 1
    local q = tufts[tuftN]
    if not q then q = {}; tufts[tuftN] = q end
    q.rel, q.x, q.w = rel, x, math.max(2, w or 2)
    q.n, q.s, q.done = math.max(1, math.floor(n or 3)), math.max(0.02, scale or 1), false
end
function GrassField._tuftRequests() return tufts, tuftN end
local function tuftSig(relFrom, relTo)
    local sig = 0
    for i = 1, tuftN do
        local q = tufts[i]
        if q.rel > relFrom and q.rel <= relTo then
            sig = sig + math.floor(q.x) * 7 + math.floor(q.w) + q.n * 13 + math.floor(q.s * 100) * 3
        end
    end
    return sig
end
```

Stats (241-245): `GrassField.stats = { replays = 0, builds = 0, sprites = 0, tufts = 0 }` e em `resetStats` `st.replays, st.builds, st.sprites, st.tufts = 0, 0, 0, 0`.

No `draw(ctx)`, logo após `local relTo = ctx.relTo or (ctx.relCrest + 2)` (355):

```lua
    local sig = tuftSig(relFrom, relTo)
```

Replay (386-387) ANTES: `if sl and sl[1] == relFrom and sl[2] == relTo then` → DEPOIS: `if sl and sl[1] == relFrom and sl[2] == relTo and sl[5] == sig then`. No replay, os pedidos dessa fatia são consumidos sem emitir (senão ficariam pendentes para a próxima fatia):

```lua
        if sl and sl[1] == relFrom and sl[2] == relTo and sl[5] == sig then
            for i = 1, tuftN do
                local q = tufts[i]
                if q.rel > relFrom and q.rel <= relTo then q.done = true end
            end
```

Emissão dos tufos, inserir ANTES de `local count = qm.n - sliceStart` (697):

```lua
    for i = 1, tuftN do
        local q = tufts[i]
        if not q.done and q.rel > relFrom and q.rel <= relTo then
            q.done = true
            local tq = g.tOf(q.rel)
            if tq and tq > 0 then
                local nx = (q.x - ctx.x) / w
                local zq = camZ + q.rel
                local qx = math.floor(q.x)
                for bi = 0, q.n - 1 do
                    local hb = hash(qx * 31 + bi, 17)
                    local hv = hash(qx * 53 + bi, 7)
                    local bx = q.x - q.w * 0.5 + (bi + 0.5) / q.n * q.w
                        + (hb - 0.5) * q.w / q.n
                    local base = g.latY(bx - g.cx, tq)
                    local s = q.s * (0.72 + hb * 0.55)
                    local vquad = (hv < P.broad)
                        and (N_THIN + math.floor(hb * N_BROAD)) or math.floor(hv * N_THIN)
                    local ht = hash(qx * 17 + bi, 23)
                    local c = (ht < 0.25) and cDark or ((ht < 0.55) and cMid or cLight)
                    emit(math.floor(bx), math.floor(base + 1),
                        s * ((hb < 0.5) and 1 or -1), s,
                        CELL_W / 2, CELL_H, CELL_W, CELL_H, quads[vquad],
                        c8(c[1]), c8(c[2]), c8(c[3]), K_BLADE, nx, zq, hb, hv)
                end
                GrassField.stats.tufts = GrassField.stats.tufts + q.n
            end
        end
    end
```

Gravação da fatia (711): `sl[1], sl[2], sl[3], sl[4] = relFrom, relTo, sliceStart, count` → `sl[1], sl[2], sl[3], sl[4], sl[5] = relFrom, relTo, sliceStart, count, sig`.

`clearCache` (717-723): acrescentar `tuftN = 0`.

- [ ] **Passo 4: WorldRoad — tufos dos props, do castelo e dos marcos**

**4a. `WorldRoad.draw`, logo após `WeatherEngine.beginFrame({ ... })` (3492-3493):**

```lua
    GrassField.beginFrame()
```

**4b. `drawList`, logo depois do `PropCut.draw(img, p.kind, ...)` do prop (3228-3229):**

```lua
                if p.kind ~= "tuft" and p.kind ~= "flowers" and p.kind ~= "fence"
                   and fadeA >= 0.5 then
                    local oc2 = Scene.Grade.cfg("occlusion")
                    local isTree = (p.kind == "tree" or p.kind == "pine"
                        or p.kind == "deadtree" or p.kind == "bush")
                    local hsh = (p.z * 7.31) % 1
                    local nT = isTree and (1 + math.floor(hsh * 2))
                        or (oc2.tuftsMin + math.floor(hsh * (oc2.tuftsMax - oc2.tuftsMin + 1)))
                    local hpx = oc2.baseCover * ihv * s * (isTree and 0.6 or 1)
                        * (oc2.tuftScale[1] + hsh * (oc2.tuftScale[2] - oc2.tuftScale[1]))
                    GrassField.requireTufts(rel - 0.05, pxX, iw * s * 0.8, nT,
                        hpx / GrassField.CELL_H)
                end
```

**4c. `drawForkPhysical`, depois do `love.graphics.draw(img, ...)` do marco (3044-3045):**

```lua
                do
                    local oc2 = Scene.Grade.cfg("occlusion")
                    local hsh = (i * 0.618) % 1
                    GrassField.requireTufts(relM - 0.05, px, iw * s * 0.8,
                        oc2.tuftsMin + math.floor(hsh * (oc2.tuftsMax - oc2.tuftsMin + 1)),
                        oc2.baseCover * ih * s * aMul / GrassField.CELL_H)
                end
```

**4d. `drawCastleOf`, dentro do `if alpha >= 1 then` que começa na 2101, logo após `WorldRoad._castleBaseHalf = iw * s * 0.44`:**

```lua
        GrassField.requireTufts(REL_CREST - 0.1, cx, iw * s * 0.9, 6,
            (ih * s * 0.05) / GrassField.CELL_H)
```

- [ ] **Passo 5: WorldRoad — landmark escolhido como pseudo-prop em `drawProps`, apagar `drawLandmarkFront`**

**5a. Apagar** a função `drawLandmarkFront` inteira (2894-2924) e a chamada `drawLandmarkFront(g, x, w, WorldRoad._camZ)` em `WorldRoad.draw` (3601).

**5b. Listas de passe (2944).** ANTES: `local _farPass, _nearPass, _behind, _front = {}, {}, {}, {}` → DEPOIS:

```lua
WorldRoad._lists = { far = {}, near = {}, behind = {}, front = {} }
```

Em `drawProps` (2966-2967): `local farPass = _farPass` / `local nearPass = _nearPass` → `local farPass = WorldRoad._lists.far` / `local nearPass = WorldRoad._lists.near`; em 3329: `local behind, front = _behind, _front` → `local behind, front = WorldRoad._lists.behind, WorldRoad._lists.front`.

**5c. Em `drawProps`, depois do bloco `local fkMarks = nil do ... end` (2986-2998) e ANTES de `local function drawForkPhysical()`:**

```lua
    local lmMark = nil
    do
        local lm = WorldRoad._landmark
        if lm then
            local relL = lm.z - camZ
            if relL < -3 then
                WorldRoad._landmark = nil
            else
                local tL = g.tOf(relL)
                if tL and tL >= 0 then
                    lmMark = WorldRoad._lmMark or {}
                    WorldRoad._lmMark = lmMark
                    lmMark.rel, lmMark.t, lmMark.lm, lmMark.drawn = relL, tL, lm, false
                end
            end
        end
    end
    local function drawChosenLandmark()
        local lm, rel, t = lmMark.lm, lmMark.rel, lmMark.t
        local img = getLandmark(lm.key)
        if not img then return end
        img = landmarkFrame(lm.key, lm.phase or lm.z) or img
        local iw, ih = img:getWidth(), img:getHeight()
        local s = g.scaleAt(lm.size or 2.0, t, LMG.refH(lm.key, ih))
        local py = g.latY(0, t)
        local lx = g.cx + roadWobble(lm.z, t, w)
        local shPad = lmCfg(LANDMARK_SHADOW_PAD, lm.key) or 0
        local shY = py - 1 - shPad * s
        if not ShadowEngine.sprite(img, lx, shY, s,
            shadowOpts(nil, nil, shPad, lmCfg(WorldRoad.SHADOW_PROFILE, lm.key))) then
            love.graphics.setColor(0, 0, 0, 0.22)
            love.graphics.ellipse("fill",
                lx + sunShadowDir(g, x, w, lx) * iw * s * 0.14,
                shY, iw * s * 0.30, math.max(2, 4 * g.persp(t)))
            love.graphics.setColor(1, 1, 1, 1)
        end
        local lmk = Scene.Grade.cfg("landmarks")[lm.key:match("landmark_(%a+)$") or ""]
        if lmk and lmk.scorch then
            Scene.Contact.scorch(lx, shY, iw * s, t, lmk.scorch.radius, lmk.scorch.alpha)
        end
        Scene.Contact.queue(img, lx, shY, s, t, 1, 1)
        local lc = Scene.Grade.color("landmark", t, LMG.c)
        love.graphics.setColor(lc[1], lc[2], lc[3], 1)
        love.graphics.draw(img, math.floor(lx - iw * s / 2), math.floor(py - ih * s), 0, s, s)
        love.graphics.setColor(1, 1, 1, 1)
        drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, 1)
        submitLandmarkLight(lm.key, lx, py, iw, ih, s, rel, lm.z)
        submitLandmarkOccluder(img, lx, py, iw, ih, s, rel)
        local oc2 = Scene.Grade.cfg("occlusion")
        GrassField.requireTufts(rel - 0.05, lx, iw * s * 0.8, oc2.tuftsMax,
            oc2.baseCover * ih * s / GrassField.CELL_H)
        WorldRoad._landmarkDrawnAt = GrassField.stats.builds + GrassField.stats.replays
    end
```

**5d. `drawList` (3072-3076).** Depois do bloco `if fkMarks and not fkMarks.drawn and rel < fkMarks.rel then ... end` inserir:

```lua
            if lmMark and not lmMark.drawn and rel < lmMark.rel then
                flushGrassTo(lmMark.rel)
                drawChosenLandmark()
                lmMark.drawn = true
            end
```

**5e. Fim de `drawProps` (3355-3362).** ANTES:

```lua
    if fkMarks and not fkMarks.drawn then
        flushGrassTo(fkMarks.rel)
        drawForkPhysical()
        fkMarks.drawn = true
    end
    flushGrassTo(-1)
```

DEPOIS:

```lua
    if fkMarks and not fkMarks.drawn then
        flushGrassTo(fkMarks.rel)
        drawForkPhysical()
        fkMarks.drawn = true
    end
    if lmMark and not lmMark.drawn then
        flushGrassTo(lmMark.rel)
        drawChosenLandmark()
        lmMark.drawn = true
    end
    flushGrassTo(-1)
```

- [ ] **Passo 6: Rodar os testes, contagem e perf**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_world_props
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_worldroad_resume
CARDGAME_HEADLESS=1 lovec . test_one test_contact_shadow
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: todos verdes (o `test_worldroad_resume` continua vendo `_landmark` sumir com `rel < -3`); contagem `188` (193 − `drawLandmarkFront` − 4 listas). `test_perf_budget`: "grama com câmera parada: nenhuma fatia reconstruída" continua 0 (a assinatura dos tufos é estável com a câmera parada).

- [ ] **Passo 7: Capturas, suíte, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 03_oclusao_base
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/03_oclusao_base
cp "$SAVE"/integracao_terreno/03_oclusao_base/*.png tools/preview_out/integracao_terreno/03_oclusao_base/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir `b1_dia_landmark.png`: capim na frente da base da fogueira; `b1_meio_fork.png`: tufos na base das três placas e dos troncos; `b1_dia_castelo.png`: franja na colina sob o castelo.

```bash
git add engine/GrassField.lua src/ui/WorldRoad.lua tools/test_world_props.lua tools/preview_out/integracao_terreno/03_oclusao_base
git commit -m "Oclusão pela base: tufos obrigatórios na fatia à frente de props, marcos e castelo; o landmark escolhido volta ao pintor como pseudo-prop dentro do balanço

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 4: `WeatherEngine` — névoa baixa na base das montanhas + véu de profundidade por fatia

**Files:**
- Modify: `engine/WeatherEngine.lua` (1-3 requires; 75-82 estado; 481-497 `beginFrame`; 648-661 `flushTo`; 663-734 haze; 809-818 `reset`)
- Modify: `src/ui/WorldRoad.lua` (`WorldRoad.draw` 3496-3501: chamada de `drawLowFog` entre `drawClouds` e `WeatherEngine.drawSky`)
- Modify: `tools/test_weather.lua` (bloco novo antes do bloco final de varredura de fonte, linha 494)
- Test: `tools/test_weather.lua`

**Interfaces:**
- Consumes: `SceneGrade.isActive()`, `SceneGrade.fogAlpha(t)`, `SceneGrade.fogColor() -> r, g, b`, `SceneGrade.cfg("lowFog") -> { alpha, height, drift }` (Tarefa 1); `QuadMesh` (engine); `geo` do WeatherEngine (`geo.x, geo.w, geo.latY, geo.relCrest, geo.tPow`, já preenchido em `beginFrame`).
- Produces (usada pela Tarefa 5):
  - `WeatherEngine.drawLowFog(x, yTop, w, h, cfg, alphaK)` — faixa de névoa com ruído lento recortada em `(x, yTop, w, h)`; `cfg = { alpha, height, drift }`; `alphaK` multiplica; `reducedMotion` zera a deriva.
  - `WeatherEngine.stats.veilBands` (véus de profundidade desenhados no quadro) e `WeatherEngine.stats.lowFogBands`.
  - `WeatherEngine._veilAlphaAt(t) -> number` (= `SceneGrade.fogAlpha(t) × 0.55`).
  - `flushTo(relLow)` passa a desenhar, DEPOIS das partículas da fatia, um véu plano da cor da névoa entre a profundidade do flush anterior e `relLow`.

- [ ] **Passo 1: Teste que falha (bloco novo em `tools/test_weather.lua`)**

Inserir imediatamente antes do bloco `do local src = love.filesystem.read("src/ui/WorldRoad.lua") ...` (linha 494):

```lua
    do
        local SceneGrade = require("engine.SceneGrade")
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 3 do frame(1) end
        t:truthy("véu de profundidade desenhado por fatia (" .. tostring(WeatherEngine.stats.veilBands) .. ")",
            (WeatherEngine.stats.veilBands or 0) >= 3)
        t:truthy("névoa baixa desenhada na base das montanhas (" .. tostring(WeatherEngine.stats.lowFogBands) .. ")",
            (WeatherEngine.stats.lowFogBands or 0) >= 1)
        SceneGrade.begin("fields", 1, nil, 1, { 0.8, 0.8, 0.8 })
        t:truthy("véu mais forte no horizonte que na base",
            WeatherEngine._veilAlphaAt(0) > WeatherEngine._veilAlphaAt(1))
        t:truthy("véu nunca passa de 0,5", WeatherEngine._veilAlphaAt(0) <= 0.5)

        WeatherEngine.disabled = true
        frame(1)
        t:truthy("clima desligado ainda desenha o véu de profundidade", (WeatherEngine.stats.veilBands or 0) >= 3)
        WeatherEngine.disabled = false

        local W2, H2 = love.graphics.getDimensions()
        local function lowFogShot(tm, rm)
            _G.gameSettings = { reducedMotion = rm }
            local cv = love.graphics.newCanvas(W2, H2)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.2, 0.2, 0.2, 1)
            WeatherEngine.update(0, { biomeId = "fields", camZ = 5.5, time = tm })
            SceneGrade.begin("fields", 0.5, nil, 1, { 0.8, 0.8, 0.8 })
            WeatherEngine.drawLowFog(0, 200, W2, 60, { alpha = 0.4, height = 0.1, drift = 0.02 }, 1)
            love.graphics.setCanvas()
            return cv:newImageData()
        end
        local a1 = lowFogShot(100, false)
        local a2 = lowFogShot(130, false)
        local r0 = select(1, a1:getPixel(10, 100))
        local inside = false
        local moved = false
        for x = 0, W2 - 1, 7 do
            local r, _, _, _ = a1:getPixel(x, 250)
            if math.abs(r - 0.2) > 0.01 then inside = true end
            local rb = a2:getPixel(x, 250)
            if math.abs(r - rb) > 0.005 then moved = true end
        end
        t:truthy("névoa baixa: pinta dentro da faixa", inside)
        t:truthy("névoa baixa: fora da faixa intacto", math.abs(r0 - 0.2) < 0.005)
        t:truthy("névoa baixa: deriva com o tempo", moved)
        local b1 = lowFogShot(100, true)
        local b2 = lowFogShot(130, true)
        t:truthy("reducedMotion: névoa baixa parada (quadros idênticos)", b1:getString() == b2:getString())
        _G.gameSettings = { reducedMotion = false }

        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local pm = src:find("drawMountains(g, x, w, WorldRoad._camZ)", 1, true)
        local pf = src:find("WeatherEngine.drawLowFog(", 1, true)
        local pmf = src:find("drawMountainsFront(g, x, w, WorldRoad._camZ)", 1, true)
        t:truthy("WorldRoad: névoa baixa entre o fundo e a frente das montanhas",
            pm ~= nil and pf ~= nil and pmf ~= nil and pm < pf and pf < pmf)
    end
```

- [ ] **Passo 2: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_weather`
Esperado: `[FAIL] véu de profundidade desenhado por fatia (nil)` e crash em `WeatherEngine._veilAlphaAt` (nil).

- [ ] **Passo 3: Implementar no `WeatherEngine`**

Topo (depois de `local GrassField = require("engine.GrassField")`):

```lua
local SceneGrade = require("engine.SceneGrade")
```

Estado (depois de `local camZ0 = 0`, linha 82):

```lua
local vqm = nil
local veilRel = 0
local VEIL_K = 0.55
local function veilAlphaAt(t) return SceneGrade.fogAlpha(t) * VEIL_K end
WeatherEngine._veilAlphaAt = veilAlphaAt
```

Stats (85): `WeatherEngine.stats = { particles = 0, quads = 0, flushes = 0, veilBands = 0, lowFogBands = 0 }`.

`beginFrame` (481-490) ANTES:

```lua
function WeatherEngine.beginFrame(f)
    local g = f.geom
    geo = geo or {}
    geo.y, geo.h, geo.w, geo.x = g.y, g.h, f.w, f.x
    geo.latY, geo.persp, geo.cx = g.latY, g.persp, g.cx
    geo.relCrest, geo.tPow = f.relCrest, f.tPow
    if prefill and cur and lastCtx then WeatherEngine.update(0, lastCtx) end
    nS, cursorK, microN, poolN = 0, 0, 0, 0
    if WeatherEngine.disabled or nP == 0 then return end
```

DEPOIS:

```lua
function WeatherEngine.beginFrame(f)
    local g = f.geom
    geo = geo or {}
    geo.y, geo.h, geo.w, geo.x = g.y, g.h, f.w, f.x
    geo.latY, geo.persp, geo.cx = g.latY, g.persp, g.cx
    geo.relCrest, geo.tPow = f.relCrest, f.tPow
    if prefill and cur and lastCtx then WeatherEngine.update(0, lastCtx) end
    nS, cursorK, microN, poolN = 0, 0, 0, 0
    veilRel = f.relCrest
    vqm = vqm or QuadMesh.new(64)
    WeatherEngine.stats.veilBands, WeatherEngine.stats.lowFogBands = 0, 0
    if WeatherEngine.disabled or nP == 0 then return end
```

`flushTo` (648-661) ANTES:

```lua
function WeatherEngine.flushTo(relLow)
    if nS == 0 or cursorK >= nS then return end
    local k2 = cursorK
    while k2 < nS and relS[k2 + 1] >= relLow do k2 = k2 + 1 end
    if k2 == cursorK then return end
    local from = cursorK > 0 and qEnd[cursorK] or 0
    local to = qEnd[k2]
    cursorK = k2
    if to > from then
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(from, to - from)
        WeatherEngine.stats.flushes = WeatherEngine.stats.flushes + 1
    end
end
```

DEPOIS:

```lua
local function depthVeil(relLow)
    if not geo or not vqm or not SceneGrade.isActive() then return end
    local lo = max(0, relLow)
    if lo >= veilRel then return end
    local relCrest, tPow = geo.relCrest, geo.tPow
    local tA = tOfRel(veilRel, relCrest, tPow)
    local tB = tOfRel(lo, relCrest, tPow)
    veilRel = lo
    local yA = floor(geo.latY(0, tA))
    local yB = floor(geo.latY(0, tB)) + 1
    if yB <= yA then return end
    local a = veilAlphaAt((tA + tB) * 0.5)
    if a < 0.004 then return end
    local r, g, b = SceneGrade.fogColor()
    vqm:reset()
    vqm:rect(geo.x, yA, geo.w, yB - yA, 0, 0, 1, 1, min(1, r), min(1, g), min(1, b), a)
    vqm:upload(0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    vqm:draw(0, 1)
    WeatherEngine.stats.veilBands = WeatherEngine.stats.veilBands + 1
end

function WeatherEngine.flushTo(relLow)
    if nS > 0 and cursorK < nS then
        local k2 = cursorK
        while k2 < nS and relS[k2 + 1] >= relLow do k2 = k2 + 1 end
        if k2 > cursorK then
            local from = cursorK > 0 and qEnd[cursorK] or 0
            local to = qEnd[k2]
            cursorK = k2
            if to > from then
                love.graphics.setColor(1, 1, 1, 1)
                qm:draw(from, to - from)
                WeatherEngine.stats.flushes = WeatherEngine.stats.flushes + 1
            end
        end
    end
    depthVeil(relLow)
end
```

`drawLowFog`, inserir depois de `drawHaze` (728) e antes de `flushAll`:

```lua
function WeatherEngine.drawLowFog(x, yTop, w, h, cfg, alphaK)
    if not cfg or (cfg.alpha or 0) <= 0 or h < 2 then return end
    if not hazeImg then buildHaze() end
    local r, g, b = 0.9, 0.9, 0.95
    if SceneGrade.isActive() then r, g, b = SceneGrade.fogColor() end
    r, g, b = min(1, r), min(1, g), min(1, b)
    local a = cfg.alpha * (alphaK or 1)
    local s = max(1, floor(h / HAZE_H + 0.5))
    local bandH = HAZE_H * s
    local tm = reduced() and 0 or time
    local drift = (cfg.drift or 0) * 600 * tm
    local off = floor((drift % (HAZE_W * s)) / s) * s
    local sx0, sy0 = love.graphics.transformPoint(x, yTop)
    local sx1, sy1 = love.graphics.transformPoint(x + w, yTop + h)
    love.graphics.push("all")
    love.graphics.setScissor(floor(min(sx0, sx1)), floor(min(sy0, sy1)),
        math.ceil(abs(sx1 - sx0)), math.ceil(abs(sy1 - sy0)))
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(hazeImg, hazeQuad, x - HAZE_W * s * 2 + off, yTop + h - bandH, 0, s, s)
    love.graphics.setColor(r, g, b, a * 0.6)
    love.graphics.draw(hazeImg, hazeQuad, x - HAZE_W * s * 2 - off, yTop + h - bandH * 0.6, 0, s, s)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    WeatherEngine.stats.lowFogBands = WeatherEngine.stats.lowFogBands + 2
end
```

`reset` (809-818): acrescentar `veilRel = 0`.

- [ ] **Passo 4: Chamar no WorldRoad**

`WorldRoad.draw` (3496-3501) ANTES:

```lua
    drawSky(g, x, y, w)
    drawCelestial(g, x, y, w)
    drawMountains(g, x, w, WorldRoad._camZ)
    drawClouds(g, x, y, w)
    WeatherEngine.drawSky(g, x, w)
    drawMountainsFront(g, x, w, WorldRoad._camZ)
```

DEPOIS:

```lua
    drawSky(g, x, y, w)
    drawCelestial(g, x, y, w)
    drawMountains(g, x, w, WorldRoad._camZ)
    drawClouds(g, x, y, w)
    do
        local lf = Scene.Grade.cfg("lowFog")
        local bandH = math.floor(h * lf.height)
        WeatherEngine.drawLowFog(x, g.crestApexY - bandH, w, bandH + 6, lf, 1)
    end
    WeatherEngine.drawSky(g, x, w)
    drawMountainsFront(g, x, w, WorldRoad._camZ)
```

(A trava antiga do `test_weather` exige `WeatherEngine.drawSky` imediatamente antes de `drawMountainsFront`; por isso a névoa baixa entra ANTES do raio.)

- [ ] **Passo 5: Testes, perf, contagem**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_weather
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: verdes; draw calls do `test_perf_budget` sobem no máximo ~40 (um véu por fatia) e ficam ≤ 600; contagem `188`.

- [ ] **Passo 6: Capturas, suíte, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 04_nevoa_camadas
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/04_nevoa_camadas
cp "$SAVE"/integracao_terreno/04_nevoa_camadas/*.png tools/preview_out/integracao_terreno/04_nevoa_camadas/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir `b1_por_castelo.png`: faixa de névoa na base das montanhas, o fundo da estrada mais lavado que a frente, sem degrau visível entre fatias (se houver degrau, baixe `VEIL_K` para 0,45 e refaça a captura).

```bash
git add engine/WeatherEngine.lua src/ui/WorldRoad.lua tools/test_weather.lua tools/preview_out/integracao_terreno/04_nevoa_camadas
git commit -m "WeatherEngine: névoa baixa na base das montanhas e véu de profundidade por fatia, somado ao véu da névoa de intenção

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 5: Interação de cada landmark com o terreno (fogueira, bandeira, loja, castelo, evento, elite)

**Files:**
- Modify: `engine/LightEngine.lua` (112-144 `submit`: campo `sy`; 252-261 composite: escala vertical; acessor `_lastEntry`)
- Modify: `engine/LuminaireEngine.lua` (229-252: `drawEmbersSpec` + `drawEmbers` delegando)
- Modify: `engine/WeatherEngine.lua` (50-56 presets internos; 773-802 `emitLeaf`: irmão `emitDust`; 516-536 alpha por partícula)
- Modify: `engine/ShadowEngine.lua` (12-19 `setFrame`, 169-176 `queue`: `ShadowEngine.stats.queued`)
- Modify: `src/ui/WorldRoad.lua` (`drawLandmarkSmoke` 1309-1336; `submitLandmarkLight` 1338-1364; `drawCastleOf` 2084-2099 e 2101-2109; `drawForkPhysical` e `drawChosenLandmark` em `drawProps`; `LMG` campos novos)
- Create: `tools/test_landmark_fx.lua`
- Modify: `tools/run_all_tests.lua` (registrar `test_landmark_fx` depois de `test_contact_shadow`)
- Test: `tools/test_landmark_fx.lua`

**Interfaces:**
- Consumes: `SceneGrade.cfg("landmarks")[kind]` com `kind ∈ rest|battle|shop|event|elite|castle` (Tarefa 1); `ContactShadow.scorch` (Tarefa 2, já ligado); `GrassField.windAt(nx, wz, t, P, pers)`; `WeatherEngine.drawLowFog(x, yTop, w, h, cfg, alphaK)` (Tarefa 4); `LuminaireEngine.anchor("landmark", key, 0, path)`; `ShadowEngine.queue(img, feetX, feetY, s, opts)`.
- Produces:
  - `LightEngine.submit(spec)` aceita `spec.sy` (escala vertical da poça, 1 = círculo); `LightEngine._lastEntry() -> entry|nil`.
  - `LuminaireEngine.drawEmbersSpec(em, fx, fy, sh, seed)` com `em = { color = {r,g,b}, count = n }`; `drawEmbers(bid, kind, ...)` delega.
  - `WeatherEngine.emitDust(dxFrac, z, t, hFrac, color, alpha)`; `WeatherEngine.dustCount() -> n`; teto `MAX_DUST = 14`.
  - `ShadowEngine.stats = { queued = 0 }` (zerado em `setFrame`).
  - WorldRoad: `drawLandmarkSmoke(key, px, py, iw, ih, s, alpha, thin)`; `submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK, lmk)`; `LMG.castleShOpts`, `LMG.LIGHT_SHOP_GLOW`; `WorldRoad._flagKx` (último cisalhamento da bandeira, só diagnóstico de teste).

- [ ] **Passo 1: Teste que falha (`tools/test_landmark_fx.lua`)**

```lua
local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("landmarks × terreno: fogueira, bandeira, loja, castelo, evento, elite")
    local LightEngine = require("engine.LightEngine")
    local LuminaireEngine = require("engine.LuminaireEngine")
    local WeatherEngine = require("engine.WeatherEngine")
    local ShadowEngine = require("engine.ShadowEngine")
    local WorldRoad = require("src.ui.WorldRoad")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local W, H = love.graphics.getDimensions()

    do
        LightEngine.setEnabled(true)
        LightEngine.beginFrame({ 0.8, 0.8, 0.8 })
        LightEngine.submit({ x = 100, y = 100, radius = 40, sy = 0.35, color = { 1, 0.7, 0.4 },
            intensity = 0.3, dither = true, levels = 6, z = 5 })
        local e = LightEngine._lastEntry()
        t:truthy("LightEngine.submit guarda sy (poça rasa e alongada)", e ~= nil and e.sy == 0.35)
        local okC = pcall(LightEngine.composite, 0, 0, W, H)
        t:truthy("composite desenha poça com sy sem erro", okC)
        LightEngine.setEnabled(nil)
    end

    do
        local n = 0
        local realRect = love.graphics.rectangle
        love.graphics.rectangle = function(...) n = n + 1; return realRect(...) end
        LuminaireEngine.drawEmbersSpec({ color = { 1, 0.6, 0.2 }, count = 4 }, 100, 100, 40, 3)
        local big = n
        n = 0
        LuminaireEngine.drawEmbersSpec({ color = { 1, 0.6, 0.2 }, count = 4 }, 100, 100, 10, 3)
        local small = n
        love.graphics.rectangle = realRect
        t:truthy("drawEmbersSpec: brasas com chama alta (" .. big .. ")", big > 0)
        t:eq("drawEmbersSpec: nada com chama baixa (< 14 px)", small, 0)
        local calls = 0
        local realSpec = LuminaireEngine.drawEmbersSpec
        LuminaireEngine.drawEmbersSpec = function(...) calls = calls + 1; return realSpec(...) end
        LuminaireEngine.drawEmbers("abyss", "brazier", 100, 100, 40, 1)
        LuminaireEngine.drawEmbersSpec = realSpec
        t:eq("drawEmbers delega em drawEmbersSpec", calls, 1)
    end

    do
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        WorldRoad.update(1 / 30)
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        love.graphics.setCanvas()
        for _ = 1, 40 do
            WeatherEngine.emitDust(0.02, WorldRoad._camZ + 9, 0.6, 0.01, { 0.8, 0.7, 0.5 }, 0.1)
        end
        t:truthy("emitDust respeita o teto (" .. WeatherEngine.dustCount() .. " ≤ 14)",
            WeatherEngine.dustCount() <= 14 and WeatherEngine.dustCount() > 0)
        local P, np = WeatherEngine._particles()
        local inRoad = true
        for i = 1, np do
            if P[i].dust and math.abs(P[i].lx) > 0.2 then inRoad = false end
        end
        t:truthy("poeira fica na faixa da estrada", inRoad)
        for i = 1, 30 * 9 do
            WeatherEngine.update(1 / 30, { biomeId = "fields", camZ = WorldRoad._camZ, time = 7000 + i / 30 })
        end
        t:eq("poeira some sozinha em < 9 s", WeatherEngine.dustCount(), 0)
    end

    local function sceneWith(key, camZ, tod, rm)
        _G.gameSettings = { reducedMotion = rm or false }
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._segBase = 0
        WorldRoad._camZ = camZ
        WorldRoad.setTimeOfDay(tod or 1, true)
        for _ = 1, 10 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        if key then
            WorldRoad._landmark = { key = key, z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
        end
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        WorldRoad.drawOverlays(0, 52, W, H - 52)
        love.graphics.setCanvas()
    end

    do
        local emberCalls = 0
        local realSpec = LuminaireEngine.drawEmbersSpec
        LuminaireEngine.drawEmbersSpec = function(...) emberCalls = emberCalls + 1; return realSpec(...) end
        sceneWith("landmark_rest", 5.5)
        local rest = emberCalls
        emberCalls = 0
        sceneWith("landmark_battle", 5.5)
        local battle = emberCalls
        LuminaireEngine.drawEmbersSpec = realSpec
        t:truthy("fogueira: brasas sobem (" .. rest .. ")", rest >= 1)
        t:eq("bandeira: sem brasas", battle, 0)
    end

    do
        sceneWith("landmark_battle", 5.5, 1, false)
        local kxA = WorldRoad._flagKx
        WorldRoad._time = WorldRoad._time + 0.37
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        love.graphics.setCanvas()
        local kxB = WorldRoad._flagKx
        t:truthy("bandeira: pano cisalha com o vento e muda com o tempo",
            kxA ~= nil and kxB ~= nil and kxA ~= kxB)
        sceneWith("landmark_battle", 5.5, 1, true)
        t:eq("reducedMotion: bandeira parada (kx = 0)", WorldRoad._flagKx, 0)
    end

    do
        sceneWith("landmark_shop", 5.5)
        local glow = false
        for i = 1, LightEngine.queued() do
            local e = LightEngine._entryAt(i)
            if e and e.sy and e.sy < 1 then glow = true end
        end
        t:truthy("loja: brilho das janelas no chão (poça com sy < 1)", glow)
    end

    do
        sceneWith(nil, WorldRoad.TRAVEL_DISTANCE * 8 * 0.1)
        local far = WeatherEngine.stats.lowFogBands
        local qFar = ShadowEngine.stats.queued
        sceneWith(nil, WorldRoad.TRAVEL_DISTANCE * 8 * 0.9)
        local near = WeatherEngine.stats.lowFogBands
        t:truthy("castelo perto: névoa baixa própria (" .. near .. " > " .. far .. ")", near > far)
        t:truthy("castelo: sombra pelo sol na fila do ShadowEngine (" .. ShadowEngine.stats.queued .. ")",
            ShadowEngine.stats.queued >= 1 and qFar >= 1)
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("castelo: as duas elipses fixas saíram",
            src:find("ellipse(\"fill\", cx + shd * iw * s * 0.20", 1, true) ~= nil)
        t:truthy("castelo: ShadowEngine.queue no lugar delas",
            src:find("ShadowEngine.queue(img, cx, crest2 + 2, s, LMG.castleShOpts)", 1, true) ~= nil)
        t:truthy("WorldRoad lê 'landmarks' da tabela para o castelo",
            src:find('Scene.Grade.cfg("landmarks").castle', 1, true) ~= nil)
        t:truthy("WorldRoad emite poeira pela bandeira", src:find("WeatherEngine.emitDust(", 1, true) ~= nil)
        t:truthy("WorldRoad: fumaça fina da fogueira", src:find('lmk.smoke == "thin"', 1, true) ~= nil)
    end

    WorldRoad._landmark = nil
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    _G.gameSettings = savedSettings
    return t:done()
end

return M
```

Registrar em `tools/run_all_tests.lua` depois de `test_contact_shadow`:

```lua
    { group = "unit",  name = "test_landmark_fx" },
```

- [ ] **Passo 2: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_landmark_fx`
Esperado: crash em `LightEngine._lastEntry` (nil) ou `[FAIL]` em cada bloco.

- [ ] **Passo 3: Engines**

**3a. `engine/LightEngine.lua`.** Em `submit` (125-133) acrescentar `sy = spec.sy or 1,` na tabela `entry`. No composite (252-261) ANTES:

```lua
                local sc = (e.r * 2 / S) / ww
                love.graphics.draw(whiteImg, math.floor(e.x / S),
                    math.floor(e.y / S), 0, sc, sc, ww / 2, ww / 2)
```

DEPOIS:

```lua
                local sc = (e.r * 2 / S) / ww
                love.graphics.draw(whiteImg, math.floor(e.x / S),
                    math.floor(e.y / S), 0, sc, sc * (e.sy or 1), ww / 2, ww / 2)
```

E o fallback de micro-sprite logo abaixo (266-268): `sc, sc` → `sc, sc * (e.sy or 1)`. Acessores (antes do `return LightEngine`):

```lua
function LightEngine._lastEntry() return queue[#queue] end
function LightEngine._entryAt(i) return queue[i] end
function LightEngine.queued() return #queue end
```

**3b. `engine/LuminaireEngine.lua` (229-252).** ANTES:

```lua
function LuminaireEngine.drawEmbers(bid, kind, fx, fy, sh, seed)
    local def = LuminaireEngine.def(bid, kind)
    local em = def and def.embers
    if not em or sh < 14 then return end
    local time = love.timer.getTime()
```

DEPOIS:

```lua
function LuminaireEngine.drawEmbersSpec(em, fx, fy, sh, seed)
    if not em or sh < 14 then return end
    local time = love.timer.getTime()
```

(o corpo continua igual até o `love.graphics.setColor(1, 1, 1, 1)` e `end`) e, em seguida:

```lua
function LuminaireEngine.drawEmbers(bid, kind, fx, fy, sh, seed)
    local def = LuminaireEngine.def(bid, kind)
    return LuminaireEngine.drawEmbersSpec(def and def.embers, fx, fy, sh, seed)
end
```

**3c. `engine/ShadowEngine.lua`.** Depois de `local frame = { ... }` (5-10): `ShadowEngine.stats = { queued = 0 }`. Em `setFrame` acrescentar `ShadowEngine.stats.queued = 0`. Em `queue`, depois de `squeueN = squeueN + 1`: `ShadowEngine.stats.queued = squeueN`.

**3d. `engine/WeatherEngine.lua`.** Depois de `local LEAF_SHED = { ... }` (50-51):

```lua
local DUST = { kind = "ash", fall = -0.004, fallVar = 0.4, size = 1.2,
               windK = 0.12, land = 0.3, fg = 0, colors = { { 1, 1, 1 } } }
local MAX_DUST = 14
```

Alpha por partícula: em `beginFrame`, depois de `if (p.retire or 0) > 0 then A = A * max(0, 1 - p.retire / RETIRE_FADE) end` (536):

```lua
        if p.alphaK then A = A * p.alphaK end
```

E no `spawn` (142-151), junto de `p.tint = nil`: `p.alphaK = nil` e `p.dust = false`. Em `emitLeaf` (773-802), depois de `p.shed = true`: `p.dust = false` e `p.alphaK = nil`. Depois de `emitLeaf` inserir:

```lua
function WeatherEngine.emitDust(dxFrac, z, t, hFrac, color, alpha)
    if WeatherEngine.disabled or reduced() or not geo then return end
    local n = 0
    for i = 1, nP do if P[i].dust then n = n + 1 end end
    if n >= MAX_DUST then return end
    nP = nP + 1
    local p = P[nP] or {}
    P[nP] = p
    p.pr = DUST
    p.shed = false
    p.dust = true
    p.age, p.retire = 0, 0
    p.rise, p.ff = false, false
    p.st, p.lt = 0, 0
    p.fg = false
    p.ph = rng:random() * 6.2832
    p.ci = 1
    p.z = z
    p.lx = dxFrac / spread(t)
    p.hg = hFrac
    p.vf = DUST.fall * (0.7 + rng:random() * 0.6)
    p.alphaK = alpha or 0.1
    p.tint = p.tint or {}
    p.tint[1], p.tint[2], p.tint[3] = color[1], color[2], color[3]
    p.sortRel = p.z - (WeatherEngine._sortCamZ or 0)
    local j = nP - 1
    while j >= 1 and (P[j].sortRel or 0) < p.sortRel do
        P[j + 1] = P[j]
        j = j - 1
    end
    P[j + 1] = p
end

function WeatherEngine.dustCount()
    local n = 0
    for i = 1, nP do if P[i].dust then n = n + 1 end end
    return n
end
```

A poeira usa o preset `DUST ≠ cur`, então o laço de `update` já a aposenta em `RETIRE_FADE` (6 s) com fade de alpha; a condição `if p.pr ~= cur and not p.shed then p.retire = ...` cobre o caso (a poeira não é `shed`).

- [ ] **Passo 4: WorldRoad — fumaça fina, pulso, brilho da loja, bandeira, castelo**

**4a. `LMG` (depois de `LMG.tint4 = ...`, Tarefa 1):**

```lua
LMG.castleShOpts = { baseK = 0.12, lenK = 0.30, alphaK = 0.8 }
LMG.LIGHT_SHOP_GLOW = { 1.00, 0.72, 0.38 }
```

**4b. `drawLandmarkSmoke` (1309-1336).** ANTES:

```lua
local function drawLandmarkSmoke(key, px, py, iw, ih, s, alpha)
    local sm = lmCfg(LANDMARK_SMOKE, key)
    if not sm or ih * s < 46 then return end
    local mx = px + (sm.xf - 0.5) * iw * s
    local my = py - ih * s + sm.yf * ih * s
    local rise = ih * s * 0.52
    local cr, cg, cb = 0.80, 0.77, 0.72
    if sm.color then cr, cg, cb = sm.color[1], sm.color[2], sm.color[3] end
    for k = 0, 2 do
        local p = (WorldRoad._time * 0.30 + k * 0.333) % 1
        local a = alpha * 0.40 * math.min(1, p * 5) * (1 - p)
        if a > 0.01 then
            local puffX = mx + math.sin(WorldRoad._time * 0.8 + k * 2.1 + p * 2.6)
                * (0.8 + p * 3.2) * s + p * 2.5 * s
            local puffY = my - p * rise
            local sz = math.max(2, (1.1 + p * 2.8) * s)
```

DEPOIS:

```lua
local function drawLandmarkSmoke(key, px, py, iw, ih, s, alpha, thin)
    local sm = lmCfg(LANDMARK_SMOKE, key)
    local xf, yf, k0 = nil, nil, 1
    if sm then
        xf, yf = sm.xf, sm.yf
    elseif thin then
        local anc = LuminaireEngine.anchor("landmark", key, 0,
            "assets/sprites/world/" .. key .. ".png")
        xf, yf = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.4
        k0 = 0.5
    end
    if not xf or ih * s < 46 * k0 then return end
    local mx = px + (xf - 0.5) * iw * s
    local my = py - ih * s + yf * ih * s
    local rise = ih * s * 0.52 * (thin and 0.8 or 1)
    local cr, cg, cb = 0.80, 0.77, 0.72
    if sm and sm.color then cr, cg, cb = sm.color[1], sm.color[2], sm.color[3] end
    for k = 0, 2 do
        local p = (WorldRoad._time * 0.30 + k * 0.333) % 1
        local a = alpha * 0.40 * k0 * math.min(1, p * 5) * (1 - p)
        if a > 0.01 then
            local puffX = mx + math.sin(WorldRoad._time * 0.8 + k * 2.1 + p * 2.6)
                * (0.8 + p * 3.2) * s + p * 2.5 * s
            local puffY = my - p * rise
            local sz = math.max(2, (1.1 + p * 2.8) * s * k0)
```

(o resto da função fica igual.)

**4c. `submitLandmarkLight` (1338-1364).** ANTES:

```lua
local function submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK)
    local L = lmCfg(LANDMARK_LIGHT, key)
    if not L or not LightEngine.submitMicro then return end
    alphaK = alphaK or 1
    if alphaK <= 0.05 then return end
```

DEPOIS:

```lua
local function submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK, lmk)
    local L = lmCfg(LANDMARK_LIGHT, key)
    if not L or not LightEngine.submitMicro then return end
    alphaK = alphaK or 1
    if alphaK <= 0.05 then return end
    if lmk and (lmk.lanternGlow == false or lmk.runeFlicker == false) then return end
    if lmk and lmk.windowGlow then
        local gx, gy = love.graphics.transformPoint(px, py + 2)
        LightEngine.submit({
            x = gx, y = gy, radius = iw * s * 0.5 * lmk.windowGlow.spread, sy = 0.35,
            color = LMG.LIGHT_SHOP_GLOW, intensity = lmk.windowGlow.alpha * alphaK,
            dither = true, ditherAmt = 0.28, levels = 6, seed = seed, z = rel,
        })
    end
```

E mais abaixo, ANTES:

```lua
    local n = love.math.noise(time * 1.4, sd) * 0.75
        + love.math.noise(time * 4.0, sd + 37.2) * 0.25
    local fxT, fyT = love.graphics.transformPoint(fx, fy)
    local fi = 0.86 + 0.14 * n
```

DEPOIS:

```lua
    local n = love.math.noise(time * 1.4, sd) * 0.75
        + love.math.noise(time * 4.0, sd + 37.2) * 0.25
    if lmk and lmk.runeFlicker then
        n = love.math.noise(time * 0.7, sd) * 0.65
            + love.math.noise(time * 2.1, sd + 53.7) * 0.35
    end
    local fxT, fyT = love.graphics.transformPoint(fx, fy)
    local fi = 0.86 + 0.14 * n
    if lmk and lmk.pulse and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
        fi = fi * (1 + lmk.pulse * math.sin(time * 2.3 + sd))
    end
```

**4d. Fogueira (brasas), bandeira (vento + poeira), chamadas com `lmk` — em `drawForkPhysical`.** O trecho (depois das inserções das Tarefas 2 e 3) fica:

```lua
                local br = hovered and 1.10 or 1
                local lc = Scene.Grade.color("landmark", tM, LMG.c)
                love.graphics.setColor(math.min(1, lc[1] * br), math.min(1, lc[2] * br),
                    math.min(1, lc[3] * br), aMul)
                local kxF = 0
                if lmk and lmk.flagWave and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
                    local wP = GrassField.PRESETS[rawBiome().id]
                    local gw = wP and GrassField.windAt((px - x) / w, camZ + relM, WorldRoad._time, wP, 0) or 0
                    kxF = -gw * 0.035 + math.sin(WorldRoad._time * 2.4 + i) * 0.02
                end
                WorldRoad._flagKx = kxF
                love.graphics.draw(img, math.floor(px), math.floor(py), 0, s, s, iw / 2, ih, kxF, 0)
                drawLandmarkSmoke(key, px, py, iw, ih, s, aMul, lmk and lmk.smoke == "thin")
                submitLandmarkLight(key, px, py, iw, ih, s, relM,
                    i * 31.7, aMul * (hovered and 1.4 or 1), lmk)
                if lmk and lmk.embers and aMul > 0.5 then
                    local anc = LuminaireEngine.anchor("landmark", key, 0,
                        "assets/sprites/world/" .. key .. ".png")
                    local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
                    LuminaireEngine.drawEmbersSpec(LMG.EMBERS, px + (ax - 0.5) * iw * s,
                        py - ih * s * (1 - ay), ih * s, i * 7.7)
                end
                if lmk and lmk.dust and not (_G.gameSettings and _G.gameSettings.reducedMotion)
                   and love.math.random() < lmk.dust.rate / 60 then
                    local ra = envColor("roadA")
                    local halfF = ROAD_HALF * (0.30 + 0.70 * (tM ^ 1.15))
                    WeatherEngine.emitDust((px - g.cx) / w + (love.math.random() - 0.5) * halfF * 1.6,
                        camZ + relM, tM, 0.01,
                        { math.min(1, ra[1] * 1.4), math.min(1, ra[2] * 1.35), math.min(1, ra[3] * 1.2) },
                        lmk.dust.alpha)
                end
```

(substitui o `love.graphics.draw(img, math.floor(px - iw * s / 2), math.floor(py - ih * s), 0, s, s)` e as duas chamadas seguintes de `drawLandmarkSmoke`/`submitLandmarkLight`.) Em `LMG`: `LMG.EMBERS = { color = { 1.00, 0.62, 0.22 }, count = 3 }`.

**4e. O mesmo em `drawChosenLandmark`** (Tarefa 3, dentro de `drawProps`): trocar o bloco

```lua
        local lc = Scene.Grade.color("landmark", t, LMG.c)
        love.graphics.setColor(lc[1], lc[2], lc[3], 1)
        love.graphics.draw(img, math.floor(lx - iw * s / 2), math.floor(py - ih * s), 0, s, s)
        love.graphics.setColor(1, 1, 1, 1)
        drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, 1)
        submitLandmarkLight(lm.key, lx, py, iw, ih, s, rel, lm.z)
```

por:

```lua
        local lc = Scene.Grade.color("landmark", t, LMG.c)
        love.graphics.setColor(lc[1], lc[2], lc[3], 1)
        local kxF = 0
        if lmk and lmk.flagWave and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
            local wP = GrassField.PRESETS[rawBiome().id]
            local gw = wP and GrassField.windAt((lx - x) / w, lm.z, WorldRoad._time, wP, 0) or 0
            kxF = -gw * 0.035 + math.sin(WorldRoad._time * 2.4) * 0.02
        end
        WorldRoad._flagKx = kxF
        love.graphics.draw(img, math.floor(lx), math.floor(py), 0, s, s, iw / 2, ih, kxF, 0)
        love.graphics.setColor(1, 1, 1, 1)
        drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, 1, lmk and lmk.smoke == "thin")
        submitLandmarkLight(lm.key, lx, py, iw, ih, s, rel, lm.z, 1, lmk)
        if lmk and lmk.embers then
            local anc = LuminaireEngine.anchor("landmark", lm.key, 0,
                "assets/sprites/world/" .. lm.key .. ".png")
            local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
            LuminaireEngine.drawEmbersSpec(LMG.EMBERS, lx + (ax - 0.5) * iw * s,
                py - ih * s * (1 - ay), ih * s, lm.z)
        end
        if lmk and lmk.dust and not (_G.gameSettings and _G.gameSettings.reducedMotion)
           and love.math.random() < lmk.dust.rate / 60 then
            local ra = envColor("roadA")
            local halfF = ROAD_HALF * (0.30 + 0.70 * (t ^ 1.15))
            WeatherEngine.emitDust((lx - g.cx) / w + (love.math.random() - 0.5) * halfF * 1.6,
                lm.z, t, 0.01,
                { math.min(1, ra[1] * 1.4), math.min(1, ra[2] * 1.35), math.min(1, ra[3] * 1.2) },
                lmk.dust.alpha)
        end
```

**4f. Castelo (`drawCastleOf`).** ANTES (2084-2095):

```lua
    if alpha >= 1 then
        local ra = envColor("roadA")
        local crest2 = g.crestYAt(cx)
        love.graphics.setColor(ra[1] * 0.92, ra[2] * 0.92, ra[3] * 0.92, 0.85)
        love.graphics.ellipse("fill", cx, crest2 + 2,
            iw * s * 0.34, 5 + 9 * progress)
        local shd = sunShadowDir(g, x, w, cx)
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.ellipse("fill", cx + shd * iw * s * 0.20
            + (shd == 0 and iw * s * 0.10 or 0), crest2 + 3,
            iw * s * 0.28, 4 + 7 * progress)
    end
```

DEPOIS:

```lua
    local lmc = Scene.Grade.cfg("landmarks").castle
    if alpha >= 1 and lmc and lmc.hillShadow then
        local crest2 = g.crestYAt(cx)
        ShadowEngine.queue(img, cx, crest2 + 2, s, LMG.castleShOpts)
    end
```

E logo depois do `love.graphics.draw(img, math.floor(cx - iw * s / 2), math.floor(baseY - ih * s), 0, s, s)` (2098-2099):

```lua
    if alpha >= 1 and lmc and lmc.lowFog and progress > 0.55 then
        WeatherEngine.drawLowFog(cx - iw * s * 0.6, baseY - ih * s * 0.12, iw * s * 1.2,
            ih * s * 0.12 + 4, Scene.Grade.cfg("lowFog"), (progress - 0.55) / 0.45 * 0.8)
    end
```

A sombra do castelo entra na fila do `ShadowEngine` (descarregada depois da grama, em `drawProps`), então cai sobre o capim do topo da colina na direção do sol, no lugar das duas elipses.

- [ ] **Passo 5: Testes, perf, contagem**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_landmark_fx
CARDGAME_HEADLESS=1 lovec . test_one test_world_shadows
CARDGAME_HEADLESS=1 lovec . test_one test_weather
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_contact_shadow
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: verdes; contagem `188`.

- [ ] **Passo 6: Capturas, suíte, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 05_landmarks
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/05_landmarks
cp "$SAVE"/integracao_terreno/05_landmarks/*.png tools/preview_out/integracao_terreno/05_landmarks/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir `b1_por_landmark.png` (fogueira: brasas, fumaça fina, chão pulsando), `b1_por_fork.png` (loja com brilho no chão, bandeira inclinada), `b1_por_castelo.png` (névoa na base do castelo, sombra em vez das elipses).

```bash
git add engine/LightEngine.lua engine/LuminaireEngine.lua engine/WeatherEngine.lua engine/ShadowEngine.lua src/ui/WorldRoad.lua tools/test_landmark_fx.lua tools/run_all_tests.lua tools/preview_out/integracao_terreno/05_landmarks
git commit -m "Landmarks no terreno: brasas, fumaça fina e pulso da fogueira, bandeira ao vento com poeira, brilho da loja no chão, névoa e sombra do castelo pelo sol

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 6: `PropVariation` — tom/escala/espelho/fase por instância e vento em duas amplitudes nas árvores

**Files:**
- Create: `engine/PropVariation.lua`
- Create: `tools/test_prop_variation.lua`
- Modify: `src/ui/WorldRoad.lua` (`local Scene` topo; `drawPropsBehind` 2244-2270; `drawList` 3111-3270: escala/flip/cor/vento do prop e das companheiras, hitbox e oclusor)
- Modify: `tools/run_all_tests.lua` (registrar `test_prop_variation` depois de `test_landmark_fx`)
- Test: `tools/test_prop_variation.lua`

**Interfaces:**
- Consumes: `SceneGrade.cfg("trees") -> { tint, scale, flip, windPhase, canopySway, trunkSway, bushSway }` (Tarefa 1); `GrassField.windAt` (rajada); `PropCut.draw(img, kind, x, y, rot, sx, sy, kx)` (WorldRoad:43).
- Produces:
  - `PropVariation.of(seed, kind, tbl) -> v` (tabela REUTILIZADA: copie os campos antes de chamar de novo) com `v.tintR, v.tintG, v.tintB` (1 ± tint), `v.scale` (1 ± scale), `v.flip` (±1), `v.windPhase` (0..2π), `v.canopy`, `v.trunk` (amplitudes; arbusto usa `bushSway` na copa e 0 no tronco).
  - `PropVariation.sway(v, time, gust, stiff, reduced) -> rot, kx` — `rot` do tronco (rad), `kx` cisalhamento da copa somado à rajada (`-gust × stiff`); `reduced = true` → `0, 0`.
  - WorldRoad: `Scene.Var` (campo novo em `Scene`).

- [ ] **Passo 1: Teste que falha (`tools/test_prop_variation.lua`)**

```lua
local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("PropVariation: variação por instância determinística; vento em duas amplitudes")
    local PV = require("engine.PropVariation")
    local tbl = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.030, trunkSway = 0.010, bushSway = 0.040 }

    local a = PV.of(12.5, "tree", tbl)
    local aR, aS, aF, aP = a.tintR, a.scale, a.flip, a.windPhase
    local b = PV.of(12.5, "tree", tbl)
    t:truthy("mesma semente → mesmos valores", b.tintR == aR and b.scale == aS and b.flip == aF and b.windPhase == aP)
    local c = PV.of(13.7, "tree", tbl)
    t:truthy("semente diferente → valores diferentes", c.tintR ~= aR or c.scale ~= aS or c.windPhase ~= aP)

    local okRange, flips, phases = true, { [1] = 0, [-1] = 0 }, true
    for i = 1, 200 do
        local v = PV.of(i * 0.731, "tree", tbl)
        if v.tintR < 0.95 - 1e-9 or v.tintR > 1.05 + 1e-9 then okRange = false end
        if v.tintG < 0.97 - 1e-9 or v.tintG > 1.03 + 1e-9 then okRange = false end
        if v.scale < 0.92 - 1e-9 or v.scale > 1.08 + 1e-9 then okRange = false end
        if v.windPhase < 0 or v.windPhase >= 6.2832 then phases = false end
        flips[v.flip] = (flips[v.flip] or 0) + 1
    end
    t:truthy("tom em 1 ± tint, escala em 1 ± scale", okRange)
    t:truthy("fase em [0, 2π)", phases)
    t:truthy("espelho sorteia os dois lados (" .. flips[1] .. "/" .. flips[-1] .. ")", flips[1] > 50 and flips[-1] > 50)

    local nf = PV.of(5, "tree", { tint = 0, scale = 0, flip = false, windPhase = false })
    t:truthy("flip=false → sempre 1; windPhase=false → 0; tint/scale 0 → 1",
        nf.flip == 1 and nf.windPhase == 0 and nf.tintR == 1 and nf.scale == 1)

    local tr = PV.of(5, "tree", tbl)
    local trC, trT = tr.canopy, tr.trunk
    local bu = PV.of(5, "bush", tbl)
    t:truthy("árvore: copa 0.030 e tronco 0.010", trC == 0.030 and trT == 0.010)
    t:truthy("arbusto: copa = bushSway e tronco 0", bu.canopy == 0.040 and bu.trunk == 0)

    local v = PV.of(5, "tree", tbl)
    local r0, k0 = PV.sway(v, 10.0, 0, 0.022, false)
    local r1, k1 = PV.sway(v, 10.4, 0, 0.022, false)
    t:truthy("sway muda com o tempo", r0 ~= r1 or k0 ~= k1)
    t:truthy("tronco quase parado (|rot| ≤ trunk)", math.abs(r0) <= 0.010 + 1e-9 and math.abs(r1) <= 0.010 + 1e-9)
    t:truthy("copa balança mais que o tronco (|kx| pode chegar a canopy)", math.abs(k0) <= 0.030 + 1e-9)
    local _, kg = PV.sway(v, 10.0, 1.5, 0.022, false)
    t:truthy("rajada soma no cisalhamento da copa", math.abs(kg - k0 + 1.5 * 0.022) < 1e-9)
    local rr, kr = PV.sway(v, 10.0, 1.5, 0.022, true)
    t:truthy("reducedMotion → sem movimento (0, 0)", rr == 0 and kr == 0)
    local vr = PV.of(12.5, "tree", tbl)
    t:truthy("reducedMotion não mexe na variação (tom/escala/espelho ficam)",
        vr.tintR == aR and vr.scale == aS and vr.flip == aF)

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("WorldRoad sem a rotação fixa antiga (* 0.018)", src:find("* 0.018", 1, true) ~= nil)
        t:truthy("drawList usa Scene.Var.sway", src:find("Scene.Var.sway(pv,", 1, true) ~= nil)
        t:truthy("companheiras com fase própria", src:find("Scene.Var.of(p.z + ci * 17.3", 1, true) ~= nil)
        t:truthy("emersão na crista usa a mesma variação", select(2, src:gsub("Scene%.Var%.of%(p%.z, p%.kind", "")) >= 2)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local W, H = love.graphics.getDimensions()
        local cv = love.graphics.newCanvas(W, H)
        local ok = true
        for bio = 1, 6 do
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(bio)
            WorldRoad._camZ = 5.5
            for _ = 1, 5 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            love.graphics.setCanvas(cv)
            local okD = pcall(WorldRoad.draw, 0, 52, W, H - 52, bio)
            love.graphics.setCanvas()
            ok = ok and okD
        end
        t:truthy("os 6 biomas desenham com variação de árvore", ok)
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    return t:done()
end

return M
```

Registrar em `tools/run_all_tests.lua` depois de `test_landmark_fx`:

```lua
    { group = "unit",  name = "test_prop_variation" },
```

- [ ] **Passo 2: Rodar e ver falhar**

Rodar: `CARDGAME_HEADLESS=1 lovec . test_one test_prop_variation`
Esperado: crash `module 'engine.PropVariation' not found`.

- [ ] **Passo 3: Implementar `engine/PropVariation.lua`**

```lua
local PropVariation = {}

local out = { tintR = 1, tintG = 1, tintB = 1, scale = 1, flip = 1,
              windPhase = 0, canopy = 0, trunk = 0 }

local function hash01(n)
    local v = math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)
end

function PropVariation.of(seed, kind, tbl)
    seed = seed or 0
    tbl = tbl or out
    local h1 = hash01(seed * 1.37 + 0.11)
    local h2 = hash01(seed * 2.19 + 7.3)
    local h3 = hash01(seed * 0.73 + 19.1)
    local h4 = hash01(seed * 3.31 + 2.2)
    local h5 = hash01(seed * 5.07 + 41.9)
    local h6 = hash01(seed * 1.91 + 3.7)
    local tk = tbl.tint or 0
    out.tintR = 1 + (h1 - 0.5) * 2 * tk
    out.tintG = 1 + (h2 - 0.5) * 2 * tk * 0.6
    out.tintB = 1 + (h3 - 0.5) * 2 * tk
    out.scale = 1 + (h4 - 0.5) * 2 * (tbl.scale or 0)
    out.flip = (tbl.flip and h5 < 0.5) and -1 or 1
    out.windPhase = tbl.windPhase and (h6 * 6.2832) % 6.2832 or 0
    if kind == "bush" then
        out.canopy = tbl.bushSway or 0
        out.trunk = 0
    else
        out.canopy = tbl.canopySway or 0
        out.trunk = tbl.trunkSway or 0
    end
    return out
end

function PropVariation.sway(v, time, gust, stiff, reduced)
    if reduced then return 0, 0 end
    local ph = time * 1.15 + (v.windPhase or 0)
    local rot = math.sin(ph) * (v.trunk or 0)
    local kx = math.sin(ph * 1.3 + 0.7) * (v.canopy or 0) - (gust or 0) * (stiff or 0)
    return rot, kx
end

return PropVariation
```

- [ ] **Passo 4: WorldRoad — `Scene.Var` e o bloco do prop em `drawList`**

**4a. Topo:** a tabela `Scene` ganha `Var = require("engine.PropVariation"),`.

**4b. `drawList`**, do `if img then` (3111) até o `PropCut.draw(...)` do prop (3229), com as edições das Tarefas 1 a 3 já aplicadas, fica assim (substituir o trecho inteiro):

```lua
            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, t, ih)
                local isTree = (p.kind == "tree" or p.kind == "pine"
                    or p.kind == "deadtree" or p.kind == "bush")
                local reduced = (_G.gameSettings and _G.gameSettings.reducedMotion) or false
                local vflip, vtR, vtG, vtB = 1, 1, 1, 1
                local pv = nil
                if isTree then
                    pv = Scene.Var.of(p.z, p.kind, Scene.Grade.cfg("trees"))
                    s = s * pv.scale
                    vflip, vtR, vtG, vtB = pv.flip, pv.tintR, pv.tintG, pv.tintB
                    local pvc = LMG.pvCopy
                    pvc.windPhase, pvc.canopy, pvc.trunk = pv.windPhase, pv.canopy, pv.trunk
                    pv = pvc
                end

                local lumDef = LuminaireEngine.def(p.bid, p.kind)
                local lumAnc, lumSink, lumFlip = nil, 0, 1
                if lumDef then
                    lumAnc = LuminaireEngine.anchor(p.bid, p.kind, p.variant,
                        luminairePath(p.bid, p.kind, p.variant))
                    if lumDef.face and lumDef.face ~= 0 then
                        local want = p.side < 0 and 1 or -1
                        lumFlip = (want == lumDef.face) and 1 or -1
                    end
                    pxX = pxX - (lumAnc.offX or 0) * s * lumFlip
                    lumSink = (lumAnc.footPad or 0) * s
                    local fr = luminaireFrames(p.bid, p.kind, p.variant)
                    if fr then
                        local ph = (p.z * 7.31) % #fr
                        img = fr[1 + math.floor(
                            (WorldRoad._time * 10 + ph) % #fr)]
                        iw, ih = img:getWidth(), img:getHeight()
                    end
                end

                local _, ihv = PropCut.get(img, p.kind)
                local gw = 0
                if isTree and not reduced then
                    local wP = GrassField.PRESETS[p.bid or rawBiome().id]
                    if wP then
                        gw = GrassField.windAt((pxX - x) / w, p.z, WorldRoad._time, wP, 0)
                        if gw * gw > 1.6 and p.kind ~= "deadtree" and t > 0.25
                           and WorldRoad._rng:random() < 0.035 then
                            local gA = envColor("grassA")
                            WeatherEngine.emitLeaf((pxX - g.cx) / w
                                + (WorldRoad._rng:random() - 0.5) * iw * s * 0.5 / w,
                                p.z, t, ih * s * 0.62 / (g.persp(t) * g.h),
                                { math.min(1, gA[1] * 1.35), math.min(1, gA[2] * 1.3),
                                  math.min(1, gA[3] * 1.1) })
                        end
                    end
                end
                local stiff = (p.kind == "bush") and 0.030
                    or (p.kind == "deadtree" and 0.014 or 0.022)

                if p.cluster and isTree then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cx2 = pxX + off
                        local cy2 = g.latY(cx2 - g.cx, t)
                        local cvar = (p.variant + ci) % 3
                        local cimg = getSprite(p.kind, cvar, p.bid)
                        if cimg then
                            local cvv = Scene.Var.of(p.z + ci * 17.3, p.kind, Scene.Grade.cfg("trees"))
                            local cs = s * (0.5 + 0.13 * ci) * cvv.scale
                            local cflip = cvv.flip
                            local crot, ckx = Scene.Var.sway(cvv, WorldRoad._time, gw, stiff, reduced)
                            ShadowEngine.queue(cimg, cx2, cy2 - 1, cs,
                                shadowOpts(0.8 * fadeA, cflip,
                                    PropCut.cutOf(cimg, p.kind),
                                    WorldRoad.SHADOW_PROFILE[p.kind]))
                            Scene.Contact.queue(cimg, cx2, cy2, cs, t, 0.8 * fadeA, cflip)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), t, LMG.c)
                            love.graphics.setColor(math.min(1, cc[1] * 0.88 * cvv.tintR),
                                math.min(1, cc[2] * 0.88 * cvv.tintG),
                                math.min(1, cc[3] * 0.88 * cvv.tintB), fadeA)
                            PropCut.draw(cimg, p.kind, math.floor(cx2),
                                math.floor(cy2), crot, cs * cflip, cs, ckx * cflip)
                        end
                    end
                end

                if p.kind == "fence" then
                    for fi = 1, (t >= 0.35 and 2 or 0) do
                        local fz = p.z + fi * 1.7
                        local ft = g.tOf(fz - camZ)
                        if ft and ft >= 0 then
                            local flat = p.side * w
                                * ((0.11 + 0.38 * ft) + p.lane * 0.38)
                            local fx = g.cx + flat
                            local fy = g.latY(fx - g.cx, ft)
                            local fs = g.scaleAt((KIND_SIZE.fence or 1) * (p.big or 1), ft, ih)
                            ShadowEngine.queue(img, fx, fy - 1, fs,
                                shadowOpts(0.85 * fadeA))
                            Scene.Contact.queue(img, fx, fy, fs, ft, 0.85 * fadeA, 1)
                            local fc = Scene.Grade.color("prop", ft, LMG.c)
                            love.graphics.setColor(fc[1] * 0.94, fc[2] * 0.94, fc[3] * 0.94, fadeA)
                            love.graphics.draw(img, math.floor(fx), math.floor(fy),
                                0, fs, fs, iw / 2, ih)
                        end
                    end
                end

                local aFade = math.min(1, 0.72 + t * 1.1)
                if not ShadowEngine.queue(img, pxX, sy - 1, s,
                    shadowOpts(aFade * fadeA, lumFlip * vflip,
                        lumAnc and lumAnc.footPad or PropCut.cutOf(img, p.kind),
                        WorldRoad.SHADOW_PROFILE[p.kind])) then
                    local shd = sunShadowDir(g, x, w, pxX)
                    love.graphics.setColor(0, 0, 0, 0.20 * aFade * fadeA)
                    love.graphics.ellipse("fill",
                        pxX + shd * iw * s * 0.16, sy - 1,
                        iw * s * 0.24, math.max(2, 4 * g.persp(t)))
                end
                if p.kind ~= "tuft" and p.kind ~= "flowers" then
                    Scene.Contact.queue(img, pxX, sy, s, t, fadeA, lumFlip * vflip)
                end

                local rot = 0
                local gustKx = 0
                local sink2 = lumSink
                if pv then
                    rot, gustKx = Scene.Var.sway(pv, WorldRoad._time, gw, stiff, reduced)
                elseif p.kind == "tuft" or p.kind == "flowers" then
                    rot = math.sin(WorldRoad._time * 2.3 + p.z * 1.4) * 0.055
                end
                rot = rot + pokeRot(p)

                local pc = Scene.Grade.color(Scene.Grade.familyOf(p.kind, lumDef ~= nil), t, LMG.c)
                love.graphics.setColor(math.min(1, pc[1] * vtR), math.min(1, pc[2] * vtG),
                    math.min(1, pc[3] * vtB), fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip * vflip, s, gustKx * lumFlip * vflip)
```

**4c. `LMG.pvCopy`:** a tabela devolvida por `Scene.Var.of` é REUTILIZADA a cada chamada; as companheiras chamam `of` entre o `of` do prop principal e o `sway` dele. Por isso o bloco acima copia `windPhase/canopy/trunk` para `LMG.pvCopy` e o `sway` do principal lê a cópia. Em `LMG` (junto de `LMG.c = {}`): `LMG.pvCopy = { windPhase = 0, canopy = 0, trunk = 0 }`.

**4d. Hitbox e oclusor (3231-3270, já editados na Tarefa 1):** `local flip = lumFlip or 1` → `local flip = (lumFlip or 1) * vflip`; no oclusor `oc.sx, oc.sy, oc.ox, oc.oy = s, s, iw / 2, ihv` → `oc.sx, oc.sy, oc.ox, oc.oy = s * vflip, s, iw / 2, ihv`.

**4e. `drawPropsBehind` (2244-2270), emersão com a mesma variação.** ANTES:

```lua
            if crest and img and math.abs(pxX - g.cx) < w * 0.26 then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, 0, ih)
                local _, ihv = PropCut.get(img, p.kind)
                local sink = (1 - em) * ihv * s
                if p.cluster then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cimg = getSprite(p.kind, (p.variant + ci) % 3, p.bid)
                        if cimg then
                            local cs = s * (0.5 + 0.13 * ci)
                            local ccrest = g.crestYAt(pxX + off) or crest
                            local _, cihv = PropCut.get(cimg, p.kind)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                            love.graphics.setColor(cc[1] * 0.6, cc[2] * 0.6, cc[3] * 0.6, fadeA)
                            PropCut.draw(cimg, p.kind, math.floor(pxX + off),
                                math.floor(ccrest + (1 - em) * cihv * cs), 0, cs, cs)
                        end
                    end
                end
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                love.graphics.setColor(cb[1] * 0.66, cb[2] * 0.66, cb[3] * 0.66, fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX),
                    math.floor(crest + sink), 0, s, s)
            end
```

DEPOIS:

```lua
            if crest and img and math.abs(pxX - g.cx) < w * 0.26 then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, 0, ih)
                local isTree = (p.kind == "tree" or p.kind == "pine"
                    or p.kind == "deadtree" or p.kind == "bush")
                local vflip, vtR, vtG, vtB = 1, 1, 1, 1
                if isTree then
                    local pv = Scene.Var.of(p.z, p.kind, Scene.Grade.cfg("trees"))
                    s = s * pv.scale
                    vflip, vtR, vtG, vtB = pv.flip, pv.tintR, pv.tintG, pv.tintB
                end
                local _, ihv = PropCut.get(img, p.kind)
                local sink = (1 - em) * ihv * s
                if p.cluster and isTree then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cimg = getSprite(p.kind, (p.variant + ci) % 3, p.bid)
                        if cimg then
                            local cvv = Scene.Var.of(p.z + ci * 17.3, p.kind, Scene.Grade.cfg("trees"))
                            local cs = s * (0.5 + 0.13 * ci) * cvv.scale
                            local ccrest = g.crestYAt(pxX + off) or crest
                            local _, cihv = PropCut.get(cimg, p.kind)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                            love.graphics.setColor(math.min(1, cc[1] * 0.6 * cvv.tintR),
                                math.min(1, cc[2] * 0.6 * cvv.tintG),
                                math.min(1, cc[3] * 0.6 * cvv.tintB), fadeA)
                            PropCut.draw(cimg, p.kind, math.floor(pxX + off),
                                math.floor(ccrest + (1 - em) * cihv * cs), 0, cs * cvv.flip, cs)
                        end
                    end
                end
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                love.graphics.setColor(math.min(1, cb[1] * 0.66 * vtR), math.min(1, cb[2] * 0.66 * vtG),
                    math.min(1, cb[3] * 0.66 * vtB), fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX),
                    math.floor(crest + sink), 0, s * vflip, s)
            end
```

(No original o `p.cluster` da emersão não exigia `isTree`; aqui exige, igual ao `drawList`. `p.cluster` só é sorteado para tree/pine/deadtree/bush em `rollProp`, então nada muda.)

- [ ] **Passo 5: Testes, perf, contagem**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_prop_variation
CARDGAME_HEADLESS=1 lovec . test_one test_world_props
CARDGAME_HEADLESS=1 lovec . test_one test_world_shadows
CARDGAME_HEADLESS=1 lovec . test_one test_perf_budget
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one test_contact_shadow
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: verdes; contagem `188`; KB/frame do `test_perf_budget` inalterado (`of` e `sway` não alocam).

- [ ] **Passo 6: Capturas, suíte, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 06_prop_variation
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/06_prop_variation
cp "$SAVE"/integracao_terreno/06_prop_variation/*.png tools/preview_out/integracao_terreno/06_prop_variation/
CARDGAME_HEADLESS=1 lovec . test_all
```

Abrir `b1_dia_fork.png`: a parede de árvores deixa de repetir a mesma silhueta (espelhos, tamanhos e tons diferentes); comparar com `05_landmarks/b1_dia_fork.png`.

```bash
git add engine/PropVariation.lua tools/test_prop_variation.lua tools/run_all_tests.lua src/ui/WorldRoad.lua tools/preview_out/integracao_terreno/06_prop_variation
git commit -m "PropVariation: tom, escala, espelho e fase de vento por instância; copa e tronco com amplitudes próprias; companheiras balançam

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 7: Calibrar o bioma 2 (`highlands`, Colinas da Torre)

**Files:**
- Modify: `src/data/scene_integration.lua` (entrada `highlands`)
- Create: `tools/preview_out/integracao_terreno/07_highlands_antes/` e `.../07_highlands_depois/` (12 PNGs cada)
- Test: `tools/test_scene_grade.lua` (limites da tabela, já cobre todo bioma)

**Interfaces:**
- Consumes: `tools/screenshot_integracao_terreno.lua` com sufixo `:2` (Tarefa 1); `SceneGrade` lendo `DATA.highlands` (Tarefa 1); tudo das Tarefas 2 a 6 já ligado.
- Produces: a linha `highlands` da tabela calibrada por captura.

- [ ] **Passo 1: Capturar o bioma com os valores derivados (antes)**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 07_highlands_antes:2
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/07_highlands_antes
cp "$SAVE"/integracao_terreno/07_highlands_antes/*.png tools/preview_out/integracao_terreno/07_highlands_antes/
```

- [ ] **Passo 2: Julgar as 12 capturas (Read em cada PNG) com a lista fixa**

Para `b2_{dia,meio,por}_{fork,landmark,viagem,castelo}.png`, anotar sim/não:
1. O chão, as árvores e o marco têm a MESMA temperatura (lua fria azul-violeta; nada amarelado sobrando no marco ou no inimigo).
2. O horizonte é mais lavado e menos saturado que a base, sem degrau visível entre fatias do véu.
3. A faixa de contato lê como sombra, não como contorno preto (se parecer contorno: `contact.alpha` −0,1).
4. Os tufos cobrem a base sem esconder a arte (se esconderem: `occlusion.baseCover` −0,02).
5. A névoa baixa na base das montanhas aparece no pôr do sol e não vira muro branco (se virar: `lowFog.alpha` −0,06).
6. As árvores da parede não repetem silhueta e o vento é visível sem ficar frenético (se frenético: `trees.canopySway` −0,008).
7. À noite nada clareia além da arte (sem halo, sem lift).

- [ ] **Passo 3: Ajustar a entrada `highlands`**

Editar só os números da entrada `highlands` em `src/data/scene_integration.lua` conforme os itens reprovados no Passo 2, dentro dos limites travados por `test_scene_grade` (`satFar < satNear ≤ 1`, `contrastFar` em [0.4, 1], `fogFar ≤ 0.6`, `contact.height ≤ 0.08`, `tuftsMin ≤ tuftsMax`). Se tudo passou no Passo 2, nenhuma mudança: registre isso na mensagem de commit.

- [ ] **Passo 4: Trava e captura depois**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 07_highlands_depois:2
mkdir -p tools/preview_out/integracao_terreno/07_highlands_depois
cp "$SAVE"/integracao_terreno/07_highlands_depois/*.png tools/preview_out/integracao_terreno/07_highlands_depois/
```

Esperado: `== ALL GREEN ==`; reler os PNGs reprovados no Passo 2 e confirmar que passaram.

- [ ] **Passo 5: Suíte e commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_all
git add src/data/scene_integration.lua tools/preview_out/integracao_terreno/07_highlands_antes tools/preview_out/integracao_terreno/07_highlands_depois
git commit -m "Integração do terreno: calibração das Colinas da Torre (highlands) pela grade de capturas

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 8: Calibrar o bioma 3 (`abyss`, Estrada do Abismo)

**Files:**
- Modify: `src/data/scene_integration.lua` (entrada `abyss`)
- Create: `tools/preview_out/integracao_terreno/08_abyss_antes/` e `.../08_abyss_depois/`
- Test: `tools/test_scene_grade.lua`

**Interfaces:**
- Consumes: `tools/screenshot_integracao_terreno.lua` com sufixo `:3`; `SceneGrade` lendo `DATA.abyss`.
- Produces: a linha `abyss` calibrada.

- [ ] **Passo 1: Capturar antes**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 08_abyss_antes:3
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/08_abyss_antes
cp "$SAVE"/integracao_terreno/08_abyss_antes/*.png tools/preview_out/integracao_terreno/08_abyss_antes/
```

- [ ] **Passo 2: Julgar `b3_*.png` com a lista fixa**

1. Temperatura única (brasa vermelha; o pôr do sol NÃO vira roxo: `grade.dusk` precisa continuar quente).
2. Horizonte lavado pela névoa VERMELHA fina (`fog` do abismo), sem degrau.
3. Faixa de contato lê como sombra sobre chão escuro (se sumir: `contact.alpha` +0,05).
4. Tufos escassos (abismo é árido): `tuftsMax ≤ 4`.
5. Névoa baixa de cinza fraca e móvel (`lowFog.alpha ≤ 0.18`).
6. Árvores mortas quase paradas (`canopySway ≤ 0.018`), só espelho/tom/escala variando.
7. Terra queimada da fogueira mais forte que nos campos (`scorch.alpha ≥ 0.55`), brasas visíveis.

- [ ] **Passo 3: Ajustar a entrada `abyss`** (mesmos limites do `test_scene_grade`; sem reprovação = sem mudança).

- [ ] **Passo 4: Trava e captura depois**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 08_abyss_depois:3
mkdir -p tools/preview_out/integracao_terreno/08_abyss_depois
cp "$SAVE"/integracao_terreno/08_abyss_depois/*.png tools/preview_out/integracao_terreno/08_abyss_depois/
```

- [ ] **Passo 5: Suíte e commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_all
git add src/data/scene_integration.lua tools/preview_out/integracao_terreno/08_abyss_antes tools/preview_out/integracao_terreno/08_abyss_depois
git commit -m "Integração do terreno: calibração da Estrada do Abismo (abyss) pela grade de capturas

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 9: Calibrar o bioma 4 (`frost`, Geleira Espectral)

**Files:**
- Modify: `src/data/scene_integration.lua` (entrada `frost`)
- Create: `tools/preview_out/integracao_terreno/09_frost_antes/` e `.../09_frost_depois/`
- Test: `tools/test_scene_grade.lua`

**Interfaces:**
- Consumes: `tools/screenshot_integracao_terreno.lua` com sufixo `:4`; `SceneGrade` lendo `DATA.frost`.
- Produces: a linha `frost` calibrada.

- [ ] **Passo 1: Capturar antes**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 09_frost_antes:4
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/09_frost_antes
cp "$SAVE"/integracao_terreno/09_frost_antes/*.png tools/preview_out/integracao_terreno/09_frost_antes/
```

- [ ] **Passo 2: Julgar `b4_*.png` com a lista fixa**

1. Temperatura única fria; a neve continua a coisa mais clara da cena (o grade nunca passa de 1).
2. Horizonte muito lavado (geleira é o bioma de mais névoa: `fogFar` pode ir a 0,6) sem degrau.
3. Faixa de contato azulada e suave (`contact.alpha ≤ 0.5`): sombra preta na neve lê como buraco.
4. Tufos baixos e raros (`baseCover ≤ 0.08`).
5. Névoa baixa é a mais presente dos seis (`lowFog.alpha` 0,28 a 0,34) e quase parada (`drift ≤ 0.012`).
6. Pinheiros com pouco vento (`canopySway ≤ 0.028`).
7. A névoa de intenção do ato 4 (`fogHook`) continua mandando: na captura `viagem` o véu da névoa de intenção não some nem dobra.

- [ ] **Passo 3: Ajustar a entrada `frost`** (limites do `test_scene_grade`; sem reprovação = sem mudança).

- [ ] **Passo 4: Trava e captura depois**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one test_weather
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 09_frost_depois:4
mkdir -p tools/preview_out/integracao_terreno/09_frost_depois
cp "$SAVE"/integracao_terreno/09_frost_depois/*.png tools/preview_out/integracao_terreno/09_frost_depois/
```

- [ ] **Passo 5: Suíte e commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_all
git add src/data/scene_integration.lua tools/preview_out/integracao_terreno/09_frost_antes tools/preview_out/integracao_terreno/09_frost_depois
git commit -m "Integração do terreno: calibração da Geleira Espectral (frost) pela grade de capturas

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 10: Calibrar o bioma 5 (`marsh`, Pântano da Podridão)

**Files:**
- Modify: `src/data/scene_integration.lua` (entrada `marsh`)
- Create: `tools/preview_out/integracao_terreno/10_marsh_antes/` e `.../10_marsh_depois/`
- Test: `tools/test_scene_grade.lua`

**Interfaces:**
- Consumes: `tools/screenshot_integracao_terreno.lua` com sufixo `:5`; `SceneGrade` lendo `DATA.marsh`.
- Produces: a linha `marsh` calibrada.

- [ ] **Passo 1: Capturar antes**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 10_marsh_antes:5
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/10_marsh_antes
cp "$SAVE"/integracao_terreno/10_marsh_antes/*.png tools/preview_out/integracao_terreno/10_marsh_antes/
```

- [ ] **Passo 2: Julgar `b5_*.png` com a lista fixa**

1. Temperatura única esverdeada; a lanterna verde-bruxaria continua contrastando com o chão.
2. Horizonte lavado pela névoa verde-oliva, sem degrau.
3. Faixa de contato esverdeada-escura (`shadowTint` verde), não preta.
4. Tufos são os mais densos e altos dos seis (`baseCover` 0,12 a 0,15, `tuftsMax` 7), cobrindo a base da cabana e das pedras.
5. Névoa baixa espessa e lenta (`lowFog.alpha` 0,26 a 0,32).
6. Arbustos balançam mais que as árvores mortas (`bushSway ≥ 0.045`, `canopySway ≤ 0.03`).
7. A chuva fina continua lendo contra o chão (o véu de profundidade não a apaga: se apagar, `fogFar` −0,05).

- [ ] **Passo 3: Ajustar a entrada `marsh`** (limites do `test_scene_grade`; sem reprovação = sem mudança).

- [ ] **Passo 4: Trava e captura depois**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 10_marsh_depois:5
mkdir -p tools/preview_out/integracao_terreno/10_marsh_depois
cp "$SAVE"/integracao_terreno/10_marsh_depois/*.png tools/preview_out/integracao_terreno/10_marsh_depois/
```

- [ ] **Passo 5: Suíte e commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_all
git add src/data/scene_integration.lua tools/preview_out/integracao_terreno/10_marsh_antes tools/preview_out/integracao_terreno/10_marsh_depois
git commit -m "Integração do terreno: calibração do Pântano da Podridão (marsh) pela grade de capturas

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Tarefa 11: Calibrar o bioma 6 (`dusk`, Campos do Crepúsculo)

**Files:**
- Modify: `src/data/scene_integration.lua` (entrada `dusk`)
- Create: `tools/preview_out/integracao_terreno/11_dusk_antes/` e `.../11_dusk_depois/`
- Test: `tools/test_scene_grade.lua`

**Interfaces:**
- Consumes: `tools/screenshot_integracao_terreno.lua` com sufixo `:6`; `SceneGrade` lendo `DATA.dusk`.
- Produces: a linha `dusk` calibrada.

- [ ] **Passo 1: Capturar antes**

```bash
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 11_dusk_antes:6
SAVE=$(ls -d "$LOCALAPPDATA"/LOVE/card-game* "$APPDATA"/LOVE/card-game* 2>/dev/null | head -1)
mkdir -p tools/preview_out/integracao_terreno/11_dusk_antes
cp "$SAVE"/integracao_terreno/11_dusk_antes/*.png tools/preview_out/integracao_terreno/11_dusk_antes/
```

- [ ] **Passo 2: Julgar `b6_*.png` com a lista fixa**

1. Temperatura: dia âmbar quente → pôr do sol púrpura (`grade.dusk` roxo), sem esverdear o chão rosado.
2. Horizonte alaranjado pela névoa quente, sem degrau.
3. Faixa de contato púrpura-escura (`shadowTint`), coerente com as sombras longas do sol baixo (`ShadowEngine` já alonga em tod 1).
4. Tufos médios (como os campos: `baseCover` 0,10).
5. Névoa baixa dourada e leve (`lowFog.alpha ≤ 0.22`).
6. Árvores com o vento mais vivo dos seis (`canopySway` 0,034 a 0,040), folhas do clima acompanhando.
7. A névoa de intenção do ato 6 (`fogHook`) continua mandando na captura `viagem`.

- [ ] **Passo 3: Ajustar a entrada `dusk`** (limites do `test_scene_grade`; sem reprovação = sem mudança).

- [ ] **Passo 4: Trava e captura depois**

```bash
CARDGAME_HEADLESS=1 lovec . test_one test_scene_grade
CARDGAME_HEADLESS=1 lovec . test_one test_weather
CARDGAME_HEADLESS=1 lovec . test_one screenshot_integracao_terreno 11_dusk_depois:6
mkdir -p tools/preview_out/integracao_terreno/11_dusk_depois
cp "$SAVE"/integracao_terreno/11_dusk_depois/*.png tools/preview_out/integracao_terreno/11_dusk_depois/
```

- [ ] **Passo 5: Suíte, perf nos seis biomas, memória, commit**

```bash
CARDGAME_HEADLESS=1 lovec . test_all
CARDGAME_HEADLESS=1 lovec . test_one perf_probe 1920x1080:phases
python tools/count_locals.py src/ui/WorldRoad.lua
```

Esperado: suíte verde; `perf_probe` com mediana ≤ 5 ms em 1080p e draw calls ≤ 520 (meta da spec); contagem `188`. Registrar em `memory/worldroad_scene.md` (seção nova "Integração ao terreno (Out/2026)") os módulos novos (`SceneGrade`, `ContactShadow`, `PropVariation`, `GrassField.requireTufts`, névoa em camadas), a tabela `src/data/scene_integration.lua`, as travas (`test_scene_grade`, `test_contact_shadow`, `test_landmark_fx`, `test_prop_variation`, extensões de `test_world_props`/`test_weather`), a ferramenta `screenshot_integracao_terreno` e a decisão "montanha sem temperatura, só profundidade". Atualizar a linha do `GrassField`/`WeatherEngine`/`LightEngine`/`LuminaireEngine` no `CLAUDE.md` §2 (engine/) com os três módulos novos.

```bash
git add src/data/scene_integration.lua tools/preview_out/integracao_terreno/11_dusk_antes tools/preview_out/integracao_terreno/11_dusk_depois memory/worldroad_scene.md CLAUDE.md
git commit -m "Integração do terreno: calibração dos Campos do Crepúsculo (dusk); memória e CLAUDE.md com os módulos novos

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Decisões e desvios em relação à spec (para quem executa)

1. **`LuminaireEngine.contentScan` não existe** (spec §2.3). O que existe é `LuminaireEngine._scanImage` (âncora da chama + footPad) e `scanContentRect` dentro do WorldRoad. A pegada ganhou varredura própria em `ContactShadow.scan(img, data)`, chamada nos três pontos que já decodificam o PNG (`tryLoadPng`, `readAnimFrames`, `toImage`), dentro do pré-aquecimento. Nenhum decode a mais.
2. **`ContactShadow.queue` é posicional** (`img, x, y, s, t, alpha, flip`) em vez de `opts` tabela: a fila é pooled e lê a pegada pela imagem; evita uma tabela por prop por quadro (`test_perf_budget`: KB/frame).
3. **`SceneGrade.color` é multiplicador de `setColor`**, então "contraste por profundidade" vira brilho ao horizonte (`contrastFar` substitui o `aFade` antigo de 0,72) e "dessaturação" vira mistura com a luminância do próprio multiplicador. O lightmap continua multiplicando o ambiente por cima; `color` NÃO multiplica o ambiente (senão dobraria o escurecimento).
4. **Montanhas sem temperatura** (spec §5 × §2.2): família `mountain` recebe só névoa e contraste (`NO_TEMP`), trava em `test_scene_grade`.
5. **Névoa baixa das montanhas entra ANTES do raio** (entre `drawClouds` e `WeatherEngine.drawSky`), porque a trava antiga do `test_weather` exige `drawSky` colado em `drawMountainsFront`. O castelo distante recebe a névoa própria dele (Tarefa 5), não a das montanhas.
6. **Véu de profundidade = um retângulo plano por fatia** (2 draw calls por flush com partículas): mais barato que ruído por fatia e fica dentro de 600 draw calls. Se o degrau entre fatias ficar visível no pôr do sol, baixar `VEIL_K`.
7. **Poeira da bandeira sorteia no RNG global** (`love.math.random`), nunca em `WorldRoad._rng` (a população dos props mudaria com o cosmético) nem no `Rng` da run.
8. **Contagem de locais do WorldRoad**: 198 → 197 (T1) → 193 (T2) → 188 (T3), sem subir depois. Toda tabela nova de saída/pool é campo de `LMG`, `WorldRoad._pools`, `WorldRoad._lists` ou `Scene`.
