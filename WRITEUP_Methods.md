# Method

## Data source and study period
Data were drawn from the National Crime Victimization Survey (NCVS) and aggregated across survey years 2014–2022. The NCVS is a nationally representative, stratified multistage household survey administered by the U.S. Census Bureau for the Bureau of Justice Statistics (BJS) that captures criminal victimization experiences, including incidents that may not be reported to police.

## Unit of analysis and analytic samples
The unit of analysis for the present study was the incident. Incidents were classified into four analytic scopes: (a) **Total** (all incidents in the merged 2014–2022 analytic file), (b) **Theft**, (c) **Violent**, and (d) a **Total backup definition** used to evaluate robustness under an alternative operationalization of “social” offending (described below). For each scope, incidents were assigned to an offender age group based on the scoring rules implemented in the project notebooks (solo incidents were assigned the solo offender’s age; group incidents were duplicated and attributed to the youngest and oldest co-offender age brackets to preserve the intended “range” representation used by the original scoring pipeline).

Age group categories were: **Under 12**, **12–14**, **15–17**, **18–20**, **21–29**, and **30+**.

## Measures
### Social context of the incident (primary definition)
The primary social-context measure categorized incidents as **alone**, **group**, or **observed** (i.e., a third category reflecting being observed/witnessed rather than co-offending). This trichotomous measure corresponds to the `social_crime` variable present in the merged incident-level analytic files used by the weighted pipelines.

### Social context of the incident (backup definition: “co-offending only”)
To evaluate whether the substantive pattern of results depended on treating observation/witnessing as “social,” we conducted a total-sample backup analysis in which **social offending was defined strictly as co-offending**. In this backup definition, incidents were categorized as **group** (co-offending) versus **alone** (solo). This operationalization aligns with a common framing in the co-offending literature in which “social” offending is reserved for group offending.

## Statistical approach
### Weighted, design-based inference (primary analyses)
Primary inferential analyses used NCVS incident weights and replicate weights to obtain design-consistent point estimates and variance estimates. Specifically, we created replicate-weight survey designs using **Fay’s balanced repeated replication (BRR)** with **160 replicate weights** (`VICREPWGT1`–`VICREPWGT160`) and Fay’s coefficient **\(\rho = .30\)**. All survey-weighted models were implemented using the `survey` package in R via `svrepdesign(..., type = "Fay", rho = 0.3, mse = TRUE)`.

For categorical comparisons across age groups, we used design-based omnibus tests (Rao–Scott adjusted tests reported as **F** statistics) followed by pairwise comparisons with familywise control via Bonferroni adjustment, consistent with the project’s scoring notebooks.

For modeling the likelihood of solo offending, we fit survey-weighted logistic regressions (`svyglm(..., family = binomial())`) and reported **odds ratios (ORs)** with **95% confidence intervals**.

To directly evaluate whether emerging-adult ages (18–20) more closely resembled adolescent ages (15–17) or adult ages, we ran logistic models using two reference categories: **15–17** and **18–20**.

### Unweighted robustness checks (supplemental analyses)
As a supplemental robustness check, we reran descriptives and inferential tests **without weights** (standard chi-square tests and standard logistic regression). These analyses were intended to assess whether the direction and general pattern of results were consistent when analyses were conducted on the raw analytic sample rather than the design-weighted estimand.

## Reporting strategy
All Results are reported with an emphasis on **effect magnitudes** (e.g., differences in weighted proportions across age groups and ORs with 95% confidence intervals) alongside inferential statistics. This approach is particularly important for large-scale survey analyses, where high precision can yield statistically significant results even for small differences.
