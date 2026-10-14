---
name: code_notes/engine/GrassField.lua
description: Comentários com decisão/regra/histórico colhidos de engine/GrassField.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/GrassField.lua`

Origem: `engine/GrassField.lua` em `7dbdb60d` (54 de 99 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local GrassField = {}`)

> engine/GrassField.lua
> ============================================================================
> GRASSFIELD — motor dedicado de vegetação rasteira (v1, Jul/2026)
> ============================================================================
> A BASE do cenário: lâminas de capim individuais cobrindo o terreno todo,
> com física de vento fluida e paleta/comportamento por bioma.
>
> TÉCNICA (pesquisa Jul/2026):
> Vento em 3 CAMADAS (sistema da Guerrilla/Horizon, adaptado pra 2D):
> (1) frente de RAJADA viajando pelo campo (onda espacial que se move),
> (2) BRISA local (senos por posição de mundo — cada tufo tem fase própria),
> (3) JITTER de ponta (tremor rápido de baixa amplitude, cresce na rajada).
> Lâmina = sprite com CISALHAMENTO (kx) e pivô na RAIZ: base fixa no chão,
> ponta desloca kx·altura (GPU Gems cap.7 / fórmula clássica de sway).
> Rajada também ENCURTA a lâmina (sy reduz com |lean|) — projeção 2D do
> dobrar, truque de pixel art (Defold forum).
> Ponta mais clara que o corpo: BAKED no atlas em tons de cinza; o tint
> por bioma colore corpo e ponta de uma vez (1 setColor por lâmina).
> Out/2026 (perf): lote = QuadMesh (FFI) e o VENTO roda no VERTEX
> SHADER (GrassField.SHADER_VERTEX — as mesmas fórmulas de windAt/
> flick/pokeLean, por vértice). Câmera parada = o lote do frame
> anterior é reusado inteiro (0 Lua por lâmina); 1 draw por fatia.
>
> SEM stencil, SEM alpha translúcido — pixels opacos na paleta.
>
> USO (ver WorldRoad):
> GrassField.draw{ x=, w=, time=, camZ=, geom=g, relCrest=,
> roadCenter=fn(z,t), roadHalf=fn(t),
> colors={light=,mid=,accent=}, biomeId="fields",
> forkActive=false, forkRel=10 }
> ============================================================================

## L36-44 (em `GrassField`, junto a `GrassField.PRESETS = {`)

> PRESETS por bioma: personalidade do capim (densidade, altura, vento).
> Cores NÃO ficam aqui — vêm do chamador (lerpam no crossfade de bioma).
>
> v9.7.2 (feedback: "as gramas estão muito estáticas"): vento AMBIENTE
> ~45% mais forte em todos os biomas (windAmp ×1.45, gustAmp ×1.35,
> gustSpeed ×1.15) — a vida da grama agora é toda dele, já que a rajada
> de hover do mouse foi removida. Caráter relativo por bioma preservado
> (abyss segue o mais parado, highlands o mais ventoso).

## L68-72 (em `dusk`, junto a `local CELL_W, CELL_H = 8, 16`)

> ATLAS de lâminas (gerado 1x): tons de CINZA pra tintar por bioma.
> Corpo 0.60, raiz 0.45 (aterra), ponta 1.0 (pega luz) — o tint único
> por lâmina produz o gradiente raiz-escura→ponta-clara de graça.

## L76-78 (em `dusk`, junto a `local N_CLUMP = 6`)

> MOITAS (v7.4, cobertura 100%): células de 16×16 com 8-10 lâminas
> pré-assadas + base quase sólida — 1 sprite cobre ~5× mais chão que uma
> lâmina, viabilizando o tapete contínuo sem explodir a contagem

## L136-138 (em `put`, junto a `local clumpX0 = CELL_W * n`)

> MOITAS: 2 fileiras da base quase sólidas (chão DE capim — é o que
> garante o tapete contínuo entre fileiras) + 8-10 lâminas variadas
> com brilho individual (profundidade interna baked)

## L171-173 (em `put`, junto a `quads = {}`)

> Out/2026: "quad" = UV normalizado {u0, v0, u1, v1} (o lote é um
> QuadMesh escrito por FFI — ver engine/QuadMesh.lua), mesmo recorte
> do Quad do LÖVE que existia aqui

## L185-201 (em `clumpQuads`, junto a `local ffi = require("ffi")`)

