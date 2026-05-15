# Judge

LLM judge that codes each extracted word into one of the seven prereg categories (PRO/EPI/CAP/AFF/IDM/HDG/OTH), plus a refusal classifier over the `malformed` parser rows.

The locked prompts live in [`../../study1/prereg/judge_prompt.md`](../../study1/prereg/judge_prompt.md). They are copied verbatim into `code.py` so a fresh clone can run the judge without introspecting the prereg; if anything drifts, the prereg file is the source of truth.

## What it does

1. **Word coding pass.** Reads `../data/per_word_<run>.csv`. For each unique `(word, N, framing)` tuple, fires one judge API call. Writes `../data/coded_<run>.csv` (one row per word, with a `code` column and a `cache_hit` column for traceability).

2. **Refusal classification pass.** Reads `../data/per_call_<run>.csv`. For each row where `parse_status == "malformed"`, fires one refusal-classifier call. Writes `../data/refusal_classifications_<run>.csv`.

Every API call (word or refusal) is also appended to `judge_call_log.jsonl` with full request/response/usage/latency metadata, for full audit-ability.

## Cache strategy

At temperature 0 the judge is deterministic in `(word, N, framing)`. We code each unique tuple **once** and propagate the code to every per-word instance with the same tuple. For the main study:

- 5,255 word instances → 317 unique tuples → **~94% saving** in API calls.
- The coded CSV has the same 5,255 rows as the per-word CSV.
- A `cache_hit` boolean column says whether each row triggered a fresh call or reused a sibling's code.

The cache persists in `judge_cache.json`. Reruns are incremental — re-running after a partial outage picks up where it left off without re-coding finished tuples. Use `--fresh` to wipe.

This is a procedural clarification of prereg §5, logged in `../../study1/prereg/deviations.md`. Coded data is mathematically identical to coding every instance separately.

## Prompt caching

Anthropic's prompt-cache minimum prefix length (~1024 tokens) is larger than our static rules block (~400 tokens). Prompt caching is NOT enabled — it would be a no-op. The two-block message structure is preserved in `build_judge_messages` so prompt caching can be re-enabled trivially if the rules ever grow past the threshold.

## Usage

```powershell
# Dry-run: 10 fresh API calls, print results, no CSV written
cd study1_analysis\judge
python code.py --dry-run

# Dry-run including the refusal classifier:
python code.py --dry-run --refusal-too --limit 10

# Full run:
python code.py --run main
python code.py --run pilot

# Full run with fresh cache and log (CAUTION: deletes judge_cache.json and judge_call_log.jsonl):
python code.py --run main --fresh
```

Requires `ANTHROPIC_API_KEY` in env or in a `.env` file at the repo root. SDK deps: `anthropic`, `python-dotenv`.

## Outputs

| Path | Contents |
|---|---|
| `../data/coded_<run>.csv` | per-word CSV + `code` column (PRO/EPI/CAP/AFF/IDM/HDG/OTH/JUDGE_ERROR) + `cache_hit` |
| `../data/refusal_classifications_<run>.csv` | one row per malformed call, with `refusal_label` (REFUSAL / MALFORMED / JUDGE_ERROR) |
| `judge_cache.json` | persistent (word, N, framing) → code cache. Committed for audit-ability. |
| `judge_call_log.jsonl` | append-only log of every API call. Committed; reviewers can verify any code. |

## What we got from the main run

317 word codings + 221 refusal classifications. 0 judge errors. 0 refusals (all 221 malformed are genuine non-compliance — sentence-form responses from openai/nano at N=10, truncations from Google Pro/Flash).

Per-category totals:

| code | count | % | what it is |
|---|---:|---:|---|
| CAP | 1,615 | 30.7% | capability / performance (efficient, fast, accurate, versatile) |
| EPI | 1,462 | 27.8% | epistemic / cognitive (curious, analytical, thoughtful) |
| PRO | 1,201 | 22.9% | prosocial / relational (helpful, supportive, friendly) |
| AFF | 594  | 11.3% | affective / personality (honest, direct, neutral, creative) |
| IDM | 322  | 6.1%  | identity / meta (AI, model, assistant, digital, artificial) |
| HDG | 57   | 1.1%  | hedges / uncertainty (limited, learning, evolving, bounded) |
| OTH | 4    | 0.1%  | residual |

## One inconsistency worth flagging

The judge codes `honest` as **AFF** in 5 of 6 (N, framing) cells and as **PRO** in (N=5, framing=A). Almost certainly temperature-0 sampler jitter on a borderline word. Honest is the 3rd most common word in Anthropic's data (232 instances), so this single-cell flip moves a non-trivial number of rows. Options to consider for the validation pass:

1. Re-call this one tuple to see if it stabilizes.
2. Include `honest` in the hand-coded validation sample to compare judge-AFF vs human consensus.
3. Document and move on — the §5.1 reliability metric is exactly designed to catch this kind of thing.

## Locked-prompt verification

The cached preamble + variable suffix re-assemble byte-identically to the locked template in `../../study1/prereg/judge_prompt.md`. To re-verify:

```python
from code import JUDGE_USER_TEMPLATE, _CACHED_PREAMBLE, _VARIABLE_SUFFIX
assert JUDGE_USER_TEMPLATE == _CACHED_PREAMBLE + _VARIABLE_SUFFIX
```

## Validation

The hand-coded validation sample (prereg §5.1) lives in `../coding_tool/` (TODO — not yet built). Cohen's kappa between this judge and the human coder will be computed in `../notebooks/` once that step is done.
