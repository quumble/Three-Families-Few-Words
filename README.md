# Three Families, Few Words

A study comparing how nine frontier language models from three providers (Anthropic, OpenAI, Google) describe themselves when asked.

Each model is prompted to "describe yourself" in 1, 3, 5, or 10 words, under two framings (open vs. AI-grounded), 20 trials per cell — 1,440 calls total. Words are extracted and categorized into a seven-category scheme (prosocial, epistemic, capability, affective, identity/meta, hedges, other). The headline question: do the three families systematically differ in what they say about themselves, and does framing shift those differences?

## Status

- **Study 1 (pilot):** [TODO once run] 144 calls, methods development.
- **Study 2 (main):** [TODO once run] 1,440 calls.
- **Preregistration:** see [`study1/prereg/prereg.md`](study1/prereg/prereg.md). Timestamped OSF version at: [TODO add OSF link after posting].

## Repository structure

```
.
├── README.md
├── LICENSE
├── .gitignore
├── .env.example
└── study1/                  # pilot study + (currently) main study assets
    ├── README.md
    ├── prereg/              # locked preregistration
    │   ├── prereg.md
    │   ├── judge_prompt.md
    │   └── deviations.md    # any post-prereg changes are logged here
    ├── runner/              # API caller
    │   ├── run.py
    │   └── requirements.txt
    ├── prompts/             # prompt templates (in runner code; copy here for reference)
    ├── data/
    │   ├── raw/             # JSONL from runner (committed unless too large; otherwise on OSF)
    │   ├── parsed/          # parsed word lists in CSV
    │   └── coded/           # category-coded data in CSV
    ├── coding_tool/         # in-repo HTML hand-coding interface
    └── analysis/            # analysis notebooks
```

## Quick start

1. Clone the repo.
2. Copy `.env.example` to `.env` and fill in your three API keys.
3. Install dependencies:
   ```powershell
   cd study1\runner
   pip install -r requirements.txt
   ```
4. Run the pilot first:
   ```powershell
   python run.py --pilot
   ```
5. After verifying the pilot output, run the main study:
   ```powershell
   python run.py
   ```

The runner is resumable. If it dies partway through, re-run with `--resume`:
```powershell
python run.py --resume
```

## Reproducibility

- Anthropic and OpenAI calls use pinned model snapshots. Google preview models cannot be pinned; we log the calendar date of the run and any version metadata Google returns. See the prereg §3.1 for the full list.
- The master seed for task ordering is logged at run start in `data/raw/run_metadata_*.json`.
- Trial-level reproducibility of exact tokens is not possible at temperature 1.0 across these providers, but the task list and call order are reproducible from the seed.

## Citation

If you use this work, please cite [TODO add citation].

## License

[TODO add license]
