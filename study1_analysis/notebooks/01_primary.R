## 01_primary.R — Primary confirmatory analyses (locked)
##
## Runs the 5 pre-specified primary tests (per prereg §6.2 and the
## 2026-05-10 / 2026-05-15 deviations) on both the primary coded dataset
## (study1_analysis/data/coded_main.csv) and the sensitivity dataset
## (study1_analysis/data/coded_main_sensitivity.csv).
##
## The 5 tests at Bonferroni-corrected α = .01 (per deviation 2026-05-10):
##   1. H1-PRO       family main effect on Prosocial proportion (LRT)
##   2. H1-IDM       family main effect on Identity/Meta proportion (LRT)
##   3. H2-IDM       framing main effect on IDM (coefficient Wald test)
##   4. H3-IDM       family × framing interaction on IDM (coefficient Wald test)
##   5. H4-compliance family main effect on compliance rate (LRT, per-trial outcome)
##
## H2-AFF is also reported (framing coefficient in the AFF model) but is
## corrected separately per prereg §6.2.
##
## Outputs:
##   output/primary_results.csv     — flat results table (one row per test × dataset)
##   output/primary_models.rds      — list of fitted model objects for inspection
##   output/primary_session.txt     — sessionInfo() at run time
##
## Usage:
##   cd study1_analysis/notebooks
##   Rscript 01_primary.R
##
## Convergence policy (deterministic fallback ladder, applied per model fit):
##   1. glmmTMB with full RE structure: (1|model_id) + (1|trial_id)
##   2. If singular / non-convergent: drop (1|trial_id), keep (1|model_id)
##   3. If still failing: lme4::glmer with optimizer = bobyqa, full RE structure
##   4. If still failing: lme4::glmer with (1|model_id) only
## Any fallback used is recorded in the results CSV (`re_structure` column)
## and a deviation entry must be added by hand to study1/prereg/deviations.md.

source("_setup.R")

banner("Primary confirmatory analyses (5 tests × 2 datasets)")

CATEGORIES_TESTED <- c("PRO", "IDM", "AFF")  # PRO and IDM for primary, AFF for separate H2

ALPHA_BONF        <- 0.01     # 5 primary tests at family-wise α = .05
ALPHA_H2_AFF      <- 0.05     # H2-AFF reported separately, uncorrected

## --- Model-fitting helpers -------------------------------------------------

