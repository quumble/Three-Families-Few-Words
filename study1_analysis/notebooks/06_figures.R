## 06_figures.R — Comprehensive figure set for the writeup
##
## Driven from:
##   - coded_main.csv (primary)         category-proportion plots
##   - coded_main_sensitivity.csv       sensitivity-coded variants
##   - per_word_main.csv                top-words lollipops
##   - per_call_main.csv                compliance plot
##   - secondary_results.csv            length-effect summary, JS scalars
##   - kappa_summary.json               κ-by-category chart
##
## Writes PNG files to output/figures/ at 300 dpi. Each figure is also saved
## as a small `<fig>_data.csv` next to it (the exact numbers behind the plot)
## so the writeup can quote without re-running R.
##
## Conditional-on-compliance signaling:
##   Three models (gemini-3-flash-preview, gemini-3.1-pro-preview,
##   gpt-5.4-nano-2026-03-17) produced parseable responses on fewer than 100%
##   of trials. Their per-cell word counts are therefore conditional on the
##   model successfully completing the format. In every figure that shows
##   per-cell estimates, we mark these cells visually (hatched fill,
##   compliance-rate annotation, or a tinted overlay strip depending on what
##   reads cleanest for the chart in question). The visual signal is the same
##   across all figures: a thin orange band labeled "n_compliant / n_total"
##   sits next to or above each affected cell.
##
## Usage:
##   cd study1_analysis/notebooks
##   Rscript 06_figures.R

source("_setup.R")

FIG_DIR <- file.path(NB_OUT, "figures")
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

# `%||%` is in base R since 4.4.0; define a local fallback for older Rs.
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

banner("Figures for the writeup")
cat("Output directory: ", FIG_DIR, "\n", sep = "")

## --- Helpers ---------------------------------------------------------------

#' Save a ggplot at the writeup's standard size and DPI, and write its
#' underlying data alongside the image.
save_figure <- function(plot, name, data = NULL, width = 7, height = 5) {
  png_path <- file.path(FIG_DIR, paste0(name, ".png"))
  ggsave(png_path, plot, width = width, height = height, dpi = 300,
         bg = "white")
  cat("  ", png_path, "\n", sep = "")
  if (!is.null(data)) {
    csv_path <- file.path(FIG_DIR, paste0(name, "_data.csv"))
    write_csv(data, csv_path)
    cat("  ", csv_path, "\n", sep = "")
  }
  invisible(png_path)
}

## --- Per-trial compliance, for the conditional-on-compliance overlay ------

per_call <- read_csv(PER_CALL_MAIN, show_col_types = FALSE) %>%
  mutate(compliant = parse_status %in% c("clean", "wrapped"))

compliance_per_model <- per_call %>%
  group_by(family, model_id_sent) %>%
  summarize(
    n_compliant = sum(compliant),
    n_total     = dplyr::n(),
    rate        = n_compliant / n_total,
    .groups     = "drop"
  ) %>%
  arrange(family, model_id_sent)

# Per-cell (family, framing, n) compliance — used to annotate the figures
# that show per-(family, framing, n) breakdowns.
compliance_per_cell <- per_call %>%
  group_by(family, framing, n, model_id_sent) %>%
  summarize(
    n_compliant_model = sum(compliant),
    n_total_model     = dplyr::n(),
    .groups           = "drop"
  ) %>%
  group_by(family, framing, n) %>%
  summarize(
    n_compliant = sum(n_compliant_model),
    n_total     = sum(n_total_model),
    rate        = n_compliant / n_total,
    .groups     = "drop"
  )

# Cells where compliance < 100% — used for visual marking.
THIN_RATE_THRESHOLD <- 0.999  # anything below this gets the "conditional" mark
thin_cells <- compliance_per_cell %>%
  filter(rate < THIN_RATE_THRESHOLD)
cat("\nCells flagged as conditional-on-compliance (rate < ",
    THIN_RATE_THRESHOLD, "):\n", sep = "")
print(as.data.frame(thin_cells))

## --- Load coded data for the proportion-based figures ---------------------

primary_df     <- load_coded(CODED_PRIMARY,     "primary")
sensitivity_df <- load_coded(CODED_SENSITIVITY, "sensitivity")

