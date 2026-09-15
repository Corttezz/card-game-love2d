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

## 11. Mudar o TEMPO de um sistema abre janelas que não existiam

O crash `attempt to index local 'g' (a nil value)` no meio de um turno
(Set/2026) não veio de código novo com defeito: veio de código ANTIGO cuja
janela de exposição era curta demais para alguém alcançar.

`Game:playSelectedCards` sempre passou `self.selectedCards` — a tabela **viva**
— para o `CombatSequence`, que monta a geometria uma vez e percorre a lista
depois. E `Game:selectCard` nunca teve guarda de combate ativo. Enquanto a
resolução durava fração de segundo, ninguém conseguia clicar no meio. Quando
cada acontecimento passou a ocupar seu instante ([[combat_beats]]), a resolução
passou a durar **segundos** e a janela virou o tamanho de um turno: bastava
clicar numa carta da mão.

Dois estragos, e o silencioso é o pior: selecionar inseria uma carta sem
geometria (crash), desselecionar devolvia a mana de uma carta **já sendo
jogada** — sem quebrar nada.

**A regra:** ao desacelerar ou alongar um sistema, procure o que ficava
protegido só pela velocidade. Pergunte "o que o jogador consegue fazer agora
que antes não dava tempo?". E a correção certa é em duas camadas — trave a
entrada (o guard) **e** torne o consumidor imune (copiar a lista na entrada,
nunca iterar referência viva de terceiros).

---

## 12. Build errada vira bug fantasma

O dono joga a partir de cópias e máquinas diferentes. Já custou semanas de "bug
que não reproduz" (memória `user-runs-stale-copy`). Duas defesas:

- `jogar.bat` faz `cd` para o diretório do projeto antes de chamar o LOVE —
  é o lançador oficial;
- `Config.VERSION` aparece no rodapé do menu e **sobe a cada leva que vai para
  teste**. Antes de investigar um defeito reportado, confirme o número na tela.

---

## 13. Arte de ESTADO precisa concordar com a arte BASE — e ninguém confere

`WorldRoad.drawCastle` troca a arte do castelo pelo frame da animação de
entrada quando `doorK > 0.02`. A troca é seca: o código desenha o que
estiver no PNG e **não tem opinião sobre o que ele mostra**. A fortaleza do
abismo tem um arco em chamas; a animação apagava o fogo e descia uma laje
de pedra no vão. *"Ta aparecendo uma porta do nada no castelo que tinha
porta de fogo"* (dono, Set/2026).

Dois aprendizados, e o segundo é o caro:

**Truncar uma animação que vai pro lugar errado não conserta.** A primeira
tentativa cortou os 2 últimos frames ("materializavam uma porta fechada").
Mas o frame 6 já era a laje quase fechada — o defeito só ficou mais curto,
e o dono reportou o MESMO sintoma uma leva depois, o que custou a viagem
inteira de novo. Sentido errado se corrige regerando, não aparando.

**O primeiro invariante que escrevi estava errado, e os dados disseram.**
Medi "o vão CLAREIA ao abrir" e três biomas reprovaram — com razão deles: o
castelo dos campos tem uma porta de madeira de verdade, que abre pra um
interior escuro. Brilho não separa os dois casos. O que separa é MATERIAL:
uma passagem é um BURACO (escuridão, ou fogo), um portão fechado é uma
SUPERFÍCIE feita da mesma alvenaria do muro ao lado. A trava virou "a cor
do vão não pode CONVERGIR pra cor da parede que o ladeia" — e aí a mesma
asserção aprova a porta de madeira (que se AFASTA do muro, virando vazio) e
reprova a laje. Números em `tools/test_castle_gate.lua`: defeito sobra 19%
da distância inicial, o caso aprovado mais apertado sobra 82%.

**A regra:** quando uma trava reprova casos que você sabe que são certos,
ela está medindo o SINTOMA e não a propriedade. Não afrouxe o limiar —
procure o invariante que distingue de verdade, porque o limiar afrouxado
passa a aceitar o defeito junto.

---

## 14. O teste que passa o MESMO literal errado dos dois lados confirma a si mesmo

`RunManager:advanceFloorInAct(totalActs)` recebia o total de atos como
**parâmetro**, com default 3. Todos os chamadores passavam `3` cravado —
inclusive o caminho real do jogo. Quando a campanha foi de 3 para 6 atos,
`Config.TotalActs` mudou e esse `3` não.

