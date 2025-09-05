# CardInfoDisplay - Componente de Exibição de Informações de Cartas

## Visão Geral

O `CardInfoDisplay` é um componente reutilizável que centraliza a lógica de exibição de informações de cartas em todo o jogo. Ele elimina a duplicação de código e garante consistência visual entre diferentes telas.

## Características

- **Reutilizável**: Pode ser usado em qualquer tela que precise mostrar informações de cartas
- **Configurável**: Permite controlar quais informações são exibidas
- **Consistente**: Mantém o mesmo estilo visual em todo o jogo
- **Flexível**: Suporta diferentes posicionamentos e configurações
- **Estilo Balatro**: Painel retangular com fundo escuro e bordas arredondadas
- **Descrição Completa**: Exibe nome, descrição, raridade e estatísticas da carta

## Uso Básico

```lua
local CardInfoDisplay = require("src.ui.CardInfoDisplay")

-- Cria uma instância
local cardInfo = CardInfoDisplay:new()

-- Desenha as informações da carta
cardInfo:draw(cardInstance, x, y)
```

## Configuração

### Configuração Global

```lua
cardInfo:configure({
    showRarity = true,      -- Mostra raridade da carta
    showStats = true,       -- Mostra ataque/defesa/custo
    showDescription = false, -- Mostra descrição da carta
    textColor = {1, 1, 1, 1}, -- Cor do texto
    rarityColors = {        -- Cores para cada raridade
        common = {0.7, 0.7, 0.7},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.8, 0.2, 0.8},
        legendary = {0.8, 0.6, 0.2},
        basic = {0.5, 0.5, 0.5}
    }
})
```

### Configuração Local (por chamada)

```lua
cardInfo:draw(cardInstance, x, y, {
    showRarity = true,
    showStats = true,
    showDescription = false
})
```

## Métodos Disponíveis

### `draw(cardInstance, x, y, options)`
Desenha todas as informações da carta configuradas.

### `drawRarity(cardInstance, x, y, options)`
Desenha apenas a raridade da carta.

### `drawStats(cardInstance, x, y, options)`
Desenha apenas as estatísticas (ataque/defesa/custo).

### `drawName(cardInstance, x, y, options)`
Desenha apenas o nome da carta.

## Exemplos de Uso

### 1. Tela de Recompensas
```lua
-- Mostra raridade, estatísticas e descrição para escolha
self.cardInfoDisplay:draw(cardInstance, x, y, {
    showRarity = true,
    showStats = true,
    showDescription = true
})
```

### 2. Cartas na Mão
```lua
-- Mostra estatísticas e descrição no hover
self.cardInfoDisplay:draw(cardInstance, x, y, {
    showRarity = false,
    showStats = true,
    showDescription = true
})
```

### 3. Tela de Detalhes
```lua
-- Mostra todas as informações
self.cardInfoDisplay:draw(cardInstance, x, y, {
    showRarity = true,
    showStats = true,
    showDescription = true
})
```

## Integração com Classes Existentes

### CardRewardScreen
```lua
-- No construtor
self.cardInfoDisplay = CardInfoDisplay:new()

-- Na função de desenho
self.cardInfoDisplay:draw(cardInstance, x, y, {
    showRarity = true,
    showStats = true,
    showDescription = false
})
```

### Card (classe base)
```lua
-- No construtor
instance.cardInfoDisplay = CardInfoDisplay:new()

-- Na função de desenho
self.cardInfoDisplay:draw(self, x, y, {
    showRarity = false,
    showStats = true,
    showDescription = false
})
```

### JokerCard
```lua
-- No construtor
instance.cardInfoDisplay = CardInfoDisplay:new()

-- Na função de desenho
self.cardInfoDisplay:draw(self, x, y, {
    showRarity = false,
    showStats = true,
    showDescription = true
})
```

## Vantagens da Refatoração

