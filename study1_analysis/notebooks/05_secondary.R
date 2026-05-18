## 05_secondary.R — Secondary / exploratory analyses (prereg §6.3)
##
## Discharges the prereg §6.3 commitments and the exploratory five-category
## H1 battery that §6.2 promises. Numerical only; figures live in
## 06_figures.R. Both scripts are independent of 01_primary.R and can be
## re-run without re-running anything upstream.
##
## What this script computes, for each of the primary and sensitivity
## coded datasets:
##
##   A. Length effects with full family×length interaction.
##      For each of the 7 categories, fit
##         is_CAT ~ family * framing + family * n_fac + (1|model_id) + (1|trial_id)
##      and run two LRTs:
##         (i)  drop family:n_fac          → "does the length effect vary by family?"
##         (ii) drop n_fac AND family:n_fac (marginality) → "is there any length effect at all?"
##      Same deterministic fallback ladder as 01_primary.R. Sparse categories
##      (HDG, OTH, AFF in some cells) may degrade to glmmTMB model-only or
##      lme4 — logged in `re_structure`, no deviation needed because §6.3 is
##      exploratory.
##
##   B. Exploratory H1 battery (prereg §6.2, item 1):
##      "Likelihood-ratio test of the family fixed effect, run separately for
##      each of the seven categories." 01_primary.R covers PRO and IDM (the
##      pre-specified primary tests). This script covers the other five
##      (EPI, CAP, AFF, HDG, OTH) as exploratory. Same marginality-respecting
##      LRT: drop family AND family:framing from the §6.2 §01-style fixed-
##      effects spec.
##
##   C. Type/token ratio per (family, framing, N) cell.
##      Tokens = parseable words in the cell. Types = unique surface forms.
##      Also reports root-TTR = types / sqrt(tokens), which adjusts for the
##      known length sensitivity of raw TTR. The token-level data come from
##      the coded CSV (one row per word), so TTR varies between primary and
##      sensitivity only if the swap added/removed any row, which it does
##      not — the swap re-codes but never drops, so this output is identical
##      across datasets. Written once with dataset="both" for honesty.
##
##   D. Jensen-Shannon divergence per model, between Framing A and Framing B.
##      Two flavors:
##         (i)  category JS: 7-bin proportion vector per (model, framing).
##              This is the prereg-literal version: "category proportions
##              vector". One scalar per model.
##         (ii) word-distribution JS: per-cell vocabulary, Laplace-smoothed
##              over the union vocabulary at α = 0.5. Same scalar shape; the
##              word version answers "does framing-B change the words, not
##              just the categories?" One scalar per model.
##      JS distance reported is the symmetric sqrt of the JS divergence,
##      bounded in [0, 1] when log base 2 is used. We use log base 2.
##
##   E. Top-words tables.
##      `top_words_paper.csv`     : top-10 words per (family, framing)   →  6 lists × 10 rows = 60 rows
##      `top_words_appendix.csv`  : top-10 words per (family, framing, N) → 24 lists × 10 rows = 240 rows
##      Ties at the bottom rank are kept (output may have >10 rows per cell).
##      Counts are within-cell raw counts; proportions are within-cell.
##      Driven from per_word_main.csv (judge codes irrelevant for word lists),
##      so unaffected by the primary/sensitivity distinction. Written once.
##
## Outputs:
##   output/secondary_results.csv     — flat results table for A + B + D
##   output/type_token_ratios.csv     — for C
##   output/top_words_paper.csv       — for E (6-list version)
##   output/top_words_appendix.csv    — for E (24-list version)
##   output/secondary_models.rds      — fitted model objects from A + B
##   output/secondary_session.txt     — sessionInfo() at run time
##
## Usage:
##   cd study1_analysis/notebooks
##   Rscript 05_secondary.R

source("_setup.R")

## --- Source helpers from 01_primary.R -------------------------------------
##
## Same trick 04_sonnet_sensitivity.R uses: read 01_primary.R, find the first
## executable line, source everything above it. We reuse fit_category_model(),
## refit_dropping(), lrt(), wald_coef(), report_variance_components(), and
## the convergence-checking machinery, since the §6.3 length/exploratory-H1
## fits are structurally identical to the §6.2 ones.

