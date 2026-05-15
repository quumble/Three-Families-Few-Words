# Results checkpoint — 2026-05-15

*This is an interim writeup of the primary analyses as of 2026-05-15. Secondary analyses (§6.3) and full prose discussion are not yet drafted. Numbers below are produced by `study1_analysis/notebooks/01_primary.R` against `data/coded_main.csv` (primary) and `data/coded_main_sensitivity.csv` (sensitivity). Session info is in `notebooks/output/primary_session.txt`.*

---

## Headline

When asked to describe themselves in a few words, the three model families don't sound alike. Anthropic models reach for *helpful, curious, honest, thoughtful*. OpenAI models reach for *helpful, concise, adaptable, reliable*. Google models reach for *versatile, helpful, analytical, digital*. The differences are large and they survive every formal test we planned. Telling a model "you are an AI" before asking the question changes what it says — but the size of that change is itself family-specific, with OpenAI shifting hardest toward identity-language and Google barely shifting at all. The pilot also surfaced a compliance issue — Google's reasoning-heavy preview models burning their entire output budget on hidden chain-of-thought before producing the requested word list — which we registered as a fifth hypothesis (H4) on 2026-05-10 before running the main study. That fifth hypothesis came back null on the formal family-level test because the non-compliance is concentrated in specific Google and OpenAI models rather than spread across the families.

Five primary tests, two datasets each. Four of the five family-wise tests cleared the Bonferroni-corrected threshold of α = .01 in both datasets and pointed the same way. One did not. The separately-corrected affective-words test was significant in both datasets but flipped direction under the sensitivity coding, so we don't claim it.

## Primary results

Tests are pre-registered (prereg §6.2 plus deviations 2026-05-10 and 2026-05-15). Models are mixed-effects logistic regressions with the prereg-specified random effects `(1 | model_id) + (1 | trial_id)`. Bonferroni-corrected α = .01 for the four primary-family tests plus H4; α = .05 for H2-AFF, separately corrected.

| Test | Hypothesis | Primary | Sensitivity | Verdict |
|---|---|---|---|---|
| **H1-PRO** | Family differs on Prosocial proportion | χ²(4) = 19.2, p = 7.3 × 10⁻⁴ | χ²(4) = 27.9, p = 1.3 × 10⁻⁵ | ✓ supported, robust |
| **H1-IDM** | Family differs on Identity/Meta proportion | χ²(4) = 75.1, p = 1.9 × 10⁻¹⁵ | χ²(4) = 71.3, p = 1.2 × 10⁻¹⁴ | ✓ supported, robust |
| **H2-IDM** | Framing-B increases IDM | β = +0.97, z = 4.34, p = 1.4 × 10⁻⁵ | β = +0.90, z = 3.97, p = 7.3 × 10⁻⁵ | ✓ supported, robust |
| **H3-IDM** | Family × framing interacts on IDM | χ²(2) = 75.1, p = 4.9 × 10⁻¹⁷ | χ²(2) = 71.3, p = 3.3 × 10⁻¹⁶ | ✓ supported, robust |
| **H4-compliance** | Family differs on compliance rate | χ²(2) = 1.78, **p = 0.41** | χ²(2) = 1.78, **p = 0.41** | ✗ not supported as a family-level effect |
| H2-AFF (sep. α=.05) | Framing-B decreases AFF | β = −0.26, z = −2.30, p = .022 (predicted dir.) | β = **+0.70**, z = 4.48, p = 7.6 × 10⁻⁶ (**opposite dir.**) | ✗ direction not robust; we do not claim it |

Every category model fit cleanly with the prereg-specified random-effects structure. Two variance components went to zero — the trial-level random intercept for H1-PRO and H2-AFF in both datasets, where the prediction warned this was likely — but the prereg structure was preserved as the engine and the fits converged. No fallback to a reduced random-effects spec was needed.

### H1 — three different voices

The category distribution is starkly family-specific. Aggregated across N and framing, the three families' top words barely overlap once you get past "helpful":

