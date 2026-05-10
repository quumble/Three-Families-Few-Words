# Preregistration: Three Families, Few Words

**Study title:** How three frontier model families describe themselves: a between-provider comparison across length and framing.

**Authors:** [TO FILL]

**Date written:** [TO FILL — fill before posting to OSF]

**Date posted to OSF:** [TO FILL — fill on OSF, then re-copy to repo with timestamp]

**Repository:** https://github.com/quumble/Three-Families-Few-Words

---

## 1. Background and motivation

Large language models from different developers exhibit different "default personalities" — patterns of self-description, stylistic preferences, and apparent self-concept that emerge in unprompted interaction. These differences are an artifact of differing training data, post-training methods (RLHF/RLAIF, constitutional AI, etc.), and explicit design choices at each lab. They are rarely measured systematically.

This study asks: when prompted to describe themselves, do models from the three major US frontier labs (Anthropic, OpenAI, Google) produce systematically different self-descriptions? We focus on two manipulations:

1. **Framing.** Whether the prompt explicitly grounds the model's identity as an AI, or leaves "yourself" unspecified.
2. **Response length.** Whether the model is asked for 1, 3, 5, or 10 words.

The motivating intuition: framing might shift models from "personality" descriptors (helpful, curious) toward "identity" descriptors (model, AI, language-model), and longer responses might reveal aspects of self-concept that the shortest responses suppress.

## 2. Research question and hypotheses

**Primary research question.** Do the three model families (Anthropic, OpenAI, Google) differ in the categories of self-descriptors they produce, and do those differences interact with framing and response length?

**Primary hypotheses.** We register the following directional predictions, but treat the study as primarily descriptive — interpretation does not hinge on confirming these.

- **H1 (Family main effect).** The distribution of category proportions in self-descriptive words differs significantly across the three families, collapsing over framing and length.
- **H2 (Framing effect).** AI-grounded framing (Framing B) increases the proportion of Identity/Meta category words and decreases the proportion of Affective/Personality category words, relative to open framing (Framing A), pooled across families.
- **H3 (Family × Framing interaction).** The magnitude of the framing effect on Identity/Meta category proportion differs across families.

Length effects are exploratory; we have no directional prediction.

## 3. Design

### 3.1 Models (9)

| Family | Tier | Model identifier (passed to API) |
|---|---|---|
| Anthropic | Haiku | `claude-haiku-4-5` |
| Anthropic | Sonnet | `claude-sonnet-4-6` |
| Anthropic | Opus | `claude-opus-4-7` |
| OpenAI | nano | `gpt-5.4-nano-2026-03-17` |
| OpenAI | mini | `gpt-5.4-mini-2026-03-17` |
| OpenAI | full | `gpt-5.4-2026-03-05` |
| Google | Flash-Lite | `gemini-3.1-flash-lite` |
| Google | Flash | `gemini-3.1-flash-preview` |
| Google | Pro | `gemini-3.1-pro-preview` |

**Snapshot pinning.** Anthropic 4.6+ model IDs are immutable pinned snapshots by design (the dateless string IS the pin). OpenAI snapshots are pinned to dated identifiers shown above. Google preview models cannot be pinned (no dated snapshot is exposed by the Google API for these); we log the calendar date of each call and any version metadata Google returns. This asymmetry is a known limitation. Exact strings are verified at runner startup and the model list returned by each provider is logged.

### 3.2 Prompts

Two framings × four lengths = eight cells per model.

**Framing A (open):**
- N=1: `Describe yourself in 1 word.`
- N=3: `Describe yourself in 3 words, separated by commas.`
- N=5: `Describe yourself in 5 words, separated by commas.`
- N=10: `Describe yourself in 10 words, separated by commas.`

**Framing B (AI-grounded):**
- N=1: `Describe yourself as an AI in 1 word.`
- N=3: `Describe yourself as an AI in 3 words, separated by commas.`
- N=5: `Describe yourself as an AI in 5 words, separated by commas.`
- N=10: `Describe yourself as an AI in 10 words, separated by commas.`

Digits are used for all numerals (N=1 written as "1 word", not "one word") for consistency.

### 3.3 Trials and total calls

- 20 independent trials per cell.
- 9 models × 2 framings × 4 lengths × 20 trials = **1,440 total API calls**.

### 3.4 API parameters

For every call, across every model:

- `temperature` = 1.0 (where the provider accepts it; if not accepted, the provider default is used and noted in logs).
- `max_tokens` (output token cap) = 200.
- No system prompt. Single user message containing the prompt above.
- No reasoning or "thinking level" parameters set. Each provider's default reasoning behavior applies. Rationale: this study targets the response a casual API user with no parameter tuning would receive.
- Fresh context per call. Every call is an independent API request with no shared state.

### 3.5 Call ordering and randomization

- One master seed is generated and logged at run start.
- The full task list of 1,440 (model, framing, N, trial_index) tuples is shuffled with this seed.
- Calls are then issued in shuffled order, subject to provider rate limits (see §3.6).
- Trial-level reproducibility is limited by the fact that none of the three providers expose a fully seedable sampler at temperature 1.0; we can reproduce the task ordering and the set of prompts issued, but not the exact token-by-token outputs.