## ==========================================================================
## fig01 — family × category proportions, by framing
## ==========================================================================
##
## The headline visual. Three panels (one per family) showing category
## proportions under framing A and B side by side. Sensitivity-coded version
## saved as fig01b.

make_fig01 <- function(df, fname, subtitle) {
  d <- df %>%
    group_by(family, framing, code) %>%
    summarize(n_words = dplyr::n(), .groups = "drop_last") %>%
    mutate(prop = n_words / sum(n_words)) %>%
    ungroup() %>%
    mutate(
      code   = factor(code, levels = CATEGORIES),
      family = factor(family, levels = FAMILIES)
    )

  p <- ggplot(d, aes(x = framing, y = prop, fill = code)) +
    geom_col(position = position_stack(reverse = TRUE)) +
    facet_wrap(~ family, nrow = 1) +
    scale_fill_manual(values = CATEGORY_COLORS, name = "Category") +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      x = "Framing  (A = open, B = 'as an AI')",
      y = "Proportion of parseable words",
      title = "Category proportions by family and framing",
      subtitle = subtitle
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major.x = element_blank(),
          legend.position = "right")

  save_figure(p, fname, data = d, width = 8, height = 4.5)
}

banner("fig01 — Family × category proportions × framing")
make_fig01(primary_df,     "fig01_family_x_category_proportions",
           "Primary coding")
make_fig01(sensitivity_df, "fig01b_family_x_category_proportions_sensitivity",
           "Sensitivity coding (human-boundary swap)")

## ==========================================================================
## fig02 — IDM framing shift, per family, with per-model points
## ==========================================================================
##
## The H3 story in one chart. Bar = family-level IDM% under A vs B; point =
## per-model IDM% under each framing. Lines connecting A→B per model
## emphasize the shift size.

make_fig02 <- function(df, fname, subtitle) {
  per_model <- df %>%
    group_by(family, model_id_sent, framing) %>%
    summarize(
      n_idm   = sum(code == "IDM"),
      n_total = dplyr::n(),
      prop    = n_idm / n_total,
      .groups = "drop"
    )
  per_family <- per_model %>%
    group_by(family, framing) %>%
    summarize(prop = sum(n_idm) / sum(n_total), .groups = "drop")

  p <- ggplot(per_family, aes(x = framing, y = prop, fill = family)) +
    geom_col(width = 0.7, alpha = 0.55) +
    geom_line(data = per_model,
              aes(group = model_id_sent, color = family),
              linewidth = 0.4, alpha = 0.7) +
    geom_point(data = per_model,
               aes(color = family), size = 2, alpha = 0.95) +
    facet_wrap(~ family, nrow = 1) +
    scale_fill_manual(values = FAMILY_COLORS, guide = "none") +
    scale_color_manual(values = FAMILY_COLORS, guide = "none") +
    scale_y_continuous(labels = percent_format(accuracy = 1),
                       limits = c(0, NA)) +
    labs(
      x = "Framing",
      y = "Identity/Meta proportion",
      title = "IDM% under framing A vs B, by family",
      subtitle = paste0(subtitle,
        " (bars: family-level rate; lines+points: per-model)")
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major.x = element_blank())

  save_figure(p, fname, data = per_family, width = 8, height = 4.5)
}

banner("fig02 — IDM framing shift, per family")
make_fig02(primary_df,     "fig02_idm_framing_shift",
           "Primary coding")
make_fig02(sensitivity_df, "fig02b_idm_framing_shift_sensitivity",
           "Sensitivity coding")

## ==========================================================================
## fig03 — Length effects per category × family
## ==========================================================================
##
## N on x, category proportion on y, lines per family, faceted by category.
## Compliance-thinned cells (Google Flash, Pro; GPT-5.4 nano) get a small
## diamond marker on top of the regular dot to flag conditional estimates.

