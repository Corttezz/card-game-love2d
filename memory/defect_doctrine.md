---
name: Doutrina de defeitos — como eles se escondem neste projeto
description: Padrões TRANSVERSAIS de como bugs se escondem e como achá-los, destilados de defeitos reais que chegaram ao dono jogando. Complementa ui_layout_invariants (que trata de layout) com o que vale para qualquer subsistema.
type: project
---

# Doutrina de defeitos

[[ui_layout_invariants]] trata de layout. Este arquivo trata do **método**: os
padrões que se repetem em subsistemas diferentes. Cada regra aqui nasceu de um
defeito que passou por testes verdes e chegou ao dono **jogando** — que é o
único juiz que faltava em todos eles.

---

## 1. Animação com callback disparada por CONDIÇÃO precisa de trava

O fim de run desliga o CRT e troca de tela **no callback** do desligamento. O
gatilho é `game:checkGameOver()`, que continua verdadeiro no frame seguinte, e
no seguinte. Cada frame chamava a transição de novo, substituindo a animação em
curso e zerando o cronômetro: a 60 fps o callback **nunca** chegava ao fim.
Resultado: TV desligada para sempre, estado ainda `"playing"`, nenhuma tecla
respondendo. *"A tela fica preta e não tem como voltar pro menu, só fechando o
jogo"* (dono, Set/2026).

**A regra:** antes de iniciar um efeito com callback, pergunte quem dispara. Se
é um EVENTO (clique, carta jogada), pode disparar à vontade. Se é uma CONDIÇÃO
avaliada todo frame, **precisa de trava de reentrada** — e a trava precisa ser
liberada no caminho de volta, senão trava a próxima vez (mesmo sintoma, uma run
depois, muito mais difícil de relacionar à causa).

Corolário de testabilidade: a trava morava inline num closure do `love.load`,
onde teste nenhum a alcança. Virou `src/ui/EndTransition.lua` por isso. **Se a
lógica não é alcançável por teste, ela vai quebrar sem ninguém ver.**

---

## 2. Tela que esconde informação pode estar escondendo um defeito do MODELO

Queixa: *"se eu tiver duas cartas iguais, na tela de forjar só aparece uma"*.
Parecia bug de UI. Havia mesmo um `seen[id]` deduplicando a grade — mas ele era
**coerente** com a regra de então: o nível de forja morava num mapa por ID e
`buildPlayableDeck` o aplicava a todas as cópias. Com três "Golpe", forjar uma
**forjava as três**. Mostrar três cartas que sempre andam juntas seria mentira
de UI; a dedupe era o curativo.

Consertar só a grade teria **exposto** a mentira em vez de corrigi-la.

**A regra:** quando uma tela colapsa, agrupa ou omite algo que o jogador
possui, pergunte *por que alguém fez isso* antes de desfazer. Frequentemente a
resposta é que o modelo por baixo não sustenta a distinção.

---

## 3. Feedback certo na HORA ERRADA é pior que feedback nenhum

Barreira de Fogo disparava o reflexo ao **jogar a carta**, não ao levar o
golpe — em sete cartas. E o feedback era bem feito: som metálico, estouro no
inimigo, número subindo. Por isso era pior: **ensinava causalidade errada.** O
jogador conclui "escudo machuca" e nunca entende por que o reflexo some no
turno em que não joga defesa.

Ausência de feedback deixa o jogador sem saber. Feedback no momento errado o
deixa **convicto do errado**, e isso não se desfaz sozinho.

---

## 4. Meça a EMENDA, não o item

Três defeitos diferentes, a mesma forma:

| onde | o item passava | a emenda falhava |
|---|---|---|
| música em loop | MP3 válido, envelope bom, loudness certa | fim não casava com o começo: a volta piscava |
| animação de ícone | 9 frames, 9 distintos no md5 | frame N derivava do frame 0: o loop pulsava |
| crossfade de faixa | cada `playMusic` correto | troca durante o fade deixava a faixa antiga tocando **para sempre** |

Critério que funciona para os dois primeiros: a diferença entre o primeiro e o
último frame não pode passar de ~1,6x a diferença de um passo normal. Acima
disso, **ping-pong** (0..N seguido de N-1..1) mata a emenda por construção —
ver [[music_generation]] e `tools/pixellab_animate_vouchers.py`.

Para o terceiro, a regra é outra: **quem substitui um estado transitório tem
que encerrar o anterior.** O crossfade era um só; trocar o registro sem parar a
faixa que saía deixava órfã tocando. A→B→C rápido deixava A e B.

---

## 5. Valide o asset no CONTEXTO REAL — os três passos, e nenhum basta sozinho

Ícone de status aprovado três vezes e reprovado três vezes, cada uma por um
motivo novo:

1. **no tamanho de uso, nunca ampliado** — ampliado tudo parece bom; a 27px a
   presa e as três gotinhas viraram riscos;
2. **sobre o fundo real, nunca sobre branco** — a tira de aprovação era branca,
   que é exatamente onde tom escuro brilha; a gota vinho marcava 7 de contraste
   contra o corpo quase-preto da pill;
3. **lado a lado com um que funciona** — isolado o olho se acostuma com
   qualquer coisa. Só contra o veneno ficou óbvio que o disco de espinhos
   virava mancha.

