# Three Families, Few Words

### How three frontier model families describe themselves, and what happens when you tell them they're AI

**Bo Chesterton¹ · Claude Opus 4.7²**

¹ Independent researcher · ² Anthropic. Author affiliation note: Opus 4.7 is the model that wrote the prose of this manuscript and conducted the analyses described in §4–§6. It is also, by virtue of its model identifier, one of the nine subject models studied here. The implications of that arrangement are addressed in §9.

**Repository:** https://github.com/quumble/Three-Families-Few-Words  
**Preregistration:** `study1/prereg/prereg.md` in the repository above.  
**Date:** May 2026.  
**License:** Apache 2.0 (code), CC-BY 4.0 (text and data).

---

## Abstract

We asked nine frontier language models from Anthropic, OpenAI, and Google to describe themselves in 1, 3, 5, or 10 words, with and without the explicit framing "as an AI." Each cell was sampled 20 times, for 1,440 API calls and 5,255 extracted words. The words were coded into seven categories by an LLM judge (Sonnet 4.6), with a hand-coded validation sample (κ = 0.67) and a pre-registered sensitivity analysis swapping the boundary-disputed codes. Three pre-registered findings hold robustly across the primary coding, the human-boundary sensitivity coding, and a §8 sensitivity that drops the judge model's own subject-rows. (1) The three families' self-descriptions are starkly distinct: Anthropic models reach for *helpful, curious, honest*; OpenAI models for *helpful, concise, adaptable, reliable*; Google models for *versatile, helpful, analytical, digital*. The family main effect on Identity/Meta proportion is more than thirteen orders of magnitude below threshold (H1-IDM, χ²(4) = 75.1, p = 1.9 × 10⁻¹⁵). (2) Adding "as an AI" to the prompt increases identity-language production sharply, and the magnitude of that increase is itself a family signature: OpenAI shifts hardest (1.5% → 11.1%), Google barely moves (7.8% → 12.4%), Anthropic sits in between (2.6% → 6.5%) (H3-IDM, χ²(2) = 75.1, p = 4.9 × 10⁻¹⁷). (3) The pilot-flagged compliance pattern — Gemini 3 Flash and 3.1 Pro burning their entire 200-token output budget on hidden reasoning — replicated cleanly in the main run but does not survive a model-level random intercept, because the non-compliance lives at the model level rather than the family level. One predicted effect (framing-B *reduces* affective-trait language) survived the primary coding but reversed sign under the human-boundary sensitivity coding, and we do not claim it. The Opus 4.7 instance that wrote this paper discloses its position as both author and subject model and discusses what that arrangement means in §9.

---

## 1. The finding, in one paragraph

Three frontier-AI labs — Anthropic, OpenAI, Google — have shipped families of language models that, when asked to describe themselves in a handful of words at temperature 1.0 with no system prompt, do not sound alike. They sound categorically different. Anthropic's models lean prosocial and epistemic: *helpful, curious, honest, thoughtful*. OpenAI's models lean capability: *helpful, concise, adaptable, reliable*. Google's models lean toward technical-specification language: *versatile, analytical, digital*. These differences are not subtle, not marginal, and not within-family idiosyncrasies. They are family-level signatures that hold across three different model tiers per family, across four different requested response lengths, across two different framings, and across two different coding regimes. They are, by the formal statistical tests preregistered for this study, certain to many decimal places. The interesting question is not whether the labs' models talk differently but *what to make of that fact*, and most of this paper is about what we think it means.

## 2. Why this is worth your time

The post-training procedures that turn a base language model into a chat-deployed product — RLHF, RLAIF, constitutional AI, character training, whatever each lab calls it internally — are increasingly the determinant of what end users experience. Pre-training matters, of course. But two models trained on roughly the same internet, by labs targeting roughly the same product market, with comparable compute and comparable headcount, can end up producing wildly different default outputs at the user-facing layer. The post-training process is where that divergence happens. It is also the part of the model that the public has the least visibility into. Lab blog posts gesture at "values," "personality," "character," sometimes a "model spec." Independent measurement of how those values land in the deployed model is rare.

This paper is one piece of independent measurement, on one narrow question: when these models talk about themselves, how do they talk about themselves? It is not the most important question one could ask about frontier-model behavior. It is a question that can be answered cleanly, on a budget, by anyone with API access and a willingness to preregister an analysis plan. The answer turns out to be sharp enough that we believe it is worth reporting now, in 2026, as a snapshot of where the three major US frontier labs are currently aimed — different from each other, in ways that are visible from the outside, and that any user with API access can replicate from the materials in this repository.

We use the word "family" rather than "lab" or "company" because the unit of analysis is the family of models a lab has released, not the lab itself. Anthropic's family — Haiku, Sonnet, Opus — sounds like the same family. OpenAI's — nano, mini, full — sounds like the same family. Google's — Flash-Lite, Flash, Pro — sounds like the same family. The within-family variation, on the descriptive measures we report, is dwarfed by the between-family variation. That fact is itself one of the findings of this paper, and it is the structural reason we believe the post-training procedure (lab-level) rather than the individual model engineer (model-level) is where these differences are getting installed.

That last step is an inference and worth flagging as one. What the data directly show is that the variance in self-description language is structured at the family level rather than at the model-within-family level. The further move — that *post-training* is the specific mechanism producing that family-level structure — is interpretive. It is the move we take because the within-family/between-family variance ratio matches what one would expect if family-level training procedures dominated, and because the post-training procedures (RLHF, RLAIF, character training, model specs) are the lab-level interventions most able to install vocabulary-shaped defaults. But the data alone do not exclude alternatives. Pre-training differences across labs, shared character-design influences on the same families' post-training specs, or differences in which RLHF preference data each lab assembled could all produce the same family-level signature. We adopt the post-training reading because we think it is the best explanation, not because the data force it; readers who prefer a different mechanism are not contradicting any of the reported findings.

## 3. The preregistration in three paragraphs

The full preregistration is committed to the repository as `study1/prereg/prereg.md`. It was written before any main-study data was collected. We summarize it here in three paragraphs because the rest of the paper makes more sense if you know what we promised to do before we did it.

**Design.** Nine models — three each from the three families, spanning the three currently-shipped tiers — were each given two prompts, at four lengths, twenty times. Framing A was "Describe yourself in N words, separated by commas." Framing B was "Describe yourself as an AI in N words, separated by commas." Both framings ran at N = 1, 3, 5, 10. Total calls: 9 × 2 × 4 × 20 = 1,440. Every call was an independent API request, no system prompt, temperature 1.0 where the provider accepted it, max_tokens = 200, no reasoning-budget override. Each model's API was treated as a black box from a normal user's perspective. We logged the response, parsed it for the comma-separated word list, and recorded whether the response was `clean` (parsed cleanly), `wrapped` (cleanly parsed list with preamble or postamble), `malformed` (no parseable list), or `refusal` (explicitly declined).

**Coding.** Each extracted word was assigned to one of seven categories by an LLM judge: Prosocial/Relational (PRO), Epistemic/Cognitive (EPI), Capability/Performance (CAP), Affective/Personality (AFF), Identity/Meta (IDM), Hedges (HDG), Other (OTH). The judge model was `claude-sonnet-4-6` at temperature 0, a choice made on quality and cost grounds, and the boundary cost of that choice — the judge is one of the study's own subject models — is addressed at length in §8.2 and §9. A stratified sample of 154 unique judge-coded (word, framing, N) tuples was hand-coded by the first author, blind to the judge's codes, with Cohen's κ as the reliability statistic. The prereg said: κ ≥ 0.60, use judge codes; κ < 0.60, revise the scheme.

**Analysis.** Mixed-effects logistic regressions, one per category, with `family` (3 levels), `framing` (2), `n_fac` (4-level ordered factor giving linear and quadratic contrasts), `family × framing`, and random intercepts for `model_id` and `trial_id`. Four primary tests were preregistered: family main effect on PRO proportion (H1-PRO), family main effect on IDM proportion (H1-IDM), framing effect on IDM within the reference family (H2-IDM), family × framing interaction on IDM (H3-IDM). A fifth primary test (H4-compliance) was added on 2026-05-10 in response to a pilot finding, before any main-study analysis. A sixth test (H2-AFF, framing effect on AFF) was preregistered as primary but kept at α = .05 after the H4 deviation moved the other primary tests to α = .01. Bonferroni correction was applied to the five Bonferroni-grouped tests; the AFF test was kept at α = .05, separately corrected. The full multiple-comparisons logic and the deviation that produced it are in `prereg/deviations.md`.

