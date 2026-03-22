#!/usr/bin/env Rscript
# ===========================================================================
# 03 — Survey-Weighted Analysis (Analysis 1)
#
# Runs TSL-weighted descriptive statistics, Rao-Scott chi-square omnibus
# tests, and logistic regression across four crime scopes: Total, Violent,
# Theft, and Co-offending. Uses Taylor Series Linearization with
# pseudostratum (V2117) and half-sample code (V2118) as design elements.
#
# Input:  data/derived/ncvs-merged-data-1993-2024.csv (+ violent/theft)
# Output: outputs/tables/{total,violent,theft}/*.docx
#
# Supports: Analysis 1 results and supplement Tables S1-S7
# ===========================================================================

library(dplyr)
library(survey)
library(broom)
library(flextable)
library(officer)

# Handle singleton PSUs (strata with only one PSU) — standard BJS approach
options(survey.lonely.psu = "adjust")

# ---------------------------------------------------------------------------
# COMMON FUNCTIONS
# ---------------------------------------------------------------------------

discover_age_levels <- function(df) {
  all_age_vals <- unique(c(
    unique(df$age_solo),
    unique(df$youngest_multiple),
    unique(df$oldest_multiple)
  ))
  all_age_vals <- all_age_vals[!is.na(all_age_vals) & all_age_vals != ""]

  find_age <- function(vals, pattern) {
    matched <- grep(pattern, vals, value = TRUE)
    if (length(matched) >= 1) return(matched[1])
    return(NA_character_)
  }

  age_levels <- c(
    find_age(all_age_vals, "Under|under"),
    find_age(all_age_vals, "^12"),
    find_age(all_age_vals, "^15"),
    find_age(all_age_vals, "^18"),
    find_age(all_age_vals, "^21"),
    find_age(all_age_vals, "^30")
  )
  age_levels <- age_levels[!is.na(age_levels)]
  return(age_levels)
}

prepare_data <- function(csv_path) {
  cat("  Reading:", csv_path, "\n")
  df <- read.csv(csv_path)
  cat("  Rows read:", nrow(df), "\n")

  # Clean weights
  df <- df %>% filter(!is.na(incident_weight), incident_weight > 0)
  cat("  Rows after weight filter:", nrow(df), "\n")

  # Verify TSL design variables
  df <- df %>% filter(!is.na(V2117), V2117 != "", !is.na(V2118), V2118 != "")
  cat("  Rows after V2117/V2118 filter:", nrow(df), "\n")

  # Trim whitespace + convert N/A to NA
  df[] <- lapply(df, function(col) {
    if (is.character(col)) trimws(col) else col
  })
  df[df == "N/A"] <- NA

  # Discover age levels
  age_levels <- discover_age_levels(df)
  cat("  Age levels:", paste(age_levels, collapse = ", "), "\n")

  # Normalize age labels to simple ASCII (matching Rmd logic)
  normalize_age <- function(x) {
    x <- as.character(x)
    x[grepl("Under|under", x)] <- "under_12"
    x[grepl("^12", x)] <- "12-14"
    x[grepl("^15", x)] <- "15-17"
    x[grepl("^18", x)] <- "18-20"
    x[grepl("^21", x)] <- "21-29"
    x[grepl("^30", x)] <- "30+"
    return(x)
  }

  df$age_solo <- normalize_age(df$age_solo)
  df$oldest_multiple <- normalize_age(df$oldest_multiple)
  df$youngest_multiple <- normalize_age(df$youngest_multiple)

  # Fix youngest/oldest consistency
  age_levels_ascii <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")
  only_oldest <- is.na(df$youngest_multiple) & df$oldest_multiple %in% age_levels_ascii
  only_youngest <- is.na(df$oldest_multiple) & df$youngest_multiple %in% age_levels_ascii
  df$youngest_multiple[only_oldest] <- df$oldest_multiple[only_oldest]
  df$oldest_multiple[only_youngest] <- df$youngest_multiple[only_youngest]

  df$year <- as.numeric(as.character(df$year))

  # Ensure TSL variables are properly typed
  df$V2117 <- as.character(df$V2117)
  df$V2118 <- as.character(df$V2118)
  df$YR_GRP <- as.character(df$YR_GRP)

  return(df)
}

