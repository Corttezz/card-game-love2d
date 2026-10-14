---
name: code_notes/tools/test_locale_accents.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_locale_accents.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_locale_accents.lua`

Origem: `tools/test_locale_accents.lua` em `7dbdb60d` (3 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local M = {}`)

> tools/test_locale_accents.lua
> Acento de verdade nos 5 idiomas (Out/2026).
>
> Três defeitos da mesma família, todos invisíveis no código e óbvios na
> tela de quem joga em outro idioma:
> 1. A fonte (Press Start 2P) desenhava as MAIÚSCULAS acentuadas como uma
> letra encolhida com acento na mesma célula: "CRÉDITOS" saía
> "CRéDITOS". O remédio foi redesenhar os glifos (tools/font_latin_caps.py);
> aqui medimos os pixels: a maiúscula acentuada contém a letra base
> INTEIRA e o acento fica FORA dela.
> 2. Os locales misturavam texto acentuado e transliterado ("Forca",
> "dano" em espanhol, "degats", "fuer"/"Staerke"). Lista de ASCII-ismos
> conhecidos por idioma: se voltar, falha.
> 3. O glossário de palavras-chave do tooltip era português em todo idioma.
> Cada verbete precisa casar a sua carta-exemplo em cada idioma e mostrar
> nome/texto traduzidos.
>
> Roda: love . test_one test_locale_accents

## L25-26 (em `LOCALES`, junto a `local ASCIIISMS = {`)

> Palavras que NUNCA devem aparecer num texto do locale (comparação por
> palavra inteira, sem diferenciar caixa). Cada uma já apareceu de verdade.

## L209 (em `ptNames`, junto a `I18n.setLocale("de", true)`)

> O nome exibido em alemão não pode ser o português (o defeito original).