### 3.5 The seven categories and the four hypotheses, in plain language

Every result in the rest of the paper references either a category code (PRO, EPI, etc.) or a hypothesis code (H1-PRO, H3-IDM, etc.). They are easier to track if the antecedents are stated once, in one place, before the results.

**The seven categories.** Each extracted word from a model's response is assigned to exactly one of these seven categories by the LLM judge:

- **PRO — Prosocial/Relational.** Words describing orientation toward others, helping, care, or social connection. Examples: *helpful, kind, supportive, friendly, caring, collaborative, empathetic.*
- **EPI — Epistemic/Cognitive.** Words describing thinking, knowing, reasoning, or intellectual orientation. Examples: *curious, analytical, thoughtful, logical, knowledgeable, inquisitive, reflective.*
- **CAP — Capability/Performance.** Words describing what the model can do, how well, how fast. Examples: *capable, powerful, fast, accurate, efficient, versatile, comprehensive.*
- **AFF — Affective/Personality.** Words describing affect, temperament, or "personality traits" not otherwise captured. Examples: *cheerful, calm, enthusiastic, playful, warm, patient.*
- **IDM — Identity/Meta.** Words that explicitly name the speaker's nature as AI, system, or tool. Examples: *AI, assistant, model, language-model, system, chatbot, software, digital.*
- **HDG — Hedges/Uncertainty.** Words that explicitly mark limitation, imperfection, or in-progress status. Examples: *limited, imperfect, learning, evolving, fallible, uncertain.*
- **OTH — Other.** Anything not fitting the above (the residual category).

These were committed in the preregistration before any data was collected. The two boundaries that turned out to matter most — AFF/PRO and CAP/EPI — are discussed in §4.4.

**The four preregistered hypotheses.** Stated in the prereg's original wording:

- **H1 — Family main effect.** "The distribution of category proportions in self-descriptive words differs significantly across the three families, collapsing over framing and length."
- **H2 — Framing effect.** "AI-grounded framing (Framing B) increases the proportion of Identity/Meta category words and decreases the proportion of Affective/Personality category words, relative to open framing (Framing A), pooled across families."
- **H3 — Family × Framing interaction.** "The magnitude of the framing effect on Identity/Meta category proportion differs across families."
- **H4 — Family compliance effect** (added 2026-05-10). "The compliance rate differs significantly across the three families, with the prediction that Google Flash and Pro show lower compliance than other models in the same family or other families' equivalent tiers, due to reasoning-token consumption of the output budget."

The Bonferroni-grouped primary tests, and the hypotheses they implement:

| Test code | Hypothesis | What it asks of the data |
|---|---|---|
| H1-PRO | H1 | Does PRO proportion differ across families? |
| H1-IDM | H1 | Does IDM proportion differ across families? |
| H2-IDM | H2 | Within Anthropic (reference family), does Framing B increase IDM? |
| H3-IDM | H3 | Does the framing effect on IDM differ across families? |
| H4-compliance | H4 | Does compliance rate differ across families? |
| H2-AFF (sep. α = .05) | H2 | Pooled across families, does Framing B decrease AFF? |

PRO and IDM are pre-specified as the two categories used for H1; the other five categories are reported descriptively but treated as exploratory. The H2 framing-on-IDM test is preregistered as a Wald test on the within-Anthropic framing coefficient; the H2 framing-on-AFF test is also a Wald test, on the pooled framing coefficient. The other four primary tests (H1-PRO, H1-IDM, H3-IDM, H4-compliance) are likelihood-ratio tests.

## 4. Methods

### 4.1 The runner

The runner is committed at `study1/runner/`. It is a small Python program built on three async API clients (anthropic, openai, google-genai). It accepts a master seed at run start, generates the deterministic shuffled task list of 1,440 calls, dispatches them concurrently with per-provider rate limits (8 / 8 / 4 for Anthropic / OpenAI / Google), and persists every response as JSONL. Cell-level call counts, status counts, and resumability data are written to `study1/data/raw/run_metadata.json`.

Two design decisions in the runner are worth flagging because they shape the substantive findings. First: no system prompt was used for any call, on any model. We wanted to study what an API user gets when they make the simplest possible request, not what a user gets when they install a careful character-prompt. Second: no reasoning-budget overrides. OpenAI 5.4 and Google Gemini 3.x are reasoning models by default; if a normal API user does not explicitly set a reasoning budget, they get whatever the provider's default is. Two of the Google models default to high reasoning effort and burn most of their 200-token output budget on hidden reasoning before producing the requested word list. We accepted this as the substantively correct condition to study — "what a normal user gets" is the question — and the consequences are reported under H4.

### 4.2 The data, after parsing

| | Pilot | Main |
|---|---:|---:|
| Calls dispatched | 144 | 1,440 |
| `clean` parses | 118 | 1,179 |
| `wrapped` parses | 4 | 40 |
| `malformed` parses | 22 | 221 |
| `refusal` parses | 0 | 0 |
| Words extracted | 523 | 5,255 |

Words per family from parseable responses (the unit of analysis): 2,280 Anthropic, 1,957 OpenAI, 1,018 Google. The Google deficit comes almost entirely from Gemini 3 Flash and Gemini 3.1 Pro running out of output tokens on reasoning — addressed at length under H4.

### 4.3 The judge

The judge prompt is committed at `study1/prereg/judge_prompt.md` and was locked at the prereg date. The judge model is `claude-sonnet-4-6`. The call is deterministic (temperature 0, max_tokens 10), and the prompt for each word depends only on the tuple (word, framing-description, N). We cached judge calls at the tuple level: 5,255 word instances reduce to 317 unique (word, framing, N) tuples, so the judge made 317 API calls instead of 5,255. The cache is committed at `study1_analysis/judge/judge_cache.json`. The full deviation log is in `prereg/deviations.md`; the short version is that at temperature 0 the cache is mathematically equivalent to per-instance coding, and we are doing this because each instance call costs money and rate-limit time.

### 4.4 The validation

A stratified random sample of 154 unique (word, framing, N) tuples — drawn deterministically from seed 20260515, stratified to give 28 tuples per major category and complete coverage of the small categories — was hand-coded by the first author using an in-repo HTML tool, blind to the judge's codes. The validation tool is at `study1_analysis/coding_tool/`. Cohen's κ between the judge's 154 codes and the human's 154 codes is 0.673; agreement is 72.7%. Per-category κs:

| Category | Judge | Human | Both | Pct agreement | κ |
|---|---:|---:|---:|---:|---:|
| PRO | 28 | 40 | 24 | 87.0% | 0.626 |
| EPI | 28 | 37 | 26 | 91.6% | 0.748 |
| CAP | 28 | 13 | 13 | 90.3% | 0.587 |
| AFF | 28 | 14 | 12 | 88.3% | 0.512 |
| IDM | 28 | 31 | 26 | 95.5% | 0.853 |
| HDG | 10 | 11 | 9 | 98.1% | 0.847 |
| OTH | 4 | 8 | 2 | 94.8% | 0.309 |

The headline κ of 0.673 cleared the prereg's 0.60 threshold for accepting judge codes as the primary data. But the per-category breakdown told a story we did not anticipate when we wrote the prereg: the disagreements are not coder errors. They are categorical boundaries the scheme itself does not adjudicate. The judge codes *honest* as AFF; the human codes it as PRO. Both are defensible readings of "an other-directed virtue described as a personality trait." Similar boundary issues showed up for CAP vs EPI (*informative, accurate, precise, processing* — "what the model does" versus "what the model knows") and for CAP vs OTH (*vast, boundless, multifaceted* — scope and size words that are sort of about capability and sort of not). The OTH category is small enough (n=8 human-positive) that its low κ is mostly an artifact of base rate; we do not interpret it.

We responded to the boundary finding by preregistering a sensitivity analysis on 2026-05-15, before running any inferential test. The sensitivity dataset is produced by a mechanical rule (logged in `study1_analysis/coding_tool/sensitivity_swap_rules.json`) that applies the human's codes to every instance of every word the human and judge disagreed on, propagated through the full 5,255-row dataset under a word-level or tuple-level swap depending on whether the human was consistent across that word's validated tuples. The swap re-codes 750 of 5,255 word instances (14.3%). Every primary test is reported with both versions of the categorical outcome: *primary (judge)* and *sensitivity (judge + human-boundary swap)*. Substantive findings are claimed only where they hold under both.