expand_age <- function(df) {
  # Expand: solo uses age_solo, group uses youngest/oldest (duplicated if different)
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  df <- df %>%
    mutate(
      solo_flag = !is.na(age_solo) & age_solo %in% age_levels,
      same_group_age = youngest_multiple == oldest_multiple & !is.na(youngest_multiple),
      two_group_ages = youngest_multiple != oldest_multiple & !is.na(youngest_multiple) & !is.na(oldest_multiple)
    )

  solo_df <- df %>% filter(solo_flag) %>% mutate(age = age_solo)
  same_age_df <- df %>% filter(!solo_flag & same_group_age) %>% mutate(age = youngest_multiple)
  diff_age_df <- df %>% filter(!solo_flag & two_group_ages)
  youngest_rows <- diff_age_df %>% mutate(age = youngest_multiple)
  oldest_rows <- diff_age_df %>% mutate(age = oldest_multiple)

  result <- bind_rows(solo_df, same_age_df, youngest_rows, oldest_rows) %>%
    select(-solo_flag, -same_group_age, -two_group_ages)

  cat("  Expanded rows:", nrow(result), "\n")
  return(result)
}

make_survey_design <- function(df) {
  # Taylor Series Linearization design
  # V2117 = pseudostratum, V2118 = half-sample code (PSU)
  # Strata = interaction(YR_GRP, V2117) to handle PSU boundary changes
  # nest = TRUE because PSU codes repeat across strata
  svydesign(
    ids = ~V2118,
    strata = ~interaction(YR_GRP, V2117),
    weights = ~incident_weight,
    data = df,
    nest = TRUE
  )
}

run_weighted_counts <- function(df, output_path) {
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  filtered_df <- df %>%
    filter(!is.na(V2117)) %>%
    filter(age %in% age_levels) %>%
    mutate(is_alone = social_crime == "alone", is_observed = social_crime == "observed")

  # TSL: create design on full filtered dataset, then use subset() for domains
  full_design <- make_survey_design(filtered_df)

  weighted_total_by_age <- function(condition_expr, design) {
    design_sub <- subset(design, eval(condition_expr))
    svytotal(~factor(age, levels = age_levels), design_sub) |> coef() |> as.numeric()
  }

  alone_counts <- weighted_total_by_age(quote(is_alone), full_design)
  observed_counts <- weighted_total_by_age(quote(is_observed), full_design)
  group_counts <- weighted_total_by_age(quote(solo_group_crime == "group"), full_design)

  ncvs_calc_1 <- data.frame(
    age_group = age_levels,
    alone = round(alone_counts),
    group = round(group_counts),
    observed = round(observed_counts)
  )
  ncvs_calc_1$grand_total <- rowSums(ncvs_calc_1[, c("alone", "group", "observed")], na.rm = TRUE)

  total_row <- data.frame(
    age_group = "Total",
    alone = sum(ncvs_calc_1$alone),
    group = sum(ncvs_calc_1$group),
    observed = sum(ncvs_calc_1$observed),
    grand_total = sum(ncvs_calc_1$grand_total)
  )
  ncvs_calc_1 <- rbind(ncvs_calc_1, total_row)

  ft <- flextable(ncvs_calc_1) |> autofit() |> theme_booktabs()
  save_as_docx("Weighted Counts" = ft, path = output_path)

  cat("  Saved counts:", output_path, "\n")

  # Also compute and save percentages
  pct_df <- ncvs_calc_1[ncvs_calc_1$age_group != "Total", ]
  pct_df[, c("alone", "group", "observed")] <- round(
    pct_df[, c("alone", "group", "observed")] / pct_df$grand_total * 100, 1
  )
  pct_df[, c("alone", "group", "observed")] <- apply(
    pct_df[, c("alone", "group", "observed")], c(1, 2), function(x) paste0(x, "%")
  )
  pct_df <- pct_df[, c("age_group", "alone", "group", "observed")]

  pct_path <- sub("calc_1_table", "percentages_table", output_path)
  ft2 <- flextable(pct_df) |> autofit() |> theme_booktabs()
  save_as_docx("Weighted Percentages" = ft2, path = pct_path)
  cat("  Saved percentages:", pct_path, "\n")

  # Print key numbers for extraction
  cat("\n  --- DESCRIPTIVE SUMMARY ---\n")
  print(ncvs_calc_1)
  cat("\n  --- PERCENTAGES ---\n")
  # Recompute without formatting for clean output
  pct_clean <- ncvs_calc_1[ncvs_calc_1$age_group != "Total", ]
  pct_clean[, c("alone", "group", "observed")] <- round(
    pct_clean[, c("alone", "group", "observed")] / pct_clean$grand_total * 100, 1
  )
  print(pct_clean)
  cat("\n")

  return(ncvs_calc_1)
}