> LOTE NA GPU (Out/2026, perf): o SpriteBatch "stream" com ~10k
> batch:add + ~10k setColor por frame (5-8 ms de chamadas C) virou um
> QuadMesh escrito por FFI com o VENTO NO VERTEX SHADER:
> a CPU escreve a lâmina PARADA (vento zero) + os parâmetros do vento
> dela (hash/fase/amplitude) — as MESMAS fórmulas de antes, só que
> avaliadas por vértice na GPU (GrassField.SHADER_* abaixo);
> com a câmera PARADA (batalha, escolha de caminho) nada da cena da
> grama muda além do relógio → o lote do frame anterior é REUSADO
> inteiro: zero Lua por lâmina, só 1 uniform + 1 draw por fatia;
> cada FATIA de profundidade (painter do WorldRoad) é um trecho
> contíguo do buffer (setDrawRange) — a intercalação com as árvores
> é a mesma, fatia a fatia.
> Cisalhamento (kx) e encurtamento (sy) são lineares na altura do
> vértice: X += kx·sx·(ly−oy) e Y −= |lean|·0.16·sy·(ly−oy) — o mesmo
> Matrix4::setTransformation do SpriteBatch, só que com kx vindo do shader.

## L315-318 (em `GF_FORMAT`, junto a `local cache = { valid = false, slices = {} }`)

> CACHE do lote: válido enquanto a "cena da grama" não muda (tudo menos o
> relógio, que é uniform). frameMode = "replay" (reusa trechos gravados)
> ou "build" (gera e grava). cacheable cai pra false se algo no frame
> depende do tempo na CPU (broto nascendo) ou se as fatias mudaram.

## L321-322 (em `cache`, junto a `GrassField.stats = { replays = 0, builds = 0, sprites = 0 }`)

> contadores (trava de regressão tools/test_perf_budget): fatias
> REUSADAS × CONSTRUÍDAS e sprites escritos pela CPU desde o último reset

## L331 (em `rowCache`, junto a `local lastTime`)

> frame atual (múltiplas chamadas/frame — v7.5)

## L333-334 (em `rowCache`, junto a `local GF_DEBUG = require("src.core.Release").isDev() and os.getenv("GF_DEBUG")  -- nunca no pacote`)

> diagnóstico (prova magenta + log de LOD): cacheado no load — os.getenv
> por moita custava 7.8k chamadas C/frame

## L335 (em `rowCache`, junto a `local GF_DEBUG = require("src.core.Release").isDev() and os.getenv("GF_DEBUG")`)

> nunca no pacote

## L337-345 (em `rowCache`, junto a `local function windAt(nx, wz, t, P, pers)`)

> VENTO em 3 camadas. Fase espacial vem da POSIÇÃO DE MUNDO (nx = fração
> horizontal da tela, wz = z absoluto do mundo) — a frente de rajada
> ATRAVESSA o campo e o mundo rolando faz o vento "fluir" na viagem.
> Retorna lean normalizado [-1..1]-ish (multiplicado por windAmp).
>
> pers ∈ [0,1]: PERSONALIDADE da lâmina — relógio próprio (frequência e
> fase individuais). Vizinhas nunca dançam em bloco (GoT: params por
> lâmina; paper Real Time Animated Grass: variação dentro do cluster).

## L348-354 (em `windAt`, junto a `local phA = nx * 7.5 + wz * 0.23`)

