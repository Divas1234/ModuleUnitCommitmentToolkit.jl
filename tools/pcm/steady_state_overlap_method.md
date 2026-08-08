# Steady-State Overlap Window Identification Method

## 1. Motivation

The unit dwell-time criterion and the ramping-event criterion mainly address explicit tight operating conditions, such as remaining minimum up/down restrictions and strong net-load ramping requirements. In these cases, the overlap window is used to preserve feasibility and prepare enough ramping capability across rolling-window boundaries.

During normal supply-demand balance periods, however, load variation is relatively smooth and coal-fired generation capacity is sufficient. The core role of the overlap window is then different. It is not mainly used to eliminate infeasibility caused by tight constraints, but to reduce the downstream operating deviation introduced by finite boundary-condition transfer. Therefore, the steady-state criterion quantifies how the influence of previous commitment decisions decays over later periods and selects the shortest overlap window that keeps this accuracy loss below a given tolerance.

In the current implementation, this mechanism is mainly realized by:

- `solve_local_reference_commitment(...)`
- `sample_and_train_loss_models(...)`
- `compute_steady_state_overlap_mapping(...)`
- `compute_adaptive_overlap_window(...)`

The main PCM script uses `steady_state_mode = "regression"`, so `T_steady` is selected through the calibrated accuracy-loss mapping instead of a fixed decay length.

## 2. Candidate and Reference Subproblems

Let the execution length of rolling window `k` be:

```math
T^{\mathrm{exe}}
```

and let the candidate overlap length be:

```math
H \in [L^{\min}, L^{\max}].
```

For each candidate `H`, the program solves a candidate subproblem with total horizon:

```math
T^{\mathrm{exe}} + H.
```

It also solves a reference subproblem with the maximum look-ahead horizon:

```math
T^{\mathrm{exe}} + L^{\max}.
```

Both subproblems use the same load profile, renewable forecast scenarios, and inherited initial boundary state. Only the first `T^{\mathrm{exe}}` periods are committed. Let their committed execution-period costs be:

```math
C_{k,H}, \qquad C_{k,\mathrm{ref}}.
```

Let their terminal commitment states at the end of the committed execution window be:

```math
\boldsymbol{x}_{k,H}^{\mathrm{end}},
\qquad
\boldsymbol{x}_{k,\mathrm{ref}}^{\mathrm{end}}.
```

In the code, the committed result is produced by `truncate_and_commit_results(...)`, and the committed cost is evaluated by `compute_committed_cost(...)`.

## 3. Local Economic Reference Commitment

To measure how much the inherited rolling boundary differs from the locally economic operating mode, the program solves an additional local reference problem for the same start time while intentionally ignoring the previous rolling window's inherited boundary conditions. This is implemented by:

```julia
solve_local_reference_commitment(...)
```

The first-period commitment of this local no-boundary solve is used as:

```math
\boldsymbol{x}_{k}^{\mathrm{loc}}.
```

The inherited current initial commitment state is:

```math
\boldsymbol{x}_{k}^{0}.
```

The capacity-weighted boundary deviation is defined as:

```math
X_{\Delta,k}
=
\frac{
\sum_{i\in\Omega_G} P_i^{\max}
\left|x_{i,k}^{0}-x_{i,k}^{\mathrm{loc}}\right|
}{
\sum_{i\in\Omega_G} P_i^{\max}
}.
```

The unit-count switching deviation is:

```math
X_{\mathrm{sw},k}
=
\frac{1}{|\Omega_G|}
\sum_{i\in\Omega_G}
\left|x_{i,k}^{0}-x_{i,k}^{\mathrm{loc}}\right|.
```

`X_{\Delta,k}` emphasizes the installed capacity involved in the inherited boundary deviation, while `X_{\mathrm{sw},k}` measures the fraction of units whose on/off state differs. Both are normalized to `[0, 1]`.

In the code, these two quantities are computed by:

```julia
commitment_boundary_deviation(units, x_0_curr, x_ref_curr)
```

and correspond to:

- `X_delta_norm`
- `X_switch_ratio`

If the local reference solve is unavailable, the function falls back to the original input boundary state.

## 4. Accuracy-Loss Label

For each candidate overlap length `H`, the execution-period cost loss is:

```math
\delta_{C,k}(H)
=
\frac{
\left|C_{k,H}-C_{k,\mathrm{ref}}\right|
}{
C_{k,\mathrm{ref}}
}.
```

