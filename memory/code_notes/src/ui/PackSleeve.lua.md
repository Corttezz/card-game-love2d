---
name: code_notes/src/ui/PackSleeve.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PackSleeve.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PackSleeve.lua`

Origem: `src/ui/PackSleeve.lua` em `7dbdb60d` (15 de 25 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-40 (junto a `local PackSleeve = {}`)

> src/ui/PackSleeve.lua
> Renderiza o "envelope" (sleeve) de um booster pack — a carta selada que
> aparece na PRATELEIRA da loja e, depois, centralizada antes de explodir.
>
> Estratégia:
> • PNG do PixelLab em assets/sprites/packs/<id>.png (caminho normal).
> • Fallback procedural por kind se o PNG sumir.
>
> O sleeve é, ANTES DE TUDO, a arte. Os PNGs do PixelLab já trazem moldura,
> cantoneiras metálicas com rebites, fitas cruzadas e selo — o envelope está
> COMPLETO no arquivo. O trabalho deste módulo é mostrá-lo, não redecorá-lo.
>
> Histórico (Set/2026) que existe pra não ser repetido: uma versão anterior
> empilhou por cima da arte (a) um halo aditivo feito de 3 cópias escaladas do
> PRÓPRIO sleeve e (b) cantoneiras em "L" desenhadas por código. As duas foram
> REJEITADAS pelo dono e removidas:
> • o halo de silhueta, sendo a arte retangular, não lia como brilho — lia
> como uma cópia fantasma e desfocada do pacote atrás dele, indistinguível
> de erro de renderização. Um halo com a forma do objeto só funciona com
> silhueta recortada; com retângulo, não funciona.
> • as cantoneiras de código dobravam as chapas que a arte JÁ tem pintadas,
> transbordando a borda. Era redundância, não reforço.
> Se for preciso destacar o pacote de novo, o sinal tem que ser algo que a arte
> NÃO tem — e a regra é errar para MENOS.
>
> O que sobrou, e por quê:
> 1) faíscas orbitando — discretas, ficam FORA da arte, não a cobrem;
> 2) reação de hover — o sleeve sobe, incha de leve e inclina. Feedback de
> interação, que nenhuma arte estática pode dar sozinha;
> E o que NAO sobrou: o booster shader, desligado por padrão (ver o comentário
> em drawAt). Era a terceira camada sobre a arte e a última a cair.
>
> HOVER: `drawAt` DETECTA o mouse sozinho a partir do retângulo que vai
> desenhar. Nenhum chamador precisa mudar — quem quiser desligar passa
> `opts.interactive = false` (é o que a cinemática de abertura faz, onde o
> sleeve não é clicável).
>
> Acessibilidade: com `_G.gameSettings.reducedMotion` some a OSCILAÇÃO
> (respiração, tilt, órbita das faíscas) — a reação de hover permanece,
> estática.

## L61 (em `PROCEDURAL_GLYPHS`, junto a `local proceduralCache = {}`)

> Cache de canvases procedurais por kind (evita regerar todo frame).

## L64-65 (em `proceduralCache`, junto a `local hoverState = {}`)

> Estado de hover por sleeve desenhado (chave = packId ou kind). Guarda o
> valor interpolado 0..1 pra transição suave em vez de liga/desliga.

## L72-74 (em `reducedMotion`, junto a `local function seedOf(key)`)

> Hash estável de string → 0..1. Usado pra dessincronizar a respiração e as
> faíscas entre pacotes vizinhos na prateleira (sem isso todos pulsam juntos
> e o efeito vira "a UI inteira piscando").

## L102-103 (em `tryLoadPNG`, junto a `local function buildProcedural(kind)`)

> Gera canvas procedural pra um kind. Cache por kind. Cores vêm do MESMO
> tema do resto do efeito — fallback e PNG falam a mesma língua cromática.

## L149-151 (em `outline`, junto a `love.graphics.printf(PackThemes.label(kind), 0, H - 36, W, "center")`)

> th.label deixou de existir (virou labelKey + i18n). Sem isto o fallback
> procedural saia com o titulo em BRANCO, o que so apareceria no dia em que
> um PNG de sleeve sumisse -- exatamente quando ninguem esta olhando.

## L169-170 (em `outline`, junto a `function PackSleeve.getImage(packId, kind)`)

> Retorna a Image (PNG do PixelLab OU canvas procedural) pra um pack.
> Prioridade: PNG > procedural por kind > Standard fallback.

## L181-182 (em `PackSleeve.getDimensions`, junto a `function PackSleeve.isMouseOver(cx, cy, scale)`)

> O mouse está sobre o retângulo do sleeve desenhado em (cx, cy) com `scale`?
> Exposto pra quem quiser sincronizar tooltip/cursor com a reação do sleeve.

## L192-194 (em `PackSleeve.isMouseOver`)

> ===========================================================================
> Camadas do efeito
> ===========================================================================

## L196-198 (em `PackSleeve.isMouseOver`, junto a `local function drawSparkles(th, cx, cy, scale, alpha, hover, t, seed, still)`)

> Faíscas: pontos numa órbita elíptica em volta do sleeve, cintilando fora de
> fase. Quantidade e velocidade saem do tema (Celestial tem mais e mais
> lentas; Bufão tem menos e rápidas).

## L227-229 (em `drawSparkles`)

> ===========================================================================
> Desenho principal
> ===========================================================================

## L231-245 (em `drawSparkles`, junto a `function PackSleeve.drawAt(packId, kind, cx, cy, scale, alpha, opts)`)

> Desenha o sleeve (faíscas + arte com shader tingido).
> (cx, cy) é o CENTRO. scale default 1. alpha default 1 — respeitada, nunca
> sobrescrita (bug F7.5).
>
> opts (tudo opcional; omitir = comportamento padrão de prateleira):
> interactive — false desliga a auto-detecção de hover (default true)
> hover       — força o estado de hover (0..1 ou bool), ignora o mouse
> rotation    — tilt extra em rad (a cinemática usa no wobble pré-estouro)
> sparkles    — false desliga as faíscas
> shader      — true RELIGA o booster shader (default: DESLIGADO, ver abaixo)
> key         — chave própria pro estado de hover (default packId/kind)
> phase       — congela a fase do booster shader (default = relógio). Sem
> isso a captura sai não-determinística: a faixa de foil está
> onde o relógio deixou, e medir "quanto o shader desvia da
> arte" vira sorteio

## L271 (em `PackSleeve.drawAt`, junto a `local k = math.min(1, dt * 12)`)

> Lerp enquadrado (12/s) — sem isso o sleeve "pula" ao entrar/sair.

## L286 (em `PackSleeve.drawAt`, junto a `if opts.sparkles ~= false then`)

> 1) faíscas (fora da silhueta, nunca por cima da ilustração)

## L291-309 (em `PackSleeve.drawAt`, junto a `local ox, oy = img:getWidth() * 0.5, img:getHeight() * 0.5`)

> 2) a arte, com o booster shader iridescente
> ARTE PURA POR PADRÃO (Set/2026). O booster shader ficou DESLIGADO aqui
> por decisão tomada em cima de uma comparação lado a lado (a folha de 3
> linhas de `love . screenshot_packopen shelf`, linha "ARTE PURA"):
> Arcano   puro = azul-real com olho dourado vivo | com shader = roxo lavado
> Celestial puro = azul-noite, lua e prata nítidas | com shader = embaçado
> Bufão    puro = carmim com máscara em ouro vivo | com shader = arroseado
> Padrão   puro = pergaminho, tiras escuras, lacre | com shader = névoa rosada
> Espectral puro = verde com caveira em contraste  | com shader = menta lavado
> O argumento que fechou a questão não foi gosto: o shader aplicava a MESMA
> listra diagonal nos cinco. A rodada inteira foi gastar esforço criando
> identidade POR TIPO (bursts dedicados, temas, cores próprias) e esse
> efeito uniformizava tudo por cima — trabalhava contra o próprio objetivo.
>
> NÃO religue isto achando que é melhoria. Se um dia quiserem foil de
> verdade, o lugar dele é numa CARTA com edition, não no envelope.
> Consequência: `sheen`/`sheen_amt` em shaders/booster.glsl viraram CAMINHO
> MORTO no uso normal (o arquivo segue compilando e testado, mas ninguém o
> aplica). Mantidos pra não quebrar quem passar `shader = true`.

