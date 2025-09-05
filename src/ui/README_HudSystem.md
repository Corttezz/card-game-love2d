# Sistema de HUD - Documentação

## 📖 **Visão Geral**

O **Sistema de HUD** é uma implementação moderna e componetizada para exibir informações de vida, armadura, mana do jogador e dados do inimigo (vida, dano, fase). O sistema foi projetado com estética moderna inspirada em CSS, utilizando gradientes, bordas arredondadas, efeitos de glow e animações sutis.

## ✨ **Características**

- **Design Moderno**: Inspirado em CSS com bordas arredondadas, gradientes e efeitos de vidro
- **Componetizado**: Sistema modular e reutilizável
- **Responsivo**: Se adapta automaticamente a diferentes resoluções
- **Animações Sutis**: Efeitos de glow, pulso e partículas
- **Performance Otimizada**: Renderização eficiente com cache de recursos
- **Temático**: Cores específicas para jogador (verde) e inimigo (vermelho)
- **Ícones Dinâmicos**: Ícones carregados de arquivos ou criados programaticamente

## 🏗️ **Arquitetura**

### **Componentes Principais**

1. **HudPanel** - Classe base para todos os painéis
2. **HudPlayerPanel** - Painel específico para o jogador
3. **HudEnemyPanel** - Painel específico para o inimigo
4. **HudManager** - Gerenciador que coordena todos os painéis

### **Hierarquia**

```
HudManager
├── HudPlayerPanel (extends HudPanel)
└── HudEnemyPanel (extends HudPanel)
```

## 📁 **Estrutura de Arquivos**

```
src/ui/
├── HudPanel.lua           ← Classe base
├── HudPlayerPanel.lua     ← Painel do jogador
├── HudEnemyPanel.lua      ← Painel do inimigo
├── HudManager.lua         ← Gerenciador principal
└── README_HudSystem.md    ← Esta documentação

components/
└── GameUI.lua             ← Integração com o sistema existente
```

## 🎨 **Design Visual**

### **HudPlayerPanel (Jogador)**
- **Posição**: Canto inferior esquerdo
- **Tema**: Verde (vida/crescimento)
- **Cores**:
  - Background: Verde escuro translúcido
  - Borda: Verde médio com efeito de glow
  - Texto: Verde muito claro
- **Informações**:
  - Vida (barra vermelha)
  - Armadura (barra azul acinzentada)
  - Mana (barra azul)

### **HudEnemyPanel (Inimigo)**
- **Posição**: Canto inferior direito
- **Tema**: Vermelho (perigo/agressão)
- **Cores**:
  - Background: Vermelho escuro translúcido
  - Borda: Vermelho médio com efeito de glow
  - Texto: Vermelho muito claro
- **Informações**:
  - Vida (barra vermelha)
  - Dano (texto com ícone)
  - Fase atual
  - Nível de ameaça (indicador visual)

### **Efeitos Visuais**

1. **Sombras**: Offset de 4px para profundidade
2. **Gradientes**: Verticais para backgrounds
3. **Glow**: Bordas com efeito de brilho pulsante
4. **Partículas**: Energia temática circulando os painéis
5. **Glass Effect**: Overlay translúcido no topo

## 🚀 **Uso**

### **Integração Básica**

```lua
-- No GameUI ou main
local HudManager = require("src.ui.HudManager")

-- Inicialização
local hudManager = HudManager:new()

-- No update loop
hudManager:update(dt)

-- No draw loop
hudManager:draw(game) -- game contém player e enemy
```

### **Configuração de Posições**

As posições são calculadas automaticamente baseadas na resolução:

```lua
-- Jogador (inferior esquerdo)
playerPanel.x = 2% da largura da tela
playerPanel.y = altura da tela - altura do painel - 2%

-- Inimigo (inferior direito)
enemyPanel.x = largura da tela - largura do painel - 2%
enemyPanel.y = altura da tela - altura do painel - 2%
```

### **Personalização de Cores**

```lua
-- Exemplo de customização
local customPanel = HudPanel:new(x, y, width, height, {
    backgroundColor = {0.1, 0.1, 0.1, 0.9},
    borderColor = {0.5, 0.5, 0.5, 0.8},
    accentColor = {1.0, 1.0, 0.0, 1.0}, -- Amarelo
    textColor = {1, 1, 1, 1}
})
```

## 🔧 **API Reference**

### **HudManager**

```lua
-- Construtor
HudManager:new()

-- Métodos principais
hudManager:update(dt)
hudManager:draw(game)
hudManager:show()
hudManager:hide()

-- Getters
hudManager:getPlayerPanel()
hudManager:getEnemyPanel()
```

### **HudPanel (Base)**

```lua
-- Construtor
HudPanel:new(x, y, width, height, options)

-- Métodos de desenho
panel:drawBackground()
panel:drawStatusBar(label, current, max, x, y, width, height, color)
panel:drawText(text, x, y, font, color)
panel:drawIcon(icon, x, y, scale, color)

-- Métodos de configuração
panel:setPosition(x, y)
panel:setSize(width, height)
panel:update(dt)
```