The terminal capacity-weighted commitment deviation is:

```math
\delta_{\Delta,k}(H)
=
\frac{
\sum_{i\in\Omega_G} P_i^{\max}
\left|
x_{i,k,H}^{\mathrm{end}}
-
x_{i,k,\mathrm{ref}}^{\mathrm{end}}
\right|
}{
\sum_{i\in\Omega_G} P_i^{\max}
}.
```

The terminal unit-count switching deviation is:

```math
\delta_{\mathrm{sw},k}(H)
=
\frac{1}{|\Omega_G|}
\sum_{i\in\Omega_G}
\left|
x_{i,k,H}^{\mathrm{end}}
-
x_{i,k,\mathrm{ref}}^{\mathrm{end}}
\right|.
```

The comprehensive accuracy-loss label is:

```math
\mathcal{L}_{k}(H)
=
\delta_{C,k}(H)
+
0.50\,\delta_{\Delta,k}(H)
+
0.25\,\delta_{\mathrm{sw},k}(H).
```

This is consistent with the implementation in `sample_and_train_loss_models(...)`:

```julia
loss_val = cost_loss + 0.50 * state_loss + 0.25 * switch_loss
```

The additional commitment-state penalties are important because a short overlap can have a similar committed-period cost while leaving a different terminal commitment state. That terminal difference is passed to the next rolling window and can become a downstream scheduling error.

## 5. Feature Vector

For offline calibration and online prediction, the steady-state mapping uses:

```math
\boldsymbol{z}_{k,H}
=
\left[
1,\;
L_k^{\mathrm{norm}},\;
U_k^{\mathrm{norm}},\;
X_{\Delta,k},\;
X_{\mathrm{sw},k},\;
H
\right]^{\mathsf T}.
```

The normalized average net load is:

```math
L_k^{\mathrm{norm}}
=
\frac{\bar P_{\mathrm{net},k}}{P_{\mathrm{peak}}}.
```

The online capacity ratio at the start of the rolling window is:

```math
U_k^{\mathrm{norm}}
=
\frac{
\sum_i P_i^{\max}x_{i,k}^{0}
}{
\sum_i P_i^{\max}
}.
```

`sample_and_train_loss_models(...)` samples representative start times, load scales, initial commitment states, and candidate overlap lengths. It solves the corresponding subproblems and records the accuracy-loss label for each candidate `H`. This calibration step is executed before the rolling-horizon simulation loop and is not included in the operational simulation solve-time metric.

## 6. Regression-Based Accuracy-Loss Mapping

In regression mode, the calibrated model is:

```math
\ln \widehat{\mathcal{L}}_k(H)
=
\beta_0
+
\beta_L L_k^{\mathrm{norm}}
+
\beta_U U_k^{\mathrm{norm}}
+
\beta_{\Delta} X_{\Delta,k}
+
\beta_{\mathrm{sw}} X_{\mathrm{sw},k}
+
\beta_H H.
```

The predicted loss is therefore:

```math
\widehat{\mathcal{L}}_k(H)
=
\exp\left(
\beta_0
+
\beta_L L_k^{\mathrm{norm}}
+
\beta_U U_k^{\mathrm{norm}}
+
\beta_{\Delta} X_{\Delta,k}
+
\beta_{\mathrm{sw}} X_{\mathrm{sw},k}
+
\beta_H H
\right).
```

The implementation enforces a physical monotonicity condition on the overlap-length coefficient. If the fitted coefficient satisfies `beta[6] >= 0`, it is corrected to a negative value:

```julia
if beta[6] >= 0.0
    beta[6] = -0.3
end
```

This ensures that the predicted accuracy loss does not increase as the overlap window becomes longer.

The neural-network mode uses the same input features and the same loss label, but replaces the log-linear model with a one-hidden-layer nonlinear approximation.

## 7. Model-Selected Steady-State Overlap

Given the admissible accuracy-loss threshold `epsilon`, the model-selected overlap length is the smallest candidate `H` satisfying:

```math
\widehat{\mathcal{L}}_k(H) \leq \varepsilon.
```

That is:

```math
H_k^{\mathrm{model}}
=
\min
\left\{
H\in[L^{\min},L^{\max}]\cap\mathbb{Z}_{+}
\;\middle|\;
\widehat{\mathcal{L}}_k(H)\leq\varepsilon
\right\}.
```

