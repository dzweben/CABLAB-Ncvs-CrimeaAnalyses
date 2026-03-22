#!/usr/bin/env Rscript
# ===========================================================================
# 07 — Risk-Taking Moderation (Unweighted Sensitivity)
#
# Replicates the Analysis 2 moderation using unweighted OLS to verify
# results are not driven by survey weights.
#
# Input:  data/derived/ncvs-risk-merged-1993-2024.csv
# Output: Console (statistics used in manuscript generator)
#
# Supports: Supplement — Unweighted Analyses
# ===========================================================================

library(dplyr)
library(broom)

cat("\n", strrep("=", 70), "\n")
cat("UNWEIGHTED RISK-TAKING MODERATION ANALYSIS\n")
cat(strrep("=", 70), "\n\n")

# ── Read and filter ──
df <- read.csv("data/derived/ncvs-risk-merged-1993-2024.csv", stringsAsFactors = FALSE)
df <- df %>% filter(crimetype_raw %in% as.character(1:17))

# ── Create unified AGE_BIN ──
df$AGE_BIN <- ifelse(df$solo_group_crime == "solo", df$age_solo,
              ifelse(df$solo_group_crime == "group", df$youngest_multiple, NA))

valid_bins <- c("Under 12", "12-14", "15-17", "18-20", "21-29", "30+")

df <- df %>%
  filter(AGE_BIN %in% valid_bins,
         SOCIAL2 %in% c("alone", "social"),
         !is.na(incident_weight), incident_weight > 0,
         V2117 != "", V2118 != "")

df$RISK_SCORE <- as.numeric(df$RISK_SCORE)
df <- df %>% filter(!is.na(RISK_SCORE))

cat("Analysis sample (unweighted N):", format(nrow(df), big.mark = ","), "\n")

# ── Factor setup: 15-17 as reference ──
df$AGE_BIN <- factor(df$AGE_BIN,
                     levels = c("15-17", "Under 12", "12-14", "18-20", "21-29", "30+"))
df$SOCIAL2 <- factor(df$SOCIAL2, levels = c("alone", "social"))

age_order <- c("Under 12", "12-14", "15-17", "18-20", "21-29", "30+")

# ══════════════════════════════════════════════════════════════════════
# DESCRIPTIVE TABLE: Unweighted means
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("DESCRIPTIVE TABLE: Unweighted Mean RISK_SCORE\n")
cat(strrep("=", 70), "\n\n")

cat(sprintf("  %-7s %-8s %8s %8s %8s\n", "Age", "Context", "Mean", "SD", "N"))
cat(sprintf("  %s\n", strrep("-", 48)))

for (ab in age_order) {
  for (s in c("alone", "social", "TOTAL")) {
    if (s == "TOTAL") {
      sub <- df %>% filter(AGE_BIN == ab)
    } else {
      sub <- df %>% filter(AGE_BIN == ab, SOCIAL2 == s)
    }
    m <- mean(sub$RISK_SCORE, na.rm = TRUE)
    s_d <- sd(sub$RISK_SCORE, na.rm = TRUE)
    n <- nrow(sub)
    cat(sprintf("  %-7s %-8s %8.4f %8.4f %8s\n",
                ab, s, m, s_d, format(n, big.mark = ",")))
  }
  cat("\n")
}

# Social boost (social - alone) at each age
cat("  Solo → Social gap by age (unweighted):\n")
for (ab in age_order) {
  sub_a <- df %>% filter(AGE_BIN == ab, SOCIAL2 == "alone")
  sub_s <- df %>% filter(AGE_BIN == ab, SOCIAL2 == "social")
  m_a <- mean(sub_a$RISK_SCORE, na.rm = TRUE)
  m_s <- mean(sub_s$RISK_SCORE, na.rm = TRUE)
  gap <- m_s - m_a
  cat(sprintf("    %-7s: %+.4f (%+.1f pp)\n", ab, gap, gap * 100))
}

# ══════════════════════════════════════════════════════════════════════
# DESCRIPTIVE AGE GRADIENT: RISK_SCORE ~ AGE_BIN (unweighted OLS)
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("DESCRIPTIVE AGE GRADIENT: RISK_SCORE ~ AGE_BIN (unweighted, ref: 15-17)\n")
cat(strrep("=", 70), "\n\n")

model1 <- lm(RISK_SCORE ~ AGE_BIN, data = df)
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

