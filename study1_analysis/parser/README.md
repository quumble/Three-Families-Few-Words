# Parser

Converts the runner's JSONL output into analysable CSVs. This is the bridge between `data/raw/` and the downstream coding step.

## What it does

For each call in `data/raw/responses_*.jsonl`, the parser:

1. Strips cosmetic decoration (outer markdown bold, single trailing period) without losing data.
2. Tries to parse the response as a `clean` N-item comma-separated list.
3. If that fails, tries to extract an N-item list embedded in prose → `wrapped`.
4. Otherwise → `malformed`. A `truncated=True` flag marks malformed responses where the API stopped at `max_tokens` / `MAX_TOKENS` / `incomplete`.

Refusal classification is **not** done here — per prereg §4, refusals are a downstream judge step that re-classifies `malformed` rows.

## Outputs

Written to `data/parsed/`:

- `per_call_<run>.csv` — one row per API call (1440 for main, 160 for pilot). Includes the full `response_text`, `parse_status`, `truncated`, the extracted words as a JSON list, and a `parse_note` explaining malformed cases.
- `per_word_<run>.csv` — one row per extracted word (only for `clean` / `wrapped` calls). This is the primary-analysis dataset per prereg §6.1.
- `parse_summary.json` — counts and provenance for both runs.

## Usage

```powershell
cd parser
python parse.py            # both pilot and main
python parse.py --run main # main only
```

## Design decisions worth knowing

These reflect choices made when reading prereg §4 against the real data:

- **Trailing periods and outer `**bold**` are cosmetic.** A response like `**Curious.**` is `clean`, not `wrapped`. The prereg's "ending without terminal punctuation" wording is interpreted as referring to clause-ending prose, not a single styling period. Anthropic Sonnet bolds N=1 answers nearly every time; treating that as `wrapped` would be silly.
- **Truncated responses with too few words → `malformed`.** The strict reading of prereg §4 (must have exactly N tokens). Affected 169 main-study calls — almost all Google Pro and Google Flash at N≥5 where the reasoning budget consumed the 200-token output cap. This is the most consequential parse decision in the project; alternatives are discussed in `prereg/deviations.md` (or will be, if we ever switch).
- **Multi-word and hyphenated tokens stay intact.** `"AI assistant"` is one word; `"language-model"` is one word. Per prereg §4.
- **Pilot data is not de-duplicated.** The pilot JSONL contains 160 rows for what was logged as a 144-task run, because an aborted earlier attempt left rows on disk that the resume merged with later runs. Pilot data is non-confirmatory per prereg §7 anyway; we keep all rows and note this.

## Parser tests

`test_parse.py` exercises the parsing logic against 15 real-data strings covering: plain N=1, bold N=1, preamble + bolded list, hyphenated multi-word tokens, truncated short lists, sentence-form responses, internal-thinking leaks, missing-comma cases.

```powershell
python test_parse.py
```
