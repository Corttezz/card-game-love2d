# Corte 13 (incremental sobre o corte 12)

_03/11/2026. Pedido: falas do Daniel de 03/11 14:21 (`E:\dev\_orquestracao\` follow-up do corte 13). Base: corte 12 com a loja (a versão que ele viu, 72,6 s)._

## Arquivos

- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c13_720p.mp4`: 80,0 s, 13,6 Mb/s.
- Master: `grimoire_trailer_c13.mp4`.
- Montagem: `card-game-trailer\tools\trailer_c13_cut.py` (branch `steam-store-v2`).
- Render: `corte/render13.sh`. Medidas: `corte/medir13.py` (saída em `corte13_provas\medidas.txt`). Folhas: `corte/provas13.py`.

## Os 5 pontos do Daniel

1. **Loja sem corte brusco.** A loja ficou com 4,0 s (29,41 a 33,41 s):
   - **Imagem:**
     - entra por dissolve de 0,5 s;
     - mostra a chegada pela estrada até a casinha da loja, e a passagem do próprio jogo para o interior (cerca de 31,0 s);
     - sai por dissolve de 0,45 s para o Espantalho.
   - **Som:**
     - crossfade de 1 s da música do Rei para a música da loja (28,91 a 29,91 s);
     - o sino da loja (`shopOpen`) toca na tomada;
     - na saída, crossfade de volta (32,91 a 33,71 s).
     - O Rei retoma 1,5 s antes do ponto onde parou. Assim os cinco salões caem **nas mesmas posições da faixa do corte 12** (62,80 / 64,06 / 65,00 / 66,56 / 67,81 s da música).
   - Folha: `p_loja_transicoes_10qps.png`.
2. **Espantalho: tomada nova.** Gravada hoje, headless:
   - identidade `card-game-trailer-c13`, um `lovec`, código atual da `main` com o voo novo do anjo;
   - arquivo `entr_cursed_scarecrow_c13.mkv`.
   - O espantalho de madeira fica no primeiro plano, e a criatura salta do poste e anda até a estrada.
   - No filme: 33,41 a 36,14 s (`p_espantalho_10qps.png`).
3. **Anjo Caído: voo novo pelo PixelLab.**
   - **Causa:** o voo usava o clipe `descend`, que só abre as asas, sem bater nenhuma vez. Além disso, o corte antigo começava 1,9 s depois da largada, quase no pouso.
   - **Arte:** clipe novo `swoop`, gerado no PixelLab (`animate_image`, 3 tentativas, escolhida a 3) dentro da assinatura Tier 2, sem gasto novo (949 gerações restantes antes).
     - 12 quadros em loop: as asas sobem, abrem, descem com força; o corpo sobe 3 px; os pés ficam soltos; o manto ondula.
     - Primeiro e último quadro idênticos ao `idle/0`.
     - O voo do jogo usa esse loop (`swoopLoop`).
   - **Commit no jogo:** `8f841939` (branch `trailer-c13-anjo-voo`).
     - Testes: `test_enemy_entrances` 964/0 e suíte completa 172/172 PASS.
   - **Tomada nova:** `entr_fallen_angel_c13.mkv`. No filme vai de 38,64 a 41,81 s, entrando 0,6 s antes da largada: cerca de 2 s de voo batendo asas até o pouso.
   - Folha: `p_anjo_15qps.png`. Antes e depois: `anjo_voo_antes_depois.png`.
4. **Portão sem corte brusco:**
   - **Música:** desce aos poucos do início do último salão (48,91 s) até abaixo de −50 dBFS em 51,20 s, **2,29 s** de fade.
   - **Aproximação** (50,18 s): plano novo, a caminhada pela estrada até o castelo com a bandeira, só som ambiente.
   - **Porta** (52,58 s): a porta abrindo, com o som do portão.
   - **Entrada do Rei-Carniça desde o começo** (54,58 s): salão escuro, os olhos acendendo em 55,08 s, os rasantes, o pouso e o cartão do nome.
   - **Luta** (62,13 s): a música volta numa batida forte, e daí em diante tudo segue como no corte 12.
   - Transições em dissolve (0,5 / 0,4 / 0,3 s).
   - Folhas: `p_portao_seq_10qps.png`, `p_entrada_chefe_5qps.png`.
5. **Final bem amarrado à música:**
   - os cortes da luta, os corvos e o golpe letal continuam nas batidas fortes da faixa;
   - depois do golpe, a música cede a −16 dB e volta para a morte;
   - o corte para o preto foi posto num ataque da faixa (73,05 s, 7,9x) e ganhou impacto (`boot-impact` + `boss_land_impact`);
   - a música corta junto e está abaixo de −50 dBFS em 73,18 s;
   - o logo (73,35 a 79,85 s) toca só os sons da animação.
   - Folha: `p_final_10qps.png`.

Pendências do corte 12 também aplicadas:
- fade longo antes do portão (ponto 4);
- seção das cartas e da Coleção **+2,2 dB** contra o corte 12.

## Medidas (`medir13.py`)

| item | medida |
|---|---|
| loudness (ebur128, 720p final) | `I: -14.1 LUFS  LRA: 8.0 LU  Peak: -1.2 dBFS` |
| fade antes do portão | 48,91 → 51,20 s (2,29 s até −50 dBFS) |
| música isolada, 51,20 a 62,08 s (aproximação, portão, entrada inteira) | máx. −53,0 dBFS |
| música isolada, do portão (52,58 s) ao fim da entrada | máx. −91,6 dBFS |
| música isolada, logo inteiro (73,35 a 79,85 s) | máx. −95,7 dBFS |
| golpe letal sobre a música (1,6 a 0,15 s / 2,5 a 0,5 s antes) | +17,8 / +14,1 dB |
| morte nas cartas, mesmas janelas | +10,4 / +11,3 dB (11f: +3,6) |
| cartas + Coleção contra o corte 12 | +2,2 dB |
| final contra o corte 12 | 390 quadros, diferença média 0,04/255 |

- **Escala:** sem zoom do corte.
  - Os avisos de `escala.txt` ficam em 27,4 s (corte com glitch) e 41,43 s (medida degenerada no pouso do anjo).
  - Os demais caem de 57,77 a 58,63 s, dentro da cinemática do próprio jogo, com poucos pontos casados.
- **Custo:** a morte nas cartas perdeu cerca de 4 dB de margem contra o corte 12, porque as cartas subiram. Continua acima do 11g (+9,6).

## Revisão 2 (depois de `revisao-corte13.md`, d3a1141c, 8,8 FAIL)

Só mixagem; a imagem é a mesma.

1. **Entrada da loja sem buraco.**
   - O Rei agora desce devagar, sobreposto à loja, e só zera 1,8 s depois do corte: +2 → −3 dB em 29,91 s → −10 dB em 30,71 s → silêncio em 31,21 s.
   - A música da loja sobe de −34 para −3 dB entre 28,81 e 29,81 s.
   - O Rei volta 2,8 s antes do ponto onde ficou inaudível, e os salões continuam nas mesmas posições da faixa do corte 12.
   - **Medida** (envelope de 50 ms, `corte13_provas\transicoes_som.txt`): mínimo de −26,5 dB e subida máxima de +7,6 dB em 50 ms. Antes eram −39 dB e +25 dB. No meio da loja, o ritmo da própria faixa sobe +11,8 dB em 50 ms.
2. **Aproximação com som de ambiente.**
   - O ambiente da tomada subiu (ambiente 4,0).
   - Entram o vento e os grilos do jogo (`weather/wind-1`, `night-crickets-1`).
   - **Medida:** o som total de 50,18 a 52,58 s fica entre −30,4 e −14,2 dB, mediana −23,5 dB (antes, −44 a −54).

As outras medidas não mudaram:
- `I: -14.0 LUFS  LRA: 7.9 LU  Peak: -1.2 dBFS`;
- fade de 2,29 s; música ≤ −91,5 dBFS do portão até a luta e ≤ −95,6 dBFS no logo;
- golpe letal +14,1 dB; cartas +2,3 dB contra o corte 12;
- logo igual ao 12 (0,04/255);
- 720p a 13,6 Mb/s.

## Aprovação e entrega

- **Revisora do time:** `revisao-corte13b.md` (commit `d70e1496`), **9,2**, `===CORTE13_PRONTO===`.
- **Entregue:** `C:\Users\corte\grokbot_entrega\corte13_720p.mp4`, igual byte a byte ao master 720p. sha256 `22dd06f6ef2dcbd1eaf8e5aee5153a3021a710033d501202aa1a49d722d71ece`.
- **Ressalva não aplicada:** ficou um vale de ~0,8 s (50,5 a 51,4 s, −32 a −40 dB na medida dela) entre a saída da música e a entrada do vento. Ela recomenda entrar com o vento ~0,5 s antes.
