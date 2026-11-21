# A02 native test report

Four source-only Mojo test programs and one optional upstream adapter program were exercised. The packaged smoke program was also run against the generated `.mojoc`. The following claims apply to local regressions.

| Program | Assertions exercised |
| --- | --- |
| `tests/a02_smoke.mojo` | A scalar identity has one valid cell and returns PASS. |
| `tests/a02_layout_proof.mojo` | Runtime ranks 0–16, empty one-past origins, negative and zero strides, C/F reshape, 2–6-step compositions, signed slice fusion, incompatible broadcast and invalid indices/shapes, integer and allocation overflow, exact peer overlap, and permission checks. Checks reject copy and off-by-one mutants. Address and alias ablations each demonstrate the obligation they remove. Finite replay rejects a modified coordinate witness. |
| `tests/a02_certificate.mojo` | Double-flip replay for ranks 1–16, tampered axis descriptors, composition with permute and transpose, 48 small shape cross-checks of a symbolic certificate, mismatched permission, malformed permutations, unsupported operations and exhausted rank budget. |
| `tests/a02_affine.mojo` | Exact slice-fusion certificate with two probes for an input domain of one billion elements, first mismatch at C-order ordinal 1 for the mutated slice, tampered certificate and witness rejection, broadcast and rank changes, empty box, malformed slice, domain mismatch, and agreement with the finite checker on 16 small shapes. |
| `tests/a02_momijo_adapters.mojo` | Matching dense C reshape values in both independent engines. General also tests rejection of an invalid reshape and a rank-16 read. Light cross-checks actual transposed/flipped view addresses and values and a broadcast zero stride. |

The preflight runner observed the expected outcomes for six fixtures at seed 42. It refused the measurement request without creating the designated output directory. Test programs use fixed cases. The CLI accepts a deterministic seed. These cases provide regression coverage. The confirmatory holdout, native GPU, external baselines, measurement and canonical evidence validation are NOT_RUN. [Exact commands](BUILD_LOG_A02_MOMIJO.md)
