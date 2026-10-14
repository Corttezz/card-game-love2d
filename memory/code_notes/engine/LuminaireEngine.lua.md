---
name: code_notes/engine/LuminaireEngine.lua
description: Comentários com decisão/regra/histórico colhidos de engine/LuminaireEngine.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/LuminaireEngine.lua`

Origem: `engine/LuminaireEngine.lua` em `7dbdb60d` (20 de 26 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local LightEngine = require("engine.LightEngine")`)

> engine/LuminaireEngine.lua
> ============================================================================
> LUMINAIREENGINE v1 — motor de props DECORATIVOS EMISSORES DE LUZ (Jul/2026)
> ============================================================================
> Pedido: "um motor específico para os elementos decorativos que emitem luz
> (lanterna, pedras com fogo, fogueiras, postes)... reaproveitando as luzes,
> com 2-3 adaptações por bioma... tem que parecer algo que pertence ao bioma".
>
> O motor NÃO desenha o sprite do prop (isso é do painter do WorldRoad, que
> respeita a REGRA DE PROFUNDIDADE). Ele é o dono de:
>
> CATÁLOGO   — 2-3 tipos de luminária POR BIOMA, cada um com cor/raio/
> núcleo/intensidade/estilo de flicker próprios (a lanterna
> do pântano é verde-bruxaria; o braseiro da geleira é a
> ÚNICA coisa quente do bioma — contraste é identidade).
> LUZ        — submit no LightEngine (núcleo micro na chama + poça de
> chão posterizada), com estilos de flicker além do
> fire/pulse nativos: "wisp" (respiração lenta errante) e
> "shimmer" (cintilação rápida de cristal) modulados AQUI.
> ÂNCORA     — onde a chama vive no sprite. Detectada POR CONTEÚDO
> (centróide dos pixels mais brilhantes do PNG — arte
> PixelLab não precisa de âncora manual), com fallback do
> catálogo pra arte procedural. Mesmo scan mede offX/footPad
> (lição dos monstros: canvas com margem descentra o prop).
> BRASAS     — partículas de fagulha DETERMINÍSTICAS (função do tempo,
> zero estado — mesma doutrina do GrassField) desenhadas
> pelo chamador no slot de profundidade do prop.
>
> Zero stencil, zero shader novo — reusa LightEngine.submit/submitMicro.
> ============================================================================

## L36-37 (em `LuminaireEngine`, junto a `LuminaireEngine.POOL_MIN_T = 0.50`)

> poça de chão só quando o prop está perto (t alto) — de longe vive entre
> copas e o dither da poça quebrava a silhueta das árvores (lição F-1)

## L40-49 (em `LuminaireEngine`, junto a `local FIRE_AMBER  = { 1.00, 0.62, 0.25 }`)

> CATÁLOGO por bioma. Campos por tipo:
> size    — tamanho de mundo (KIND_SIZE do WorldRoad)
> lane    — faixa na cunha [colado na estrada .. borda]; emissor vive na
> BEIRA da estrada (a poça alcança o caminho)
> anchor  — {xr, yr} fallback da chama (fração do sprite, y do topo)
> light   — cor/raio(∝ altura na tela)/núcleo/intensidade/flicker
> embers  — fagulhas subindo (cor própria; só tipos de FOGO vivo)
> weight  — peso de spawn sugerido (biomes.lua referencia)

## L52-56 (em `FIRE_AMBER`, junto a `local CATALOG = {`)

> Out/2026 (dono, jogando): fora a fogueira dos Campos e do Crepúsculo e a
> lanterna de chão das Colinas — "muito feias, não fazem sentido". A remoção
> de Set/2026 só tirou a fogueira de biomes.lua (propWeights), mas luminária
> é sorteada DAQUI (cadência do WorldRoad) — por isso ela continuava
> aparecendo. Tirar um tipo de luminária = tirar do CATALOG.

## L58-59 (em `CATALOG`, junto a `fields = {`)

> Campos Arruinados: âmbar de fazenda — lampião e santuário de vela
> (mundo rural que ainda acende as luzes)

## L72-73 (em `light`, junto a `highlands = {`)

> Colinas da Torre: noite de lua — fogo ARCANO azul nos braseiros dos
> monólitos e runas acesas na pedra

## L86-87 (em `light`, junto a `abyss = {`)

> Estrada do Abismo: inferno — braseiro de pilar rugindo (referência),
> tocha de estaca carbonizada, fissura de brasa no chão

## L105-106 (em `light`, junto a `frost = {`)

> Geleira Espectral: o braseiro QUENTE é o único calor do bioma
> (contraste); cristal de gelo e lanterna de pedra são a luz fria local

## L123-124 (em `light`, junto a `marsh = {`)

> Pântano da Podridão: bruxaria — lampião torto de fogo-fátuo VERDE,
> cogumelos bioluminescentes, totem musgoso com chama espectral

## L141-142 (em `light`, junto a `dusk = {`)

> Campos do Crepúsculo: golden hour eterna — lampião dourado
> (referência) e santuário de velas no trigo