#' Fit a binomial GLMM for a category indicator with the prereg-specified
#' full structure, falling back through a deterministic ladder if needed.
#'
#' Returns a list with: model, engine, re_structure, converged, warnings.
fit_category_model <- function(df, category, formula_fixed) {
  outcome_name <- paste0("is_", category)
  df[[outcome_name]] <- as.integer(df$code == category)

  full_re   <- "+ (1 | model_id) + (1 | trial_id)"
  reduced_re <- "+ (1 | model_id)"

  attempts <- list(
    list(engine = "glmmTMB", re = full_re,    label = "glmmTMB full"),
    list(engine = "glmmTMB", re = reduced_re, label = "glmmTMB model-only"),
    list(engine = "lme4",    re = full_re,    label = "lme4 full"),
    list(engine = "lme4",    re = reduced_re, label = "lme4 model-only")
  )

  collected_warnings <- character()

  for (att in attempts) {
    formula_full <- as.formula(paste(outcome_name, "~", formula_fixed, att$re))
    cat("  Trying:", att$label, "\n")

    fit <- tryCatch({
      withCallingHandlers({
        if (att$engine == "glmmTMB") {
          glmmTMB(formula_full, data = df, family = binomial())
        } else {
          glmer(formula_full, data = df, family = binomial(),
                control = glmerControl(optimizer = "bobyqa",
                                       optCtrl = list(maxfun = 1e5)))
        }
      }, warning = function(w) {
        collected_warnings <<- c(collected_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      })
    }, error = function(e) {
      collected_warnings <<- c(collected_warnings,
                               paste("ERROR:", conditionMessage(e)))
      NULL
    })

    if (is.null(fit)) next

    converged <- is_converged(fit, att$engine)
    if (converged) {
      return(list(model        = fit,
                  engine       = att$engine,
                  re_structure = att$re,
                  converged    = TRUE,
                  warnings     = collected_warnings,
                  attempt      = att$label))
    } else {
      collected_warnings <- c(collected_warnings,
                              paste(att$label, "did not converge / singular"))
    }
  }

  list(model = NULL, engine = NA, re_structure = NA,
       converged = FALSE, warnings = collected_warnings, attempt = "none")
}

#' Convergence / singularity check. glmmTMB exposes `sdr$pdHess`; lme4
#' exposes a `optinfo$conv$opt` code. Both can be inspected via summary().
is_converged <- function(fit, engine) {
  if (engine == "glmmTMB") {
    # convergence info lives in fit$sdr; pdHess = TRUE means the Hessian
    # was positive-definite, which is the practical convergence check.
    sdr <- fit$sdr
    if (is.null(sdr)) return(FALSE)
    isTRUE(sdr$pdHess)
  } else {
    # lme4: conv$opt == 0 is success
    isTRUE(fit@optinfo$conv$opt == 0)
  }
}

#' Refit a model with a single fixed-effect term dropped, returning the
#' reduced fit (same engine, same RE structure). Used for likelihood-ratio
#' tests of fixed effects.
refit_dropping <- function(fitted, drop_terms) {
  base_formula <- formula(fitted$model)
  # Build new formula by removing requested terms from the fixed part.
  # update() with a "- term" specification is the cleanest way.
  drop_rhs <- paste("-", drop_terms, collapse = " ")
  new_formula <- update(base_formula, paste(". ~ . ", drop_rhs))

  if (fitted$engine == "glmmTMB") {
    update(fitted$model, formula = new_formula)
  } else {
    update(fitted$model, formula = new_formula)
  }
}

#' Likelihood-ratio test between a full and reduced model.
#' Returns a list with chi2, df, p_value, AIC_full, AIC_reduced.
lrt <- function(full_fit, reduced_fit) {
  ll_full    <- as.numeric(logLik(full_fit))
  ll_reduced <- as.numeric(logLik(reduced_fit))
  df_full    <- attr(logLik(full_fit), "df")
  df_reduced <- attr(logLik(reduced_fit), "df")
  chi2       <- 2 * (ll_full - ll_reduced)
  df_diff    <- df_full - df_reduced
  p_value    <- pchisq(chi2, df = df_diff, lower.tail = FALSE)
  list(chi2       = chi2,
       df         = df_diff,
       p_value    = p_value,
       AIC_full   = AIC(full_fit),
       AIC_reduced = AIC(reduced_fit),
       logLik_full = ll_full,
       logLik_reduced = ll_reduced)
}

#' Wald test on a single coefficient. Extracts estimate, SE, z, p.
wald_coef <- function(fitted, coef_name) {
  if (fitted$engine == "glmmTMB") {
    co <- summary(fitted$model)$coefficients$cond
  } else {
    co <- summary(fitted$model)$coefficients
  }
  if (!(coef_name %in% rownames(co))) {
    return(list(coef = coef_name, estimate = NA, std_error = NA,
                z = NA, p_value = NA,
                note = paste("coefficient", coef_name, "not in model")))
  }
  row <- co[coef_name, ]
  list(coef       = coef_name,
       estimate   = unname(row["Estimate"]),
       std_error  = unname(row["Std. Error"]),
       z          = unname(row["z value"]),
       p_value    = unname(row[grep("Pr\\(", colnames(co))]),
       note       = "")
}

## --- Pre-flight diagnostics ------------------------------------------------

#' Print per-trial distribution of a binary outcome for a given category.
#' Tells us whether the trial-level random intercept has anything to grab.
#' (If most trials are all-zero, the trial RE will go singular.)
preflight_category <- function(df, category) {
  is_cat <- as.integer(df$code == category)
  by_trial <- tapply(is_cat, df$trial_id, sum)
  zero <- sum(by_trial == 0)
  one  <- sum(by_trial == 1)
  two  <- sum(by_trial == 2)
  more <- sum(by_trial >= 3)
  n_trials <- length(by_trial)
  cat(sprintf("  %s: %d/%d words (%.1f%%)  |  per-trial: zero=%d (%.1f%%) one=%d two=%d 3+=%d\n",
              category, sum(is_cat), nrow(df), 100*mean(is_cat),
              zero, 100*zero/n_trials, one, two, more))
  invisible(list(category = category, p_outcome = mean(is_cat),
                 n_trials = n_trials, zero_outcome_trials = zero))
}

#' Print per-family compliance counts. Flags complete separation (any
#' family-level cell at 0% or 100%), which makes Wald-style coefficient
#' tests against that level produce nonsense SEs.
preflight_compliance <- function(per_call_df) {
  tbl <- table(per_call_df$family, per_call_df$compliant)
  cat("  Per-family compliance:\n")
  for (fam in rownames(tbl)) {
    n_compliant <- if ("1" %in% colnames(tbl)) tbl[fam, "1"] else 0
    n_total     <- sum(tbl[fam, ])
    rate        <- n_compliant / n_total
    flag        <- if (rate %in% c(0, 1)) "  <-- COMPLETE SEPARATION" else ""
    cat(sprintf("    %-10s %d / %d  (%.1f%%)%s\n",
                fam, n_compliant, n_total, 100*rate, flag))
  }
}

#' After a model is fit, print its variance components so we can see whether
#' a trial-level RE went singular (variance == 0) versus stayed non-trivial.
report_variance_components <- function(fitted, test_label) {
  if (is.null(fitted) || is.null(fitted$model)) return(invisible(NULL))
  cat(sprintf("  [variance components for %s, engine=%s]\n",
              test_label, fitted$engine))
  vc <- tryCatch({
    if (fitted$engine == "glmmTMB") {
      vc_summary <- summary(fitted$model)$varcor$cond
      vc_df <- data.frame(
        group = names(vc_summary),
        variance = sapply(vc_summary, function(x) attr(x, "stddev")^2)
      )
      vc_df
    } else {
      vc_obj <- as.data.frame(VarCorr(fitted$model))
      data.frame(group = vc_obj$grp, variance = vc_obj$vcov)
    }
  }, error = function(e) {
    cat("    (could not extract variance components: ", conditionMessage(e), ")\n", sep = "")
    return(NULL)
  })
  if (!is.null(vc)) {
    for (i in seq_len(nrow(vc))) {
      flag <- if (vc$variance[i] < 1e-8) "  <-- SINGULAR (≈ 0)" else ""
      cat(sprintf("    %-25s variance = %.6f%s\n",
                  vc$group[i], vc$variance[i], flag))
    }
  }
}

## --- The five primary tests, packaged --------------------------------------

#' Run all five primary tests on one coded dataset.
#' Returns a list:
#'   results: tibble (one row per test) with chi2/df/p_value or coef/SE/z/p
#'   models : named list of fitted models for archival
run_primary_battery <- function(coded_df, per_call_df, dataset_label) {
  banner(paste("Dataset:", dataset_label))

  ## ---- Pre-flight diagnostics ---------------------------------------------
  ## Before any model is fit, print the things that drive convergence behavior
  ## so the deviation log (if needed) can be written from facts, not warnings.
  banner("Pre-flight diagnostics (no models fit yet)", "-")
  cat("Category outcome density and per-trial structure:\n")
  cat("(low % outcome + many zero-outcome trials = trial-level RE likely singular)\n")
  for (cat_label in c("PRO", "IDM", "AFF")) {
    preflight_category(coded_df, cat_label)
  }
  cat("\nCompliance outcome (H4):\n")
  cat("(any cell at 0% or 100% = complete separation; LRT still works, coefficient SEs unreliable)\n")
  preflight_compliance(per_call_df)
  cat("\n")

  results <- list()
  models  <- list()

  ## Common fixed-effects spec for category models, per prereg §6.2.
  ## family + framing + n_fac (linear + quadratic via ordered factor contrast)
  ## + family × framing interaction.
  FIXED_FULL_CAT <- "family * framing + n_fac"

  ## ---- H1-PRO and H1-IDM: family main effect (LRT) ----
  ## Tricky: to test family main effect cleanly while preserving marginality,
  ## drop BOTH family and family:framing from the model.
  for (cat_label in c("PRO", "IDM")) {
    test_name <- paste0("H1-", cat_label)
    banner(paste("Test:", test_name, "(LRT family main effect)"), "-")

    full <- fit_category_model(coded_df, cat_label, FIXED_FULL_CAT)
    if (!full$converged) {
      results[[test_name]] <- list(test = test_name, status = "FAILED_FULL_MODEL",
                                   warnings = paste(full$warnings, collapse = " | "))
      next
    }
    models[[paste0(test_name, ".full")]] <- full
    report_variance_components(full, test_name)

    # Reduced model: drop family AND family:framing (marginality).
    reduced_fit <- tryCatch(
      refit_dropping(full, c("family", "family:framing")),
      error = function(e) NULL
    )
    if (is.null(reduced_fit)) {
      results[[test_name]] <- list(test = test_name, status = "FAILED_REDUCED_MODEL")
      next
    }
    models[[paste0(test_name, ".reduced")]] <- list(model = reduced_fit,
                                                    engine = full$engine)

    test_out <- lrt(full$model, reduced_fit)
    results[[test_name]] <- list(
      dataset       = dataset_label,
      test          = test_name,
      kind          = "LRT (family main effect, marginality-respecting)",
      chi2          = test_out$chi2,
      df            = test_out$df,
      p_value       = test_out$p_value,
      threshold     = ALPHA_BONF,
      significant   = test_out$p_value < ALPHA_BONF,
      engine        = full$engine,
      re_structure  = full$re_structure,
      AIC_full      = test_out$AIC_full,
      AIC_reduced   = test_out$AIC_reduced,
      warnings      = paste(full$warnings, collapse = " | ")
    )
  }

  ## ---- H2-IDM: framing coefficient (Wald) in IDM model ----
  banner("Test: H2-IDM (framing coefficient Wald)", "-")
  idm_full <- models[["H1-IDM.full"]]  # reuse the IDM model
  if (!is.null(idm_full)) {
    # The framing coefficient name depends on how factor contrasts are set up.
    # With family=anthropic as reference, framing=A as reference, the framing
    # coefficient is "framingB" — the effect of framing B relative to A,
    # *within the reference family (anthropic)* because family:framing is in
    # the model.
    w <- wald_coef(idm_full, "framingB")
    results[["H2-IDM"]] <- list(
      dataset      = dataset_label,
      test         = "H2-IDM",
      kind         = "Wald on coefficient `framingB` (effect within reference family anthropic)",
      coefficient  = "framingB",
      estimate     = w$estimate,
      std_error    = w$std_error,
      z            = w$z,
      p_value      = w$p_value,
      threshold    = ALPHA_BONF,
      significant  = !is.na(w$p_value) && w$p_value < ALPHA_BONF,
      direction_predicted = "positive (B > A)",
      direction_observed  = if (is.na(w$estimate)) NA else
                              ifelse(w$estimate > 0, "positive", "negative"),
      engine       = idm_full$engine,
      re_structure = idm_full$re_structure,
      note         = w$note
    )
  }

  ## ---- H3-IDM: family × framing interaction coefficient (Wald) ----
  banner("Test: H3-IDM (family:framing interaction Wald)", "-")
  if (!is.null(idm_full)) {
    # Two interaction coefficients exist: familyopenai:framingB and
    # familygoogle:framingB. Per prereg "the interaction coefficient" is
    # ambiguous between (a) any one of these, (b) a joint test of both.
    # We report both individual Wald tests AND a joint LRT against the
    # main-effects-only model. The joint LRT is the cleanest match to "the
    # interaction" as a 2-df hypothesis.
    reduced_no_inter <- tryCatch(
      refit_dropping(idm_full, "family:framing"),
      error = function(e) NULL
    )
    if (!is.null(reduced_no_inter)) {
      test_out <- lrt(idm_full$model, reduced_no_inter)
      results[["H3-IDM"]] <- list(
        dataset      = dataset_label,
        test         = "H3-IDM",
        kind         = "LRT (family × framing interaction, 2 df)",
        chi2         = test_out$chi2,
        df           = test_out$df,
        p_value      = test_out$p_value,
        threshold    = ALPHA_BONF,
        significant  = test_out$p_value < ALPHA_BONF,
        engine       = idm_full$engine,
        re_structure = idm_full$re_structure
      )
      # Also report the per-coefficient Wald tests for interpretability.
      for (coef_nm in c("familyopenai:framingB", "familygoogle:framingB")) {
        w <- wald_coef(idm_full, coef_nm)
        results[[paste0("H3-IDM.", coef_nm)]] <- list(
          dataset = dataset_label,
          test    = paste0("H3-IDM detail: ", coef_nm),
          kind    = "Wald on individual interaction coefficient (descriptive)",
          coefficient = coef_nm,
          estimate    = w$estimate,
          std_error   = w$std_error,
          z           = w$z,
          p_value     = w$p_value
        )
      }
    }
  }

  ## ---- H2-AFF: framing coefficient in AFF model (separately corrected) ----
  banner("Test: H2-AFF (framing coefficient, separately corrected)", "-")
  aff_full <- fit_category_model(coded_df, "AFF", FIXED_FULL_CAT)
  if (aff_full$converged) {
    models[["H2-AFF.full"]] <- aff_full
    report_variance_components(aff_full, "H2-AFF")
    w <- wald_coef(aff_full, "framingB")
    results[["H2-AFF"]] <- list(
      dataset      = dataset_label,
      test         = "H2-AFF",
      kind         = "Wald on coefficient `framingB`",
      coefficient  = "framingB",
      estimate     = w$estimate,
      std_error    = w$std_error,
      z            = w$z,
      p_value      = w$p_value,
      threshold    = ALPHA_H2_AFF,
      significant  = !is.na(w$p_value) && w$p_value < ALPHA_H2_AFF,
      direction_predicted = "negative (B < A)",
      direction_observed  = if (is.na(w$estimate)) NA else
                              ifelse(w$estimate > 0, "positive", "negative"),
      engine       = aff_full$engine,
      re_structure = aff_full$re_structure,
      note_correction = "Reported separately from the 4 Bonferroni-corrected primary tests, per prereg §6.2."
    )
  }

  ## ---- H4-compliance: family main effect on per-trial compliance (LRT) ----
  banner("Test: H4-compliance (family main effect on compliance, LRT)", "-")
  # Per-trial binomial outcome.
  # Fixed: family + framing + n_fac. We do NOT include family:framing here
  # since the H4 hypothesis is purely a family main effect on compliance.
  # Random: (1 | model_id). No trial-level RE since the outcome IS at the
  # trial level.
  formula_full_h4 <- compliant ~ family + framing + n_fac + (1 | model_id)
  formula_reduced_h4 <- compliant ~ framing + n_fac + (1 | model_id)

  cat("  Fitting full compliance model...\n")
  h4_full <- tryCatch(
    glmmTMB(formula_full_h4, data = per_call_df, family = binomial()),
    error = function(e) {
      message("glmmTMB failed (", conditionMessage(e), "); trying lme4...")
      glmer(formula_full_h4, data = per_call_df, family = binomial(),
            control = glmerControl(optimizer = "bobyqa"))
    }
  )
  cat("  Fitting reduced compliance model (drop family)...\n")
  h4_reduced <- tryCatch(
    glmmTMB(formula_reduced_h4, data = per_call_df, family = binomial()),
    error = function(e) {
      glmer(formula_reduced_h4, data = per_call_df, family = binomial(),
            control = glmerControl(optimizer = "bobyqa"))
    }
  )

  test_out <- lrt(h4_full, h4_reduced)
  models[["H4-compliance.full"]]    <- list(model = h4_full,
                                            engine = class(h4_full)[1])
  models[["H4-compliance.reduced"]] <- list(model = h4_reduced,
                                            engine = class(h4_reduced)[1])

  # Wrap into helper-expected shape and print variance components.
  # H4 uses class-based engine label; normalize to "glmmTMB"/"lme4".
  h4_engine_label <- if (inherits(h4_full, "glmmTMB")) "glmmTMB" else "lme4"
  report_variance_components(
    list(model = h4_full, engine = h4_engine_label),
    "H4-compliance"
  )

  results[["H4-compliance"]] <- list(
    dataset       = dataset_label,
    test          = "H4-compliance",
    kind          = "LRT (family main effect on per-trial compliance)",
    chi2          = test_out$chi2,
    df            = test_out$df,
    p_value       = test_out$p_value,
    threshold     = ALPHA_BONF,
    significant   = test_out$p_value < ALPHA_BONF,
    AIC_full      = test_out$AIC_full,
    AIC_reduced   = test_out$AIC_reduced,
    engine        = class(h4_full)[1],
    re_structure  = "(1 | model_id)"
  )

  list(results = results, models = models)
}

## --- Run both datasets -----------------------------------------------------

primary_df     <- load_coded(CODED_PRIMARY,     "primary (coded_main.csv)")
sensitivity_df <- load_coded(CODED_SENSITIVITY, "sensitivity (coded_main_sensitivity.csv)")
per_call_df    <- load_per_call()

cat("\nDataset row counts:\n")
cat("  primary coded   :", nrow(primary_df),     "words\n")
cat("  sensitivity     :", nrow(sensitivity_df), "words\n")
cat("  per_call        :", nrow(per_call_df),    "trials\n\n")

# Per-trial outcome doesn't change between primary and sensitivity datasets
# (the sensitivity swap only re-codes which category a word is in, not which
# trials are compliant). H4 results are reported once but populated into both
# dataset blocks for symmetry.

primary_run     <- run_primary_battery(primary_df,     per_call_df, "primary")
sensitivity_run <- run_primary_battery(sensitivity_df, per_call_df, "sensitivity")

## --- Flatten into a single results CSV ------------------------------------

flatten_results <- function(run_list) {
  do.call(rbind, lapply(run_list$results, function(r) {
    # All possible columns across the various test types
    cols <- c("dataset", "test", "kind", "coefficient", "estimate",
              "std_error", "z", "chi2", "df", "p_value",
              "threshold", "significant",
              "direction_predicted", "direction_observed",
              "AIC_full", "AIC_reduced",
              "engine", "re_structure", "warnings", "note")
    row <- as.list(setNames(rep(NA, length(cols)), cols))
    for (nm in intersect(names(r), cols)) row[[nm]] <- r[[nm]]
    as.data.frame(row, stringsAsFactors = FALSE)
  }))
}

results_primary     <- flatten_results(primary_run)
results_sensitivity <- flatten_results(sensitivity_run)
results_all         <- rbind(results_primary, results_sensitivity)

out_csv <- file.path(NB_OUT, "primary_results.csv")
write_csv(results_all, out_csv)
cat("\nResults CSV -> ", out_csv, "\n", sep = "")

## --- Save model objects ----------------------------------------------------

models_all <- list(primary = primary_run$models, sensitivity = sensitivity_run$models)
out_rds <- file.path(NB_OUT, "primary_models.rds")
saveRDS(models_all, out_rds)
cat("Model objects -> ", out_rds, "\n", sep = "")

## --- Reproducibility -------------------------------------------------------

write_session_info("primary_session.txt")

## --- Compact terminal summary ---------------------------------------------

banner("Compact summary")
summary_table <- results_all[, c("dataset", "test", "p_value",
                                 "threshold", "significant")]
print(summary_table, row.names = FALSE)

cat("\nNote: significance shown with Bonferroni-corrected α = .01 for the four ",
    "primary-Bonferroni tests (H1-PRO, H1-IDM, H2-IDM, H3-IDM, H4-compliance), ",
    "α = .05 for H2-AFF (separately reported per prereg §6.2).\n", sep = "")
