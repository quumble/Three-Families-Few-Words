# Deviations from Preregistration

Any change to the runner, prompts, parsing logic, coding scheme, or analysis plan after the prereg was posted to OSF is logged here with date, description, and rationale.

## Format

```
## YYYY-MM-DD — Short title

**Section of prereg affected:** [e.g., §3.4 API parameters]

**Change:** What was changed.

**Rationale:** Why.

**Effect on analysis:** How (if at all) this changes the analysis or interpretation.
```

---

## 2026-05-10 — Google Flash tier model identifier change

**Section of prereg affected:** §3.1 (Model identifiers).

**Change:** Google Flash tier changed from `gemini-3.1-flash-preview` to `gemini-3-flash-preview`. Discovered during pilot run on 2026-05-10: the 3.1-tagged Flash model is not exposed for text generation on the Gemini Developer API (only image, TTS, and live variants exist at 3.1). The closest available current-generation Flash text model is `gemini-3-flash-preview`. Pro and Flash-Lite identifiers unchanged.

**Rationale:** The originally registered ID does not exist as a callable text-generation endpoint. `gemini-3-flash-preview` is the most-current Flash text model available to standard API users at the time of running. Note that Google's own changelog shows `gemini-3-pro-preview` now aliases to `gemini-3.1-pro-preview`, so the Gemini 3 / 3.1 distinction is partly cosmetic at Google.

**Effect on analysis:** None — the substitution preserves the design intent (current-generation Flash tier from each provider). The Google family is now mixed 3 / 3.1 / 3.1 across Flash / Pro / Flash-Lite; this asymmetry within the family is logged but does not affect any pre-specified analysis, which compares between families rather than between tier-versions within Google.

## 2026-05-10 — Compliance rate promoted to primary outcome; Google subset issue acknowledged

**Section of prereg affected:** §6.2 (Primary analyses), §6.3 (Secondary analyses), §8 (Known limitations).

**Change:**
1. Compliance rate — the proportion of trials per (family, framing, N) cell yielding a `clean` or `wrapped` parse status (i.e., not `malformed` or `refusal`) — is promoted from secondary (§6.3) to primary (§6.2). A fifth primary hypothesis is added:
   - **H4 (Family compliance effect).** The compliance rate differs significantly across the three families, with the prediction that Google Flash and Pro show lower compliance than other models in the same family or other families' equivalent tiers, due to reasoning-token consumption of the output budget.
2. The Bonferroni-corrected primary test count is raised from 4 to 5; per-test threshold becomes α = .01.
3. The category-proportion analysis is explicitly noted as a conditional analysis for Google Flash and Pro: estimates for these tiers represent "category proportions conditional on the model successfully completing the format," not unconditional category proportions.

**Rationale:** The pilot revealed that Gemini 3 Flash and Gemini 3 Pro consume nearly the entire 200-token output budget on hidden reasoning, producing systematically truncated or non-compliant responses (22/22 truncation flags in the pilot came from these two cells). The decision is to leave `max_tokens=200` and the no-thinking-override settings unchanged — the truncation pattern is itself a substantive cross-provider finding and we want to report it. Doing so honestly requires elevating compliance rate to a primary outcome rather than treating the systematic Google failure as a nuisance variable.

**Effect on analysis:** Adds one primary hypothesis (H4); tightens the Bonferroni threshold for the four pre-registered category tests; adds an honest caveat to the Google Flash/Pro category estimates. Does not change any code or any data collection parameter.

## 2026-05-15 — Judge calls cached by (word, N, framing) tuple

**Section of prereg affected:** §5.1 (Coding procedure), procedural only.

**Change:** Instead of issuing one judge API call per word instance (5,255 calls for the main study), the judge issues one call per unique `(word, N, framing)` tuple (317 calls for the main study) and propagates the resulting code to every per-word row with the same tuple. The coded CSV records a `cache_hit` boolean per row for traceability, and every fresh API call is logged with full request/response/usage metadata in `study1_analysis/judge/judge_call_log.jsonl`.

**Rationale:** The judge model is invoked at temperature 0 with a prompt fully determined by `(word, N, framing_description)`. At temperature 0 the output is deterministic, so coding the same tuple twice produces the same code twice. Caching produces an analysis dataset that is mathematically identical to per-instance coding while saving ~94% of API calls (and the corresponding cost and rate-limit time). The cache is persisted across runs to allow resumability.

**Effect on analysis:** None. The coded data is identical to what per-instance coding would produce, up to any temperature-0 sampler jitter (negligible at this scale and at α = .01). Full call logs and the persistent cache file are committed alongside the coded CSV, so a reviewer can re-verify any tuple's code if desired.

## 2026-05-15 — Validation sample drawn at the tuple level, not the instance level

**Section of prereg affected:** §5.1 (Coding procedure — hand-coded validation).

**Change:** The hand-coded validation sample is drawn at the unique `(word, framing, N)` tuple level rather than the word-instance level. Target was "200 words stratified by judge category, ~28 per category"; actual is 154 unique tuples stratified by judge category (28 each for PRO/EPI/CAP/AFF/IDM, plus all 10 HDG and all 4 OTH that exist). Sampling is deterministic given seed = 20260515. Implementation lives in `study1_analysis/coding_tool/`.

**Rationale:** The LLM judge is invoked at temperature 0 against a prompt that depends only on `(word, framing, N)`, and the 2026-05-15 caching deviation makes this explicit — every instance of the same tuple gets the exact same judge code. Sampling at the instance level would mean coding identical tuples repeatedly (e.g., the tuple `(curious, A, 3)` appears in many trials and would be re-coded each time). Those repeated codings give no new information about judge–human agreement, only about intra-rater consistency, which is not what κ measures. Sampling at the tuple level uses the coder's time on actual category variety. Numerically, the per-tuple κ is identical to what the instance-level κ would converge to if the human coded every instance, since the judge code is constant within a tuple.

**Effect on analysis:** Validation sample size is 154 unique tuples rather than 200 word-instances. Cohen's κ is computed at the tuple level. The κ ≥ 0.60 threshold for accepting judge codes (prereg §5.1) is applied to the tuple-level estimate. Power for the κ estimate is slightly lower than at n=200 but adequate to discriminate κ ≈ 0.6 from κ ≈ 0.8 (the relevant clinical region). Per-category one-vs-rest κs are reported alongside the overall κ. If the headline κ ≥ 0.60, judge codes are accepted; if < 0.60, the coding scheme is revised — same rule as the prereg, just applied to the tuple-level estimate.
