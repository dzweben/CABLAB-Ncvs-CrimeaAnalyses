#!/usr/bin/env Rscript
# ===========================================================================
# 06 — Risk-Taking Moderation Analysis (Analysis 2, Weighted)
#
# Tests whether offender age moderates the relationship between social
# context and risk-taking in violent crime. Uses survey-weighted OLS with
# interaction terms: RISK_SCORE ~ AGE_BIN * SOCIAL2.
#
# Input:  data/derived/ncvs-risk-merged-1993-2024.csv
# Output: Console (statistics used in manuscript generator)
#
# Supports: Results — Analysis 2: Risk-Taking in Violent Crime
# ===========================================================================

library(dplyr)
library(survey)
library(broom)

options(survey.lonely.psu = "adjust")
cat("\n", strrep("=", 70), "\n")
cat("ANALYSIS 2: RISK-TAKING IN ADOLESCENT VIOLENT CRIME\n")
cat("Standard moderation | 6 NCVS age bins | 15-17 reference\n")
cat(strrep("=", 70), "\n\n")

# ── Read and filter ──
df <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
cat("Total rows loaded:", format(nrow(df), big.mark = ","), "\n")

df <- df %>% filter(crimetype_raw %in% as.character(1:17))
cat("After TOC 1-17 filter:", format(nrow(df), big.mark = ","), "\n")

# ── Create unified AGE_BIN (routed: solo→V4237, group→V4251 youngest) ──
df$AGE_BIN <- ifelse(df$solo_group_crime == "solo", df$age_solo,
              ifelse(df$solo_group_crime == "group", df$youngest_multiple, NA))

valid_bins <- c("Under 12", "12-14", "15-17", "18-20", "21-29", "30+")

df <- df %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL2 %in% c("alone", "social"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

# Convert RISK_SCORE
df$RISK_SCORE <- as.numeric(df$RISK_SCORE)

# Drop rows without valid composite
df <- df %>% filter(!is.na(RISK_SCORE))

cat("Analysis sample:", format(nrow(df), big.mark = ","), "\n")

# ── Factor setup: 15-17 as reference ──
df$AGE_BIN <- factor(df$AGE_BIN,
                     levels = c("15-17", "Under 12", "12-14", "18-20", "21-29", "30+"))
df$SOCIAL2 <- factor(df$SOCIAL2, levels = c("alone", "social"))

cat("AGE_BIN levels:", paste(levels(df$AGE_BIN), collapse = ", "), "\n")
cat("Reference: 15-17, alone\n\n")

# ── Survey design (TSL) ──
svy <- svydesign(ids = ~V2118,
                 strata = ~interaction(YR_GRP, V2117),
                 weights = ~incident_weight,
                 data = df, nest = TRUE)

# ══════════════════════════════════════════════════════════════════════
# DESCRIPTIVE TABLE: 5 age bins × 2 social contexts
# ══════════════════════════════════════════════════════════════════════
cat(strrep("=", 70), "\n")
cat("DESCRIPTIVE TABLE: Weighted Mean RISK_SCORE\n")
cat(strrep("=", 70), "\n\n")

cat(sprintf("  %-7s %-8s %8s %8s %8s\n", "Age", "Context", "Mean", "SE", "N"))
cat(sprintf("  %s\n", strrep("-", 48)))

age_order <- c("Under 12", "12-14", "15-17", "18-20", "21-29", "30+")

for (ab in age_order) {
  for (s in c("alone", "social", "TOTAL")) {
    if (s == "TOTAL") {
      sub <- subset(svy, AGE_BIN == ab)
    } else {
      sub <- subset(svy, AGE_BIN == ab & SOCIAL2 == s)
    }
    m <- svymean(~RISK_SCORE, sub, na.rm = TRUE)
    n <- nrow(sub$variables)
    cat(sprintf("  %-7s %-8s %8.4f %8.4f %8s\n",
                ab, s, coef(m), SE(m), format(n, big.mark = ",")))
  }
  cat("\n")
}

# Social boost (social - alone) at each age
cat("  Solo → Social gap by age:\n")
for (ab in age_order) {
  sub_a <- subset(svy, AGE_BIN == ab & SOCIAL2 == "alone")
  sub_s <- subset(svy, AGE_BIN == ab & SOCIAL2 == "social")
  m_a <- coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
  m_s <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE))
  gap <- m_s - m_a
  cat(sprintf("    %-7s: %+.4f (%+.1f pp)\n", ab, gap, gap * 100))
}

# Social offending rate by age (verification from Analysis 1)
cat("\n  Social offending rate (unweighted):\n")
for (ab in age_order) {
  n_soc <- sum(df$AGE_BIN == ab & df$SOCIAL2 == "social")
  n_tot <- sum(df$AGE_BIN == ab)
  cat(sprintf("    %-7s: %5d/%5d = %.1f%%\n", ab, n_soc, n_tot,
              n_soc / n_tot * 100))
}

# ══════════════════════════════════════════════════════════════════════
# DESCRIPTIVE AGE GRADIENT: RISK_SCORE ~ AGE_BIN
# Teen crimes are riskier (overall finding)
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("DESCRIPTIVE AGE GRADIENT: RISK_SCORE ~ AGE_BIN  (ref: 15-17)\n")
cat("Are teen crimes riskier than other ages?\n")
cat(strrep("=", 70), "\n\n")