### **HudPlayerPanel**

```lua
-- Construtor
HudPlayerPanel:new(x, y, width, height)

-- Métodos específicos
panel:draw(player)
panel:updatePosition()
panel:getHealthPercentage(player)
panel:getArmorPercentage(player)
panel:getManaPercentage(player)
```

### **HudEnemyPanel**

```lua
-- Construtor
HudEnemyPanel:new(x, y, width, height)

-- Métodos específicos
panel:draw(enemy, currentPhase)
panel:updatePosition()
panel:getHealthPercentage(enemy)
panel:drawThreatLevel(phase, x, y)
```

## 📊 **Barras de Status**

### **Características**

- **Background**: Escuro com transparência
- **Gradiente**: Horizontal da cor base para cor clara
- **Highlight**: Brilho branco no topo
- **Bordas**: Arredondadas com efeito de glow
- **Números**: Formato "atual/máximo"
- **Animações**: Pulso sutil em barras preenchidas

### **Cores das Barras**

- **Vida**: Vermelho `{0.8, 0.3, 0.3, 1.0}`
- **Armadura**: Azul acinzentado `{0.6, 0.6, 0.8, 1.0}`
- **Mana**: Azul `{0.3, 0.5, 0.9, 1.0}`

## 🎭 **Ícones**

### **Sistema de Ícones**

O sistema tenta carregar ícones de arquivos PNG e, se não encontrar, cria ícones programaticamente:

```lua
-- Ícones carregados de arquivo
assets/icons/
├── armor.png
├── attack.png
└── mana.png

-- Ícones criados programaticamente
- health (coração)
- skull (caveira para inimigo)
```

### **Criação de Ícones Personalizados**

```lua
function Panel:createCustomIcon()
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    
    -- Desenhar seu ícone aqui
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", size/2, size/2, size/4)
    
    love.graphics.setCanvas()
    return canvas
end
```

## 🔄 **Responsividade**

### **Sistema Responsivo**

- **Posições**: Baseadas em percentuais da tela
- **Tamanhos**: Calculados dinamicamente
- **Fontes**: Escalas responsivas via FontManager
- **Espaçamentos**: Proporcionais ao tamanho da tela

### **Breakpoints**

```lua
-- Tamanhos responsivos
width = Config.Utils.getResponsiveSize(0.28, 280, "width")   -- 28% da largura
height = Config.Utils.getResponsiveSize(0.18, 140, "height") -- 18% da altura
```

## ⚡ **Performance**

### **Otimizações**

- **Cache de ícones**: Carregados uma vez na inicialização
- **Update seletivo**: Apenas quando visível
- **Desenho eficiente**: Uso mínimo de love.graphics calls
- **Partículas limitadas**: Máximo 3-5 partículas por painel

### **Monitoramento**

```lua
-- Para debug de performance
local startTime = love.timer.getTime()
hudManager:draw(game)
local endTime = love.timer.getTime()
print("HUD render time:", (endTime - startTime) * 1000, "ms")
```

## 🎯 **Casos de Uso**

### **Jogos de Cartas**
- Informações essenciais sempre visíveis
- Feedback visual de recursos (mana, vida)
- Estado do inimigo para estratégia

### **RPGs**
- Barras de status tradicionais
- Informações de combate
- Progressão visual

### **Jogos de Estratégia**
- Estado dos recursos
- Informações do oponente
- Feedback de ações

## 🛠️ **Customização Avançada**

### **Temas Personalizados**

```lua
-- Tema noturno
local nightTheme = {
    backgroundColor = {0.02, 0.02, 0.05, 0.98},
    borderColor = {0.1, 0.1, 0.3, 0.9},
    accentColor = {0.3, 0.3, 0.8, 1.0},
    textColor = {0.8, 0.8, 1.0, 1.0}
}

-- Tema dourado
local goldTheme = {
    backgroundColor = {0.1, 0.08, 0.02, 0.95},
    borderColor = {0.8, 0.6, 0.2, 0.8},
    accentColor = {1.0, 0.8, 0.2, 1.0},
    textColor = {1.0, 0.9, 0.7, 1.0}
}
```

### **Animações Personalizadas**

```lua
-- Override do método de partículas
function CustomPanel:drawParticleEffects()
    -- Suas animações personalizadas aqui
end
```

## 🔧 **Troubleshooting**

### **Problemas Comuns**

1. **Ícones não aparecem**
   - Verifique se os arquivos PNG existem
   - Ícones programáticos são criados automaticamente

2. **Posicionamento incorreto**
   - Chame `updatePosition()` após mudanças de resolução
   - Verifique cálculos responsivos

3. **Performance baixa**
   - Reduza número de partículas
   - Desative efeitos desnecessários

4. **Cores incorretas**
   - Verifique valores RGBA (0-1)
   - Confirme reset de cor após operações

---

**O Sistema de HUD oferece uma interface moderna, componetizada e altamente customizável para jogos que precisam de feedback visual elegante e profissional!** 🎮✨