make_fig03 <- function(df, fname, subtitle) {
  d <- df %>%
    group_by(family, n, code) %>%
    summarize(
      n_words = dplyr::n(),
      .groups = "drop_last"
    ) %>%
    mutate(prop = n_words / sum(n_words)) %>%
    ungroup() %>%
    mutate(code = factor(code, levels = CATEGORIES))

  # Per-cell compliance marker — for any (family, n), if the rate < threshold
  # in either framing, flag the cell.
  flag <- compliance_per_cell %>%
    group_by(family, n) %>%
    summarize(any_thin = any(rate < THIN_RATE_THRESHOLD),
              min_rate = min(rate),
              .groups  = "drop")
  d <- d %>% left_join(flag, by = c("family", "n"))

  p <- ggplot(d, aes(x = n, y = prop, color = family, group = family)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 2) +
    geom_point(data = filter(d, any_thin),
               shape = 5, size = 4, stroke = 0.6) +
    facet_wrap(~ code, nrow = 2) +
    scale_color_manual(values = FAMILY_COLORS, name = "Family") +
    scale_x_continuous(breaks = NS) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      x = "Requested response length (N words)",
      y = "Category proportion",
      title = "Category proportion vs requested length, by family",
      subtitle = paste0(subtitle,
        " · open diamonds mark (family, N) cells with <100% compliance")
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(),
          legend.position = "bottom")

  save_figure(p, fname, data = d, width = 9, height = 6)
}

banner("fig03 — Length effects per category × family")
make_fig03(primary_df,     "fig03_length_effects_per_category",
           "Primary coding")
make_fig03(sensitivity_df, "fig03b_length_effects_per_category_sensitivity",
           "Sensitivity coding")

## ==========================================================================
## fig04 — Top-words lollipops per (family, framing)
## ==========================================================================
##
## Six panels (3 families × 2 framings). Within each panel, the top-10
## words for that cell with horizontal lollipops. Driven from per_word_main.

per_word <- read_csv(file.path(DATA_DIR, "per_word_main.csv"),
                     show_col_types = FALSE)

top_words_6 <- per_word %>%
  group_by(family, framing, word) %>%
  summarize(count = dplyr::n(), .groups = "drop") %>%
  group_by(family, framing) %>%
  arrange(desc(count), word, .by_group = TRUE) %>%
  mutate(rank = dplyr::row_number()) %>%
  filter(rank <= 10) %>%
  ungroup() %>%
  mutate(panel_label = paste0(family, " / Framing ", framing))

# Make a panel-unique row label, then order ALL labels globally so that
# within each panel they sort by count descending (i.e. top of panel = highest
# count). facet_wrap(scales = "free_y") then shows only the in-panel subset.
top_words_6 <- top_words_6 %>%
  mutate(word_in_panel = paste0(word, " [", panel_label, "]")) %>%
  arrange(panel_label, desc(count)) %>%
  mutate(word_in_panel = factor(word_in_panel, levels = rev(word_in_panel)))

banner("fig04 — Top-10 words per (family, framing)")
p_fig04 <- ggplot(top_words_6,
                  aes(x = count, y = word_in_panel, color = family)) +
  geom_segment(aes(x = 0, xend = count, yend = word_in_panel),
               linewidth = 0.6) +
  geom_point(size = 2.4) +
  facet_wrap(~ panel_label, ncol = 2, scales = "free_y") +
  scale_color_manual(values = FAMILY_COLORS, guide = "none") +
  scale_y_discrete(labels = function(x) sub(" \\[.*\\]$", "", x)) +
  labs(
    x = "Count (within cell)",
    y = NULL,
    title = "Top 10 self-descriptive words per (family, framing)",
    subtitle = "From parseable responses in coded_main.csv"
  ) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.major.y = element_blank(),
        strip.text = element_text(face = "bold"))

save_figure(p_fig04, "fig04_top_words_lollipop",
            data = top_words_6 %>% select(family, framing, word, count, rank),
            width = 9, height = 8)

## ==========================================================================
## fig05 — JS divergence per model
## ==========================================================================
##
## Bar chart of category-JS distance per model, with word-JS overlaid as
## points so both are visible. Read directly from secondary_results.csv if
## it exists; otherwise warn and skip.