model1 <- svyglm(RISK_SCORE ~ AGE_BIN, design = svy, family = gaussian())
res1 <- tidy(model1, conf.int = TRUE)

cat(sprintf("  %-20s %10s %12s %12s %12s\n",
            "Term", "B", "95% CI", "", "p"))
cat(sprintf("  %s\n", strrep("-", 70)))

for (i in seq_len(nrow(res1))) {
  r <- res1[i, ]
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-20s %+10.4f [%+.4f, %+.4f] %12.6f %s\n",
              r$term, r$estimate, r$conf.low, r$conf.high, r$p.value, sig))
}

cat("\n  Interpretation: Negative B = that age group's crimes are LESS risky\n")
cat("  than 15-17 crimes (by B points on the 0-1 composite scale).\n")

# ══════════════════════════════════════════════════════════════════════
# MODERATION ANALYSIS
# Step 1: Additive model
# Step 2: Interaction model
# Step 3: F-change test
# Step 4: Probe — interaction coefficients + simple slopes
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("MODERATION ANALYSIS: Does age moderate the social → risk relationship?\n")
cat(strrep("=", 70), "\n\n")

# ── Step 1: Additive model ──
cat("Step 1: Additive model — RISK_SCORE ~ AGE_BIN + SOCIAL2\n\n")
model_additive <- svyglm(RISK_SCORE ~ AGE_BIN + SOCIAL2,
                          design = svy, family = gaussian())
res_add <- tidy(model_additive, conf.int = TRUE)

cat(sprintf("  %-35s %10s %12s %12s %12s\n",
            "Term", "B", "95% CI", "", "p"))
cat(sprintf("  %s\n", strrep("-", 80)))

for (i in seq_len(nrow(res_add))) {
  r <- res_add[i, ]
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-35s %+10.4f [%+.4f, %+.4f] %12.6f %s\n",
              r$term, r$estimate, r$conf.low, r$conf.high, r$p.value, sig))
}

# ── Step 2: Interaction model ──
cat("\n\nStep 2: Interaction model — RISK_SCORE ~ AGE_BIN * SOCIAL2\n\n")
model_interaction <- svyglm(RISK_SCORE ~ AGE_BIN * SOCIAL2,
                             design = svy, family = gaussian())
res_int <- tidy(model_interaction, conf.int = TRUE)

cat(sprintf("  %-45s %10s %12s %12s %12s\n",
            "Term", "B", "95% CI", "", "p"))
cat(sprintf("  %s\n", strrep("-", 85)))

for (i in seq_len(nrow(res_int))) {
  r <- res_int[i, ]
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-45s %+10.4f [%+.4f, %+.4f] %12.6f %s\n",
              r$term, r$estimate, r$conf.low, r$conf.high, r$p.value, sig))
}

# ── Step 3: F-change test (moderation significance) ──
cat("\n\nStep 3: F-CHANGE TEST (additive vs interaction)\n")
cat("  Testing: Do the 5 AGE_BIN:SOCIAL2 interaction terms jointly = 0?\n\n")

ftest <- regTermTest(model_interaction, ~AGE_BIN:SOCIAL2)
cat(sprintf("  Wald F(%d, %d) = %.4f\n", ftest$df, ftest$ddf, ftest$Ftest))
cat(sprintf("  p = %.10f\n", ftest$p))

if (ftest$p < .001) {
  cat("  >>> MODERATION IS SIGNIFICANT (p < .001)\n")
} else if (ftest$p < .05) {
  cat(sprintf("  >>> MODERATION IS SIGNIFICANT (p = %.4f)\n", ftest$p))
} else {
  cat(sprintf("  >>> MODERATION IS NOT SIGNIFICANT (p = %.4f)\n", ftest$p))
}

cat("\n  Interpretation: The effect of social context on risk-taking\n")
cat("  significantly differs across age groups.\n")

# ── Step 4a: Interaction coefficients (moderation probing) ──
cat("\n\n", strrep("-", 70), "\n")
cat("Step 4a: INTERACTION COEFFICIENTS (moderation probing)\n")
cat("Each tests: is this age's social boost different from 15-17's?\n")
cat(strrep("-", 70), "\n\n")

# Social boost at 15-17 = SOCIAL2social coefficient
social_15_17 <- res_int %>% filter(term == "SOCIAL2social")
cat(sprintf("  Reference social boost (15-17): %+.4f (SE=%.4f, p=%.6f)\n",
            social_15_17$estimate, social_15_17$std.error, social_15_17$p.value))

# Interaction terms = difference from 15-17's boost
int_terms <- res_int %>% filter(grepl(":", term))
cat(sprintf("\n  %-10s %12s %10s %12s %12s\n",
            "Age", "Diff from", "SE", "p", "Total boost"))
cat(sprintf("  %-10s %12s %10s %12s %12s\n",
            "", "15-17", "", "", "(pp)"))
cat(sprintf("  %s\n", strrep("-", 60)))

for (j in seq_len(nrow(int_terms))) {
  r <- int_terms[j, ]
  age_label <- gsub("AGE_BIN|:SOCIAL2social", "", r$term)
  total_boost <- social_15_17$estimate + r$estimate
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+12.4f %10.4f %12.6f %s %+8.1f pp\n",
              age_label, r$estimate, r$std.error, r$p.value, sig,
              total_boost * 100))
}

