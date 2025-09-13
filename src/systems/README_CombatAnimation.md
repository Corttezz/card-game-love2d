# Sistema de Animação de Combate - Estilo Balatro

## 📖 **Visão Geral**

O **Sistema de Animação de Combate** transforma a jogabilidade monótona em uma experiência visual espetacular, onde cada carta selecionada voa dramaticamente para o centro da tela e é processada individualmente com efeitos visuais impressionantes.

## ✨ **Características Principais**

### 🎬 **Fases da Animação**

1. **Cards Flying** - Cartas voam da mão para o centro
2. **Processing** - Cada carta é processada individualmente  
3. **Damage Dealing** - Números de dano são exibidos
4. **Complete** - Cartas desaparecem com fade-out

### 🎯 **Efeitos Visuais**

- **Movimento suave** com easing Out-Quart
- **Rotação dinâmica** de cada carta
- **Escala aumentada** no centro (1.3x)
- **Glow pulsante** durante processamento
- **Números de dano** flutuantes coloridos
- **Textos de efeito** descritivos
- **Fundo escurecido** para foco

## 🏗️ **Arquitetura**

### **Componentes**
- `CombatAnimationSystem.lua` - Sistema principal
- `Game.lua` - Integração com lógica de jogo
- `main.lua` - Update e draw loops

### **Estados**
```lua
"idle"           -- Sistema inativo
"cards_flying"   -- Cartas voando para centro
"processing"     -- Processando cada carta
"damage_dealing" -- Mostrando danos acumulados
"complete"       -- Finalizando animação
```

## 🎮 **Fluxo de Funcionamento**

### **1. Início do Combate**
```lua
game.combatAnimationSystem:startCombat(
    selectedCards,
    onComplete,     -- Callback de conclusão
    onCardProcessed -- Callback por carta
)
```

### **2. Voo das Cartas**
- Cartas voam em sequência (intervalo de 0.3s)
- Movimento suave para posições calculadas no centro
- Cada carta ganha glow e escala aumentada

### **3. Processamento Individual**
- Cada carta é processada separadamente
- Efeitos visuais específicos por tipo:
  - **Ataque**: Números vermelhos de dano
  - **Defesa**: Números azuis de bloqueio  
  - **Joker**: Efeitos especiais

### **4. Finalização**
- Fade-out das cartas com rotação
- Callback de conclusão
- Retorno ao jogo normal

## 🎨 **Configurações Visuais**

### **Timing**
```lua
timings = {
    cardFly = 0.6,        -- Tempo de voo
    cardProcess = 1.2,    -- Processamento  
    damageShow = 0.8,     -- Exibição de dano
    cardInterval = 0.3    -- Intervalo entre cartas
}
```

### **Posicionamento**
- **Centro da tela**: Ponto focal principal
- **Espaçamento**: 150px entre cartas
- **Offset vertical**: -50px do centro

### **Cores dos Efeitos**
- **Dano**: `{1, 0.3, 0.3}` (Vermelho)
- **Bloqueio**: `{0.3, 0.7, 1}` (Azul)
- **Nomes**: `{1, 1, 0.8}` (Amarelo claro)

## 🔧 **API Reference**

### **CombatAnimationSystem**

#### **Construtor**
```lua
local system = CombatAnimationSystem:new()
```

#### **Métodos Principais**
```lua
-- Inicia combate
system:startCombat(cards, onComplete, onCardProcessed)

-- Atualiza animação
system:update(dt)

-- Desenha efeitos
system:draw()

-- Verifica se está ativo
local isActive = system:isAnimating()
```

#### **Callbacks**
```lua
-- Processamento de carta
function onCardProcessed(card)
    local result = {}
    
    if card.type == "attack" then
        result.damage = calculateDamage(card)
    elseif card.type == "defense" then  
        result.defense = calculateDefense(card)
    end
    
    return result
end

-- Conclusão do combate
function onComplete()
    -- Limpar seleções
    -- Próximo turno
end
```

## 💡 **Integração**

### **Game.lua**
```lua
-- Inicialização
instance.combatAnimationSystem = CombatAnimationSystem:new()

-- Substituir processamento direto
function Game:playSelectedCards()
    self.combatAnimationSystem:startCombat(
        self.selectedCards,
        function() self:onCombatAnimationComplete() end,
        function(card) return self:processCardInCombat(card) end
    )
end
```

### **main.lua**
```lua
-- Update loop
function updateGame(dt)
    game.combatAnimationSystem:update(dt)
    -- ... resto do update
end

-- Draw loop  
function drawGame()
    -- ... desenha jogo base
    game.combatAnimationSystem:draw() -- Por cima de tudo
end
```

## 🎯 **Recursos Avançados**

### **Easing Suave**
- **Out-Quart**: `1 - (1-t)⁴` para movimento natural
- **Aceleração inicial** rápida
- **Desaceleração gradual** no destino

### **Efeitos Dinâmicos**
- **Glow crescente** conforme carta se aproxima
- **Pulso durante processamento** com math.sin()
- **Rotação aleatória** para dinamismo
- **Escala responsiva** baseada na tela

### **Números Flutuantes**
- **Movimento vertical** ascendente
- **Fade-out gradual** baseado na vida
- **Cores temáticas** por tipo de efeito
- **Tamanhos responsivos** baseados na tela

## 🚀 **Benefícios**

### **Experiência do Jogador**
- ✅ **Feedback visual claro** de cada ação
- ✅ **Sensação de impacto** nas jogadas
- ✅ **Tempo para processar** resultados
- ✅ **Estilo visual profissional**

### **Gameplay**
- ✅ **Compreensão melhor** dos efeitos
- ✅ **Antecipação** e suspense
- ✅ **Satisfação** ao ver dano acumular
- ✅ **Clareza** no que cada carta faz

### **Técnico**
- ✅ **Performance otimizada** com cache
- ✅ **Callbacks flexíveis** para extensão
- ✅ **Estados bem definidos** para debug
- ✅ **Integração limpa** com sistema existente

## 🎭 **Exemplos de Uso**

### **Combo de Ataque**
```
[Carta 1] --> [Voa] --> [10 Dano] 
[Carta 2] --> [Voa] --> [15 Dano]
[Carta 3] --> [Voa] --> [8 Dano]
Total: 33 de Dano!
```

### **Defesa + Ataque**
```
[Escudo] --> [Voa] --> [+12 Bloqueio]
[Espada] --> [Voa] --> [20 Dano]
```

### **Ativação de Joker**
```
[Joker] --> [Voa] --> [Efeito Especial!]
```

## 🔮 **Possíveis Extensões**

- **Efeitos de combo** para cartas relacionadas
- **Animações específicas** por carta única
- **Partículas** para efeitos especiais
- **Som sincronizado** com animações
- **Câmera shake** para impactos maiores
- **Slow motion** para momentos épicos

---

**O Sistema de Animação de Combate transforma cada jogada em um momento cinematográfico épico, elevando a experiência do jogo a um nível AAA!** 🎬⚔️✨