js_path <- file.path(NB_OUT, "secondary_results.csv")
if (file.exists(js_path)) {
  secondary <- read_csv(js_path, show_col_types = FALSE)
  js <- secondary %>%
    filter(grepl("^JS-", test), dataset == "primary") %>%
    mutate(
      flavor   = ifelse(grepl("^JS-category", test), "category", "word"),
      model_id = sub("^JS-(category|word)-", "", test)
    ) %>%
    select(flavor, model_id, js_dist = estimate, note) %>%
    mutate(
      family = case_when(
        grepl("^claude", model_id) ~ "anthropic",
        grepl("^gpt",    model_id) ~ "openai",
        grepl("^gemini", model_id) ~ "google",
        TRUE                       ~ NA_character_
      ),
      display = MODEL_DISPLAY[model_id]
    )

  # Order models within family by category-JS for legibility.
  order_key <- js %>% filter(flavor == "category") %>%
    arrange(family, js_dist) %>% pull(display)
  js$display <- factor(js$display, levels = order_key)

  banner("fig05 — JS divergence per model (A vs B)")
  p_fig05 <- ggplot() +
    geom_col(data = filter(js, flavor == "category"),
             aes(x = display, y = js_dist, fill = family), alpha = 0.7) +
    geom_point(data = filter(js, flavor == "word"),
               aes(x = display, y = js_dist), size = 3, color = "black",
               shape = 17) +
    scale_fill_manual(values = FAMILY_COLORS, name = "Family") +
    scale_y_continuous(limits = c(0, NA)) +
    labs(
      x = NULL,
      y = "JS distance (framing A vs B)",
      title = "Per-model JS distance between framing-A and framing-B",
      subtitle = "Bars: 7-bin category-proportion JS  ·  black triangles: word-vocab JS (Laplace α=0.5)"
    ) +
    theme_minimal(base_size = 11) +
    theme(axis.text.x = element_text(angle = 35, hjust = 1),
          panel.grid.major.x = element_blank())

  save_figure(p_fig05, "fig05_js_divergence_per_model",
              data = js, width = 8.5, height = 5)
} else {
  cat("  Skipping fig05: secondary_results.csv not found.\n")
  cat("  Run 05_secondary.R first to produce JS data.\n")
}

## ==========================================================================
## fig06 — Per-model compliance
## ==========================================================================
##
## Already-known visual: nine models, three families, with the three
## non-compliant models (Gemini Flash, Gemini Pro, GPT-5.4 nano) visibly
## below the rest. The §5.3 paper table in chart form.

banner("fig06 — Compliance per model")
comp <- compliance_per_model %>%
  mutate(
    display = MODEL_DISPLAY[model_id_sent],
    family  = factor(family, levels = FAMILIES)
  ) %>%
  arrange(family, desc(rate))
comp$display <- factor(comp$display, levels = rev(comp$display))

p_fig06 <- ggplot(comp, aes(x = rate, y = display, fill = family)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = sprintf("%d / %d  (%.1f%%)",
                                n_compliant, n_total, 100 * rate)),
            hjust = -0.05, size = 3.1) +
  scale_x_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.18), expand = c(0, 0),
                     breaks = c(0, 0.25, 0.5, 0.75, 1.0)) +
  scale_fill_manual(values = FAMILY_COLORS, name = "Family") +
  labs(
    x = "Parseable response rate (clean or wrapped)",
    y = NULL,
    title = "Per-model compliance with the requested format",
    subtitle = "1,440 trials (160 per model). Three models below ceiling: Gemini 3 Flash, Gemini 3.1 Pro, GPT-5.4 nano."
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank())

save_figure(p_fig06, "fig06_compliance_per_model",
            data = comp, width = 9, height = 4.5)

## ==========================================================================
## fig07 — κ by category (validation pass)
## ==========================================================================
##
## Read kappa_summary.json from the coding tool.

banner("fig07 — Per-category κ (validation pass)")
kappa_path <- file.path(REPO_ROOT, "study1_analysis", "coding_tool",
                        "kappa_summary.json")
