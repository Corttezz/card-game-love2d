# Sistema de Áudio - Card Game

## Problema Resolvido

O jogo estava executando sem som no WSL2 (Windows Subsystem for Linux) porque o WSL2 não tem acesso direto aos dispositivos de áudio do Windows por padrão.

## Solução Implementada

### 1. Sistema de Áudio Robusto (`src/systems/AudioSystem.lua`)

- **Detecção automática de WSL2**: O sistema detecta se está rodando no WSL2
- **Múltiplos backends de áudio**: Tenta usar diferentes backends (pulse, alsa, directsound)
- **Fallback gracioso**: Funciona mesmo sem áudio disponível
- **Cache inteligente**: Carrega sons uma vez e reutiliza
- **Controle de volume**: Volume separado para música e efeitos sonoros

### 2. Integração Completa

- **Música de fundo**: `audio/music.mp3` toca automaticamente
- **Efeitos sonoros**: Todos os sons do jogo funcionam
- **Sistema centralizado**: Um único ponto de controle para todo áudio
- **Compatibilidade**: Funciona tanto no WSL2 quanto em sistemas nativos

### 3. Recursos de Áudio

#### Sons Implementados:
- **Música de fundo**: `music.mp3` (loop contínuo)
- **Hover de carta**: `hoverCard.wav` (quando passa mouse sobre carta)
- **Seleção de carta**: `clickselect2-92097.mp3` (quando clica em carta)
- **Início do deck**: `deckStart.mp3` (quando inicia jogo)
- **Som de espada**: `sword-sound-260274.mp3` (ataques)
- **Som de armadura**: `punching-light-armour-87442.mp3` (defesas)

#### Controles de Volume:
- Volume geral: controla todo o áudio
- Volume da música: controla apenas música de fundo
- Volume dos efeitos: controla apenas sons de ação

## Como Usar

### Executar o Jogo
```bash
love .
```

### Verificar Status do Áudio
O sistema mostra automaticamente o status do áudio no console:
```
=== STATUS DO ÁUDIO ===
Disponível: ✓
WSL2: ✓
Volume geral: 1
Volume música: 0.3
Volume SFX: 0.7
Sons carregados: 5
Música tocando: ✓
========================
```

### Configurar Áudio no WSL2 (Opcional)

Se o áudio não estiver funcionando no WSL2, execute:
```bash
./setup-audio-wsl2.sh
```

Este script fornece instruções detalhadas para configurar PulseAudio no Windows e WSL2.

## Arquivos Modificados

1. **`src/systems/AudioSystem.lua`** - Novo sistema de áudio
2. **`main.lua`** - Integração do sistema de áudio
3. **`src/core/Game.lua`** - Uso do sistema centralizado
4. **`src/systems/CombatAnimationSystem.lua`** - Integração com áudio
5. **`src/cards/base/Card.lua`** - Som de hover centralizado
6. **`setup-audio-wsl2.sh`** - Script de configuração

## Benefícios

✅ **Funciona no WSL2**: Detecta e corrige problemas de áudio automaticamente
✅ **Música de fundo**: Adiciona atmosfera ao jogo
✅ **Efeitos sonoros**: Feedback auditivo para todas as ações
✅ **Performance**: Cache inteligente evita recarregar sons
✅ **Robustez**: Funciona mesmo sem áudio disponível
✅ **Compatibilidade**: Funciona em qualquer sistema operacional

## Troubleshooting

### Áudio não funciona no WSL2
1. Execute `./setup-audio-wsl2.sh` para instruções detalhadas
2. Verifique se o PulseAudio está instalado no Windows
3. Configure as variáveis de ambiente necessárias
4. Reinicie o WSL2 após configurações

### Sons não carregam
1. Verifique se os arquivos de áudio existem na pasta `audio/`
2. Verifique as permissões dos arquivos
3. Execute `love .` e observe as mensagens do console

### Volume muito baixo/alto
1. O sistema usa volumes configuráveis em `Config.Audio`
2. Ajuste os valores em `src/core/Config.lua`
3. Use as funções de controle de volume do `AudioSystem`

## Status do Projeto

🎵 **Áudio completamente implementado e funcional**
🔧 **Sistema robusto com fallbacks**
🎮 **Integração completa com o jogo**
📱 **Compatível com WSL2 e sistemas nativos**
