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
