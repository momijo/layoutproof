# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: src/layoutproof/a02/affine_solver.mojo
# Module: layoutproof.a02.affine_solver

"""Produce exact affine certificates for concrete-shape strided view rewrites."""

from std.collections import List, Optional
from .affine_replay import AffineCertificate, AffinePoint, check_fragment, check_program
from .arithmetic import address, count
from .ir import Layout, Program, Reason, Status, Verdict
from .lowering import Lowered, lower
from .oracle import fits
from .verifier import budgeted, decision, validate_inputs


struct AffineResult(Movable):
    var verdict: Verdict
    var certificate: Optional[AffineCertificate]
    var requires_write_admission: Bool

    def __init__(out self, var verdict: Verdict, var certificate: Optional[AffineCertificate],
                 requires_write_admission: Bool = False):
        self.verdict = verdict^
        self.certificate = certificate^
        self.requires_write_admission = requires_write_admission


def propose(source: Layout, mapping: Lowered, writable: Bool) raises -> AffineCertificate:
    ref shape = mapping.output.shape
    var points = List[AffinePoint]()
    if count(shape) != 0:
        var index = List[Int](length=len(shape), fill=0)
        points.append(AffinePoint(mapping.lineage(source, index), address(mapping.output, index)))
        for axis in range(len(shape) - 1, -1, -1):
            if shape[axis] > 1:
                index[axis] = 1
                points.append(AffinePoint(mapping.lineage(source, index), address(mapping.output, index)))
                index[axis] = 0
    return AffineCertificate(shape.copy(), mapping.output.storage, writable, points^)


def certify_affine(source: Layout, reference: Program, candidate: Program) -> AffineResult:
    """Decide equality of supported view maps, conditional on admissible access."""
    if not budgeted(source, reference, 0) or not budgeted(source, candidate, 0):
        return AffineResult(decision(Status.UNKNOWN, Reason.WORK_LIMIT), None)
    if not check_fragment(reference) or not check_fragment(candidate):
        return AffineResult(decision(Status.UNSUPPORTED, Reason.PROOF_FRAGMENT), None)
    try:
        validate_inputs(source, [])
    except e:
        return AffineResult(decision(Status.REJECTED, Reason.INVALID_INPUT, String(e)), None)
    try:
        if not fits(source, reference, Int.MAX):
            return AffineResult(decision(Status.UNKNOWN, Reason.WORK_LIMIT), None)
    except e:
        return AffineResult(decision(Status.REJECTED, Reason.INVALID_REFERENCE, String(e)), None)
    try:
        if not fits(source, candidate, Int.MAX):
            return AffineResult(decision(Status.UNKNOWN, Reason.WORK_LIMIT), None)
    except e:
        return AffineResult(decision(Status.FAIL, Reason.INVALID_CANDIDATE, String(e)), None)
    try:
        var mapping = lower(source, reference)
        var certificate = propose(source, mapping, reference.writable)
        # Independently establish every point on the reference before the
        # candidate checker can treat a difference as a counterexample.
        if check_program(source, reference, certificate).status != Status.PASS:
            return AffineResult(decision(Status.FAIL, Reason.ORACLE_DISAGREEMENT), None)
        var result = check_program(source, candidate, certificate)
        if result.status != Status.PASS and result.status != Status.FAIL:
            return AffineResult(result^, None)
        if result.status == Status.PASS and reference.writable:
            return AffineResult(
                decision(Status.PASS, Reason.CONDITIONAL_EQUIVALENCE,
                         "map equality requires separate admission against the current live peers"),
                certificate^,
                True,
            )
        # On mismatch this is the validated reference table, not a proof of equality.
        return AffineResult(result^, certificate^)
    except e:
        return AffineResult(decision(Status.ERROR, Reason.ORACLE_DISAGREEMENT, String(e)), None)
