# Geleira Espectral (frost, ato 4): checklist (18/Out/2026, frente replica-45)

Capturas: `antes/` (main `ed2484f1`) e `depois/`, grade de 12 (`b4_{dia,meio,por}_{fork,landmark,viagem,castelo}.png`),
batalha 1080p em tod 0,65 e 0,95 (`batalha_1080p_tod65/95.png`), régua em `*/escala/` (com e sem sombra).
Recortes antes|depois em `recortes/` (ampliados 1x a 3x). Arte nova em `arte/`.

Atenção: a luminária nova tem outro peso de sorteio (0,6 para 0,9), então a fila de props do quadro de
batalha mudou (antes 2 lanternas, depois 3 postes). Os recortes comparam a MESMA região da tela, não o mesmo
objeto; as razões de escala estão em `objetos.md`.

## Lista fixa do plano (Tarefa 9)

| # | pergunta | resposta | evidência |
|---|---|---|---|
| 1 | Temperatura única fria; a neve continua a coisa mais clara | **Sim.** Grade virou só matiz (dia 0,96/0,98/1, pôr 0,86/0,90/1, era 0,64/0,70/0,90 e escurecia a cena inteira por cima do ambiente). A neve das copas e dos postes é o branco da cena. | `recortes/06_pinheiros_meio_dir.png`, `depois/b4_dia_fork.png` |
| 2 | Horizonte muito lavado, sem degrau | **Sim.** `fogCurve` 1,4 → 1,9 (névoa só no fundo), `fogFar` 0,55, `contrastFarDay` 0,88; a crista recua para o azul das montanhas sem faixa. | `recortes/07_crista_castelo.png` |
| 3 | Faixa de contato azulada e suave (≤ 0,5) | **Sim.** `contact.alpha` 0,45 com `shadowTint` azul; a base do poste tem faixa curta azul, não preta. | `recortes/04_base_luminaria_sombra_tod65.png` |
| 4 | Tufos baixos e raros (`baseCover` ≤ 0,08) | **Sim**, 0,07 (intocado). | `recortes/11_bandeira_encruzilhada_dia.png` |
| 5 | Névoa baixa a mais presente (0,28 a 0,34) e quase parada (≤ 0,012) | **Sim**, 0,30 e drift 0,012 → 0,010. | `depois/b4_por_viagem.png` |
| 6 | Pinheiros com pouco vento (≤ 0,028) | **Sim**, `canopySway` 0,026 → 0,024. | dado |
| 7 | Névoa de intenção do ato 4 manda na viagem | **Sim.** `fogHook`/`intent_fog.lua` intocados; `test_weather` 148/0. | `depois/b4_*_viagem.png` |

## As 9 lições do dono

| # | lição | resposta | evidência |
|---|---|---|---|
| 1 | Sombra natural, nítida, 3 degraus, nascendo da base; nada do fundo pintando a frente | **Sim.** Sombras ligadas como no ato 1 (`alphaK` 1,0 → 2,0, `fade` 0,30, cor de multiplicação azul 0,46/0,52/0,66, árvore ×1,35, disco de copa 0,45). Poste: a sombra nasce no pé e cai para baixo-esquerda (sol à direita), multiplica o chão em ~0,72. Diff com `ESCALA_NOSHADOW=1`: nenhuma sombra sobre o inimigo nem sobre o poste da frente. | `recortes/04_base_luminaria_sombra_tod65.png`, `depois/escala/b4_tod65_nosh.png` |
| 2 | Árvore nunca mais clara/enevoada que o chão ao lado | **Sim** no sentido da lição: a névoa das árvores agora segue a curva do chão (`treeDepth.lift` 0,30, `haze` crua, sem filtro branco). Os pinheiros são mais claros que o chão por serem NEVE pintada, não por névoa; o chão subiu (ver 8) para a neve das copas não brilhar sobre asfalto. | `recortes/05_pinheiros_meio_esq.png`, `06` |
| 3 | Escala contra o inimigo | **Sim.** Poste novo 0,86 a 0,88× o inimigo na mesma profundidade (a lanterna de mão antiga valia 0,24×); pinheiro adulto sempre acima do poste; castelo 2,8× a maior árvore da crista (299 / 107 px). Braseiro (2,7) fica como fogo de chão, ~0,35×. | `objetos.md`, `depois/escala/b4_tod65.txt` |
| 4 | Árvores não todas iguais | **Parcial.** 3 pinheiros + árvore morta com `sizeK` e `PropVariation` (`bright` 0,12 novo). Não regenerei pinheiros (a frente de animação vem depois); a parede ainda repete as 3 silhuetas. | `recortes/05`, `06` |
| 5 | Lado iluminado para o sol | **Sim.** Poste novo pintado com luz da direita (sol do bioma em `xr` 0,80); `face = 1` vira o braço para a estrada. | `recortes/02_luminaria_meio_tod95.png` |
| 6 | Luminária apagada de dia, acesa no entardecer; fogo tinge o chão | **Sim.** O poste usa o `dayK` do motor (luz só a partir de tod 0,45); luz 1,25 → 1,50 de raio, 0,80 → 0,95 de intensidade. Fogueira: `selfLight` 0 → 0,20 (×2 no descanso). A chama pintada do PNG fica sempre, como no ato 1. | `recortes/01_luminaria_perto_tod95.png`, `09_fogueira_encruzilhada_por.png`, `12` |
| 7 | Chão mais escuro e mais frio lá para frente | **Sim.** `groundFar` 0,8 → 0,66, `groundReach` 0,7 → 0,85. | `depois/batalha_1080p_tod65.png` |
| 8 | Colagem | **Corrigido o maior caso:** o chão era asfalto escuro (46/54/75) sob pinheiros carregados de neve. `biomes.lua` frost: `grassA/B` e `grassTint` sobem para um chão de neve batida azul-acinzentado (~80/97/134). A lanterna de mão (caixinha de pedra de 36 px que lia como lixeira) foi trocada por poste de ferro nevado. | `recortes/08_chao_perto_tod65.png`, `01`, `03` |
| 9 | Métrica não prova visual | Olhei cada recorte e a batalha nos dois horários antes de marcar. | este arquivo |

## Leitura honesta do que ainda está feio

- A parede de pinheiros repete 3 silhuetas; no perto os pinheiros enormes são o mesmo PNG espelhado.
- O mato do chão (tufos da `GrassField`) ainda tem um tom malva em 1024x768 no pôr do sol.
- A sombra longa dos pinheiros do meio cria no quadro de batalha uma borda reta e comprida no chão (fisicamente
  plausível com sol baixo, mas lê como faixa).
- A luz das luminárias continua discreta em cima da neve: o lightmap só multiplica, e o chão claro tem pouco
  para clarear.
