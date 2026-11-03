# Corte 12 (incremental sobre o 11g rev 2)

_03/11/2026. Pedido: falas do Daniel de 03/11 09:38 (`E:\dev\_orquestracao\tdz_c12.txt`). Só montagem e som sobre o 11g rev 2. Nenhuma captura nova._

## Arquivos

- Principal: `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c12_720p.mp4` (69,6 s), master `grimoire_trailer_c12.mp4`.
- Variante A/B com a loja: `grimoire_trailer_c12_loja_720p.mp4` (72,6 s), master `grimoire_trailer_c12_loja.mp4`.
- Montagem: `card-game-trailer\tools\trailer_c12_cut.py` (branch `steam-store-v2`). Render: `corte/render12.sh main|loja`. Medidas: `corte/medir12.py main loja`. Provas: `corte/provas12.py`, pasta `corte12_provas\`.

## O que mudou contra o 11g rev 2

1. **Uma versão só, com a música do Rei-Carniça.** A Tirano saiu, junto com os impactos extras que só existiam para ela.
2. **Portão e entrada do chefe sem música.** A música vem caindo no último salão (ROT COLOSSUS) e chega a zero no corte do portão. O portão fica 1,8 s (antes 0,95 s) só com o som do castelo abrindo e o ambiente. Depois vem a entrada do Rei-Carniça com os sons dela. A música volta no primeiro quadro da luta, no mesmo ponto da faixa que o 11g usava (batida 15,7x).
3. **Final sem música.** Depois do golpe letal a música cai e está em zero antes do preto. O logo com o Grimório enchendo de ícones toca só com os sons da animação. Imagem do final idêntica ao 11g.
4. **Textos mais visíveis.** Mesma redação (inclusive "SIX BOSSES."):
   - letra maior (até escala 12);
   - faixa escura mais forte atrás (alfa 225, era 160);
   - posição um pouco mais baixa (17% da altura);
   - revelação mais curta (0,22 s, era 0,35);
   - mais tempo na tela: 4,2 / 3,4 / 2,9 / 3,6 s.
   - "ONE HAND CAN BREAK A KING." agora entra nos corvos e fica 3,2 s (era ~1,5 s, quase ilegível).
5. **Portão sem o HUD 70/70.** O plano começa no quadro 570 da tomada, quando o HUD já saiu. O som do portão vai como efeito no corte.
6. **Mix sem `loudnorm`:**
   - ganho fixo + limitador de pico real com sobreamostragem 4x (192 kHz), a −1,4 dBFS;
   - a música cede antes dos golpes: −11 dB na morte das cartas, e o duck que já existia no golpe letal;
   - a cama das cartas, da Coleção e das criaturas subiu 2 a 4 dB e os efeitos das cartas +2 dB, para a seção não ficar baixa.
7. **Variante com a loja (A/B):**
   - 3 s dentro da loja (tomada `shop_arrive` de 20/10, build com a loja atual de 15/10), com a música da loja, entre as cartas da Coleção e as criaturas;
   - a música do Rei **pausa** e volta do mesmo ponto, então tudo depois da loja continua nas mesmas batidas (o resto do filme é o principal deslocado 3,000 s).

## Não feito

- **Queda do inimigo depois do golpe nas cartas.** A tomada mostra o bruto se desfazendo atrás das cartas jogadas cerca de 1,25 s depois do golpe (quadros 1398 a 1410), quase escondido pelas cartas. Incluir isso desfaria o corte logo depois do flash, que foi pedido e aprovado. Ficou de fora.
- **Itens da Tirano** (trocas de salão): não se aplicam mais.

## Medidas (saída de `medir12.py`, completa em `corte12_provas\medidas.txt`)

| | principal | loja |
|---|---|---|
| loudness (720p final, ebur128) | −14,1 LUFS, pico −1,2 dBFS, LRA 12,0 | −14,1 LUFS, −1,2 dBFS, LRA 11,7 |
| música isolada, portão até 50 ms antes da luta | máx. −95,7 dBFS (45,68 a 50,66 s) | máx. −92,7 dBFS (48,68 a 53,66 s) |
| música isolada, preto + logo inteiro | máx. −96,2 dBFS (62,70 a 69,50 s) | máx. −96,1 dBFS (65,69 a 72,49 s) |
| golpe letal, margem sobre a música 1,6 a 0,15 s antes / 2,5 a 0,5 s antes | +18,3 / +16,7 dB | +18,2 / +16,6 dB |
| morte nas cartas, mesmas janelas | +14,7 / +15,5 dB | +14,6 / +15,4 dB |

Comparação:
- 11g rev 2 (Rei): golpe letal +14,3 / +12,8 dB; morte nas cartas +8,9 / +9,6 dB.
- 11f (Rei): morte nas cartas +2,8 / +3,6 dB.

Outras checagens:
- **Final:** 390 de 390 quadros do `logo_sting`. Contra o 11g, diferença média de 1,36/255 (`p_fecho_c12_x_c11g.json`).
- **Escala** (`escala.txt`): só três avisos, nenhum de zoom do corte.
  - 27,4 s: corte com glitch, medida degenerada.
  - 47,7 a 47,9 s: a cinemática do próprio jogo, com o chefe voando.
  - O 11g tinha os mesmos.
- **Bitrate 720p:** 14,1 Mb/s (principal) e 13,8 Mb/s (loja).

Custo do mix novo:
- a faixa dinâmica (LRA) subiu de 8,8 para 12,0 LU;
- as cartas e a Coleção ficam cerca de 4 dB mais baixas que no 11g; os salões e a luta, mais altos.

## Aprovação e entrega

Revisora do time (`revisao-corte12.md`, commit `ba9bf2dc`):
- **Principal: 9,4**, `===CORTE12_PRONTO===`. Sem regressão contra o 11g rev 2.
- **Loja: 8,8.** Piora o filme: são 3 s de prateleira parada, e a música da loja corta a do Rei na subida para o Espantalho. Por isso ela **não** entra no corte.

Entregue em `C:\Users\corte\grokbot_entrega\`, os dois iguais byte a byte aos masters 720p:
- `corte12_720p.mp4`, sha256 `fc956a726ddaa921b2671a80f953d9cc1694086fe4fcbc02832ec5040f668f71`;
- `corte12_loja_720p.mp4`, só como registro do A/B rejeitado, sha256 `6b20b167860814833421c6597d210063e98ec9be8f34b524ef42fed2a5739adf`.

Ressalva da revisora, não aplicada: a música some em cerca de 0,75 s antes do portão. Um fade de 1,5 a 2 s leria mais como "abaixando".
