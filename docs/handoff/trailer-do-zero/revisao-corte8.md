# Revisão: corte 8 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte8.md` (commit 31724b34), `revisao-grimoire-corte7.md` (7 pontos, commit 816f0997), a decisão definitiva do Grimoire sobre o ponto 2 e os critérios de sempre. Vídeos: `grimoire_zero_corte8_1080p.mp4`, `_720p.mp4` e `_rei_720p.mp4`; stems em `build\trailer\zero8\zero8_tirano\` e `zero8_rei\zero8_rei_rei\`. Método: luma de todos os quadros e loudness (`medir.py`), mixagem por plano (`mixagem.py` → `mix8_*.json`), força de ataque do grave (30 a 160 Hz), fluxo espectral em mel (`flux.py`), deslocamento vertical quadro a quadro na queda (perfil da parede), folhas a 2,5, 10 e 20 quadros/s, recortes 1:1 e quadros a 50%. Tudo em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\c8\` (pré-checagem no corte 7 em `...\rev\p8\`). Não ouvi._

## Os 7 pontos: real ou falso, conferido por conta própria

| # | ponto | diretora | minha conferência | no corte 8 |
|---|---|---|---|---|
| 1 | zoom recuando no fim da luta | real | **Real**, mas não nos tempos do Grimoire: no corte 7 o recuo era a passagem **×3 na vida → ×1 na mão** (45,8 s Tirano / 45,75 s Rei, `p8\luta_t.png`, `p8\luta_r.png`), seguida de ×2 no LETHAL. **Erro meu:** dei 10 em "zoom em degraus progressivos" (N4) nos cortes 5 a 7 sem ver esse ×1. | **Resolvido nas duas** (`q\fim_t.png`, `q\fim_r.png`): Revoada ×2 → vida ×2 → **um plano ×2** com o Rei, a mão e o painel "29 → 48 LETHAL" (45,8 a 50,36 s) → golpe **×3** (o "48" vermelho inteiro no alto) → queda ×3. Nenhum degrau para trás. O pan da queda anda **3 px de tela por quadro na 1080p e 2 px na 720p (1 px de captura)**, posição pelo quadro. Ele para ~0,5 s no meio e retoma; as oscilações de ±5 a ±15 px no impacto são o tremor do jogo, que já vem na tomada. |
| 2 | Murder of Crows (critério definitivo do Grimoire) | a carta não existe | **Confirmado no código:** `murder_of_crows` é golpe do Rei-Carniça (`src/data/enemies.lua:100`), e não há carta com esse nome em `src/data/cards`. | **Atende.** Plano ×2 no Rei nas duas, com os mesmos quadros da tomada. Folha a 20 quadros/s (`q\nome.png`): nome grande de **42,05 a 42,65 s** (Tirano) e de **42,39 a 42,99 s** (Rei), depois o nome menor, ainda legível, até o corte. Legível por **~1,0 s** na principal e **~0,85 s** no Rei, dentro de 0,8 a 1 s. Os corvos partem no corte para a vida, que continua no lugar (35 ms e 55 ms do grave, como nos cortes aprovados). |
| 3 | golpe do Rei em ~49,9 s é o ataque mais forte? | não procede | **Falso, tabela confirmada.** O golpe está a 50,36 s. Na mixagem final: grave de **49 dB a 50,368 s** (o maior entre 49,3 e 51,3 s, fora o ataque de 57 dB a 49,50 s, que fica a −52 quadros) e fluxo espectral **13,27 a −1,8 quadro** (o mais forte em ±0,6 s). Em 49,9 s há só um onset fraco (2,98 no meu método, 1,89 no da diretora). No stem da música, a volta do golpe tem 86 dB no grave. | ok |
| 4 | castelo → portão ~1,4 s contra 2,24 s | intervalo diferente | **Explicado, tabela confirmada.** Na EDL: esporo 25,07 a 26,31 s, pouso 26,31 a 27,31 s, portão a partir de 27,31 s, total 2,24 s. Provável origem dos ~1,4 s do Grimoire: **o castelo aparece ao fundo** do plano do esporo (silhueta no horizonte, quadros de 25,5 e 25,9 s) e do pouso (torres ao fundo, 26,6 s; `q\r259.png`). É o horizonte do bioma, não o plano do castelo. | ok |
| 5 | fumaça roxa pontilhada entre o salão e o Rei | não é nossa | **Falso como transição.** A prova lado a lado (tomada crua 13,8 s × corte 7 33,9 s) mostra a mesma fumaça roxa pontilhada com os olhos no escuro: é a cinemática do próprio jogo. Antes dela há corte seco. | ok (não mexer é o certo) |
| 6 | Carrion Crown chapada | real | **Real.** | **Resolvido** (`q\brilho_t.png`, `q\brilho_r.png`, 10 quadros/s): uma faixa de brilho diagonal em blocos passa pela face a cada ~1,2 s, e entre as passagens a carta tem o brilho vivo das joias. A face e o nome continuam legíveis em todos os quadros, sem lavar. |
| 7 | contorno escuro nas silhuetas dos salões | real (estilo) | **Real.** | **Feito, mas aplicado onde não há silhueta.** Ver abaixo. |

