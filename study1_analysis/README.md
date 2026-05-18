# Study 1 — Post-data-collection work

This folder contains everything that happens **after** data collection. The locked half (preregistration, runner, raw JSONL) lives in [`../study1/`](../study1/) and does not change once the prereg is posted.

The split is deliberate: `study1/` is a snapshot of the preregistered design and the data it produced. `study1_analysis/` is the working space for parsing, coding, validation, and analysis — operations on the locked artifact rather than parts of it. A reviewer auditing prereg compliance can read only `study1/` and ignore `study1_analysis/`.

## Pipeline

```
study1/data/raw/                  parser/         judge/             coding_tool/
  responses_*.jsonl     ──▶    parse.py    ──▶  code.py    ──▶  sample.py
                                                                  coding_tool.html
                                    │              │              kappa.py
                                    ▼              ▼              apply_sensitivity_swap.py
                              data/per_*.csv    data/coded_*.csv         │
                                                data/refusal_*.csv        ▼
                                                judge/judge_cache.json   data/validation_main.csv
                                                judge/judge_call_log.jsonl   data/coded_main_sensitivity.csv

                                                                                  │
                                                                                  ▼
                                                                         notebooks/
                                                                           01_primary.R
                                                                           04_sonnet_sensitivity.R
                                                                           02_variance_components.R
                                                                           03_h1_pro_diagnostic.R
                                                                           (02_descriptives.Rmd — TODO)
```

Each stage is independent: re-run the parser without re-running the judge; fit a new model in `notebooks/` without re-running anything upstream.

## Folder layout

| Path | Purpose | Status |
|---|---|---|
| `parser/` | JSONL → `clean`/`wrapped`/`malformed` per-call CSV + per-word CSV. | ✅ complete |
| `judge/` | LLM judge that codes each word into the 7-category scheme. Includes the refusal classifier for malformed rows. | ✅ complete |
| `coding_tool/` | Standalone HTML interface for the human hand-coding of the validation sample (prereg §5.1). 154 unique `(word, framing, N)` tuples; κ scoring script included. | ✅ tool built; awaiting hand-coding pass |
| `notebooks/` | Mixed-effects logistic regressions (prereg §6.2 + §8 sensitivity). Diagnostics, variance components, and the §8 Sonnet-dropped sensitivity. Secondary analyses (§6.3) and figures still to be written in `02_descriptives.Rmd`. | ✅ confirmatory done; descriptives TODO |
| `data/` | Flat directory holding parser CSVs, judge CSVs, and (later) validation outputs. | populated |

## Files currently in `data/`

| File | Source | Rows | Description |
|---|---|---|---|
| `per_call_main.csv` | parser | 1,440 | One row per main-study API call, plus `parse_status`, `truncated`, extracted words. |
| `per_call_pilot.csv` | parser | 160 | Same for the pilot (160 instead of 144 — see parser README). |
| `per_word_main.csv` | parser | 5,255 | One row per extracted word from `clean`/`wrapped` responses. Primary-analysis dataset per prereg §6.1. |
| `per_word_pilot.csv` | parser | 523 | Same for the pilot. |
| `coded_main.csv` | judge | 5,255 | `per_word_main.csv` plus a `code` column (one of PRO/EPI/CAP/AFF/IDM/HDG/OTH) and a `cache_hit` boolean for traceability. |
| `coded_main_sensitivity.csv` | swap script | 5,255 | `coded_main.csv` with the boundary-disputed-word swap applied (deviation, 2026-05-15). `original_code` preserved, `swap_applied` and `swap_policy` columns added. 750 rows (14.3%) re-coded. |
| `refusal_classifications_main.csv` | judge | 221 | One row per malformed main-study call, classified REFUSAL vs MALFORMED. All 221 came back MALFORMED. |
| `validation_main.csv` | hand-coding tool | 154 | One row per hand-coded `(word, framing, N)` tuple with `human_code`. Output of `coding_tool/coding_tool.html`. |

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

