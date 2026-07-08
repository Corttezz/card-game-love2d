# Gameplay Overhaul v1 — jogabilidade real, score vivo, conquistas

> **Status:** EM EXECUÇÃO (Jul/2026) — F0 ✅ (honestidade das cartas),
> F1 ✅ (descarte de mão + block zera + intents do inimigo),
> F2 ✅ (fúria anti-stall + curas exaurem + folha única + mana 25),
> F3 ✅ (ScoreSystem TINTA×SELO + TopBar vivo + banner RoundEval + recorde
> no perfil + EndScreens), F4 ✅ (20 conquistas + AchievementSystem +
> galeria via botão CONQUISTAS no menu), F5 parcial (balance pass numérico:
> bash 8→10, fireball 9→11, rake 4→6, blur 5→7, power_through 15→12).
> Pendentes de F5: keywords/glossário no hover (orbs nunca explicados),
> tags decorativas consumidas ou removidas, combos cross-classe, forja
> visível no CardFrame. Baseado em 3 auditorias (carta-a-carta,
> loop sistêmico, dossiê Balatro/StS/Monster Train — ver §Apêndices).
> Pedido do dono: "hoje eu só mando todas as cartas da mão, boto armadura
> infinita, me curo com poção e dá tudo certo — quero jogabilidade real,
> desafio real, score na tela estilo Balatro, endless com recorde, cartas
> que conversem entre si, descrições que refletem o que a carta faz,
> conquistas como as do Balatro."

---

## 0. Diagnóstico em uma frase

O jogo dá ~11 de dano-ou-armor por mana **com prêmio de combo por jogar tudo**,
contra um inimigo que só faz UMA coisa (dano flat 100% anulável por 1-2 cartas
de defesa), sem descarte de mão, sem clock de batalha, com cura comum
reciclável ao infinito e o dobro do ouro necessário — **"jogar tudo, sempre"
não é exploit, é o ótimo global que o sistema define.** Além disso, 8 cartas
"Exaurir" não exaurem (bug), 14 cartas mentem na descrição e ~20 tags não
fazem nada.

## 1. As fases (ordem de execução)

### F0 — Honestidade das cartas (bugs de verdade) ✅ prioridade máxima
Descrição TEM que ser contrato. Correções:
1. **Exhaust nunca dispara** (8 cartas): `CardDatabase:createCardInstance`
   deriva `instance.exhaust = true` quando `effects` contém
   `{type="exhaust"}`. Reativa `_exhaustedThisBattle` + remoção da run.
2. `mage_machine_learning`: `draw_cards` (roda 1× na compra) →
   `on_turn_start_draw`; remover `innate` (sem sentido em joker).
3. `mage_sages_gem`: adicionar o `on_turn_start_draw 1` prometido.
4. `warrior_bloodletting`: implementar effect novo `self_damage` (perde HP
   direto, ignora armor) — a carta promete "Perde 3 HP".
5. `warrior_berserk`: `damage_per_turn` deve ignorar armor (HP loss direto).
6. `mage_fission`: descrição → "+1 mana" (comportamento real).
7. `mage_electrodynamics`: descrição → "+2 dano em ataques" (não fala de orb).
8. `warrior_second_wind`/`rogue_calculated_gamble`: descrição diz o que o
   código faz (descarte aleatório, valores fixos).
9. `warrior_plate_mail`/`mage_consume`: "permanente"/"temporário" → "nesta
   batalha" (vida útil real).
10. `warrior_spot_weakness`: tag `weak` → `vulnerable`.
11. Meta-texto vazando ("Tag #strike para combos") removido das descrições.
12. Durações nos textos: poison/weak/vulnerable sempre com "(N turnos)".

### F1 — As três alavancas que criam decisão (o coração)
1. **Mão descarta no fim do turno** (exceto `retain` — flag já existe e
   vira mecânica real). Draw fixo 5/turno. Remove draw de emergência +3.
   → nasce o dilema "jogo agora ou perco a carta".
2. **Armor zera no início do turno do jogador** (fim do banco de 50).
   Cap 50→30. → defesa vira decisão POR TURNO, lida com o intent do inimigo.
3. **Intents do inimigo** (Enemy ganha script de comportamento): ciclo
   telegrafado ataque / ataque_forte ×1.6 / defender +armor / buff +2 dmg
   perm / debuff weak no player. `EnemyHud` JÁ desenha ícone de intent —
   passa a mostrar o intent REAL do próximo turno + número.
   Elites abrem com buff; bosses têm gimmick por ato (a1: cura 8/turno,
   a2: multi-hit 3×, a3: weak a cada 3 turnos).

### F2 — Clock e economia (stall morre, ouro dói)
1. **Fúria anti-stall**: a partir do turno 6 o inimigo ganha +2 dmg/turno
   cumulativo (comunicado com pill "Fúria").