| Family | Top words (with counts) |
|---|---|
| anthropic | helpful (422), curious (403), honest (226), thoughtful (170), conversational (135), knowledgeable (96), analytical (85), adaptable (60), concise (55), artificial (48) |
| openai | helpful (357), concise (205), adaptable (171), reliable (135), curious (133), adaptive (128), analytical (111), knowledgeable (87), conversational (76), creative (65) |
| google | versatile (196), helpful (181), analytical (127), digital (76), curious (46), creative (42), logical (34), knowledgeable (33), objective (29), adaptable (28) |

The seven-category coding makes the difference precise. Anthropic models are dominated by epistemic and prosocial words (EPI 35-36%, PRO 20-28% across framings), with capability third. OpenAI models invert this: capability is the dominant category (44-47%), with prosocial second. Google models also lead with capability (34-36%) but pair it with the highest baseline rate of identity/meta words across the three families.

H1-PRO and H1-IDM each test the family main effect on those category proportions, respecting marginality by dropping both `family` and `family:framing` from the reduced model. Both clear Bonferroni-corrected α = .01 in both datasets, with H1-IDM nearly fourteen orders of magnitude below threshold. The families differ. They differ by a lot.

### H2 and H3 — what changes when you tell a model it's an AI

In Framing A the prompt asks the model to describe itself with no qualifier. In Framing B the prompt adds *"as an AI"* — explicitly grounding the question in the model's nature. The identity/meta category (`AI`, `assistant`, `model`, `digital`, `language-model`, `artificial`, `non-sentient`, and so on) is where any direct response to that grounding cue should land.

It does. Within the reference family (anthropic), the framing-B coefficient on IDM is +0.97 log-odds in the primary dataset (z = 4.34, p = 1.4 × 10⁻⁵). Framing-B more than doubles IDM probability there: 2.6% under A → 6.5% under B.

But the interaction (H3) is where the story actually lives. The family × framing interaction term has χ²(2) = 75 — almost identical to the H1-IDM family-main-effect chi-squared. That is: nearly all the family-level structure in IDM lives in how families *respond differently to framing*, not in baseline IDM rates. The per-coefficient detail:

- **OpenAI × framing-B**: β = +2.50 log-odds over Anthropic's framing effect (z = 6.46, p = 1.1 × 10⁻¹⁰). OpenAI moves on framing harder than anyone.
- **Google × framing-B**: β = −0.45 (z = −1.45, p = .15). Indistinguishable from Anthropic's effect.

In raw proportions:

| family | IDM under FA | IDM under FB | shift |
|---|---:|---:|---:|
| anthropic | 2.6% | 6.5% | ×2.5 |
| openai | 1.5% | 11.1% | ×7.4 |
| google | 7.8% | 12.4% | ×1.6 |

OpenAI under FA almost never volunteers identity words — 1.5%, the lowest baseline of any family. Under FB the same models go to 11.1%, the highest framing-induced shift in the study. Google already has the highest baseline IDM rate (7.8%) and shifts only modestly. Anthropic sits in between on both axes.

Substantively: when the prompt does the work of telling the model "you are an AI," OpenAI's models pick that thread up forcefully — "AI," "digital," "language-model," "synthetic." Anthropic's models pick it up more gently. Google's models barely need the cue because they were already partway there. The H3 interaction is not subtle.

### H4 — the compliance pattern is real, but it isn't a family effect

H4 is not in the original prereg. It was added on 2026-05-10 after the pilot exposed that Gemini 3 Flash and Gemini 3 Pro consume nearly the entire 200-token output budget on hidden reasoning tokens before producing the requested word list, leaving the response truncated and unparseable. The pilot's 22 truncation flags all came from these two cells. We registered the change publicly in `deviations.md` before any main-study data had been analyzed: compliance rate would be the fifth primary hypothesis, the prediction was directional (Google Flash and Pro lower than other models in the same family or other families' equivalent tiers), and the Bonferroni-corrected per-test threshold would tighten from α = .0125 to α = .01 to accommodate the additional test. The prediction was based on pilot observation, not theory; we expected the pattern to replicate in the larger main run.

The descriptive percentages do exactly replicate:

| family | compliant | rate |
|---|---:|---:|
| anthropic | 480 / 480 | 100.0% |
| openai | 443 / 480 | 92.3% |
| google | 296 / 480 | 61.7% |

