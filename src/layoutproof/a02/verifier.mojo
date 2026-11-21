# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Bounded cross-check and deterministic, independently replayed witnesses."""

from std.collections import List, Set
from .arithmetic import address, count, decode, equal, validate
from .ir import Checks, Layout, Order, Program, Reason, Status, Verdict
from .lowering import Lowered, lower
from .oracle import Frame, first_alias, fits, interpret_bounded


def decision(status: Status, reason: Reason, var detail: String = "",
             ordinal: Int = -1, other: Int = -1) -> Verdict:
    return Verdict(status, reason, ordinal, other, detail^)


def validate_inputs(source: Layout, peers: List[Layout]) raises:
    if source.storage < 0:
        raise Error("negative storage identity is reserved for materializations")
    validate(source)
    for i in range(len(peers)):
        ref peer = peers[i]
        if peer.storage < 0:
            raise Error("negative peer storage identity")
        validate(peer)
        if peer.storage == source.storage and peer.capacity != source.capacity:
            raise Error("inconsistent source storage capacity")
        for j in range(i):
            if peer.storage == peers[j].storage and peer.capacity != peers[j].capacity:
                raise Error("inconsistent peer storage capacity")


def budgeted(source: Layout, program: Program, cap: Int) -> Bool:
    if len(source.shape) > 64 or len(source.strides) > 64 or len(program.ops) > 64:
        return False
    for op in program.ops:
        if len(op.dims) > 64:
            return False
    return cap >= 0 and cap <= 4096


def evaluate_lowering(source: Layout, compiled: Lowered, frame: Frame) raises -> Bool:
    ref result = compiled.output
    if (
        not equal(result.shape, frame.shape)
        or result.storage != frame.storage
        or result.write_capable != frame.write_capable
        or count(result.shape) != len(frame.cells)
    ):
        return False
    for n in range(len(frame.cells)):
        var index = decode(result.shape, n, Order.C)
        var ordinal = compiled.lineage(source, index)
        if ordinal != frame.cells[n].source or address(result, index) != frame.cells[n].physical:
            return False
        var input_index = decode(source.shape, ordinal, Order.C)
        if address(source, input_index) != frame.cells[n].value:
            return False
    return True


def has_lowered_alias(result: Layout, peers: List[Layout]) raises -> Bool:
    var seen = Set[Int]()
    for n in range(count(result.shape)):
        var offset = address(result, decode(result.shape, n, Order.C))
        if offset in seen:
            return True
        seen.add(offset)
    for peer in peers:
        if peer.storage == result.storage:
            for n in range(count(peer.shape)):
                var offset = address(peer, decode(peer.shape, n, Order.C))
                if offset in seen:
                    return True
    return False


def compare_frames(left: Frame, right: Frame, left_write: Bool, right_write: Bool,
                   peers: List[Layout], checks: Checks) -> Verdict:
    if not equal(left.shape, right.shape):
        return decision(Status.FAIL, Reason.DOMAIN)
    if checks.address and left.storage != right.storage and len(left.cells) == 0:
        return decision(Status.FAIL, Reason.ADDRESS, "different empty-result storage")
    for i in range(len(left.cells)):
        var a = left.cells[i]
        var b = right.cells[i]
        if a.source != b.source:
            return decision(Status.FAIL, Reason.LOGICAL, ordinal=i)
        if a.value != b.value:
            return decision(Status.FAIL, Reason.VALUE, ordinal=i)
        if checks.address and (left.storage != right.storage or a.physical != b.physical):
            return decision(Status.FAIL, Reason.ADDRESS, ordinal=i)
    if left_write != right_write:
        return decision(Status.FAIL, Reason.PERMISSION)
    if checks.alias and left_write:
        if not right.write_capable:
            return decision(Status.FAIL, Reason.PERMISSION, "candidate storage is read-only")
        var b = first_alias(right, peers)
        if b[0] >= 0:
            return decision(Status.FAIL, Reason.ALIAS, "candidate write overlaps", b[0], b[1])
    return decision(Status.PASS, Reason.EQUIVALENT)


def verify(source: Layout, reference: Program, candidate: Program, peers: List[Layout],
           checks: Checks = Checks.FULL, cap: Int = 256, finite_only: Bool = False) -> Verdict:
    if len(peers) > 16 or not budgeted(source, reference, cap) or not budgeted(source, candidate, cap):
        return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
    try:
        for peer in peers:
            if len(peer.shape) > 64 or len(peer.strides) > 64:
                return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        validate_inputs(source, peers)
        if count(source.shape) > cap:
            return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        for peer in peers:
            if count(peer.shape) > cap:
                return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
    except e:
        return decision(Status.REJECTED, Reason.INVALID_INPUT, String(e))

    var expected: Frame
    var observed: Frame
    try:
        if not fits(source, reference, cap):
            return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        expected = interpret_bounded(source, reference)
    except e:
        return decision(Status.REJECTED, Reason.INVALID_REFERENCE, String(e))
    if checks.alias and reference.writable:
        if not expected.write_capable:
            return decision(Status.REJECTED, Reason.PERMISSION, "reference storage is read-only")
        var conflict = first_alias(expected, peers)
        if conflict[0] >= 0:
            return decision(Status.REJECTED, Reason.ALIAS, "reference write overlaps",
                            conflict[0], conflict[1])
    try:
        if not fits(source, candidate, cap):
            return decision(Status.UNKNOWN, Reason.WORK_LIMIT)
        observed = interpret_bounded(source, candidate)
    except e:
        return decision(Status.FAIL, Reason.INVALID_CANDIDATE, String(e))

    try:
        if not finite_only:
            var left = lower(source, reference)
            var right = lower(source, candidate)
            if not evaluate_lowering(source, left, expected) or not evaluate_lowering(source, right, observed):
                return decision(Status.FAIL, Reason.ORACLE_DISAGREEMENT)
            if checks.alias and reference.writable:
                var oracle_right = first_alias(observed, peers)
                if (
                    has_lowered_alias(left.output, peers)
                    or has_lowered_alias(right.output, peers) != (oracle_right[0] >= 0)
                ):
                    return decision(Status.FAIL, Reason.ORACLE_DISAGREEMENT)
        return compare_frames(expected, observed, reference.writable, candidate.writable, peers, checks)
    except e:
        return decision(Status.ERROR, Reason.ORACLE_DISAGREEMENT, String(e))


def replay_counterexample(source: Layout, reference: Program, candidate: Program,
                          peers: List[Layout], checks: Checks, witness: Verdict,
                          cap: Int = 256) -> Bool:
    var replay = verify(source, reference, candidate, peers, checks, cap, finite_only=True)
    return (
        replay.status == Status.FAIL
        and witness.status == Status.FAIL
        and replay.reason == witness.reason
        and replay.reason != Reason.ORACLE_DISAGREEMENT
        and replay.ordinal == witness.ordinal
        and replay.other == witness.other
        and replay.detail == witness.detail
    )
