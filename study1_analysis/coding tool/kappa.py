"""
Compute reliability between hand codes and LLM judge codes.

Reads:
  - sample_keyed.csv         (tuple_id, word, framing, n, judge_code)
  - ../data/validation_main.csv  (tuple_id, word, framing, n, human_code, timestamp)

Outputs:
  - Prints overall Cohen's kappa, per-category one-vs-rest kappas, percent agreement,
    and a 7x7 confusion matrix (judge rows, human cols).
  - Writes a CSV of disagreements for inspection: disagreements.csv
  - Writes a summary JSON: kappa_summary.json

Per prereg §5.1:
  - If κ ≥ 0.6, judge codes are accepted as the primary data.
  - If κ < 0.6, the coding scheme is revised and that constitutes a deviation.

Flagged items ("FLAG") are reported separately and excluded from kappa.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE.parent / "data"

KEYED = HERE / "sample_keyed.csv"
VALIDATION = DATA_DIR / "validation_main.csv"
DISAGREEMENT_OUT = HERE / "disagreements.csv"
SUMMARY_OUT = HERE / "kappa_summary.json"

CATEGORIES = ["PRO", "EPI", "CAP", "AFF", "IDM", "HDG", "OTH"]


def cohens_kappa(y1: pd.Series, y2: pd.Series, labels: list[str]) -> float:
    """Cohen's kappa with explicit label set so empty categories are handled."""
    n = len(y1)
    if n == 0:
        return float("nan")
    cm = pd.crosstab(y1, y2).reindex(index=labels, columns=labels, fill_value=0)
    arr = cm.to_numpy(dtype=float)
    total = arr.sum()
    if total == 0:
        return float("nan")
    po = np.trace(arr) / total
    row_marg = arr.sum(axis=1) / total
    col_marg = arr.sum(axis=0) / total
    pe = float(np.sum(row_marg * col_marg))
    if pe == 1.0:
        return float("nan")
    return float((po - pe) / (1.0 - pe))


def one_vs_rest_kappa(judge: pd.Series, human: pd.Series, cat: str) -> dict:
    """Per-category kappa: cat-vs-not-cat."""
    j_bin = (judge == cat).astype(int)
    h_bin = (human == cat).astype(int)
    n_judge_pos = int(j_bin.sum())
    n_human_pos = int(h_bin.sum())
    n_both_pos = int(((j_bin == 1) & (h_bin == 1)).sum())
    n_both_neg = int(((j_bin == 0) & (h_bin == 0)).sum())
    po = (n_both_pos + n_both_neg) / len(j_bin)
    p_j = n_judge_pos / len(j_bin)
    p_h = n_human_pos / len(j_bin)
    pe = p_j * p_h + (1 - p_j) * (1 - p_h)
    k = (po - pe) / (1 - pe) if pe < 1 else float("nan")
    return {
        "category": cat,
        "n_judge_positive": n_judge_pos,
        "n_human_positive": n_human_pos,
        "n_both_positive": n_both_pos,
        "percent_agreement": round(po, 4),
        "kappa": round(k, 4) if k == k else None,  # NaN -> None for JSON
    }


def main() -> None:
    if not VALIDATION.exists():
        raise FileNotFoundError(
            f"Could not find {VALIDATION}. Run coding_tool.html first and download "
            f"validation_main.csv into study1_analysis/data/."
        )
    keyed = pd.read_csv(KEYED)
    valid = pd.read_csv(VALIDATION)

    merged = keyed.merge(
        valid[["tuple_id", "human_code"]], on="tuple_id", how="left"
    )

    # Report missing / flagged
    n_total = len(merged)
    flagged = merged[merged["human_code"] == "FLAG"]
    missing = merged[merged["human_code"].isna() | (merged["human_code"] == "")]
    used = merged[
        merged["human_code"].notna()
        & (merged["human_code"] != "FLAG")
        & (merged["human_code"] != "")
    ].copy()

    print(f"Sample size: {n_total} unique (word, framing, N) tuples")
    print(f"  Hand-coded (non-FLAG): {len(used)}")
    print(f"  Flagged: {len(flagged)}")
    print(f"  Missing: {len(missing)}")
    print()

    if len(used) == 0:
        print("No usable codes. Exiting.")
        return

    judge = used["judge_code"]
    human = used["human_code"]

    # Overall kappa
    overall_k = cohens_kappa(judge, human, CATEGORIES)
    po = float((judge == human).mean())
    print(f"Overall percent agreement: {po:.3%}")
    print(f"Overall Cohen's kappa:    {overall_k:.4f}")
    print()
    print("Interpretation guide (Landis & Koch 1977):")
    print("  < 0.00  poor          .41-.60  moderate     .81-1.00  almost perfect")
    print("  .00-.20 slight        .61-.80  substantial")
    print("  .21-.40 fair")
    print()
    print(
        "Prereg threshold: kappa >= 0.60 to accept judge codes; "
        "below that, the coding scheme is revised."
    )
    print()

    # Per-category kappas
    print("Per-category one-vs-rest:")
    per_cat = []
    for cat in CATEGORIES:
        result = one_vs_rest_kappa(judge, human, cat)
        per_cat.append(result)
        k_str = f"{result['kappa']:.4f}" if result["kappa"] is not None else "n/a"
        print(
            f"  {cat}: judge+={result['n_judge_positive']:>3}  "
            f"human+={result['n_human_positive']:>3}  "
            f"both+={result['n_both_positive']:>3}  "
            f"agreement={result['percent_agreement']:.3f}  "
            f"kappa={k_str}"
        )
    print()

    # Confusion matrix: rows = judge, cols = human
    print("Confusion matrix (rows = judge, cols = human):")
    cm = pd.crosstab(judge, human).reindex(
        index=CATEGORIES, columns=CATEGORIES, fill_value=0
    )
    print(cm.to_string())
    print()

    # Disagreements
    disagrees = used[used["judge_code"] != used["human_code"]].copy()
    disagrees = disagrees.sort_values(["judge_code", "human_code", "word"])
    disagrees.to_csv(DISAGREEMENT_OUT, index=False)
    print(f"Wrote {len(disagrees)} disagreement rows to {DISAGREEMENT_OUT.name}")
    if len(disagrees) > 0:
        print()
        print("Disagreements:")
        for _, r in disagrees.iterrows():
            print(
                f"  '{r['word']}'  framing={r['framing']} N={r['n']}  "
                f"judge={r['judge_code']}  human={r['human_code']}"
            )
    print()

    summary = {
        "n_total_tuples": n_total,
        "n_used": len(used),
        "n_flagged": len(flagged),
        "n_missing": len(missing),
        "percent_agreement": round(po, 4),
        "kappa_overall": round(overall_k, 4) if overall_k == overall_k else None,
        "kappa_threshold": 0.60,
        "judge_accepted_by_threshold": (overall_k >= 0.60) if overall_k == overall_k else None,
        "per_category": per_cat,
        "confusion_matrix_rows_judge_cols_human": cm.to_dict(),
        "n_disagreements": len(disagrees),
    }
    SUMMARY_OUT.write_text(json.dumps(summary, indent=2))
    print(f"Wrote summary JSON to {SUMMARY_OUT.name}")


if __name__ == "__main__":
    main()