cat("\n  Interpretation: Negative diff = smaller social boost than 15-17.\n")
cat("  Significant p = that age's social boost is STATISTICALLY DIFFERENT\n")
cat("  from the 15-17 social boost.\n")

# ── Step 4b: Simple effects of age at SOCIAL2=alone ──
cat("\n\n", strrep("-", 70), "\n")
cat("Step 4b: SIMPLE EFFECTS OF AGE AT SOCIAL2=alone\n")
cat("Is the age gradient in risk present when offending alone?\n")
cat(strrep("-", 70), "\n\n")

# From the interaction model: AGE_BIN coefficients = age effect at alone (reference)
main_age_terms <- res_int %>% filter(grepl("^AGE_BIN", term) & !grepl(":", term))

cat(sprintf("  %-10s %10s %10s %10s\n", "Age", "B vs 15-17", "SE", "p"))
cat(sprintf("  %s\n", strrep("-", 45)))

for (j in seq_len(nrow(main_age_terms))) {
  r <- main_age_terms[j, ]
  age_label <- gsub("AGE_BIN", "", r$term)
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+10.4f %10.4f %10.6f %s\n",
              age_label, r$estimate, r$std.error, r$p.value, sig))
}

cat("\n  Interpretation: These are the age effects WHEN OFFENDING ALONE.\n")
cat("  Non-significant = no age difference in risk when solo.\n")
cat("  This is the compositional evidence: the overall age gradient\n")
cat("  disappears when we remove social offending.\n")

# ══════════════════════════════════════════════════════════════════════
# ERA STABILITY: Is the moderation stable across decades?
# Three-way: AGE_BIN × SOCIAL2 × ERA
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("ERA STABILITY: AGE_BIN × SOCIAL2 × ERA three-way interaction\n")
cat("Does the moderation pattern change across decades?\n")
cat(strrep("=", 70), "\n\n")

# Compute era bins from year (matching Analysis 1's Figure 4)
df$ERA_FIG <- ifelse(df$year <= 2003, "1993-2003",
              ifelse(df$year <= 2014, "2004-2014", "2015-2024"))
df$ERA_FIG <- factor(df$ERA_FIG, levels = c("1993-2003", "2004-2014", "2015-2024"))

svy <- svydesign(ids = ~V2118,
                 strata = ~interaction(YR_GRP, V2117),
                 weights = ~incident_weight,
                 data = df, nest = TRUE)

model_3way <- svyglm(RISK_SCORE ~ AGE_BIN * SOCIAL2 * ERA_FIG,
                      design = svy, family = gaussian())

# Omnibus test of the three-way interaction
ftest_3way <- regTermTest(model_3way, ~AGE_BIN:SOCIAL2:ERA_FIG)
cat(sprintf("  Three-way Wald F(%d, %d) = %.4f\n",
            ftest_3way$df, ftest_3way$ddf, ftest_3way$Ftest))
cat(sprintf("  p = %.6f\n", ftest_3way$p))

if (ftest_3way$p >= .05) {
  cat("  >>> THREE-WAY INTERACTION IS NOT SIGNIFICANT\n")
  cat("  >>> The moderation does NOT vary by era.\n")
} else {
  cat(sprintf("  >>> THREE-WAY INTERACTION IS SIGNIFICANT (p = %.4f)\n",
              ftest_3way$p))
}

# Descriptive: social boost by age within each era
cat("\n  Social boost (social - alone) by age × era:\n")
cat(sprintf("  %-7s %12s %12s %12s\n",
            "Age", "1993-2003", "2004-2014", "2015-2024"))
cat(sprintf("  %s\n", strrep("-", 48)))

era_order_fig <- c("1993-2003", "2004-2014", "2015-2024")
for (ab in age_order) {
  boosts <- c()
  for (era in era_order_fig) {
    sub_a <- subset(svy, AGE_BIN == ab & SOCIAL2 == "alone" & ERA_FIG == era)
    sub_s <- subset(svy, AGE_BIN == ab & SOCIAL2 == "social" & ERA_FIG == era)
    n_a <- nrow(sub_a$variables)
    n_s <- nrow(sub_s$variables)
    if (n_a >= 10 & n_s >= 10) {
      m_a <- coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
      m_s <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE))
      gap <- (m_s - m_a) * 100
      boosts <- c(boosts, sprintf("%+.1f pp", gap))
    } else {
      boosts <- c(boosts, "  n<10")
    }
  }
  cat(sprintf("  %-7s %12s %12s %12s\n", ab, boosts[1], boosts[2], boosts[3]))
}

# Cell Ns per era
cat("\n  Cell Ns (alone / social) by age × era:\n")
for (ab in age_order) {
  ns <- c()
  for (era in era_order_fig) {
    n_a <- sum(df$AGE_BIN == ab & df$SOCIAL2 == "alone" & df$ERA_FIG == era)
    n_s <- sum(df$AGE_BIN == ab & df$SOCIAL2 == "social" & df$ERA_FIG == era)
    ns <- c(ns, sprintf("%d/%d", n_a, n_s))
  }
  cat(sprintf("  %-7s %12s %12s %12s\n", ab, ns[1], ns[2], ns[3]))
}

# ── Era-stratified moderation F-change tests ──
cat("\n\n  ERA-STRATIFIED MODERATION F-CHANGE TESTS\n")
cat("  (Does the moderation replicate independently within each era?)\n")
cat(sprintf("  %s\n", strrep("-", 60)))

