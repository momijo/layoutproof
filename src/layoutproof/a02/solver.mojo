# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: src/layoutproof/a02/solver.mojo
# Module: layoutproof.a02.solver

"""Symbolic normalization under common, defined input and permission predicates."""

from std.collections import List, Optional
from .ir import Kind, Program, Reason, Status
from .replay import AxisImage, Certificate, replay


@fieldwise_init
struct ProofResult(Movable):
    var status: Status
    var reason: Reason
    var certificate: Optional[Certificate]

    def requires_write_admission(self) -> Bool:
        return self.status == Status.PASS and self.reason == Reason.CONDITIONAL_EQUIVALENCE


def normalize(program: Program, rank: Int) -> Optional[List[AxisImage]]:
    var axes = List[AxisImage]()
    for i in range(rank):
        axes.append(AxisImage(i, False))
    for op in program.ops:
        if op.kind == Kind.TRANSPOSE or op.kind == Kind.FLIP:
            if op.axis < 0 or op.axis >= rank:
                return None
            if op.kind == Kind.TRANSPOSE:
                if op.first < 0 or op.first >= rank:
                    return None
                var a = axes[op.axis]
                axes[op.axis] = axes[op.first]
                axes[op.first] = a
            else:
                axes[op.axis].reversed = not axes[op.axis].reversed
        elif op.kind == Kind.PERMUTE:
            if len(op.dims) != rank:
                return None
            var next_axes = List[AxisImage]()
            var present = List[Bool](length=rank, fill=False)
            for index in op.dims:
                if index < 0 or index >= rank or present[index]:
                    return None
                next_axes.append(axes[index])
                present[index] = True
            axes = next_axes^
        else:
            return None
    return axes^


def certify(reference: Program, candidate: Program, rank: Int) -> ProofResult:
    if rank < 0 or rank > 64 or len(reference.ops) > 64 or len(candidate.ops) > 64:
        return ProofResult(Status.UNKNOWN, Reason.WORK_LIMIT, None)
    var expected = normalize(reference, rank)
    var observed = normalize(candidate, rank)
    if not expected or not observed:
        return ProofResult(Status.UNSUPPORTED, Reason.PROOF_FRAGMENT, None)
    var left = expected.take()
    var right = observed.take()
    if reference.writable != candidate.writable:
        return ProofResult(Status.FAIL, Reason.PERMISSION, None)
    for axis in range(rank):
        if left[axis] != right[axis]:
            return ProofResult(Status.UNKNOWN, Reason.CERTIFICATE, None)
    var certificate = Certificate(rank, left^)
    if not replay(reference, candidate, certificate):
        return ProofResult(Status.FAIL, Reason.CERTIFICATE, None)
    var reason = Reason.CONDITIONAL_EQUIVALENCE if reference.writable else Reason.EQUIVALENT
    return ProofResult(Status.PASS, reason, certificate^)


def manual_double_flip(reference: Program, candidate: Program, rank: Int) -> Bool:
    # Manual comparator for this rule only, with the same conditional domain.
    if len(reference.ops) != 2 or len(candidate.ops) != 0:
        return False
    ref first = reference.ops[0]
    ref second = reference.ops[1]
    return first.kind == Kind.FLIP and second.kind == Kind.FLIP \
        and first.axis == second.axis and first.axis >= 0 and first.axis < rank \
        and reference.writable == candidate.writable