Detalhe que fecha: a medição de contraste é **triagem, não veredito**, e não é
neutra em relação ao matiz — verde pesa 0,7152 na luminância e vermelho 0,2126,
então 60 é trivial para verde e **fisicamente inalcançável** para vermelho puro
(satura em ~54). Num ícone vermelho baixo, aumente o realce branco; clarear o
vermelho troca identidade por métrica. Detalhado em [[ui_rendering]].

---

## 6. Pipeline que reaproveita trabalho tem que confrontar a ENTRADA

O gerador de animações pulava a geração quando achava um job salvo daquele
ícone. Depois de três animações serem **reprovadas** (pastas apagadas, prompts
reescritos), ele encontrou os jobs antigos e **rebaixou exatamente os frames
recusados** — com o prompt novo no arquivo e o resultado velho no disco.

Isso é pior que falhar, porque parece ter funcionado. Corrigido guardando o
hash da descrição no job: se o prompt mudou, regenera e **avisa**.

**A regra:** cache que não confere a entrada não é cache, é armadilha.

---

## 7. Há defeitos que não existem em nenhum item — só ENTRE dois

Os três atos e o boss tinham centroide espectral de 107, 173, 139 e 154 Hz:
quatro retumbos graves quase idênticos. **Cada arquivo, isolado, passava em
tudo.** O defeito só existia na comparação, e nenhuma métrica de arquivo único
jamais o pegaria — por isso chegou ao dono (*"cada ato tem que ser uma música
diferente"*) em vez de a mim.

Mesma forma na loja: o preço era moeda cunhada na carta e retângulo flutuante
no pacote, a 40px de distância. Nenhum dos dois está errado sozinho; **os dois
juntos** é que leem como template — foi o que o dono chamou de "cara de IA".

**A regra:** quando o pedido é "isso está inconsistente", meça pares, não itens.
E adicione a comparação à ferramenta (`check_loop` ganhou colisão de brilho no
rodapé), senão ela depende de alguém lembrar.

---

## 8. Instrumento errado não se conserta com adjetivo

Vale para prompt de áudio e de arte. Pedir "warm" e "nothing shrill" a um
saltério não mudou nada — trocar para alaúde e viola da gamba levou o brilho de
5417 Hz para 432 Hz. Descrever o ARRANJO (instrumento, andamento, modo) em vez
do CLIMA ("melancólico", "opressivo") é o que separou quatro retumbos de quatro
músicas. Adjetivo de humor não tem tradução sonora única; instrumento tem.

Na arte, o equivalente: descrever a FORMA e o que NÃO pode se mover, em vez do
sentimento. E ciclo curto (4 frames em vez de 8), porque metade do caminho é
metade da chance de derivar.

---

## 9. Teste só vale depois de você REVERTER a correção

Toda trava desta sessão foi verificada desfazendo o conserto e confirmando a
falha — e os números viraram parte do relatório:

| correção revertida | o que o teste acusa |
|---|---|
| trava de fim de run | 120 transições iniciadas, **0** completadas |
| forja por cópia | 13 falhas, incluindo "cópia 1 NÃO foi forjada junto" |
| faixa órfã de música | 3 faixas tocando juntas |
| espinhos na jogada | 5 falhas em `test_beats` |
| fúria muda | 6 falhas |
| moeda que orbita | "moeda pousada NÃO se move mais" falha |

**Teste que não falha com o bug presente é decoração.** E o formato importa: a
asserção tem que descrever o DEFEITO em linguagem de jogador, não o valor
interno — quem lê o vermelho daqui a um ano precisa entender o que quebrou.

Corolário: asserção de contagem (`> 10 casos`, `total > 0`) evita o falso verde
de um teste que não exercitou nada. Um loop que não achou nada passa em todas
as asserções de conteúdo.

---

## 10. O que não é observado não é corrigido

A auditoria do catálogo mediu o que ninguém tinha medido: **78 das 128 cartas**
resolviam todos os efeitos num único frame. A queixa do dono ("muitas coisas só
saem acontecendo") era exata, e nenhum teste existente falava disso porque
nenhum media *tempo* ou *ordem* — só resultado.

Quando o pedido for "revise todas", **construa a varredura**, não confie em
lembrar. `tools/audit_feedback.lua` virou catraca: falha se um tipo de efeito
mudo NOVO aparecer, e cobra a remoção da lista quando um é corrigido.

---

## 11. Build errada vira bug fantasma

O dono joga a partir de cópias e máquinas diferentes. Já custou semanas de "bug
que não reproduz" (memória `user-runs-stale-copy`). Duas defesas:

- `jogar.bat` faz `cd` para o diretório do projeto antes de chamar o LOVE —
  é o lançador oficial;
- `Config.VERSION` aparece no rodapé do menu e **sobe a cada leva que vai para
  teste**. Antes de investigar um defeito reportado, confirme o número na tela.

---

## Ligações

[[ui_layout_invariants]] · [[ui_rendering]] · [[combat_beats]] ·
[[music_generation]] · [[card_icon_animation]] · [[sfx_generation]] ·
[[input_focus]] · [[rng_and_offers]] · [[known_gaps]]
