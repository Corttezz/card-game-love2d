---
name: UI Layout Invariants (zonas, resize, fallback silencioso)
description: Invariantes obrigatórias de qualquer tela — não-sobreposição por construção, resize que cobre estado NOVO, e proibição de fallback silencioso. Nasceu de defeitos reais reportados pelo dono em Set/2026.
type: project
---

# UI Layout Invariants

Três regras que vieram de defeitos reais, reportados pelo dono olhando a tela.
Cada uma custou uma rodada de retrabalho. Leia antes de mexer em qualquer tela.

---

## 1. Não-sobreposição é GARANTIDA POR CONSTRUÇÃO, nunca por ajuste fino

**O defeito:** na tela de escolha de carta do pacote, o botão "Selecionar/Cancelar"
desenhava em cima da etiqueta de raridade. O código tinha, literalmente:

```lua
-- etiqueta de raridade:    ty  = ry + imgH + 8
-- botões confirmar/cancel: by0 = ry + imgH + 8
```

**A mesma coordenada Y.** Não era "o botão alguns pixels fora do lugar" — eram
dois elementos ancorados na carta, cada um sem saber do outro. É o que acontece
quando o layout cresce por ADIÇÃO: cada elemento novo é posicionado em relação
ao vizinho mais próximo, e ninguém tem um mapa do todo.

**A regra:** toda tela com mais de ~3 elementos móveis define **ZONAS** (bandas)
e cada elemento pertence a exatamente uma. Elementos de zonas diferentes nunca
disputam espaço, em nenhum estado. O padrão de referência é
[`src/ui/PackChoiceLayout.lua`](../src/ui/PackChoiceLayout.lua):

```
CONTEXTO   título, contador, botão de sair
CARTAS     a fileira (+ metadado colado na carta)
DETALHE    tudo que se sabe do item em foco
AÇÃO       confirmar / cancelar / instrução
```

Quando o espaço aperta, **quem cede é a escala do conteúdo**, não a posição das
bandas. E o módulo expõe um `validate()` que os tools rodam por estado — é o
teste geométrico que layout por acumulação nunca tem.

