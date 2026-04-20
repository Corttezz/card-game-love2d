---
name: Project Conventions
description: OOP via metatables, PT-BR, Config responsivo, Theme.Colors, print() como logger, sem deps externas
type: feedback
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
Regras de estilo e convenções observadas no código.

**Why:** manter consistência facilita review e evita introduzir padrões divergentes num codebase pequeno mas polido.

**How to apply — sempre que escrever código novo no projeto:**

1. **OOP via metatables:**
   ```lua
   local Klass = {}
   Klass.__index = Klass
   function Klass:new(...) 
       local instance = setmetatable({}, Klass)
       -- init
       return instance
   end
   ```
   Não introduzir libs de classe (middleclass, 30log, etc.) — o projeto é deliberadamente zero-dep.

2. **Idioma:** strings de UI, mensagens de jogo (`game:addMessage`), e prints de debug em **português (BR)**. Comentários em PT-BR também. Identificadores e nomes de API ficam em **inglês** (ex.: `playSelectedCards`, não `jogarCartasSelecionadas`).

3. **Layout responsivo:** **nunca** hard-code px absolutos. Use:
   - `Config.Utils.getResponsiveSize(ratio, maxSize, dimension)` para tamanhos.
   - `Config.Utils.getRelativePosition(ratio, screenSize)` para posições.
   - `love.graphics.getWidth() / getHeight()` direto para cálculos ad-hoc.
   - Ratios ficam em `Config.UI.*` (ex: `CARD_SPACING_RATIO = 0.15`).

4. **Cores:** sempre de `Theme.Colors.*`. Se precisar interpolar: `Theme.Utils.interpolateColor(c1, c2, t)`.

5. **Fontes:** `FontManager.getFont(size)` ou `FontManager.getResponsiveFont(ratio, maxSize)`. Nunca `love.graphics.newFont` direto em hot path.

6. **Áudio:** `_G.audioSystem:playSound("name")` checando `isAudioAvailable()` — nunca `love.audio.newSource` em código novo.

7. **Constantes centralizadas:** novas magic numbers de gameplay vão em `Config.Game.*`; de UI em `Config.UI.*`; de cartas (tilt, sombra, etc) em `Config.Cards.*`; de áudio em `Config.Audio.*`.

8. **Logging:** `print()` é o padrão. Não há logger estruturado. Mensagens de usuário no jogo passam por `game:addMessage(text, "info"|"success"|"warning"|"error")`.

9. **Validação de assets:** ao carregar imagem use `pcall(love.graphics.newImage, path)` com fallback para `"assets/cards/attack/theRock.png"`. Use `pcall` também para sons.

10. **Separação de UI:**
    - `components/` = telas completas e widgets "de aplicação" (Menu, Button, CardRewardScreen).
    - `src/ui/` = HUD, Theme, efeitos visuais reutilizáveis.
    - `src/core/Game.lua` = lógica de gameplay; não desenha nada diretamente.

11. **Ao adicionar carta**, edite `CardDatabase.lua` (data-driven). **Não** crie subclasses novas — os 4 tipos (attack/defense/joker/effect) cobrem tudo, diferenças vão em `card.effects`.

12. **Não duplique comportamento legado:** `src/MessageSystem.lua` é cópia antiga (ignore), `ClassSystem.lua` é deprecated (use CardRegistry), `EffectSystem:getCardData` com if `card.name == "X"` é anti-pattern (use `card.effects`).
