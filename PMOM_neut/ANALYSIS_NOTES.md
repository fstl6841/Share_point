# PMOM Neutralization Analysis — Notes

**Date started**: 2026-05-12
**Script**: `pmom_neut_analysis.py`
**Universes**: SPX, MXEA, MXWO, MXEF, MXAP
**Data**: `QuantFactorsNTRLZ` (LS_Zstd, P=0, CAD, GF=0, wNB=0)

---

## Data Loading Notes

- **TYTD2EV1Y asymmetric handling**: No `PMR_B_TYTD2EV1Y` exists in DB.
  B-track uses production `TYTD2EV1Y`, P-track uses `PMR_P_TYTD2EV1Y`.
- **Momentum themes** (PMOM_3SLOW, FMOMA, FMOMFS): identical across B/P tracks — always fetched as production (no prefix).
- Cache stored in `./cache/*.parquet`. Set `FORCE_RELOAD = True` to refetch from DB.

---

## Rationale for PMOM Neutralization

### The mechanical problem

Value factors have a **structural anti-momentum bet** embedded in them. Value ratios (E/P, EBIT/EV, EBITDA/EV, etc.) have price or enterprise value in the denominator. When a stock's price rises — which is what momentum rewards — its valuation ratios mechanically deteriorate, making it look "less cheap."

#### Formal derivation

For any valuation ratio F(t) / M(t) (fundamental over market cap), insert an identity:

    F(t)     M(t-1)     M(t-12)     F(t)
    ──── = ──────── × ──────── × ────────
    M(t)     M(t)      M(t-1)     M(t-12)

Taking logs:

    ln(F(t)/M(t)) = ln(M(t-1)/M(t)) + ln(M(t-12)/M(t-1)) + ln(F(t)/M(t-12))

                   = -ln(1 + r(t-1))  -  ln(1 + r(t-12:t-1))  +  ln(F(t)/M(t-12))

Applying the Taylor approximation  ln(1+x) ≈ x :

                   ≈  -r(t-1)         -  r(t-12:t-1)           +  ln(F(t)/M(t-12))
                      ────────            ────────────             ─────────────────
                      = (STREV)           = (PMOM)                lagged fund. yield

This decomposition is **exact** (up to the Taylor approximation) and holds for every ratio of the form F/M, regardless of what F is. Any cross-sectional sort on a valuation ratio mechanically embeds a **negative PMOM bet** and a positive short-term reversal bet.

**Notes:** The derivation uses log returns and a first-order Taylor expansion. The LS_Zstd re-standardization (ranking + z-scoring + winsorization) applied in production will further alter the relationship, but the directional anti-momentum contamination persists.

### Why neutralize in low DD (when PMOM works best)?

The anti-momentum drag hurts most in **low DD** (normal/bull markets):

1. Momentum delivers its strongest returns in low DD environments
2. Value's mechanical short-momentum position creates a **drag** during precisely the periods when momentum is most rewarded
3. Diagnostics confirmed: in low DD, Value and WFP have lower forward returns when Corr(PMOM, Value) < 0 — across every universe
4. Neutralizing removes the momentum contamination, making Value a **purer fundamental bet** independent of momentum

### Why we might NOT want to neutralize in high DD (when PMOM crashes)

In **high DD** (crisis/drawdown), the logic flips:

1. Momentum tends to **crash** in high DD — momentum reversals are well-documented in crisis periods
2. Value's anti-momentum bet, which is a drag in low DD, becomes a **natural hedge** in high DD. Being effectively short momentum when momentum is crashing helps Value returns
3. Diagnostics showed the relationship is mixed in high DD — no consistent evidence that the negative PMOM correlation hurts Value during drawdowns
4. By neutralizing in high DD, you'd **remove this natural hedge**, making Value more exposed during crises

### Asymmetry summary

| DD Regime | PMOM performance | Value's anti-PMOM bet is a... | Neutralize? |
|-----------|-----------------|-------------------------------|-------------|
| Low DD | PMOM works well | **Drag** (short the winner) | Yes — removes drag |
| High DD | PMOM crashes | **Hedge** (short the loser) | No — keep the hedge |

### Why Earnings_Value shows the strongest empirical anti-PMOM correlation

The derivation above shows the $-\text{PMOM}$ term is **identical** for every ratio F/M, regardless of what F is. So the mechanism is equally strong for Earnings_Value, FCF_Value, and TYTD2EV1Y.

The empirical difference comes from the **residual term** $\ln(F_t / M_{t-12})$:

