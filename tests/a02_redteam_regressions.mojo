# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: tests/a02_redteam_regressions.mojo
# Module: tests.a02_redteam_regressions

from std.collections import List
from std.testing import assert_equal, assert_true
from layoutproof.a02 import (
    Checks, Layout, Op, Order, Program, Reason, Status, admit_affine_write,
    certify, certify_affine, interpret, replay_affine, replay_counterexample, verify,
)


def check_writable_admission() raises:
    var writable = Program([], True)
    var read_only = Layout([2], [0], 0, 1, 0, False)
    var conditional = certify_affine(read_only, writable, writable)
    assert_true(conditional.verdict.status == Status.PASS)
    assert_true(conditional.verdict.reason == Reason.CONDITIONAL_EQUIVALENCE)
    assert_true(conditional.requires_write_admission)
    var proof = conditional.certificate.take()
    assert_true(replay_affine(read_only, writable, writable, proof))
    var denial = admit_affine_write(read_only, writable, writable, proof, [])
    assert_true(denial.status == Status.REJECTED and denial.reason == Reason.PERMISSION)

    var source = Layout([2], [2], 0, 4, 6, True)
    var peers = List[Layout]()
    peers.append(Layout([1], [0], 2, 4, 6, False))
    var affine = certify_affine(source, writable, writable)
    assert_true(affine.requires_write_admission)
    var peer_proof = affine.certificate.take()
    var conflict = admit_affine_write(source, writable, writable, peer_proof, peers)
    assert_true(conflict.status == Status.REJECTED and conflict.reason == Reason.ALIAS)
    assert_equal(conflict.ordinal, 1)
    assert_true(admit_affine_write(source, writable, writable, peer_proof, [], cap=1).status == Status.UNKNOWN)
    assert_true(admit_affine_write(source, writable, writable, peer_proof, []).status == Status.PASS)
    peer_proof.points[0].address += 1
    assert_true(admit_affine_write(source, writable, writable, peer_proof, []).reason == Reason.CERTIFICATE)

    var overlapping = Layout([2], [0], 0, 1, 6, True)
    var overlap = certify_affine(overlapping, writable, writable)
    var overlap_proof = overlap.certificate.take()
    var self_conflict = admit_affine_write(overlapping, writable, writable, overlap_proof, [])
    assert_true(self_conflict.status == Status.REJECTED and self_conflict.reason == Reason.ALIAS)
    assert_equal(self_conflict.other, 1)
    var read = Program([], False)
    var readonly_proof = certify_affine(source, read, read)
    assert_true(not readonly_proof.requires_write_admission)


def check_reshape_addresses() raises:
    var source = Layout([3], [-1], 2, 3, 7, False)
    var reshape = Program([Op.reshape([1, 3], Order.C)], False)
    var expanded = Program([Op.expand(0)], False)
    assert_true(verify(source, reshape, expanded, []).status == Status.PASS)
    var frame = interpret(source, reshape)
    assert_equal(frame.storage, 7)
    for ordinal in range(3):
        assert_equal(frame.cells[ordinal].source, ordinal)
        assert_equal(frame.cells[ordinal].physical, 2 - ordinal)
        assert_equal(frame.cells[ordinal].value, 2 - ordinal)

    var copied = Program([Op.reshape([1, 3], Order.C, True)], False)
    var copied_frame = interpret(source, copied)
    assert_true(copied_frame.storage != frame.storage)
    for ordinal in range(3):
        assert_equal(copied_frame.cells[ordinal].value, 2 - ordinal)
        assert_equal(copied_frame.cells[ordinal].physical, ordinal)
    var witness = verify(source, reshape, copied, [])
    assert_true(witness.status == Status.FAIL and witness.reason == Reason.ADDRESS)
    assert_true(replay_counterexample(source, reshape, copied, [], Checks.FULL, witness))

    var chunked = Layout([2, 4], [11, -2], 8, 20, 8, True)
    var split = Program([Op.reshape([2, 2, 2], Order.C)], False)
    var flattened = Program([Op.reshape([8], Order.C)], False)
    var round_trip = Program([Op.reshape([2, 2, 2], Order.C), Op.reshape([2, 4], Order.C)], False)
    assert_true(verify(chunked, Program([], False), round_trip, []).status == Status.PASS)
    assert_true(verify(chunked, split, flattened, []).reason == Reason.INVALID_CANDIDATE)
    var split_frame = interpret(chunked, split)
    for n in range(8):
        assert_equal(split_frame.cells[n].physical, 8 + 11 * (n // 4) - 2 * (n % 4))

    var f_layout = Layout([2, 3], [-2, -4], 10, 11, 9, True)
    var flatten_f = Program([Op.reshape([6], Order.F)], False)
    var unpack_f = Program([Op.reshape([6], Order.F), Op.reshape([2, 3], Order.F)], False)
    assert_true(verify(f_layout, Program([], False), unpack_f, []).status == Status.PASS)
    var f_frame = interpret(f_layout, flatten_f)
    for n in range(6):
        assert_equal(f_frame.cells[n].physical, 10 - 2 * n)


def check_proof_boundaries() raises:
    var source = Layout([2], [1], 0, 2, 0, True)
    var invalid = Program([Op.slice(0, 0, 3, 1), Op.slice(0, 0, 1, 1)], False)
    var fused = Program([Op.slice(0, 0, 1, 1)], False)
    var result = certify_affine(source, invalid, fused)
    assert_true(result.verdict.status == Status.REJECTED and result.verdict.reason == Reason.INVALID_REFERENCE)
    assert_true(not result.certificate)
    var identity = Program([], False)
    var flip = Program([Op.flip(1), Op.flip(1)], False)
    assert_true(certify(flip, identity, 1).status == Status.UNSUPPORTED)
    assert_true(certify(flip, identity, 2).status == Status.PASS)
    var limited = certify(identity, identity, 65)
    assert_true(limited.status == Status.UNKNOWN and limited.reason == Reason.WORK_LIMIT)
    assert_true(not limited.certificate)


def main() raises:
    check_writable_admission()
    check_reshape_addresses()
    check_proof_boundaries()
    print("PASS: red-team write admission, signed reshape, storage witness and proof limits")