run_chi_square <- function(df, output_path) {
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  chi_df <- df %>%
    filter(!is.na(age), age %in% age_levels, social_crime %in% c("alone", "observed", "group")) %>%
    mutate(
      age = factor(age, levels = age_levels),
      is_solo = factor(ifelse(social_crime == "alone", "Solo", "Social"),
                       levels = c("Social", "Solo"))
    )

  # TSL: create design on full filtered dataset
  full_design <- make_survey_design(chi_df)

  # Omnibus
  rs_test <- svychisq(~is_solo + age, design = full_design, statistic = "F")
  omnibus_row <- tibble(
    `Age Group 1` = "ALL", `Age Group 2` = "vs. all",
    `F (Rao-Scott)` = round(rs_test$statistic, 3),
    `df` = paste0(round(rs_test$parameter[1], 2)),
    `p` = formatC(rs_test$p.value, format = "f", digits = 6),
    `p (Bonferroni)` = ""
  )

  cat("\n  --- OMNIBUS ---\n")
  cat("  F =", round(rs_test$statistic, 2), ", df =", round(rs_test$parameter[1], 2),
      ", p =", formatC(rs_test$p.value, format = "e", digits = 3), "\n")

  # Pairwise - TSL: use subset() from the full design for proper variance estimation
  age_pairs <- combn(age_levels, 2, simplify = FALSE)
  pairwise_results <- list()

  for (pair in age_pairs) {
    sub <- subset(full_design, age %in% pair)
    sub <- update(sub, age = droplevels(age))
    sub <- update(sub, is_solo = factor(is_solo, levels = c("Social", "Solo")))

    result <- tryCatch({
      stat <- svychisq(~is_solo + age, sub, statistic = "F")
      tibble(
        `Age Group 1` = pair[1], `Age Group 2` = pair[2],
        `F (Rao-Scott)` = round(stat$statistic, 3),
        `df` = paste0(round(stat$parameter[1], 2)),
        `p_raw` = stat$p.value
      )
    }, error = function(e) {
      tibble(
        `Age Group 1` = pair[1], `Age Group 2` = pair[2],
        `F (Rao-Scott)` = NA, `df` = "1", `p_raw` = NA_real_
      )
    })
    pairwise_results[[length(pairwise_results) + 1]] <- result
  }

  pw <- bind_rows(pairwise_results) %>%
    mutate(
      `p` = formatC(p_raw, format = "f", digits = 6),
      `p (Bonferroni)` = formatC(pmin(p_raw * n(), 1), format = "f", digits = 6)
    ) %>%
    arrange(desc(`F (Rao-Scott)`)) %>%
    select(-p_raw)

  cat("\n  --- PAIRWISE (sorted by F) ---\n")
  print(as.data.frame(pw), row.names = FALSE)

  final_table <- bind_rows(omnibus_row, pw)
  ft <- flextable(final_table) |> autofit() |> theme_booktabs()
  save_as_docx("Chi-Square Tests" = ft, path = output_path)
  cat("\n  Saved:", output_path, "\n")
}

