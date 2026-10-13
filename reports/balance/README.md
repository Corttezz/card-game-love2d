# reports/balance/

Saída da bateria de balanceamento (`python tools/balance.py`): um diretório
por rótulo com `report.md` (leitura humana), `results.json` (agregados) e
`records.json` (um registro por run — o que `tools/balance_report.py`
re-renderiza). O sweep (`tools/balance_tune.py`) grava `<label>-summary.json`.

Os relatórios são ARTEFATOS regenerados a cada bateria e ficam fora do git
(ver `.gitignore` aqui); os números que importam vão para
`memory/balance_curves.md` / `memory/sts_difficulty_targets.md` com a seed,
o piloto e o HEAD em que foram medidos. Ver `memory/balance_pipeline.md`.
