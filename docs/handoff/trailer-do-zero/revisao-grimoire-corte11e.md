# Revisão independente: corte 11 revisão 5 ("11e"), versões Tirano e Rei

_Revisora independente (revisora-grimoire), 03/11/2026. Para não ancorar no colega, não li os `revisao-corte11*.md` antes de dar as notas. Tudo abaixo foi medido de novo, direto dos mp4 em `E:\dev\projects\card-game-trailer\build\trailer\`. O que é só leitura de quadro está marcado como tal. Não ouvi as mixagens: avaliei o áudio só por loudness e onsets._

## Veredito

| versão | nota | passa a régua (9,0 + claramente melhor)? |
|---|---|---|
| **Tirano** (principal) | **8,7** | não |
| **Rei** (alternativa) | **9,0** | por pouco; melhor que v8/v6, mas não "claramente" |

O 11e é o melhor trailer até aqui. Atende ao pé da letra os quatro pontos do Daniel e não tem defeito técnico. Na prática, porém, é uma remontagem do v5/v6/v8. O ganho real está em três coisas: a luta inteira até a morte do Rei, o Espantalho e a ordem certa dos blocos. Os três pontos que ele mais pode estranhar estão na lista de correções abaixo. **Recomendação:** mandar a versão **Rei** ao Daniel, avisando que a do Tirano corta a montagem dos chefes em acentos fracos. A outra saída é fazer uma 11f curta com os itens 1 a 3 antes de mandar.

## Medições (as minhas)

| item | Tirano | Rei | prova |
|---|---|---|---|
| duração | 69,1 s | 69,7 s | ffprobe |
| vídeo 720p | 1280x720 60 fps, 13,7 Mb/s | 1280x720 60 fps, 13,8 Mb/s | ffprobe (10d: 5,7 Mb/s) |
| master 1080p | 33,2 Mb/s | 33,2 Mb/s | ffprobe (v8: 28,9) |
| loudness integrada | −14,1 LUFS, pico −1,4 dBFS, LRA 11,3 | −14,0 LUFS, pico −1,0, LRA 9,5 | `ebur128=peak=true` |
| curva (short-term, Tirano) | 3 s −28, 9 s −22, 15 s −19, 24 s −13, 42 s −11,5, 51 s −10,9, 66 s −17 | | abre calmo e cresce |
| quadros escuros (luma < 12) | 3,87 s: TV ligando e fundo do logo | 3,87 s, igual | `l_*.gray` |
| flashes | no máximo 4 subidas > 20 de luma em 1 s, todas quadros seguidos de um mesmo flash (27,0 s e 38,7 s) | igual (26,9 s e 39,1 s) | abaixo do limite de 3 flashes por segundo |
| zoom | moldura da TV com o mesmo tamanho em todos os 70 quadros da folha | igual | `folha_*_1qps.jpg` |
| final x v8 (luma 480x270) | 0,62 / 0,36 / 0,65 / 0,04 a −6,3/−5,0/−2,0/−0,6 s do fim; 6,6 a −3,5 s | 0,88 / 0,46 / 0,66 / 0,06; 7,2 a −3,5 s | é o mesmo `logo_sting`; o 6,6 cai no meio das letras animadas e indica um desvio de alguns quadros (leitura minha, não medida) |

### Vida nos cortes da luta (1080p, 2 quadros antes x 1 depois de cada corte)
`revisao-grimoire-corte11e_provas/hp_cortes_tirano.png` e `hp_cortes_rei.png`:
- Herói: 41 → 41 nos três cortes do turno 1 e dos corvos; depois 9 → 9 no corte para o turno letal.
- Rei: 124/220 → 124/220 (Tirano 48,7 s); 30 → 30 (Tirano 51,9 s, Rei 53,2 s); 21 → 21 (Tirano 57,3 s, Rei 58,2 s).
- No corte 50,7 s (Tirano) / 51,7 s (Rei) a dezena fica coberta pela arte do Golpe do Colosso nos dois lados, e é a mesma cobertura antes e depois.
- **Nenhum número muda num corte, nas duas versões.** A morte vem do golpe letal −31 sobre 21, com prévia "21/21 LETHAL".

### Cortes x batida (onsets medidos por mim, fluxo espectral sobre o mp3 da própria faixa, mapa vídeo → faixa = t − 12,6 + P0)
`onsets_proprios_tirano.txt` e `onsets_proprios_rei.txt` (script `onsets.py`):
- Todos os cortes depois que a música entra caem num onset com o mesmo desvio de −46 ms. Esse desvio é constante e vem da janela do meu detector (1024/22050 s), não do corte. **Sincronia ok nas duas versões.**
- **A diferença está na força do acento:**
  - **Rei**, montagem dos chefes (40,7 / 41,6 / 43,2 / 44,4 / 45,7 s): onset em 1º ou 2º lugar dentro de ±1 s, grave 4,6× a 24×. O corte cai no golpe de bumbo, que é exatamente o "trocava de vídeo seguindo o ritmo" que o Daniel elogiou.
  - **Tirano**, montagem (38,7 / 39,9 / 41,0 / 41,8 / 43,0 s): onset em 1º a 6º lugar em ±1 s, grave 0,3× a 2,2×. Os cortes seguem a grade, mas em acentos médios, sem o grave. No ouvido isso deve soar "no tempo", mas não "batendo". Os números do diretor dizem o mesmo (5,8× a 9,6×, grave de +0,2 a +10,7 dB no Tirano, contra 9× a 31× e +30 dB no Rei).

## Pontos do Daniel (citação literal de `tdz_c11.txt`, 02/11 22:30)

| # | o que ele disse (literal) | Tirano | Rei | evidência |
|---|---|---|---|---|
| 1 | "Esses techs que você tá colocando aí são muito ruins. Tu não colocou chains, tipo, por que correntes? Por que a gente quer enfatizar isso? Isso é algo, só um detalhe do jogo." | 8,5 | 8,5 | CHAINS/FROST saíram. Os 6 cartões vendem o todo (atos, deck, cartas vivas, bestiário, chefes, rei), legíveis em 720p, no topo e sem tapar a ação (`folha_*`). Ressalvas: (a) tipografia e posição iguais às dos cartões que ele odiou no 10d (`folha_10d_1qps.jpg`), então a forma pode lembrar o 10d; (b) "SIX BOSSES." aparece sobre **cinco** salões **vazios** (o chefe não aparece no salão) |
| 2 | "Não faz o menor sentido ali a entrada já ser as cartas. As entradas poderiam ser iguais a como estava em alguns teasers para trás: seis atos mostrando um pouquinho sobre cada um deles, meio que andando para frente em cada ato, com som ambiente calminho." | 8,8 | 8,8 | TV liga (0 a 3 s) e seis atos de ~2 s andando pela estrada, com os postes passando (`acts_tirano.jpg`). Ambiente de −28 a −21 LUFS; a música só entra aos 12,6 s. Ressalvas: ~12 s contra ~30 s no v5, e dissolve longo entre os atos (os quadros a ±0,2 s de cada troca já têm dupla exposição, então cada ato fica "limpo" só ~1 s) |
| 3a | "...ele só mostra os vídeos na hora de falar que tem vários... bosses. Aí foi mostrando cada vídeo um após o outro, e isso que eles trocavam de vídeo, seguindo ali o ritmo e o tempo da música. Isso eu achei muito legal." | 8,0 | 9,3 | Os 5 salões Higgsfield aparecem só no "SIX BOSSES.", um por acento, com o nome embaixo. No Rei os cortes caem no grave; no Tirano, em acentos médios (tabela acima). Não foi estendida: são os mesmos 5 do v8, ~5,4 s no Tirano e ~6,6 s no Rei |
| 3b | "...os vídeos do Riggs Field... ficaram com uma qualidade muito ruim, mas muito ruim mesmo." | 8,5 | 8,5 | Salões vêm do original 4K sem tratamento de paleta, nítidos em 720p (`hall_lich_720.jpg`), iguais ao v5/v6 que ele aprovou. Continua sendo vídeo de IA: pixel "falso" e gradientes lisos se o olho parar no salão |
| 3c | "O ideal é que dê uma sensação de algo épico, algo legal, que o seu jogar as cartas seja algo satisfatório." | 8,5 | 8,8 | Clímax forte: porta, olhos, revoada, cartão "CARRION KING", turno com combo, corvos levando o herói a 9/70, LETHAL, −31 e morte em câmera lenta dessaturada. A jogada de cartas 15 a 22 s é o take `deck8` do v8: Volley +15, mas contra um inimigo de **466/466**, e os −47 mal mexem a barra (466 → 463 no quadro). Pouco "satisfatório" visualmente (`cards_climax_tirano.jpg`) |
| 3d | "Pode mostrar o deck em determinado momento ali, a coleção, com as cartas liberadas, mostrando tudo ali descendo." | 9,0 | 9,0 | Grade da Coleção rolando (23,9 a 27 s) e duas cartas abertas grandes no tempo (Blood Sword, Helm of Valor) |
| 3e | "É legal a gente mostrar também as entradas de algumas criaturas. A entrada do Espantalho é bem legal..." | 9,3 | 9,3 | Espantalho acorda (29,3 a 31,9 s), depois Grifo, Anjo Caído e Serpe de gelo, um por acento (`entr_tirano.jpg`) |
| 4 | "...a gente tinha uma finalização ali do Grimoire sendo preenchido com ícone, animações e extensões, e isso tudo se perdeu nessa sua versão." | 10 | 10 | Final idêntico ao v8 (tabela acima): selo, raios, ticks, GRIMOIRE letra a letra, WISHLIST ON STEAM |

Regras permanentes:
- Sem zoom: ok.
- Análise por quadros e medição: feita.
- O impacto vem de flash e shake, sem escala: ok. Os glitches de linha branca em ~31,8 s (Tirano) e ~29/34 s (Rei) são a transição do próprio jogo e também aparecem no v6/v8.

## Comparação com os melhores anteriores (folhas a 1 quadro/s)

| ponto | v8 (`fbad4d46`) | v6 (`701fedc1`) | 11e | 11e é |
|---|---|---|---|---|
| abertura com os 6 atos e ambiente | só ato 1 (~5 s) | 6 atos (~12 s) + citação placeholder | 6 atos (~12 s), sem citação | melhor que v8, igual/melhor que v6 |
| jogada de cartas | `deck8` | outro take (mago) | `deck8` (o mesmo do v8) | igual |
| coleção | não tem | grade + 6 cartas abertas + coringas/pacotes | grade + 2 cartas | melhor que v8, um pouco menor que v6 |
| entradas de criaturas | Grifo, Serpe (sem Espantalho) | não tem | Espantalho + 3 | melhor |
| montagem dos chefes no ritmo | 5 salões no drop | 4 salões | 5 salões (no grave forte só no Rei) | igual (Rei talvez melhor) |
| clímax | luta para no meio | luta + morte dessaturada | luta contínua, herói a 9, letal, morte | melhor |
| final do Grimoire | o de referência | igual | idêntico | igual |
| textos | rúnicos + 2 citações placeholder em tela preta | citações placeholder | 6 cartões que vendem o jogo | melhor |
| nitidez / bitrate | 28,9 Mb/s 1080p | 28,2 Mb/s 1080p | 33,2 1080p / 13,7 720p | igual/melhor |

Contra o 10d que ele rejeitou (`folha_10d_1qps.jpg`), o 11e é muito melhor em todos os pontos. Contra v6/v8 é melhor, mas a diferença está na estrutura e no clímax, não em material novo. Por isso não chamo de "claramente melhor" para a versão Tirano.

## Ele vai gostar? (honesto)
- **Provavelmente sim**, bem mais que o 10d: é o que ele pediu, na ordem que pediu, com o final que ele amava.
- **O risco** é ele achar "é o v8 de novo, mais longo". O deck contra 466 de vida, o "SIX BOSSES." sobre cinco salões vazios e os atos curtos e dissolvidos são o tipo de detalhe que ele aponta.
- **Na versão Tirano**, a montagem que ele amou perde o soco do grave.

## Correções sugeridas (para uma 11f, sem captura nova se possível)
1. **Tirano, 38,7 a 44,1 s:** escolher os cortes dos salões nos acentos com grave ≥ 10× (como no Rei), ou deslocar o trecho da faixa (P0) para a montagem cair no drop. Conferir com `onsets.py`.
2. **Atos, 3 a 15 s:** encurtar o dissolve para ≤ 0,25 s, ou cortar seco num sopro de ambiente, para cada ato ficar ~1,8 s limpo. Se couber, 2,5 s por ato (+3 s no total), mais perto do v5.
3. **Jogada de cartas, 15 a 22 s:** trocar `deck8` (inimigo 466/466) por um take em que o golpe tira um pedaço visível da barra ou mata. O próprio take do Rei tem −39/−33 sobre 220 (turno 1) e pode abrir o bloco.
4. **"SIX BOSSES." (38,7 s):** ou mostrar 6 batidas (5 salões + uma silhueta escura "?" para a rainha), ou mudar o texto para não contar ("A KING IN EVERY HALL."). Pergunta para o Daniel.
5. **Estender a montagem** (pedido do brief, não do Daniel): repetir a fila com o chefe aparecendo no salão (os `boss_cine_*` já existem) dobraria o trecho no ritmo sem IA nova. Opcional.

## Itens em aberto
- Ninguém, nem eu, ouviu as mixagens. Loudness e LRA estão ok, mas o balanço só se confirma no ouvido.
- SFX do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões são vídeo de IA (Higgsfield): rotular como cinemático se for para a Steam ou o YouTube e declarar uso de IA.

## Comandos
- `ffprobe -show_entries format=duration,bit_rate:stream=width,height,r_frame_rate,bit_rate` nos 4 arquivos do c11 + v8, v6, v5, 10d.
- `ffmpeg -vf fps=1,scale=256:-1,tile=10x8` → folhas.
- `ffmpeg -af ebur128=peak=true` e `ebur128=metadata=1` (curva short-term).
- `ffmpeg -vf scale=64:36,format=gray` → luma por quadro (escuros e flashes).
- `ffmpeg -sseof` → comparação do final com o v8.
- `python -I onsets.py <mp3> <P0> "<cortes>"` (Tirano P0 = 21,0; Rei P0 = 36,0).
- `python -I hp.py <master 1080p> <saida> "<cortes>"`.
- Scratch: `C:\Users\corte\AppData\Local\Temp\claude\rgc11e\`.