**Corolário — zona vazia é pior que zona ausente.** Uma banda larga e vazia que
só se preenche no hover lê como buraco na interface ("ficou com um espaço meio
que empty, isso ficou bem estranho" — dono, Set/2026). Se a informação só existe
no hover, ela deve estar ANCORADA no objeto que descreve, não numa tarja fixa
atravessando a tela. Ver também [[resize_pattern]].

---

## 2. Resize tem que cobrir o estado NOVO, não só o que existia quando a tela nasceu

[`memory/resize_pattern.md`](resize_pattern.md) já exigia `resize()` em toda
overlay. A regra existia **e foi violada mesmo assim**, porque o checklist dela
cobre "tela nova" e o defeito veio de "estado novo em tela existente": uma
reestruturação adicionou zonas, escala adaptativa, botões e banda de detalhe, e
o `resize()` continuou recalculando só o que existia antes.

**A regra, então:** sempre que você adicionar QUALQUER estado cacheado a uma
tela — rect, escala, fonte derivada, canvas pré-renderizado, posição de botão —
você tem a obrigação de estender o `resize()` dela no MESMO commit. Não é
tarefa de outro momento.

### NASCER grande ≠ CRESCER

Este é o ponto que deixou o bug escapar de todas as validações anteriores.
Capturar a tela já criada em 1920×1080 **não exercita o caminho do bug**. O bug
mora em: layout calculado num tamanho, janela muda, layout reaproveitado.

**Teste obrigatório, manual, antes de dizer que resize funciona:**

1. Abra o jogo em janela PEQUENA.
2. Entre na tela (loja, pacote, forja, evento, descanso...).
3. **Configurações → Fullscreen**, COM A TELA ABERTA. (O `SettingsMenu`
   chama `love.resize` manualmente, então é o caminho fiel.)
4. Desligue o fullscreen e volte.
5. Arraste a borda da janela aos poucos, com a tela aberta.

> **NÃO existe tecla `f`.** O `CLAUDE.md` documentou `f: toggle fullscreen`
> por muito tempo e isso é falso — não há binding no `love.keypressed`. Os
> únicos caminhos reais são o SettingsMenu e arrastar a borda. Esta memória
> chegou a repetir o erro na primeira versão (Set/2026).

Em nenhum momento pode haver elemento preso em coordenada antiga, fora da tela,
sobreposto ou com fonte de tamanho errado. Lembre que trocar resolução exige
`FontManager.clearCache()` (ver [[conventions]]).

**Armadilha registrada:** `PackOpenScreen:resize()` chamava `_layoutCards()`, que
SNAPA as cartas pra posição de spawn (centro do envelope). Redimensionar no meio
da revelação teleportava as cartas de volta e elas ficavam lá. Toda tela com
animação em curso precisa distinguir "recalcular destino" de "reposicionar do
zero" — resolvido com uma flag de "já despachado".

**Nota de ferramenta — como testar resize sem travar.** `love.window.setMode`
repetido dentro de um tool que roda em `love.load` NÃO retorna (e pedir janela
maior que a área útil do desktop trava já na primeira chamada). Duas saídas
que funcionam:

1. **Falsificar a janela** (preferido, usado em `tools/test_forge_resize.lua`):
   monkey-patch em `love.graphics.getWidth/getHeight`. Todo layout responsivo
   deriva dessas duas funções, então isso exercita exatamente "layout calculado
   num tamanho, reaproveitado noutro" — sem tocar no modo de vídeo. Roda na
   suíte, é determinístico e rápido.
2. **`setMode` com tamanhos abaixo da área útil** e poucas paradas
   (`tools/screenshot_shop.lua resize`) — serve pra CAPTURA visual, não pra
   suíte.

**Se o tool simular `love.resize`, ele tem que simular o que o `love.resize`
REALMENTE faz.** O teste da loja limpava só `FontManager` e por isso continuou
acusando o bug do canvas depois dele já estar corrigido — estava validando um
caminho que o jogo não usa mais. Teste que não espelha o caminho real acusa bug
inexistente, ou deixa passar um que existe.

---

## 3. Fallback silencioso é proibido

Três defeitos independentes desta sessão tiveram a MESMA causa: o código
continuava rodando, o efeito sumia, e ninguém percebia por semanas.

| Onde | O que acontecia |
|---|---|
| `engine/Easing.lua` | `byName[name] or Easing.smooth` — `"easeOut"` em camelCase não resolve (a tabela só tem minúsculas). Seis animações do `PackOpenScreen` rodaram com a curva errada por várias rodadas de polish. |
| `src/ui/BoosterShader.lua` | `load()` com `pcall` — shader que não compila degrada pra "sem efeito". Um agente mediu desvio 0.00 três ciclos seguidos comemorando, enquanto media arte crua sem shader nenhum. |
| `engine/Moveable.lua` | `reducedMotion` transforma `hop_up`/`swell_up`/`shove_x` em no-op. Correto por acessibilidade — mas a flag ficou ligada num save e custou uma sessão inteira de debug de "o feel sumiu depois do pull". |

**A regra:** quando um lookup falha ou um recurso não carrega, **AVISE**. Um
`print` uma vez por chave desconhecida basta (o `Easing.apply` já faz isso
agora). O custo de um aviso no console é zero; o custo de um efeito que some
sem rastro é uma sessão de debug.

**Corolário para acessibilidade:** `reducedMotion` pode remover MOVIMENTO, nunca
INFORMAÇÃO. Se o jogador precisa do número, do nome ou do estado pra decidir,
aquilo continua aparecendo com a flag ligada — só sem o exagero.

---

## 4. A arte já é boa; o trabalho é parar de cobri-la

Os pacotes acumularam TRÊS camadas de código sobre a ilustração — halo com a
silhueta do próprio sleeve (lia como cópia fantasma), cantoneiras em "L"
desenhadas por cima das chapas metálicas **que já existiam pintadas na arte**,
e um shader de foil que lavava a cor e dava a MESMA listra diagonal nos cinco
tipos, uniformizando justamente a identidade que se queria criar.

Cada camada entrou com boa intenção. Juntas produziram o "parece colagem" que o
dono reclamou três vezes. A correção foi **remover**, não somar.

**Antes de adicionar efeito sobre um asset, ABRA O PNG.** Metade do que se
pensa em "acrescentar" já está desenhado ali. E prefira errar para menos: dá pra
acrescentar depois vendo a tela limpa; é muito mais difícil enxergar o excesso
quando ele já virou o normal.

**Teste objetivo pra "o efeito está lavando a arte?":** renderize 1:1 e compare
pixel a pixel com o PNG de origem. Em repouso o desvio deve ser ~0. Foi assim
que o foil caiu de +10,6 para +0,78 de clareamento nas tiras do pacote Standard.

---

## Ligações

[[resize_pattern]] · [[ui_design_system]] · [[conventions]] · [[card_feel]]
