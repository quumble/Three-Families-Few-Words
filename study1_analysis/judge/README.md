# Judge

LLM judge that codes each extracted word into one of the seven prereg categories (PRO/EPI/CAP/AFF/IDM/HDG/OTH), plus a refusal classifier over the `malformed` rows.

The locked prompts live in [`../../study1/prereg/judge_prompt.md`](../../study1/prereg/judge_prompt.md). They are copied verbatim into `code.py` so a fresh clone can run the judge without introspecting the prereg; if anything drifts, the prereg file is the source of truth.

## What it does

1. **Word coding pass.** Reads `data/per_word_<run>.csv`. For each unique `(word, N, framing)` tuple, fires one judge API call. Writes `data/coded_<run>.csv` (one row per word, with a `code` column and a `cache_hit` column for traceability).

2. **Refusal classification pass.** Reads `data/per_call_<run>.csv`. For each row where `parse_status == "malformed"`, fires one refusal-classifier call. Writes `data/refusal_classifications_<run>.csv`.

Every API call (word or refusal) is also appended to `judge_call_log.jsonl` with full request/response/usage metadata.

## Cache strategy

At temperature 0 the judge is deterministic in `(word, N, framing)`. We code each unique tuple **once** and propagate the code to every per-word instance with the same tuple. For the main study:

- 5,255 word instances → 317 unique tuples → **~94% saving** in API calls
- Coded CSV has the same 5,255 rows as the per-word CSV
- A `cache_hit` boolean column says whether each row triggered a fresh call or reused a sibling's code

The cache persists in `judge_cache.json`. Reruns are incremental — re-running after a partial outage picks up where it left off without re-coding finished tuples. Use `--fresh` to wipe.

This is a procedural clarification of prereg §5, documented in `study1/prereg/deviations.md`. Coded data is mathematically identical to coding every instance separately.

## Prompt caching

Anthropic's prompt-cache minimum prefix length (~1024 tokens) is larger than our static rules block (~400 tokens). Prompt caching is NOT enabled — it would be a no-op. The two-block message structure is preserved in case the rules grow.

## Usage

```powershell
# Dry-run: 10 fresh API calls (configurable via --limit), print results, no CSV written
cd study1_analysis\judge
python code.py --dry-run

# Dry-run including the refusal classifier:
python code.py --dry-run --refusal-too --limit 5

# Full run:
python code.py --run main
python code.py --run pilot

# Full run with fresh cache and log:
python code.py --run main --fresh
```

Requires `ANTHROPIC_API_KEY` in env or in a repo-root `.env`. SDK deps: `anthropic`, `python-dotenv` (same as the runner).

## Outputs

| Path | Contents |
|---|---|
| `data/coded_<run>.csv` | per-word CSV + `code` (one of PRO/EPI/CAP/AFF/IDM/HDG/OTH/JUDGE_ERROR) + `cache_hit` |
| `data/refusal_classifications_<run>.csv` | one row per malformed call, with `refusal_label` (REFUSAL / MALFORMED / JUDGE_ERROR) |
| `judge/judge_cache.json` | persistent (word, N, framing) → code cache |
| `judge/judge_call_log.jsonl` | append-only log of every API call (request, response, usage, latency) |

## Validation

The hand-coded validation sample (prereg §5.1) lives in `../coding_tool/` (TODO — not yet built). Cohen's kappa between this judge and the human coder will be computed in `../notebooks/` once that step is done.
