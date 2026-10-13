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