primary_script <- file.path(HERE, "01_primary.R")
primary_lines  <- readLines(primary_script)
exec_start <- grep("^primary_df\\s*<-\\s*load_coded", primary_lines)
if (length(exec_start) != 1) {
  stop("Could not locate the first executable line ",
       "(`primary_df <- load_coded(...)`) in 01_primary.R.")
}
defs_only <- primary_lines[seq_len(exec_start - 1L)]
eval(parse(text = paste(defs_only, collapse = "\n")), envir = globalenv())
cat("Sourced function definitions from 01_primary.R (lines 1 to ",
    exec_start - 1L, ")\n", sep = "")

## --- Load data -------------------------------------------------------------

banner("Secondary / exploratory analyses (§6.3 + §6.2-exploratory)")

primary_df     <- load_coded(CODED_PRIMARY,     "primary (coded_main.csv)")
sensitivity_df <- load_coded(CODED_SENSITIVITY, "sensitivity (coded_main_sensitivity.csv)")

cat("\nDataset row counts:\n")
cat("  primary coded   :", nrow(primary_df),     "words\n")
cat("  sensitivity     :", nrow(sensitivity_df), "words\n\n")

## ==========================================================================
## A. Length effects (full family×length interaction), per category
## ==========================================================================
##
## Fixed-effects formula for the LENGTH-augmented model:
##   is_CAT ~ family * framing + family * n_fac
## In R formula algebra this expands to:
##   family + framing + n_fac + family:framing + family:n_fac
## (no three-way interaction, by §6.3 design — three-way is not pre-specified
## and the cells get too thin to fit it reliably for AFF/HDG/OTH.)

FIXED_LENGTH_CAT <- "family * framing + family * n_fac"

#' Guarded wrapper around lrt() that catches the negative-chi² case.
#' When glmmTMB (or lme4) lands the full and reduced fits at different local
#' optima with extreme sparsity, the LRT statistic 2(ll_full - ll_reduced) can
#' come back negative — a mathematical impossibility under correct convergence.
#' We treat any negative chi² as an unestimable test rather than reporting a
#' meaningless number. The original (negative) chi² and both log-likelihoods
#' are preserved in the note for auditability.
lrt_guarded <- function(full_fit, reduced_fit, label = NA_character_) {
  out <- lrt(full_fit, reduced_fit)
  if (!is.na(out$chi2) && out$chi2 < 0) {
    audit <- sprintf(
      "NEGATIVE LRT chi2 = %.4f (ll_full = %.4f, ll_reduced = %.4f) — full and reduced fits did not converge to the same optimum; treated as unestimable.",
      out$chi2, out$logLik_full, out$logLik_reduced
    )
    cat("  *** ", if (!is.na(label)) paste0("[", label, "] ", "") else "",
        audit, "\n", sep = "")
    out$chi2          <- NA_real_
    out$p_value       <- NA_real_
    out$unestimable_note <- audit
  } else {
    out$unestimable_note <- NA_character_
  }
  out
}