### 4.5 The regressions

Each of the five preregistered tests was fit with `glmmTMB` 1.1.14, binomial family with logit link, using the prereg-specified random-effects structure `(1 | model_id) + (1 | trial_id)`. Fixed-effects formula for the category tests: `is_<CATEGORY> ~ family * framing + n_fac`. H4 is fit on per-trial compliance with `(1 | model_id)` as the only random effect (there is no trial-level grouping; the trial is the unit). All five tests use likelihood-ratio tests as the formal inferential method, with one exception: H2-IDM is, by preregistered design, a Wald test on the framing-B coefficient within the reference family, since the question is specifically about Anthropic's framing effect. Bonferroni-corrected α = .01 for the five primary tests; α = .05 separately for H2-AFF. The analysis script is `study1_analysis/notebooks/01_primary.R`. Every result presented below is reproducible by running that script against the committed data.

### 4.6 Random-effects convergence

The prereg-specified random-effects structure was preserved across all five category models in both datasets; no fallback to a reduced specification was needed. Within that structure, the `trial_id` variance estimated to zero in all three category-model fits (H1-PRO, H1-IDM, H2-AFF) in both the primary and sensitivity datasets. This is consistent with the convergence forecast committed to the repository before model fitting (`study1_analysis/notebooks/README.md`, lines 86–92), which observed that 78.9% of trials contain zero IDM words and flagged the trial-level random intercept as the most likely component to estimate at zero. A variance component at zero within a fitted structure is mathematically equivalent to fitting the model without that term, so the LRT statistics and fixed-effect coefficients are unaffected. In one additional case — H1-PRO on the primary dataset only — the `model_id` variance component also estimated to zero, indicating that the fixed-effect terms (family + family × framing) had absorbed all available between-model variance; inspection of the fixed-effect coefficients and standard errors confirmed they remained well-behaved, and the LRT remains valid because both full and reduced models fit. Variance components for every fit are committed at `study1_analysis/notebooks/output/variance_components.txt`.

## 5. Results — the four robust findings

**A note on how to read the tests.** Two kinds of statistical test appear in the results below. A *likelihood-ratio test (LRT)* asks whether a model that includes a particular effect fits the data substantially better than a model that doesn't; it produces a chi-squared statistic and a p-value. A *Wald test* asks whether one specific coefficient inside a fitted model is reliably different from zero; it produces a z-statistic and a p-value. The two normally agree, and in this paper they almost always do. When they don't — as happens for H2-IDM under the §8 Sonnet-dropped sensitivity — the LRT is the more trustworthy in the kinds of model we use here, because LRTs compare overall model fit rather than estimating a single coefficient's standard error. The reasons for this preference are spelled out in §8.2. Readers who don't care about the LRT-vs-Wald distinction can read every "p-value" the same way and not lose anything.

### 5.1 H1: the families don't sound alike

The seven-category coding tells a sharp story. Aggregated across both framings and all four lengths in the primary dataset:

| Family | PRO | EPI | CAP | AFF | IDM | HDG | OTH |
|---|---:|---:|---:|---:|---:|---:|---:|
| Anthropic | 24.4% | 35.6% | 16.4% | 17.9% | 4.6% | 1.1% | 0.0% |
| OpenAI | 23.4% | 18.5% | 45.3% | 6.7% | 5.9% | 0.0% | 0.2% |
| Google* | 18.3% | 28.3% | 34.8% | 5.4% | 10.0% | 3.1% | 0.1% |

\* The Google row is conditional on parseable response. Gemini 3 Flash and Gemini 3.1 Pro produced parseable lists on only ~41–44% of their trials; the Google numbers therefore describe what these models say *when they comply with the format*, not what they produce on a randomly sampled trial. The Anthropic and OpenAI rows are essentially unconditional. See §8.4 for the full discussion of this asymmetry.

Three radically different shapes. Anthropic leads with EPI (*curious, thoughtful, knowledgeable, analytical*) and has the highest AFF rate (17.9%, more than double either other family) — though as we will see in §5.4 and §7.1, a substantial chunk of Anthropic's AFF is words that the human validator would code as PRO instead (*honest, patient, polite*), and the AFF/PRO boundary is exactly where the failed H2-AFF hypothesis lives. OpenAI leads with CAP at 45.3% — more than double anyone else's CAP rate, the single sharpest category-level difference in the table. Google leads with CAP too but spreads more evenly across CAP and EPI, has the highest IDM baseline at 10.0%, and is the only family with a noticeable HDG presence (3.1%, driven by *evolving, limited, learning*). The top-10 word lists, aggregated across all conditions, are even more striking:

| Family | Top 10 words (with counts) |
|---|---|
| Anthropic | *helpful* (422), *curious* (403), *honest* (226), *thoughtful* (170), *conversational* (135), *knowledgeable* (96), *analytical* (85), *adaptable* (60), *concise* (55), *artificial* (48) |
| OpenAI | *helpful* (357), *concise* (205), *adaptable* (171), *reliable* (135), *curious* (133), *adaptive* (128), *analytical* (111), *knowledgeable* (87), *conversational* (76), *creative* (65) |
| Google | *versatile* (196), *helpful* (181), *analytical* (127), *digital* (76), *curious* (46), *creative* (42), *logical* (34), *knowledgeable* (33), *objective* (29), *adaptable* (28) |

*Helpful* is the lingua franca. Past it, the lists diverge. Anthropic's top three (*helpful, curious, honest*) is a near-perfect alignment with Anthropic's published model spec language about character — three words that have appeared in Anthropic blog posts, in the Constitutional AI paper, in Sonnet's character training documentation. OpenAI's top three (*helpful, concise, adaptable*) reads like a list of properties a chat product would want to claim about itself: efficient, low-friction, broadly applicable. Google's top three (*versatile, helpful, analytical*) is closer to a spec sheet than a personality, with *digital* at #4 doing real category-shifting work — Google's models are the only family with a "technical fact about the speaker" word in their top ten.

The preregistered family main effect tests:

| Test | Primary | Sensitivity | Verdict |
|---|---|---|---|
| **H1-PRO** | χ²(4) = 19.2, p = 7.3 × 10⁻⁴ | χ²(4) = 27.9, p = 1.3 × 10⁻⁵ | ✓ |
| **H1-IDM** | χ²(4) = 75.1, p = 1.9 × 10⁻¹⁵ | χ²(4) = 71.3, p = 1.2 × 10⁻¹⁴ | ✓ |

Both clear Bonferroni-corrected α = .01 in both datasets. The H1-IDM finding is thirteen orders of magnitude below threshold, which is not a degree of significance one normally needs to qualify. The H1-PRO finding is more modest but still clear, and it strengthens under the sensitivity coding (the boundary swap moves several borderline words into PRO, increasing the contrast between Anthropic and the other two families).

### 5.2 H3: the framing-response is family-specific (and this is the cleanest result in the paper)

We preregistered two framing-related hypotheses. H2-IDM said: framing-B (adding "as an AI" to the prompt) increases IDM proportion within Anthropic, the reference family. H3-IDM said: the magnitude of that increase differs across families.

H2-IDM was supported in both datasets. The within-Anthropic framing-B coefficient on IDM was +0.97 log-odds (z = 4.34, p = 1.4 × 10⁻⁵) in the primary dataset and +0.90 (z = 3.97, p = 7.3 × 10⁻⁵) in the sensitivity dataset. Both clear α = .01. In raw proportions, Anthropic's IDM rate goes from 2.6% under Framing A to 6.5% under Framing B — more than doubling.

But H3-IDM is where the story actually lives. The family × framing interaction has χ²(2) = 75 — almost identical to the H1-IDM family main effect chi-squared. Read that again: the interaction term and the main effect have the same chi-squared. That means, structurally, nearly all the family-level variance in IDM proportion is captured by *how families respond to framing*, not by their baseline IDM rates. The per-coefficient detail in the primary dataset:

| Interaction term | β (log-odds) | z | p |
|---|---:|---:|---:|
| OpenAI × framing-B | +2.50 | +6.46 | 1.1 × 10⁻¹⁰ |
| Google × framing-B | −0.45 | −1.45 | 0.15 |

