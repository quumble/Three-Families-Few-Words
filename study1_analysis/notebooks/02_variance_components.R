## 02_variance_components.R — extract variance components from the saved
## primary-analysis model objects.
##
## Reads notebooks/output/primary_models.rds (produced by 01_primary.R) and
## writes notebooks/output/variance_components.txt with the variance for each
## random-effects term in each fitted model. Singular components (variance ≈ 0)
## are flagged.
##
## This script does no fitting and runs in seconds. It exists so the methods
## section of the writeup has a citable artifact for variance-component claims
## (e.g. "the trial-level random intercept estimated to zero for H1-PRO and
## H2-AFF in both datasets") rather than relying on terminal output from the
## original 01_primary.R run that wasn't captured.
##
## Usage:
##   cd study1_analysis/notebooks
##   Rscript 02_variance_components.R

source("_setup.R")

banner("Variance components from primary_models.rds")

models_rds <- file.path(NB_OUT, "primary_models.rds")
if (!file.exists(models_rds)) {
  stop("Cannot find ", models_rds,
       ". Run 01_primary.R first to produce it.")
}

models_all <- readRDS(models_rds)
cat("Loaded ", models_rds, "\n", sep = "")
cat("Datasets in file: ", paste(names(models_all), collapse = ", "), "\n\n", sep = "")

## --- Extractor ------------------------------------------------------------
## Mirrors the singular-flag rule used by report_variance_components() in
## 01_primary.R so the output is comparable to what that script printed.

SINGULAR_TOL <- 1e-8

extract_vc <- function(wrapper) {
  # wrapper is the list stored in models_all[[dataset]][[name]];
  # the fitted model lives in wrapper$model and the engine in wrapper$engine.
  if (is.null(wrapper) || is.null(wrapper$model)) {
    return(data.frame(group = character(), variance = numeric()))
  }
  if (identical(wrapper$engine, "glmmTMB")) {
    vc <- summary(wrapper$model)$varcor$cond
    data.frame(
      group    = names(vc),
      variance = vapply(vc, function(x) attr(x, "stddev")^2, numeric(1)),
      row.names = NULL
    )
  } else {
    # lme4 fallback path
    vc <- as.data.frame(lme4::VarCorr(wrapper$model))
    data.frame(group = vc$grp, variance = vc$vcov, row.names = NULL)
  }
}

## --- Walk and emit --------------------------------------------------------

out_txt <- file.path(NB_OUT, "variance_components.txt")
con     <- file(out_txt, open = "wt")
on.exit(close(con), add = TRUE)

writeLines(c(
  paste0("# Variance components — extracted from primary_models.rds at ", Sys.time()),
  "#",
  "# Source: study1_analysis/notebooks/output/primary_models.rds",
  "# Produced by:   study1_analysis/notebooks/02_variance_components.R",
  paste0("# Singular flag threshold: variance < ", SINGULAR_TOL),
  ""
), con)

n_singular_total <- 0L

for (dataset in names(models_all)) {
  writeLines(c(strrep("=", 70),
               paste0("Dataset: ", dataset),
               strrep("=", 70), ""), con)

  for (test_name in names(models_all[[dataset]])) {
    wrapper <- models_all[[dataset]][[test_name]]
    engine  <- if (!is.null(wrapper$engine)) wrapper$engine else "unknown"
    vc      <- extract_vc(wrapper)

    writeLines(sprintf("--- %s   (engine = %s) ---", test_name, engine), con)

    if (nrow(vc) == 0) {
      writeLines("    (no variance components extractable)", con)
    } else {
      for (i in seq_len(nrow(vc))) {
        singular <- vc$variance[i] < SINGULAR_TOL
        if (singular) n_singular_total <- n_singular_total + 1L
        flag <- if (singular) "    <-- SINGULAR (≈ 0)" else ""
        writeLines(
          sprintf("    %-25s variance = %.6f%s",
                  vc$group[i], vc$variance[i], flag),
          con
        )
      }
    }
    writeLines("", con)
  }
}

writeLines(c(strrep("-", 70),
             sprintf("Total variance components at zero (variance < %g): %d",
                     SINGULAR_TOL, n_singular_total),
             strrep("-", 70)), con)

cat("Variance components -> ", out_txt, "\n", sep = "")
cat("Total singular components found: ", n_singular_total, "\n", sep = "")
