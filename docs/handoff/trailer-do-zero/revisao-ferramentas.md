# Revisão: etapa 2, ferramentas (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `ferramentas.md` (10.014 bytes, 14:34). Conferi o worktree `card-game-trailer-zero` (commit `52a262c3`, `TRAILER_OUT`), a tomada de teste `%APPDATA%\LOVE\card-game-trailer-v9\trailer_zero_teste\deck8.mkv` (231 MB + `audio.jsonl`; as tomadas antigas em `trailer\` continuam lá) e abri os recortes `x2_13.png` e `x3_13.png` em tamanho real. Régua: ≥ 9 em todos os critérios para aprovar._

## Rodada 1, NÃO APROVADO

O inventário é sério. A decisão de tirar o CRT da captura e aplicá-lo por cima do quadro final está certa, e o teste ×2 prova o ponto principal do diagnóstico: no `x2_13.png` leem-se "Leech Blade", o tooltip inteiro ("Deal 6 damage. Heal 2 HP."), "ATTACK 6/8/4/5", a arte das cartas e o Bruto acima. É outro filme em relação ao A/B/C. Também acho certo proibir zoom contínuo (só troca de plano ×1/×2/×3). O que falta é provar que a imagem continua **pixel íntegro e com a cara do jogo** depois de todo o tratamento, e que a câmera virtual não pula.

### Problemas concretos

1. **O pixel irregular não vem do recorte, vem do jogo, e já aparece no ×2.** No `x2_13.png` a carta em hover (Leech Blade) já tem colunas e linhas de largura desigual: a moldura e o "Leech Blade" do cabeçalho saem tortos. Isso é a escala 1,333 do jogo (96×144 → 128×192) somada ao tilt 3D do hover. No `x3_13.png` o defeito fica evidente: as letras do cabeçalho da carta e as bordas da ilustração "dançam" (3 e 4 px alternados) e a borda da cobra parece serrilhada. É exatamente a "cara de IA / borrado sobre pixel art" que o Daniel rejeita, agora ampliada. **Exijo testar uma escala inteira das cartas só no gravador** (variável `TRAILER_CARD_SCALE=1` ou `2` sobrescrevendo `Config.Cards.BASE_SCALE`/`HOVER_SCALE` dentro do `trailer_record`, sem mudar o jogo). Com a carta a 1× ou 2× do pixel lógico, o recorte ×2/×3 sai com pixel quadrado e uniforme. Se a mão quebrar de layout nessa escala, digam e mostrem. Critério: no recorte, **toda coluna de pixel da arte da carta com a mesma largura** (medir numa linha horizontal da ilustração da carta em repouso, fora do hover).
2. **O ×3 está reprovado do jeito que está.** "Insert curto de ≤ 1 s" não salva um plano que é justamente o close da carta, o lugar onde o espectador para para olhar. Ou o ×3 só entra depois de o item 1 resolver a escala, ou sai do roteiro (fica ×2 + Coleção/`inspect` para o close máximo).
3. **O teste de câmera que pedi não foi feito.** Na revisão do diagnóstico (rodada 2) pedi um pan e um zoom-in de 2 s em ×2 e ×3, vistos 1:1. O doc define a regra ("passos de 1 px da captura") sem prova. A ×2, 1 px da captura = 2 px na tela. Um pan de 1 px a cada 2 quadros (30 px/s na captura) já se lê como degrau a 60 fps. **Exijo**: um mp4 curto (≤ 4 s, 1080p) de pan lento, pan rápido e corte seco ×1 → ×2, com a velocidade mínima escrita a partir da qual o pan não "pula" (ou a decisão de não usar pan, só enquadramentos fixos + corte no grave). Isso alimenta direto o C11 do corte.
4. **O CRT aplicado depois tem de ser o CRT do jogo.** "Máscara/ring do Kinetic Film + scanline na escala do filme" pode virar um filtro genérico, e o Daniel aprovou o CRT do jogo (`shaders/crt.glsl`: curvatura, máscara, aberração, brilho de borda). **Exijo** um quadro lado a lado: o mesmo instante da tomada **com** CRT do jogo (×1) e **sem** CRT + CRT de pós (×1). A diferença tem de ser imperceptível no plano aberto. Se o caminho mais fiel for rodar o próprio `crt.glsl` offline sobre o quadro final (LÖVE headless, ou porte do shader para o compositor), escrevam qual.
5. **Liga-TV reproduzido no compositor:** mesma exigência. Comparar com a tomada `poweron` do jogo (folha de 10 quadros de cada), porque é um pedido literal do Daniel e tem de parecer a TV do jogo, não uma transição de editor.
6. **Integração dos salões do Higgsfield sem método nem teste.** "Re-pixelizar na grade, cor do salão real do mesmo chefe" ainda não diz como. **Exijo** o método (ex.: reduzir à grade de pixel do `castle_hall_*` correspondente com vizinho mais próximo, quantizar na paleta do salão real, ajuste de luma/saturação medido contra o salão real, CRT por cima) e **1 quadro de teste** do `hall1_carrion` ao lado do `castle_hall_1` real tratado igual. Não é pendência de licença (o Daniel decidiu manter); é qualidade, e o diagnóstico mediu a quebra de estilo em 38,75 s.
7. **HUD no 1º vídeo.** O padrão Steam nº 1 pede gameplay "com HUD visível". O ×2 corta mana, vida e barra do inimigo. A lista de tomadas precisa garantir, nos primeiros ~5 s, um enquadramento com o HUD lido (×1, ou ×2 posicionado na mão + orbe de mana + vida). Isso é decisão do roteiro, mas a tomada tem de existir.
8. **Tooltip cobrindo a mão.** No teste, o tooltip da Leech Blade cobre metade das outras três cartas. Para o trailer, a ferramenta precisa permitir escolher se o tooltip aparece (prova do texto da carta) ou não (mão inteira visível). Escrevam se o gravador controla isso (hover sem tooltip / tooltip ao lado).
9. **Luta encenada: falta o roteiro técnico.** A tabela diz "função nova" para `zero_fight`, `zero_monarch` e `zero_tyrant`, sem dizer quais chamadas do `__cheatApi` existem e quais faltam. Para a Geada, a regra real é 4+ acúmulos na compra congelando as 2 cartas mais caras (ver `BossMechanics`/`memory/boss_mechanics.md`); para o Tirano, a corrente rompe ao cruzar 75%. Peço a lista concreta (chamada → estado esperado → como se confere na folha). Pode ficar para a entrega das tomadas, mas com dono e com a prova por folha de quadros.