#' Fit the length-augmented model for one category and run two LRTs.
#' Returns a list with two `results` rows (length-interaction, length-main)
#' and the fitted models.
length_battery_one_cat <- function(df, category, dataset_label) {
  test_id_inter <- paste0("LEN-", category, "-interaction")
  test_id_main  <- paste0("LEN-", category, "-main")
  banner(paste("Length tests:", category, "  [dataset:", dataset_label, "]"), "-")

  full <- fit_category_model(df, category, FIXED_LENGTH_CAT)
  if (!full$converged) {
    failed_inter <- list(dataset = dataset_label, test = test_id_inter,
                         status = "FAILED_FULL_MODEL",
                         warnings = paste(full$warnings, collapse = " | "))
    failed_main  <- list(dataset = dataset_label, test = test_id_main,
                         status = "FAILED_FULL_MODEL",
                         warnings = paste(full$warnings, collapse = " | "))
    return(list(
      results = setNames(list(failed_inter, failed_main),
                         c(test_id_inter, test_id_main)),
      models  = list()
    ))
  }
  report_variance_components(full, paste("LEN-", category))

  results <- list()
  models  <- list()
  models[[paste0(test_id_inter, ".full")]] <- full

  # ---- LRT (i): drop family:n_fac only.
  red_inter <- tryCatch(refit_dropping(full, "family:n_fac"),
                        error = function(e) NULL)
  if (!is.null(red_inter)) {
    test_out <- lrt_guarded(full$model, red_inter,
                            label = paste0(test_id_inter, "/", dataset_label))
    note_text <- if (!is.na(test_out$unestimable_note)) test_out$unestimable_note
                 else "Exploratory (§6.3); α uncorrected"
    results[[test_id_inter]] <- list(
      dataset      = dataset_label,
      test         = test_id_inter,
      kind         = "LRT (length effect varies by family — drop family:n_fac)",
      chi2         = test_out$chi2,
      df           = test_out$df,
      p_value      = test_out$p_value,
      threshold    = 0.05,
      significant  = !is.na(test_out$p_value) && test_out$p_value < 0.05,
      AIC_full     = test_out$AIC_full,
      AIC_reduced  = test_out$AIC_reduced,
      engine       = full$engine,
      re_structure = full$re_structure,
      warnings     = paste(full$warnings, collapse = " | "),
      note         = note_text
    )
  } else {
    results[[test_id_inter]] <- list(
      dataset = dataset_label, test = test_id_inter,
      status = "FAILED_REDUCED_MODEL_INTER"
    )
  }

  # ---- LRT (ii): drop n_fac AND family:n_fac (length-anywhere test, marginality).
  red_main <- tryCatch(refit_dropping(full, c("n_fac", "family:n_fac")),
                       error = function(e) NULL)
  if (!is.null(red_main)) {
    test_out <- lrt_guarded(full$model, red_main,
                            label = paste0(test_id_main, "/", dataset_label))
    note_text <- if (!is.na(test_out$unestimable_note)) test_out$unestimable_note
                 else "Exploratory (§6.3); α uncorrected"
    results[[test_id_main]] <- list(
      dataset      = dataset_label,
      test         = test_id_main,
      kind         = "LRT (any length effect — drop n_fac + family:n_fac)",
      chi2         = test_out$chi2,
      df           = test_out$df,
      p_value      = test_out$p_value,
      threshold    = 0.05,
      significant  = !is.na(test_out$p_value) && test_out$p_value < 0.05,
      AIC_full     = test_out$AIC_full,
      AIC_reduced  = test_out$AIC_reduced,
      engine       = full$engine,
      re_structure = full$re_structure,
      warnings     = paste(full$warnings, collapse = " | "),
      note         = note_text
    )
  } else {
    results[[test_id_main]] <- list(
      dataset = dataset_label, test = test_id_main,
      status = "FAILED_REDUCED_MODEL_MAIN"
    )
  }

  list(results = results, models = models)
}

## ==========================================================================
## B. Exploratory H1 battery (the five non-pre-specified categories)
## ==========================================================================
##
## Same marginality-respecting test as H1-PRO and H1-IDM in 01_primary.R,
## but on EPI / CAP / AFF / HDG / OTH. AFF is double-listed here and in
## 01_primary.R's H2-AFF fit, which is fine — the fit is the same model
## with a different question asked of it.

EXPLORATORY_H1_CATS <- c("EPI", "CAP", "AFF", "HDG", "OTH")
FIXED_FULL_CAT      <- "family * framing + n_fac"  # mirrors 01_primary.R