for (era in era_order_fig) {
  era_df <- df %>% filter(ERA_FIG == era)
  cat(sprintf("\n  %s (n = %s)\n", era, format(nrow(era_df), big.mark = ",")))

  svy_era <- svydesign(ids = ~V2118,
                       strata = ~interaction(YR_GRP, V2117),
                       weights = ~incident_weight,
                       data = era_df, nest = TRUE)

  mod_int <- svyglm(RISK_SCORE ~ AGE_BIN * SOCIAL2,
                     design = svy_era, family = gaussian())
  ft <- regTermTest(mod_int, ~AGE_BIN:SOCIAL2)
  cat(sprintf("    F-change: F(%d, %d) = %.4f, p = %.6f\n",
              ft$df, ft$ddf, ft$Ftest, ft$p))
  if (ft$p < .001) {
    cat("    >>> SIGNIFICANT (p < .001)\n")
  } else if (ft$p < .05) {
    cat(sprintf("    >>> SIGNIFICANT (p = %.4f)\n", ft$p))
  } else {
    cat(sprintf("    >>> NOT SIGNIFICANT (p = %.4f)\n", ft$p))
  }
}

# ══════════════════════════════════════════════════════════════════════
# EFFECT SIZES
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("EFFECT SIZES\n")
cat(strrep("=", 70), "\n\n")

pooled_sd <- sd(df$RISK_SCORE, na.rm = TRUE)
cat(sprintf("  Pooled SD of RISK_SCORE: %.4f\n\n", pooled_sd))

cat("  Descriptive age gradient (full sample, from age-only model):\n")
for (ab in c("Under 12", "12-14", "18-20", "21-29", "30+")) {
  term <- paste0("AGE_BIN", ab)
  b <- res1 %>% filter(term == !!term)
  if (nrow(b) > 0) {
    d <- b$estimate / pooled_sd
    cat(sprintf("    %-7s vs 15-17: d = %.3f\n", ab, d))
  }
}

cat("\n  Age gradient among solo offenders (from interaction model):\n")
for (j in seq_len(nrow(main_age_terms))) {
  r <- main_age_terms[j, ]
  age_label <- gsub("AGE_BIN", "", r$term)
  d <- r$estimate / pooled_sd
  cat(sprintf("    %-7s vs 15-17: d = %.3f\n", age_label, d))
}

cat("\n  Social boost effect sizes:\n")
cat(sprintf("    15-17 social boost: d = %.3f\n",
            social_15_17$estimate / pooled_sd))
for (j in seq_len(nrow(int_terms))) {
  r <- int_terms[j, ]
  age_label <- gsub("AGE_BIN|:SOCIAL2social", "", r$term)
  total_boost <- social_15_17$estimate + r$estimate
  d <- total_boost / pooled_sd
  cat(sprintf("    %-7s social boost: d = %.3f\n", age_label, d))
}

# ══════════════════════════════════════════════════════════════════════
# SENSITIVITY: CO-OFFENDING vs TRULY ALONE (observed excluded)
# Pure co-offending effect: group vs truly alone, observed excluded
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("SENSITIVITY: CO-OFFENDING vs TRULY ALONE\n")
cat("Observed crimes EXCLUDED — pure co-offending effect\n")
cat(strrep("=", 70), "\n\n")

# Reload full data for co-offending analysis
df_co <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
df_co <- df_co %>% filter(crimetype_raw %in% as.character(1:17))

# EXCLUDE observed crimes — only truly alone and group
df_co <- df_co %>% filter(social_crime %in% c("alone", "group"))
cat("After excluding observed crimes:", format(nrow(df_co), big.mark = ","), "incidents\n")

# Create AGE_BIN
df_co$AGE_BIN <- ifelse(df_co$solo_group_crime == "solo", df_co$age_solo,
                 ifelse(df_co$solo_group_crime == "group", df_co$youngest_multiple, NA))

# Social variable: group = "social", truly alone = "alone"
df_co$SOCIAL_COOFF <- ifelse(df_co$social_crime == "group", "social", "alone")

df_co <- df_co %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL_COOFF %in% c("alone", "social"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

df_co$RISK_SCORE <- as.numeric(df_co$RISK_SCORE)
df_co <- df_co %>% filter(!is.na(RISK_SCORE))
cat("Co-offending analysis sample:", format(nrow(df_co), big.mark = ","), "\n")

# Factor setup
df_co$AGE_BIN <- factor(df_co$AGE_BIN,
                        levels = c("15-17", "Under 12", "12-14", "18-20", "21-29", "30+"))
df_co$SOCIAL_COOFF <- factor(df_co$SOCIAL_COOFF, levels = c("alone", "social"))

# Survey design
svy_co <- svydesign(ids = ~V2118,
                    strata = ~interaction(YR_GRP, V2117),
                    weights = ~incident_weight,
                    data = df_co, nest = TRUE)

# Descriptive table
cat("\n  DESCRIPTIVE TABLE: Weighted Mean RISK_SCORE (co-offending only)\n")
cat(sprintf("  %-7s %-8s %8s %8s %8s\n", "Age", "Context", "Mean", "SE", "N"))
cat(sprintf("  %s\n", strrep("-", 48)))

for (ab in age_order) {
  for (s in c("alone", "social")) {
    sub <- subset(svy_co, AGE_BIN == ab & SOCIAL_COOFF == s)
    m <- svymean(~RISK_SCORE, sub, na.rm = TRUE)
    n <- nrow(sub$variables)
    cat(sprintf("  %-7s %-8s %8.4f %8.4f %8s\n",
                ab, s, coef(m), SE(m), format(n, big.mark = ",")))
  }
  cat("\n")
}

# Social boost (co-offending - alone) at each age
cat("  Co-offending → alone gap by age:\n")
for (ab in age_order) {
  sub_a <- subset(svy_co, AGE_BIN == ab & SOCIAL_COOFF == "alone")
  sub_s <- subset(svy_co, AGE_BIN == ab & SOCIAL_COOFF == "social")
  m_a <- coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
  m_s <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE))
  gap <- m_s - m_a
  cat(sprintf("    %-7s: %+.4f (%+.1f pp)\n", ab, gap, gap * 100))
}

