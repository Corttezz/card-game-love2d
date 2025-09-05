# 🃏 CARD GAME

Um jogo de cartas estratégico desenvolvido em Lua usando o framework LÖVE2D, inspirado em jogos como Balatro.

## 🎮 Como Jogar

### **Objetivo**
Derrotar inimigos em fases consecutivas, construindo um deck estratégico com cartas de ataque, defesa e jokers passivos.

### **Controles**
- **MOUSE**: Selecionar cartas e navegar pela interface
- **ESPAÇO**: Comprar uma carta do deck
- **R**: Reiniciar o jogo (durante o gameplay)
- **ESC**: Voltar ao menu principal

### **Mecânicas do Jogo**

#### **Cartas de Ataque** ⚔️
- Causam dano direto aos inimigos
- Consomem mana para serem jogadas
- Podem ser afetadas por multiplicadores de dano

#### **Cartas de Defesa** 🛡️
- Adicionam armadura ao jogador
- Reduzem o dano recebido dos inimigos
- Consomem mana para serem jogadas

#### **Jokers (Cartas Passivas)** 🃏
- Ativam efeitos especiais quando jogadas
- Ocupam slots permanentes durante o jogo
- Exemplo: "God of the Abyss" dobra o dano de todas as cartas de ataque no turno

#### **Sistema de Turnos**
- **Seu Turno**: Selecione e jogue cartas
- **Turno do Inimigo**: O inimigo ataca automaticamente
- **Fim do Turno**: Mana é restaurada e uma carta é comprada

#### **Progressão**
- Cada fase tem um inimigo mais forte
- A cada 3 fases, sua vida é restaurada
- Vitória após completar 10 fases

## 🚀 Como Executar

### **Pré-requisitos**
- [LÖVE2D](https://love2d.org/) instalado no sistema

### **Instalação e Execução**

#### **Linux/WSL:**
```bash
# Instalar LÖVE2D
sudo apt update
sudo apt install love

# Navegar para a pasta do projeto
cd /caminho/para/card-game

# Executar o jogo
love .
```

#### **Windows:**
1. Baixe e instale o LÖVE2D
2. Navegue até a pasta do projeto
3. Execute: `love .` ou arraste a pasta para o executável do LÖVE2D

#### **macOS:**
```bash
# Instalar via Homebrew
brew install love

# Executar
love .
```

## 📁 Estrutura do Projeto

```
card-game/
├── src/                    # Código fonte principal
│   ├── Game.lua           # Lógica principal do jogo
│   ├── Player.lua         # Sistema do jogador
│   ├── Enemy.lua          # Sistema dos inimigos
│   ├── Card.lua           # Sistema base de cartas
│   ├── AttackCard.lua     # Cartas de ataque
│   ├── DefenseCard.lua    # Cartas de defesa
│   ├── JokerCard.lua      # Cartas joker (passivas)
│   └── MessageSystem.lua  # Sistema de mensagens
├── components/             # Componentes da interface
│   ├── Button.lua         # Botões interativos
│   ├── Menu.lua           # Menu principal
│   └── GameUI.lua         # Interface do gameplay
├── assets/                 # Recursos visuais
│   ├── cards/             # Imagens das cartas
│   │   ├── attack/        # Cartas de ataque
│   │   └── defense/       # Cartas de defesa
│   └── jokers/            # Imagens dos jokers
├── audio/                  # Arquivos de áudio
├── main.lua               # Arquivo principal
├── conf.lua               # Configurações do LÖVE2D
└── README.md              # Este arquivo
```

## 🎯 Características

- ✅ **Menu principal** com opções de jogo
- ✅ **Sistema de cartas** com ataque, defesa e jokers
- ✅ **Jokers passivos** como no Balatro
- ✅ **Sistema de fases** com inimigos progressivamente mais fortes
- ✅ **Interface polida** com barras de vida, armadura e mana
- ✅ **Sistema de mensagens** para feedback do jogador
- ✅ **Sistema de pontuação** baseado no dano causado
- ✅ **Efeitos visuais** e animações nas cartas
- ✅ **Sistema de turnos** estratégico

## 🔧 Desenvolvimento

### **Tecnologias Utilizadas**
- **Lua**: Linguagem de programação principal
- **LÖVE2D**: Framework para desenvolvimento de jogos 2D
- **Sistema de Componentes**: Arquitetura modular para fácil manutenção

### **Como Adicionar Novas Cartas**

1. **Carta de Ataque:**
```lua
table.insert(self.deck, AttackCard:new("Nome", custo, dano, subtipo, "caminho/imagem.png"))
```

2. **Carta de Defesa:**
```lua
table.insert(self.deck, DefenseCard:new("Nome", custo, defesa, subtipo, "caminho/imagem.png"))
```

3. **Joker:**
```lua
table.insert(self.deck, JokerCard:new("Nome", custo, função_efeito, subtipo, "caminho/imagem.png"))
```

### **Estrutura de um Joker**
```lua
function(game)
    -- Seu efeito aqui
    game.damageMultiplier = 2
    game:addMessage("Efeito ativado!", "success")
end
```

## 🎨 Personalização

- **Imagens**: Substitua as imagens em `assets/` para personalizar o visual
- **Sons**: Modifique os arquivos de áudio em `audio/` para novos efeitos sonoros
- **Cores**: Ajuste as cores nos componentes para diferentes temas
- **Dificuldade**: Modifique os valores de vida e dano dos inimigos em `src/Game.lua`

## 🐛 Solução de Problemas

### **Erro: "love: command not found"**
- Instale o LÖVE2D: `sudo apt install love` (Linux) ou baixe do site oficial

### **Jogo não inicia**
- Verifique se está na pasta correta
- Execute `love .` (com o ponto)
- Verifique se todos os arquivos estão presentes

### **Imagens não carregam**
- Verifique se os caminhos das imagens estão corretos
- Certifique-se de que as imagens existem na pasta `assets/`

## 📝 Licença

Este projeto é de código aberto e pode ser modificado e distribuído livremente.

## 🤝 Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para:
- Reportar bugs
- Sugerir novas funcionalidades
- Adicionar novas cartas
- Melhorar a interface
- Otimizar o código

---

**Divirta-se jogando! 🎮**



