---
name: code_notes/src/ui/WorldRoad.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/WorldRoad.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/WorldRoad.lua`

Origem: `src/ui/WorldRoad.lua` em `7dbdb60d` (320 de 490 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-28 (junto a `local biomesData = require("src.data.biomes")`)

> src/ui/WorldRoad.lua
> V4 "CIRCLE LAND" — o mundo é um DOMO (disco-terra gigante), fiel à mecânica
> real do Path of Kings (APK: CircleLandController + GameObjects Circle/Sphere).
>
> GEOMETRIA:
> O chão é um círculo de raio R (~2.2× a largura) com centro ABAIXO da tela.
> O topo do círculo é a CRISTA CURVA: crestY(px) = cy - sqrt(R² - (px-cx)²).
> Avançar = o disco "gira": conteúdo (tijolos da estrada, tufos, props)
> flui da crista pra base acelerando (t^p), crescendo em escala.
>
> PAINTER'S ORDER (oclusão de graça, sem stencil):
> céu → nuvens → montanhas parallax → CASTELO (cresce c/ progresso, base
> sempre atrás do domo) → INIMIGO emergindo (meio-corpo atrás da curva) →
> PREENCHIMENTO DO DOMO → estrada de tijolos → props do lado de cá.
>
> SEM herói (primeira pessoa implícita: vemos só inimigos e cenário).
>
> ESCALA COERENTE por tipo (KIND_SIZE, unidades de mundo): árvore ~3.4× arbusto.
>
> Arte: PNG do PixelLab em assets/sprites/world/<nome>.png tem prioridade
> (clouds/castle/mountains/bricks/tufts + props por bioma); fallback procedural.
>
> API (inalterada p/ GameplayScene):
> update(dt) / draw(x,y,w,h,actNumber) / travel{distance,duration,onComplete,
> encounter} / isTraveling() / setBiome(n) / getRoadAnchor(rel,x,y,w,h) /
> BATTLE_REL / TRAVEL_DISTANCE / TRAVEL_DURATION / clearCache()
>
> Plano: docs/plan/worldroad-sphere-v4.md · Memória: memory/worldroad_scene.md

## L41-43 (junto a `local GrassField = require("engine.GrassField")`)

> v9.7.1: GrassField declarado AQUI (era local no meio do arquivo e o
> update() — textualmente ANTES — enxergava global nil → crash na rajada
> do mouse; mesma lição do ciclo 41)

## L46-53 (junto a `local PropCut = {`)

> Out/2026 (pedido do dono: "raízes muito expostas"): RAÍZES NO CHÃO.
> Metadata por sprite em src/data/world_props.lua (`sink` = linhas de arte
> enterradas). O sprite é desenhado por um QUAD sem as linhas de baixo, com
> a linha recortada apoiada na latitude do chão; a fatia de capim na frente
> do pé (flushGrassTo) cobre o contato. Desenhar o sprite mais baixo (o
> sink2 do ciclo 27) não enterrava nada: o chão é uma textura e a raiz
> continuava por cima dela. Tudo numa tabela só (teto de 200 locals do
> arquivo); caches fracos por imagem — zero alocação por quadro.

## L98-100 (em `WorldRoad`, junto a `local CREST_RATIO   = 0.40   -- y do topo do domo (fração da altura da área)`)

> ============================================================================
> TUNING
> ============================================================================

## L108 (em `WorldRoad`, junto a `local PROP_SPACING  = 1.05`)

> denso: cenário COMPLETO (feedback: "sentimento

## L109-110 (em `WorldRoad`, junto a `local UNIT_PX       = 0.115  -- 1 unidade de mundo em px = UNIT_PX × altura da área`)

> de que tem todo um cenário já pronto"; ciclo 19
> baixou de 1.45 — "poucas coisas espalhadas")

## L115-124 (em `WorldRoad`, junto a `WorldRoad.BATTLE_REL_NEAR = 9`)

> baixo, SEPARADO do castelo na crista)
> PALCO DA BATALHA (Out/2026, dono: "os inimigos param muito na frente da
> tela; a carta em hover e a descrição ficam à frente do inimigo"). O rel 9
> acima é o MAIS PERTO que o inimigo para; a cena (GameplayScene) empurra
> ele estrada adentro até o pé ficar acima da carta levantada no hover —
> ver battleRelFor. Como cartas/tooltip têm tamanho FIXO em px e o mundo
> escala com a altura da tela, a distância de parada é por TAMANHO DE
> TELA: ~12.6 em 1080p, ~15.4 em 1024x768, ~16 em 1280x720.
> BATTLE_REL guarda o palco VIGENTE (lido pelo painter, pela viagem e pelo
> oclusor de luz); quem o escreve é WorldRoad.setBattleRel.

## L126 (em `WorldRoad`, junto a `WorldRoad.BATTLE_REL_FAR  = 16.5`)

> teto: além disso ele encosta no castelo

## L127-129 (em `WorldRoad`, junto a `WorldRoad.TRAVEL_DISTANCE = 20`)

> ciclo 24 (feedback): viagem mais CALMA — menos distância e mais tempo
> ("as coisas vão muito rápido, o inimigo chega muito rápido")
> ciclo 26: mais lenta ainda (5.0→6.5s pra mesma distância)

## L134-139 (em `WorldRoad`, junto a `local KIND_SIZE = {`)

> Tamanho de mundo por tipo. REGRA DE OURO (feedback Jul/2026): árvore perto
> da câmera TEM que ser maior que o inimigo (~255px) — árvore menor que
> monstro quebra a escala do mundo. tree 3.8 → ~375px na base.
> (Jul/2026, ciclo 19): +~25% geral — a maioria dos props visíveis vive em
> t≈0.3-0.5 onde persp derruba pra ~30%; com os valores antigos tudo ficava
> miúdo (feedback: "os tamanhos estão pequenos").

## L146-155 (em `KIND_SIZE`, junto a `WorldRoad.SHADOW_PROFILE = {`)

> PERFIL DE PEGADA da sombra (ShadowEngine v9, Out/2026 — "a fogueira é um
> círculo e a sombra é o círculo inteiro depois dela"). Objeto BAIXO E LARGO
> declara que fração da altura do conteúdo é pegada no chão (baseK), que
> fração acima dela projeta (riseK; chama não tem sombra) e o quanto a
> sombra encurta (lenK). Quem NÃO está aqui — árvore, poste, estandarte,
> tenda, loja, obelisco, totem, pilar, cerca, placa — segue a silhueta
> inteira (aprovada). Chave = tipo de prop OU chave de marco (a cheia
> `<bioma>_landmark_rest` vence a da família, via lmCfg). Frações medidas
> no PNG (perfil de opacidade por linha, tools/preview_out/sombras_mundo).
> Campo de módulo, não `local`: o escopo do arquivo está no teto de 200.

## L166-167 (em `landmark_chest`, junto a `landmark_rest           = { baseK = 0.22, riseK = 0.17 },`)

> fogueiras: pegada = anel de pedras/toras; só a altura das pedras
> projeta (riseK) — a chama é luz, não corpo

## L176-177 (em `dusk_landmark_rest`, junto a `local function kindSize(kind, bid)`)

> v9: luminárias têm tamanho POR BIOMA no catálogo do LuminaireEngine
> (lanterna do pântano ≠ cogumelo); resto cai no KIND_SIZE global

## L183-184 (em `kindSize`, junto a `local BIOME_BY_ID = {}`)

> v9: âncora de chama, cor, raio e flicker das luminárias migraram pro
> LuminaireEngine (catálogo por bioma) — ver engine/LuminaireEngine.lua

## L193-194 (em `ENV_FIELDS`, junto a `}`)

> (lightAmbient saiu daqui: o ambiente de luz agora é computado por
> currentLightAmbient() — lerp dia/noite pelo timeOfDay + blend de bioma)

## L197-199 (em `ENV_FIELDS`, junto a `WorldRoad._time = 0`)

> ============================================================================
> ESTADO
> ============================================================================

## L202-205 (em `ENV_FIELDS`, junto a `WorldRoad._segBase = 0`)

> v10: âncora do TRECHO — o castelo reseta pra longe quando o bioma vira
> (pedido: "quando troca de bioma, a distância do castelo reseta").
> _segBasePrev preserva a âncora do bioma anterior durante o crossfade
> (senão o castelo que está esvaindo pipocava pra longe junto).

## L208 (em `ENV_FIELDS`, junto a `WorldRoad._entry = nil`)

> v10.2: cerimônia de entrada (door/fade)

## L230-235 (em `rawBiome`, junto a `WorldRoad._timeOfDay = 1          -- default: mood cheio (tools/validação)`)

> ============================================================================
> F6.1: ENTARDECER PROGRESSIVO POR ANDAR (LightEngine)
> ============================================================================
> timeOfDay 0 = dia (andar 1 do ato) → 1 = anoitecer (andar do boss).
> GameplayScene seta o alvo por floorInAct; a transição EASE durante a
> viagem (o mundo escurece enquanto você anda, não num corte).

## L257-258 (em `biomeLightAmbient`, junto a `local function currentLightAmbient()`)

> Ambiente de luz do frame: lerp dia→noite pelo timeOfDay, com crossfade
> de bioma pelo MESMO relógio do blend (smoothstep, igual ao envColor).

## L290-293 (em `envColor`, junto a `local function domeGeom(x, y, w, h)`)

> ============================================================================
> GEOMETRIA DO DOMO
> ============================================================================
> Retorna funções de geometria pro frame corrente (dependem de x,y,w,h).

## L321-323 (em `g.tOf`, junto a `function g.persp(t)`)

> PERSPECTIVA ÚNICA: todo tamanho no mundo passa por essa curva.
> Longe (t=0) = 10% do tamanho; perto (t=1) = 100%, com crescimento
> acelerado no fim (t^1.65) — profundidade REAL, não linear.

## L327-331 (em `g.persp`, junto a `function g.latY(dx, t)`)

> LATITUDE VERDADEIRA da esfera: y de qualquer ponto do chão em
> (offset lateral dx, profundidade-fração t). Antes o Y interpolava
> linearmente pro fundo PLANO da tela — o campo próximo achatava e
> parecia "curvatura contrária". Agora tudo deita na circunferência:
> círculo de latitude com raio (R - d) e mesmo centro do domo.

## L347-360 (em `g.scaleAt`, junto a `local ffi = require("ffi")`)

> ============================================================================
> SPRITES (PNG PixelLab prioridade; fallback procedural)
> ============================================================================
> v9.7.1: retângulo de CONTEÚDO por imagem (pixels com alpha ≥ 0.6) — o
> clique no cenário deve acertar só a parte FÍSICA do prop (feedback: "a
> luz não deveria contar no clique, só o corpo do poste"). Canvases
> PixelLab têm margens transparentes enormes (lanterna fields: corpo de
> 21px num canvas de 72) e a hitbox de quad inteiro cobria justamente a
> área onde o glow do LightEngine aparece. Scan 1× por arquivo, cache
> fraco por Image (morre junto com o sprite).
> Out/2026 (perf da troca de bioma): o PNG era decodificado DUAS vezes
> (newImage + newImageData) e varrido com getPixel por pixel. Agora o
> chamador passa o ImageData que já decodificou e a varredura lê o alpha
> direto do buffer rgba8 (FFI) — mesmo limiar: a ≥ 0.6 ⇔ byte ≥ 153.

## L408-414 (em `tryLoadPng`, junto a `local function readAnimFrames(key)`)

> v9.1: FRAMES de animação da luminária (só o fogo/lâmpada mexe, corpo
> estático — PixelLab animate_object). Layout:
> assets/sprites/world/anim/<bid>_<kind>_<variant>/0.png..N.png
> Sem pasta → luminária fica com o PNG estático (glow assado + flicker
> de luz seguem funcionando).
> Loader compartilhado (luminárias E landmarks): lê a pasta ordenada
> numericamente. nil se não existe ou tem menos de 2 frames.

## L456-461 (em `luminaireFrames`, junto a `local lumPathCache = {}`)

> v9: caminho do PNG da luminária (mesma cascata variant → 0 do getSprite)
> — o LuminaireEngine escaneia o arquivo pra achar a chama/margens
> MEMOIZADO (revisão de perf, Out/2026): é chamado POR LUMINÁRIA POR FRAME
> (argumento do LuminaireEngine.anchor), e cada chamada fazia até 2 stats de
> disco + concatenações — ~3% do frame do WorldRoad no perfil. O disco não
> muda em runtime; false = "não existe" (cacheado também).

## L743-745 (em `c`, junto a `local function makeLantern(b, variant, rng)`)

> LightEngine v1: poste com lanterna acesa — o GLOW é ASSADO na arte (ramp
> quente de 3 degraus concêntricos no vidro), regra "luz se desenha na
> paleta". A poça de luz no chão vem do LightEngine (submit no drawProps).

## L769 (em `woodD`, junto a `local function makeBrazier(b, variant, rng)`)

> LightEngine v1: braseiro de pedra com fogo assado no topo (mesma regra)

## L789-791 (em `makeBrazier`, junto a `local function makeLuminaireGeneric(b, kind, variant, rng)`)

> v9: fallback procedural GENÉRICO pra kind de luminária sem PNG nem maker
> próprio (firepit/shrine/runestone/torch/fissure/crystal/mushroom/totem):
> pedestal na paleta do bioma + glow assado 3 degraus na COR do catálogo

## L837-838 (em `getSprite`, junto a `if not img and kind ~= "cloud" and kind ~= "castle"`)

> fallback pra VARIANTE 0 do PNG: se o tipo tem arte PixelLab, ela SEMPRE
> vence o procedural (misturar arte rica com procedural tosco denuncia)

## L864-865 (em `getSprite`, junto a `function WorldRoad.propCutInfo(kind, variant, bid)`)

> Linhas de arte enterradas e altura visível do sprite de um prop (segue a
> MESMA cascata de variante do getSprite). Pra trava/ferramenta.

## L873-879 (em `WorldRoad.propCutInfo`, junto a `local KIND_LANE = {`)

> ============================================================================
> MUNDO: props em distância + reciclagem
> ============================================================================
> Lanes (ciclo 21 — CUNHA): lane agora é fração [0,1] DENTRO da cunha
> permitida (triângulo da lateral do castelo até o canto de baixo da tela,
> igual à referência do APK). 0 = colado na diagonal interna, 1 = borda.
> O corredor central (estrada + grama ao redor) fica SEMPRE limpo.

## L892-893 (em `TREE_KIND`, junto a `local TREEISH = { tree = true, pine = true, deadtree = true }`)

> ciclo 22 (feedback): "árvores muitas vezes, o resto poucas" — árvores
> pesam ×3.5 no sorteio, todo o resto ×0.5 (tufo quase some: 2.5→0.7)

## L895-896 (em `TREEISH`, junto a `local function kindMult(kind)`)

> v9: luminária NÃO leva a pena ×0.5 dos props raros (o ×0.5 esmagava o
> rate — "hoje custa aparecer uma"); árvore segue dominante (×3.5)

## L902-906 (em `kindMult`, junto a `local kindOrderCache = setmetatable({}, { __mode = "k" })`)

> Ordem de sorteio ESTÁVEL (Out/2026): pairs() sobre chaves string muda de
> ordem entre processos (hash de string semeado do LuaJIT) — o mesmo seed
> dava cenários diferentes a cada execução e a prova visual pixel a pixel
> (tools/perf_visual_diff) era impossível. Lista ordenada por nome, 1x
> por tabela de pesos.

## L937-941 (em `pickKind`, junto a `local function rollProp(p, z, forcedSide, noLum)`)

> noLum: pula o agendador de luminária — usado pelos chamadores que vão
> makeWall(p) logo em seguida (treeline/reciclagem de parede). Sem isso o
> agendador GASTAVA o cursor do poste e o makeWall sobrescrevia pra árvore:
> o poste agendado sumia silenciosamente ("às vezes a estrada fica às
> escuras" — v9.3).

## L947-949 (em `rollProp`, junto a `if forcedSide then`)

> LADO primeiro (a cadência de luminária é POR LADO — ver abaixo).
> populate spawna nos DOIS lados por passo; _sideBal balanceia spawns
> avulsos durante a viagem.

## L960-966 (em `SIDE_W`, junto a `local LUM_STEP = 7      -- período base por lado (unidades de z)`)

> v9.3 (feedback: "postes aparecem tudo de uma vez / tudo lá na
> frente"): cadência AGENDADA com FASE ALTERNADA. Cada lado guarda o
> z do PRÓXIMO poste (_nextLumZ[side]); os lados nascem meio período
> defasados → esquerda e direita intercalam em profundidades
> diferentes (um no pé da tela, outro no meio, outro no fundo — a
> "escada" de estrada real). Jitter pequeno (±LUM_JIT) mantém orgânico
> sem deixar dois postes nascerem na mesma faixa de z.

## L970-971 (em `SIDE_W`, junto a `[-1] = z + LUM_STEP * (0.15 + rng:random() * 0.20),`)

> primeiro poste do lado A perto (0.15-0.35 do período), o do lado
> B meio período depois — a escada já nasce montada

## L977 (em `SIDE_W`, junto a `if LuminaireEngine.isLuminaire(p.kind) then`)

> prop de parede: nunca vira luminária E não mexe no cursor

## L984-988 (em `SIDE_W`, junto a `local nearBias = (z - (WorldRoad._camZ or 0)) < 9`)

> hora deste lado: o prop VIRA luminária (sorteio do catálogo).
> Na faixa de PERTO (rel < 9, só no populate estático) os kinds
> roadside (poste/braseiro/tocha altos) pesam ×3 — o slot do pé
> da tela precisa LER como poste; santuário/cogumelo discretos
> lá na frente sumiam na moldura ("não parece que tem poste").

## L1010-1014 (em `w`, junto a `local other = -p.side`)

> CORRENTE ENTRE LADOS: o próximo poste do OUTRO lado cai na
> janela intermediária [z+0.3, z+0.65]×período — nem colado no
> meu (mesma faixa de z lê como "portal"), nem além do meu
> próximo (buraco combinado > período deixa trecho às escuras).
> É isso que garante a escada perto/meio/fundo em QUALQUER corte.

## L1025-1026 (em `w`, junto a `local ldef = LuminaireEngine.def(b.id, p.kind)`)

> v9: luminária tem lane do catálogo por bioma (cogumelo entra no mato,
> lampião cola na estrada — a poça de luz precisa alcançar o caminho)

## L1035-1036 (em `w`, junto a `if (p.kind == "tree" or p.kind == "pine" or p.kind == "deadtree")`)

> MOLDURA LATERAL (lição dos painéis do PoK): ~30% dos props grandes vão
> pras bordas da tela, maiores — emolduram o corredor visual até o castelo

## L1046-1048 (em `w`, junto a `WorldRoad._sideBal = (WorldRoad._sideBal or 0)`)

> ciclo 20: cluster multiplica a MASSA VISUAL do lado — sem contar
> as companheiras no saldo, um "grupo de 3" pesava como 1 árvore e
> a tela desequilibrava mesmo com o sorteio balanceado

## L1060-1061 (em `w`, junto a `local function resolveOverlap(p)`)

> ANTI-EMPILHAMENTO: rejeita spawn que cai em cima de outro prop grande
> (mesmo lado, lane próxima, z próximo) — re-rola lane/lado até 4 tentativas

## L1063-1065 (em `resolveOverlap`, junto a `if p.kind == "fence" then`)

> CERCAS têm zona de exclusividade GLOBAL (uma linha de cerca a cada
> 8+ unidades, qualquer lado): cerca é marco raro da estrada, não
> entulho — 2 props de cerca juntos viravam "ferro-velho" de 6 cercas

## L1068-1069 (em `resolveOverlap`, junto a `if o ~= p and not o.ghost and o.kind == "fence"`)

> fantasma do cross-dissolve não conta como ocupante (é arte
> esvaindo do bioma velho, não um objeto do mundo)

## L1093-1094 (em `BIG`, junto a `local lane = KIND_LANE[p.kind] or KIND_LANE.default`)

> ciclo 21: mantém o LADO (spawn agora é simétrico por construção)
> e re-rola posição dentro da cunha: lane nova + nudge em z

## L1101-1102 (em `BIG`, junto a `local function makeWall(p)`)

> Transforma um prop em membro da PAREDE de árvores (treeline da cunha):
> espécie dominante do bioma, lane no miolo da cunha, maior, 50% cluster

## L1113-1134 (em `makeWall`, junto a `local SWAP_FADE   = 0.42   -- cross-dissolve de UM prop (longe); perto estica`)

> ============================================================================
> TROCA DE BIOMA NO POOL DE PROPS (v10.3)
> Bug do dono: "ao trocar de ato, as antigas árvores do ato anterior começam
> aparecendo, só saem depois". setBiome trocava só a COR (crossfade de
> BLEND_DURATION); cada prop guarda o p.bid do sorteio e só trocava quando
> RECICLAVA (p.z - camZ < -3.5). Como o pool vai até REL_CREST+EMERGE_BAND
> (~35) e cada andar anda TRAVEL_DISTANCE (20), o fundo levava ~2 andares
> pra virar. As luminárias viviam do mesmo problema (mesmo pool).
>
> Solução: CROSS-DISSOLVE POR PROP — nada de limpar o pool (sumiço seco de
> todas as árvores, treeline inclusa, é pop feio contra o crossfade suave de
> cor que já existe). O prop velho vira um FANTASMA: cópia VISUAL no MESMO z
> e no MESMO lado, ou seja, no MESMO slot do painter (REGRA DE PROFUNDIDADE
> intacta — o fantasma é só mais um prop na lista ordenada por z). Ele esvai
> enquanto o prop, já re-sorteado no bioma novo, aparece.
>
> ESCALONADO POR PROFUNDIDADE (perspectiva): prop LONGE é pequeno na tela e
> trocar a arte dele é quase imperceptível → troca PRIMEIRO e rápido. Prop
> PERTO é grande → troca POR ÚLTIMO e mais devagar (e costuma reciclar
> sozinho antes, porque some da tela em poucos metros). Ninguém fica pra
> trás: todo prop à frente da câmera entra na onda.
> ============================================================================

## L1137-1139 (em `makeWall`, junto a `local GHOST_FIELDS = { "z", "side", "kind", "variant", "bid", "lane",`)

> campos VISUAIS copiados pro fantasma. Estado interativo (poke, folhinhas,
> pássaros pousados, hitbox) fica SÓ com o prop de verdade — fantasma é arte
> esvaindo, não é mais um objeto do mundo.

## L1162-1164 (em `swapPropsToBiome`, junto a `local order = {}`)

> ordem CRESCENTE de z pro re-sorteio: a cadência de luminária
> (_nextLumZ) é um cursor que só anda pra frente — sortear de trás pra
> frente gastaria o cursor lá no fundo e deixaria a estrada às escuras.

## L1173-1174 (em `ghosts`, junto a `if rel >= 0 then`)

> prop já ATRÁS da câmera está deslizando pra fora (over): trocar a
> arte dele no meio da saída é gasto sem ganho

## L1183-1184 (em `gh`, junto a `gh._pokeT, gh._leafFx = p._pokeT, p._leafFx`)

> o balanço/folhinhas de um clique recente seguem na arte
> que o jogador cutucou (ela é que está esvaindo)

## L1209-1211 (em `WorldRoad._props`, junto a `WorldRoad._nextLumZ = nil`)

> v9.2: cursor de cadência de luminária ZERA na repopulação — o valor
> do trecho anterior (z alto) fazia o espaçamento mínimo demitir toda
> luminária do bioma novo (marsh nascia sem NENHUM emissor)

## L1216-1217 (em `WorldRoad._props`, junto a `for side = -1, 1, 2 do`)

> ciclo 21: spawn nos DOIS lados por passo (90% cada) — cunhas
> laterais cheias ("preencha quase tudo") e simétricas por construção

## L1230-1234 (em `p`, junto a `local zt = 1.2`)

> TREELINE (ciclo 21, ref APK): parede CONTÍNUA de árvores nas cunhas —
> o sorteio misto acima gasta muito em prop pequeno, então sem essa
> passada garantida ficavam buracos na moldura de floresta.
> p.wall = true: a reciclagem preserva a identidade (ciclo 22 — sem
> isso a parede dissolvia em tufos conforme o jogador viajava)

## L1247-1250 (em `p`, junto a `WorldRoad._clouds = {}`)

> v5.8 (feedback): nuvens SEMPRE pequenas e ao fundo — nada de bolha
> gigante colada na câmera. Drift lento + bob senoidal (phase) pra
> não ficarem estáticas. v5.10 (feedback): menos nuvens, banda mais
> ALTA no céu, e só cloud_0 (cloud_1 foi apagada do jogo).

## L1256 (em `WorldRoad._clouds`, junto a `speed = 2.6 + WorldRoad._rng:random() * 2.6,`)

> v9.7: deriva mais viva (feedback "nuvens muito estáticas")

## L1263-1264 (em `WorldRoad._clouds`, junto a `for _ = 1, 3 do`)

> camada DISTANTE de nuvens (menores e mais lentas ainda —
> segunda profundidade no céu = fundo mais rico sem poluir)

## L1278-1280 (em `WorldRoad._clouds`, junto a `function WorldRoad.setBiome(n)`)

> ============================================================================
> API
> ============================================================================

## L1292-1293 (em `WorldRoad._blend`, junto a `swapPropsToBiome(WorldRoad._camZ)`)

> v10.3: os PROPS também viram (antes só a cor virava e as árvores
> do ato anterior ficavam no pool até reciclar, ~2 andares)

## L1298-1321 (em `WorldRoad._blend`, junto a `function WorldRoad.enterCastle(opts)`)

> ============================================================================
> v10: CERIMÔNIA DE ENTRADA no castelo — SÓ NO BOSS (v10.1: "a porta só
> deve abrir quando for o boss"; mini-boss briga do lado de fora, elite
> vai pro hall com fade simples). Pedido: "a porta do castelo abrindo,
> um som, e a gente entrando ali dentro".
> v10.2 (feedback): a cerimônia NÃO mexe na câmera/escala — o castelo já
> está no tamanho natural da caminhada (perto por volta do boss). Só:
> door (1.4s) — frames de ABERTURA (anim/<bid>_castle_door) + som do
> portão (madeira; abyss/dusk = surto arcano)
> fade (0.9s) — fade a preto → onComplete (GameplayScene revela o hall)
>
> v10.3 (Set/2026): "abrir" é o VERBO, não a batente. A fase se chama
> "door" por herança dos biomas de portão de madeira, mas o que a
> animação mostra tem que ser COERENTE COM A ARTE DO CASTELO daquele
> bioma. O abismo NÃO TEM PORTA: a fortaleza v3 tem um arco em CHAMAS.
> Os frames antigos apagavam o fogo e desciam uma laje de pedra no vão —
> literalmente uma porta nascendo do nada, e foi assim que o dono viu
> ("ta aparecendo uma porta do nada no castelo que tinha porta de fogo").
> Os frames de hoje fazem o oposto: as veias de brasa acendem pela
> fortaleza inteira e o arco ABRE numa passagem incandescente.
> Ao trocar a arte do castelo de um bioma, REGERE esta animação junto —
> ela parte do frame 0 da arte base e nada no código percebe se as duas
> divergirem.
> ============================================================================

## L1355-1357 (em `WorldRoad._travel`, junto a `if opts.encounter and (opts.encounter.img or opts.encounter.anim) then`)

> v8.4.1: aceita anim OU img — o billboard animado tem img=nil e o
> filtro por .img fazia o encounter virar NIL ("o monstro sumiu da
> viagem, só aparece no final"). Copia também os campos novos.

## L1377-1381 (em `WorldRoad.isTraveling`, junto a `local function roadWobble(worldZ, t, w)`)

> Âncora na estrada (centro) pro rel dado — usada pelo inimigo de batalha.
> MEANDRO da estrada (v5.2, feedback: "caminho retinho, precisa de
> imperfeições"): 3 senos em frequências diferentes — curvas largas +
> ondulação local. Depende do worldZ ABSOLUTO: objetos ancorados numa
> posição do mundo veem o mesmo desvio que a fileira da estrada ali.

## L1389-1392 (em `roadWobble`, junto a `function WorldRoad.setBattleEnemyDraw(fn, baseY)`)

> v9.2: registra o desenho do inimigo pra rodar DENTRO do painter no eixo
> do monstro. baseY = Y do PÉ do monstro na tela (sort 2.5D por base):
> prop com pé mais BAIXO na tela (ou ~igual) = mais perto → na FRENTE.
> One-shot: o WorldRoad.draw consome e zera. Sem registro, nada muda.

## L1406-1416 (em `WorldRoad.getRoadAnchor`, junto a `WorldRoad.ENEMY_SIZE_REF_REL = 9`)

> TAMANHO do inimigo de batalha pela distância de parada. Até Out/2026 ele
> parava em rel 9 com 250px (330 o chefe) — esse é o 1.0 da régua. Parar
> mais ao fundo encolhe pela MESMA perspectiva do mundo (g.persp), elevada
> a ENEMY_SIZE_PERSP: 1 = perspectiva pura; < 1 = o monstro encolhe menos
> que um prop (criatura grande, e a leitura de intenção precisa de corpo).
> Independe do tamanho da tela: t só depende do rel.
> 0.6 (estudo Out/2026, tools/study_enemy_stage): com perspectiva pura o
> comum parava com 120-140px em 1024x768/720p — menor que a carta da mão,
> sem ameaça; 0.6 dá 148-183px (183-211 em 1080p) e ainda encolhe o
> bastante pra não virar gigante ao lado das árvores da mesma faixa.
> Vale também pro salão do chefe (SceneAnchors.depthSizeK).

## L1426-1439 (em `WorldRoad.battleSizeK`, junto a `WorldRoad.ENEMY_SCREEN_BASE_H = 716   -- altura da área do mundo em 1024x768`)

> TELA GRANDE (Out/2026, fullscreen nativo): o mundo escala com a altura
> da área (g.scaleAt ∝ h) mas o EnemyRenderer desenha em pixels FIXOS
> (250/330) — em 2560x1440 o monstro da estrada ficava ~25% menor que o
> mundo em volta ("boneco colado no cenário"). Mesma regra do salão
> (GameplayScene.hallScreenK): acima da área de 1080p o inimigo cresce
> junto, com teto 1.4; abaixo nada muda (4:3 e 1080p ficam como estão).
>
> v2 (Out/2026, escala de UI): com a mão/HUD crescendo junto com a tela
> (src/ui/UiScale), o palco empurra o encontro estrada adentro e o inimigo
> caía pra ~14-17% da altura em 1080p/4K — "o inimigo é a estrela da
> batalha". Agora ele cresce MAIS que a área: 1 até a área do 1024x768
> (716px, nada muda lá), +1.4x por área-base a mais, teto 2.6. Medido
> (tools/screenshot_uiscale_battle): estrada ≥ 25% da altura de 1080p a
> 4K. O billboard da viagem usa a mesma função (chegada sem pulo).

## L1450-1454 (em `WorldRoad.enemyScreenK`, junto a `function WorldRoad.battleRelFor(x, y, w, h, footLimitY)`)

> Distância de parada pra que o PÉ do inimigo (no centro da estrada) caia
> em footLimitY ou ACIMA (menor y). Pura: inverte a mesma geometria do
> getRoadAnchor (sy = crest + (bottom - crest)·t, t = (1 - rel/crista)^pow).
> Clampada em [BATTLE_REL_NEAR, BATTLE_REL_FAR] — nunca mais perto que o
> palco histórico, nunca colado no castelo.

## L1477-1479 (em `easeInOutCubic`, junto a `local LANDMARK_FOR_TYPE = {`)

> MARCOS DO FORK (declarados ANTES do update — bug ciclo 41: eram locais
> do fim do arquivo e update() não os enxergava → crash ao escolher).
> Tamanhos GRANDES (feedback: "são realmente lugares, maiores que árvores")

## L1482-1483 (em `LANDMARK_FOR_TYPE`, junto a `mini_boss = "landmark_miniboss", boss = "landmark_battle",`)

> mini-chefe tem marco PRÓPRIO (Out/2026, known_gaps #16): estandarte de
> crânio chifrudo com tochas — não é "mais uma batalha" no fork.

## L1501-1519 (em `getLandmark`, junto a `local LANDMARK_ANIM = {`)

> ============================================================================
> v9.5: LUGARES VIVOS (feedback: "a fogueira está estática, isso é estranho —
> o mapa todo se movimenta"). Cada landmark ganha:
> 1. FRAMES PixelLab em assets/sprites/world/anim/<key>/0..N.png (mesma
> receita das luminárias: frame 0 = PNG base, só fogo/pano/brilho mexe).
> pingpong = vai-e-volta (pano/brilho reiniciando no frame 0 dá "pulo";
> fogo pode correr o loop).
> 2. Sombra ancorada na BASE DA PAREDE por conteúdo (footPad): na casa/tenda
> as últimas linhas do sprite são escada/deck avançando pro 1º plano e a
> silhueta-sombra nascia na PONTA disso — "saindo mais pra frente da
> casa" (feedback com print). Valores medidos por opacidade/linha.
> 3. Micro-luz na chama/janela/orbe (âncora = scan de conteúdo do
> LuminaireEngine, receita das janelas do castelo) com flicker de fogo.
> 4. Fumaça de chaminé determinística na casa (função pura do tempo,
> doutrina GrassField), no MESMO slot de profundidade do sprite.
> ============================================================================
> hoverFpsK: hover ACELERA a animação (fogo cresce, vento venta) — v9.6.
> hoverAnim: pasta de anim de ESTADO no hover (porta da casa abrindo);
> toca por progresso 0→1 (abre no enter, fecha no exit), não por loop.

## L1526-1527 (em `landmark_shop`, junto a `abyss_landmark_rest      = { fps = 10, pingpong = true, hoverFpsK = 1.8 },`)

> v11: os rest/elite POR ATO medem emenda ~2x (o genérico do ato 1 fecha
> o loop e roda direto). Ping-pong neles, medido um a um no compose.

## L1533-1535 (em `dusk_landmark_elite`, junto a `fields_castle    = { fps = 8, pingpong = true },`)

> v9.8: CASTELOS VIVOS (feedback: "totalmente estáticos") — bandeiras
> tremulam, janelas/fogo/olhos pulsam; frames em anim/<bid>_castle/.
> pingpong em todos (pano e brilho reiniciando no frame 0 dá pulo)

## L1543 (em `dusk_castle`, junto a `local LANDMARK_HOVER_SOUND = {`)

> som de hover por lugar (v9.6, ElevenLabs em audio/sfx/fork-hover-*.mp3)

## L1552-1556 (em `LANDMARK_HOVER_SOUND`, junto a `local LANDMARK_SHADOW_PAD = {`)

> v11: a chave CHEIA (<bid>_landmark_<tipo>) sobrepõe a do tipo — cada arte
> de ato tem seu próprio pé de parede e sua própria boca de chaminé, medidos
> no PNG (perfil de opacidade por linha, receita do v9.5).
> Out/2026: REMEDIDO depois do corte do chão assado (ver LMG) — a saliência
> que sobra é degrau/deck/vaso; estandartes = 0 (o pé é o mastro).

## L1559-1563 (em `LANDMARK_SHADOW_PAD`, junto a `highlands_landmark_shop = 4,  abyss_landmark_shop = 11,`)

> v11: TODA loja e TODA tenda de ato precisa de entrada própria, mesmo
> quando o valor é 0 — sem ela a chave cai na família e herdaria os 12
> da cabana do ato 1, jogando a sombra pra fora do pé. Medido no PNG:
> linhas do rodapé com menos de 75% da largura máxima são saliência
> (degrau, deck, monte), não parede.

## L1586 (em `LANDMARK_SMOKE`, junto a `landmark_shop = { xf = 0.325, yf = 0.02 },`)

> xf/yf = boca da chaminé em fração do canvas (medido no PNG)

## L1588-1590 (em `landmark_shop`, junto a `highlands_landmark_shop = { xf = 0.233, yf = 0.00 },`)

> color: ver drawLandmarkSmoke — valor escolhido CONTRA o céu do bioma
> céu ESCURO (colinas, abismo, pântano) → fumaça clara, a de sempre.
> céu CLARO (geleira, crepúsculo) → fumaça escura e densa, senão some.

## L1598-1612 (em `dusk_landmark_shop`, junto a `local LANDMARK_GENERIC_BIOME = "fields"   -- ato 1 = dono da arte genérica`)

> ============================================================================
> v11 (Set/2026) — LUGAR POR ATO: cada bioma tem sua loja, sua fogueira, seu
> estandarte, seu obelisco e sua tenda. Pedido do dono: "no ato 1 a loja é
> diferente, no ato 2 a loja é diferente, e isso para cada um dos locais".
>
> A chave vira `<bid>_landmark_<tipo>` quando a arte do bioma existe; senão
> cai no genérico E AVISA (fallback silencioso é PROIBIDO neste projeto).
> Os caminhos seguem os loaders que já existem, sem tocar neles:
> base   assets/sprites/world/<key>.png            (tryLoadPng)
> frames assets/sprites/world/anim/<key>/0..N.png  (readAnimFrames)
>
> As tabelas de configuração (tamanho, fps, som, sombra, luz, fumaça)
> continuam por TIPO — `landmarkFamily` tira o prefixo do bioma. Uma
> entrada com a chave CHEIA sobrepõe a do tipo quando a arte do bioma
> precisa de âncora própria (ex.: a chaminé muda de lugar).

## L1613 (em `dusk_landmark_shop`, junto a `local LANDMARK_GENERIC_BIOME = "fields"`)

> ato 1 = dono da arte genérica

## L1641-1644 (em `landmarkHoverAnimKey`, junto a `local function landmarkKeyFor(nodeType, bid)`)

> resolve tipo de nó + bioma → chave da arte. O conjunto do bioma é ATÔMICO:
> se o tipo tem anim de estado (porta da loja) e ela falta, o bioma inteiro
> volta pro genérico — meia-loja do bioma com a porta da cabana de outro
> seria um pulo de identidade na cara do jogador.

## L1653-1654 (em `landmarkKeyFor`, junto a `if bid == LANDMARK_GENERIC_BIOME then`)

> o ato 1 É o dono da arte genérica (pedido do dono: "a arte de hoje
> fica sendo a do ato 1") — não duplicamos os PNGs nem avisamos por ele

## L1693-1694 (em `landmarkFrames`, junto a `local function landmarkFrameAt(key, ft)`)

> frame do lugar num TEMPO-DE-FRAME absoluto (ft). O fork usa relógio
> próprio por braço (acumula dt — o hover acelera sem pular frame)

## L1708-1711 (em `landmarkFrameAt`, junto a `local function landmarkFrame(key, seed)`)

> frame pelo relógio global + fase (caminho da CHEGADA, sem hover).
> seed = fase própria (dois marcos iguais não piscam em uníssono).
> mod pelo PERÍODO real (pingpong = 2n-2) — preserva a continuidade do
> handoff fork → lugar também no vai-e-volta

## L1721-1735 (em `landmarkFrame`, junto a `local LMG = { NO_CRITTERS = {}, ORIG_H = {`)

> fumaça da chaminé: puffs determinísticos subindo/inchando/sumindo, no
> idioma do castelo (aglomerado de quadrados chunky, sem halo translúcido)
> ============================================================================
> CHÃO DOS MARCOS (Out/2026, dono: "os lugares da encruzilhada parecem
> colados no cenário"): os PNGs do PixelLab vinham com um remendo de chão
> ASSADO na base (laje, terra, monte de neve, tufo) na cor errada pro bioma.
> O remendo foi REMOVIDO da arte (base + quadros de anim; segmentação pela
> paleta do rodapé + flood por baixo do objeto, ver memory/weather_engine.md)
> e o rodapé vazio cortado. ORIG_H guarda a altura ANTIGA do canvas: o
> tamanho na tela continua o mesmo (g.scaleAt mira a altura do canvas — sem
> isso o objeto cresceria o tanto do remendo que saiu). O contato com o chão
> agora é a sombra projetada (ShadowEngine) sobre a estrada do bioma.
> (Uma tabela só: o escopo do arquivo está no teto de 200 locais do LuaJIT.
> Também guarda a lista vazia de critters — noite com vagalumes do clima.)
> ============================================================================

## L1753-1754 (em `LMG.refH`, junto a `function LMG.setTint(br, a)`)

> banho da LUZ DO BIOMA (mesma receita dos props: 16% da cor da névoa) —
> o marco genérico (chefe menor, baú) lê certo em qualquer bioma

## L1770-1773 (em `drawLandmarkSmoke`, junto a `local cr, cg, cb = 0.80, 0.77, 0.72`)

> v11: a fumaça vive CONTRA O CÉU, então o valor dela é do BIOMA, não da
> fumaça. Céu escuro (highlands, abyss) pede fumaça clara; céu claro
> (frost, dusk) pede fumaça escura e densa, senão ela simplesmente some.
> Mesma regra vale pra vapor e faísca que dependam de contraste com o céu.

## L1797-1799 (em `drawLandmarkSmoke`, junto a `local function submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK)`)

> micro-luz do lugar: âncora por conteúdo (centróide dos pixels mais
> claros — fogo/janela/orbe), flicker de fogo das luminárias.
> alphaK acompanha o fade do sprite (braço não-escolhido na convergência)

## L1815-1816 (em `submitLandmarkLight`, junto a `local fi = 0.86 + 0.14 * n`)

> v9.9.2: mesma receita dos postes (glow dither + núcleo) — o micro
> cru com raio grande virava um bloco quadrado no lightmap ¼

## L1830-1836 (em `submitLandmarkLight`, junto a `WorldRoad._hitScene = {}`)

> ============================================================================
> v9.7: CENÁRIO INTERATIVO (pedido: "tudo interativo no mapa, tipo
> Hearthstone") — clicar num prop dá uma mexidinha (pêndulo amortecido no
> pivô da base), copa solta folhinhas, cerca espanta os pássaros pousados,
> nuvem faz squash, e cada kind tem seu som. O registro de hit é refeito
> POR FRAME na ordem do painter (o teste varre do fim = mais perto 1º).
> ============================================================================

## L1838-1840 (em `WorldRoad._hitScene`, junto a `local POKE_SOUND = {`)

> v9.7.2: tuft/flowers FORA do mapa de poke (feedback: "não quero
> interação com a grama") — grama não tem som nem hitbox (ver skip no
> registro do painter); a vida dela vem do vento ambiente do GrassField.

## L1852-1854 (em `POKE_SOUND`, junto a `local POKE_SOUND_BIOME = {`)

> v9.7.2: MATERIAL por bioma (feedback: "o poste do bioma 1 é de MADEIRA
> e saía barulho de ferro") — override (bid, kind); default = POKE_SOUND.
> fields/marsh/dusk = poste de madeira; highlands/frost = ferro (catálogo).

## L1879-1880 (em `pokeRot`, junto a `local function drawLeafFx(p, bx, by, iw, ih, s)`)

> folhinhas caindo da copa clicada — desenhadas no MESMO slot do prop
> (REGRA DE PROFUNDIDADE); trajetória = função pura do tempo desde o clique

## L1946-1947 (em `WorldRoad.pokeSceneAt`, junto a `local function submitLandmarkOccluder(img, px, py, iw, ih, s, rel)`)

> lightmap: silhueta em flatColor (receita do monstro) — o lugar fica na
> cor da arte mesmo à noite/contraluz; luz de poste soma calor por cima

## L1968-1969 (em `flatColor`, junto a `local prewarmTick`)

> pré-aquecimento de bioma (definido lá embaixo, depois de todos os
> loaders — local declarada aqui pro update enxergar; lição do ciclo 41)

## L1974-1976 (em `WorldRoad.update`, junto a `prewarmTick()`)

> Out/2026: carrega/assa os assets do bioma ATUAL e do PRÓXIMO aos
> poucos (orçamento por frame) — a troca de ato engasgava 100-370 ms
> no 1º frame do bioma novo carregando tudo de uma vez

## L1981-1982 (em `WorldRoad.update`, junto a `local encA = WorldRoad._encounter`)

> v8.4: o monstro vem ANDANDO vivo (idle animada no billboard —
> "estático vindo é estranho")

## L2012-2013 (em `WorldRoad._landmark`, junto a `phase = animT - WorldRoad._time * fps,`)

> v9.6: fase que faz o relógio global CONTINUAR do
> relógio do braço — frame não pula no handoff

## L2029-2031 (em `WorldRoad._landmark`, junto a `f._animT = f._animT or {}`)

> v9.6: LUGARES REAGEM ao hover — relógio de animação POR BRAÇO
> (acumula dt; hover acelera fogo/vento sem pular frame) + progresso
> da anim de estado (porta da casa: abre no enter, fecha no exit)

## L2046-2047 (em `WorldRoad._landmark`, junto a `if f.hover ~= f._hoverPrev then`)

> som do lugar no ENTER do hover (pitch levemente variado —
> pattern Balatro anti-fadiga; sem som na convergência)

## L2059-2063 (em `WorldRoad._landmark`, junto a `do`)

> v9.7.2: a RAJADA no hover da grama (pokeAt + swish do v9.7) foi
> REMOVIDA a pedido ("barulho estranho, movimento esquisito — não
> quero interação com a grama"). Em compensação o vento AMBIENTE do
> GrassField subiu (WIND_* nos presets) — grama viva sem depender do
> mouse. Não reintroduzir hover/click na grama.

## L2065 (em `WorldRoad._landmark`, junto a `do`)

> v10.2: cerimônia de entrada — só porta abrindo + fade (SEM câmera)

## L2120-2121 (em `WorldRoad._landmark`, junto a `for i = #WorldRoad._props, 1, -1 do`)

> v10.3: relógio do cross-dissolve de troca de bioma. De trás pra frente
> porque remove fantasmas que terminaram de esvair.

## L2136-2138 (em `WorldRoad._landmark`, junto a `for _, p in ipairs(WorldRoad._props) do`)

> Reciclagem: passou da base → renasce atrás da crista. Preserva o
> LADO (simetria eterna) e a identidade de PAREDE (ciclo 22 — sem isso
> a treeline dissolvia em props pequenos conforme o jogador viajava)

## L2140-2142 (em `WorldRoad._landmark`, junto a `if not p.ghost and p.z - WorldRoad._camZ < -3.5 then`)

> 3.5 (era -0.5): dá tempo do slide-out do ciclo 25 tirar o prop
> da tela por completo antes de reciclar
> (fantasma nunca recicla — ele só esvai e sai da lista)

## L2158-2161 (em `WorldRoad._landmark`, junto a `do`)

> CLIMA (WeatherEngine, Out/2026): neve/chuva/cinza/folhas/sementes em
> coordenadas de MUNDO, empurradas pela mesma rajada do capim. Substitui
> as antigas partículas ambientais em tela (36 quadradinhos planos, sem
> profundidade nem vento).

## L2164-2165 (em `WorldRoad._landmark`, junto a `local walked = math.max(0, WorldRoad._camZ - (WorldRoad._segBase or 0))`)

> v2: densidade pela CHEGADA AO CASTELO (mesma conta do castelo
> crescendo) e vagalumes pela noite (luma do ambiente)

## L2173 (em `WorldRoad._landmark`, junto a `local wa = require("src.systems.WeatherAudio")`)

> SOM do clima: camas que nunca dão loop + avulsos + trovão

## L2180-2181 (em `WorldRoad._landmark`, junto a `local ct = WorldRoad._castleTop`)

> FUMAÇA DA CHAMINÉ do castelo: só quando perto (progress > 0.55) —
> "tem alguém lá" esperando você chegar

## L2235-2238 (em `WorldRoad._landmark`, junto a `local glowBio = LightEngine.ambientLuma() < 0.75`)

> CRITTERS: borboletas/vagalumes rasantes sobre a grama (vida no chão).
> LightEngine v1: ambiente ESCURO ganha MAIS vagalumes (cap 14) — eles
> são fonte de luz agora, não só detalhe. Gate por LUMINÂNCIA (F6.1:
> fields ao anoitecer também acende vagalumes, como na referência)

## L2243-2245 (em `WorldRoad._landmark`, junto a `local xr`)

> Spawn nas FAIXAS DE VEGETAÇÃO laterais (feedback: vagalume no
> meio da estrada lia como poste; ele vive no mato). ~12% ainda
> nascem em qualquer lugar — um ou outro cruzando o caminho é vivo.

## L2272-2277 (em `WorldRoad._landmark`, junto a `local skyTopColorCache = {}`)

> ============================================================================
> RENDER
> ============================================================================
> Cor do topo do strip de montanhas (o céu BAKED no PNG) — cacheada por bioma.
> O céu procedural preenche a área acima do strip com ESSA cor → emenda
> invisível (era o "retângulo escuro": sépia procedural vs azul do PNG).

## L2286-2287 (em `mountainsSkyColor`, junto a `local cx = math.floor(data:getWidth() / 2)`)

> desce a coluna central até achar um pixel OPACO e CLARO —
> pula outline/borda escura do topo do strip (bug: céu preto)

## L2320-2321 (em `baked`, junto a `local bandH = 8`)

> casa com o céu do PNG das montanhas: cor chapada + leve clareada
> nas bandas de baixo (chunky 8px)

## L2367-2368 (em `drawCelestialOf`, junto a `if cel.kind == "moon" then`)

> lua: disco cheio + CRATERAS (crescente via disco-de-céu deixava anel
> fantasma quando a cor amostrada não batia com o gradiente local)

## L2404-2407 (em `drawBirds`, junto a `local hazeShader, hazeShaderTried`)

> P2 (perspectiva atmosférica das nuvens): shaders/haze.glsl pinta a
> SILHUETA do sprite na cor do céu; o alpha da vertex color é a dose.
> Lazy + pcall: sem GPU/shader (tool headless, driver velho) o véu some e
> a nuvem só fica com o tint — degrada, não quebra.

## L2417-2419 (em `getHazeShader`, junto a `local CLOUD_HAZE = 0.42`)

> Quanto a nuvem converge pra cor do céu. Nuvem é o objeto MAIS DISTANTE
> da cena — deve ser o mais lavado de todos (Draw Paint Academy: o longe
> perde contraste e puxa pra cor do céu).

## L2422-2426 (em `getHazeShader`, junto a `local function normTint(t)`)

> O tint de bioma (`biome.cloud`) foi calibrado quando a nuvem era o
> cinza-neutro procedural do makeCloud. O PNG do PixelLab já vem CREME
> baked (239,213,184) — multiplicar o tint cru escureceria demais.
> Normalizar pelo canal máximo preserva o MATIZ do bioma e devolve o
> valor; quem cuida do brilho é o véu de névoa acima.

## L2435-2436 (em `drawClouds`, junto a `local sw = math.sqrt(w / 1024)`)

> escala acompanha (raiz da) largura da tela: no ultrawide o strip é
> gigante — nuvem em px fixo sumiria; no 4:3 não estoura

## L2438-2441 (em `drawClouds`, junto a `local tr, tg, tb = normTint(tint)`)

> BUG QUE ISSO CORRIGE: até aqui o RGB de `tint` era calculado e
> DESCARTADO (`setColor(1,1,1,a)`) — só o alpha sobrevivia. A nuvem
> creme aparecia igual sob qualquer céu; no abyss medimos 2,6× mais
> clara que o próprio céu, a ponto de ler como corpo celeste.

## L2443-2445 (em `drawClouds`, junto a `local sky = mountainsSkyColor(rawBiome().id) or envColor("skyHorizon")`)

> alvo do lerp: a cor do céu REAL atrás da nuvem. Com strip de
> montanhas full-bleed o céu é a cor amostrada do PNG (a mesma que
> drawSky usa) — usar `skyHorizon` do bioma ali erraria o alvo.

## L2453 (em `drawClouds`, junto a `local bob = math.sin(WorldRoad._time * 0.35 + (c.phase or 0)) * 4`)

> bob vertical suave (v5.8→v9.7: ±2.5 → ±4, "muito estáticas")

## L2458-2459 (em `drawClouds`, junto a `local sq = 1`)

> v9.7: clique = squash & stretch amortecido (origem no centro
> pra não deslocar a nuvem)

## L2473-2475 (em `drawClouds`, junto a `if hz and sky then`)

> passe 2: véu de névoa na MESMA silhueta e MESMO transform —
> lerp pra cor do céu. O sprite do passe 1 continua opaco: o
> alpha vive só aqui (regra do ciclo 24).

## L2491-2496 (em `drawClouds`, junto a `local _gradV, _gradH`)

> v6.1: texturas de gradiente reutilizáveis — rampa de alpha de 256
> passos (invisível a olho) que mata o banding das faixas de rects
> (névoa de distância, vinhetas). Cor final = textura * setColor, então
> a MESMA textura serve pra qualquer cor/alpha. Deliberadamente Image
> (caminho GL mais batido do projeto) e não Mesh — o driver NVIDIA da
> máquina é frágil (histórico 0xC00000FD).

## L2517-2519 (em `gradTex`)

> (v7: glowTex/CASTLE_GLOW_K REMOVIDOS — glow radial translúcido em cena
> pixel art lia como "mancha transparente de cor estranha", feedback direto.
> Luz em pixel art se DESENHA na paleta, não se sobrepõe com alpha.)

## L2521-2523 (em `gradTex`, junto a `local function sunShadowDir(g, x, w, px)`)

> v6.3: direção da luz da cena = posição do astro do bioma. Sombras de
> contato deslocam CONTRA o sol (coerência global barata, mesma ideia do
> shadow_parrallax do Balatro). Retorna deslocamento normalizado [-1,1].

## L2535-2537 (em `ridge`, junto a `local function stripTransform(g, x, w, camZ, iw, ih)`)

> Transform do strip gigante (v5.7): escala COVER + tiling espelhado.
> COMPARTILHADO entre o strip base e a camada frontal (mountains_front) —
> as duas precisam alinhar pixel-perfect pra oclusão de nuvem funcionar.

## L2557-2562 (em `drawStripTiles`, junto a `local function drawStripMirrorBelow(img, x, sx, yTop, tileW, off, bottomY)`)

> v5.9.4 (feedback): abaixo do strip, o PRÓPRIO strip INTEIRO de cabeça
> pra baixo, emendado na última linha de ARTE BOA — "é como se fosse uma
> continuação da parte debaixo do principal mas de cabeça para baixo".
> O rodapé chapado (degradê pra preto assado pela geração) foi CROPADO
> dos PNGs na fonte (scratchpad/crop_strip_footer.py, Jul/2026) — a
> última linha do strip é arte boa, então o espelho é o strip inteiro.

## L2593-2598 (em `drawMountainsOf`, junto a `local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)`)

> v5.7 (feedback): o background é GIGANTE — uma peça em escala COVER
> (máximo entre largura e a altura que alcança o topo do frame)
> preenchendo o céu inteiro com a arte do PNG (nada de céu chapado
> "fake" + sol duplicado de tiling). Nuvens/pássaros agora desenham
> POR CIMA dele (reordenado no draw). Só largura vazava o céu
> procedural em 4:3 (faixa roxa/listra no full3).

## L2602-2603 (em `drawMountainsOf`, junto a `drawStripMirrorBelow(img, x, sx, yTop, tileW, off, g.bottomY)`)

> v5.9.4 (feedback): strip inteiro espelhado verticalmente abaixo
> da última linha de arte — continuação de cabeça pra baixo

## L2611-2613 (em `drawMountains`, junto a `local bl = WorldRoad._blend`)

> crossfade na troca de bioma: NOVO por baixo a 100%, VELHO por cima
> esvaindo (1-t) — se o velho for mais alto, a sobra dele TAMBÉM esvai
> (na ordem antiga o céu baked do velho ficava como faixa fixa)

## L2626 (em `drawMountains`, junto a `local iw, ih = img:getWidth(), img:getHeight()`)

> fallback genérico: mesma regra GIGANTE/cover do drawMountainsOf (v5.7)

## L2648-2651 (em `drawMountains`, junto a `local function drawMountainsFrontOf(g, x, w, camZ, bid, alpha)`)

> CAMADA FRONTAL das montanhas (v5.8): a silhueta extraída do próprio
> strip (<bid>_mountains_front.png, céu transparente) redesenhada por cima
> das nuvens com o MESMO transform — nuvem em movimento passa ATRÁS dos
> picos sem stencil. Bioma sem PNG frontal (marsh) = sem oclusão.

## L2675-2681 (em `drawMountainsFront`, junto a `local CASTLE_APPROACH = {`)

> Castelo-destino: atrás do domo, centro da crista, escala por progresso.
> v10: LIMITE DE APROXIMAÇÃO mapeado por bioma (pedido: "mapear o limite
> de andada por bioma e ter salvo") — fator de crescimento no fim do
> trecho (s_max = base×(1+growth)). Calibrado por screenshot gate1..6;
> o clamp anti-corte abaixo garante que NENHUMA arte corta no topo.
> v10.5: growth calibrado pra ALTURA FINAL parelha entre biomas
> (ih varia 169-215px; alvo ~550-570px de castelo em 768p no fim)

## L2686-2691 (em `CASTLE_APPROACH`, junto a `local CASTLE_SINK_EXTRA = {`)

> v10.3 (feedback): no fim da aproximação alguns castelos ficavam "pra
> cima" e mostravam a BORDA INFERIOR da arte (fundação + grama/neve/musgo
> assados na base) flutuando acima da crista. highlands/abyss afunilam pro
> portão e assentam bem; fields/frost/marsh/dusk têm base larga → afundam
> um pouco mais pra enterrar essa borda no chão. Fração EXTRA de ih·s
> somada ao sink (só cresce perto, ∝ progress, pra não afetar o longe).

## L2696-2703 (em `drawCastleOf`, junto a `local walked = math.max(0, camZ - (segBase or WorldRoad._segBase or 0))`)

> v10: progresso POR TRECHO ancorado na troca de bioma — o castelo
> RESETA pra longe quando o bioma vira (o módulo antigo fazia a
> distância "dar a volta" no meio do ato).
> v10.2 (feedback): SÓ o crescimento natural da caminhada — sem cap,
> sem "boost" de câmera. A perspectiva de chegar perto vem só disso
> (como era antes); por volta do boss o castelo já está enorme e a
> porta abre no lugar. Empurrar a escala fazia o castelo SAIR da
> esfera (dava pra ver o fim da arte) e "parar/recuar" no fim = ERRADO.

## L2708-2710 (em `drawCastleOf`, junto a `img = landmarkFrame(bid .. "_castle", (bid:byte(1) + #bid) * 0.7) or img`)

> v9.8: castelo VIVO — frames PixelLab (bandeiras/janelas; estrutura
> estática, frame 0 = PNG base). Fase própria por bioma: no crossfade
> os dois castelos não pulsam em uníssono

## L2712-2717 (em `drawCastleOf`, junto a `do`)

> v10: ENTRADA — a abertura SUBSTITUI o frame vivo (anim de ESTADO em
> anim/<bid>_castle_door, indexada pelo progresso da fase "door" —
> mesma receita da porta da casa da loja). O frame 0 dessa anim TEM
> que ser igual à arte base do castelo: aqui a troca é seca, e
> qualquer diferença vira um pulo na cara do jogador quando doorK
> cruza 0.02 (ver v10.3 no cabeçalho de enterCastle).

## L2728-2733 (em `drawCastleOf`, junto a `local refW = math.min(w, g.h * 1.5)`)

> APROXIMAÇÃO (feedback v5): o castelo se aproxima de verdade — escala
> 1.0 → 4.2 ao longo do trecho (antes 1.0→2.5, "nem dava pra ver o
> portão"). Crescimento acelera no fim (progress^1.4): os últimos
> andares são a chegada dramática, portão dominante.
> v5.5: escala pelo MENOR entre largura e altura×1.5 — em tela larga o
> castelo escalado por w ficava gigante e cortado no topo

## L2735-2737 (em `drawCastleOf`, junto a `local baseScale = (refW * 0.155) / 218`)

> v9.9: escala por DENSIDADE DE PIXEL constante (referência = arte de
> ~218px) — antes dividia por iw e QUALQUER canvas esticava pra mesma
> largura; a torre estreita do highlands novo (164px) ficaria gorda

## L2742-2754 (em `drawCastleOf`, junto a `local sinkExtra = (CASTLE_SINK_EXTRA[bid] or 0) * progress`)

> v10.5 (feedback: "bem perto ele só sobe, não expande"): o CLAMP de
> escala foi REMOVIDO. Ele congelava o crescimento em ~56% do trecho
> (sMax ~1.76 numa curva que vai a ~3×) e a metade final da chegada
> virava só o slide do sink = "sobe sem crescer". PERTO = GRANDE, como
> no design original v5: o topo PODE sair do quadro no fim (fica atrás
> da topbar — é a sensação de estar ao pé do castelo). Quem protege o
> chão é o sink/sinkExtra (a base NUNCA sobe acima da crista) e o teto
> real é o growth mapeado por bioma (CASTLE_APPROACH, alturas finais
> parelhas ~550-570px em 768p).
> afundamento DIMINUI chegando: no fim só 3% da altura fica atrás da
> crista — o PORTÃO (base do sprite) sobe e fica totalmente visível.
> v10.3: + afundamento EXTRA por bioma (∝ progress) pra enterrar a
> borda inferior larga dos castelos que flutuavam no fim.

## L2758-2760 (em `drawCastleOf`, junto a `if alpha >= 1 then`)

> PÁTIO de terra no pé do castelo (v5.4, feedback "castelo parece
> colado"): elipse na cor da estrada onde ela encontra o portão —
> o castelo assenta num terreno batido, não numa grama lisa

## L2767 (em `drawCastleOf`, junto a `local shd = sunShadowDir(g, x, w, cx)`)

> v6.3: sombra direcional do castelo (contra o sol do bioma)

## L2775-2777 (em `drawCastleOf`, junto a `love.graphics.setColor(1, 1, 1, alpha)`)

> (v7: rim light aditivo e glow das janelas REMOVIDOS — cópia aditiva
> e halos translúcidos sobre sprite pixel art viravam franja/mancha de
> cor estranha. As janelas acesas já estão DESENHADAS no sprite.)

## L2782 (em `drawCastleOf`, junto a `if alpha >= 1 then`)

> topo do castelo (pra fumaça da chaminé) — só no passe principal

## L2790-2791 (em `WorldRoad._castleTop`, junto a `WorldRoad._castleBaseHalf = iw * s * 0.44`)

> v7.4.4: meia-largura da base (a franja de crista do GrassField
> pula esse vão — senão capim brota na frente do portão)

## L2794-2796 (em `WorldRoad._castleTop`, junto a `local LW = Config.Lighting.WINDOW`)

> LightEngine v1: micro-luzes POR JANELA (revisão F-1/F-7: a pedra
> escurece com o ambiente; só o entorno imediato das janelas volta.
> NUNCA uma luz única cobrindo o sprite — vira "adesivo diurno").

## L2800-2801 (em `WorldRoad._castleTop`, junto a `local wcol = (bio and bio.lightWindowColor) or LW.color`)

> cor da luz segue a JANELA PINTADA no castelo do bioma (marsh é
> verde, abyss é brasa) — luz laranja em castelo verde denuncia

## L2803-2806 (em `WorldRoad._castleTop`, junto a `local time = love.timer.getTime()`)

> v9.9.2 (feedback: "a luz do castelo é um quadrado estranho — usa
> o mesmo motor dos postes"): receita do LuminaireEngine — glow
> posterizado+dither COM flicker de fogo + núcleo micro pequeno,
> em vez do submitMicro cru de raio grande. Fase própria por janela.

## L2818-2819 (em `WorldRoad._castleTop`, junto a `LightEngine.submit({`)

> z=999: o castelo é o objeto mais FUNDO — qualquer silhueta
> (árvore, inimigo) na frente oclui a luz das janelas

## L2838-2839 (em `drawCastle`, junto a `drawCastleOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id,`)

> v10: o castelo que ESVAI usa a âncora do trecho anterior —
> continua na distância em que estava, sem pipocar pra longe

## L2846-2849 (em `drawCastle`, junto a `for _, sp in ipairs(WorldRoad._smoke) do`)

> fumaça da chaminé (atrás do domo, junto com o castelo)
> v7: puff = AGLOMERADO de pixels chunky (3 quadrados desencontrados) —
> forma gráfica desenhada, sem halo translúcido (feedback: halos leem
> como mancha em pixel art)

## L2864-2865 (em `drawCastle`, junto a `local function drawEncounterBehind(g, x, w, camZ)`)

> Inimigo emergindo de trás da curva (desenhado ANTES do preenchimento do
> domo → o disco oculta o corpo; só a parte acima da crista aparece).

## L2873 (em `drawEncounterBehind`, junto a `local em = 1 - (rel - REL_CREST) / EMERGE_BAND`)

> 0 = acabou de aparecer (todo atrás), 1 = na crista

## L2877-2879 (em `drawEncounterBehind`, junto a `local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3`)

> escala CONTÍNUA com o mundo: mesma persp-normalização do passe frontal
> em t=0 (antes era 0.5 fixo → o inimigo ENCOLHIA de repente ao cruzar a
> crista e ficava maior que árvore — quebrava a esfera)

## L2883-2884 (em `drawEncounterBehind`, junto a `cx = cx - math.floor((e.offX or 0) * s)`)

> v8.2: centro por conteúdo + pé cravado (consistente com o passe
> frontal — sem pulo ao cruzar a crista)

## L2892 (em `drawEncounterBehind`, junto a `if e.anim then`)

> v8.4: emergindo também animado

## L2900-2903 (em `drawEncounterBehind`, junto a `local function drawPropsBehind(g, x, w, camZ)`)

> PROPS EMERGINDO da curvatura (ciclo 23, feedback): árvores e itens na
> faixa além da crista (REL_CREST..+EMERGE_BAND) desenham ANTES do fill do
> domo, com a base afundada — o domo tampa a parte de baixo do corpo, igual
> ao monstro. Antes eles simplesmente pipocavam ao cruzar a crista.

## L2905-2906 (em `drawPropsBehind`, junto a `if WorldRoad._fork then return end`)

> durante o fork os marcos ocupam a faixa central — emersão pausa
> (câmera parada; ninguém percebe e nada nasce em cima dos marcos)

## L2910 (em `drawPropsBehind`, junto a `local fadeA = propFadeK(p)`)

> v10.3: alpha do cross-dissolve de troca de bioma (1 fora da troca)

## L2916-2917 (em `drawPropsBehind`, junto a `local edef = LuminaireEngine.def(p.bid, p.kind)`)

> v9.2: roadside emerge já colado na borda da estrada (mesma
> fórmula do drawProps em t=0 — sem pulo ao cruzar a crista)

## L2925-2927 (em `drawPropsBehind`, junto a `if edef and crest and img and math.abs(pxX - g.cx) < w * 0.26 then`)

> v9.2: LUMINÁRIA emergindo — mesma lógica do drawProps (flip
> pro braço apontar pra estrada + frame animado + luz acesa).
> Antes emergia com sprite cru, sem flip nem chama.

## L2951-2953 (em `drawPropsBehind`, junto a `local flameTopY = baseY - ih * s * (1 - (lumAnc.ay or 0.3))`)

> luz: núcleo na chama (poça só quando t alto → aqui não).
> só quando o topo já saiu do domo (senão a chama fica
> ENTERRADA e vaza luz por baixo do horizonte)

## L2965-2966 (em `drawPropsBehind`, junto a `alphaK = fadeA,`)

> v10.3: a luz esvai JUNTO com a luminária trocada
> (senão sobra poça órfã de um poste que já sumiu)

## L2973-2978 (em `drawPropsBehind`, junto a `if crest and img and math.abs(pxX - g.cx) < w * 0.26 then`)

> ciclo 30/33: emersão SÓ na faixa central do horizonte. O
> clamp por crestYAt (c30) era raso demais — a curva dip é
> pequena perto do topo e árvores a 0.4w ainda emergiam nas
> laterais (domo pintava faixa de grama POR CIMA das copas,
> "sanduíche" com as árvores da frente). Critério certo:
> distância HORIZONTAL do centro, como o inimigo na estrada.

## L2986 (em `drawPropsBehind`, junto a `if p.cluster then`)

> companheiras de cluster emergem junto (senão pipocam)

## L3013-3016 (em `drawPropsBehind`, junto a `local GROUND_TEX_W, GROUND_TEX_H = 128, 96`)

> ============================================================================
> TEXTURA DO DOMO: tile seamless por bioma (clumps de 3 tons + pontinhos),
> baked 1x e cacheada. Rola verticalmente com camZ = a terra GIRANDO.
> ============================================================================

## L3036-3038 (em `light`, junto a `local mid = { (base[1] + dark[1]) / 2, (base[2] + dark[2]) / 2, (base[3] + dark[3]) / 2 }`)

> V2: 4 tons + acento do bioma + clumps em OITAVAS (grande→pequeno) —
> randomização natural: manchas grandes definem regiões, médias quebram,
> pequenas dão grão; cores todas da MESMA família (se respeitam)

## L3069-3070 (em `clump`, junto a `for _ = 1, 16 do`)

> acentos do bioma (florzinhas/cristais/brasas espalhados esparsos)
> v6.5: 9→16 (a referência tem flores pontuais espalhadas no gramado)

## L3078-3079 (em `clump`, junto a `for _ = 1, 26 do`)

> v6.5: LÂMINAS de capim — pares verticais claros de 2px (dão fio à
> grama; sem eles a textura é só manchas)

## L3095-3101 (em `clump`, junto a `local GROUND_V_DENSITY = 4.8   -- texels de textura por unidade de mundo`)

> Preenchimento do DOMO em MODO-7 REAL: linhas horizontais respeitando o
> círculo (largura de cada linha = corda do círculo naquele y), com TEXELS
> CRESCENDO conforme se aproximam (profundidade de verdade — antes a textura
> era escala única e parecia adesivo plano) e V mapeado pela MESMA curva de
> profundidade dos props (rola coerente com tudo).
> ⚠️ SEM love.graphics.stencil: a versão com stencil CRASHAVA o driver
> NVIDIA (0xC00000FD em nvoglv64) e envenenava o OpenGL da máquina inteira.

## L3103-3113 (em `clump`, junto a `local domeSlots = {}`)

> Textura do domo em FATIAS DE LATITUDE (igual à estrada): cada linha de
> profundidade é dividida em segmentos que deitam no arco REAL da esfera —
> as fileiras do padrão CURVAM pra baixo nas bordas como a crista. Antes as
> linhas eram horizontais retas e contradiziam o arco da estrada (era o
> resto da "curvatura contrária" que sobrava no campo próximo).
> Out/2026 (perf): as ~15-40k fatias viraram quads num QuadMesh (FFI) em
> vez de setViewport+draw por fatia (custava 2-6 ms de chamadas C/frame).
> MESMA geometria e UV de antes, quad a quad. E como o chão só depende de
> câmera/geometria/bioma/alpha, com a câmera parada (batalha) o lote é
> reaproveitado inteiro: 1 draw, zero Lua. Um slot por camada do
> crossfade (bioma anterior + atual).

## L3123-3124 (em `ds`, junto a `if ds.camZ ~= camZ or ds.x ~= x or ds.w ~= w or ds.cx ~= g.cx`)

> (alpha do crossfade fica FORA da chave: vai na cor global do draw —
> senão a camada que entra reconstruía o lote inteiro a cada frame)

## L3131 (em `ds`, junto a `WorldRoad._domeBuilds = (WorldRoad._domeBuilds or 0) + 1`)

> (trava de perf)

## L3149-3152 (em `ds`, junto a `local SEG = (t < 0.3) and 8 or 32`)

> v5.6: SEG adaptativo — perto da CRISTA (t<0.3), onde a borda da
> esfera é visível, fatias de 8px (curva lisa); no corpo, 32px.
> Fatias de 32px na borda viravam "retângulos" (feedback: "não é
> um círculo perfeito, tem partes retas").

## L3177-3183 (em `drawDome`, junto a `love.graphics.setColor(grassB[1] * 0.78, grassB[2] * 0.78, grassB[3] * 0.78, 1)`)

> fundo chapado (segura o blend de cor por baixo da textura).
> ciclo 35: ESCURO (grassB×0.78), não grassA — as fatias de textura
> assentam na latitude do CENTRO do segmento e perto da borda lateral
> o degrau expõe o círculo-base em escadinha; claro, virava um ARO DE
> BRILHO contornando a esfera inteira ("o brilho lá da borda, o final
> da esfera", visível em todos os biomas). Escuro, vira sombra de
> borda — natural numa esfera.

## L3197-3200 (em `drawDome`)

> SOMBRAS DE NUVEM: REMOVIDAS (ciclo 26) — as elipses deslizando no
> gramado liam como "bolas sem sentido" e, quando passavam sob uma
> árvore, como sombra flutuante descolada dela. Nuvem de background
> distante não projeta sombra no chão do primeiro plano.

## L3202-3205 (em `drawDome`)

> (v7: "faixa de luz aditiva" da crista REMOVIDA — véu amarelado
> translúcido sobre o gramado lia como mancha, não como sol. Luz em
> pixel art se desenha na paleta — o realce da crista fica por conta
> do arco claro opaco lá embaixo.)

## L3207-3209 (em `drawDome`, junto a `do`)

> v5.6: TAMPA LISA da silhueta — arco exato do círculo por cima da
> borda da textura (as fatias escadinham; o arco esconde os degraus
> com uma curva contínua na cor do topo do domo). Largura total.

## L3219-3223 (em `drawDome`, junto a `local bandH = (g.bottomY - g.crestApexY) * 0.22`)

> luz sutil da crista (banda clara fina na curva — SEM pontinhos).
> ciclo 32: era circle() COMPLETO — o arco descia pelas laterais POR
> CIMA das árvores da treeline ("a corzinha da borda aplicada nas
> árvores à frente"). Agora é ARCO limitado à faixa central do
> horizonte (regra do ciclo 30: lateral é borda do mundo, não crista)

## L3226-3227 (em `drawDome`, junto a `phiMax = math.min(phiMax, math.asin(math.min(1, w * 0.26 / g.R)))`)

> ciclo 33: teto horizontal (curva rasa → o arco por altura alcançava
> ~0.54w e ainda tocava as árvores laterais)

## L3236-3242 (em `drawDome`, junto a `local function drawTerrainDetail(g, x, w, camZ)`)

> ============================================================================
> v7: DETALHE DE TERRENO EM PIXEL NATIVO (feedback: "pense em algo que
> combine com nosso 3D — pequenos relevos, gramas, matos que façam sentido
> com o terreno"). NADA translúcido, NADA de asset avulso: tufos de capim e
> dobras de relevo DESENHADOS na família de cor do gramado do bioma,
> ancorados no mundo (rolam com o domo) e seguindo a latitude da esfera.
> ============================================================================

## L3246-3247 (em `drawTerrainDetail`, junto a `local dark  = { gB[1] * 0.70, gB[2] * 0.70, gB[3] * 0.70 }`)

> família de tons do próprio gramado — contraste FORTE (em paleta
> escura como o fields, ×1.2 sumia; a leitura vem das pontas claras)

## L3252-3254 (em `light`, junto a `local CELL_R = 3.1`)

> LOMBADAS DE RELEVO: arcos que LEVANTAM do chão seguindo a
> latitude da esfera — aresta clara em cima (pega luz), vinco escuro
> embaixo (sombra). Relevo desenhado na linguagem do nosso 3D.

## L3292-3294 (em `light`, junto a `love.graphics.setColor(1, 1, 1, 1)`)

> (v7.1: os tufos estáticos que ficavam aqui foram PROMOVIDOS ao motor
> dedicado engine/GrassField.lua — lâminas individuais com física de
> vento, chamado via drawGrass depois da estrada.)

## L3298-3299 (em `light`, junto a `local roadTileCache = {}`)

> Tile DEDICADO de terra (PixelLab, ciclo 10): base texturizada da estrada.
> road_dirt_<bid>.png > road_dirt.png > nil (fallback: cores chapadas).

## L3315-3321 (em `getRoadTile`, junto a `local FORK_REL    = 10    -- onde a estrada se divide`)

> ============================================================================
> FORK — A ENCRUZILHADA (v5): a estrada se bifurca em 2-3 braços e cada
> braço tem um MARCO (landmark PixelLab) dizendo o que o caminho é.
> Substitui o MapScreen quando estamos na estrada. Contrato: showFork(nodes,
> onChosen) → clique num braço → convergência (braço vira a estrada central
> enquanto a câmera avança) → onChosen(node, index).
> ============================================================================

## L3329-3330 (em `WorldRoad.showFork`, junto a `WorldRoad._landmark = nil`)

> nova encruzilhada = deixamos o lugar anterior pra trás (feedback:
> "depois que seleciona, a opção continua aparecendo na tela")

## L3368-3377 (em `forkAlpha`)

> ============================================================================
> v7.1: GRAMA VIVA — engine/GrassField.lua (motor dedicado de vegetação).
> Cores vêm do envColor (lerpam no crossfade); geometria/estrada INJETADAS.
> Desenhada DEPOIS da estrada (margem invade a borda do caminho).
> Definida DEPOIS de forkOffset (local abaixo = nil pra função de cima,
> lição do ciclo 41): na encruzilhada o capim respeita CADA braço em vez
> de abrir um clarão único ("sem grama demais entre e em volta deles").
> ============================================================================
> (v9.7.1: o require do GrassField subiu pro topo do arquivo — o update
> usa a rajada do mouse e locals daqui não existem pra quem vem antes)

## L3379-3382 (em `forkAlpha`, junto a `local _grassCtx, _grassCtxFrame, _grassFork`)

> relFrom/relTo (v7.5): janela de profundidade — o drawProps intercala
> fatias de grama entre as árvores (capim na frente do pé cobre o pé).
> O ctx é construído 1x POR FRAME e reutilizado entre as fatias:
> reconstruir tabela+closures por fatia dava ~200 alocações/frame (GC)

## L3390-3391 (em `drawGrass`, junto a `local lum = (gA[1] + gA[2] + gA[3]) / 3`)

> boost ADAPTATIVO da ponta clara: em paleta escura (fields ~0.16
> de luminância) o ×1.42 fixo sumia no fundo

## L3407-3408 (em `roadHalf`, junto a `roadCenters = function(z, t)`)

> encruzilhada: centros de CADA braço naquela profundidade
> (nil = estrada única) + fator de largura (0.78 com 2-3)

## L3418-3420 (em `roadCenters`, junto a `ws[i] = forkAlpha(f, i)`)

> clareira do braço ACOMPANHA o fade dele: braço que
> some na convergência devolve a grama junto (antes a
> estrada sumia e a clareira ficava → faixa lisa)

## L3441-3443 (em `light`, junto a `_grassCtx.frame = WorldRoad._drawFrame`)

> frame de DESENHO (não o relógio): com o mundo pausado o _time não
> anda, mas cada draw é um frame novo — o GrassField zera o cursor
> do lote por frame (senão o buffer cresceria a cada frame pausado)

## L3445-3448 (em `light`, junto a `local f = WorldRoad._fork`)

> assinatura do fork (tudo que move os braços no forkOffset): o
> GrassField reusa o lote da grama enquanto a cena não muda, e o
> roadCenters lê o fork AO VIVO — sem isso o cache não veria a
> encruzilhada abrindo/convergindo

## L3488-3489 (em `f.converge`, junto a `WorldRoad.pokeSceneAt(mx, my)`)

> v9.7: clique fora dos marcos CUTUCA o cenário (mapa vivo estilo
> Hearthstone) — só juice/som, nenhum efeito de gameplay

## L3495-3498 (em `f.converge`, junto a `local function drawRoad(g, x, w, camZ)`)

> Estrada de terra: faixa do castelo (crista) até a base — tile rolando em
> modo-7 (quando existe) + manchas orgânicas + sulcos + pedrinhas + bordas.
> v5: quando o fork está ativo, fileiras além de FORK_REL pintam UMA VEZ POR
> BRAÇO (centro deslocado + largura menor) — a estrada literalmente se abre.

## L3509-3512 (em `drawRoad`, junto a `local qm = WorldRoad._roadQM`)

> Out/2026 (perf): cada fatia/retângulo vira um quad no QuadMesh (FFI)
> na MESMA ordem de antes (tile da fileira → decoração → próxima
> fileira por cima); 1 draw no fim. Retângulo chapado = quad SEM
> textura (u sentinela + shader do lote). Antes: ~7-12k chamadas C.

## L3529-3532 (em `hash`, junto a `local t, rel, worldZ, half0, edgeAmp, eL, eR, rowId, blend, m`)

> estado da FILEIRA corrente (upvalues do paintRow): o paintRow era
> uma closure criada POR FILEIRA — criação de função no laço aborta o
> JIT (NYI), e com o lote em FFI o interpretador ficava MAIS lento
> que as chamadas C de antes. Agora é 1 closure por frame.

## L3544-3546 (em `paintRow`, junto a `local jag = 14 * (0.35 + 0.65 * t)`)

> BORDA SERRADA (ref APK do usuário): degraus irregulares por
> faixa de mundo (rowId) — tijolos "saltando" da borda em
> escadinha, não linha lisa. É isso que faz parecer caminho real.

## L3559-3562 (em `paintRow`, junto a `local vx = (segX - cxRow) / hs + tw * 0.5`)

> v10.1: sampling CENTRADO no eixo da estrada (antes:
> offset u aleatório por faixa) — os sulcos de roda e o
> desgaste central assados na textura SEGUEM a curva do
> caminho (e cada braço do fork ganha os seus)

## L3611 (em `paintRow`, junto a `local yL = math.floor(g.latY(xL - cx, t))`)

> bordas quebradas + pedrinha da transição

## L3629-3631 (em `paintRow`, junto a `if newRow then`)

> v6.5: DITHER de transição terra↔grama — salpicos dos dois
> lados da borda (denso perto, esparso longe). A emenda vira
> meio-tom orgânico em vez de linha serrada dura.

## L3652-3653 (em `paintRow`, junto a `if newRow and hash(rowId * 41 + 5) > 0.45 then`)

> GRAMA INVADINDO a estrada (v5.4, feedback): fiapos verdes
> entrando pelas bordas — transição orgânica terra↔gramado

## L3677-3679 (em `paintRow`, junto a `m = 0.97 + hash(rowId) * 0.04`)

> v10.1: banda de brilho por faixa MUITO mais sutil (0.10→0.04) —
> a superfície sintetizada carrega a variação; a banda forte por
> cima re-achatava tudo em listras horizontais

## L3681-3686 (em `paintRow`, junto a `if tile then`)

> v10.1: superfície SINTETIZADA por bioma (engine/RoadSurface —
> clusters tonais + micro-relevo top-light + sulcos contínuos +
> desgaste central) no lugar do PNG tileado ("textura padrão
> replicada, sem profundidade/desnível" — feedback). PNG segue
> como fallback se o bake falhar.
> (tile resolvido 1x fora do laço — mesmo valor em toda fileira)

## L3698-3699 (em `paintRow`, junto a `local wob = roadWobble(worldZ, t, w)`)

> MEANDRO ORGÂNICO: centro serpenteia (roadWobble compartilhado
> com TODAS as âncoras — inimigo, marcos, chegada seguem a curva)

## L3703-3704 (em `paintRow`, junto a `local kk = (rel - FORK_REL) / (MARK_REL - FORK_REL)`)

> largura do braço COMEÇA em 100% no ponto do fork e afina
> conforme os braços se separam (fix: "quebra fininha" na junção)

## L3731-3743 (em `paintRow`, junto a `WorldRoad._forkLabelCache = { locale = nil, byType = {} }`)

> v9.4 (feedback: "as paradas flutuam / pulam no hover / postes da frente
> ficam atrás delas"): o SPRITE físico do marco agora desenha DENTRO do
> painter (drawForkPhysical, em drawProps) — intercalado por profundidade
> como qualquer prop, com sombra projetada única e silhueta legível no
> lightmap. Aqui (overlay pós-composite) fica SÓ a UI: pill com nome +
> descrição no hover. Sem bob: parada é LUGAR, não botão.
> Rótulo/descrição do marco no idioma ATUAL, pelo tipo do nó. O nó salvo
> carrega `label`/`desc` no idioma em que foi gerado (save antigo, troca de
> idioma com a run salva) — só vale como último recurso, pra tipo sem chave.
> Cache por (idioma, tipo): roda a cada quadro no draw da encruzilhada e o
> I18n.t aloca (test_perf_budget: 386 KB/quadro sem o cache). Troca de
> idioma invalida sozinha (a chave inclui o locale). Mora em campo do
> módulo, não em `local`: o arquivo está no teto de 200 locais do LuaJIT.

## L3802-3803 (em `drawForkMarks`, junto a `local shOptPool, shOptN = {}, 0`)

> (pool de opts de sombra declarado AQUI porque drawLandmarkFront, logo
> abaixo, já usa — local Lua só existe depois da definição)

## L3819-3820 (em `shadowOpts`, junto a `local function drawLandmarkFront(g, x, w, camZ)`)

> Marco "onde chegamos" (pós-convergência): fica plantado no centro da
> estrada e desliza naturalmente quando a próxima viagem acontecer.

## L3830 (em `drawLandmarkFront`, junto a `img = landmarkFrame(lm.key, lm.phase or lm.z) or img`)

> v9.5: o lugar continua VIVO depois da chegada (mesmos frames do fork)

## L3836 (em `drawLandmarkFront`, junto a `local shPad = lmCfg(LANDMARK_SHADOW_PAD, lm.key) or 0`)

> v8: sombra projetada da silhueta (v9.5: ancorada na base da parede)

## L3851 (em `drawLandmarkFront`, junto a `drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, 1)`)

> v9.5: vida contínua + legibilidade noturna (mesma receita do fork)

## L3857-3859 (em `drawLandmarkFront`, junto a `local function drawCrestFog(g, x, w)`)

> Props do lado de cá da crista (crescem descendo o domo)
> Névoa atmosférica na crista (pesquisa: perspectiva atmosférica — o longe
> perde contraste e puxa pra cor do céu). Banda fina seguindo a CURVA.

## L3862-3864 (em `drawCrestFog`, junto a `local fogLimitY = g.crestApexY + (g.bottomY - g.crestApexY) * 0.22`)

> ciclo 28: névoa SÓ na faixa do horizonte (topo da crista). A curva
> da crista desce até os cantos da tela, e a névoa seguindo ela pintava
> a "borda do mundo" POR CIMA das árvores laterais (feedback dusk)

## L3870-3871 (em `drawCrestFog`, junto a `local dx = math.abs((x + sx) - g.cx)`)

> ciclo 33: também limita HORIZONTAL (a curva é rasa no topo e o
> clamp por altura sozinho deixava a névoa alcançar ~0.6w)

## L3874-3875 (em `drawCrestFog`, junto a `local fade = 1 - (dx / halfW) ^ 2`)

> v6.1: gradiente por textura + fade horizontal suave (o corte
> seco em 0.30w era um degrau vertical visível)

## L3884-3888 (em `drawCrestFog`, junto a `local propZDesc = function(a, c) return a.z > c.z end`)

> POOLS POR FRAME (Out/2026, perf): o drawProps alocava ~100 KB/frame em
> tabelas de vida de 1 frame (opções de sombra, oclusores, hitboxes,
> listas de passe) — lixo que o GC recolhia em picos. Os consumidores
> (ShadowEngine.flush, LightEngine.composite, hit-test do clique) leem
> tudo DENTRO do mesmo frame, então cada slot é reaproveitado no próximo.

## L3912-3914 (em `drawProps`, junto a `local farPass = _farPass`)

> passe 1: props DISTANTES (t < 0.25) — depois recebem a névoa por cima
> passe 2: névoa da crista
> passe 3: props do meio/perto — nítidos, na frente da névoa

## L3926-3930 (em `drawProps`, junto a `local grassRel = REL_CREST + 2`)

> v7.5: GRAMA INTERCALADA por profundidade — antes de cada prop,
> descarrega a fatia de capim mais distante que ele (painter real:
> capim na frente do pé da árvore COBRE o pé; atrás, fica atrás).
> Quantizado em 0.35 z-units: árvores quase na mesma profundidade
> compartilham 1 flush (menos overhead por fatia)

## L3936-3937 (em `flushGrassTo`, junto a `WeatherEngine.flushTo(relLow)`)

> clima da MESMA fatia: floco no ar/pousado nessa profundidade
> (o capim e as árvores mais perto vêm depois e o cobrem)

## L3942-3947 (em `flushGrassTo`, junto a `local fkMarks = nil`)

> v9.4: MARCOS DO FORK são LUGARES DO MUNDO — o sprite desenha AQUI,
> no slot de profundidade de MARK_REL (REGRA DE PROFUNDIDADE: poste/
> árvore mais perto desenha DEPOIS, na frente). Sombra projetada única
> (o disco de glow saiu — lia como sombra dupla) e silhueta com
> flatColor no lightmap (legível à noite, luz de poste soma por cima).
> A UI (pill/descrição) continua no overlay pós-composite.

## L3971-3974 (em `drawForkPhysical`, junto a `local animT = f._animT and f._animT[i]`)

> v9.5: lugar VIVO — frame da animação (fase própria por
> braço). v9.6: relógio próprio do braço (hover acelera
> fogo/vento); porta da casa é anim de ESTADO — substitui
> o frame do loop enquanto abre/fecha (progresso _hoverK)

## L3999-4002 (em `drawForkPhysical`, junto a `local shPad = lmCfg(LANDMARK_SHADOW_PAD, key) or 0`)

> sombra projetada (ÚNICA sombra — coerente com o resto).
> v9.5: ancorada na BASE DA PAREDE (footPad): na casa as
> últimas linhas do sprite são a escada avançando pro 1º
> plano e a sombra nascia "na frente" do pé (feedback)

## L4017-4018 (em `drawForkPhysical`, junto a `drawLandmarkSmoke(key, px, py, iw, ih, s, aMul)`)

> v9.5: coisinhas vivas do lugar (fumaça de chaminé) +
> micro-luz da chama/janela/orbe — mesmo slot de profundidade

## L4022-4023 (em `drawForkPhysical`, junto a `if aMul > 0.6 then`)

> lightmap: silhueta legível à noite. Só com alpha cheio (na
> convergência o sprite some — silhueta fantasma no chão).

## L4047-4048 (em `drawList`, junto a `if fkMarks and not fkMarks.drawn and rel < fkMarks.rel then`)

> v9.4: marcos do fork entram no painter NO SLOT deles — props
> mais perto (rel menor) desenham depois, NA FRENTE dos marcos

## L4055-4067 (em `drawList`, junto a `local over = math.max(0, -rel)`)

> CUNHA (ciclo 21, ref APK): zona permitida = triângulo que vai
> da lateral do castelo (crista) até o CANTO de baixo da tela.
> inner cresce com t → na base só os cantos extremos têm props;
> o corredor central da estrada fica sempre limpo.
> ciclo 24: funil mais fechado (0.13+0.44t → 0.11+0.38t)
> ciclo 25: SAÍDA REAL — depois de passar por você (rel<0) o
> prop desliza pra fora pelo canto (acelera pra fora e pra
> baixo) em vez de sumir de repente com meia copa na tela
> v9.2 (feedback: "saída sai da tela rápido demais e diagonal;
> deixar mais lenta e mais reta, seguindo o movimento do mundo"):
> empurrão lateral 0.16→0.09 (diagonal mais VERTICAL) e a
> descida 0.20→0.13 (linger — acompanha a perspectiva em vez de
> disparar pro canto)

## L4071-4075 (em `drawList`, junto a `local rdef = LuminaireEngine.def(p.bid, p.kind)`)

> v9.2 (feedback: "postes têm que ficar na borda da estrada,
> não longe"): luminária ROADSIDE ancora na meia-largura REAL
> da estrada (mesma fórmula do corredor do fork), não na cunha
> das árvores — o poste ilumina o caminho, o braço pende
> por cima dele

## L4087-4089 (em `drawList`, junto a `local fadeA = propFadeK(p)`)

> v10.3: alpha do cross-dissolve de troca de bioma (1 fora da
> troca). O fantasma do prop velho esvai enquanto o prop novo,
> já re-sorteado, aparece — MESMO slot de profundidade.

## L4093-4096 (em `drawList`, junto a `if img and WorldRoad._fork and rdef and rdef.roadside`)

> v9.4.1 (feedback: "não seria bom aparecer poste na parte de
> escolher"): enquanto o fork está ativo, poste ROADSIDE da
> faixa da FRENTE some — ele ficava na frente das paradas e
> virava ruído na hora da escolha. Volta quando a viagem segue.

## L4101-4103 (em `drawList`, junto a `if img and WorldRoad._fork and rel > FORK_REL - 1.5 then`)

> CORREDOR DO FORK (feedback: "árvores não podem ocupar os
> caminhos"): com a estrada bifurcada, props que caem sobre
> QUALQUER braço somem enquanto o fork existe

## L4123-4125 (em `drawList`, junto a `local lumDef = LuminaireEngine.def(p.bid, p.kind)`)

> LuminaireEngine v9: centragem POR CONTEÚDO (offX/footPad
> do canvas) — lição dos monstros: margem do PixelLab
> descentra o prop e deixa o pé flutuando

## L4131-4134 (em `drawList`, junto a `if lumDef.face and lumDef.face ~= 0 then`)

> v9.1 (feedback: "todos apontados pro mesmo lugar"):
> o braço do poste aponta SEMPRE pra estrada — prop à
> esquerda quer braço pra direita e vice-versa; espelha
> quando a arte nasceu virada pro lado errado

## L4141-4143 (em `drawList`, junto a `local fr = luminaireFrames(p.bid, p.kind, p.variant)`)

> v9.1: fogo ANIMADO (frames PixelLab, corpo estático).
> Fase própria por prop (p.z) — nada pisca em uníssono
> (doutrina "randomize tudo"). Sombra segue o frame.

## L4156-4158 (em `drawList`, junto a `if p.cluster and (p.kind == "tree" or p.kind == "pine"`)

> CLUSTER natural (feedback: "muito solto"): árvores vêm em
> grupos de 2-3, companheiras menores atrás/ao lado — como
> vegetação de verdade, não pontos isolados

## L4161-4164 (em `drawList`, junto a `for ci = 1, p.cluster do`)

> ciclo 19: offsets antigos (±0.55-0.62×iw, escala ~igual)
> empilhavam 3 árvores no mesmo pixel — agora cada
> companheira afasta ~1 largura pro seu lado, é bem menor
> e apoia no chão da PRÓPRIA latitude (com sombra)

## L4166-4167 (em `drawList`, junto a `local off = p.side`)

> só pra FORA (p.side): offset ± deixava a companheira
> interna invadir a estrada (árvore no meio do caminho)

## L4177-4179 (em `drawList`, junto a `ShadowEngine.queue(cimg, cx2, cy2 - 1, cs,`)

> v8: sombra projetada da companheira
> footPad = raiz enterrada (PropCut): a sombra
> nasce no pé VISÍVEL, não na raiz recortada

## L4191-4192 (em `drawList`, junto a `if p.kind == "fence" then`)

> CERCA = LINHA de 3 segmentos ao longo da estrada (cerca
> solitária "jogada no nada" não existe no mundo real)

## L4194-4196 (em `drawList`, junto a `for fi = 1, (t >= 0.35 and 2 or 0) do`)

> ciclo 20: espaçamento 0.85→1.7 (em t médio os segmentos
> comprimiam num bolo — "cercas todas juntas"); de longe
> (t<0.35) nem desenha os extras, só o segmento principal

## L4216-4226 (em `drawList`, junto a `local aFade = math.min(1, 0.72 + t * 1.1)`)

> v8: SOMBRA PROJETADA da silhueta (ShadowEngine) —
> substitui a elipse "círculo nos pés": a própria forma
> do sprite deitada no chão, cisalhada pra longe do sol,
> comprimento pelo horário. ENFILEIRADA: desenha depois
> de props+grama (a sombra cai SOBRE a grama — imediata,
> o tapete mais próximo cobria). Fallback: elipse legada.
> footPad: margem da luminária OU raiz enterrada da árvore
> (PropCut, Out/2026) — o sprite é desenhado sem as linhas
> de raiz, então a sombra ancora no pé VISÍVEL; com o canvas
> inteiro as linhas da raiz viravam pra cima do contato e
> escureciam a base do tronco por cima do sprite.

## L4239-4240 (em `drawList`, junto a `local rot = 0`)

> BALANÇO de vento (vegetação viva): rotação sutil no pivô
> da base, fase única por prop (p.z)

## L4248-4251 (em `drawList`, junto a `local wP = GrassField.PRESETS[p.bid or rawBiome().id]`)

> WeatherEngine v1: a MESMA rajada que deita o capim
> inclina a copa — CISALHAMENTO com pivô no pé (linhas
> de pixel só deslizam; rotação serrilharia o sprite).
> A frente de rajada atravessa capim → árvore → ar.

## L4259-4260 (em `drawList`, junto a `if gw * gw > 1.6 and p.kind ~= "deadtree" and t > 0.25`)

> rajada forte arranca folha da copa (cai no clima,
> com a cor do capim do bioma; árvore seca não)

## L4271-4274 (em `drawList`, junto a `elseif p.kind == "tuft" or p.kind == "flowers" then`)

> base ENTERRADA: o ciclo 27 afundava 4% desenhando o
> sprite abaixo do chão (sink2) — a raiz seguia por cima
> da textura. Agora PropCut RECORTA as linhas de raiz
> (world_props.sink) e a linha de contato fica em sy.

## L4276-4277 (em `drawList`, junto a `rot = math.sin(WorldRoad._time * 2.3 + p.z * 1.4) * 0.055`)

> v5.4: capim/flores balançam mais rápido e mais soltos
> que árvores (massa menor) — "grama balançando"

## L4280-4281 (em `drawList`, junto a `rot = rot + pokeRot(p)`)

> v9.7: mexidinha do CLIQUE (pêndulo amortecido na base)
> soma ao vento — qualquer kind reage

## L4284-4289 (em `drawList`, junto a `local lt = envColor("fog")`)

> perspectiva atmosférica + LUZ DO BIOMA: props tomam banho
> da cor ambiente (quente no abismo, frio na geleira) — sem
> isso parecem adesivos recortados de outro mundo
> ciclo 24: aFade só no BRILHO — alpha sempre 1. Alpha
> parcial deixava o domo vazar através das árvores longe
> (feedback: "as árvores ficam com uma transparência")

## L4296 (em `drawList`, junto a `fadeA)`)

> v10.3: alpha só varia no cross-dissolve

## L4300-4309 (em `drawList`, junto a `if not p.ghost and p.kind ~= "tuft" and p.kind ~= "flowers" then`)

> v9.7: mapa interativo — área clicável (ordem do painter)
> + folhinhas do clique no MESMO slot de profundidade.
> v9.7.1: hitbox = retângulo de CONTEÚDO (pixels opacos) e
> não o quad inteiro — as margens do canvas cobriam a área
> do glow ("a luz não deveria contar no clique").
> v9.7.2: grama (tuft/flowers) NÃO é interativa — sem
> hitbox, sem som, sem mexida ("não quero interação com
> a grama"); a vida dela é o vento ambiente do GrassField
> v10.3: fantasma do cross-dissolve não é clicável (a arte
> está esvaindo; quem responde ao clique é o prop novo)

## L4334-4341 (em `drawList`, junto a `if fadeA >= 0.5`)

> LightEngine v1.1: vegetação OCLUI luz vinda de trás
> (silhueta no lightmap — janelas do castelo/poças fundas
> não vazam por cima da copa; lanterna na FRENTE ainda
> ilumina a árvore). Pedido do usuário: "só aparece a
> porcentagem do corpo que estiver pra fora".
> v10.3: no cross-dissolve só a METADE mais opaca oclui —
> fantasma + prop novo empilhados dobrariam a silhueta no
> lightmap (a troca do oclusor cai no meio do fade, invisível)

## L4347-4352 (em `drawList`, junto a `local ambT = LightEngine.ambientLuma`)

> v9.2 (feedback "algumas árvores ficam escuras quando a
> luz vem de trás"): lift SUAVE — a silhueta da copa nunca
> cai abaixo de ~72% da cor cheia, mesmo contraluz. Só age
> em ambiente baixo (max(1,...)); de dia liftT=1 (natural).
> Alvo menor que o do monstro (1.0): árvore é cenário e
> deve escurecer um pouco à noite, sem esmagar pra preto.

## L4359-4360 (em `drawList`, junto a `oc.sx, oc.sy, oc.ox, oc.oy = s, s, iw / 2, ihv`)

> origem na linha de contato (ihv): as linhas de raiz
> recortadas caem sob o pé no lightmap (¼ res, invisível)

## L4367-4371 (em `drawList`, junto a `if lumDef then`)

> LuminaireEngine v9: prop emissor → o MOTOR cuida do núcleo
> na chama + poça de chão + estilo de flicker por bioma.
> Âncora da chama detectada por conteúdo (pixel mais claro).
> Brasas desenham AQUI, no slot de profundidade do prop
> (REGRA DE PROFUNDIDADE: fagulha atrás da árvore da frente).

## L4378-4379 (em `drawList`, junto a `if p._pokeT then`)

> v9.7: poste clicado balança — a CHAMA (e a luz/brasas
> que nascem dela) acompanha o pêndulo da base

## L4384-4387 (em `drawList`, junto a `local gxT, gyT = love.graphics.transformPoint(fx, sy)`)

> v9.2 (feedback: "poça no pé da madeira não faz
> sentido"): a luz no chão cai EMBAIXO DA CHAMA (fx),
> não na raiz do poste (pxX) — a lâmpada fica no braço,
> deslocada pro lado

## L4393-4395 (em `drawList`, junto a `la.flameH = math.max(8, gyT - fyT)`)

> v9.2: poça ∝ altura da CHAMA sobre o chão, com
> teto de 30% da área (poste gigante ditherizava
> o céu com um disco do tamanho do sprite)

## L4398-4399 (em `drawList`, junto a `la.alphaK = fadeA`)

> v10.3: a luz esvai JUNTO com a luminária trocada
> (sem poça órfã de um poste que já sumiu)

## L4402-4403 (em `drawList`, junto a `if fadeA >= 0.5 then`)

> brasas só na metade opaca (fagulha de poste fantasma
> lê como fagulha solta no ar)

## L4409-4410 (em `drawList`, junto a `if p.kind == "fence" and p.perched and not p.flown then`)

> AVES pousadas na cerca: 2 pixels escuros no trilho de cima;
> decolam em arco quando você chega perto (rel < 6.5)

## L4419 (em `drawList`, junto a `if rel < 6.5 or p._scareBirds then`)

> v9.7: batida na cerca (_scareBirds) também espanta

## L4440-4444 (em `drawList`, junto a `drawCrestFog(g, x, w)`)

> ciclo 36: névoa ANTES de qualquer árvore. O design antigo (far →
> névoa → near) pintava a névoa POR CIMA das árvores distantes — no
> dusk (névoa laranja sobre copa roxa) virava franja de brilho
> seguindo a borda ("o brilho da borda aparece acima das árvores").
> Atmosfera nas árvores longe já existe via aFade (escurecimento).

## L4447-4451 (em `drawList`, junto a `local enemyFn = WorldRoad._enemyDraw`)

> v9.2 (feedback: "definir um eixo onde postes ficam na FRENTE do
> monstro"): o inimigo vive em BATTLE_REL. Props mais PERTO que ele
> (rel < eixo) precisam desenhar DEPOIS dele (na frente); mais longe,
> antes (atrás). GameplayScene registra o desenho do inimigo via
> setBattleEnemyDraw; o painter o chama no eixo, entre os dois grupos.

## L4454-4462 (em `drawList`, junto a `local et = g.tOf(WorldRoad.BATTLE_REL)`)

> sort 2.5D por Y da BASE na tela: o pé do monstro é a régua.
> Prop cujo pé cai igual ou mais baixo (−6px de folga) que o do
> monstro está tão perto ou mais → desenha na FRENTE dele. Postes
> que emolduram a batalha (mesma latitude) ficam na frente, como
> o usuário quer. rel sozinho não bastava (poste enorme na mesma
> faixa parecia atrás).
> régua = pé do monstro pela MESMA fórmula dos props (g.latY na
> latitude de BATTLE_REL). getRoadAnchor usava um lerp diferente,
> então a comparação saía torta.

## L4465-4468 (em `drawList`, junto a `local behind, front = _behind, _front`)

> painter puro por Y da BASE: pé do prop ABAIXO do pé do monstro
> (na tela) = mais PERTO → na frente; acima = mais longe → atrás.
> Margem +2px só pra empatados irem pra frente. Vale igual pra
> poste, árvore, tudo (regra de profundidade real, sem exceção).

## L4488-4489 (em `drawList`, junto a `WeatherEngine.flushTo(WorldRoad.BATTLE_REL)`)

> clima mais longe que o monstro desenha antes dele (o resto vem
> nas fatias da frente — floco perto cai NA FRENTE do inimigo)

## L4497 (em `drawList`, junto a `if fkMarks and not fkMarks.drawn then`)

> v9.4: nenhum prop mais perto que os marcos? desenha os marcos agora

## L4503 (em `drawList`, junto a `flushGrassTo(-1)`)

> fatia final: capim mais perto que todos os props

## L4504-4505 (em `drawList`, junto a `ShadowEngine.flush()`)

> v8: sombras enfileiradas caem SOBRE o campo completo (grama + pés
> de quem estiver dentro delas — como sombra real)

## L4520-4521 (em `drawEncounterFront`, junto a `local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3`)

> escala pela MESMA perspectiva do mundo, normalizada pro handoff:
> persp(t)/persp(tBattle) = 1.0 exato no BATTLE_REL (sem pulo)

## L4524-4525 (em `drawEncounterFront`, junto a `local s = e.targetScale * WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(g.h) * k`)

> battleSizeK: no BATTLE_REL o billboard tem o MESMO tamanho que o
> EnemyRenderer vai desenhar (handoff sem pulo, qualquer distância)

## L4527-4531 (em `drawEncounterFront`, junto a `cx = cx - math.floor((e.offX or 0) * s)`)

> v8.2: centro por conteúdo + pé cravado no chão (a margem embaixo do
> canvas fazia o monstro "surgir flutuando lá do fundo")
> Out/2026: pé do QUADRO atual (framePads) + afundado footSink, mesma
> regra do EnemyRenderer — sem isso ele vinha "flutuando milímetros"
> nos quadros em que a idle sobe a figura inteira.

## L4541-4543 (em `drawEncounterFront`, junto a `if e.anim then`)

> v8/8.4: sombra projetada do monstro que vem vindo (frame da anim)
> v9: pegada da criatura (enemy_poses.shadowBaseK — rato/touro são
> largos e baixos; sem o campo, silhueta inteira como sempre)

## L4557 (em `drawEncounterFront`, junto a `if e.anim then`)

> v8.4: vem ANDANDO vivo (idle animada; fallback estático)

## L4564-4565 (em `drawEncounterFront`, junto a `local oxT, oyT = love.graphics.transformPoint(dx0, dy0)`)

> LightEngine v1.1: o inimigo descendo a estrada oclui luzes atrás
> dele (janelas do castelo de onde ele saiu)

## L4567-4574 (em `drawEncounterFront`, junto a `local ar, ag, ab = 1, 1, 1`)

> v9.2: z com VIÉS +6 (mesma correção do EnemyRenderer) — o corpo só
> oclui luz bem mais funda (castelo); poça de luminária que ele cruza
> na viagem continua iluminando-o (sem o viés ele APAGAVA ao passar
> por braseiro, estrobando com o flicker)
> v9.2 (feedback: "andando fica numa cor ok, mas estático escurece do
> nada"): o billboard da viagem usa o MESMO flatColor do EnemyRenderer
> estático (cor padrão + leve tom do ambiente) — senão o handoff
> viagem→batalha muda o brilho de repente.

## L4588-4589 (em `fn`, junto a `local r, g2, b, a = love.graphics.getColor()`)

> SpriteAnimation:draw ignora setColor — repassa via
> getColor (mesmo padrão do occluder do EnemyRenderer)

## L4601-4602 (em `fn`, junto a `local anchors = e.spriteId and EnemyEmissives[e.spriteId]`)

> LightEngine v1.2: emissivos do monstro (olhos/chamas) brilhando
> desde longe — "algo vem vindo na estrada" (dados por spriteId)

## L4605-4606 (em `fn`, junto a `local pulse = 0.90 + 0.10 * math.sin(WorldRoad._time * 1.1)`)

> pulso em FASE ÚNICA: olhos pulsam juntos (fase por âncora fazia
> um olho apagar enquanto o outro acendia — feedback Jul/2026)

## L4617-4620 (em `fn`, junto a `local _profT, _profKB`)

> Instrumento de perf (tools/perf_probe): com WorldRoad._prof = {} o draw
> acumula ms por fase em _prof[fase]. nil = custo zero (1 teste por marca).
> Também acumula KB alocados por fase em _prof["kb " .. fase] (o perf_probe
> para o GC durante a medição).

## L4643-4645 (em `WorldRoad.draw`, junto a `local lr = WorldRoad._lastRect or {}`)

> v9.7: mapa interativo — guarda o rect (o update converte mouse →
> mundo pra rajada da grama) e zera o registro de hit do frame
> (nuvens e props se registram na ordem do painter durante o draw)

## L4652-4658 (em `WorldRoad.draw`, junto a `LightEngine.beginFrame(WeatherEngine.modulateAmbient(currentLightAmbient()))`)

> LightEngine v1: abre o frame de luz com o ambiente do bioma (lerp
> dia→noite pelo timeOfDay + crossfade de bioma). As fontes se
> registram durante o draw; o composite roda FORA (drawLightComposite —
> GameplayScene/tools), pra iluminar também o inimigo plantado e
> deixar HUD/pills de fora.
> (WeatherEngine: tempestade escurece o ambiente, raio o devolve até
> ~branco — multiply-only, o clarão nunca pinta acima da arte)

## L4661-4662 (em `WorldRoad.draw`, junto a `do`)

> ShadowEngine v1: frame de sombra — direção pelo astro do bioma,
> comprimento pelo horário (tod), opacidade pela luminância da luz

## L4670-4673 (em `WorldRoad.draw`, junto a `local gb0 = envColor("grassB")`)

> FUNDO DE SEGURANÇA (feedback telas largas): pinta a área inteira na
> cor escura do terreno ANTES de tudo — qualquer pixel que as camadas
> não cobrirem (cantos extremos além da curvatura, aspect ratios
> largos) mostra terra do bioma em vez de PRETO.

## L4678-4680 (em `WorldRoad.draw`, junto a `love.graphics.push()`)

> v6.6: ROOM SWAY (padrão update_canvas_juice do Balatro) — a cena
> inteira respira: rotação/drift imperceptíveis + zoom de 0.6% pra
> cobrir as bordas. Tira o "still frame" sem o jogador perceber o quê.

## L4690-4691 (em `WorldRoad.draw`, junto a `WeatherEngine.beginFrame({ geom = g, x = x, w = w, camZ = WorldRoad._camZ,`)

> clima: projeta e monta o lote do frame (DENTRO do room sway — as
> micro-luzes das brasas usam transformPoint)

## L4699-4701 (em `WorldRoad.draw`, junto a `drawClouds(g, x, y, w)`)

> v5.8: nuvens ENTRE o céu do strip e a silhueta frontal das montanhas
> (feedback: "as nuvens passam atrás das montanhas") — a camada
> mountains_front redesenha só os picos por cima delas.

## L4709-4712 (em `WorldRoad.draw`, junto a `do`)

> v6.2: PERSPECTIVA ATMOSFÉRICA — véu na cor da névoa sobre TODO o
> plano distante (strip+espelho+nuvens+picos+pássaros), mais forte
> perto do horizonte e sumindo no zênite. O longe perde contraste e
> puxa pra cor do céu; castelo/props desenham DEPOIS e ficam nítidos.

## L4719-4720 (em `WorldRoad.draw`, junto a `for sx = 0, w - 1, 6 do`)

> bordas: a crista desce até os cantos — a faixa entre o ápice e a
> curva local também é plano distante (o domo só cobre o centro)

## L4730-4732 (em `WorldRoad.draw`, junto a `do`)

> NÉVOA DE DISTÂNCIA (v5.4): banda de bruma entre as montanhas e o
> mundo — separa os planos (feedback: "neblina entre montanhas e
> floresta"). O castelo desenha DEPOIS: mais perto, fura a bruma.

## L4745-4748 (em `WorldRoad.draw`, junto a `_profMark('haze')`)

> (v7: GOD RAYS REMOVIDOS — polígonos translúcidos aditivos sobre a
> cena pixel art liam como "luz de pixel transparente de cor estranha"
> (feedback direto). Se voltarem um dia, têm que ser DESENHADOS:
> feixes em dither de pixels na paleta, não polígono com alpha.)

## L4763-4766 (em `WorldRoad.draw`, junto a `do`)

> v10: RoadWear — imperfeições do leito por bioma (manchas, pedras,
> rachaduras com brasa, poças, neve, folhas). Determinístico por z do
> mundo; DEPOIS da terra, ANTES da grama/props (detalhe é do CHÃO —
> capim na borda e pés de árvore cobrem ele, nunca o contrário).

## L4784-4785 (em `roadHalf`)

> (v7.5: drawGrass agora é chamado DENTRO de drawProps, em fatias de
> profundidade intercaladas com as árvores — painter real)

## L4787-4789 (em `roadHalf`, junto a `do`)

> ciclo 36: critters e partículas ambientais ANTES dos props — pontos
> brilhantes (folha dourada, vagalume) por cima das copas escuras liam
> como "brilho saindo das árvores". Partícula é do CAMPO: árvore oclui.

## L4791-4792 (em `roadHalf`, junto a `do`)

> critters rasantes (borboleta de dia, vagalume nos biomas escuros) —
> pousados na LATITUDE da esfera, esvoaçando baixinho

## L4796-4798 (em `roadHalf`, junto a `local glow = LightEngine.ambientLuma() < 0.75`)

> LightEngine v1: vagalume por LUMINÂNCIA do ambiente — qualquer
> bioma escurecido (inclusive fields ao anoitecer, F6.1) acende;
> de dia vira borboleta

## L4800-4801 (em `roadHalf`, junto a `local skipGlow = glow and WeatherEngine.hasFireflies(b.id)`)

> v2: à noite quem acende é o WeatherEngine (vagalume em profundidade,
> com som) — o critter de tela só fica de borboleta, de dia

## L4809-4810 (em `roadHalf`, junto a `local depth = 0.45 + 0.55 * cr.yr`)

> vagalume: ponto que pisca com halo (escala com a
> profundidade — longe é faísca, perto é pirilampo)

## L4817-4818 (em `roadHalf`, junto a `local fx2, fy2 = love.graphics.transformPoint(cxr, cyy)`)

> LightEngine v1: micro-luz = de-escurecimento local (o
> "glow real" do vagalume no lightmap; revisão F-6)

## L4836-4837 (em `roadHalf`, junto a `_profMark('critters')`)

> (partículas ambientais em tela → WeatherEngine, intercalado por
> profundidade dentro do drawProps)

## L4845-4846 (em `roadHalf`, junto a `love.graphics.pop()`)

> v6.6: fim do room sway — fork/pills/vinhetas ficam FIXOS (UI
> interativa balançando desalinharia os hitboxes do mouse)

## L4849-4852 (em `roadHalf`, junto a `drawLandmarkFront(g, x, w, WorldRoad._camZ)`)

> landmark/encounter DEPOIS dos props: objetos de mundo que precisam
> ficar por cima das copas. (LightEngine v1: drawForkMarks saiu daqui —
> marks/pills são UI in-world e agora desenham em drawForkOverlay,
> DEPOIS do composite de luz, pra não escurecerem — revisão F-10.)

## L4856-4859 (em `roadHalf`)

> (v6.8.1: moldura de silhuetas de árvore nos cantos REMOVIDA — lia como
> "manchas pretas", não como folhagem. Se voltar, tem que ser com sprite
> de folhagem DETALHADO dedicado, nunca silhueta chapada. Feedback direto
> do usuário — não reintroduzir como estava.)

## L4861-4863 (em `roadHalf`, junto a `if WorldRoad._travel then`)

> v6.7: GRADE POR ESTADO — véu multiplicativo sutil ligado ao momento
> (viagem esquenta, encounter esfria pro vermelho) — eco barato do
> ease_background_colour do Balatro

## L4874-4875 (em `roadHalf`, junto a `local gradH = math.floor(h * 0.20)`)

> vinheta inferior (mesma linguagem das outras scenes) — gradiente
> por textura (v6.1: sem degraus de rect)

## L4881 (em `roadHalf`, junto a `local vw = math.floor(w * 0.055)`)

> vinheta LATERAL sutil (enquadramento cinematográfico — foco no centro)

## L4891-4894 (em `roadHalf`)

> ============================================================================
> LightEngine v1: overlays pós-mundo (ordem: draw → [inimigo] →
> drawLightComposite → drawForkOverlay → HUD). Ver docs/plan/lighting-engine-v1.md
> ============================================================================

## L4896-4898 (em `roadHalf`, junto a `function WorldRoad.drawLightComposite(x, y, w, h)`)

> Composite multiply do lightmap sobre a cena. Chamar DEPOIS do mundo (e do
> inimigo plantado) e ANTES de qualquer UI. Guard interno: sem beginFrame
> neste frame (interiores/caminho esquecido) é no-op — nunca escurece à toa.

## L4903-4905 (em `WorldRoad.drawLightComposite`, junto a `function WorldRoad.drawForkOverlay(x, y, w, h)`)

> Marks + pills da encruzilhada: UI in-world, desenha DEPOIS do composite
> (legibilidade). Também registra os markBoxes do hit-test do mouse — todo
> caminho interativo com fork PRECISA chamar isto todo frame.

## L4911 (em `WorldRoad.drawForkOverlay`, junto a `function WorldRoad.drawOverlays(x, y, w, h)`)

> Conveniência: composite + fork overlay na ordem certa.

## L4917-4921 (em `WorldRoad.drawOverlays`, junto a `function WorldRoad.resetRun()`)

> RESET DE RUN (bug "abandonei e caí na run antiga", Jul/2026): o mundo
> é estado de módulo e sobrevivia ao abandono — a run nova começava com
> o bioma/câmera/viagem/castelo da run morta. Chamado pelo rebind da
> GameplayScene (setGame). Volta o mundo pro estado de INÍCIO de run:
> bioma 1, câmera no zero, sem viagem/entrada/fork/encounter pendentes.

## L4923-4928 (em `WorldRoad.resetRun`, junto a `WorldRoad._rng:setSeed(0xC0FFEE)`)

> O sorteio cosmético (props, nuvens) nasce de `_rng`, um gerador do
> módulo semeado UMA vez no load: sem reseed, a run nova (e a cena de
> qualquer teste) dependia de quantos props o processo já tinha sorteado
> antes. 13/Out: um caso a mais no test_hand_deal deslocou a sequência e
> o mesmo código mediu 38,1 → 41,4 KB/frame no test_perf_budget. Run
> nova = mundo igual, sempre.

## L4952-4959 (em `WorldRoad._clouds`, junto a `function WorldRoad.restoreProgress(actNumber, floorInAct)`)

> RESTAURA o progresso do mundo ao CONTINUAR uma run salva (pedido do
> dono, Jul/2026: "o mundo precisa continuar no exato mesmo local — o
> progresso, a proximidade com o castelo, cenário"). O progresso do
> mundo é emergente (cada troca de andar viaja TRAVEL_DISTANCE), então
> reconstruímos: andar N ⇒ N-1 viagens desde a base do trecho.
> IMPORTANTE: seta _biomeIndex DIRETO (sem setBiome) — setBiome reancora
> _segBase em _camZ, o que zeraria a caminhada e jogaria o castelo pra
> longe de novo.

## L4971-4982 (em `WorldRoad.restoreProgress`, junto a `WorldRoad.PREWARM_BUDGET = 0.002      -- s por frame (update)`)

> ============================================================================
> PRÉ-AQUECIMENTO DE BIOMA (Out/2026, perf): o 1º frame de um bioma novo
> decodificava ~30-60 PNGs (props × variantes, luminárias + frames de
> chama, marcos do fork, castelo, montanhas), assava a textura do chão e
> a superfície da estrada (RoadSurface, ~98k texels) — tudo DENTRO do
> frame da troca de ato (100-370 ms de engasgo medidos pelo perf_probe).
> Agora uma coroutine percorre a MESMA lista de loaders (os caches são os
> de sempre — o draw só encontra tudo pronto) com orçamento de tempo por
> frame, primeiro do bioma ATUAL e depois do PRÓXIMO (ato N+1). Um job
> pesado indivisível (um PNG grande) estoura o orçamento uma vez, nunca
> empilha. Falha de loader: avisa e marca o bioma como feito (sem laço).
> ============================================================================

## L5030-5034 (em `kinds`, junto a `prewarmTick = function(budget, baseIdx)`)

> Roda jobs até o orçamento do frame acabar. Alvo: bioma atual, depois o
> próximo. Exposto (WorldRoad.prewarmTick) pra ferramentas medirem.
> `baseIdx` (opcional) aquece a partir de outro bioma que não o atual: a
> seleção de classe aquece o bioma 1 antes de a run existir, e o primeiro
> frame do mundo deixa de pagar ~130 ms de carga.