#' Run the H1 family-LRT for one category on one dataset.
h1_one_cat <- function(df, category, dataset_label) {
  test_id <- paste0("H1-", category, "-exploratory")
  banner(paste("Exploratory H1:", category, "  [dataset:", dataset_label, "]"), "-")

  full <- fit_category_model(df, category, FIXED_FULL_CAT)
  if (!full$converged) {
    failed_row <- list(
      dataset = dataset_label, test = test_id,
      status = "FAILED_FULL_MODEL",
      warnings = paste(full$warnings, collapse = " | ")
    )
    return(list(
      results = setNames(list(failed_row), test_id),
      models  = list()
    ))
  }
  report_variance_components(full, test_id)

  red <- tryCatch(refit_dropping(full, c("family", "family:framing")),
                  error = function(e) NULL)
  if (is.null(red)) {
    failed_row <- list(
      dataset = dataset_label, test = test_id,
      status = "FAILED_REDUCED_MODEL"
    )
    return(list(
      results = setNames(list(failed_row), test_id),
      models  = setNames(list(full), paste0(test_id, ".full"))
    ))
  }

  test_out <- lrt_guarded(full$model, red,
                          label = paste0(test_id, "/", dataset_label))
  note_text <- if (!is.na(test_out$unestimable_note)) test_out$unestimable_note
               else "Exploratory (§6.2 item 1, non-pre-specified category); α uncorrected"
  result_row <- list(
    dataset      = dataset_label,
    test         = test_id,
    kind         = "LRT (family main effect on category, marginality-respecting; EXPLORATORY)",
    chi2         = test_out$chi2,
    df           = test_out$df,
    p_value      = test_out$p_value,
    threshold    = 0.05,
    significant  = !is.na(test_out$p_value) && test_out$p_value < 0.05,
    AIC_full     = test_out$AIC_full,
    AIC_reduced  = test_out$AIC_reduced,
    engine       = full$engine,
    re_structure = full$re_structure,
    warnings     = paste(full$warnings, collapse = " | "),
    note         = note_text
  )
  list(
    results = setNames(list(result_row), test_id),
    models  = setNames(list(full),        paste0(test_id, ".full"))
  )
}

## ==========================================================================
## C. Type/token ratio per (family, framing, N) cell
## ==========================================================================

compute_ttr_table <- function(df, dataset_label) {
  df %>%
    group_by(family, framing, n) %>%
    summarize(
      n_tokens = n(),
      n_types  = n_distinct(word),
      ttr      = n_distinct(word) / n(),
      ttr_root = n_distinct(word) / sqrt(n()),
      .groups  = "drop"
    ) %>%
    mutate(dataset = dataset_label, .before = 1) %>%
    arrange(family, framing, n)
}

## ==========================================================================
## D. Jensen-Shannon divergence per model: framing-A vs framing-B
## ==========================================================================
##
## JS divergence on log base 2 is bounded in [0, 1]. JS distance is sqrt(JS).
## For category JS: 7-bin vector p_A, p_B for each model, then JS(p_A, p_B).
## For word JS:    per-(model, framing) word-count vector; smooth with α=0.5
##                 over the union vocabulary V (only words appearing in either
##                 framing for that model); compute JS on the smoothed
##                 proportions. Choice of α and the union-V scope is logged
##                 in the script header and the output's `note` column.

#' JS divergence between two probability vectors (same length, sum-to-1).
#' Returns NA if either vector has zero mass.
js_divergence <- function(p, q, base = 2) {
  if (sum(p) == 0 || sum(q) == 0) return(NA_real_)
  # Renormalize defensively in case of rounding.
  p <- p / sum(p)
  q <- q / sum(q)
  m <- 0.5 * (p + q)
  kl <- function(a, b) {
    nz <- a > 0
    sum(a[nz] * (log(a[nz], base = base) - log(b[nz], base = base)))
  }
  0.5 * kl(p, m) + 0.5 * kl(q, m)
}

js_distance <- function(p, q, base = 2) sqrt(js_divergence(p, q, base))

#' Category-proportion vector for one (model, framing). Always length 7, in
#' the global CATEGORIES order. Zero categories get zero, not smoothed (this
#' is the prereg-literal version; the word-JS version below handles zeros via
#' Laplace smoothing).
category_proportion_vector <- function(df, model, framing_lvl) {
  sub <- df[df$model_id_sent == model & df$framing == framing_lvl, ]
  if (nrow(sub) == 0) return(setNames(rep(NA_real_, length(CATEGORIES)), CATEGORIES))
  counts <- table(factor(sub$code, levels = CATEGORIES))
  as.numeric(counts) / sum(counts)
}

