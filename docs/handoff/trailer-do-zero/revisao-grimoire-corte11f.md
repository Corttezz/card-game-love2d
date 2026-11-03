# Revisão independente: corte 11f (corte 11, revisão 6), versões Tirano e Rei

_Revisora independente (revisora-grimoire), 03/11/2026. Não li `revisao-corte11f.md` nem `revisao-corte11f2.md` antes de dar as notas. As afirmações da diretora (`corte11f.md` e `corte11f_provas\`) foram tratadas como alegação e medidas de novo, direto dos mp4. Não ouvi as mixagens. O áudio foi avaliado por loudness, onsets e envelope de 100 ms._

Arquivos: `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11f_720p.mp4` (Tirano, 70,3 s) e `grimoire_trailer_c11f_rei_720p.mp4` (Rei, 69,7 s), mais os masters 1080p. As cópias em `C:\Users\corte\grokbot_entrega\` são idênticas byte a byte (`cmp`). Provas em `revisao-grimoire-corte11f_provas\`; scripts fora do repo, em `%TEMP%\claude\rgc11f\`.

## Veredito

| versão | 11e (minha nota) | **11f** | passa (9,0 e claramente melhor)? |
|---|---|---|---|
| **Tirano** (principal) | 8,7 | **8,8** | **não** |
| **Rei** (alternativa) | 9,0 | **9,1** | **sim, por pouco** |

O 11f melhora o 11e no ponto que eu mais cobrava: a jogada de cartas agora derruba um inimigo de **55/55 para 7/55** e o mata no turno seguinte. Os atos também ficaram mais limpos.

Ainda há três pontos que seguram as notas:
- **Tirano, montagem dos salões:** continua sem soco. Isso não é falha de montagem. A faixa do Tirano **não tem** ataques fortes de grave: medi a faixa inteira, 81 s, e só três onsets passam de 4× de grave (7,0 s, 8,2 s e 34,5 s da faixa). Nenhum deles cai na janela usada. A nova regra de corte da diretora não tinha onde se apoiar.
- **A morte do inimigo na jogada de cartas acontece atrás das duas cartas** paradas no centro da tela. O golpe −30 e o flash aparecem; o corpo caindo fica quase todo coberto.
- **Pendências do `revisao-grimoire-corte11.md` que continuam:**
  - corvos parados por 5,4 s;
  - golpe letal do Tirano sem peso;
  - HUD "HERO 70/70" no portão.

**Recomendação:** mandar ao Daniel **a versão Rei como principal**, com a do Tirano só como alternativa ou sem enviá-la. Se ele exigir a música do Tirano, a correção é de som: um impacto grave em cada troca de salão (ver "Correções").

## Medições (as minhas)

| item | Tirano | Rei | prova |
|---|---|---|---|
| duração / vídeo | 70,3 s, 1280x720 60 fps, 13,9 Mb/s (1080p 34,2) | 69,7 s, 14,1 Mb/s (1080p 34,4) | ffprobe |
| loudness | −14,1 LUFS, pico real −1,2 dBFS, LRA 11,2 | −14,1 LUFS, −1,1 dBFS, LRA 9,2 | `ebur128=peak=true` (confere com a diretora) |
| quadro 0 / pretos | luma 8,2 (moldura da TV desligada, como v8/11e); preto só de 0,53 a 0,78 s (TV ligando) e na cauda | igual | `cortes_x_onsets_ana.txt` |
| flashes | no máximo 4 subidas > 20 de luma em 1 s, todas quadros seguidos do mesmo flash (16,4 s) | igual | abaixo de 3 flashes por segundo |
| zoom | nenhuma mudança de enquadramento nas folhas a 2 e 4 q/s; só a TV ligando e o rasante do Rei, que são do jogo | igual | `t_2qps_*.jpg`, `r_2qps_*.jpg` |
| final | 390 de 390 quadros do `logo_sting.mp4`, diferença média 1,6/255 (máx. 2,22) | igual | `logo.py` (mesmo valor do 11e e do v8) |

### Jogada de cartas nova (`cards_c11f`), 1080p a 6 q/s e 10 q/s
`t_cards_hp_6qps.jpg`, `t_kill_crop.jpg`:
- **Turno 1:** 55/55. O Volley entra na tela (o banner diz **+18**; a diretora escreveu +15). A barra vai 55 → (atrás das cartas) → 30 → 26 → 15 → 9 → **7/55**, e aparece "Enraged".
- **Corte para o turno 2:** 7/55 nos dois lados do corte. A prévia mostra "LETHAL".
- **Golpe −30** em ~24,4 s, com flash branco de tela.
- **O problema:** de 24,4 a 25,8 s as duas cartas (Executioner, Shadow Dance) ficam paradas no centro, **na frente do inimigo**. Do bruto caído só se vê a base, embaixo das cartas. Depois vem o glitch para a Coleção. A morte existe, mas quase não se lê.
- É muito melhor que o 11e (466/466 → 463), mas ainda não é o "matei" limpo que o Daniel quer sentir.

### Salões x batida (onsets da faixa de cada versão, mapa t − 12,6 + P0)
`saloes_onsets.txt`, `cortes_x_onsets_ana.txt`:

| | cortes (s) | força do onset no corte | grave no corte | posição em ±1 s |
|---|---|---|---|---|
| **11f Tirano** | 39,572 / 40,717 / 41,850 / 42,717 / 44,150, portão 45,350 | 2,3 a 3,4× | 0,1 a 2,9× (média 1,1×) | 1º, 3º, 4º, 4º, 6º; portão 11º de 12 |
| 11e Tirano | 39,851 / 40,989 / 41,848 / 42,997 / 44,14 | 2,4 a 3,4× | 0,1 a 2,2× (média 1,2×) | 1º a 5º |
| **11f Rei** | 39,398 / 40,683 / 41,617 / 43,183 / 44,450, portão 45,650 | 5,8 a 7,7× | 4,6 a 24,4× | 1º ou 2º em todos |

- O desvio constante de −46 a −65 ms é a janela do meu detector, como no 11e. **A sincronia está ok nas duas versões.**
- No Tirano, os onsets fortes entre 38 e 46,5 s ficam todos entre 2,5 e 3,6×, com grave de no máximo 2,9×. É uma faixa plana. Mudar o corte de lugar dentro dela não pode dar o "trocava de vídeo no ritmo" que o Daniel elogiou. **Na prática, o 11f Tirano é igual ao 11e nesse ponto.**
- O próprio relatório da diretora admite a mesma coisa: +4 a +11 dB no Tirano contra +30 dB no Rei.
- Nos salões, o Tirano também ficou mais curto: ~1,15 s por salão, cerca de 5,8 s de montagem. **Não foi estendida.**

### Margem dos golpes (envelope de 100 ms, mix final)
`golpes_margem.txt`:
- **Combo do turno 1 de cartas** (Tirano 21,9 a 22,4 s): pico −5,8 a −6,7 dBFS contra cama de −14 a −15. Uns +8 dB. Melhorou, mas não chega a 12.
- **Golpe que mata nas cartas** (24,4 s): a cama cai para −21 a −25 dB logo antes e o golpe sobe a −10. São +11 a +15 dB de contraste sobre o silêncio, mas só +3 dB acima da música de 1 s antes. Mesmo assim, o desenho "silêncio e golpe" funciona.
- **Golpe letal do Tirano** (60,1 s): a música cai de −6 para −18 dB, e o golpe vem a **−12 dB**, ou seja, 6 dB abaixo da música de antes. O ponto mais alto é o início do plano da morte, em 60,6 s (−9). **O golpe que mata o Rei é mais baixo que a música que o antecede.** No 11e, pela mesma medida, eram +4,4 dB. Ou seja, não melhorou.
- **Golpe letal do Rei** (59,5 s): a cama cai a −20 e o golpe vem a −7,6, uns +12 dB sobre o vale e igual à música de antes. Esse lê bem.

### Itens do `revisao-grimoire-corte11.md` (fora do escopo do 11f)

| item | estado no 11f | segura a nota abaixo de 9? |
|---|---|---|
| corvos parados ~5,4 s | **Continua.** Tirano 52,72 a 58,13 s (5,4 s), Rei 53,23 a 58,25 s (5,0 s). A mediana de movimento (0,73) é igual à da abertura calma (0,74), no clímax do filme (`t_fight_4qps.jpg`, linhas 3 e 4). | sim, é o maior trecho morto do clímax |
| porta escura 1,5 s | **Resolvido**, já no 11e: o portão vai direto ao rasante roxo (`t_45_48_8qps.jpg`). | não |
| golpe letal: hit-stop, flash, shake, duck, ≥ 12 dB | **Parcial.** Há duck antes e um quadro de flash no corte (60,12 s), mas não há hit-stop (o −31 já sobe nos quadros seguintes) e a margem no Tirano é negativa (ver acima). No Rei, ok no som. | no Tirano, sim |
| duck nos golpes do combo | **Parcial:** +8 dB no combo das cartas. | pouco |
| HUD "HERO 70/70" no portão | **Continua**, mais curto: ~0,15 s em 45,35 a 45,50 s (Tirano) (`t_gate_hud.jpg`). A luta abre com 41/70. | pouco (é pequeno e rápido) |

### Abertura dos atos
`t_2qps_1.jpg`, linhas 1 a 4:
- Seis atos de ~2,3 s andando pela estrada, na ordem: floresta, noite, inferno, gelo, pântano, crepúsculo.
- Dissolve curto: só um quadro misto por troca a 2 q/s.
- A cartela "SIX ACTS. ONE ROAD TO THE CASTLE." fica de 3,5 a 6,5 s.
- Só ambiente; a música entra em 12,6 s.
- Melhor que o 11e. Ainda é curta perto do v5 (~33 s), mas é o equilíbrio certo para 70 s.

## Pontos do Daniel (citação literal de `tdz_c11.txt`, 02/11 22:30)

| # | o que ele disse (literal) | Tirano | Rei | evidência e comparação com o 11e |
|---|---|---|---|---|
| 1 | "Esses techs que você tá colocando aí são muito ruins. Tu não colocou chains, tipo, por que correntes? Por que a gente quer enfatizar isso? Isso é algo, só um detalhe do jogo." | 8,5 | 8,5 | Igual ao 11e: SIX ACTS / BUILD A LIVING DECK / EVERY CARD COMES ALIVE / A BESTIARY OF THE CURSED / SIX BOSSES / ONE HAND CAN BREAK A KING. Nada de CHAINS/FROST. Ressalvas que continuam: a fonte e a posição são as mesmas dos cartões que ele odiou no 10d, e "SIX BOSSES." aparece sobre **cinco** salões. |
| 2 | "Não faz o menor sentido ali a entrada já ser as cartas. As entradas poderiam ser iguais a como estava em alguns teasers para trás: seis atos mostrando um pouquinho sobre cada um deles, meio que andando para frente em cada ato, com som ambiente calminho." | 9,0 | 9,0 | Melhor que o 11e (8,8): cada ato fica limpo por mais tempo (2,3 s, dissolve de 0,2 s). |
| 3a | "...ele só mostra os vídeos na hora de falar que tem vários, vários beings, vários bosses. Aí foi mostrando cada vídeo um após o outro, e isso que eles trocavam de vídeo, seguindo ali o ritmo e o tempo da música. Isso eu achei muito legal." | 8,0 | 9,3 | No Tirano, igual ao 11e: os cortes seguem a grade, mas a faixa não tem acento grave (média de 1,1× no corte). No Rei, todos os cortes caem no 1º ou 2º acento, com grave de 4,6 a 24×. Não foi estendida nas duas versões. |
| 3b | "...pelo menos você mostrou os vídeos do Riggs Field por algum motivo. Os vídeos ficaram com uma qualidade muito ruim, mas muito ruim mesmo." | 8,5 | 8,5 | São os mesmos salões nítidos do 11e (13,9 Mb/s no 720p), mas continuam sendo vídeo de IA. |
| 3c | "O ideal é que dê uma sensação de algo épico, algo legal, que o seu jogar as cartas seja algo satisfatório." | 8,6 | 9,0 | **Melhorou** (11e: 8,5 / 8,8): a barra cai 87% na tela com combo e flash, e o turno seguinte é LETHAL. Ainda pesam três coisas: a morte coberta pelas cartas (24,4 a 25,8 s), os corvos parados por 5,4 s e, no Tirano, o golpe letal mais baixo que a música. |
| 3d | "Pode mostrar o deck em determinado momento ali, a coleção, com as cartas liberadas, mostrando tudo ali descendo." | 9,0 | 9,0 | Igual ao 11e: a grade rola ~3 s e duas cartas abrem grandes. |
| 3e | "É legal a gente mostrar também as entradas de algumas criaturas. A entrada do Espantalho é bem legal, e a entrada de algumas outras é legal também." | 9,3 | 9,3 | Igual: Espantalho, Grifo, Anjo Caído e Serpe de gelo, um por acento. |
| 4 | "...a gente tinha uma finalização ali do Grimoire sendo preenchido com ícone, animações e extensões, e isso tudo se perdeu nessa sua versão. Você nem que jogou fora algo que está funcionando em cinco, seis versões anteriores." | 10 | 10 | 390 de 390 quadros, 1,6/255. |

Regras permanentes:
- Sem zoom: ok.
- Análise por quadros e medição: feita.
- Impacto só por flash e shake: ok.

## Comparação com os melhores anteriores

Base: minhas folhas e notas do 11e/11; o 10d, o v8 e o v6 foram medidos nas revisões anteriores.

| ponto | v8 | v6 | 11e | **11f** | 11f contra o melhor anterior |
|---|---|---|---|---|---|
| abertura com os 6 atos e ambiente | só o ato 1 | 6 atos + citação placeholder | 6 atos, dissolve longo | 6 atos, dissolve curto | **melhor** |
| jogada de cartas satisfatória | `deck8` (466) | mago | `deck8` (466) | 55 → 7 → morte (coberta) | **melhor** |
| coleção | não tem | maior (6 cartas + coringas/pacotes) | grade + 2 | igual ao 11e | pior que o v6 |
| entradas de criaturas / Espantalho | sem Espantalho | não tem | com Espantalho | igual | melhor |
| montagem dos chefes no ritmo | 5 salões no drop | 4 salões | Rei forte / Tirano fraco | igual ao 11e | Rei igual ou melhor; Tirano pior que o drop do v8 |
| clímax | luta para no meio | morte dessaturada | luta inteira, corvos parados | igual ao 11e | melhor em história, pior em densidade (corvos) |
| final Grimoire | referência | igual | igual | igual | igual |
| textos | rúnicos + citações | citações | 6 cartões | igual | melhor, com a ressalva do item 1 |

**Rei:** melhor que o v8 e o v6 em abertura, cartas, criaturas e clímax; igual no final e na montagem. Eu chamo isso de "claramente melhor" no conjunto. A margem é pequena, porque o que mais pesa contra (corvos, morte coberta) está justamente no "épico / satisfatório".

**Tirano:** a montagem de chefes, que é o momento que o Daniel disse que amou, segue mais fraca que a do v8 e que a da própria versão Rei. Não passa.

## Ele vai gostar? (honesto)
- **Versão Rei:** provavelmente sim. É a lista dele, na ordem dele, com o final que ele amava, e agora a carta "mata". O risco é ele notar os 5 s de corvos parados no clímax e as cartas na frente do monstro na hora da morte. São exatamente os detalhes de "satisfatório" que ele cobra.
- **Versão Tirano:** é mais provável que ele sinta que "a parte dos chefes não bate como antes". É a crítica dele ao 10d, dita ao contrário.

## Correções sugeridas (sem captura nova)
1. **Tirano, salões 39,57 a 45,35 s:** pôr um impacto grave (o `boot-impact` que já abre o 1º salão, ou um sub-boom do próprio jogo) em **cada** troca de salão, a −8 a −6 dB, com duck de −4 dB na música por 250 ms. A faixa não tem o acento, então ele tem que vir do som. A outra saída é deixar o Rei como principal.
2. **Corvos, Tirano 52,72 a 58,13 s / Rei 53,23 a 58,25 s:** acelerar 1,75 a 2× só esse trecho. Os números continuam contínuos e o filme ganha ~2,5 s.
3. **Golpe letal do Tirano (60,1 s):** o golpe precisa ficar ≥ 6 dB **acima** da música de antes (hoje está 6 dB abaixo). Subir o SFX do golpe +8 a +10 dB, ou segurar o vale e soltar o golpe mais alto. Congelar 4 a 6 quadros no −31 (hit-stop, sem zoom).
4. **Morte nas cartas (24,4 a 25,8 s):** cortar para a Coleção logo depois do flash do −30, em ~24,6 s. Ou escolher uma janela do take em que as cartas já tenham saído do centro e o bruto caído apareça. Hoje são 1,2 s de cartas paradas na frente do monstro.
5. **Portão (Tirano 45,35 a 45,50 s; Rei equivalente):** entrar no plano ~0,2 s depois, quando o HUD 70/70 já sumiu.
6. **"SIX BOSSES." sobre cinco salões:** continua pendente com o Daniel.

Com 1 a 3, eu esperaria Tirano ~9,0. Com 2 e 4, Rei ~9,3.

## Itens em aberto
- Ninguém, nem eu, ouviu as mixagens.
- SFX do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões feitos em IA (Higgsfield): o Daniel não gostou da qualidade. Rotular e declarar o uso de IA se for publicado.

## Comandos usados
- `ffprobe -show_entries format=duration,bit_rate:stream=width,height,r_frame_rate,bit_rate` e `cmp` contra as cópias entregues.
- `ffmpeg -vf scale=96:54,format=gray -f rawvideo` + `ana.py` (cortes, pretos, onsets da faixa própria, P0 = 21,0 Tirano / 36,0 Rei, M_IN = 12,6, conferido em `trailer_c11f_cut.py`).
- `onsets.py` (força, posição em ±1 s e grave 20 a 150 Hz no corte; mesmo método do 11e) e `top.py` (todos os onsets da faixa).
- `fl.py` (flashes e mediana de movimento por trecho).
- `ffmpeg -af ebur128=peak=true`.
- `hit.py` / `env.py` (envelope RMS do mix final).
- `logo.py` (390 quadros contra `brand/logo_sting.mp4`).
- Folhas a 2, 4, 6, 8 e 10 q/s; recortes 1:1 do master 1080p.
