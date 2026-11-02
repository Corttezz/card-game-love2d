# Corte 10 (trailer-do-zero)

_Diretora, 02/11/2026. Base: `revisao-grimoire-corte9.md` (commit 255c8668, Tirano 8,6 e Rei 8,8, reprovado). Só montagem: nenhuma troca de faixa, texto ou salão, nada criado que não exista no jogo, **sem zoom** (escala 1,00 em todo o filme). **Sem 4K, Steam, push ou save real. Um `lovec` por vez, headless.** Os masters antigos estão intactos (`grimoire_zero_corte9_*` e anteriores não foram regravados; pastas de trabalho novas `zero10` e `zero10_rei`)._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10_720p.mp4` |
| variante (Rei) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10_rei_720p.mp4` |

Pipeline: `corte/edl10.py` (importa o `edl9.py` e aplica `_c10()`), `build_video.py`, `crt_pass.py`, `mix2.py` (o respiro do corte 9 vale para o corte 10), `mux2.py`, `med10.py`. Provas: `provas10.py` (folhas, tempos do logo, escala), `tab10.py` (cortes × onsets). A música é a mesma do corte 9 (`zero9/music_tirano.wav`, `zero9_rei/music_rei.wav`): o golpe continua em 50,36 s e nenhum trecho da faixa muda.

## Correções pedidas (`revisao-grimoire-corte9.md`)

| # | ponto | real/falso | o que foi feito | prova |
|---|---|---|---|---|
| 1 | vida 70 → 25 num corte, sem golpe (as duas) | **Real.** Na tomada `zero_carrion`, o único turno com 25/70 e a mão na tela dura ~0,3 s (35,65 a 35,95 s), então a opção (a) não existe. A vida cai de 70 para 25 na tomada de **35,233 a 35,65 s**, durante o turno, com o painel HERO piscando em vermelho (é o dano da revoada encenada, `swarm_staged`, mostrado pela animação de dano do próprio jogo). | Opção (b): plano novo `k_dreno` antes do "ENEMY TURN", com a mão, o painel e o Rei na tela inteira, **corte no onset** e tremor de 8 quadros no golpe. O plano do guerreiro perdeu o mesmo tempo pelo começo (a seleção das cartas) e mantém o fim (cartas voando e o "24"). **Tirano:** guerreiro 39,20 a 40,90 s, golpe 40,90 a 41,506 s (vida começa a cair a 40,914 s, onset de 11,5× a +0,7 quadro; 25/70 visível de ~41,3 s). **Rei:** guerreiro 39,48 a 40,72 s, golpe 40,72 a 42,00 s (vida começa a cair a 40,739 s, onset de 26,1×, desvio 0,0; o quadro com 25/70 fica segurado 34 quadros como hit-stop). Depois: 25 → 22 → 21 → 17 → 13 → 9 com os corvos, como antes. | `corte10_provas/tirano/p1_vida_hero_39.0-50.4s_10qps.png`, `corte10_provas/rei/p1_vida_hero_39.0-50.4s_10qps.png` (recorte do painel HERO, 10 quadros/s, de 39,0 a 50,4 s: a vida só cai nos quadros com o painel vermelho do golpe e dos corvos); `.../tirano/p3_golpe_vida_e_anuncio_40.60-43.60s.png`, `.../rei/p3_golpe_vida_e_anuncio_40.40-43.40s.png` |
| 2 | CTA 1,93 s (as duas) | **Real.** | Bloco do logo na posição absoluta do corte 2 (`LOGO` do `edl2.py`, sem tocar no código da animação): giro 57,77, selo 58,00, GRIMOIRE 58,60, gênero 59,40, WISHLIST 61,98 s. Os 0,58 s saíram do verso girando do coringa: **Tirano** o plano abre na face (tomada +0,583 s; face legível de 55,22 a 57,77 s, **2,55 s**); **Rei** a tomada abre +0,483 s, já na face (a 0,367 s ainda era a carta de perfil), e o quadro final segurado perdeu 3 quadros; face legível de 54,56 a 57,77 s, **3,2 s**. Revelação (`boss_reveal_sting`) no quadro da face: 55,24 s (Tirano) e 54,575 s (Rei). | Tempos medidos pelo dourado de cada linha (`p2_tempos_logo.json`): **corte 2 GRIMOIRE 58,850 / gênero 59,400 / WISHLIST 61,983 s; corte 10 Tirano 58,850 / 59,400 / 61,983; corte 10 Rei 58,850 / 59,400 / 61,983. WISHLIST na tela 2,517 s nas duas** (corte 9: 1,933 e 1,983). Máscara dourada do logo contra o corte 2 no mesmo instante (`p2_logo_mascara_dourada_vs_corte2.json`): sobreposição média **0,975** depois de 59 s (mínimo 0,943) nas duas; o corte 9 dava 0,874 (mínimo 0,0). Folhas `tirano/p2_logo_corte2_x_corte10.png`, `rei/p2_logo_corte2_x_corte10.png`. |
| 3 | sincronia da Tirano (recomendado) | **Real** (LETHAL +14 quadros, vida −7,8). | **Gancho:** os planos 0 a 8,5 s são uma tomada contínua (sem zoom, as divisões viraram invisíveis), então a tomada inteira foi atrasada 11 quadros (começa em 10,077 s, quadro 0 com a mão, o HUD e o Espantalho). O "LETHAL" aparece a **2,817 s**, na batida de 2,821 s (+0,3 quadro); o clarão do "Play Cards" foi junto (3,873 s). **Vida:** corte em **43,212 s** (onset de 8,9×, desvio 0,0); o quadro do "Murder of Crows" fica 12 quadros a mais. Também levei o espólio a 8,533 s (onset de 14,7×, 0,0) e a Revoada a 41,506 s (onset, 0,0). | `corte10_provas/onsets_tirano_corte10.md` e `onsets_rei_corte10.md`; `tirano/p4_lethal_na_batida_2.50-3.00s.png` |
| 4 | trecho sem jogo de 27,97 a 34,84 s (recomendado, "se a música deixar") | **Real**, mas **não feito**. | A música para em 30,08 s e volta em 36,97 s no ponto exato da segunda passagem da faixa. Tirar 0,5 s da porta e 0,5 s do trono exige mudar onde a faixa é cortada (e deslocar toda a segunda metade e o golpe) ou alongar o silêncio. As duas coisas mudam a música, e o pedido era só se a música deixasse. Fica como está. | |

