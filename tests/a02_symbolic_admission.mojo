# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

from std.collections import List
from std.testing import assert_equal, assert_true
from layoutproof.a02 import (
    Layout, Op, Program, Reason, Status, admit_symbolic_write, certify,
    certify_affine, replay, replay_affine, verify,
)


def test_writable_symbolic() raises:
    var writable = Program([], True)
    var result = certify(writable, writable, 1)
    assert_true(result.status == Status.PASS)
    assert_true(result.reason == Reason.CONDITIONAL_EQUIVALENCE)
    assert_true(result.requires_write_admission())
    var proof = result.certificate.take()
    assert_true(replay(writable, writable, proof))

    var read_only = Layout([2], [0], 0, 1, 0, False)
    var denied = admit_symbolic_write(read_only, writable, writable, proof, [])
    assert_true(denied.status == Status.REJECTED and denied.reason == Reason.PERMISSION)
    assert_true(verify(read_only, writable, writable, []).reason == denied.reason)

    var source = Layout([2], [2], 0, 4, 6, True)
    var peers = List[Layout]()
    peers.append(Layout([1], [0], 2, 4, 6, False))
    var overlap = admit_symbolic_write(source, writable, writable, proof, peers)
    assert_true(overlap.status == Status.REJECTED and overlap.reason == Reason.ALIAS)
    assert_equal(overlap.ordinal, 1)
    var self_alias = Layout([2], [0], 0, 1, 6, True)
    assert_true(admit_symbolic_write(self_alias, writable, writable, proof, []).reason == Reason.ALIAS)
    var admitted = admit_symbolic_write(source, writable, writable, proof, [])
    assert_true(admitted.status == Status.PASS and admitted.reason == Reason.EQUIVALENT)
    assert_true(admit_symbolic_write(source, writable, writable, proof, [], cap=1).status == Status.UNKNOWN)
    var wrong_rank = Layout([1, 2], [0, 2], 0, 4, 6, True)
    assert_true(admit_symbolic_write(wrong_rank, writable, writable, proof, []).reason == Reason.CERTIFICATE)

    var read = Program([], False)
    var read_result = certify(read, read, 1)
    assert_true(read_result.status == Status.PASS and read_result.reason == Reason.EQUIVALENT)
    assert_true(not read_result.requires_write_admission())
    var read_proof = read_result.certificate.take()
    assert_true(admit_symbolic_write(source, read, read, read_proof, []).status == Status.REJECTED)


def test_broadcast_replay_definedness() raises:
    var source = Layout([2], [1], 0, 2, 0, False)
    var sliced = Program([Op.slice(0, 0, 1, 1)], False)
    var malformed = Program([Op.broadcast([1])], False)
    var exact = certify_affine(source, sliced, sliced)
    assert_true(exact.verdict.status == Status.PASS)
    var proof = exact.certificate.take()
    assert_true(replay_affine(source, sliced, sliced, proof))
    # The probe at zero agrees with the slice under a missing broadcast guard.
    assert_true(not replay_affine(source, sliced, malformed, proof))
    assert_true(not replay_affine(source, malformed, sliced, proof))

    var singleton = Layout([1], [0], 0, 1, 0, False)
    var expanded = Program([Op.expand(0), Op.broadcast([2, 3])], False)
    var broadcast = Program([Op.broadcast([2, 3])], False)
    var valid = certify_affine(singleton, expanded, broadcast)
    assert_true(valid.verdict.status == Status.PASS)
    assert_true(replay_affine(singleton, expanded, broadcast, valid.certificate.take()))


def main() raises:
    test_writable_symbolic()
    test_broadcast_replay_definedness()
    print("PASS: symbolic write admission and independent affine broadcast definedness")
