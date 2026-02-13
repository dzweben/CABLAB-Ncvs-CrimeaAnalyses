# Unweighted supplemental analyses (NCVS)
# Runs: (1) Total (main definition: alone/group/observed), (2) Theft, (3) Violent,
# and (4) Total backup definition (co-offending only social).
#
# Outputs: supplemental/unweighted_outputs/<scope>/*

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(broom)
  library(flextable)
  library(officer)
})

AGE_LEVELS <- c("Under 12", "12–14", "15–17", "18–20", "21–29", "30+")

out_base <- file.path("supplemental", "unweighted_outputs")
dir.create(out_base, recursive = TRUE, showWarnings = FALSE)

normalize_age <- function(x) {
  dplyr::case_when(
    x %in% c("under_12", "Under 12") ~ "Under 12",
    x %in% c("12-14", "12–14") ~ "12–14",
    x %in% c("15-17", "15–17") ~ "15–17",
    x %in% c("18-20", "18–20") ~ "18–20",
    x %in% c("21-29", "21–29") ~ "21–29",
    x == "30+" ~ "30+",
    TRUE ~ as.character(x)
  )
}

read_and_clean <- function(path) {
  df <- read.csv(path)
  df <- df %>% filter(!is.na(incident_weight), incident_weight > 0)
  df[] <- lapply(df, function(col) if (is.character(col)) trimws(col) else col)
  df[df == "N/A"] <- NA
  df <- df %>% mutate(
    age_solo = normalize_age(as.character(age_solo)),
    youngest_multiple = normalize_age(as.character(youngest_multiple)),
    oldest_multiple = normalize_age(as.character(oldest_multiple))
  )
  df
}

# Attribute group incidents to youngest/oldest age brackets (duplicate rows when needed)
attribute_age_rows <- function(df) {
  df <- df %>% mutate(
    solo_flag = solo_group_crime == "solo",
    same_group_age = (!solo_flag) & !is.na(youngest_multiple) & (youngest_multiple == oldest_multiple),
    two_group_ages = (!solo_flag) & !is.na(youngest_multiple) & !is.na(oldest_multiple) & (youngest_multiple != oldest_multiple)
  )

  solo_df <- df %>% filter(solo_flag) %>% mutate(age = age_solo)
  same_age_df <- df %>% filter(!solo_flag & same_group_age) %>% mutate(age = youngest_multiple)
  different_age_df <- df %>% filter(!solo_flag & two_group_ages)
  youngest_rows <- different_age_df %>% mutate(age = youngest_multiple)
  oldest_rows <- different_age_df %>% mutate(age = oldest_multiple)

  bind_rows(solo_df, same_age_df, youngest_rows, oldest_rows) %>%
    select(-solo_flag, -same_group_age, -two_group_ages)
}

# MAIN definition: uses existing merged variable social_crime (alone/group/observed)
# BACKUP definition: co-offending only => group vs alone
build_social_vars <- function(df, kind=c("main","backup")) {
  kind <- match.arg(kind)
  if (kind == "main") {
    df %>% mutate(
      social_kind = factor(social_crime, levels=c("alone","observed","group"))
    )
  } else {
    df %>% mutate(
      social_kind = factor(dplyr::case_when(
        solo_group_crime == "group" ~ "group",
        solo_group_crime == "solo" ~ "alone",
        TRUE ~ NA_character_
      ), levels=c("alone","group"))
    )
  }
}

# Descriptives: counts + row percents by age and social_kind
summarize_counts <- function(df) {
  tab <- df %>%
    filter(age %in% AGE_LEVELS) %>%
    filter(!is.na(social_kind)) %>%
    count(age, social_kind, name="n") %>%
    tidyr::pivot_wider(names_from=social_kind, values_from=n, values_fill=0) %>%
    arrange(factor(age, levels=AGE_LEVELS))

  tab$grand_total <- rowSums(tab[ , setdiff(names(tab), "age"), drop=FALSE])

  pct <- tab
  crime_cols <- setdiff(names(tab), c("age","grand_total"))
  pct[crime_cols] <- round(100 * pct[crime_cols] / pct$grand_total, 2)

  list(counts=tab, pct=pct)
}