run_logistic_regression <- function(df, ref_level, output_path) {
  age_levels_ordered <- if (ref_level == "15-17") {
    c("15-17", "under_12", "12-14", "18-20", "21-29", "30+")
  } else if (ref_level == "18-20") {
    c("18-20", "under_12", "12-14", "15-17", "21-29", "30+")
  } else {
    c(ref_level, setdiff(c("under_12", "12-14", "15-17", "18-20", "21-29", "30+"), ref_level))
  }

  full_df <- df %>%
    filter(age %in% age_levels_ordered, social_crime %in% c("alone", "observed", "group")) %>%
    filter(!is.na(incident_weight), incident_weight > 0, !is.na(V2117)) %>%
    mutate(
      age_group = factor(age, levels = age_levels_ordered),
      is_alone = social_crime == "alone"
    )

  # TSL: create design on full filtered dataset
  full_design <- make_survey_design(full_df)
  model <- svyglm(is_alone ~ age_group, design = full_design, family = binomial())

  model_output <- tidy(model, conf.int = TRUE, exponentiate = TRUE) %>%
    mutate(across(where(is.numeric), ~ round(., 4))) %>%
    rename(
      `Age Group` = term,
      `Odds Ratio` = estimate,
      `Std. Error` = std.error,
      `z` = statistic,
      `p` = p.value,
      `CI Lower` = conf.low,
      `CI Upper` = conf.high
    )

  cat("\n  --- LOGISTIC REGRESSION (ref =", ref_level, ") ---\n")
  print(as.data.frame(model_output), row.names = FALSE)

  ft <- flextable(model_output) |> autofit() |> theme_booktabs()
  save_as_docx("Logistic Regression" = ft, path = output_path)
  cat("  Saved:", output_path, "\n")
}

# ---------------------------------------------------------------------------
# CO-OFFENDING ONLY ANALYSIS
# ---------------------------------------------------------------------------

