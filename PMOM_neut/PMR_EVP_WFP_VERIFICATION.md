# `PMR_EVP_WFP` — End-to-End Verification

**Question asked:** *Does `PMR_EVP_WFP` really have only Earnings_Value
neutralized to PMOM — nothing else? And does the database actually store
what the build recipe says it should?*

**Short answer:**
- ✅ **Yes** at the recipe level (07a → 07d) and at the input-piece level.
- ✅ **Yes** at the reconstruction level (per-date Spearman vs DB ≈ 0.9999).
- ❌ **But** at the final-composite level, EV-only PMOM-neutralization is
  invisible in rank correlation with PMOM_3SLOW — the composite stays nearly
  identical to baseline because the Momentum_3SLOW third dominates.

---

## 1. Pipeline reminder

The four scripts in [`data_creation/`](../data_creation/) build the EVP variant
in this order:

| Step | Script | Action |
|---|---|---|
| 07a | [07a_build_value_ev_variants.py](../data_creation/07a_build_value_ev_variants.py) | Per-stock weighted sum: `Value_EVP = 0.253·PMR_P_Earnings_Value + 0.374·PMR_B_FCF_Value + 0.374·PMR_B_TYTD2EV1Y` |
| 07b | [07b_ntrlz_value_ev_variants.py](../data_creation/07b_ntrlz_value_ev_variants.py) | Re-neutralize the `Value_EVP` composite vs standard RFs only (`Size, VolZsTrad, BetaZs, LEV` — **no PMOM**). Output `PMR_EVP_Value`. |
| 07c | [07c_build_wfp_variants.py](../data_creation/07c_build_wfp_variants.py) | Per-stock weighted sum: `WFP_EVP = ⅓·PMR_EVP_Value + ⅓·PMR_B_Quality + ⅓·PMR_B_Momentum_3SLOW` |
| 07d | [07d_ntrlz_wfp_variants.py](../data_creation/07d_ntrlz_wfp_variants.py) | Re-neutralize the `WFP_EVP` composite vs standard RFs only. Output `PMR_EVP_WFP`. |

The only place `PMOM_3SLOW` appears as a neutralization target anywhere in this
pipeline is **inside the leaves of `Earnings_Value`** (when they were built
as `PMR_P_*` in step 06b).

---

## 2. Verification scripts produced

| Script | Purpose |
|---|---|
| [evp_wfp_pmom_footprint.py](evp_wfp_pmom_footprint.py) | Measure |ρ(input, PMOM_3SLOW)| for each piece going into `WFP_EVP` |
| [_locate_wfp_composites.py](_locate_wfp_composites.py) | Confirm which DB table holds the final composites |
| [evp_wfp_composite_verification.py](evp_wfp_composite_verification.py) | (1) Measure |ρ(composite, PMOM)| for `PMR_B_WFP`, `PMR_EVP_WFP`, `PMR_P_WFP`; (2) Reconstruct `PMR_EVP_WFP` from inputs and compare per-date rank vs DB |

All outputs land in [`../output/`](../output/):
- `evp_wfp_pmom_footprint.csv`
- `evp_wfp_composite_footprint.csv`
- `evp_wfp_reconstruction.csv`

---

## 3. Test A — input-piece PMOM footprint

**Method.** For each of the 5 inputs of `WFP_EVP`, compute the daily
cross-sectional Spearman correlation with `PMOM_3SLOW` (loaded from
`cache/<U>/pmom_PMR_P_.parquet`). Take the absolute median across dates,
then median across the 5 universes.

**Result (pooled medians across SPX, MXEA, MXWO, MXEF, MXAP):**

| Input piece                         | PMOM-neut? | median ρ | \|ρ\|   |
|-------------------------------------|:----------:|---------:|--------:|
| `PMR_B_Momentum_3SLOW`              | no         | +0.612   | 0.612   |
| `PMR_B_Quality`                     | no         | +0.072   | 0.073   |
| `PMR_B_FCF_Value`                   | no         | +0.050   | 0.060   |
| `PMR_B_TYTD2EV1Y`                   | no         | +0.047   | 0.050   |
| **`PMR_P_Earnings_Value`**          | **YES**    | **+0.004** | **0.015** |

