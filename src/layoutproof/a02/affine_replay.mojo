# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Replay concrete-shape affine view certificates without enumerating cells."""

from std.collections import List
from .arithmetic import count, equal, validate
from .ir import Checks, Kind, Layout, Program, Reason, Status, Verdict
from .oracle import digits, lookup, next_shape, row_number, validate_step
from .verifier import decision, verify


@fieldwise_init
struct AffinePoint(ImplicitlyCopyable):
    var lineage: Int
    var address: Int


@fieldwise_init
struct AffineCertificate(Movable):
    var shape: List[Int]
    var storage: Int
    var writable: Bool
    # Origin followed by unit coordinates on nonsingleton axes in reverse axis order.
    var points: List[AffinePoint]


def check_fragment(program: Program) -> Bool:
    for op in program.ops:
        if op.kind == Kind.RESHAPE:
            return False
    return True


def check_program(source: Layout, program: Program, certificate: AffineCertificate) raises -> Verdict:
    if len(source.shape) > 64 or len(program.ops) > 64 or len(certificate.shape) > 64:
        return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
    if not check_fragment(program):
        return decision(Status.UNSUPPORTED, Reason.PROOF_FRAGMENT)
    if source.storage < 0 or source.storage != certificate.storage:
        return decision(Status.FAIL, Reason.ADDRESS)
    validate(source)
    var shapes = List[List[Int]]()
    shapes.append(source.shape.copy())
    for i in range(len(program.ops)):
        ref op = program.ops[i]
        if len(op.dims) > 64:
            return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        validate_step(shapes[i], op)
        var shape = next_shape(shapes[i], op)
        if len(shape) > 64:
            return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        _ = count(shape)
        shapes.append(shape^)
    ref output = shapes[len(program.ops)]
    if not equal(output, certificate.shape):
        return decision(Status.FAIL, Reason.DOMAIN)
    if program.writable != certificate.writable:
        return decision(Status.FAIL, Reason.PERMISSION)
    if count(output) == 0:
        if len(certificate.points) != 0:
            return decision(Status.FAIL, Reason.CERTIFICATE)
        return decision(Status.PASS, Reason.EQUIVALENT)

    var coordinate = List[Int](length=len(output), fill=0)
    var point = 0
    for axis in range(len(output), -1, -1):
        if axis < len(output):
            if output[axis] == 1:
                continue
            coordinate[axis] = 1
        if point >= len(certificate.points):
            return decision(Status.FAIL, Reason.CERTIFICATE)
        var ordinal = row_number(output, coordinate)
        var lineage = ordinal
        var indices = coordinate.copy()
        for i in range(len(program.ops) - 1, -1, -1):
            lineage = lookup(shapes[i], shapes[i + 1], indices, lineage, program.ops[i])
            indices = digits(shapes[i], lineage)
        # A checked source layout bounds the products and all partial sums.
        var physical = source.offset
        for i in range(len(indices)):
            physical += indices[i] * source.strides[i]
        var claimed = certificate.points[point]
        if claimed.lineage != lineage:
            return decision(Status.FAIL, Reason.LOGICAL, ordinal=ordinal)
        if claimed.address != physical:
            return decision(Status.FAIL, Reason.ADDRESS, ordinal=ordinal)
        point += 1
        if axis < len(output):
            coordinate[axis] = 0
    if len(certificate.points) != point:
        return decision(Status.FAIL, Reason.CERTIFICATE)
    return decision(Status.PASS, Reason.EQUIVALENT)


def replay_affine(source: Layout, reference: Program, candidate: Program,
                  certificate: AffineCertificate) -> Bool:
    """Replay map equality. For mutable access, call admit_affine_write separately."""
    # Every admitted transform is affine in its output coordinates. Agreement
    # at the origin and along the active axes fixes all affine coefficients.
    try:
        return check_program(source, reference, certificate).status == Status.PASS and (
            check_program(source, candidate, certificate).status == Status.PASS
        )
    except:
        return False


def admit_affine_write(source: Layout, reference: Program, candidate: Program,
                       certificate: AffineCertificate, live_peers: List[Layout],
                       cap: Int = 256) -> Verdict:
    """Check writable admission for the supplied snapshot of all live peer views."""
    if not reference.writable or not candidate.writable:
        return decision(Status.REJECTED, Reason.PERMISSION, "write admission requires writable programs")
    if not replay_affine(source, reference, candidate, certificate):
        return decision(Status.FAIL, Reason.CERTIFICATE)
    return verify(source, reference, candidate, live_peers, Checks.FULL, cap)


def replay_affine_counterexample(source: Layout, reference: Program, candidate: Program,
                                 certificate: AffineCertificate, witness: Verdict) -> Bool:
    if witness.status != Status.FAIL or (
        witness.reason != Reason.DOMAIN and witness.reason != Reason.PERMISSION
        and witness.reason != Reason.LOGICAL and witness.reason != Reason.ADDRESS
    ):
        return False
    try:
        if check_program(source, reference, certificate).status != Status.PASS:
            return False
        var observed = check_program(source, candidate, certificate)
        return (
            observed.status == Status.FAIL and observed.reason == witness.reason
            and observed.ordinal == witness.ordinal and observed.other == witness.other
        )
    except:
        return False
