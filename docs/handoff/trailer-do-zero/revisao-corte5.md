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

## Versão Tirano 5b (`grimoire_zero_corte5_1080p.mp4` 19:19 / `_720p` 19:20), rodada 2: NÃO APROVADO, falta a queda (Q)

_Medidas: `...\scratchpad\rev\h5b\`; folhas da virada a 4 quadros/s e da queda a 8 quadros/s; comparação da queda do corte 4 com a do 5b no mesmo instante (`...\rev\g5b\c4c5.png`); movimento quadro a quadro de 53,4 a 56 s. Não ouvi._

**Virada: resolvida.** Sequência: ×1 com o Rei anunciando "Murder of Crows" → **×2 no painel de vida** (45,48–48,27 s), com **25 → 21 → 17 → 13 → 9** e "Weak", grandes → ×1 com a mão dada e o Rei → **×2 com "48 LETHAL" ao lado da mão** (50,19–52,83 s, 2,64 s) → Play Cards apertado → golpe. O "9" aparece grande e o LETHAL fica legível com pelo menos 1,2 s de ×2 antes do JOGAR. O Rei sai cortado pela borda esquerda no ×2 do LETHAL, mas o assunto do plano é o painel, que acende e prende o olho. Aceito. N1, N4 e C4 vão a 9.

Zero quadros pretos; −14,2 LUFS, −1,1 dBTP, LRA 9,3; pico +3,0 dB (−8,4 contra −11,9 fora do clímax). O resto continua como na rodada 1.

### Q, queda do Rei: **6/10**
Comparei a queda do 5b com a do corte 4 no mesmo instante (54,3 e 55,0 s): **é praticamente a mesma** (`g5b/c4c5.png`). Mudou o enquadramento por poucos pixels e só. O que está na tela:
- 53,4–53,8 s: hit-stop com flash, tremor e o "48" (bom);
- 53,8–54,9 s: o Rei de pé, quase parado (o movimento médio da imagem fica em ~2,7 por quadro, só a câmera descendo 2 px por quadro), já pequeno no quadro ×2 e dessaturado, com "BREAK THEM BACK." em cima;
- 55,0–55,2 s: a queda propriamente dita acontece em **~0,2 s** (o pico de movimento é 55,05–55,17 s);
- 55,2–55,96 s: o corpo no chão, na base do quadro, até o coringa.

Ou seja: a queda real dura 0,2 s, no rodapé do quadro e dessaturada. O olho vê "Rei parado → Rei no chão". Nenhum dos recursos pedidos pelo Grimoire às 18:57 entrou: nem mais perto, nem tremor ou poeira no impacto do corpo, nem a ajoelhada segurada.

**Exijo**, dentro de ≤ 2,5 s do 48 ao corpo no chão e só com degraus inteiros:
1. **um degrau ×2 → ×3 no mesmo centro** no instante em que o Rei começa a ceder (cerca de 54,6 s), com o corpo ocupando a metade de baixo do quadro;
2. **a ajoelhada segurada** de 0,4 a 0,6 s (congelar ou desacelerar em passo inteiro de quadro: repetir quadros, nunca interpolar), para o espectador ler "ele caiu de joelhos";
3. **o impacto do corpo** com tremor curto (6 a 8 quadros, passos pares, como no golpe) e poeira ou faíscas (as partículas do próprio jogo servem) no quadro em que ele toca o chão, junto com o baque no som (o `bossDeathThud` / `swordSound` já existem; confira que ele cai **no** quadro do toque);
4. o "BREAK THEM BACK." entrando **depois** do impacto, ou acima do Rei sem cobrir a coroa no ×3.

| nota | antes (rodada 1) | 5b |
|---|---|---|
| C4 Legibilidade | 8 | 9 |
| N1 virada | 8 | 9 |
| N4 zoom no miolo | 7 | 9 |
| ponto 4 do Grimoire (corte 4) | 8 | 9 |
| **Q queda do Rei** | — | **6** |
| C6 Pico | 10 | **8** (o pagamento visual da queda não se lê) |
| G5 golpe final forte | 9 | 9 (o golpe é forte; a falha está depois dele) |

As demais notas são as da rodada 1, todas ≥ 9. **Status da Tirano 5b: NÃO APROVADO por um único item, a queda (Q 6, C6 8).** A variante do Rei (`grimoire_zero_corte5_rei_720p.mp4`, 19:14) é anterior à virada 5b; reviso a que sair com a virada e a queda novas.

## Variante Rei 5b (`grimoire_zero_corte5_rei_720p.mp4`, 19:24), rodada 1: NÃO APROVADO

_Medidas: `...\scratchpad\rev\h5rei\`; mixagem nos stems `build\trailer\zero5_rei\zero5_rei_rei\` (`mix5_rei.json`), com a curva da música em janelas de 20 ms; quadros da queda (`...\rev\g5b\rei_queda6.png`, `rei_fim.png`); movimento quadro a quadro de 53,6 a 56,9 s. Não ouvi._

Esta variante já traz a virada 5b e **uma queda nova**, que é a que a Tirano precisa.

### Q, queda do Rei na variante: **9/10**
EDL: `k_golpe` ×2 com hit-stop e o "48" (52,83 s, 0,9 s) → `k_queda` **×3 no mesmo centro** (53,73 s) → `k_ajoelha` ×3 com **a ajoelhada segurada** (54,13–56,88 s, `hold 30`). Na tela:
- **tremor forte** no golpe (diferença entre quadros de 12 a 31 de 53,62 a 54,07 s, passos inteiros);
- o degrau ×2 → ×3 deixa o Rei grande, ocupando o meio do quadro; ele cede (54,1 a 54,3 s), cai de joelhos e **fica ajoelhado**, legível, com faíscas no chão (`r_55.5`);
- do fim do hit-stop até a ajoelhada assentar: ~2,0 s (dentro de ≤ 2,5 s);
- "BREAK THEM BACK." no alto, sem cobrir a coroa;
- a ponte para o coringa nasce da ajoelhada.
Não dou 10 porque o corpo nunca toca o chão (fica de joelhos até o coringa) e o "corpo do Rei no chão" do plano de som (55,46 s) não tem imagem correspondente. Como "segurar na ajoelhada" foi uma das opções do Grimoire, aceito.

**A Tirano tem de receber exatamente esta queda** (golpe ×2 → queda ×3 → ajoelhada segurada).

### O que segura a variante
1. **O pico ficou fora de sincronia (regressão).** Na variante o golpe passou para 52,83 s (como na Tirano), mas o som do golpe ficou no tempo antigo. A música está em **−∞ de 52,66 a 53,24 s** (o respiro) e só volta a 53,24 s, junto com `bossDeathThud`, `bossFeatherBurst`, `enemyVoice_carrion_king_death2` e o `comboTrigger`. Resultado: o flash, o tremor e o "48" (52,83 s) acontecem **dentro do respiro**, com só o `swordSound` (52,91 s), e o impacto sonoro grande chega **0,41 s depois** da imagem. No golpe, que é o ponto mais importante do filme, o som e a imagem estão desencontrados. **Exijo** o respiro terminando e o impacto (música + baque + pena + voz) no **quadro do hit-stop** (52,83 s), como na Tirano (onde a música sobe +12,9 dB nesse quadro).
2. **Coringa sem som e com a música por cima (M4, terceira vez nesta variante).** A carta do coringa aparece a 56,07 s (dentro do `k_ajoelha`) e não há nenhum evento de revelação no `mix_sources.json` (a Tirano tem `bossRevealSting` e `jokerSig_joker_boss_carrion`). No plano `k_coringa` a música está a −16,1 e o SFX a −32,5: a música fica **16 dB acima** do som da revelação. **Exijo** o som de revelação do coringa no quadro em que a carta aparece e a música 4 a 6 dB abaixo dele.
3. **Gárgula / "6 ACTS." (11,82 s):** a maior subida em ±30 ms é de 10,1 dB, melhor que antes (5,9), mas ainda fraca. Com os itens 1 e 2 resolvidos, aceito 9 se cair num ataque de ≥ 15 dB ou num evento do jogo escrito.

Zero quadros pretos; −14,1 LUFS, −1,2 dBTP, LRA 8,2; fecho 3,3 dB abaixo do pico (−8,8 contra −12,1).

| nota (variante Rei 5b) | valor |
|---|---|
| Q queda do Rei | **9** |
| C3 Sincronia | **7** (o impacto do golpe 0,41 s depois da imagem) |
| C6 Pico | **8** (pelo mesmo motivo) |
| C14 Som / N5 | **7** (golpe desencontrado; coringa sem som) |
| G5 golpe final forte | **8** |
| demais (C1, C2, C4, C5, C7 a C13, G1 a G4, G6, G7, N1 a N4) | ≥ 9, iguais à Tirano 5b |

**Status da variante Rei 5b: NÃO APROVADO** (itens 1 e 2). **Status da Tirano 5b: continua NÃO APROVADO** pela queda; a correção é usar a queda desta variante. `===CORTE5_PRONTO===` só quando as duas passarem.

## Versão Tirano 5c (`grimoire_zero_corte5_1080p.mp4` 19:37 / `_720p` 19:38), rodada 3: NÃO APROVADO (só mixagem)

_Medidas: `...\scratchpad\rev\h5c\`; mixagem nos stems `build\trailer\zero5\zero5_tirano\` (`mix5c.json`) e curva da música em 20 ms; folha a 6 quadros/s de 52,6 a 57,6 s (`...\rev\g5b\tir_c.png`). Não ouvi._

### Q, queda do Rei na Tirano: **9/10, resolvida**
Golpe ×2 com flash, tremor e o "48" (52,83–53,85 s) → **degrau ×3 no mesmo centro** (53,85 s): o Rei grande cede, cai de joelhos e **o corpo toca o chão** (~55,2 s), com faíscas. "BREAK THEM BACK." entra **depois** do impacto (55,32 s). O coringa sobe do corpo caído. Do fim do hit-stop até o corpo no chão são ~1,4 s, dentro de ≤ 2,5 s, só com degraus inteiros. É a melhor queda até agora: legível, com peso e contínua.

**Sincronia do golpe:** a música volta a 52,82 s, junto com `bossDeathThud`, `bossFeatherBurst` e a voz de morte, no quadro do hit-stop. Correto.

### O que segura (regressões de mixagem)
1. **O pico perdeu a margem.** O curto prazo do clímax ficou em **−9,7** (era −8,4 no 5b); o melhor trecho fora do clímax é **−11,4** (28 s, a montagem de estradas). Margem de **1,7 dB**, abaixo dos ≥ 2 dB fixados no roteiro. O LRA caiu de 9,3 para **6,7**. Parece que o ganho de pós-golpe foi aliviado ou o limitador passou a apertar o impacto (o momentâneo chega a −6,9 em 54 s). **Exijo** o pico de volta a ≥ 2 dB acima de qualquer outro trecho (o mais simples: baixar a montagem de 25 a 29 s em 1 a 2 dB, ou devolver o ganho da queda).
2. **Coringa: a meta escorregou e o som chega atrasado.** No plano `k_coringa` a música está a −22,9 e o SFX a −23,6, empatados, quando a meta é a música 4 a 6 dB **abaixo**. E a revelação (`bossRevealSting` + `jokerSig_joker_boss_carrion`) toca a **57,62 s**, ~0,6 s **depois** de a face da carta aparecer (no corte de 56,98 s). Exijo o som da revelação no quadro da face e a música 4 a 6 dB abaixo dele.

O resto se mantém: zero quadros pretos, −14,1 LUFS, −1,0 dBTP, a virada 5b aprovada e os demais pontos ≥ 9.

| nota (Tirano 5c) | valor |
|---|---|
| Q queda do Rei | **9** |
| G5 golpe final forte | 9 |
| C6 Pico | **8** (margem 1,7 dB) |
| C14 Som / N5 | **8** (pico achatado, LRA 6,7, coringa empatado e atrasado) |
| demais | ≥ 9 |

**Status da Tirano 5c: NÃO APROVADO, só por dois ajustes de mixagem** (margem do pico ≥ 2 dB; coringa 4 a 6 dB abaixo do SFX e no quadro da face). A imagem está aprovada. A variante do Rei segue com os itens da rodada anterior (golpe dessincronizado e coringa sem som); a queda dela já passou.

## Versão Tirano 5d (`grimoire_zero_corte5_1080p.mp4` 19:47 / `_720p` 19:48), rodada 4: **APROVADO**

_Conferido de forma independente: medidas quadro a quadro (`...\scratchpad\rev\h5d_tirano\`); mixagem nos stems `build\trailer\zero5\zero5_tirano\` (`mix5d_tirano.json`); folha a 6 quadros/s de 52,6 a 57,6 s (`...\rev\g5b\tir_d.png`); loudness do 720p. Não ouvi: a escuta humana (fone e caixa) continua pendente com o Daniel/Grimoire._

Os dois ajustes de mixagem da rodada 3 chegaram:
- **Margem do pico:** curto prazo do golpe/queda a **−9,2**, contra −12,0 no melhor trecho fora do clímax: **+2,8 dB** (meta ≥ 2). LRA de volta a **8,9**.
- **Coringa:** música −17,2 e SFX −12,1 no plano: **5,1 dB abaixo** (meta 4 a 6). A revelação e a assinatura do coringa tocam a **57,00 s**, no quadro da face (o plano começa a 56,98 s).
- **Golpe:** música, voz de morte, penas e baque a 52,83 s, no quadro do hit-stop (o mix sobe +22,6 dB no corte).
- **Queda:** a mesma do 5c (×2 com 48 → ×3 no mesmo centro → ajoelhada segurada → corpo no chão com tremor e poeira → "BREAK THEM BACK." depois do impacto → coringa nascendo do corpo).
- **Zero quadros pretos;** −14,2 LUFS, −1,1 dBTP no 1080p e no 720p.

Cortes com ataque fraco restantes: `e6_anjo` 11,4 dB e `logo` 11,1 dB (ataque a ≤ 2 quadros, aceitáveis); `k_porta` 11,9 dB, guiado pelo evento do portão (`castleGateOpen` +9 dB). Nenhum fora da regra.

### Notas por critério (Tirano 5d)

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | 10 |
| C2 Sem preto | 10 | | G2 caminhada ≤ 3 s | 9 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | 9 |
| C4 Legibilidade | 9 | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 | | G5 golpe final forte | 9 |
| C6 Pico | 9 | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | 9 | | N1 virada legível | 9 |
| C9 Conformidade | 9 | | N2 portão / caminhada | 9 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | 10 |
| C11 Continuidade | 9 | | N4 zoom em degraus progressivos | 9 |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | 9 |
| C13 Prende do início ao fim | 9 | | correções 1 a 7 do corte 4 | 9 em todas |
| C14 Som | 9 | | pontos 1 a 6 do Grimoire (corte 4) | 10 · 9 · 10 · 9 · 10 · 9 |
| **Q queda do Rei** | **9** | | | |

**Veredito da versão Tirano (corte 5d): APROVADO**, com ≥ 9 em todos os critérios. Ressalvas que não bloqueiam e vão na Entrega: escuta humana pendente; "NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX"; declaração de IA (salões Higgsfield) com o Daniel.

**Variante Rei:** aguardando o arquivo novo (a diretora está regravando com a gárgula no ataque de 12,50 s). Reviso depois do commit dela. `===CORTE5_PRONTO===` só com as duas aprovadas.
