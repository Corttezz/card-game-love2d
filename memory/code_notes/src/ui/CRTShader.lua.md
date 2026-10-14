---
name: code_notes/src/ui/CRTShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CRTShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CRTShader.lua`

Origem: `src/ui/CRTShader.lua` em `7dbdb60d` (21 de 51 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local CRTShader = {}`)

> src/ui/CRTShader.lua
> Wrapper do shader CRT pós-processamento (Balatro-style).
> Uso típico:
> CRTShader.load()
> CRTShader.setStrength(0.8)
> function love.draw()
> CRTShader.beginScene()
> ...draw all game stuff...
> CRTShader.endScene()
> end

## L16 (em `CRTShader`, junto a `local strength = 0.75`)

> identidade CRT v2 FORTE (pedido do dono): tubo de verdade.

## L19-22 (em `CRTShader`, junto a `local power = 1`)

> ===== ESTADO FÍSICO DO TUBO (identidade CRT v2, Jul/2026) =====
> power 0..1: 0 = TV desligada, 1 = ligada. powerOn/powerOff animam com
> animador PRÓPRIO (não EventManager: o desligar precisa rodar até
> durante transições de estado e no caminho do quit).

## L25-27 (em `CRTShader`, junto a `local powerDirection = 1   -- 1 = ligando/estável, -1 = desligando`)

> Coreografia do power (v3.6): o shader tem DUAS coreografias distintas —
> ligar (ponto → linha → abre rolando → assenta) e desligar (colapso →
> linha → ponto de fósforo que esfria e apaga). powerDirection escolhe.

## L30-32 (em `CRTShader`, junto a `local glitchAmount = 0`)

> Tremidinha ocasional (sync jitter): evento raro de instabilidade de
> sinal — banda horizontal treme por ~0.15s a cada 4-9s. Agendado aqui,
> executado no shader (uniforms glitch/glitchY).

## L38-41 (em `CRTShader`, junto a `local degradeAmount = 0`)

> SURTO de TV velha (v3.8, pedido do dono): o baseline é limpo/legível,
> mas a cada 8-20s o sinal "degrada" por 0.6-2s — vinheta/CA/ruído/
> flicker sobem e uma hum bar rola pela tela. Envelope: ataque rápido
> (0.12s), decaimento suave (0.35s). Intensidade de pico varia por evento.

## L47-48 (em `CRTShader`, junto a `local calmRect = { 0, 0, 0, 0 }`)

> Zona de leitura (Loja v5): retângulo em px do conteúdo onde a aberração e
> o surto somem. Quem desenha texto miúdo pede A CADA QUADRO; endScene zera.

## L67-72 (em `CRTShader.load`, junto a `CRTShader.LEVELS = { "off", "low", "normal" }`)

> ===== NÍVEIS (Out/2026: Configurações → Vídeo → CRT) =====
> Desligado / Baixo / Normal. "Baixo" mantém o gabinete e a coreografia do
> tubo, mas curvatura, scanlines, grille, aberração e vinheta caem pra
> metade — texto nítido em 1080p/1440p pra quem acha o tubo cheio pesado.
> A ordem do ciclo é off → low → normal (Normal + 1 dá a volta pro Off:
> Enter no Normal DESLIGA, como o toggle antigo fazia).

## L101-102 (em `CRTShader.nextLevel`, junto a `function CRTShader.levelFromSettings(s)`)

> Nível a partir dos settings salvos: `crtLevel` novo; save antigo só tinha
> o booleano `crtShader` (false = desligado).

## L127-129 (em `CRTShader.toggle`, junto a `function CRTShader.setPower(p, dir)`)

> ===== API do power =====
> dir opcional: força a coreografia (1 ligando, -1 desligando) — usado
> pelas ferramentas de captura pra congelar um estágio específico.

## L145-146 (em `animatePower`, junto a `local turningOff = to <= 0.01`)

> Desligar DE VERDADE (to≈0) usa a coreografia do colapso; qualquer
> outra animação (ligar, blip de canal) usa a do warm-up.

## L151-152 (em `powerAnim`, junto a `ease = turningOff and "outquad" or nil }`)

> desligar: colapso RÁPIDO no começo, ponto de fósforo
> demorando pra apagar no fim (easeOutQuad no k)

## L169-171 (em `powerAnim`, junto a `function CRTShader.jolt(dur)`)

> SOLAVANCO externo (BossCinematic, pouso do chefe): a faixa de glitch do
> agendador, só que AGORA. Sem tubo ligado, nada (o tool de captura não
> usa o CRT).

## L246-248 (em `CRTShader.update`, junto a `function CRTShader.setCalmRect(x, y, w, h)`)

> Pede a ZONA DE LEITURA deste quadro (px REAIS do conteúdo: quem desenha
> dentro do UiScale multiplica por UiScale.activeK()). Uma por quadro; a
> última chamada vence. Zerada em endScene.

## L258-259 (em `CRTShader.getCalmRect2`, junto a `function CRTShader.setChromaScale(k) caScale = math.max(0, math.min(1, k or 1)) end`)

> Escala da aberração cromática neste quadro (telas de leitura: a loja
> pede 0,45; curvatura/scanlines ficam). Volta a 1 em endScene.

## L268-269 (em `CRTShader.setStrength`, junto a `function CRTShader.setDegrade(v)`)

> Força o surto (ferramentas de captura/preview — não usar no gameplay,
> o agendador do update cuida do timing aleatório).

## L279-286 (em `CRTShader.getStrength`, junto a `function CRTShader.screenToContent(x, y)`)

> ===== MOUSE ATRAVÉS DO VIDRO (Jul/2026) =====
> O shader distorce a IMAGEM (gabinete come borda, domo curva o resto),
> mas o mouse chega em coordenadas físicas da janela — perto do topo e da
> base o pixel clicado não é o pixel mostrado (bug do dono: filtros da
> Coleção "clicam acima de onde aparecem"). Esta função replica EXATAMENTE
> a matemática de amostragem do crt.glsl (tela → conteúdo): é o mesmo
> caminho que o pixel percorre, então o clique cai onde o olho vê.
> MANTENHA EM SINCRONIA com shaders/crt.glsl (BEZEL_PX, halfExt, domo).

## L288-289 (em `CRTShader.screenToContent`, junto a `if not shader or not enabled or strength < 0.01 then return x, y end`)

> passthrough: CRT desligado, sem shader, ou strength ~0 (o shader
> também faz passthrough nesse caso)

## L313-314 (em `CRTShader.screenToContent`, junto a `return sx * w, sy * h`)

> sem clamp: clique no gabinete extrapola pra fora do conteúdo e
> naturalmente não acerta UI (não inventa hits na borda)

## L318-321 (em `CRTShader.screenToContent`, junto a `function CRTShader.renderTube(src, dst)`)

> ABERTURA (Out/2026): desenha `src` dentro de `dst` passando pelo MESMO
> shader do tubo (gabinete, curvatura, scanlines), com a resolução do
> canvas de destino: é o nosso televisor em tamanho pequeno, na página.
> Tubo ligado e estável, sem surto nem tremidinha. false = sem shader.

## L362-364 (em `CRTShader.beginScene`, junto a `function CRTShader.endScene(target)`)

> Fecha a cena e desenha com o shader aplicado. `target` (opcional): canvas
> de destino em vez da tela — ferramentas de captura sem janela renderizam
> o tubo num canvas falsificado (screenshot_crt_levels, test_crt_levels).

