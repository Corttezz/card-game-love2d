---
name: Abertura "página e televisor" + fita do menu
description: Out/2026, a pedido do dono a partir de heyparker.ai ("gostei do começo: a tela, a fita; quero o nosso visual"). IntroTube antes do boot, CRT ligando só no mergulho, fita ticker no pé do menu.
type: project
---

# Abertura (src/scenes/IntroTube.lua) e fita (components/Menu.lua)

Referência do dono: heyparker.ai abre com uma página creme, um Macintosh
antigo no meio datilografando a frase na tela com cursor, e ao rolar a
câmera MERGULHA na tela; logo abaixo uma faixa ("Ribbon") ticker com borda
de 4 px. Pedido: "a mesma coisa, com o nosso visual".

## Como ficou

- **Fase `intro` do BootScene** (antes de `loading`): página de PERGAMINHO
  (`Palette.PARCHMENT` com grão e vinheta de tinta em degraus Bayer, canvas
  por tamanho) com o NOSSO televisor no meio: o conteúdo do tubo é um canvas
  4:3 de 46% da largura da janela, passado pelo MESMO `crt.glsl` por
  `CRTShader.renderTube(src, dst)` (gabinete, curvatura, scanlines, tubo
  ligado e estável). Sombra dura do televisor na página.
- **Datilografia**: `menu.title` e depois `menu.subtitle` (5 idiomas), 22
  cps, blip do corvo a cada 2 letras (`Narrator.playBlip`), cursor "_" a
  2,2 Hz, pausa em ponto final. O subtítulo cabe na abertura do tubo
  (`TextFit` + `getWrap`, quebra decidida pelo texto completo).
- **Mergulho**: 1 s ease in-out, escala até a ABERTURA do tubo (canvas menos
  o gabinete de 20 px) cobrir a janela (`IntroTube.geometry(W,H).sEnd`);
  a página escurece junto. No fim → `BootScene._tubeOn()`:
  `callbacks.onTubeOn` (main.lua reabilita o CRT de tela cheia e dispara
  `powerOn(1.8)`) + `bootTvPowerOn`; o loading/sintonia de sempre continua
  DENTRO do tubo. Durante a abertura o CRT de tela cheia fica desligado
  (`onIntroStart`, estado anterior guardado em `BootScene._crtWasEnabled`).
- **Pular**: tecla/clique na abertura pula SÓ a abertura (cai na sintonia);
  de novo, pula o boot. `reducedMotion`: texto inteiro na hora, sem mergulho.
- **Tools/testes**: `callbacks.intro` default = `not _G.HEADLESS_TOOL` (o
  `test_boot_entry` e os tools de boot continuam começando em `loading`).
  `BOOT`: `love . test_one screenshot_intro [loc]:[WxH]` captura 5 quadros +
  a fita. Trava: `test_intro_tube` (fases, geometria em 6 tamanhos, pular,
  reducedMotion, BootScene com/sem intro, fita).