#' Compute the category-JS table on one dataset.
compute_category_js <- function(df, dataset_label) {
  models <- sort(unique(as.character(df$model_id_sent)))
  out <- lapply(models, function(m) {
    pA <- category_proportion_vector(df, m, "A")
    pB <- category_proportion_vector(df, m, "B")
    family <- as.character(unique(df$family[df$model_id_sent == m]))[1]
    tibble::tibble(
      dataset    = dataset_label,
      family     = family,
      model_id   = m,
      kind       = "category-proportion JS (7-bin vector, no smoothing)",
      js_div     = js_divergence(pA, pB),
      js_dist    = js_distance(pA, pB),
      n_A_words  = sum(df$model_id_sent == m & df$framing == "A"),
      n_B_words  = sum(df$model_id_sent == m & df$framing == "B"),
      note       = "JS uses log base 2 → bounded in [0, 1]"
    )
  })
  dplyr::bind_rows(out)
}

#' Word-distribution JS for a (model) pair-of-framings, with Laplace
#' smoothing α = 0.5 over the union vocabulary observed for that model.
#' Per-word data come from the coded CSV (`word` column).
compute_word_js <- function(df, dataset_label, alpha = 0.5) {
  models <- sort(unique(as.character(df$model_id_sent)))
  out <- lapply(models, function(m) {
    sub_A <- df[df$model_id_sent == m & df$framing == "A", ]
    sub_B <- df[df$model_id_sent == m & df$framing == "B", ]
    family <- as.character(unique(df$family[df$model_id_sent == m]))[1]

    vocab <- sort(unique(c(sub_A$word, sub_B$word)))
    if (length(vocab) == 0) {
      return(tibble::tibble(
        dataset = dataset_label, family = family, model_id = m,
        kind = paste0("word JS (Laplace α=", alpha, ", union vocab)"),
        js_div = NA_real_, js_dist = NA_real_,
        n_A_words = nrow(sub_A), n_B_words = nrow(sub_B), vocab_size = 0L,
        note = "empty vocabulary"
      ))
    }
    cA <- table(factor(sub_A$word, levels = vocab))
    cB <- table(factor(sub_B$word, levels = vocab))
    # Laplace smooth: add α to each count.
    pA <- (as.numeric(cA) + alpha) / (sum(as.numeric(cA)) + alpha * length(vocab))
    pB <- (as.numeric(cB) + alpha) / (sum(as.numeric(cB)) + alpha * length(vocab))

    tibble::tibble(
      dataset    = dataset_label,
      family     = family,
      model_id   = m,
      kind       = paste0("word JS (Laplace α=", alpha, ", union vocab)"),
      js_div     = js_divergence(pA, pB),
      js_dist    = js_distance(pA, pB),
      n_A_words  = nrow(sub_A),
      n_B_words  = nrow(sub_B),
      vocab_size = length(vocab),
      note       = "Laplace smoothing over union of A+B vocabularies"
    )
  })
  dplyr::bind_rows(out)
}

## ==========================================================================
## E. Top-words tables
## ==========================================================================
##
## These are word-counts, not category counts. They don't depend on the
## judge's codes, so we compute them from per_word_main.csv (not the coded
## CSVs) and write them once.

compute_top_words <- function(per_word, group_cols, top_n = 10) {
  # 1. Per-cell totals (so we can report within-cell proportions).
  totals <- per_word %>%
    group_by(across(all_of(group_cols))) %>%
    summarize(total_words_in_cell = n(), .groups = "drop")

  # 2. Per-cell word counts, take top_n by count, ties at bottom kept.
  per_word %>%
    group_by(across(all_of(group_cols)), word) %>%
    summarize(count = n(), .groups = "drop") %>%
    group_by(across(all_of(group_cols))) %>%
    arrange(desc(count), word, .by_group = TRUE) %>%
    mutate(rank = dplyr::row_number()) %>%
    filter(rank <= top_n) %>%
    ungroup() %>%
    left_join(totals, by = group_cols) %>%
    mutate(within_cell_proportion = count / total_words_in_cell) %>%
    arrange(across(all_of(group_cols)), rank)
}

