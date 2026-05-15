# Three Families, Few Words

A study comparing how nine frontier language models from three providers (Anthropic, OpenAI, Google) describe themselves when asked.

Each model is prompted to "describe yourself" in 1, 3, 5, or 10 words, under two framings (open vs. AI-grounded), 20 trials per cell — 1,440 calls total. Words are extracted, then categorized into a seven-category scheme (prosocial, epistemic, capability, affective, identity/meta, hedges, other). Headline question: do the three families systematically differ in what they say about themselves, and does framing shift those differences?

## Status

- **Pilot (Study 1, methods development):** 160 calls completed 2026-05-10. Discarded for confirmatory analysis per prereg §7.
- **Main study (Study 2):** 1,440 calls completed 2026-05-10. 0 API failures.
- **Parser:** complete. 1,179 clean / 40 wrapped / 221 malformed (169 of those truncated by Google's reasoning overhead). 5,255 words extracted for primary analysis.
- **LLM judge:** complete. All 5,255 words coded into 7 categories. 0 judge errors.
- **Refusal classifier:** complete. 0 refusals; all 221 malformed are genuine non-compliance.
- **Hand-coded validation (prereg §5.1):** complete (2026-05-15). 154-tuple stratified sample hand-coded by the first author, blind to judge codes. Overall κ = 0.673 (substantial, above the 0.60 threshold); judge codes accepted as primary per prereg §5.1. A pre-specified sensitivity analysis (the boundary-disputed-word swap deviation) produced `study1_analysis/data/coded_main_sensitivity.csv`.
- **Statistical analysis (prereg §6):** TODO. Will be run against both `coded_main.csv` (primary) and `coded_main_sensitivity.csv` (sensitivity).
- **Preregistration:** [`study1/prereg/prereg.md`](study1/prereg/prereg.md). OSF link: [TODO add after posting].

## Repository structure

The repo is split into two top-level halves:

```
.
├── study1/                         # PREREG-LOCKED. Data collection and locked design.
│   ├── prereg/                     # The preregistration + locked judge prompt + deviations log.
│   ├── runner/                     # The async API caller that produced the raw data.
│   └── data/raw/                   # The 1,440 JSONL records + run metadata. Output of the runner.
│
└── study1_analysis/                # Everything that happens AFTER data collection.
    ├── parser/                     # JSONL → per-call CSV + per-word CSV.
    ├── judge/                      # LLM judge + refusal classifier.
    ├── coding_tool/                # Hand-coding HTML + κ scoring + sensitivity-swap script.
    ├── data/                       # Outputs of parser, judge, and coding tool (flat layout).
    └── (TODO) notebooks/           # Mixed-effects regressions and figures.
```

The split is intentional: `study1/` is a snapshot of what was preregistered and the data it produced; `study1_analysis/` is the working space for everything we do *to* that data. Reviewers can audit prereg compliance by looking only at `study1/`; nothing inside `study1_analysis/` modifies anything inside `study1/`.

Each folder has its own README with the details for that stage.

## Quick start (reproducing the analysis)

1. Clone the repo.
2. Set up the environment:
   ```powershell
   cd study1\runner
   pip install -r requirements.txt
   pip install anthropic python-dotenv     # for the judge as well
   ```
3. The raw data is already committed. To re-parse:
   ```powershell
   cd ..\..\study1_analysis\parser
   python parse.py
   ```
4. To re-run the judge (requires `ANTHROPIC_API_KEY` in `.env` at repo root):
   ```powershell
   cd ..\judge
   python code.py --dry-run --refusal-too --limit 10   # sanity check first
   python code.py --run main                            # full coding
   ```
5. Statistical analysis: TODO.

## Reproducing the data collection from scratch

Only do this if you want to re-collect data. The committed raw data is already analysis-ready.

1. Create a `.env` file at the repo root containing your three API keys:
   ```
   ANTHROPIC_API_KEY=sk-ant-...
   OPENAI_API_KEY=sk-...
   GOOGLE_API_KEY=...
   ```
2. From `study1/runner/`:
   ```powershell
   python run.py --pilot     # pilot first (144 calls / ~6s)
   python run.py             # main study (1,440 calls / ~10 min)
   ```
3. Output lands in `study1/data/raw/`. **Don't commit overwrites of these files unless you intend to replace the locked dataset** — they're the official prereg-aligned artifact.

## Costs and timing

Data collection ran in ~10 minutes for the main study, well under $5 across the three providers combined.

The judge stage uses `(word, N, framing)` caching against the deterministic temperature-0 judge — 317 unique tuples for 5,255 word instances, plus 221 refusal classifications. Roughly **$2–3 in API calls** for the full main-study coding. See `study1_analysis/judge/README.md` for the rationale.

## Reproducibility notes

- Anthropic and OpenAI calls use pinned model snapshots. Google preview models cannot be pinned by ID; we log the calendar date of each call and any version metadata Google returns. See prereg §3.1.
- The master seed for task ordering is logged at run start in `study1/data/raw/run_metadata_*.json`.
- Trial-level reproducibility of exact tokens isn't possible at temperature 1.0 across these providers, but the task list and call order are reproducible from the seed.
- The judge runs at temperature 0; codes are deterministic given the cache state. The judge cache (`study1_analysis/judge/judge_cache.json`) is committed for full audit-ability.

## Deviations from prereg

All deviations are logged in [`study1/prereg/deviations.md`](study1/prereg/deviations.md). As of the most recent update, there are five:

1. Google Flash tier model ID swapped (the originally registered ID didn't exist as a callable text endpoint).
2. Compliance rate promoted from secondary to primary outcome after the pilot revealed Google reasoning-budget issues; one new primary hypothesis (H4) added.
3. Judge calls cached by (word, N, framing) tuple — procedural-only; mathematically identical to per-instance coding at temperature 0.
4. Validation sample drawn at the unique tuple level (154 tuples) rather than the word-instance level (200 instances); rationale: at temperature 0 the judge is deterministic per tuple, so instance-level repetition adds no κ signal.
5. Boundary-disputed-word sensitivity analysis added on top of the locked primary analysis, after validation κ = 0.673 cleared the threshold but revealed scheme-ambiguity disagreements on AFF↔PRO and CAP↔EPI boundaries.

## License

Apache-2.0. See [LICENSE](LICENSE).

## Citation

TODO add citation after writeup.
