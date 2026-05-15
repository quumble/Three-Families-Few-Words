# Study 1 — Post-data-collection work

This folder contains everything that happens **after** data collection. The locked half (preregistration, runner, raw JSONL) lives in [`../study1/`](../study1/) and does not change once the prereg is posted.

The split is deliberate: `study1/` is a snapshot of the preregistered design and the data it produced. `study1_analysis/` is the working space for parsing, coding, validation, and analysis — operations on the locked artifact rather than parts of it. A reviewer auditing prereg compliance can read only `study1/` and ignore `study1_analysis/`.

## Pipeline

```
study1/data/raw/                  parser/         judge/
  responses_*.jsonl     ──▶    parse.py    ──▶  code.py
                                                                       
                                    │              │
                                    ▼              ▼
                              data/per_*.csv    data/coded_*.csv
                                                data/refusal_*.csv
                                                judge/judge_cache.json
                                                judge/judge_call_log.jsonl

                                                       │
                                                       ▼
                                              (TODO) coding_tool/, notebooks/
```

Each stage is independent: re-run the parser without re-running the judge; fit a new model in `notebooks/` without re-running anything upstream.

## Folder layout

| Path | Purpose | Status |
|---|---|---|
| `parser/` | JSONL → `clean`/`wrapped`/`malformed` per-call CSV + per-word CSV. | ✅ complete |
| `judge/` | LLM judge that codes each word into the 7-category scheme. Includes the refusal classifier for malformed rows. | ✅ complete |
| `coding_tool/` | Standalone HTML interface for the human hand-coding of the 200-word validation sample (prereg §5.1). | TODO |
| `notebooks/` | Mixed-effects logistic regressions, JS divergence, descriptive plots (prereg §6). | TODO |
| `data/` | Flat directory holding parser CSVs, judge CSVs, and (later) validation outputs. | populated |

## Files currently in `data/`

| File | Source | Rows | Description |
|---|---|---|---|
| `per_call_main.csv` | parser | 1,440 | One row per main-study API call, plus `parse_status`, `truncated`, extracted words. |
| `per_call_pilot.csv` | parser | 160 | Same for the pilot (160 instead of 144 — see parser README). |
| `per_word_main.csv` | parser | 5,255 | One row per extracted word from `clean`/`wrapped` responses. Primary-analysis dataset per prereg §6.1. |
| `per_word_pilot.csv` | parser | 523 | Same for the pilot. |
| `coded_main.csv` | judge | 5,255 | `per_word_main.csv` plus a `code` column (one of PRO/EPI/CAP/AFF/IDM/HDG/OTH) and a `cache_hit` boolean for traceability. |
| `refusal_classifications_main.csv` | judge | 221 | One row per malformed main-study call, classified REFUSAL vs MALFORMED. All 221 came back MALFORMED. |

## Quick descriptives from `coded_main.csv`

Proportion of words in each category, broken by family × framing (informational only; no inferential analysis yet):

| family | framing | n_words | PRO | EPI | CAP | AFF | IDM | HDG | OTH |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| anthropic | A | 1,140 | 28.5% | 36.1% | 13.0% | 19.6% | 2.6% | 0.2% | 0.0% |
| anthropic | B | 1,140 | 20.4% | 35.2% | 19.9% | 16.1% | 6.5% | 2.0% | 0.0% |
| google | A | 516 | 19.6% | 32.2% | 34.1% | 5.8% | 7.8% | 0.4% | 0.2% |
| google | B | 502 | 16.9% | 24.3% | 35.5% | 5.0% | 12.4% | 6.0% | 0.0% |
| openai | A | 1,060 | 26.3% | 20.0% | 44.1% | 7.9% | 1.5% | 0.0% | 0.2% |
| openai | B | 897 | 20.0% | 16.7% | 46.7% | 5.4% | 11.1% | 0.0% | 0.1% |

The three families look distinct: Anthropic leans EPI/PRO (curious, helpful, honest, thoughtful), OpenAI leans CAP (concise, adaptable, reliable), Google also leans CAP plus a notable digital/IDM presence. The framing-B shift toward IDM is visible across all three families, consistent with H2. Inferential testing per prereg §6 is the TODO.

Note: Google rows have ~500 words rather than ~1,100 because many Google Pro / Flash trials at N=5 and N=10 truncated under max_tokens before producing a parseable list and were excluded from the primary-analysis dataset. The compliance rate is itself a primary outcome (H4) — see prereg/deviations.

## Notes for the next person picking this up

- The parser and judge are both path-aware: each resolves locations via `__file__`. Don't move scripts without checking the path constants near the top.
- Outputs in `data/` are regenerable from `../study1/data/raw/` and the parser/judge code. They're small enough to commit, and committing them means a reviewer who doesn't want to spend $3 on judge calls can still run the analysis directly.
- The judge cache `judge/judge_cache.json` is committed for full audit-ability. Reruns are incremental against it.
- Any change to parser logic, judge prompt usage, or coding scheme is a deviation from prereg §4 / §5 and should be logged in `../study1/prereg/deviations.md` before producing the confirmatory analysis dataset.

## What's left to do

1. **Hand-coded validation (prereg §5.1).** Build `coding_tool/` — an HTML interface that draws a stratified random sample of ~200 words from `coded_main.csv` (without showing the judge code), captures human codes, and writes them to `data/validation_*.csv`. Cohen's kappa is then computed in a notebook.
2. **Statistical analysis (prereg §6).** Mixed-effects logistic regressions for each category, framing main effect, family × framing interaction. Bonferroni correction at α = .01 for the 5 primary tests (the 4 originally planned + H4 on compliance).
3. **Writeup.**