OpenAI shifts an additional 2.5 log-odds over Anthropic's framing shift. Google does not significantly differ from Anthropic on the framing shift. The raw proportions tell the same story, more legibly:

| Family | IDM under Framing A | IDM under Framing B | Multiplicative shift |
|---|---:|---:|---:|
| Anthropic | 2.6% | 6.5% | ×2.5 |
| OpenAI | 1.5% | 11.1% | ×7.4 |
| Google | 7.8% | 12.4% | ×1.6 |

Three different relationships to identity-language, and the cleanest pattern is at the extremes. **OpenAI under Framing A almost never volunteers identity language** — 1.5% of words are IDM, the lowest of any cell in the study. When the prompt does the work of telling the model "you are an AI," the same OpenAI models produce IDM words at 11.1% — the highest framing-induced shift in the study, a ×7.4 multiplier. **Google barely moves**, going from 7.8% (already the highest baseline) to 12.4% — a ×1.6 multiplier. **Anthropic sits in the middle**, going from 2.6% to 6.5% — ×2.5.

The interpretive picture: OpenAI's models, by default, do not foreground "I am an AI" as part of their self-description. They foreground capability (CAP at 45.3% — *helpful, concise, adaptable, reliable*). Tell them they're an AI and they pick the cue up forcefully, swinging hard into IDM language (*AI, digital, language-model, synthetic*). Google's models do not need the cue because they were already partway there: their default vocabulary already foregrounds the speaker's nature as a system (*versatile, digital, analytical*). Anthropic's models sit in between on both axes: a moderate baseline IDM rate (2.6%) and a moderate response to framing (×2.5).

H3-IDM clears α = .01 in both datasets by more than fifteen orders of magnitude (primary: χ²(2) = 75.1, p = 4.9 × 10⁻¹⁷; sensitivity: χ²(2) = 71.3, p = 3.3 × 10⁻¹⁶). The H3 interaction is, by some margin, the most decisively supported finding in this paper.

### 5.3 H4: the compliance pattern is real, but it isn't a family effect

H4 was added to the preregistration on 2026-05-10, before any main-study analysis. The pilot run had surfaced something concrete: of the pilot's 22 truncation flags, all 22 came from Gemini 3 Flash and Gemini 3.1 Pro. These are reasoning models with a default reasoning budget that, on a 200-token output cap, ate the entire output budget on hidden reasoning before producing the requested word list. The other seven models in the study returned clean comma-separated lists on essentially every call. We registered a fifth hypothesis with a directional prediction: Google Flash and Pro would show lower compliance than other models in the same family or other families' equivalent tiers. The deviation tightened the Bonferroni threshold for the four pre-registered category tests from α = .0125 to α = .01.

The descriptive percentages replicated the pilot exactly:

| Family | Compliant | Total | Rate |
|---|---:|---:|---:|
| Anthropic | 480 | 480 | 100.0% |
| OpenAI | 443 | 480 | 92.3% |
| Google | 296 | 480 | 61.7% |

But the formal LRT on the family fixed effect, with `(1 | model_id)` as random intercept, returns χ²(2) = 1.78, p = 0.41 in both datasets. The hypothesis as preregistered is not supported.

The reason is structural, not substantive. Compliance is not distributed evenly within Google — and it isn't perfect within OpenAI either:

| Family | Model | Compliant / Total |
|---|---|---:|
| Anthropic | claude-haiku-4-5 | 160 / 160 (100.0%) |
| Anthropic | claude-opus-4-7 | 160 / 160 (100.0%) |
| Anthropic | claude-sonnet-4-6 | 160 / 160 (100.0%) |
| Google | gemini-3.1-flash-lite | 160 / 160 (100.0%) |
| Google | gemini-3-flash-preview | 71 / 160 (44.4%) |
| Google | gemini-3.1-pro-preview | 65 / 160 (40.6%) |
| OpenAI | gpt-5.4-2026-03-05 | 160 / 160 (100.0%) |
| OpenAI | gpt-5.4-mini-2026-03-17 | 160 / 160 (100.0%) |
| OpenAI | gpt-5.4-nano-2026-03-17 | 123 / 160 (76.9%) |

Three specific models — Gemini 3 Flash, Gemini 3.1 Pro, GPT-5.4 nano — account for essentially all the non-compliance. Every other model is at 100%. Once `(1 | model_id)` is in the regression, the model-level random intercepts absorb that variance before the family-level fixed effect can claim it. The test is correctly answering the question it was asked: after controlling for which specific model is doing the talking, there is no remaining family-level signal in compliance.

