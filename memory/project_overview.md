---
name: Project Overview
description: Identidade do projeto card-game-love2d — tech stack, inspirações, idioma e escopo
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
Card game estratégico 2D em **Lua + LÖVE2D 11.3**, inspirado em **Slay the Spire** (deck dinâmico por classe, recompensas pós-batalha, raridades) e **Balatro** (jokers passivos, efeitos 3D em cartas, animações cinematográficas de combate).

**Why:** projeto de estudo/pessoal (indie) onde o dev valoriza polimento visual AAA e escalabilidade da base de cartas. UI e strings ficam em **português (BR)**. Inclui suporte robusto a WSL2 para áudio.

**How to apply:**
- Preserve PT-BR em strings de usuário e mensagens de debug (`print`).
- Ao propor refatorações, priorize clareza da máquina de estados e data-driven cards — não quebre o estilo Balatro 3D em `Card.lua`.
- Tecnologias: Lua 5.1 (LÖVE), sem dependências externas (tudo em repo). Não adicionar libs sem pedir.
- Classes principais: Warrior / Mage / Rogue. Fases até `VICTORY_PHASES = 10`.
- Há 3 docs auxiliares no root (`AUDIO_README.md`, `GUIA_NOVO_SISTEMA.md`, `SISTEMA_SLAY_THE_SPIRE.md`) — tratar como contexto, mas o código é a fonte de verdade.