# Moderation: Additive vs Interaction
cat("\n  MODERATION F-CHANGE TEST (co-offending only)\n\n")

model_add_co <- svyglm(RISK_SCORE ~ AGE_BIN + SOCIAL_COOFF,
                        design = svy_co, family = gaussian())
model_int_co <- svyglm(RISK_SCORE ~ AGE_BIN * SOCIAL_COOFF,
                        design = svy_co, family = gaussian())

ftest_co <- regTermTest(model_int_co, ~AGE_BIN:SOCIAL_COOFF)
cat(sprintf("  Wald F(%d, %d) = %.4f\n", ftest_co$df, ftest_co$ddf, ftest_co$Ftest))
cat(sprintf("  p = %.10f\n", ftest_co$p))

if (ftest_co$p < .001) {
  cat("  >>> MODERATION IS SIGNIFICANT (p < .001)\n")
} else if (ftest_co$p < .05) {
  cat(sprintf("  >>> MODERATION IS SIGNIFICANT (p = %.4f)\n", ftest_co$p))
} else {
  cat(sprintf("  >>> MODERATION IS NOT SIGNIFICANT (p = %.4f)\n", ftest_co$p))
}

# Interaction coefficients
res_int_co <- tidy(model_int_co, conf.int = TRUE)
social_ref_co <- res_int_co %>% filter(term == "SOCIAL_COOFFsocial")
cat(sprintf("\n  Reference co-offending boost (15-17): %+.4f (SE=%.4f, p=%.6f)\n",
            social_ref_co$estimate, social_ref_co$std.error, social_ref_co$p.value))

int_terms_co <- res_int_co %>% filter(grepl(":", term))
cat(sprintf("\n  %-10s %12s %10s %12s %12s\n",
            "Age", "Diff from", "SE", "p", "Total boost"))
cat(sprintf("  %-10s %12s %10s %12s %12s\n",
            "", "15-17", "", "", "(pp)"))
cat(sprintf("  %s\n", strrep("-", 60)))

for (j in seq_len(nrow(int_terms_co))) {
  r <- int_terms_co[j, ]
  age_label <- gsub("AGE_BIN|:SOCIAL_COOFFsocial", "", r$term)
  total_boost <- social_ref_co$estimate + r$estimate
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+12.4f %10.4f %12.6f %s %+8.1f pp\n",
              age_label, r$estimate, r$std.error, r$p.value, sig,
              total_boost * 100))
}

# Simple effects at alone (main age effects from interaction model)
cat("\n  SIMPLE EFFECTS OF AGE AT SOCIAL_COOFF=alone\n")
main_age_co <- res_int_co %>% filter(grepl("^AGE_BIN", term) & !grepl(":", term))
cat(sprintf("  %-10s %10s %10s %10s\n", "Age", "B vs 15-17", "SE", "p"))
cat(sprintf("  %s\n", strrep("-", 45)))
for (j in seq_len(nrow(main_age_co))) {
  r <- main_age_co[j, ]
  age_label <- gsub("AGE_BIN", "", r$term)
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+10.4f %10.4f %10.6f %s\n",
              age_label, r$estimate, r$std.error, r$p.value, sig))
}

# Effect sizes
pooled_sd_co <- sd(df_co$RISK_SCORE, na.rm = TRUE)
cat(sprintf("\n  Pooled SD: %.4f\n", pooled_sd_co))
cat(sprintf("  15-17 co-offending boost d = %.3f\n",
            social_ref_co$estimate / pooled_sd_co))

# ══════════════════════════════════════════════════════════════════════
# SENSITIVITY: OBSERVED vs ALONE (solo crimes only, group excluded)
# Pure bystander effect: observed solo vs truly alone solo
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("SENSITIVITY: OBSERVED vs ALONE (solo crimes only)\n")
cat("Group crimes EXCLUDED — pure bystander effect\n")
cat(strrep("=", 70), "\n\n")

# Reload full data
df_obs <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
df_obs <- df_obs %>% filter(crimetype_raw %in% as.character(1:17))

# EXCLUDE group crimes entirely — solo crimes only
df_obs <- df_obs %>% filter(solo_group_crime == "solo")
cat("After excluding group crimes:", format(nrow(df_obs), big.mark = ","), "solo crimes\n")

# Create AGE_BIN (solo only, so always age_solo)
df_obs$AGE_BIN <- df_obs$age_solo

# Social variable: observed vs alone (the only two categories left)
df_obs$SOCIAL_OBS <- df_obs$social_crime  # already "observed" or "alone"

