# EV-Neutralization vs PMOM — empirical finding

**Date**: 2026-05-13
**Author**: research note, PMOM_neut project
**Question**: Does PMOM-neutralizing the Value (EV) component actually help when PMOM is doing well, as the cross-betting intuition predicts?

---

## TL;DR

**Yes for EV / WFP_EVP. No for full WFP_P.**

- `EV_P − EV_B` is **monotonically increasing** in trailing-12m PMOM regime; +7.7 bps/month in the top tercile vs −8.1 bps/month in the bottom tercile.
- Annual `(WFP_EVP − WFP_B)` has **Pearson +0.725** with annual PMOM_3SLOW return on SPX (N=38). Sign-match 25/38 years (66%).
- Conversely, **WFP_P delta has Pearson −0.21 slope on monthly M return with R² = 0.79** — the *opposite* of the prediction. The component-level benefit gets destroyed when wrapped back into the WFP composite.

---

## The premise

Working hypothesis from the conversation:

> PMOM tends to bet against EV (cheap stocks ≈ losers). In a PMOM-tailwind regime, Baseline EV is dragged down by its anti-PMOM tilt. Neutralizing EV to PMOM removes the tilt → neutralized EV should outperform Baseline EV.

## Evidence (SPX as anchor, all from cached parquets)

### 1. Premise confirmed at the score level

Full-sample correlation of L/S returns with PMOM_3SLOW (B-track):

| Universe | V_B | EV_B | Q_B |
|---|---|---|---|
| SPX  | −0.29 | **−0.37** | +0.06 |
| MXWO | −0.35 | **−0.48** | +0.04 |
| MXEA | −0.10 | **−0.28** | +0.20 |
| MXEF | +0.10 | 0.00 | +0.22 |
| MXAP | +0.13 | 0.00 | +0.29 |

EV is the most strongly anti-PMOM factor, especially in developed markets. Quality is roughly orthogonal-to-mildly-positive.

### 2. Conditional (P − B) delta by trailing-12m PMOM tercile

Cross-universe pooled, bps/month:

| Trailing-12m M regime | V_delta | EV_delta | Q_delta | WFP_P_delta | WFP_VP_delta | WFP_EVP_delta |
|---|---|---|---|---|---|---|
| M_LOW   | −12.2 | −8.1 | +1.5  | +9.6  | −3.4 | −1.6 |
| M_MID   | −6.3  | +0.8 | −3.8  | −13.0 | −0.1 | +0.1 |
| **M_HIGH**  | **+1.6**  | **+7.7** | −6.2  | **−34.6** | +4.4 | +1.7 |

EV neutralization helps monotonically. WFP_P does the *opposite* — gets destroyed in PMOM-tailwind regimes.

### 3. Linear: `(P − B)_delta = a + b · M_return`

| Delta            | slope b | R²   |
|------------------|---------|------|
| V_delta          | +0.029  | 0.02 |
| **EV_delta**     | **+0.055**  | **0.30** |
| Q_delta          | −0.037  | 0.41 |
| **WFP_P_delta**  | **−0.21**   | **0.79** |
| WFP_VP_delta     | +0.020  | 0.05 |
| WFP_EVP_delta    | +0.013  | 0.30 |

For every +1% PMOM month, EV_P beats EV_B by ~5.5 bps. WFP_P *loses* ~21 bps. R² of 0.79 for WFP_P is near-mechanical.

### 4. 2024 SPX (PMOM = +11.2%, IR 1.56) — head to head

| Variant | Baseline cum | Variant cum | Delta | Verdict |
|---|---|---|---|---|
| V (P − B)        | +2.88% | +1.99% | −0.89 pp | hurt |
| **EV (P − B)**   | +1.45% | **+2.04%** | **+0.60 pp** | helped |
| Q (P − B)        | +0.48% | +0.32% | −0.16 pp | hurt |
| WFP_P            | +5.38% | +2.11% | −3.27 pp | hurt hard |
| WFP_VP           | +5.38% | +4.75% | −0.63 pp | hurt |
| **WFP_EVP**      | +5.38% | **+5.50%** | **+0.12 pp** | helped |

### 5. Annual `(WFP_EVP − WFP_B)` vs PMOM, SPX (N=38)

| Metric | Value |
|---|---|
| Pearson  (annual)  | **+0.725** |
| Spearman (annual)  | +0.513 |
| Pearson  (monthly, N=435) | +0.712 |
| Sign-match years   | 25 / 38 (66%) |

Largest negative deltas were in PMOM-crash years (2009: PMOM −27%, delta −90 bps; 2016: PMOM −15%, delta −50 bps). Largest positive deltas in PMOM-tailwind years (1998, 2015 +83 bps, 2017 +45 bps, 2024).

---

## Why the WFP composite reverses

The WFP is roughly an equal-weight blend of V + Q + M (active weights). When V_B is anti-M, it produces *opposite-sign positions* on the same stocks as M — the WFP blend naturally **diversifies risk via this overlap**.

Neutralization removes that overlap:

- V_clean is no longer anti-M → no longer cancels M's positions
- WFP_P becomes more concentrated on M's preferred names
- The Q channel makes it worse: Q_B was mildly +M; Q_clean is slightly −M → subtracts return when M wins
- Net at WFP_P level: the +5 bps/% from V_clean is more than offset by the −4 bps/% from Q_clean and the loss of V/M diversification

WFP_EVP avoids this trap because it only touches the EV-flavored Value sub-themes — a minor structural change (score corr 0.999 vs Baseline) — yet that small touch is enough to pick up the EV-specific PMOM-tailwind benefit.

---

## Practical implications

1. **The neutralization belongs at the EV leaf level**, not at the full WFP recipe. WFP_EVP is the right operating point of the three variants tested.
2. **Don't use WFP_P as a "PMOM-clean" alternative to Baseline WFP** — it does not provide diversification when PMOM is hot, it provides the opposite.
3. **The EVP route is regime-positive but small in magnitude** (~+12 bps in 2024 SPX, full-sample IR delta ~−0.02). If the goal is to gain meaningful M-regime hedging, the operation needs to be done in a *re-built* WFP architecture rather than as a swap-in inside the existing one.

---

## Reproducibility

All numbers above produced by:

- [_wfp_diagnostic_run.py](_wfp_diagnostic_run.py) — coverage, dispersion, common-window IR, sub-period IR
- [_wfp_regime_test.py](_wfp_regime_test.py) — conditional deltas, regression slopes
- [_wfp_2024_spx.py](_wfp_2024_spx.py) — 2024 SPX head-to-head
- [_wfp_evp_annual_spx.py](_wfp_evp_annual_spx.py) — annual table, correlation

Inputs are cached parquets in `analysis/cache/`. Main analysis: [pmom_neut_analysis.py](pmom_neut_analysis.py).