- **Fita e subtítulo do menu**: a fita ticker (`título · subtítulo · vN`
  no pé, borda de 4 px) e o SUBTÍTULO "Cartas arcanas. Decisões fatais."
  sob o título foram REMOVIDOS em 13/Out a pedido do dono ("tira essas
  coisas embaixo de Grimório, deixa sem nada"). Sob GRIMOIRE não há nada;
  a frase vive só na tela do computador da abertura (`menu.subtitle` nos
  locales continua, por causa dela). Trava: `test_intro_tube` §7.

**Why:** o jogo já "vive numa TV"; a abertura mostra o aparelho de fora
antes de entrar nele, com o mesmo shader (não um mock). **How to apply:**
tempos em `IntroTube.T`; frase = chaves de menu (sem chave nova); se o CRT
não compila, o televisor vira moldura plana AVISADA.

## Modo ARTE: o computador gerado (Out/2026)

Dono: "gerar literalmente o computador do site da Parker (Higgsfield), com
as nossas cores; o primeiro quadro e esse computador, depois da zoom e vai
pro jogo". Contrato e prompt em `docs/plan/intro-computer-prompt.md`.

- A arte entra por `python tools/intro_computer_import.py <render.png>
  --width 640 --palette`: recorta pela cor do canto, reduz com nearest,
  acha a TELA pintada de magenta puro `#ff00ff` (bbox; avisa se < 85%
  cheia), fura a tela (transparente), quantiza na paleta sepia e grava
  `assets/sprites/intro/computer.png` + `src/data/intro_computer.lua`
  (`{ image, w, h, screen = {x,y,w,h} }`).
- `IntroTube.computerArt()` carrega esses dados quando existem
  (`IntroTube.DATA_PATH`; cache, `reloadArt()`); `geometry()` devolve
  `mode = "art"`: computador com `ART_FRAC` (70%) da altura da janela,
  `sx/sy/sw/sh` = a tela em px, `sEnd` = escala pra TELA encher a janela.
  O tubo e renderizado no tamanho da tela + gabinete do shader e so a
  ABERTURA (quad sem os 20 px de bezel) entra na tela; a PNG vai por cima;
  tudo escala em torno do centro da tela no mergulho. Sem o arquivo de
  dados: `mode = "tube"` (televisor do shader, como antes).
- Capturas: `INTRO_DATA=<lua> love . test_one screenshot_intro pt_BR:1920x1080`
  (sufixo `_art` nos arquivos). Trava: `test_intro_tube` 5b escreve uma arte
  sintetica no save dir e verifica modo, encaixe, tela dentro da arte,
  mergulho cobrindo a janela e fallback. Prova sintetica em
  `tools/preview_out/intro/` (computador desenhado por script, nao e a arte
  final).

## A carta na fenda (Out/2026, "todos os efeitos do site")

No site, depois do texto uma mão enfia um DISQUETE no Macintosh e só então a
câmera mergulha na tela (que mostra um redemoinho de carregamento). Aqui,
com a arte do computador: fase `insert` entre `page` e `dive`: o VERSO de
uma carta (`src/ui/CardBack`) vem do canto inferior direito já girada,
endireita no caminho (ease in-out, `T.insert` 1,1 s) e some pela FENDA do
disquete. O truque é um `setScissor` na linha da fenda: o que sobe além
dela está "dentro" do gabinete, e sobra 5% da carta para fora. Sons:
`cardDraw` na partida e `buttonClick` ao entrar (78% do caminho); depois um
flash de fósforo na tela (`T.insertHold` 0,35 s) e o mergulho. O redemoinho
do site é a nossa sintonia do boot, que já acontece dentro do tubo.

A fenda vem de `slot` nos dados (`tools/intro_computer_import.py` acha a
faixa de tinta larga e baixa abaixo da tela, ≥ 18% da largura, ≤ 8% da
altura); sem `slot`, `IntroTube.SLOT_FALLBACK` (fração da arte). Televisor
do shader (sem arte) e `reducedMotion` não têm a fase. Capturas
`3b_carta`/`3c_flash` no `screenshot_intro`; trava `test_intro_tube` 5c.

Efeitos do site mapeados: datilografia com cursor (feito), dica de rolar
(= "pressione qualquer tecla"), rosto na tela ("Meet Parker", não
reproduzido: a tela mostra o título), disquete (= a carta), redemoinho
(= sintonia), mergulho na tela (feito), fita ticker (feito).

## A arte instalada (13/Out/2026)

`assets/sprites/intro/computer.png` (640×773, paleta sépia) veio do
**Higgsfield Unlimited pelo navegador** (Seedream 4.5, 3:4, custo zero):
driver `E:/dev/projects/Tiktok-accounts/pipeline/4_video/higgsfield_unlimited.js`
(`sessao` na porta 9222 + `gerar <fila.json> --dir=<pasta>`), prompt de
`docs/plan/intro-computer-prompt.md` com o Macintosh REAL do heyparker.ai
(quadro 0 da sequência do hero, `framerusercontent.com/images/<id>.png`)
como referência. O job NÃO aceitou a referência (0 de 1) e mesmo assim
devolveu um Macintosh fiel; a tela saiu roxa `#8a1a8a`, não `#ff00ff`, por
isso o importador casa pelo MATIZ. O render cru trouxe base + drive externo
+ emblema dourado + rebites + manchas: o dono pediu para tirar ("achei
feio"), então o corte é na linha de baixo do gabinete (y 1934 do render
1728×2304) e o corpo bege é pintado LISO (`(229,203,154)`), preservando
bezel, fenda (retângulo 830..1500 × 1565..1750, com o canto esquerdo até
905 também liso) e contornos. Fonte limpa em
`assets/sprites/intro/computer_source.png`; renders crus (ilustração e
pixel art, descartada: degraus falsos "cara de IA") em
`tools/preview_out/intro_hf/` (untracked). Reinstalar: `python
tools/intro_computer_import.py assets/sprites/intro/computer_source.png
--width 640 --palette`.

Pedido do dono (13/Out): "antes do zoom apague o que tá escrito": o texto
da tela some junto com o flash da carta (`textAlpha()`); no televisor do
shader, nos últimos 0,3 s da espera. O mergulho é sempre em tela vazia.

## Borda do zoom = borda do jogo (13/Out, dono: "a transição tem que ficar melhor")

Antes o mergulho escalava a tela da arte (4:3) até COBRIR a janela e o
CRT de tela cheia ligava do apagão (`setPower(0)` + `powerOn(1.8)`):
corte seco entre a borda da arte e o gabinete do shader. Agora, no modo
arte: (1) `geometry` devolve `sEndX/sEndY` = a tela cai EXATAMENTE na
abertura do CRT (janela menos `BEZEL_PX` por lado), escala POR EIXO (a
tela 4:3 vira 16:9 no caminho) e o centro da tela caminha até o centro da
janela; (2) durante o mergulho o tubo é renderizado na resolução FINAL
(canvas W×H, `renderTube`) e encolhido até a tela, então o último quadro
é pixel a pixel o primeiro do CRT do jogo; (3) `IntroTube.endedWithDive()`
→ `BootScene._tubeOn(seamless)` → `onTubeOn(true)` no main.lua liga o CRT
já aceso (`setPower(1)`); pular ou reducedMotion seguem ligando do apagão.
Trava: `test_intro_tube` (tela × sEndX/sEndY = abertura; endedWithDive só
pelo mergulho).
