# PMOM Neutralization — Leaf-Level Diagnostic Report

**Project:** `Felix_Research/PMOM_neut/`
**Date:** May 2026
**Scope:** Value + Quality leaves across 5 universes (SPX, MXEA, MXWO, MXEF, MXAP)

---

## 1. Question

The PMOM neutralization step (`PMR_P_` track) is supposed to strip price-momentum
exposure out of every factor before they are aggregated. We wanted to answer:

1. **Did it work?** How much PMOM exposure was actually removed per leaf?
2. **Where was PMOM hiding the most?** Which leaves carried the biggest raw PMOM bias?
3. **Why?** What property of a leaf (signal stability, transmission channel, …)
   makes it carry more PMOM than another in the same sub-theme?

---

## 2. Data & method

- **Production track** (no prefix) = pre-PMOM-neutralization factor values
  (already neutralized for `Size, VolZsTrad, BetaZs, LEV`).
- **`PMR_P_` track** = post-PMOM-neutralization factor values
  (also neutralized for `PMOM_3SLOW`).
- **Raw track** = pre-any-neutralization values from `cache/<U>/alpha.parquet`.
- 13 leaves analysed (from `DICT_WEIGHTS_LEAF`):
  - Value-passthrough: `TYTD2EV1Y`
  - FCF Value: `FCF2EV1Y`, `FCF2EVZs5Y`
  - Earnings Value: `E2P`, `EBIT2EV1Y`, `EBITDA2EV1Y`, `NOPAT2EV1Y`
  - Profit: `GP1Y`, `FCF2A1Y`
  - Investment: `AssetGrowthSlope5`, `IssuanceGrowthSlope5`,
    `ExtGrowthSlope5`, `AssetGrowthNReSlope5`
- Daily cross-sectional regressions / correlations of each leaf vs `PMOM_3SLOW`.

---

## 3. Scripts produced

All under [Felix_Research/PMOM_neut/analysis/](.):

| Script | Purpose | Output |
|---|---|---|
| [leaf_pmom_removal_diagnostic.py](leaf_pmom_removal_diagnostic.py) | Quantify PMOM removed per leaf (production → `PMR_P_`) | [output/leaf_pmom_removal.csv](../output/leaf_pmom_removal.csv) |
| [leaf_stability_vs_pmom_bias.py](leaf_stability_vs_pmom_bias.py) | Test A — month-over-month rank stability vs PMOM bias | [output/leaf_stability_vs_pmom_bias.csv](../output/leaf_stability_vs_pmom_bias.csv) + PNG |
| [leaf_rf_absorption_diagnostic.py](leaf_rf_absorption_diagnostic.py) | Test B — 3-stage decomposition RAW → standard RFs → +PMOM | [output/leaf_rf_absorption.csv](../output/leaf_rf_absorption.csv) + PNG |
| [_combined_stability_vs_raw_rho.py](_combined_stability_vs_raw_rho.py) | Joins the two diagnostic CSVs into one ranked view | (prints to console) |

---

## 4. Results

### 4.1 Neutralization works (β_P ≈ 0)

For every leaf in every universe, the post-`PMR_P_` PMOM beta collapses to ~0
(`beta_P_PMOM` column of `leaf_pmom_removal.csv`). The neutralization step is
doing what it claims to do — there is no residual PMOM exposure to harvest by
re-neutralizing.

### 4.2 Pre-neutralization PMOM bias is concentrated in a few leaves

Pooled medians across the 5 universes, sorted by raw |corr(factor, PMOM)|:

