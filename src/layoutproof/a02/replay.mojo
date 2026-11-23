# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: src/layoutproof/a02/replay.mojo
# Module: layoutproof.a02.replay

"""Independent symbolic certificate checker for signed axis permutations."""

from std.collections import List
from .ir import Checks, Kind, Layout, Program, Reason, Status, Verdict
from .verifier import decision, verify


@fieldwise_init
struct AxisImage(ImplicitlyCopyable, Equatable):
    var source: Int
    var reversed: Bool


@fieldwise_init
struct Certificate(Movable):
    var rank: Int
    var image: List[AxisImage]


def fragment(program: Program, rank: Int) -> Bool:
    if rank < 0 or rank > 64 or len(program.ops) > 64:
        return False
    for op in program.ops:
        if op.kind == Kind.PERMUTE:
            if len(op.dims) != rank:
                return False
            var seen = List[Bool](length=rank, fill=False)
            for axis in op.dims:
                if axis < 0 or axis >= rank or seen[axis]:
                    return False
                seen[axis] = True
        elif op.kind == Kind.TRANSPOSE or op.kind == Kind.FLIP:
            if op.axis < 0 or op.axis >= rank:
                return False
            if op.kind == Kind.TRANSPOSE and (op.first < 0 or op.first >= rank):
                return False
        else:
            return False
    return True


def pulls_back(program: Program, output_axis: Int) -> AxisImage:
    var axis = output_axis
    var reverse = False
    for step in range(len(program.ops) - 1, -1, -1):
        ref op = program.ops[step]
        if op.kind == Kind.PERMUTE:
            axis = op.dims[axis]
        elif op.kind == Kind.TRANSPOSE:
            if axis == op.axis:
                axis = op.first
            elif axis == op.first:
                axis = op.axis
        elif op.kind == Kind.FLIP and axis == op.axis:
            reverse = not reverse
    return AxisImage(axis, reverse)


def replay(reference: Program, candidate: Program, certificate: Certificate) -> Bool:
    """Replay a fixed-rank map theorem. Mutable access requires separate admission."""
    # Each output axis selects one input extent. Its coordinate is either j
    # or extent - 1 - j. Equal axis images imply equal maps for every extent.
    if reference.writable != candidate.writable or len(certificate.image) != certificate.rank:
        return False
    if not fragment(reference, certificate.rank) or not fragment(candidate, certificate.rank):
        return False
    for axis in range(certificate.rank):
        var expected = certificate.image[axis]
        if pulls_back(reference, axis) != expected or pulls_back(candidate, axis) != expected:
            return False
    return True


def admit_symbolic_write(source: Layout, reference: Program, candidate: Program,
                         certificate: Certificate, live_peers: List[Layout],
                         cap: Int = 256) -> Verdict:
    """Check concrete write admission against the supplied live peer views."""
    if not reference.writable or not candidate.writable:
        return decision(Status.REJECTED, Reason.PERMISSION, "write admission requires writable programs")
    if len(source.shape) != certificate.rank or not replay(reference, candidate, certificate):
        return decision(Status.FAIL, Reason.CERTIFICATE)
    return verify(source, reference, candidate, live_peers, Checks.FULL, cap)