## L169-173 (em `LuminaireEngine.isLuminaire`, junto a `local anchorCache = {}`)

> ÂNCORA POR CONTEÚDO: centróide dos pixels mais brilhantes do PNG (a chama
> assada É o ponto mais claro da arte) + offX/footPad (margens do canvas).
> Cache por chave; PNG ausente/procedural → fallback do catálogo.

## L176-179 (em `anchorCache`, junto a `local ffi = require("ffi")`)

> Out/2026 (perf da troca de bioma): leitura dos pixels por FFI direto no
> buffer rgba8 do ImageData — getPixel por pixel eram ~10-20k chamadas C
> por PNG, 2 passadas, na hora do 1º frame do bioma novo. Os valores são
> os MESMOS do getPixel do LÖVE 11 (byte/255 em float): tabela F8.

## L257-263 (em `LuminaireEngine.anchor`, junto a `function LuminaireEngine.submit(bid, kind, a)`)

> LUZ: núcleo micro na chama + poça de chão. Flickers "fire"/"pulse" são
> nativos do LightEngine; "wisp" e "shimmer" são modulados aqui (noise
> contínuo, nunca random puro — doutrina do motor de luz).
> a = { fx, fy (chama em coords de TELA pós-transform), gx, gy (pés),
> sh (altura do sprite na tela), t, rel, seed }

## L270-282 (em `LuminaireEngine.submit`, junto a `local fi, fr = 1, 1`)

> v9.2 (feedback: "a luz da lâmpada tem que se mexer, não ficar
> estática"): o flicker é calculado AQUI pra TODOS os tipos e aplicado
> tanto na micro-luz (glow da lâmpada) quanto na poça — antes o "fire"
> só modulava a poça (dentro do LightEngine) e o núcleo ficava fixo.
> fi = multiplicador de intensidade; fr = de raio (a luz "expande e
> fica pequenininha"). Passamos flicker=nil pro LightEngine pra não
> aplicar de novo (dupla modulação).
> v9.2 (feedback: "lâmpada longe fica estática; TODAS deviam pulsar"):
> amplitude do flicker AMPLA (fr swing largo) — o halo "expande e fica
> pequenininho" de forma visível a qualquer distância.
> flicker GENTIL (a versão anterior "piscava rápido demais"): a mesma
> respiração suave que a poça de chão tinha — é ELA que o usuário
> gostou. fi = intensidade, fr = raio (expande/encolhe devagar).

## L303-308 (em `LuminaireEngine.submit`, junto a `local base = a.flameH or a.sh`)

> v9.2 (feedback: "o brilho bom que estava no PÉ deve ir pra CIMA, na
> lâmpada; e escalar com a distância"): UMA luz suave (mesmo shader
> da antiga poça — posterizada + dither) centrada NA CHAMA (a.fx/a.fy),
> não no chão. O raio escala com a ALTURA DA CHAMA na tela (a.flameH:
> longe = pequena, perto = grande — some a sensação de "tamanho fixo").
> Sem halo micro duro e sem poça no chão.

## L310-312 (em `LuminaireEngine.submit`, junto a `local aK = a.alphaK or 1`)

> v10.3: alphaK opcional (1 = normal) — o chamador esvai a luz junto com
> a arte da luminária (cross-dissolve de troca de bioma no WorldRoad),
> pra não sobrar poça órfã de um poste que já sumiu

## L314-317 (em `LuminaireEngine.submit`, junto a `local distK = 0.42 + 0.58 * math.min(1, (a.t or 1) / 0.55)`)

> v9.2 (feedback: "poste longe o feixe fica grande demais; mais
> proporcional"): fator de distância — o glow encolhe além do que o
> flameH já reduz (a perspectiva sozinha deixava o disco grande
> relativo ao poste minúsculo na dobra da esfera). Perto = 1.0.

## L323-326 (em `LuminaireEngine.submit`, junto a `dither = true, ditherAmt = 0.28, levels = 8,`)

> v9.2 (feedback: "ainda pixelado e xadrez"): 8 degraus (gradiente
> bem fino) + dither de amplitude 0.28 (quase imperceptível — só
> quebra a banda). No lightmap ¼ o Bayer cheio virava xadrez de
> 4px; com degraus finos quase não precisa de dither.

## L330-331 (em `LuminaireEngine.submit`, junto a `LightEngine.submitMicro(a.fx, a.fy,`)

> núcleo quente pequeno no centro da chama (hotspot), escala com base,
> SEM piso — longe encolhe junto (nada de dot fixo)

## L337-343 (em `LuminaireEngine.submit`, junto a `local function hash01(n)`)

> BRASAS: fagulhas subindo da chama. DETERMINÍSTICAS (função pura do tempo,
> como o GrassField) — cada fagulha tem ciclo/fase próprios derivados do
> seed; chamador desenha no slot de profundidade do prop (REGRA DE
> PROFUNDIDADE: brasa na frente da árvore desenha depois dela).
> fx, fy = chama na tela (coords locais do painter); sh = altura na tela.

