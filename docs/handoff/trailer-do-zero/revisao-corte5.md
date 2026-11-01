# Revisão: corte 5 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte5.md` (conferência quadro a quadro dos 6 pontos, aprovada pelo Grimoire), `revisao-grimoire-corte4.md` (6 pontos), o ajuste do Grimoire de 18:57 (queda do Rei legível, ≤ ~2,5 s, degraus inteiros, nota própria Q) e tudo o que já valia (14 critérios, 7 pontos do corte 1, 5 do corte 2, 7 correções do corte 4). Arquivos: `grimoire_zero_corte5_1080p.mp4` (19:03) e `_720p.mp4` (19:04). Método: medidas quadro a quadro (`...\scratchpad\rev\h5_1080\`), quadros cheios da virada, do LETHAL e do espólio, folha a 5 quadros/s do portão (`...\rev\g5\`), tamanho de pixel medido por corrida de cor na montagem sem CRT (`pixel.py` em `build\trailer\zero5\zero_semcrt.mp4`), mixagem nos stems `build\trailer\zero5\zero5_tirano\` (`mix5_tirano.json`). Não ouvi._

**Por ordem do Grimoire, esta rodada avalia tudo menos a queda do Rei**, que está sendo refeita. A nota Q e a variante do Rei entram em seções próprias.

## Versão Tirano, rodada 1 (sem a queda): NÃO APROVADO, falta 1 item

### Conferência dos 6 pontos do Grimoire (refeita por mim no corte 5)

| # | ponto | veredito no corte 5 | prova minha |
|---|---|---|---|
| 1 | zero quadro preto | **resolvido** | 0 quadros abaixo de 5% de luma no filme inteiro |
| 2 | o portão abre de verdade, com som | **resolvido** | folha a 5 quadros/s (`g5/portao.png`): porta fechada → folhas girando → entrada escura, a ×2, num plano só (29,95–32,55 s); SFX do trecho a −19,5 dBFS, sobre a música a −20 |
| 3 | pixel dos salões = sprites/fundo | **resolvido** | corrida de cor modal: salão do Tirano **5 px**, salão de gelo **5 px**, trono do Rei **5 px**; fundo do salão real do Rei **5 px**. No corte 4 eram 4 contra 5. Concordo com a diretora que o sprite do Rei (2 a 3 px) não é a referência certa; o fundo é |
| 4 | vida 25/21/17/13/9 legível, olhar contínuo | **olhar resolvido, leitura não** (abaixo) | a virada inteira num enquadramento ×1 só: o olho não atravessa a tela por corte |
| 5 | espólio ≥ +1 s | **resolvido** | 3,09 s (8,60–11,69 s), Poison Dart e Rain of Blades inteiras, "145 LIVING CARDS." numa linha livre acima de AFFINITY / RARE FIND |
| 6 | queda entre o 48 e o corpo | **conferido por mim no corte 4** | a diretora tem razão: o Rei aparece de pé, ajoelhando e caindo por ~1,8 s entre 53,6 e 55,4 s, com a câmera acompanhando. Como o Grimoire mandou deixar a queda **mais legível** (ajuste das 18:57), ela será refeita e avaliada na nota Q |

### O que ainda segura: a virada a ×1 deixou o LETHAL e a vida pequenos (N1 / N4 / C4)
A solução "tudo no mesmo enquadramento" acabou com o pulo do olho, mas fez isso recuando para o **×1 da tela inteira dentro da moldura do CRT**, o mesmo problema que o Grimoire apontou no corte 2 (N4: "a moldura deixa a UI pequena onde a carta importa; zoom no miolo"). No quadro a 1080p (`g5/f_47.6.png`, `g5/lb.png`):
- o **"9 /70"** do herói tem uns 40 px de altura, no canto inferior esquerdo;
- o painel **"48 LETHAL"** tem o "48" com uns 35 px e a palavra **LETHAL com ~20 px**, à direita;
- os corvos que mergulham no painel do herói são manchas roxas de poucos pixels.

Em tela cheia a 1080p, lê quem procura. No player da página da Steam (~600 px de largura) e no celular, a palavra LETHAL fica com 6 a 8 px de altura: **ilegível**. É exatamente a palavra que o filme quer que o público leia antes do golpe.

**Exijo** um único degrau inteiro **×1 → ×2 no instante em que o painel acende "48 LETHAL"**, com um recorte que contenha **o Rei, o painel LETHAL e a mão** (o recorte de captura x ≈ 900 a 1860 cabe os três; o corte 4 fez isso, mas cortava o Rei pela metade, então desloquem o recorte para o Rei entrar inteiro, mesmo que a mão saia pela base). O olho já está no painel porque ele acende, então o degrau não faz o olho atravessar. Segurem ≥ 1,2 s a ×2 antes do JOGAR, e o golpe segue a ×2 no Rei. A queda da vida (25 → 9) pode continuar a ×1, mas o "9" final precisa aparecer **grande uma vez**: ou no mesmo degrau ×2 (se couber) ou num ×2 no painel do herói **antes** de o LETHAL acender, no mesmo canto em que o olho está.

### Mixagem (medida)
- **Coringa:** música −21,8 / SFX −16,6 (**5,2 dB abaixo**, ok).
- **Salão do Tirano:** música −18,7 / efeito −30,6 (lidera por 12 dB) e sobe +5,6 dB no corte (ok).
- **Trono do Rei (tom de sala):** −50 a −57 dBFS em 100 ms. Um pouco abaixo da faixa pedida (−45 a −50), mas audível como "sala" e não como zero digital. Aceito.
- **Pico:** golpe e morte a −8,3/−8,4 LUFS de curto prazo, **+3,5 dB** sobre o melhor trecho fora do clímax (−11,8).
- **Portão:** audível (−19,5), mas não "alto de propósito" como o Grimoire pediu no corte 4 (o mix do plano fica em −15, no nível do resto). Sugiro +3 dB no pico do rangido.
- **Criaturas (25,4–29,95 s):** stem de SFX a −∞: o anjo pousa a ×2 sem som nenhum. Menor, mas é o único plano "em ação" sem o som da ação.
- Sincronia: os mesmos cortes no ataque da medição do corte 4 (sem regressão).
- −14,2 LUFS, −1,1 dBTP e LRA 9,5 no 1080p e no 720p.

## Notas da versão Tirano (rodada 1, sem a queda)

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | 10 |
| C2 Sem preto | 10 | | G2 caminhada ≤ 3 s | 9 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | 9 |
| C4 Legibilidade | **8** | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 | | G5 golpe final forte | 9 |
| C6 Pico | 10 | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | 9 | | N1 virada legível | **8** |
| C9 Conformidade | 9 | | N2 portão | 9 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | 10 |
| C11 Continuidade | 9 | | N4 zoom no miolo | **7** |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | 9 |
| C13 Prende do início ao fim | 9 | | pontos 1-5 do corte 4 (Grimoire) | 10 · 9 · 10 · **8** · 10 |
| C14 Som | 9 | | Q queda do Rei | pendente (refazendo) |

**Status: NÃO APROVADO, por um item:** a virada precisa de um degrau ×2 no LETHAL (com o Rei inteiro) e do "9" grande uma vez. Os pontos menores (portão +3 dB, um baque no pouso do anjo) entram na mesma rodada se não atrasarem. A queda refeita (Q) e a variante do Rei vêm a seguir.