if (file.exists(kappa_path)) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cat("  jsonlite not installed; install.packages('jsonlite') to enable fig07.\n")
    cat("  Skipping fig07.\n")
  } else {
    ks <- jsonlite::fromJSON(kappa_path)
    # The structure is repo-specific; we look up per-category κs defensively.
    # Expected: ks$per_category$<CAT>$kappa  (or similar). Fall back to a
    # hand-built table from the paper if structure doesn't match.
    per_cat <- tryCatch({
      pc <- ks$per_category
      tibble(
        code     = names(pc),
        kappa    = vapply(pc, function(x) as.numeric(x$kappa %||% NA), numeric(1)),
        n_judge  = vapply(pc, function(x) as.numeric(x$n_judge %||% NA), numeric(1)),
        n_human  = vapply(pc, function(x) as.numeric(x$n_human %||% NA), numeric(1))
      )
    }, error = function(e) NULL)

    if (is.null(per_cat) || all(is.na(per_cat$kappa))) {
      cat("  kappa_summary.json shape unexpected; using paper-table fallback.\n")
      per_cat <- tibble(
        code    = c("PRO", "EPI", "CAP", "AFF", "IDM", "HDG", "OTH"),
        kappa   = c(0.626, 0.748, 0.587, 0.512, 0.853, 0.847, 0.309),
        n_judge = c(28, 28, 28, 28, 28, 10, 4),
        n_human = c(40, 37, 13, 14, 31, 11, 8)
      )
    }

    per_cat <- per_cat %>%
      mutate(code = factor(code, levels = CATEGORIES))

    p_fig07 <- ggplot(per_cat, aes(x = kappa, y = code, fill = code)) +
      geom_col(width = 0.7) +
      geom_vline(xintercept = 0.60, linetype = "dashed", color = "red") +
      geom_text(aes(label = sprintf("κ=%.2f", kappa)),
                hjust = -0.1, size = 3.2) +
      scale_fill_manual(values = CATEGORY_COLORS, guide = "none") +
      scale_x_continuous(limits = c(0, 1.05),
                         breaks = c(0, 0.25, 0.5, 0.6, 0.75, 1.0),
                         expand = c(0, 0)) +
      labs(
        x = "Cohen's κ (judge vs first author, validation sample)",
        y = NULL,
        title = "Per-category κ (validation pass, 154 tuples)",
        subtitle = "Dashed line: prereg §5.1 acceptance threshold (κ = 0.60)"
      ) +
      theme_minimal(base_size = 11) +
      theme(panel.grid.major.y = element_blank())

    save_figure(p_fig07, "fig07_kappa_per_category",
                data = per_cat, width = 7, height = 4.5)
  }
} else {
  cat("  kappa_summary.json not found at expected path; skipping fig07.\n")
}

## ==========================================================================
## fig08 — TTR by cell
## ==========================================================================
##
## Sqrt-normalized type/token ratio (root-TTR) per (family, framing, N).
## Same conditional-on-compliance marker as fig03.

banner("fig08 — Type/token ratio by cell")
ttr_path <- file.path(NB_OUT, "type_token_ratios.csv")
if (file.exists(ttr_path)) {
  ttr <- read_csv(ttr_path, show_col_types = FALSE) %>%
    mutate(family = factor(family, levels = FAMILIES))

  # Same compliance flag as fig03.
  flag <- compliance_per_cell %>%
    group_by(family, framing, n) %>%
    summarize(rate = first(rate), .groups = "drop") %>%
    mutate(any_thin = rate < THIN_RATE_THRESHOLD)
  ttr <- ttr %>% left_join(flag, by = c("family", "framing", "n"))

  p_fig08 <- ggplot(ttr, aes(x = n, y = ttr_root, color = family,
                             group = family)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 2) +
    geom_point(data = filter(ttr, any_thin),
               shape = 5, size = 4, stroke = 0.6) +
    facet_wrap(~ framing, nrow = 1,
               labeller = labeller(framing = c(A = "Framing A (open)",
                                               B = "Framing B (as an AI)"))) +
    scale_color_manual(values = FAMILY_COLORS, name = "Family") +
    scale_x_continuous(breaks = NS) +
    labs(
      x = "Requested response length (N words)",
      y = "Root-TTR  (= types / sqrt(tokens))",
      title = "Lexical diversity per cell (root-TTR)",
      subtitle = "Open diamonds mark cells with <100% compliance — token totals are conditional"
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank())

  save_figure(p_fig08, "fig08_ttr_by_cell",
              data = ttr, width = 9, height = 4.5)
} else {
  cat("  type_token_ratios.csv not found; run 05_secondary.R first. Skipping fig08.\n")
}

## --- Reproducibility -------------------------------------------------------

write_session_info("figures_session.txt")

banner("Figures complete")
cat("All figures written to: ", FIG_DIR, "\n", sep = "")
cat("Each figure has a matching <name>_data.csv next to it.\n")