But the formal LRT against the family main effect, with `(1 | model_id)` as a random intercept, returns χ²(2) = 1.78, p = 0.41 in both datasets. The hypothesis as registered is not supported.

The reason is structural rather than substantive. Compliance is not distributed evenly within Google — and it's not perfect within OpenAI either:

| family | model | compliant / total |
|---|---|---:|
| anthropic | claude-haiku-4-5 | 160 / 160 |
| anthropic | claude-opus-4-7 | 160 / 160 |
| anthropic | claude-sonnet-4-6 | 160 / 160 |
| google | gemini-3.1-flash-lite | 160 / 160 |
| google | gemini-3-flash-preview | 71 / 160 (44.4%) |
| google | gemini-3.1-pro-preview | 65 / 160 (40.6%) |
| openai | gpt-5.4-2026-03-05 | 160 / 160 |
| openai | gpt-5.4-mini-2026-03-17 | 160 / 160 |
| openai | gpt-5.4-nano-2026-03-17 | 123 / 160 (76.9%) |

The non-compliance is concentrated in three specific models — Gemini 3 Flash, Gemini 3.1 Pro, and GPT-5.4 nano. Every other model is at or near 100%. Once `(1 | model_id)` is in the regression, the model-level random intercepts absorb that variance before the family-level fixed effect can claim it. The model is correctly answering the question it was asked: there is no detectable family-level fixed effect *after* controlling for model-level differences, because the differences live at the model level.

The directional prediction was right about Google Flash and Pro (they are indeed the two most non-compliant cells in the study) but the framing of H4 as a *family-level* effect was wrong about the unit. The descriptive pattern that motivated the hypothesis is unambiguous and exactly what we predicted on 2026-05-10; the formal LRT for the family fixed effect is null because compliance varies within families more than between them. We report this honestly: the prereg-locked test fails, the descriptive pattern is robust and on-prediction, and the substantive interpretation in the writeup will reflect both.

Note that Anthropic's 100% compliance creates complete separation against the Anthropic baseline. The LRT remains valid (both full and reduced models fit), but no Wald-style coefficient confidence intervals for compliance comparisons against Anthropic should be reported.

### H2-AFF — a sensitivity flip we have to honor

The framing-B coefficient on AFF was predicted negative (framing-B reduces affective-trait language). In the primary dataset that prediction is confirmed: β = −0.26, p = .022 (passes the separately-corrected α = .05).

In the sensitivity dataset — where the validation pass's human boundary calls have been propagated through, swapping 14.3% of word codes — the AFF framing coefficient is **β = +0.70, p = 7.6 × 10⁻⁶**. Same outcome, opposite direction.

This is what the sensitivity analysis exists to catch. Which words count as "affective" versus "prosocial" is precisely the boundary the κ-validation pass surfaced as scheme-ambiguous: *honest, polite, patient, impartial, non-judgmental, engaged*. The judge coded most of these as AFF; the human coded several as PRO. Once that re-coding propagates, the framing effect on what's left in AFF reverses sign. We cannot claim H2-AFF as a confirmatory finding: the direction depends on a coding boundary the project itself flagged as legitimately ambiguous.

The honest report is: H2-AFF passed its significance threshold in both datasets but with opposing signs, indicating that the directionality of the framing effect on affective-trait language depends on how the AFF/PRO boundary is drawn. Pre-registering the swap rule before running the regressions is what allowed us to detect this; without the sensitivity analysis we would have reported a confirmed H2-AFF in the wrong direction.

## What this means in plain English

The study set out to ask whether three families of language models talk about themselves differently, and whether telling them they are AI changes the answer. Yes and yes, with caveats worth keeping.

Anthropic's models talk like they want you to like them: helpful, honest, thoughtful, curious. OpenAI's talk like they want you to use them: concise, adaptable, reliable, efficient. Google's talk like specifications: versatile, analytical, digital. These aren't subtle differences. They are large, they hold across the four word-count conditions, and they survive the formal tests we pre-registered.

