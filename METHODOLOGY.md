# PMOM Neutralization — Methodology

**Last updated**: 2026-05-13
**Project**: `Felix_Research/PMOM_neut/`
**Companion docs**: [ANALYSIS_NOTES.md](ANALYSIS_NOTES.md), [findings_evp_vs_pmom.md](findings_evp_vs_pmom.md)

This document describes (A) the methodology built into the production analysis script `pmom_neut_analysis.py`, and (B) the ad-hoc investigation methodology used in the Section 4 WFP-variants drill-down (May 2026).

---

## Part A — Production analysis methodology (`pmom_neut_analysis.py`)

### A.1 Research question

Does **PMOM-neutralizing** the Value and Quality factor scores (the "P-track") preserve their alpha while removing the anti-PMOM cross-bet that hurts performance in PMOM-tailwind regimes?

Two tracks are compared end-to-end:

| Track | DB prefix     | Description |
|-------|---------------|-------------|
| B     | `PMR_B_`      | Baseline production scores |
| P     | `PMR_P_`      | Cross-sectionally PMOM-neutralized scores (residualized on PMOM_3SLOW) |

### A.2 Universes & factors

- **Universes (5)**: `SPX Index`, `MXEA Index`, `MXWO Index`, `MXEF Index`, `MXAP Index`
- **Value/Quality sub-themes** (B/P-prefixed): `Earnings_Value`, `FCF_Value`, `Profit`, `Investment`
- **Standalone Value leaf**: `TYTD2EV1Y` (production for B, `PMR_P_` for P)
- **Themes**: `Value`, `Quality` (B/P-prefixed); `PMOM_3SLOW`, `FMOMA`, `FMOMFS` (production-only — identical across tracks)
- **WFP composite variants** (read from `QuantFactorsNTRLZ`):
  - `Baseline` ← `PMR_B_WFP`
  - `P`        ← `PMR_P_WFP` (full V & Q neutralized, then composed)
  - `VP`       ← `PMR_VP_WFP` (Value side only)
  - `EVP`      ← `PMR_EVP_WFP` (EV sub-themes of Value only)

### A.3 Data pipeline

All data is queried once from IDB and cached as parquet under `analysis/cache/`. Subsequent runs read from cache unless `FORCE_RELOAD = True`.

| Cache file                              | Contents |
|-----------------------------------------|----------|
| `unified_factors_btrack.parquet`        | Sub-theme + theme scores, B-track |
| `unified_factors_ptrack.parquet`        | Sub-theme + theme scores, P-track |
| `unified_leaves_btrack.parquet`         | All V/Q leaf scores, B-track |
| `unified_leaves_ptrack.parquet`         | All V/Q leaf scores, P-track |
| `unified_wfp_variants.parquet`          | WFP_B / WFP_P / WFP_VP / WFP_EVP scores |
| `members.parquet`                       | Universe constituents + weights |
| `forward_tr.parquet`                    | 1-month forward total return, CAD, lag=0 |
| `volatility.parquet`                    | `Vol1YTrad`, `Vol3YTrad` |
| `dd_indicator.parquet`                  | `DD`, `DDSmooth` (LenDD=24, LenSmooth=10) |
| `ls_returns_composite.parquet`          | Monthly L/S returns, composites + WFP_3SLOW |
| `ls_returns_wfp_variants.parquet`       | Monthly L/S returns for the 4 WFP variants |

### A.4 L/S portfolio construction (`calc_ls_returns`)

Per `(Universe, Date, Factor)`:

1. **Score → raw holding**: $h_n = \text{score} / \text{Var}$ where $\text{Var} = (\text{Vol})^2$ and Vol = avg of `Vol1YTrad` and `Vol3YTrad`, clipped at 98th pctile per date, annualized $(\times \sqrt{52})$.
2. **Demean**: $h_{mc} = h_n - \overline{h_n}$ (cross-section mean per date).
3. **Scale**: $\text{ActiveWeight} = s_{\max} \cdot h_{mc} / \max(|\min h_{mc}|, \max h_{mc})$ with $s_{\max} = 0.02$. This caps the largest absolute active weight at 2%.
4. **Return**: $r_t = \sum_i \text{ActiveWeight}_{i,t} \cdot \text{ForwardTR}_{i,t}$.

WFP_3SLOW is computed as the equal-weight average of `Value`, `Quality`, `PMOM_3SLOW` L/S returns. WFP variants are loaded as **scores** and the same `calc_ls_returns` is applied to them.

