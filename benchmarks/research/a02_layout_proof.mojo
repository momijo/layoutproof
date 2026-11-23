# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: benchmarks/research/a02_layout_proof.mojo
# Module: benchmarks.research.a02_layout_proof

"""Native benchmark admission entry point. Canonical evidence is currently blocked."""

from std.sys import argv
from std.sys.terminate import exit
from layoutproof.a02.cases import affine_fixture, fixture
from layoutproof.a02.ir import Checks, Status, Verdict
from layoutproof.a02.affine_replay import admit_affine_write, replay_affine_counterexample
from layoutproof.a02.affine_solver import certify_affine
from layoutproof.a02.verifier import replay_counterexample, verify


@fieldwise_init
struct Options(Movable):
    var paper: String
    var engine: String
    var case_name: String
    var seed: Int
    var samples: Int
    var warmup: Int
    var timing: String
    var device: String
    var output_root: String
    var check_only: Bool


def help_text():
    print("Momijo LayoutProof (Mojo), A02")
    print("Usage: research-a02 [--check-only] [--paper A02] [--engine model|general|light|both]")
    print("  [--case flip-slice|slice-mutant|copy-mutant|aliased-write|affine-slice|affine-slice-mutant]")
    print("  [--seed N]")
    print("  [--samples N] [--warmup N] [--timing cold|warm] [--device cpu] [--output-root PATH]")
    print("Use --check-only for an untimed CPU model preflight. Canonical evidence is blocked.")
    print("Use --help or --version alone.")


def parse() raises -> Options:
    var options = Options("A02", "model", "flip-slice", 0, 10, 3, "warm", "cpu", "", False)
    var args = argv()
    var index = 1
    while index < len(args):
        var flag = String(args[index])
        index += 1
        if flag == "--check-only":
            options.check_only = True
            continue
        if index == len(args):
            raise Error("option requires a value: " + flag)
        var value = String(args[index])
        index += 1
        if flag == "--paper":
            options.paper = value^
        elif flag == "--engine":
            options.engine = value^
        elif flag == "--case":
            options.case_name = value^
        elif flag == "--seed":
            options.seed = atol(value)
        elif flag == "--samples":
            options.samples = atol(value)
        elif flag == "--warmup":
            options.warmup = atol(value)
        elif flag == "--timing":
            options.timing = value^
        elif flag == "--device":
            options.device = value^
        elif flag == "--output-root":
            options.output_root = value^
        else:
            raise Error("unknown option: " + flag)
    if options.paper != "A02" or options.seed < 0 or options.samples <= 0 or options.warmup < 0:
        raise Error("invalid paper, seed, samples or warmup")
    if options.timing != "cold" and options.timing != "warm":
        raise Error("timing mode must be cold or warm")
    if options.engine != "model" and options.engine != "general" and options.engine != "light" and options.engine != "both":
        raise Error("unknown engine")
    if options.check_only and options.output_root != "":
        raise Error("--check-only cannot create or request scientific output; remove --output-root")
    return options^


def run() raises -> Int:
    var args = argv()
    if len(args) == 2 and args[1] == "--help":
        help_text()
        return 0
    if len(args) == 2 and args[1] == "--version":
        print("Momijo LayoutProof 0.1.0")
        return 0
    var options = parse()
    if options.device != "cpu":
        print("UNSUPPORTED: DEVICE")
        return 2
    if options.engine != "model":
        print("UNSUPPORTED: ENGINE_BENCHMARK; use test-momijo for native adapter checks")
        return 2
    var use_affine = options.case_name == "affine-slice" or options.case_name == "affine-slice-mutant"
    var workload = (
        affine_fixture(options.case_name, options.seed)
        if use_affine else fixture(options.case_name, options.seed)
    )
    var result: Verdict
    if use_affine:
        var proved = certify_affine(workload.source, workload.reference, workload.candidate)
        if proved.verdict.status == Status.FAIL:
            if not proved.certificate or not replay_affine_counterexample(
                workload.source, workload.reference, workload.candidate,
                proved.certificate.take(), proved.verdict,
            ):
                print("ERROR ORACLE_DISAGREEMENT")
                return 1
        if proved.requires_write_admission:
            result = admit_affine_write(workload.source, workload.reference, workload.candidate,
                                        proved.certificate.take(), workload.peers)
        else:
            ref verdict = proved.verdict
            result = Verdict(verdict.status, verdict.reason, verdict.ordinal, verdict.other, verdict.detail.copy())
    else:
        result = verify(workload.source, workload.reference, workload.candidate, workload.peers)
        if result.status == Status.FAIL and not replay_counterexample(
            workload.source, workload.reference, workload.candidate, workload.peers,
            Checks.FULL, result,
        ):
            print("ERROR ORACLE_DISAGREEMENT")
            return 1
    print(result.status.code, result.reason.code, result.detail)
    if result.status != workload.expected or result.reason != workload.reason:
        return 1
    if options.check_only:
        return 0
    if result.status != Status.PASS:
        print("NOT_RUN: CORRECTNESS_GATE")
        return 2
    print("NOT_RUN: CANONICAL_EVIDENCE_PROTOCOLS_MISSING")
    return 2


def main():
    try:
        exit(run())
    except e:
        print("REJECTED:", e)
        exit(1)
