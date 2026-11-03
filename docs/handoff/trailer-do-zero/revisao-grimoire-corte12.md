# Revisão independente: corte 12 (principal Rei-Carniça + variante com loja)

_Revisora independente (revisora-grimoire), 03/11/2026. Não li `revisao-corte12.md` nem nenhum `revisao-corte11*.md` da revisora do time. Medi tudo de novo direto dos mp4. Não ouvi as mixagens: o som foi avaliado pela stem de música, pelo envelope RMS de 100 ms, por loudness EBU R128 e pela margem dos golpes._

## Arquivos revisados

| arquivo | sha256 | observação |
|---|---|---|
| `grimoire_trailer_c12_720p.mp4` (principal) | `fc956a72…f668f71` | idêntico a `grokbot_entrega\corte12_720p.mp4` |
| `grimoire_trailer_c12_loja_720p.mp4` (variante) | `6b20b167…739adf` | |
| `grimoire_trailer_c11g_rei_720p.mp4` (referência 11g rev 2) | `3aec5769…e498b` | idêntico a `grokbot_entrega\corte11g_rei_720p.mp4` |

Provas em `revisao-grimoire-corte12_provas\`: folhas de quadros e `medicoes.txt`, com todas as saídas numéricas. Scripts fora do repo, em `%TEMP%\claude\rgc12\`.

## Veredito

| versão | nota | passa? |
|---|---|---|
| **Principal (Rei-Carniça)** | **9,3** | **sim**: ≥ 9,0 e sem regressão de ponto contra o 11g rev 2 (que eu avaliei em 9,3). Ressalva menor de mix nas cartas, abaixo. |
| **Variante com loja** | **8,7** | **não: descartar.** |

O corte 12 cumpre os pedidos das 09:38:
- portão e entrada do chefe sem música;
- final sem música;
- textos maiores e mais firmes.

E conserta dois itens que estavam em aberto no 11g: o HUD 70/70 no portão saiu e a porta agora se vê **abrindo**.

Não dou nota acima de 9,3 por três motivos:
- o fade antes do portão é rápido demais para ler como "abaixando";
- há um furo quase mudo de ~0,6 s antes do som do portão;
- a seção das cartas ficou 3 dB mais baixa que no 11g.

## Pontos do Daniel (citação literal de `tdz_c12.txt`, 03/11 09:38)

| # | o que ele disse (literal) | nota | evidência |
|---|---|---|---|
| 1 | "A música com Rick Carnisa foi a melhor." | 10 | Uma versão só, com a música do Rei. Até 45,6 s a imagem é a mesma do 11g rev 2 (só os textos mudam), e a luta usa o mesmo material com offsets constantes (−0,85 / −0,97 / −1,28 / −1,30 s). |
| 2a | "No momento em que a gente vai mostrar a entrada do castelo, com a porta abrindo, a gente vai tirar a música. A música vai ficar abaixando até ficar sem nada, para deixar o som ambiente do castelo abrindo." | **8,8** | A stem da música cai de −9 dBFS (44,6 s) para −38 (45,0) e −64 (45,5), e chega a −90 no corte do portão (45,63). A queda útil leva **~0,4 a 0,6 s**. Isso soa mais como "cortou" do que como "foi abaixando". Entre 45,0 e 45,6 s o mix inteiro fica de −34 a −91 dB RMS, um furo quase mudo de ~0,6 s, e o som do portão só entra em 45,7 (−26 → −13 dB, contínuo até 47,9). A porta **abre na tela** de 45,88 a 46,6 s (`m_porta_crop_8qps.jpg`), coisa que no 11g não se via. A música fica abaixo de −98 dBFS (pico) de 45,7 a 50,6 s. |
| 2b | "A gente vai ver o clipe de entrada do primeiro boss, com o som dele, sem a música etc." | 9,5 | A entrada vai de 47,62 a 50,62 s (3,0 s), com fumaça, aparição e o cartão "CARRION KING / Sovereign of Crows" (`m_portao_8qps.jpg`). Som próprio de −3 a −9 dB em 48,0 a 49,2, decaindo até −41 em 50,6. Música em zero. |
| 2c | "Depois, o clipe continua da forma ali que você fez na finalização." | 9,4 | A música volta seca no 1º quadro da luta (50,73 s: −105 → −8 dBFS), em cima de um onset forte. A luta é o mesmo material do 11g. Vida contínua: herói 41 → 41 → 41 → 9 → 9; chefe 124 → … → 30 → 30 → 21 → 21 (o 85 → 60 é a Imolação rolando, como no 11g) (`m_hp_cortes.png`). |
| 3 | "No final do clipe, a gente também não vai ter mais a música. A gente vai ter apenas os barulhos que tem quando está na animação ali do Grimório etc." | 9,6 | Depois do golpe letal (59,50 s) a stem desce aos poucos: −20 (59,4), −40 (60,4), −57 (61,2), −68 (62,0), −100 (62,8). Do preto ao fim, fica abaixo de −98 dBFS. O logo (63,0 a 69,5 s) traz só os sons da animação, no mesmo nível do 11g (−18,6 contra −18,5 dB RMS). Os quadros do logo são idênticos aos do 11g (diferença 0,00 em 96x54 de 64 a 69 s). O fade aqui leva ~3 s e lê como "acabou a música". É o fade que faltou no portão. |
| 4 | "Uma coisa também sobre os textos que ficam aparecendo: eu sinto que eles não estão com tanta evidência. Eu acho que talvez eles passem despercebidos, mas não é uma forma que não ficaria tão estranha." | 9,2 | A letra está visivelmente maior e a faixa escura, mais firme (`m_2qps.jpg` contra `r11g_2qps.jpg`). Tempo na tela, contado nas folhas a 2 q/s: SIX ACTS ~3,7 s; BUILD A LIVING DECK ~2,9 s; EVERY CARD COMES ALIVE ~2,6 s; A BESTIARY OF THE CURSED ~2,8 s; SIX BOSSES ~5,9 s; **ONE HAND CAN BREAK A KING ~3,8 s (55,5 a 59,3 s; no 11g, ~1,3 s)**. Sai com glitch antes do flash letal (59,30 a 59,35). Não ficou estranho: continua a mesma família tipográfica, só mais legível. Fica o risco de gosto: "SIX BOSSES." aparece sobre cinco salões. |
| 5 | "Se você quiser também, em algum momento, encaixar e ver se faz sentido mostrar a loja dentro da loja interna dela com a música da loja, pode fazer sentido, mas a gente precisa verdadeiramente fazer os testes para ver se vai ficar bom ou não." | teste feito: **descartar** | Ver a seção da variante. |

Regras permanentes:
- **Sem zoom:** nenhuma mudança de enquadramento nas folhas. O que muda de tamanho é só a cinemática do próprio jogo e o glitch.
- **Impacto por hit-stop, flash e shake:** o golpe letal tem congelamento, flash em 59,50 e cortes secos (`m_golpe_letal_20qps.jpg`).
- **Final Grimoire mantido:** idêntico.
- **Espantalho:** mantido (29,5 a 32,5 s).
- **Higgsfield:** os mesmos salões de IA (risco de gosto já conhecido).

## Critérios gerais

| critério | resultado | prova |
|---|---|---|
| duração / vídeo | 69,63 s, 1280x720 a 60 q/s, 14,1 Mb/s, AAC 315k | `medicoes.txt` |
| loudness | −14,1 LUFS, LRA 12,0 (11g: 8,8), pico real −1,2 dBFS | `medicoes.txt` |
| quadro 0 / pretos | luma 8,7, TV desligada; pretos só de 0,53 a 0,70 s e no último quadro, igual ao 11g | `medicoes.txt` |
| golpe letal | pico −0,6 dB; **+18,5 dB** sobre a música de 1,6 a 0,15 s antes, +16,7 de 2,5 a 0,5 s antes (11g: +14,9 / +13,4) | `medicoes.txt` |
| morte nas cartas (24,10 s) | flash em 24,10, pico −1,9 dB, **+14,5 / +15,2 dB** (11g: +8,7 / +9,2); cauda atravessa o glitch para a Coleção (24,35 a 24,45) | `m_cartas_morte_20qps.jpg` |
| golpes pequenos das cartas (19,38 a 23,17 s) | margem relativa +4,5 a +5,5 dB (11g: +4,8 a +6,0), mas o pico absoluto caiu de −8 a −10 para **−13 a −14 dB** | `medicoes.txt` |
| nível por seção, contra o 11g (mix igualado em −14 LUFS) | abertura −0,3; **cartas −3,0**; Coleção −1,8; criaturas −0,4; salões +1,5; luta +1,6; logo −0,2 dB | `seg.py` em `medicoes.txt` |
| corte na música | os salões e a luta caem nos onsets da faixa do Rei (≤ 4 quadros, 12 a 15x), como no 11g | `medicoes.txt` (cortes) |
| HUD no portão | não aparece. A tomada do castelo começa limpa em 45,88 s. | `m_portao_8qps.jpg` |

## Comparação com o 11g rev 2 (Rei), ponto a ponto

| ponto | 11g rev 2 | corte 12 | resultado |
|---|---|---|---|
| abertura com 6 atos e ambiente | ok | igual, texto maior | igual / melhor |
| jogada de cartas | morte +8,7 dB | morte +14,5 dB; seção −3 dB e golpes pequenos ~4 dB mais baixos em absoluto | **melhor no clímax, pior no corpo (menor)** |
| Coleção | ok | igual, nível −1,8 dB | igual (levemente mais baixa) |
| criaturas / Espantalho | ok | igual | igual |
| montagem dos salões no ritmo | forte | igual, +1,5 dB | igual / melhor |
| portão | 0,95 s, HUD 70/70, porta não se via abrir | 1,8 s, sem HUD, porta abrindo, só ambiente | **melhor** (fade curto e furo de 0,6 s à parte) |
| entrada do chefe | com música | só som próprio, 3 s | **melhor** (pedido dele) |
| clímax / golpe letal | +14,9 dB | +18,5 dB; frase final legível por 3,8 s | **melhor** |
| final Grimoire | com resto de música | sem música, quadros idênticos | **melhor** (pedido dele) |
| textos | pequenos, passavam despercebidos | maiores, faixa mais firme, mais tempo | **melhor** |

Não há regressão de **ponto**. A única regressão mensurável é de nível: o corpo da seção das cartas (16,5 a 24 s) e a Coleção ficaram 1,8 a 3 dB mais baixos, porque o mix sem `loudnorm` ganhou faixa dinâmica (LRA de 8,8 para 12,0). A satisfação da jogada no conjunto fica igual ou melhor, porque o fechamento ganhou +6 dB. Mesmo assim, é a seção que o Daniel mais valoriza.

## Variante com loja: 8,7, descartar

- **Imagem:** 3 s (29,48 a 32,48 s) da bancada da loja, com uma prateleira estática; quase nada se mexe nos 12 quadros a 4 q/s (`l_loja_4qps.jpg`). Ela entra entre o close da Coleção e o Espantalho, justamente o trecho que ele mais ama.
- **Som:** a música do Rei para (−37 dBFS de pico na stem em 29,2 s) e a da loja entra baixa (−20 a −30 dB RMS no mix), com dois furos (29,2 a 29,4 s e 32,2 a 32,3 s, a −36 a −51). Ela quebra a subida que levava ao Espantalho.
- Não acrescenta informação de venda que o filme já não tenha. **Descartar.** Se a loja voltar um dia, precisa de uma ação na tela (comprar, abrir pacote) e de uma ponte musical, não de uma pausa.

## Sugestões para uma próxima revisão (só áudio, opcionais; não seguram a entrega)

1. **Fade do portão** (44,4 a 45,63 s): fazer a música cair ao longo de 1,5 a 2 s, começando em ~43,9 s, e não em 0,4 s a partir de 44,6. Antecipar o ambiente/rangido do castelo ~0,4 s antes do corte (a partir de ~45,2 s), para não sobrar o furo de −34 a −91 dB entre 45,0 e 45,6. Meta: nenhum trecho de 100 ms abaixo de −35 dB RMS entre 44,5 e 45,8 s.
2. **Corpo das cartas** (16,5 a 24,0 s): +2 a +3 dB nos efeitos das cartas (os golpes de 19,38 / 20,68 / 21,58 / 22,48 s), para os picos voltarem a ~−10 dB, como no 11g, sem mexer na morte de 24,10. Coleção (24,5 a 29,4 s): +1,5 dB na cama. Conferir de novo o pico real ≤ −1 dBTP.

Com os dois, eu esperaria ~9,5. Sem eles o corte já está entregável.

## Itens em aberto

- Ninguém, nem eu, ouviu as mixagens. Os dois pontos que merecem ouvido antes do Daniel são o portão (45,0 a 45,8 s) e a jogada das cartas.
- SFX do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões feitos com vídeo de IA (Higgsfield): risco de gosto; declarar o uso de IA na Steam.
- "SIX BOSSES." sobre cinco salões: decisão do Daniel.

## Comandos usados

- `sha256sum` (build contra entrega).
- `ffprobe -show_entries format=duration,bit_rate:stream=...`.
- `ffmpeg -af ebur128=peak=true`.
- `ffmpeg -vf scale=96:54,format=gray -r 60 -f rawvideo` + `ana.py` (cortes, pretos, onsets da faixa do Rei).
- Alinhamento por segmento contra o 11g (offsets e diferença média).
- `env3.py` (RMS do mix em 100 ms).
- `stem.py` (pico da stem `grimoire_trailer_c12_music.f32`, estéreo 48 kHz).
- `hit3.py` (margens dos golpes).
- `seg.py` (nível por seção).
- `sheet.py` (folhas de 2 a 20 q/s e recorte da porta).
- `hp720.py` (vida nos cortes da luta).
