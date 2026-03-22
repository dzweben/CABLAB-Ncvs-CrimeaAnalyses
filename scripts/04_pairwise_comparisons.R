#!/usr/bin/env Rscript
# ===========================================================================
# 04 — Pairwise Age-Group Comparisons
#
# Extracts all 15 Bonferroni-corrected pairwise odds ratios with 95% CIs
# for the supplement tables.
#
# Input:  data/derived/ncvs-merged-data-1993-2024.csv (+ violent/theft)
# Output: Console (statistics used in manuscript generator)
#
# Supports: Supplement Tables S4-S7
# ===========================================================================

library(dplyr)
library(survey)
library(broom)

options(survey.lonely.psu = "adjust")

source_prepare <- function(csv_path) {
  df <- read.csv(csv_path)
  df <- df %>% filter(!is.na(incident_weight), incident_weight > 0,
                      !is.na(V2117), V2117 != "", !is.na(V2118), V2118 != "")
  df[] <- lapply(df, function(col) if (is.character(col)) trimws(col) else col)
  df[df == "N/A"] <- NA
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
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")
  only_oldest <- is.na(df$youngest_multiple) & df$oldest_multiple %in% age_levels
  only_youngest <- is.na(df$oldest_multiple) & df$youngest_multiple %in% age_levels
  df$youngest_multiple[only_oldest] <- df$oldest_multiple[only_oldest]
  df$oldest_multiple[only_youngest] <- df$youngest_multiple[only_youngest]
  df$V2117 <- as.character(df$V2117)
  df$V2118 <- as.character(df$V2118)
  df$YR_GRP <- as.character(df$YR_GRP)
  return(df)
}

expand_age <- function(df) {
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")
  df <- df %>% mutate(
    solo_flag = !is.na(age_solo) & age_solo %in% age_levels,
    same_group_age = youngest_multiple == oldest_multiple & !is.na(youngest_multiple),
    two_group_ages = youngest_multiple != oldest_multiple & !is.na(youngest_multiple) & !is.na(oldest_multiple)
  )
  solo_df <- df %>% filter(solo_flag) %>% mutate(age = age_solo)
  same_age_df <- df %>% filter(!solo_flag & same_group_age) %>% mutate(age = youngest_multiple)
  diff_age_df <- df %>% filter(!solo_flag & two_group_ages)
  youngest_rows <- diff_age_df %>% mutate(age = youngest_multiple)
  oldest_rows <- diff_age_df %>% mutate(age = oldest_multiple)
  bind_rows(solo_df, same_age_df, youngest_rows, oldest_rows) %>%
    select(-solo_flag, -same_group_age, -two_group_ages)
}

make_design <- function(df) {
  svydesign(ids = ~V2118, strata = ~interaction(YR_GRP, V2117),
            weights = ~incident_weight, data = df, nest = TRUE)
}

# Run pairwise ORs for social offending definition
run_pairwise_ors <- function(df, label) {
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  work_df <- df %>%
    filter(!is.na(age), age %in% age_levels,
           social_crime %in% c("alone", "observed", "group")) %>%
    mutate(age = factor(age, levels = age_levels),
           is_alone = as.numeric(social_crime == "alone"))

  full_design <- make_design(work_df)

  pairs <- combn(age_levels, 2, simplify = FALSE)
  cat("\n===", label, "PAIRWISE ORs (social offending) ===\n")

  for (pair in pairs) {
    sub <- subset(full_design, age %in% pair)
    sub <- update(sub, age = factor(age, levels = pair))

    tryCatch({
      model <- svyglm(is_alone ~ age, design = sub, family = binomial())
      result <- tidy(model, conf.int = TRUE, exponentiate = TRUE)
      coef_row <- result[2, ]
      cat(sprintf("  %s vs. %s: OR=%.4f [%.4f, %.4f] p=%.6f\n",
                  pair[1], pair[2], coef_row$estimate, coef_row$conf.low,
                  coef_row$conf.high, coef_row$p.value))
    }, error = function(e) {
      cat(sprintf("  %s vs. %s: ERROR - %s\n", pair[1], pair[2], e$message))
    })
  }
}

# Run pairwise ORs for co-offending only definition
run_cooff_pairwise_ors <- function(df) {
  age_levels <- c("under_12", "12-14", "15-17", "18-20", "21-29", "30+")

  work_df <- df %>%
    filter(!is.na(age), age %in% age_levels,
           solo_group_crime %in% c("solo", "group")) %>%
    mutate(age = factor(age, levels = age_levels),
           is_non_group = as.numeric(solo_group_crime == "solo"))

  full_design <- make_design(work_df)

  pairs <- combn(age_levels, 2, simplify = FALSE)
  cat("\n=== CO-OFFENDING PAIRWISE ORs ===\n")

  for (pair in pairs) {
    sub <- subset(full_design, age %in% pair)
    sub <- update(sub, age = factor(age, levels = pair))

    tryCatch({
      model <- svyglm(is_non_group ~ age, design = sub, family = binomial())
      result <- tidy(model, conf.int = TRUE, exponentiate = TRUE)
      coef_row <- result[2, ]
      cat(sprintf("  %s vs. %s: OR=%.4f [%.4f, %.4f] p=%.6f\n",
                  pair[1], pair[2], coef_row$estimate, coef_row$conf.low,
                  coef_row$conf.high, coef_row$p.value))
    }, error = function(e) {
      cat(sprintf("  %s vs. %s: ERROR - %s\n", pair[1], pair[2], e$message))
    })
  }
}

# === TOTAL ===
cat("Loading Total data...\n")
total_df <- source_prepare("data/derived/ncvs-merged-data-1993-2024.csv") %>% expand_age()
run_pairwise_ors(total_df, "TOTAL")

# === VIOLENT ===
cat("\nLoading Violent data...\n")
violent_df <- source_prepare("data/derived/violent-ncvs-merged-data-1993-2024.csv") %>% expand_age()
run_pairwise_ors(violent_df, "VIOLENT")

# === THEFT ===
cat("\nLoading Theft data...\n")
theft_df <- source_prepare("data/derived/theft-ncvs-merged-data-1993-2024.csv") %>% expand_age()
run_pairwise_ors(theft_df, "THEFT")

# === CO-OFFENDING ===
cat("\nRunning co-offending pairwise...\n")
run_cooff_pairwise_ors(total_df)

cat("\n=== ALL PAIRWISE ORs EXTRACTED ===\n")
