---
name: code_notes/tools/test_input_focus.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_input_focus.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_input_focus.lua`

Origem: `tools/test_input_focus.lua` em `7dbdb60d` (8 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_input_focus.lua
> Regressão do FOCO DE ENTRADA (bug do dono, Set/2026: "quando estou dentro
> do menu de pausa o hover continua pegando elementos de trás").
>
> O que este teste trava, nesta ordem:
> 1. o portão do mouse (src/ui/InputFocus): com overlay visível, quem
> desenha na camada de trás lê o mouse FORA DA TELA;
> 2. o efeito disso em componentes REAIS (Button do projeto e as rows do
> PauseMenu de verdade) — hover morre atrás, vive dentro do modal;
> 3. a VOLTA sem mexer o mouse: fechado o overlay, o hover de trás acende
> no frame seguinte (hover preso apagado é o defeito inverso);
> 4. a distinção modal × cobertura: a TopBar (camada CHROME) morre sob a
> pausa e sobrevive sob a loja/descanso/mapa;
> 5. a FIAÇÃO no main.lua — porque o mecanismo pode estar perfeito e o
> dispatch não usá-lo. Sem esta parte, reverter o main.lua passaria.
>
> Roda: love . test_one test_input_focus

## L22 (em `M`, junto a `local function fakeOverlay()`)

> Overlay de mentira: só precisa responder isVisible().

## L75 (em `M.run`, junto a `IF.push("scene_cover")`)

> Dentro do overlay o mouse é real (o hover DELE tem que funcionar).

## L82 (em `M.run`, junto a `t:truthy("camada nenhuma = sempre permitido (cursor)", IF.allows(nil))`)

> Sem camada declarada (cursor do mouse, chrome global): nunca bloqueia.

## L164 (em `M.run`, junto a `local src = love.filesystem.read("main.lua") or ""`)

> ===== 6. fiacao do main.lua (reverter o dispatch TEM que falhar) =====

## L178-182 (em `esperados`, junto a `local function corpo(nome, fim)`)

> A camada SCENE tem que envolver o dispatch de ESTADO no update E
> no draw, e cada HANDLER de evento tem que perguntar pelo captor.
> Fatiamos POR FUNCAO: contar ocorrencias no arquivo inteiro deixava
> passar a remocao de uma delas (medido — reverter a camada do
> love.update continuava verde).

## L219-224 (em `corpo`, junto a `do`)

> ===== COBERTURA vs COBERTURA: quem desenha manda (Set/2026) =====
> "Tela de remover carta nenhum clique funciona." `_G.openCardPicker`
> reusa o RestScreen e troca currentState pra "rest", mas NAO esconde a
> tela que o chamou. Aberto de um EVENTO, o eventScreen seguia visivel e,
> por ter sido registrado DEPOIS, roubava o foco: o mouse do picker virava
> sentinela e o clique nao tinha em quem cair.

## L237 (em `pause:isVisible`, junto a `IF.register("rest",  picker, { keepChrome = true })`)

> ordem de registro = a do main.lua: rest ANTES de event