run_cooffending_analysis <- function(df, output_dir) {
  cat("\n  --- CO-OFFENDING ONLY ANALYSIS ---\n")

  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  # Binary: group vs solo (co-offending only, excludes observed)
  cooff_df <- df %>%
    filter(!is.na(age), age %in% age_levels,
           solo_group_crime %in% c("solo", "group")) %>%
    filter(!is.na(incident_weight), incident_weight > 0, !is.na(V2117)) %>%
    mutate(
      age = factor(age, levels = age_levels),
      cooff_status = factor(solo_group_crime, levels = c("group", "solo")),
      is_non_group = ifelse(solo_group_crime == "solo", 1, 0)
    )

  # TSL: create design on full co-offending dataset
  full_design <- make_survey_design(cooff_df)

  # Descriptive counts
  cat("\n  Co-offending weighted counts:\n")
  group_counts <- svytotal(~interaction(age, cooff_status), full_design) |> coef()
  for (a in age_levels) {
    g <- group_counts[paste0("interaction(age, cooff_status).", a, ".group")]
    s <- group_counts[paste0("interaction(age, cooff_status).", a, ".solo")]
    total <- g + s
    pct_group <- round(g / total * 100, 1)
    cat("    ", a, ": group =", round(g), "(", pct_group, "%), solo =", round(s), "\n")
  }

  # Omnibus chi-square
  rs_test <- svychisq(~cooff_status + age, design = full_design, statistic = "F")
  cat("\n  Omnibus: F =", round(rs_test$statistic, 2),
      ", df =", round(rs_test$parameter[1], 2),
      ", p =", formatC(rs_test$p.value, format = "e", digits = 3), "\n")

  # Pairwise - TSL: use subset() from full design
  age_pairs <- combn(age_levels, 2, simplify = FALSE)
  cat("\n  Pairwise comparisons:\n")
  pw_results <- list()
  for (pair in age_pairs) {
    sub <- subset(full_design, age %in% pair)
    sub <- update(sub, age = droplevels(age))
    tryCatch({
      stat <- svychisq(~cooff_status + age, sub, statistic = "F")
      bonf_p <- min(stat$p.value * length(age_pairs), 1)
      cat("    ", pair[1], "vs", pair[2], ": F =", round(stat$statistic, 2),
          ", p =", formatC(stat$p.value, format = "f", digits = 6),
          ", p(Bonf) =", formatC(bonf_p, format = "f", digits = 6), "\n")
    }, error = function(e) {
      cat("    ", pair[1], "vs", pair[2], ": ERROR -", e$message, "\n")
    })
  }

  # Logistic regressions (3 reference levels)
  for (ref in c("15-17", "18-20", "30+")) {
    lvls <- c(ref, setdiff(age_levels, ref))
    lr_df <- cooff_df %>% mutate(age = factor(age, levels = lvls))
    lr_design <- make_survey_design(lr_df)

    model <- svyglm(is_non_group ~ age, design = lr_design, family = binomial())
    model_output <- tidy(model, conf.int = TRUE, exponentiate = TRUE) %>%
      mutate(across(where(is.numeric), ~ round(., 4)))

    cat("\n  Logistic Regression (co-offending, ref =", ref, "):\n")
    print(as.data.frame(model_output), row.names = FALSE)

    ft <- flextable(model_output) |> autofit() |> theme_booktabs()
    ref_clean <- gsub("\\+", "plus", ref)
    save_as_docx("Logistic Regression" = ft,
                 path = file.path(output_dir, paste0("backup_logit_ref_", ref_clean, ".docx")))
  }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

cat("================================================================\n")
cat("NCVS Weighted Analysis Pipeline - 1993-2024 (TSL)\n")
cat("Variance estimation: Taylor Series Linearization\n")
cat("Design: V2117 (pseudostratum) x V2118 (half-sample code)\n")
cat("================================================================\n\n")

# ---- TOTAL OFFENSES ----
cat("\n####################################\n")
cat("# TOTAL OFFENSES\n")
cat("####################################\n")

ncvs_total <- prepare_data("data/derived/ncvs-merged-data-1993-2024.csv")
ncvs_total <- expand_age(ncvs_total)

dir.create("outputs/tables/total", showWarnings = FALSE, recursive = TRUE)
run_weighted_counts(ncvs_total, "outputs/tables/total/combinedco_ncvs_calc_1_table.docx")
run_chi_square(ncvs_total, "outputs/tables/total/combinedco-chi_squared_table.docx")
run_logistic_regression(ncvs_total, "15-17", "outputs/tables/total/Combinedcof-15-17int-logistic_regression_solo_offending.docx")
run_logistic_regression(ncvs_total, "18-20", "outputs/tables/total/Centered18-20_logistic_regression_solo_offending.docx")

# ---- VIOLENT OFFENSES ----
cat("\n####################################\n")
cat("# VIOLENT OFFENSES\n")
cat("####################################\n")

ncvs_violent <- prepare_data("data/derived/violent-ncvs-merged-data-1993-2024.csv")
ncvs_violent <- expand_age(ncvs_violent)

dir.create("outputs/tables/violent", showWarnings = FALSE, recursive = TRUE)
run_weighted_counts(ncvs_violent, "outputs/tables/violent/combinedco_ncvs_calc_1_table.docx")
run_chi_square(ncvs_violent, "outputs/tables/violent/combinedco-chi_squared_table.docx")
run_logistic_regression(ncvs_violent, "15-17", "outputs/tables/violent/Combinedcof-15-17int-logistic_regression_solo_offending.docx")
run_logistic_regression(ncvs_violent, "18-20", "outputs/tables/violent/Centered18-20_logistic_regression_solo_offending.docx")

# ---- THEFT OFFENSES ----
cat("\n####################################\n")
cat("# THEFT OFFENSES\n")
cat("####################################\n")

ncvs_theft <- prepare_data("data/derived/theft-ncvs-merged-data-1993-2024.csv")
ncvs_theft <- expand_age(ncvs_theft)

dir.create("outputs/tables/theft", showWarnings = FALSE, recursive = TRUE)
run_weighted_counts(ncvs_theft, "outputs/tables/theft/combinedco_ncvs_calc_1_table.docx")
run_chi_square(ncvs_theft, "outputs/tables/theft/combinedco-chi_squared_table.docx")
run_logistic_regression(ncvs_theft, "15-17", "outputs/tables/theft/Combinedcof-15-17int-logistic_regression_solo_offending.docx")
run_logistic_regression(ncvs_theft, "18-20", "outputs/tables/theft/Centered18-20_logistic_regression_solo_offending.docx")

# ---- CO-OFFENDING ONLY ----
cat("\n####################################\n")
cat("# CO-OFFENDING ONLY (TOTAL)\n")
cat("####################################\n")

ncvs_cooff <- prepare_data("data/derived/ncvs-merged-data-1993-2024.csv")
ncvs_cooff <- expand_age(ncvs_cooff)

dir.create("outputs/tables/total", showWarnings = FALSE, recursive = TRUE)
run_cooffending_analysis(ncvs_cooff, "outputs/tables/total")

cat("\n================================================================\n")
cat("ALL ANALYSES COMPLETE\n")
cat("================================================================\n")
