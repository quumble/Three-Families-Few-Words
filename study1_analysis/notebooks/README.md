# Notebooks — analysis

This is where the inferential analyses and figures live. The split mirrors the prereg's confirmatory/exploratory split:

- `01_primary.R` is the **locked confirmatory artifact**. It runs the 5 primary tests (per prereg §6.2 + the 2026-05-10 and 2026-05-15 deviations) against both `coded_main.csv` and `coded_main_sensitivity.csv`, producing a reproducible results CSV. It is run as a script, not edited interactively.
- `02_descriptives.Rmd` (TODO) is for descriptives, §6.3 secondary analyses, figures. Iterative, evolves with the writeup.

## Files

| File | Status | Purpose |
|---|---|---|
| `_setup.R` | done | Common environment: packages, paths, factor levels, loader functions |
| `01_primary.R` | done | The 5 primary tests × 2 datasets, locked |
| `02_descriptives.Rmd` | TODO | Cell-level descriptives, §6.3 secondary analyses, figures |
| `output/primary_results.csv` | written by 01 | Flat results table — one row per test × dataset |
| `output/primary_models.rds` | written by 01 | Fitted model objects for inspection |
| `output/primary_session.txt` | written by 01 | `sessionInfo()` dump for reproducibility |

## Running the primary analysis

R must be installed locally (≥ 4.0), plus the packages listed in `_setup.R`:

```r
install.packages(c("readr", "dplyr", "tidyr", "glmmTMB", "lme4", "broom.mixed"))
```

Then from the notebooks directory:

```powershell
cd study1_analysis\notebooks
Rscript 01_primary.R
```

The script writes everything to `output/`. The terminal output ends with a compact summary table — five rows, p-values, threshold, significance.

## The five primary tests

Per prereg §6.2 plus deviations 2026-05-10 (H4 added) and 2026-05-15 (sensitivity dataset). All are run twice — once on the primary coded dataset and once on the sensitivity-swapped dataset. Substantive conclusions are claimed only where they hold in both.

| Test | What's tested | Outcome | Test statistic | Threshold |
|---|---|---|---|---|
| H1-PRO | Family main effect on Prosocial proportion | binary (PRO vs not) | LRT (drop family + family:framing) | Bonferroni α = .01 |
| H1-IDM | Family main effect on Identity/Meta proportion | binary (IDM vs not) | LRT (drop family + family:framing) | Bonferroni α = .01 |
| H2-IDM | Framing main effect on IDM (predicted positive) | binary (IDM vs not) | Wald on `framingB` coefficient | Bonferroni α = .01 |
| H3-IDM | Family × framing interaction on IDM | binary (IDM vs not) | LRT (drop family:framing; 2 df) | Bonferroni α = .01 |
| H4-compliance | Family main effect on per-trial compliance (predicted Google Flash/Pro lower) | binary (compliant vs not) | LRT (drop family) | Bonferroni α = .01 |

H2-AFF (framing main effect on Affective; predicted negative) is also reported but corrected separately per prereg §6.2 at α = .05.

## Model specification

Per prereg §6.2 plus marginality-respecting LRTs:

**For category outcomes (H1, H2, H3, H2-AFF):**

```
is_<CATEGORY> ~ family * framing + n_fac + (1 | model_id) + (1 | trial_id)
```

Where:
- `family` is a 3-level factor (anthropic / openai / google), anthropic as reference.
- `framing` is a 2-level factor (A / B), A as reference.
- `n_fac` is an ordered factor on {1, 3, 5, 10}, giving linear and quadratic contrasts.
- `model_id` is the 9-level model identifier, treated as nested under family (the random intercept structure captures this implicitly).
- `trial_id` is the call_id of the originating API trial.

**For the compliance outcome (H4):**

```
compliant ~ family + framing + n_fac + (1 | model_id)
```

No trial-level RE because the outcome is at the trial level. No family:framing interaction because H4 is purely a family main effect hypothesis.

## Convergence policy and fallback ladder

Mixed-effects logistic regression with sparse binary outcomes (IDM is 6.1%, with 78.9% of trials contributing zero IDM words) can be hard to fit. The script applies a deterministic fallback ladder per model, recording which level was used:

1. `glmmTMB` with full RE: `(1 | model_id) + (1 | trial_id)`
2. `glmmTMB` with reduced RE: `(1 | model_id)`
3. `lme4::glmer` with bobyqa, full RE
4. `lme4::glmer` with bobyqa, reduced RE

A fallback to level 2 or below would be a **deviation from prereg §6.2** and must be logged in `../../study1/prereg/deviations.md` before the result is reported as confirmatory. The `re_structure` column in `primary_results.csv` records which level was actually used.

## Convergence risks (predictions before running)

These are worth eyeballing in the output:

- **IDM trial-level random intercept** is the most likely failure point. 78.9% of trials have zero IDM words, so the trial RE has very little within-vs-between-trial variance to estimate. Expect a singular fit warning here; fallback to level 2 is likely. If that happens it should be logged as a deviation.
- **Google cells at N=5 and N=10** have heavily reduced trial counts (20-22 vs 60) due to truncation. The family estimate for Google is on thinner data than for Anthropic/OpenAI; standard errors will reflect this. This is not a convergence issue but an interpretation one — the H1 family-main-effect tests are conditional on the data we have.
- **Anthropic compliance is 100%** in the per-call data. This is *complete separation* for the H4 family contrast against Anthropic. The LRT for the family main effect on compliance still works (the LRT statistic remains finite because both full and reduced models fit), but coefficient-level Wald tests against the Anthropic baseline will have unstable / undefined standard errors. We report H4 as the LRT plus the raw descriptive percentages, not as coefficient estimates.
- **OTH** is 0.1% of words. The script doesn't fit an OTH model per primary analysis (it's exploratory per prereg).

## Pre-flight diagnostics (printed before any model is fit)

To make any required deviation entries factual rather than reactive, the script prints two pre-flight blocks per dataset before fitting anything:

1. **Per-category outcome density and per-trial structure** for PRO, IDM, AFF. Shows the % of words in each category and, for each category, how many trials produced zero / one / two / three+ words of that category. If most trials are zero-outcome (as for IDM), the trial-level random intercept will likely go singular and a deviation will need to be logged.

2. **Per-family compliance counts** for H4. Any cell at 0% or 100% is flagged `COMPLETE SEPARATION`. Anthropic's 100% compliance will fire this flag; the implication is that we report H4 via the LRT (which is still valid) plus descriptive percentages.

After each successful model fit, the variance components for the random-effect terms are also printed. A `(1|trial_id)` term reported with `variance = 0.000000  <-- SINGULAR (≈ 0)` is the signal that the prereg-specified RE structure didn't have anything to estimate from this data — the same model with that term dropped gives the same fixed-effect estimates and SEs, and is what should be reported (with a deviation entry).

## Reading the output

`output/primary_results.csv` has one row per test. Key columns:

- `test`: identifier (H1-PRO, H1-IDM, H2-IDM, H3-IDM, H2-AFF, H4-compliance)
- `kind`: LRT vs Wald, with marginality notes
- `chi2` / `df` / `p_value`: for LRTs
- `coefficient` / `estimate` / `std_error` / `z` / `p_value`: for Wald tests
- `threshold` / `significant`: Bonferroni-corrected for the 5-test family; H2-AFF separate
- `direction_predicted` / `direction_observed`: for H2 (we predicted positive for IDM, negative for AFF)
- `engine` / `re_structure`: which fallback level was used
- `warnings`: any convergence or singularity messages collected during the fit

The fitted model objects are in `output/primary_models.rds`; load with `readRDS()` and inspect via `summary()`. Variance components show whether the trial RE went singular.

## Why R and not Python

The analysis uses `glmmTMB` and `lme4`, which are mature R packages with conservative defaults, well-tested convergence diagnostics, and output that any reviewer in social or behavioral science will recognize. The Python equivalents (`statsmodels`, `bambi`) either don't support binomial GLMM (statsmodels) or require Bayesian inference that introduces additional decisions (priors) the prereg doesn't specify.
