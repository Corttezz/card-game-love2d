# Revisão independente do corte 11 (revisora-grimoire)

_03/11/2026. Revisora independente, só leitura. Medi tudo por quadros (ffmpeg) e por números. As revisões do time (`revisao-corte11*.md`) **não foram lidas** antes desta nota. As afirmações da diretora (`corte11.md`, `corte11_inventario.md`, `corte11_provas\`) foram tratadas como alegação e conferidas de novo._

Arquivos revisados (`E:\dev\projects\card-game-trailer\build\trailer\`): `grimoire_trailer_c11_720p.mp4` (Tirano, 69,1 s), `grimoire_trailer_c11_rei_720p.mp4` (Rei, 69,7 s) e os masters 1080p. Referências: v5, v6, v8 master, kinetic B (`grimoire_kinetic_new_som_720p.mp4`), 10d 720p (rejeitado) e `brand\logo_sting.mp4`.

Provas: `revisao-grimoire-corte11_provas\`. Scripts e dados brutos ficam fora do repo, em `%TEMP%\claude\rgc11\` (`ana.py`, `logo.py`).

## Veredito

| versão | nota | passa na barra de 9,0? |
|---|---|---|
| Tirano (principal) | **8,6** | não |
| Rei-Carniça (alternativa) | **8,8** | não |

O corte 11 é **muito melhor que o 10d** e cumpre, um por um, os pedidos explícitos do Daniel. Tecnicamente é limpo: o fecho é idêntico ao v8, a vida é contínua dentro da luta e a imagem é 8 vezes mais nítida que a do 10d.

Ainda não é "claramente melhor que os melhores cortes antigos" no que o Daniel mais cobrou: sensação épica e jogada de carta satisfatória. O clímax dura 18 s e tem dois trechos parados:
- a porta escura, 1,5 s;
- os corvos, 5,4 s no mesmo enquadramento, com só o número do herói caindo no canto.

O golpe letal também tem pouco peso: não há quadro de impacto, e o som do golpe sobe 9 a 10 dB acima da cama (Tirano) ou ~7 dB (Rei). No v8 esse pico era de 12 a 16 dB. Os ajustes que faltam são de montagem e mixagem, sem regravar (lista no fim).

## 1. Os pontos do Daniel (02/11, 22:30), nota por versão

| # | o que ele disse | Tirano | Rei | evidência |
|---|---|---|---|---|
| 1 | Textos ruins, "por que correntes?" | 9,0 | 9,0 | Não há CHAINS nem FROST. São sete cartelas curtas, que vendem o jogo, grandes e legíveis em 720p (`x_t_31.75.jpg`: "A BESTIARY OF THE CURSED." ocupa ~83% da largura). A entrada em glitch embaralha o texto por 1 a 2 quadros (24,25 s; 41,75 s), mas é intencional e curta. |
| 2 | A abertura não pode ser cartas; seis atos andando para frente, som ambiente calmo | 9,0 | 9,0 | 0 a 1,1 s TV ligando, depois 3 a 15 s com os 6 atos na ordem real do jogo (floresta, floresta noturna, inferno, gelo, pântano, crepúsculo; confere com `Enemies.HOME_BIOME`), câmera andando (o poste passa). Só ambiente: RMS −32 a −24 dB nos 3 a 12 s, contra −13 a −15 no clímax. A música entra em 12,6 s. `folha_t_0s_4qps.jpg`. |
| 2b | Vídeos do "Riggs Field" (Higgsfield) com qualidade muito ruim | 9,0 | 9,0 | Nitidez (variância do Laplaciano, mesmo recorte do salão do Rei, 1280x720): **c11 918 / 876**, contra **10d 117**. O 720p perde pouco do master (PSNR 44,7 dB, nitidez 918 contra 931). Bitrate de 13,7 / 13,8 Mb/s, contra 5,7 do 10d. `nitidez_salao_10d_x_c11.jpg`. |
| 3 | Montagem dos chefes trocando no ritmo da música | 8,0 | 9,0 | Os 5 salões cortam no onset com ±2,4 q, que é a latência fixa do meu detector (`cortes_x_onsets_medido.txt`). **Mas no Tirano os acentos são fracos:** 4,3 a 6,2× o fluxo mediano e grave de +0 a +4 dB (o primeiro salão, em 38,71 s, cai num onset de 4,3× com grave de +0,5 dB). No Rei os acentos são fortes: 12 a 15× e grave de +16 a +46 dB. No Rei a troca "bate"; no Tirano ela só acompanha. |
| 4 | Sensação épica, jogar cartas satisfatório | 7,5 | 7,5 | Há o combo Volley +15 (15 a 24 s) e o golpe letal real de 21/21 (`golpe_letal_tirano_58-60s.jpg`). Por outro lado: as cartas aparecem pequenas (regra sem zoom, HUD 1:1); o golpe letal não tem hit-stop nem flash; o King só fica cinza no corte seguinte; o pico do golpe sobre a cama é de 9 a 10 dB (Tirano) ou 6,7 dB (Rei), contra 12 a 16 dB no v8. O clímax tem a porta escura (Tirano 47,0 a 48,5 s; Rei 48,5 a 50,0 s, energia de movimento < 0,25) e os corvos (Tirano 51,9 a 57,3 s, mesmo enquadramento). Ver `folha_t_50s_4qps.jpg`. |
| 5 | Mostrar deck/coleção com cartas liberadas descendo | 8,5 | 8,5 | A grade da Coleção rola por ~3 s com "EVERY CARD COMES ALIVE.", depois duas cartas abrem grandes (Blood Sword, Helm of Valor). Cumpre o pedido. A rolagem é curta e sem um acento visual que mostre "muitas cartas". |
| 6 | Entradas de criaturas, Espantalho | 9,0 | 9,0 | Espantalho acorda e anda (29,3 a 31,9 s, `x_t_31.75.jpg`), depois grifo, anjo caído e serpe de gelo, cada uma num corte. |
| 7 | O fecho do Grimoire com ícones e animações | 10 | 10 | Medi os 390 quadros contra `logo_sting.mp4`: diferença média **1,60/255** (máximo 1,6 / 2,22) nas duas versões. O v8 dá 1,58 na mesma medida, ou seja, é igual. Todos os 390 quadros estão lá. |

## 2. Critérios de sempre

| critério | Tirano | Rei | número / prova |
|---|---|---|---|
| Quadro 0 não preto | ok | ok | Luma 8,7 no quadro 0: é a moldura da TV, desligada de propósito, igual ao v8 (8,7). O preto de verdade é só 0,53 a 0,70 s, no clarão da TV ligando. |
| Pretos não intencionais | ok | ok | Fora isso, só o fundo do logo e a cauda de 0,1 s. |
| Sem zoom | ok | ok | Na folha a cada 0,25 s não há crescimento de enquadramento. Os únicos movimentos de escala são a TV ligando e o rasante do King, que são do jogo. Confere com a medida da diretora. |
| Continuidade de vida na luta | 9 | 9 | `vida_*_10qps.jpg`, 10 quadros/s, 1:1. O King vai 124 → 85 → 77 → 49 → 37 → 33 → 31 → 30, depois queimadura 30 → 25 → 22 → 21, depois −21. O herói vai 41 → 9 nos corvos. Nenhum número muda num corte. **Ressalva:** na tomada do portão (Tirano 44,2 a 44,4 s; Rei 45,9 a 46,0 s) o HUD mostra **HERO 70/70**, e 3 s depois a luta abre com 41/70. Fica ~0,3 s na tela, pequeno, mas é uma quebra de continuidade fora dos cortes da luta. |
| Loudness | ok | ok | Tirano −14,1 LUFS, pico −1,4 dB, LRA 11,3. Rei −14,0 LUFS, pico −1,0 dB, LRA 9,5 (ebur128). Conferem com a alegação. A dinâmica é melhor que a do v8 (LRA 6,5) e a do v6 (5,0). |
| Margem dos golpes | 7,5 | 7 | Picos acima da cama de 1,5 s: Tirano 9,3 / 9,8 / 10,3 dB no turno 1 e no letal; Rei 4 a 10 dB, com o letal em ~6,7 dB. v8: 11,8 a 16,2 dB. |
| Ritmo / prende atenção | 8,5 | 8,5 | 29 cortes/min (v8 31, v6 29, 10d 21). A mediana de movimento é 1,06 (v8 0,74, 10d 0,82), então o filme é mais vivo que o v8. As quedas estão todas no clímax (ver o item 4 da tabela 1). |
| Textos | 9 | 9 | Ver o item 1 da tabela 1. |
| Verdade do material | ok | ok | Gameplay capturado no motor, com HUD. Os salões são IA e só aparecem como "mood" com nome. A luta começa preparada (King 124/220, herói 41/70); está declarado. |

## 3. Comparação com os cortes antigos

| referência | onde o c11 é melhor | onde o c11 é pior |
|---|---|---|
| **10d** (rejeitado) | Em quase tudo: nitidez 8×, bitrate 2,4×, fecho certo, abertura nos atos, sem CHAINS/FROST, salões originais. | Nada relevante. |
| **v8** (melhor anterior) | Abertura dos atos 10 s com ambiente (no v8 eram ~4 s). Coleção. Espantalho. Luta que termina com o King morrendo de verdade. Sem as falsas citações ("Two cards, one road..."). Mais dinâmica (LRA 11 contra 6,5). Mesma qualidade de imagem: 13,7 Mb/s no 720p a partir de um master de 33 Mb/s. | Luta mais longa e menos densa: 18 s contra ~10 s, com 7 s de trechos parados. Golpes 3 a 6 dB mais baixos sobre a música. No v8 o clímax é mais "porrada". |
| **v6** | O mesmo que no v8, mais a luta com o King. A entrada das criaturas é mais forte. | O v6 mostrava coringas, relíquias e pacotes ("JOKERS. RELICS. PACKS."), e isso sumiu. A coleção do v6 era mais longa (6 cartas abertas contra 2). |
| **v5** | Mais curto e mais focado (69 s contra 114 s), mesmo conceito de abertura e de salões no ritmo. | A abertura do v5 era mais contemplativa (~33 s). O c11 acerta em encurtar. |
| **kinetic B** | Mais imagem do jogo e menos tipografia. Fiel ao gosto do Daniel ("mostrar o jogo"). | O kinetic tinha mais energia por segundo (49 cortes/min). Não é a direção pedida. |

Resumo: o c11 é a melhor **estrutura** até agora (é a lista do Daniel, na ordem dele), com a qualidade técnica do v8. Ainda **não é claramente melhor que o v8 no impacto do clímax**, que é justamente o "épico / satisfatório" que ele pediu.

## 4. O que segura a aprovação (edições sem regravar)

1. **Corvos mais rápidos.** Tirano 51,86 a 57,29 s; Rei 53,21 a 58,23 s. Acelerar 2× (ou 1,75×) só esse trecho mantém todos os números contínuos e corta ~2,5 s de quadro parado. Alternativa: começar o trecho no 3º mergulho, mas isso faz o número do herói pular num corte, então não serve.
2. **Porta escura mais curta.** Tirano 47,0 a 48,5 s; Rei 48,5 a 50,0 s. Deixar ~0,6 s de olhos no escuro, cortando no onset seguinte.
3. **Quadro de impacto no golpe letal.** Tirano ~59,0 s; Rei ~59,5 s, no quadro do −21. Hit-stop de 4 a 6 quadros (congelar, não zoom), flash branco de 1 a 2 quadros e tremor de 4 a 6 px. Também: som do golpe +3 a 4 dB e música com duck de −5 dB por 300 ms. Meta: o golpe letal pelo menos 12 dB acima da cama, como no v8.
4. **Golpes do turno 1 e do combo** (15 a 24 s; 45,3 a 51,9 s): o mesmo duck curto, para chegar a ≥ 12 dB de margem.
5. **Salões no Tirano:** os acentos da faixa são fracos. Ou deslocar a janela da música (`P0`) para um trecho com grave forte sob os 5 salões, ou aceitar e preferir a versão do Rei como principal.
6. **HUD 70/70 no portão.** Tirano 44,14 a 44,45 s; Rei 45,68 a 46,0 s. Entrar na tomada ~0,35 s depois, quando o HUD já sumiu, ou cobrir com o glitch de transição.

Com 1 a 4 feitos, eu esperaria Rei ≥ 9,2 e Tirano ~9,0 (o Tirano depende do item 5).

## 5. Opinião sobre o que está em aberto com o Daniel (não decido)

- **Textos:** aprovaria todos. "ONE HAND CAN BREAK A KING." é o mais forte. "SIX BOSSES." sobre cinco salões: eu trocaria por "SIX BOSSES. ONE STAYS HIDDEN." ou manteria e deixaria a curiosidade. Do jeito que está, quem conta os salões pode achar erro.
- **Luta começando no meio:** aceitável, porque o filme não tem tempo para uma luta inteira. A continuidade de vida está certa, fora o 70/70 do portão.
- **Versão principal:** recomendo trocar para o **Rei**. A música é do próprio chefe da luta, e os salões batem em acentos fortes.
- **SFX do ElevenLabs (plano free):** continua bloqueando a publicação.

## Comandos usados (resumo)
- `ffprobe` (resolução/bitrate); `ffmpeg ... ebur128=peak=true` (loudness).
- `ffmpeg -vf scale=96:54,format=gray -f rawvideo` + `ana.py` (cortes, pretos, movimento, onsets por fluxo espectral da faixa própria de cada versão, com offset `t − 12,6 + P0`).
- Folhas a 4 q/s (`tile=8x5`); painéis de vida a 10 q/s, recorte 1:1 do master 1080p.
- `logo.py`: os 390 quadros do logo contra `logo_sting.mp4`, com busca de offset.
- Nitidez: variância do Laplaciano (OpenCV) no mesmo recorte, 1280x720.