df_obs <- df_obs %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL_OBS %in% c("alone", "observed"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

# Recode to match factor levels
df_obs$SOCIAL_OBS <- ifelse(df_obs$SOCIAL_OBS == "observed", "social", "alone")

df_obs$RISK_SCORE <- as.numeric(df_obs$RISK_SCORE)
df_obs <- df_obs %>% filter(!is.na(RISK_SCORE))
cat("Observed-only analysis sample:", format(nrow(df_obs), big.mark = ","), "\n")

# Factor setup
df_obs$AGE_BIN <- factor(df_obs$AGE_BIN,
                         levels = c("15-17", "Under 12", "12-14", "18-20", "21-29", "30+"))
df_obs$SOCIAL_OBS <- factor(df_obs$SOCIAL_OBS, levels = c("alone", "social"))

# N per cell
cat("\n  Cell Ns:\n")
for (ab in age_order) {
  n_a <- sum(df_obs$AGE_BIN == ab & df_obs$SOCIAL_OBS == "alone")
  n_s <- sum(df_obs$AGE_BIN == ab & df_obs$SOCIAL_OBS == "social")
  cat(sprintf("    %-7s: alone=%5d, observed=%5d\n", ab, n_a, n_s))
}

# Survey design
svy_obs <- svydesign(ids = ~V2118,
                     strata = ~interaction(YR_GRP, V2117),
                     weights = ~incident_weight,
                     data = df_obs, nest = TRUE)

# Descriptive table
cat("\n  DESCRIPTIVE TABLE: Weighted Mean RISK_SCORE (observed-only)\n")
cat(sprintf("  %-7s %-8s %8s %8s %8s\n", "Age", "Context", "Mean", "SE", "N"))
cat(sprintf("  %s\n", strrep("-", 48)))

for (ab in age_order) {
  for (s in c("alone", "social")) {
    sub <- subset(svy_obs, AGE_BIN == ab & SOCIAL_OBS == s)
    m <- svymean(~RISK_SCORE, sub, na.rm = TRUE)
    n <- nrow(sub$variables)
    cat(sprintf("  %-7s %-8s %8.4f %8.4f %8s\n",
                ab, s, coef(m), SE(m), format(n, big.mark = ",")))
  }
  cat("\n")
}

# Observed boost at each age
cat("  Observed boost (observed - alone) by age:\n")
for (ab in age_order) {
  sub_a <- subset(svy_obs, AGE_BIN == ab & SOCIAL_OBS == "alone")
  sub_s <- subset(svy_obs, AGE_BIN == ab & SOCIAL_OBS == "social")
  m_a <- coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
  m_s <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE))
  gap <- m_s - m_a
  cat(sprintf("    %-7s: %+.4f (%+.1f pp)\n", ab, gap, gap * 100))
}

# Moderation: F-change test
cat("\n  MODERATION F-CHANGE TEST (observed-only)\n\n")

model_add_obs <- svyglm(RISK_SCORE ~ AGE_BIN + SOCIAL_OBS,
                         design = svy_obs, family = gaussian())
model_int_obs <- svyglm(RISK_SCORE ~ AGE_BIN * SOCIAL_OBS,
                         design = svy_obs, family = gaussian())

ftest_obs <- regTermTest(model_int_obs, ~AGE_BIN:SOCIAL_OBS)
cat(sprintf("  Wald F(%d, %d) = %.4f\n", ftest_obs$df, ftest_obs$ddf, ftest_obs$Ftest))
cat(sprintf("  p = %.10f\n", ftest_obs$p))

if (ftest_obs$p < .001) {
  cat("  >>> MODERATION IS SIGNIFICANT (p < .001)\n")
} else if (ftest_obs$p < .05) {
  cat(sprintf("  >>> MODERATION IS SIGNIFICANT (p = %.4f)\n", ftest_obs$p))
} else {
  cat(sprintf("  >>> MODERATION IS NOT SIGNIFICANT (p = %.4f)\n", ftest_obs$p))
}

# Interaction coefficients
res_int_obs <- tidy(model_int_obs, conf.int = TRUE)
social_ref_obs <- res_int_obs %>% filter(term == "SOCIAL_OBSsocial")
cat(sprintf("\n  Reference observed boost (15-17): %+.4f (SE=%.4f, p=%.6f)\n",
            social_ref_obs$estimate, social_ref_obs$std.error, social_ref_obs$p.value))

int_terms_obs <- res_int_obs %>% filter(grepl(":", term))
cat(sprintf("\n  %-10s %12s %10s %12s %12s\n",
            "Age", "Diff from", "SE", "p", "Total boost"))
cat(sprintf("  %-10s %12s %10s %12s %12s\n",
            "", "15-17", "", "", "(pp)"))
cat(sprintf("  %s\n", strrep("-", 60)))

for (j in seq_len(nrow(int_terms_obs))) {
  r <- int_terms_obs[j, ]
  age_label <- gsub("AGE_BIN|:SOCIAL_OBSsocial", "", r$term)
  total_boost <- social_ref_obs$estimate + r$estimate
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+12.4f %10.4f %12.6f %s %+8.1f pp\n",
              age_label, r$estimate, r$std.error, r$p.value, sig,
              total_boost * 100))
}

