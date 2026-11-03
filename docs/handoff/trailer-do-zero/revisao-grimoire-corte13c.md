# Revisão independente: corte 13 rev 3 (corte13c, só mixagem)

_Revisora independente (revisora-grimoire), 03/11/2026. Não li `revisao-corte13*.md` da revisora do time. Medi direto do mp4 e da stem de música. Não ouvi a mixagem: avaliei pelo envelope RMS de 50 e 100 ms, por EBU R128 e pela margem dos golpes. Revisão anterior: `revisao-grimoire-corte13.md` (5b3e8aff), rev 2 com nota 8,9._

## Arquivo revisado

| arquivo | sha256 | observação |
|---|---|---|
| `grokbot_entrega\corte13c_720p.mp4` | `8e3e6e0c…58de47` | confere com o informado |
| `grokbot_entrega\corte13_720p.mp4` (rev 2) | `22dd06f6…d71ece` | intacto |

- Vídeo: 79,92 s, 13,6 Mb/s.
- **Imagem igual ao rev 2:** o `framemd5` do vídeo decodificado bate quadro a quadro (4795 de 4795, nenhum diferente). Não há nada visual para rever de novo. As notas de imagem da revisão do rev 2 continuam valendo.
- Provas: `revisao-grimoire-corte13c_provas\medicoes.txt`.

## Veredito

**Nota 9,2. Passa.** Fica acima de 9,0 e sem regressão perceptível contra o corte 12.

- O que me fez reprovar o rev 2 foi consertado. A luta voltou para −12,3 dB RMS (corte 12: −11,3; rev 2: −14,4) e voltou a ficar **acima** dos salões (+2,1 dB; no 12, +2,6; no rev 2, −0,7).
- O golpe letal continua sendo o som mais alto do final.
- Integrado −14,1 LUFS, LRA 11,9 (igual ao 12, que tinha 12,0), pico real −1,3 dBFS.

Não dou mais que 9,2 por três motivos:
- o resto do filme desceu ~1 dB com o ganho final (8,2 contra 9,3 no rev 2);
- o vale da saída da loja ficou como estava;
- valem as ressalvas de ritmo do rev 2: 12,6 s sem música antes da luta e vitrine parada.

## Nível por seção (dB RMS do mix)

| seção | c13c | rev 2 | corte 12 | c13c − c12 | c13c − rev 2 |
|---|---|---|---|---|---|
| abertura | −22,4 | −20,8 | −21,7 | −0,7 | −1,7 |
| cartas | −16,0 | −15,5 | −18,7 | **+2,7** | −0,4 |
| Coleção | −17,9 | −17,8 | −21,4 | **+3,5** | −0,1 |
| loja | −21,1 | −19,3 | — | — | −1,8 |
| Espantalho (alinhado pelo acento) | −18,2 | −16,9 | −17,9 | −0,3 | −1,3 |
| criaturas (34,2 a 44,3 s) | −16,3 | −15,2 | −15,4 | −0,9 | −1,1 |
| salões | −14,4 | −13,6 | −13,9 | −0,5 | −0,8 |
| aproximação + entrada | −15,7 | −14,4 | — | — | −1,3 |
| **luta** (62,8 a 69,9 s) | **−12,3** | −14,4 | −11,3 | −0,9 | **+2,1** |
| letal até o preto | −11,7 | −11,1 | −12,1 | +0,4 | −0,6 |
| logo (só sons da animação) | −22,5 | −20,6 | −21,6 | −0,9 | −1,8 |

Os offsets de alinhamento contra o 12 são os mesmos da revisão anterior. As linhas estão em `medicoes.txt`.

**Leitura da tabela:**
- A luta subiu ~3 dB e o ganho final caiu 1,1 dB para manter −14 LUFS. Por isso as seções que não foram mexidas desceram ~1 a 1,8 dB contra o rev 2.
- Contra o corte 12, que o Daniel viu, todas ficam a menos de 1 dB, exceto cartas e Coleção, que estão melhores.
- Diferença abaixo de 1 dB no mesmo material não é regressão perceptível em programa. O que importa, o **arco**, voltou ao do 12:

  | trecho | c13c | corte 12 |
  |---|---|---|
  | salões | −14,4 | −13,9 |
  | luta | −12,3 | −11,3 |
  | letal | pico −3,1 dB em 50 ms | pico −3,2 dB em 50 ms |

## Item 3: golpe letal

| medida | c13c | rev 2 | corte 12 |
|---|---|---|---|
| RMS de 50 ms no golpe (70,08 s / 59,66 s) | −3,2 | −3,0 | −3,2 |
| margem sobre o mix de 1,6 a 0,15 s antes | +14,6 | +14,2 | +13,5 |
| margem sobre o mix de 2,5 a 0,5 s antes | +12,4 | +12,7 | +13,5 |
| maior 50 ms entre 2,5 e 0,5 s antes → letal acima | +5,3 (batida em −0,83 s) | +5,0 | +4,7 |
| música isolada, 1,75 a 0,05 s antes (o vale) | −24,8 RMS | −24,5 | −22,1 |
| música isolada, 2,5 a 0,5 s antes | −15,1 RMS, pico +1,5 antes do limitador | −19,8 | −18,8, pico −0,2 |