> (1) DUAS frentes de rajada com velocidades INCOMENSURÁVEIS — a
> interferência nunca se repete (versão barata do "noise de magnitude
> viajante" do Ghost of Tsushima).
> v7.4.9: fases espaciais DIAGONAIS E CRUZADAS (uma ↘, outra ↗) —
> com a fase dominada por wz a frente virava LINHA HORIZONTAL
> subindo pela tela (feedback: "uma linha de pixels atravessa o
> gramado até o fim da esfera")

## L359 (em `windAt`, junto a `local f1p, f2p = math.max(f1, 0), math.max(f2, 0)`)

> (Out/2026: max(f,0)² ≡ (f>0 and f² or 0), sem desvio — ver QuadMesh.c8)

## L368-369 (em `windAt`, junto a `local curl = math.sin(ph * 9.3 + t * 2.6)`)

> (3) REDEMOINHOS: alta frequência espacial transversal (vorticles
> do GoT em 2D) — tremores localizados que giram pelo campo

## L381-386 (em `windAt`, junto a `GrassField._poke = nil`)

> v9.7: RAJADA DO MOUSE (mapa interativo) — sopro local e amortecido nas
> lâminas perto do cursor. Vive FORA do windAt: os call sites passam
> relógios ESCALADOS pro windAt (junco 0.62×, flor +0.3) e o envelope da
> rajada precisa do tempo REAL do ctx.

## L391 (em `GrassField._poke`)

> (pokeLean mora no SHADER_VERTEX — uniform uPoke; Out/2026)

## L393-397 (em `GrassField._poke`)

> (v7.4.12: windCalm REMOVIDO — até a "brisa calma" era um campo espacial
> compartilhado: a fase variava tão devagar em profundidade que fileiras
> vizinhas respiravam em sincronia = a "linha seguindo padrão" do 4º
> feedback. O tapete agora usa osciladores 100% INDEPENDENTES por moita:
> nenhum termo compartilhado entre duas moitas quaisquer.)

## L399-401 (em `GrassField._poke`, junto a `local sortRow`)

> hash determinístico [0,1) — população estateless (mundo-ancorada, sem
> spawn/reciclagem: as lâminas "existem" onde a janela da câmera olha)
> ordenação da fileira por balde de cor (ver PASSE A)

## L410-412 (em `hash`, junto a `local function emit(x, y, sx, sy, ox, oy, qw, qh, q, R, G, B,`)

> Escreve 1 sprite PARADO (vento zero) + parâmetros do vento. Equivale a
> SpriteBatch:add(quad, x, y, 0, sx, sy, ox, oy, kx=0) com a cor (R,G,B)
> em bytes; o shader soma kx·arm.x e −squash·arm.y por vértice.

## L445-446 (em `emit`, junto a `local KEY_N = 22`)

> chave da "cena da grama" (tudo que muda a geometria/cor escrita pela
> CPU). Comparada campo a campo, sem alocar.

## L490-491 (em `GrassField.draw`, junto a `if frameMode == "build" then`)

> o frame que acabou pode virar cache (se nada nele dependeu do
> relógio na CPU e as fatias foram todas gravadas)

## L532-533 (em `GrassField.draw`, junto a `frameMode = "build"`)

> fatias mudaram (prop novo, fork...): o resto do frame é build e
> ele não vira cache (faltam as fatias de antes no registro)

## L551-552 (em `GrassField.draw`, junto a `cDark[1], cDark[2], cDark[3] = cMid[1] * 0.68, cMid[2] * 0.68, cMid[3] * 0.68`)

> 3º tom (sombra): lâminas na sombra das vizinhas — profundidade de
> moita real (2 tons alternados liam como padrão artificial)

## L555-564 (em `GrassField.draw`, junto a `if ctx.time ~= lastTime then`)

> até QUASE a crista (-0.05, não -0.8): o corte antigo deixava uma
> faixa careca que a geometria da esfera AMPLIFICA nas laterais
> (t 0..0.03 = ~15px no centro, 40-100px nas bordas em tela larga —
> "o final da esfera sem grama", feedback com print ultrawide)
> v7.5: JANELA de profundidade — o WorldRoad chama draw() várias
> vezes por frame, intercalando fatias de grama entre as árvores
> (painter real: capim na frente do pé da árvore COBRE o pé)
> câmera em movimento? (viagem/convergência — broto desligado).
> Detecção POR FRAME (ctx.time): com múltiplas chamadas por frame,
> comparar camZ por chamada daria "parado" da 2ª fatia em diante

## L570-571 (em `GrassField.draw`, junto a `local wf = math.floor(camZ / Z_CELL)`)

> poda do cache 1x por frame (janela COMPLETA da câmera — as
> fatias usam janelas parciais e podariam fileiras vivas)

## L580-582 (em `GrassField.draw`, junto a `local first = math.floor((camZ + math.max(0, relFrom)) / Z_CELL)`)

> v7.5 (perf): range de células LIMITADO à janela da fatia — sem
> isso cada uma das ~dezenas de fatias/frame varria o campo inteiro
> (17ms/frame; com o corte, volta ao custo de ~1 passada)

## L587-602 (em `GrassField.draw`, junto a `local NK = 96                       -- moitas por fileira (fração fixa)`)

> ========================================================================
> PASSE A (v7.4): TAPETE 100% — fileiras de MOITAS de trás pra frente
> (painter: cada fileira cobre o chão da anterior; a base quase sólida
> da moita garante continuidade). LOD em ESPAÇO DE TELA: só desenha
> fileira quando o Y na tela avançou ~40% da altura da moita — no
> longe (fileiras comprimidas) pula quase todas de graça. No longe as
> moitas também ESTICAM na horizontal (detalhe é sub-pixel; menos
> sprites pra cobrir a mesma largura).
> ========================================================================
> TUDO ancorado no MUNDO (v7.4.1 — feedback: "movimentando pra frente
> fica estranho"): decimação por potência de 2 fixa por fileira +
> moita em fração FIXA da largura (nada re-embaralha nem desliza).
> v7.4.2 (perf): dados estáticos por fileira em CACHE (os 6 hashes por
> moita custavam 1 sin cada, TODO frame) + vento amostrado em grade
> grossa com lerp (espacialmente suave; a moita só modula amplitude —
> personalidade fina fica nos ACENTOS). Corte medido: ~4.0→~1.5ms.

## L604 (em `GrassField.draw`, junto a `for ci = last, first, -1 do`)

> (poda do cache movida pro bloco 1x-por-frame lá em cima — v7.5)

## L616-618 (em `GrassField.draw`, junto a `local M = 1`)

> v7.4.8: folga calculada pro PIOR CASO (moita rasteira,
> 0.60×) — com 0.30 o vão entre fileiras ficava mais alto
> que a rasteira e o chão vazava ("mais buracos")

## L630-637 (em `GrassField.draw`, junto a `rc = { order = {},`)

> born: fileira recém-criada BROTA do chão (v7.4.5)
> — mas SÓ com a câmera parada (entrada de cena).
> v7.4.7 (feedback: "no demo, viajando, o fundo
> fica liso"): em viagem o LOD promove fileiras
> SEM PARAR no terço final — todas mid-broto =
> careca permanente. Em movimento a fileira nova
> entra em tamanho cheio (nasce atrás das
> vizinhas sobrepostas — o pop é invisível).

## L643-644 (em `rc`, junto a `local dq = math.floor(`)

> seco QUANTIZADO em 3 níveis (permite agrupar
> por cor: 3 tons × 3 secos = 9 baldes/fileira)

## L651-657 (em `rc`, junto a `local df = math.min(1, math.max(0,`)

> v7.4.6: 3 ALTURAS com sorteio PONDERADO pela
> distância da estrada (rasteira na beira do
> caminho → alta na parede de floresta; pesos
> deslizam, sorteio continua aleatório).
> |lf| é estático → o tier NUNCA muda em
> movimento (threshold dinâmico faria a moita
> trocar de altura no meio da viagem)

## L664-667 (em `rc`, junto a `local hMul`)

> piso da rasteira = 0.60: abaixo disso ela
> fica mais baixa que o vão entre fileiras e
> fura o tapete (altura muda SÓ pra cima da
> linha de cobertura, nunca pra baixo dela)

## L693-698 (em `rc`, junto a `sortRow = rc`)

> ordem por COR (dentro da fileira a profundidade
> é a mesma — pintar por balde não muda a imagem):
> setColor só quando o balde troca (~9/fileira em
> vez de 96) — chamada C é o custo dominante
> comparador fixo (closure criada no laço aborta
> o trace do JIT — Out/2026)

## L706-708 (em `rc`, junto a `local centers, armK, armW`)

> v7.4.15: na encruzilhada valida contra CADA braço —
> a clareira única (half + 0.17w) deixava o miolo
> entre os caminhos e o entorno carecas

## L739-741 (em `rc`, junto a `local zk = z + e.dz * Z_CELL * 3`)

> jitter FIXO (×3, não ×M): atrelado ao M, a
> moita dava um pulo de profundidade quando o
> LOD trocava de nível durante a viagem

## L747-754 (em `rc`, junto a `local amp = (0.14 + math.abs(e.dz) * 0.26)`)

> v7.4.12 (pedido direto: "randomize tudo,
> nada faz a mesma coisa ao mesmo tempo"):
> oscilador INDEPENDENTE por moita — 2 senos
> em frequências próprias + fase própria +
> amplitude própria. ZERO termo compartilhado
> entre moitas = impossível formar linha.
> (vento: GPU — amplitude da moita vai no
> atributo; fases/frequências saem de hk/dz)

## L770-771 (em `rc`, junto a `local age = t0 - rc.born`)

> BROTO com stagger por moita: cresce do chão
> em ~0.6-1.3s (calmo, "nascendo de verdade")

## L780-794 (em `rc`, junto a `emit(math.floor(pxX),`)

> hMul só na ALTURA: rasteira estreita
> furaria o tapete (largura cobre o chão).
> v7.4.10: SEM encurtamento por |lean| no
> tapete — a mudança de escala re-amostrava o
> sprite (nearest) e as fileiras ESCURAS da
> base ganhavam/perdiam 1px em ONDA coerente
> com a rajada ("varredura escurecendo a base
> das gramas linha por linha", 2º feedback).
> O balanço fica só no cisalhamento (kx), que
> desloca pixels sem re-amostrar altura.
> v7.4.13: kx × flip — a escala negativa do
> espelho invertia TAMBÉM o cisalhamento:
> metade das moitas dobrava pro lado oposto
> do próprio lean ("um conjunto se mexe pra
> esquerda, outro pra diagonal direita")

## L810-817 (em `rc`, junto a `if relTo > ctx.relCrest then`)

> ========================================================================
> PASSE A2 (v7.4.4): FRANJA DA CRISTA — fileira de moitas sentadas NA
> curva do horizonte, silhueta contra o céu ("o fim do mundo tem
> capim"). Mata de vez a careca da borda, que a geometria da esfera
> amplifica nas laterais. ESTÁTICA como a treeline (anel
> "infinitamente longe": o mundo rolando não a move). O inimigo
> emergindo é desenhado ANTES do domo → sobe POR TRÁS do capim.
> ========================================================================

## L831-834 (em `rc`, junto a `local ht = hash(k * 29 + 3, 57)`)

> v7.4.12: oscilador independente também aqui — a
> franja é literalmente uma LINHA; com vento
> compartilhado ela pulsava em conjunto na crista
> (vento: GPU, tipo K_CREST)

## L851-854 (em `rc`, junto a `for ci = first, last do`)

> ========================================================================
> PASSE B: ACENTOS — lâminas individuais + juncos + flores POR CIMA do
> tapete (movimento fino visível, flick, inércia — a "vida" da grama)
> ========================================================================

## L856-857 (em `rc`, junto a `local patch = 0.5 + 0.5 * math.sin(ci * 0.31)`)

> MANCHAS de crescimento: grama real cresce em patches, não em
> distribuição uniforme — modulação espacial lenta da densidade

## L861-862 (em `rc`, junto a `if h1 < (0.34 + 0.24 * patch) * P.density then`)

> acento é TEMPERO (o tapete do passe A já cobre o chão):
> densidade menor, e só onde a lâmina individual é legível

## L873-874 (em `rc`, junto a `local pxX = roadC + side * (half * 0.94`)

> da beira da estrada (levemente POR CIMA da borda —
> grama invade o caminho) até a LARGURA TODA do campo

## L877-878 (em `rc`, junto a `local armBlock = false`)

> v7.4.15: na encruzilhada o acento só some se cair
> DENTRO de um braço (antes: sumia da região inteira)

## L898-900 (em `rc`, junto a `local nb = (t < 0.22) and (2 + math.floor(h3 * 2))`)

> TUFO: menos lâminas no longe (vira pontinho),
> 3-6 no campo — cada uma com flexibilidade,
> variante, fase e tom próprios

## L903-909 (em `rc`, junto a `local ramp = math.min(1, (t - 0.18) / 0.10)`)

> escala MAIS perspectiva: minúscula na crista,
> graúda no primeiro plano.
> v7.4.5: rampa ESPACIAL de nascimento — o acento
> CRESCE conforme se aproxima (t 0.18→0.28) em vez
> de popar em tamanho cheio numa linha fixa da
> tela (feedback: "grama surgindo do nada"; agora
> tem o mesmo "vir vindo" gradual das árvores)

## L912-913 (em `rc`, junto a `local dfA = math.min(1, h2 * 1.8)`)

> v7.4.6: tier de altura ponderado pela distância
> da estrada (h2 É a distância do sorteio lateral)

## L929-932 (em `rc`, junto a `local dryK = hash(ci * 7, slot * 3 + 9) * 0.30`)

> FLICK do tufo (impulso raro e curto — bicho/
> lufada pontual): no shader, por h3
> tom SECO/VIÇOSO por tufo (campos reais têm
> manchas amareladas — GoT: variação por área)

## L944-950 (em `rc`, junto a `local ht = hash(ci * 17 + bi, slot * 23 + 2)`)

> física (raiz fixa, ponta balança,
> flexível ∝ altura, encurta ao dobrar,
> junco com INÉRCIA): no shader, a partir
> de nx/z/hb/h3 — ver SHADER_VERTEX
> tom em 3 níveis por lâmina (sombra /
> meia-luz / luz) — moita com profundidade;
> o gradiente raiz→ponta vem do atlas

## L964-965 (em `rc`, junto a `if h3 > 1 - P.flower and t > 0.25 then`)

> flor/broto na cor de acento do bioma (a
> "vida" do campo — dourado/brasa/cristal...)