### A.5 DD regime conditioning

`DDSmooth` is the 10-month smoothed drawdown indicator (length 24, monthly). The panel is partitioned into regimes by sign of `DDSmooth`:

- **Low DD** (smooth ≥ 0): risk-on, PMOM typically rewarded
- **High DD** (smooth < 0): risk-off, contrarian / Value tend to win

Stats are computed per regime (Ann Ret, Vol, IR) and contrasted B vs P to test the hypothesis that **neutralization helps in low-DD regimes** (where PMOM is winning and the V/Q anti-PMOM bet is a drag).

### A.6 Standard stats reported

`compute_ir_stats` returns:

- **Ann Ret %** = monthly mean × 12 × 100
- **Vol %**     = monthly std × √12 × 100
- **IR**        = Ann Ret / Vol
- **N months**  = non-null observation count

Cross-universe means are reported as simple averages over the 5 universes.

### A.7 Section map of `pmom_neut_analysis.py`

| Section | Purpose | Output type |
|---------|---------|-------------|
| 1.1 | Full-sample L/S return correlations: PMOM vs V/Q (B vs P) | Correlation matrices |
| 1.2 | Full-sample cross-sectional **score** correlations vs PMOM | Mean + Std of XS corr |
| 1.3 | 24M rolling L/S return correlation vs PMOM | Time series chart |
| 1.4 | Rolling XS score correlation vs PMOM | Time series chart |
| 2.1 | Hierarchical performance table (leaves + sub-themes + themes), B vs P | IR table |
| 2.2 | Theme/composite performance (V, Q, WFP_3SLOW) | IR table |
| 2.3 | Theme-level performance summary | IR table |
| 2.4 | Cumulative L/S return charts | Equity curves |
| 3   | DD regime conditioning — build panel | Panel construction |
| 3.1 | Performance stats by DD state | Regime-IR table |
| 4.1 | WFP variants (B, P, VP, EVP) full-sample performance | IR table |
| 4.2 | WFP variants by DD regime | Regime-IR table |

### A.8 Reading the output

The script is `# %%` cell-structured and runnable interactively (VS Code Python cells / Jupyter). Every section prints a banner and uses `IPython.display.display` for styled DataFrames.

---

## Part B — Section 4 investigation methodology (May 2026 drill-down)

### B.1 Triggering observation

Section 4.1 showed all three neutralized WFP variants (P / VP / EVP) within 0.04 IR of Baseline, with **P slightly worse** in the post-2010 sub-period. This was counter to the prior that "neutralization removes a known drag." Five hypothesis tests were run in sequence.

### B.2 Investigation principle: falsification ladder

Each step is structured as a **falsifiable check** that either (a) rules out a trivial explanation and forces the next step, or (b) localizes the effect. The user's adversarial role ("prove me wrong") was a step in the ladder, not a side conversation.

### B.3 Steps

#### Step 1 — Coverage diagnostic (`_wfp_diagnostic_run.py`)

- **Test**: Compare number of dates, number of QAIDs, and non-null rows for each WFP variant per universe.
- **Decision rule**: If coverage differs → the IR comparison is contaminated by sample selection and is invalid. If identical → continue.
- **Result**: Identical coverage. **Full-window IR equals Common-window IR.** Sample artifact ruled out.

#### Step 2 — Dispersion + score-level correlation

- **Test**: For each variant, compute cross-sectional std of scores per date, and average cross-sectional correlation with Baseline.
- **Decision rule**: If dispersion is identical and correlation ≈ 1.0, the variant is structurally near-identical → IR differences must be tiny by construction.
- **Result**: Score correlations were `B=1.00`, `EVP=0.999`, `VP=0.967`, `P=0.912`. EVP is essentially a no-op at the score level.

#### Step 3 — Sub-period IR

- **Test**: Decompose full-sample IR into pre-2000, 2000–2009, 2010–2019, 2020+ buckets, cross-universe means.
- **Decision rule**: Look for monotonic regime dependence.
- **Result**: P-track wins pre-2010, loses post-2010 — clean regime split. This *suggested* "M-strong regimes hurt neutralization," which the user challenged.

#### Step 4 — Regime hypothesis test (`_wfp_regime_test.py`)

User's counter-hypothesis: *Because PMOM counter-bets EV, neutralizing EV should HELP in PMOM-tailwind regimes.* Three nested tests:

