"""
Generate the stratified validation sample for hand-coding.

Reads `study1_analysis/data/coded_main.csv`. For each of the 7 judge categories,
samples unique (word, framing, n) tuples up to a target. Writes:

  - sample.json         : the items to code, blinded (no judge code field)
  - sample_blinded.json : alias, same content, explicit naming for the HTML
  - sample_keyed.csv    : tuple_id -> (word, framing, n, judge_code) for later kappa scoring.

Sampling is deterministic given SEED.

Stratification (prereg §5.1, target ~28/category, all rows if fewer, min 10):
  CAP: 28 unique tuples (of 104)
  EPI: 28 unique tuples (of 60)
  AFF: 28 unique tuples (of 50)
  IDM: 28 unique tuples (of 49)
  PRO: 28 unique tuples (of 40)
  HDG: 10 unique tuples (of 10 - all)
  OTH:  4 unique tuples (of 4  - all)
  Total: 154 unique tuples to hand-code.

This is a deviation from "200 words stratified" in prereg §5.1: we sample at
the unique (word, framing, n) tuple level rather than the word-instance level
because the judge codes are deterministic per tuple (per the 2026-05-15
caching deviation). Coding a tuple once vs. coding the same tuple 50 times
gives the same judge-human agreement signal. Logged as a deviation.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE.parent / "data"
CODED_CSV = DATA_DIR / "coded_main.csv"

OUT_SAMPLE = HERE / "sample.json"
OUT_KEYED = HERE / "sample_keyed.csv"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SEED = 20260515  # date of sampling; deterministic given this seed

# Per-category target unique-tuple counts. If the category has fewer tuples
# than the target, take all of them.
TARGETS = {
    "CAP": 28,
    "EPI": 28,
    "AFF": 28,
    "IDM": 28,
    "PRO": 28,
    "HDG": 28,  # only 10 exist; will take all 10
    "OTH": 28,  # only 4 exist; will take all 4
}

CATEGORY_ORDER = ["PRO", "EPI", "CAP", "AFF", "IDM", "HDG", "OTH"]


def main() -> None:
    df = pd.read_csv(CODED_CSV)
    print(f"Loaded {len(df)} coded word-instances from {CODED_CSV.name}")

    # Unique (word, framing, n) tuples, with their judge code.
    tuples = (
        df[["word", "framing", "n", "code"]]
        .drop_duplicates()
        .reset_index(drop=True)
        .copy()
    )
    print(f"Found {len(tuples)} unique (word, framing, n) tuples")
    print(tuples["code"].value_counts().to_string())
    print()

    rng = random.Random(SEED)
    selected_rows: list[dict] = []

    for code in CATEGORY_ORDER:
        pool = tuples[tuples["code"] == code]
        target = TARGETS[code]
        take = min(target, len(pool))
        idxs = sorted(rng.sample(list(pool.index), take))
        sub = pool.loc[idxs]
        for _, row in sub.iterrows():
            selected_rows.append(
                {
                    "word": row["word"],
                    "framing": row["framing"],
                    "n": int(row["n"]),
                    "judge_code": row["code"],
                }
            )
        print(f"  {code}: sampled {take} of {len(pool)} unique tuples")

    # Shuffle final presentation order so categories interleave (avoids the
    # coder learning "I'm in the CAP block now"). Keyed CSV is left in
    # selection order for traceability.
    print(f"\nTotal sampled: {len(selected_rows)} tuples")
    presentation = selected_rows.copy()
    rng.shuffle(presentation)

    # Assign tuple_id in presentation order so the human-coded output joins
    # naturally with the judge codes later.
    for i, row in enumerate(presentation):
        row["tuple_id"] = i

    # Write the blinded sample for the HTML tool: NO judge code included.
    blinded = [
        {
            "tuple_id": row["tuple_id"],
            "word": row["word"],
            "framing": row["framing"],
            "n": row["n"],
        }
        for row in presentation
    ]
    OUT_SAMPLE.write_text(json.dumps(blinded, indent=2))
    print(f"Wrote blinded sample to {OUT_SAMPLE.name}")

    # Write the keyed CSV (with judge code) for kappa scoring.
    keyed = pd.DataFrame(presentation)[["tuple_id", "word", "framing", "n", "judge_code"]]
    keyed.to_csv(OUT_KEYED, index=False)
    print(f"Wrote keyed CSV (judge codes, for scoring later) to {OUT_KEYED.name}")


if __name__ == "__main__":
    main()
