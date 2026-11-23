# A02 Mojo patch manifest

| Paths | Change |
| --- | --- |
| `README.md` | Replaced initial planning text with project identity, executed build entry points, provenance and evidence limits. |
| `.gitignore` | Excludes local toolchain, caches, generated packages and named local raw-evidence roots. |
| `.github/workflows/a02.yml` | Adds paper CPU, package and fail-closed benchmark admission checks. |
| `pixi.toml`, `pixi.lock` | Adds paper tasks and uses the genuine pinned upstream dependency resolution. |
| `src/layoutproof/__init__.mojo`, `src/layoutproof/a02/__init__.mojo`, `src/layoutproof/a02/ir.mojo` | Adds the paper package and typed instructions, layout and outcomes. |
| `src/layoutproof/a02/arithmetic.mojo`, `src/layoutproof/a02/lowering.mojo` | Adds checked shape, address and affine-layout lowering. |
| `src/layoutproof/a02/oracle.mojo`, `src/layoutproof/a02/verifier.mojo` | Adds the independent interpreter, finite decision procedure, ablations and counterexample replay. |
| `src/layoutproof/a02/solver.mojo`, `src/layoutproof/a02/replay.mojo` | Adds a symbolic signed-axis producer, separate certificate replay and manual baseline. |
| `src/layoutproof/a02/affine_solver.mojo`, `src/layoutproof/a02/affine_replay.mojo` | Adds exact affine view proofs on fixed extents, independent replay and coordinate counterexamples. |
| `src/layoutproof/a02/cases.mojo`, `benchmarks/research/a02_layout_proof.mojo` | Adds exploratory source-defined inputs and the runner's executable benchmark admission path. |
| `adapters/a02_general.mojo`, `adapters/a02_light.mojo` | Adds independent, optional Momijo differential adapters. |
| `tests/a02_smoke.mojo`, `tests/a02_layout_proof.mojo`, `tests/a02_certificate.mojo`, `tests/a02_affine.mojo`, `tests/a02_momijo_adapters.mojo` | Adds executable CPU regression and integration tests. The V4 round adds the affine suite to the three original source-only suites. |
| `docs/a02/README.md`, `docs/a02/AUDIT_A02_MOMIJO.md`, `docs/a02/APPLICABILITY_MATRIX.tsv`, `docs/a02/BUILD_LOG_A02_MOMIJO.md`, `docs/a02/TEST_REPORT_A02_MOMIJO.md`, `docs/a02/HANDOFF_A02_MOMIJO.md`, `docs/a02/PATCH_MANIFEST_A02_MOMIJO.md` | Adds the semantic specification, source and test observations, evidence routes and handoff. |

The supplied `docs/a02/LIBRARY_SOURCE_PIN.txt` is retained as input provenance. The library APIs and existing upstream tests were used at their supplied revision. Generated build outputs and measurement files are outside the source patch.
