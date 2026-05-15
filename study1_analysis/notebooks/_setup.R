## _setup.R — package loading and environment dump
##
## Sourced at the top of every analysis script so the environment is
## consistent and the loaded versions are recorded.

# Required packages. If any are missing, install with:
#   install.packages(c("readr", "dplyr", "tidyr", "glmmTMB", "lme4", "broom.mixed"))
suppressPackageStartupMessages({
  library(readr)        # fast CSV
  library(dplyr)        # data manipulation
  library(tidyr)        # pivot, fill
  library(glmmTMB)      # primary mixed-effects engine (more stable than lme4 for sparse outcomes)
  library(lme4)         # fallback engine + likelihood-ratio testing utilities
  library(broom.mixed)  # tidy() for mixed-effects model output
})

## --- Path constants --------------------------------------------------------

HERE          <- normalizePath(getwd())
REPO_ROOT     <- normalizePath(file.path(HERE, "..", ".."))
DATA_DIR      <- file.path(REPO_ROOT, "study1_analysis", "data")
NB_OUT        <- file.path(REPO_ROOT, "study1_analysis", "notebooks", "output")

dir.create(NB_OUT, showWarnings = FALSE, recursive = TRUE)

CODED_PRIMARY     <- file.path(DATA_DIR, "coded_main.csv")
CODED_SENSITIVITY <- file.path(DATA_DIR, "coded_main_sensitivity.csv")
PER_CALL_MAIN     <- file.path(DATA_DIR, "per_call_main.csv")

## --- Factor levels used everywhere ----------------------------------------

CATEGORIES <- c("PRO", "EPI", "CAP", "AFF", "IDM", "HDG", "OTH")
FAMILIES   <- c("anthropic", "openai", "google")
FRAMINGS   <- c("A", "B")
NS         <- c(1L, 3L, 5L, 10L)

## --- Loader functions ------------------------------------------------------

#' Read a coded per-word CSV and return a clean data frame with factors
#' in the right reference levels and N as an ordered factor with linear and
#' quadratic contrasts (per prereg §6.2).
load_coded <- function(path, label) {
  df <- read_csv(path, show_col_types = FALSE)
  required <- c("call_id", "family", "tier", "model_id_sent",
                "framing", "n", "trial_index", "code")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop("Missing columns in ", path, ": ", paste(missing, collapse = ", "))
  }

  df <- df %>%
    mutate(
      family    = factor(family,    levels = FAMILIES),
      framing   = factor(framing,   levels = FRAMINGS),
      tier      = factor(tier),
      model_id  = factor(model_id_sent),
      # n as ordered factor so contr.poly gives orthogonal linear+quadratic
      n_fac     = factor(n, levels = NS, ordered = TRUE),
      # trial_id: unique trial identifier, used as random-effect grouping
      trial_id  = factor(call_id),
      code      = factor(code, levels = CATEGORIES)
    )
  attr(df, "label") <- label
  df
}

#' Read per_call_main.csv for the H4 compliance analysis. Outcome: 1 if the
#' call's parse_status is "clean" or "wrapped", else 0.
load_per_call <- function(path = PER_CALL_MAIN) {
  df <- read_csv(path, show_col_types = FALSE)
  df %>%
    mutate(
      family     = factor(family,    levels = FAMILIES),
      framing    = factor(framing,   levels = FRAMINGS),
      tier       = factor(tier),
      model_id   = factor(model_id_sent),
      n_fac      = factor(n, levels = NS, ordered = TRUE),
      trial_id   = factor(call_id),
      compliant  = as.integer(parse_status %in% c("clean", "wrapped"))
    )
}

## --- Pretty printing helpers ----------------------------------------------

#' Print a banner so output is scannable when running the script in a terminal.
banner <- function(text, char = "=") {
  bar <- strrep(char, max(nchar(text) + 4, 60))
  cat("\n", bar, "\n", char, " ", text, "\n", bar, "\n", sep = "")
}

## --- Reproducibility dump --------------------------------------------------

#' Write sessionInfo() to a file in NB_OUT so each script run records which
#' package versions were loaded.
write_session_info <- function(filename) {
  out <- file.path(NB_OUT, filename)
  con <- file(out, open = "wt")
  on.exit(close(con))
  writeLines(c(
    paste0("# Session info — written by ", scriptName(), " at ", Sys.time()),
    "",
    capture.output(sessionInfo())
  ), con)
  cat("Session info -> ", out, "\n", sep = "")
}

# Best-effort script-name retrieval — handles both Rscript and source()
scriptName <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  hit  <- grep("--file=", args, value = TRUE)
  if (length(hit) > 0) return(sub("--file=", "", hit[1]))
  "interactive"
}
