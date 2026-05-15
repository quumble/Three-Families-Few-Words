# Hand-coding validation tool

Implements the human-coded validation pass from prereg §5.1: a stratified
random sample of unique `(word, framing, N)` tuples from `coded_main.csv`
is hand-coded by the first author, blind to the LLM judge's codes, and
Cohen's κ between human and judge is computed.

## Files

| File | Purpose |
|---|---|
| `sample.py` | Generates the stratified validation sample (deterministic, seed=20260515). Writes `sample.json` (blinded, no judge codes) and `sample_keyed.csv` (judge codes, for later scoring). |
| `sample.json` | The blinded sample: 154 unique `(tuple_id, word, framing, n)` rows. No judge codes. |
| `sample_keyed.csv` | The same rows with `judge_code` attached. Used only by `kappa.py` after coding is complete. **Do not open this before coding** if you want to preserve blinding. |
| `coding_tool.html` | Single-file static tool for hand-coding. Bakes the blinded sample inline (no network access needed). |
| `kappa.py` | Reads `sample_keyed.csv` + `../data/validation_main.csv` (your coding output) and computes overall κ, per-category one-vs-rest κ, percent agreement, confusion matrix, and a disagreements CSV. |
| `apply_sensitivity_swap.py` | Generates the boundary-disputed-word sensitivity dataset by applying the swap rule (deviations.md, 2026-05-15) to `coded_main.csv`. Writes `../data/coded_main_sensitivity.csv` and a `sensitivity_swap_rules.json` audit file. |
| `sensitivity_swap_rules.json` | Per-word swap policy actually applied: word-level vs tuple-level, the human code used, and the validated tuples that justify each policy. |

## Workflow

1. **(Re)generate the sample (optional — already committed).**
   ```powershell
   python sample.py
   ```
   Deterministic: same seed → same 154 tuples in the same order. If you re-run
   this and the contents of `sample.json` change, you must also update the
   inline `SAMPLE = [...]` array in `coding_tool.html` to match. There's a
   self-check at the top of `kappa.py` (via `sample_keyed.csv`) that will
   refuse to score if `tuple_id`s don't line up.

2. **Code the sample.**
   Open `coding_tool.html` in any browser (double-click works — no server
   needed). For each item, press `1`–`7` to assign a category, or `0`/`Space`
   to flag and revisit. Progress saves to your browser's `localStorage` after
   every keystroke. You can close the tab and reopen to resume.

   The category reference (definitions + examples) is visible in the sidebar
   on every screen, so you don't have to memorize the seven codes.

3. **Export and score.**
   When the progress bar is full, click **Download CSV**. Save the resulting
   `validation_main.csv` into `study1_analysis/data/`. Then:
   ```powershell
   python kappa.py
   ```
   Prints overall and per-category reliability, the confusion matrix, and
   the list of judge–human disagreements. Writes:
   - `coding_tool/disagreements.csv` — disagreement rows for inspection
   - `coding_tool/kappa_summary.json` — full summary

## Sampling design

Prereg §5.1 specifies "a stratified random sample of 200 words (target ~28
per category if the judge's distribution permits)". We deviated to sample
**unique `(word, framing, N)` tuples** rather than word *instances*. This is
because the judge codes are deterministic per tuple by construction (per the
2026-05-15 caching deviation): coding the same tuple twice gives no new
judge-vs-human signal. The deviation is logged in
`../../study1/prereg/deviations.md`.

Stratified by judge code, target 28 unique tuples per category, all rows if
the category has fewer:

| Code | Tuples sampled / available |
|---|---|
| PRO | 28 / 40 |
| EPI | 28 / 60 |
| CAP | 28 / 104 |
| AFF | 28 / 50 |
| IDM | 28 / 49 |
| HDG | 10 / 10 (all) |
| OTH | 4 / 4 (all) |
| **Total** | **154 / 317** |

Items are presented in randomized (shuffled) order so the coder doesn't
learn "I'm in the AFF block now."

## Blinding

`sample.json` and the baked-in `SAMPLE` array in `coding_tool.html` contain
**no judge codes**. The judge codes live only in `sample_keyed.csv`, which
the HTML tool does not read. The browser-side coding tool cannot reveal the
judge's code because it doesn't have it.

If you want the strongest blinding, do not open `sample_keyed.csv` (or any
file in `../data/coded_main.csv`) before completing the coding pass.

## Keyboard shortcuts in the tool

| Key | Action |
|---|---|
| `1`–`7` | Assign category (PRO/EPI/CAP/AFF/IDM/HDG/OTH) and advance |
| `0` or `Space` | Flag this item for revisit; advance |
| `←` / `→` | Previous / next item without coding |
| `Backspace` | Undo: go back one item and erase its code |

## Disagreement interpretation

`kappa.py` writes `disagreements.csv` with every tuple where judge ≠ human.
Inspect these manually to decide whether disagreements reflect:

- **Coder error or fatigue** (re-code with care);
- **A genuinely ambiguous word** that could go either way (expected; this is
  what the reliability metric is for);
- **A systematic judge problem** in some category (e.g., judge consistently
  labels "limited" as IDM when it should be HDG).

The third case, if widespread, is what would push κ below 0.60 and trigger a
coding-scheme revision per prereg §5.1.

## Sensitivity analysis (post-validation)

For the actual main-study run, validation returned κ = 0.673 (above threshold, judge codes accepted). Disagreements clustered on the AFF↔PRO and CAP↔EPI boundaries and turned out to reflect scheme ambiguity rather than coder error. Rather than revise the scheme (the κ < 0.60 path) we kept the locked scheme and added a sensitivity analysis. To regenerate it:

```powershell
python apply_sensitivity_swap.py
```

This applies the swap rule (deviations.md, 2026-05-15 "Boundary-disputed-word sensitivity analysis") to `../data/coded_main.csv` and writes `../data/coded_main_sensitivity.csv` plus the per-word rule audit in `sensitivity_swap_rules.json`. The 5 primary regressions are run against both `coded_main.csv` and `coded_main_sensitivity.csv` in the analysis notebook; substantive conclusions are claimed only where they hold in both versions.

The swap is deterministic given `validation_main.csv` and `coded_main.csv`. Re-running the script regenerates the same files. **Known artifact**: under the strict tuple-level rule, the word "curious" at the single tuple (B, N=5) flips 71 instances to AFF on the basis of one validation entry that disagreed with three others. This is documented in the deviation entry; we chose to apply the rule strictly rather than override post-hoc.