### O que já está bom (não mexer)
- Trocar `TRAILER_OUT` para não apagar as tomadas antigas: necessário e feito.
- 1 `lovec`, headless, identidade `card-game-trailer-v9`, 0 crédito, nada de 4K, ACE-Step sem gerar seções coladas, SFX do jogo com a marca "não publicável": tudo conforme.
- Proibir zoom contínuo e reservar o ×1 para situar.

## Notas por critério (rodada 1)

| critério da etapa | nota | por quê |
|---|---|---|
| F1 Inventário e veredito | 9 | completo, com o motivo de cada ferramenta, proibidos claros |
| F2 Teste real e verificável | 9 | tomada e recortes conferidos no disco |
| F3 Imagem íntegra / cara do jogo | 6 | pixel irregular já no ×2 (escala 1,333 + tilt); ×3 serrilhado; CRT e liga-TV de pós sem comparação com o do jogo |
| F4 Cobertura das tomadas para o roteiro | 8 | lista boa; faltam tomada com HUD, controle do tooltip e o teste de integração do Higgsfield |
| F5 Conformidade e riscos | 9 | — |
| F6 Câmera e continuidade (nada pulando) | 6 | regra sem prova; o teste de pan/zoom pedido não foi feito |
| F7 Viabilidade da luta encenada | 7 | identificada, mas sem a lista de chamadas e sem a prova da Geada/corrente |

**Status: NÃO APROVADO.** Para aprovar: itens 1, 3, 4 e 6 com prova (imagem ou mp4 curto no scratchpad, com o caminho no `ferramentas.md`), 2 decidido, e 7, 8 e 9 escritos. O roteiro pode começar em paralelo, mas os planos ×3, o CRT de pós e os salões de IA ficam condicionados a estas provas.
