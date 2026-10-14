---
name: code_notes/engine/WeatherEngine.lua
description: Comentários com decisão/regra/histórico colhidos de engine/WeatherEngine.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/WeatherEngine.lua`

Origem: `engine/WeatherEngine.lua` em `7dbdb60d` (25 de 89 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-42 (junto a `local WeatherEngine = {}`)

> engine/WeatherEngine.lua
> ============================================================================
> WEATHERENGINE — clima com PROFUNDIDADE de verdade no domo (v2, Out/2026)
> ============================================================================
> A grama mostrou o vento no CHÃO; aqui o mesmo vento aparece no AR. Neve,
> chuva, cinza, folhas, sementes e VAGALUMES vivem em COORDENADAS DE MUNDO
> (lateral normalizada, z absoluto, altura acima do chão) e são projetados
> pela mesma geometria do domo que os props:
> tamanho e velocidade de queda na tela ∝ persp(t) (paralaxe real);
> cada partícula CAI até a latitude dela (g.latY) e POUSA ali;
> o desenho entra no PAINTER por profundidade (REGRA DE PROFUNDIDADE do
> WorldRoad): flushTo(rel) junto com as fatias de grama; além da crista
> desenha ANTES do domo e some atrás da curva do mundo;
> o VENTO é o GrassField.windAt — a MESMA rajada que deita o capim
> empurra a neve e inclina a chuva.
>
> v2 (feedback do dono: "pixels grandes demais, chuva grossa, POLUINDO"):
> tudo FINO: medida em pixel de TELA (1 px até 1440p), chuva = risco de
> 1 px com alpha baixo, neve quase toda 1 px. Clima é TEXTURA, não ruído
> (Hollow Knight/Ori: partícula ambiente é sutil e some no contraste;
> o que se nota é a VIDA, não o pontilhado);
> densidade pela CHEGADA AO CASTELO: calma no começo do ato, pico perto
> do chefe (uma curva só: intensityFor(progress)); tempestade e raio só
> na parte final;
> VAGALUMES: 1 px com micro-luz do LightEngine acendendo o capim
> embaixo, piscando em ciclo próprio, densidade pela NOITE (luma do
> ambiente); variante por bioma (amarelo quente, fogo-fátuo verde,
> cisco claro, cristal de gelo, faísca azul);
> estado pro SOM (audioState): intensidade, tempestade, rajada, noite,
> trovão pendente pela distância do raio, vagalume perto acendendo.
>
> TEMPESTADE: o relâmpago é polilinha de PIXELS desenhada ATRÁS da silhueta
> frontal das montanhas; o clarão é o AMBIENTE do lightmap subindo até
> ~branco — multiply-only, o clarão só DEVOLVE a arte (doutrina de luz).
> Raio longe = fino, curto, clarão fraco, trovão tardio e baixo.
>
> ACESSIBILIDADE: reducedMotion corta a densidade e DESLIGA clarão/raio
> (risco fotossensível). ≤2 pulsos por raio, ≥5 s entre raios.
>
> PERF: 1 QuadMesh (FFI) por frame, ~1 draw por fatia de profundidade;
> sem closures nem love.graphics.* nos laços. Não toca no cache da grama.
> ============================================================================

## L51-60 (em `WeatherEngine`, junto a `WeatherEngine.PRESETS = {`)

> PRESETS por bioma. Unidades:
> count  = partículas vivas na intensidade 1 (perto do castelo)
> fall   = queda em fração da ALTURA da área por segundo, a persp 1
> size   = px de TELA a persp 1 numa área de 1000 px (chuva: comprimento)
> windK  = quanto a rajada do capim empurra (lateral normalizada/s)
> land   = segundos pousado antes de sumir
> fg     = fração no PRIMEIRO PLANO (na frente de tudo, um pouco maior)
> ff     = vagalumes { count (noite cheia), style, color, radius, light }

## L162-165 (em `smooth`, junto a `function WeatherEngine.intensityFor(prog)`)

> A CURVA ÚNICA: intensidade pela chegada ao castelo (0..1)
>
> começo do ato = 12% (céu quase limpo), porta do castelo = 100%

## L169 (em `WeatherEngine.intensityFor`, junto a `local function stormFor(pr, prog, t)`)

> tempestade só no trecho final (e respirando num ciclo longo)

## L180-188 (em `curProgress`, junto a `WeatherEngine.fogHook = nil`)

> NÉVOA DE INTENÇÃO (Out/2026): quando o intent do inimigo está encoberto,
> o clima da tela ENGROSSA pra que a leitura venha do mundo, não de um
> interruptor de UI. O estado decide e o clima acompanha (o relógio do clima
> é visual e não pode ser a regra — src/systems/IntentVisibility.lua).
> `fogHook` é instalado por quem sabe o estado e devolve 0..1 de intensidade
> extra; `veilCur` persegue esse alvo a 4/s (~0,5 s pra 85%: quando a vez
> volta ao jogador, depois dos beats de upkeep/compra, a bruma já fechou).
> O mesmo valor é a opacidade da BRUMA DE TELA (drawHaze, no flushAll): "?"
> no HUD nunca aparece sobre céu limpo — renderedFog() é o que a trava mede.

## L209-210 (em `WeatherEngine.storm`, junto a `return min(1, max(stormFor(cur, curProgress(), time), veilBoost()))`)

> a névoa oculta também fecha a tempestade (nevasca: rastro na rajada,
> `dark`) — nunca acima de 1

## L227-228 (em `tOfRel`, junto a `local function spawn(p, pr, camZ, fresh, kindTag)`)

> (re)nasce uma partícula. fresh = preenchimento inicial (altura aleatória)
> kindTag: nil = clima, "rise" = brasa subindo, "ff" = vagalume

## L299 (em `ffGlow`, junto a `b = 0.45 + 0.55 * (0.5 + 0.5 * sin(c * 6.2832))`)

> respira, quase nunca apaga

## L319-322 (em `addParticle`, junto a `function WeatherEngine.update(dt, ctx)`)

> UPDATE: simulação em coordenadas de mundo
> ctx = { biomeId, camZ, time, windP, progress (0..1), luma (ambiente) }

## L337-338 (em `WeatherEngine.update`, junto a `night = smooth(0.82, 0.55, ctx.luma)`)

> noite pela LUMINÂNCIA do ambiente (o mesmo gate dos vagalumes do
> LightEngine): 0.82 = dia claro, 0.55 = noite fechada

## L380-383 (em `WeatherEngine.update`, junto a `p.age = (p.age or 0) + dt`)

> APOSENTADORIA determinística: partícula de um preset que saiu de
> cena (troca de bioma) esvai em RETIRE_FADE s, e qualquer uma tem
> vida máxima — floco atrás da crista caindo devagar podia passar
> de 60 s (bug exposto por troca de RNG, Out/2026)

## L489 (em `WeatherEngine.update`, junto a `local st = cur and cur.storm`)

> RAIO: só com tempestade forte (fim do ato), nunca com reducedMotion

## L525-526 (em `WeatherEngine.audioState`, junto a `function WeatherEngine.strike(xr, dist)`)

> dispara um raio agora (tools/teste chamam direto). dist 0 = em cima,
> 1 = horizonte. Polilinha de pixels em coordenadas NORMALIZADAS.

## L573-574 (em `WeatherEngine.flash`, junto a `local _amb = { 1, 1, 1 }`)

> ambiente do lightmap: tempestade escurece, raio devolve a arte. NUNCA
> passa de 1 (multiply-only — o clarão não pinta, só tira a sombra)

## L593-595 (em `WeatherEngine.modulateAmbient`, junto a `WeatherEngine.debugMagenta = false`)

> prova de cobertura: WeatherEngine.debugMagenta = true pinta tudo de
> magenta e engorda 4px (partícula fina some na captura — use pra provar
> que está desenhando antes de mexer em tamanho)

## L614 (em `WeatherEngine.beginFrame`, junto a `WeatherEngine._sortCamZ = camZ`)

> emitLeaf insere na ordem com o mesmo eixo

## L616 (em `WeatherEngine.beginFrame`, junto a `local hk = h / 1000`)

> v2: pixel de TELA. 1 px até ~1440p; 2 px só em 4K (fino é a regra)

## L667 (em `WeatherEngine.beginFrame`, junto a `quad(px, py - u, u, u, min(1, cr * (0.6 + 0.4 * b) + 0.15 * b),`)

> núcleo de 1 px + cruz de halo só quando aceso e perto

## L677-679 (em `WeatherEngine.beginFrame`, junto a `if LightEngine and b > 0.15 then`)

> a LUZ é o efeito: micro-luz devolve a cor cheia do núcleo e
> os vagalumes de PERTO pousam uma poça no capim embaixo
> (mesma linguagem das luminárias: degraus finos + dither leve)

## L703 (em `WeatherEngine.beginFrame`, junto a `if t > 0.45 then`)

> coroa: 2 quadros (abre e espalha), só no campo de perto

## L798-803 (em `WeatherEngine.flushTo`, junto a `local hazeImg, hazeQuad = nil, nil`)

> BRUMA DE TELA da névoa de intenção: bandas de ruído em pixel correndo com o
> vento por cima do mundo inteiro (na frente do inimigo da estrada, atrás do
> HUD — o flushAll é o último passe do painter). Tingida pelo `hazeColor` do
> preset. reducedMotion: parada, nunca ausente (informação, não movimento).

## L829-831 (em `nz`, junto a `local vwin = sin(3.14159 * (y + 0.5) / HAZE_H)`)

> janela vertical: cada banda some nas bordas (as bandas se
> sobrepõem pela metade — sem isso o corte reto entre bandas
> lia como retângulos, não como bruma)

## L865 (em `drawHaze`, junto a `local depthK = 0.45 + 0.55 * min(1, (i + 1) / nBands)`)

> mais densa embaixo (o chão some primeiro) e nunca cobre o céu alto

## L950-954 (em `WeatherEngine.emitLeaf`, junto a `p.sortRel = p.z - (WeatherEngine._sortCamZ or 0)`)

> A folha nasce DURANTE o draw do WorldRoad (slot da árvore), depois da
> ordenação do quadro: entra já na posição certa (fundo → frente) em vez
> de ficar no fim com o sortRel velho da tabela reaproveitada — o lote
> ficava fora de ordem até o quadro seguinte (test_weather, ordem do
> test_all).

## L970-971 (em `WeatherEngine.reset`, junto a `rng:setSeed(9173)`)

> gerador próprio reseedado: run nova (e cena de teste) sempre igual,
> não dependente de quantas partículas o processo já sorteou

