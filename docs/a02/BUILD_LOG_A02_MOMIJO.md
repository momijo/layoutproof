# A02 local build and execution record

Host `Linux x86_64`, Pixi `0.84.2`, Mojo `1.1.0 (8189361e)`, MAX locked to `26.6.0`. The paper baseline was `3843c8734de9b83d34092c9b754245eb7fae29a5` plus the working tree shown in the patch manifest. The independently checked-out library source was `3c9fc14fa31f7bee8c8c783e191ca63dded57544`. The paper copied the genuine lock byte for byte. Its SHA-256 is `ac96d652523cd24c553753665ca9238a2f0c2f7e434fb1ebd6601b738d6c6d5e`.

The offline install used cached packages copied into the ignored paper cache. `RATTLER_CACHE_DIR`, `XDG_CACHE_HOME`, `MODULAR_CACHE_DIR` and `TMPDIR` pointed inside the paper repository. Pixi fell back to its built-in virtual package detection because the channel repodata cache was unavailable. Mojo reported a sandbox denial for Crashpad's socket setup. An initial direct baseline attempt without the installed environment's `MODULAR_HOME` failed with exit 1 because `std` could not be located. Running the pinned compiler with its installed activation variables resolved that setup error.

| Executed command | Exit | Observation |
| --- | ---: | --- |
| `pixi install --locked --offline` | 0 | Installed pinned environment from cached packages. |
| `pixi run --locked --offline mojo --version` | 0 | Compiler version above. |
| `pixi run --locked --offline test-smoke` | 0 | Scalar model smoke. |
| `pixi run --locked --offline test-all` | 0 | Smoke, bounded semantic suite and symbolic certificate suite. |
| `pixi run --locked --offline test-momijo` | 0 | Separate General and Light CPU adapters. |
| `pixi run --locked --offline package` | 0 | Nonempty `dist/layoutproof.mojoc`. |
| `pixi run --locked --offline mojo run -I dist tests/a02_smoke.mojo` | 0 | Executed the smoke test from the compiled package. |
| `pixi run --locked --offline research-a02 --help` and `pixi run --locked --offline research-a02 --version` | 0 each | CLI help and runner version. |
| `pixi run --locked --offline research-a02 --check-only --seed 42 --case CASE` | 0 each | `flip-slice` PASS, `slice-mutant` FAIL/LOGICAL, `copy-mutant` FAIL/ADDRESS, `aliased-write` REJECTED/ALIAS. |
| `pixi run --locked --offline research-a02 --output-root .tmp/blocked-evidence` | 2 | NOT_RUN, canonical protocols missing. `test ! -e .tmp/blocked-evidence` exited 0. |
| `pixi run --locked --offline research-a02 --case copy-mutant` | 2 | NOT_RUN, failed candidate stopped by correctness gate. |
| `pixi run --locked --offline research-a02 --device gpu` | 2 | UNSUPPORTED device for this runner. |

The unchanged Momijo baselines ran before adding the paper code. The commands below used `MOMIJO` for the independent source checkout and its activated toolchain, with output and temporary paths in the paper repository.

| Executed command | Exit |
| --- | ---: |
| `mojo run -I "$MOMIJO/src" -I "$MOMIJO" "$MOMIJO/tests/tensor/reshape_in_place.mojo"` | 0 |
| `mojo run -I "$MOMIJO/src" -I "$MOMIJO" "$MOMIJO/tests/tensor/smoke_cpu.mojo"` | 0 |
| `mojo run -I "$MOMIJO/src" -I "$MOMIJO" "$MOMIJO/tests/tensor_light/checked_layout_views.mojo"` | 0 |
| `mojo run -I "$MOMIJO/src" -I "$MOMIJO" "$MOMIJO/tests/tensor_light/smoke_cpu.mojo"` | 0 |
| `mojo run -I "$MOMIJO/src" -I "$MOMIJO" "$MOMIJO/tests/tensor_light/smoke_cpu_gemm_degenerate.mojo"` | 0 |

GitHub Actions is configured for the paper's self-contained tasks. Hosted CI, other hosts, and formal evidence collection were NOT_RUN. Zero benchmark samples were recorded. Z3 and hyperfine were available and unused for experiments. [Test scope](TEST_REPORT_A02_MOMIJO.md)

## V4 rerun on the current paper worktree

The pinned compiler was usable through Pixi with `TMPDIR`, `XDG_CACHE_HOME`, `MODULAR_CACHE_DIR` and `RATTLER_CACHE_DIR` set to existing repository-local directories. The Crashpad socket diagnostic persisted. The previously installed environment was reused.

| Executed command | Exit | Observation |
| --- | ---: | --- |
| `pixi run --locked --offline mojo --version` | 0 | Mojo 1.1.0 (8189361e). |
| `pixi run --locked --offline test-affine` | 0 | Affine producer, independent replay, tampered-witness rejection and finite cross-check. |
| `pixi run --locked --offline test-smoke` | 0 | Scalar identity. |
| `pixi run --locked --offline test-all` | 0 | Four source-only test programs, including the new affine suite. |
| `pixi run --locked --offline test-momijo` | 0 | General and Light adapter checks at the pinned clean source revision. |
| `pixi run --locked --offline package` | 0 | Fresh, nonempty `dist/layoutproof.mojoc`. |
| `pixi run --locked --offline mojo run -I dist tests/a02_smoke.mojo` | 0 | Compiled-package scalar test. |
| `pixi run --locked --offline mojo run -I dist tests/a02_affine.mojo` | 0 | Compiled-package affine proof and witness tests. |
| `pixi run --locked --offline research-a02 --check-only --case CASE --seed 42` | 0 each | Six cases. `affine-slice` PASS, `affine-slice-mutant` FAIL/LOGICAL. The four prior cases retained their verdicts. |
| `pixi run --locked --offline research-a02 --case affine-slice --output-root raw-evidence/v4-admission-probe` | 2 | NOT_RUN, canonical evidence protocols missing. The output directory was absent afterward. |

The five upstream CPU programs listed above were rerun through `pixi run --locked --offline mojo run -I "$A02_MOMIJO/src" -I "$A02_MOMIJO" "$A02_MOMIJO/tests/$file"`, where `A02_MOMIJO` was the pinned source checkout. All five exited 0. Hosted CI and canonical evidence validation were NOT_RUN.