## O que segura nas duas versões: o contorno do ponto 7 pega luz, fogo e neve

O pedido do Grimoire era um contorno de 1 px da grade **nas silhuetas principais**, para casar com os sprites. O filtro aplicado põe o contorno em toda borda de luminância > 55, e com isso:
- **Trono (31,0 s, `q\trono78.png` 1:1 e `q\halls8.png` a 50%):** as manchas de luz das velas nos pilares e as poças de luz do tapete e do chão ganharam borda preta e viraram recortes chapados, como adesivos. O contorno também corre por dentro das chamas atrás do trono.
- **Salão de lava (14,5 s, `q\hall78.png`):** tracejados pretos por dentro da cascata de lava, que leem como rachaduras ou sujeira. Nos pilares, que são silhueta, ficou bom.
- **Gelo (21,3 s, `q\f8_21.3.png`):** a neve e o gelo iluminados do chão ficaram cheios de tracejado preto.

Nos sprites do jogo, luz, fogo e neve não têm contorno: só os objetos sólidos têm. Do jeito que está, o salão fica mais sujo que no corte 7. **Exijo** o contorno só nas silhuetas sólidas (pilares, arcos, trono, estátuas, bordas de parede e chão contra o fundo) e nenhum contorno em borda cujo lado claro seja luz, fogo, lava, chama ou neve, por exemplo excluindo as bordas em que o lado claro está acima de uma luminância de emissor ou na faixa de matiz do fogo e do gelo. Mesmos salões, mesma grade de 5 px.

## Versão principal (Tirano), 1080p e 720p: NÃO APROVADO (falta 1 item)

Medidas: zero quadros < 5% nos 3870 quadros; −14,1 LUFS, −1,1 dBTP, LRA 8,4 (1080p = 720p); pico −9,5 contra −12,0 fora do clímax, **+2,5 dB**; coringa com a música **4,7 dB abaixo do SFX**; música até o fim, com fade; mixagem por plano igual à do corte 7 aprovado, exceto a Revoada (SFX −36 dB, ambiente −52 dB, música à frente). Os cortes depois de 40 s são 41,45 (dentro do plano da mão), 43,02, 45,80, 50,37, 50,97 e 55,22 s, mais 51,35 s, que é o Rei ajoelhando (fundo parado, conferido no corte 6).

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | 10 |
| C2 Sem preto | 10 | | G2 caminhada | 10 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | **8** (contorno em luz e fogo) |
| C4 Legibilidade | 9 | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 (o plano ×2 do LETHAL tem 4,56 s, mas com ação contínua: cartas jogadas e o painel subindo) | | G5 golpe final forte | 10 (×3 com o "48" inteiro) |
| C6 Pico | 9 (+2,5 dB) | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | 9 | | N1 virada legível | 9 |
| C9 Conformidade | 9 | | N2 caminhada / porta | 10 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | **8** (contorno fora da silhueta) |
| C11 Continuidade | 9 | | N4 zoom em degraus progressivos | 10 (agora sim, sem o ×1) |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | 9 |
| C13 Prende do início ao fim | 9 | | 10 pontos do corte 5 e correções dos cortes 6 e 7 | 9 ou mais em todos |
| C14 Som | 9 | | pontos 1 a 6 do corte 7 | 9 ou mais em todos |
| **Q queda do Rei** | **9** (×3 acompanhando o corpo; a pausa de 0,5 s no pan não atrapalha a leitura) | | **ponto 7 do corte 7** | **8** |

## Variante do Rei (720p): NÃO APROVADO (falta 1 item, o mesmo)

Medidas: zero quadros < 5%; −14,1 LUFS, −1,1 dBTP, LRA 8,6; pico **+3,1 dB**; coringa com a música **5,2 dB abaixo do SFX**; a face com o nome segurada até o logo (sem cinza), com o giro único da 7c; portão e pouso nos ataques; os 5 cortes do ponto 10 nos onsets; música até o fim. Os salões são os mesmos arquivos da principal, então o contorno tem o mesmo defeito.

As notas são iguais às da principal, menos: **C6 Pico 10** (+3,1 dB). **G3, N3 e o ponto 7 ficam em 8.**

## Status
- Principal (Tirano): **NÃO APROVADO**, só pelo contorno nos salões (ponto 7, G3, N3 em 8).
- Variante (Rei): **NÃO APROVADO**, pelo mesmo item.

Os pontos 1, 2, 4 e 6 estão resolvidos, e os pontos 3 e 5 eram falsos, com prova conferida. Com o contorno restrito às silhuetas sólidas, sem outra mudança, as duas versões ficam com 9 ou mais em tudo. `===CORTE8_PRONTO===` não marcado.
