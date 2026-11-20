# LayoutProof for Momijo

**Mojo-native research on rank-polymorphic verification of tensor layouts, views, and rewrite rules.**

[Momijo — Mojo AI framework](https://github.com/taleblou/momijo) · [Momiru — independent Rust framework](https://github.com/taleblou/momiru) · [Companion Rust LayoutProof study](https://github.com/momiru/layoutproof)

> **Research status — pre-results.** This is the dedicated **Momijo** implementation of the *LayoutProof* study (internal ID **A02**). The mathematical method, native checker, compiler tests, and any device measurements must pass the documented acceptance gates before any claim of formal verification, correctness, or speedup is made. This README defines the intended research contract; the original Momijo source archive and the complete common-protocol package must be audited/imported separately.

[Research problem](#research-problem) · [Method](#proposed-layoutproof-method) · [Evaluation](#evaluation-plan) · [Reproducibility](#reproducibility-and-evidence-integrity) · [Contributing](#contributing-and-engineering-standards)

## At a glance

| Item | Scope |
| --- | --- |
| Parent framework | **Momijo** — independently developed, Mojo-native AI/numerical framework |
| Repository | [`momijo/layoutproof`](https://github.com/momijo/layoutproof) |
| Primary language | **Mojo** for executable source, tests, codecs, and native measurement |
| Research focus | Tensor layout semantics, signed strides, alias safety, and checkable rewrite evidence |
| Engines | **General** runtime-rank tensors and an independent **Light** FP32 fixed-rank engine |
| Evidence | Independent checker, mutation controls, native schema-v4 samples, versioned provenance |
| Availability | Research implementation under development; **no validated results published yet** |

## Why Momijo?

**Momijo** is an open-source, Mojo-native project working toward a complete tensor, machine-learning, deep-learning, and numerical-computing framework. Its long-term vision includes autograd, neural-network training, data processing, and vision workflows, with the ambition to serve as a high-performance alternative to PyTorch **where verified and supported**. LayoutProof is a **focused companion research repository**, not a claim that those broader application modules are complete.

Momijo already organizes the source foundation around two *independent* tensor engines: `momijo.tensor` for General-purpose runtime-rank tensor operations, and `momijo.tensor_light` for a specialized FP32 fixed-rank contract (ranks 0–8). The study investigates how reshape, transpose, slicing, broadcasting, and other view/layout rewrites preserve observable semantics across those contracts. No automatic compatibility between engines or with the Rust implementation is assumed.

Mojo ownership/copy/move behavior, compile-time specialization, and device execution deserve **separate** verification. A source file or kernel declaration does not demonstrate a successfully compiled GPU path. Experiments must identify the installed Mojo/MAX toolchain, the exact compilation/execution mode, actual device support, and whether the run was CPU, GPU, AOT, or a nonexecuted model.

**Related projects:** [Momijo source foundation](https://github.com/taleblou/momijo), [Momiru source foundation](https://github.com/taleblou/momiru), and the [independent Rust companion study](https://github.com/momiru/layoutproof). The paired studies share *case definitions and evidence rules*, not one native implementation, an ABI, or identical runtime performance.

## Design boundaries in Momijo

The supplied article protocol identifies these **source-inspection anchors** in the Momijo source archive:

- `src/momijo/tensor/layout/` — General layout representation and transformations.
- `src/momijo/tensor/view/` — General tensor view operations and constraints.
- `src/momijo/tensor_light/alias/overlap.mojo` — Light-engine overlap/alias reasoning.

These paths are research audit anchors, **not** evidence of an existing formal-prover API. The baseline audit must inspect actual module exports, `pixi.toml`, runnable tasks, tests, examples, and benchmarks under the installed compiler. Any new research module must be importable through real package boundaries; keep an unmodified reference path for comparative experiments.

**Mojo-specific engineering rules:** executable implementations stay in `.mojo`; preserve verified project conventions, explicit ownership and checked error paths; avoid invented intrinsics, unchecked allocations, nested-function workarounds, or disabled tests. Keep General and Light independent. A device benchmark needs an actual supported compiler/backend and correct completion synchronization; an unsynchronized host launch is not GPU execution time.


## Research problem

Tensor rewrites are not correct merely because two expressions return the same values on a handful of shapes. A transformation can preserve logical elements while changing storage addresses, creating aliases, requiring materialization, or permitting unsafe writes. Zero-sized axes, scalar tensors, negative strides, broadcasted zero strides, and symbolic dimensions make these distinctions especially important.

For a signed-strided tensor view, the proposed model treats the address of a logical index **i** as:

$$
a(\mathbf{i}) = o + \sum_{k=0}^{r-1} i_k s_k
$$

where `o` is the storage offset, `s_k` is a signed stride, and the index domain is constrained by the tensor shape. The study separates **logical-value equivalence**, **physical address-map equivalence**, and **write/alias admissibility**. It checks allocation bounds and integer overflow rather than treating out-of-bounds addresses or overflow as valid examples.

### Research questions

1. **Correctness:** Which layout-sensitive tensor rewrites can be verified under explicit shape, storage, and alias preconditions?
2. **Comparative value:** Does the proposed proof-obligation approach offer a defensible improvement over suitable verification baselines and finite-model testing?
3. **Generalizability and cost:** What changes with rank, shape, stride family, solver resources, tensor engine, and available hardware?

This work is a **research hypothesis**, not an already established theorem or performance result.

## Proposed LayoutProof method

The intended mechanism is a typed intermediate representation for transformations such as `reshape`, `transpose`, `permute`, `slice`, `flip`, `expand`, `squeeze`, and `broadcast`.

1. **Normalize the contract:** Record shape/rank, dtype, signed strides, storage offset/extent, ownership/alias constraints, operation parameters, and applicable execution capabilities.
2. **Preflight:** Reject invalid inputs through checked arithmetic, bounds tests, and explicit eligibility checks; never rely on assertions for production validation.
3. **Construct obligations:** Formalize compatible domains, logical-index/value mappings, physical address mappings, and write permissions separately.
4. **Check candidates:** Use an appropriately supported symbolic method and/or finite enumeration; record solver assumptions, resource limits, and unresolved constraints.
5. **Independently verify evidence:** Replay counterexample models or proof/certificate evidence in a distinct checker; test deliberately incorrect rewrite mutants.
6. **Measure only admitted variants:** Correctness must pass for the exact `(case_id, variant)` before performance samples are used in an accepted comparison.

An exhaustive search over a *bounded* set of ranks and shapes is not presented as a universal proof. An inconclusive solver attempt remains `UNKNOWN`, including when a documented resource limit is reached.

### Result-state contract

| Status | Meaning |
| --- | --- |
| `PASS` | The applicable oracle or checker independently accepted this concrete result/evidence. |
| `REJECTED` | An invalid input or candidate was correctly refused, with a recorded reason. |
| `FAIL` | A mismatch, unsound certificate, invalid acceptance, or violated invariant was detected. |
| `UNKNOWN` | A supported analysis was inconclusive, including proof-search limits. |
| `UNSUPPORTED` | The requested engine, operation, dtype, rank, toolchain, or device capability is unavailable. |
| `NOT_RUN` | No attempted run occurred, or a required dependency/hardware was absent. |
| `ERROR` | An unexpected infrastructure failure or execution error occurred. |

`UNKNOWN`, `UNSUPPORTED`, `NOT_RUN`, and `ERROR` are never silently converted into `PASS`. Correctly rejected malformed inputs are not conflated with candidate correctness failures.

## Evaluation plan

The experiment matrix is anchored to **A02** and includes the following families:

| Family | Primary concern |
| --- | --- |
| `C00` | Eligible General/Light FP32 comparisons |
| `C01` | Rank boundaries: scalar, rank 1/8, and General-only rank 9/16 |
| `C02` | Contiguous, transposed, negative-stride, zero-stride, and aliased layouts |
| `C03` | Small/large shapes, resource stress, and checked overflow rejection |
| `C04` | Ablations with one meaningful mechanism varied at a time |
| `C05` | Predeclared held-out cases and uncertainty estimates |
| `C06` | Known-broken rewrites and mutation detection |
| `C07` | Real toolchain, CPU, and optional verified-device eligibility |
| `C08` | LayoutProof's primary compositions: 2–6 rewrite steps and symbolic/concrete shapes |
| `C09` | Proof/counterexample replay and resource-limited formal analysis |

The study covers rank 0, empty axes, singleton axes, ranks 1/2/4/8, and higher ranks **only where the General engine supports them**. Cases address overlapping writes, negative and broadcast strides, invalid offsets, and huge shapes that should fail safely. Each family is classified in an applicability matrix before execution; irrelevant experiments are not manufactured just to fill a template.

**Candidate baselines** include TensorRight, *A Verified Compiler for a Functional Tensor Language*, independent finite-model checking, unchanged native tensor behavior, and mutation-based validation. Compatibility and licensing must be checked before adopting any comparison. A stronger baseline may invalidate a novelty claim; negative findings remain reportable.

**Planned ablations** include disabling the physical-address obligation, disabling an alias precondition as a deliberately failing negative control, finite-only checking, symbolic-only checking, and manual/baseline rewrite validation. Intentionally unsound variants may be used to test detection, but must never enter an approved optimization path.

### Primary outcomes

- Number and coverage of verified rewrite rules and unsupported rule classes.
- Proof/decision time and solver resource use for eligible cases.
- Counterexample detection rate, reproducibility, and minimized witnesses.
- Failures and limitations under shape polymorphism.
- Correctness-filtered performance and overhead, with uncertainty, when native timed operations genuinely apply.

Planned article-specific artifacts are `rewrite_coverage.svg`, `proof_time_vs_complexity.svg`, `accepted_vs_rejected_rules.tsv`, and `proof_certificates/index.tsv`. These files are **not** claimed to exist or contain experimental results until generated and independently validated.

## Reproducibility and evidence integrity

The research uses the **package-root, schema-v4** contract named `COMMON_OUTPUT_CONTRACT.md` (from the separate article protocol package). Each actual tensor-native run writes immutable records outside the distributable source tree:

```
${RESEARCH_OUTPUT_ROOT}/A02/<repository>/<engine>/<run_id>/
  manifest.toml
  cases.tsv
  correctness.tsv
  raw_samples.tsv
  metrics.tsv
  failures.tsv
  ablations.tsv
  summary.md
```

The reporting stage, which is separate from native execution, uses:

```
${RESEARCH_OUTPUT_ROOT}/A02/aggregate/<analysis_run_id>/
  analysis_manifest.toml
  input_audit.tsv
  case_eligibility.tsv
  comparisons.tsv
  statistics.tsv
  report_validation.tsv
  figures/
  tables/
  summary.md
  reproducibility.md
  artifact_checksums.sha256
```

Native output columns and their semantics must come from the canonical contract; this README does not define a competing schema. Raw samples, correctness verdicts, and manifests are immutable, and aggregate reports never overwrite them. Each case has an independently reproducible input digest, a concrete variant-specific oracle outcome, and recorded source/toolchain/hardware provenance.

### Portable input, output, and non-tensor protocols

- **QTC1** is the versioned portable tensor *input* corpus. Exact cross-language input equivalence requires independent Rust and Mojo codec conformance, matching bytes/hashes and semantic contracts (including storage alias topology, signed zero and NaN representation where applicable).
- **QTO1** is versioned *observed numerical output* evidence, combined with a genuinely independent numerical oracle, declared tolerances, and post-state/alias checks. Matching digests alone do not establish correctness; tolerant outputs may correctly have different digests.
- **NTE1** is the separate evidence route for proof-only queries or installation/provenance checks with **no actual tensor operand**. Never invent a dummy tensor to fit tensor-run schema v4.

These are **protocol requirements**, not claims that native codecs, proof solvers, or test vectors have already passed. Their canonical definitions, positive/negative fixtures, and output evidence rules must be imported/pinned from the complete research protocol package before measurement. Actual cross-language comparisons require both independent native conformance reports and **separately pinned** source revisions; commit hashes from distinct repositories are not expected to be identical.

### Measurement admission rules

1. Freeze each repository's baseline commit, compiler and dependency versions, semantic contract, case corpus, and oracle version.
2. Predeclare comparisons, timing boundaries, eligibility rules, and relevant confidence/uncertainty procedures.
3. Run correctness and evidence verification *before* accepting any timed candidate variant.
4. Do not compare compiler-inclusive durations to kernel-only or allocation-inclusive durations.
5. Retain every valid and failed raw attempt; do not turn missing or failed measurements into zero latency.
6. Report GPU performance **only** after a supported device executes and synchronizes the measured kernel. Otherwise mark `NOT_RUN` or `UNSUPPORTED` with a reason.
7. Use observed, independently validated measurements when editing the manuscript; never insert projected numbers as findings.


## Getting started — Momijo (Mojo)

**Prerequisites:** Linux/macOS targets actually supported by the imported `pixi.toml`, [Pixi](https://pixi.sh/), access to the required Modular packages, and the source-pinned Mojo/MAX toolchain. For Windows development, prefer a supported Linux/WSL2 environment over assuming native Windows Mojo support. Resolve the toolchain specified by the imported manifest; do not substitute syntax from a different Mojo release.

```bash
# Clone the article repository after it has been created and populated.
git clone https://github.com/momijo/layoutproof.git
cd layoutproof

# Record the exact source and environment.
git rev-parse HEAD
pixi --version

# After the verified Momijo pixi.toml has been imported:
pixi lock
pixi install
pixi task list
```

The source Momijo project documents these Pixi tasks in its own `pixi.toml`. They should be **reconfirmed against the imported manifest and compiler** before use:

```bash
pixi run list-tests
pixi run test-smoke
pixi run test-tensor
pixi run test-tensor-light
pixi run test-all

# Parent-framework demonstrations (not LayoutProof results):
pixi run mojo run -I src -I . examples/tensor/creation.mojo
pixi run mojo run -I src -I . examples/tensor_light/creation.mojo
```

These are candidate baseline verification commands, **not statements that they have already succeeded in the LayoutProof repository**. If the commands or toolchain have changed, update this section from actual `pixi task list` output rather than inventing a compatibility workaround. Generate a real `pixi.lock` using an accessible environment and pin it according to project policy.

### Intended research entry points (not yet certified)

The Mojo-native A02 runner should support `--paper A02`, an eligible engine selector (`general`, `light`, or `both`), deterministic `--seed`, workload/case selection, warmup/repetition settings, and `--output-root`. The **exact Mojo path and Pixi task name must follow verified compiler behavior and checked-in task registration**. The article README deliberately does not present a fictional `pixi run research-a02` task as already working.

### Planned repository layout after source import

```text
layoutproof/
├── src/momijo/                  # Existing Momijo source root
│   ├── tensor/                  # General runtime-rank tensor engine
│   └── tensor_light/            # Independent FP32 Light engine
├── tests/                       # Existing suites + A02 Mojo regression tests
├── benchmarks/research/         # A02 native Mojo benchmarks when registered
├── docs/research/A02/           # Protocol, applicability, design, audit and handoff
├── .github/workflows/           # Mojo validation and research CI
├── AGENTS.md                    # Short, source-backed coding-agent instructions
├── pixi.toml                    # Verified toolchain and task source of truth
├── pixi.lock                    # Genuine resolved lockfile, when created
├── LICENSE                      # Original MIT attribution retained
└── README.md
```

This is a **target map**, not a guarantee that all files and tasks already exist in the new repository. Future Momijo `learn`, `vision`, `dataframe`, and `visual` domains must not be advertised as completed applications merely because a namespace exists.

## Release readiness — Mojo-specific gates

- Inspect compiler/toolchain versions and run the actual smoke and General/Light suites; preserve exact commands, exit codes, and errors. Absent toolchains produce `NOT_RUN`, not a fabricated pass.
- Preserve the independent General and Light semantics, especially Light's FP32 rank 0–8 boundary and any verified ownership/alias limitations.
- Use a genuinely independent reference interpreter and checker; mutated, known-invalid rewrites must be reliably rejected before performance claims.
- Report actual CPU-vs-GPU execution and synchronize supported accelerator operations. GPU-themed code and CPU simulations are **not** measurements on a real device.
- Keep only `.mojo` executable/research code in the Momijo source distribution, along with permitted TOML/YAML/Markdown/license metadata. Do not add Rust or Python implementation files, generated binaries, temporary caches, or raw benchmark records.
- If symbolic reasoning requires an external non-Mojo solver wrapper, keep it in a separately identified research environment and never disguise it as native Mojo code or silently violate the repository language policy.

## Scientific provenance and article

- **Study identifier:** `A02` (an internal project ID, deliberately excluded from the repository slug).
- **Working paper title:** *LayoutProof: Rank-Polymorphic Verification of Layout-Sensitive Tensor Transformations*.
- **Manuscript status:** Pre-results research draft; no formal result, performance advantage, device capability, or acceptance by a journal is asserted.
- **Proposed target venue:** *Proceedings of the ACM on Programming Languages* (venue fit to be assessed, not an accepted publication).
- **Protocol:** `RESEARCH_SPEC.md`, `EXPERIMENT_MATRIX.tsv`, `ACCEPTANCE_CHECKLIST.md`, and the normative common-output / portable-case / output-evidence / non-tensor specifications.

The research program uses this order: architecture and prior-work audit → native implementation and regression testing → independent benchmark/report validation → evidence-backed manuscript revision → independent red-team audit. No step is marked complete solely because its instructions exist.

### Relevant prior work (starting points, not an exhaustive review)

- Arora *et al.* (2025), [TensorRight: Automated Verification of Tensor Graph Rewrites](https://doi.org/10.1145/3704865).
- Liu, Bernstein, Chlipala, and Ragan-Kelley (2024), [A Verified Compiler for a Functional Tensor Language](https://doi.org/10.1145/3656390).
- [MLIR One-Shot Bufferization](https://mlir.llvm.org/docs/Bufferization/) (official documentation).
- [NumPy ndarray strides](https://numpy.org/doc/stable/reference/generated/numpy.ndarray.strides.html) (official documentation).

All bibliographic entries, author lists, publication dates, and direct-method comparisons must be independently rechecked against primary sources before submission.

## Contributing and engineering standards

Contributions should be narrowly scoped, independently reviewable, and tied to a testable contract. Please open an issue describing the semantic claim or defect, the affected operation/engine, a minimal counterexample, and its expected outcome. Pull requests should include negative and boundary tests, exact build/test commands with outcomes, and a source-to-evidence explanation if a scientific claim changes. Never suppress a failing test or replace measured observations with synthetic successes.

Do not commit secrets, local machine paths, private datasets, generated binaries, build caches, or raw benchmark output to a public release. Preserve all inherited copyright and third-party notices. Vulnerabilities that could expose data or cause memory unsafety should be reported privately to repository maintainers when a security contact is published.

## Maintainers, licensing, and citation

**Project founders and maintainers:** Morteza Taleblou and Mitra Daneshmand. Maintainer status does not determine the final scientific manuscript author order, affiliations, or contribution statements; those will be confirmed by the authors.

The source foundation is MIT-licensed. Preserve the original **MIT `LICENSE`**, both copyright holders, and any third-party notices when creating this article repository. No source license may be changed implicitly by copying research code. See the checked-in license after the baseline source import.

When a paper or archived release becomes available, add the verified DOI, tagged source revision, and a correct `CITATION.cff`. Until then, cite this repository by its exact URL, commit SHA, and access date rather than inventing publication metadata.

---

*LayoutProof is an independent, evidence-driven research implementation associated with its parent framework—not a claim that the entire framework, GPU stack, or formal verification system is already complete.*