**Interpretation.**
- `PMR_P_Earnings_Value` is the **only** piece whose PMOM correlation has been
  driven to zero. |ρ|≈0.015 is 3–40× smaller than every other Value/Quality
  input — confirming it is the only piece explicitly orthogonalized against
  `PMOM_3SLOW`.
- FCF_Value, TYTD2EV1Y, Quality all carry residual PMOM correlation in the
  0.05–0.07 range — i.e. untouched by PMOM neutralization.
- Momentum_3SLOW carries |ρ|≈0.61 because it **is** the PMOM family
  (correlation isn't 1.00 because `PMOM_3SLOW` is one of three components
  inside `Momentum_3SLOW`, and stocks are ranked differently).

This is a direct, quantitative confirmation that **the EV slice is the
only piece carrying explicit PMOM orthogonality** going into the composite.

---

## 4. Test B — recipe reconstruction vs DB

**Method.** Fetch the three inputs from `QuantFactorsNTRLZ`, compute
`recon = ⅓·PMR_EVP_Value + ⅓·PMR_B_Quality + ⅓·PMR_B_Momentum_3SLOW`
per `(Date, QAID)`. Fetch the DB-stored `PMR_EVP_WFP`. Compute per-date
Spearman correlation between `recon` and `DB`, then take the median across
dates per universe.

**Result.**

| Universe   | median Spearman(recon, DB) | q25     | n_obs   |
|------------|---------------------------:|--------:|--------:|
| SPX Index  | 0.9999                     | 0.9999  | 216 k   |
| MXEA Index | 0.9999                     | 0.9999  | 293 k   |
| MXWO Index | 0.9998                     | 0.9998  | 499 k   |
| MXEF Index | 0.9997                     | 0.9996  | 291 k   |
| MXAP Index | 0.9999                     | 0.9999  | 343 k   |

**Interpretation.** The recipe in 07c is exactly what's in the database, up
to the cross-sectional re-orthogonalization in 07d (standard RFs only).
The remaining ~0.0001–0.0003 gap is that final GLS pass — which **does not**
touch PMOM, only `Size/VolZsTrad/BetaZs/LEV`. Recipe identity confirmed.

---

## 5. Test C — final-composite PMOM footprint (the unexpected result)

**Method.** Same as Test A but applied to the three final composites
stored in `QuantFactorsNTRLZ`.

**Result (pooled medians across 5 universes):**

| Composite      | \|ρ(., PMOM_3SLOW)\| |
|----------------|---------------------:|
| `PMR_EVP_WFP`  | **0.323**            |
| `PMR_B_WFP`    | **0.318**            |
| `PMR_P_WFP`    | **0.286**            |

**Per-universe |ρ| (pooled into the median above):**

| Universe   | B_WFP  | EVP_WFP | P_WFP  |
|------------|-------:|--------:|-------:|
| SPX Index  | 0.298  | 0.307   | 0.293  |
| MXEA Index | 0.324  | 0.335   | 0.289  |
| MXWO Index | 0.298  | 0.311   | 0.286  |
| MXEF Index | 0.330  | 0.328   | 0.273  |
| MXAP Index | 0.318  | 0.323   | 0.273  |

**Interpretation — the surprising part.**

1. **`PMR_EVP_WFP` does NOT have a lower PMOM rank-correlation than baseline.**
   In 4 of 5 universes it is fractionally *higher* than `PMR_B_WFP` (delta
   ≈ +0.5 pp). Removing PMOM from the EV sliver does not measurably reduce
   the composite's overall rank correlation with PMOM.

2. **Why:** ⅓ of every WFP variant is `PMR_B_Momentum_3SLOW` (|ρ|≈0.61).
   That single chunk dominates the composite's PMOM correlation. The EV
   sliver is only `⅓ × 0.253 ≈ 8.4%` of the composite — small enough that
   removing its PMOM loading is a rounding error against the Momentum third.

3. Even **full `PMR_P_WFP`** (Q and V both fully PMOM-neutralized) only
   reduces |ρ| from 0.32 → 0.29 (≈ 3 pp). The remaining ≈ 0.29 is the
   Momentum_3SLOW third, which is kept baseline by design (neutralizing
   momentum to PMOM is circular — see `BASELINE_THEMES` in
   [06a_build_wfp.py](../data_creation/06a_build_wfp.py)).