- **Earnings_Value** (E2P, EBIT/EV, EBITDA/EV, NOPAT/EV): Numerators are trailing accounting earnings — updated quarterly, very sticky month-to-month. The residual term adds little cross-sectional variation, so the $-\text{PMOM}$ component is a **larger share** of total variance → highest measured anti-PMOM correlation (avg XS ρ ≈ −0.05).
- **FCF_Value** (FCF2EV1Y, FCF2EVZs5Y): Free cash flow is noisier (lumpy capex, seasonal working capital). More independent variation in the residual **dilutes** the anti-PMOM signal, even though the mechanism is identical.
- **TYTD2EV1Y** (total yield to EV): Includes dividends + buybacks. Buyback yields tend to increase for momentum winners (strong stock → confident management → share repurchases), creating a partial **pro-momentum offset** in the numerator that cancels some of the denominator effect.

In short: Earnings_Value is not more *mechanically* anti-momentum — the mechanism is just **less diluted** by numerator noise. If only one sub-theme were to be neutralized, it would be the priority target.

### Implementation path: regime-conditional neutralization

The trailing correlation sign-split (Corr(PMOM, V) < 0 vs ≥ 0) was diagnostic — it confirmed the mechanism but would be noisy and impractical as a live signal.

**DD level** is the natural switch:
- Already computed in production (`QuantDDIndicator`, DDSmooth)
- Directly maps to the rationale (neutralize when PMOM works, keep hedge when it doesn't)
- Binary regime switch — simpler than a continuous correlation signal
- More robust — DD state changes slowly, less prone to whipsaw

Implementation: at each rebalance, check DDSmooth. Low DD → use `PMR_P_` (neutralized) scores for Value/Quality. High DD → use production (baseline) scores. Same infrastructure, conditional lookup.

Full-sample (always-on) neutralization is the simpler alternative: accept losing a small natural hedge in high DD to remove a larger drag in low DD. Section 3.1 evaluates this trade-off.

---

## Section 1.1 — Full-Sample L/S Return Correlations

Measures: Pearson correlation of monthly L/S returns between PMOM_3SLOW and each VQ factor, full sample.

**Findings**: *(to be filled after reviewing output)*

---

## Section 1.2 — Full-Sample Cross-Sectional Score Correlations

Measures: At each date, compute Pearson correlation between PMOM_3SLOW score and each VQ factor score across all stocks, then average across all dates.

### Expected behaviour

If neutralization is via OLS residuals, the P-track XS correlation with PMOM should be exactly zero pre-`LS_Zstd`. The `LS_Zstd` re-standardization (re-ranking, z-scoring, winsorization) can leak back ±0.01–0.03. Values > 0.05 in magnitude would flag a problem.

### Results (cross-universe average)

| Factor | Avg B (baseline) | Avg P (neutralized) | Delta | Interpretation |
|---|---|---|---|---|
| Earnings_Value | -0.049 | +0.010 | +0.059 | Most PMOM-contaminated value factor (anti-momentum). Cleaned. |
| FCF_Value | +0.044 | +0.012 | -0.032 | Clean |
| TYTD2EV1Y | +0.036 | +0.007 | -0.030 | Clean — confirms B/P prefix fix is working |
| Profit | +0.066 | +0.002 | -0.064 | Strong pro-momentum bias removed, nearly perfect zero |
| Investment | +0.045 | +0.007 | -0.037 | Clean |
| Value | +0.002 | +0.012 | +0.010 | Was already near zero (EV's negative corr offset other sub-factors) |
| Quality | +0.077 | +0.005 | -0.072 | Strongest baseline contamination, cleaned to near-zero |

### Key takeaways

1. **Neutralization is working correctly** — all P-track averages are within ±0.01–0.02.
2. **Quality and Profit** had the largest baseline PMOM contamination (~+0.07–0.08, pro-momentum).
3. **Earnings_Value** is uniquely **anti-momentum** (-0.05 baseline), opposite sign from other VQ factors.
4. **Value composite** was already near zero because Earnings_Value's negative corr offset the positive corr of other value sub-factors.
5. Residual P-track correlations of ±0.01 are normal `LS_Zstd` re-standardization artifacts.

### Std Dev table

The temporal standard deviation of XS correlations tells how **stable** the PMOM contamination is over time. All P-track std devs are lower than B-track (negative Delta), meaning neutralization not only removes the average contamination but also reduces its variability.

---

## Section 1.3 — Rolling 24M L/S Return Correlations

Measures: Rolling 24-month Pearson correlation of L/S returns between PMOM_3SLOW and Earnings_Value.

**Findings**: *(to be filled after reviewing charts)*

---

## Section 1.4 — Rolling Cross-Sectional Score Correlations

Measures: Monthly XS score correlation between PMOM_3SLOW and Earnings_Value, plotted over time (no rolling average).

**Findings**: *(to be filled after reviewing charts)*

---

## Section 2.1 — Leaf-Level Performance (Ret / Vol / IR)

**Findings**: *(to be filled)*

---

## Section 2.2 — Sub-Theme Performance

**Findings**: *(to be filled)*

---

## Section 2.3 — Theme-Level Performance

**Findings**: *(to be filled)*

---

## Section 2.4 — Cumulative L/S Return Charts

**Findings**: *(to be filled)*

---

## Section 3.1 — Performance Stats by DD State

**Findings**: *(to be filled)*

---

## Section 4 — WFP Variants (Baseline, P, VP, EVP)

**Date added**: 2026-05-13
**Driver script**: §4 of `pmom_neut_analysis.py`
**Diagnostic scripts**: `_wfp_diagnostic_run.py`, `_wfp_regime_test.py`, `_wfp_2024_spx.py`, `_wfp_evp_annual_spx.py`
**Full memo**: [findings_evp_vs_pmom.md](findings_evp_vs_pmom.md)

### Variants tested

| Label    | DB factor       | Construction |
|----------|-----------------|--------------|
| Baseline | `PMR_B_WFP`     | Production WFP recipe, no neutralization |
| P        | `PMR_P_WFP`     | Full V/Q PMOM-neutralized, then composed |
| VP       | `PMR_VP_WFP`    | Only Value-side variant (V neutralized, Q production) |
| EVP      | `PMR_EVP_WFP`   | Only EV sub-themes of Value neutralized |

Coverage is **identical** across all four variants (same dates, same QAIDs) — Full-window IR equals Common-window IR. So the §4 underperformance signal is NOT a sample artifact.

### Full-sample cross-universe means

| Variant  | Ret % | Vol % | IR   | Score corr vs Baseline | L/S ret corr vs Baseline |
|----------|-------|-------|------|------------------------|---------------------------|
| Baseline | 7.54  |       | 1.45 | 1.000                  | 1.00 |
| P        | 6.02  |       | 1.41 | 0.912                  | ~0.83 |
| VP       | 7.60  |       | 1.42 | 0.967                  | ~0.98 |
| EVP      | 7.54  |       | 1.43 | 0.999                  | ~0.998 |

**Headline observation**: the four variants are nearly identical in IR (within 0.04). VP/EVP look basically like Baseline by construction — the partial neutralization moves very few positions. Only P meaningfully differs.

### Sub-period IR (cross-universe mean)

| Period    | Baseline | P    | VP   | EVP  |
|-----------|----------|------|------|------|
| <2000     | 1.66     | **1.75** | 1.65 | 1.63 |
| 2000-2009 | 1.58     | **1.91** | 1.52 | 1.53 |
| 2010-2019 | **1.55** | 1.30 | 1.49 | 1.53 |
| 2020+     | **1.23** | 1.00 | 1.27 | 1.25 |

P-track wins pre-2010, loses post-2010. The cost of removing the PMOM-cross-bet is regime-dependent.

### Regime hypothesis test: does EV-neutralization help when PMOM is winning?

**Premise**: PMOM counter-bets EV → in PMOM-tailwind regimes, neutralized EV should beat Baseline EV. Tested empirically:

1. **Cross-sectional anchor — corr(L/S returns, PMOM) full sample, B-track:**

   | Universe | V_B   | EV_B  | Q_B   |
   |----------|-------|-------|-------|
   | SPX      | −0.29 | **−0.37** | +0.06 |
   | MXWO     | −0.35 | **−0.48** | +0.04 |
   | MXEA     | −0.10 | **−0.28** | +0.20 |
   | MXEF     | +0.10 | 0.00  | +0.22 |
   | MXAP     | +0.13 | 0.00  | +0.29 |

   EV is strongly anti-PMOM in DM; ambiguous in EM. Premise holds.

2. **Conditional (P − B) delta by trailing-12m PMOM tercile (bps/month, pooled):**

   | Regime  | V_delta | EV_delta | Q_delta | WFP_P  | WFP_VP | WFP_EVP |
   |---------|---------|----------|---------|--------|--------|---------|
   | M_LOW   | −12.2   | −8.1     | +1.5    | +9.6   | −3.4   | −1.6 |
   | M_MID   | −6.3    | +0.8     | −3.8    | −13.0  | −0.1   | +0.1 |
   | M_HIGH  | +1.6    | **+7.7** | −6.2    | **−34.6** | +4.4   | +1.7 |

   EV neutralization is monotonically improving in M regime. WFP_P does the **opposite** — gets crushed when PMOM is hot.

3. **Linear: (P − B)_delta = a + b · M_return (pooled monthly):**

   | Delta            | slope b   | R²   |
   |------------------|-----------|------|
   | V_delta          | +0.029    | 0.02 |
   | **EV_delta**     | **+0.055**| 0.30 |
   | Q_delta          | −0.037    | 0.41 |
   | **WFP_P_delta**  | **−0.21** | **0.79** |
   | WFP_VP_delta     | +0.020    | 0.05 |
   | WFP_EVP_delta    | +0.013    | 0.30 |

4. **Annual `(WFP_EVP − WFP_B)` vs annual PMOM, SPX (N = 38 years):**
   - **Pearson +0.725**, Spearman +0.513
   - Sign-match 25/38 years (66%)
   - Largest negative deltas: PMOM-crash years (2009 PMOM −27% → delta −90 bps; 2016 PMOM −15% → −50 bps)
   - Largest positive deltas: PMOM-tailwind years (1998, 2015 +83 bps, 2017 +45 bps, 2024)

5. **2024 SPX (PMOM +11.2%, IR 1.56)** — head to head:

   | Variant | Baseline cum | Variant cum | Delta | Verdict |
   |---------|-------------|-------------|-------|---------|
   | V (P − B)    | +2.88% | +1.99% | −0.89 pp | hurt |
   | **EV (P − B)** | +1.45% | **+2.04%** | **+0.60 pp** | helped |
   | Q (P − B)    | +0.48% | +0.32% | −0.16 pp | hurt |
   | WFP_P  | +5.38% | +2.11% | −3.27 pp | hurt hard |
   | WFP_VP | +5.38% | +4.75% | −0.63 pp | hurt |
   | **WFP_EVP** | +5.38% | **+5.50%** | **+0.12 pp** | helped |

### Why the component-level benefit reverses at the WFP composite

The WFP is roughly equal-weight V + Q + M (active weights). V_B being anti-M creates **opposite-sign positions on the same stocks** as the M leg — the WFP naturally **diversifies** through this overlap.

Neutralization severs the overlap:

- V_clean is no longer anti-M → no longer cancels M's positions → WFP_P concentrates on M's preferred names
- Q channel makes it worse: Q_B was mildly +M; Q_clean is slightly −M → subtracts return when M wins
- Net: the +5 bps/% M from V_clean is more than offset by Q_clean's −4 bps/% plus loss of V/M diversification → WFP_P loses ~21 bps for every +1% in M
- WFP_EVP avoids this trap because EV-only neutralization is a near-no-op structurally (score corr 0.999) but **specifically** picks up the EV-PMOM hedge

### Takeaways

1. **The right place to neutralize is the EV leaf**, not the full WFP recipe.
2. **WFP_P is not a viable "PMOM-clean" alternative** to Baseline WFP — it underperforms in PMOM-tailwind regimes (which has been most of post-2010) and the loss is mechanical, not noise.
3. **WFP_EVP delivers the regime-positive behaviour but small in magnitude** (~+12 bps in 2024 SPX, full-sample IR delta ~−0.02). To meaningfully harvest the hedge, the operation likely needs to be done in a *re-built* WFP architecture (clean V + standalone M, no overlap reliance) rather than as a swap-in inside the existing one.
4. The DD-conditional implementation logic (Section 4 of this doc, "Why neutralize in low DD") is reinforced: low DD ↔ PMOM-tailwind ↔ EV-neutralization helps. The findings here are an *unconditional* version of that argument applied at the EV level rather than the V level.

---

## Open Questions / Follow-ups

- Re-build WFP from clean V + clean Q + M as separate legs (instead of swapping neutralized inputs into the existing recipe) and re-evaluate full-sample IR. Does removing the structural V/M overlap reliance unlock the regime hedge cleanly?
- Test EV-only neutralization in DD-conditional mode (low DD → EVP, high DD → Baseline). Does it dominate both endpoints?
- Quantify the V/M diversification overlap explicitly — what fraction of WFP_B's risk reduction vs (V + Q + M) standalone comes from the V's anti-M tilt cancelling M's positions?