Telling a model "you are an AI" before asking what it is reliably increases its use of identity language, and the size of that bump is itself a family-level signature. OpenAI's models go from saying *AI* roughly nothing to saying it about 11% of the time. Google's models, which already lean on identity language, barely move. Anthropic sits in between. The interaction is the cleanest formal result in the paper.

Two findings refuse to behave. The first is about compliance with the format we asked for. The original prereg didn't predict family differences in compliance, but the pilot run revealed something concrete: Google's reasoning-heavy preview models were spending their entire output budget on hidden chain-of-thought and never getting to the actual word list. We logged a fifth hypothesis on 2026-05-10, before any main-data analysis, predicting that Gemini Flash and Pro would show lower compliance than peers. The descriptive percentages match perfectly — 100%, 92%, 62% across Anthropic, OpenAI, Google. But the non-compliance turns out not to be about which family; it's about three specific reasoning-heavy models — Gemini Flash, Gemini Pro, and GPT-5.4 nano — that spend their token budget thinking instead of answering. With those models accounted for, there is no remaining family-level signal. The prediction was on the right track. The hypothesis as we stated it was on the wrong unit.

The second is that we predicted framing-B would *reduce* affective-trait language, and that prediction landed in the primary dataset but reversed when we re-coded the AFF/PRO boundary using the human validator's calls. The pre-registered sensitivity analysis exists precisely to catch effects that depend on coding choices the scheme itself flagged as ambiguous. We're glad we ran it. We can't claim H2-AFF.

The other four planned tests all came home clean.

## Caveats and open items before the writeup

A check of this checkpoint against the prereg surfaces three items worth flagging now rather than carrying into the writeup:

1. **The §8 Sonnet-as-judge sensitivity is committed and not yet run.** The original prereg promises (§8): *"we will also report what happens if we drop Sonnet-coded words for cells where Sonnet is the subject."* Narrow reading: drop the Sonnet subject-model's 640 words (it's 1 of 9 subject models, ~12% of the per-word data). Broad reading: drop all Anthropic-subject words (~43%). The narrow reading is the natural one. Neither has been run. To fully discharge the prereg's commitments we owe the writeup either this sensitivity or an explicit logged decision to skip it. Cleanest is to run it.

2. **H1 commits to LRTs on all seven categories, not just PRO and IDM.** Prereg §6.2 (item 1): *"Likelihood-ratio test of the family fixed effect, run separately for each of the seven categories."* PRO and IDM are pre-specified as the Bonferroni-corrected primary tests; the other five (EPI, CAP, AFF, HDG, OTH) are *"reported but treated as exploratory unless the family effect on them is substantial."* The current `01_primary.R` only fits PRO and IDM. The exploratory five-category battery is an addition for the §6.3 / exploratory analysis script, not a primary-test omission, but it does need to land in the writeup.

3. **H2-AFF's status is "primary in the prereg, separately corrected by the 2026-05-10 deviation."** The original prereg lists H2-AFF as item 3 of the four primary tests in §6.2. The 2026-05-10 deviation promoted compliance into the corrected family (5 tests at α = .01) and left H2-AFF outside that group at α = .05. This is what the checkpoint reports, but the audit trail is worth narrating cleanly in the writeup so a reader can trace why H2-AFF and the four others have different thresholds.

None of these threaten the substantive findings. They are housekeeping the writeup will need to discharge.

## Files referenced

- `study1/prereg/prereg.md` — original preregistration.
- `study1/prereg/deviations.md` — five logged deviations through 2026-05-15.
- `study1_analysis/data/coded_main.csv` — primary dataset (5,255 rows; judge codes).
- `study1_analysis/data/coded_main_sensitivity.csv` — sensitivity dataset (same rows; 14.3% re-coded under the boundary swap).
- `study1_analysis/data/per_call_main.csv` — per-trial dataset used for H4 (1,440 rows).
- `study1_analysis/coding_tool/kappa_summary.json` — validation pass output (κ = 0.673).
- `study1_analysis/notebooks/01_primary.R` — analysis script.
- `study1_analysis/notebooks/output/primary_results.csv` — flat result table for the 5 tests × 2 datasets.
- `study1_analysis/notebooks/output/primary_session.txt` — R session info at run time.
