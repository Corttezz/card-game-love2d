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
- **Fita** (`Menu:_drawRibbon`): faixa de tinta no pé da tela, borda de 4 px
  `AGED_GOLD_DARK` (`Menu.RIBBON_BORDER`), texto `título · subtítulo · vN`
  rolando a 38 px/s sem emenda (parado em reducedMotion); versão/créditos e
  placa de perfil sobem `Menu.RIBBON_H` (`Menu:footerY()`).

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
