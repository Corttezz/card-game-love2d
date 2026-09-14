-- src/systems/ResumeFlow.lua
-- O que o CONTINUAR precisa reconstruir ALÉM do que está no save.
--
-- O save guarda o `currentRun` inteiro — inclusive `currentNode` — então o
-- ANDAR, o NÓ e o inimigo voltam certos (Game:resumeRun). O que NÃO volta é o
-- estado de CENA: a cena do combate não é função só do nó, é função do nó
-- MAIS o que a cutscene de chegada já encenou. Esse "já encenou" mora numa
-- local de módulo do GameplayScene (`bossEntered`), que nasce `false` a cada
-- `setGame` — e no Continuar nenhuma viagem dispara (o mundo já é ancorado no
-- andar salvo por `resumeWorld`), logo `enterCastle` nunca roda e a flag
-- nunca vira `true`.
--
-- Resultado, com captura do dono (Set/2026): retomar DENTRO da luta do chefe
-- do ato 2 mostrava o lich plantado no MEIO DA ESTRADA — grama, pinheiros,
-- castelo ao longe — em vez do salão. O chefe estava certo (sprite e 220 de
-- vida vieram do nó salvo); o CENÁRIO é que ficou preso no default.
--
-- A regra que este módulo encapsula: **retomar dentro da luta do chefe é
-- retomar DENTRO do salão** — a porta já foi aberta antes do save, e repetir
-- a cerimônia (ou pior, não mostrar o salão) é quebrar a continuidade que o
-- jogador viu. Elite e mini-boss ficam de fora DE PROPÓSITO: eles lutam na
-- ESTRADA (memory/enemy_pose_and_scene_anchor.md — "o hall é o clímax do
-- ato"), então para eles a estrada do resume já é a cena certa.
--
-- Mora fora do GameplayScene (e fora do callback do menu) para ser
-- TESTÁVEL: `plan` é pura e `apply` recebe a cena por injeção, de modo que
-- `tools/test_resume.lua` mede a decisão sem contexto gráfico nenhum.

local ResumeFlow = {}

-- PURA: o que a cena precisa saber para retomar no lugar certo.
--
-- `atFork` importa porque `currentNode` NÃO é limpo quando a encruzilhada
-- abre (showMapSelection só gera `pendingNodes`): salvar na bifurcação logo
-- depois de matar o chefe deixa `currentNode.type == "boss"` como resíduo do
-- nó JÁ resolvido. Sem esta guarda, o Continuar na encruzilhada abriria o
-- salão do castelo no lugar da estrada que se bifurca — trocar um defeito
-- por outro.
function ResumeFlow.plan(run)
    local node = run and run.currentNode
    local pending = run and run.pendingNodes
    local atFork = (pending ~= nil and #pending > 0)
    local nodeType = node and node.type
    return {
        nodeType = nodeType,
        atFork = atFork,
        -- true = a cena de combate tem que ser o SALÃO, já entrado.
        bossInterior = (nodeType == "boss") and not atFork,
    }
end

-- Aplica o plano na cena. `scene` é injetável só para teste; em produção é o
-- GameplayScene. Devolve o plano para quem quiser logar/decidir depois.
function ResumeFlow.apply(game, scene)
    scene = scene or require("src.scenes.GameplayScene")
    local run = game and game.runManager and game.runManager.currentRun
    local plan = ResumeFlow.plan(run)

    -- Mundo (bioma/câmera/entardecer) + âncora do andar. Ver o comentário
    -- de GameplayScene.resumeWorld: sem ancorar o andar, a caminhada até o
    -- nó escolhido nunca dispara.
    if scene.resumeWorld then scene.resumeWorld(game) end

    if plan.bossInterior and scene._debugForceBossEntered then
        -- Salta a cerimônia da porta e entrega o salão direto. É a MESMA
        -- porta que as ferramentas de captura usam; o nome ainda diz
        -- "_debug" porque renomeá-lo é uma edição no GameplayScene, que
        -- está sob outra frente nesta sessão (ver relatório).
        scene._debugForceBossEntered()
    end

    return plan
end

return ResumeFlow
