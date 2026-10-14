---
name: code_notes/src/ui/BoosterShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/BoosterShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/BoosterShader.lua`

Origem: `src/ui/BoosterShader.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local BoosterShader = {}`)

> src/ui/BoosterShader.lua
> Wrapper do shaders/booster.glsl. Aplica textura iridescente azul-prata
> animada sobre uma imagem de carta — usado em "cartas seladas" / pacotes.
>
> Uso:
> BoosterShader.apply(image, phase, dissolve)                 -- arco-íris neutro
> BoosterShader.apply(image, phase, dissolve, sheen, amount)  -- tingido
> love.graphics.draw(image, ...)
> BoosterShader.clear()
>
> phase: number (fase da animação iridescente; passe love.timer.getTime()
> pra animação contínua, ou um valor fixo pra freeze)
> dissolve: 0..1 — combina com dissolve mask (opcional, default 0)
> sheen: {r,g,b} — cor dominante do TIPO de pacote (PackThemes.<kind>.glow).
> Sem ela os 5 pacotes brilham idênticos e a identidade da arte se
> perde no arco-íris genérico.
> amount: 0..1 — quanto a iridescência é puxada pro sheen (default 0 =
> comportamento original, pra não mudar quem chamava com 3 args).

## L36-37 (em `BoosterShader.load`, junto a `hasSheen = (s.hasUniform ~= nil)`)

> Uniform ausente (shader antigo / compilador removeu) faria `send` dar
> erro em TODO frame — checa uma vez e decide aqui.

## L40-42 (em `BoosterShader.load`, junto a `if not hasSheen then`)

> Só avisa na ANOMALIA. O silêncio aqui já custou caro uma vez: um erro de
> compilação no GLSL derruba o shader inteiro e o sleeve degrada calado pra
> "sem foil", que é difícil de distinguir de "foil sutil demais".