| Factor | Subtheme | stability | \|ρ_RAW\| | \|ρ_B\| | \|ρ_P\| |
|---|---|---:|---:|---:|---:|
| FCF2A1Y | Profit | 0.947 | **0.097** | 0.087 | 0.005 |
| EBITDA2EV1Y | Earnings_Value | 0.950 | **0.087** | 0.131 | 0.009 |
| EBIT2EV1Y | Earnings_Value | 0.945 | **0.070** | 0.071 | 0.009 |
| AssetGrowthSlope5 | Investment | 0.986 | 0.064 | 0.035 | 0.006 |
| ExtGrowthSlope5 | Investment | 0.978 | 0.064 | 0.046 | 0.004 |
| FCF2EVZs5Y | FCF_Value | 0.908 | 0.055 | 0.021 | 0.010 |
| IssuanceGrowthSlope5 | Investment | 0.982 | 0.053 | 0.042 | 0.007 |
| NOPAT2EV1Y | Earnings_Value | 0.940 | 0.051 | 0.012 | 0.011 |
| FCF2EV1Y | FCF_Value | 0.936 | 0.050 | 0.076 | 0.005 |
| GP1Y | Profit | 0.966 | 0.050 | 0.021 | 0.002 |
| AssetGrowthNReSlope5 | Investment | 0.982 | 0.049 | 0.025 | 0.003 |
| E2P | Earnings_Value | 0.957 | 0.035 | 0.012 | 0.001 |
| TYTD2EV1Y | Value-passthrough | 0.901 | 0.033 | 0.047 | 0.005 |

- `ρ_RAW` — pre-any-neutralization
- `ρ_B` — after standard RFs (Size, VolZsTrad, BetaZs, LEV)
- `ρ_P` — after also neutralizing `PMOM_3SLOW`

### 4.3 Effect of the standard RFs on PMOM bias

For most leaves, neutralizing the four standard RFs *reduces* |ρ| with PMOM
(`Drop_StdRFs > 0`), but for **EBIT2EV1Y / EBITDA2EV1Y / FCF2EV1Y / TYTD2EV1Y**
the standard RFs slightly **amplify** PMOM bias (`Drop_StdRFs < 0`). The size /
volatility / beta tilts inside those leaves were partially *masking* the PMOM
tilt; once removed, more PMOM exposure becomes visible and must be cleaned up
by the dedicated `PMOM_3SLOW` step.

### 4.4 Test A — stability vs raw PMOM bias

Spearman rank correlation across leaves between `stability` and `|ρ_RAW|`:

| Universe | All 13 leaves | Value-only (7 leaves) |
|---|---:|---:|
| SPX | −0.13 | +0.36 |
| MXEA | +0.18 | +0.43 |
| MXWO | +0.04 | +0.21 |
| MXEF | −0.46 | −0.64 |
| MXAP | +0.57 | −0.43 |
| **Pooled** | **+0.14** | **+0.36** |

→ A **weak positive** link in Developed Value, but not robust across universes.
Stability is **not** a sufficient explanation for PMOM bias.

---

## 5. Conclusions

1. ✅ **The neutralization works.** No residual PMOM exposure after `PMR_P_`.

2. **PMOM bias is concentrated in three leaves**: `FCF2A1Y`, `EBITDA2EV1Y`,
   `EBIT2EV1Y`. These deserve scrutiny if downstream composites show drift
   between production and `PMR_P_` aggregates.

3. **The "noise story" is partial, not dominant.** Within Earnings_Value the
   ordering EBITDA > EBIT > NOPAT > E2P is consistent with "more stable
   accruals → more PMOM passes through". But **FCF2A1Y carries the highest raw
   PMOM correlation of all leaves despite having no price denominator**,
   which the noise/transmission-channel story alone cannot explain. Likely a
   genuine economic link (high-FCF firms *are* typically PMOM winners).

4. **Investment leaves are the most stable (0.97–0.99) yet carry only mid-range
   PMOM bias (~0.05–0.06).** Stability is necessary but not sufficient — a
   transmission channel (price in denominator, or economic co-movement) is also
   required.

5. **Operational takeaway**: the PMOM neutralization is doing real work and is
   *not* removing equal amounts from every leaf — EBIT/EBITDA-EV and FCF2A1Y
   are where most of the work happens. If those leaves' post-`PMR_P_` rank
   ordering differs materially from production, that is the *intended* effect
   of the step, not a bug.

---

## 6. Caveats

- Pooled medians smooth over real cross-universe heterogeneity (MXEF/MXAP
  rank correlations flip sign vs SPX/MXEA). Single-universe conclusions should
  use the per-universe CSV rows, not the pooled view.
- "Stability" here is month-over-month Spearman rank correlation of the
  factor signal itself; it is a property of the *numerator*, not of the
  factor-vs-PMOM relationship.
- Decomposition Test B is correlation-based, not orthogonal-regression-based —
  numbers should be read as ordinal, not as a strict variance decomposition.