2. **Cura exaure**: potions/curas common ganham `{type="exhaust"}` (agora
   funciona, F0.1).
3. **Uma folha de pagamento**: matar `earnBattleGold` do `nextPhase`
   (RoundEval já paga 5+3+juros). `consecutiveWins` real em vez de
   `currentPhase`.
4. `mana_upgrade`: 8→25 ouro, máx 2 por run.

### F3 — Score "Tinta × Selo" (Balatro chips×mult) + recorde na tela
```
ScoreBatalha = floor(TINTA × SELO)
TINTA = maxHP inimigo + 10·andar + 50·(ato-1)   [×2 boss, ×1.25 elite,
                                                 ×1.18^n no endless]
SELO  = 1.0
  + 0.30 por turno abaixo do par (par = 3+ato)   [eficiência]
  − 0.10 por turno acima (piso ×0.5)
  + 0.25 por combo de tag DISTINTO na batalha     [estilo]
  + 0.50 se 3+ combos no MESMO turno
  + 0.50 terminou com HP ≤ 25%                    [risco]
  + 1.00 flawless (zero dano tomado)
```
- `src/systems/ScoreSystem.lua`: acumula por batalha via turnContext/combos.
- **TopBar**: `✒ 12.480` ao lado do ouro; hover → tooltip com última
  batalha / run / recorde. Tint dourado ao cruzar o recorde + toast único.
- **RoundEval**: banner "TINTA 240 × SELO 2.3 = 552" com contagem
  incremental (EventManager + juice_up) — único momento de celebração.
- Recorde em ProfileStats (`bestScore`); EndScreens mostram run vs recorde.
- Endless vira o motivo de existir do score (recorde = "até onde fui").

### F4 — Conquistas (20, temáticas grimório)
`src/systems/AchievementSystem.lua` + `src/data/achievements.lua`,
persistência no ProfileStats (`achievements = {id=true}`), toast dourado ao
desbloquear, galeria na Collection. Lista completa no dossiê (§A3):
Primeira Página, Trindade do Grimório, O Capítulo Final, Além da Última
Página (endless 10), Escriba Incansável (2500 cartas), Grimório de Bolso
(deck ≤6), Enciclopédia Ambulante (30+), Voto de Pobreza (sem loja),
Asceta (sem joker), Tinta Crua (só commons), Sem Rascunhos (sem forja),
Relâmpago Selado (win turno 1), Fio da Navalha (1 HP), Imaculado (boss sem
dano), Miasma (15+ poison), Muralha do Escriba (armor cap num turno),
Tinta Viva (4 combos no turno), Dez Mil Velas (10k score, escadinha
100k/1M no endless), Bibliotecário (96 cartas vistas), Ferreiro-Mor
(25 forjas). Checks alimentados por turnContext/Game/ProfileStats — sem
telemetria nova.

### F5 — Cartas que conversam (pós-rebalance)
1. Tags decorativas ganham consumo ou morrem do catálogo (`combo`, `cycle`,
   `zero_cost`...). "Combo-starter" precisa FAZER algo (ex: tag `combo`
   conta como 2 pra regras de contagem).
2. Novos combos cross-classe possíveis (cycle_motion pro mage exige 1 carta
   discard no pool mage; thorn pro rogue).
3. Keywords sublinhadas nas descrições (Veneno, Fraco, Vulnerável, Orbe,
   Exaurir) com glossário no hover (CardInfoDisplay) — resolve "orbs jamais
   explicados".
4. Balance pass numérico: nerf backstab/adrenaline/power_through/
   bloodletting; buff bash/fireball/rake/blur (tabela na auditoria §4).
5. Upgrade de forja VISÍVEL na carta (+N já salvo em run.upgraded — mostrar
   no CardFrame com selo verde e stats upadas).

## 2. Critério de aceite (o teste do dono)
Jogar o ato 1 e sentir: (a) turnos onde NÃO jogar tudo é melhor; (b) intents
mudando o que eu jogo; (c) cura acabando; (d) score subindo na TopBar e
vontade de bater o recorde no endless; (e) toda carta faz o que diz.

## 3. Apêndices — relatórios completos
- A1: Auditoria carta-a-carta (agente, Jul/2026) — 96 cartas, 8 exhaust
  quebrados, 14 mentirosas, ~20 tags mortas, custo-benefício por classe.
- A2: Diagnóstico sistêmico — a matemática do "spam ótimo", 10 alavancas.
- A3: Dossiê Balatro — 31 conquistas, score chips×mult, endless
  super-exponencial, fórmula Tinta×Selo, 20 conquistas PT-BR.
(Os três estão no transcript da sessão; os essenciais foram incorporados
acima. Este doc é a fonte canônica do redesign.)
