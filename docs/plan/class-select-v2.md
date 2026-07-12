# Seleção de Classe v2 — "O Salão dos Heróis" (Jul/2026)

> Pedido do dono: a tela de classes está "meio estranha"; quer classes
> como PERSONAGENS (StS-style), com animação na escolha, bem apresentado,
> artes PixelLab animadas. Basear no que existe, melhorar.

## 1. Análise do que existe (leitura completa)

**As 3 classes diferem em 4 eixos:**
| Eixo | Warrior | Mage | Rogue |
|---|---|---|---|
| Passiva | Ímpeto (2+ ataques/turno → +1 Força na batalha) | Conduíte (começa com orbe Raio 4) | Toxinas (1º ataque/turno aplica 1 Veneno) |
| Starter | warrior_strike + warrior_defend | mage_zap + defense_001 | rogue_strike + rogue_defend |
| Pool | ~30 cartas strike/armor/thorn/strength | ~30 cartas orbs/magic/draw | ~30 cartas poison/cycle/exhaust |
| Arquétipos | Muralha, Berserker, Reflexo | Canalizador, Potion, Magia Pura | Venenoso, Ciclo, Exaurir (10 no total, memory/archetypes.md) |

**Problemas da tela atual (F4 do UI overhaul):** painéis informativos mas
sem PERSONAGEM (os avatares `assets/classes/*.png` do CardRegistry nem
existem em disco); ícone 48px genérico; zero animação; hover = lift 6px.

## 2. Design v2

**Heróis full-body animados via PixelLab** (v3 mode, 96px, side view,
sufixo de estilo obrigatório do projeto):
- warrior: cavaleiro em placas com montante rúnico + capa carmim
- mage: erudito arcano encapuzado com orbe âmbar na palma
- rogue: assassino de couro com adagas gêmeas + frascos de veneno

**Disco** (novo id "heroes/<classe>" no SpriteAnimation — basePath aceita
categoria): `assets/sprites/characters/heroes/<classe>/south.png` +
`animations/idle/south/*.png`. Instalação: `tools/install_hero_animation.sh`.

**Layout da tela** (3 colunas):
1. HERÓI grande (~scale 2.6, nearest) em cima, idle ping-pong rodando,
   spotlight radial âmbar sob os pés (mesma imagem de glow do menu).
2. Placa de nome + linha de cor da classe.
3. Chip de PASSIVA (nome + descrição — é o diferencial real).
4. Cartas iniciais em miniatura (CardFrame real, mantido).
5. Coluna com backing translúcido ink (linguagem do menu v2.1), não
   caixa Panel9 pesada.

**Interação:**
- Hover: herói dá um passo à frente (y+6, scale 2.6→2.85 suave),
  spotlight acende, placa realça âmbar.
- Clique: FLASH no herói + juice + partículas douradas + trava input,
  0.45s depois confirma (EventManager.after) — a escolha É um momento.
- Fallback gracioso: sem sprites instalados → ícone antigo (nada quebra).

## 3. Mais classes (proposta, NÃO neste patch)
O sistema aguenta N classes (CardRegistry + pools por raridade). Custo
real de uma 4ª classe: ~30 cartas novas (fluxo completo obrigatório:
arte + i18n ×5 + tags + balance — memory/card_creation_flow.md), passiva
nova no Game.lua, starter, testes. Candidata desenhada: "Templário"
(hybrid armor→damage, arquétipo Conversão já stub em archetypes.md).
Decisão do dono pendente.