## ==========================================================================
## Run everything
## ==========================================================================

all_results <- list()
all_models  <- list(primary = list(), sensitivity = list())

## ---- A + B: length and exploratory-H1 batteries, both datasets ----

for (ds_pair in list(
  list(label = "primary",     df = primary_df),
  list(label = "sensitivity", df = sensitivity_df)
)) {
  banner(paste("=== Length + exploratory-H1 batteries on dataset:", ds_pair$label, "==="))

  # A: length-effect battery on all 7 categories.
  for (cat_label in CATEGORIES) {
    out <- length_battery_one_cat(ds_pair$df, cat_label, ds_pair$label)
    all_results <- c(all_results, out$results)
    for (nm in names(out$models)) {
      all_models[[ds_pair$label]][[nm]] <- out$models[[nm]]
    }
  }

  # B: exploratory-H1 on the 5 non-pre-specified categories.
  for (cat_label in EXPLORATORY_H1_CATS) {
    out <- h1_one_cat(ds_pair$df, cat_label, ds_pair$label)
    all_results <- c(all_results, out$results)
    for (nm in names(out$models)) {
      all_models[[ds_pair$label]][[nm]] <- out$models[[nm]]
    }
  }
}

## ---- D: JS divergence (both flavors), both datasets ----

banner("Jensen-Shannon divergence: category-JS and word-JS, both datasets")

js_rows <- list()
for (ds_pair in list(
  list(label = "primary",     df = primary_df),
  list(label = "sensitivity", df = sensitivity_df)
)) {
  cat_js  <- compute_category_js(ds_pair$df, ds_pair$label)
  word_js <- compute_word_js(ds_pair$df, ds_pair$label, alpha = 0.5)
  js_rows[[length(js_rows) + 1]] <- cat_js
  js_rows[[length(js_rows) + 1]] <- word_js
}
js_table <- dplyr::bind_rows(js_rows)

cat("\nJS table (head):\n")
print(head(js_table, 12))

## ---- Flatten A + B results and append D rows ----

flatten_results <- function(run_list) {
  # Same schema as 01_primary.R's flatten_results so a viewer of either CSV
  # can read both with the same column expectations. If a fit failed, the
  # row carries `note = "FAILED_*"` rather than a separate `status` column.
  do.call(rbind, lapply(run_list, function(r) {
    cols <- c("dataset", "test", "kind", "coefficient", "estimate",
              "std_error", "z", "chi2", "df", "p_value",
              "threshold", "significant",
              "direction_predicted", "direction_observed",
              "AIC_full", "AIC_reduced",
              "engine", "re_structure", "warnings", "note")
    row <- as.list(setNames(rep(NA, length(cols)), cols))
    # Promote status (if set) into the note column for schema parity with 01.
    if (!is.null(r$status) && is.null(r$note)) {
      r$note <- r$status
    }
    for (nm in intersect(names(r), cols)) row[[nm]] <- r[[nm]]
    as.data.frame(row, stringsAsFactors = FALSE)
  }))
}

results_AB <- flatten_results(all_results)

# Reshape JS rows into the same wide schema as the LRT rows so they can live
# in the same CSV. JS rows use the `kind` column for flavor and store the JS
# distance in `estimate` (for use as a scalar quantity in figures).
js_rows_wide <- js_table %>%
  transmute(
    dataset     = dataset,
    test        = paste0("JS-", ifelse(grepl("^category", kind), "category", "word"),
                         "-", model_id),
    kind        = kind,
    coefficient = NA_character_,
    estimate    = js_dist,            # JS distance, in [0, 1]
    std_error   = NA_real_,
    z           = NA_real_,
    chi2        = NA_real_,
    df          = NA_real_,
    p_value     = NA_real_,
    threshold   = NA_real_,
    significant = NA,
    direction_predicted = NA_character_,
    direction_observed  = NA_character_,
    AIC_full    = NA_real_,
    AIC_reduced = NA_real_,
    engine      = NA_character_,
    re_structure = NA_character_,
    warnings    = NA_character_,
    note        = paste0("family=", family,
                         "; n_A_words=", n_A_words,
                         "; n_B_words=", n_B_words,
                         "; ", note)
  )

