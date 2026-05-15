# Study 1 — Locked data-collection artifact

This folder is the **prereg-locked** half of the repository. It contains:

- The preregistration document and locked judge prompt.
- The runner code that produced the raw data.
- The raw data itself.
- The deviations log.

**Nothing in this folder should change once the prereg is posted to OSF.** All analysis happens in [`../study1_analysis/`](../study1_analysis/), which is free to evolve.

## Workflow

The full study comprises a pilot run (160 calls in our case — see Deviations) and a main run (1,440 calls). Both already completed on 2026-05-10 with zero API failures. The data is committed in `data/raw/`.

To re-run from scratch:

1. **Read the prereg.** [`prereg/prereg.md`](prereg/prereg.md) is the authoritative design document. The locked judge prompt is in [`prereg/judge_prompt.md`](prereg/judge_prompt.md). Any deviations are in [`prereg/deviations.md`](prereg/deviations.md).

2. **Run the pilot.** From `runner/`:
   ```powershell
   python run.py --pilot
   ```
   Output: `data/raw/responses_pilot.jsonl` and `data/raw/run_metadata_pilot.json`.

3. **Inspect pilot output.** Look for refusals or non-compliance per (family, framing), truncated responses (`finish_reason` hitting max_tokens), parser edge cases, provider-specific issues. Any deviations get logged in `prereg/deviations.md` before the main run.

4. **Run the main study:**
   ```powershell
   python run.py
   ```
   Output: `data/raw/responses_main.jsonl` and `data/raw/run_metadata_main.json`.

5. **Parsing, coding, analysis** — see [`../study1_analysis/README.md`](../study1_analysis/README.md).

## A resume-behavior caveat

The runner's `--resume` flag skips call_ids that already appear with `status == "success"` in the existing JSONL. Failed records are **not** removed. If a call failed in run A and succeeded on retry in run B (resumed against the same JSONL), the file contains both records — one `failed` and one `success` — for the same `call_id`.

The current `responses_main.jsonl` is unaffected: the main study ran from scratch with no failures and no resumes. The pilot JSONL has 160 rows for a 144-task design due to an earlier aborted attempt — the parser's `parse_summary.json` logs this and the pilot is non-confirmatory anyway. Downstream tools (the parser) read all rows but don't de-duplicate; if you ever resume a future run after partial failures, the resulting JSONL will need a dedup pass by `(call_id, status)` before downstream use.

## Files

| Path | Purpose |
|---|---|
| `prereg/prereg.md` | Locked design document. The authoritative source for hypotheses, model list, prompts, parsing rules, coding scheme, and analysis plan. |
| `prereg/judge_prompt.md` | The exact text of the LLM-judge prompt used for category coding (and the refusal classifier). Locked at OSF posting date. |
| `prereg/deviations.md` | Log of every change made after the prereg was posted, with date, scope, and rationale. |
| `runner/run.py` | Async resumable runner that fired the 1,440 API calls across three providers. |
| `runner/requirements.txt` | Pinned Python dependencies for the runner. |
| `data/raw/responses_pilot.jsonl` | 160 JSON records — one per API call from the pilot. |
| `data/raw/responses_main.jsonl` | 1,440 JSON records — one per API call from the main study. |
| `data/raw/run_metadata_pilot.json` | Run config, seed, timing, counts for the pilot. |
| `data/raw/run_metadata_main.json` | Same for the main study. |

## Data-collection cost

Anthropic + OpenAI + Google combined: well under $5 for the full 1,440 calls. The Google Pro and Gemini Flash reasoning-token consumption noted in the deviations log was an empirical surprise about *what came back*, not about *cost*.

## Deviations from prereg

See [`prereg/deviations.md`](prereg/deviations.md). As of the latest update there are five entries:

1. Google Flash tier model ID swap.
2. Compliance rate promoted to a primary outcome (H4 added).
3. Procedural caching of judge calls by (word, N, framing) tuple.
4. Validation sample drawn at the unique-tuple level rather than the word-instance level.
5. Boundary-disputed-word sensitivity analysis added.

The first two affect what's measured and analyzed; the third is purely about API call efficiency; the fourth changes the κ unit of analysis; the fifth adds a second pass of the primary tests against a swapped dataset to check robustness on the AFF/PRO and CAP/EPI scheme boundaries.
