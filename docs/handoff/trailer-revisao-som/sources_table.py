import sys, os, json, collections

OUT = r'E:\dev\projects\card-game-trailer\build\trailer\som'
for name in sys.argv[1:]:
    log = json.load(open(os.path.join(OUT, name, 'mix_sources.json'), encoding='utf-8'))
    by = collections.OrderedDict()
    for e in sorted(log, key=lambda e: e['t']):
        k = e['file']
        d = by.setdefault(k, {'n': 0, 'ts': [], 'lic': e['license'], 'codes': set()})
        d['n'] += 1; d['ts'].append(e['t']); d['codes'].add(e['code'])
    print(f'\n#### {name}: {len(by)} arquivos, {len(log)} eventos\n')
    print('| Arquivo | Origem / licenca | Vezes | Tempos (s) |')
    print('|---|---|---|---|')
    for k, d in sorted(by.items(), key=lambda kv: (kv[1]['lic'], kv[0])):
        ts = ', '.join(f'{t:.2f}' for t in d['ts'][:6]) + (' ...' if len(d['ts']) > 6 else '')
        print(f"| `{k}` | {d['lic']} | {d['n']} | {ts} |")
