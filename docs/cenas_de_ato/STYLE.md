# Cenas de abertura de ato — style bible (14/11/2026)

Pedido do Daniel (14/11): "mini cenas antes de começar cada ato ... uma cena totalmente gerada com pixelab contendo várias camadas ... elementos se mexendo ... com efeito sonoro ... como se fosse uma apresentação". Depois: "algo na vibe da imagem do vídeo do yt que te mandei" (só clima e composição; nada de copiar o quadro, o título nem o mago).

## Formato (igual nos 6 atos)
- Duração 8 s (pular com clique, tecla ou botão do controle a qualquer momento; ao terminar segue sozinho).
- Tela em pixel art de 640×360 px virtuais, escala inteira (1280×720 = 2×, 1920×1080 = 3×, 2560×1440 = 4×), bordas com a cor do céu/chão.
- Composição fixa da série (é o que faz as 6 lerem como uma coleção):
  1. **Moldura em arco**: galhos/troncos do bioma (no ato 1, um carvalho velho) fecham o topo e as laterais. É a camada mais próxima, escura e contrastada.
  2. **Caminho**: uma trilha de pedra ou terra sai do pé da tela, no centro-direita, e entra em profundidade até o ponto de fuga.
  3. **Viajante solitário**: figura encapuzada de costas, pequena (1/6 da altura), parada no caminho, olhando o mundo. Capuz, manto, alforje e cajado simples de viajante. Nunca chapéu pontudo, barba longa ou cajado de mago (nada que leia como personagem de terceiros).
  4. **Luz ao fundo**: a fonte de luz do bioma atrás do arco (no ato 1, o sol dourado do entardecer) com raios suaves; o fundo é claro, a frente é escura (contraluz).
  5. **Título à esquerda**, no terço superior: "ATO I" pequeno, o nome do ato grande, e uma linha de subtítulo menor. Fonte do jogo (`assets/fonts/pixel.ttf`), ouro `{0.95, 0.82, 0.52}` com sombra, entra letra a letra.
- Camadas (parallax, do fundo para a frente): `sky` (opaca), `far`, `mid`, `path`, `traveler`, `arch`. Movimento de câmera: deriva lenta de 12 px para a direita e zoom de 1,00 → 1,03 ao longo da cena; cada camada se desloca proporcionalmente à profundidade (0,1 / 0,25 / 0,5 / 0,8 / 0,85 / 1,2).
- Elementos vivos: até 4 por cena, escolhidos pelo bioma. Ato 1: folhas caindo, poeira dourada nos raios de luz, névoa baixa, corvos ao longe e o manto do viajante ao vento.

## Paleta e traço
- Paleta do bioma em `src/data/biomes.lua`, mais o sufixo sépia de `memory/backgrounds_catalog.md`. Ato 1 (`fields`): céu pêssego e dourado, montanhas azul-acinzentadas, verdes de folhagem com reflexo verde-azulado APAGADO (nada de ciano neon), terra ocre e caminho de pedra musgosa.
- Pixel art nítida, contorno escuro de 1 px nas camadas próximas, sem contorno no fundo distante (perspectiva atmosférica: o fundo fica mais claro e menos contrastado).
- Diorama (`memory/art_direction_diorama.md`): copas em três planos, oclusão e sombra na direção da luz do bioma.
- Nenhum texto dentro da arte; o título é desenhado pelo jogo.

## Som
- A música do ato entra em fade de 2,5 s no início da cena (a trilha nova de cada ato).
- 2–3 SFX ambiente por cena (ElevenLabs sound-generation): a cama do bioma (vento no capim e nas folhas no ato 1), um detalhe vivo (corvos ao longe) e um "selo" suave quando o título termina de escrever (um sino ou harpa curto e grave).

