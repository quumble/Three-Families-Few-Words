# Study 1 — Pilot and Main

This folder contains everything for the pilot (144 calls) and the main study (1,440 calls). They share a runner; the only difference is the `--pilot` flag, which uses 2 trials per cell instead of 20.

## Workflow

1. **Read the prereg.** [`prereg/prereg.md`](prereg/prereg.md) is the authoritative design document. The judge prompt is in [`prereg/judge_prompt.md`](prereg/judge_prompt.md). Both are locked at the OSF posting date.

2. **Run the pilot.**
   ```powershell
   cd runner
   python run.py --pilot
   ```
   Output: `data/raw/responses_pilot.jsonl` and `data/raw/run_metadata_pilot.json`.

3. **Inspect pilot output.** Look for:
   - Refusals or non-compliance per (family, framing).
   - Truncated responses (any `finish_reason` indicating max_tokens hit).
   - Parser edge cases.
   - Provider-specific issues.

   Any changes to the runner or coding scheme are logged in `prereg/deviations.md` before running the main study.

4. **Run the main study.**
   ```powershell
   cd runner
   python run.py
   ```
   Output: `data/raw/responses_main.jsonl` and `data/raw/run_metadata_main.json`.

5. **Parse, code, analyze.** (Subsequent scripts not yet written; will be added as the study progresses.)

## Files

| Path | Purpose |
|---|---|
| `prereg/prereg.md` | Locked design document |
| `prereg/judge_prompt.md` | LLM-judge prompt for category coding |
| `prereg/deviations.md` | Post-prereg changes log |
| `runner/run.py` | The main runner (async, resumable) |
| `runner/requirements.txt` | Pinned Python dependencies |
| `data/raw/responses_*.jsonl` | One JSON record per API call |
| `data/raw/run_metadata_*.json` | Run config, seed, timing, counts |
| `data/parsed/` | Parsed word lists (CSV) |
| `data/coded/` | Category-coded words (CSV) |
| `coding_tool/` | HTML hand-coding interface |
| `analysis/` | Analysis notebooks |

## Cost estimate (rough)

Per-trial input is ~15 tokens, output up to 200 tokens. Across 1,440 calls:

- Anthropic (3 models × 160 calls = 480 calls): Haiku/Sonnet/Opus mix, well under $5 total.
- OpenAI (3 models × 160 calls = 480 calls): mostly nano/mini, well under $5 total.
- Google (3 models × 160 calls = 480 calls): Flash-Lite/Flash/Pro mix, well under $5 total.

Reasoning tokens on the larger OpenAI and Google models can balloon costs; budget headroom is recommended. Pilot mode (144 calls) costs roughly 1/10 of the above.

## Deviations from prereg

See [`prereg/deviations.md`](prereg/deviations.md). If empty, no deviations have been logged yet.
