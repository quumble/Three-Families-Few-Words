## 03_h1_pro_diagnostic.R — fixed-effects sanity check for H1-PRO primary
##
## H1-PRO on the primary dataset is the one category fit where both random-
## effects variance components estimated to functionally zero (model_id ≈ 3e-8,
## trial_id ≈ 2e-10; see variance_components.txt). This script writes the
## full glmmTMB summary to output/ so the methods section can cite a frozen
## artifact confirming the fixed-effect estimates and SEs are well-behaved
## despite the singular RE.

source("_setup.R")

m   <- readRDS(file.path(NB_OUT, "primary_models.rds"))
out <- file.path(NB_OUT, "h1_pro_primary_diagnostic.txt")

con <- file(out, open = "wt")
sink(con)
cat("# H1-PRO full model on primary dataset — fixed-effects diagnostic\n")
cat("# Written at ", format(Sys.time()), "\n\n", sep = "")
print(summary(m$primary[["H1-PRO.full"]]$model))
sink()
close(con)

cat("Wrote ", out, "\n", sep = "")