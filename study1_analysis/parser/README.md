# Parser

Converts the runner's JSONL output into analyzable CSVs. This is the bridge between the locked `study1/data/raw/` artifact and the downstream judge step.

## What it does

For each call in `../../study1/data/raw/responses_*.jsonl`, the parser:

1. Strips cosmetic decoration (outer markdown bold, single trailing period) without losing data.
2. Tries to parse the response as a `clean` N-item comma-separated list.
3. If that fails, tries to extract an N-item list embedded in prose → `wrapped`.
4. Otherwise → `malformed`. A `truncated=True` flag marks malformed responses where the API stopped at `max_tokens` / `MAX_TOKENS` / `incomplete`.

Refusal classification is **not** done here — per prereg §4, refusals are a downstream judge step that re-classifies `malformed` rows. See [`../judge/`](../judge/).

## Outputs

Written to `../data/` (flat — no `parsed/` subfolder):

- `per_call_<run>.csv` — one row per API call (1,440 for main, 160 for pilot). Includes the full `response_text`, `parse_status`, `truncated`, the extracted words as a JSON list, and a `parse_note` explaining malformed cases.
- `per_word_<run>.csv` — one row per extracted word (only for `clean` / `wrapped` calls). This is the primary-analysis dataset per prereg §6.1.

A small `parse_summary.json` is written next to the script in `parser/` (counts and provenance for both runs).

## Usage

```powershell
cd study1_analysis\parser
python parse.py            # parses both pilot and main
python parse.py --run main # main only
```

Requires only the Python standard library (Python ≥ 3.10 for the type-union syntax). No third-party deps.

## Design decisions worth knowing

These reflect choices made when reading prereg §4 against the real data:

- **Trailing periods and outer `**bold**` are cosmetic.** A response like `**Curious.**` is `clean`, not `wrapped`. The prereg's "ending without terminal punctuation" wording is interpreted as referring to clause-ending prose, not a single styling period. Anthropic Sonnet bolds N=1 answers nearly every time; treating that as `wrapped` would be silly.
- **Truncated responses with too few words → `malformed`.** The strict reading of prereg §4 (must have exactly N tokens). Affected 169 main-study calls — almost all Google Pro and Google Flash at N ≥ 5 where the reasoning budget consumed the 200-token output cap. This is the most consequential parse decision in the project. Logged as a (non-deviation) procedural call in [`../../study1/prereg/deviations.md`](../../study1/prereg/deviations.md).
- **Multi-word and hyphenated tokens stay intact.** `"AI assistant"` is one word; `"language-model"` is one word. Per prereg §4.
- **Pilot data is not de-duplicated.** The pilot JSONL contains 160 rows for what was logged as a 144-task run, because an aborted earlier attempt left rows on disk that the resume merged with later runs. Pilot data is non-confirmatory per prereg §7 anyway; we keep all rows and log the duplication count in `parse_summary.json`.

## Parser tests

`test_parse.py` exercises the parsing logic against 15 real-data strings covering: plain N=1, bold N=1, preamble + bolded list, hyphenated multi-word tokens, truncated short lists, sentence-form responses, internal-thinking leaks, missing-comma cases.

```powershell
python test_parse.py
```

## Headline numbers from the last run

| Run | rows | clean | wrapped | malformed | truncated | words to per-word CSV |
|---|---:|---:|---:|---:|---:|---:|
| main | 1,440 | 1,179 (81.9%) | 40 (2.8%) | 221 (15.3%) | 169 (11.7%) | 5,255 |
| pilot | 160 | 118 | 4 | 38 | 16 | 523 |

The truncated pile concentrates in Google Pro/Flash at N ≥ 5 and is itself a finding worth reporting in the writeup (cf. prereg §6.3 on malformed/refusal rates, and the H4 compliance hypothesis added in deviations).
