# Momijo LayoutProof (Mojo)

Momijo LayoutProof is the Mojo implementation of A02, *LayoutProof: Rank-Polymorphic Verification of Layout-Sensitive Tensor Transformations*. It checks whether two tensor-view programs agree on their output domain, logical index mapping, values, physical addresses and writable access. The paper code lives here. The two CPU tensor engines are maintained in the independent Momijo library. [A02 design and reproduction guide](docs/a02/README.md)

The native implementation includes checked signed-stride lowering and a bounded reference interpreter. Bounded counterexamples are reported by the forward interpreter and replayed using backward maps. Shape-polymorphic certificates cover signed permutations at a fixed rank. Exact affine certificates cover stepped slices, singleton insertion and removal, and broadcast at concrete shapes. The interpreter also checks C- and F-order reshapes. The General adapter exercises owned dense FP32 reshapes. The Light adapter exercises signed views, write-through access, and disjoint reshape copies. [Source and capability audit](docs/a02/AUDIT_A02_MOMIJO.md)

## Build and test

The Pixi lock resolves Mojo 1.1.0 and MAX 26.6.0. The verified target is Linux x86-64.

```sh
pixi install --locked
pixi run --locked mojo --version
pixi run --locked test-smoke
pixi run --locked test-all
pixi run --locked package
pixi run --locked mojo run -I dist tests/a02_smoke.mojo
```

Run the native adapters against the pinned Momijo checkout. The task defaults to `../../libraries/momijo` and checks the revision and source tree before compilation. The paper-only suite is `test-all`. CI runs the adapters separately with `test-momijo`.

```sh
MOMIJO_SOURCE_DIR=/path/to/momijo pixi run --locked test-momijo
pixi run --locked research-a02 --check-only --case flip-slice --seed 42
pixi run --locked research-a02 --check-only --case affine-slice --seed 42
```

The upstream source pin is `taleblou/momijo@3c9fc14fa31f7bee8c8c783e191ca63dded57544`. The paper package uses the same dependency lock and builds without the upstream source tree. Capture the paper revision and dirty-tree status separately when reproducing a run. [Dependency source pin](docs/a02/LIBRARY_SOURCE_PIN.txt) · [Executed commands](docs/a02/BUILD_LOG_A02_MOMIJO.md)

## Scientific scope

Finite checks cover every coordinate of an admitted concrete case. The affine checker establishes conditional equality on a concrete box from its origin and unit coordinates. The signed-permutation checker establishes conditional equality for all compatible extents at the certificate rank. Writable certificates require a separate concrete check against the declared live peers. Symbolic reasoning for arbitrary slice and broadcast extents, reshape certificates, production write safety, GPU execution, comparator replication and performance claims remain open.

The canonical input, output and non-tensor evidence contracts and their vectors are missing from the supplied protocol package. The benchmark entry point runs untimed admission checks and reports `NOT_RUN` for measurement. This checkout has no benchmark samples, cross-language conformance results or publication evidence. [Evidence blockers and next gates](docs/a02/HANDOFF_A02_MOMIJO.md)

The repository is MIT-licensed. [License and attribution](LICENSE)
