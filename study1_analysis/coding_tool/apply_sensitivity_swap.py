"""
Apply the sensitivity-analysis code swap to produce coded_main_sensitivity.csv.

The swap rule (locked in 2026-05-15; logged in deviations.md as
"Boundary-disputed-word sensitivity analysis"):

1. Identify every word that appeared in the validation sample with at least
   one judge-human disagreement (the "disagreement words").
2. For each disagreement word, check whether the human's codes across its
   validated tuples are consistent:
     - Consistent: apply the human's code to every instance of the word in
       the full 5,255-row dataset, regardless of framing/N.
     - Inconsistent: for specifically validated tuples, use the human's code
       for that tuple; for un-validated tuples of this word, retain the
       judge's code.
3. All other words retain the judge's code throughout.

Output: coded_main_sensitivity.csv with columns identical to coded_main.csv
plus a swap_applied boolean for transparency.
"""
from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE.parent / "data"
KEYED = HERE / "sample_keyed.csv"
VALIDATION = DATA_DIR / "validation_main.csv"
CODED = DATA_DIR / "coded_main.csv"

OUT_SENS = DATA_DIR / "coded_main_sensitivity.csv"
OUT_RULES = HERE / "sensitivity_swap_rules.json"


def main() -> None:
    keyed = pd.read_csv(KEYED)
    valid = pd.read_csv(VALIDATION)
    coded = pd.read_csv(CODED)

    val = keyed.merge(valid[["tuple_id", "human_code"]], on="tuple_id", how="inner")
    val = val[val["human_code"].notna() & (val["human_code"] != "FLAG")].copy()

    # Disagreements at the validated-tuple level.
    disagreements = val[val["judge_code"] != val["human_code"]].copy()
    disagreement_words = sorted(disagreements["word"].unique())
    print(f"Disagreement words ({len(disagreement_words)}): {disagreement_words}")
    print()

    # For each disagreement word, determine swap policy.
    swap_rules: dict[str, dict] = {}
    for word in disagreement_words:
        sub = val[val["word"] == word].copy()
        human_codes = sub["human_code"].unique()
        if len(human_codes) == 1:
            swap_rules[word] = {
                "policy": "word_level",
                "human_code": str(human_codes[0]),
                "n_validated_tuples": int(len(sub)),
                "validated_tuples": [
                    {"framing": r["framing"], "n": int(r["n"]),
                     "judge_code": r["judge_code"], "human_code": r["human_code"]}
                    for _, r in sub.iterrows()
                ],
            }
        else:
            swap_rules[word] = {
                "policy": "tuple_level",
                "reason": "human coded this word inconsistently across validated tuples",
                "n_validated_tuples": int(len(sub)),
                "per_tuple": {
                    f"{r['framing']}_N{int(r['n'])}": {
                        "judge_code": r["judge_code"],
                        "human_code": r["human_code"],
                    }
                    for _, r in sub.iterrows()
                },
            }

    OUT_RULES.write_text(json.dumps(swap_rules, indent=2))
    print(f"Wrote per-word swap rules to {OUT_RULES.name}")
    print()

    # Apply the swap to the full coded dataset.
    out = coded.copy()
    out["original_code"] = out["code"]  # keep a trace
    out["swap_applied"] = False
    out["swap_policy"] = ""

    n_changed = 0
    for word, rule in swap_rules.items():
        mask_word = out["word"] == word
        if rule["policy"] == "word_level":
            mask = mask_word & (out["code"] != rule["human_code"])
            n = int(mask.sum())
            out.loc[mask, "code"] = rule["human_code"]
            out.loc[mask, "swap_applied"] = True
            out.loc[mask, "swap_policy"] = "word_level"
            print(f"  word_level: '{word}' -> {rule['human_code']}   "
                  f"({n} instances changed)")
            n_changed += n
        else:
            for tuple_key, info in rule["per_tuple"].items():
                framing, n_str = tuple_key.split("_N")
                n_val = int(n_str)
                mask = (
                    mask_word
                    & (out["framing"] == framing)
                    & (out["n"] == n_val)
                    & (out["code"] != info["human_code"])
                )
                k = int(mask.sum())
                out.loc[mask, "code"] = info["human_code"]
                out.loc[mask, "swap_applied"] = True
                out.loc[mask, "swap_policy"] = "tuple_level"
                print(f"  tuple_level: '{word}' framing={framing} N={n_val} "
                      f"-> {info['human_code']}   ({k} instances changed)")
                n_changed += k

    print()
    print(f"Total word instances re-coded: {n_changed} of {len(out)} "
          f"({n_changed / len(out):.2%})")

    # Sanity: distribution shift
    print()
    print("Code distribution comparison:")
    before = coded["code"].value_counts().sort_index()
    after = out["code"].value_counts().sort_index()
    delta = (after - before).fillna(0).astype(int)
    summary = pd.DataFrame({"before": before, "after": after, "delta": delta})
    print(summary.to_string())

    out.to_csv(OUT_SENS, index=False)
    print()
    print(f"Wrote sensitivity-analysis dataset to {OUT_SENS.relative_to(HERE.parent.parent)}")


if __name__ == "__main__":
    main()