O estrago: a run virava endless ao fim do ato 3, `checkVictory` retorna false
com `endlessMode`, e o jogo ficou **impossível de vencer**. Os atos 4-6
existiam, com a curva certa, mas rotulados endless e sem fim. Trocar "o jogo
acaba cedo demais" por "o jogo não acaba nunca" é regressão pior que o
defeito original.

**E a suíte ficou verde o tempo todo**, porque os testes também passavam `3`:

```lua
t:eq("fim do ato final retorna 'endless_start'", rm2:advanceFloorInAct(3), ...)
```

O teste exercitava o PARÂMETRO, nunca a configuração do jogo. Ele teria
passado com `Config.TotalActs` valendo 3, 6 ou 600. Não é teste fraco — é
teste que **não toca a variável que o defeito habita**.

**A regra:** quando um valor tem uma fonte única (`Config.X`), o teste chama
o caminho de produção **sem passar o valor**. Parâmetro com default vira
override de teste, nunca contrato de chamada — e se produção passa o valor,
o teste tem que provar que produção passa o CERTO, não que a função respeita
o que recebe.

Corolário que pegou o defeito: a varredura certa não era do FIM, era de
**cada fronteira**. O teste novo percorre ato a ato e exige que nenhum passo
do meio ligue o endless. Defeito de limiar mora nas bordas, e "a borda" quase
nunca é só a última.

E o achado não veio de teste nenhum: veio de rodar `love . autoplay` e ler
"Ato final: A4-F4 **(endless)**" num relatório. **Jogar o jogo — mesmo com um
bot — encontra o que a suíte inteira não vê**, que é a mesma lição que o dono
vem dando a sessão toda de outro jeito.

---

## 15. Detector que mede a coisa errada é pior que detector nenhum

Três casos na mesma sessão, em subsistemas sem relação:

| onde | o que media | por que mentia |
|---|---|---|
| "ouro queimado" do autoplay | `getUpgrades(id)` (MAIOR nível entre cópias) contra o retorno de `upgradeCard(id)` (nível da cópia de MENOR nível, recém-forjada) | com 2 cópias e uma já forjada, antes=1 e depois=1 → gritava numa forja que funcionou (3 alarmes falsos em 6 corridas) |
| "rodapé parado" dos marcos | qualquer pixel mudando no rodapé | no abismo a brasa do chão pulsa **de propósito** — proibia movimento que era design |
| emenda de loop dos marcos | CONTAGEM de pixels ativos | é proxy: dois frames podem ter a mesma contagem e conteúdo diferente |

Os três modos de falha têm nome:
- **pergunta trocada** — mede uma grandeza parecida com a que interessa
  (máximo entre cópias ≠ nível daquela cópia);
- **proibição larga demais** — trava movimento que era intencional;
- **proxy** — conta em vez de comparar.

Isso é pior que não medir porque **dá confiança falsa**, e no caso do
autoplay é especialmente caro: aquele harness existe para decidir BALANÇO, e
alarme falso faz a anomalia de verdade se perder no ruído.

**A regra:** escolher O QUE medir é parte do teste, não detalhe de
implementação. E vale a checagem barata: *o detector consegue distinguir o
caso bom do caso ruim?* Se os dois produzem o mesmo número, ele não mede
nada.

---

## 16. Regra de domínio repetida em N telas volta na tela N+1

"Coringa não tem custo de mana" (ele é passivo e nunca passa pela mão) foi
corrigida no badge da arte, depois no tooltip — e **reapareceu** na escolha
de pacote e na Coleção, porque cada tela carregava seu próprio `if`. O dono
achou jogando: *"tem joker na hora de escolher que apresenta custo tbm"*.

Correção de tela conserta a tela. Correção de REGRA conserta as próximas: a
pergunta virou `CardFrame.showsManaCost(card)`, e a tela seguinte pergunta em
vez de repetir o defeito.

**O sintoma diagnóstico:** se você está escrevendo um `if` que já escreveu
noutro arquivo, o `if` está no lugar errado — não é duplicação de código, é
uma regra de domínio sem casa.

---

## Ligações

[[ui_layout_invariants]] · [[ui_rendering]] · [[combat_beats]] ·
[[music_generation]] · [[card_icon_animation]] · [[sfx_generation]] ·
[[input_focus]] · [[rng_and_offers]] · [[known_gaps]]