# Simple effects at alone
cat("\n  SIMPLE EFFECTS OF AGE AT SOCIAL_OBS=alone\n")
main_age_obs <- res_int_obs %>% filter(grepl("^AGE_BIN", term) & !grepl(":", term))
cat(sprintf("  %-10s %10s %10s %10s\n", "Age", "B vs 15-17", "SE", "p"))
cat(sprintf("  %s\n", strrep("-", 45)))
for (j in seq_len(nrow(main_age_obs))) {
  r <- main_age_obs[j, ]
  age_label <- gsub("AGE_BIN", "", r$term)
  sig <- ifelse(r$p.value < .001, "***",
         ifelse(r$p.value < .01, "**",
         ifelse(r$p.value < .05, "*", "")))
  cat(sprintf("  %-10s %+10.4f %10.4f %10.6f %s\n",
              age_label, r$estimate, r$std.error, r$p.value, sig))
}

# Effect sizes
pooled_sd_obs <- sd(df_obs$RISK_SCORE, na.rm = TRUE)
cat(sprintf("\n  Pooled SD: %.4f\n", pooled_sd_obs))
cat(sprintf("  15-17 observed boost d = %.3f\n",
            social_ref_obs$estimate / pooled_sd_obs))

# ══════════════════════════════════════════════════════════════════════
# SENSITIVITY: COLLAPSED 12-17 vs 21-30+ (teen vs adult)
# Both decompositions with binary age grouping
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("COLLAPSED TEEN (12-17) vs ADULT (21-30+) MODERATION\n")
cat(strrep("=", 70), "\n\n")

# --- CO-OFFENDING: teen vs adult ---
cat("--- CO-OFFENDING (group vs truly alone) ---\n\n")

df_co2 <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
df_co2 <- df_co2 %>% filter(crimetype_raw %in% as.character(1:17))
df_co2 <- df_co2 %>% filter(social_crime %in% c("alone", "group"))

df_co2$AGE_BIN <- ifelse(df_co2$solo_group_crime == "solo", df_co2$age_solo,
                  ifelse(df_co2$solo_group_crime == "group", df_co2$youngest_multiple, NA))

df_co2$SOCIAL_COOFF <- ifelse(df_co2$social_crime == "group", "social", "alone")

df_co2 <- df_co2 %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL_COOFF %in% c("alone", "social"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

df_co2$RISK_SCORE <- as.numeric(df_co2$RISK_SCORE)
df_co2 <- df_co2 %>% filter(!is.na(RISK_SCORE))

# Collapse: 12-17 = teen, 21-30+ = adult, drop Under 12 and 18-20
df_co2$AGE_COLLAPSED <- ifelse(df_co2$AGE_BIN %in% c("12-14", "15-17"), "teen_12_17",
                        ifelse(df_co2$AGE_BIN %in% c("21-29", "30+"), "adult_21_30", NA))
df_co2 <- df_co2 %>% filter(!is.na(AGE_COLLAPSED))
cat("Co-offending collapsed sample:", format(nrow(df_co2), big.mark = ","), "\n")

df_co2$AGE_COLLAPSED <- factor(df_co2$AGE_COLLAPSED, levels = c("teen_12_17", "adult_21_30"))
df_co2$SOCIAL_COOFF <- factor(df_co2$SOCIAL_COOFF, levels = c("alone", "social"))

svy_co2 <- svydesign(ids = ~V2118,
                     strata = ~interaction(YR_GRP, V2117),
                     weights = ~incident_weight,
                     data = df_co2, nest = TRUE)

# Descriptive means
cat("\n  Descriptive means:\n")
for (ag in c("teen_12_17", "adult_21_30")) {
  for (s in c("alone", "social")) {
    sub <- subset(svy_co2, AGE_COLLAPSED == ag & SOCIAL_COOFF == s)
    m <- svymean(~RISK_SCORE, sub, na.rm = TRUE)
    n <- nrow(sub$variables)
    cat(sprintf("    %-12s %-8s: M=%.4f (SE=%.4f) N=%s\n",
                ag, s, coef(m), SE(m), format(n, big.mark = ",")))
  }
  # Boost
  sub_a <- subset(svy_co2, AGE_COLLAPSED == ag & SOCIAL_COOFF == "alone")
  sub_s <- subset(svy_co2, AGE_COLLAPSED == ag & SOCIAL_COOFF == "social")
  gap <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE)) -
         coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
  cat(sprintf("    %-12s boost: %+.1f pp\n\n", ag, gap * 100))
}

# F-change test
model_add_co2 <- svyglm(RISK_SCORE ~ AGE_COLLAPSED + SOCIAL_COOFF,
                          design = svy_co2, family = gaussian())
model_int_co2 <- svyglm(RISK_SCORE ~ AGE_COLLAPSED * SOCIAL_COOFF,
                          design = svy_co2, family = gaussian())

ftest_co2 <- regTermTest(model_int_co2, ~AGE_COLLAPSED:SOCIAL_COOFF)
cat(sprintf("  Wald F(%d, %d) = %.4f\n", ftest_co2$df, ftest_co2$ddf, ftest_co2$Ftest))
cat(sprintf("  p = %.10f\n", ftest_co2$p))

res_co2 <- tidy(model_int_co2, conf.int = TRUE)
cat("\n  Full model coefficients:\n")
for (j in seq_len(nrow(res_co2))) {
  r <- res_co2[j, ]
  cat(sprintf("    %-45s B=%+.4f SE=%.4f p=%.6f\n",
              r$term, r$estimate, r$std.error, r$p.value))
}

