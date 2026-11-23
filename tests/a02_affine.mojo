# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: tests/a02_affine.mojo
# Module: tests.a02_affine

from std.testing import assert_equal, assert_true
from layoutproof.a02 import Layout, Op, Order, Program, Reason, Status, certify_affine
from layoutproof.a02 import replay_affine, replay_affine_counterexample, verify


def main() raises:
    var extent = 1_000_000_000
    var source = Layout([extent], [-1], extent - 1, extent, 11, True)
    var original = Program([Op.flip(0), Op.slice(0, 0, extent // 2, 2)], True)
    var fused = Program([Op.slice(0, extent - 1, extent // 2, -2)], True)
    assert_true(verify(source, original, fused, []).status == Status.UNKNOWN)
    var decision = certify_affine(source, original, fused)
    assert_true(decision.verdict.status == Status.PASS)
    var proof = decision.certificate.take()
    assert_equal(len(proof.points), 2)
    assert_true(replay_affine(source, original, fused, proof))
    proof.points[1].address += 1
    assert_true(not replay_affine(source, original, fused, proof))
    var mutated = Program([Op.slice(0, extent - 1, extent // 2, -1)], True)
    var counterexample = certify_affine(source, original, mutated)
    assert_true(counterexample.verdict.status == Status.FAIL)
    assert_true(counterexample.verdict.reason == Reason.LOGICAL)
    assert_equal(counterexample.verdict.ordinal, 1)
    var evidence = counterexample.certificate.take()
    assert_true(replay_affine_counterexample(source, original, mutated, evidence, counterexample.verdict))
    counterexample.verdict.ordinal = 2
    assert_true(not replay_affine_counterexample(source, original, mutated, evidence, counterexample.verdict))

    var scalar = Layout([], [], 0, 1, 11, False)
    var broadcast = Program([Op.expand(0), Op.broadcast([1, 3]), Op.squeeze(0)], False)
    var direct = Program([Op.broadcast([3])], False)
    assert_true(certify_affine(scalar, broadcast, direct).verdict.status == Status.PASS)
    var empty = Layout([0, 3], [Int.MIN, 1], 0, 0, 11, True)
    var empty_program = Program([Op.flip(1), Op.expand(2), Op.squeeze(2)], True)
    var identity = Program([], True)
    var vacuous = certify_affine(empty, empty_program, identity)
    assert_true(vacuous.verdict.status == Status.PASS)
    var empty_proof = vacuous.certificate.take()
    assert_equal(len(empty_proof.points), 0)
    assert_true(replay_affine(empty, empty_program, identity, empty_proof))
    var dense_reshape = Program([Op.reshape([3, 0], Order.C)], True)
    assert_true(certify_affine(empty, dense_reshape, identity).verdict.status == Status.UNSUPPORTED)
    var invalid = Program([Op.slice(1, 2, 3, -2)], True)
    assert_true(certify_affine(empty, empty_program, invalid).verdict.reason == Reason.INVALID_CANDIDATE)
    var domain_change = Program([Op.transpose(0, 1)], True)
    assert_true(certify_affine(empty, empty_program, domain_change).verdict.reason == Reason.DOMAIN)

    for rows in range(1, 5):
        for cols in range(1, 5):
            var dense = Layout([rows, cols], [cols, 1], 0, rows * cols, 0, True)
            var first = Program([Op.transpose(0, 1), Op.flip(1)], False)
            var second = Program([Op.flip(0), Op.permute([1, 0])], False)
            assert_true(certify_affine(dense, first, second).verdict.status == Status.PASS)
            assert_true(verify(dense, first, second, []).status == Status.PASS)
            var different = Program([Op.transpose(0, 1)], False)
            var bounded = verify(dense, first, different, [])
            var affine = certify_affine(dense, first, different)
            assert_true(affine.verdict.status == bounded.status)
            assert_equal(affine.verdict.ordinal, bounded.ordinal)
    print("PASS: affine certificates on concrete extents, replay, tampering and counterexamples")
