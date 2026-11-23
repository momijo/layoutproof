# Source-package provenance and status (2026-11-23)

This is an **independent source package** for the A02 Mojo paper repository,
`https://github.com/momijo/layoutproof`. It is **not** a scientific results release.

- Base: last supplied **committed** source snapshot,
  `A02_LayoutProof_Paper_Code_DRAFT_20261123T111548337109Z.zip`,
  from the user's A02 diagnostic archive. Commit `4d66b6a3a64de158c6a1d966071a6ebbd165f96a`
  on `codex/a02-layoutproof`.
- Pinned Momijo library: `https://github.com/taleblou/momijo`,
  commit `3c9fc14fa31f7bee8c8c783e191ca63dded57544`.
- **Important:** the snapshot exporter excluded **28 local modified paths**
  from the Mojo paper. In the subsequent V12 execution, Codex reported
  additional fixes and tests but they were not committed or included in the
  supplied source snapshot. This package cannot reproduce those edits
  without their actual file bytes.
- Existing Mojo source headers use the same SPDX three-line copyright
  convention for Morteza Taleblou and Mitra Daneshmand. Both authors are
  also named in the MIT license in this package.
- No native Mojo compiler, Pixi, upstream library checkout, or live GitHub CI
  was run **while producing this package**. Historical reports under `docs/a02/`
  are inherited from the snapshot and do not certify this revised package.

## Before publishing

Compare the package against the **current local checkout including all 28
uncommitted paths**. Never replace newer local Codex changes with older files.
Run on the project's Linux workstation:

```sh
pixi install --locked
pixi run --locked test-all
MOMIJO_SOURCE_DIR="$HOME/research-a02/libraries/momijo" pixi run --locked test-momijo
pixi run --locked package
pixi run --locked mojo run -I dist tests/a02_smoke.mojo
```

The scientific QTC1, QTO1 and NTE1 protocols and independent evidence are
still required before publishing any formal or empirical claims.

## Header convention

Mojo file headers mirror the Momijo SPDX + Source + Module convention. The original upstream files were not rewritten; these paper sources use the same two-author attribution.

## Post-package dependency audit

Added a checked local native-verification script, a release-audit status document,
README verification instructions, and required native validation integration.
For the exact changes and remaining verification limits, use
[`RELEASE_AUDIT.md`](RELEASE_AUDIT.md). Earlier build reports are inherited and
must not be interpreted as a PASS for this packaged revision.