- **O golpe é o maior impacto do trecho todo.** Os seis 50 ms mais altos de 62,0 a 73,5 s estão todos entre 69,95 e 70,30 s, ou seja, no próprio letal.
- O vale da música antes do golpe ficou: −24,8 dB, contra −22,1 no 12.
- **A "queda da janela larga" vem de comparar com a música isolada.** Uma batida forte da faixa fica entre 2,5 e 1,75 s antes do golpe. No rev 2 ela estava rebaixada junto com a luta inteira; no c13c voltou a soar como no 12 (ali o pico da música também passava do do golpe).
- No mix final, depois do limitador, o letal fica **+5,3 dB acima do 50 ms mais alto** dessa janela. É mais que no 12 (+4,7), e o 12 foi o que o Daniel aprovou para o final.
- Para o gosto dele ("final bem trabalhado com a música bem alinhada com tudo"), isso **ajuda**: a batida forte antes do vale prepara o golpe, e os cortes seguem nos onsets (imagem idêntica à do rev 2, 30 a 50 ms). Não vejo perda.

## Item 4: criaturas a −0,9 / −1,2 dB do corte 12

**Não é regressão real.** A janela 34,2 a 44,3 s mistura tomadas e posições de música diferentes das do 12 (a tomada do Espantalho é nova, o anjo é novo e o Rei voltou com recuo depois da loja). Alinhado pelo mesmo acento musical (c12 31,8 s = c13 36,3 s):

| | c13c | corte 12 |
|---|---|---|
| Espantalho | −18,2 dB | −17,9 dB (−0,3) |
| o acento em si | −12,4 dB | −11,7 dB |

A diferença restante é o ganho global de −1,1 dB, abaixo do perceptível.

## Item 5: opcionais

- **Vento no portão:** aplicado em parte.
  - No c13c o ambiente sobe a −21,5 dB em 51,2 s; no rev 2 só subia em 51,5 a 51,7 s. Entrou ~0,3 s antes.
  - O vale de 50,5 a 50,9 s ficou em −30,7 a −33,1 dB (rev 2: −29,0 a −31,5), por causa do ganho global mais baixo.
  - Não é furo. Fica um patamar de ambiente baixo de ~0,5 s.
- **Saída da loja:** não mudou. Mínimo de −30,2 dB em 33,1 a 33,2 s, ~0,3 s.

Nenhum dos dois segura a entrega.

## Notas por ponto do Daniel (mesma citação de 14:21 da revisão anterior)

| # | ponto | rev 2 | c13c | por quê |
|---|---|---|---|---|
| 1 | loja suave | 8,8 | 8,8 | imagem igual; vale da saída igual |
| 2 | Espantalho novo | 9,0 | 9,0 | igual; nível igual ao 12 no mesmo acento |
| 3 | voo do anjo | 9,2 | 9,2 | imagem igual |
| 4 | portão aos poucos, olhos | 9,3 | 9,3 | vento ~0,3 s antes; vale de ~0,5 s a −31/−33 dB |
| 5 | final bem trabalhado | 8,6 | **9,3** | luta de volta acima dos salões; letal é o pico do trecho, com margem ≥ à do 12; logo sem música |

## Sugestões (opcionais, não seguram a entrega)

1. **Opcional:** +1 dB na abertura (0 a 16,5 s) e no logo (73,4 a 79,85 s), para empatar com o 12, conferindo de novo −14 LUFS e o pico ≤ −1 dBTP.
2. **Opcional:** encher 33,0 a 33,3 s (saída da loja) e 50,5 a 50,9 s (antes do vento) com 0,3 a 0,4 s a mais de sobreposição.

## Itens em aberto

- Ninguém ouviu a mixagem. Vale ouvir de 62 a 73 s contra o corte 12 antes de mandar ao Daniel.
- ElevenLabs no plano free, salões de IA do Higgsfield, e "SIX BOSSES." sobre cinco salões: continuam como antes.
- Duração de 80 s, com o trecho mais lento de 49,5 a 62 s: risco de gosto, pedido dele.

## Comandos usados

- `sha256sum`.
- `ffmpeg -map 0:v -f framemd5` nos dois mp4 e comparação dos hashes quadro a quadro.
- `ffmpeg -af ebur128=peak=true`.
- `ffmpeg -f f32le` + `env.py` (RMS de 100 ms).
- `seg3.py` (seções contra o rev 2 e o 12, margens do letal e os 50 ms mais altos).
- Análise da stem `grimoire_trailer_c13c_music.f32` com ganho 8,2 (rev 2: 9,3; corte 12: 8,7).