The three families look distinct: Anthropic leans EPI/PRO (curious, helpful, honest, thoughtful), OpenAI leans CAP (concise, adaptable, reliable), Google also leans CAP plus a notable digital/IDM presence. The framing-B shift toward IDM is visible across all three families, consistent with H2. Full inferential testing per prereg §6.2 is complete (see `notebooks/output/primary_results.csv`); §6.3 secondary analyses are the remaining TODO.

Note: Google rows have ~500 words rather than ~1,100 because many Google Pro / Flash trials at N=5 and N=10 truncated under max_tokens before producing a parseable list and were excluded from the primary-analysis dataset. The compliance rate is itself a primary outcome (H4) — see prereg/deviations.

## Notes for the next person picking this up

- The parser and judge are both path-aware: each resolves locations via `__file__`. Don't move scripts without checking the path constants near the top.
- Outputs in `data/` are regenerable from `../study1/data/raw/` and the parser/judge code. They're small enough to commit, and committing them means a reviewer who doesn't want to spend $3 on judge calls can still run the analysis directly.
- The judge cache `judge/judge_cache.json` is committed for full audit-ability. Reruns are incremental against it.
- Any change to parser logic, judge prompt usage, or coding scheme is a deviation from prereg §4 / §5 and should be logged in `../study1/prereg/deviations.md` before producing the confirmatory analysis dataset.

## What's left to do

1. **Secondary analyses (prereg §6.3).** Length effects within category by family, type/token ratios per cell, top-word lists per cell, Jensen-Shannon divergence between framing-A and framing-B distributions per model, and the H1 family-LRT extended to the five non-pre-specified categories (EPI, CAP, AFF, HDG, OTH) as exploratory. To live in `notebooks/02_descriptives.Rmd`.
2. **Figures for the writeup.**
3. **Writeup finalisation.** Current draft: `papers/three_families_few_words_v2.md`.

## Completed analyses

- **Primary tests (prereg §6.2).** `notebooks/01_primary.R` against both `coded_main.csv` and `coded_main_sensitivity.csv`. Output: `notebooks/output/primary_results.csv`, `primary_models.rds`, `primary_session.txt`. Four of five Bonferroni-grouped tests clear α = .01 in both datasets. H4 fails as a family-level effect; the descriptive prediction holds at the model level. H2-AFF flips sign between datasets and is not claimed.
- **§8 Sonnet-as-judge sensitivity.** `notebooks/04_sonnet_sensitivity.R` re-runs the category tests after dropping the 760 rows where Sonnet is the subject. Output: `notebooks/output/sonnet_sensitivity_results.csv`. H1-PRO, H1-IDM, H3-IDM survive; H2-IDM is unestimable on the sub-dataset due to complete separation in the within-Anthropic reference cell (the only Anthropic-A IDM observations come from Sonnet).
- **Variance components.** `notebooks/02_variance_components.R` extracts RE variances from the saved fits. Output: `notebooks/output/variance_components.txt`. The `trial_id` random intercept estimates to zero in every category model — consistent with the pre-fit forecast in `notebooks/README.md` (most trials produce zero outcome words for any given category).
- **H1-PRO diagnostic.** `notebooks/03_h1_pro_diagnostic.R` inspects the H1-PRO fit specifically.

## Completed validation pass

Validation returned **κ = 0.673** overall (substantial; above the prereg's 0.60 threshold), with per-category one-vs-rest κs of: IDM 0.85, HDG 0.85, EPI 0.75, PRO 0.63, CAP 0.59, AFF 0.51, OTH 0.31 (n=4, unstable). Judge codes are accepted as primary per prereg §5.1. The 42 disagreements clustered on the AFF↔PRO and CAP↔EPI boundaries and reflected scheme ambiguity (the prereg §5 text permitted both readings) rather than coder error. A pre-specified sensitivity analysis applying a human-boundary swap is logged in the deviations file and produced `data/coded_main_sensitivity.csv`.