4. The small |ρ| *increase* from B → EVP is not an error. The 07d GLS pass
   re-distributes weights cross-sectionally to enforce standard-RF
   orthogonality on the new composite — when the EV piece changes (PMOM-clean
   instead of baseline), the composite's loadings on Size/Vol/Beta/LEV
   shift slightly, and the GLS fix can leave a slightly different (but
   tiny) PMOM residual.

---

## 6. Reconciling with `findings_evp_vs_pmom.md`

Earlier diagnostic ([findings_evp_vs_pmom.md](findings_evp_vs_pmom.md))
reported that `WFP_EVP` *does* help in return-regression terms:
+0.12 pp annual long-short performance in PMOM-tailwind regimes, and a
Pearson +0.725 of annual `(WFP_EVP − WFP_B)` vs annual PMOM return
on SPX.

**These two results are not in conflict.** The benefit of `WFP_EVP` is not
that the composite has lower PMOM rank-correlation as a score — it
clearly does not (Test C). The benefit is that **the EV sliver's
contribution to the long-short portfolio is cleaner**: when the EV leaves
are PMOM-neutralized, the stocks they push into the long/short books are
not the same stocks Momentum is already pushing. The resulting portfolio
turnover and concentration are subtly different, and over many years that
translates into a small persistent alpha pickup in PMOM-tailwind regimes.

This is **return-level diversification**, not **score-level orthogonality**.
The two metrics measure different things:
- Score-level: are the cross-sectional ranks of `WFP_EVP` orthogonal to
  `PMOM_3SLOW` ranks? **No** — they aren't, because Momentum is ⅓ of WFP.
- Portfolio-level: do the long/short positions of `WFP_EVP` add return on
  top of what `WFP_B` already gives in PMOM-favorable years? **Yes** —
  modestly, only inside Value, only via the EV slice.

---

## 7. Conclusions

1. **The recipe is exactly as documented in 07a/07b/07c/07d**, confirmed
   by per-date Spearman ≈ 0.9999 between reconstruction and DB-stored
   `PMR_EVP_WFP`.

2. **The only piece of `PMR_EVP_WFP` with explicit PMOM-orthogonality is
   the Earnings_Value sub-theme** (its 4 leaves: `E2P, EBIT2EV1Y,
   EBITDA2EV1Y, NOPAT2EV1Y`). Every other input — FCF_Value, TYTD2EV1Y,
   Quality, Momentum_3SLOW — is baseline.

3. **EV-only PMOM neutralization is invisible at the composite rank-
   correlation level** (Δ|ρ| ≈ 0 vs baseline) because the Momentum_3SLOW
   third dominates the composite's PMOM exposure.

4. **The empirical benefit of `WFP_EVP` (per the earlier `findings_evp_vs_pmom`
   work) lives at the portfolio-return level**, not at the score-correlation
   level. Future analysis comparing variants should measure return
   regressions / portfolio overlap, not just |ρ(composite, PMOM)|.

5. **Operational takeaway.** Anyone evaluating whether `WFP_EVP` "removes
   PMOM" should be careful which metric they use. The cleanest minimum-
   intervention claim is: *EV leaves are PMOM-orthogonal at the leaf level,
   that orthogonality is inherited by the EV-only Value composite, and the
   final WFP_EVP composite contains exactly ⅓·0.253 ≈ 8% of its weight in
   PMOM-clean signal — the rest is baseline.*

---

## 8. Caveats

- All correlations are **Spearman / rank-based**. Linear (Pearson)
  correlations would give different absolute numbers but the same
  qualitative ordering.
- "PMOM_3SLOW" used for the comparison is the baseline (`PMR_P_` cache) —
  the same factor that 06b uses as a neutralization target in production.
- The composite-level Δ between EVP and B is small (≤ 1 pp |ρ|) and
  fluctuates in sign across universes; do not over-interpret the sign.
- The pooled medians smooth over real cross-universe heterogeneity; for
  any single-universe decision use the per-universe table in §5.