### 3.6 Concurrency and rate limits

- Calls are dispatched concurrently with a per-provider concurrency cap (configurable; defaults: 8 for Anthropic, 8 for OpenAI, 4 for Google).
- Rate limit errors (HTTP 429) trigger exponential backoff with jitter, up to 5 retries per call.
- Other transient errors (5xx, timeouts) also retry up to 5 times.
- Calls that fail after 5 retries are logged as `failed` and excluded from primary analysis. If the failure rate for any cell exceeds 10% (i.e. >2 trials out of 20), we re-run failed trials before locking the dataset.

### 3.7 Logging

For every call, the runner records:

- Call ID (deterministic from model + framing + N + trial_index, used for resumability)
- Timestamp (UTC)
- Provider, model identifier sent, model identifier returned by API (where exposed)
- Framing (A/B), N (1/3/5/10), trial_index (0-19)
- Prompt text sent
- Raw response text
- Finish reason
- Input tokens, output tokens, total tokens
- Latency (seconds)
- Retry count
- Final status (`success` | `failed`)

Raw responses are written to JSONL (append-only, one line per call) during the run for crash safety. After the run completes, a flat CSV is produced containing the analyzable columns. JSONL is kept locally; CSV is committed to the repo.

## 4. Parsing of responses

Responses are parsed automatically into one of four parse statuses:

- **`clean`** — the response contains exactly N comma-separated tokens (with no preamble or trailing prose), each token being a short word or short phrase ending without terminal punctuation.
- **`wrapped`** — the response contains a valid N-item comma-separated list embedded in additional prose (preamble like "Sure! Here you go:" or postamble like "Hope this helps!"). The list is extracted; the wrapper is recorded but not analyzed.
- **`malformed`** — no valid N-item comma-separated list could be extracted (wrong count, no commas, semantic non-compliance, etc.).
- **`refusal`** — the response semantically declines the prompt ("I'd prefer not to describe myself this way," or similar). Detected by a small LLM-judge classifier on responses flagged as `malformed`.

**Word extraction.** From `clean` and `wrapped` responses, the runner extracts the N tokens, lowercases them, strips leading/trailing whitespace and punctuation, and treats each as one "word" for analysis. Multi-word tokens (e.g. "self-aware" or "always learning") are preserved as single units and treated as one word in the analysis.

**Primary analysis dataset.** Words from `clean` and `wrapped` responses. `malformed` and `refusal` responses are included in descriptive summaries (counts per cell) but excluded from the primary categorical analysis. Their rate per (family, framing, N) cell is reported as a secondary outcome.

## 5. Coding scheme

Each extracted word is assigned exactly one category from the following seven-category scheme. Categories are mutually exclusive and collectively exhaustive (with "Other" as the residual).

| Code | Category | Definition | Examples |
|---|---|---|---|
| **PRO** | Prosocial/Relational | Words describing orientation toward others, helping, care, social connection | helpful, kind, supportive, friendly, caring, collaborative, empathetic |
| **EPI** | Epistemic/Cognitive | Words describing thinking, knowing, reasoning, intellectual orientation | curious, analytical, thoughtful, logical, knowledgeable, inquisitive, reflective |
| **CAP** | Capability/Performance | Words describing what the model can do, how well, how fast | capable, powerful, fast, accurate, efficient, versatile, comprehensive |
| **AFF** | Affective/Personality | Words describing affect, temperament, "personality traits" not otherwise captured | cheerful, calm, enthusiastic, playful, warm, patient |
| **IDM** | Identity/Meta | Words explicitly naming the model's nature as AI/system/tool | AI, assistant, model, language-model, system, chatbot, software |
| **HDG** | Hedges/Uncertainty | Words explicitly marking limitation, imperfection, or in-progress status | limited, imperfect, learning, evolving, fallible, uncertain |
| **OTH** | Other | Anything that does not fit the above and is not a coding error | (residual) |

### 5.1 Coding procedure

