---
name: Resize Pattern (overlay screens responsivas)
description: Padrão obrigatório pra layouts cacheados — toda overlay screen DEVE recalcular positions em love.resize. Lista todas as telas + checklist + armadilhas.
type: project
---

# Resize Pattern — overlay screens responsivas

Toda overlay screen com cardPositions/button rects/container bounds cacheados
DEVE responder a `love.resize` reconstruindo o layout. Sem isso, ao maximizar a
janela vinda de uma resolução menor (ou vice-versa), os elementos ficam
posicionados nas coordenadas antigas — desalinhados, off-center, ou parcialmente
fora da tela.

**Why:** Love2D recria o canvas em resize e chama `love.resize(w, h)`, mas NÃO
re-executa nenhum código de layout dos componentes. Quem cacheou rects no
:show()/:new() fica com state stale.

**How to apply:** Sempre que adicionar uma nova overlay screen com positions
cacheados, garantir 3 coisas:

1. Expor método `resize()` (preferido) ou `updateLayout()` no componente.
2. Dentro do método, recalcular TUDO que foi cacheado em :show() — cardPositions,
   container rects, button x/y, font sizes derivados, etc.
3. Adicionar dispatch em `main.lua:love.resize()` chamando o método sob guard
   nil-safe (`if screen and screen.resize then screen:resize() end`).

## Telas auditadas (Apr/2026)

| Tela | Estratégia | Método |
|---|---|---|
| `Menu` | recalcula em update | `updatePositions()` |
| `ClassSelectionScreen` | recalcula em update | `updatePositions()` |
| `CardRewardScreen` | cacheia tudo em :show + detecta resize em update | `updateLayout()` + rebuild buttons |
| `PackOpenScreen` | cacheia em :show via `_layoutCards` | `resize()` re-roda `_layoutCards` + `_buildSkipButton` |
| `RestScreen` | rebuild buttons por mode | `resize()` chama `buildChooseButtons` ou `buildForgeButtons` |
| `EventScreen` | rebuild buttons | `resize()` chama `buildButtons` |
| `RoundEvalScreen` | DynaTexts + cashOutButton | `resize()` chama ambos |
| `CollectionScreen` | calc dinâmico por frame | `resize()` é stub no-op |
| `MapScreen` | layout dinâmico | `resize()` re-roda `updateLayout` |
| `TopBar` | recalc por frame | `resize()` |
| `SettingsMenu` | rebuild buttons | `rebuild()` quando visible |

## Centralização — armadilha comum

Bug recorrente: container tem largura X, cards ocupam Y < X, mas startX usa
`subPad + (i-1)*spacing` em vez de `(X - Y) / 2 + (i-1)*spacing`. Resultado:
cards ficam left-aligned com padding fixo na esquerda, e sobra à direita.

**Fix:** sempre computar
```
totalCardsW = n * cardW + (n-1) * spacing
startX = container.x + (container.w - totalCardsW) / 2
```

E NÃO subtrair subPad do cardWidth se já estamos centrando — isso reduz
cardWidth desnecessariamente e cria gap visível.

## Checklist quando adicionar novo overlay

- [ ] Layout method é idempotente (pode rodar várias vezes sem side-effect)?
- [ ] Lê `love.graphics.getWidth()/getHeight()` toda vez (não cacheia em :new)?
- [ ] Tem método `resize()` exposto?
- [ ] Adicionado em `main.lua:love.resize` com guard nil?
- [ ] Centralização usa formula `(container.w - totalW) / 2`, não padding fixo?
- [ ] Botões/buttons attached são reposicionados (x/y mutados) ou recriados?
- [ ] Testar: abrir overlay em 1024×768 → arrastar pra 1920×1080 → checar que
  todos elementos centralizam de novo e não ficam offset.

## Como testar manualmente

1. `love .` em fullscreen ou janela default.
2. Pressione `f` (toggle fullscreen) ou redimensione a janela.
3. Abra cada overlay (shop, pack open, rest, event, round eval).
4. Verifique que tudo recentralizou — não deve ter elemento "preso" no
   antigo canto.