## Itens já corrigidos no corte 9, conferidos de novo

| item | corte 10 | prova |
|---|---|---|
| sem zoom | Escala entre quadros vizinhos medida no filme inteiro (SIFT + afim parcial, quadro sim, quadro não): **nenhuma mudança acima de 3% em plano de jogo**. Os únicos avisos caem em 35,0 a 36,0 s (escuro da entrada do Rei, cinemática do jogo, poucos pontos casados), trecho **idêntico ao do corte 9 bit a bit** (diferença 0,0), em 8,53 s (o próprio corte para o espólio) e, no Rei, de 58,17 a 58,30 s (o coringa girando para virar selo, parte da animação do logo do corte 2). | `escala_filme_inteiro.txt`, `escala_tirano_final_e_escuro.txt` |
| o que não mudou | Segundos 12 a 37 e 51 a 53 (Tirano) e 0 a 37 e 48 a 53 (Rei) são **idênticos ao corte 9**: salões, letreiros, anjo a 26,552 s, portão, escuro de 1,5 s, golpe, respiro e queda em escala 1,00. Nos trechos 40 a 48 s, que não editei, a diferença é uniforme, de ~2/255 (grão do CRT refeito por bloco). | `p0_diferenca_corte9_x_corte10_por_segundo.txt` |
| "Murder of Crows" ~1,1 s | Rei: "ENEMY TURN" a 42,0 s e o nome segurado até ~43,2 s, como no corte 9. Tirano: o nome fica ~1,3 s (12 quadros a mais por causa do corte da vida na batida). | `rei/p3_golpe_vida_e_anuncio_40.40-43.40s.png`, `tirano/p3_golpe_vida_e_anuncio_40.60-43.60s.png` |
| textos | Os mesmos oito, exatos; "145 LIVING CARDS." começa junto com o espólio (8,533 s no Tirano). | |
| quadro preto | **0 quadros < 5% de luma** nas duas. | `p0_diferenca_corte9_x_corte10_por_segundo.txt` |

## Medidas finais (mp4)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,1 LUFS / −1,2 dBTP / 8,0 LU | −14,0 LUFS / −1,3 dBTP / 8,2 LU |
| margem do pico (golpe) | +2,5 dB | +3,1 dB |
| coringa: música abaixo do SFX | 5,0 dB | 5,9 dB |
| WISHLIST na tela | 2,517 s | 2,517 s |
| face do coringa legível | 2,55 s | 3,2 s |

## Para o Daniel (não mexi)
- Ordem "CHAINS. → 42 CREATURES. → FROST." (observação da revisão).
- A queda de 70 para 25 é o dano encenado da revoada na tomada, mostrado pela animação de dano do HUD do jogo, sem o golpe de um monstro na tela. Se ele preferir um golpe de monstro visível, a tomada `zero_carrion` precisa ser regravada.
- O fecho tem a animação e os tempos absolutos do corte 2; o fundo é a sala em tela inteira (tomada de 55,25 s), porque o fundo do corte 2 era um recorte com zoom.
