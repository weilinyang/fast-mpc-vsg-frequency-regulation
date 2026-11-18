# Fast MPC-VSG frequency regulation: MATLAB reference code

This repository contains the MATLAB and Simulink reference implementation for
**Fast Multi-Step Model Predictive Frequency Regulation Strategy For Islanded
Microgrids with Energy Storage**. It provides the frequency-control algorithm,
the sequence-reuse quadratic program, and the simulation scripts used for the
reported software studies.

## Requirements

- MATLAB R2023b
- Simulink
- Simscape Electrical / Specialized Power Systems for the switching-network model
- Optimization Toolbox for `quadprog`
- Control System Toolbox only for the optional `check_local_stability` script

The scripts use relative paths. Start MATLAB in the repository root and run:

```matlab
addpath(fullfile(pwd, 'matlab'));
addpath(fullfile(pwd, 'matlab', 'supplemental'));
```

## Reproduce the software simulations

1. Run `run_revision_experiments` to generate the reduced-order controller
   comparisons, metrics, and a desktop QP benchmark in `results/`.
2. Run `run_supplemental_batch` to run the 34 switching-network cases. It
   rebuilds `code/supplemental_network.slx` from the supplied
   `code/fangzheng.slx` for the first case and writes traces and run records to
   `results/supplemental/`. The first model is the supplied source model; the
   second is the revised simulation model. The batch may take substantial time.
3. Run `audit_supplemental_optimality` after the batch to check selected
   sequence-reuse trajectories against the full QP at the same states.

For a single switching-network case, use the included revised model directly:

```matlab
c = supp_config;
c.caseName = 'nominal';
c.method = 'reuse';
record = run_supplemental_case(c, false);
```

`solve_sequence.m` contains the full, warm-start, two-block, and endpoint-reuse
QP variants. `supp_controller_step.m` implements the adaptive VSG parameters,
predictor, weight, and online MPC step. `prediction_matrices.m` builds the
reduced-order prediction matrices.

## Scope of the code

The switching-network simulations use a 50 microsecond controller sample and
the simulation settings stated in the manuscript. The HIL implementation has
different parameter saturations and a 100 microsecond task period. This
repository does not contain the DS1202 deployment project or the HIL raw data,
and desktop timing is not a hardware deadline measurement.

Generated `results/` and `manuscript/` outputs are ignored by Git. Source
file hashes are recorded in `SOURCE_MANIFEST.json`.
