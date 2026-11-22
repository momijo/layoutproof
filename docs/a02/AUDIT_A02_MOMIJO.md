# A02 Momijo source audit

Paper baseline `3843c8734de9b83d34092c9b754245eb7fae29a5` tracked the license and README. The upstream source at the supplied pin `3c9fc14fa31f7bee8c8c783e191ca63dded57544` had a clean native source tree. The paper imports the upstream Mojo/MAX resolution byte for byte. Its source and tests are independent of the adapter tests.

| Upstream path at the pin | Verified capability | A02 role |
| --- | --- | --- |
| `src/momijo/tensor/storage.mojo`, `tensor/shape/shape.mojo`, `tensor/factory/creation.mojo` | `TensorF32` owns a contiguous CPU FP32 allocation. `RuntimeTensorShape.try_from_dims` handles runtime rank. `ones_f32`, `get`, `set`, and `reshape_in_place` support the dense adapter. | Implemented for the tested subset. Signed/zero-stride view and alias operations are unsupported for this adapter. Historical General `tensor/layout/` and `tensor/view/` anchors are absent at this pin. |
| `src/momijo/tensor_light/layout/layout.mojo`, `tensor_light/core/tensor.mojo`, `tensor_light/view/view.mojo` | `TensorLayout[rank].checked`, `physical_offset`, `TensorView.get` and rank-static FP32 methods. Native checks invoked `reshape_view`, `transpose`, `flip`, and `broadcast_to` with HostStorage. | Implemented for the exercised rank-two views. Light supports ranks 0–8. The upstream smoke suite tests its rank boundary. |
| `src/momijo/tensor_light/alias/overlap.mojo` | Range and host-span overlap helpers, including `ranges_disjoint` and `host_output_disjoint_from_input`. | Source-audited. Paper peer and write policy is an explicit analytical contract. The adapter exercises read views. |
| `tests/tensor/`, `tests/tensor_light/` | Five upstream executable programs, including CPU smoke, dense reshape, checked layouts and degenerate GEMM. | Observed CPU baseline. See build log. |
| `pixi.toml`, `.github/workflows/{ci,security,release,benchmarks}.yml` | Upstream toolchain and independent CI/release integration. No tracked modern examples or benchmark programs at this pin. | Paper-specific tasks and lock are local to this repository. GPU execution is NOT_RUN. |

The dependency uses MIT source terms. Pixi resolves Modular's Mojo/MAX distributions and their dependencies separately under their package terms. The research checker adds no external solver dependency. The supplied audit feedback identified TensorRight, ATL, CuTe, ISL, MLIR bufferization and BOLT as comparison candidates. This implementation round establishes no relative coverage or novelty finding.
