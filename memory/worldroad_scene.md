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

# ⭐ Integração ao terreno (17/Out/2026)

Pedido do dono: os assets são bons, mas parecem colados no terreno. Critério:
"o objeto tem que parecer que está no chão, não colado". Spec:
`docs/superpowers/specs/2026-10-17-integracao-landmarks-terreno-design.md`;
plano: `docs/superpowers/plans/2026-10-17-integracao-landmarks-terreno.md`.
Ato 1 (`fields`) calibrado; biomas 2 a 6 esperam a aprovação do dono
(Tarefas 7 a 11 do plano). Capturas antes/depois de cada passe:
`tools/preview_out/integracao_terreno/<passe>/` via
`lovec . test_one screenshot_integracao_terreno <label>[:<bioma>]`.

**Dados:** `src/data/scene_integration.lua`, uma linha por bioma (grade,
contact, occlusion, lowFog, trees, landmarks). Tudo o que é calibrável mora
aí; o código só lê.

**Os seis passes (um engine cada, o WorldRoad só chama):**
1. `engine/SceneGrade.lua`: FONTE ÚNICA de cor de sprite da cena. `begin`
   uma vez por quadro logo depois do `LightEngine.beginFrame(amb)`;
   `color(família, t, out)` = temperatura da luz por hora do dia + névoa +
   dessaturação (depois da névoa) + brilho por profundidade (`contrastFar`,
   alcança 1 em t=0,25, mesma curva do `aFade` antigo). `flatColor` = ambiente
   puro para TODO oclusor (o `lift` das árvores e o "só matiz" dos marcos
   saíram). **Montanhas = sem grade** (a faixa delas carrega o céu pintado;
   gradear marronzava o céu). Castelo usa t = 0,6 + 0,4·progress. Expira em
   0,1 s (salão do chefe não herda o grade da estrada).
2. `engine/ContactShadow.lua`: pegada medida no PNG (colunas que tocam o chão,
   `scan` no pré-aquecimento: `toImage`/`tryLoadPng`/`readAnimFrames`) e faixa
   escura curta descarregada logo após o `ShadowEngine.flush()`, num lote.
   Terra queimada da fogueira = disco cheio com alpha caindo e franja irregular.
   **Nada de dither em área** (o primeiro scorch pontilhava linhas inteiras e
   virou bloco quadriculado; trava `maxRowTransitions`).
3. `GrassField.requireTufts(rel, x, w, n, scale)`: lâminas na fatia logo à
   frente da base, no mesmo lote e vento; assinatura por fatia mantém o replay
   da grama com a câmera parada. O landmark escolhido virou pseudo-prop dentro
   do `drawProps` (`drawChosenLandmark`), entre fatias e no balanço;
   `drawLandmarkFront` não existe mais. Tufos do marco nos FLANCOS da base
   (no centro da estrada viram pontinhos na terra).
4. `WeatherEngine`: véu de profundidade em cada `flushTo`, SEGUINDO A CURVA do
   domo (24 segmentos; plano pintaria o céu das laterais), bandas contíguas
   (sobrepor 1 px faz linhas), desenhado com `love.graphics.rectangle` em lote
   (QuadMesh por fatia alocava DataView: +3 KB/quadro). `drawLowFog` na base
   das montanhas: quad reaproveitado com viewport exato, **sem push("all") nem
   scissor** (a versão com os dois derrubava o LÖVE com segfault na suíte longa).
5. Landmarks × terreno pela tabela `landmarks`: brasas (`drawEmbersSpec`),
   fumaça fina e pulso da fogueira; bandeira cisalhada pelo `GrassField.windAt`
   + poeira rara (`WeatherEngine.emitDust`, teto 14); loja com poça rasa
   (`LightEngine.submit{sy}`); castelo com sombra pelo sol na fila do
   `ShadowEngine` (as duas elipses fixas saíram) e névoa própria.
6. `engine/PropVariation.lua`: tom/escala/espelho/fase por semente do prop
   (determinístico), vento em duas amplitudes (tronco gira pouco, copa
   cisalha), companheiras balançam com fase própria. `of` devolve tabela
   reutilizada: copie antes de chamar de novo (`LMG.pvCopy`).

**Calibração do ato 1 com o dono (17/Out, folhas antes|depois em
`tools/preview_out/integracao_terreno/06_calibracao/`, medidas em `medidas.txt`):**
- temperatura do sol é só MATIZ (dia 1/0,985/0,95, pôr 1/0,94/1): a versão
  que escurecia dobrava o ambiente do LightEngine e apagava o pôr do sol;
- névoa da cor da BASE DAS MONTANHAS (`fog` dia azul-acinzentado, `fogDusk`
  lilás), `fogCurve 2.4` (só o fundo), `VEIL_K 0.25`: névoa pêssego virava
  grama cáqui;
- chão, estrada e grama pedem cor em t=1 (textura atravessa todas as
  profundidades; a distância fica com o véu): t=0,5 dessaturava e achatava;
- oclusor de TODA família ganha o mesmo `liftRef/maxLift` da tabela (0,72/1,8,
  os valores do lift antigo das árvores): sem ele a mata ficava escura e sem
  detalhe no pôr do sol;
- `FAMILY_DEPTH` (landmark e inimigo 0,35): o que é escolha ou informação de
  jogo não some na distância;
- sombras: `contact.alpha 0.72`, `shadow.alphaK 2.0` (teto 0,75); faixa de
  contato com altura até 35% da largura do vão (poste fino não vira bloco);
- castelo: sem sombra projetada (caía por cima das montanhas e da própria
  base); `ContactShadow.queueDisc` no topo da colina, abaixo da crista;
- marcos da encruzilhada com luz própria (`landmarks.*.selfLight`, poça rasa).
- A ferramenta de captura fixa o idioma em inglês (a identity de teste
  herdava alemão e as folhas não comparavam igual com igual).

**Rodada de realismo (17/Out, depois de o dono rejeitar a calibração 0604051c; checklist em
`tools/preview_out/integracao_terreno/07_realismo/checklist.md`):**
- SOMBRA RESPEITA PROFUNDIDADE: `ShadowEngine.flushBand/guard/commit/endFrame` e `ContactShadow`
  idem. As sombras são descarregadas com cada fatia de grama, recortadas pela faixa do domo
  (`setClip`), e um objeto só é desenhado depois de a fila pendente que cruza a caixa dele sair.
  A fila única no fim do quadro pintava a sombra de trás sobre o poste da frente (trava em
  `test_world_shadows`).
- Sombra com gradiente ao longo do comprimento (`ShadowEngine.FADE`), na cor do shadowTint.
  Força +60% (alphaK 1.6), não 2x.
- Chão em degradê contínuo por pixel: o véu do `WeatherEngine` virou shader (`groundFar/groundReach`).
- Árvores: `treeGain`, variação de tom 0,02. O shader de volume das árvores foi tentado e retirado
  (não convencia).
- Custo: 561 draw calls e 7,7 ms em 1080p (eram 4,3). Baratear = máscara num passe só.

**Rodada de ajuste (17/Out, checklist em `tools/preview_out/integracao_terreno/08_ajuste/checklist.md`):**
- Sombras em PASSE ÚNICO com máscara de profundidade: os objetos gravam o contorno com a sua
  profundidade t (`ShadowEngine.mask/maskRect`, `PropCut.mask`); as sombras projetadas e de contato
  são acumuladas com a profundidade de quem projeta (`queue(..., t)`, `ContactShadow.drawAcc`); a
  composição só escurece onde o objeto não está mais perto. Agrupado por imagem.
  Resultado: 390 draw calls e 4,4 a 5,2 ms em 1080p (a versão por fatia+guard fazia 561 e 7,7 ms).
  Batalha: `endFrame` antes do inimigo.
- Dia: `contrastFarDay 1.0` (o horizonte clareia e azula; só o pôr do sol escurece a distância).
- Árvores perto: `treeNear` (verde) + `treeGain 0.7`, só até t = 0,6.
- `ShadowEngine.occlude` (volume na copa) existe, mas está desligado (`selfShade.k = 0`): em intensidade
  baixa o roxo do shadowTint deixava a copa acinzentada (saturação 131 → 104 no pôr do sol).

**Fechamento do ato 1 (17/Out, `09_final/checklist.md`):** sombra de pixel art = UMA cópia da
silhueta (sem smear), resolução 1/2, esmaecimento em `ShadowEngine.STEPS` (3) degraus e composição
por MULTIPLICAÇÃO com a cor de sombra do bioma (`shadow.color`). A mistura alpha com a cor de tinta
pintava roxo/cinza sobre a grama e lia como sujeira. Trava: no máximo 4 tons no esmaecimento.
Árvores perto: `treeNear` leve (0,95/1/0,93), `treeGain 0.8`.

**Números (1024×768, test_perf_budget isolado):** antes 427 draw calls /
30,5 KB; depois 389 / 31,5 KB, 4,1 ms em 1080p (o véu é ~40 draw calls). Locais do arquivo
`WorldRoad.lua`: 198 → 188 (`python tools/count_locals.py src/ui/WorldRoad.lua`).

**Travas:** `test_scene_grade`, `test_contact_shadow`, `test_landmark_fx`,
`test_prop_variation`, blocos novos em `test_world_props` e `test_weather`.

**Regra:** cor de sprite da cena só pelo `SceneGrade` (nada de `setColor` com
tom fixo nos pontos de desenho do WorldRoad/EnemyRenderer).

**Realismo do ato 1 (18/Out/2026, frente realismo-cenario; pesquisa em
`tools/preview_out/realismo/00_pesquisa.md`, um `checklist.md` por experimento):**
- Sombra de árvore: a fila do `ShadowEngine` passa a HONRAR o `alphaK` por entrada
  (`drawQueued`); `shadow.alphaK` global 2,2 (inimigo e marcos, um degrau acima),
  árvores ×`shadow.tree.alphaK` 1,45 e `lenK` 0,70 (sol mais alto: a copa cai do lado
  do tronco); `shadow.fade` vira dado; disco de sombra de copa sob cada árvore
  (`shadow.canopy`, `ContactShadow.queueDisc`, em união com a silhueta). O global
  3,0 pintava um borrão sob o inimigo da viagem: rejeitado.
- Chão: `groundFar` 0,62 / `groundReach` 0,85 / `contrastFarDay` 0,85 (perto claro,
  longe escuro, pedido do dono).
- Árvores por plano: `grade.treeDepth = { near, far, sat, bright, fog }` só na
  família `tree` (`SceneGrade.color`): a crista recua para a névoa; meio ~88 % de
  saturação (sat 0,55 acinzentava o meio: rejeitado).
- Lado iluminado: `world_props.lit[sprite] = ±1` medido no PNG; `PropCut.flipToSun`
  espelha para o lado pintado ficar virado ao sol (`celestial.xr`); sem `lit` o
  espelho segue sorteado.
- Fogueira: `LANDMARK_LIGHT.landmark_rest` 0,95/0,85, `selfLight` ×2 no rest;
  lanterna dos campos 1,50/0,95 e `size` 4,2 → 3,2 (poste de 2,5 m tinha 91 % da
  altura de uma árvore adulta).
- Medidas: árvore t=1 / 0,5 / 0,22 = 400-560 / 180-200 / 90-100 px (`persp` certo);
  `tools/realismo_measure.lua` lista tamanho por profundidade; folhas antes|atual|
  experimento com recortes 3x por `tools/realismo_sheet.py`. Perf 1080p 4,4 ms,
  389 draw calls, 31 KB.

**Árvores novas do ato 1 por plano (18/Out/2026, frente arvores-novas; prova e
checklist em `tools/preview_out/arvores_novas/`):** o dono rejeitou as árvores
antigas e a troca de 3 (massa uniforme no meio). Agora `fields_tree_0..5` = seis
candidatas `fields_sun_*` (a_0, c_3, a_3, a_1, b_2, c_0: redonda, larga, com vãos,
inclinada, alta, em patamares; todas neutras de luz, sem `lit`), `world_props.variants`
diz quantas variantes a espécie tem (`PropCut.nvar`; `rollProp`, companheiras e
`prewarmJobs` leem dali) e `makeWall` nunca repete a variante da vizinha do mesmo lado.
- **Tratamento por plano = `shaders/tree_depth.glsl`**, só na família `tree` e só
  em bioma com `grade.treeDepth` (`SceneGrade.treeDepth(t)` → `PropCut.beginDepth`):
  névoa por PIXEL para `SceneGrade.treeHaze()` (névoa crua × `haze` por canal; os
  escuros sobem mais), saturação por pixel (`satNear` no perto → `sat` no fundo),
  meia resolução NÍTIDA no fundo (`lod`: amostra pontual do bloco 2×2; a média 2×2
  virava blur e foi rejeitada) e volume topo-claro/base-escura (`vol`). No perto o
  shader é pixel-idêntico ao desenho cru fora de `vol`/`satNear` (trava em
  `test_world_props`). O `tdSat` saiu do tint do `SceneGrade.color` (num tint quase
  branco não dessaturava nada).
- **Lição:** clarear a base escura de TODAS as copas (lift alto, sem volume) deixa a
  mata do meio MAIS uniforme; o que separa árvore de árvore é o contraste dentro da
  copa (topo claro, base escura) e a diferença de brilho entre vizinhas
  (`PropVariation.bright` ±16 % além do tom ±6 %). A névoa entra devagar
  (`near` 0,70 → `far` 0,25) e mais verde que roxa.
- Sombra de copa e faixa de contato só no perto (`PropCut.nearK`); `treeGain` 0,92.
- Perf 1080p: 5,2 ms mediana, 401 draw calls, 31,6 KB, 0 decode na troca; 188 locais.

