# Abertura: o computador (arte gerada) e o contrato com o jogo

Pedido do dono (Out/2026): "gerar literalmente o computador do site da Parker,
no Higgsfield, com as NOSSAS cores; o primeiro quadro do jogo é esse
computador, depois dá zoom e vai pro jogo".

## O que o jogo faz com a arte

1. `assets/sprites/intro/computer.png` + `src/data/intro_computer.lua`
   (gerados por `tools/intro_computer_import.py`).
2. A abertura (`src/scenes/IntroTube.lua`) desenha a página de pergaminho,
   o computador centralizado e, DENTRO do retângulo da tela, o tubo com o
   título/subtítulo datilografados (curvatura e scanlines do `crt.glsl`,
   sem o gabinete do shader: a moldura é a da arte).
3. O zoom é feito pelo jogo (não pelo vídeo): a câmera mergulha na tela até
   ela encher a janela e o CRT de tela cheia liga. Assim o texto continua
   vivo e o tempo/pular/reducedMotion ficam no nosso controle.

## Prompt (Higgsfield, imagem)

```
A vintage all-in-one beige personal computer from the 1980s (compact
Macintosh style: built-in small CRT screen, floppy slot below the screen,
rounded cream-beige plastic case), seen straight from the front, centered,
occupying about 70% of the frame height. Clean product-style illustration,
dark fantasy grimoire palette: aged parchment cream #e8d5a0 and warm sepia
#b8a068 for the plastic, deep ink #1a0f08 for outlines and vents, tarnished
gold #b08a3e for a small badge, rust orange #8b4a1e accents. The SCREEN area
is a flat solid pure magenta rectangle (#ff00ff), nothing drawn on it.
Plain flat background in the same parchment cream #e8d5a0, no shadow, no
desk, no cables, no text, no logo. Crisp edges, slightly worn plastic, soft
top-left lighting.
```

Variações úteis: "pixel art, 1px dark outline, limited 16-color sepia
palette" (se preferir já em pixel art), ou passar o PNG do Higgsfield pelo
PixelLab (`image_to_pixelart`) com a paleta do jogo.

Regras que NÃO podem faltar (o importador depende delas):
- tela em **magenta puro `#ff00ff`**, lisa e retangular (é o que o script
  detecta e recorta; vira a janela onde o jogo desenha o tubo);
- fundo **liso** (o script corta pela cor do canto) ou transparente;
- computador inteiro no quadro, sem cortar pés nem topo; sem texto na arte;
- a FENDA do disquete desenhada em tinta escura, larga e baixa, abaixo da
  tela (o importador a detecta e grava `slot`; é por ela que a carta entra
  antes do mergulho; se não achar, o jogo usa `IntroTube.SLOT_FALLBACK`).

## Instalar

```
python tools/intro_computer_import.py C:\caminho\render.png --width 640 --palette
love . test_one screenshot_intro pt_BR:1920x1080     # 5 quadros + fita
love . test_one test_intro_tube
```

`--width` reduz com nearest (pixel art fica nítida; 640 px de largura = o
computador ocupa ~46% da janela 1080p sem reamostrar); `--palette` quantiza
nas cores do `Palette.lua`. Sem o arquivo de dados a abertura usa o
televisor do shader (comportamento atual).
