# A02 Mojo source-package release audit — 2026-11-23

**Status: SOURCE PACKAGE / NOT A SCIENTIFIC RESULTS RELEASE.**

## Upstream dependency and live-engine path

- Paper source: `momijo/layoutproof`, based on committed topic head `4d66b6a3a64de158c6a1d966071a6ebbd165f96a`.
- Native dependency: `taleblou/momijo@3c9fc14fa31f7bee8c8c783e191ca63dded57544`, checked in `pixi.toml`, native source selection and CI.
- `adapters/a02_general.mojo` imports upstream dense General FP32 types; `adapters/a02_light.mojo` imports upstream signed-stride Light views. They execute real storage operations.
- `test-full` and the CI workflow cover both `test-all` (independent proof implementation) and `test-momijo` (actual upstream engine adapter compilation/execution).
- `scripts/verify_native.sh` requires a matching clean local upstream checkout and runs all mandatory local native, paper-only and package gates.

## Verified for this downloadable archive

- Source layout, file hashes, headers, TOML/YAML and lockfile structure, native import references, task/CI dependency consistency, and shell syntax: checked offline.
- *Not executed here*: Mojo/Pixi compilation, upstream source runtime, package AOT, live GitHub Actions. This environment has neither Pixi/Mojo nor access to the user's live library checkout.
- Historical `BUILD_LOG_A02_MOMIJO.md` and `TEST_REPORT_A02_MOMIJO.md` refer to prior commits; they do **not** certify these changes.

## Must remain blocked before publication / `main` merge

1. The submitted source snapshot excluded **28 locally modified Mojo paths**, and later Codex changes are not present. Recover and reconcile those exact contents from `~/research-a02/papers/mojo-paper` **before** using this package on an active branch.
2. Run `bash scripts/verify_native.sh` with the pinned Momijo library and check GitHub CI for the final SHA.
3. No fully qualified native Momijo benchmark or canonical evidence writer is present: model-only preflight must not be called native measurement.
4. Obtain the authoritative common output contract, QTC1/QTO1/NTE1 protocols and vectors; independently validate all scientific evidence before claims.
5. Review and approve the draft PR; do not claim complete scientific verification from green standalone tests.

## Independent offline re-audit (2026-11-23)

- Scope: exact source files included in this archive, not the user's uncommitted Git worktree.
- Fixes/changes: Added CI Bash syntax check and an explicit guard against `--check-only --output-root` misuse; aligned local verifier and CI rejection tests; retained explicit model-only benchmark non-claim.
- Offline checks: ZIP archive integrity; manifest/config parsing; shell syntax; native adapter source and version pin consistency; repo-specific path/CI invariants; internal documentation references.
- Remaining release blockers: The benchmark CLI cannot produce measurements for real Momijo General/Light engines. Authoritative evidence contracts and uncommitted local sources were not available here.
- In this environment neither Rust/Cargo nor Pixi/Mojo was available, so successful compilation or executed proof/speedup is **not asserted**.
- These changes are an independently reviewed **source candidate**, not a scientifically certified release.