**Árvores animadas por quadros (18/Out/2026, frente arvores-anim; pedido do dono: "uma
animação mínima feita pelo PixelLab... só para dar um efeito mais detalhado"):**
- Quadros em `assets/sprites/world/anim/<bioma>_<kind>_<v>/0..6.png`; o `0.png` é o PNG
  estático byte a byte. `PropCut.treeFrames` carrega (no `prewarmJobs`, junto do sprite) e
  `PropCut.frameOf` escolhe: `PropCut.anim = { fps = 5, pingpong = true }`, fase POR INSTÂNCIA
  = `windPhase` do `PropVariation` (mesma semente do balanço; vizinhas nunca no mesmo quadro).
  O quadro entra só no `love.graphics.draw` (`PropCut.draw(..., fimg)`): quad de corte, sombra
  (`ShadowEngine.queue`/`mask`), `ContactShadow`, texel do `tree_depth` e oclusão continuam
  usando a imagem BASE, o que é exato porque a silhueta é idêntica em todo quadro.
  `reducedMotion` = sem quadro (estático). Só a árvore principal e a do cluster na faixa
  visível; a crista (`drawPropsBehind`) fica estática.
- Geração: `tools/pixellab_tree_anims.py` (`animate_image`, 6 quadros, prompt por família;
  queue/poll/check/install/sheet/rawsheet/texmem). O modelo REDESENHA a árvore inteira (só ~70 %
  dos pixels do quadro 0 gerado batem com a base, e tronco/raízes trocam de cor); por isso o
  install NÃO usa o quadro cru: transfere só o DELTA entre quadros gerados (o que mexeu do
  quadro 0 gerado ao N), dentro da silhueta da base, fora do contorno de 1 px, fora dos 30 %
  inferiores (tronco), sem abrir furo, com paleta presa à da base. Portão: IoU cru ≥ 0,97,
  tronco ≥ 0,95 entre quadros gerados, e anim "viva" (≥ 0,8 % da área mexe).
- Campos: animadas `fields_tree_0/1/2/4`. `fields_tree_3` e `_5` reprovaram 3 tentativas cada
  (o modelo deforma a copa/silhueta; com o último quadro pinado na base sai CONGELADO) e ficam
  só com o balanço. Outros biomas: quadros crus gerados em `tools/preview_out/arvores_anim/raw/`
  mas NÃO instalados (frentes de replicação vão revisar essas árvores antes). Pinheiros e
  árvores secas reprovaram em massa no 1º lote (IoU 0,86 a 0,93, tronco 0,74 a 0,90); só
  `abyss_deadtree_2` passou. Trava: `test_tree_anim`.

**Escala humana do quadro de batalha (18/Out/2026, frente cenario-escala; entregas em
`tools/preview_out/escala_humana/`: `medidas.md`, `checklist.md`, recortes antes|depois):**
o dono reprovou o quadro de batalha do ato 1 (poste menor que o inimigo, árvores do meio
leitosas, "sem sombra", lanterna acesa de dia, árvores da crista do tamanho do castelo).
- **Unidade de medida = o inimigo.** Em 1080p o inimigo comum mede 317 px e fica em t=0,385
  (`battleRelFor` empurra o palco até a carta levantada; `enemyScreenK` 1,555 e
  `ENEMY_SIZE_PERSP` 0,6), o que dá **6,9 unidades de `size`** na profundidade dele, não as 3,7
  que a conta ingênua (250 px em rel 9) sugere. Ferramenta: `lovec . test_one escala_humana
  <rótulo>:<b1..b6|fork|landmark|castelo>` (1080p virtual, `ESCALA_TOD`, `ESCALA_VIRTUAL=WxH`),
  escreve PNG + `.txt` com altura em px de cada prop (`_hitScene`), inimigo, castelo
  (`WorldRoad._castleTop.h`) e marco escolhido (`_lmMark.h`); `tools/escala_humana_sheet.py`
  monta folhas e mede copa × grama.
- **Tamanhos (dado):** `KIND_SIZE` tree 5,6 / pine 6,0 / deadtree 5,2 (eram 4,6/5,0/4,2);
  poste de rua 5,0 nos campos, pântano e crepúsculo (3,2/4,2/4,2); braseiros 2,4 a 2,5, tocha
  2,2, totem 3,0; relicário/cristal/cogumelo/lanterna de mão do gelo intocados. Resultado: poste
  = 0,68× o inimigo REAL na mesma profundidade (era 0,44), árvore adulta 0,6 a 1,1× (era 0,5 a
  0,8). A razão literal do brief (poste 1,35×, árvore 1,5× do inimigo real) exigiria poste ≈ 9 e
  árvore ≈ 10 unidades: a árvore perto passaria de 1100 px e cobriria estrada e cartas. O lever
  que falta é o tamanho do inimigo (cresce 1,555× em 1080p contra 1,40× do mundo), decisão de
  legibilidade que não foi mexida.
- **Crista:** `PropCut.crestK(kind, t)` (`PropCut.CREST = { t = 0.15, k = 0.70 }`) encolhe só
  as árvores nos últimos 15 % de profundidade (o `persp` tem piso 0,14 e deixava a árvore do
  horizonte do tamanho do castelo); castelo nasce em `CASTLE_APPROACH.far` 1,3 do tamanho
  base e cresce `growth` 2,9 (era 1,0 + 3,2: o tamanho final no portão não mudou). Castelo /
  maior árvore da crista: 1,7 → 2,3 a 2,5 em todos os atos.
- **Véu das árvores = curva do chão.** `treeDepth.lift` virou multiplicador de
  `SceneGrade.fogAlpha(t)` (0,25 = o mesmo `VEIL_K` que o chão recebe) com a névoa CRUA do
  bioma (`haze = {1,1,1}`); o shader `tree_depth.glsl` não clareia mais os escuros; a família
  `tree` com shader não recebe a névoa clara do tint (`SceneGrade.color`); `sat` 0,85 no
  horizonte; meia resolução só em t < `lodT` 0,12. Medido em t 0,3 a 0,5: copa/grama vizinha
  L 1,10 → 0,70 e S 0,92 → 1,84 (no perto é 0,88 / 1,71). lift 1,0 e 0,5 ainda liam lavanda.
- **Sombras:** a batalha SEMPRE compôs as mesmas sombras da encruzilhada (duas bandas:
  `endFrame` antes do inimigo e no fim; provado por diff com `ESCALA_NOSHADOW=1`). O que
  estava errado: `ShadowEngine.sprite` aplicava o cisalhamento do sol DENTRO do espaço do
  sprite espelhado, então todo prop virado para a estrada (`face`, `flipToSun`) projetava a
  sombra PARA o sol (postes da direita para a direita). Agora `kx = -shd·0,78·flip`. O poste
  mais perto continua sem sombra visível porque o sol está à frente da câmera (`celestial.yr`
  0,14): a sombra cai para baixo da tela; só a faixa de contato aparece.
- **Luminária de dia:** `LuminaireEngine.setTimeOfDay` (chamado no `WorldRoad.draw`) e
  `dayK = smoothstep(0.45, 0.85, tod)` (`DAY_GATE`) multiplicam raio e intensidade da luz e
  da micro-luz; em `dayK = 0` nada é submetido. A chama pintada no PNG fica. No jogo real
  (tod 0,62 a 1,0) a lanterna acende do andar 1 (fraca) ao 4 (cheia).
- Perf 1080p: 3,5 ms mediana, 397 draw calls, 31,8 KB; WorldRoad continua em 188 locais.
- **Cadência das luminárias:** `LUM_STEP` 7 → 13 (jitter 2,5; lado oposto meio passo à
  frente, 0,45 a 0,65 do passo). Com poste de 5,0 a cadência antiga empilhava quatro postes em
  volta do inimigo (a cabeça do perto encostava no do meio); agora no máximo 2 por lado na
  faixa visível de 26 unidades (batalha do ato 1: um em t 0,85 e um em t 0,13). Braseiros,
  tochas e totens seguem a mesma fila.
- **Inimigo cresce com o mundo (18/Out/2026, lead, depois de "faça yes com tudo"):**
  `ENEMY_SCREEN_GROWTH` 1,4 → 1,05, então em 1080p o inimigo cresce 1,42x como o cenário
  (289 px em vez de 317) e os props subiram 12 % na mesma régua: poste 5,6, tree/pine/deadtree
  6,3/6,7/5,9, braseiros 2,7/2,8, tocha 2,5, totem 3,4, lanterna do gelo 1,8. Na profundidade
  do inimigo o poste vale ~0,85 dele; toda árvore segue mais alta que o poste; o topo do castelo
  do ato 1 voltou a aparecer acima da barra do inimigo. A sombra projetada do inimigo encurtou
  25 % (`lenK × 0,75` no `EnemyRenderer`): com o sol à frente da câmera ela cai para a frente
  dele e lia como mancha na estrada. `test_enemy_stage` exige 1,4 < k1080 < 1,7.
- **Densidade de pixel (18/Out/2026, frente replica-6, folha `tools/preview_out/replica_atos/seis_atos_densidade_pixel.png`):**
  prop perto da câmera chegava a 9 a 11x de escala (árvore dos campos 9,2, crepúsculo 11,1, poste 8,9)
  contra 3,2 do inimigo em 1080p, e lia como blocos. Regra: `PropCut.PIX` + `PropCut.nearFade` no
  `drawProps`: prop cuja escala geométrica passaria de `cap` (2,0) × pixel de referência do inimigo
  (`ref` 2,08 × `enemyScreenK`) não é desenhado (parado: corte seco; na viagem: some em `fade` 0,88 a
  1,0 da razão). Testado e rejeitado: teto suave de escala (o poste perto encolhia para 1,4x o inimigo e
  a profundidade achatava, tudo a partir de t 0,65 com o mesmo tamanho). Com o recuo a parede mais perto
  fica em t 0,6 a 0,8 com tronco e raiz à vista; o poste perto da câmera sai, os da profundidade do
  inimigo ficam. Pior escala nos seis atos: 5,7 a 6,2. Trava em `test_world_props` (seis biomas, com a
  variação de escala por instância). `escala_humana` imprime `s=` por prop.
- **Castelo fora da coluna do HUD (18/Out/2026, frente replica-6, folha
  `tools/preview_out/replica_atos/seis_atos_castelo.png`):** em todos os atos o castelo da crista ficava
  exatamente atrás da intenção e da barra de vida do inimigo (e do corpo dele). Baixar o HUD não
  resolvia: o próprio inimigo cobre a base do castelo. Agora o castelo nasce deslocado na crista
  (`CASTLE_APPROACH.side` 0,17 da largura × `(1 - progress)^1,5`), no lado OPOSTO ao sol/lua do bioma
  (`celestial.xr`), e volta ao centro conforme a jornada avança: no fim do ato está de frente para a
  estrada, como a cena do portão pede. A clareira da grama segue o castelo (`castleGapX`) e prop da
  crista na frente dele some (t < 0,3; na viagem esmaece de 0,24 a 0,36). Castelo / maior árvore da
  crista vizinha: 2,3 a 3,7 nos seis atos (o ato 6 passou de 1,8 para 2,4 sem mudar tamanho).
- **Ato 6 / dusk (18/Out/2026, frente replica-6, `tools/preview_out/replica_atos/dusk/`):** entrada
  `dusk` copiada do modelo `fields` (treeDepth, sombra de árvore e disco de copa, contato 0,65, chão
  mais escuro no horizonte); temperatura virou só matiz (o `dusk` 0,78/0,56/0,70 apagava as copas
  perto para quase preto); névoa = cor medida da base das montanhas, cor de sombra púrpura. Árvores
  3 → 7 variantes (`dusk_tree_3..6`: choupo, carmim de outono, meio pelada, chorona;
  `variants.dusk_tree = 7`), porque a parede era uma massa roxa única. Poste regenerado (madeira
  sem a faixa laranja pintada e sem a mão-francesa quadriculada) e cintilação refeita só no vidro em
  `anim/dusk_lantern_0/` (o `anim/` tem prioridade sobre o PNG solto: trocar só o PNG não muda nada);
  tamanho 6,1 para o poste medir o mesmo que o do ato 1 em cada profundidade (601 x 605 px em t 0,85).
  Diorama (adendo do dono): as 7 árvores regeradas com copa em três planos e luz do sol do bioma
  (à ESQUERDA, `celestial.xr` 0,30), `world_props.lit = -1` para o `flipToSun` manter o lado claro no sol.
- **Ato 4 / frost (18/Out/2026, frente replica-45, `tools/preview_out/replica_atos/frost/`):** entrada
  `frost` no modelo `fields` (treeDepth com lift 0,30, sombras ligadas: alphaK 2,0, cor de multiplicação
  azul 0,46/0,52/0,66, árvore ×1,35, copa 0,45; chão mais escuro no horizonte); grade só matiz (o pôr
  0,64/0,70/0,90 escurecia tudo). O chão era asfalto escuro sob pinheiros carregados de neve (colagem):
  `biomes.lua` frost `grassA/B` 0,30 → 0,50 e `grassTint` 0,62/0,68/0,75 → 0,80/0,86/0,94 (neve batida).
  A "lanterna de mão" (caixinha de pedra de 36 px, 0,24× o inimigo, lia como lixeira) virou poste de
  ferro nevado com braço de volutas (PixelLab `create_image_pro`, ref. de forma `fields_lantern_0`, de
  paleta a antiga): size 5,6, `face` 1, 0,86 a 0,88× o inimigo; chama tremulando por script em
  `anim/frost_lantern_0/`. Fogueira `selfLight` 0,20.
- **Ato 2 highlands (18/Out/2026, frente replica-23, `tools/preview_out/replica_atos/highlands/`):**
  entrada do ato 1 replicada (treeDepth, treeNear, sombra 2,2 com árvore/copa e cor fria, contato
  0,65, chão perto claro/longe escuro); braseiro regerado como pilar de 2,5 m (0,87x o inimigo,
  era um cubo de 0,30x) com `light.pool` (poça no chão, genérico no LuminaireEngine) porque a chama
  no topo deixava o círculo de luz no ar; 3 pinheiros novos (`variants` 6); chama da fogueira
  recolorida de salmão pastel para laranja vivo (a lua a acinzentava e o fogo não lia como fogo).
- **Ato 5 / marsh (18/Out/2026, frente replica-45, `tools/preview_out/replica_atos/marsh/`):** entrada
  `marsh` no modelo `fields` (grade só matiz, treeDepth lift 0,25, sombras alphaK 2,0 com cor de
  multiplicação verde-musgo 0,34/0,40/0,32, árvore ×1,35, copa 0,50, chão mais escuro no horizonte,
  fogueira `selfLight` 0,12); lanterna verde 1,60 de raio e 1,00 de intensidade com `light.pool`
  0,80/0,80 (verde sobre grama verde quase não aparecia e a chama no alto não alcançava o chão). A parede era 3 árvores iguais: `marsh_deadtree_3..7` (inclinada com cortina de
  musgo, cipreste com joelhos, tronco partido, forquilha, nó inchado; PixelLab `create_image_pro` com
  `marsh_deadtree_0/1` de referência), `variants.marsh_deadtree = 8`, `sink` 8 a 10. Sem `lit`: a
  assimetria medida no PNG é de forma, não de luz.

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

> **SUPERSEDIDO em Set/2026 (v11).** O interior é SÓ do boss, e a âncora do
> inimigo não é mais fixa — ver
> [`memory/enemy_pose_and_scene_anchor.md`](enemy_pose_and_scene_anchor.md).
> O texto abaixo descreve o estado v10.4 e ficou aqui pelo histórico.

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
- ~~Endless (bioma 4-6) usa castle_hall_<min(act,3)>~~ — superado: cada ato tem o seu salão (ver [[boss_halls]]).
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

**Ciclo 43 (entregue — v5.3, 06/Jul):** (1) "quebra fininha" na junção
do fork: braços agora COMEÇAM em 100% da largura e afinam com o mesmo
smoothstep do offset (hm = 1-0.22k). (2) Borda serrada estilo ref APK:
jitter em blocos por rowId (±7px×profundidade) nas bordas xL/xR — degraus
de tijolo, não linha lisa; combinado com o meandro. (3) CASTELOS
definitivo: validação por composição sobre MAGENTA revelou o que fundo
claro escondia (abyss comido no lado esquerdo inteiro!). Fixes: ESPELHO
simétrico (transparente ganha o pixel espelhado — castelos são
simétricos; abyss +3697px) + veias finas por linha (vão ≤20px).
LIÇÃO DE PIPELINE: transparência de sprite SÓ se valida compondo sobre
cor contrastante (magenta) — fundo branco/preto esconde vazamento.
castles_magenta2.png = sheet de prova.

**Ciclo 44 (entregue — castelo abismo v6 + regras de geração, 06/Jul):**
5 tentativas de castelo escuro ensinaram o padrão: (a) descrição
"black/obsidian/dark charcoal" → gerador ASSA backdrop dramático (lua,
montanhas, halo) e a remoção de fundo COME fileiras da parede (tom
confunde com céu) → paredes fatiadas; (b) reconstrução espelho+veias não
salva sprite muito comido (fendas de 1px viram slits na escala do
portão). REGRAS DE OURO da geração de castelo: (1) paleta de TOM MÉDIO
("weathered dark crimson-brown", nunca preto puro); (2) "sprite alone
floating on fully transparent background with generous empty margin";
(3) prova magenta AMPLIADA 3x (1px de fenda invisível em 1x!) ANTES de
instalar; (4) validar in-engine na escala do PORTÃO (gate<N>), não só
distância. v6 veio PERFEITO de primeira com essas regras (fundo creme
chapado, alto contraste, 0 furos). Galeria de monstros no demo: tecla M
(setas/H/K/J/1-6).

**Ciclo 45 (entregue — v5.4 atmosfera, 06/Jul):** triagem do feedback de
IA externa (via print estático, sem código): 60% JÁ EXISTIA e só aparece
em movimento (vento, partículas por bioma, pássaros, critters, fumaça,
12+ camadas, meandro) — print parado não prova vida. Adotado o que era
novo: (1) NÉVOA DE DISTÂNCIA — banda de bruma (fog do bioma, α pico 0.26)
entre montanhas e mundo, castelo desenha depois e fura; (2) GRAMA
INVADINDO a estrada — fiapos verdes nas bordas por rowId (55%);
(3) tufos/flores BALANÇAM (rot 0.055, 2.3Hz — mais soltos que árvores);
(4) sombra rasteira do inimigo DE VOLTA (0.42×largura, achatada, colada
nos pés — remoção antiga jogou fora a âncora junto com o bug de offset);
(5) PÁTIO de terra batida no pé do castelo (elipse roadA, cresce com
progress) — castelo assenta no terreno. Descartado do feedback: refazer
camadas (temos), parallax extra (mundo-esfera já dá profundidade via
persp), "estrada reta" (meandro v5.2 já resolvera).

**Ciclo 46 (entregue — v5.5 telas largas, 06/Jul):** feedback: "em tela
cheia os detalhes do céu não aparecem + fundo preto em alguns biomas".
Causa: montanhas escalavam por LARGURA (sx = w/iw) — em monitor largo o
strip ficava gigante, cobria lua/nuvens e o topo (transparente) expunha
o fundo de segurança escuro. Castelo idem (baseScale por w → cortado).
Fixes: (1) montanhas por ORÇAMENTO DE ALTURA: sx = max(0.72×skyH/ih,
w/(3iw)) + tiling adaptativo (nTiles = ceil(w/tileW)+2, espelhado);
(2) faixa hillsNear da base do strip até o fundo (extremidades onde o
domo não cobre); (3) castelo: refW = min(w, h×1.5). Validação nova:
prefixo wide_ no screenshot (1914×1011) — REGRA: layout de céu/bg
valida nos DOIS aspectos (full<N> e wide_full<N>).

**Ciclo 47 (entregue — v5.6 bordas da esfera + faixas laterais, 06/Jul):**
(1) "Retângulos na curvatura": fatias de 32px da textura do domo
escadinhavam na borda visível → SEG adaptativo (8px onde t<0.3, 32 no
corpo) + tampa lisa (arc exato do círculo, lw3, cor grassA, largura
total, 256 segmentos) + circle fill com 256 segmentos. (2) Faixas
preta/roxa nas extremidades largas: eram TRÊS camadas chapadas
empilhadas + o RODAPÉ do PNG das montanhas (últimas fileiras degradam
pra preto). Fix: gradiente hillsNear→grassA×0.82 começando 46px DENTRO
do strip (cobre o rodapé preto) e alvo = tom do topo do domo (funde com
a silhueta). Validado wide_full2 com zoom + full2 normal sem regressão.
Se a região ainda incomodar: opção futura = franja de silhuetas de
pinheiro descendo até a borda do domo.

**Ciclo 48 (entregue — v5.7 background GIGANTE, 06/Jul):** feedback direto:
"esse seu fake eu não gostei — o próprio background deve ser grande o
suficiente pra ocupar toda a tela; nuvens acima do BACKGROUND, não do céu
fake" (print abyss ultrawide: céu chapado + sol DUPLICADO do tiling).
Reversão da v5.5: (1) montanhas em escala COVER —
`sx = max(w/iw, (crestApexY - g.y + 70)/ih)` — uma peça domina o frame
nos DOIS aspectos (ultrawide: largura ganha, 1 sol; 4:3: altura ganha,
crop lateral centrado). Primeira tentativa só por largura vazou o céu
procedural em 4:3 (faixa roxa+listra no full3) → daí o max(). (2) Ordem
do draw: drawClouds/drawBirds movidos pra DEPOIS de drawMountains —
nuvens e pássaros vivem SOBRE a arte do bioma; drawCelestial fica atrás
(o sol/lua ASSADO no PNG assume o papel em quase todo bioma). Gradiente
de rodapé do c47 mantido. Validado full1/3/5/6 + wide_full3 (ws_c50/51).
LIÇÃO: "céu procedural + strip baixo" lê como FAKE — o jogador quer a
ARTE preenchendo; procedural só pode aparecer se indistinguível dela.

**Ciclo 49 (entregue — v5.8 nuvens atrás das montanhas + camadas, 06/Jul):**
feedback: "nuvens passando atrás das montanhas do background; nuvens
sempre pequenas e ao fundo; animação nelas". (1) CAMADA FRONTAL:
<bid>_mountains_front.png = silhueta extraída do próprio strip
(scratchpad/extract_ridge.py: flood do céu pelo topo com tolerância
vizinho-a-vizinho POR BIOMA {fields 26, highlands 36, frost 34, abyss 28,
dusk 34} + mediana 3×3 + abertura morfológica h±2/v±1 + re-flood +
de-speckle <25px), desenhada DEPOIS das nuvens com o MESMO transform
(stripTransform/drawStripTiles compartilhados) — oclusão real sem stencil.
Marsh = névoa por design, insegmentável → SEM overlay (fallback
gracioso: getSprite retorna false). Ilhas tipo o sol do dusk PODEM ficar
na frente (nuvem passa atrás do sol — bonito). Prova magenta 3× por
bioma antes de instalar. (2) NUVENS: escala 0.85-1.4 near / 0.45-0.75
far (era até 3.2 — "gigantes e próximas"), banda alta (yr ≤0.60), drift
mais lento, bob senoidal 2.5px (0.35Hz, phase própria), escala ×
sqrt(w/1024) pros dois aspectos. (3) BUG DA FERRAMENTA descoberto:
full<N>/gate<N> passavam actNumber=1 no draw → setBiome(1) criava blend
INVERTIDO t=0 cujo prev (bioma pedido, alpha 1) cobria tudo — DOIS bugs
se cancelando; a camada frontal expôs (picos do fields sobre o dusk).
Fix: passar o bioma certo + _blend=nil pós-warmup (igual modo endless).
CONSEQUÊNCIA: paletas "validadas" antes eram meio-blend com fields — a
estrada do abyss é MUITO mais escura na verdade (real do gameplay; a
ferramenta é que mentia). LIÇÃO: modo de validação que passa parâmetro
fixo≠estado configurado gera dupla-verdade — sempre ecoar o parâmetro.

**Ciclo 50 (entregue — v5.8.1 silhueta SÓLIDA, 06/Jul):** feedback com
print: "apenas a parte mais escura funcionou" — neve clara ≈ céu pálido
era marcada como céu pelo flood e virava BURACO na camada frontal (nuvem
aparecia POR CIMA da neve). Fix no extrator (agora versionado em
tools/extract_mountains_front.py): após flood+abertura, componentes do
front são classificados — massa CONECTADA AO CHÃO é preenchida coluna a
coluna do cume até a base (silhueta sólida, neve incluída); ilha grande
≥600px (sol do dusk) mantida como está; fragmento solto descartado
(nuvem passa na frente — ok pra picos distantes). LIÇÃO: pra OCLUSÃO o
que importa é a SILHUETA (borda superior), não a classificação
pixel-a-pixel — preencher pra baixo elimina toda classe de buraco
interno. Validado: prova magenta 5 biomas + full1 + wide_full4.

**Ciclo 51 (entregue — revisão dos 6 biomas + fusão de componentes, 06/Jul):**
pedido: "revise todos biomas". Varredura full1-6 + wide_full1-6 achou 2
falhas na oclusão: (a) highlands — pico roxo grande DESCONECTADO da massa
pela névoa da base → descartado → nuvem passava na frente; (b) dusk —
listras horizontais do horizonte atravessam o disco do sol → flood
entrava por elas → sol furado, nuvem visível sobre o disco. FIX v5.1 do
extrator: FUSÃO — componente ≥40px pairando até 12px acima da massa
funde nela antes do fill-down (pico gruda, sol gruda nos morros);
migalha <40px NÃO funde (fill-down dela virava pilar fino que mordia
nuvem no céu aberto — visto no fields/abyss na 1ª tentativa). Cascata de
3 passes (pico gruda em pico). Validação: prova magenta 5 biomas + zoom
3× in-engine nos 2 casos (nuvem cortada na diagonal da encosta; nuvem
sumindo na borda do sol). Modo novo na ferramenta:
enemy<N>_<spriteId> — monstro plantado na estrada do bioma N (validou
winter_monarch/mire_hag/eclipse_queen nos cenários endless).

**Ciclo 52 (entregue — oclusão FINAL, cume por detalhe, 06/Jul):**
feedback com print (fields): "ainda tá acontecendo, só a parte escura
funcionou" — causa REAL mais profunda que buraco: faces iluminadas
(neve pêssego do fields, gelo pálido do frost, rims do abyss/dusk) têm
A MESMA COR do céu — flood por cor não separa em NENHUMA tolerância
(varredura tol 16/22/28 provou: ou come a face, ou trava o céu inteiro
como oclusor). Solução v6 do extrator: CUME POR DETALHE — céu é LISO,
montanha é TEXTURIZADA. busy = contraste local 3×3 > limiar POR BIOMA
(frost 12 — neve suave; resto 26); cume-detalhe = 1º y com busy
persistente na vertical (≥3 das 6 linhas seguintes — filtra listra de
1px do céu do dusk); mediana-5 + CONSISTÊNCIA DE LINHA (±6 colunas
concordando em ±7px, senão rebaixa — mata pilar de raio de sol/borda de
nuvem assada); TETO DE ELEVAÇÃO por bioma sobre o flood (DCAP: frost/
highlands 64 céu limpo, fields 32, abyss 18, dusk 12 céu cheio de
objeto assado — teto alto ali vira mesa/perna sob o sol). Ridge final =
min(flood+fusão, detalhe com teto). FERRAMENTA DE PROVA nova: nuvem
FORÇADA colada na encosta via PIL (composite base+nuvem+front) — pega o
que a prova magenta não mostra (front é invisível sobre a própria arte).
LIÇÃO: validação de oclusão exige teste com o OBJETO OCLUÍDO presente.
NOTA: assets carregam no boot do LÖVE — feedback "ainda quebrado" com
timestamps próximos pode ser sessão antiga do jogo (pedir restart).

**Ciclo 53 (entregue — roster endless COMPLETO, 06/Jul):** 9 monstros
novos (v3 low top-down, 96/96/128px, idle 4f/hurt 6f/death 7f south):
- Frost (4): frost_wight a2509e76 / glacier_knight 2387dbb6 /
  winter_monarch 5b9aedb4
- Marsh (5): bog_ghoul f8255189 / mire_hag 452bc0b9 / rot_colossus
  40ffec96 (death falhou 1x "heavy load" — retry ok, lição do c40
  confirmada: SEMPRE checar failed jobs no get_character)
- Dusk (6): dusk_shade 3b418a1f (hurt/death perderam slot na 1ª onda —
  re-enfileirar anims que caíram no cap 8) / blood_duke f923a367 /
  eclipse_queen 33a1713d
Fiação: ENEMY_ROSTER[4..6] + resolveSpriteId wrap %6 (espelha
WorldRoad.rawBiome) + Game:nextPhase calcula act efetivo no endless
(4 + floor((currentFloor-25)/8)) + galeria do demo com 12 monstros.
Instalador reutilizável: tools espelhado em scratchpad/install_enemy.py
(baixa ZIP, crop por UNIÃO de bboxes +2px, instala idle/hurt/death).

**Ciclo 54 (entregue — auditoria por pixel + polylines manuais, 06/Jul):**
feedback (print bioma 2): "quebrado em alguns biomas, teste todos os
pixels possíveis". FERRAMENTAS DE AUDITORIA definitivas: (1) TINT
vermelho da camada frontal in-engine (_G.WR_TINT em drawMountainsFrontOf)
— revelou CUNHAS azuis descobertas nos "V entre picos" do highlands que
overlay 3× não mostrava; (2) dump numérico do topo do front por coluna
(compara com grid de coordenadas sobre a arte); (3) GRADE DENSA de
nuvens forçadas (33 posições × 3 alturas × 5 biomas via PIL). CAUSA das
cunhas: no V entre dois picos o flood desce comendo a face de TRÁS
(lisa → detector de textura cego; DCAP não ajuda porque o topo da massa
ali é o fundo do V). FIX: RIDGE_RAISE — polylines manuais por bioma
lidas do dump+grid (highlands: 5 segmentos) aplicadas como
min(auto, lerp); RIDGE_CLEAR — inverso (max) pra platô de sobre-oclusão
em céu aberto (fields x58-88). LIÇÕES: (a) overlay em zoom baixo
engana — auditar com NÚMEROS por coluna + zoom 5-6× com grid; (b) tint
in-engine é a prova fim-a-fim real (pega até desalinhamento de
transform); (c) heurística tem teto — os últimos 5% são polyline manual
mesmo, e tudo bem (400px/bioma, determinístico, versionado).

**Ciclo 55 (entregue — sol não oclui nuvem, 06/Jul):** feedback: "no
bioma 6 não faz sentido nuvem passar atrás do sol" — correto: sol é
astro DISTANTE, nuvem passa na FRENTE. Removida a regra da ilha
oclusora ≥600px do extrator (existia só pro sol do dusk); componente
solto de qualquer tamanho agora é descartado do front. Nuvem cruza o
sol por cima e continua cortada pelos morros. REGRA DE CAMADAS do céu:
astro assado (sol/lua) < nuvem móvel < silhueta de montanha.

**Ciclo 56 (entregue — espelho vertical sob o strip, 06/Jul):** feedback:
"o background é espelhado no lado, espelhe também embaixo pra preencher".
drawStripMirrorBelow: espelho vertical do próprio PNG abaixo da base
(quad pula as 46 linhas do rodapé degradado — emenda limpa), substituindo
o degradê chapado do c47. v5.9.2 (iterado com o usuário): espelho
completo mostrava CÉU INVERTIDO no fundo ("precisa inverter para que o
fundo continue o fundo") → versão final espelha SÓ A FAIXA DE TERRENO
(26px de fonte acima do rodapé pulado) em PING-PONG descendo até o fim
do frame — floresta espelha floresta, montanha espelha montanha, nunca
chega no céu. Emendas sempre casam (alternância flip/normal).
_quadCache novo (limpo no clearCache). v5.9.3 (feedback: "bioma 5
ficou zoado"): o seam começava em `yTop + (ih-46)*sx` — 46 linhas-fonte
ANTES do fim do strip — SOBRESCREVENDO arte real (árvores/névoa do
marsh viravam padrão Rorschach espelhado). Fix: `seamY = floor(yTop +
ih*sx)` (fim REAL do strip). v5.9.4 (feedback: "é como se fosse uma
continuação da parte debaixo do principal mas de cabeça para baixo"):
faixinha ping-pong ABANDONADA — agora é o STRIP INTEIRO espelhado
verticalmente abaixo do seam (reflexo verdadeiro). Pegadinha: vários
PNGs terminam num rodapé chapado que degrada pra preto; espelhar da
última linha bruta DOBRAVA a faixa preta (canto preto gordo nos biomas
2/3/6). Solução: MIRROR_JUNK por bioma (medido por variância de linha,
scratchpad/measure_footer.py: fields 8, highlands 14, abyss 7, frost 0,
marsh 1, dusk 12) — o reflexo pula essas linhas na fonte E cobre o
rodapé do strip real, seam idêntico nos dois lados. Marsh junk=1 é o
que protege a arte de árvores/névoa dele (o Rorschach do v5.9.2 era
skip 46 fixo). Validado nos SEIS biomas em wide (mir7_w1..w6) — lição:
mudança no espelho exige captura dos 6, não só dos 3 primeiros.
Sequela (feedback: "linha preta em baixo nos _front"): as camadas
_front carregavam o MESMO rodapé chapado (100% opaco) e desenham
DEPOIS do espelho — re-pintavam a faixa preta por cima do reflexo.
Sequela 2 (feedback: "não é só o front, o normal também tem — algumas
gerações vieram assim"): solução DEFINITIVA foi CROPAR o rodapé fora
dos PNGs (scratchpad/crop_strip_footer.py): fields 112→104,
highlands 101→87, abyss 105→98, marsh 112→111, dusk 112→100 (frost já
era limpo). Base e front cortados JUNTOS — precisam de dimensões
idênticas pro stripTransform compartilhado alinhar a oclusão. Com os
assets limpos, MIRROR_JUNK e FOOT_JUNK foram REMOVIDOS do código
(espelho volta a ser o strip inteiro, sem quad). Se regenerar um strip
no PixelLab: medir rodapé (measure_footer.py) → cropar base+front
juntos (crop_strip_footer.py) → rodar o extrator.

**v5.10 (feedback nuvens):** cloud_1.png APAGADA do jogo (usuário não
gostou dela) — todas as nuvens usam variant 0 (cloud_0). Menos nuvens
(near 6→4, far 5→3) e banda mais alta: near yr 0.07..0.40 (era
0.10..0.60), far yr 0.05..0.25 (era 0.06..0.34).

## ⭐ v6 — Overhaul visual "sair da cara de protótipo" (Jul/06, autônomo)

Plano: `docs/plan/worldroad-visual-v6.md` (pesquisa: fóruns LÖVE, source do
Balatro em E:\dev\projects\balatro-source\, PixelLab MCP — resumo em
memory/research_libs_pixellab.md). 7 passos entregues, cada um validado com
captura dos 6 biomas (modo `all` do screenshot tool = 1 processo GL) +
travel/fork/blend6. Commits d1a009f → 1f638d1.

**Infra nova (helpers no WorldRoad.lua):**
- `gradTex()` — `_gradV` (1×256, alpha 1→0 vertical) e `_gradH` (256×1
  horizontal), filtro LINEAR. **Deliberadamente Image, não Mesh** (driver
  NVIDIA histórico 0xC00000FD — Image é o caminho GL já provado). Escalar
  y por `px/256`; alpha negativo no scale = gradiente invertido.
- `glowTex()` — 128×128 radial `(1-d²)²` pra glows aditivos.
- `sunShadowDir(g, x, w, px)` — offset horizontal normalizado [-1,1] da
  sombra AFASTANDO do celestial do bioma (`cel.xr`); fallback g.cx.

**v6.1 (d1a009f) — suavização de banding:** vinheta inferior (gv preto
0.32) + laterais (gh 0.16); banda de névoa do horizonte redesenhada com
gradiente contínuo (era 20 rects); crest fog por coluna com fade
horizontal `1-(dx/halfW)²`. DESCOBERTA: drawSky/drawCelestial são
INVISÍVEIS (strip cover cobre o céu todo) — re-escopo do passo pra
suavizar o que APARECE, não o céu procedural.

**v6.2 (56ac929) — haze atmosférico:** wash de gradiente (cor fog, alpha
0.16) da crista pra cima + colunas nas extremidades até crestYAt —
separação tonal longe/perto (perspectiva aérea de verdade).

**v6.3 (a246f1e) — luz global coerente:** `sunShadowDir` aplicado em TODAS
as sombras (props 0.16, companheiras, cercas 0.14, marcos do fork 0.14,
landmark 0.14, castelo 0.20) — sombras apontam pro lado oposto do sol do
bioma. Castelo ganha RIM LIGHT aditivo (cópia deslocada 2px na direção do
sol, cor do celestial, alpha 0.28) antes do draw principal.
⚠️ **REMOVIDO no v7**: cópia aditiva sobre sprite pixel art virava
franja/mancha de cor. Só o `sunShadowDir` (sombras direcionais) sobreviveu.

**v6.4 (06815f9) — janelas acesas:** `CASTLE_GLOW_K` por bioma (fields
0.45 … abyss/dusk 1.0); glow de corpo (1.25×iw, âmbar 0.11×gk) + glow de
portão (0.55×iw, laranja 0.18×gk), pulso `0.86+0.14sin(1.7t)`. Só quando
castelo 100% opaco (não vaza no crossfade).
⚠️ **REMOVIDO no v7** junto com o rim light (halos translúcidos manchavam
o sprite — as janelas acesas já estão DESENHADAS no PNG do castelo).

**v6.5 (95b35e7) — chão rico:** dither nas bordas da estrada (3 iterações
de px estrada-fora + grama-dentro por rowId novo — mata a linha dura);
grama com 16 acentos + 26 pares de lâminas claras no tile; banda de luz
na crista do domo (aditivo 0.06, 30% da altura, por coluna).

**v6.6 (c194d9a) — vida ambiente:** god rays (2 raios, 2 polígonos
aninhados soft-edge, aditivo ~0.03-0.06 oscilando) gated por `RAY_K`
(abyss/dusk = 0 — sol no horizonte não faz raio de cima); fumaça do
castelo com halo suave (glowTex 2.6× + core pixel); **room sway Balatro**
(update_canvas_juice): push/translate senoidal ±1.5px/rotate 0.0012/scale
1.006/pop — termina ANTES de fork marks/pills (hitboxes de mouse ficam
fora do sway).

**v6.7 (1f638d1) — enquadramento cinematográfico:** state grade
full-frame (travel+encounter = vermelho 0.045; travel normal = âmbar
0.04). ⚠️ O framing de árvores-silhueta nos cantos foi **REMOVIDO no
v6.8.1** — feedback direto do usuário ("oq diabos é essas coisas pretas
nos cantos"): silhueta chapada de sprite reusado lia como mancha preta,
não como folhagem. NÃO reintroduzir como estava; se a moldura da
referência voltar, precisa de sprite de folhagem DETALHADO dedicado
(PixelLab, primeiro plano, com cor/textura), nunca tint quase-preto.

**v6.8 — validação integral:** full1-6 (modo all) + travel + fork +
blend6 revisados: pills do fork legíveis sobre o framing, blend atravessa
as camadas novas sem rasgo, espelho sem emenda. LIÇÃO DE PROCESSO (falso
wedge): burst de captura com o jogo do usuário aberto reproduziu 0xC00000FD
até no trivial — NÃO era driver envenenado; resolveu sozinho quando ele
fechou o jogo. Protocolo: checar `Get-Process love,lovec` antes de
capturar, re-testar trivial após ~1min antes de alarmar (detalhe no
memory global nvidia-driver-love-crash).

**Backlog v6 (documentado, não pedido):** vendorizar moonshine/flux/anim8
(veredito ADOTAR em research_libs_pixellab); tileset Wang PixelLab pra
transição estrada↔grama; lanterna + props animados (fogueira/bandeiras
via animate_object); passe de luz canvas add→multiply caseiro.

## ⭐ v7.1 — GrassField: motor dedicado de grama (Jul/06)

Pedido explícito do usuário: "engine só pra grama... física, movimentação
fluida... populado no terreno todo... base pra tudo". Contexto: o v7
anterior REVERTEU duas abordagens rejeitadas — (a) assets PixelLab
avulsos enfiados no terreno ("não faz o menor sentido"), (b) luzes
translúcidas do v6 (god rays/glows/rim/faixa de crista — "pixel
transparente de cores estranhas"). REGRA APRENDIDA: luz e detalhe em
pixel art se DESENHAM na paleta (opaco); véu com alpha lê como mancha.

**engine/GrassField.lua** (novo, reutilizável, não conhece o WorldRoad):
- Lâminas individuais num SpriteBatch (atlas 9 células 8×16 em TONS DE
  CINZA: corpo 0.60, raiz 0.45, ponta 1.0 → 1 tint por lâmina produz o
  gradiente raiz-escura→ponta-clara; 6 finas + 2 largas/junco + 1 flor).
- VENTO em 3 camadas (padrão Guerrilla/Horizon adaptado a 2D): frente de
  rajada viajante (sin(fase espacial − t·gustSpeed), vales calmos) +
  brisa local (2 senos por posição) + jitter de ponta (cresce na rajada).
- Física da lâmina: cisalhamento kx com PIVÔ NA RAIZ (base fixa, ponta
  desloca kx·altura — GPU Gems cap.7) + encurtamento sy∝|lean|
  (projeção 2D do dobrar, truque do fórum Defold) + flexibilidade por
  lâmina (hash) — nunca movem em bloco.
- População ESTATELESS mundo-ancorada (hash por célula z×slot, sem
  spawn/reciclagem), margem da estrada→campo aberto, some no fork,
  invade de leve a borda do caminho (half*0.94).
- PRESETS por bioma (densidade/altura/vento/junco/flor): fields brisa
  1.0; highlands vento forte de montanha; abyss restolho ar-parado 0.55;
  frost tundra rala 0.5; marsh juncos altos 1.15/1.30 broad 0.30; dusk
  trigo dourado flor 0.12. CORES não ficam no preset — vêm do envColor
  do chamador (lerpam de graça no crossfade de bioma).
- WorldRoad: drawGrass injeta geom/roadCenter/roadHalf/cores; chamado
  DEPOIS de drawRoad; definido DEPOIS de FORK_REL (lição ciclo 41).
  drawTerrainDetail mantém só as lombadas de relevo (arcos latitude,
  aresta clara + vinco escuro). clearCache limpa o GrassField.
- VALIDAÇÃO DE MOVIMENTO: modo `grass` no screenshot tool — 2 capturas
  do mesmo frame com Δ1.1s no MESMO processo; diff provou lâminas
  balançando (90k px alterados, tufos fixos no lugar = vento, não ruído).
- Perf: ~2-4k batch:add/frame (1 draw call), ~20k sin/frame — folga.

**Evolução v7.2→v7.4.6 (mesma noite, feedbacks em sequência):**
- v7.2 campo cheio até a crista + contraste adaptativo por luminância;
- v7.3 vento v2 (2 frentes incomensuráveis + vorticles + respiração
  ~20s + relógio por lâmina + inércia de junco + flicks + seco/viçoso);
- v7.4 TAPETE 100% (moitas 16×16 pré-assadas, fileiras far→near com LOD
  em espaço de tela) — "quero 100% em tudo";
- v7.4.1 ancoragem 100% MUNDO (decimação ci%M potência de 2 + fração
  fixa de largura + jitter z por moita) — "movimento fica estranho";
- v7.4.2 perf: bench A/B no screenshot tool (cena 4.5ms sem grama,
  7.6ms com; 60fps ok), rowCache, vento em grade 13 amostras+lerp,
  baldes de cor;
- v7.4.3 tapete até t>0.002 (corte 0.03 deixava careca AMPLIFICADA nas
  laterais pela geometria — prova magenta + log LOD, gated GF_DEBUG);
- v7.4.4 FRANJA DA CRISTA (moitas sentadas na curva do horizonte,
  estáticas, pulam castelo/estrada; inimigo emerge POR TRÁS do capim);
- v7.4.5 nascimento natural: broto com stagger (rc.born), jitter z FIXO
  (era ×M — pulava na troca de LOD), rampa espacial dos acentos
  (t 0.18→0.28) — "grama brotava do nada";
- v7.4.6 3 ALTURAS ponderadas pela distância da estrada (rasteira na
  beira → alta na parede de floresta; |lf| estático decide o tier =
  nunca muda em movimento; hMul SÓ na altura — largura cobre o chão).

**v7.5 (f6db66e, Jul/07) — fatias intercaladas com as árvores:**
`GrassField.draw()` aceita janela de profundidade (`relFrom`/`relTo`) e o
WorldRoad intercala fatias de capim entre os props (painter real: capim
na frente do pé da árvore COBRE o pé). Cuidados que a fatia exige:
detecção de câmera-em-movimento por FRAME via `ctx.time` (por chamada
daria "parado" da 2ª fatia em diante); poda do rowCache 1×/frame com a
janela COMPLETA da câmera; range de células limitado à janela da fatia
(sem isso: 17ms/frame); ctx construído 1×/frame e reutilizado entre as
fatias (~200 alocações/frame de tabela+closures a menos).

⭐ **REGRA GERAL (pedido explícito do usuário, Jul/07): essa lógica vale
pra TODO elemento futuro da cena.** Qualquer coisa nova que viva no campo
(pedra, animal, personagem, efeito, prop) entra no painter INTERCALADO
por profundidade (`rel`) — nunca em camada global por tipo. Na frente do
pé de uma árvore = desenha depois dela; atrás = antes. Inclui a grama
(janelas `relFrom`/`relTo`) e a luz (`LightEngine.submitOccluder` com
`z`). Elemento em camada plana por cima do campo é BUG, não estilo.
(Também registrado nos anti-patterns do CLAUDE.md.)

Backlog natural do motor: dobra interativa (inimigo/herói passando),
sombra de rajada (escurecer levemente onde gust>0.7 — DESENHADO, não
véu), wind dir global por bioma no update dos props (hoje só a grama).

**Próximos ciclos (fila fina — plateau de qualidade atingido):**
14. Sfx da viagem — DESBLOQUEADO Jul/10: key ElevenLabs na memória auto
    do Claude (elevenlabs-api-key); pipeline audio/sfx/ já rodou pro
    hover do fork (v9.6)
21. Aguardar feedback do usuário jogando (viagem/blends/interiores em MOTION
    é onde os ciclos 3-12 aparecem; stills já validados)

## v9.5 (Jul/10) — LUGARES VIVOS do fork (fogueira/casa/bandeira/elite/tenda)

Feedback: "a fogueira está estática, isso é estranho — o mapa todo se
movimenta"; "a sombra não sai do pé da casa, sai mais pra frente dela".

- **Frames PixelLab por landmark** em `assets/sprites/world/anim/<key>/0..8.png`
  (mesma receita das luminárias v9.1; loader compartilhado `readAnimFrames`).
  `LANDMARK_ANIM` define fps + `pingpong` (pano/brilho vai-e-volta — loop
  reiniciando no frame 0 dá "pulo"; fogo corre o loop). Fase própria por
  braço (`i*3.7`) e `_landmark.phase` herda a fase do braço escolhido →
  frame NÃO pula no handoff fork→lugar. ⚠️ fase = `seed % #frames` direto;
  multiplicador 7.31 com seeds `i*3.7` caía quase em uníssono (27.05≈3×9).
- **Sombra na BASE DA PAREDE** (`LANDMARK_SHADOW_PAD`: shop 12, event 5,
  chest 6): nesses sprites as últimas linhas são escada/deck/baú avançando
  pro 1º plano — a silhueta-sombra nascia na PONTA disso ("na frente" da
  casa). footPad do ShadowEngine + feetY sobe `pad*s`. Medido por
  opacidade/linha (largura < ~75% da máxima = saliência, não parede).
- **Micro-luz do lugar** (`LANDMARK_LIGHT`): fogueira quente, obelisco
  roxo, janelas da casa, orbe da tenda — âncora pelo scan de conteúdo do
  LuminaireEngine (centróide dos pixels claros; bid "landmark" fora do
  catálogo é nil-safe), flicker de fogo, `submitMicro` com z=rel (árvore
  na frente oclui). Bandeira NÃO emite luz.
- **Fumaça da chaminé da casa** (`LANDMARK_SMOKE`/`drawLandmarkSmoke`):
  puffs determinísticos (função pura do tempo, doutrina GrassField) no
  idioma do castelo (quadrados chunky, sem halo), no MESMO slot de
  profundidade; gate `ih*s < 46px` (longe vira ruído). Boca da chaminé
  medida no PNG (xf=0.325, yf=0.02).
- **drawLandmarkFront agora tem paridade com o fork**: frames + fumaça +
  micro-luz + occluder flatColor (antes o lugar "chegado" apagava à noite).
  Occluder extraído pra `submitLandmarkOccluder` (um lugar só).
- Validação dos frames: frame0 == PNG base BIT A BIT (âncoras/scan
  continuam válidos), atividade 400-2000px/frame concentrada onde deve
  (máscaras de diff: chamas/pano/janelas/runas/orbe; corpo estático).

## v9.6 (Jul/10) — HOVER dos lugares: reação + som (ElevenLabs)

Feedback: "quando passar o mouse, a animação poderia ser diferente ou
emitir algum som — fogueira mais forte com som de brasa, casa com porta
abrindo e barulho de porta".

- **Relógio de animação POR BRAÇO** (`f._animT[i]` acumula `dt·fps`):
  hover multiplica a velocidade (`hoverFpsK` 1.6-1.8 — fogo cresce, vento
  venta) SEM pular frame (relógio absoluto, não time·fps). A chegada
  (`_landmark.phase`) recebe `animT − time·fps` pra continuar contínua;
  o mod da fase usa o PERÍODO real (pingpong = 2n−2, não n).
- **Porta da casa = anim de ESTADO** (`hoverAnim = "landmark_shop_hover"`,
  frames em `anim/landmark_shop_hover/`): progresso `f._hoverK[i]` 0→1
  (abre a 2.6/s no enter, fecha a 3.2/s no exit), indexa o frame direto —
  substitui o loop de janelas enquanto > 0.02. A anim PixelLab repinta a
  fachada com bloom de luz quente antes da folha abrir — mantido (lê como
  "a casa te recebe" na escala do fork); se incomodar, mascarar só a
  região da porta em composite offline.
- **Som por lugar no ENTER do hover** (`LANDMARK_HOVER_SOUND` →
  `Sfx.playWithVariation(snd, 1.0, 0.06)` — pitch anti-fadiga Balatro):
  forkHoverFire/Door/Flag/Elite/Tent, gerados no ElevenLabs
  (sound-generation, 1.4-2.0s) em `audio/sfx/fork-hover-*.mp3`,
  registrados no main.lua (0.50-0.60). Key do ElevenLabs: memória
  auto do Claude (`elevenlabs-api-key`) — free tier, usuário rotaciona.
- Micro-luz do lugar ganha boost ×1.4 na intensidade durante o hover.
- Convergência: hover congela (sem som/aceleração), porta fecha sozinha.

## v9.7/v9.7.1 (Jul/10) — CENÁRIO INTERATIVO (mapa vivo estilo Hearthstone)

- **Clique em prop** = pêndulo amortecido na base (`pokeRot`, amp por kind
  em POKE_AMP) + som por kind (POKE_SOUND: rustle/wood/lamp/stone/chime,
  fogo e chime REUSAM os sons do fork). Copas soltam 5 folhinhas
  (`drawLeafFx` — cor do bioma, deadtree solta lasca marrom, MESMO slot
  de profundidade). Cerca com pássaros pousados: `_scareBirds` → voam.
  Poste clicado: a CHAMA acompanha o pêndulo (`fx += rot·(gy−fy)`) —
  luz e brasas seguem juntas.
- **Registro de hit POR FRAME** (`WorldRoad._hitScene`, zerado no início
  do draw): nuvens se registram no drawClouds, props no drawList — ordem
  do painter; `pokeSceneAt` varre do fim (mais perto primeiro). Validação:
  modo `poke` no screenshot tool (varredura de grade → 56 alvos, 0 erros).
- **Nuvens**: deriva ×1.6 + bob ±4 ("muito estáticas") e clique = squash
  & stretch amortecido com origem no centro.
- **Rajada do mouse na grama**: `GrassField.pokeAt(nx, wz, t)` +
  `pokeLean` somado nos call sites das lâminas/flores (NÃO dentro do
  windAt — os call sites passam relógios ESCALADOS, o envelope precisa do
  tempo real do ctx). Conversão mouse→mundo: tl linear pela banda vertical
  → `wz = camZ + REL_CREST·(1 − tl^(1/T_POW))`. Swish throttled 1.2s.
- **Entrada dos cliques**: fork miss → poke (forkMousePressed); estado
  playing → GameplayScene.mousepressed agora RETORNA consumo e o main.lua
  poka o que sobrou (botão 1); cardReward → CardRewardScreen já retornava
  consumo, main.lua poka no miss. cardReward também passou a rodar
  `WorldRoad.update(dt)` (run mode) — o mundo continua vivo atrás das
  ofertas (anims/vento/nuvens e o juice dos pokes).
- ⚠️ **v9.7.1 (crash em produção)**: `GrassField` era `local` declarado no
  MEIO do arquivo — o `update()` (textualmente antes) via global nil →
  "attempt to index global 'GrassField'". Require movido pro TOPO. É a
  MESMA lição do ciclo 41 (forkOffset): local declarado depois não existe
  pra função de cima. Checar sempre que um sistema novo entra no update.

**v9.7.2 (feedback: material/naturalidade/demo):**
- **Som por MATERIAL**: `POKE_SOUND_BIOME` (bid→kind→som) sobrepõe o
  default — poste de MADEIRA (fields/marsh/dusk lantern) usa
  `sceneLampWood` (rangido de madeira novo); ferro (highlands/frost)
  segue `sceneLampCreak`. Ao adicionar luminária nova, conferir material.
- **Rajada da grama v2**: a tremida senoidal 15Hz lia como vibração
  mecânica ("não ficou natural") → onda que PARTE do cursor (lâmina à
  esquerda deita pra esquerda, side = sign(dx)), swell único
  `min(1,e·10)·exp(−4e)`, amp 1.9; a brisa própria da lâmina traz a
  organicidade por cima.
- **Poof da nuvem regenerado** (sopro fofo abafado, sem tom/squeak).
- **Demo (`love . demo_worldroad`)**: agora valida TUDO por bioma —
  `setupAudio()` próprio (love.load do main não roda em modo tool;
  AudioManager:new se auto-inicializa), tecla **F cicla 2 conjuntos de
  fork** (6 tipos de lugar), mouse real (fork clicável + pokeSceneAt),
  rajada da grama funciona (polling no update). 1-6 troca bioma, T hora.

(seção v9.7 antiga removida — duplicava a de cima e dizia "cutucar só na
encruzilhada", que o v9.7.1 tornou obsoleto. Extra que valia: POKE_AMP
copa 0.085 / monolito 0.03; folhinhas 1.6s; volumes scene 0.26-0.36;
validação = modo `poke` do screenshot tool, 56 alvos sem erro.)

## v9.8 (Jul/10) — CASTELOS VIVOS (bandeiras + janelas + fogo/olhos)

Feedback: "castelos totalmente estáticos; janelas podiam ter luz,
bandeiras paradas". Frames em `anim/<bid>_castle/0..8.png`, troca no
`drawCastleOf` via `landmarkFrame(bid.."_castle", fase-por-bioma)` —
entradas fps/pingpong na LANDMARK_ANIM (pingpong em todos).

⚠️ **LIÇÃO NOVA: PixelLab v3 NÃO segura sprite grande parado.** Nos
landmarks (5-9k px de conteúdo) o "perfectly static" funcionou; nos
castelos (~35k px) a cantaria INTEIRA ferveu (15-28k px de atividade!)
e no highlands o modelo INVENTOU janelas acesas. Receita que funcionou —
**COMPOSITE CIRÚRGICO** (scratchpad `castle_compose.py`):
- frame final = PNG base 100% + (a) PASTE dos rects bons da anim
  (bandeiras/estandartes/fogo do portão — auto-detectados por cor:
  vermelho saturado no topo com V alto pra não pegar tijolo; dusk = rect
  MANUAL, telhado rosa confunde) + (b) PULSO PROCEDURAL das janelas
  (pixels no hue da luz do bioma, sat/val por castelo, denoise ≥2
  vizinhos — EXCETO highlands: os olhos são 8px e morrem no denoise)
  com dim progressivo por frame (f0=base; o pingpong do runtime faz a
  respiração) e profundidade por pixel via hash (orgânico).
- Calibrações que importaram: marsh val 0.72 (senão pega o MUSGO todo),
  dusk sat 0.55/val 0.65 (senão pega tijolo dourado), abyss flag_val
  0.58 + banda y<0.26h (senão pega tijolo vermelho torre abaixo).
- Resultado: atividade 8-2733px CONFINADA, estrutura pixel-idêntica,
  frame0 == base bit a bit. Por castelo: fields 2 bandeiras + janelas
  quentes · highlands 2 OLHOS do portão (depth 1.8×) · abyss 2
  estandartes + fogo do portão + janelas brasa · frost janelas ciano ·
  marsh luz-bruxa verde · dusk pennant do pináculo + ouro do portão.
- O compose SOBRESCREVE os frames — originais do PixelLab só no zip do
  objeto-âncora (re-extrair antes de recompor com regras novas).

## v9.9 (Jul/11) — CASTELOS v2 (arte re-alinhada ao bioma)

Feedback: "castelos meio diferentes da arte do restante do conjunto".
Análise de estilo (props + paletas): pixel art sombria/pintural, formas
desgastadas, 1 hue por bioma. Veredito: fields/dusk/highlands REFEITOS
(cinza-limpo/tijolo-alegre/raso), abyss/frost/marsh mantidos (desafiantes
gerados perderam — viraram "cena com fundo").

- **Geração** (`create_map_object` 224×200, view=side, selective outline,
  detailed shading, high detail): prompts com o PADRÃO portão + janelas
  acesas + bandeiras + paleta do bioma. ⚠️ Em canvas grande o modelo
  PINTA FUNDO mesmo pedindo isolado (os 6 vieram 100% opacos; highlands
  v1 veio com lua/céu/montanha — regen com "one single isolated building
  on a plain flat solid background" + lista de negativos resolveu o fundo
  ficar CHAPADO). Remoção: flood-fill das bordas (cor = moda da borda)
  + manter só o maior componente (mata estrelas/ilhas). Crop bbox.
- **Highlands = torre-vigia** (bioma "Colinas da Torre"): 164×171,
  estreita — exigiu fix no drawCastleOf: baseScale agora divide por 218
  FIXO (densidade de pixel constante; dividir por iw esticava qualquer
  canvas pra mesma largura). Manteve os OLHOS no portão + fogueirinha.
- **lightWindows re-derivados por conteúdo** (clusters de pixels
  saturados no hue da luz) e atualizados no biomes.lua pros 3 novos.
- **Animação**: mesma receita v9.8 (animate_object + composite cirúrgico).
  ⚠️ Slug de descrição COLIDE no zip (fields novo × velho = mesma pasta,
  18 arquivos com nomes duplicados) — desambiguar por DIMENSÃO do
  frame_000, quebrando o infolist em runs que começam em frame_000.
  Anims antigas de fields/highlands/dusk REMOVIDAS do disco na troca da
  arte (frames velhos + base nova = castelo antigo aparecendo).
- Resultado: f0==base bit a bit; movimento confinado (fields 1.9k px =
  2 bandeiras+janelas; highlands 733 = olhos/fogo do portão+frestas;
  dusk 3.2k = 3 flâmulas+janelas+portão). Screenshot em cena validado.

## v9.9.1 (Jul/11) — castelos v3 (highlands/abyss/marsh) + conserto do dusk

Feedback: fields = padrão-ouro; highlands "fino e estranho", abyss/marsh
refazer na linguagem do que deu certo; dusk ótimo mas com BURACOS
transparentes in-game.

- **Buracos do dusk**: o flood-fill tol 30 VAZAVA pras sombras escuras do
  castelo (≈ cor do céu pintado). Receita definitiva de extração:
  flood tol 14 + PEEL de borda (2 anéis, tol 34 — franja de céu na
  silhueta) + ilhas: manter maior componente E qualquer ilha ≥24px
  (ponta de bandeira separada não pode sumir). 490px restaurados;
  recompose em cima da base reparada (rects sem buracos → paste seguro).
- **v3 = massa do fields** (corpo + 2 torres + portão + janelas +
  bandeira) com material do bioma: highlands ardósia/janelas de FOGO
  âmbar/bandeira azul; abyss rocha carbonizada/veias de brasa/portão em
  chamas/2 bandeiras; marsh pedra verde-negra/musgo/chamas-bruxa no
  portão/bandeira verde. lightWindows re-derivados (marsh: filtrar musgo
  claro — só portão+janela viram âncora).
- Compose: flag_match ganhou blue/green; gatefire com fire_hue por bioma
  (marsh verde). Pulso do marsh pega brilhos de musgo → piscam como
  ESPOROS (combina com o ambient do bioma — mantido de propósito).
- ⚠️ **v3 pode DEGENERAR no fim da sequência** (abyss: fogo explodiu
  branco pra fora do arco nos frames 7-8) — inspecionar a cauda e
  TRUNCAR (loader aceita qualquer nº de frames; pingpong segue suave).
  Abyss ficou com 0..6.
- Slugs de anim SEMPRE distintos entre versões (colisão de pasta no zip);
  desambiguação por dimensão continua como rede de segurança.

## v9.9–v9.9.2 (Jul/10-11) — CASTELOS REGENERADOS (arte alinhada ao bioma)

Feedback: "castelos meio diferentes da arte do resto do conjunto". Análise
props+paletas → estilo alvo: pixel art sombria/pintural, formas desgastadas,
hue dominante por bioma. Novos gerados via `create_map_object` 224×200
side/selective outline/detailed shading/high detail; **fields virou o
padrão-ouro** (corpo largo + 2 torres + portão + janelas acesas + bandeiras)
e os demais seguiram essa massa. Estado final: TODOS os 6 castelos novos
exceto frost (mantido — desafiante perdeu). Escala do drawCastleOf agora é
por DENSIDADE DE PIXEL constante (÷218 fixo, não ÷iw).

**Lições de geração (sprites grandes):**
- Modelo PINTA FUNDO em canvas grande mesmo pedindo isolado → prompt
  "one single isolated building on a plain flat solid background" +
  negativos (no sky/moon/clouds/landscape) e extração determinística.
- **Extração segura** (`castle*_pipeline.py`): flood-fill das bordas com
  tol 14 + peel 2 anéis (tol 34) + ilhas <24px removidas (≥24 preservadas
  — ponta de bandeira solta). Tol 30 direto VAZA pras sombras do corpo
  (dusk ficou com 490px de buraco — "partes transparentes").
- **Portão tem que ser PORTA FECHADA no prompt** ("CLOSED by a heavy
  wooden double door"): arco aberto o modelo pinta com a cor do fundo →
  vira buraco transparente na extração (highlands v3, 338px no portão).
- "perfectly frontal symmetrical view facing the viewer" resolve castelo
  de lado.
- Anim v3 pode DEGENERAR nos frames finais (abyss: fogo explodiu branco
  nos f7-f8) → validar filmstrip e TRUNCAR a cauda (loader aceita
  qualquer contagem; pingpong continua suave com 7 frames).
- Slug de pasta no zip = 50 chars da descrição → anims com prefixo igual
  COLIDEM (entradas duplicadas); desambiguar por DIMENSÃO do frame_000
  em runs consecutivos do infolist.

**v9.9.2 — LUZ DOS CASTELOS UNIFICADA** (feedback: "luz do castelo é um
quadrado estranho, usa o motor dos postes"): janelas do castelo e
micro-luzes dos landmarks migradas do `submitMicro` cru (raio grande =
bloco no lightmap ¼) pra receita do LuminaireEngine: `LightEngine.submit`
(glow dither 0.28/levels 8, raio ×1.5-1.6, intensidade ×0.55) + núcleo
`submitMicro` pequeno (×0.45), AMBOS com flicker de fogo e fase própria
por janela. lightWindows re-derivados por conteúdo a cada arte nova.

(GrassField: rajada de hover do mouse foi REMOVIDA em edição externa —
vento ambiente ×1.45 no lugar; pokeAt/pokeLean seguem no arquivo sem
chamadores. Não reintroduzir.)

## v9.9.x (Jul/10-11) — SAGA DOS CASTELOS v2→v6 (regeneração por bioma)

Iterações guiadas pelo usuário até os 6 castelos ficarem no mesmo nível.
Estado FINAL: fields v2 (arruinado musgo, padrão-ouro do usuário) ·
highlands v6 (cidadela gótica em camadas, estandarte + janela-catedral) ·
abyss v3 truncado 7 frames (vulcânico, veias de brasa + portão em chamas) ·
frost ORIGINAL (venceu o desafiante) · marsh v5 (cidadela alagada,
torreão redondo + cogumelos brilhantes, anim 100% procedural) · dusk v2
reparado (ameixa, 3 flâmulas douradas).

**Regras de PROMPT aprendidas (usar SEMPRE em prédio grande):**
- Palavra de ambiente ("under moonlight") = modelo pinta lua/céu/montanha
  COLADOS na silhueta → inextraível. Usar "pale highlights on the bricks".
- "one single isolated building centered on a plain flat solid gray
  background" + negativos (no sky/moon/clouds/mountains/landscape/ground).
- Portão: "large arched gateway CLOSED by a heavy wooden double door" —
  arco aberto o modelo pinta com a COR DO FUNDO → vira buraco transparente.
- Vista: "perfectly frontal symmetrical view facing the viewer".
- Silhueta rica: "tall central keep rising HIGH BEHIND the gatehouse wall,
  towers of DIFFERENT heights, layered depth silhouette" — sem isso vem
  "muralha + 2 torres" (caixote, reclamação do usuário).
- Escala drawCastleOf agora é DENSIDADE DE PIXEL fixa (ref 218px) — arte
  estreita renderiza estreita (não estica pro mesmo w).

**Extração (scratchpad castle*_pipeline.py):** flood borda tol 14 + peel
2 anéis (tol 34) + ilhas <24px removidas (estrela pintada some, ponta de
bandeira fica). Tol alta (30) VAZA pras sombras do corpo = buracos
(dusk teve 490px restaurados). Cena entranhada (lua/montanha na silhueta)
= regenerar, não operar.

**Anim/composite:** paste rect só das bandeiras/fogo (anim v3), janelas
SEMPRE pulso procedural (dim progressivo, hash por pixel). Anim v3
degenera no fim às vezes (abyss: fogo branco explodindo nos frames 7-8 →
TRUNCAR a cauda; loader aceita qualquer contagem). Colheita do zip:
slugs de 50 chars COLIDEM entre versões → desambiguar por DIMENSÃO do
frame_000, runs consecutivos na ordem do infolist.

**Luz (v9.9.2):** janelas do castelo e micro-luzes dos landmarks usam a
receita do LuminaireEngine (LightEngine.submit glow dither levels=8 +
submitMicro núcleo 0.45r + flicker fire por janela) — o submitMicro cru
de raio grande virava BLOCO quadrado no lightmap ¼ (reclamação).
lightWindows re-derivados por conteúdo a cada troca de arte (v9.9.3:
highlands 4 âncoras, marsh 4 âncoras com base dos cogumelos).

## v10 (Jul/11) — ENTRADA NO CASTELO (reset por bioma + cerimônia da porta)

Pedidos: castelo reseta pra longe na troca de bioma; limite de aproximação
mapeado por bioma (sem corte/flutuação); boss = máximo perto; entrada
imersiva com a porta abrindo + som.

- **Âncora de trecho** (`_segBase`, set no setBiome que MUDA): progress =
  (camZ − segBase)/SEGMENT_LEN — SEM módulo (o módulo antigo dava a volta
  no meio do ato). `_segBasePrev` mantém o castelo em crossfade na
  distância antiga (sem pipocar). Andando o progress trava em
  APPROACH_WALK_MAX (0.80); o 1.0 final é da cerimônia (`_approachBoost`).
- **CASTLE_APPROACH por bioma** (growth do fim, "mapeado e salvo") +
  CLAMP analítico `s ≤ (crestY − y − 6)/(ih·(1−sink))` — topo nunca corta,
  pra qualquer arte. Calibração visual: screenshot `gate1..6` (agora com
  boost=1 = visão do boss). Na CERIMÔNIA o clamp RELAXA
  (`sMax·(1 + boost·1.3)`): o castelo cresce além do enquadramento (pé da
  muralha, olhando pra cima) e o portão domina a cena — validado no gate3
  (portão de fogo do abyss preenchendo o quadro no fim da estrada).
- **Cerimônia `WorldRoad.enterCastle{approach, onComplete}`** (update):
  walk 1.3s (boost→alvo, boss 1.0/elite 0.82) → door 1.4s (frames de
  `anim/<bid>_castle_door/` indexados por doorK + som castleGateOpen ou
  castleGateMagic p/ abyss/dusk) → push 0.9s (boost×1.05 + fade preto)
  → onComplete. GameplayScene: `interior`/`worldBattle`/inimigo/HUD
  ganharam gate `not WorldRoad.isEntering()` (a cena segura na estrada até
  o fade); entryFade() desenhado junto do interiorFade (preto contínuo:
  entry escurece ATÉ, interiorFade revela DO preto); mousepressed engole
  cliques na cinemática; o gatilho é o floorKey change com node
  boss/mini_boss/elite (antes ia direto pro interior com fade seco).
- **Portas**: 6 anims PixelLab (porta abre; abyss = fogo se parte; dusk =
  surto dourado), composite SÓ no rect do portão (auto-detect: diff
  f0-vs-f8 no centro-baixo, dv>40) — frame0 == base bit a bit.
  ⚠️ Slug do zip corta em 50 chars NO MEIO da palavra — keyword de colheita
  tem que ser prefixo-seguro ("iron_bands_swin", não "..._swinging").

  **⚠️ ABYSS — a porta que nascia do nada (Set/2026, REGERADO).** A
  fortaleza do abismo NÃO TEM PORTA: tem um arco em CHAMAS. A anim antiga
  apagava o fogo e descia uma laje de pedra no vão. A primeira tentativa de
  conserto TRUNCOU em 7 frames ("f7-f8 materializavam uma porta fechada do
  nada") e **não resolveu** — o frame 6 já era a laje quase fechada, e o
  dono voltou a reportar exatamente o mesmo sintoma uma leva depois.
  Truncar uma animação que vai pro lugar errado só faz chegar mais perto
  devagar. Os 9 frames de hoje foram REGERADOS no sentido certo: as veias
  de brasa acendem pela fortaleza inteira e o arco ABRE numa passagem
  incandescente. Travado por `love . test_one test_castle_gate`.
- Sons: castle-gate-open (madeira 3.5s) / castle-gate-magic (arcano 3s),
  volumes 0.62/0.58 no main.lua.

**v10.5 (feedback: "bem perto ele só sobe, não expande"):**
- O clamp v10.4 (mesmo estável) congelava a escala em ~56% do trecho
  (sMax ~1.76 vs curva que vai a ~3×) — a metade final da chegada era só
  o slide do sink = castelo subindo SEM crescer. CLAMP REMOVIDO de vez.
- Modelo correto (= design original v5): PERTO É GRANDE — no fim o castelo
  tem ~550-570px (768p), ocupa ~73% da tela e o TOPO sai do quadro (fica
  atrás da topbar; GameplayScene desenha a topbar depois). Isso é a
  sensação de estar ao pé do portão. Proteções que ficam: sink/sinkExtra
  (base NUNCA sobe acima da crista — era esse o "saindo da esfera") e
  growth por bioma (CASTLE_APPROACH) calibrado pra ALTURA FINAL PARELHA
  (frost 2.6 e dusk 3.0 porque as artes são mais altas; demais 3.2-3.4).
- ⚠️ Lição consolidada: NUNCA clamp de escala no castelo. As duas
  tentativas (v10 relaxável, v10.4 estável) produziram artefatos que o
  usuário sentiu na hora ("encolhe", "só sobe"). Cortar topo no fim é
  FEATURE, não bug.

**v10.4 (feedback: 2 bugs no fluxo de chegada/entrada):**
- BUG 1 — castelo ENCOLHIA ao aproximar do mini-boss/boss ("efeito
  contrário, o mundo anda mas o castelo recua"). Causa: o clamp usava
  `sinkK = 0.03 + 0.20·(1-progress)` → conforme progress↑, (1-sinkK)↑ →
  `sMax` ENCOLHIA; quando o castelo batia no teto, DIMINUÍA a cada passo.
  Fix: teto ESTÁVEL com o sink FINAL (`finalSink = 0.03 + sinkExtra`,
  constante) → s = min(cresce, constante) = monotônico. Tamanho final
  idêntico; some só o encolhimento no meio. (geom do teto = onde o topo
  toca g.y+6, já contando o sinkExtra — nunca corta.)
- BUG 2 — ordem quebrada no boss: entrava na SALA, aí a cutscene da porta,
  aí voltava pra sala. Causa: durante a viagem de aproximação `entering`
  ainda era false (enterCastle só no onComplete), então
  `interior = not entering and boss = true` → sala aparecia ANTES da porta.
  Fix: flag `bossEntered` (GameplayScene) — a sala do boss só existe DEPOIS
  do fade da cutscene. Ordem certa: exterior (castelo cresce) → porta abre
  → fade → sala. Resetado quando um novo andar de boss começa; elite segue
  hall direto. `isInt` (InteriorFX/fade) alinhado ao mesmo critério.
- DEMO: SPACE agora SIMULA O FLUXO — anda um passo por toque (castelo
  cresce), e ao chegar perto (progress ≥ 0.92) dispara a cerimônia SOZINHO
  (porta + fade), resetando pra andar de novo. B = entrada instantânea.
  Modo `screenshot_worldroad grow<NN>` prova crescimento monotônico.

**v10.3 (feedback: castelos "pra cima" mostrando a base no fim):**
- fields/frost/marsh/dusk têm BORDA INFERIOR larga na arte (grama/neve/
  cogumelo/fundação assados) que, com o sink fixo de 3% no fim, flutuava
  acima da crista. highlands/abyss afunilam pro portão e assentam bem.
- Fix: `CASTLE_SINK_EXTRA` por bioma (fields/marsh/dusk +0.06, frost +0.07
  de ih·s) somado ao baseY, ∝ progress (só perto, não afeta o longe).
  Calibrado pela altura da prateleira de chão medida em cada PNG (perfil
  de opacidade das últimas linhas). Validado offline (linha da crista sobre
  o sprite) + gate1..6 in-game: base enterrada, portão/paredes intactos.

**v10.1/v10.2 (feedback forte — REVERTI a manipulação de câmera):**
- ⚠️ **NUNCA empurrar escala/posição do castelo pra "chegar perto".** A
  perspectiva vem SÓ do crescimento natural da caminhada (`progress =
  walked/SEGMENT_LEN`, escala `1+progress^1.4·growth`). O `_approachBoost`
  (v10) crescia a escala acima do enquadramento → o castelo SAÍA da esfera
  (dava pra ver o fim da arte no topo) e o cap 0.80 fazia ele "parar/
  recuar" no fim = os dois ERRADOS. Removidos: `_approachBoost`,
  `APPROACH_WALK_MAX`, fases "walk"/"push", relaxamento do clamp. O clamp
  virou só GUARDA (`s=min(s,sMax)`, sem boost) — nunca empurra pra fora.
- **mini_boss NÃO entra no castelo** (v10.1): briga na ESTRADA como batalha
  comum (viaja lá de trás, sem hall/background).
- **elite TAMBÉM não entra** (v11, Set/2026 — pedido do dono): o hall é o
  clímax do ato e o pagamento da cerimônia da porta; o elite acontece 2-3x
  por ato, sem viagem e sem porta. Hoje **interior = só o boss**, decidido
  por `GameplayScene.isInteriorNode(nodeType, bossEntered)` (fonte única —
  a condição vivia duplicada em draw e update). O elite passou a viajar
  pela estrada como batalha comum. Ver
  [`memory/enemy_pose_and_scene_anchor.md`](enemy_pose_and_scene_anchor.md).
- **Cerimônia = SÓ boss, SÓ porta+som+fade** (sem câmera): o boss é um
  andar como os outros → `travel()` sem encounter (esfera anda 1 passo, o
  castelo cresce naturalmente) → onComplete `enterCastle()` → door 1.4s
  (frames + som) → fade 0.9s → hall. (v11: a linha "elite = hall direto"
  morreu junto com o elite no interior.) Demo tecla **B** posiciona camZ no
  fim do trecho e abre a porta.

## v11 (Set/2026) — LUGAR POR ATO: 5 locais × 6 atos

Pedido do dono, jogando: "cada um desses locais aí customizado por ato — no
ato 1 a loja é diferente, no ato 2 a loja é diferente, e isso para cada um
dos locais (...) se atente ao chão, se atente ao ato". Aviso explícito de que
refazer custa dinheiro à toa.

**Resolução por bioma.** `landmarkKeyFor(nodeType, bid)` devolve
`<bid>_landmark_<tipo>` quando a arte do bioma existe; senão cai no genérico
**e AVISA** (fallback silencioso é proibido). Os caminhos reaproveitam os
loaders que já existiam, sem tocar neles: base em
`assets/sprites/world/<key>.png` (tryLoadPng), frames em
`anim/<key>/0..8.png` (readAnimFrames).
- **O ato 1 É o dono da arte genérica** (`LANDMARK_GENERIC_BIOME = "fields"`):
  não duplica PNG nem avisa por ele.
- **O conjunto do bioma é ATÔMICO**: se o tipo tem anim de estado (a porta da
  loja) e ela falta, o bioma inteiro volta pro genérico. Meia-loja do bioma
  com a porta da cabana de outro seria pulo de identidade na cara do jogador.
- As tabelas de config (`LANDMARK_SIZE/ANIM/HOVER_SOUND/SHADOW_PAD/LIGHT/
  SMOKE`) continuam por TIPO; `landmarkFamily` tira o prefixo do bioma e
  `lmCfg` deixa a chave CHEIA sobrepor. **Toda loja e toda tenda precisa de
  entrada própria de `SHADOW_PAD` mesmo valendo 0** — sem ela herdaria os 12
  da cabana do ato 1 e a sombra sairia do pé.

**A fumaça é do BIOMA, não da fumaça** (`LANDMARK_SMOKE[...].color`): ela vive
contra o céu. Céu escuro (colinas, abismo, pântano) pede fumaça clara; céu
claro (geleira, crepúsculo) pede fumaça escura, senão ela simplesmente some.
Vale pra vapor e faísca que dependam de contraste com o céu.

**Duas teimosias do PixelLab que não se resolvem por prompt** (3 tentativas
gastas provando a primeira):
1. Ele SEMPRE pinta uma laje de chão chapada embaixo do prédio. A saída foi
   inverter: o prompt PEDE o chão certo do bioma, e a cirurgia
   (`foot.mjs`) só (a) apaga o que passa da PAREDE no rodapé e (b) puxa o
   que fica pro tom do chão do bioma. Objeto ALTO E FINO (estandarte,
   obelisco, fogueira) NÃO se apara — a base dele é legitimamente mais larga
   que o corpo, igual ao monte de cascalho do ato 1.
   Regra extra: **tufo de grama verde-vivo no pé é corpo estranho** em bioma
   cuja relva não é verde (colinas = turfa azul-esverdeada, dusk = restolho);
   a harmonização normal não pega porque poupa pixel saturado, então há um
   passe próprio pra vegetação. Dither na borda foi TESTADO E DESCARTADO:
   a 1:1 na tela vira tracejado visível.
2. O v3 não segura sprite parado (mesma lição dos castelos v9.8). Composite
   cirúrgico com 3 máscaras, escolhidas por tipo:
   - `glow` — pixels emissivos (saturados OU muito claros) em qualquer frame,
     dilatados 2px. **Independente de MATIZ**: serve pra janela âmbar, chama
     laranja, runa violeta e cristal ciano. Loja / fogueira / elite.
   - `rect` — retângulo do diff f0-vs-f8. É a porta abrindo.
   - `above` — congela SÓ o rodapé. Estandarte e tenda, onde o pano ondulando
     É a animação e mascarar por luz mataria ela.

**Medir, não olhar o contact sheet.** Jurei ver o telhado de neve mexendo num
sheet 3× e a medição provou 0px de diferença — a vizinhança de sprites com
luz diferente engana. As travas que valem, impressas pelo compose de cada
conjunto: (a) frame 0 == base bit a bit, (b) **nada muda fora da máscara**
(prova que a estrutura não ferveu — a versão anterior dessa trava media "o
rodapé não mudou" e dava falso alarme no abismo, onde a brasa do chão pulsa
de propósito), (c) emenda do loop pela diferença REAL entre o último e o
primeiro frame contra um passo médio (a versão anterior comparava CONTAGEM de
pixels ativos, que é só proxy). Emenda > 1.6× → ping-pong; foi assim que
`abyss/highlands/frost_landmark_elite` e `abyss_landmark_rest` ganharam
entrada própria em `LANDMARK_ANIM` (o rest/elite do ato 1 fecha o loop).

**Custo real:** os 24 conjuntos + piloto sairam por **127 gerações** (estimei
750-1100). Uma base = ~5, uma anim v3 = ~1-2. O caro é REFAZER: 3 bases
descartadas no piloto. Retrabalho: 4 peças (elite e loja do abismo, fogueira
do pântano, tufos do highlands).

**Ferramentas** (scratchpad, Node — o Python da máquina está quebrado):
`wave.mjs` (driver da onda, fases base/anim, **idempotente**: a primeira
rodada morreu no download e teria pago tudo de novo), `foot.mjs`,
`compose.mjs`, `install_frames.mjs`, `medir.mjs`, `png.mjs` (decode/encode
RGBA puro). ⚠️ **Frame de animação mora em URL ASSINADA do Backblaze: mandar
o header Authorization junto devolve 401** — a assinatura já é a credencial.
No jogo: `love . grade_locais` monta a grade 5×6 de conferência a partir das
cenas reais, e `love . screenshot_worldroad b<N>_fork|forkb|forkhover` captura
a encruzilhada de um ato (`forkb` = elite/evento, porque showFork trava em 3
braços; `forkhover` = porta aberta). ⚠️ O modo fork passava `1` fixo no
`WorldRoad.draw` e chamava `setBiome(1)` todo frame — TODA captura de fork
de outro ato até aqui mostrava o ato 1. Corrigido.

### Lições de MÉTODO do v11 (valem fora desta cena)

**1. Uma trava que mede a coisa errada é pior que trava nenhuma** — ela dá
confiança falsa. As duas do lote falharam pelos dois jeitos clássicos:
- *Proibir movimento que era de propósito.* A trava "o rodapé não mudou"
  acusava FALHA no abismo, onde a rachadura de brasa fica NO CHÃO e pulsar é
  o efeito pretendido. O que realmente prova que a estrutura não ferveu é
  "nada mudou FORA DA MÁSCARA".
- *Medir um proxy em vez da coisa.* A emenda do loop estava sendo calculada
  pela CONTAGEM de pixels ativos por frame — dois frames podem ter a mesma
  contagem com conteúdo completamente diferente. O certo é a diferença REAL
  entre o último e o primeiro frame contra a de um passo médio.
Fica ao lado da regra "meça a emenda, não o item": escolher O QUE medir é
parte do teste, não detalhe de implementação.

**2. ⚠️ Captura de encruzilhada anterior a Set/2026 é SUSPEITA.** O modo
`fork` do `screenshot_worldroad` passava `1` fixo como `actNumber` no
`WorldRoad.draw`, e `draw` chama `setBiome(actNumber)` — ou seja, TODA
captura de fork de qualquer ato mostrava o ato 1, independente do
`setBiome` feito antes. Qualquer conclusão visual tirada dessas imagens no
passado precisa ser refeita antes de virar decisão. Corrigido no v11 (o modo
aceita prefixo `b<N>_` e repassa o bioma pro draw).

**3. Não descreva na animação o que não está no sprite.** Ao refazer a
barraca do pântano a arte perdeu as abas laterais de pano, mas a descrição de
idle continuava pedindo "as abas balançam". Pedir movimento de algo que não
existe é convidar o v3 a INVENTAR — e inventar é justamente o que faz ele
ferver a estrutura. A anim segue o que está desenhado.

**4. `git status` responde "está salvo?"; diff contra um SHA anotado responde
outra pergunta.** Com mais de uma frente commitando, o `HEAD` se move por
baixo de você: comparar com um SHA que você anotou antes responde "mudou
desde aquele ponto?", e uma peça commitada DEPOIS dele aparece como
"diferente", o que é fácil de ler como "não commitada". Aconteceu aqui — as
três peças refeitas diferiam de `36d4d31` (o commit do lote) justamente
porque já estavam salvas em `bf1b770`. As perguntas certas pra "está salvo?"
são `git status --short` (vazio = tudo commitado) e `git log -1 -- <arquivo>`
(qual commit carrega este arquivo). É a MESMA família das lições 1 e 2: a
medição estava correta e respondia uma pergunta parecida — só não era a
pergunta que se queria responder. Antes de concluir a partir de um número,
confira se ele mede o que você está afirmando.

**5. A cirurgia de composite não é opcional, e MÁSCARA LARGA a anula.** As
animações dos locais por ato foram compostas — e mesmo assim o dono viu
"bandeira que se mexe do lugar" e "fogueira flicando a sombra". A cirurgia
estava lá; o que faltou foi o tamanho da máscara:
- o estandarte usou o modo `above`, que congela só o rodapé e libera TODO o
  resto: o mastro era repintado a cada quadro e aparecia/sumia. Medido depois:
  no estandarte do ato 2 o mastro mora em x11-12 e o pano em x11-28 — o mastro
  está DENTRO do vão do pano, então qualquer máscara "o pano inteiro" o inclui.
- a fogueira usou `glow` (saturado OU muito claro), que pega a brasa do chão,
  as runas da tigela e o entulho junto com a chama.
- a loja das colinas usou o mesmo `glow`, e a pedra pálida dela passa de
  luma 195 — a máscara virou "o prédio inteiro".

⚠️ **E a trava "nada fora da máscara" PASSOU em todos os três**, porque ela
verifica o que foi DECLARADO, não o que deveria ficar parado. Uma trava não
substitui escolher a máscara certa.

Receita que corrigiu (custo ZERO — máscara nova é subconjunto da antiga, então
o movimento já está nos quadros instalados; basta reinstalar o original e
recompor): **diga ao contrário — liste o que NÃO pode mudar e proteja primeiro**
(mastro, travessa, anel de pedras, corpo do braseiro, entulho, moldura), e só
então abra a máscara na chama / na barra de baixo do pano / na luz da porta.
Na dúvida, máscara MENOR: animação sutil demais é reclamação pequena, estrutura
fervendo é "cara de IA". A geometria sai da arte-base, não de chute:
- PANO = a maior sequência de linhas com o MESMO vão [mn..mx] (a travessa é
  larga mas dura 2-3 linhas; o pano é a coluna constante e alta). Tentar por
  "linha larga o bastante" pega a travessa junto — errei assim na 1ª versão.
- MASTRO = a coluna FINA que sobra logo ABAIXO do pano, antes do entulho.
- ANEL DE PEDRAS = a primeira linha da metade de baixo que chega a ~70% da
  largura máxima; dali pra baixo é estrutura.
Confira sempre as DUAS pontas: quadro 0 == base bit a bit **e** movimento médio
não-nulo — máscara apertada demais vira sprite parado, que é o outro jeito de
errar.

**6. Detector que reprova tudo não discrimina nada — e o conserto é comparar
com um PAR conhecido-bom.** A 1ª versão do `tools/anim_drift` reprovou 36 de
36, inclusive as do ato 1, que são o padrão da casa; ela teria mandado refazer
o conjunto inteiro. Passou a comparar cada marco com o EQUIVALENTE DO ATO 1 em
vez de usar limiar absoluto, e aí isolou exatamente os 6 defeituosos. É a mesma
família das lições 1, 2 e 4 desta lista: a medida estava certa, a PERGUNTA é
que estava errada. E note o limite dela: o defeito do estandarte (mastro
piscando no MEIO do sprite) não aparece em métrica de rodapé nenhuma — foi
preciso ABRIR os quadros (`love . sheet <pasta> 4`). Métrica filtra, olho
decide.


## ⭐ Perf Out/2026 — o mundo inteiro em ~3-4 ms (era 15-30)

Medição da revisão de lançamento: 1080p custava 20-31 ms de CPU por frame
(~1000 draw calls) e a troca de ato engasgava 100-370 ms. O custo NÃO era
GPU: eram **dezenas de milhares de chamadas Lua→C por frame** (setViewport
+ draw por fatia do chão, por fatia da estrada; batch:add + setColor por
lâmina) — e chamada C/closure no laço também derruba o JIT.

**O que mudou (mesma imagem — prova pixel a pixel ≤0,002% de px, só
arredondamento de float):**
- `engine/QuadMesh.lua` (novo): quads escritos por FFI num ByteData e
  desenhados como 1 Mesh com `setDrawRange`. Fórmulas de vértice/UV/cor =
  as do LÖVE 11 (Quad::refresh, Matrix4::setTransformation, toColor32).
  Quad SEM textura no meio de texturizados = u sentinela + `untexturedShader`.
- **Chão do domo**: malha cacheada por (camZ, geometria, textura); câmera
  parada = 1 draw, zero Lua. Alpha do crossfade vai na cor GLOBAL (fora da
  chave — senão a camada que entra reconstruía a cada frame).
- **Estrada**: mesma ordem de antes (tile → decoração → próxima fileira)
  num QuadMesh só, 1 draw. O `paintRow` era closure criada POR FILEIRA —
  FNEW no laço aborta o trace e, com FFI, o interpretador fica MAIS lento
  que as chamadas C antigas (95 ms/frame num run). Agora 1 closure/frame.
- **Grama**: ver `engine/GrassField.lua` — vento no VERTEX SHADER e lote
  reusado com a câmera parada (chave: camZ, geometria, cores, bioma,
  `forkSig`, fatias). Na câmera andando a CPU escreve só a lâmina parada +
  parâmetros (hash/fase). `ctx.frame` (= `WorldRoad._drawFrame`) zera o
  cursor por FRAME DE DESENHO — com o mundo pausado o `_time` não anda.
- **Troca de ato**: `prewarmTick` no `update` carrega o bioma ATUAL e o
  PRÓXIMO aos poucos (`WorldRoad.PREWARM_BUDGET` = 2 ms/frame): chão,
  RoadSurface (bake cede a cada 16 linhas), montanhas+cor do céu, castelo
  (+porta), props×3 variantes, luminárias (sprite+chama+âncora), marcos do
  fork. Loader novo de asset de bioma? **Adicione em `prewarmJobs`** — a
  trava `test_perf_budget` reprova se o 1º frame do bioma decodificar PNG.
- PNG decodificado 1× (ImageData → Image) e varredura de conteúdo por FFI
  no buffer rgba8 (era getPixel por pixel, 2 decodes por arquivo).
- **Pools por frame** em drawProps (opções de sombra, oclusores, hitboxes,
  listas de passe, arg do LuminaireEngine): 130 → ~26 KB/frame de lixo.
- `pickKind`/sorteio de luminária em ordem ESTÁVEL (`kindOrder`): `pairs()`
  em chave string muda de ordem entre processos (hash semeado do LuaJIT) —
  o mesmo seed dava cenários diferentes e a prova visual era impossível.

**Lições de JIT (LuaJIT 2.1 do LÖVE 11.5):** laço quente com FFI PRECISA
compilar. Matam o trace: closure criada no laço (FNEW/UCLO), desvio
frequente que vira trace lateral que não monta (NYICOAL — use
`math.max/min` em vez de `x > 0 and x or 0`). Diagnóstico:
`love . test_one perf_probe 1920x1080:jitv` lista abortos por linha.

**Números (1080p, mesma sessão, máquina com outra frente rodando):**
regime estável 24-31 → 3-4 ms (mediana), draw calls ~1000 → ~410,
viajando ~30 → ~9-10 ms, troca de ato 140-250 → 31-51 ms (o resto é
JIT reaquecendo + fantasmas do crossfade, não carga de disco).

**Ferramentas:** `perf_probe [WxH][:phases|:switch|:jitv|:profile]`
(ms por fase + KB alocados), `perf_visual_diff ref|cmp[:WxH]` (casos
determinísticos: relógio/mouse/RNG congelados), trava `test_perf_budget`.

## Fork fechando — clareira acompanha o fade (Out/2026)

Bug do dono: ao escolher um braço, os outros dois sumiam mas ficava um
"rastro liso sem grama" onde estavam. Causa (NÃO era o cache da grama — o
`forkSig` já incluía `converge.k` e reconstruía todo frame): a ESTRADA dos
braços não escolhidos esmaece com `forkAlpha` (zera em k≈0.63), mas o
`roadCenters` do ctx da grama seguia devolvendo os 3 centros com largura
cheia até o fork fechar → chão do domo sem estrada e sem capim. Existia
desde o v7.4.15 (clareira por braço), anterior à otimização b44694f.
Correção: `roadCenters(z,t)` devolve um 3º valor `ws[i] = forkAlpha(f,i)`
e o GrassField multiplica a clareira (lâminas e acentos) por ele — a grama
CRESCE de volta junto com o fade. `forkAlpha` subiu pra antes do
`drawGrass` (lição ciclo 41: local abaixo é nil pra quem vem antes).
Regra: **tudo que esmaece um elemento do chão tem que esmaecer a máscara
que ele impõe à grama (clareira, corredor de props) na mesma curva.**
Trava: `test_perf_budget` ("fork fechando → braço que sumiu não deixa
clareira", "reconstrói a cada frame da convergência", "assentado → volta a
reusar o lote"). Captura: `love . screenshot_worldroad forkfade<N>` (N
ticks de 1/30 s após escolher o braço do meio; o rastro aparecia em 40-48).

## Raízes no chão + variantes de árvore por bioma (13/Out/2026)

Pedido do dono: "no primeiro ato as árvores ficam com as raízes muito
expostas; enfiar um pouquinho mais no chão" + "gerar mais árvores parecidas
com cada ato, se ficar bom".

**Diagnóstico:** o sink do ciclo 27 (4% da altura, igual pra toda vegetação)
só DESLOCAVA o sprite pra baixo. O chão é textura: a raiz continuava
desenhada por cima dela, e só a fatia de capim da frente escondia alguma
coisa. Medido no PNG (perfil de largura das linhas de baixo), a leva mais
larga das raízes de `fields_tree_0/1` fica ACIMA da linha de contato.

**Mecanismo (`PropCut` no topo do WorldRoad, dados em
`src/data/world_props.lua`):** `sink[<png>]` = linhas de ARTE enterradas,
medidas sprite a sprite (enterra a leva mais larga da raiz, deixa o
alargamento de cima à vista). O sprite é desenhado por um **Quad sem essas
linhas**, com a linha recortada apoiada em `sy` (origem `ih - sink`); a
grama na frente continua cobrindo o pé (painter intercalado). Sem entrada
= `SINK_DEFAULT_FRAC` (4%, arbustos/procedurais); teto `SINK_MAX_FRAC` 15%.
A chave segue a cascata de variante do `getSprite` (variante sem PNG herda
a 0), porque o metadata pendura na IMAGEM (`PropCut.px[img]`, tabela fraca,
registrado no `tryLoadPng`). Sombra (ShadowEngine) continua ancorada em
`sy - 1` com o sprite inteiro: a sombra da raiz sai do pé, fica natural.
Hitbox e oclusor do LightEngine usam a altura visível (`ihv`); no lightmap
as linhas recortadas caem sob o pé (¼ res, invisível). Emersão na crista
usa o mesmo quad (continuidade ao cruzar). `sizeK[<png>]` = escala
relativa por sprite: o `scaleAt` normaliza toda variante de um kind pra
MESMA altura de tela, então espécie menor (abeto jovem, toco partido)
precisa de fator < 1. Medidas: fields_tree_0/1 11 px, abyss_deadtree_0 11,
highlands_pine_0 9, dusk_tree_0 9, marsh_deadtree_0 7, frost_pine_0 5.

**Variantes novas (`tools/pixellab_trees.py`):** `create_image_pro` com a
árvore do bioma como `style_image` + `reference_images` (base64 lido do
disco), 4 candidatas por chamada (≤170 px; 16 abaixo de 85 px), 10
gerações por chamada. `poll` monta as urls `?index=0..N-1` a partir de
"frames: N" (o texto só traz o índice 0). `process` = alpha binário +
crop + preenchimento de furos internos (ciclo 34) + contagem de cores;
`sheet` = prancha referência × candidatas por bioma
(`tools/preview_out/arvores/variantes_bioma_N_<id>.png`), julgada a olho:
entra só o que lê como o mesmo artista/bioma. Instaladas 14: fields_tree_2,
highlands_pine_1/2 + highlands_deadtree_0, abyss_deadtree_1/2 + abyss_bush_0,
frost_pine_1/2 + frost_deadtree_0, marsh_deadtree_1/2, dusk_tree_1/2
(deadtree/bush de highlands/frost/abyss eram sorteados em propWeights SEM
PNG → procedural). Sorteio inalterado (`p.variant = rng:random(0, 2)`,
cluster `(variant+ci)%3`): só o PNG que a variante carrega mudou.
Descartes: cópias quase idênticas da referência (frost_a 0-3), copas de
bolha arredondada (frost_b 0/3), gradientes de render com 200-370 cores e
bolsões escuros (marsh_a 0/2/3, abyss_a 0/3, fields_a 1/3), paleta de
outro bioma (marsh_b 1), tronco em espiral (dusk_a 2); o resto só perdeu
a vaga (3 variantes por kind). Trava: `test_world_props` (PNG da espécie
da parede por bioma, sink dentro do teto, tronco opaco na linha de
contato, sem margem transparente, cascata de variante). Perf: draw calls
idênticos (427/453/444/467/475/418 por bioma), texmem +0.3 MB.

## Backlog

- [ ] **Validação visual v3.3 nativa** (precisa driver resetado; testar em
  estágios: screenshot single → repetir → tour completo)
- [x] ~~Gerar batches PixelLab dos outros 5 biomas~~ — CONCLUÍDO no ciclo 18
  (todos os 6 biomas com props PixelLab)
- [ ] Herói PixelLab (create_character vista NORTE + animate walk 2-4 frames)
- [ ] Entrada do inimigo ao fim da viagem (materialize/juice em vez de pop)
- [ ] Sfx de passos durante travel (Sfx.play com pitchVariation)
- [x] ~~Variação de landmark por bioma~~ — FEITO no v11 (5 locais × 6 atos)
- [ ] Avaliar textura modo-7 na grama com pattern DEDICADO de terreno
  (gerar via PixelLab um tile "grass_ground" sem motivos — aí sim funciona)
