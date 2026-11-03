# Revisão independente: corte 13 rev 2

_Revisora independente (revisora-grimoire), 03/11/2026. Não li `revisao-corte13.md` nem `revisao-corte13b.md`. Medi tudo de novo direto do mp4, com quadros extraídos agora. Não ouvi a mixagem: o som foi avaliado pelo envelope RMS de 100 ms, pela stem de música, por loudness EBU R128 e pela margem dos golpes._

## Arquivo revisado

| arquivo | sha256 | observação |
|---|---|---|
| `grokbot_entrega\corte13_720p.mp4` | `22dd06f6…d71ece` | idêntico ao build `grimoire_trailer_c13_720p.mp4` |

- Vídeo: 79,98 s, 1280x720 a 60 q/s, 13,6 Mb/s.
- Referências: `corte12_720p.mp4` (principal, 69,6 s) e `corte12_loja_720p.mp4` (72,6 s).
- Provas em `revisao-grimoire-corte13_provas\`: folhas de quadros e `medicoes.txt`, com todas as saídas numéricas.
- Scripts fora do repo, em `%TEMP%\claude\rgc13\`.

## Veredito

**Nota 8,9. Não passa.** A nota fica abaixo de 9,0 e há uma regressão mensurável contra o corte 12.

Os quatro pedidos de imagem foram bem atendidos:
- loja com dissolve;
- Espantalho novo;
- anjo batendo asas de verdade;
- portão em sequência longa com olhos no escuro.

O que segura a nota é o fim, justamente o ponto 5 do Daniel. Contra o corte 12 que ele viu, **a luta final ficou 3,0 dB mais baixa**:
- mix de 62,8 a 69,9 s: −14,4 dB RMS (no 12, −11,3);
- a música da luta caiu ~3,5 dB (stem com ganho: −13,6 contra −10,1).

Com isso, o clímax agora fica **abaixo** da montagem dos salões (−13,6 dB), quando no corte 12 ficava 2,6 dB acima. Ao mesmo tempo, cartas e Coleção subiram 3,2 a 3,6 dB. O arco de energia achatou: o filme fica alto no meio e mais manso na luta que fecha. O conserto é só de mix (abaixo). Com ele, eu esperaria ~9,3.

## Pontos do Daniel (citação literal de `tdz_c13.txt`, 03/11 14:21)

Fala completa: _"na hora que muda para o mercado tem uma mudança muito abrupta de tela de musica etc, tem q ser algo mais suave, a gravaçaõ de entrada do espantalho tente gerar outra, esse outro ai que vou enviar  enquanto ele ta voando ele fica muito durão nao mexe tanto no ar podemos melhorar a animação dele com o pixel lab, na hora que troca para o a porta do boss, teve uma mudança abrupta também, poderia as poucos a musica ir abaixando ai muda pro cenario aparece o som ambiente ai vai mostrando uma cena aproximando da porta ela abrindo etc algo mais suave ai mostra a cena de entrada desde o começo do primeiro boss, dos olhos dele etc, ai começa tudo da forma que esta mas deixe esse final bem trabalahdo com a musica bem ainhada com tudo"_

### 1. Loja: 8,8

Pedido: _"na hora que muda para o mercado tem uma mudança muito abrupta de tela de musica etc, tem q ser algo mais suave"_

- **Entrada:** dissolve real da Coleção para a estrada da loja, de 29,50 a 29,80 s (`s_loja_in.png`).
- **Música na entrada:** sem buraco e sem salto.
  - O RMS de 100 ms fica entre −26,6 e −11,8 dB de 28,4 a 31,4 s.
  - A maior subida é de +8,5 dB em 100 ms, no sino em 31,0 a 31,1 s. Sem o sino, +5,5 dB em 50 ms.
- **Passagem para o interior** (30,80 a 31,10 s, `s_loja_passagem_20qps.png`): é a transição do próprio jogo. A bancada desce de cima em ~0,3 s, com o balcão inclinado, sobre a estrada. É o momento mais seco da loja, mas é movimento e não corte. Aceitável, porque é verdade de gameplay.
- **Saída:** dissolve de 33,45 a 33,75 s para o Espantalho (`s_loja_out.png`).
  - No som, há um vale curto de 33,0 a 33,3 s (−30,0 / −31,7 / −28,2 dB), ~0,3 s.
  - Não é furo mudo, mas é o ponto mais vazio da passagem.
- **Ressalva de conteúdo:** de 31,4 a 33,4 s a vitrine fica parada, sem compra e sem pacote. Os objetos só aparecem. Lê como "existe uma loja", não como "eu compro aqui".

### 2. Espantalho: 9,0

Pedido: _"a gravaçaõ de entrada do espantalho tente gerar outra"_

- Tomada nova de 33,75 a 36,10 s (`s_espantalho.png`).
- O espantalho de madeira fica no primeiro plano à esquerda. A criatura vem da direita e anda até o centro da estrada.
- O texto "A BESTIARY OF THE CURSED." entra limpo.
- A tomada é estável e legível. Não é espetacular (a criatura ocupa ~100 px de altura no 720p), mas cumpre.

### 3. Anjo: 9,2

Pedido: _"enquanto ele ta voando ele fica muito durão nao mexe tanto no ar podemos melhorar a animação dele com o pixel lab"_

- **Voo** de 38,7 a ~40,7 s (`c_anjo13_15qps.png`, recorte 1:1 a 15 q/s):
  - entra pelo alto à esquerda e desce em diagonal até o pouso;
  - as asas abrem e fecham em ciclos visíveis: abertas em 39,27 a 39,40, recolhidas em 39,47, abertas de novo em 39,93 a 40,07, e assim até o pouso;
  - o halo e o manto acompanham.
- **Corte 12** (`s_anjo12.png`, 37,5 a 38,5 s): o anjo já aparecia quase pousado, com as asas abertas e paradas.
- A melhora é clara e responde exatamente ao "mexe pouco no ar".
- **Ressalva:** a cena é escura e avermelhada, e o anjo fica médio-pequeno na tela. O bater de asas se vê bem no recorte, menos no quadro inteiro.

### 4. Portão: 9,3

Pedido: _"poderia as poucos a musica ir abaixando ai muda pro cenario aparece o som ambiente ai vai mostrando uma cena aproximando da porta ela abrindo etc algo mais suave ai mostra a cena de entrada desde o começo do primeiro boss, dos olhos dele etc"_

**Música abaixando.** A stem sai de −13,8 dB (48,9 s) e desce aos poucos: −26 (49,3), −36 (49,5), −46 (50,5), −63 (50,7), −96 (51,4). São ~2,3 s de queda que se leem como fade, não como corte. No corte 12 eram ~0,5 s.

**Sem buraco.** O mix fica entre −33,6 e −13 dB RMS de 49,5 a 54,6 s. Isso cumpre a meta que eu mesma propus no 12 (nada abaixo de −35 dB). O vale citado pela revisora do time (50,5 a 51,4 s) existe na minha medida como um patamar de −28 a −31,5 dB: ambiente baixo, mas não mudo. Antecipar o vento em 0,5 s é opcional.

**Aproximação** (50,45 a 54,5 s, `s_portao_4qps.png`, `c_porta_5qps.png`):
- a estrada e os postes passam;
- a bandeira vermelha fica no caminho;
- o castelo fica fixo no centro;
- **a porta abre na tela** de 52,8 a 53,4 s (as duas folhas se afastam), com som próprio de −20 a −15 dB.

**Entrada desde o começo** (`s_entrada_3qps.png`):
- salão escuro em 54,6 s;
- **olhos acendem em ~55,07 s** e ficam até 57,4 s, com névoa roxa;
- rasante em 57,7 a 58,4 s;
- pouso em 59,0 s;
- cartão "CARRION KING / Sovereign of Crows" de 60,07 a 62,0 s.
- Música da stem abaixo de −94 dBFS (pico) de 51,5 a 62,0 s.

**Volta da luta.** O som próprio decai até −55 dB em 62,0 s e a música entra seca em 62,1 s (−18 → −9,8 dB), em cima de um onset forte da faixa (24,7 dB/10 ms, 40 ms antes do corte). Funciona como respiro antes do golpe.

**Custo de ritmo:** do fim da música (49,5 s) até a luta (62,1 s) são ~12,6 s sem música, e só a entrada do chefe dura 7,5 s (era 3,0). É o que ele pediu, mas é o trecho de maior risco de atenção do filme. Os olhos parados por 2,3 s (55,1 a 57,4 s) são o candidato natural a encurtar, se ele achar longo.

### 5. Final: 8,6

Pedido: _"ai começa tudo da forma que esta mas deixe esse final bem trabalahdo com a musica bem ainhada com tudo"_

**O que está certo:**
- Cortes da luta nos onsets da faixa (30 a 50 ms antes do corte, 2 a 3 quadros), como no 12.
- Mesma luta do 12 (diferença média 0,5 a 1,8/255 com offset constante).
- Vida contínua; "ONE HAND CAN BREAK A KING." legível de 66,4 a 69,2 s (`s_luta_final.png`).
- Golpe letal com pico em 70,08 s, +14,2 / +12,7 dB sobre o mix antes (12: +13,5 / +13,5).
- Morte do chefe em tons frios até 72,8 s.
- TV desligando com estática de 73,07 a 73,33 s, junto com o impacto (mix −7,8 dB em 73,1) e a música zerando em 73,2 (`s_preto_15qps.png`).
- Logo de 73,4 a 79,85 s idêntico ao do 12 (diferença 0,00), stem em silêncio digital a partir de 76,2 s e abaixo de −98 dBFS desde 73,4 s. Só os sons da animação.

**O que regrediu:** o nível da luta (62,8 a 69,9 s).

| seção | c13 | c12 | diferença |
|---|---|---|---|
| abertura | −20,8 | −21,7 | +0,9 |
| cartas | −15,5 | −18,7 | +3,2 |
| Coleção | −17,8 | −21,4 | +3,6 |
| criaturas | −15,2 | −15,4 | +0,3 |
| salões | −13,6 | −13,9 | +0,3 |
| **luta** | **−14,4** | **−11,3** | **−3,0** |
| letal até o preto | −11,1 | −12,1 | +1,0 |
| logo | −20,6 | −21,6 | +1,0 |

(dB RMS do mix na seção, os dois em ~−14 LUFS; offsets de alinhamento em `medicoes.txt`)

A causa está na música: a stem da luta, com o ganho final, fica em −13,6 no 13 contra −10,1 no 12. O "final bem trabalhado" ficou mais fraco que o que ele viu. Em 12,6 s sem música antes dele, a volta ainda pega (−55 → −10 dB), mas depois a luta inteira soa abaixo dos salões.

## Critérios gerais

| critério | resultado | prova |
|---|---|---|
| loudness | −14,0 LUFS, LRA 7,9 (12: 12,0), pico real −1,2 dBFS | `medicoes.txt` |
| sem zoom | nenhuma mudança de enquadramento de corte nas folhas. Escala muda só na cinemática do jogo (rasante 57,7 a 58,4 s) e no glitch. | folhas |
| impacto | hit-stop, flash, shake e estática de TV; nada de zoom | `s_luta_final.png`, `s_preto_15qps.png` |
| jogada das cartas | golpes de 19,38 a 22,72 s com pico de −1,8 a −2,9 dB (12: −6 a −7) e RMS de 50 ms ~4 dB mais alto; margem relativa igual (+2,5 a +4,9). Morte em 24,25 s com +10,9 / +11,2 dB (12: +11,6 / +12,2). | `medicoes.txt` (golpes) |
| abertura, cartas, Coleção | imagem idêntica ao 12 (diferença 0,15 a 0,30/255, offset 0) | `medicoes.txt` (alinhamento) |
| final Grimoire | idêntico ao 12 (0,00/255), sem música | idem |
| textos | os mesmos do 12 (já aprovados por tamanho e firmeza) | folhas |
| duração | 80,0 s (12: 69,6). +4 s de loja, +4,4 s de aproximação, +4,5 s de entrada. | |

## Comparação com o corte 12, seção a seção

| seção | corte 12 | corte 13 | resultado |
|---|---|---|---|
| abertura 6 atos | ok | idêntica, +0,9 dB | igual |
| cartas | corpo baixo | +3,2 dB, golpes mais presentes | **melhor** |
| Coleção | baixa | +3,6 dB | **melhor** |
| loja | não tinha (variante 8,7) | dissolves, sem buraco, vitrine parada | nova, aceitável |
| Espantalho | ok | tomada nova, limpa | igual / melhor |
| anjo | asas paradas, quase pousado | voo com ciclos de asa | **melhor** |
| salões no ritmo | forte | cortes nos onsets da faixa (30 a 50 ms antes), +0,3 dB | igual |
| portão | fade de 0,5 s, furo de 0,6 s | fade de 2,3 s, sem furo, porta abrindo | **melhor** |
| entrada do chefe | 3 s, já com aparição | 7,5 s, desde os olhos | **melhor** (pedido), mais lento |
| **luta** | **−11,3 dB** | **−14,4 dB, abaixo dos salões** | **pior** |
| golpe letal e preto | bom | TV desligando no impacto | igual / melhor |
| logo | sem música | idêntico | igual |

## Sugestões, com tempos

1. **Obrigatório: devolver a energia da luta.** De 62,10 a 69,90 s, subir a música da luta em +3 dB, para a stem voltar ao nível do 12. Meta: mix da luta ≥ −12 dB RMS e pelo menos +1,5 dB acima dos salões (44,5 a 48,8 s).
   - Para não perder a margem do letal, manter (ou criar) um recuo da música de ~0,4 s antes de 70,08 s.
   - Depois, refazer o ganho final e conferir o pico real ≤ −1 dBTP e a margem do letal ≥ +12 dB.
   - A imagem não muda.
2. **Opcional:** encher o vale da saída da loja (33,0 a 33,3 s, −30 a −32 dB) com 0,3 s a mais de sobreposição da música do Rei ou da cauda do sino.
3. **Opcional:** antecipar o vento em ~0,5 s (50,4 a 51,4 s fica em −28 a −31 dB).
4. **Opcional, só se o Daniel achar longo:** encurtar ~1 s dos olhos parados (55,1 a 57,4 s), que é o trecho mais estático dos 80 s.

## Itens em aberto

- Ninguém, nem eu, ouviu a mixagem. O ponto que mais merece ouvido é a volta da luta (62,1 a 70 s), comparada com o corte 12.
- SFX e música do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões feitos com vídeo de IA (Higgsfield): risco de gosto (ele achou a qualidade ruim); declarar o uso de IA na Steam.
- "SIX BOSSES." sobre cinco salões: decisão do Daniel.

## Comandos usados

- `sha256sum` (entrega contra build).
- `ffprobe` (duração, taxa, streams).
- `ffmpeg -af ebur128=peak=true`.
- `ffmpeg -vf scale=96:54,format=gray -r 60 -f rawvideo` + `ana.py` (cortes e pretos) e `align.py` (alinhamento por seção contra o 12 e o 12 com loja).
- `ffmpeg -f f32le` + `env.py` (RMS e pico em 50/100 ms do mix e da stem `grimoire_trailer_c13_music.f32`).
- `hit.py` (margem dos golpes).
- `seg.py` (nível por seção).
- `sheet.py` e `crop.py` (folhas de 2,5 a 20 q/s e recortes 1:1 do anjo e da porta).