1. **Eliminação de Duplicação**: Código repetido foi removido de múltiplas classes
2. **Manutenibilidade**: Mudanças no estilo visual são feitas em um só lugar
3. **Consistência**: Todas as telas usam o mesmo padrão visual
4. **Flexibilidade**: Fácil de configurar para diferentes contextos
5. **Testabilidade**: Componente isolado é mais fácil de testar

## Estrutura de Arquivos

```
src/ui/
├── CardInfoDisplay.lua          # Componente principal
├── CardInfoDisplayExample.lua   # Exemplos de uso
└── README_CardInfoDisplay.md    # Esta documentação
```

## Visual e Layout

O componente agora renderiza um painel retangular **ACIMA** da carta com:

```
┌─────────────────────────────────┐
│         ┌─────────────────────┐ │
│         │   Nome da Carta     │ │
│         │                     │ │
│         │ [Descrição com      │ │
│         │  quebra de linha    │ │
│         │  automática]        │ │
│         │                     │ │
│         │ [RARIDADE]          │ │
│         │ [Ataque] [Mana]     │ │
│         └─────────────────────┘ │
│                                 │
│            [Carta]              │
└─────────────────────────────────┘
```

**Características do novo layout:**

### Botão de Raridade Responsivo
```
┌─────────────────────────────────┐
│         ┌─────────────────────┐ │
│         │   Nome da Carta     │ │
│         │                     │ │
│         │ [Descrição com      │ │
│         │  quebra de linha]   │ │
│         │                     │ │
│         │ ┌─────────────┐     │ │ ← Largura ajustada ao texto
│         │ │  UNCOMMON   │     │ │
│         │ └─────────────┘     │ │
│         │ [Ataque] [Mana]     │ │
│         └─────────────────────┘ │
│                                 │
│            [Carta]              │
└─────────────────────────────────┘
```

**Funcionalidades do botão de raridade responsivo:**
- **Largura automática** baseada no tamanho do texto
- **Largura mínima** de 80px para consistência visual
- **Padding inteligente** de 20px para espaçamento adequado
- **Centralização automática** do texto no botão
- **Prevenção de overflow** - nunca sai da tela
- **Ajuste de posição** se necessário para caber na tela

- **Fundo escuro semi-transparente** com bordas arredondadas
- **Nome da carta** em branco no topo
- **Área de descrição** com fundo mais claro para destacar o texto
- **Botão de raridade responsivo** que se ajusta ao tamanho do texto
- **Estatísticas** com ícones (ataque, defesa, mana)
- **Posicionamento inteligente** que se adapta ao conteúdo
- **Quebra de linha responsiva** para descrições longas
- **Layout responsivo** que se adapta ao tamanho da tela
- **Posicionamento automático** acima da carta (ou abaixo se não couber)

### Cores de Raridade
- **Common**: Cinza claro
- **Uncommon**: Verde
- **Rare**: Roxo
- **Legendary**: Dourado
- **Basic**: Cinza médio

## Funcionalidades Avançadas

### Quebra de Linha Inteligente
- **Detecção automática** de palavras que não cabem na linha
- **Quebra responsiva** baseada no tamanho da fonte
- **Altura dinâmica** do painel baseada no conteúdo

### Layout Responsivo
- **Painel adaptativo** que se ajusta ao tamanho da tela
- **Posicionamento inteligente** que evita sair da tela
- **Fallback automático** para posicionamento abaixo se não couber acima
- **Botão de raridade responsivo** que se ajusta ao tamanho do texto

### Posicionamento Perfeito
- **Centralizado horizontalmente** acima da carta
- **Margens seguras** para evitar sair da tela
- **Ajuste automático** baseado no espaço disponível
- **Botão de raridade inteligente** que nunca sai da tela

## Próximos Passos

- Adicionar suporte a diferentes fontes
- Implementar animações de entrada/saída
- Adicionar suporte a temas visuais
- Criar testes unitários para o componente
- Adicionar suporte a palavras-chave destacadas na descrição
- Implementar transições suaves de posicionamento
