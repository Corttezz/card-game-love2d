# WorldRoad Visual v6 — do protótipo à cena rica

> **STATUS (Jul/06/2026): CONCLUÍDO — v6.1 a v6.8 entregues** (commits
> d1a009f → 1f638d1 + docs). Escopo executado com adaptações descobertas
> em campo, anotadas por passo abaixo. Detalhe completo em
> `memory/worldroad_scene.md` (seção "v6 — Overhaul visual").
>
> - Passo 1 → ✅ re-escopado (v6.1): drawSky/drawCelestial são INVISÍVEIS
>   (strip cover cobre o céu) — virou suavização de banding do que aparece
>   (vinhetas + névoa em gradiente contínuo via gradTex).
> - Passo 2 → ✅ v6.2 (haze atmosférico sobre a crista).
> - Passo 3 → ✅ v6.3 (sunShadowDir em todas as sombras + rim light do
>   castelo).
> - Passo 4 → ✅ parcial v6.4: glows aditivos das janelas/portão via
>   glowTex + CASTLE_GLOW_K (canvas multiply completo ficou no backlog —
>   custo/risco > ganho pro estado atual).
> - Passo 5 → ✅ parcial v6.5: dither estrada↔grama + grama multi-tom +
>   banda de luz na crista (sombra de nuvem FBM DESCARTADA — regra do
>   ciclo 26: nuvem distante não projeta sombra no primeiro plano).
> - Passo 6 → ✅ v6.6: god rays com RAY_K por bioma + fumaça suave + room
>   sway Balatro (partículas por bioma já existiam dos ciclos 1-12).
> - Passo 7 → ✅ v6.7: framing de árvores nos cantos + state grade
>   (vinheta via gradTex ficou no passo 1; palette snap descartado).
> - Passo 8 → ✅ v6.8: full1-6 + travel/fork/blend6 revisados, docs
>   sincronizados.
>
> Backlog remanescente: canvas de luz multiply, moonshine/flux/anim8
> vendorizados, tileset Wang estrada↔grama, lanterna/props animados.

Objetivo: tirar a "cara de protótipo" da cena de mundo (WorldRoad) e aproximá-la
da referência (cena pixel-art rica: vegetação densa, iluminação quente
localizada, props detalhados, profundidade atmosférica, moldura escura).

