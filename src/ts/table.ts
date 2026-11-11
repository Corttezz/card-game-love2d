// Mini-mesa: uma mão de verdade do Guerreiro. Regras de combo idênticas às do jogo
// (src/systems/ComboSystem.lua): bônus = passo × min(cartas anteriores, teto); carta com a tag COMBO conta 2 na fila.
type Card = { id: string; name: string; desc: string; cost: number; type: string; atk: number; def: number; combo: boolean; rarity: string; spr: string };
type Combo = { id: string; name: string; step: number; cap: number };
type TableData = { mana: number; hand: Card[]; foe: { name: string; spr: string; hp: number; intent: number }; combos: Combo[]; comboTag: string; block: string; damage: string };
type Hooks = { sfx: (src: string) => void; tilt: (els: HTMLElement[]) => void; confetti?: (x: number, y: number) => void; sfxMap?: Record<string, string> };

const $ = (s: string) => document.querySelector(s) as HTMLElement | null;

export function resolve(order: Card[], combos: Combo[]) {
  const rule = (id: string) => combos.find((c) => c.id === id)!;
  return order.map((c, i) => {
    const before = order.slice(0, i);
    let bonus = 0;
    const hits: { name: string; v: number }[] = [];
    const kind = c.type === 'attack' ? 'volley' : c.type === 'defense' ? 'wall' : '';
    if (kind) {
      const r = rule(kind);
      const n = before.filter((b) => b.type === c.type).reduce((s, b) => s + (b.combo ? 2 : 1), 0);
      if (n > 0) { const v = r.step * Math.min(n, r.cap); bonus += v; hits.push({ name: r.name, v }); }
    }
    if (c.type === 'attack' || c.type === 'defense') {
      const r = rule('pair');
      const n = before.filter((b) => b.id === c.id).length;
      if (n > 0) { const v = r.step * Math.min(n, r.cap); bonus += v; hits.push({ name: r.name, v }); }
    }
    const dmg = c.type === 'attack' ? c.atk + bonus : 0;
    const blk = c.type === 'defense' ? c.def + bonus : 0;
    return { card: c, dmg, blk, hits };
  });
}

