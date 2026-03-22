#!/usr/bin/env Rscript
# ===========================================================================
# 05 — Temporal Stability Test (Year x Age Interaction)
#
# Tests whether the age-graded social offending pattern is stable across
# the 31-year study period by estimating age x year interactions in a
# survey-weighted logistic regression model.
#
# Input:  data/derived/ncvs-merged-data-1993-2024.csv
# Output: Console (statistics used in manuscript generator)
#
# Supports: Results — Stability Across Survey Years
# ===========================================================================

library(dplyr)
library(survey)

options(survey.lonely.psu = "adjust")

cat("================================================================\n")
cat("YEAR x AGE INTERACTION ANALYSIS (1993-2024, TSL)\n")
cat("================================================================\n\n")

# --- Read and prepare data (replicating main pipeline logic) ---
df <- read.csv("data/derived/ncvs-merged-data-1993-2024.csv", stringsAsFactors = FALSE)
cat("Rows read:", nrow(df), "\n")

# Trim whitespace
df[] <- lapply(df, function(col) if (is.character(col)) trimws(col) else col)
df[df == "N/A"] <- NA

# Normalize age labels
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

# Fix youngest/oldest consistency
only_oldest <- is.na(df$youngest_multiple) & df$oldest_multiple %in% age_levels
only_youngest <- is.na(df$oldest_multiple) & df$youngest_multiple %in% age_levels
df$youngest_multiple[only_oldest] <- df$oldest_multiple[only_oldest]
df$oldest_multiple[only_youngest] <- df$youngest_multiple[only_youngest]

# Ensure proper types
df$year <- as.numeric(as.character(df$year))
df$V2117 <- as.character(df$V2117)
df$V2118 <- as.character(df$V2118)
df$YR_GRP <- as.character(df$YR_GRP)

cat("Year range:", min(df$year, na.rm=TRUE), "-", max(df$year, na.rm=TRUE), "\n")
cat("Years present:", paste(sort(unique(df$year)), collapse=", "), "\n\n")

# Expand co-offense rows
expand_age <- function(df) {
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
  return(result)
}

# Filter and expand
df <- df %>% filter(!is.na(incident_weight), incident_weight > 0,
                    !is.na(V2117), V2117 != "", !is.na(V2118), V2118 != "",
                    social_crime %in% c("alone", "observed", "group"))
df <- expand_age(df)

# Set up variables
df$age <- factor(df$age, levels = age_levels)
df$is_solo <- ifelse(df$social_crime == "alone", 1, 0)

# Filter to valid age
df <- df %>% filter(!is.na(age))
cat("Analysis rows:", nrow(df), "\n\n")

# Center year at 2008 (approx midpoint of 1993-2024)
df$year_c <- df$year - 2008

# --- Survey design (TSL) ---
df$strata_var <- interaction(df$YR_GRP, df$V2117)
des <- svydesign(
  ids = ~V2118,
  strata = ~strata_var,
  weights = ~incident_weight,
  data = df,
  nest = TRUE
)

# --- Model 1: Main effects only ---
cat("--- MODEL 1: Main effects (age + year) ---\n")
m1 <- svyglm(is_solo ~ relevel(age, ref = "15-17") + year_c,
              design = des, family = binomial())

coef_df1 <- data.frame(
  term = names(coef(m1)),
  OR = round(exp(coef(m1)), 4),
  p = formatC(summary(m1)$coefficients[, "Pr(>|t|)"], format = "g", digits = 4)
)
print(coef_df1, row.names = FALSE)
cat("\nYear main effect OR:", round(exp(coef(m1)["year_c"]), 4), "\n\n")

# --- Model 2: Interaction (age x year) ---
cat("--- MODEL 2: Interaction (age x year) ---\n")
# Use pre-releveled factor to keep term names simple for regTermTest
df$age_r <- relevel(df$age, ref = "15-17")
des <- svydesign(ids = ~V2118, strata = ~strata_var, weights = ~incident_weight,
                 data = df, nest = TRUE)
m2 <- svyglm(is_solo ~ age_r * year_c,
              design = des, family = binomial())

coef_df2 <- data.frame(
  term = names(coef(m2)),
  OR = round(exp(coef(m2)), 4),
  SE = round(summary(m2)$coefficients[, "Std. Error"], 4),
  p = formatC(summary(m2)$coefficients[, "Pr(>|t|)"], format = "g", digits = 4)
)
print(coef_df2, row.names = FALSE)

# --- Joint Wald test for interaction terms ---
cat("\n--- JOINT WALD TEST FOR INTERACTION TERMS ---\n")
interaction_terms <- grep(":year_c", names(coef(m2)))
cat("Interaction terms:", names(coef(m2))[interaction_terms], "\n\n")

# Use anova to compare nested models (main effects only vs interaction)
m1_r <- svyglm(is_solo ~ age_r + year_c, design = des, family = binomial())
joint_test <- anova(m1_r, m2, method = "Wald")
print(joint_test)
cat("\n")

# --- Individual interaction ORs ---
cat("\n--- INDIVIDUAL INTERACTION ORs (per 1-year change) ---\n")
int_names <- names(coef(m2))[interaction_terms]
int_ors <- exp(coef(m2)[interaction_terms])
int_se <- summary(m2)$coefficients[interaction_terms, "Std. Error"]
int_p <- summary(m2)$coefficients[interaction_terms, "Pr(>|t|)"]
int_bonf <- pmin(int_p * 5, 1)  # 5 interaction terms

for (i in seq_along(int_names)) {
  ci_lo <- exp(coef(m2)[interaction_terms[i]] - 1.96 * int_se[i])
  ci_hi <- exp(coef(m2)[interaction_terms[i]] + 1.96 * int_se[i])
  cat(sprintf("  %s: OR = %.4f [%.4f, %.4f], p = %s, p(Bonf) = %s\n",
              int_names[i], int_ors[i], ci_lo, ci_hi,
              formatC(int_p[i], format = "g", digits = 4),
              formatC(int_bonf[i], format = "g", digits = 4)))
}

# --- Per-decade ORs for interpretability ---
cat("\n--- INTERACTION ORs PER DECADE ---\n")
cat("(Exponentiate interaction coef * 10 for 10-year change)\n")
for (i in seq_along(int_names)) {
  or_decade <- exp(coef(m2)[interaction_terms[i]] * 10)
  ci_lo_dec <- exp((coef(m2)[interaction_terms[i]] - 1.96 * int_se[i]) * 10)
  ci_hi_dec <- exp((coef(m2)[interaction_terms[i]] + 1.96 * int_se[i]) * 10)
  cat(sprintf("  %s: OR/decade = %.4f [%.4f, %.4f]\n",
              int_names[i], or_decade, ci_lo_dec, ci_hi_dec))
}

cat("\n--- INTERPRETATION ---\n")
cat("Year centered at 2008. Study spans 31 years (1993-2024, excl 2006).\n")
cat("Interaction OR > 1 = age group becomes MORE solo over time relative to 15-17.\n")
cat("Interaction OR < 1 = age group becomes MORE social over time relative to 15-17.\n")

cat("\n================================================================\n")
cat("YEAR INTERACTION ANALYSIS COMPLETE\n")
cat("================================================================\n")
