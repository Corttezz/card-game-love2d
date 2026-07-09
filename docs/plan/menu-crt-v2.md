# Menu + Entrada v2 — "O Televisor é o Palco" (Jul/2026)

> Pedido do dono: reformular menu e entrada pra ficarem "bem melhores",
> trazendo a estética CRT/televisão pros botões e settings ("igualzinho
> as televisões"), mantendo/adicionando coisas interativas e animações.
> Iterar com capturas ("tire tudo enquanto está fazendo").

## 1. Conceito

O jogo já VIVE dentro de um televisor (CRT v3.x). O menu v2 abraça isso:
**o mundo grimório é o PROGRAMA passando na TV; o chrome de menu é o OSD
do aparelho** (on-screen display — aquele texto verde-fósforo que TVs
desenham por cima da imagem: canal, volume em bloquinhos, relógio).

Duas linguagens convivem SEM brigar:
- **Programa** (sépia grimório): cenário, título DynaText, cartas
  flutuantes, botões de pergaminho — o que já existe, polido.
- **Aparelho** (OSD verde-fósforo): tag de canal "AV-1 GRIMOIRE" que
  aparece e some (como TV real após trocar de canal), chuvisco de
  sintonia na entrada, barras de volume em segmentos nas Settings,
  varredura de scanline no hover dos botões.

## 2. Peças

### 2.1 src/ui/TvOsd.lua (novo — helper compartilhado)
- `staticNoise(alpha)`: chuvisco fullscreen — 4 ImageData 160×120 de
  ruído pré-gerados, ciclados a ~12fps, nearest scaled (pixelões de TV
  fora do ar) + banda horizontal escura ocasional.
- `tag(text, corner, alpha)`: texto OSD verde-fósforo com sombra dura e
  ghost de fósforo (cópia 1px deslocada, alpha baixo).
- `segmentBar(x, y, w, value, opts)`: a barra de volume de TV — N
  bloquinhos verdes preenchidos + vazios delineados.
- Paleta própria: OSD_GREEN (0.42, 0.98, 0.50), OSD_DIM. Fonte
  FontManager (pixel) tamanho ~15.

### 2.2 BootScene v2 — "sintonizando o canal"
1. TV liga (CRT v3.6, mantido).
2. **Chuvisco de sintonia**: 0.55s de static resolvendo na cena
   (staticAlpha 1→0) + tag "AV-1" no canto — o canal ancora.
3. Cascade v2: mini-cartas voam em **ESPIRAL** (angle anima junto com
   dist — antes era linha reta radial), tumble mantido.
4. Título com **glitch de sinal** ao materializar: 2 cópias RGB
   deslocadas por ~0.12s, depois assenta (own-math, discreto).
5. Loading bar reaproveita segmentBar OSD (verde) — "a TV sintonizando".

### 2.3 Menu v2
- **OSD do aparelho**: ao entrar no menu, canto sup-dir mostra
  "AV-1 GRIMOIRE" + relógio real (os OSDs somem em ~3.5s com fade, como
  TV de verdade; reaparecem a cada enterWithIntro).
- **Botões CRT**: no hover — (a) varredura de scanline clara descendo
  pelo botão em loop (scissor no rect), (b) glow de fósforo pulsante na
  borda, (c) seta "▶" OSD piscando à esquerda (TV menu style). Overlay
  desenhado pelo Menu POR CIMA do Button (widget global intocado).
- **Vida ambiente**: motes de poeira dourada derivando (14 partículas
  próprias baratas); cartas flutuantes agora são CLICÁVEIS — clique dá
  spin 360° com juice + SFX (easter egg interativo).
- Mantidos: fundo scene_menu, DynaText do título, perfil/versão no
  rodapé, intro staggered.

### 2.4 SettingsMenu v2 — o menu DO TELEVISOR
- Volumes (music/sfx/master) e screenshake trocam "NN%" por
  **segmentBar de 10 bloquinhos verde-fósforo** (a imagem mental de
  ajustar volume numa TV velha).
- Header vira OSD: "◼ MENU" verde + linha; footer "AV-1 · GRIMOIRE".
- Painel/botões continuam pixel sépia (consistência) — o VERDE aparece
  só nos elementos "do aparelho". Toda a lógica intocada (persistência,
  dropdown de idioma, caminho do clique testado).

## 3. Regras
- Legibilidade > efeito (herdada da v2.3 do CRT).
- Nada de onda viajante (trauma GrassField). Varredura de scanline é
  DENTRO do botão em hover, não na cena.
- OSD verde usado com parcimônia (é tempero, não prato).
- Validação por captura em cada etapa (tools/screenshot_menu_v2.lua):
  menu com OSD + hover, boot mid-cascade com static, settings com barras.
- Caminho do clique: smoke_ui_turn continua verde; cartas clicáveis do
  menu não podem roubar clique dos botões (checar z-order de hit).
