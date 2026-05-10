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