Base de pesquisa (Jul/2026):
- **Source completo do Balatro em `E:\dev\projects\balatro-source\`** —
  técnicas mapeadas: background.fs swirl 3-cores (resources/shaders/background.fs:18-51,
  game.lua:2282-2306), ease_background_colour por estado (functions/common_events.lua:276-360),
  room sway/canvas juice (common_events.lua:1127-1154), partículas attach
  (engine/particles.lua), sombra com parallax (engine/moveable.lua:461,
  engine/sprite.lua:73-122), cores globais pulsantes (game.lua:2500-2506),
  CRT como cola visual (game.lua:2732-2952).
- **Fóruns/devlogs LÖVE2D**: perspectiva atmosférica em camadas (SLYNYRD
  pixelblog 23; razões de parallax 10-130%), canvas de luz add→multiply sem
  stencil (love2d.org t=83942, t=84407), dithering Bayer 8×8 pra matar banding
  (anisopteragames.com), contact shadows + rim light (xDasher devlog),
  sombra de nuvem por FBM, wind sway por shader (topo balança/raiz fixa),
  moonshine como referência de grade/vinheta/glow.

Diagnóstico do pipeline atual (src/ui/WorldRoad.lua:2252-2366):
céu = cor chapada em bandas de 8px; domo = círculo chapado + textura
pontilhista + arco de linha como "luz"; sem modelo de luz global (sombras =
elipses fixas, tints cinza hardcoded); bordas da estrada = rects com hash;
névoa/halos/vinhetas = faixas de retângulo com banding; fumaça = quadrados.

Restrições INEGOCIÁVEIS:
- `love.graphics.stencil` PROIBIDO (crash driver NVIDIA). Oclusão/máscara só
  por blend modes, camadas ou alpha de textura.
- Validação SEMPRE via `lovec E:\dev\projects\card-game-love2d screenshot_worldroad wide_full<N>`
  nos 6 biomas + análise das capturas (salvas em %APPDATA%\LOVE\card-game\).
- Shaders em sintaxe LÖVE 11.x (`effect()`), aplicados no canvas lógico
  (nearest), não na janela. `luac -p` antes de rodar. 60fps.
- Nunca matar processos por nome; não abrir janelas enquanto o usuário joga.
- Strings/comentários em PT-BR. Commit por passo concluído.

---

## Passo 1 — Céu vivo (gradiente + dithering + astro com glow)

Substituir `drawSky` (bandas chapadas de 8px) por gradiente vertical rico:
2-3 cores por bioma (zênite→horizonte, com banda quente no horizonte),
quantizado com dithering ordenado Bayer 8×8 (matriz gerada em Lua via
ImageData, shader de 1 lookup). Sol/lua: substituir os 2 anéis duros por
halo com falloff suave (quads aditivos concêntricos com alpha decrescente).
Opcional se couber: drift lentíssimo de 3ª cor inspirado no background.fs
do Balatro (paleta do bioma, spin_amount≈0).
Aceitação: capturas dos 6 biomas sem banding no céu; halo do sol/lua sem
anel duro; paleta por bioma preservada no crossfade.

## Passo 2 — Perspectiva atmosférica + parallax calibrado

Cada camada de fundo (strip de montanha, espelho, treeline, clusters de
props distantes) recebe tint interpolado pra cor do céu proporcional à
profundidade (lerp cor→céu por depth). Substituir a banda de névoa em rects
(2278-2287) e o crest fog por gradientes suaves (mesh ou quads com vértices
alpha). Calibrar razões de parallax por camada (céu ~15%, montanhas 25-40%,
meia-distância 50%, chão 100%) na taxa angular do camZ.
Aceitação: 3+ planos de profundidade distinguíveis nas capturas; zero
banding de névoa; montanhas visivelmente mais "distantes" que hoje.

## Passo 3 — Modelo de luz global + sombras coerentes

Direção de sol por bioma (derivada da posição do celestial). Contact shadow
padronizada (elipse alpha 0.25-0.35, largura ~0.7× sprite, achatada 3:1)
sob TODOS os props, castelo, marcos e inimigo. Sombra direcional nos props
grandes: sprite re-desenhado achatado/deslocado na direção oposta ao sol
(padrão Balatro moveable.lua:461/sprite.lua:73-122), alpha baixo. Rim light
barato no castelo e no inimigo emergindo (shader de borda: vizinho na
direção da luz com alpha 0 → mistura cor do sol).
Aceitação: nos 6 biomas as sombras apontam consistentemente contra o sol;
nenhum prop "flutuando"; rim light visível no castelo ao entardecer.

## Passo 4 — Canvas de luz (ambient + luzes aditivas, sem stencil)

Canvas de luz: preenchido com cor ambiente do bioma (entardecer=azulado
frio, dusk=roxo, etc.), luzes desenhadas com blend add (gradiente radial
64×64 gerado em código, falloff (1-d²)²), composto sobre a cena com
multiply premultiplied. Fontes de luz: janelas do castelo (quente,
pulsando via cor global pulsante estilo G.C.EDITION), lua no dusk/abyss,
1 lanterna de estrada (novo prop opcional PixelLab ou procedural).
Aceitação: janelas do castelo iluminam de verdade; cena noturna/entardecer
com contraste quente×frio; 60fps mantido; zero stencil.

## Passo 5 — Chão rico (domo com shading + estrada orgânica + sombra de nuvem)

Domo: substituir círculo chapado + arco de linha por shading direcional
real (gradiente de luz crista→base, dithered) e textura de grama multi-tom
com tufos/flores por bioma (reaproveitar clumps, adicionar 2-3 tons e
detalhes de 1-2px espalhados por hash). Estrada: emenda orgânica
grama↔terra (faixa de transição dithered em vez de serrilha de rects),
pedras com 2 tons + highlight. Sombras de nuvem: FBM scrollando (reusar
value noise do dissolve.glsl) escurecendo o morro em patches suaves
(multiply ~0.85), sincronizado com a direção do drift das nuvens.
Aceitação: nenhuma área de cor chapada >100px no domo; emenda
estrada↔grama sem serrilha dura; patches de sombra deslizando em motion.

## Passo 6 — Vida ambiente (partículas por bioma + sway + fumaça + god rays)

Presets de partícula por bioma: vagalumes aditivos pulsantes (dusk/marsh),
folhas caindo com drift senoidal (fields/highlands), neve (frost), cinzas
subindo (abyss), pólen (fields dia). Fumaça da chaminé: quadrados →
partículas suaves com crescimento+fade. Wind sway nos props via shear com
origem na base (sin(t+x)·0.02, fase por posição) ou shader UV (topo
balança, raiz fixa). 1-2 god rays estáticos atrás do castelo (quads
aditivos alpha 0.04-0.08 oscilando) com motes de poeira dentro. Room sway
sutil da cena inteira (rotate 0.001·sin(0.3t) + drift, padrão
update_canvas_juice do Balatro).
Aceitação: cena parada nunca 100% estática; preset certo por bioma;
partículas respeitam profundidade (atrás do front quando ao longe).

## Passo 7 — Moldura e coesão final (framing + vinheta + grade por estado)

Foreground framing: silhuetas escuras de vegetação nas bordas
laterais/inferiores (reusar PNGs de árvore dos biomas tintados quase-preto)
com parallax 110-130% (mais rápido que a câmera). Vinheta radial suave via
shader (substituir as faixas de rects de 2350-2363). Color grade global por
bioma+estado: tint multiplicativo easado (padrão ease_background_colour,
0.6s) ligado a viagem/encounter/fork/chegada. Avaliar palette snap leve no
final do pipeline (posterize fraco) pra colar PixelLab+procedural.
Aceitação: comparação lado a lado com a referência mostra moldura escura e
foco central; vinheta sem degraus; grade muda suavemente ao viajar/encontrar.

## Passo 8 — Validação integral + documentação

Tour completo: capturas dos 6 biomas (wide + 4:3) + travel + fork + gate +
encounter; conferir crossfade de bioma com as camadas novas; medir FPS.
Atualizar memory/worldroad_scene.md (ciclo v6), CLAUDE.md (novos shaders/
sistemas) e docs/plan/worldroad-visual-v6.md (status por passo).
Aceitação: todas as capturas revisadas sem regressão; docs sincronizados
com o código; FPS ≥60 em 1914×1011.