1. **Anchor correlation** — `corr(V_B / EV_B / Q_B L/S returns, PMOM_3SLOW L/S returns)` full-sample, per universe. Establishes whether the cross-bet premise actually holds.
2. **Tercile-conditional delta** — Pool monthly observations across universes. Form trailing-12m PMOM terciles. Compute `mean(WFP_X − WFP_B)` per tercile.
3. **Linear regression** — Pooled OLS: $\Delta = a + b \cdot M_t$, where $M_t$ is contemporaneous PMOM return. Report slope and $R^2$.

Decision rule: If slope is positive AND tercile delta is monotonically increasing in PMOM regime → user's hypothesis confirmed for that delta.

**Result**: Confirmed at the **component** level (EV_delta slope +0.055, R²=0.30) but **reversed** at the **composite** level (WFP_P slope −0.21, R²=0.79). WFP_EVP retains the component-level direction with smaller magnitude.

#### Step 5 — Targeted-year and annual confirmation

- **2024 SPX** (`_wfp_2024_spx.py`): PMOM had a strong year (+11.2%, IR 1.56). Compute cumulative L/S return for each variant and Baseline, then `Variant − Baseline`. Verdict per variant.
- **Annual SPX correlation** (`_wfp_evp_annual_spx.py`): For each calendar year, compound monthly returns to get annual `WFP_EVP`, `WFP_B`, and `PMOM_3SLOW`. Compute `Delta = EVP − B`. Report Pearson and Spearman of `Delta` vs `PMOM_3SLOW`, sign-match count.

Decision rule: If the regime relationship holds out-of-test on a single fresh year AND on the annual aggregate, the finding is robust.

**Result**: 2024 SPX showed EV (P − B) `+0.60 pp`, WFP_EVP `+0.12 pp`, WFP_P `−3.27 pp`. Annual `Delta` vs `M`: Pearson `+0.725`, Spearman `+0.513`, sign-match `25/38`.

### B.4 Mechanism reconstruction

After steps 1–5 closed the empirical question, an analytical explanation was required to make the finding actionable:

- The WFP composite is roughly EW(V, Q, M) of *active weights*.
- B-track V is **anti-M**; this means V and M leg active weights on the same stock often have opposite signs — they cancel partially.
- This cancellation is **risk-reducing diversification**, not just a drag on return.
- Neutralizing V removes the cancellation → WFP_P over-concentrates on M's preferred names.
- Q-track behaves the opposite way: Q_B is **mildly pro-M**, Q_P is mildly anti-M → Q_P subtracts return when M wins.

Net: P-track gains EV's regime hedge but loses V/M overlap diversification and adds Q_P's anti-M drag. Composite slope ends up the wrong sign.

### B.5 Decision the methodology produced

- **Reject**: Replace WFP_B with WFP_P as a drop-in.
- **Accept**: WFP_EVP as the minimum-change operating point — it preserves the score (corr 0.999), picks up the regime hedge in the right direction (Pearson +0.725 annual), and adds no measurable structural drag.
- **Open follow-up**: Rebuild WFP from clean V + clean Q + standalone M as separate legs, rather than swapping cleaned inputs into the existing recipe. The mechanism analysis predicts this should unlock the regime hedge cleanly.

### B.6 Reproducibility

| Step | Script | Cache used |
|------|--------|------------|
| 1, 2, 3 | `_wfp_diagnostic_run.py` | `ls_returns_wfp_variants.parquet`, `unified_wfp_variants.parquet` |
| 4 | `_wfp_regime_test.py` | `ls_returns_composite.parquet`, `ls_returns_wfp_variants.parquet` |
| 5a | `_wfp_2024_spx.py` | same as above |
| 5b | `_wfp_evp_annual_spx.py` | same as above |

All scripts are runnable from `legacy_iAAM/` with:

```powershell
& "venv310/Scripts/python.exe" "Felix_Research/PMOM_neut/analysis/<script>.py"
```

No DB access required after the production caches exist. Caches are regenerated by re-running `pmom_neut_analysis.py` with `FORCE_RELOAD = True`.

---

## Cross-references

- Production analysis: [pmom_neut_analysis.py](pmom_neut_analysis.py)
- Project notes (Section 4 block has the full results): [ANALYSIS_NOTES.md](ANALYSIS_NOTES.md)
- Standalone memo on the EVP-vs-PMOM finding: [findings_evp_vs_pmom.md](findings_evp_vs_pmom.md)
- WFP score construction: `Felix_Research/PMOM_neut/data_creation/07d_ntrlz_wfp_variants.py`