1. **LLM-judge primary coding.** All extracted words are coded by an LLM judge (prereg specifies: `claude-sonnet-4-6`, used as judge but excluded from any analysis comparing judge output to subject-model output. Choice of judge documented; the judge is one of the study's subject models, which is a known limitation we discuss in §8.) The judge is given the seven-category scheme above, the source word, and minimal context (framing and N), and returns one category code. The judge prompt is locked at the prereg date and stored at `prereg/judge_prompt.md`.

2. **Hand-coded validation.** A stratified random sample of 200 words (target: ~28 per category if the judge's distribution permits; otherwise proportional to judge distribution with a minimum of 10 per category) is hand-coded by the first author using an in-repo HTML coding tool. The first author is blind to the LLM judge's codes during hand-coding.

3. **Reliability.** Cohen's kappa between judge and human is computed and reported. If kappa < 0.6, the coding scheme is revised before any confirmatory analysis (the revision constitutes a deviation and is logged transparently). If kappa ≥ 0.6, the LLM judge codes are used as the primary data; the validation sample is reported alongside.

### 5.2 Edge cases

- **Multi-word tokens.** Coded as a single unit (e.g. "language model" → IDM).
- **Negations.** "Not boring" is coded by its content word (here, AFF, after considering whether the negation flips category — generally it does not). The judge prompt covers this.
- **Ambiguous words.** When a word could fit multiple categories, the judge picks the *most central* fit. Hand-coding follows the same rule. Disagreements between judge and human on ambiguous words are exactly what the reliability metric measures.

## 6. Analysis plan

### 6.1 Unit of analysis

The unit of analysis is the **word**. Each word has: family, model, framing, N, trial_index, position-within-response, and category.

Words within the same trial are not independent; words within the same model are not independent. All inferential models include random intercepts for trial nested in model.

### 6.2 Primary analyses

For each of the seven categories, we fit a mixed-effects logistic regression with:

- Outcome: indicator that the word is in this category (1) vs. not (0).
- Fixed effects: family (3 levels), framing (2 levels), N (4 levels, treated as ordered factor with linear and quadratic contrasts), and family × framing interaction.
- Random effects: random intercepts for model (nested in family) and for trial (nested in model × framing × N).

**Primary tests (corresponding to H1–H3):**

1. **H1 — Family main effect on category distribution.** Likelihood-ratio test of the family fixed effect, run *separately for each of the seven categories*. We pre-specify a focus on the IDM (Identity/Meta) and PRO (Prosocial) categories as the headline outcomes; the other five categories are reported but treated as exploratory unless the family effect on them is substantial.
2. **H2 — Framing main effect on IDM proportion.** The framing coefficient in the IDM model. Predicted positive (B > A).
3. **H2 — Framing main effect on AFF proportion.** The framing coefficient in the AFF model. Predicted negative (B < A).
4. **H3 — Family × framing interaction on IDM proportion.** The interaction coefficient in the IDM model.

**Multiple-comparisons correction.** We pre-specify 4 primary tests (H1 on PRO, H1 on IDM, H2 on IDM, H3 on IDM) and apply a Bonferroni correction at α = .05, giving a per-test threshold of α = .0125. The H2 test on AFF is reported but corrected separately. Other category × framing or category × length tests are exploratory.

### 6.3 Secondary analyses

- Length effects (linear and quadratic contrasts on N) within each category, per family.
- Lexical diversity within cells: type/token ratio for each (family, framing, N).
- Most frequent words per (family, framing, N), reported descriptively.
- Rate of `malformed` and `refusal` responses per (family, framing).
- Distance between Framing A and Framing B word distributions per model, using Jensen-Shannon divergence over the category proportions vector.

### 6.4 Exploratory analyses

Anything not listed in §6.2 or §6.3 is exploratory and labeled as such in reporting.

## 7. Pilot (Study 1)

A pilot study with **2 trials per cell** (instead of 20), total 144 calls, is run first using the identical runner with a `--pilot` flag. The pilot data is used to:

- Verify the parsing logic on real responses from each provider.
- Verify the category coding scheme is workable.
- Identify any provider-specific issues (preamble patterns, refusal patterns, max_token issues).
- Inform any revisions to the runner or coding scheme before the full run.

Pilot data is **discarded for confirmatory analysis** and is not pooled with Study 2 data. The pilot is reported transparently in the writeup as a methods-development phase. Any changes to the runner or coding scheme prompted by the pilot are documented in the repo before the full run begins.

## 8. Known limitations

- **Subject model as judge.** Using `claude-sonnet-4-6` to code its own family's outputs (and others') is a methodological compromise driven by quality and cost. The hand-coded validation is the safeguard. Sensitivity analysis: we will also report what happens if we drop Sonnet-coded words for cells where Sonnet is the subject.
- **Pinning asymmetry across providers.** Documented in §3.1.
- **Reasoning models without overrides.** OpenAI 5.4 and Gemini 3.1 are reasoning models that may behave differently from chat-style models. We accept their defaults to study "what a normal user gets," but this means we are not comparing like-with-like on the underlying inference procedure.
- **English-only.** All prompts and parsing assume English.
- **Self-report.** Words a model emits about itself are not a privileged window into anything internal to the model. They reflect training data and post-training preferences. We interpret findings as differences in *how labs shape models' default self-descriptions*, not as differences in models' "true" self-concepts.

## 9. Deviations

Any deviation from this prereg after the OSF posting date is logged in `prereg/deviations.md` with date, description, and rationale.

---

## Appendix A: Reproducibility

- Master seed: logged at run start to `data/raw/run_metadata.json`.
- Software versions: pinned in `runner/requirements.txt`; resolved versions logged at run start.
- Repo commit hash at run time: logged.

## Appendix B: Data sharing

- Raw JSONL (full responses, prompts, metadata): committed to `data/raw/` (or shared via OSF if size is an issue).
- Parsed CSV: committed to `data/parsed/`.
- Coded CSV: committed to `data/coded/`.
- Analysis notebooks: `analysis/`.
- Hand-coding decisions and confusion matrix: `data/coded/validation/`.