# Chi-square omnibus + pairwise (Bonferroni across all pairwise age comparisons)
chi_suite <- function(df) {
  # binary: solo vs group (consistent with earlier code)
  dd <- df %>%
    filter(age %in% AGE_LEVELS, solo_group_crime %in% c("solo","group")) %>%
    mutate(
      age = factor(age, levels=AGE_LEVELS),
      is_solo = factor(ifelse(solo_group_crime=="solo","Solo","Group"), levels=c("Group","Solo"))
    )

  # Omnibus
  omni <- chisq.test(table(dd$is_solo, dd$age))

  # Pairwise
  pairs <- combn(AGE_LEVELS, 2, simplify=FALSE)
  pw <- lapply(pairs, function(pr) {
    sub <- dd %>% filter(age %in% pr)
    tt <- table(sub$is_solo, sub$age)
    # if sparse, fall back to fisher
    if (any(tt < 5)) {
      ft <- fisher.test(tt)
      data.frame(group1=pr[1], group2=pr[2], test="Fisher", statistic=NA, df=NA, p_value=ft$p.value)
    } else {
      ct <- suppressWarnings(chisq.test(tt))
      data.frame(group1=pr[1], group2=pr[2], test="Chi-squared", statistic=unname(ct$statistic), df=unname(ct$parameter), p_value=ct$p.value)
    }
  })
  pw <- bind_rows(pw) %>% mutate(p_bonferroni = p.adjust(p_value, method="bonferroni"))

  list(
    omnibus = data.frame(test="Chi-squared omnibus", statistic=unname(omni$statistic), df=unname(omni$parameter), p_value=omni$p.value),
    pairwise = pw
  )
}

# Logistic regression using aggregated counts: outcome = alone vs not-alone (group + observed)
logit_suite <- function(counts_df, ref_level) {
  df <- counts_df
  # Ensure columns exist
  if (!"alone" %in% names(df)) stop("counts_df must have an 'alone' column")
  df <- df %>% mutate(
    age_group = factor(age, levels=AGE_LEVELS)
  )
  df$age_group <- relevel(df$age_group, ref=ref_level)

  m <- glm(cbind(alone, grand_total - alone) ~ age_group, data=df, family=binomial())
  broom::tidy(m) %>% mutate(
    OR = exp(estimate),
    OR_low = exp(estimate - 1.96*std.error),
    OR_high = exp(estimate + 1.96*std.error)
  )
}

save_docx <- function(tables_named, path) {
  # tables_named: named list of data.frames or flextable
  items <- lapply(tables_named, function(x) {
    if (inherits(x, "flextable")) x else flextable(x)
  })
  do.call(save_as_docx, c(items, list(path=path)))
}

run_scope <- function(scope_name, input_csv, kind=c("main","backup")) {
  kind <- match.arg(kind)
  message("\n--- Running ", scope_name, " (", kind, ") ---")

  df <- read_and_clean(input_csv) %>% attribute_age_rows() %>% build_social_vars(kind=kind)

  out_dir <- file.path(out_base, scope_name)
  dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)

  desc <- summarize_counts(df)
  write.csv(desc$counts, file.path(out_dir, "descriptives_counts.csv"), row.names=FALSE)
  write.csv(desc$pct, file.path(out_dir, "descriptives_percentages.csv"), row.names=FALSE)

  chi <- chi_suite(df)
  write.csv(chi$omnibus, file.path(out_dir, "chi_square_omnibus.csv"), row.names=FALSE)
  write.csv(chi$pairwise, file.path(out_dir, "chi_square_pairwise_bonferroni.csv"), row.names=FALSE)

  # Logistic regressions (two anchors)
  logit_1517 <- logit_suite(desc$counts, ref_level="15–17")
  logit_1820 <- logit_suite(desc$counts, ref_level="18–20")
  write.csv(logit_1517, file.path(out_dir, "logit_ref_15-17.csv"), row.names=FALSE)
  write.csv(logit_1820, file.path(out_dir, "logit_ref_18-20.csv"), row.names=FALSE)

  # A single DOCX bundle for easy supplemental inclusion
  save_docx(list(
    "Descriptives (counts)" = desc$counts,
    "Descriptives (percentages)" = desc$pct,
    "Chi-square omnibus" = chi$omnibus,
    "Chi-square pairwise (Bonferroni)" = chi$pairwise,
    "Logit ORs (ref 15–17)" = logit_1517,
    "Logit ORs (ref 18–20)" = logit_1820
  ), file.path(out_dir, paste0(scope_name, "_SUPPLEMENT_unweighted.docx")))

  invisible(TRUE)
}

# 4 analyses requested
run_scope("total_main",   "ncvs-merged-data-2014-2022.csv", kind="main")
run_scope("theft_main",   "theft-ncvs-merged-data-2014-2022.csv", kind="main")
run_scope("violent_main", "violent-ncvs-merged-data-2014-2022.csv", kind="main")
run_scope("total_backup_cooffending_only", "ncvs-merged-data-2014-2022.csv", kind="backup")

message("\nAll unweighted supplemental analyses complete. Outputs in: ", out_base)
