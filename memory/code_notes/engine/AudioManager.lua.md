---
name: code_notes/engine/AudioManager.lua
description: Comentários com decisão/regra/histórico colhidos de engine/AudioManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/AudioManager.lua`

Origem: `engine/AudioManager.lua` em `7dbdb60d` (17 de 45 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local AudioManager = {}`)

> engine/AudioManager.lua
> Gerencia reprodução de SFX e música. Inspirado em
> balatro-source/engine/sound_manager.lua.
>
> Diferenças vs Balatro:
> Síncrono (sem love.thread).
> Polifonia automática: cada SFX mantém pool de Source clones; instâncias
> ociosas são reaproveitadas, e quando todas estão tocando, clona uma nova.
> Modulação por grupo (master/music/sfx) aplicada em update(), não em
> loadSound() — permite mudar volume em runtime sem reload.
> API mantém compatibilidade com o AudioSystem antigo (loadSound, playSound,
> setMusicVolume, setSFXVolume, setVolume, isAudioAvailable, getStatus,
> printStatus, loadBackgroundMusic, playBackgroundMusic, stopBackgroundMusic,
> campos .musicVolume / .sfxVolume / .volume).

## L19 (em `AudioManager`, junto a `local MAX_CLONES_PER_SOUND = 8`)

> evita explosão de polifonia em loops descontrolados.

## L45-50 (em `AudioManager:new`, junto a `self.sources = {}`)

> Estrutura central: por code, mantém template (1ª source) + entry com
> pool de clones ativos.
> self.sources[code] = {
> template = Source, baseVolume, group, stream, basePitch, pitchVariation,
> instances = { Source, Source, ... }   -- inclui template como [1]
> }

## L58-60 (em `self.groups`, junto a `ambient = opts.ambientVolume or 1.0,`)

> AMBIENTE (clima da estrada + ambiente dos lugares): grupo próprio,
> slider "Ambiente" em Configurações. 1.0 = nível desenhado (já baixo
> — Config.Audio.AMBIENT_VOLUME entra no volume base de cada som).

## L64-65 (em `self.groups`, junto a `self.currentMusic = nil`)

> Music tracking: nome do code da música atualmente tocando + alvo de
> crossfade (nil = sem fade em curso).

## L69 (em `self.groups`, junto a `self.musicVolume = self.groups.music`)

> Compat: campos públicos lidos por SettingsMenu.

## L94-95 (em `AudioManager:_initializeAudio`, junto a `function AudioManager:loadSound(code, path, opts)`)

> Carrega um SFX/música. opts = { volume=1, group="sfx", stream=false,
> pitch=1, pitchVariation=0 }

## L125-126 (em `instances`, junto a `instGain       = setmetatable({}, { __mode = "k" }),`)

> ganho POR INSTÂNCIA (camas de ambiente com crossfade entre vozes
> do mesmo som). Fraco: instância ociosa não segura nada.

## L147-148 (em `acquireInstance`, junto a `local stolen = entry.instances[1]`)

> Se passou do limite, reusa a primeira (corta a mais antiga). Padrão
> consistente com voice-stealing em engines de áudio.

## L154-155 (em `acquireInstance`, junto a `if entry.stream then`)

> Streams (música) não devem ser clonadas — clone() de stream é caro e
> raramente é o que se quer (música simultânea é crossfade, não polifonia).

## L209-211 (em `AudioManager:play`, junto a `function AudioManager:setInstanceGain(code, src, g)`)

> Ganho de UMA instância (0..1) multiplicado sobre base×grupo×master — o
> update por frame respeita (antes reescrevia o volume de toda instância
> tocando, o que impedia fade por voz). nil/1 = sem ganho extra.

## L219 (em `AudioManager:setInstanceGain`, junto a `function AudioManager:playSound(name)`)

> Compat com a API antiga (Sfx.play -> playSound).

## L232 (em `AudioManager:playMusic`, junto a `local entry = self.sources[code]`)

> Já tocando essa música; só garante que está playing.

## L251-265 (em `AudioManager:playMusic`, junto a `local atual = self.currentMusic`)

> FAXINA ANTES DE TROCAR — sem isto, música SOBREPÕE música.
>
> O defeito (relatado pelo dono, Set/2026: "a música da forja continuou a
> sobrepor a música do ato"): o crossfade é UM só, guardado em
> `musicCrossfade`. Se uma troca nova chega antes de a anterior terminar
> — e isso é o caso comum, porque abrir a forja/picker troca de faixa e
> fechar troca de volta em poucos segundos, com fade de 2,5s — o registro
> do crossfade antigo era SUBSTITUÍDO e a faixa que estava saindo nunca
> recebia `stop()`. Ela ficava tocando para sempre no volume em que parou,
> e a partir daí duas (ou três) faixas somavam.
>
> A varredura é sobre TODAS as fontes do grupo `music`, e não só sobre o
> `from` do crossfade anterior, porque a sequência pode ter deixado mais
> de uma órfã (A→B→C rápido deixa A e B). Só sobrevivem a faixa que está
> saindo (vira o `from` do novo fade) e a que está entrando.

## L314 (em `AudioManager:stopMusic`, junto a `function AudioManager:loadBackgroundMusic(path)`)

> Compat: API antiga assumia 1 música única em self.backgroundMusic.

## L350-351 (em `AudioManager:setVolume`, junto a `function AudioManager:update(dt)`)

> Re-aplica volumes em todas instâncias ativas e processa crossfade de música.
> Também faz cleanup lazy de clones que terminaram.

## L390-392 (em `AudioManager:update`, junto a `i = i + 1`)

> Mantém template (i==1) sempre; clones ociosos podem ser
> removidos pra liberar memória — mas só se passaram muitas
> instâncias. Pra simplicidade, mantemos pool inteiro.