export function initTable(D: TableData, t: Record<string, string>, hooks: Hooks) {
  const root = $('#table');
  if (!root || !D) return;
  let order: number[] = [];
  let hp = D.foe.hp;
  let busy = false;
  let hand = D.hand.map((c, i) => ({ c, i }));
  const handEl = $('#hand')!, laneEl = $('#lane')!, manaEl = $('#mana')!, logEl = $('#t-log')!, callout = $('#callout')!;
  const hpEl = $('#foe-hp')!, foe = root.querySelector('.foe') as HTMLElement;
  $('#foe-name')!.textContent = D.foe.name;
  const fspr = $('#foe-spr')!; fspr.className = `spr sprite ${D.foe.spr}`;
  $('#intent-v')!.textContent = String(D.foe.intent);
  const sfx = (k: string) => hooks.sfxMap?.[k] && hooks.sfx(hooks.sfxMap[k]);

  const cardEl = (c: Card, idx: number) => {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'card' + (c.rarity === 'legendary' ? ' holo' : ''); b.dataset.rarity = c.rarity; b.dataset.idx = String(idx);
    b.setAttribute('aria-pressed', 'false');
    b.innerHTML = `<span class="face"><span class="cost"><span>${c.cost}</span></span><span class="order"></span><span class="name"></span><i class="art spr ${c.spr}" aria-hidden="true"></i>
<span class="val">${c.atk ? '⚔ ' + c.atk : '⛨ ' + c.def}</span><span class="desc"></span>${c.combo ? `<span class="kind combo">${D.comboTag}</span>` : '<span class="kind"></span>'}</span>`;
    (b.querySelector('.name') as HTMLElement).textContent = c.name;
    if (Math.max(...c.name.split(/\s+/).map((w) => w.length)) > 11) b.querySelector('.name')!.classList.add('long');
    (b.querySelector('.desc') as HTMLElement).textContent = c.desc;
    b.addEventListener('click', () => toggle(idx));
    return b;
  };
  const spent = () => order.reduce((s, i) => s + D.hand[i].cost, 0);
  function render() {
    const res = resolve(order.map((i) => D.hand[i]), D.combos);
    const dmg = res.reduce((s, r) => s + r.dmg, 0), blk = res.reduce((s, r) => s + r.blk, 0);
    // mana
    manaEl.innerHTML = `<b>${t.mana}</b> ` + Array.from({ length: D.mana }, (_, i) => `<i class="${i < spent() ? 'spent' : ''}"></i>`).join('') + ` <span>${D.mana - spent()}/${D.mana}</span>`;
    // cartas na mão
    for (const b of handEl.querySelectorAll<HTMLButtonElement>('button.card')) {
      const idx = +b.dataset.idx!; const pos = order.indexOf(idx);
      b.setAttribute('aria-pressed', String(pos >= 0));
      (b.querySelector('.order') as HTMLElement).textContent = pos >= 0 ? String(pos + 1) : '';
      b.disabled = busy || (pos < 0 && spent() + D.hand[idx].cost > D.mana);
    }
    // fila com os bônus
    laneEl.innerHTML = res.map((r, k) => `<span class="slot on" title="${r.hits.map((h) => h.name + ' +' + h.v).join(' · ')}">${k + 1}<br>${r.dmg ? '⚔' + r.dmg : '⛨' + r.blk}</span>`).join('') +
      Array.from({ length: Math.max(0, 4 - res.length) }, () => '<span class="slot"></span>').join('');
    const names = res.flatMap((r) => r.hits.map((h) => `${h.name} +${h.v}`));
    callout.textContent = names.length ? `${t.combo} ${names.join(' · ')}` : '';
    // prévia na barra de vida
    hpEl.style.setProperty('--hp', String(Math.max(0, hp) / D.foe.hp));
    hpEl.style.setProperty('--pv', String(Math.min(hp, dmg) / D.foe.hp));
    hpEl.querySelector('b')!.textContent = `${Math.max(0, hp)} / ${D.foe.hp}${dmg ? `  (−${dmg})` : ''}`;
    $('#you-block')!.textContent = blk ? `⛨ ${D.block} ${blk}` : '';
    // resumo junto dos botões (no celular a barra de vida fica fora da tela enquanto se escolhe)
    const sum = $('#t-sum'); if (sum) sum.textContent = order.length ? `⚔ ${dmg} → ${Math.max(0, hp - dmg)}/${D.foe.hp}${blk ? `  ⛨ ${blk}` : ''}${names.length ? '  · ' + names.join(' · ') : ''}` : '';
  }
  function toggle(idx: number) {
    if (busy) return;
    const pos = order.indexOf(idx);
    if (pos >= 0) order.splice(pos, 1);
    else if (spent() + D.hand[idx].cost <= D.mana) { order.push(idx); sfx('card-draw'); }
    render();
  }
  function deal() {
    order = []; hp = D.foe.hp; busy = false; logEl.textContent = ''; foe.classList.remove('dead');
    hand = hand.map((x) => ({ ...x, r: Math.random() })).sort((a, b) => (a as { r: number }).r - (b as { r: number }).r);
    handEl.replaceChildren(...hand.map(({ c, i }) => cardEl(c, i)));
    hooks.tilt(Array.from(handEl.querySelectorAll('.card')));
    render();
  }
  async function endTurn() {
    if (busy || !order.length) return;
    busy = true;
    const res = resolve(order.map((i) => D.hand[i]), D.combos);
    const wait = (ms: number) => new Promise((r) => setTimeout(r, document.body.classList.contains('reduced') || matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : ms));
    let blk = 0;
    for (const r of res) {
      if (r.dmg) { hp -= r.dmg; foe.classList.remove('hit'); void foe.offsetWidth; foe.classList.add('hit'); sfx('card-play-attack'); }
      if (r.blk) { blk += r.blk; sfx('card-play-defense'); }
      if (r.hits.length) sfx('combo-trigger');
      render(); await wait(420);
    }
    const dealt = res.reduce((s, r) => s + r.dmg, 0);
    if (hp <= 0) {
      foe.classList.add('dead'); sfx('battle-victory');
      logEl.textContent = `${t.tableDeal.replace('{n}', String(dealt))} ${t.win}`;
      const r = root!.getBoundingClientRect(); hooks.confetti?.(r.left + r.width / 2, r.top + r.height * 0.3);
    } else {
      sfx('enemy-attack');
      const taken = Math.max(0, D.foe.intent - blk);
      logEl.textContent = `${t.tableDeal.replace('{n}', String(dealt))} ${taken ? t.tableTake.replace('{n}', String(taken)) : t.tableBlocked} ${t.lose} ${t.tableLoseHint}`;
    }
    order = []; render(); // a mão fica travada até "Dar de novo"
  }
  $('#t-end')!.addEventListener('click', endTurn);
  $('#t-reset')!.addEventListener('click', deal);
  root.dataset.ready = '1';
  deal();
}