# ══════════════════════════════════════════════════════════════════════
# MODERATION ANALYSIS (unweighted OLS)
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("MODERATION ANALYSIS (unweighted OLS)\n")
cat(strrep("=", 70), "\n\n")

# ── Step 1: Additive model ──
model_additive <- lm(RISK_SCORE ~ AGE_BIN + SOCIAL2, data = df)

# ── Step 2: Interaction model ──
model_interaction <- lm(RISK_SCORE ~ AGE_BIN * SOCIAL2, data = df)
res_int <- tidy(model_interaction, conf.int = TRUE)

cat("Interaction model coefficients:\n\n")
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

# ── Step 3: F-change test ──
cat("\n\nF-CHANGE TEST (additive vs interaction)\n\n")
ftest <- anova(model_additive, model_interaction)
cat("  ANOVA comparison:\n")
print(ftest)

# Extract F and p
f_val <- ftest$F[2]
p_val <- ftest$`Pr(>F)`[2]
df1 <- ftest$Df[2]
df2 <- ftest$Res.Df[2]
cat(sprintf("\n  F(%d, %d) = %.4f, p = %.10f\n", df1, df2, f_val, p_val))

if (p_val < .001) {
  cat("  >>> MODERATION IS SIGNIFICANT (p < .001)\n")
} else if (p_val < .05) {
  cat(sprintf("  >>> MODERATION IS SIGNIFICANT (p = %.4f)\n", p_val))
} else {
  cat(sprintf("  >>> MODERATION IS NOT SIGNIFICANT (p = %.4f)\n", p_val))
}

# ── Step 4a: Interaction coefficients ──
cat("\n\n", strrep("-", 70), "\n")
cat("INTERACTION COEFFICIENTS (unweighted)\n")
cat("Each tests: is this age's social boost different from 15-17's?\n")
cat(strrep("-", 70), "\n\n")

social_15_17 <- res_int %>% filter(term == "SOCIAL2social")
cat(sprintf("  Reference social boost (15-17): %+.4f (SE=%.4f, p=%.6f)\n",
            social_15_17$estimate, social_15_17$std.error, social_15_17$p.value))

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

# ── Step 4b: Simple effects of age at SOCIAL2=alone ──
cat("\n\n", strrep("-", 70), "\n")
cat("SIMPLE EFFECTS OF AGE AT SOCIAL2=alone (unweighted)\n")
cat(strrep("-", 70), "\n\n")

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

# ══════════════════════════════════════════════════════════════════════
# EFFECT SIZES
# ══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 70), "\n")
cat("EFFECT SIZES (unweighted)\n")
cat(strrep("=", 70), "\n\n")

pooled_sd <- sd(df$RISK_SCORE, na.rm = TRUE)
cat(sprintf("  Pooled SD of RISK_SCORE: %.4f\n\n", pooled_sd))

cat("  Descriptive age gradient (full sample, from age-only model):\n")
for (ab in c("Under 12", "12-14", "18-20", "21-29", "30+")) {
  term_name <- paste0("AGE_BIN", ab)
  b <- res1 %>% filter(term == !!term_name)
  if (nrow(b) > 0) {
    d <- b$estimate / pooled_sd
    cat(sprintf("    %-7s vs 15-17: B = %+.4f, d = %.3f, p = %.6f\n",
                ab, b$estimate, d, b$p.value))
  }
}

cat("\n  Age gradient among solo offenders (from interaction model):\n")
for (j in seq_len(nrow(main_age_terms))) {
  r <- main_age_terms[j, ]
  age_label <- gsub("AGE_BIN", "", r$term)
  d <- r$estimate / pooled_sd
  cat(sprintf("    %-7s vs 15-17: B = %+.4f, d = %.3f, p = %.6f\n",
              age_label, r$estimate, d, r$p.value))
}

cat("\n  Social boost effect sizes:\n")
d_ref <- social_15_17$estimate / pooled_sd
cat(sprintf("    15-17 social boost: B = %+.4f, d = %.3f\n",
            social_15_17$estimate, d_ref))
for (j in seq_len(nrow(int_terms))) {
  r <- int_terms[j, ]
  age_label <- gsub("AGE_BIN|:SOCIAL2social", "", r$term)
  total_boost <- social_15_17$estimate + r$estimate
  d <- total_boost / pooled_sd
  cat(sprintf("    %-7s social boost: B = %+.4f, d = %.3f\n",
              age_label, total_boost, d))
}

cat("\n\nDone.\n")