## Transição no jogo (um movimento só, 14/11/2026)
Ordem: a tela de onde se vem (recompensas do chefe, ou menu/seleção de classe na run nova) escurece em 0,6 s (retrato tirado na hora, `ActIntro.snapshot`) → a cena sobe do preto com o ambiente do bioma → a música do ato entra a partir de 1 s (`ActIntro.MUSIC_AT`; o MusicDirector segura o silêncio antes) → título letra a letra a partir de 1,5 s e o sino no fim do nome → o detalhe vivo (corvos, coruja etc.) em 4,3 s, longe do sino → no fim a cena se funde direto na tela seguinte (encruzilhada ou início da estrada), sem passar pelo preto. Pular continua valendo (o fim vira uma fusão de 0,35 s); entrada e os primeiros 0,25 s ignoram clique, tecla e botão (o clique que fechou as recompensas não pula a cena). Durante a cena não aparecem partículas, textos flutuantes nem o flash de início de run.
Captura: `lovec . test_one record_act_transition <0..6>` (0 = run nova; N = chefe do ato N até a encruzilhada do N+1; 6 = fim do jogo) e `python tools/act_transition_video.py <pasta> <saida.mp4>` (vídeo com o som remontado das fontes do jogo e um relatório de pretos, cortes secos e entradas de som).

## Regras de jogo
- Aparece ao começar o ato 1 (nova run) e depois do chefe de cada ato, antes do próximo.
- Opção "Cenas de abertura de ato" (aba Vídeo, ligada por padrão; a aba Jogo já está no limite de 6 linhas). Desligada, ou se a arte falhar ao carregar: a cena não aparece e o jogo segue direto. Com `reducedMotion`, a cena aparece parada (sem deriva da câmera, folhas e poeira).
- Ferramentas e testes sem janela pulam a cena (como a intro); quem testa ou grava a cena liga `_G.ACT_INTRO_FORCE`.
- Nunca entra no save: o Continuar nunca reabre uma cena.

## Pipeline (piloto do ato 1, 14/11/2026)
1. `python tools/pixellab_act_intro.py queue <ato> master` + `poll <ato>`: uma pintura mestra 688×384 no `create_image_pro` (o modelo desenha ~480×268 com margem), com a arte do próprio ato como referência de estilo (`style_ref.png`). Custo: 25 gerações.
2. `python tools/act_intro_layers.py <ato>`: separa a pintura em `far` (céu e montanhas), `ground`, `arch` (máscara por cor das árvores ligadas à borda) e o recorte do viajante, e preenche o que fica atrás com a cor vizinha. Ajustes por ato no dicionário `ACT`.
3. `python tools/pixellab_act_intro.py anim_traveler <ato>` e `crow <ato>`: loops curtos no `animate_image` (manto ao vento, 8 quadros; corvo, 6). Custo: ~3 gerações. `python tools/act_intro_anims.py <ato>` limpa e encaixa.
4. SFX: ElevenLabs sound-generation (cama de ambiente em loop + 1 detalhe vivo + o sino do título, igual nos 6), normalizados a -25/-24/-21 LUFS.
5. Atos 2–6 (14/11/2026): a pintura mestra usa a do ato 1 como referência de estilo ("mesma série"). O arco sai por luminância (contraluz: `arch_lum`, `lum_k`, `fill_holes` no `ACT`), com parallax do arco menor (0,85–0,9) para esconder a borda reta da máscara. O viajante é o loop do ato 1 (`animDir`, com `travelerTint` do bioma); onde o da pintura é menor (atos 4–6), ele fica parado no chão (`traveler = false`). Elementos vivos por `fx` (`glow` = brasas, vagalumes, almas; `mote` = neve, cinza, esporos), névoa, corvos e lanterna.
   - 2 Colinas da Torre: noite de lua, vagalumes, névoa, corvo; vento + coruja.
   - 3 Estrada do Abismo: sol vermelho, brasas subindo, cinza caindo, lanterna; vento + pedras rolando.
   - 4 Geleira Espectral: neve em dois planos, almas azuis, névoa; vento gelado + gelo rachando.
   - 5 Pântano da Podridão: lua verde, luzes do pântano, esporos, lanterna; pântano + bolhas.
   - 6 Campos do Crepúsculo: eclipse, folhas de outono, poeira dourada, corvos; vento + sino distante.
   - O nome no título é sempre `acts.actN` (nome do bioma, igual ao do bestiário); `act_intro.actN_sub` é o subtítulo.
6. Vídeo: `lovec . test_one record_act_intro <ato>` (quadros PNG, relógio fixo, `TOOL_WINDOW=1920x1080`) e `bash tools/act_intro_video.sh <ato> <saida.mp4>` (música do ato e SFX nos volumes do jogo).
