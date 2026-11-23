#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: scripts/verify_native.sh
# Purpose: Compile and exercise both pinned Momijo engines, not just the paper model.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$root"
export MOMIJO_SOURCE_DIR=${MOMIJO_SOURCE_DIR:-"$root/../../libraries/momijo"}
pin=3c9fc14fa31f7bee8c8c783e191ca63dded57544

printf '%s\n' 'A02 Mojo | PRE-PUBLICATION native validation (not scientific evidence)'
for tool in pixi git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'ERROR: required tool is not installed/on PATH: %s\n' "$tool" >&2
    exit 3
  fi
done
if [[ ! -d "$MOMIJO_SOURCE_DIR" ]]; then
  printf 'ERROR: missing pinned Momijo checkout: %s\n' "$MOMIJO_SOURCE_DIR" >&2
  exit 4
fi
observed=$(git -C "$MOMIJO_SOURCE_DIR" rev-parse --verify HEAD)
if [[ "$observed" != "$pin" ]]; then
  printf 'ERROR: Momijo HEAD %s differs from required %s\n' "$observed" "$pin" >&2
  exit 5
fi
if [[ -n $(git -C "$MOMIJO_SOURCE_DIR" status --porcelain -- src/momijo) ]]; then
  printf '%s\n' 'ERROR: pinned Momijo src/momijo has local changes' >&2
  exit 5
fi
if ! grep -Fq "$pin" pixi.toml || ! grep -Fq "$pin" docs/a02/LIBRARY_SOURCE_PIN.txt; then
  printf '%s\n' 'ERROR: Pixi native adapter task and documented source pin differ' >&2
  exit 6
fi

pixi install --locked
pixi run --locked test-all
# These execute genuine upstream General/Light APIs, not the standalone proof model.
native_output=$(pixi run --locked test-momijo)
printf '%s\n' "$native_output"
if ! grep -Fq 'PASS: Momijo General FP32 owned C-order reshape' <<<"$native_output" || \
   ! grep -Fq 'PASS: Momijo Light FP32 transpose, negative stride and broadcast' <<<"$native_output"; then
  printf '%s\n' 'ERROR: the native test task did not demonstrate BOTH upstream engines' >&2
  exit 6
fi
pixi run --locked package
pixi run --locked mojo run -I dist tests/a02_smoke.mojo
pixi run --locked research-a02 --check-only --case flip-slice --seed 7
pixi run --locked research-a02 --check-only --case affine-slice --seed 7
# A successful preflight cannot also be mistaken for an evidence export.
misuse_result=0
pixi run --locked research-a02 --check-only --output-root dist/evidence || misuse_result=$?
if [[ "$misuse_result" -ne 1 || -e dist/evidence ]]; then
  printf 'ERROR: --check-only with --output-root was not rejected (exit=%s)\n' "$misuse_result" >&2
  exit 7
fi
# The evidence runner MUST refuse to export purported measurements.
result=0
pixi run --locked research-a02 --output-root dist/evidence || result=$?
if [[ "$result" != 2 || -e dist/evidence ]]; then
  printf 'ERROR: missing-protocol evidence gate did not fail closed (exit=%s)\n' "$result" >&2
  exit 7
fi
printf '%s\n' 'PASS: Mojo model tests, pinned Momijo General/Light adapters and package smoke'
printf '%s\n' 'NOT_CERTIFIED: no native benchmark data or QTC1/QTO1/NTE1 evidence was generated'