# Teen boost and adult boost
teen_boost_co <- res_co2 %>% filter(term == "SOCIAL_COOFFsocial")
int_co <- res_co2 %>% filter(grepl(":", term))
adult_boost_co <- teen_boost_co$estimate + int_co$estimate[1]
cat(sprintf("\n  Teen (12-17) co-offending boost: %+.4f (%+.1f pp)\n",
            teen_boost_co$estimate, teen_boost_co$estimate * 100))
cat(sprintf("  Adult (21-30+) co-offending boost: %+.4f (%+.1f pp)\n",
            adult_boost_co, adult_boost_co * 100))
cat(sprintf("  Difference (interaction): %+.4f, p = %.6f\n",
            int_co$estimate[1], int_co$p.value[1]))

# --- OBSERVED: teen vs adult ---
cat("\n\n--- BYSTANDER OBSERVATION (observed vs truly alone, solo only) ---\n\n")

df_obs2 <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
df_obs2 <- df_obs2 %>% filter(crimetype_raw %in% as.character(1:17))
df_obs2 <- df_obs2 %>% filter(solo_group_crime == "solo")

df_obs2$AGE_BIN <- df_obs2$age_solo
df_obs2$SOCIAL_OBS <- ifelse(df_obs2$social_crime == "observed", "social", "alone")

df_obs2 <- df_obs2 %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL_OBS %in% c("alone", "social"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

df_obs2$RISK_SCORE <- as.numeric(df_obs2$RISK_SCORE)
df_obs2 <- df_obs2 %>% filter(!is.na(RISK_SCORE))

# Collapse
df_obs2$AGE_COLLAPSED <- ifelse(df_obs2$AGE_BIN %in% c("12-14", "15-17"), "teen_12_17",
                         ifelse(df_obs2$AGE_BIN %in% c("21-29", "30+"), "adult_21_30", NA))
df_obs2 <- df_obs2 %>% filter(!is.na(AGE_COLLAPSED))
cat("Observed collapsed sample:", format(nrow(df_obs2), big.mark = ","), "\n")

df_obs2$AGE_COLLAPSED <- factor(df_obs2$AGE_COLLAPSED, levels = c("teen_12_17", "adult_21_30"))
df_obs2$SOCIAL_OBS <- factor(df_obs2$SOCIAL_OBS, levels = c("alone", "social"))

svy_obs2 <- svydesign(ids = ~V2118,
                      strata = ~interaction(YR_GRP, V2117),
                      weights = ~incident_weight,
                      data = df_obs2, nest = TRUE)

# Descriptive means
cat("\n  Descriptive means:\n")
for (ag in c("teen_12_17", "adult_21_30")) {
  for (s in c("alone", "social")) {
    sub <- subset(svy_obs2, AGE_COLLAPSED == ag & SOCIAL_OBS == s)
    m <- svymean(~RISK_SCORE, sub, na.rm = TRUE)
    n <- nrow(sub$variables)
    cat(sprintf("    %-12s %-8s: M=%.4f (SE=%.4f) N=%s\n",
                ag, s, coef(m), SE(m), format(n, big.mark = ",")))
  }
  sub_a <- subset(svy_obs2, AGE_COLLAPSED == ag & SOCIAL_OBS == "alone")
  sub_s <- subset(svy_obs2, AGE_COLLAPSED == ag & SOCIAL_OBS == "social")
  gap <- coef(svymean(~RISK_SCORE, sub_s, na.rm = TRUE)) -
         coef(svymean(~RISK_SCORE, sub_a, na.rm = TRUE))
  cat(sprintf("    %-12s boost: %+.1f pp\n\n", ag, gap * 100))
}

# F-change test
model_add_obs2 <- svyglm(RISK_SCORE ~ AGE_COLLAPSED + SOCIAL_OBS,
                           design = svy_obs2, family = gaussian())
model_int_obs2 <- svyglm(RISK_SCORE ~ AGE_COLLAPSED * SOCIAL_OBS,
                           design = svy_obs2, family = gaussian())

ftest_obs2 <- regTermTest(model_int_obs2, ~AGE_COLLAPSED:SOCIAL_OBS)
cat(sprintf("  Wald F(%d, %d) = %.4f\n", ftest_obs2$df, ftest_obs2$ddf, ftest_obs2$Ftest))
cat(sprintf("  p = %.10f\n", ftest_obs2$p))

res_obs2 <- tidy(model_int_obs2, conf.int = TRUE)
cat("\n  Full model coefficients:\n")
for (j in seq_len(nrow(res_obs2))) {
  r <- res_obs2[j, ]
  cat(sprintf("    %-45s B=%+.4f SE=%.4f p=%.6f\n",
              r$term, r$estimate, r$std.error, r$p.value))
}

teen_boost_obs <- res_obs2 %>% filter(term == "SOCIAL_OBSsocial")
int_obs <- res_obs2 %>% filter(grepl(":", term))
adult_boost_obs <- teen_boost_obs$estimate + int_obs$estimate[1]
cat(sprintf("\n  Teen (12-17) observed boost: %+.4f (%+.1f pp)\n",
            teen_boost_obs$estimate, teen_boost_obs$estimate * 100))
cat(sprintf("  Adult (21-30+) observed boost: %+.4f (%+.1f pp)\n",
            adult_boost_obs, adult_boost_obs * 100))
cat(sprintf("  Difference (interaction): %+.4f, p = %.6f\n",
            int_obs$estimate[1], int_obs$p.value[1]))

cat("\n\nDone.\n")