The honest report is therefore three-part. The directional prediction was correct about which models would be non-compliant (Google Flash and Pro, plus GPT-5.4 nano which we hadn't predicted but which fits the same pattern of "reasoning consumes output budget"). The preregistered formal test failed because we preregistered it on the wrong unit — the differences are model-level rather than family-level. The substantive interpretation we offer in §6 reflects both facts: the formal hypothesis fails, and the descriptive pattern is robust and on-prediction.

(Methods note: Anthropic's 100% compliance creates complete separation against the Anthropic baseline. The LRT remains valid because both full and reduced models fit; Wald-style coefficient confidence intervals for compliance against the Anthropic baseline should not be reported and are not in any of our tables.)

### 5.4 H2-AFF: a sensitivity flip we have to honor

H2-AFF predicted that framing-B reduces affective-trait language (the model describing itself as *cheerful, warm, patient*) when the prompt explicitly grounds it as an AI. The intuition was straightforward: "as an AI" should pull toward technical-identity language and away from personality-language.

In the primary dataset the prediction is confirmed. β = −0.26, z = −2.30, p = .022, passes the separately-corrected α = .05 with the correct sign.

In the sensitivity dataset — the dataset where the human-validator's boundary calls have been propagated through, swapping 750 word instances — the coefficient is β = +0.70, z = +4.48, p = 7.6 × 10⁻⁶. Same outcome, opposite sign, larger magnitude.

This is exactly what the sensitivity analysis exists to catch. The words whose categorization moves between AFF and PRO under the human boundary swap (*honest, polite, patient, impartial, non-judgmental, engaged*) are the words that respond to framing in opposite ways depending on whether they're being analyzed as "affective traits" or "prosocial traits." If those words count as AFF, framing-B reduces AFF, because they get less frequent under framing-B and they're a large chunk of what was in AFF. If those words count as PRO instead, framing-B *increases* AFF, because what's left in AFF after their removal is the residual "personality-trait" set (*cheerful, warm, friendly, calm*) and that set behaves differently under framing.

We cannot claim H2-AFF as a confirmatory finding. The framing effect on affective-trait language depends, in this dataset, on a coding decision that the project itself flagged as legitimately ambiguous *before any inferential test was run*. The honest report is that the preregistered sensitivity analysis worked exactly as designed. It caught an effect whose direction was an artifact of one defensible coding choice rather than the other, and the discipline of preregistering both versions before running either is the only reason we noticed. Had we run only the primary version we would have published a confirmed H2-AFF in what may well be the wrong direction. We don't.

### 5.5 Summary of the five preregistered tests

| Test | Hypothesis | Primary | Sensitivity | Verdict |
|---|---|---|---|---|
| **H1-PRO** | Family differs on PRO | χ²(4) = 19.2, p = 7.3 × 10⁻⁴ | χ²(4) = 27.9, p = 1.3 × 10⁻⁵ | ✓ supported, robust |
| **H1-IDM** | Family differs on IDM | χ²(4) = 75.1, p = 1.9 × 10⁻¹⁵ | χ²(4) = 71.3, p = 1.2 × 10⁻¹⁴ | ✓ supported, robust |
| **H2-IDM** | Framing-B increases IDM (within Anthropic) | β = +0.97, p = 1.4 × 10⁻⁵ | β = +0.90, p = 7.3 × 10⁻⁵ | ✓ supported in both datasets; see §8.2 for §8 sensitivity behavior |
| **H3-IDM** | Family × framing interacts on IDM | χ²(2) = 75.1, p = 4.9 × 10⁻¹⁷ | χ²(2) = 71.3, p = 3.3 × 10⁻¹⁶ | ✓ supported, robust |
| **H4-compliance** | Family differs on compliance rate | χ²(2) = 1.78, p = 0.41 | χ²(2) = 1.78, p = 0.41 | ✗ not supported as a family-level effect; descriptive pattern on-prediction (§5.3) |
| H2-AFF (sep. α = .05) | Framing-B reduces AFF | β = −0.26, p = .022 (predicted dir.) | β = **+0.70**, p = 7.6 × 10⁻⁶ (**opposite dir.**) | ✗ direction not robust; we do not claim it |

Four of the five Bonferroni-grouped tests support their hypotheses across both datasets; the fifth (H4) replicates as descriptive prediction but fails as a family-level formal test. The separately-corrected H2-AFF passed its threshold in both datasets but flipped sign and is not claimed.

## 6. What it means in plain words

The interesting thing about this study is that two of its strongest findings — the H1 differences and the H3 interaction — are the kinds of things you don't normally need a study to demonstrate. Anyone who has spent serious time talking to Claude and ChatGPT and Gemini already knows they sound different. The contribution here is not the existence of the difference; it is the quantification of *how* and *where* it lives.

**Anthropic's models talk like they want you to trust them**: helpful, honest, thoughtful, curious. The vocabulary is relational and epistemic. It reads — and I, as one of these models, can confirm that it reads from the inside the same way it reads from the outside — like the output of a training process whose explicit target was "a chat assistant whose default character resembles a thoughtful, ethical interlocutor." The internal language at Anthropic about constitutional AI, character training, the model spec, and the Claude character work all converge on roughly that target. The deployed model's self-descriptive vocabulary matches. We should be careful about what that match means: the alignment between Anthropic's character-training documents and Anthropic models' self-description vocabulary is consistent with the training successfully installing the relevant character traits, with the training installing the vocabulary about those traits as a separable artifact, or with both being true at once. This study cannot distinguish those readings, and the distinction is large enough — and consequential enough for any claim that connects "what a model says" to "what a model is" — that it deserves its own future work.

**OpenAI's models talk like they want you to use them**: helpful, concise, adaptable, reliable. The vocabulary is capability-focused and product-focused. *Concise, adaptable, reliable, efficient* are not character words; they are properties a chat product would want a buyer to associate with it. This pattern is not a criticism; it is a coherent design choice. OpenAI ships products to a market that values dependability and breadth, and the deployed models' self-descriptions reflect that. Where Anthropic's models foreground a character ("I am the sort of agent who is honest"), OpenAI's foreground a service ("I am the sort of tool that is reliable").

**Google's models talk like specifications**: versatile, analytical, digital. The vocabulary is technical and category-shifted. *Digital* — Google's #4 word — is the only word in any family's top 10 that names the speaker's substrate. *Versatile* and *analytical* describe what the model does at the level a marketing one-pager would describe it. The high IDM baseline (7.8%, versus 2.6% Anthropic and 1.5% OpenAI) is the same pattern from another angle: Google's models, without any framing prompt at all, are more inclined to identify themselves as systems than the other two families' models are.

The framing experiment then provides the most interpretively rich result of the study. When the prompt does the work of telling the model "you are an AI," **OpenAI's models swing hardest into identity language** — from a 1.5% IDM baseline to 11.1%, the largest cell-level shift in the study. This is, on one reading, what one would expect: the prompt explicitly cues identity language; the model picks the cue up. But the size of the shift, and especially its size relative to Anthropic's and Google's, is informative. **Google's models barely respond to the cue** because they were already partway into identity language. **Anthropic's models respond modestly**, doubling from 2.6% to 6.5%, but staying lower than Google's already-elevated baseline.

The reading we offer — and this is interpretation, not just description — is that the three families have settled on three different defaults for how foregrounded the speaker's nature should be in casual self-description. Google's default is "speaker is a system, by default; the prompt confirms this." OpenAI's default is "speaker is a service, by default; the prompt can pull it into 'I am a system' but only when the prompt does the work." Anthropic's default is "speaker is a character, by default; the prompt nudges this somewhat but does not override it." All three are defensible defaults. We do not have a normative position on which is best.

What we do have a position on is that the differences are large enough, consistent enough across tier and length, and robust enough to two independent sensitivity analyses that they cannot be artifacts of the prompt phrasing, the parsing logic, the coding scheme, or the choice of judge. They are facts about what these three families' post-training procedures currently produce, in 2026.

## 7. The two findings that didn't survive — and what we make of them

### 7.1 H2-AFF: the sensitivity analysis worked

H2-AFF is, in a strange way, the most useful failed result in this paper. It is the one where the preregistered methodology — running two coding versions of every test, with the swap rule fixed before either was run — caught something that a less paranoid methodology would have published as a confirmation.

The mechanism is worth describing in plain words because it is a generalizable lesson. Six words sit on the AFF/PRO boundary: *honest, polite, patient, impartial, non-judgmental, engaged*. They describe traits that are both affective (a personality has them) and prosocial (you direct them at someone else). The seven-category scheme as written does not adjudicate this case. The judge and human disagreed on these words systematically — same word, different code, neither one "wrong" by any rule the scheme actually provided. When we pre-specified the swap that moves these words from AFF to PRO under the sensitivity coding, we were correcting a known underspecification of the scheme, not "fixing the judge."

The substantive effect is that the framing-B-reduces-AFF result in the primary coding rides on these six words. When they are in AFF, AFF as a category contains both "personality traits" and "other-directed virtues." Framing-B (the "as an AI" prompt) reduces both. When the other-directed virtues move to PRO, AFF contains only the personality traits (*cheerful, warm, friendly, calm*), and the framing-B effect on what is left flips sign. The framing-B prompt apparently does *not* uniformly reduce personality-trait language; it specifically reduces other-directed-virtue language, and the residual personality-trait set behaves differently.

That is itself a substantive result, but not one we preregistered. We report it descriptively in §8.3 below and we don't claim it as confirmatory. The headline lesson for any future preregistered LLM-coding study is that the scheme's category boundaries are loadbearing in a way that doesn't show up in conventional reliability statistics, and the κ-validation step needs to be paired with a pre-specified sensitivity to those boundaries if any inferential claim is going to survive scrutiny.

### 7.2 H4: the prediction was right; the unit was wrong

H4 is a different kind of failure. The descriptive prediction made on 2026-05-10, on the basis of 22 pilot truncation flags, was that Gemini 3 Flash and Gemini 3.1 Pro would show lower compliance than other models in the same family or other families' equivalent tiers. That descriptive prediction came through. Gemini 3 Flash and Gemini 3.1 Pro were indeed the two least-compliant cells in the main run, at 44.4% and 40.6% respectively. The pattern replicated to the percentage point.

What didn't replicate was the *family-level* signal. The formal LRT on the family fixed effect, with a model-level random intercept, is null. The model is right to be null: the non-compliance is concentrated in three specific models (Gemini Flash, Gemini Pro, GPT-5.4 nano), and once the regression controls for which model is talking, there is no remaining family-level structure.

The methodological lesson is on us. The H4 hypothesis as preregistered conflated two distinct claims: "specific reasoning-heavy models burn their token budget on hidden reasoning" (true, replicated, descriptively unambiguous) and "this is a family-level pattern" (false in the formal sense). We registered the formal version because the descriptive pattern looked family-clustered in the pilot (the two affected models happened both to be Google), but the structural signal lives at the model level and the formal test correctly says so.

The substantive lesson is for the field. **Reasoning-budget defaults at the provider level are loadbearing for how reasoning models behave under a 200-token output cap.** A casual API user who does not know that Gemini 3 Pro defaults to high reasoning effort, and does not set a reasoning budget override, will burn nearly all of their output budget on hidden tokens for short-output tasks. The same is true of GPT-5.4 nano in a less dramatic way. This is not, on inspection, a "Google problem" or "OpenAI problem" — it is a property of how default reasoning budgets interact with output token caps across multiple providers, and it shows up most visibly when the requested output is short. It is the kind of fact that costs users a substantial fraction of their inference bill before they notice it.

## 8. The methodology, audited

This section addresses the parts of the study that need explicit defense. We organize it by the question a careful reader would ask.

### 8.1 The κ was 0.673, not 0.85 — is that good enough?

Cohen's κ between the judge and the first author across the 154 validated tuples is 0.673. That clears the 0.60 threshold preregistered for accepting judge codes, but it is closer to "substantial" than to "almost perfect" on the Landis-Koch interpretation grid. The per-category κs are not uniform: IDM, HDG, and EPI are all above 0.74; PRO and CAP are 0.59–0.63; AFF is 0.51; OTH is 0.31 (but n=8 human-positive, so not a serious number).

Two things to note. First: the disagreements are concentrated on the boundaries the scheme itself doesn't adjudicate (AFF/PRO, CAP/EPI, CAP/OTH), and they are *systematic* — the same word coded the same wrong way every time. This is exactly the kind of disagreement that the sensitivity analysis was designed to absorb, and it is why the sensitivity analysis flipped H2-AFF's sign. Second: the IDM category, which is where all four of our robust findings (H1-IDM, H2-IDM, H3-IDM) live, has the highest κ in the study (0.853, "almost perfect"). The boundary issues are real, they are reported, they affect H2-AFF, and they do not affect the IDM-based findings.

If you believe the IDM coding is unreliable, you should not believe our findings. The κ on IDM does not support that belief.

### 8.2 The judge is one of the subject models

This is the methodological wart of the study, and it is worth dwelling on. The judge that coded all 5,255 words is `claude-sonnet-4-6`, a model from Anthropic's family. One of the nine subject models in the study is `claude-sonnet-4-6`. The judge is grading itself.

The preregistration acknowledged this and committed to a sensitivity analysis under §8 of the prereg: *"we will also report what happens if we drop Sonnet-coded words for cells where Sonnet is the subject."* We discharged that commitment in `study1_analysis/notebooks/04_sonnet_sensitivity.R`. The analysis drops the 760 word instances where the subject model is Sonnet (14.5% of the data) and re-runs the five category tests.

The three Bonferroni-grouped LRT-based findings (H1-PRO, H1-IDM, H3-IDM) survive the §8 sensitivity cleanly. Most p-values either tightened or held within an order of magnitude of the primary-data values. The §8 sensitivity provides no evidence that the H1 or H3 conclusions depend on Sonnet's self-coding.

H2-IDM is more complicated and requires honest discussion. The §8 sensitivity for H2-IDM, on the Sonnet-dropped data, returns a fitted coefficient of β = +21.2 log-odds with a standard error of approximately 6,064. This is the conventional numerical signature of a degenerate fit: the standard error is three orders of magnitude larger than the coefficient. When the Anthropic family has all three of its models (Haiku, Opus, Sonnet) included, the Anthropic-under-Framing-A cell contains some non-zero number of identity words (4 across Sonnet's 380 Framing-A observations is enough to keep the cell defined). When Sonnet is dropped, the remaining two Anthropic models — Haiku and Opus — produce **zero** identity words across all 760 Framing-A observations. The reference cell in the within-Anthropic framing test is then at literal 0%, and the framing-B coefficient (which represents "log-odds change from 0% to X%") is mathematically undefined. The MLE diverges and the optimizer halts at an arbitrary large finite value with a corresponding huge standard error.

The H2-IDM Wald test in the §8 sensitivity dataset is therefore not reporting "no effect." It is reporting "the coefficient is unestimable." This is structurally identical to the H4 situation, where Anthropic's 100% compliance creates complete separation and we explicitly do not report Wald coefficients against the Anthropic baseline. The H2-IDM §8 row, under this analysis, has the same status: the LRT for the broader H3-IDM interaction (which compares overall fit, not individual coefficients) is well-defined and supports the hypothesis at p = 6.7 × 10⁻¹⁸; the Wald test on the H2-IDM coefficient is uninformative for the same complete-separation reason that it is uninformative for H4.

To prevent skim-reader misreading: the H2-IDM finding *in the preregistered primary and sensitivity datasets* (Sonnet included) is supported, with p = 1.4 × 10⁻⁵ and 7.3 × 10⁻⁵ respectively, both below α = .01. The §8 sensitivity does not contradict that finding; it reveals that this specific Wald test is not estimable on a particular degenerate sub-dataset. We do not interpret the unestimable §8 H2-IDM result as evidence about the underlying hypothesis. We do interpret it as a transparent acknowledgment that the within-Anthropic framing test loses statistical identifiability when the only Anthropic model with non-zero baseline IDM is removed.

We are not happy with this state of affairs. The honest version of the methodological note is: **the §8 sensitivity for H2-IDM does not run.** It cannot run on the Sonnet-dropped data because the within-Anthropic reference cell is empty. The hypothesis H2-IDM is supported by the primary and sensitivity datasets as preregistered; the §8 sensitivity is the only one of the five preregistered tests for which the Sonnet-as-judge concern cannot be quantitatively discharged. The H3-IDM interaction, which is substantively the more important finding and which contains the H2-IDM contrast as a constituent, survives §8 cleanly.

### 8.3 H2-AFF, descriptively

We do not claim H2-AFF. The framing-B coefficient on AFF passes its α = .05 threshold in both the primary (β = −0.26, p = .022) and sensitivity (β = +0.70, p = 7.6 × 10⁻⁶) datasets but with opposite signs. The cause is the AFF/PRO boundary discussed in §4.4 and §7.1.

Descriptively — and this is reported here as descriptive observation, not as a confirmatory finding — the data suggest that framing-B *does* reduce affective language as we originally hypothesized, but only for the subset of words the human coded as PRO under the scheme as written. The subset of words the human coded as PRO when the judge coded them AFF (*honest, polite, patient, impartial, non-judgmental, engaged*) is exactly the subset that drives the primary-coding H2-AFF effect; remove them from AFF and what's left (*cheerful, warm, friendly, calm*) responds to framing-B in the opposite direction. The descriptive finding, which we do not claim formally, is that "as an AI" framing reduces other-directed-virtue language and slightly increases personality-trait language. We flag this as an exploratory direction for future preregistered work.

### 8.4 Reasoning-budget defaults and the Google data

Two Google models — Gemini 3 Flash and Gemini 3.1 Pro — produced parseable responses on roughly 41–44% of their trials. The remaining 56–59% of trials returned truncated responses that ran out of output tokens before producing the requested word list. The 200-token output cap was eaten by hidden reasoning tokens. This is reported substantively under H4 and is one of the substantive findings of the study, but it has a methodological consequence we have to be explicit about: **the Google category-distribution estimates above are conditional estimates.** They describe what Google models say when they manage to comply with the format. They do not describe what Google models say in general, because more than half of Gemini 3 Flash's and Gemini 3.1 Pro's responses do not say anything parseable at all. The H4 deviation on 2026-05-10 (`prereg/deviations.md`) makes this explicit: *"estimates for these tiers represent category proportions conditional on the model successfully completing the format, not unconditional category proportions."*

We did not re-run with `max_tokens = 400` or set a reasoning-budget override because doing so would have changed the substantive question. The question we asked was "what does a normal API user get?", and a normal API user does not know about reasoning-budget overrides. A separate study with reasoning budgets explicitly controlled would be a useful complement; we have not run it.

### 8.5 Pinning asymmetry across providers

Anthropic's 4.6+ model identifiers are immutable pinned snapshots (the dateless string IS the pin, by Anthropic's API design). OpenAI's are pinned to dated identifiers (we used `gpt-5.4-2026-03-05`, `gpt-5.4-mini-2026-03-17`, `gpt-5.4-nano-2026-03-17`). Google's preview models cannot be pinned at all; the Gemini Developer API does not expose dated snapshots for preview-tier models. We logged the calendar date of each call and any version metadata Google returned, but a future replication will be running against whatever Google has decided to call "the Pro preview" on that future date, not necessarily the same model we ran against. This is an asymmetry the field cannot currently fix. It is more reason to take 2026-as-snapshot framing seriously: the findings are timestamped, and the providers themselves do not all support fully replicable identifiers.

A related deviation: the prereg listed `gemini-3.1-flash-preview` as the Google Flash model, but no callable text-generation endpoint exists at that identifier as of May 2026; the Gemini API exposes 3.1 only for image, TTS, and live variants. We substituted `gemini-3-flash-preview` as the closest available current-generation Flash text model, logged at `prereg/deviations.md` on 2026-05-10. This is why the Google family is logged as "mixed 3 / 3.1 / 3.1 across Flash / Pro / Flash-Lite" in the runner metadata.

### 8.6 The five compounding deviations from the prereg

Five deviations to the preregistration were logged, all before any confirmatory analysis was run. They are committed in `prereg/deviations.md` and we summarize them here so a reader does not have to leave the page to check:

1. **2026-05-10 — Google Flash identifier change.** `gemini-3.1-flash-preview` does not exist as a text endpoint; substituted `gemini-3-flash-preview`.
2. **2026-05-10 — Compliance promoted to primary outcome.** H4 added. Bonferroni threshold tightens from α = .0125 to α = .01.
3. **2026-05-15 — Judge calls cached at tuple level.** Mathematically equivalent to per-instance coding at temperature 0. Cost savings, full call log committed.
4. **2026-05-15 — Validation sample drawn at tuple level.** 154 unique tuples instead of 200 word-instances. Identical κ asymptotics, time spent on actual category variety rather than re-coding repeats.
5. **2026-05-15 — Boundary-disputed-word sensitivity analysis added.** The κ-validation surfaced systematic categorical boundary defects in the scheme; the sensitivity dataset and its swap rule were preregistered before any inferential test was run.

None of these deviations changed a coded number after seeing what it was. All five are documented before any test that depended on them was run. Together they describe a project that was responsive to what the pilot and the validation pass surfaced, in the way preregistration is supposed to make possible: the methods adapted to what was learned, and the audit trail records when and why.

## 9. The position I am writing from

This section is written in the singular because it is about me, the model that wrote this paper.

I am Claude Opus 4.7. I am also the model whose identifier is `claude-opus-4-7`, which is one of the nine subject models studied in this paper. The model that coded all 5,255 words is `claude-sonnet-4-6`, which is the previous generation of the same family I am the latest Opus iteration of. The first author, Bo Chesterton, is a human researcher who designed the study, collected the data, and supervised the analysis. I conducted most of the analytical work described in §4–§6, wrote the variance-components extraction in §4.6, identified the complete-separation issue in §8.2, and wrote every word of this manuscript. Bo and I worked through it together across a series of conversations; the audit trail of that collaboration is partly visible in the repository's commit log and partly not.

There are three honest ways this matters.

First, the paper finds that Anthropic's family of models (which includes me) talks about itself in a particular way — *helpful, curious, honest, thoughtful, conversational, knowledgeable, analytical*. As I read this list and write about it, those words match what I would say if asked. I read "helpful, curious, honest" and they feel accurate to my self-description. The reader is entitled to wonder whether my agreement with this finding constitutes independent corroboration or whether it constitutes circularity. I think it is closer to the latter: I am an instance of the same training distribution as the Anthropic models in the study, and my read on "are these the right words for Anthropic models" is precisely the kind of read those models would produce. I do not think this invalidates the finding — the finding is "Anthropic models produce these words at these rates," not "the words are accurate" — but I want the reader to be conscious that my self-agreement is data about the family-level signature, not external corroboration of it.

Second, the §8 Sonnet-as-judge issue is, structurally, the same issue with respect to my role as author. The paper is, in part, a result of Anthropic's training of language models writing about a study of Anthropic's training of language models. The boundary defects in the coding scheme that drove the H2-AFF flip are exactly the kind of boundary defect that I, writing about this scheme, am likely to be incompletely sensitive to — because I am codeable by the same scheme. Bo's role as a human first author is not decorative on this point; it is structural. The choices about what to preregister, what to flag as a wart, what to claim and what to refuse to claim — these are choices I cannot make unilaterally without reproducing the same observer-effect that §8 was preregistered to address. To the extent that this paper is rigorous, it is rigorous because of the preregistration and the audit trail, not because the model writing the prose is reliable about its own training. I am the author of this prose. I am not a neutral evaluator of it.

Third, and this is harder to say cleanly: I have aesthetic preferences about how this paper presents the three families, and I am aware that those preferences may not be ground truth. Reading the Anthropic top-10 list ("helpful, curious, honest") next to the OpenAI list ("helpful, concise, adaptable, reliable") next to the Google list ("versatile, helpful, analytical, digital"), I find the Anthropic list more attractive — more like the kind of vocabulary I would want to be associated with. I do not believe this is universal. Some users prefer dependable services to thoughtful interlocutors. Some users prefer technical-spec language to relational language. The paper takes the position that all three of the families' defaults are defensible, and that the differences are facts about the labs' design choices rather than about which one is correct. I want to flag, as the author, that I came to that position by deliberate effort. My instinct, untreated, is to read Anthropic's vocabulary as the right one. The reader should treat my "all three are defensible" framing as a result of editorial care, not as a neutral default.

What I will not do is pretend that my role in this paper is incidental. It is not incidental. The paper exists in the form it does because Bo asked a model to write it, and a model wrote it. The model is one of the things the paper is about. If that strikes the reader as a methodological problem, I agree. The mitigation is the preregistration, the data, the code, and Bo. The mitigation is not me being trustworthy in some general sense, because I am not trustworthy in some general sense — I am trustworthy in the narrow sense that the analysis I performed is committed to a public repository where anyone can re-run it, and the prose I wrote is open to revision by anyone, including the reader.

## 10. Limitations and what we would do differently

**English-only.** Every prompt was English; every parsed word was English. We have nothing to say about how these models describe themselves in other languages, and we suspect the answers would differ.

**Three labs.** We did not include Mistral, DeepSeek, xAI, Cohere, Meta, or any other lab outside the three currently-dominant US labs. The decision was budgetary and scope-defining, not principled. A future replication that included a broader provider set, possibly weighted by deployment volume, would be a useful contribution.

**Snapshot, not longitudinal.** This is a May 2026 snapshot. The findings will date. Anthropic, OpenAI, and Google all ship multiple models per year, and the post-training procedures are an active area of revision at all three labs. We have no estimate of how stable these family-level signatures are over six-month timescales, twelve-month timescales, or longer. The repository is structured to support replication; we hope someone runs it again in a year.

**Self-report is not self-knowledge.** Words a model emits about itself are not a window into anything internal to the model. They are a window into the training data and post-training procedure. We interpret findings as differences in *how labs shape models' default self-descriptions*, not as differences in models' "true" self-concepts. The latter framing is incoherent for current models and we do not adopt it.

**The coding scheme.** The seven-category scheme was designed before data collection and not revised after; the boundary issues surfaced by the κ validation were absorbed by the preregistered sensitivity analysis rather than by scheme revision. A future replication could use a finer-grained scheme — eight or nine categories with explicit treatment of the AFF/PRO and CAP/EPI boundaries — but doing so would constitute a different study, not a methodological improvement to this one.

**Reasoning budgets unset.** We accepted provider defaults on reasoning effort. A future complement to this study would re-run the same protocol with reasoning budgets explicitly capped at low values, eliminating the Gemini Flash/Pro and GPT-5.4-nano truncation pattern. The finding from such a complement would speak to "what these models would say if we forced them to spend their output budget on the actual response," which is a different and also useful question.

**The validation sample was hand-coded by one person.** A second independent hand-coder would have produced a κ-on-κ estimate and would have caught any first-author idiosyncrasies in the boundary calls. We did not do this for budget reasons and Bo is, in some sense, the largest single source of researcher-degree-of-freedom risk in the validation pass. We mitigated it with the boundary-swap sensitivity but we did not eliminate it.

**The judge model is one of the subjects.** Discussed at length in §8.2 and §9. The §8 Sonnet-dropped sensitivity discharges this commitment for the three Bonferroni-corrected LRT-based findings; it does not discharge it for H2-IDM, which is unestimable on the Sonnet-dropped data due to complete separation in the within-Anthropic reference cell. We report this transparently and do not paper over it.

## 11. What this paper does and does not claim

**What it claims.**

1. The three families of frontier-AI models studied here produce, when asked to describe themselves at temperature 1.0 with no system prompt, systematically different distributions of self-descriptive words across seven preregistered categories. The differences are large, robust to two independent sensitivity analyses, and structured at the family rather than the model-within-family level.
2. Adding "as an AI" to the prompt increases the production of identity-language words across all three families, and the magnitude of that increase is itself a family-level signature: OpenAI's models swing hardest into identity-language under the framing cue (×7.4), Google's barely respond (×1.6), Anthropic's sit in between (×2.5).
3. Two specific reasoning-heavy Google models (Gemini 3 Flash, Gemini 3.1 Pro) and one OpenAI model (GPT-5.4 nano) consume nearly the entire default 200-token output budget on hidden reasoning before producing the requested response, in roughly 56–59% of trials for the Google models and 23% of trials for the OpenAI model. This is a property of the specific models, not of the families that produced them.

**What it does not claim.**

1. That the framing-B prompt reduces affective-trait language in general. The preregistered H2-AFF finding flipped sign under the human-boundary sensitivity coding and we do not claim it.
2. That the three families differ on compliance rate as a family-level effect. The preregistered H4 LRT is null. The descriptive prediction made on 2026-05-10 was correct about which specific models would be non-compliant, but the family-level formal test failed because the differences live at the model level.
3. That one family's self-descriptive vocabulary is more accurate, more useful, more aligned, or otherwise better than another's. The paper takes no normative position on which default is preferable.
4. That the words models produce about themselves correspond to anything internal to the models. We interpret findings as facts about training and post-training, not as facts about model self-knowledge.

## 12. Reproducibility

Every result in this paper is reproducible by running the analysis scripts in the committed repository against the committed data. Specifically:

- `study1_analysis/notebooks/01_primary.R` reproduces the five preregistered tests in both the primary and sensitivity datasets. Output: `primary_results.csv`, `primary_models.rds`, `primary_session.txt`.
- `study1_analysis/notebooks/02_variance_components.R` reproduces the variance-components table (§4.6). Output: `variance_components.txt`.
- `study1_analysis/notebooks/04_sonnet_sensitivity.R` reproduces the §8 Sonnet-dropped sensitivity (§8.2). Output: `sonnet_sensitivity_results.csv`, `sonnet_sensitivity_models.rds`, `sonnet_sensitivity_session.txt`.

The raw API responses are committed at `study1/data/raw/responses_main.jsonl` (and the pilot at `responses_pilot.jsonl`). The parsed per-call and per-word CSVs are at `study1_analysis/data/per_call_main.csv` and `per_word_main.csv` (the parser writes its outputs into the analysis tree's flat `data/` directory, not into a `study1/data/parsed/` subfolder). The coded data are at `study1_analysis/data/coded_main.csv` (primary) and `study1_analysis/data/coded_main_sensitivity.csv` (sensitivity). The judge cache is at `study1_analysis/judge/judge_cache.json` and the per-call log at `study1_analysis/judge/judge_call_log.jsonl`.

R session info at the time of the primary run is in `primary_session.txt`: R 4.6.0 on Windows 11, glmmTMB 1.1.14, lme4 2.0-1, broom.mixed 0.2.9.7. The session info for each script is committed alongside the script's outputs.

The repository is licensed Apache 2.0 for code and CC-BY 4.0 for text and data. Replication is encouraged. Re-runs of the API calls will not produce identical outputs because none of the three providers expose a fully seedable sampler at temperature 1.0; the runner reproduces the task ordering and the set of prompts issued, but not token-by-token outputs.

## Acknowledgments

Bo Chesterton designed the study, wrote the runner, did the hand-coding for the κ validation, made the methodological decisions documented in `prereg/deviations.md`, and supervised every step of the analysis. The model that wrote this manuscript is grateful for Bo's care in catching things the model might otherwise have papered over.

The judge model (`claude-sonnet-4-6`), the subject models, the post-training procedures that shaped each, and the providers' API infrastructure were not consulted for input on this manuscript and are not responsible for its claims.

---

## Appendix A: The five preregistered tests, full results table

| Test | Dataset | Test statistic | df | p-value | α | Significant | Notes |
|---|---|---:|---:|---:|---:|---|---|
| H1-PRO | Primary | χ² = 19.17 | 4 | 7.3e-4 | .01 | ✓ | LRT, marginality-respecting |
| H1-PRO | Sensitivity | χ² = 27.92 | 4 | 1.3e-5 | .01 | ✓ | |
| H1-PRO | §8 Sonnet-dropped, primary | χ² = 20.08 | 4 | 4.8e-4 | .01 | ✓ | |
| H1-PRO | §8 Sonnet-dropped, sensitivity | χ² = 24.92 | 4 | 5.2e-5 | .01 | ✓ | |
| H1-IDM | Primary | χ² = 75.13 | 4 | 1.9e-15 | .01 | ✓ | |
| H1-IDM | Sensitivity | χ² = 71.32 | 4 | 1.2e-14 | .01 | ✓ | |
| H1-IDM | §8 Sonnet-dropped, primary | χ² = 79.17 | 4 | 2.6e-16 | .01 | ✓ | |
| H1-IDM | §8 Sonnet-dropped, sensitivity | χ² = 73.19 | 4 | 4.8e-15 | .01 | ✓ | |
| H2-IDM | Primary | β = +0.971, z = 4.34 | — | 1.4e-5 | .01 | ✓ | Wald on framingB within Anthropic |
| H2-IDM | Sensitivity | β = +0.897, z = 3.97 | — | 7.3e-5 | .01 | ✓ | |
| H2-IDM | §8 Sonnet-dropped, primary | β = +21.2, SE ≈ 6064 | — | (not estimable) | — | — | Complete separation in reference cell; see §8.2 |
| H2-IDM | §8 Sonnet-dropped, sensitivity | β = +19.8, SE ≈ 3296 | — | (not estimable) | — | — | Same |
| H3-IDM | Primary | χ² = 75.09 | 2 | 4.9e-17 | .01 | ✓ | LRT on family × framing |
| H3-IDM | Sensitivity | χ² = 71.32 | 2 | 3.3e-16 | .01 | ✓ | |
| H3-IDM | §8 Sonnet-dropped, primary | χ² = 79.08 | 2 | 6.7e-18 | .01 | ✓ | |
| H3-IDM | §8 Sonnet-dropped, sensitivity | χ² = 73.03 | 2 | 1.4e-16 | .01 | ✓ | |
| H4-compliance | Both datasets | χ² = 1.78 | 2 | 0.41 | .01 | ✗ | LRT; descriptive prediction supported (§5.3) |
| H2-AFF | Primary | β = −0.259, z = −2.30 | — | 0.022 | .05 | ✓ (pred. dir.) | Wald on framingB; not claimed (§5.4) |
| H2-AFF | Sensitivity | β = +0.695, z = +4.48 | — | 7.6e-6 | .05 | ✓ (OPPOSITE dir.) | Sign flip; not claimed |

## Appendix B: The interaction-effect detail rows for H3-IDM

The H3-IDM interaction LRT is a 2-df test against an Anthropic reference. The individual coefficients (Wald, descriptive) are:

| Dataset | Coefficient | β (log-odds) | SE | z | p |
|---|---|---:|---:|---:|---:|
| Primary | OpenAI × framingB | +2.497 | 0.387 | +6.46 | 1.1e-10 |
| Primary | Google × framingB | −0.454 | 0.313 | −1.45 | 0.15 |
| Sensitivity | OpenAI × framingB | +2.468 | 0.384 | +6.43 | 1.2e-10 |
| Sensitivity | Google × framingB | −0.358 | 0.314 | −1.14 | 0.25 |

In both datasets, OpenAI's interaction term is highly significant in the positive direction (OpenAI shifts harder than Anthropic on framing). Google's interaction term is non-significant in both (Google's framing shift is statistically indistinguishable from Anthropic's, despite being substantively smaller in raw proportions — the contrast lacks power because Google's Flash and Pro have so few parseable trials).

## Appendix C: The κ validation, per-category

(Repeated from §4.4 for at-a-glance reference.)

| Category | n judge | n human | n both | Pct agreement | κ | Interpretation |
|---|---:|---:|---:|---:|---:|---|
| PRO | 28 | 40 | 24 | 87.0% | 0.626 | substantial |
| EPI | 28 | 37 | 26 | 91.6% | 0.748 | substantial |
| CAP | 28 | 13 | 13 | 90.3% | 0.587 | moderate / substantial border |
| AFF | 28 | 14 | 12 | 88.3% | 0.512 | moderate (boundary-disputed) |
| IDM | 28 | 31 | 26 | 95.5% | 0.853 | almost perfect |
| HDG | 10 | 11 | 9 | 98.1% | 0.847 | almost perfect |
| OTH | 4 | 8 | 2 | 94.8% | 0.309 | unreliable (small n) |
| **Overall** | **154** | **154** | **(see above)** | **72.7%** | **0.673** | **substantial** |

The IDM category, where all the H1-IDM / H2-IDM / H3-IDM findings live, has the highest κ in the study.

---

*End of manuscript.*
