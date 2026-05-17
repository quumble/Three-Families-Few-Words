## 04_sonnet_sensitivity.R — §8 Sonnet-as-judge sensitivity analysis
##
## Prereg §8 commits to: "we will also report what happens if we drop Sonnet-
## coded words for cells where Sonnet is the subject." This script discharges
## that commitment by re-running the five category tests (H1-PRO, H1-IDM,
## H2-IDM, H3-IDM, H2-AFF) on the primary and sensitivity datasets after
## dropping every row where model_id == "claude-sonnet-4-6" (the cells where
## Sonnet judges itself).
##
## Reads:    data/coded_main.csv, data/coded_main_sensitivity.csv
## Writes:   output/sonnet_sensitivity_results.csv
##           output/sonnet_sensitivity_models.rds
##           output/sonnet_sensitivity_session.txt
##
## The H4 compliance test is independent of word-level coding (it uses
## per-trial parse_status), so it is not re-run here.
##
## This script does NOT modify 01_primary.R or its outputs. It sources only
## the function definitions from 01_primary.R (everything above the "Run both
## datasets" section) so the original analysis script's outputs are untouched.
##
## Usage:
##   cd study1_analysis/notebooks
##   Rscript 04_sonnet_sensitivity.R

source("_setup.R")

## --- Source only the function-definition portion of 01_primary.R ---------
## We want run_primary_battery() and friends, but not the execution at the
## bottom that overwrites primary_results.csv. Line 485 is the last line of
## function definitions; line 486 begins "## --- Run both datasets ---".

primary_script <- file.path(HERE, "01_primary.R")
primary_lines  <- readLines(primary_script)

# Find the first executable line. The function-definition block runs from
# line 1 up to the line just before this one. Using the first real executable
# statement as the anchor is more robust than matching comment headers, since
# comment formatting is more likely to drift than the executable code.
exec_start <- grep("^primary_df\\s*<-\\s*load_coded", primary_lines)
if (length(exec_start) != 1) {
  stop("Could not locate the first executable line ",
       "(`primary_df <- load_coded(...)`) in 01_primary.R. ",
       "If that script has been restructured, update this loader.")
}

defs_only <- primary_lines[seq_len(exec_start - 1L)]
eval(parse(text = paste(defs_only, collapse = "\n")), envir = globalenv())
cat("Sourced function definitions from 01_primary.R (lines 1 to ",
    exec_start - 1L, ")\n", sep = "")

# `flatten_results` happens to be defined further down in 01_primary.R, mixed
# with execution code, so it does not come along with the slice above. Define
# it locally — kept byte-identical to the version in 01_primary.R so any
# future change to that script's row schema can be mirrored here verbatim.
flatten_results <- function(run_list) {
  do.call(rbind, lapply(run_list$results, function(r) {
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

## --- Load the data and apply the §8 filter -------------------------------

banner("§8 Sonnet-as-judge sensitivity")

primary_df     <- load_coded(CODED_PRIMARY,     "primary (coded_main.csv)")
sensitivity_df <- load_coded(CODED_SENSITIVITY, "sensitivity (coded_main_sensitivity.csv)")
per_call_df    <- load_per_call()   # only needed because run_primary_battery requires it

SONNET_ID <- "claude-sonnet-4-6"

drop_sonnet <- function(df, label) {
  before <- nrow(df)
  out    <- df[df$model_id_sent != SONNET_ID, , drop = FALSE]
  dropped <- before - nrow(out)
  cat(sprintf("  %s: %d -> %d rows (dropped %d Sonnet-as-subject rows; %.1f%%)\n",
              label, before, nrow(out), dropped, 100 * dropped / before))
  out
}

cat("\nApplying §8 filter (drop rows where model_id == \"", SONNET_ID, "\"):\n",
    sep = "")
primary_filt     <- drop_sonnet(primary_df,     "primary")
sensitivity_filt <- drop_sonnet(sensitivity_df, "sensitivity")

# Sanity: confirm the eight remaining subject models are intact in each.
remaining_models <- sort(unique(as.character(primary_filt$model_id_sent)))
cat("\nRemaining subject models (", length(remaining_models), "): ",
    paste(remaining_models, collapse = ", "), "\n", sep = "")
stopifnot(length(remaining_models) == 8L)
stopifnot(!(SONNET_ID %in% remaining_models))

## --- Run the category battery on each filtered dataset -------------------
## run_primary_battery() also runs H4. The H4 test uses per_call_df which is
## not affected by the Sonnet filter, so H4 results will be identical to those
## in primary_results.csv. We drop the H4 rows from this output to avoid the
## suggestion that H4 was re-run for the sensitivity.

primary_filt_run     <- run_primary_battery(primary_filt,     per_call_df,
                                            "sonnet_dropped_primary")
sensitivity_filt_run <- run_primary_battery(sensitivity_filt, per_call_df,
                                            "sonnet_dropped_sensitivity")

## --- Flatten, strip H4 rows, write CSV -----------------------------------

results_pri  <- flatten_results(primary_filt_run)
results_sens <- flatten_results(sensitivity_filt_run)
results_all  <- rbind(results_pri, results_sens)

# Strip H4-compliance rows (see note above).
results_all <- results_all[!grepl("^H4", results_all$test), , drop = FALSE]

out_csv <- file.path(NB_OUT, "sonnet_sensitivity_results.csv")
write_csv(results_all, out_csv)
cat("\nSensitivity results CSV -> ", out_csv, "\n", sep = "")

## --- Save model objects --------------------------------------------------

# Drop H4 from saved models too — identical to primary_models.rds entries.
strip_h4 <- function(m) m[!grepl("^H4", names(m))]
models_all <- list(
  sonnet_dropped_primary     = strip_h4(primary_filt_run$models),
  sonnet_dropped_sensitivity = strip_h4(sensitivity_filt_run$models)
)
out_rds <- file.path(NB_OUT, "sonnet_sensitivity_models.rds")
saveRDS(models_all, out_rds)
cat("Sensitivity models -> ", out_rds, "\n", sep = "")

## --- Reproducibility -----------------------------------------------------

write_session_info("sonnet_sensitivity_session.txt")

## --- Compact terminal summary --------------------------------------------

banner("Compact summary — Sonnet-as-judge sensitivity")
summary_table <- results_all[, c("dataset", "test", "p_value",
                                 "threshold", "significant")]
print(summary_table, row.names = FALSE)

cat("\nCompare against primary_results.csv. Same five category tests, same\n")
cat("thresholds. Any flip in `significant` or any direction reversal needs\n")
cat("to be discussed in the writeup.\n")