If no candidate satisfies the threshold, the implementation uses:

```math
H_k^{\mathrm{model}} = L^{\max}.
```

This selection is implemented in:

```julia
compute_steady_state_overlap_mapping(...)
```

## 8. Analytical State-Decay Floor

To prevent the regression model from underestimating large inherited boundary deviations, the implementation also adds an analytical lower bound based on state-deviation decay.

The initial disturbance amplitude is:

```math
A_{0,k}
=
\max
\left\{
X_{\Delta,k},
X_{\mathrm{sw},k}
\right\}.
```

Its residual influence after `H` overlap hours is approximated as:

```math
A_k(H)
=
A_{0,k}(1-\alpha_{\mathrm{state}})^H.
```

The state-error threshold is:

```math
\varepsilon_{\mathrm{state}}
=
\mathrm{clip}(\varepsilon/2,\;0.01,\;0.08).
```

The state-decay floor is:

```math
H_k^{\mathrm{state}}
=
\mathrm{clip}
\left(
\left\lceil
\frac{
\ln(\varepsilon_{\mathrm{state}}/A_{0,k})
}{
\ln(1-\alpha_{\mathrm{state}})
}
\right\rceil,
L^{\min},
L^{\max}
\right).
```

When:

```math
A_{0,k}\leq\varepsilon_{\mathrm{state}},
```

the implementation directly sets:

```math
H_k^{\mathrm{state}} = L^{\min}.
```

Therefore, in regression or neural-network mode, the final steady-state overlap is:

```math
T_k^{\mathrm{steady}}
=
\max
\left\{
H_k^{\mathrm{model}},
H_k^{\mathrm{state}}
\right\}.
```

This design combines data-driven prediction with a physical conservative floor. The learned model captures how accuracy loss changes with operating conditions and overlap length, while the analytical floor ensures that large boundary-state deviations cannot be assigned an unrealistically short steady-state overlap.

## 9. Decay-Only Fallback

If offline calibration is not used and `steady_state_mode = "decay"`, the steady-state overlap degenerates to a unified boundary-sensitivity decay formula:

```math
T^{\mathrm{steady}}
=
\max
\left\{
1,\;
\left\lceil
\frac{\ln\varepsilon}{\ln(1-\alpha)}
\right\rceil
\right\}.
```

It is the minimum duration satisfying:

```math
(1-\alpha)^{T^{\mathrm{steady}}}\leq\varepsilon.
```

This fallback is implemented by:

```julia
calculate_boundary_sensitivity_decay(alpha, epsilon)
```

## 10. Final Composite Overlap Window

The steady-state criterion is combined with the remaining unit dwell-time criterion and the ramping/uncertainty criterion:

```math
T_k^{\mathrm{overlap}}
=
\min
\left\{
T_k^{\mathrm{remain}},
\;
\mathrm{clip}
\left(
\max
\left\{
T_k^{\mathrm{steady}},
T_k^{\mathrm{unit}},
T_k^{\mathrm{ramp}}
\right\},
L^{\min},
L^{\max}
\right)
\right\}.
```

Here:

- `T_k^{steady}` is selected by the steady-state accuracy-loss mapping.
- `T_k^{unit}` is the remaining minimum online time for currently online units or remaining minimum offline time for currently offline units.
- `T_k^{ramp}` is obtained from net-load ramping and multi-scenario uncertainty detection.
- `T_k^{remain}` is the remaining available horizon after the execution window.

The implementation computes:

```julia
T_overlap_raw = max(T_steady, T_unit, T_ramp)
T_overlap = clamp(T_overlap_raw, min_overlap, max_overlap)
T_overlap = max(0, min(T_overlap, max_possible_overlap))
```

Thus, during normal balanced periods, the method prefers the shortest overlap window that satisfies the predicted accuracy-loss threshold. When inherited boundary deviation is large, slow-start units still have remaining dwell restrictions, or a strong ramping/high-uncertainty event appears in the look-ahead horizon, the final overlap window is automatically raised by the corresponding criterion.

The overlap interval only provides look-ahead information. The rolling-horizon simulation commits only the first `T^{exe}` periods, then extracts the terminal commitment state, startup/shutdown decisions, and remaining dwell information from the committed execution window as boundary conditions for the next rolling window.
