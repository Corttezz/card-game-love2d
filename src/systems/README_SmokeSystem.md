# Sistema de Smoke - Documentação

## 📖 **Visão Geral**

O **SmokeSystem** é um sistema de partículas que adiciona efeitos atmosféricos sutis ao fundo do jogo, criando uma atmosfera mais imersiva e profissional.

## ✨ **Características**

- **Efeitos sutis**: Opacidade muito baixa para não interferir no gameplay
- **Movimento vertical natural**: Partículas se movem principalmente para cima
- **4 texturas diferentes**: Usa todas as suas imagens PNG de smoke
- **Configurável**: Múltiplos presets para diferentes intensidades
- **Performance otimizada**: Máximo de 2-6 partículas ativas (muito reduzido)
- **Responsivo**: Se adapta a qualquer resolução de tela
- **Distribuição total**: Partículas aparecem por toda a tela (não apenas centro)
- **Fade in suave**: Aparecem gradualmente sem desaparecimento abrupto
- **Tamanho médio**: Partículas de tamanho equilibrado e visível
- **Movimento orgânico**: Movimento vertical com variação horizontal sutil
- **Rotação sutil**: Giro muito lento e natural
- **Saída natural**: Só desaparecem quando saem muito da tela

## 🎮 **Controles**

### **Teclas de Atalho (durante o gameplay):**

- **`1`** - Smoke muito sutil (5 partículas, opacidade 0.01-0.04)
- **`2`** - Smoke padrão (8 partículas, opacidade 0.02-0.08) ⭐ **RECOMENDADO**
- **`3`** - Smoke atmosférico (12 partículas, opacidade 0.015-0.06)
- **`4`** - Smoke intenso (15 partículas, opacidade 0.05-0.15)
- **`0`** - Desliga completamente o sistema de smoke

## 🔧 **Configurações**

### **Preset Padrão (Recomendado)**
```lua
{
    maxParticles = 4,        -- Máximo de partículas (muito reduzido)
    spawnRate = 2.0,         -- Nova partícula a cada 2.0 segundos
    minOpacity = 0.02,       -- Opacidade mínima (2%)
    maxOpacity = 0.08,       -- Opacidade máxima (8%)
    minSpeed = 15,           -- Velocidade mínima (movimento suave)
    maxSpeed = 25,           -- Velocidade máxima (movimento suave)
    windEffect = 0.3,        -- Efeito de vento sutil
    centerZone = 1.0,        -- Zona da tela (100% - toda a tela)
    minScale = 1.2,          -- Escala mínima (tamanho equilibrado)
    maxScale = 2.0,          -- Escala máxima (tamanho equilibrado)
    fadeInTime = 1.5,        -- Fade in mais lento
    maxOffscreenDistance = 200 -- Só remove quando sai muito da tela
}
```

### **Preset Sutil**
- **5 partículas** com opacidade **0.01-0.04**
- Ideal para jogos que precisam de efeitos mínimos

### **Preset Atmosférico**
- **12 partículas** com opacidade **0.015-0.06**
- Equilibrio entre sutileza e presença

### **Preset Intenso**
- **15 partículas** com opacidade **0.05-0.15**
- Para momentos dramáticos ou cutscenes

## 📁 **Estrutura de Arquivos**

```
assets/effects/
├── smoke1.png     ← Textura de smoke 1
├── smoke2.png     ← Textura de smoke 2
├── smoke3.png     ← Textura de smoke 3
└── smoke4.png     ← Textura de smoke 4

src/systems/
├── SmokeSystem.lua        ← Sistema principal
└── README_SmokeSystem.md  ← Esta documentação

src/config/
└── SmokeConfig.lua        ← Configurações e presets
```

## 🚀 **Como Funciona**

### **1. Inicialização**
- Carrega as 4 texturas PNG de smoke
- Aplica configuração padrão (sutil)
- Inicializa sistema de partículas

### **2. Update Loop**
- Spawn de novas partículas na zona central da tela
- Movimento das partículas em todas as direções (aleatório)
- Fade in suave e rápido (1-1.5 segundos)
- Crescimento sutil das partículas
- Movimento contínuo com efeito de vento
- Rotação contínua para variedade visual
- Remoção apenas quando saem muito da tela

### **3. Renderização**
- Desenha partículas com opacidade e escala calculadas
- Posicionamento atrás das cartas (não interfere no gameplay)
- Rotação aleatória para variedade visual

## 🎨 **Personalização**

### **Criar Novo Preset**
```lua
-- No SmokeConfig.lua
SmokeConfig.CUSTOM = {
    maxParticles = 10,
    spawnRate = 0.6,
    minOpacity = 0.03,
    maxOpacity = 0.10,
    -- ... outras configurações
}
```

### **Aplicar Configuração Personalizada**
```lua
-- No seu código
SmokeConfig.applyToSystem(smokeSystem, "custom")
```

## 🔍 **Debug e Monitoramento**

### **Ver Estatísticas**
```lua
local stats = smokeSystem:getStats()
print("Partículas ativas:", stats.activeParticles)
print("Texturas carregadas:", stats.texturesLoaded)
```

### **Limpar Sistema**
```lua
smokeSystem:clear() -- Remove todas as partículas
```

## ⚠️ **Considerações de Performance**

- **Máximo recomendado**: 15 partículas simultâneas
- **Opacidade baixa**: Não afeta performance significativamente
- **Cache de texturas**: Carregadas uma vez no início
- **Update otimizado**: Apenas partículas ativas são processadas

## 🎯 **Casos de Uso**

### **Jogo Normal**
- Use preset **"default"** ou **"subtle"**
- Efeito sutil que não distrai

### **Momentos Especiais**
- Use preset **"atmospheric"** para transições
- Use preset **"intense"** para boss fights

### **Cutscenes**
- Use preset **"intense"** para drama
- Desligue com **"0"** para cenas limpas

## 🌟 **Dicas de Uso**

1. **Comece sutil**: Use preset "default" como base
2. **Teste diferentes**: Use as teclas 1-4 para encontrar o ideal
3. **Adapte ao momento**: Mude presets conforme a situação
4. **Monitore performance**: Se houver lag, reduza para preset "subtle"
5. **Considere o tema**: Smoke escuro para jogos sombrios, claro para alegres

## 🔧 **Solução de Problemas**

### **Smoke não aparece**
- Verifique se as imagens PNG estão em `assets/effects/`
- Pressione tecla `2` para resetar configuração
- Verifique console para mensagens de erro

### **Performance baixa**
- Use preset "subtle" (tecla `1`)
- Reduza `maxParticles` no código
- Verifique se outras partículas não estão sobrecarregando

### **Smoke muito intenso**
- Use preset "subtle" (tecla `1`)
- Ou desligue completamente (tecla `0`)

---

**O sistema de smoke está configurado para ser sutil e não interferir no gameplay, mas pode ser facilmente ajustado conforme suas necessidades!** 🎨✨
