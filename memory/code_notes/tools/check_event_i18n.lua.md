---
name: code_notes/tools/check_event_i18n.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_event_i18n.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_event_i18n.lua`

Origem: `tools/check_event_i18n.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/check_event_i18n.lua
> Duas verificações de i18n dos eventos, nos 5 idiomas:
>
> 1. RÓTULO ESTOURA O BOTÃO? (largura)
> 2. AS CHAVES DE FEEDBACK EXISTEM? (resolução)
>
> O botão degrada em dois passos (components/Button.lua:249): primeiro encolhe
> a fonte até MIN_FONT, e só então TRUNCA com "...". Truncagem numa opção de
> evento é grave — o rótulo é justamente o contrato da troca ("[+$45 / -12
> HP]"), e cortar o custo transforma decisão informada em pegadinha.
>
> Traduzir multiplica o risco por 5: alemão e francês são bem mais longos que
> o português em que o layout foi desenhado. Isto mede os 14 eventos × 5
> idiomas × todas as opções de uma vez, em vez de olhar print por print.
>
> Roda: love . check_event_i18n [largura]
> Exit 1 se algo truncar.

## L33-38 (em `M.run`, junto a `local sw = tonumber(width) or 800`)

> Mesma conta do buildButtons: btnW = pw - 120, e o texto vive dentro de
> innerPadX=12 de cada lado (Button:_drawClean).
> Default 800 = `t.window.minwidth` do conf.lua, NAO a janela atual: a
> verificacao tem que medir o PIOR caso suportado, e nao o tamanho que a
> janela por acaso tem quando o teste roda (senao passa na maquina de
> quem escreveu e quebra na de quem joga em janela pequena).

## L77-90 (em `M.run`, junto a `local missing, untranslated = 0, 0`)

> ======================================================================
> 2) CHAVES DE FEEDBACK
> ======================================================================
> Os textos de resultado (`events.<id>.r_*`) sao chamados de DENTRO das
> funcoes apply, com I18n.t(chave, vars, fallbackPT). Chave escrita
> errado NAO quebra nada: cai no fallback, ou seja, a tela fica perfeita
> em portugues e so aparece em ingles/alemao, onde ninguem olha. A
> paridade entre locales (test_i18n) tambem nao pega isto, porque ela
> compara os locales ENTRE SI e nunca contra o que o codigo pede.
>
> Aqui o cruzamento e feito: varre os r_* declarados no pt_BR e exige que
> cada um resolva em TODOS os idiomas, com texto DIFERENTE do portugues
> (traducao ausente e um PT repetido, que passaria em qualquer checagem
> de existencia).