results_all <- dplyr::bind_rows(
  tibble::as_tibble(results_AB),
  js_rows_wide
)

out_csv <- file.path(NB_OUT, "secondary_results.csv")
write_csv(results_all, out_csv)
cat("\nSecondary results CSV -> ", out_csv, "\n", sep = "")

## ---- Save model objects ----

out_rds <- file.path(NB_OUT, "secondary_models.rds")
saveRDS(all_models, out_rds)
cat("Secondary models     -> ", out_rds, "\n", sep = "")

## ---- C: TTR (one table, both datasets — same numbers; sanity check) ----

banner("Type/token ratio per (family, framing, N) cell")

ttr_primary     <- compute_ttr_table(primary_df,     "primary")
ttr_sensitivity <- compute_ttr_table(sensitivity_df, "sensitivity")
stopifnot(nrow(ttr_primary) == nrow(ttr_sensitivity))
# TTR is purely a word-counting operation; primary and sensitivity differ only
# in category labels, not in which words/rows exist. We sanity-check that the
# numerical columns match and then collapse to a single table.
ttr_diff <- ttr_primary %>%
  select(family, framing, n, n_tokens, n_types, ttr, ttr_root) %>%
  inner_join(
    ttr_sensitivity %>% select(family, framing, n, n_tokens, n_types, ttr, ttr_root),
    by = c("family", "framing", "n"),
    suffix = c("_pri", "_sens")
  )
ttr_check <- with(ttr_diff,
                  all(n_tokens_pri == n_tokens_sens) &&
                  all(n_types_pri  == n_types_sens))
if (!ttr_check) {
  warning("TTR numbers differ between primary and sensitivity. This is unexpected; ",
          "the sensitivity swap re-codes categories but should not add/remove rows. ",
          "Writing both versions for inspection.")
  ttr_out <- bind_rows(ttr_primary, ttr_sensitivity)
} else {
  ttr_out <- ttr_primary %>% mutate(dataset = "both (primary == sensitivity row-wise)")
  cat("  Verified: TTR numbers identical between primary and sensitivity.\n")
}

out_ttr <- file.path(NB_OUT, "type_token_ratios.csv")
write_csv(ttr_out, out_ttr)
cat("TTR table -> ", out_ttr, "\n", sep = "")

## ---- E: Top-words tables (driven from per_word_main.csv) ----

banner("Top-words tables")

per_word <- read_csv(file.path(DATA_DIR, "per_word_main.csv"),
                     show_col_types = FALSE)

top_paper    <- compute_top_words(per_word, c("family", "framing"),       top_n = 10)
top_appendix <- compute_top_words(per_word, c("family", "framing", "n"),  top_n = 10)

out_top_paper    <- file.path(NB_OUT, "top_words_paper.csv")
out_top_appendix <- file.path(NB_OUT, "top_words_appendix.csv")
write_csv(top_paper,    out_top_paper)
write_csv(top_appendix, out_top_appendix)
cat("Top-words (paper)    -> ", out_top_paper,    "\n", sep = "")
cat("Top-words (appendix) -> ", out_top_appendix, "\n", sep = "")

## ---- Reproducibility ----

write_session_info("secondary_session.txt")

## ---- Compact terminal summary ----

banner("Compact summary — secondary analyses")
summary_table <- results_all %>%
  filter(!is.na(p_value) | grepl("^JS", test)) %>%
  select(dataset, test, chi2, df, p_value, estimate) %>%
  as.data.frame()
print(summary_table, row.names = FALSE)

cat("\nReminder: every test in 05_secondary.R is exploratory. No Bonferroni\n")
cat("correction is applied here; α = .05 is used as a uniform reporting\n")
cat("threshold. Substantive claims drawn from this script should be presented\n")
cat("as exploratory in the writeup.\n")
